-- ════════════════════════════════════════════════════════════
--  0031 — Desbloqueio na prescrição e dois acertos de conta
--
--  Três correções contra a especificação de gamificação.
--
--  1. O DESBLOQUEIO AGORA ACONTECE NO ENVIO DA PRESCRIÇÃO
--
--  O documento diz: "ao enviar uma prescrição, o sistema deve liberar
--  esse exercício na biblioteca pessoal do aluno". Não era o que
--  acontecia. `desbloquear_exercicios` só rodava dentro de
--  `conceder_conquistas`, que é chamada pelo app DO ALUNO — ao concluir
--  um treino ou ao abrir Recordes. A tela de Desbloqueios só lia.
--
--  Resultado: o professor prescrevia, o aluno abria a biblioteca no
--  mesmo minuto e não via nada. O exercício aparecia dias depois, na
--  primeira vez que ele concluísse um treino. O gatilho que motiva a
--  descoberta chegava depois da descoberta.
--
--  Agora dois gatilhos cuidam disso no banco, onde o fato acontece:
--  atribuir uma ficha a um aluno, e acrescentar um exercício a uma
--  ficha já atribuída. Fica independente do app — qualquer caminho que
--  prescreva (tela, importação, script) desbloqueia.
--
--  2. NUMERADOR E DENOMINADOR SÃO O MESMO CATÁLOGO
--
--  A barra contava, em cima, TODOS os exercícios desbloqueados — os
--  oficiais e os que o professor criou — e embaixo só os oficiais. Um
--  aluno com muito exercício personalizado via "40 de 32 exercícios" e
--  um percentual grudado em 100%. O numerador passa a contar só os
--  oficiais, que é o catálogo que a especificação manda usar de base.
--
--  A biblioteca continua listando tudo: o exercício personalizado é
--  dele e tem de aparecer. O que ele não faz é entrar numa conta cuja
--  base é outra.
--
--  3. SEMANA COMPLETA CONTA DIAS, NÃO LINHAS DE FICHA
--
--  `dias_previstos` somava `array_length(dias_semana)` ficha a ficha.
--  Com duas fichas ativas no mesmo dia da semana, o previsto virava 2
--  onde só existe 1 dia, a execução contava dias distintos, e a semana
--  jamais fechava — travando TODOS os selos de consistência desse
--  aluno. Agora conta os dias distintos da união.
--
--  Nenhuma conquista já concedida é mexida: `aluno_conquistas` não é
--  tocada aqui, e a data de quem já tem continua a que foi.
--
--  Depende do 0030. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- As colunas de saída fazem parte da assinatura: `create or replace`
-- recusaria com 42P13 se um dia elas mudarem. Mantenho o padrão do
-- 0028 e do 0030 — derrubar e criar. `conceder_conquistas` chama esta
-- por nome e resolve na execução; nenhum dado mora em função.
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
  sequencia_dias_plano integer,
  semanas_com_peso     integer,
  dias_agua_meta       integer,
  meses_acompanhamento integer,
  -- Novas no 0030.
  checkins             integer,
  checkins_seguidos    integer
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

  -- Dias DISTINTOS da semana que a programação vigente pede.
  --
  -- Era `sum(array_length(...))`, somando ficha a ficha. Num ABC em que
  -- duas fichas ativas caem na mesma segunda, o previsto dava 2 para um
  -- dia só; a execução conta dias distintos, dava 1, e a semana nunca
  -- fechava — travando todos os selos de consistência de quem tem duas
  -- fichas no mesmo dia. A união resolve: o que importa é em quantos
  -- DIAS ele tem treino marcado.
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
  seq_plano as (
    select count(*) as n from (
      select dia, (row_number() over (order by dia)) as pos from dias_completos
    ) t group by dia - pos
  ),
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
  ),
  -- ── Check-in mensal ──────────────────────────────────────
  meses_checkin as (
    select distinct ck.mes
      from public.nutricao_checkins ck
     where ck.aluno_id = p_aluno_id
       and ck.mes <= date_trunc('month', current_date)::date
  ),
  -- Cada corrida de meses consecutivos vira uma linha, com o último mês
  -- dela. Só interessa a corrida VIVA: a que termina neste mês ou no
  -- anterior.
  corridas as (
    select max(mes) as fim, count(*) as n
      from (
        select mes, (row_number() over (order by mes)) as pos from meses_checkin
      ) t
     group by mes - (pos * interval '1 month')
  )
  select
    (select count(*)::integer from exec),
    v_previstos,
    (select count(*)::integer from completas),
    coalesce((select max(n)::integer from seq_semanas), 0),
    coalesce((select max(n)::integer from seq_dias), 0),
    -- Só os OFICIAIS. O denominador logo abaixo conta `where oficial`;
    -- contar aqui também os exercícios que o professor criou punha
    -- numerador e denominador em catálogos diferentes, e um aluno com
    -- muito exercício personalizado via "40 de 32".
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
                             - interval '1 month')::date), 0);
end $$;

-- ════════════════════════════════════════════════════════════
--  DESBLOQUEIO NO ATO DA PRESCRIÇÃO
-- ════════════════════════════════════════════════════════════

-- Acrescenta ao repertório do aluno os exercícios de uma ficha.
--
-- `security definer` porque quem dispara é o PROFESSOR, e ele não
-- escreve em `aluno_exercicios` — a tabela não tem política de insert
-- para ninguém, de propósito: ela só muda por função que confere o
-- motivo. Aqui o motivo é o próprio gatilho; a linha da prescrição já
-- passou pelas políticas de `aluno_fichas` e `ficha_exercicios`.
--
-- Só acrescenta, nunca remove: tirar a ficha não tira o exercício. É
-- o que a especificação pede e o que faz a biblioteca ser do aluno e
-- não da prescrição.
create or replace function public.desbloquear_da_ficha(
  p_aluno_id uuid,
  p_ficha_id uuid
)
returns void
language sql security definer set search_path = public as $$
  insert into public.aluno_exercicios (aluno_id, exercicio_id)
  select distinct p_aluno_id, fe.exercicio_id
    from public.ficha_exercicios fe
   where fe.ficha_id = p_ficha_id
  on conflict (aluno_id, exercicio_id) do nothing;
$$;

-- Ficha atribuída ao aluno: libera o que ela já tem dentro.
create or replace function public.tg_desbloquear_ficha_do_aluno()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform public.desbloquear_da_ficha(new.aluno_id, new.ficha_id);
  return new;
end $$;

drop trigger if exists desbloquear_ao_atribuir_ficha on public.aluno_fichas;
create trigger desbloquear_ao_atribuir_ficha
  after insert on public.aluno_fichas
  for each row execute function public.tg_desbloquear_ficha_do_aluno();

-- Exercício acrescentado a uma ficha que JÁ está com alunos: libera
-- para cada um deles. Sem isto, trocar um exercício da ficha de um
-- aluno que já a tinha não desbloquearia nada — e é o caminho mais
-- comum de todos, o professor ajustando o treino de quem já é aluno.
create or replace function public.tg_desbloquear_exercicio_novo()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.aluno_exercicios (aluno_id, exercicio_id)
  select af.aluno_id, new.exercicio_id
    from public.aluno_fichas af
   where af.ficha_id = new.ficha_id
  on conflict (aluno_id, exercicio_id) do nothing;
  return new;
end $$;

drop trigger if exists desbloquear_ao_incluir_exercicio on public.ficha_exercicios;
create trigger desbloquear_ao_incluir_exercicio
  after insert on public.ficha_exercicios
  for each row execute function public.tg_desbloquear_exercicio_novo();

-- Quem já era aluno antes destes gatilhos. Idempotente: o `on conflict`
-- não duplica nem reescreve a data de quem já tinha o exercício.
insert into public.aluno_exercicios (aluno_id, exercicio_id)
select distinct af.aluno_id, fe.exercicio_id
  from public.aluno_fichas af
  join public.ficha_exercicios fe on fe.ficha_id = af.ficha_id
on conflict (aluno_id, exercicio_id) do nothing;

revoke all on function public.numeros_do_aluno(uuid)          from public;
revoke all on function public.desbloquear_da_ficha(uuid, uuid) from public;
grant execute on function public.numeros_do_aluno(uuid) to authenticated;

notify pgrst, 'reload schema';

-- Conferência: a função voltou com as dezessete colunas, os dois
-- gatilhos existem, e a conta do numerador agora filtra `oficial`.
select
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'numeros_do_aluno')   as colunas_17,
  (select count(*) from pg_trigger
    where not tgisinternal
      and tgname in ('desbloquear_ao_atribuir_ficha',
                     'desbloquear_ao_incluir_exercicio'))               as gatilhos_2,
  (select position('ex.oficial' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'numeros_do_aluno')      as numerador_oficial,
  (select position('count(distinct d)' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'numeros_do_aluno')      as previstos_distintos,
  (select count(*) from public.aluno_exercicios)                         as desbloqueios_totais;
