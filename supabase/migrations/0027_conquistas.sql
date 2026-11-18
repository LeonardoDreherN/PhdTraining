-- ════════════════════════════════════════════════════════════
--  0027 — Conquistas e desbloqueios
--
--  O motor é um só para treino e nutrição. O catálogo (nome, descrição,
--  marcos) mora no app, versionado junto com a tela; aqui ficam só os
--  dois fatos que o app não pode inventar:
--
--    • `aluno_conquistas` — o que foi desbloqueado e QUANDO. A data é
--      exigida pela especificação e não dá para recalcular depois: se o
--      aluno chegou a 50 treinos em março, março é a data, mesmo que em
--      maio ele tenha 80.
--
--    • `aluno_exercicios` — o repertório que ele já recebeu. Também não
--      dá para recalcular: a especificação diz que o exercício continua
--      desbloqueado mesmo quando a prescrição sai do ar, e aí o vínculo
--      com a ficha já não existe.
--
--  QUEM CONCEDE É O BANCO
--
--  `conceder_conquistas` recalcula os critérios a partir dos dados reais
--  — execuções, refeições, pesagens — e insere só o que foi merecido. O
--  app chama; não decide. Deixar o app inserir na tabela significaria
--  que qualquer um com a chave anônima se dá 500 treinos.
--
--  É idempotente: rodar dez vezes não duplica nem reescreve a data.
--
--  Depende do 0001 e do 0014. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create table if not exists public.aluno_conquistas (
  aluno_id        uuid not null references public.alunos(id) on delete cascade,
  codigo          text not null,
  desbloqueado_em timestamptz not null default now(),

  -- O valor que a disparou: 50 treinos, 4 semanas. Fica guardado porque
  -- o marco do catálogo pode mudar, e o que o aluno conquistou não.
  valor           integer,

  primary key (aluno_id, codigo)
);

create index if not exists aluno_conquistas_idx
  on public.aluno_conquistas (aluno_id, desbloqueado_em desc);

create table if not exists public.aluno_exercicios (
  aluno_id        uuid not null references public.alunos(id) on delete cascade,
  exercicio_id    uuid not null references public.exercicios(id) on delete cascade,
  desbloqueado_em timestamptz not null default now(),
  primary key (aluno_id, exercicio_id)
);

-- ════════════════════════════════════════════════════════════
--  DESBLOQUEIO DE EXERCÍCIOS
-- ════════════════════════════════════════════════════════════

-- Acrescenta ao repertório do aluno os exercícios das fichas dele.
--
-- Só acrescenta. Tirar a ficha não tira o exercício: a especificação é
-- explícita, e é o que faz a biblioteca ser dele e não da prescrição.
create or replace function public.desbloquear_exercicios(p_aluno_id uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare novos integer;
begin
  if not public.aluno_e_meu(p_aluno_id) then
    raise exception 'Sem permissão para este aluno' using errcode = '42501';
  end if;

  with inseridos as (
    insert into public.aluno_exercicios (aluno_id, exercicio_id)
    select distinct p_aluno_id, fe.exercicio_id
      from public.aluno_fichas af
      join public.ficha_exercicios fe on fe.ficha_id = af.ficha_id
     where af.aluno_id = p_aluno_id
    on conflict (aluno_id, exercicio_id) do nothing
    returning 1
  )
  select count(*) into novos from inseridos;

  return novos;
end $$;

-- ════════════════════════════════════════════════════════════
--  OS NÚMEROS DO ALUNO
-- ════════════════════════════════════════════════════════════

-- Tudo que as conquistas e os recordes precisam, numa consulta só.
--
-- `semanas_completas` usa a programação VIGENTE para todas as semanas.
-- A especificação pede a programação de cada época, mas o histórico de
-- prescrição não é guardado — não existe de onde tirar. Preferi a conta
-- transparente e documentada a inventar uma precisão que não temos.
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
  fotos_diario         integer
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_previstos integer;
begin
  if not public.aluno_e_meu(p_aluno_id) then
    raise exception 'Sem permissão para este aluno' using errcode = '42501';
  end if;

  -- Quantos dias por semana a programação vigente pede. Zero significa
  -- "sem ficha": aí não há denominador e semana completa não existe —
  -- marcar 100% de nada seria premiar quem não treina.
  select coalesce(sum(array_length(af.dias_semana, 1)), 0)
    into v_previstos
    from public.aluno_fichas af
   where af.aluno_id = p_aluno_id and af.ativa;

  return query
  with exec as (
    select date_trunc('week', e.executado_em at time zone 'America/Sao_Paulo')::date as semana,
           (e.executado_em at time zone 'America/Sao_Paulo')::date as dia
      from public.treino_execucoes e
     where e.aluno_id = p_aluno_id
  ),
  por_semana as (
    select semana, count(distinct dia) as dias
      from exec group by semana
  ),
  completas as (
    select semana from por_semana
     where v_previstos > 0 and dias >= v_previstos
  ),
  -- Sequência de semanas completas: numera as semanas e agrupa as que
  -- são consecutivas. A diferença entre a posição e a semana é constante
  -- dentro de uma sequência.
  seq_semanas as (
    select count(*) as n
      from (
        select semana,
               (row_number() over (order by semana)) as pos
          from completas
      ) t
     group by semana - (pos * interval '1 week')
  ),
  dias_distintos as (
    select distinct dia from exec
  ),
  seq_dias as (
    select count(*) as n
      from (
        select dia, (row_number() over (order by dia)) as pos
          from dias_distintos
      ) t
     group by dia - pos
  ),
  -- Dia 100% no plano: todas as refeições do plano ativo marcadas.
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
    select rr.data
      from public.refeicoes_registro rr
     where rr.aluno_id = p_aluno_id and rr.feita
     group by rr.data
    having (select total from refeicoes_do_plano) > 0
       and count(*) >= (select total from refeicoes_do_plano)
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
      where aluno_id = p_aluno_id and foto_path is not null);
end $$;

-- ════════════════════════════════════════════════════════════
--  CONCEDER
-- ════════════════════════════════════════════════════════════

-- Recalcula os critérios e grava o que foi merecido.
--
-- Devolve só as conquistas NOVAS desta chamada: é com isso que a tela
-- mostra a comemoração, sem precisar comparar listas no app.
create or replace function public.conceder_conquistas(p_aluno_id uuid)
-- Os nomes de saída não repetem os das colunas de propósito: dentro do
-- `returning`, `codigo` seria ao mesmo tempo o parâmetro de saída e a
-- coluna da tabela, e o Postgres recusa a ambiguidade.
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
      -- Quantidade de treinos.
      ('treinos_1',    n.treinos >=   1, n.treinos),
      ('treinos_10',   n.treinos >=  10, n.treinos),
      ('treinos_25',   n.treinos >=  25, n.treinos),
      ('treinos_50',   n.treinos >=  50, n.treinos),
      ('treinos_100',  n.treinos >= 100, n.treinos),
      ('treinos_250',  n.treinos >= 250, n.treinos),
      ('treinos_500',  n.treinos >= 500, n.treinos),

      -- Consistência: semanas consecutivas cumprindo a PRÓPRIA
      -- programação. Quem treina 3x e cumpre os 3 vale igual a quem
      -- treina 5x e cumpre os 5 — é o critério central do documento.
      ('semanas_1',    n.sequencia_semanas >=  1, n.sequencia_semanas),
      ('semanas_2',    n.sequencia_semanas >=  2, n.sequencia_semanas),
      ('semanas_4',    n.sequencia_semanas >=  4, n.sequencia_semanas),
      ('semanas_8',    n.sequencia_semanas >=  8, n.sequencia_semanas),
      ('semanas_12',   n.sequencia_semanas >= 12, n.sequencia_semanas),
      ('semanas_26',   n.sequencia_semanas >= 26, n.sequencia_semanas)
  )
  insert into public.aluno_conquistas (aluno_id, codigo, valor)
  select p_aluno_id, cod, v from marcos where atingido
  on conflict (aluno_id, codigo) do nothing
  returning aluno_conquistas.codigo, aluno_conquistas.valor;
exception
  -- Aluno sem ficha e sem execução nenhuma não é erro: é aluno novo.
  when no_data_found then
    return;
end $$;

-- ════════════════════════════════════════════════════════════
--  RLS
-- ════════════════════════════════════════════════════════════

alter table public.aluno_conquistas enable row level security;
alter table public.aluno_exercicios enable row level security;

-- Leitura para quem já enxerga o aluno: ele mesmo, o personal dono e a
-- equipe. Escrita: ninguém. As duas tabelas só mudam pelas funções, que
-- conferem o critério antes de gravar.
drop policy if exists "conquistas: quem vê o aluno" on public.aluno_conquistas;
create policy "conquistas: quem vê o aluno"
  on public.aluno_conquistas for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "exercicios desbloqueados: quem vê o aluno" on public.aluno_exercicios;
create policy "exercicios desbloqueados: quem vê o aluno"
  on public.aluno_exercicios for select to authenticated
  using (public.aluno_e_meu(aluno_id));

grant select on public.aluno_conquistas to authenticated;
grant select on public.aluno_exercicios to authenticated;

revoke all on function public.desbloquear_exercicios(uuid) from public;
revoke all on function public.numeros_do_aluno(uuid)       from public;
revoke all on function public.conceder_conquistas(uuid)    from public;
grant execute on function public.desbloquear_exercicios(uuid) to authenticated;
grant execute on function public.numeros_do_aluno(uuid)       to authenticated;
grant execute on function public.conceder_conquistas(uuid)    to authenticated;

notify pgrst, 'reload schema';

-- Conferência: as tabelas, as funções e o tamanho do catálogo oficial,
-- que é o denominador da barra de desbloqueios.
select
  (select count(*) from information_schema.tables
    where table_schema = 'public'
      and table_name in ('aluno_conquistas', 'aluno_exercicios'))   as tabelas,
  (select count(*) from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public'
      and p.proname in ('desbloquear_exercicios', 'numeros_do_aluno',
                        'conceder_conquistas'))                     as funcoes,
  (select count(*) from public.exercicios where oficial)            as catalogo_oficial;
