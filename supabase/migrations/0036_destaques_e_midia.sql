-- ════════════════════════════════════════════════════════════
--  0036 — O destaque que faltava, o desempate e a mídia do feed
--
--  Reli a especificação do feed contra o app. Três coisas.
--
--  1. O DESTAQUE DE NUTRIÇÃO NUNCA ERA GERADO
--
--  A tabela da especificação pede DOIS destaques: constância nos
--  treinos e consistência nutricional. A coluna `destaque_tipo` do 0029
--  já aceitava 'nutricao', e `gerar_destaques` só calculava treino. A
--  metade nutricional do recurso existia no esquema e não no código —
--  o pior lugar para uma funcionalidade faltar, porque tudo parece
--  pronto.
--
--  2. NÃO HAVIA REGRA DE DESEMPATE
--
--  "Definir regra de desempate, por exemplo: maior sequência de semanas
--  com adesão integral; se persistir empate, destacar os alunos
--  empatados." Eu tinha pulado direto para o fim da frase e destacava
--  todos os empatados de saída. Agora o desempate acontece: entre os
--  empatados em percentual, destaca quem vem de mais semanas seguidas
--  de adesão integral; se ainda empatar, aí sim vão todos.
--
--  3. O FEED NÃO ACEITAVA FOTO
--
--  "Permitir que o aluno publique fotos e textos", "permitir adicionar
--  uma legenda à foto", "publicações em texto e, se possível, com
--  imagem". A coluna `midia_url` existia desde o 0029 e nada escrevia
--  nela: não havia bucket nem caminho de envio.
--
--  O bucket é PRIVADO. A especificação manda "aplicar controles de
--  acesso às mídias e publicações", e bucket público dá URL adivinhável
--  — foto de aluno fora da comunidade é vazamento mesmo que ninguém
--  publique o link. A leitura sai por URL assinada, como as fotos de
--  progresso.
--
--  Depende do 0029 e do 0033. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════
--  MÍDIA DO FEED
-- ════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('feed-midia', 'feed-midia', false, 10485760,
   array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- O caminho é '<personal_id>/<user_id>/<arquivo>'.
--
-- A primeira pasta diz de QUAL comunidade é a foto, e é ela que a
-- leitura confere — sem isso, a policy teria de abrir a publicação para
-- descobrir o dono do feed, e a publicação ainda não existe na hora do
-- envio. A segunda diz quem enviou, e impede sobrescrever a foto de
-- outra pessoa.

drop policy if exists "feed: a comunidade lê a mídia" on storage.objects;
create policy "feed: a comunidade lê a mídia"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'feed-midia'
    and public.feed_e_meu(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "feed: envio na própria pasta" on storage.objects;
create policy "feed: envio na própria pasta"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'feed-midia'
    and public.feed_e_meu(((storage.foldername(name))[1])::uuid)
    and (storage.foldername(name))[2] = auth.uid()::text
  );

-- Apagar: quem enviou, e o dono do feed, que precisa poder remover
-- conteúdo ofensivo de verdade — não só tirar da vista.
drop policy if exists "feed: apaga quem enviou e o dono" on storage.objects;
create policy "feed: apaga quem enviou e o dono"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'feed-midia'
    and (
      (storage.foldername(name))[2] = auth.uid()::text
      or (storage.foldername(name))[1] = auth.uid()::text
    )
  );

-- A policy de insert do 0029 proibia o aluno de mexer em `midia_url`?
-- Não — ela nunca citou a coluna, então publicar com foto já era
-- permitido pelo banco. Faltava o caminho no app e o bucket. Nada a
-- alterar aqui.

-- ════════════════════════════════════════════════════════════
--  DESTAQUES: AS DUAS CATEGORIAS E O DESEMPATE
-- ════════════════════════════════════════════════════════════

create or replace function public.gerar_destaques(p_personal_id uuid, p_semana date default null)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_semana date;
  v_n      integer := 0;
  v_parcial integer;
begin
  v_semana := coalesce(p_semana,
    (date_trunc('week', current_date) - interval '1 week')::date);

  if not coalesce((select feed_ativo and destaques_ativos
                     from public.comunidade_config where personal_id = p_personal_id),
                  false) then
    return 0;
  end if;

  -- ════════════════════════════════════════════════════════
  --  CONSTÂNCIA NOS TREINOS
  --
  --  Percentual de treinos concluídos sobre os previstos na semana.
  --  Percentual e não quantidade: contar treinos absolutos premiaria
  --  quem tem mais tempo livre, não quem é consistente — e a
  --  especificação é explícita nisso.
  -- ════════════════════════════════════════════════════════
  with previstos as (
    -- Dias DISTINTOS com treino marcado, como no 0031: duas fichas no
    -- mesmo dia são um dia, não dois.
    select af.aluno_id, count(distinct d)::numeric as meta
      from public.aluno_fichas af
      join public.alunos a on a.id = af.aluno_id
     cross join lateral unnest(af.dias_semana) as d
     where a.personal_id = p_personal_id and af.ativa
     group by af.aluno_id
    having count(distinct d) > 0
  ),
  feitos as (
    select e.aluno_id,
           count(distinct (e.executado_em at time zone 'America/Sao_Paulo')::date)::numeric as fez
      from public.treino_execucoes e
     where e.personal_id = p_personal_id
       and (e.executado_em at time zone 'America/Sao_Paulo')::date
             between v_semana and v_semana + 6
     group by e.aluno_id
  ),
  adesao as (
    select p.aluno_id, least(1.0, coalesce(f.fez, 0) / p.meta) as pct
      from previstos p left join feitos f on f.aluno_id = p.aluno_id
  ),
  melhor as (select max(pct) as m from adesao where pct > 0),
  empatados as (
    select a.aluno_id from adesao a, melhor
     where melhor.m is not null and a.pct = melhor.m
  ),
  -- ── Desempate: quem vem de mais semanas seguidas de adesão
  --    integral. Só é calculado para os empatados, que são poucos.
  --
  --    A sequência olha para TRÁS a partir da semana de referência: é
  --    "vem de quantas semanas cumprindo", não "já teve uma boa fase
  --    em março".
  --    A conta é: ande para trás semana a semana e pare na primeira
  --    que não foi integral. O índice dessa semana É o tamanho da
  --    sequência — se a semana 0 já falhou, a sequência é zero. Sem
  --    nenhuma falha em um ano, 52.
  sequencias as (
    select e.aluno_id,
           coalesce((
             select min(j)
               from generate_series(0, 51) as j
              where (
                select coalesce(count(distinct
                         (x.executado_em at time zone 'America/Sao_Paulo')::date), 0)
                  from public.treino_execucoes x
                 where x.aluno_id = e.aluno_id
                   and (x.executado_em at time zone 'America/Sao_Paulo')::date
                         between v_semana - (j * 7) and v_semana - (j * 7) + 6
              ) < (select p.meta from previstos p where p.aluno_id = e.aluno_id)
           ), 52) as seq
      from empatados e
  ),
  campeoes as (
    select aluno_id from sequencias
     where seq = (select max(seq) from sequencias)
  )
  insert into public.feed_posts
    (personal_id, tipo, aluno_id, destaque_semana, destaque_tipo)
  select p_personal_id, 'destaque', c.aluno_id, v_semana, 'treino'
    from campeoes c
  on conflict (personal_id, destaque_semana, destaque_tipo)
    where destaque_semana is not null do nothing;

  get diagnostics v_n = row_count;

  -- ════════════════════════════════════════════════════════
  --  CONSISTÊNCIA NUTRICIONAL
  --
  --  Percentual de refeições registradas como concluídas sobre as
  --  planejadas na semana. O denominador é o plano ativo vezes sete —
  --  a programação individual vigente, como a especificação pede.
  -- ════════════════════════════════════════════════════════
  with previstos as (
    select a.id as aluno_id,
           (count(r.id) * 7)::numeric as meta
      from public.alunos a
      join public.planos_alimentares pl
        on pl.aluno_id = a.id and pl.ativo
      join public.plano_refeicoes r on r.plano_id = pl.id
     where a.personal_id = p_personal_id
     group by a.id
    having count(r.id) > 0
  ),
  feitos as (
    select rr.aluno_id, count(*)::numeric as fez
      from public.refeicoes_registro rr
      join public.alunos a on a.id = rr.aluno_id
     where a.personal_id = p_personal_id
       and rr.feita
       and rr.data between v_semana and v_semana + 6
     group by rr.aluno_id
  ),
  adesao as (
    select p.aluno_id, least(1.0, coalesce(f.fez, 0) / p.meta) as pct
      from previstos p left join feitos f on f.aluno_id = p.aluno_id
  ),
  melhor as (select max(pct) as m from adesao where pct > 0),
  empatados as (
    select a.aluno_id from adesao a, melhor
     where melhor.m is not null and a.pct = melhor.m
  ),
  -- Mesmo desempate, com a conta da nutrição: semanas seguidas em que
  -- TODAS as refeições planejadas foram registradas.
  sequencias as (
    select e.aluno_id,
           coalesce((
             select min(j)
               from generate_series(0, 51) as j
              where (
                select coalesce(count(*), 0)
                  from public.refeicoes_registro y
                 where y.aluno_id = e.aluno_id and y.feita
                   and y.data between v_semana - (j * 7)
                                  and v_semana - (j * 7) + 6
              ) < (select p.meta from previstos p where p.aluno_id = e.aluno_id)
           ), 52) as seq
      from empatados e
  ),
  campeoes as (
    select aluno_id from sequencias
     where seq = (select max(seq) from sequencias)
  )
  insert into public.feed_posts
    (personal_id, tipo, aluno_id, destaque_semana, destaque_tipo)
  select p_personal_id, 'destaque', c.aluno_id, v_semana, 'nutricao'
    from campeoes c
  on conflict (personal_id, destaque_semana, destaque_tipo)
    where destaque_semana is not null do nothing;

  get diagnostics v_parcial = row_count;

  return v_n + v_parcial;
end $$;

revoke all on function public.gerar_destaques(uuid, date) from public;
grant execute on function public.gerar_destaques(uuid, date) to authenticated;

notify pgrst, 'reload schema';

-- Conferência: o bucket, as policies de mídia e as duas categorias de
-- destaque dentro da função.
select
  (select count(*) from storage.buckets where id = 'feed-midia')          as bucket_1,
  (select count(*) from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and policyname like 'feed:%')                                       as policies_midia_3,
  (select position('''nutricao''' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'gerar_destaques')        as tem_nutricao,
  (select position('sequencias' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'gerar_destaques')        as tem_desempate;
