-- ============================================================
-- 0003 — O financeiro do personal
--
-- A subconta dele no gateway, os planos que ele vende aos alunos, as
-- cobranças, a carteira e os saques.
--
-- Regra que atravessa o arquivo: o saldo verdadeiro mora no gateway.
-- Aqui é espelho, para a tela abrir rápido e para dar pra reconciliar.
-- Nenhuma tela soma `carteira_movimentos` para decidir quanto alguém
-- pode sacar — um estorno chegando fora de ordem já bastaria para
-- liberar dinheiro que não existe.
--
-- Depende do 0001. Seguro rodar mais de uma vez.
-- ============================================================

-- ════════════════════════════════════════════════════════════
--  SUBCONTA NO GATEWAY
-- ════════════════════════════════════════════════════════════

create table if not exists public.pagamento_contas (
  id                 uuid primary key default gen_random_uuid(),
  personal_id        uuid not null unique references auth.users(id) on delete cascade,
  gateway            text not null default 'asaas',

  -- 'subconta'      = criada sob a conta-plataforma, cadastro dentro do app
  -- 'conta_propria' = o personal já tinha conta e conectou a dele
  modo               text not null default 'subconta'
    check (modo in ('subconta','conta_propria')),

  gateway_account_id text,
  gateway_wallet_id  text,

  -- NUNCA a chave em si: só o nome do secret no Supabase Vault. O gateway
  -- devolve a apiKey da subconta UMA vez, na resposta da criação. Guardar
  -- isso numa coluna comum é o jeito mais rápido de vazar a conta bancária
  -- de todos os personais de uma vez.
  api_key_ref        text,

  -- ── Dados que o POST /accounts exige ──────────────────────
  -- Ficam aqui, e não em `profiles`, porque profiles é legível pelos
  -- alunos do personal (é de lá que sai a marca) e CPF, renda e endereço
  -- residencial não têm por que viajar junto.
  cpf_cnpj              text,
  razao_social          text,
  nome_responsavel      text,
  data_nascimento       date,
  tipo_empresa          text
    check (tipo_empresa in ('MEI','LIMITED','INDIVIDUAL','ASSOCIATION')),
  renda_mensal_centavos integer check (renda_mensal_centavos >= 0),
  email_cobranca        text,
  telefone_fixo         text,
  telefone_celular      text,
  cep                   text,
  logradouro            text,
  numero                text,
  complemento           text,
  bairro                text,
  cidade                text,
  uf                    char(2),

  -- ── KYC ───────────────────────────────────────────────────
  kyc_status             text not null default 'pendente'
    check (kyc_status in ('pendente','em_analise','aprovado','recusado')),
  kyc_pendencias         jsonb not null default '[]'::jsonb,
  documentos_enviados_em timestamptz,
  aprovado_em            timestamptz,
  recusado_motivo        text,
  pode_receber           boolean not null default false,
  pode_sacar             boolean not null default false,

  criado_em          timestamptz not null default now(),
  atualizado_em      timestamptz not null default now()
);

-- Um CPF/CNPJ não abre duas subcontas.
create unique index if not exists pagamento_contas_cpf_cnpj_key
  on public.pagamento_contas (cpf_cnpj) where cpf_cnpj is not null;

-- Idempotência: se a chamada de criação for repetida por timeout, isto
-- impede duas subcontas para o mesmo personal.
create unique index if not exists pagamento_contas_gateway_key
  on public.pagamento_contas (gateway, gateway_account_id)
  where gateway_account_id is not null;

-- Alimenta a barra da tela "Ativar recebimentos".
create or replace function public.progresso_cadastro_pagamento(p_personal_id uuid)
returns integer
language sql stable security definer set search_path = public as $$
  select coalesce((
    select (case when c.cpf_cnpj is not null and c.nome_responsavel is not null
                  and c.tipo_empresa is not null and c.renda_mensal_centavos is not null
                 then 1 else 0 end)
         + (case when c.cep is not null and c.logradouro is not null
                  and c.numero is not null and c.cidade is not null and c.uf is not null
                 then 1 else 0 end)
         + (case when c.documentos_enviados_em is not null then 1 else 0 end)
         + (case when c.kyc_status = 'aprovado' then 1 else 0 end)
      from public.pagamento_contas c where c.personal_id = p_personal_id
  ), 0);
$$;

revoke all on function public.progresso_cadastro_pagamento(uuid) from public;
grant execute on function public.progresso_cadastro_pagamento(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════
--  PLANOS QUE O PERSONAL VENDE
-- ════════════════════════════════════════════════════════════

create table if not exists public.personal_planos (
  id                 uuid primary key default gen_random_uuid(),
  personal_id        uuid not null references auth.users(id) on delete cascade,
  nome               text not null,
  descricao          text,
  periodicidade      text not null
    check (periodicidade in ('mensal','trimestral','semestral','anual','avulso')),
  preco_centavos     integer not null check (preco_centavos >= 0),

  -- Desconto para pagamento à vista no Pix. Em ticket alto o cartão come
  -- taxa + antecipação; devolver parte disso ao aluno costuma sair mais
  -- barato que receber parcelado. É decisão de cada personal, por isso é
  -- campo e não regra fixa.
  desconto_pix_centavos integer not null default 0 check (desconto_pix_centavos >= 0),

  inclui_treino      boolean not null default true,
  inclui_dieta       boolean not null default false,
  max_parcelas       smallint not null default 1 check (max_parcelas between 1 and 12),
  link_slug          text,
  ativo              boolean not null default true,
  criado_em          timestamptz not null default now()
);

create index if not exists personal_planos_idx on public.personal_planos (personal_id, ativo);

-- Slug do link de pagamento: /c/<slug>. Único no sistema todo.
create unique index if not exists personal_planos_link_slug_key
  on public.personal_planos (lower(link_slug)) where link_slug is not null;

create table if not exists public.aluno_assinaturas (
  id                      uuid primary key default gen_random_uuid(),
  personal_id             uuid not null references auth.users(id) on delete cascade,
  aluno_id                uuid not null references public.alunos(id) on delete cascade,
  plano_id                uuid not null references public.personal_planos(id),
  status                  text not null default 'ativa'
    check (status in ('ativa','inadimplente','pausada','cancelada','encerrada')),
  dia_vencimento          smallint check (dia_vencimento between 1 and 31),
  inicio                  date not null default current_date,
  fim                     date,
  gateway_subscription_id text,
  criado_em               timestamptz not null default now()
);

create index if not exists aluno_assinaturas_personal_idx on public.aluno_assinaturas (personal_id, status);
create index if not exists aluno_assinaturas_aluno_idx    on public.aluno_assinaturas (aluno_id, status);

-- ════════════════════════════════════════════════════════════
--  COBRANÇAS
-- ════════════════════════════════════════════════════════════

create table if not exists public.cobrancas (
  id                 uuid primary key default gen_random_uuid(),
  personal_id        uuid not null references auth.users(id) on delete cascade,
  aluno_id           uuid references public.alunos(id) on delete set null,
  assinatura_id      uuid references public.aluno_assinaturas(id) on delete set null,
  plano_id           uuid references public.personal_planos(id),

  descricao          text,
  valor_centavos     integer not null check (valor_centavos >= 0),
  taxa_centavos      integer not null default 0,
  liquido_centavos   integer,
  parcelas           smallint not null default 1,
  parcela_numero     smallint,

  metodo             text check (metodo in ('pix','boleto','cartao','dinheiro','outro')),
  status             text not null default 'pendente'
    check (status in ('pendente','pago','atrasado','estornado','cancelado','falhou')),

  vencimento         date not null,
  pago_em            timestamptz,

  -- 'manual' = o personal marcou "recebi por fora" (dinheiro, Pix direto).
  -- Entra no relatório e no controle de inadimplência, mas NUNCA na
  -- carteira: esse dinheiro não passou pelo gateway, então não há o que
  -- sacar.
  origem             text not null default 'gateway' check (origem in ('gateway','manual')),

  gateway_payment_id text,
  link_pagamento     text,
  motivo_falha       text,

  criado_em          timestamptz not null default now(),
  atualizado_em      timestamptz not null default now()
);

create index if not exists cobrancas_painel_idx on public.cobrancas (personal_id, status, vencimento desc);
create index if not exists cobrancas_aluno_idx  on public.cobrancas (aluno_id, vencimento desc);

-- Idempotência do webhook: o gateway reenvia o mesmo evento quando não
-- recebe 200. Sem isto, uma cobrança vira duas.
create unique index if not exists cobrancas_gateway_payment_key
  on public.cobrancas (gateway_payment_id) where gateway_payment_id is not null;

-- ════════════════════════════════════════════════════════════
--  CARTEIRA E SAQUES
-- ════════════════════════════════════════════════════════════

create table if not exists public.carteira_movimentos (
  id               uuid primary key default gen_random_uuid(),
  personal_id      uuid not null references auth.users(id) on delete cascade,
  cobranca_id      uuid references public.cobrancas(id) on delete set null,
  saque_id         uuid,
  tipo             text not null
    check (tipo in ('credito','taxa','estorno','saque','antecipacao','ajuste')),
  valor_centavos   integer not null,   -- negativo em saída
  descricao        text,
  disponivel_em    date,               -- cartão libera parcela a parcela
  gateway_event_id text,
  criado_em        timestamptz not null default now()
);

create index if not exists carteira_movimentos_idx
  on public.carteira_movimentos (personal_id, criado_em desc);
create unique index if not exists carteira_movimentos_evento_key
  on public.carteira_movimentos (gateway_event_id) where gateway_event_id is not null;

create table if not exists public.saques (
  id                  uuid primary key default gen_random_uuid(),
  personal_id         uuid not null references auth.users(id) on delete cascade,
  valor_centavos      integer not null check (valor_centavos > 0),
  taxa_centavos       integer not null default 0,
  destino_tipo        text not null check (destino_tipo in ('pix','ted')),
  destino_descricao   text,

  -- Payload exato enviado ao gateway. É contra isto que o webhook de
  -- validação de saque compara — texto livre não dá para conferir.
  destino             jsonb,

  status              text not null default 'solicitado'
    check (status in ('solicitado','processando','concluido','falhou','cancelado')),

  -- Status cru do gateway (PENDING | BANK_PROCESSING | DONE | ...),
  -- separado do nosso porque o vocabulário deles muda sem avisar.
  gateway_status      text,
  gateway_transfer_id text,

  validacao_status    text
    check (validacao_status in ('nao_aplicavel','aguardando','aprovado','recusado')),
  validado_em         timestamptz,
  validacao_motivo    text,

  -- Gerada no cliente antes do POST. Sem isto, dois toques no botão
  -- "Sacar" viram duas transferências de verdade.
  idempotency_key     text,

  motivo_falha        text,
  solicitado_em       timestamptz not null default now(),
  concluido_em        timestamptz,
  atualizado_em       timestamptz not null default now()
);

create index if not exists saques_idx on public.saques (personal_id, solicitado_em desc);
create unique index if not exists saques_idempotency_key
  on public.saques (idempotency_key) where idempotency_key is not null;
create unique index if not exists saques_gateway_transfer_key
  on public.saques (gateway_transfer_id) where gateway_transfer_id is not null;
create index if not exists saques_aguardando_validacao_idx
  on public.saques (personal_id, valor_centavos) where validacao_status = 'aguardando';

-- Log bruto do webhook. É com isto que se descobre, três semanas depois,
-- por que um saldo divergiu.
create table if not exists public.gateway_eventos (
  id            uuid primary key default gen_random_uuid(),
  gateway       text not null default 'asaas',
  event_id      text not null,
  tipo          text not null,
  personal_id   uuid references auth.users(id) on delete set null,
  payload       jsonb not null,
  processado_em timestamptz,
  erro          text,
  recebido_em   timestamptz not null default now()
);

create unique index if not exists gateway_eventos_key
  on public.gateway_eventos (gateway, event_id);

-- ════════════════════════════════════════════════════════════
--  RLS
-- ════════════════════════════════════════════════════════════

alter table public.pagamento_contas    enable row level security;
alter table public.personal_planos     enable row level security;
alter table public.aluno_assinaturas   enable row level security;
alter table public.cobrancas           enable row level security;
alter table public.carteira_movimentos enable row level security;
alter table public.saques              enable row level security;
alter table public.gateway_eventos     enable row level security;

-- ── pagamento_contas ────────────────────────────────────────
drop policy if exists "conta: leitura própria" on public.pagamento_contas;
create policy "conta: leitura própria"
  on public.pagamento_contas for select to authenticated
  using (personal_id = auth.uid() or public.eh_admin_plataforma());

drop policy if exists "conta: cria o próprio cadastro" on public.pagamento_contas;
create policy "conta: cria o próprio cadastro"
  on public.pagamento_contas for insert to authenticated
  with check (
    personal_id = auth.uid()
    and kyc_status = 'pendente'
    and pode_receber = false
    and pode_sacar   = false
    and gateway_account_id is null
    and api_key_ref        is null
  );

-- Ele edita o que digita. Os campos que liberam dinheiro (kyc_status,
-- pode_sacar, gateway_account_id, api_key_ref) só mudam pela service_role.
drop policy if exists "conta: edita o próprio cadastro" on public.pagamento_contas;
create policy "conta: edita o próprio cadastro"
  on public.pagamento_contas for update to authenticated
  using (personal_id = auth.uid() and kyc_status in ('pendente','recusado'))
  with check (personal_id = auth.uid() and pode_receber = false and pode_sacar = false);

-- ── personal_planos ─────────────────────────────────────────
-- O aluno precisa ler: é o que ele está contratando.
drop policy if exists "planos personal: leitura no tenant" on public.personal_planos;
create policy "planos personal: leitura no tenant"
  on public.personal_planos for select to authenticated
  using (personal_id = public.meu_personal_id() or public.eh_admin_plataforma());

drop policy if exists "planos personal: escrita do dono" on public.personal_planos;
create policy "planos personal: escrita do dono"
  on public.personal_planos for all to authenticated
  using (personal_id = auth.uid())
  with check (personal_id = auth.uid());

-- ── aluno_assinaturas ───────────────────────────────────────
drop policy if exists "assinatura aluno: leitura" on public.aluno_assinaturas;
create policy "assinatura aluno: leitura"
  on public.aluno_assinaturas for select to authenticated
  using (personal_id = auth.uid() or public.aluno_e_meu(aluno_id));

drop policy if exists "assinatura aluno: escrita do personal" on public.aluno_assinaturas;
create policy "assinatura aluno: escrita do personal"
  on public.aluno_assinaturas for all to authenticated
  using (personal_id = auth.uid())
  with check (personal_id = auth.uid());

-- ── cobrancas ───────────────────────────────────────────────
drop policy if exists "cobrancas: leitura" on public.cobrancas;
create policy "cobrancas: leitura"
  on public.cobrancas for select to authenticated
  using (
    personal_id = auth.uid()
    or (aluno_id is not null and public.aluno_e_meu(aluno_id))
    or public.eh_admin_plataforma()
  );

-- O personal mexe só no que ele mesmo lançou. As do gateway são escritas
-- pelo webhook e ficam intocáveis pelo app — inclusive apagar: num `for
-- all` único o `with check` não vale para DELETE, e a linha sairia. Por
-- isso, três policies separadas.
drop policy if exists "cobrancas: insert manual" on public.cobrancas;
create policy "cobrancas: insert manual"
  on public.cobrancas for insert to authenticated
  with check (personal_id = auth.uid() and origem = 'manual');

drop policy if exists "cobrancas: update manual" on public.cobrancas;
create policy "cobrancas: update manual"
  on public.cobrancas for update to authenticated
  using      (personal_id = auth.uid() and origem = 'manual')
  with check (personal_id = auth.uid() and origem = 'manual');

drop policy if exists "cobrancas: delete manual" on public.cobrancas;
create policy "cobrancas: delete manual"
  on public.cobrancas for delete to authenticated
  using (personal_id = auth.uid() and origem = 'manual');

-- ── carteira e saques: leitura do dono, escrita só service_role ──
drop policy if exists "carteira: leitura própria" on public.carteira_movimentos;
create policy "carteira: leitura própria"
  on public.carteira_movimentos for select to authenticated
  using (personal_id = auth.uid() or public.eh_admin_plataforma());

drop policy if exists "saques: leitura própria" on public.saques;
create policy "saques: leitura própria"
  on public.saques for select to authenticated
  using (personal_id = auth.uid() or public.eh_admin_plataforma());

drop policy if exists "eventos: só admin" on public.gateway_eventos;
create policy "eventos: só admin"
  on public.gateway_eventos for select to authenticated
  using (public.eh_admin_plataforma());
