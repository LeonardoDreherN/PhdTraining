-- ============================================================
-- Verificação do banco — roda tudo e devolve UMA tabela só.
--
-- O SQL Editor do Supabase mostra apenas o resultado da última consulta,
-- então aqui está tudo junto num relatório único.
--
-- Não altera nada, exceto pedir ao PostgREST que recarregue o cache de
-- schema — necessário depois de criar tabelas, senão a API REST continua
-- respondendo 404 para elas.
-- ============================================================

notify pgrst, 'reload schema';

with tabelas as (
  select
    c.relname::text as item,
    case when c.relrowsecurity then 'RLS ligado' else '*** RLS DESLIGADO ***' end as situacao,
    (select count(*) from pg_policies p
      where p.schemaname = 'public' and p.tablename = c.relname)::text as detalhe
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
),
buckets as (
  select
    b.id::text as item,
    case when b.public then 'PÚBLICO' else 'privado' end as situacao,
    (select count(*) from pg_policies p
      where p.schemaname = 'storage' and p.tablename = 'objects'
        and p.qual like '%' || b.id || '%')::text as detalhe
  from storage.buckets b
),
funcoes as (
  select
    p.proname::text as item,
    'função' as situacao,
    '' as detalhe
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('eh_admin_plataforma','meu_personal_id','aluno_e_meu',
                      'handle_new_user','duplicar_exercicio_oficial',
                      'alunos_ativos','progresso_cadastro_pagamento')
),
planos as (
  select
    'plataforma_planos: ' || count(*)::text || ' plano(s)' as item,
    'dados' as situacao,
    coalesce(string_agg(slug, ', ' order by ordem), '(vazio)') as detalhe
  from public.plataforma_planos
)
select bloco, item, situacao, detalhe from (
  select 1 as ord, 'TABELA'  as bloco, item, situacao, detalhe from tabelas
  union all
  select 2, 'BUCKET',  item, situacao, detalhe from buckets
  union all
  select 3, 'FUNÇÃO',  item, situacao, detalhe from funcoes
  union all
  select 4, 'DADOS',   item, situacao, detalhe from planos
) x
-- Qualquer coisa com RLS desligado sobe para o topo da lista.
order by (situacao like '***%') desc, ord, item;
