-- ════════════════════════════════════════════════════════════
--  0023 — Asaas: chave da subconta no cofre e CPF do aluno
--
--  As Edge Functions `asaas-*` falam com o gateway. Este arquivo dá a
--  elas o que faltava no banco:
--
--  CHAVE DA SUBCONTA
--  O Asaas devolve a apiKey da subconta uma vez só, na criação. Ela vai
--  para o Supabase Vault (criptografada), e `pagamento_contas.api_key_ref`
--  guarda só o nome do segredo — como o 0003 já previa. Ler e gravar
--  passa por duas funções que SÓ a service_role executa: o 0005 dá
--  execute em toda função nova a `authenticated`, então aqui a permissão
--  é tirada de propósito. Um personal logado que chamasse
--  `gateway_ler_chave` levaria a chave de qualquer outro.
--
--  CPF DO ALUNO
--  O Asaas recusa cobrança sem CPF do pagador ("Para criar esta cobrança
--  é necessário preencher o CPF ou CNPJ do cliente" — testado no
--  sandbox). Fica em `alunos`, que só o personal dono e o próprio aluno
--  leem. `gateway_customer_id` é o cliente criado na subconta do
--  personal, para não criar um cliente novo a cada cobrança.
--
--  Depende do 0001, 0003 e 0005. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

alter table public.alunos add column if not exists cpf text;
alter table public.alunos add column if not exists gateway_customer_id text;

-- ── Cofre ───────────────────────────────────────────────────
create or replace function public.gateway_guardar_chave(p_personal_id uuid, p_chave text)
returns text
language plpgsql security definer set search_path = public, vault as $$
declare
  v_nome text := 'asaas_subconta_' || p_personal_id;
  v_id   uuid;
begin
  select id into v_id from vault.secrets where name = v_nome;
  if v_id is null then
    perform vault.create_secret(p_chave, v_nome, 'apiKey da subconta Asaas do personal');
  else
    perform vault.update_secret(v_id, p_chave);
  end if;
  update public.pagamento_contas set api_key_ref = v_nome where personal_id = p_personal_id;
  return v_nome;
end;
$$;

create or replace function public.gateway_ler_chave(p_personal_id uuid)
returns text
language sql stable security definer set search_path = public, vault as $$
  select s.decrypted_secret
    from public.pagamento_contas c
    join vault.decrypted_secrets s on s.name = c.api_key_ref
   where c.personal_id = p_personal_id;
$$;

revoke all on function public.gateway_guardar_chave(uuid, text) from public, anon, authenticated;
revoke all on function public.gateway_ler_chave(uuid)            from public, anon, authenticated;
grant execute on function public.gateway_guardar_chave(uuid, text) to service_role;
grant execute on function public.gateway_ler_chave(uuid)           to service_role;

notify pgrst, 'reload schema';

-- Conferência: as duas funções NÃO podem aparecer para `authenticated`.
select p.proname,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_executa,
       has_function_privilege('service_role',  p.oid, 'execute') as service_role_executa
  from pg_proc p
 where p.proname in ('gateway_guardar_chave', 'gateway_ler_chave');
