-- ════════════════════════════════════════════════════════════
--  0009 — Sessão de avaliação, cardio e postural
--
--  Até aqui cada teste morava numa tabela solta, e "a avaliação de
--  março" não existia como coisa: era o personal que lembrava que a
--  dobra e o banco de Wells foram no mesmo dia. Isto cria a sessão.
--
--  A sessão é a DATA. Um aluno tem no máximo uma avaliação por dia, e
--  todo teste com aquele `aluno_id` e aquela `data_avaliacao` pertence
--  a ela. Escolhemos isso em vez de uma coluna `avaliacao_id` nos
--  testes por três razões:
--    • os testes antigos já ficam agrupados, sem migrar dado nenhum
--    • os formulários antigos continuam funcionando sem saber da sessão
--    • não existe teste "órfão": se tem data, tem sessão (o gatilho
--      abaixo cria a sessão quando um teste aparece num dia novo)
--
--  Depende do 0001. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- ── Sessão ──────────────────────────────────────────────────
-- Guarda o que é da avaliação como um todo e não de um teste: medidas
-- básicas e sinais vitais. Peso, estatura, cintura e quadril também
-- existem na dobra e na bioimpedância; quando estão vazios aqui, o app
-- usa os do teste do mesmo dia.
create table if not exists public.avaliacoes (
  id                uuid primary key default gen_random_uuid(),
  aluno_id          uuid not null references public.alunos(id) on delete cascade,
  data_avaliacao    date not null default current_date,
  peso              numeric,
  estatura          numeric,          -- cm
  cintura           numeric,          -- cm
  quadril           numeric,          -- cm
  pa_sistolica      integer,          -- mmHg
  pa_diastolica     integer,          -- mmHg
  fc_repouso        integer,          -- bpm
  observacoes       text,
  proxima_avaliacao date,
  criado_em         timestamptz not null default now(),
  atualizado_em     timestamptz not null default now(),
  unique (aluno_id, data_avaliacao)
);

create index if not exists avaliacoes_idx
  on public.avaliacoes (aluno_id, data_avaliacao desc);

-- ── Cardiorrespiratório ─────────────────────────────────────
-- Um resultado por protocolo por dia. O VO₂máx é gravado já calculado
-- para que o relatório e a evolução não dependam da fórmula estar igual
-- no app daqui a dois anos.
create table if not exists public.avaliacao_cardio (
  id             uuid primary key default gen_random_uuid(),
  aluno_id       uuid not null references public.alunos(id) on delete cascade,
  data_avaliacao date not null default current_date,
  protocolo      text not null,
  genero         text,
  idade          integer,
  peso           numeric,
  distancia_m    numeric,
  tempo_seg      integer,
  fc_final       integer,
  vo2max         numeric,
  classificacao  text,
  observacoes    text,
  criado_em      timestamptz not null default now(),
  unique (aluno_id, data_avaliacao, protocolo)
);

create index if not exists av_cardio_idx
  on public.avaliacao_cardio (aluno_id, data_avaliacao desc);

-- ── Postural ────────────────────────────────────────────────
-- As fotos vão para o bucket privado `progresso-fotos`, em
-- '<aluno_id>/postural/<arquivo>': a primeira pasta é o aluno, que é o
-- que a policy do bucket confere. Aqui fica o CAMINHO, não a URL — a
-- URL assinada expira.
--
-- `desvios` é { "chave_do_desvio": "leve" | "moderado" | "acentuado" }.
-- A lista de desvios mora no app; ausência da chave = sem desvio.
create table if not exists public.avaliacao_postural (
  id             uuid primary key default gen_random_uuid(),
  aluno_id       uuid not null references public.alunos(id) on delete cascade,
  data_avaliacao date not null default current_date,
  foto_frente    text,
  foto_costas    text,
  foto_lado_dir  text,
  foto_lado_esq  text,
  desvios        jsonb not null default '{}'::jsonb,
  observacoes    text,
  criado_em      timestamptz not null default now(),
  unique (aluno_id, data_avaliacao)
);

-- ════════════════════════════════════════════════════════════
--  RLS
--
--  Leitura: o personal dono e o próprio aluno (que vê a avaliação dele).
--  Escrita: só o personal. As tabelas de teste do 0001 deixam o aluno
--  escrever por herança da policy genérica; nas novas não repetimos
--  isso — o aluno não tem por que editar a própria pressão arterial.
-- ════════════════════════════════════════════════════════════

alter table public.avaliacoes         enable row level security;
alter table public.avaliacao_cardio   enable row level security;
alter table public.avaliacao_postural enable row level security;

do $$
declare t text;
begin
  foreach t in array array['avaliacoes', 'avaliacao_cardio', 'avaliacao_postural'] loop
    execute format('drop policy if exists %I on public.%I', t || ': leitura', t);
    execute format(
      'create policy %I on public.%I for select to authenticated '
      'using (public.aluno_e_meu(aluno_id))',
      t || ': leitura', t);

    execute format('drop policy if exists %I on public.%I', t || ': escrita do personal', t);
    execute format(
      'create policy %I on public.%I for all to authenticated '
      'using (exists (select 1 from public.alunos a '
      '                where a.id = %I.aluno_id and a.personal_id = auth.uid())) '
      'with check (exists (select 1 from public.alunos a '
      '                     where a.id = %I.aluno_id and a.personal_id = auth.uid()))',
      t || ': escrita do personal', t, t, t);
  end loop;
end $$;

grant select, insert, update, delete on public.avaliacoes         to authenticated;
grant select, insert, update, delete on public.avaliacao_cardio   to authenticated;
grant select, insert, update, delete on public.avaliacao_postural to authenticated;

-- ════════════════════════════════════════════════════════════
--  Toda data com teste tem sessão
--
--  `security definer` porque a policy de escrita de `avaliacoes` é só do
--  personal, e as tabelas do 0001 ainda aceitam escrita do aluno: sem
--  isso, um insert legítimo do aluno quebraria aqui. O gatilho só copia
--  (aluno_id, data) de uma linha que já passou pelo RLS da tabela dela.
-- ════════════════════════════════════════════════════════════

create or replace function public.garante_sessao_avaliacao()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.data_avaliacao is not null then
    insert into public.avaliacoes (aluno_id, data_avaliacao)
    values (new.aluno_id, new.data_avaliacao)
    on conflict (aluno_id, data_avaliacao) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.garante_sessao_avaliacao() from public;

do $$
declare t text;
begin
  foreach t in array array[
    'avaliacao_morfologica_dobras',
    'avaliacao_morfologica_bioimpedancia',
    'avaliacao_neuromotores_flexibilidade',
    'avaliacao_neuromotores_resistencia',
    'avaliacao_neuromotores_impulsao',
    'avaliacao_neuromotores_carga',
    'avaliacao_cardio',
    'avaliacao_postural'
  ] loop
    execute format('drop trigger if exists garante_sessao on public.%I', t);
    execute format(
      'create trigger garante_sessao after insert or update of data_avaliacao '
      'on public.%I for each row execute function public.garante_sessao_avaliacao()', t);

    -- Os testes que já existem ganham sessão agora.
    execute format(
      'insert into public.avaliacoes (aluno_id, data_avaliacao) '
      'select distinct aluno_id, data_avaliacao from public.%I '
      'where data_avaliacao is not null '
      'on conflict (aluno_id, data_avaliacao) do nothing', t);
  end loop;
end $$;

notify pgrst, 'reload schema';

-- Conferência: deve listar as três tabelas com RLS ligado.
select relname, relrowsecurity
  from pg_class
 where relname in ('avaliacoes', 'avaliacao_cardio', 'avaliacao_postural');
