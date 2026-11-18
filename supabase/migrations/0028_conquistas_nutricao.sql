-- ════════════════════════════════════════════════════════════
--  0028 — Conquistas de nutrição
--
--  Mesmo motor do 0027: o catálogo mora no app, o banco confere o
--  critério e grava o desbloqueio com a data.
--
--  `numeros_do_aluno` ganha quatro medidas que a nutrição precisa e o
--  treino não tinha: sequência de dias 100% no plano, semanas com
--  pesagem, dias que bateram a meta de água e meses de acompanhamento.
--
--  O QUE NÃO DEU PARA FAZER
--
--  A especificação cita "check-in nutricional mensal" em duas
--  conquistas — "Acompanhamento em dia" e "Compromisso renovado". Esse
--  recurso não existe no app: não há tabela, tela nem registro de
--  check-in. Elas ficaram de fora em vez de serem ligadas a outra coisa
--  parecida, o que daria medalha por algo que o aluno não fez.
--
--  RESOLVIDO NA 0030: ela cria o registro de check-in mensal e as três
--  conquistas. Esta migration continua como está — o que vale é a 0030,
--  que redefine `numeros_do_aluno` e `conceder_conquistas` por cima.
--
--  REGRAS QUE A ESPECIFICAÇÃO EXIGE E ESTÃO NO CÓDIGO
--
--  A conquista de peso conta REGULARIDADE do registro, nunca redução:
--  `semanas_com_peso` olha se houve registro na semana, e o valor do
--  peso não entra em conta nenhuma. A frequência é semanal — não existe
--  marco diário, para não empurrar o aluno à balança todo dia.
--
--  Depende do 0027, do 0014 e do 0010. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- `create or replace` não troca o tipo de retorno: as colunas de saída
-- fazem parte da assinatura, e o Postgres recusa com 42P13. Como o 0027
-- já criou a função com onze colunas e aqui ela passa a ter quinze, o
-- jeito é derrubar antes.
--
-- Derrubar é seguro: `conceder_conquistas` chama esta por nome, e corpo
-- de plpgsql só é resolvido na execução — ela volta a funcionar assim
-- que a nova existe, logo abaixo. Nenhum dado mora em função.
drop function if exists public.numeros_do_aluno(uuid);

create function public.numeros_do_aluno(p_aluno_id uuid)
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
  -- Novas no 0028.
  sequencia_dias_plano integer,
  semanas_com_peso     integer,
  dias_agua_meta       integer,
  meses_acompanhamento integer
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_previstos integer;
  v_meta_agua integer;
  v_inicio    date;
begin
  if not public.aluno_e_meu(p_aluno_id) then
    raise exception 'Sem permissão para este aluno' using errcode = '42501';
  end if;

  select coalesce(sum(array_length(af.dias_semana, 1)), 0)
    into v_previstos
    from public.aluno_fichas af
   where af.aluno_id = p_aluno_id and af.ativa;

  -- Meta de água do plano ativo. Sem plano, 2000 ml — a mesma regra que
  -- o app usa quando nem o peso se sabe.
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
    ) t group by dia - pos
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
  -- Dias seguidos 100% no plano. A especificação pede para distinguir
  -- acumulado de consecutivo, "para não penalizar o aluno por situações
  -- pontuais": o acumulado é `dias_plano_completo`, este é a sequência.
  seq_plano as (
    select count(*) as n from (
      select dia, (row_number() over (order by dia)) as pos from dias_completos
    ) t group by dia - pos
  ),
  -- Semanas em que houve pesagem. Conta a REGULARIDADE do registro,
  -- nunca o valor: o peso em si não entra em conta nenhuma aqui.
  semanas_peso as (
    select distinct date_trunc('week', pr.data)::date as semana
      from public.peso_registros pr
     where pr.aluno_id = p_aluno_id
  ),
  seq_peso as (
    select count(*) as n from (
      select semana, (row_number() over (order by semana)) as pos from semanas_peso
    ) t group by semana - (pos * interval '1 week')
  ),
  agua_por_dia as (
    select ar.data, sum(ar.ml)::integer as total
      from public.agua_registros ar
     where ar.aluno_id = p_aluno_id
     group by ar.data
  )
  select
    (select count(*)::integer from exec),
    v_previstos,
    (select count(*)::integer from completas),
    coalesce((select max(n)::integer from seq_semanas), 0),
    coalesce((select max(n)::integer from seq_dias), 0),
    (select count(*)::integer from public.aluno_exercicios where aluno_id = p_aluno_id),
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
    end;
end $$;

-- ════════════════════════════════════════════════════════════
--  CONCEDER — agora com nutrição
-- ════════════════════════════════════════════════════════════

-- Esta mantém a assinatura do 0027, mas vai pelo mesmo caminho: se um
-- dia as colunas de saída mudarem, o `replace` falharia do mesmo jeito.
drop function if exists public.conceder_conquistas(uuid);

create function public.conceder_conquistas(p_aluno_id uuid)
returns table (conquista text, atingiu integer)
language plpgsql security definer set search_path = public as $$
declare n record;
begin
  if not public.aluno_e_meu(p_aluno_id) then
    raise exception 'Sem permissão para este aluno' using errcode = '42501';
  end if;

  perform public.desbloquear_exercicios(p_aluno_id);
  select * into n from public.numeros_do_aluno(p_aluno_id);

  return query
  with marcos(cod, atingido, v) as (
    values
      -- ── Treino ─────────────────────────────────────────────
      ('treinos_1',    n.treinos >=   1, n.treinos),
      ('treinos_10',   n.treinos >=  10, n.treinos),
      ('treinos_25',   n.treinos >=  25, n.treinos),
      ('treinos_50',   n.treinos >=  50, n.treinos),
      ('treinos_100',  n.treinos >= 100, n.treinos),
      ('treinos_250',  n.treinos >= 250, n.treinos),
      ('treinos_500',  n.treinos >= 500, n.treinos),
      ('semanas_1',    n.sequencia_semanas >=  1, n.sequencia_semanas),
      ('semanas_2',    n.sequencia_semanas >=  2, n.sequencia_semanas),
      ('semanas_4',    n.sequencia_semanas >=  4, n.sequencia_semanas),
      ('semanas_8',    n.sequencia_semanas >=  8, n.sequencia_semanas),
      ('semanas_12',   n.sequencia_semanas >= 12, n.sequencia_semanas),
      ('semanas_26',   n.sequencia_semanas >= 26, n.sequencia_semanas),

      -- ── Nutrição: dias no plano ────────────────────────────
      -- Acumulado, não consecutivo: a especificação pede para não
      -- penalizar o aluno por uma falha pontual.
      ('plano_1',      n.dias_plano_completo >=  1, n.dias_plano_completo),
      ('plano_7',      n.dias_plano_completo >=  7, n.dias_plano_completo),
      ('plano_15',     n.dias_plano_completo >= 15, n.dias_plano_completo),
      ('plano_30',     n.dias_plano_completo >= 30, n.dias_plano_completo),
      ('plano_60',     n.dias_plano_completo >= 60, n.dias_plano_completo),

      -- Semana consistente: sete dias seguidos no plano.
      ('plano_semana', n.sequencia_dias_plano >= 7, n.sequencia_dias_plano),

      -- ── Nutrição: acompanhamento ───────────────────────────
      -- Regularidade do registro de peso, NUNCA redução. Não existe
      -- marco diário de propósito: a frequência é semanal, e empurrar
      -- para a balança todo dia é o oposto do que o documento pede.
      ('peso_1',       n.pesagens >= 1,            n.pesagens),
      ('peso_4',       n.semanas_com_peso >=  4,   n.semanas_com_peso),
      ('peso_12',      n.semanas_com_peso >= 12,   n.semanas_com_peso),

      ('fotos_1',      n.fotos_diario >= 1, n.fotos_diario),
      ('fotos_3',      n.fotos_diario >= 3, n.fotos_diario),

      ('agua_1',       n.dias_agua_meta >=  1, n.dias_agua_meta),
      ('agua_7',       n.dias_agua_meta >=  7, n.dias_agua_meta),
      ('agua_30',      n.dias_agua_meta >= 30, n.dias_agua_meta),

      ('meses_3',      n.meses_acompanhamento >= 3, n.meses_acompanhamento),
      ('meses_6',      n.meses_acompanhamento >= 6, n.meses_acompanhamento)
  )
  insert into public.aluno_conquistas (aluno_id, codigo, valor)
  select p_aluno_id, cod, v from marcos where atingido
  on conflict (aluno_id, codigo) do nothing
  returning aluno_conquistas.codigo, aluno_conquistas.valor;
exception
  when no_data_found then
    return;
end $$;

revoke all on function public.numeros_do_aluno(uuid)    from public;
revoke all on function public.conceder_conquistas(uuid) from public;
grant execute on function public.numeros_do_aluno(uuid)    to authenticated;
grant execute on function public.conceder_conquistas(uuid) to authenticated;

notify pgrst, 'reload schema';

-- Conferência: as duas funções foram substituídas e já devolvem as
-- colunas novas.
select
  (select count(*) from information_schema.columns
    where table_schema = 'public'
      and table_name = 'numeros_do_aluno')                          as colunas_da_funcao,
  (select position('sequencia_dias_plano' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'numeros_do_aluno') as tem_nutricao,
  (select position('plano_60' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'conceder_conquistas') as concede_nutricao;
