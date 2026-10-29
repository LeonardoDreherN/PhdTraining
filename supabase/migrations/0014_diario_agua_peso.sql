-- ════════════════════════════════════════════════════════════
--  0014 — O dia do aluno: diário alimentar, água e peso
--
--  O plano diz o que comer; estas tabelas guardam o que aconteceu.
--
--  DIÁRIO
--  Uma linha por registro, não por refeição: o aluno pode registrar o
--  almoço do plano e, à tarde, um lanche fora dele. `refeicao_id`
--  liga ao plano quando há; nulo = algo fora do plano. `aderencia` é a
--  resposta do aluno a "como foi?" — é ela que alimenta o painel de
--  adesão do profissional, não a foto.
--
--  ÁGUA
--  Uma linha por copo, não um total do dia: "desfazer o último" e
--  "a que horas bebeu" saem de graça, e somar no dia é trivial.
--
--  PESO
--  O peso que o aluno mede em casa. O da avaliação continua na
--  avaliação — são medidas de qualidade diferente, e o app mostra a
--  origem de cada uma.
--
--  Quem escreve: diário e água, só o aluno (é o registro dele, como
--  `refeicoes_registro`). Peso, o aluno e o profissional — pesar na
--  consulta e anotar é uso normal. Quem lê: os dois, via `aluno_e_meu`.
--
--  Depende do 0001 e do 0010. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- ── Diário ──────────────────────────────────────────────────
create table if not exists public.diario_registros (
  id            uuid primary key default gen_random_uuid(),
  aluno_id      uuid not null references public.alunos(id) on delete cascade,
  data          date not null default current_date,
  refeicao_id   uuid references public.plano_refeicoes(id) on delete set null,

  -- Nome copiado no registro, como `treino_execucoes.ficha_nome`: se o
  -- plano mudar, o diário de março continua dizendo "Almoço".
  titulo        text not null,
  descricao     text,
  foto_path     text,
  aderencia     text check (aderencia in ('seguiu', 'parecido', 'fora')),

  registrado_em timestamptz not null default now()
);

create index if not exists diario_registros_idx
  on public.diario_registros (aluno_id, data desc, registrado_em);

-- ── Água ────────────────────────────────────────────────────
create table if not exists public.agua_registros (
  id            uuid primary key default gen_random_uuid(),
  aluno_id      uuid not null references public.alunos(id) on delete cascade,
  data          date not null default current_date,
  ml            integer not null check (ml > 0 and ml <= 3000),
  registrado_em timestamptz not null default now()
);

create index if not exists agua_registros_idx
  on public.agua_registros (aluno_id, data desc);

-- ── Peso ────────────────────────────────────────────────────
create table if not exists public.peso_registros (
  id            uuid primary key default gen_random_uuid(),
  aluno_id      uuid not null references public.alunos(id) on delete cascade,
  data          date not null default current_date,
  peso_kg       numeric(5, 2) not null check (peso_kg between 20 and 400),
  observacoes   text,
  registrado_por uuid default auth.uid(),
  registrado_em timestamptz not null default now()
);

create index if not exists peso_registros_idx
  on public.peso_registros (aluno_id, data desc);

-- ════════════════════════════════════════════════════════════
--  RLS
-- ════════════════════════════════════════════════════════════

alter table public.diario_registros enable row level security;
alter table public.agua_registros   enable row level security;
alter table public.peso_registros   enable row level security;

-- Leitura: o aluno e o profissional dele.
drop policy if exists "diario_registros: leitura" on public.diario_registros;
create policy "diario_registros: leitura"
  on public.diario_registros for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "agua_registros: leitura" on public.agua_registros;
create policy "agua_registros: leitura"
  on public.agua_registros for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "peso_registros: leitura" on public.peso_registros;
create policy "peso_registros: leitura"
  on public.peso_registros for select to authenticated
  using (public.aluno_e_meu(aluno_id));

-- Escrita do diário e da água: só o próprio aluno.
drop policy if exists "diario_registros: o aluno escreve o seu" on public.diario_registros;
create policy "diario_registros: o aluno escreve o seu"
  on public.diario_registros for all to authenticated
  using (exists (select 1 from public.alunos a
                  where a.id = diario_registros.aluno_id and a.user_id = auth.uid()))
  with check (exists (select 1 from public.alunos a
                       where a.id = diario_registros.aluno_id and a.user_id = auth.uid()));

drop policy if exists "agua_registros: o aluno escreve o seu" on public.agua_registros;
create policy "agua_registros: o aluno escreve o seu"
  on public.agua_registros for all to authenticated
  using (exists (select 1 from public.alunos a
                  where a.id = agua_registros.aluno_id and a.user_id = auth.uid()))
  with check (exists (select 1 from public.alunos a
                       where a.id = agua_registros.aluno_id and a.user_id = auth.uid()));

-- Peso: o aluno e o profissional dele.
drop policy if exists "peso_registros: aluno e profissional" on public.peso_registros;
create policy "peso_registros: aluno e profissional"
  on public.peso_registros for all to authenticated
  using (public.aluno_e_meu(aluno_id))
  with check (public.aluno_e_meu(aluno_id));

grant select, insert, update, delete on public.diario_registros to authenticated;
grant select, insert, update, delete on public.agua_registros   to authenticated;
grant select, insert, update, delete on public.peso_registros   to authenticated;

-- ════════════════════════════════════════════════════════════
--  FOTOS DO DIÁRIO
--
--  Privado, pelo mesmo motivo de `progresso-fotos`: foto do prato de
--  alguém com URL adivinhável é vazamento. Caminho '<aluno_id>/<arquivo>'
--  — a pasta é a permissão.
-- ════════════════════════════════════════════════════════════

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('diario-fotos', 'diario-fotos', false, 10485760,
        array['image/jpeg','image/png','image/webp','image/heic'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "diario-fotos: o aluno e o profissional veem" on storage.objects;
create policy "diario-fotos: o aluno e o profissional veem"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'diario-fotos'
    and public.aluno_e_meu(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "diario-fotos: o aluno envia" on storage.objects;
create policy "diario-fotos: o aluno envia"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'diario-fotos'
    and exists (select 1 from public.alunos a
                 where a.id = ((storage.foldername(name))[1])::uuid
                   and a.user_id = auth.uid())
  );

drop policy if exists "diario-fotos: o aluno apaga" on storage.objects;
create policy "diario-fotos: o aluno apaga"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'diario-fotos'
    and exists (select 1 from public.alunos a
                 where a.id = ((storage.foldername(name))[1])::uuid
                   and a.user_id = auth.uid())
  );

notify pgrst, 'reload schema';

-- Conferência: as três tabelas novas, todas com RLS ligado.
select relname, relrowsecurity
  from pg_class
 where relname in ('diario_registros', 'agua_registros', 'peso_registros')
 order by relname;
