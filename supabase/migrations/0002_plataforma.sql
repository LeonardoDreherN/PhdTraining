-- ============================================================
-- 0002 — A plataforma
--
-- Os planos que VOCÊ vende ao personal e a assinatura dele.
-- Depende do 0001 (usa `eh_admin_plataforma`).
--
-- Seguro rodar mais de uma vez.
-- ============================================================

create table if not exists public.plataforma_planos (
  id                    uuid primary key default gen_random_uuid(),
  slug                  text not null unique,
  nome                  text not null,
  descricao             text,
  preco_mensal_centavos integer not null check (preco_mensal_centavos >= 0),
  preco_anual_centavos  integer          check (preco_anual_centavos  >= 0),
  limite_alunos         integer,          -- null = ilimitado
  recursos              jsonb   not null default '{}'::jsonb,
  ativo                 boolean not null default true,
  ordem                 integer not null default 0,
  criado_em             timestamptz not null default now()
);

comment on column public.plataforma_planos.recursos is
  'Flags de recurso: {"dieta": true, "marca_propria": true, "biblioteca_oficial": true}';

create table if not exists public.plataforma_assinaturas (
  id                      uuid primary key default gen_random_uuid(),
  personal_id             uuid not null references auth.users(id) on delete cascade,
  plano_id                uuid not null references public.plataforma_planos(id),
  status                  text not null default 'trial'
    check (status in ('trial','ativa','inadimplente','suspensa','cancelada')),
  ciclo                   text not null default 'mensal' check (ciclo in ('mensal','anual')),
  trial_termina_em        date,
  periodo_inicio          date not null default current_date,
  periodo_fim             date,
  cancelada_em            timestamptz,
  motivo_cancelamento     text,
  gateway                 text,
  gateway_subscription_id text,
  criado_em               timestamptz not null default now(),
  atualizado_em           timestamptz not null default now()
);

-- Um personal tem no máximo uma assinatura viva.
create unique index if not exists plataforma_assinaturas_uma_viva
  on public.plataforma_assinaturas (personal_id) where status <> 'cancelada';

create index if not exists plataforma_assinaturas_status_idx
  on public.plataforma_assinaturas (status, periodo_fim);

-- Quantos alunos ativos o personal tem — é contra isto que o limite do
-- plano é conferido na hora de cadastrar mais um.
create or replace function public.alunos_ativos(p_personal_id uuid)
returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.alunos
   where personal_id = p_personal_id and ativo;
$$;

revoke all on function public.alunos_ativos(uuid) from public;
grant execute on function public.alunos_ativos(uuid) to authenticated;

-- ── RLS ─────────────────────────────────────────────────────
alter table public.plataforma_planos      enable row level security;
alter table public.plataforma_assinaturas enable row level security;

drop policy if exists "planos: tabela de preços é pública" on public.plataforma_planos;
create policy "planos: tabela de preços é pública"
  on public.plataforma_planos for select to authenticated
  using (ativo or public.eh_admin_plataforma());

drop policy if exists "planos: só admin escreve" on public.plataforma_planos;
create policy "planos: só admin escreve"
  on public.plataforma_planos for all to authenticated
  using (public.eh_admin_plataforma())
  with check (public.eh_admin_plataforma());

drop policy if exists "assinatura: leitura própria" on public.plataforma_assinaturas;
create policy "assinatura: leitura própria"
  on public.plataforma_assinaturas for select to authenticated
  using (personal_id = auth.uid() or public.eh_admin_plataforma());

-- Ninguém escreve pelo app. Quem muda status é o webhook do gateway, que
-- roda com a service_role e não passa por RLS. Deixar fechado é o que
-- impede um personal de se promover para 'ativa' com um PATCH.
drop policy if exists "assinatura: só admin escreve" on public.plataforma_assinaturas;
create policy "assinatura: só admin escreve"
  on public.plataforma_assinaturas for all to authenticated
  using (public.eh_admin_plataforma())
  with check (public.eh_admin_plataforma());

-- ── Planos iniciais — ajuste os preços ──────────────────────
insert into public.plataforma_planos
  (slug, nome, descricao, preco_mensal_centavos, preco_anual_centavos, limite_alunos, recursos, ordem)
values
  ('starter', 'Starter', 'Para quem está começando',
   4990,  49900,  15,
   '{"treino": true, "dieta": false, "marca_propria": false, "biblioteca_oficial": true}'::jsonb, 1),
  ('pro', 'Pro', 'Treino e dieta, com a sua marca',
   9990,  99900,  60,
   '{"treino": true, "dieta": true, "marca_propria": true, "biblioteca_oficial": true}'::jsonb, 2),
  ('studio', 'Studio', 'Sem limite de alunos',
   19990, 199900, null,
   '{"treino": true, "dieta": true, "marca_propria": true, "biblioteca_oficial": true, "multi_treinador": true}'::jsonb, 3)
on conflict (slug) do nothing;
