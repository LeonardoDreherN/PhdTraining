// Saldo e saque da subconta do personal.
//
//   { acao: "saldo" }  saldo disponível, lido do Asaas — o 0003 manda o
//                      saldo verdadeiro morar no gateway, nunca na soma
//                      de carteira_movimentos.
//   { acao: "sacar", valor_centavos, pix_chave, pix_tipo, idempotency_key }
//                      transferência Pix para o personal. A chave de
//                      idempotência vem do app: dois toques, um saque.

import { asaas, centavos, statusSaque } from "../_shared/asaas.ts";
import { admin, contaComChave, ErroUsuario, json, quemChamou, servir } from "../_shared/contexto.ts";

const TIPOS_PIX = ["CPF", "CNPJ", "EMAIL", "PHONE", "EVP"];

servir(async (req, corpo) => {
  const db = admin();
  const personalId = await quemChamou(req, db);

  switch (corpo.acao) {
    case "saldo": {
      const { chave } = await contaComChave(db, personalId);
      const s = await asaas<{ balance: number }>(chave, "GET", "/finance/balance");
      return json({ saldo_centavos: centavos(s.balance) });
    }
    case "sacar":
      return json(await sacar(db, personalId, corpo));
    default:
      throw new ErroUsuario("Ação desconhecida.");
  }
});

async function sacar(db: ReturnType<typeof admin>, personalId: string, corpo: Record<string, unknown>) {
  const valor = Math.trunc(Number(corpo.valor_centavos));
  const chavePix = String(corpo.pix_chave ?? "").trim();
  const tipo = String(corpo.pix_tipo ?? "").toUpperCase();
  const idem = String(corpo.idempotency_key ?? "");
  if (!Number.isFinite(valor) || valor < 100) throw new ErroUsuario("O saque mínimo é R$ 1,00.");
  if (!chavePix || !TIPOS_PIX.includes(tipo)) throw new ErroUsuario("Informe a chave Pix e o tipo dela.");
  if (idem.length < 8) throw new ErroUsuario("Requisição sem chave de idempotência.");

  const { conta, chave } = await contaComChave(db, personalId);
  if (!conta.pode_sacar) throw new ErroUsuario("Seu cadastro ainda não permite saque.");

  // Mesmo pedido de novo (toque duplo, rede caindo): devolve o que já existe.
  const { data: repetido } = await db.from("saques").select("*").eq("idempotency_key", idem).maybeSingle();
  if (repetido) {
    if (repetido.personal_id !== personalId) throw new ErroUsuario("Requisição inválida.");
    return { saque: repetido };
  }

  const s = await asaas<{ balance: number }>(chave, "GET", "/finance/balance");
  if (valor > centavos(s.balance)) throw new ErroUsuario("Saldo insuficiente para esse valor.");

  const destino = { operationType: "PIX", pixAddressKey: chavePix, pixAddressKeyType: tipo };
  const { data: saque, error } = await db.from("saques").insert({
    personal_id: personalId,
    valor_centavos: valor,
    destino_tipo: "pix",
    destino_descricao: `Pix ${tipo} ${chavePix}`,
    destino,
    status: "solicitado",
    validacao_status: "nao_aplicavel",
    idempotency_key: idem,
  }).select("*").single();
  if (error) {
    // Corrida com outro pedido igual: o índice único segurou.
    const { data: outro } = await db.from("saques").select("*").eq("idempotency_key", idem).maybeSingle();
    if (outro) return { saque: outro };
    throw error;
  }

  try {
    const t = await asaas<Record<string, unknown>>(chave, "POST", "/transfers", {
      value: valor / 100,
      ...destino,
      description: "Saque PHD",
      externalReference: saque.id,
    });
    const { data: atualizado } = await db.from("saques").update({
      gateway_transfer_id: t.id,
      gateway_status: t.status,
      status: statusSaque(t.status as string),
      taxa_centavos: centavos(t.transferFee),
      motivo_falha: (t.failReason as string) ?? null,
      atualizado_em: new Date().toISOString(),
    }).eq("id", saque.id).select("*").single();
    return { saque: atualizado };
  } catch (e) {
    await db.from("saques").update({
      status: "falhou",
      motivo_falha: e instanceof Error ? e.message : String(e),
      atualizado_em: new Date().toISOString(),
    }).eq("id", saque.id);
    throw e;
  }
}
