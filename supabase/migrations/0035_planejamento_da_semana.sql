-- ════════════════════════════════════════════════════════════
--  0035 — Planejamento alimentar da semana
--
--  A última pendência do documento de gamificação nutricional.
--
--  "Mestre da organização: registrar o planejamento alimentar da
--  semana, QUANDO ESSE RECURSO ESTIVER DISPONÍVEL." O recurso não
--  existia, e por isso a conquista ficou de fora no 0034. Esta
--  migration cria o recurso; a conquista entra junto.
--
--  O QUE É "PLANEJAR A SEMANA"
--
--  O aluno confirma que organizou a semana: olhou o plano, viu o que
--  falta comprar, separou o que precisa preparar. É um ato de
--  organização, não de alimentação — e por isso ele marca, ninguém
--  mede por ele.
--
--  POR QUE A SEMANA É A DE SEGUNDA
--
--  `date_trunc('week')` no Postgres começa na segunda, e é a mesma
--  semana que a `numeros_do_aluno` usa para treino e para peso. Duas
--  definições de semana no mesmo app seria a origem de "a conquista diz
--  4 semanas e a tela diz 5".
--
--  SÓ A SEMANA ATUAL E A QUE VEM
--
--  Planejar é olhar para a frente. Deixar marcar março em novembro
--  transformaria a conquista em botão de apertar sete vezes, e o
--  critério de organização perderia qualquer relação com organizar-se.
--
--  Depende do 0034. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create table if not exists public.planejamento_semana (
  aluno_id   uuid not null references public.alunos(id) on delete cascade,

  -- Sempre a segunda-feira da semana planejada.
  semana     date not null check (semana = date_trunc('week', semana)::date),

  -- O que ele anotou ao planejar, se quis anotar. Opcional: a conquista
  -- é por organizar, não por escrever.
  observacoes text check (observacoes is null or length(btrim(observacoes)) <= 1000),

  criado_em  timestamptz not null default now(),

  primary key (aluno_id, semana)
);

create index if not exists planejamento_semana_idx
  on public.planejamento_semana (aluno_id, semana desc);

alter table public.planejamento_semana enable row level security;

drop policy if exists "planejamento: quem acompanha lê" on public.planejamento_semana;
create policy "planejamento: quem acompanha lê"
  on public.planejamento_semana for select to authenticated
  using (public.aluno_e_meu(aluno_id));

-- Escreve o aluno, e só ele. Planejamento marcado pelo profissional não
-- é planejamento do aluno — seria o profissional dando a si mesmo a
-- medalha de organização de outra pessoa.
drop policy if exists "planejamento: o aluno marca" on public.planejamento_semana;
create policy "planejamento: o aluno marca"
  on public.planejamento_semana for insert to authenticated
  with check (
    exists (select 1 from public.alunos a
             where a.id = planejamento_semana.aluno_id
               and a.user_id = auth.uid())
    -- A semana atual ou a próxima. Planejar é olhar para a frente.
    and semana between date_trunc('week', current_date)::date
                   and (date_trunc('week', current_date) + interval '1 week')::date
  );

-- Desmarcar o que marcou por engano, enquanto a semana não passou.
drop policy if exists "planejamento: o aluno desmarca a semana aberta" on public.planejamento_semana;
create policy "planejamento: o aluno desmarca a semana aberta"
  on public.planejamento_semana for delete to authenticated
  using (
    exists (select 1 from public.alunos a
             where a.id = planejamento_semana.aluno_id
               and a.user_id = auth.uid())
    and semana >= date_trunc('week', current_date)::date
  );

grant select, insert, delete on public.planejamento_semana to authenticated;

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

      ('plano_1',      n.dias_plano_completo >=  1, n.dias_plano_completo),
      ('plano_7',      n.dias_plano_completo >=  7, n.dias_plano_completo),
      ('plano_15',     n.dias_plano_completo >= 15, n.dias_plano_completo),
      ('plano_30',     n.dias_plano_completo >= 30, n.dias_plano_completo),
      ('plano_60',     n.dias_plano_completo >= 60, n.dias_plano_completo),
      ('plano_semana', n.sequencia_dias_plano >= 7, n.sequencia_dias_plano),

      ('dedicacao_30', n.dias_com_registro >= 30, n.dias_com_registro),

      ('peso_1',       n.pesagens >= 1,            n.pesagens),
      ('peso_4',       n.semanas_com_peso >=  4,   n.semanas_com_peso),
      ('peso_12',      n.semanas_com_peso >= 12,   n.semanas_com_peso),

      ('fotos_1',      n.fotos_progresso >= 1,      n.fotos_progresso),
      ('fotos_3',      n.meses_com_foto >= 3,       n.meses_com_foto),
      ('disciplinado', n.meses_foto_cumpridos >= 1, n.meses_foto_cumpridos),

      ('agua_1',       n.dias_agua_meta >=  1, n.dias_agua_meta),
      ('agua_7',       n.dias_agua_meta >=  7, n.dias_agua_meta),
      ('agua_30',      n.dias_agua_meta >= 30, n.dias_agua_meta),

      ('meses_3',      n.meses_acompanhamento >= 3, n.meses_acompanhamento),
      ('meses_6',      n.meses_acompanhamento >= 6, n.meses_acompanhamento),

      ('checkin_1',    n.checkins >= 1,          n.checkins),
      ('checkin_3',    n.checkins_seguidos >= 3, n.checkins_seguidos),
      ('checkin_6',    n.checkins_seguidos >= 6, n.checkins_seguidos),

      -- ── Mestre da organização (§4) ─────────────────────────
      -- O recurso que faltava existe agora. A especificação pede o
      -- registro do planejamento da semana, sem contagem — então é um,
      -- como "Aluno disciplinado".
      ('organizacao_1', n.semanas_planejadas >= 1, n.semanas_planejadas)
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

-- Conferência: a tabela, as vinte e duas colunas e o marco novo.
select
  (select count(*) from information_schema.tables
    where table_schema = 'public' and table_name = 'planejamento_semana')  as tabela_1,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'numeros_do_aluno')     as colunas_22,
  (select position('semanas_planejadas' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'numeros_do_aluno')        as numeros_ok,
  (select position('organizacao_1' in prosrc) > 0
     from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'conceder_conquistas')     as concede_ok,
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'planejamento_semana')     as policies_3;
