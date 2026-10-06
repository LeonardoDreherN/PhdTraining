-- ════════════════════════════════════════════════════════════
--  0008 — Recursão infinita na policy de update de profiles
--
--  A policy "profiles: edito o meu" (0001) conferia o
--  `is_platform_admin` com uma subconsulta em public.profiles.
--  Uma policy de profiles que lê profiles faz o Postgres aplicar
--  as policies de profiles de novo, e ele aborta com
--  "infinite recursion detected in policy for relation profiles"
--  (42P17). Resultado: nenhum update em profiles passava — nem o
--  nome, nem a foto.
--
--  A conferência agora passa por funções `security definer`, que
--  leem a tabela sem reaplicar o RLS. `eh_admin_plataforma()` já
--  existia (0001); `meu_role()` é nova e trava o `role` pelo mesmo
--  motivo do admin: sem isso, um aluno virava personal com um PATCH.
--  O app nunca altera o `role` depois do cadastro.
--
--  Depende do 0001. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create or replace function public.meu_role()
returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid();
$$;

revoke all on function public.meu_role() from public;
grant execute on function public.meu_role() to authenticated;

drop policy if exists "profiles: edito o meu" on public.profiles;
create policy "profiles: edito o meu"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (
    id = auth.uid()
    and is_platform_admin = public.eh_admin_plataforma()
    and role = public.meu_role()
  );

notify pgrst, 'reload schema';
