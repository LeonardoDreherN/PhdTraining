import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { ErroAsaas } from "./asaas.ts";

export const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function json(corpo: unknown, status = 200): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

/// Erro que a tela mostra como está.
export class ErroUsuario extends Error {
  constructor(mensagem: string, public status = 400) {
    super(mensagem);
  }
}

/// Cliente com service_role: passa por cima do RLS. Só as funções usam,
/// e só depois de saber quem é o personal pelo JWT.
export function admin(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
}

/// O id de quem chamou, conferido pelo Supabase Auth (não confia no corpo).
export async function quemChamou(req: Request, db: SupabaseClient): Promise<string> {
  const token = req.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) throw new ErroUsuario("Faça login de novo.", 401);
  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user) throw new ErroUsuario("Faça login de novo.", 401);
  return data.user.id;
}

/// Envelope comum: CORS, corpo JSON, erros com mensagem legível.
export function servir(
  handler: (req: Request, corpo: Record<string, unknown>) => Promise<Response>,
) {
  Deno.serve(async (req) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
    try {
      const corpo = req.method === "POST" ? await req.json().catch(() => ({})) : {};
      return await handler(req, corpo as Record<string, unknown>);
    } catch (e) {
      if (e instanceof ErroUsuario) return json({ erro: e.message }, e.status);
      if (e instanceof ErroAsaas) {
        console.error("asaas", e.status, JSON.stringify(e.detalhes));
        return json({ erro: e.message }, 422);
      }
      console.error(e);
      return json({ erro: "Erro inesperado no servidor. Tente de novo." }, 500);
    }
  });
}

/// A conta de pagamento do personal, com a chave da subconta já lida do
/// cofre. Lança se ainda não há subconta.
export async function contaComChave(db: SupabaseClient, personalId: string) {
  const { data: conta, error } = await db
    .from("pagamento_contas")
    .select("*")
    .eq("personal_id", personalId)
    .maybeSingle();
  if (error) throw error;
  if (!conta?.gateway_account_id) {
    throw new ErroUsuario("Ative os recebimentos antes: falta criar sua conta no gateway.");
  }
  const { data: chave, error: e2 } = await db.rpc("gateway_ler_chave", { p_personal_id: personalId });
  if (e2) throw e2;
  if (!chave) throw new Error(`Subconta sem chave no cofre: ${personalId}`);
  return { conta, chave: chave as string };
}
