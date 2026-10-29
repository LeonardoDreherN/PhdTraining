-- ════════════════════════════════════════════════════════════
--  0016 — Metas do aluno e o que o app mostra a cada aluno
--
--  METAS
--  Combinados da consulta: "2 L de água por dia", "fruta no lanche",
--  "jantar até as 21h". O profissional escreve; o aluno marca como
--  cumprida.
--
--  O aluno marca por FUNÇÃO, não por policy de UPDATE. Liberar UPDATE
--  na tabela deixaria o aluno reescrever a meta que o profissional
--  definiu ("1 L" no lugar de "2 L"). A função mexe numa coluna só —
--  o mesmo padrão do 0012.
--
--  RECURSOS
--  Cada profissional decide, por aluno, o que o app mostra: diário
--  alimentar, registro de peso, calorias e macros, lista de compras.
--  Há quem não queira paciente contando caloria — com histórico de
--  compulsão, por exemplo. Ausente no jsonb = ligado: o padrão é
--  mostrar tudo, e quem desliga é o profissional.
--
--  Depende do 0001. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

alter table public.alunos
  add column if not exists recursos jsonb not null default '{}'::jsonb;

comment on column public.alunos.recursos is
  'O que o app do aluno mostra. Chaves: diario, peso, nutricional, '
  'lista_compras, chat. Ausente = ligado.';

create table if not exists public.metas_aluno (
  id           uuid primary key default gen_random_uuid(),
  aluno_id     uuid not null references public.alunos(id) on delete cascade,
  titulo       text not null,
  descricao    text,
  prazo        date,
  concluida_em timestamptz,
  criado_por   uuid default auth.uid(),
  criado_em    timestamptz not null default now()
);

create index if not exists metas_aluno_idx
  on public.metas_aluno (aluno_id, concluida_em nulls first, criado_em desc);

alter table public.metas_aluno enable row level security;

drop policy if exists "metas_aluno: leitura" on public.metas_aluno;
create policy "metas_aluno: leitura"
  on public.metas_aluno for select to authenticated
  using (public.aluno_e_meu(aluno_id));

drop policy if exists "metas_aluno: o profissional escreve" on public.metas_aluno;
create policy "metas_aluno: o profissional escreve"
  on public.metas_aluno for all to authenticated
  using (exists (select 1 from public.alunos a
                  where a.id = metas_aluno.aluno_id and a.personal_id = auth.uid()))
  with check (exists (select 1 from public.alunos a
                       where a.id = metas_aluno.aluno_id and a.personal_id = auth.uid()));

grant select, insert, update, delete on public.metas_aluno to authenticated;

-- O aluno (ou o profissional) marca e desmarca. Levanta erro quando não
-- acha a meta, para o app nunca receber sucesso de uma escrita que não
-- aconteceu.
create or replace function public.concluir_meta(p_meta_id uuid, p_concluida boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare v_aluno uuid;
begin
  select aluno_id into v_aluno from public.metas_aluno where id = p_meta_id;
  if v_aluno is null then
    raise exception 'Meta não encontrada' using errcode = 'P0002';
  end if;
  if not public.aluno_e_meu(v_aluno) then
    raise exception 'Sem permissão para esta meta' using errcode = '42501';
  end if;

  update public.metas_aluno
     set concluida_em = case when p_concluida then now() else null end
   where id = p_meta_id;
end;
$$;

revoke all on function public.concluir_meta(uuid, boolean) from public;
grant execute on function public.concluir_meta(uuid, boolean) to authenticated;

notify pgrst, 'reload schema';
