-- ============================================================
-- 0001 — Base
--
-- Tudo que o app já faz hoje, reconstruído a partir do código: as 16
-- tabelas que as 59 telas leem e escrevem. Nada foi removido.
--
-- O que mudou em relação ao banco antigo:
--   • RLS ligado em todas, desde a primeira linha
--   • isolamento entre personais garantido pelo banco, não pelo `.eq()`
--     em Dart — um personal não alcança dado de outro nem chamando a API
--     REST na mão
--   • `exercicios` ganha biblioteca oficial (personal_id nulo)
--   • índices nas consultas que as telas realmente fazem
--
-- Seguro rodar mais de uma vez.
-- ============================================================

create extension if not exists pgcrypto;

-- ════════════════════════════════════════════════════════════
--  PERFIL
-- ════════════════════════════════════════════════════════════

create table if not exists public.profiles (
  id                uuid primary key references auth.users(id) on delete cascade,
  role              text not null default 'personal' check (role in ('personal','aluno','admin')),
  nome              text,
  email             text,
  avatar_url        text,
  whatsapp          text,
  cref              text,

  -- Marca que o ALUNO enxerga. O painel do personal usa sempre a marca da
  -- plataforma; o app do aluno usa a do personal dele.
  slug              text,
  marca_nome        text,
  marca_logo_url    text,
  marca_cor         text not null default '#D7FF3E',

  onboarding_etapa  text not null default 'conta',
  is_platform_admin boolean not null default false,
  criado_em         timestamptz not null default now()
);

create unique index if not exists profiles_slug_key
  on public.profiles (lower(slug)) where slug is not null;

-- O app assume que existe uma linha em `profiles` para todo usuário logado.
-- Sem este gatilho, quem se cadastra cai numa tela sem nome e sem papel.
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, role, nome, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'role', 'personal'),
    new.raw_user_meta_data->>'nome',
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ════════════════════════════════════════════════════════════
--  ALUNOS
-- ════════════════════════════════════════════════════════════

create table if not exists public.alunos (
  id                   uuid primary key default gen_random_uuid(),
  personal_id          uuid not null references auth.users(id) on delete cascade,

  -- Nulo enquanto o aluno ainda não aceitou o convite / não tem login.
  user_id              uuid references auth.users(id) on delete set null,

  nome                 text not null,
  email                text,
  whatsapp             text,
  data_nascimento      date,
  genero               text,
  grupo                text,
  foto_url             text,
  notas                text,
  ativo                boolean not null default true,
  anamnese_tipo        text not null default 'nenhuma',
  anamnese_preenchida  boolean not null default false,
  criado_em            timestamptz not null default now()
);

create index if not exists alunos_personal_idx on public.alunos (personal_id, ativo, nome);
create index if not exists alunos_user_idx     on public.alunos (user_id) where user_id is not null;

-- Um login de aluno pertence a um cadastro só.
create unique index if not exists alunos_user_unico
  on public.alunos (user_id) where user_id is not null;

-- ════════════════════════════════════════════════════════════
--  HELPERS DE PERMISSÃO
--  Precisam vir depois de `alunos`: o corpo delas consulta a tabela.
-- ════════════════════════════════════════════════════════════

create or replace function public.eh_admin_plataforma()
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_platform_admin from public.profiles where id = auth.uid()), false);
$$;

-- Para um personal: o próprio id. Para um aluno: o id do personal dele.
-- É isto que deixa o aluno ler a ficha e os exercícios do seu treinador
-- sem enxergar os de mais ninguém.
create or replace function public.meu_personal_id()
returns uuid
language sql stable security definer set search_path = public as $$
  select case
    when (select role from public.profiles where id = auth.uid()) = 'personal'
      then auth.uid()
    else (select a.personal_id from public.alunos a where a.user_id = auth.uid() limit 1)
  end;
$$;

-- "Esta linha é de um aluno que eu posso ver?" — verdadeiro para o personal
-- dono e para o próprio aluno. Usada por toda tabela pendurada em aluno_id,
-- que é como as avaliações evitam carregar um personal_id redundante e
-- passível de dessincronizar.
create or replace function public.aluno_e_meu(p_aluno_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.alunos a
    where a.id = p_aluno_id
      and (a.personal_id = auth.uid() or a.user_id = auth.uid())
  ) or public.eh_admin_plataforma();
$$;

revoke all on function public.eh_admin_plataforma()   from public;
revoke all on function public.meu_personal_id()       from public;
revoke all on function public.aluno_e_meu(uuid)       from public;
grant execute on function public.eh_admin_plataforma() to authenticated;
grant execute on function public.meu_personal_id()     to authenticated;
grant execute on function public.aluno_e_meu(uuid)     to authenticated;

-- ════════════════════════════════════════════════════════════
--  EXERCÍCIOS
-- ════════════════════════════════════════════════════════════

create table if not exists public.exercicios (
  id             uuid primary key default gen_random_uuid(),

  -- Nulo = exercício oficial da plataforma, visível para todo mundo.
  personal_id    uuid references auth.users(id) on delete cascade,
  oficial        boolean not null default false,

  nome           text not null,
  grupo_muscular text,
  equipamento    text,
  descricao      text,
  instrucoes     text,
  midia_url      text,
  video_url      text,
  thumb_url      text,

  -- Se o personal duplicou um oficial para ajustar, aponta para o original.
  origem_id      uuid references public.exercicios(id) on delete set null,
  criado_em      timestamptz not null default now(),

  constraint exercicios_escopo_chk check (
    (oficial and personal_id is null) or (not oficial and personal_id is not null)
  )
);

create index if not exists exercicios_oficiais_idx
  on public.exercicios (grupo_muscular, nome) where oficial;
create index if not exists exercicios_do_personal_idx
  on public.exercicios (personal_id, grupo_muscular) where not oficial;
create unique index if not exists exercicios_oficial_nome_key
  on public.exercicios (lower(nome), coalesce(grupo_muscular, '')) where oficial;

-- O personal não edita um oficial: ele tira uma cópia sua.
create or replace function public.duplicar_exercicio_oficial(p_exercicio_id uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_novo uuid;
begin
  insert into public.exercicios
    (personal_id, nome, grupo_muscular, equipamento, descricao, instrucoes,
     midia_url, video_url, thumb_url, oficial, origem_id)
  select auth.uid(), e.nome, e.grupo_muscular, e.equipamento, e.descricao,
         e.instrucoes, e.midia_url, e.video_url, e.thumb_url, false, e.id
    from public.exercicios e
   where e.id = p_exercicio_id and e.oficial
  returning id into v_novo;

  if v_novo is null then
    raise exception 'Exercício oficial não encontrado: %', p_exercicio_id;
  end if;
  return v_novo;
end;
$$;

revoke all on function public.duplicar_exercicio_oficial(uuid) from public;
grant execute on function public.duplicar_exercicio_oficial(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════
--  FICHAS DE TREINO
-- ════════════════════════════════════════════════════════════

create table if not exists public.fichas (
  id          uuid primary key default gen_random_uuid(),
  personal_id uuid not null references auth.users(id) on delete cascade,
  nome        text not null,
  descricao   text,
  criado_em   timestamptz not null default now()
);

create index if not exists fichas_personal_idx on public.fichas (personal_id, nome);

create table if not exists public.ficha_exercicios (
  id                uuid primary key default gen_random_uuid(),
  ficha_id          uuid not null references public.fichas(id) on delete cascade,
  exercicio_id      uuid not null references public.exercicios(id) on delete restrict,
  series            integer not null default 3,
  repeticoes        text,
  carga             text,
  descanso_segundos integer,
  ordem             integer not null default 0,
  observacoes       text,

  -- Espaço para os métodos do montador: 'normal', 'bi_set', 'drop_set',
  -- 'piramide'. Exercícios agrupados compartilham o mesmo `grupo_id`.
  metodo            text not null default 'normal',
  grupo_id          uuid,

  criado_em         timestamptz not null default now()
);

-- `ON DELETE RESTRICT` no exercício é proposital: apagar um exercício que
-- está dentro de fichas ativas quebraria treino de aluno no meio da semana.
-- O app deve marcar como inativo, não excluir.

create index if not exists ficha_exercicios_ordem_idx
  on public.ficha_exercicios (ficha_id, ordem);

create table if not exists public.aluno_fichas (
  id          uuid primary key default gen_random_uuid(),
  aluno_id    uuid not null references public.alunos(id) on delete cascade,
  ficha_id    uuid not null references public.fichas(id) on delete cascade,
  ativa       boolean not null default true,
  dias_semana integer[] not null default '{}',
  data_inicio date not null default current_date,
  criado_em   timestamptz not null default now()
);

-- O código usa upsert sem chave explícita. Sem este índice, reatribuir a
-- mesma ficha cria linha duplicada e o aluno vê o treino duas vezes.
create unique index if not exists aluno_fichas_par_key
  on public.aluno_fichas (aluno_id, ficha_id);

create index if not exists aluno_fichas_ativas_idx
  on public.aluno_fichas (aluno_id) where ativa;

-- ════════════════════════════════════════════════════════════
--  EXECUÇÃO DE TREINO
-- ════════════════════════════════════════════════════════════

create table if not exists public.treino_execucoes (
  id               uuid primary key default gen_random_uuid(),
  personal_id      uuid not null references auth.users(id) on delete cascade,
  aluno_id         uuid references public.alunos(id) on delete set null,
  aluno_user_id    uuid,

  -- Nome copiado no momento da execução, de propósito: é registro
  -- histórico. Se o aluno trocar de nome, o treino de março continua
  -- mostrando quem o fez naquele dia.
  aluno_nome       text,
  ficha_id         uuid references public.fichas(id) on delete set null,
  ficha_nome       text,

  duracao_minutos  integer,
  total_exercicios integer,
  detalhes         jsonb not null default '[]'::jsonb,
  executado_em     timestamptz not null default now()
);

create index if not exists execucoes_personal_idx
  on public.treino_execucoes (personal_id, executado_em desc);
create index if not exists execucoes_aluno_idx
  on public.treino_execucoes (aluno_id, executado_em desc);

-- ════════════════════════════════════════════════════════════
--  ANAMNESE E AVALIAÇÕES
-- ════════════════════════════════════════════════════════════

create table if not exists public.anamnese (
  id            uuid primary key default gen_random_uuid(),
  aluno_id      uuid not null references public.alunos(id) on delete cascade,
  tipo          text not null,
  respostas     jsonb not null default '{}'::jsonb,
  preenchida_em timestamptz
);

-- O app faz `upsert` sem `onConflict`, o que no PostgREST recai sobre a
-- chave primária — e como o id vem gerado, toda edição criava uma linha
-- nova. Este índice transforma isso em atualização de verdade, desde que o
-- código passe `onConflict: 'aluno_id,tipo'`.
create unique index if not exists anamnese_aluno_tipo_key
  on public.anamnese (aluno_id, tipo);

create table if not exists public.avaliacao_geral (
  id              uuid primary key default gen_random_uuid(),
  aluno_id        uuid not null unique references public.alunos(id) on delete cascade,
  fcrep           numeric,
  vo2max          numeric,
  data_nascimento date,
  atualizado_em   timestamptz not null default now()
);

create table if not exists public.avaliacao_morfologica_dobras (
  id                uuid primary key default gen_random_uuid(),
  aluno_id          uuid not null references public.alunos(id) on delete cascade,
  protocolo         text,
  genero            text,
  data_avaliacao    date not null default current_date,
  peso              numeric,
  estatura          numeric,
  idade             integer,

  -- Perimetria
  pesco_co          numeric,
  ombro             numeric,
  torax             numeric,
  braco_esq         numeric,
  braco_dir         numeric,
  cintura           numeric,
  abdomen           numeric,
  quadril           numeric,
  coxa_esq          numeric,
  coxa_dir          numeric,
  perna_esq         numeric,
  perna_dir         numeric,

  -- Dobras cutâneas
  tricipital        numeric,
  subescapular      numeric,
  peitoral          numeric,
  abdominal         numeric,
  supraoiliaca      numeric,
  coxa              numeric,
  perna             numeric,
  axilar_media      numeric,

  -- Calculados pelo app
  soma_dobras       numeric,
  perc_gordura      numeric,
  massa_gorda       numeric,
  massa_magra       numeric,

  peso_ideal        numeric,
  perc_proposta     numeric,
  objetivo          text,
  observacoes       text,
  proxima_avaliacao date,
  criado_em         timestamptz not null default now()
);

create table if not exists public.avaliacao_morfologica_bioimpedancia (
  id                uuid primary key default gen_random_uuid(),
  aluno_id          uuid not null references public.alunos(id) on delete cascade,
  genero            text,
  data_avaliacao    date not null default current_date,
  peso              numeric,
  estatura          numeric,
  idade             integer,

  pesco_co          numeric,
  ombro             numeric,
  torax             numeric,
  braco_esq         numeric,
  braco_dir         numeric,
  cintura           numeric,
  abdomen           numeric,
  quadril           numeric,
  coxa_esq          numeric,
  coxa_dir          numeric,
  perna_esq         numeric,
  perna_dir         numeric,

  perc_gordura      numeric,
  massa_gorda       numeric,
  massa_magra       numeric,
  peso_ideal        numeric,
  perc_proposta     numeric,
  objetivo          text,
  observacoes       text,
  proxima_avaliacao date,
  criado_em         timestamptz not null default now()
);

create table if not exists public.avaliacao_neuromotores_flexibilidade (
  id             uuid primary key default gen_random_uuid(),
  aluno_id       uuid not null references public.alunos(id) on delete cascade,
  data_avaliacao date not null default current_date,
  genero         text,
  idade          integer,
  alcance        numeric,
  analise        text,
  criado_em      timestamptz not null default now()
);

create table if not exists public.avaliacao_neuromotores_resistencia (
  id                uuid primary key default gen_random_uuid(),
  aluno_id          uuid not null references public.alunos(id) on delete cascade,
  data_avaliacao    date not null default current_date,
  genero            text,
  idade             integer,
  tipo              text,
  abdominal_reps    integer,
  flexao_braco_reps integer,
  analise           text,
  criado_em         timestamptz not null default now()
);

create table if not exists public.avaliacao_neuromotores_impulsao (
  id                  uuid primary key default gen_random_uuid(),
  aluno_id            uuid not null references public.alunos(id) on delete cascade,
  data_avaliacao      date not null default current_date,
  genero              text,
  tipo                text,
  impulsao_horizontal numeric,
  impulsao_vertical   numeric,
  analise             text,
  criado_em           timestamptz not null default now()
);

create table if not exists public.avaliacao_neuromotores_carga (
  id             uuid primary key default gen_random_uuid(),
  aluno_id       uuid not null references public.alunos(id) on delete cascade,
  data_avaliacao date not null default current_date,
  genero         text,
  exercicio      text,
  carga_kg       numeric,
  repeticoes     integer,
  rm_calculado   numeric,
  analise        text,
  criado_em      timestamptz not null default now()
);

-- As telas de avaliação sempre listam por aluno e por data.
create index if not exists av_dobras_idx   on public.avaliacao_morfologica_dobras (aluno_id, data_avaliacao desc);
create index if not exists av_bio_idx      on public.avaliacao_morfologica_bioimpedancia (aluno_id, data_avaliacao desc);
create index if not exists av_flex_idx     on public.avaliacao_neuromotores_flexibilidade (aluno_id, data_avaliacao desc);
create index if not exists av_resist_idx   on public.avaliacao_neuromotores_resistencia (aluno_id, data_avaliacao desc);
create index if not exists av_impulsao_idx on public.avaliacao_neuromotores_impulsao (aluno_id, data_avaliacao desc);
create index if not exists av_carga_idx    on public.avaliacao_neuromotores_carga (aluno_id, data_avaliacao desc);

-- ════════════════════════════════════════════════════════════
--  PROGRESSO E ARQUIVOS
-- ════════════════════════════════════════════════════════════

create table if not exists public.fotos_progresso (
  id            uuid primary key default gen_random_uuid(),
  aluno_id      uuid not null references public.alunos(id) on delete cascade,
  foto_url      text not null,
  peso_kg       numeric,
  observacoes   text,
  registrado_em timestamptz not null default now()
);

create index if not exists fotos_progresso_idx
  on public.fotos_progresso (aluno_id, registrado_em desc);

create table if not exists public.aluno_arquivos (
  id            uuid primary key default gen_random_uuid(),
  aluno_id      uuid not null references public.alunos(id) on delete cascade,
  personal_id   uuid not null references auth.users(id) on delete cascade,
  nome          text not null,
  arquivo_url   text not null,
  tipo_mime     text,
  tamanho_bytes bigint,
  criado_em     timestamptz not null default now()
);

create index if not exists aluno_arquivos_idx
  on public.aluno_arquivos (aluno_id, criado_em desc);

-- ════════════════════════════════════════════════════════════
--  RLS
--
--  Isto é o que separa um personal do outro. Sem isto, a anon key que
--  está dentro do app — e portanto ao alcance de qualquer um que abra o
--  DevTools — dá acesso à base inteira.
-- ════════════════════════════════════════════════════════════

alter table public.profiles                             enable row level security;
alter table public.alunos                               enable row level security;
alter table public.exercicios                           enable row level security;
alter table public.fichas                               enable row level security;
alter table public.ficha_exercicios                     enable row level security;
alter table public.aluno_fichas                         enable row level security;
alter table public.treino_execucoes                     enable row level security;
alter table public.anamnese                             enable row level security;
alter table public.avaliacao_geral                      enable row level security;
alter table public.avaliacao_morfologica_dobras         enable row level security;
alter table public.avaliacao_morfologica_bioimpedancia  enable row level security;
alter table public.avaliacao_neuromotores_flexibilidade enable row level security;
alter table public.avaliacao_neuromotores_resistencia   enable row level security;
alter table public.avaliacao_neuromotores_impulsao      enable row level security;
alter table public.avaliacao_neuromotores_carga         enable row level security;
alter table public.fotos_progresso                      enable row level security;
alter table public.aluno_arquivos                       enable row level security;

-- ── profiles ────────────────────────────────────────────────
-- O aluno precisa ler o perfil do personal dele (é de lá que vem a marca
-- do app). Por isso profiles é legível dentro do mesmo tenant — e por isso
-- CPF e endereço NÃO moram aqui, e sim em `pagamento_contas` (0003).
drop policy if exists "profiles: leitura no meu tenant" on public.profiles;
create policy "profiles: leitura no meu tenant"
  on public.profiles for select to authenticated
  using (
    id = auth.uid()
    or id = public.meu_personal_id()
    or exists (select 1 from public.alunos a
                where a.user_id = profiles.id and a.personal_id = auth.uid())
    or public.eh_admin_plataforma()
  );

drop policy if exists "profiles: edito o meu" on public.profiles;
create policy "profiles: edito o meu"
  on public.profiles for update to authenticated
  using (id = auth.uid())
  -- `is_platform_admin` fora daqui seria escalada de privilégio: qualquer
  -- personal se promoveria a admin com um PATCH.
  with check (id = auth.uid() and is_platform_admin = (
    select p.is_platform_admin from public.profiles p where p.id = auth.uid()
  ));

-- ── alunos ──────────────────────────────────────────────────
drop policy if exists "alunos: do meu personal ou eu mesmo" on public.alunos;
create policy "alunos: do meu personal ou eu mesmo"
  on public.alunos for select to authenticated
  using (personal_id = auth.uid() or user_id = auth.uid() or public.eh_admin_plataforma());

drop policy if exists "alunos: só o personal escreve" on public.alunos;
create policy "alunos: só o personal escreve"
  on public.alunos for all to authenticated
  using (personal_id = auth.uid())
  with check (personal_id = auth.uid());

-- ── exercicios ──────────────────────────────────────────────
drop policy if exists "exercicios: oficiais e os do meu personal" on public.exercicios;
create policy "exercicios: oficiais e os do meu personal"
  on public.exercicios for select to authenticated
  using (oficial or personal_id = public.meu_personal_id());

drop policy if exists "exercicios: insert do dono" on public.exercicios;
create policy "exercicios: insert do dono"
  on public.exercicios for insert to authenticated
  with check (personal_id = auth.uid() and not oficial);

drop policy if exists "exercicios: update do dono" on public.exercicios;
create policy "exercicios: update do dono"
  on public.exercicios for update to authenticated
  using (personal_id = auth.uid() and not oficial)
  with check (personal_id = auth.uid() and not oficial);

drop policy if exists "exercicios: delete do dono" on public.exercicios;
create policy "exercicios: delete do dono"
  on public.exercicios for delete to authenticated
  using (personal_id = auth.uid() and not oficial);

drop policy if exists "exercicios: admin cuida dos oficiais" on public.exercicios;
create policy "exercicios: admin cuida dos oficiais"
  on public.exercicios for all to authenticated
  using (public.eh_admin_plataforma())
  with check (public.eh_admin_plataforma());

-- ── fichas ──────────────────────────────────────────────────
drop policy if exists "fichas: leitura no tenant" on public.fichas;
create policy "fichas: leitura no tenant"
  on public.fichas for select to authenticated
  using (personal_id = public.meu_personal_id() or public.eh_admin_plataforma());

drop policy if exists "fichas: escrita do personal" on public.fichas;
create policy "fichas: escrita do personal"
  on public.fichas for all to authenticated
  using (personal_id = auth.uid())
  with check (personal_id = auth.uid());

-- ficha_exercicios não tem personal_id: herda a permissão da ficha.
drop policy if exists "ficha_exercicios: segue a ficha" on public.ficha_exercicios;
create policy "ficha_exercicios: segue a ficha"
  on public.ficha_exercicios for select to authenticated
  using (exists (select 1 from public.fichas f
                  where f.id = ficha_exercicios.ficha_id
                    and f.personal_id = public.meu_personal_id()));

drop policy if exists "ficha_exercicios: escrita do dono da ficha" on public.ficha_exercicios;
create policy "ficha_exercicios: escrita do dono da ficha"
  on public.ficha_exercicios for all to authenticated
  using (exists (select 1 from public.fichas f
                  where f.id = ficha_exercicios.ficha_id and f.personal_id = auth.uid()))
  with check (exists (select 1 from public.fichas f
                       where f.id = ficha_exercicios.ficha_id and f.personal_id = auth.uid()));

-- ── aluno_fichas ────────────────────────────────────────────
drop policy if exists "aluno_fichas: leitura" on public.aluno_fichas;
create policy "aluno_fichas: leitura"
  on public.aluno_fichas for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "aluno_fichas: escrita do personal" on public.aluno_fichas;
create policy "aluno_fichas: escrita do personal"
  on public.aluno_fichas for all to authenticated
  using (exists (select 1 from public.alunos a
                  where a.id = aluno_fichas.aluno_id and a.personal_id = auth.uid()))
  with check (exists (select 1 from public.alunos a
                       where a.id = aluno_fichas.aluno_id and a.personal_id = auth.uid()));

-- ── treino_execucoes ────────────────────────────────────────
drop policy if exists "execucoes: leitura" on public.treino_execucoes;
create policy "execucoes: leitura"
  on public.treino_execucoes for select to authenticated
  using (personal_id = auth.uid() or aluno_user_id = auth.uid() or public.eh_admin_plataforma());

-- Quem registra é o aluno, ao terminar o treino.
drop policy if exists "execucoes: o aluno registra a sua" on public.treino_execucoes;
create policy "execucoes: o aluno registra a sua"
  on public.treino_execucoes for insert to authenticated
  with check (aluno_user_id = auth.uid() and public.aluno_e_meu(aluno_id));

-- ── anamnese e avaliações: todas seguem o dono do aluno ─────
do $$
declare t text;
begin
  foreach t in array array[
    'anamnese',
    'avaliacao_geral',
    'avaliacao_morfologica_dobras',
    'avaliacao_morfologica_bioimpedancia',
    'avaliacao_neuromotores_flexibilidade',
    'avaliacao_neuromotores_resistencia',
    'avaliacao_neuromotores_impulsao',
    'avaliacao_neuromotores_carga',
    'fotos_progresso'
  ] loop
    execute format('drop policy if exists %I on public.%I', t || ': do meu aluno', t);
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using (public.aluno_e_meu(aluno_id)) with check (public.aluno_e_meu(aluno_id))',
      t || ': do meu aluno', t);
  end loop;
end $$;

-- ── aluno_arquivos ──────────────────────────────────────────
drop policy if exists "arquivos: leitura" on public.aluno_arquivos;
create policy "arquivos: leitura"
  on public.aluno_arquivos for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "arquivos: escrita do personal" on public.aluno_arquivos;
create policy "arquivos: escrita do personal"
  on public.aluno_arquivos for all to authenticated
  using (personal_id = auth.uid())
  with check (personal_id = auth.uid());
