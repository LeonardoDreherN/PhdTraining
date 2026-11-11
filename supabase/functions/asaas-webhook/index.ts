// Webhook do Asaas. Publicado SEM verificação de JWT (quem chama é o
// Asaas); a autenticação é o header `asaas-access-token`, que tem de ser
// igual a ASAAS_WEBHOOK_TOKEN.
//
// Regras:
//   • Todo evento vai cru para `gateway_eventos` antes de qualquer coisa.
//   • O Asaas entrega "pelo menos uma vez": o id do evento (evt_...) é
//     único em gateway_eventos, e os créditos da carteira têm chave própria
//     por pagamento, para CONFIRMED + RECEIVED não creditarem duas vezes.
//   • Responde 200 mesmo quando o processamento falha (o erro fica no
//     log). Depois de 15 falhas seguidas o Asaas para a fila inteira, e aí
//     nenhum pagamento de ninguém seria registrado.

import { centavos, kycDe, statusSaque } from "../_shared/asaas.ts";
import { admin } from "../_shared/contexto.ts";

// deno-lint-ignore no-explicit-any
type Evento = Record<string, any>;

function tokenConfere(recebido: string | null): boolean {
  const esperado = Deno.env.get("ASAAS_WEBHOOK_TOKEN") ?? "";
  if (!recebido || !esperado || recebido.length !== esperado.length) return false;
  // Comparação em tempo constante: não deixa descobrir o token por tempo.
  let dif = 0;
  for (let i = 0; i < esperado.length; i++) dif |= recebido.charCodeAt(i) ^ esperado.charCodeAt(i);
  return dif === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("ok");
  if (!tokenConfere(req.headers.get("asaas-access-token"))) {
    return new Response("token inválido", { status: 401 });
  }

  const ev = (await req.json().catch(() => null)) as Evento | null;
  if (!ev?.event) return new Response("sem evento", { status: 400 });

  const db = admin();
  const eventId = String(ev.id ?? `${ev.event}:${ev.payment?.id ?? ev.transfer?.id ?? ev.account?.id}:${ev.dateCreated}`);

  const { data: log, error: eLog } = await db
    .from("gateway_eventos")
    .insert({ gateway: "asaas", event_id: eventId, tipo: ev.event, payload: ev })
    .select("id")
    .single();

  let logId = log?.id as string | undefined;
  if (eLog) {
    // Já recebido. Se foi processado, nada a fazer; se não, tenta de novo.
    const { data: antigo } = await db
      .from("gateway_eventos")
      .select("id, processado_em")
      .eq("gateway", "asaas")
      .eq("event_id", eventId)
      .maybeSingle();
    if (!antigo || antigo.processado_em) return new Response("duplicado");
    logId = antigo.id;
  }

  try {
    const personalId = await processar(db, ev, eventId);
    await db.from("gateway_eventos")
      .update({ processado_em: new Date().toISOString(), personal_id: personalId, erro: null })
      .eq("id", logId);
  } catch (e) {
    console.error("webhook", ev.event, e);
    await db.from("gateway_eventos")
      .update({ erro: e instanceof Error ? e.message : String(e) })
      .eq("id", logId);
  }
  return new Response("ok");
});

async function processar(db: ReturnType<typeof admin>, ev: Evento, eventId: string): Promise<string | null> {
  const tipo = String(ev.event);
  if (tipo.startsWith("ACCOUNT_STATUS_GENERAL_APPROVAL_")) return conta(db, ev);
  if (tipo.startsWith("PAYMENT_")) return pagamento(db, ev, tipo);
  if (tipo.startsWith("TRANSFER_")) return transferencia(db, ev, eventId);
  return null;
}

// ── Conta ─────────────────────────────────────────────────────

async function conta(db: ReturnType<typeof admin>, ev: Evento) {
  const contaId = ev.accountStatus?.id ?? ev.account?.id;
  const { data: c } = await db.from("pagamento_contas").select("personal_id, aprovado_em")
    .eq("gateway_account_id", contaId).maybeSingle();
  if (!c) throw new Error(`Conta ${contaId} não encontrada.`);
  const general = ev.accountStatus?.general ?? String(ev.event).replace("ACCOUNT_STATUS_GENERAL_APPROVAL_", "");
  const kyc = kycDe(general);
  await db.from("pagamento_contas").update({
    ...kyc,
    aprovado_em: kyc.kyc_status === "aprovado" ? (c.aprovado_em ?? new Date().toISOString()) : c.aprovado_em,
    atualizado_em: new Date().toISOString(),
  }).eq("personal_id", c.personal_id);
  return c.personal_id as string;
}

// ── Pagamento ─────────────────────────────────────────────────

const METODO: Record<string, string> = { PIX: "pix", BOLETO: "boleto", CREDIT_CARD: "cartao", DEBIT_CARD: "cartao" };

async function pagamento(db: ReturnType<typeof admin>, ev: Evento, tipo: string) {
  const p = ev.payment ?? {};
  let { data: cob } = await db.from("cobrancas").select("*").eq("gateway_payment_id", p.id).maybeSingle();
  if (!cob && p.externalReference) {
    ({ data: cob } = await db.from("cobrancas").select("*").eq("id", p.externalReference).maybeSingle());
  }
  if (!cob) throw new Error(`Cobrança do pagamento ${p.id} não encontrada.`);

  const agora = new Date().toISOString();
  const base = { atualizado_em: agora };

  switch (tipo) {
    case "PAYMENT_CONFIRMED":
    case "PAYMENT_RECEIVED": {
      const bruto = centavos(p.value);
      const liquido = centavos(p.netValue ?? p.value);
      await db.from("cobrancas").update({
        ...base,
        status: "pago",
        pago_em: cob.pago_em ?? (p.clientPaymentDate ?? p.paymentDate ?? p.confirmedDate ?? agora),
        metodo: METODO[p.billingType] ?? cob.metodo,
        taxa_centavos: bruto - liquido,
        liquido_centavos: liquido,
      }).eq("id", cob.id);
      // Um crédito por pagamento, venha CONFIRMED, RECEIVED ou os dois.
      await creditar(db, {
        personal_id: cob.personal_id,
        cobranca_id: cob.id,
        tipo: "credito",
        valor_centavos: liquido,
        descricao: cob.descricao ?? "Pagamento recebido",
        disponivel_em: p.creditDate ?? p.estimatedCreditDate ?? null,
        gateway_event_id: `credito:${p.id}`,
      });
      break;
    }
    case "PAYMENT_OVERDUE":
      if (cob.status !== "pago") await db.from("cobrancas").update({ ...base, status: "atrasado" }).eq("id", cob.id);
      break;
    case "PAYMENT_REFUNDED":
      await db.from("cobrancas").update({ ...base, status: "estornado" }).eq("id", cob.id);
      await creditar(db, {
        personal_id: cob.personal_id,
        cobranca_id: cob.id,
        tipo: "estorno",
        valor_centavos: -centavos(p.netValue ?? p.value),
        descricao: "Estorno",
        gateway_event_id: `estorno:${p.id}`,
      });
      break;
    case "PAYMENT_DELETED":
      await db.from("cobrancas").update({ ...base, status: "cancelado" }).eq("id", cob.id);
      break;
    case "PAYMENT_RESTORED":
      await db.from("cobrancas").update({ ...base, status: "pendente" }).eq("id", cob.id);
      break;
  }
  return cob.personal_id as string;
}

/// Movimento de carteira idempotente: a chave única em gateway_event_id
/// segura a repetição; a violação é ignorada de propósito.
async function creditar(db: ReturnType<typeof admin>, mov: Record<string, unknown>) {
  const { error } = await db.from("carteira_movimentos").insert(mov);
  if (error && error.code !== "23505") throw error;
}

// ── Transferência ─────────────────────────────────────────────

async function transferencia(db: ReturnType<typeof admin>, ev: Evento, _eventId: string) {
  const t = ev.transfer ?? {};
  let { data: s } = await db.from("saques").select("*").eq("gateway_transfer_id", t.id).maybeSingle();
  if (!s && t.externalReference) {
    ({ data: s } = await db.from("saques").select("*").eq("id", t.externalReference).maybeSingle());
  }
  if (!s) throw new Error(`Saque da transferência ${t.id} não encontrado.`);

  const status = statusSaque(t.status ?? String(ev.event).replace("TRANSFER_", ""));
  await db.from("saques").update({
    gateway_transfer_id: t.id ?? s.gateway_transfer_id,
    gateway_status: t.status ?? ev.event,
    status,
    taxa_centavos: t.transferFee !== undefined ? centavos(t.transferFee) : s.taxa_centavos,
    motivo_falha: t.failReason ?? s.motivo_falha,
    concluido_em: status === "concluido" ? (s.concluido_em ?? new Date().toISOString()) : s.concluido_em,
    atualizado_em: new Date().toISOString(),
  }).eq("id", s.id);

  if (status === "concluido") {
    await creditar(db, {
      personal_id: s.personal_id,
      saque_id: s.id,
      tipo: "saque",
      valor_centavos: -s.valor_centavos,
      descricao: s.destino_descricao ?? "Saque",
      gateway_event_id: `saque:${t.id ?? s.id}`,
    });
  }
  return s.personal_id as string;
}
