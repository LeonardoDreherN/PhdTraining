// Subconta do personal no Asaas.
//
//   { acao: "criar" }   cria a subconta com os dados de pagamento_contas
//   { acao: "status" }  situação cadastral + documentos pendentes (com o
//                       link de envio do próprio Asaas, quando houver)
//
// Só o próprio personal chama, com o JWT dele.

import { asaas, chavePlataforma, EVENTOS_WEBHOOK, kycDe } from "../_shared/asaas.ts";
import { admin, contaComChave, ErroUsuario, json, quemChamou, servir } from "../_shared/contexto.ts";

const soDigitos = (s: unknown) => String(s ?? "").replace(/\D/g, "");

servir(async (req, corpo) => {
  const db = admin();
  const personalId = await quemChamou(req, db);

  const { data: perfil } = await db.from("profiles").select("role, email").eq("id", personalId).single();
  if (perfil?.role !== "personal") throw new ErroUsuario("Só profissionais recebem pelo app.", 403);

  switch (corpo.acao) {
    case "criar":
      return json(await criar(db, personalId, perfil.email as string | null));
    case "status":
      return json(await status(db, personalId));
    default:
      throw new ErroUsuario("Ação desconhecida.");
  }
});

async function criar(db: ReturnType<typeof admin>, personalId: string, emailPerfil: string | null) {
  const { data: atual } = await db.from("pagamento_contas").select("*").eq("personal_id", personalId).maybeSingle();
  if (!atual) throw new ErroUsuario("Salve seus dados antes de enviar.");
  // O que o Asaas recusa sem: conferido aqui para a mensagem dizer o que
  // falta, em vez do erro genérico do gateway.
  const docAtual = soDigitos(atual.cpf_cnpj);
  const falta = [
    [docAtual.length === 11 || docAtual.length === 14, "CPF/CNPJ"],
    [atual.nome_responsavel, "nome"],
    [docAtual.length !== 11 || atual.data_nascimento, "data de nascimento"],
    [docAtual.length !== 14 || atual.razao_social || atual.nome_responsavel, "razão social"],
    [atual.email_cobranca || emailPerfil, "e-mail"],
    [soDigitos(atual.telefone_celular).length >= 10, "celular"],
    [atual.renda_mensal_centavos, "renda mensal"],
    [soDigitos(atual.cep).length === 8, "CEP"],
    [atual.logradouro, "rua"],
    [atual.numero, "número"],
    [atual.bairro, "bairro"],
  ].filter(([ok]) => !ok).map(([, nome]) => nome);
  if (falta.length) throw new ErroUsuario(`Falta preencher: ${falta.join(", ")}.`);

  // Trava contra dois toques (ou um timeout repetido): só quem troca o
  // nulo por "criando" segue. Sem isto, duas subcontas para a mesma pessoa.
  const { data: travada } = await db
    .from("pagamento_contas")
    .update({ gateway_account_id: `criando:${personalId}` })
    .eq("personal_id", personalId)
    .is("gateway_account_id", null)
    .select("*")
    .maybeSingle();
  if (!travada) return await status(db, personalId);

  const c = travada;
  const doc = soDigitos(c.cpf_cnpj);
  const pf = doc.length === 11;
  const urlWebhook = `${Deno.env.get("SUPABASE_URL")}/functions/v1/asaas-webhook`;
  const emailAlertas = Deno.env.get("ASAAS_WEBHOOK_EMAIL");
  const token = Deno.env.get("ASAAS_WEBHOOK_TOKEN");
  if (!emailAlertas || !token) throw new Error("ASAAS_WEBHOOK_EMAIL e ASAAS_WEBHOOK_TOKEN precisam estar configurados.");

  let criadaNoAsaas = false;
  try {
    const nova = await asaas<Record<string, unknown>>(chavePlataforma(), "POST", "/accounts", {
      name: pf ? c.nome_responsavel : (c.razao_social || c.nome_responsavel),
      email: c.email_cobranca || emailPerfil,
      cpfCnpj: doc,
      ...(pf ? { birthDate: c.data_nascimento } : { companyType: c.tipo_empresa }),
      phone: soDigitos(c.telefone_fixo) || undefined,
      mobilePhone: soDigitos(c.telefone_celular),
      incomeValue: (c.renda_mensal_centavos ?? 0) / 100,
      address: c.logradouro,
      addressNumber: c.numero,
      complement: c.complemento || undefined,
      province: c.bairro,
      postalCode: soDigitos(c.cep),
      externalReference: personalId,
      webhooks: [{
        name: "PHD",
        url: urlWebhook,
        email: emailAlertas,
        enabled: true,
        interrupted: false,
        apiVersion: 3,
        authToken: token,
        sendType: "SEQUENTIALLY",
        events: EVENTOS_WEBHOOK,
      }],
    });
    criadaNoAsaas = true;
    console.log("subconta criada", personalId, nova.id);

    const chave = (nova.apiKey ?? (nova.accessToken as { apiKey?: string } | undefined)?.apiKey) as string | undefined;
    if (!chave) throw new Error("O Asaas criou a subconta mas não devolveu a apiKey.");

    // A chave vai para o cofre ANTES de qualquer outra coisa: ela não pode
    // ser recuperada depois, e perder isto é perder acesso ao dinheiro.
    const { error: eCofre } = await db.rpc("gateway_guardar_chave", { p_personal_id: personalId, p_chave: chave });
    if (eCofre) throw eCofre;

    await db.from("pagamento_contas").update({
      gateway_account_id: nova.id,
      gateway_wallet_id: nova.walletId,
      kyc_status: "em_analise",
      atualizado_em: new Date().toISOString(),
    }).eq("personal_id", personalId);
  } catch (e) {
    // Destrava só se a subconta não chegou a existir: se o Asaas criou e
    // falhamos depois (cofre, update), repetir criaria uma segunda conta
    // para o mesmo CPF. A trava fica e o log diz qual conta conferir.
    if (!criadaNoAsaas) {
      await db.from("pagamento_contas").update({ gateway_account_id: null }).eq("personal_id", personalId);
      throw e;
    }
    console.error("subconta criada mas não registrada", personalId, e);
    throw new ErroUsuario("Sua conta foi criada no gateway, mas não terminamos de registrar. Fale com o suporte do PHD.", 500);
  }

  return { kyc_status: "em_analise", pode_receber: false, pode_sacar: false, documentos: [], aguardando: true };
}

async function status(db: ReturnType<typeof admin>, personalId: string) {
  const { data: c } = await db.from("pagamento_contas").select("*").eq("personal_id", personalId).maybeSingle();
  if (!c?.gateway_account_id || String(c.gateway_account_id).startsWith("criando:")) {
    return {
      kyc_status: c?.kyc_status ?? "pendente",
      pode_receber: false,
      pode_sacar: false,
      documentos: [],
      aguardando: Boolean(c?.gateway_account_id),
    };
  }

  const { chave } = await contaComChave(db, personalId);
  const [situacao, docs] = await Promise.all([
    asaas<{ general?: string }>(chave, "GET", "/myAccount/status"),
    asaas<{ data?: Record<string, unknown>[] }>(chave, "GET", "/myAccount/documents").catch(() => ({ data: [] })),
  ]);

  const kyc = kycDe(situacao.general);
  const documentos = (docs.data ?? []).map((d) => ({
    titulo: d.title,
    descricao: d.description,
    status: d.status,
    link: d.onboardingUrl ?? null,
  }));
  const faltaEnviar = documentos.some((d) => d.status === "NOT_SENT" || d.status === "REJECTED");

  await db.from("pagamento_contas").update({
    ...kyc,
    aprovado_em: kyc.kyc_status === "aprovado" ? (c.aprovado_em ?? new Date().toISOString()) : c.aprovado_em,
    documentos_enviados_em: faltaEnviar ? null : (c.documentos_enviados_em ?? new Date().toISOString()),
    // O app lê como lista de textos (PagamentoConta.kycPendencias).
    kyc_pendencias: documentos.filter((d) => d.status !== "APPROVED").map((d) => String(d.titulo ?? "")),
    atualizado_em: new Date().toISOString(),
  }).eq("personal_id", personalId);

  return { ...kyc, documentos };
}
