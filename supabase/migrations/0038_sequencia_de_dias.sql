-- ════════════════════════════════════════════════════════════
--  0038 — `date - bigint`: a conta que o Postgres não faz
--
--  A tela de conquistas da dieta não abria:
--
--    operator does not exist: date - bigint   (42883)
--
--  A CONTA
--
--  As sequências ("quantos dias seguidos") são calculadas pelo truque
--  clássico de ilhas: numere as linhas em ordem e agrupe pela diferença
--  entre o valor e o número da linha. Dias consecutivos dão sempre a
--  mesma diferença, e o tamanho de cada grupo é o tamanho da sequência.
--
--  O truque está certo. O tipo é que não.
--
--  `row_number()` devolve BIGINT. E o Postgres tem `date - integer`,
--  mas não tem `date - bigint`, e não converte bigint para integer
--  sozinho — essa conversão existe, mas só em atribuição, nunca na
--  escolha de um operador. Então a função inteira morria ao ser
--  planejada, antes de ler uma linha sequer.
--
--  Por que só apareceu agora: a função devolve TODAS as colunas de uma
--  vez, então o erro nunca foi da tela da dieta — era de qualquer
--  chamada. Ele vinha desde o 0027 e foi copiado adiante em cada
--  versão. Quem abriu a tela primeiro foi quem o encontrou.
--
--  O CONSERTO
--
--  `pos::integer`. Duas linhas.
--
--  As outras sequências não tinham o problema e ficam como estão: as
--  de semana e mês multiplicam `pos` por um `interval` (e `interval *
--  bigint` existe), e a de pesagem subtrai de um `bigint`.
--
--  Nada mais muda: mesmo nome, mesmas 22 colunas, mesma conta. É um
--  `create or replace`, então as permissões continuam de pé.
--
--  Depende do 0035. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create or replace function public.numeros_do_aluno(p_aluno_id uuid)
returns table (
  treinos              integer,
  dias_previstos       integer,
  semanas_completas    integer,
  sequencia_semanas    integer,
  sequencia_dias       integer,
  exercicios           integer,
  catalogo             integer,
  refeicoes_feitas     integer,
  dias_plano_completo  integer,
  pesagens             integer,
  fotos_diario         integer,
  sequencia_dias_plano integer,
  semanas_com_peso     integer,
  dias_agua_meta       integer,
  meses_acompanhamento integer,
  checkins             integer,
  checkins_seguidos    integer,
  dias_com_registro    integer,
  fotos_progresso      integer,
  meses_com_foto       integer,
  meses_foto_cumpridos integer,
  -- Nova no 0035.
  semanas_planejadas   integer
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_previstos integer;
  v_meta_agua integer;
  v_inicio    date;
  v_freq      integer;
  v_pede_foto boolean;
begin
  if not public.aluno_e_meu(p_aluno_id) then
    raise exception 'Sem permissão para este aluno' using errcode = '42501';
  end if;

  select coalesce(c.peso_frequencia_semanas, 1), coalesce(c.fotos_mensais, false)
    into v_freq, v_pede_foto
    from public.acompanhamento_config c
   where c.aluno_id = p_aluno_id;

  v_freq := coalesce(v_freq, 1);
  v_pede_foto := coalesce(v_pede_foto, false);

  select coalesce(count(distinct d), 0)
    into v_previstos
    from public.aluno_fichas af
   cross join lateral unnest(af.dias_semana) as d
   where af.aluno_id = p_aluno_id and af.ativa;

  select coalesce(p.agua_ml, 2000)::integer, p.data_inicio
    into v_meta_agua, v_inicio
    from public.planos_alimentares p
   where p.aluno_id = p_aluno_id and p.ativo
   limit 1;

  v_meta_agua := coalesce(v_meta_agua, 2000);

  return query
  with exec as (
    select date_trunc('week', e.executado_em at time zone 'America/Sao_Paulo')::date as semana,
           (e.executado_em at time zone 'America/Sao_Paulo')::date as dia
      from public.treino_execucoes e
     where e.aluno_id = p_aluno_id
  ),
  por_semana as (
    select semana, count(distinct dia) as dias from exec group by semana
  ),
  completas as (
    select semana from por_semana where v_previstos > 0 and dias >= v_previstos
  ),
  seq_semanas as (
    select count(*) as n from (
      select semana, (row_number() over (order by semana)) as pos from completas
    ) t group by semana - (pos * interval '1 week')
  ),
  dias_distintos as (select distinct dia from exec),
  seq_dias as (
    select count(*) as n from (
      select dia, (row_number() over (order by dia)) as pos from dias_distintos
    ) t group by dia - pos::integer
  ),
  plano as (
    select p.id from public.planos_alimentares p
     where p.aluno_id = p_aluno_id and p.ativo limit 1
  ),
  refeicoes_do_plano as (
    select count(*)::integer as total
      from public.plano_refeicoes r
     where r.plano_id = (select id from plano)
  ),
  dias_completos as (
    select rr.data as dia
      from public.refeicoes_registro rr
     where rr.aluno_id = p_aluno_id and rr.feita
     group by rr.data
    having (select total from refeicoes_do_plano) > 0
       and count(*) >= (select total from refeicoes_do_plano)
  ),
  dias_registrados as (
    select distinct rr.data as dia
      from public.refeicoes_registro rr
     where rr.aluno_id = p_aluno_id and rr.feita
    union
    select distinct dr.data
      from public.diario_registros dr
     where dr.aluno_id = p_aluno_id
  ),
  seq_plano as (
    select count(*) as n from (
      select dia, (row_number() over (order by dia)) as pos from dias_completos
    ) t group by dia - pos::integer
  ),
  periodos_peso as (
    select distinct
      floor((pr.data - date '1970-01-05') / (7 * v_freq))::bigint as balde
      from public.peso_registros pr
     where pr.aluno_id = p_aluno_id
  ),
  seq_peso as (
    select count(*) as n from (
      select balde, (row_number() over (order by balde)) as pos
        from periodos_peso
    ) t group by balde - pos
  ),
  agua_por_dia as (
    select ar.data, sum(ar.ml)::integer as total
      from public.agua_registros ar
     where ar.aluno_id = p_aluno_id
     group by ar.data
  ),
  meses_checkin as (
    select distinct ck.mes
      from public.nutricao_checkins ck
     where ck.aluno_id = p_aluno_id
       and ck.mes <= date_trunc('month', current_date)::date
  ),
  corridas as (
    select max(mes) as fim, count(*) as n
      from (
        select mes, (row_number() over (order by mes)) as pos from meses_checkin
      ) t
     group by mes - (pos * interval '1 month')
  ),
  meses_foto as (
    select distinct date_trunc('month',
             fp.registrado_em at time zone 'America/Sao_Paulo')::date as mes
      from public.fotos_progresso fp
     where fp.aluno_id = p_aluno_id
  )
  select
    (select count(*)::integer from exec),
    v_previstos,
    (select count(*)::integer from completas),
    coalesce((select max(n)::integer from seq_semanas), 0),
    coalesce((select max(n)::integer from seq_dias), 0),
    (select count(*)::integer
       from public.aluno_exercicios ae
       join public.exercicios ex on ex.id = ae.exercicio_id
      where ae.aluno_id = p_aluno_id and ex.oficial),
    (select count(*)::integer from public.exercicios where oficial),
    (select count(*)::integer from public.refeicoes_registro
      where aluno_id = p_aluno_id and feita),
    (select count(*)::integer from dias_completos),
    (select count(*)::integer from public.peso_registros where aluno_id = p_aluno_id),
    (select count(*)::integer from public.diario_registros
      where aluno_id = p_aluno_id and foto_path is not null),
    coalesce((select max(n)::integer from seq_plano), 0),
    coalesce((select max(n)::integer from seq_peso), 0),
    (select count(*)::integer from agua_por_dia where total >= v_meta_agua),
    case when v_inicio is null then 0
         else greatest(0, (extract(year from age(current_date, v_inicio)) * 12
                        +  extract(month from age(current_date, v_inicio)))::integer)
    end,
    (select count(*)::integer from meses_checkin),
    coalesce((select max(n)::integer from corridas
               where fim >= (date_trunc('month', current_date)
                             - interval '1 month')::date), 0),
    (select count(*)::integer from dias_registrados),
    (select count(*)::integer from public.fotos_progresso where aluno_id = p_aluno_id),
    (select count(*)::integer from meses_foto),
    case when v_pede_foto
         then (select count(*)::integer from meses_foto)
         else 0 end,
    (select count(*)::integer from public.planejamento_semana
      where aluno_id = p_aluno_id);
end $$;

revoke all on function public.numeros_do_aluno(uuid) from public;
grant execute on function public.numeros_do_aluno(uuid) to authenticated;

notify pgrst, 'reload schema';

-- Conferência: não sobrou nenhuma subtração sem conversão.
-- `conferido` deve vir 0.
select (length(prosrc) - length(replace(prosrc, 'dia - pos::integer', '')))
         / length('dia - pos::integer')                        as corrigidas_2,
       (length(prosrc) - length(replace(prosrc, 'dia - pos', '')))
         / length('dia - pos')
       - (length(prosrc) - length(replace(prosrc, 'dia - pos::integer', '')))
         / length('dia - pos::integer')                        as conferido
  from pg_proc p
  join pg_namespace ns on ns.oid = p.pronamespace
 where ns.nspname = 'public' and p.proname = 'numeros_do_aluno';
