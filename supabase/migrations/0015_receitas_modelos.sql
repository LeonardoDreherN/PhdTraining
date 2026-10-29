-- ════════════════════════════════════════════════════════════
--  0015 — Receitas e modelos de plano
--
--  RECEITAS
--  Biblioteca do profissional: ingredientes da base de alimentos, com
--  gramas, e o rendimento em porções. Os macros de uma porção saem da
--  soma dos ingredientes — a mesma conta do plano, sem tabela à parte
--  que poderia divergir.
--
--  Uma receita entra numa refeição por `refeicao_receitas`, com quantas
--  porções. Entra no total da refeição como qualquer alimento. O aluno
--  lê a receita do profissional dele (é como `alimentos` do tenant).
--
--  MODELOS
--  Um plano salvo para reaproveitar: "Hipertrofia 2.400 kcal",
--  "Low carb". Guardado como fotografia em `conteudo` (jsonb), não como
--  um plano sem aluno: as policies de refeições e itens dependem do
--  aluno do plano, e afrouxá-las para aceitar "plano de ninguém" seria
--  abrir um caminho de leitura entre tenants. Aplicar o modelo cria um
--  plano normal, do aluno, que segue as regras de sempre (inclusive a
--  do CRN para gravar).
--
--  Depende do 0010. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create table if not exists public.receitas (
  id                 uuid primary key default gen_random_uuid(),
  profissional_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome               text not null,
  rendimento_porcoes numeric(5, 2) not null default 1 check (rendimento_porcoes > 0),
  tempo_minutos      integer check (tempo_minutos is null or tempo_minutos >= 0),
  modo_preparo       text,
  criado_em          timestamptz not null default now(),
  atualizado_em      timestamptz not null default now()
);

create index if not exists receitas_profissional_idx
  on public.receitas (profissional_id, nome);

create table if not exists public.receita_ingredientes (
  id              uuid primary key default gen_random_uuid(),
  receita_id      uuid not null references public.receitas(id) on delete cascade,
  -- `restrict`: apagar um alimento que está em receita quebraria a conta
  -- de todos os planos que a usam.
  alimento_id     uuid not null references public.alimentos(id) on delete restrict,
  quantidade_g    numeric(8, 2) not null check (quantidade_g > 0),
  medida_exibicao text,
  ordem           integer not null default 0
);

create index if not exists receita_ingredientes_idx
  on public.receita_ingredientes (receita_id, ordem);

create table if not exists public.refeicao_receitas (
  id          uuid primary key default gen_random_uuid(),
  refeicao_id uuid not null references public.plano_refeicoes(id) on delete cascade,
  receita_id  uuid not null references public.receitas(id) on delete restrict,
  porcoes     numeric(5, 2) not null default 1 check (porcoes > 0),
  ordem       integer not null default 0
);

create index if not exists refeicao_receitas_idx
  on public.refeicao_receitas (refeicao_id, ordem);

create table if not exists public.planos_modelos (
  id              uuid primary key default gen_random_uuid(),
  profissional_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  nome            text not null,
  objetivo        text,
  conteudo        jsonb not null,
  criado_em       timestamptz not null default now()
);

create index if not exists planos_modelos_idx
  on public.planos_modelos (profissional_id, criado_em desc);

-- ════════════════════════════════════════════════════════════
--  RLS
-- ════════════════════════════════════════════════════════════

alter table public.receitas             enable row level security;
alter table public.receita_ingredientes enable row level security;
alter table public.refeicao_receitas    enable row level security;
alter table public.planos_modelos       enable row level security;

-- ── receitas: o dono escreve, o dono e os alunos dele leem ──
drop policy if exists "receitas: leitura no tenant" on public.receitas;
create policy "receitas: leitura no tenant"
  on public.receitas for select to authenticated
  using (profissional_id = auth.uid() or profissional_id = public.meu_personal_id());

drop policy if exists "receitas: escrita do dono" on public.receitas;
create policy "receitas: escrita do dono"
  on public.receitas for all to authenticated
  using (profissional_id = auth.uid())
  with check (profissional_id = auth.uid());

drop policy if exists "receita_ingredientes: segue a receita" on public.receita_ingredientes;
create policy "receita_ingredientes: segue a receita"
  on public.receita_ingredientes for select to authenticated
  using (exists (select 1 from public.receitas r
                  where r.id = receita_ingredientes.receita_id
                    and (r.profissional_id = auth.uid()
                         or r.profissional_id = public.meu_personal_id())));

drop policy if exists "receita_ingredientes: escrita do dono" on public.receita_ingredientes;
create policy "receita_ingredientes: escrita do dono"
  on public.receita_ingredientes for all to authenticated
  using (exists (select 1 from public.receitas r
                  where r.id = receita_ingredientes.receita_id and r.profissional_id = auth.uid()))
  with check (exists (select 1 from public.receitas r
                       where r.id = receita_ingredientes.receita_id and r.profissional_id = auth.uid()));

-- ── receita na refeição: as mesmas regras de `refeicao_itens` ──
drop policy if exists "refeicao_receitas: segue a refeição" on public.refeicao_receitas;
create policy "refeicao_receitas: segue a refeição"
  on public.refeicao_receitas for select to authenticated
  using (exists (select 1 from public.plano_refeicoes r
                  join public.planos_alimentares p on p.id = r.plano_id
                 where r.id = refeicao_receitas.refeicao_id
                   and public.aluno_e_meu(p.aluno_id)));

drop policy if exists "refeicao_receitas: escrita de quem tem CRN" on public.refeicao_receitas;
create policy "refeicao_receitas: escrita de quem tem CRN"
  on public.refeicao_receitas for all to authenticated
  using (public.meu_crn() is not null and exists (
          select 1 from public.plano_refeicoes r
           join public.planos_alimentares p on p.id = r.plano_id
           join public.alunos a on a.id = p.aluno_id
          where r.id = refeicao_receitas.refeicao_id and a.personal_id = auth.uid()))
  with check (public.meu_crn() is not null and exists (
          select 1 from public.plano_refeicoes r
           join public.planos_alimentares p on p.id = r.plano_id
           join public.alunos a on a.id = p.aluno_id
          where r.id = refeicao_receitas.refeicao_id and a.personal_id = auth.uid()));

-- ── modelos: só do dono ─────────────────────────────────────
drop policy if exists "planos_modelos: só o dono" on public.planos_modelos;
create policy "planos_modelos: só o dono"
  on public.planos_modelos for all to authenticated
  using (profissional_id = auth.uid())
  with check (profissional_id = auth.uid());

grant select, insert, update, delete on public.receitas             to authenticated;
grant select, insert, update, delete on public.receita_ingredientes to authenticated;
grant select, insert, update, delete on public.refeicao_receitas    to authenticated;
grant select, insert, update, delete on public.planos_modelos       to authenticated;

notify pgrst, 'reload schema';

select relname, relrowsecurity
  from pg_class
 where relname in ('receitas', 'receita_ingredientes', 'refeicao_receitas', 'planos_modelos')
 order by relname;
