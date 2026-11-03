-- ════════════════════════════════════════════════════════════
--  0022 — O que o aluno comeu, bio do profissional e cupons
--
--  CONSUMO
--  O aluno pode trocar, tirar ou acrescentar alimentos na refeição do
--  dia. `refeicoes_registro.itens` guarda o que ele comeu de fato; nulo
--  = comeu o que o plano diz. Cada item leva os nutrientes por 100 g
--  copiados do alimento — como `diario_registros.titulo`, o registro de
--  março não pode mudar porque alguém editou o alimento em abril:
--    [{ "alimento_id", "nome", "gramas", "kcal", "proteina",
--       "carboidrato", "gordura", "fibra", "origem", "item_plano_id" }]
--  `origem`: 'plano' (como prescrito), 'troca' (no lugar de um item do
--  plano) ou 'extra' (acrescentado). Quem escreve é a policy que já
--  existe no 0010: só o próprio aluno.
--
--  BIO
--  Texto e formações que o aluno vê ao tocar no profissional. Ficam em
--  `profiles`, que o aluno já lê (policy do 0001).
--
--  CUPONS
--  Descontos que o profissional oferece aos alunos dele: de uma loja
--  parceira ou de outro profissional do PHD (`indicado_id`). O aluno lê
--  os cupons ativos do próprio profissional. O perfil do indicado não é
--  do tenant do aluno; ele chega por `perfil_publico`, que só abre o que
--  é de vitrine e só para quem tem motivo de ver.
--
--  Depende do 0001, 0008 e 0010. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- ── Consumo ─────────────────────────────────────────────────
alter table public.refeicoes_registro add column if not exists itens jsonb;

-- ── Bio ─────────────────────────────────────────────────────
alter table public.profiles add column if not exists bio text;
alter table public.profiles add column if not exists formacoes jsonb not null default '[]'::jsonb;

-- ── Cupons ──────────────────────────────────────────────────
create table if not exists public.cupons (
  id              uuid primary key default gen_random_uuid(),
  profissional_id uuid not null references public.profiles(id) on delete cascade,
  titulo          text not null,
  descricao       text,
  codigo          text,
  link            text,
  indicado_id     uuid references public.profiles(id) on delete set null,
  valido_ate      date,
  ativo           boolean not null default true,
  ordem           integer not null default 0,
  criado_em       timestamptz not null default now(),
  constraint cupons_indica_outro_chk check (indicado_id is distinct from profissional_id)
);

create index if not exists cupons_idx on public.cupons (profissional_id, ordem);

alter table public.cupons enable row level security;

drop policy if exists "cupons: o dono cuida" on public.cupons;
create policy "cupons: o dono cuida"
  on public.cupons for all to authenticated
  using (profissional_id = auth.uid())
  with check (profissional_id = auth.uid());

-- Vencido ou desligado não aparece para o aluno: o profissional ainda vê
-- (pela policy de cima) e pode reativar.
drop policy if exists "cupons: os alunos do dono leem" on public.cupons;
create policy "cupons: os alunos do dono leem"
  on public.cupons for select to authenticated
  using (
    profissional_id = public.meu_personal_id()
    and ativo
    and (valido_ate is null or valido_ate >= current_date)
  );

grant select, insert, update, delete on public.cupons to authenticated;

-- ── Perfil público ──────────────────────────────────────────
-- O que um aluno pode ver de um profissional: o dele, ou um indicado num
-- cupom ativo do dele. Nada de e-mail, CPF ou marca: só a vitrine.
-- `security definer` porque o indicado é de outro tenant e a policy de
-- `profiles` (corretamente) não o mostra.
create or replace function public.perfil_publico(p_id uuid)
returns table (
  id uuid, nome text, avatar_url text, cref text, crn text,
  bio text, formacoes jsonb, whatsapp text
)
language sql stable security definer set search_path = public as $$
  select p.id, p.nome, p.avatar_url, p.cref, p.crn, p.bio, p.formacoes, p.whatsapp
    from public.profiles p
   where p.id = p_id
     and p.role = 'personal'
     and (
       p.id = auth.uid()
       or p.id = public.meu_personal_id()
       or exists (
         select 1 from public.cupons c
          where c.indicado_id = p.id
            and (
              -- O dono do cupom vê o indicado mesmo com o cupom desligado.
              c.profissional_id = auth.uid()
              or (c.profissional_id = public.meu_personal_id()
                  and c.ativo
                  and (c.valido_ate is null or c.valido_ate >= current_date))
            )
       )
     );
$$;

revoke all on function public.perfil_publico(uuid) from public;
grant execute on function public.perfil_publico(uuid) to authenticated;

-- ── Achar um profissional para indicar ──────────────────────
-- Por e-mail exato, e não por busca de nome: indicar é para quem você
-- conhece, e uma busca aberta entregaria a lista de todos os
-- profissionais da plataforma a qualquer um.
create or replace function public.profissional_por_email(p_email text)
returns table (id uuid, nome text, avatar_url text, cref text, crn text)
language sql stable security definer set search_path = public as $$
  select p.id, p.nome, p.avatar_url, p.cref, p.crn
    from public.profiles p
   where lower(p.email) = lower(btrim(p_email))
     and p.role = 'personal'
     and p.id <> auth.uid()
     and public.meu_role() = 'personal';
$$;

revoke all on function public.profissional_por_email(text) from public;
grant execute on function public.profissional_por_email(text) to authenticated;

notify pgrst, 'reload schema';

-- Conferência: as colunas novas e a tabela com RLS ligado.
select
  (select count(*) from information_schema.columns
    where table_name = 'refeicoes_registro' and column_name = 'itens')   as consumo,
  (select count(*) from information_schema.columns
    where table_name = 'profiles' and column_name in ('bio', 'formacoes')) as bio,
  (select relrowsecurity from pg_class where relname = 'cupons')          as cupons_rls;
