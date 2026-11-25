-- ════════════════════════════════════════════════════════════
--  0034 — Gamificação nutricional: o que a especificação pede
--
--  Reli a especificação contra o que está no app. Seis desvios, e um
--  deles mede a coisa errada.
--
--  1. AS CONQUISTAS DE FOTO CONTAVAM O DIÁRIO DE REFEIÇÃO
--
--  "Fotografia da evolução: completar três registros fotográficos
--  MENSAIS" e "Aluno disciplinado: anexar as fotos de acompanhamento
--  mensal" falam de `fotos_progresso` — a foto do corpo, de mês em mês.
--  Estavam contando `diario_registros.foto_path`, que é a foto do prato.
--  Um aluno que fotografa o almoço todo dia ganhava a medalha de
--  evolução sem nunca ter tirado uma foto de acompanhamento.
--
--  2. "30 DIAS DE DEDICAÇÃO" NÃO EXISTIA
--
--  A especificação é explícita: "reconhecer a participação consistente,
--  NÃO exigir perfeição alimentar". O marco `plano_30` exige trinta
--  dias com TODAS as refeições fechadas — é o oposto. Agora há uma
--  conquista separada que conta dias com registro, perfeitos ou não.
--
--  3. "ALUNO DISCIPLINADO" NÃO EXISTIA
--
--  O evento que a libera, na tabela da especificação, é "fotos mensais
--  SOLICITADAS são anexadas". Faltavam as duas pontas: o pedido do
--  profissional e a conferência. As duas entram aqui.
--
--  4. A FREQUÊNCIA DE PESAGEM ERA FIXA
--
--  "A frequência de pesagem deve ser semanal e CONFIGURADA PELO
--  PROFISSIONAL." Era semanal e cravada no código. Agora é dele, de uma
--  a quatro semanas, com uma semana de padrão.
--
--  5. O PROFISSIONAL NÃO CONFIGURAVA NADA
--
--  "O profissional deve poder configurar ou ajustar metas, frequência e
--  solicitações de check-in conforme o plano individual." Nasce a
--  `acompanhamento_config`.
--
--  6. "MESTRE DA ORGANIZAÇÃO" ESTAVA NO LUGAR ERRADO — ver o 0030.
--     A especificação a define como "registrar o planejamento alimentar
--     da semana, QUANDO ESSE RECURSO ESTIVER DISPONÍVEL". O recurso não
--     existe, e eu a tinha pendurado na sequência de check-ins. O nome
--     sai de lá (no catálogo do app); a conquista fica esperando o
--     recurso, como o próprio documento prevê.
--
--  Depende do 0030. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- O acompanhamento individual, decidido pelo profissional.
--
-- Sem linha, valem os padrões: pesagem semanal, check-in mensal ligado,
-- fotos mensais não solicitadas. São os padrões que o app já praticava,
-- para nenhum aluno existente mudar de comportamento ao rodar isto.
create table if not exists public.acompanhamento_config (
  aluno_id uuid primary key references public.alunos(id) on delete cascade,

  -- De 1 a 4 semanas. Não existe opção diária de propósito: a
  -- especificação proíbe — "não solicitar nem incentivar pesagens
  -- diárias" — e o jeito de uma proibição durar é não ter a opção.
  peso_frequencia_semanas smallint not null default 1
    check (peso_frequencia_semanas between 1 and 4),

  -- O profissional pede as fotos de acompanhamento do mês. É o que
  -- destrava "Aluno disciplinado": sem pedido, não há o que cumprir.
  fotos_mensais  boolean not null default false,

  checkin_mensal boolean not null default true,

  atualizado_em  timestamptz not null default now()
);

alter table public.acompanhamento_config enable row level security;

drop policy if exists "acompanhamento: quem acompanha lê" on public.acompanhamento_config;
create policy "acompanhamento: quem acompanha lê"
  on public.acompanhamento_config for select to authenticated
  using (public.aluno_e_meu(aluno_id));

-- Escreve o profissional dono do aluno, e só ele.
--
-- O aluno não entra: ajustar a própria frequência de pesagem é decidir
-- o próprio critério de conquista. E `aluno_e_meu` não serve aqui
-- justamente porque INCLUI o aluno — serve para ler, não para escrever.
--
-- A equipe também fica de fora por enquanto. O alcance dela deriva do
-- plano contratado (0025) e isso não cabe numa policy sem repetir a
-- regra inteira; numa policy de ESCRITA, errar para o lado restrito é
-- o certo. Quando o nutricionista convidado precisar disto, entra numa
-- migration própria, com o alcance conferido do mesmo jeito que o
-- `aluno_e_meu` confere.
drop policy if exists "acompanhamento: o profissional decide" on public.acompanhamento_config;
create policy "acompanhamento: o profissional decide"
  on public.acompanhamento_config for all to authenticated
  using (
    exists (select 1 from public.alunos a
             where a.id = acompanhamento_config.aluno_id
               and a.personal_id = auth.uid())
  )
  with check (
    exists (select 1 from public.alunos a
             where a.id = acompanhamento_config.aluno_id
               and a.personal_id = auth.uid())
  );

grant select, insert, update on public.acompanhamento_config to authenticated;

-- ════════════════════════════════════════════════════════════
--  NÚMEROS
-- ════════════════════════════════════════════════════════════

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
  checkins             integer,
  checkins_seguidos    integer,
  -- Novas no 0034.
  dias_com_registro    integer,
  fotos_progresso      integer,
  meses_com_foto       integer,
  meses_foto_cumpridos integer
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

  -- Sem linha de configuração valem os padrões antigos, para ninguém
  -- perder conquista ao rodar esta migration.
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
  -- Dias em que o aluno registrou ALGUMA coisa — perfeitos ou não.
  --
  -- É o número de "30 dias de dedicação". A especificação pede para
  -- reconhecer "a participação consistente, não exigir perfeição
  -- alimentar", e `dias_plano_completo` exige exatamente perfeição.
  -- São conquistas diferentes, e agora têm números diferentes.
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
    ) t group by dia - pos
  ),
  -- Períodos de pesagem, do tamanho que o profissional escolheu.
  --
  -- Com `v_freq = 1` isto é a semana de sempre; com 2, quinzena. O
  -- balde sai da divisão inteira dos dias desde a época, e não de
  -- `date_trunc`, porque `date_trunc` só conhece semana, mês e ano.
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
  -- Meses com foto de ACOMPANHAMENTO — `fotos_progresso`, a foto do
  -- corpo. Não é `diario_registros.foto_path`, que é a foto do prato.
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
    -- Só conta se o profissional PEDIU. "Aluno disciplinado" é sobre
    -- atender a um pedido; sem pedido, não há o que atender, e a
    -- medalha não faria sentido nenhum.
    case when v_pede_foto
         then (select count(*)::integer from meses_foto)
         else 0 end;
end $$;

-- ════════════════════════════════════════════════════════════
--  CONCEDER
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

      -- ── Dia 100% no plano: 1, 7, 15, 30, 60 (§6) ───────────
      ('plano_1',      n.dias_plano_completo >=  1, n.dias_plano_completo),
      ('plano_7',      n.dias_plano_completo >=  7, n.dias_plano_completo),
      ('plano_15',     n.dias_plano_completo >= 15, n.dias_plano_completo),
      ('plano_30',     n.dias_plano_completo >= 30, n.dias_plano_completo),
      ('plano_60',     n.dias_plano_completo >= 60, n.dias_plano_completo),
      ('plano_semana', n.sequencia_dias_plano >= 7, n.sequencia_dias_plano),

      -- ── 30 dias de dedicação (§2) ──────────────────────────
      -- Participação, não perfeição: conta dias com registro.
      ('dedicacao_30', n.dias_com_registro >= 30, n.dias_com_registro),

      -- ── Peso: regularidade, nunca redução (§3, §7) ─────────
      ('peso_1',       n.pesagens >= 1,            n.pesagens),
      ('peso_4',       n.semanas_com_peso >=  4,   n.semanas_com_peso),
      ('peso_12',      n.semanas_com_peso >= 12,   n.semanas_com_peso),

      -- ── Fotos de acompanhamento (§3, §4) ───────────────────
      ('fotos_1',      n.fotos_progresso >= 1,      n.fotos_progresso),
      ('fotos_3',      n.meses_com_foto >= 3,       n.meses_com_foto),
      ('disciplinado', n.meses_foto_cumpridos >= 1, n.meses_foto_cumpridos),

      ('agua_1',       n.dias_agua_meta >=  1, n.dias_agua_meta),
      ('agua_7',       n.dias_agua_meta >=  7, n.dias_agua_meta),
      ('agua_30',      n.dias_agua_meta >= 30, n.dias_agua_meta),

      ('meses_3',      n.meses_acompanhamento >= 3, n.meses_acompanhamento),
      ('meses_6',      n.meses_acompanhamento >= 6, n.meses_acompanhamento),

      -- ── Check-in mensal ───────────────────────────────────
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

-- Conferência: a tabela de configuração, as vinte e uma colunas e os
-- dois marcos novos.
select
  (select count(*) from information_schema.tables
    where table_schema = 'public' and table_name = 'acompanhamento_config') as tabela_1,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'numeros_do_aluno')      as colunas_21,
  (select position('dias_com_registro' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'numeros_do_aluno')         as numeros_ok,
  (select position('disciplinado' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'conceder_conquistas')      as concede_ok,
  (select position('fotos_progresso' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'conceder_conquistas')      as foto_certa;
