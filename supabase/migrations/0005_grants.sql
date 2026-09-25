-- ============================================================
-- 0005 — Permissões de tabela (GRANT)
--
-- RLS e GRANT são duas camadas diferentes, e faltava a de baixo.
--
--   GRANT diz se o papel PODE TOCAR na tabela.
--   RLS   diz QUAIS LINHAS ele enxerga depois disso.
--
-- Sem GRANT, o PostgREST nem mostra a tabela: responde 404 "Could not
-- find the table in the schema cache", porque o cache dele é montado por
-- papel. Foi exatamente o que aconteceu ao consultar a API com a anon key
-- depois de rodar o 0001 ao 0004.
--
-- O papel perigoso aqui seria `authenticated`: é com ele que o app
-- inteiro conversa depois do login. Sem grant, todo personal logado
-- receberia 404 em todas as telas.
--
-- Seguro rodar mais de uma vez.
-- ============================================================

grant usage on schema public to anon, authenticated;

-- ── authenticated ───────────────────────────────────────────
-- Acesso amplo de propósito: quem decide o que cada um vê são as policies
-- do 0001 ao 0003, não a ausência de grant. Misturar as duas camadas como
-- defesa deixa o sistema difícil de auditar — o grant vira uma regra
-- invisível que contradiz a policy.
grant select, insert, update, delete on all tables    in schema public to authenticated;
grant usage, select                  on all sequences in schema public to authenticated;
grant execute                        on all functions in schema public to authenticated;

-- ── anon ────────────────────────────────────────────────────
-- Quem não fez login não toca em nada. A única exceção é a tabela de
-- preços: a página pública de planos precisa lê-la antes de existir
-- qualquer usuário.
grant select on public.plataforma_planos to anon;

drop policy if exists "planos: visíveis sem login" on public.plataforma_planos;
create policy "planos: visíveis sem login"
  on public.plataforma_planos for select to anon
  using (ativo);

-- ── Tabelas futuras ─────────────────────────────────────────
-- Sem isto, toda tabela nova recomeça sem grant e o 404 volta.
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
  grant usage, select on sequences to authenticated;
alter default privileges in schema public
  grant execute on functions to authenticated;

notify pgrst, 'reload schema';

-- ── Conferência ─────────────────────────────────────────────
-- Deve listar `authenticated` com 4 privilégios em cada tabela, e `anon`
-- apenas em `plataforma_planos`.
select
  g.grantee,
  g.table_name,
  string_agg(g.privilege_type, ', ' order by g.privilege_type) as privilegios
from information_schema.role_table_grants g
where g.table_schema = 'public'
  and g.grantee in ('anon', 'authenticated')
group by g.grantee, g.table_name
order by g.grantee, g.table_name;
