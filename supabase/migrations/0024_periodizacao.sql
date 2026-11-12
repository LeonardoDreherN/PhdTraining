-- ════════════════════════════════════════════════════════════
--  0024 — Periodização: etapas planejadas e treinos programados
--
--  ETAPA
--  Uma fase da periodização do aluno ("Dezembro — progressão de carga"):
--  período, objetivo, volume e intensidade esperados, palavras-chave e
--  observações. É o diário de planejamento do profissional — o aluno não
--  lê. As fichas da etapa são linhas de `aluno_fichas` com `etapa_id`.
--
--  ESTADO DA FICHA DO ALUNO
--  `aluno_fichas.estado`: programada (etapa ainda não começou), vigente
--  (o aluno vê e treina) ou encerrada (histórico). `ativa` continua
--  existindo porque o app inteiro filtra por ela; um gatilho a mantém
--  igual a `estado = 'vigente'`, nos dois sentidos — o código antigo que
--  escreve `ativa` continua funcionando.
--
--  VIRADA DE ETAPA
--  `_aplicar_periodizacao` deixa vigentes as fichas da etapa mais recente
--  que já começou e encerra as das etapas anteriores (e, se a etapa pede,
--  as fichas avulsas que estavam valendo). Roda todo dia às 00:10 de
--  Brasília pelo pg_cron, e o app chama a versão por aluno ao abrir os
--  treinos — assim a troca aparece na hora mesmo se o cron atrasar.
--  Adiar uma etapa que já começou desfaz a virada: o que foi encerrado
--  automaticamente volta.
--
--  A etapa não tem fim obrigatório. Sem a próxima etapa programada, as
--  fichas continuam valendo depois de `data_fim`: aluno sem treino é
--  pior que treino velho, e o app avisa o profissional.
--
--  Depende do 0001. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create table if not exists public.periodizacao_etapas (
  id                   uuid primary key default gen_random_uuid(),
  aluno_id             uuid not null references public.alunos(id) on delete cascade,
  personal_id          uuid not null references auth.users(id) on delete cascade,
  nome                 text not null,
  data_inicio          date not null,
  data_fim             date,
  objetivo             text,
  volume               text,
  intensidade          text,
  palavras_chave       text[] not null default '{}',
  observacoes          text,
  -- Ao começar, encerra também as fichas avulsas (sem etapa) que estavam
  -- valendo. Desligado para quem mantém uma ficha paralela (mobilidade).
  substitui_anteriores boolean not null default true,
  criado_em            timestamptz not null default now(),
  atualizado_em        timestamptz not null default now(),
  constraint periodizacao_datas_chk check (data_fim is null or data_fim >= data_inicio)
);

create index if not exists periodizacao_etapas_idx
  on public.periodizacao_etapas (aluno_id, data_inicio);

alter table public.periodizacao_etapas enable row level security;

drop policy if exists "etapas: o personal do aluno" on public.periodizacao_etapas;
create policy "etapas: o personal do aluno"
  on public.periodizacao_etapas for all to authenticated
  using (personal_id = auth.uid())
  with check (
    personal_id = auth.uid()
    and exists (select 1 from public.alunos a
                 where a.id = periodizacao_etapas.aluno_id and a.personal_id = auth.uid())
  );

grant select, insert, update, delete on public.periodizacao_etapas to authenticated;

-- ── aluno_fichas ────────────────────────────────────────────
alter table public.aluno_fichas
  add column if not exists etapa_id uuid references public.periodizacao_etapas(id) on delete set null;
alter table public.aluno_fichas add column if not exists data_fim date;
alter table public.aluno_fichas add column if not exists estado text not null default 'vigente';
alter table public.aluno_fichas add column if not exists encerrada_pela_etapa boolean not null default false;

alter table public.aluno_fichas drop constraint if exists aluno_fichas_estado_chk;
alter table public.aluno_fichas add constraint aluno_fichas_estado_chk
  check (estado in ('programada', 'vigente', 'encerrada'));

update public.aluno_fichas
   set estado = case when ativa then 'vigente' else 'encerrada' end
 where estado = 'vigente' and not ativa;

-- O índice único (aluno_id, ficha_id) do 0001 continua: o app publicado
-- faz upsert por ele, e trocá-lo quebraria "Atribuir" entre rodar este
-- arquivo e publicar o app novo. Consequência: uma ficha está em uma
-- etapa por vez — para repetir um bloco, duplica-se a ficha.

create index if not exists aluno_fichas_etapa_idx on public.aluno_fichas (etapa_id);

create or replace function public.aluno_fichas_sincroniza_ativa()
returns trigger
language plpgsql as $$
begin
  -- Código antigo mexe em `ativa`: traduz para `estado`.
  if tg_op = 'UPDATE' and new.ativa is distinct from old.ativa
     and new.estado is not distinct from old.estado then
    new.estado := case when new.ativa then 'vigente' else 'encerrada' end;
  end if;
  -- Encerrada à mão não volta sozinha numa virada de etapa.
  if tg_op = 'UPDATE' and new.estado is distinct from old.estado
     and new.estado = 'encerrada' and new.encerrada_pela_etapa is not distinct from old.encerrada_pela_etapa then
    new.encerrada_pela_etapa := false;
  end if;
  if new.estado <> 'encerrada' then new.encerrada_pela_etapa := false; end if;
  new.ativa := (new.estado = 'vigente');
  return new;
end;
$$;

drop trigger if exists aluno_fichas_sincroniza_ativa on public.aluno_fichas;
create trigger aluno_fichas_sincroniza_ativa
  before insert or update on public.aluno_fichas
  for each row execute function public.aluno_fichas_sincroniza_ativa();

-- ── Virada de etapa ─────────────────────────────────────────
create or replace function public._aplicar_periodizacao(p_aluno_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  -- A etapa que vale hoje, por aluno: a que começou mais recentemente.
  create temp table if not exists _etapa_atual (aluno_id uuid, etapa_id uuid, inicio date, substitui boolean)
    on commit drop;
  delete from _etapa_atual;
  insert into _etapa_atual
  select distinct on (e.aluno_id) e.aluno_id, e.id, e.data_inicio, e.substitui_anteriores
    from public.periodizacao_etapas e
   where e.data_inicio <= hoje
     and (p_aluno_id is null or e.aluno_id = p_aluno_id)
   order by e.aluno_id, e.data_inicio desc, e.criado_em desc;

  -- 1. Fichas da etapa atual entram em vigor (inclusive as que uma virada
  --    anterior encerrou, se a etapa foi adiada e voltou a ser a atual).
  update public.aluno_fichas af
     set estado = 'vigente', data_fim = null
    from _etapa_atual a
   where af.etapa_id = a.etapa_id
     and (af.estado = 'programada' or (af.estado = 'encerrada' and af.encerrada_pela_etapa));

  -- 2. Fichas de etapas anteriores saem.
  update public.aluno_fichas af
     set estado = 'encerrada', encerrada_pela_etapa = true,
         data_fim = coalesce(af.data_fim, a.inicio - 1)
    from _etapa_atual a, public.periodizacao_etapas e
   where af.etapa_id = e.id
     and e.aluno_id = a.aluno_id
     and e.id <> a.etapa_id
     and e.data_inicio <= a.inicio
     and af.estado = 'vigente';

  -- 3. Avulsas que valiam antes da etapa saem, se a etapa substitui.
  update public.aluno_fichas af
     set estado = 'encerrada', encerrada_pela_etapa = true,
         data_fim = coalesce(af.data_fim, a.inicio - 1)
    from _etapa_atual a
   where af.aluno_id = a.aluno_id
     and af.etapa_id is null
     and a.substitui
     and af.estado = 'vigente'
     and af.data_inicio < a.inicio;

  -- 4. Etapa adiada para o futuro: as fichas dela voltam a programadas.
  update public.aluno_fichas af
     set estado = 'programada', data_fim = null
    from public.periodizacao_etapas e
   where af.etapa_id = e.id
     and e.data_inicio > hoje
     and af.estado = 'vigente'
     and (p_aluno_id is null or e.aluno_id = p_aluno_id);

  -- 5. Avulsas encerradas por uma etapa que deixou de valer (adiada ou
  --    apagada) voltam, se não há etapa atual que as substitua.
  update public.aluno_fichas af
     set estado = 'vigente', data_fim = null
   where af.etapa_id is null
     and af.estado = 'encerrada'
     and af.encerrada_pela_etapa
     and (p_aluno_id is null or af.aluno_id = p_aluno_id)
     and not exists (select 1 from _etapa_atual a
                      where a.aluno_id = af.aluno_id and a.substitui and af.data_inicio < a.inicio);
end;
$$;

revoke all on function public._aplicar_periodizacao(uuid) from public, anon, authenticated;
grant execute on function public._aplicar_periodizacao(uuid) to service_role;

-- Versão que o app chama: só para um aluno que é seu (personal) ou você
-- mesmo (aluno). O aluno também chama — é a tela dele que precisa mudar.
create or replace function public.aplicar_periodizacao_do_aluno(p_aluno_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.aluno_e_meu(p_aluno_id) then
    raise exception 'sem acesso a este aluno';
  end if;
  perform public._aplicar_periodizacao(p_aluno_id);
end;
$$;

revoke all on function public.aplicar_periodizacao_do_aluno(uuid) from public, anon;
grant execute on function public.aplicar_periodizacao_do_aluno(uuid) to authenticated;

-- ── Todo dia ────────────────────────────────────────────────
create extension if not exists pg_cron;

do $$
begin
  perform cron.unschedule('aplicar-periodizacao')
    where exists (select 1 from cron.job where jobname = 'aplicar-periodizacao');
  -- 03:10 UTC = 00:10 em Brasília.
  perform cron.schedule('aplicar-periodizacao', '10 3 * * *',
                        'select public._aplicar_periodizacao(null)');
end $$;

notify pgrst, 'reload schema';

-- Conferência: a tabela com RLS, o agendamento e as fichas por estado.
select
  (select relrowsecurity from pg_class where relname = 'periodizacao_etapas') as etapas_rls,
  (select count(*) from cron.job where jobname = 'aplicar-periodizacao')     as agendado,
  (select count(*) from public.aluno_fichas where ativa <> (estado = 'vigente')) as fora_de_sincronia;
