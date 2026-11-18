-- ════════════════════════════════════════════════════════════
--  0030 — Check-in nutricional mensal
--
--  O recurso que faltava. A especificação de gamificação nutricional
--  citava "check-in mensal" em três conquistas, e o 0028 as deixou de
--  fora porque não havia onde registrar — nem tabela, nem tela. Esta
--  migration cria o registro; as conquistas entram no mesmo movimento.
--
--  O QUE É UM CHECK-IN
--
--  Uma vez por mês o ALUNO conta como foi: o quanto conseguiu seguir o
--  plano, o que dificultou, como está a disposição, e o que quiser
--  escrever. É autorrelato — quem preenche é o aluno, nunca o
--  profissional. Por isso a escrita é só dele, e `aluno_e_meu` aqui
--  serve apenas para a LEITURA (o nutricionista e a equipe com escopo
--  de nutrição precisam ver).
--
--  UM POR MÊS, E O MÊS É O CALENDÁRIO
--
--  A chave única é (aluno_id, mes), com `mes` sempre no dia 1. Mês
--  civil, não "30 dias desde o último": com janela corrida, quem
--  responde dia 28 e dia 2 teria feito dois check-ins em cinco dias, e
--  "está em dia" perderia sentido.
--
--  A SEQUÊNCIA PERDOA O MÊS CORRENTE
--
--  `checkins_seguidos` conta a corrida que termina neste mês OU no
--  anterior. Quem respondeu em outubro e ainda não respondeu em
--  novembro não perdeu a sequência — novembro não acabou. Sem isso, a
--  medalha de constância quebraria no dia 1 de cada mês.
--
--  Depende do 0001 e do 0028. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create table if not exists public.nutricao_checkins (
  id         uuid primary key default gen_random_uuid(),
  aluno_id   uuid not null references public.alunos(id) on delete cascade,

  -- Sempre o dia 1 do mês de referência.
  mes        date not null check (mes = date_trunc('month', mes)::date),

  -- 1 a 5: o quanto conseguiu seguir o plano, e como está a disposição.
  -- Escala, não nota: o texto de cada degrau mora no app.
  adesao     smallint not null check (adesao between 1 and 5),
  energia    smallint check (energia is null or energia between 1 and 5),

  -- O que dificultou. Lista de códigos; os rótulos moram no catálogo do
  -- app, pelo mesmo motivo das conquistas — texto em banco envelhece
  -- sem migration.
  dificuldades text[] not null default '{}',

  -- Digestão. Opcional de propósito: é a pergunta mais invasiva do
  -- formulário, e obrigar a responder é a melhor forma de fazer o aluno
  -- abandonar o check-in.
  intestino  text check (intestino is null or intestino in
               ('bem', 'inchaco', 'constipacao', 'solto')),

  observacoes text check (observacoes is null or length(btrim(observacoes)) <= 2000),

  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  unique (aluno_id, mes)
);

create index if not exists nutricao_checkins_idx
  on public.nutricao_checkins (aluno_id, mes desc);

-- ════════════════════════════════════════════════════════════
--  RLS
-- ════════════════════════════════════════════════════════════

alter table public.nutricao_checkins enable row level security;

-- Lê quem acompanha o aluno — ele mesmo, o personal, e a equipe com
-- escopo de nutrição (é o que `aluno_e_meu` já resolve desde o 0025).
drop policy if exists "check-in: quem acompanha lê" on public.nutricao_checkins;
create policy "check-in: quem acompanha lê"
  on public.nutricao_checkins for select to authenticated
  using (public.aluno_e_meu(aluno_id));

-- Escreve só o aluno. O profissional não responde no lugar dele: um
-- autorrelato preenchido por outra pessoa não é autorrelato, e a
-- conquista viraria medalha por algo que o aluno não fez.
drop policy if exists "check-in: só o aluno responde" on public.nutricao_checkins;
create policy "check-in: só o aluno responde"
  on public.nutricao_checkins for insert to authenticated
  with check (
    exists (select 1 from public.alunos a
             where a.id = nutricao_checkins.aluno_id and a.user_id = auth.uid())
    -- Não dá para responder mês que não chegou.
    and mes <= date_trunc('month', current_date)::date
  );

-- Corrigir, mas só o do mês corrente. Reescrever o de março em
-- novembro não é correção, é reconstrução de memória — e o
-- profissional já leu o original.
drop policy if exists "check-in: o aluno corrige o do mês" on public.nutricao_checkins;
create policy "check-in: o aluno corrige o do mês"
  on public.nutricao_checkins for update to authenticated
  using (
    mes = date_trunc('month', current_date)::date
    and exists (select 1 from public.alunos a
                 where a.id = nutricao_checkins.aluno_id and a.user_id = auth.uid())
  )
  with check (
    mes = date_trunc('month', current_date)::date
    and exists (select 1 from public.alunos a
                 where a.id = nutricao_checkins.aluno_id and a.user_id = auth.uid())
  );

-- Sem política de DELETE: ninguém apaga check-in. O histórico é o
-- produto aqui — uma série que pode ser editada para trás não serve
-- para acompanhar ninguém.

grant select, insert, update on public.nutricao_checkins to authenticated;

-- ════════════════════════════════════════════════════════════
--  NÚMEROS — agora com check-in
-- ════════════════════════════════════════════════════════════

-- Mesmo motivo do 0028: as colunas de saída fazem parte da assinatura,
-- e `create or replace` recusaria com 42P13. Derrubar é seguro —
-- `conceder_conquistas` resolve o nome na execução.
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

  select coalesce(sum(array_length(af.dias_semana, 1)), 0)
    into v_previstos
    from public.aluno_fichas af
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
    end,
    (select count(*)::integer from meses_checkin),
    coalesce((select max(n)::integer from corridas
               where fim >= (date_trunc('month', current_date)
                             - interval '1 month')::date), 0);
end $$;

-- ════════════════════════════════════════════════════════════
--  CONCEDER — as três conquistas que faltavam
-- ════════════════════════════════════════════════════════════

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
      ('plano_1',      n.dias_plano_completo >=  1, n.dias_plano_completo),
      ('plano_7',      n.dias_plano_completo >=  7, n.dias_plano_completo),
      ('plano_15',     n.dias_plano_completo >= 15, n.dias_plano_completo),
      ('plano_30',     n.dias_plano_completo >= 30, n.dias_plano_completo),
      ('plano_60',     n.dias_plano_completo >= 60, n.dias_plano_completo),
      ('plano_semana', n.sequencia_dias_plano >= 7, n.sequencia_dias_plano),

      -- ── Nutrição: acompanhamento ───────────────────────────
      ('peso_1',       n.pesagens >= 1,            n.pesagens),
      ('peso_4',       n.semanas_com_peso >=  4,   n.semanas_com_peso),
      ('peso_12',      n.semanas_com_peso >= 12,   n.semanas_com_peso),

      ('fotos_1',      n.fotos_diario >= 1, n.fotos_diario),
      ('fotos_3',      n.fotos_diario >= 3, n.fotos_diario),

      ('agua_1',       n.dias_agua_meta >=  1, n.dias_agua_meta),
      ('agua_7',       n.dias_agua_meta >=  7, n.dias_agua_meta),
      ('agua_30',      n.dias_agua_meta >= 30, n.dias_agua_meta),

      ('meses_3',      n.meses_acompanhamento >= 3, n.meses_acompanhamento),
      ('meses_6',      n.meses_acompanhamento >= 6, n.meses_acompanhamento),

      -- ── Check-in mensal (novas no 0030) ───────────────────
      -- A primeira conta o acumulado: fez o check-in, está em dia.
      -- As outras duas contam SEQUÊNCIA, que é o que a especificação
      -- pede por organização e compromisso — três e seis meses sem
      -- faltar.
      ('checkin_1',    n.checkins >= 1,          n.checkins),
      ('checkin_3',    n.checkins_seguidos >= 3, n.checkins_seguidos),
      ('checkin_6',    n.checkins_seguidos >= 6, n.checkins_seguidos)
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

-- Conferência: a tabela, as dezessete colunas da função e os três
-- marcos novos.
select
  (select count(*) from information_schema.tables
    where table_schema = 'public' and table_name = 'nutricao_checkins') as tabela_1,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'numeros_do_aluno')  as colunas_17,
  (select position('checkins_seguidos' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'numeros_do_aluno')     as numeros_ok,
  (select position('checkin_6' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'conceder_conquistas')  as concede_ok,
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'nutricao_checkins')    as policies_3;
