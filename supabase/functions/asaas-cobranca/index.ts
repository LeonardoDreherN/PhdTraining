// Cobrança pelo Asaas, na subconta do personal (100% dele).
//
//   { acao: "gerar", cobranca_id, cpf? }  transforma uma cobrança do app em
//        cobrança do Asaas e devolve o link da fatura, onde o aluno escolhe
//        Pix, boleto ou cartão. Sem CPF do aluno o Asaas recusa: a resposta
//        traz `precisa_cpf` e o app pergunta.
//   { acao: "cancelar", cobranca_id }     apaga no Asaas; o webhook confirma.

import { asaas, hojeBrasil } from "../_shared/asaas.ts";
import { admin, contaComChave, ErroUsuario, json, quemChamou, servir } from "../_shared/contexto.ts";

const soDigitos = (s: unknown) => String(s ?? "").replace(/\D/g, "");

servir(async (req, corpo) => {
  const db = admin();
  const personalId = await quemChamou(req, db);
  const cobrancaId = String(corpo.cobranca_id ?? "");
  if (!cobrancaId) throw new ErroUsuario("Cobrança não informada.");

  const { data: cob } = await db.from("cobrancas").select("*").eq("id", cobrancaId).maybeSingle();
  // Mesma resposta para "não existe" e "não é sua": não confirma ids alheios.
  if (!cob || cob.personal_id !== personalId) throw new ErroUsuario("Cobrança não encontrada.", 404);

  switch (corpo.acao) {
    case "gerar":
      return json(await gerar(db, personalId, cob, corpo.cpf));
    case "cancelar":
      return json(await cancelar(db, personalId, cob));
    default:
      throw new ErroUsuario("Ação desconhecida.");
  }
});

// deno-lint-ignore no-explicit-any
type Linha = Record<string, any>;

async function gerar(db: ReturnType<typeof admin>, personalId: string, cob: Linha, cpfInformado: unknown) {
  if (cob.link_pagamento && cob.gateway_payment_id && !String(cob.gateway_payment_id).startsWith("criando:")) {
    return { link: cob.link_pagamento };
  }
  if (!["pendente", "atrasado"].includes(cob.status)) {
    throw new ErroUsuario("Só dá para gerar link de cobrança em aberto.");
  }
  if (!cob.aluno_id) throw new ErroUsuario("A cobrança não tem aluno.");

  const { conta, chave } = await contaComChave(db, personalId);
  if (!conta.pode_receber) throw new ErroUsuario("Seu cadastro no gateway ainda não foi aprovado.");

  const { data: aluno } = await db.from("alunos").select("*").eq("id", cob.aluno_id).single();
  let cpf = soDigitos(aluno.cpf);
  if (cpfInformado !== undefined && cpfInformado !== null && String(cpfInformado).trim() !== "") {
    cpf = soDigitos(cpfInformado);
    if (cpf.length !== 11 && cpf.length !== 14) throw new ErroUsuario("CPF ou CNPJ inválido.");
    await db.from("alunos").update({ cpf }).eq("id", aluno.id);
  }
  if (!cpf) return { precisa_cpf: true, aluno: aluno.nome };

  // Trava contra dois toques: só quem marca "criando" gera a cobrança.
  const { data: travada } = await db
    .from("cobrancas")
    .update({ gateway_payment_id: `criando:${cob.id}` })
    .eq("id", cob.id)
    .is("gateway_payment_id", null)
    .select("id")
    .maybeSingle();
  if (!travada) throw new ErroUsuario("Esta cobrança já está sendo gerada. Atualize a tela em instantes.", 409);

  try {
    let clienteId = aluno.gateway_customer_id as string | null;
    if (!clienteId) {
      const cli = await asaas<{ id: string }>(chave, "POST", "/customers", {
        name: aluno.nome,
        cpfCnpj: cpf,
        email: aluno.email || undefined,
        mobilePhone: soDigitos(aluno.whatsapp) || undefined,
        externalReference: aluno.id,
        // O personal manda o link pelo WhatsApp. Com notificação ligada o
        // Asaas também avisaria por e-mail/SMS, e SMS é cobrado à parte.
        notificationDisabled: true,
      });
      clienteId = cli.id;
      await db.from("alunos").update({ gateway_customer_id: clienteId }).eq("id", aluno.id);
    } else if (cpfInformado) {
      await asaas(chave, "POST", `/customers/${clienteId}`, { cpfCnpj: cpf });
    }

    // Vencimento no passado o Asaas recusa; a cobrança atrasada vence hoje.
    const hoje = hojeBrasil();
    const vencimento = cob.vencimento < hoje ? hoje : cob.vencimento;

    const pag = await asaas<{ id: string; invoiceUrl: string }>(chave, "POST", "/payments", {
      customer: clienteId,
      billingType: "UNDEFINED",
      value: cob.valor_centavos / 100,
      dueDate: vencimento,
      description: cob.descricao ?? "Mensalidade",
      externalReference: cob.id,
    });

    await db.from("cobrancas").update({
      origem: "gateway",
      gateway_payment_id: pag.id,
      link_pagamento: pag.invoiceUrl,
      vencimento,
      atualizado_em: new Date().toISOString(),
    }).eq("id", cob.id);

    return { link: pag.invoiceUrl };
  } catch (e) {
    await db.from("cobrancas").update({ gateway_payment_id: null }).eq("id", cob.id);
    throw e;
  }
}

async function cancelar(db: ReturnType<typeof admin>, personalId: string, cob: Linha) {
  if (cob.origem !== "gateway" || !cob.gateway_payment_id) {
    throw new ErroUsuario("Esta cobrança não está no gateway.");
  }
  if (cob.status === "pago") throw new ErroUsuario("Cobrança paga não se cancela; faça o estorno pelo Asaas.");
  const { chave } = await contaComChave(db, personalId);
  await asaas(chave, "DELETE", `/payments/${cob.gateway_payment_id}`);
  await db.from("cobrancas").update({ status: "cancelado", atualizado_em: new Date().toISOString() }).eq("id", cob.id);
  return { ok: true };
}
