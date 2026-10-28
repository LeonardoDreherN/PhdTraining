-- ════════════════════════════════════════════════════════════
--  0010 — Dieta: alimentos, plano alimentar e registro
--
--  O recurso já estava previsto: `plataforma_planos.recursos` tem a
--  flag "dieta" desde o 0002, e `personal_planos.inclui_dieta` desde
--  o 0003. Faltava o que ela liga.
--
--  QUEM PODE PRESCREVER
--  No Brasil a prescrição dietética é privativa do nutricionista
--  (Lei 8.234/91, art. 4º). Mas o mesmo profissional costuma ter CREF
--  e CRN — é o caso aqui. Separar em dois papéis obrigaria a pessoa a
--  manter duas contas para fazer um trabalho só, então o modelo é:
--  um perfil, dois registros. Quem tem `crn` preenchido prescreve;
--  quem não tem, não — e o banco é que decide isso, não a interface.
--
--  O plano guarda o CRN de quem assinou em coluna própria, não só por
--  referência: se a pessoa mudar de registro, o plano de março tem de
--  continuar mostrando sob qual CRN foi assinado.
--
--  Depende do 0001. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

alter table public.profiles add column if not exists crn text;
comment on column public.profiles.crn is
  'Registro no Conselho Regional de Nutricionistas. Preenchido = pode '
  'prescrever dieta. Sai no PDF do plano alimentar.';

-- ── Quem pode prescrever ────────────────────────────────────
-- `security definer` pelo mesmo motivo de `meu_role` no 0008: uma
-- policy que lê `profiles` sem isso dispara recursão infinita.
create or replace function public.meu_crn()
returns text
language sql stable security definer set search_path = public as $$
  select nullif(btrim(coalesce(crn, '')), '')
    from public.profiles where id = auth.uid();
$$;
revoke all on function public.meu_crn() from public;
grant execute on function public.meu_crn() to authenticated;

-- ════════════════════════════════════════════════════════════
--  ALIMENTOS
--
--  `oficial` = veio de tabela de composição (TACO/IBGE) e vale para
--  todo mundo. `profissional_id` preenchido = criado por um
--  profissional, visível só no tenant dele — é onde entram whey de
--  marca, marmita e receita da casa, que tabela oficial não cobre.
--
--  Os valores são SEMPRE por 100 g de parte comestível, que é como a
--  TACO publica. Converter na exibição é trivial; guardar em porções
--  diferentes por alimento torna qualquer soma impossível.
-- ════════════════════════════════════════════════════════════

create table if not exists public.alimentos (
  id              uuid primary key default gen_random_uuid(),

  -- Código na tabela de origem, quando houver: permite reimportar a
  -- tabela oficial sem duplicar linha.
  codigo_origem   text,
  fonte           text not null default 'manual',
  oficial         boolean not null default false,
  profissional_id uuid references auth.users(id) on delete cascade,

  nome            text not null,
  grupo           text,
  marca           text,

  -- Medida caseira de referência: "1 colher de sopa cheia", e quantos
  -- gramas ela tem. É assim que o aluno entende a quantidade — ninguém
  -- pesa 23 g de arroz na correria da manhã.
  medida_caseira  text,
  medida_gramas   numeric,

  -- Tudo por 100 g.
  kcal            numeric not null default 0,
  proteina        numeric not null default 0,
  carboidrato     numeric not null default 0,
  gordura         numeric not null default 0,
  fibra           numeric,
  sodio           numeric,   -- mg

  criado_em       timestamptz not null default now(),

  constraint alimentos_escopo_chk check (
    (oficial and profissional_id is null)
    or (not oficial and profissional_id is not null)
  )
);

-- Índice simples, e não parcial: `on conflict` com índice parcial exige
-- que o predicado seja repetido igualzinho na inserção, o que quebra fácil.
-- Como o Postgres trata nulos como distintos, os alimentos do profissional
-- (que têm `codigo_origem` nulo) continuam podendo repetir à vontade.
create unique index if not exists alimentos_origem_key
  on public.alimentos (fonte, codigo_origem);

create index if not exists alimentos_busca_idx
  on public.alimentos (lower(nome));

-- ════════════════════════════════════════════════════════════
--  PLANO ALIMENTAR
-- ════════════════════════════════════════════════════════════

create table if not exists public.planos_alimentares (
  id               uuid primary key default gen_random_uuid(),
  aluno_id         uuid not null references public.alunos(id) on delete cascade,

  -- Quem assinou, e sob qual registro.
  autor_id         uuid references auth.users(id) on delete set null,
  crn_assinatura   text,
  assinado_em      timestamptz,

  nome             text not null,
  objetivo         text,          -- emagrecimento, manutencao, hipertrofia
  data_inicio      date not null default current_date,
  data_fim         date,
  ativo            boolean not null default true,

  -- Gasto energético e metas, gravados já calculados: a fórmula pode
  -- mudar no app, e o plano de março tem de continuar dizendo o que
  -- dizia em março. `formula_tmb` registra qual foi usada.
  formula_tmb      text,
  tmb              numeric,
  fator_atividade  numeric,
  get              numeric,
  meta_kcal        numeric,
  meta_proteina    numeric,       -- g
  meta_carboidrato numeric,       -- g
  meta_gordura     numeric,       -- g
  agua_ml          numeric,

  observacoes      text,
  criado_em        timestamptz not null default now(),
  atualizado_em    timestamptz not null default now()
);

create index if not exists planos_alimentares_aluno_idx
  on public.planos_alimentares (aluno_id, data_inicio desc);

-- Só um plano ativo por aluno: dois ativos é a receita para o aluno
-- seguir o errado.
create unique index if not exists planos_alimentares_um_ativo
  on public.planos_alimentares (aluno_id) where ativo;

-- ── Refeições ───────────────────────────────────────────────
create table if not exists public.plano_refeicoes (
  id          uuid primary key default gen_random_uuid(),
  plano_id    uuid not null references public.planos_alimentares(id) on delete cascade,
  nome        text not null,          -- "Café da manhã", "Pré-treino"
  horario     time,
  ordem       integer not null default 0,
  observacoes text,
  criado_em   timestamptz not null default now()
);

create index if not exists plano_refeicoes_idx
  on public.plano_refeicoes (plano_id, ordem);

-- ── Itens ───────────────────────────────────────────────────
--
-- `grupo_substituicao`: itens da mesma refeição com o mesmo valor são
-- intercambiáveis — "arroz OU macarrão OU batata". Sem substituição a
-- dieta é abandonada na primeira vez que falta o alimento em casa, e é
-- a primeira coisa que todo nutricionista pede.
create table if not exists public.refeicao_itens (
  id                 uuid primary key default gen_random_uuid(),
  refeicao_id        uuid not null references public.plano_refeicoes(id) on delete cascade,
  alimento_id        uuid not null references public.alimentos(id) on delete restrict,
  quantidade_g       numeric not null,
  medida_exibicao    text,
  grupo_substituicao uuid,
  ordem              integer not null default 0,
  observacoes        text,
  criado_em          timestamptz not null default now()
);

create index if not exists refeicao_itens_idx
  on public.refeicao_itens (refeicao_id, ordem);

-- ── Registro do aluno ───────────────────────────────────────
-- Uma linha por refeição por dia. Sem `plano_id`: a refeição já leva
-- ao plano, e duplicar a referência abriria espaço para divergirem.
create table if not exists public.refeicoes_registro (
  id          uuid primary key default gen_random_uuid(),
  aluno_id    uuid not null references public.alunos(id) on delete cascade,
  refeicao_id uuid not null references public.plano_refeicoes(id) on delete cascade,
  data        date not null default current_date,
  feita       boolean not null default true,
  observacoes text,
  criado_em   timestamptz not null default now(),
  unique (aluno_id, refeicao_id, data)
);

create index if not exists refeicoes_registro_idx
  on public.refeicoes_registro (aluno_id, data desc);

-- ════════════════════════════════════════════════════════════
--  RLS
--
--  Leitura: quem já enxerga o aluno (personal dono e o próprio aluno),
--  via `aluno_e_meu` do 0001.
--  Escrita do plano: o dono do aluno QUE TENHA CRN. É a regra legal
--  aplicada no banco — a interface pode esconder o botão, mas quem
--  garante é isto.
-- ════════════════════════════════════════════════════════════

alter table public.alimentos           enable row level security;
alter table public.planos_alimentares  enable row level security;
alter table public.plano_refeicoes     enable row level security;
alter table public.refeicao_itens      enable row level security;
alter table public.refeicoes_registro  enable row level security;

-- ── alimentos ───────────────────────────────────────────────
drop policy if exists "alimentos: oficiais e os do meu tenant" on public.alimentos;
create policy "alimentos: oficiais e os do meu tenant"
  on public.alimentos for select to authenticated
  using (
    oficial
    or profissional_id = auth.uid()
    or profissional_id = public.meu_personal_id()
  );

drop policy if exists "alimentos: escrita do dono" on public.alimentos;
create policy "alimentos: escrita do dono"
  on public.alimentos for all to authenticated
  using (profissional_id = auth.uid() and not oficial)
  with check (profissional_id = auth.uid() and not oficial);

drop policy if exists "alimentos: admin cuida dos oficiais" on public.alimentos;
create policy "alimentos: admin cuida dos oficiais"
  on public.alimentos for all to authenticated
  using (public.eh_admin_plataforma())
  with check (public.eh_admin_plataforma());

-- ── planos ──────────────────────────────────────────────────
drop policy if exists "planos_alimentares: leitura" on public.planos_alimentares;
create policy "planos_alimentares: leitura"
  on public.planos_alimentares for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "planos_alimentares: escrita de quem tem CRN" on public.planos_alimentares;
create policy "planos_alimentares: escrita de quem tem CRN"
  on public.planos_alimentares for all to authenticated
  using (
    public.meu_crn() is not null
    and exists (select 1 from public.alunos a
                 where a.id = planos_alimentares.aluno_id
                   and a.personal_id = auth.uid())
  )
  with check (
    public.meu_crn() is not null
    and exists (select 1 from public.alunos a
                 where a.id = planos_alimentares.aluno_id
                   and a.personal_id = auth.uid())
  );

-- ── refeições e itens: herdam o plano ───────────────────────
drop policy if exists "plano_refeicoes: segue o plano" on public.plano_refeicoes;
create policy "plano_refeicoes: segue o plano"
  on public.plano_refeicoes for select to authenticated
  using (exists (select 1 from public.planos_alimentares p
                  where p.id = plano_refeicoes.plano_id
                    and public.aluno_e_meu(p.aluno_id)));

drop policy if exists "plano_refeicoes: escrita de quem tem CRN" on public.plano_refeicoes;
create policy "plano_refeicoes: escrita de quem tem CRN"
  on public.plano_refeicoes for all to authenticated
  using (public.meu_crn() is not null and exists (
          select 1 from public.planos_alimentares p
           join public.alunos a on a.id = p.aluno_id
          where p.id = plano_refeicoes.plano_id and a.personal_id = auth.uid()))
  with check (public.meu_crn() is not null and exists (
          select 1 from public.planos_alimentares p
           join public.alunos a on a.id = p.aluno_id
          where p.id = plano_refeicoes.plano_id and a.personal_id = auth.uid()));

drop policy if exists "refeicao_itens: segue a refeição" on public.refeicao_itens;
create policy "refeicao_itens: segue a refeição"
  on public.refeicao_itens for select to authenticated
  using (exists (select 1 from public.plano_refeicoes r
                  join public.planos_alimentares p on p.id = r.plano_id
                 where r.id = refeicao_itens.refeicao_id
                   and public.aluno_e_meu(p.aluno_id)));

drop policy if exists "refeicao_itens: escrita de quem tem CRN" on public.refeicao_itens;
create policy "refeicao_itens: escrita de quem tem CRN"
  on public.refeicao_itens for all to authenticated
  using (public.meu_crn() is not null and exists (
          select 1 from public.plano_refeicoes r
           join public.planos_alimentares p on p.id = r.plano_id
           join public.alunos a on a.id = p.aluno_id
          where r.id = refeicao_itens.refeicao_id and a.personal_id = auth.uid()))
  with check (public.meu_crn() is not null and exists (
          select 1 from public.plano_refeicoes r
           join public.planos_alimentares p on p.id = r.plano_id
           join public.alunos a on a.id = p.aluno_id
          where r.id = refeicao_itens.refeicao_id and a.personal_id = auth.uid()));

-- ── registro: quem marca é o aluno ──────────────────────────
drop policy if exists "refeicoes_registro: leitura" on public.refeicoes_registro;
create policy "refeicoes_registro: leitura"
  on public.refeicoes_registro for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "refeicoes_registro: o aluno marca a sua" on public.refeicoes_registro;
create policy "refeicoes_registro: o aluno marca a sua"
  on public.refeicoes_registro for all to authenticated
  using (exists (select 1 from public.alunos a
                  where a.id = refeicoes_registro.aluno_id and a.user_id = auth.uid()))
  with check (exists (select 1 from public.alunos a
                       where a.id = refeicoes_registro.aluno_id and a.user_id = auth.uid()));

grant select, insert, update, delete on public.alimentos          to authenticated;
grant select, insert, update, delete on public.planos_alimentares to authenticated;
grant select, insert, update, delete on public.plano_refeicoes    to authenticated;
grant select, insert, update, delete on public.refeicao_itens     to authenticated;
grant select, insert, update, delete on public.refeicoes_registro to authenticated;

notify pgrst, 'reload schema';

-- Conferência: as cinco tabelas novas, todas com RLS ligado.
select relname, relrowsecurity
  from pg_class
 where relname in ('alimentos','planos_alimentares','plano_refeicoes',
                   'refeicao_itens','refeicoes_registro')
 order by relname;
