// Cliente do Asaas (API v3).
//
// A chave da conta-plataforma (ASAAS_API_KEY) só cria subcontas. Todo o
// resto — cliente, cobrança, saldo, saque — roda com a chave da subconta
// do personal, para o dinheiro cair e sair direto da conta dele.
//
// Secrets (supabase secrets set ...):
//   ASAAS_API_KEY        chave da conta-plataforma (sandbox: $aact_hmlg_...)
//   ASAAS_BASE_URL       https://api-sandbox.asaas.com/v3 | https://api.asaas.com/v3
//   ASAAS_WEBHOOK_TOKEN  32+ caracteres; o Asaas devolve no header
//                        `asaas-access-token` e o webhook confere

export const ASAAS_BASE_URL = Deno.env.get("ASAAS_BASE_URL") ?? "https://api-sandbox.asaas.com/v3";

export class ErroAsaas extends Error {
  constructor(public status: number, public detalhes: unknown, mensagem: string) {
    super(mensagem);
  }
}

/// Chamada ao Asaas com a chave indicada. Erro de negócio do Asaas vem
/// como `{ errors: [{ code, description }] }`; a descrição já é em
/// português e vai direto para a tela.
export async function asaas<T = Record<string, unknown>>(
  chave: string,
  metodo: "GET" | "POST" | "DELETE",
  caminho: string,
  corpo?: unknown,
): Promise<T> {
  const r = await fetch(`${ASAAS_BASE_URL}${caminho}`, {
    method: metodo,
    headers: {
      "access_token": chave,
      "Content-Type": "application/json",
      "User-Agent": "PHD-Training/1.0",
    },
    body: corpo === undefined ? undefined : JSON.stringify(corpo),
  });
  const texto = await r.text();
  let json: unknown = null;
  try {
    json = texto ? JSON.parse(texto) : null;
  } catch {
    json = texto;
  }
  if (!r.ok) {
    const erros = (json as { errors?: { description?: string }[] })?.errors;
    const msg = erros?.map((e) => e.description).filter(Boolean).join(" ") ||
      `O gateway respondeu ${r.status}.`;
    throw new ErroAsaas(r.status, json, msg);
  }
  return json as T;
}

export function chavePlataforma(): string {
  const k = Deno.env.get("ASAAS_API_KEY");
  if (!k) throw new Error("ASAAS_API_KEY não configurada no Supabase.");
  return k;
}

/// Os eventos que cada subconta manda para o nosso webhook. Conferidos no
/// sandbox (POST /webhooks aceitou a lista inteira).
export const EVENTOS_WEBHOOK = [
  "ACCOUNT_STATUS_GENERAL_APPROVAL_APPROVED",
  "ACCOUNT_STATUS_GENERAL_APPROVAL_AWAITING_APPROVAL",
  "ACCOUNT_STATUS_GENERAL_APPROVAL_PENDING",
  "ACCOUNT_STATUS_GENERAL_APPROVAL_REJECTED",
  "PAYMENT_CONFIRMED",
  "PAYMENT_RECEIVED",
  "PAYMENT_OVERDUE",
  "PAYMENT_REFUNDED",
  "PAYMENT_DELETED",
  "PAYMENT_RESTORED",
  "TRANSFER_CREATED",
  "TRANSFER_PENDING",
  "TRANSFER_IN_BANK_PROCESSING",
  "TRANSFER_BLOCKED",
  "TRANSFER_DONE",
  "TRANSFER_FAILED",
  "TRANSFER_CANCELLED",
];

/// Situação cadastral do Asaas → a nossa. `general` é a que vale.
export function kycDe(general: string | undefined): {
  kyc_status: string;
  pode_receber: boolean;
  pode_sacar: boolean;
} {
  switch (general) {
    case "APPROVED":
      return { kyc_status: "aprovado", pode_receber: true, pode_sacar: true };
    case "REJECTED":
      return { kyc_status: "recusado", pode_receber: false, pode_sacar: false };
    default:
      return { kyc_status: "em_analise", pode_receber: false, pode_sacar: false };
  }
}

/// Status de transferência do Asaas → o nosso (0003).
export const statusSaque = (s: string | undefined) =>
  s === "DONE" ? "concluido" : s === "FAILED" ? "falhou" : s === "CANCELLED" ? "cancelado" : "processando";

/// Reais (número do Asaas) → centavos, sem erro de ponto flutuante.
export const centavos = (v: unknown) => Math.round(Number(v ?? 0) * 100);

/// Data de hoje no fuso de Brasília, como o Asaas espera (YYYY-MM-DD).
export function hojeBrasil(): string {
  return new Date().toLocaleDateString("sv-SE", { timeZone: "America/Sao_Paulo" });
}
