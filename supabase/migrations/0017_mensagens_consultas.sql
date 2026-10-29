-- ════════════════════════════════════════════════════════════
--  0017 — Chat e agenda de consultas
--
--  MENSAGENS
--  Uma conversa por aluno: o aluno e o profissional dele. Não há
--  tabela de "conversas" — o `aluno_id` já é a conversa, e uma tabela a
--  mais seria um lugar para os dois divergirem.
--
--  Escrever: quem enxerga o aluno, assinando como si mesmo (`autor_id`
--  é conferido contra `auth.uid()`, para ninguém mandar mensagem em
--  nome do outro). Marcar como lida é por função: liberar UPDATE
--  deixaria editar o texto de uma mensagem já enviada.
--
--  Entra na publicação do Realtime: é o que faz a mensagem aparecer na
--  tela do outro sem recarregar. O Realtime respeita o RLS.
--
--  CONSULTAS
--  O profissional agenda; o aluno confirma, pede para remarcar e, depois
--  da consulta, avalia. As ações do aluno são funções pelo mesmo motivo
--  das metas (0016): ele mexe no status, não na data nem no local.
--
--  Depende do 0001. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- ── Mensagens ───────────────────────────────────────────────
create table if not exists public.mensagens (
  id        uuid primary key default gen_random_uuid(),
  aluno_id  uuid not null references public.alunos(id) on delete cascade,
  autor_id  uuid not null default auth.uid(),
  texto     text not null check (length(btrim(texto)) between 1 and 4000),
  lida_em   timestamptz,
  criado_em timestamptz not null default now()
);

create index if not exists mensagens_conversa_idx
  on public.mensagens (aluno_id, criado_em desc);

alter table public.mensagens enable row level security;

drop policy if exists "mensagens: leitura" on public.mensagens;
create policy "mensagens: leitura"
  on public.mensagens for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "mensagens: envio em nome próprio" on public.mensagens;
create policy "mensagens: envio em nome próprio"
  on public.mensagens for insert to authenticated
  with check (autor_id = auth.uid() and public.aluno_e_meu(aluno_id));

grant select, insert on public.mensagens to authenticated;

-- Marca como lidas as mensagens da conversa que NÃO são minhas.
create or replace function public.marcar_mensagens_lidas(p_aluno_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.aluno_e_meu(p_aluno_id) then
    raise exception 'Sem permissão para esta conversa' using errcode = '42501';
  end if;
  update public.mensagens
     set lida_em = now()
   where aluno_id = p_aluno_id
     and autor_id <> auth.uid()
     and lida_em is null;
end;
$$;

revoke all on function public.marcar_mensagens_lidas(uuid) from public;
grant execute on function public.marcar_mensagens_lidas(uuid) to authenticated;

-- Realtime: entra na publicação uma vez só (rodar de novo não falha).
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'mensagens'
  ) then
    alter publication supabase_realtime add table public.mensagens;
  end if;
end;
$$;

-- ── Consultas ───────────────────────────────────────────────
create table if not exists public.consultas (
  id            uuid primary key default gen_random_uuid(),
  personal_id   uuid not null default auth.uid() references auth.users(id) on delete cascade,
  aluno_id      uuid not null references public.alunos(id) on delete cascade,
  inicio        timestamptz not null,
  duracao_min   integer not null default 60 check (duracao_min between 10 and 480),
  tipo          text not null default 'retorno'
    check (tipo in ('avaliacao', 'retorno', 'nutricao', 'treino', 'online')),
  local         text,
  link          text,
  observacoes   text,
  status        text not null default 'agendada'
    check (status in ('agendada', 'confirmada', 'remarcar', 'cancelada', 'realizada')),
  respondida_em timestamptz,
  nota          smallint check (nota between 1 and 5),
  comentario    text,
  criado_em     timestamptz not null default now()
);

create index if not exists consultas_personal_idx on public.consultas (personal_id, inicio);
create index if not exists consultas_aluno_idx    on public.consultas (aluno_id, inicio);

alter table public.consultas enable row level security;

drop policy if exists "consultas: leitura" on public.consultas;
create policy "consultas: leitura"
  on public.consultas for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "consultas: o profissional agenda" on public.consultas;
create policy "consultas: o profissional agenda"
  on public.consultas for all to authenticated
  using (personal_id = auth.uid())
  with check (
    personal_id = auth.uid()
    and exists (select 1 from public.alunos a
                 where a.id = consultas.aluno_id and a.personal_id = auth.uid())
  );

grant select, insert, update, delete on public.consultas to authenticated;

-- O aluno confirma ou pede para remarcar uma consulta futura dele.
create or replace function public.responder_consulta(p_consulta_id uuid, p_acao text)
returns void
language plpgsql security definer set search_path = public as $$
declare v public.consultas%rowtype;
begin
  select * into v from public.consultas where id = p_consulta_id;
  if v.id is null then
    raise exception 'Consulta não encontrada' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.alunos a
                  where a.id = v.aluno_id and a.user_id = auth.uid()) then
    raise exception 'Só o aluno responde à consulta' using errcode = '42501';
  end if;
  if p_acao not in ('confirmar', 'remarcar') then
    raise exception 'Ação inválida: %', p_acao using errcode = '22023';
  end if;
  if v.status in ('cancelada', 'realizada') or v.inicio < now() then
    raise exception 'Esta consulta não pode mais ser respondida' using errcode = '22023';
  end if;

  update public.consultas
     set status = case p_acao when 'confirmar' then 'confirmada' else 'remarcar' end,
         respondida_em = now()
   where id = p_consulta_id;
end;
$$;

-- O aluno avalia uma consulta que já aconteceu.
create or replace function public.avaliar_consulta(p_consulta_id uuid, p_nota smallint, p_comentario text)
returns void
language plpgsql security definer set search_path = public as $$
declare v public.consultas%rowtype;
begin
  select * into v from public.consultas where id = p_consulta_id;
  if v.id is null then
    raise exception 'Consulta não encontrada' using errcode = 'P0002';
  end if;
  if not exists (select 1 from public.alunos a
                  where a.id = v.aluno_id and a.user_id = auth.uid()) then
    raise exception 'Só o aluno avalia a consulta' using errcode = '42501';
  end if;
  if v.status = 'cancelada' or v.inicio > now() then
    raise exception 'A consulta ainda não aconteceu' using errcode = '22023';
  end if;

  update public.consultas
     set nota = p_nota,
         comentario = nullif(btrim(coalesce(p_comentario, '')), ''),
         status = 'realizada'
   where id = p_consulta_id;
end;
$$;

revoke all on function public.responder_consulta(uuid, text) from public;
revoke all on function public.avaliar_consulta(uuid, smallint, text) from public;
grant execute on function public.responder_consulta(uuid, text) to authenticated;
grant execute on function public.avaliar_consulta(uuid, smallint, text) to authenticated;

notify pgrst, 'reload schema';
