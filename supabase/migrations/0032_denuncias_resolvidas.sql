-- ════════════════════════════════════════════════════════════
--  0032 — A denúncia chega a alguém
--
--  A 0029 criou `feed_denuncias`, o app diz ao aluno "Denúncia enviada
--  ao profissional" — e não havia para onde ela ir. A linha entrava na
--  tabela e ninguém era avisado: o profissional só moderava o que
--  topasse por acaso rolando o feed. A mensagem ao aluno era uma
--  promessa que o sistema não cumpria.
--
--  O QUE FALTAVA ERA ONDE GUARDAR O DESFECHO
--
--  Uma caixa de entrada precisa de duas coisas: saber o que ainda não
--  foi visto, e poder tirar da frente o que já foi. Sem uma coluna de
--  desfecho, "já olhei isto e não é nada" não teria onde ser gravado, e
--  a denúncia improcedente ficaria para sempre na lista — o que, na
--  prática, faz o profissional parar de olhar a lista.
--
--  QUEM RESOLVE É O DONO DO FEED, E SÓ ELE
--
--  Nem quem denunciou nem o autor do conteúdo podem marcar nada: um
--  arquivaria a própria denúncia, o outro arquivaria a denúncia contra
--  si. A política de update confere o dono pelo post — inclusive
--  quando a denúncia é de um comentário, subindo até o post dele.
--
--  Depende do 0029. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

alter table public.feed_denuncias
  add column if not exists resolvida_em timestamptz,
  add column if not exists resolucao    text,
  add column if not exists resolvida_por uuid references public.profiles(id);

-- O desfecho é um de três, e nulo enquanto ninguém olhou.
--
--   arquivada  — olhei, não é nada
--   ocultada   — tirei do feed
--   removida   — apaguei o conteúdo
--
-- `drop constraint` antes porque rodar de novo com o check já criado
-- falharia, e esta migration precisa ser repetível.
alter table public.feed_denuncias
  drop constraint if exists feed_denuncias_resolucao_check;

alter table public.feed_denuncias
  add constraint feed_denuncias_resolucao_check
  check (resolucao is null or resolucao in ('arquivada', 'ocultada', 'removida'));

-- A lista que o profissional abre é "o que ainda não resolvi". O índice
-- é parcial pela mesma razão: o pendente é pouco, o resolvido cresce
-- para sempre, e só o pendente é consultado.
create index if not exists feed_denuncias_pendentes
  on public.feed_denuncias (criado_em desc) where resolvida_em is null;

-- ════════════════════════════════════════════════════════════
--  QUANTAS ESPERAM POR MIM
-- ════════════════════════════════════════════════════════════

-- O número do aviso no feed do profissional.
--
-- Função em vez de `count` pelo PostgREST porque a contagem precisa
-- subir do comentário até o post para achar o dono, e isso numa
-- `select` do cliente viraria duas consultas e uma soma no app.
create or replace function public.denuncias_pendentes(p_personal_id uuid)
returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::integer
    from public.feed_denuncias d
   where d.resolvida_em is null
     and p_personal_id = auth.uid()
     and (
       exists (select 1 from public.feed_posts p
                where p.id = d.post_id and p.personal_id = p_personal_id)
       or exists (select 1 from public.feed_comentarios cm
                   join public.feed_posts p on p.id = cm.post_id
                  where cm.id = d.comentario_id and p.personal_id = p_personal_id)
     );
$$;

-- ════════════════════════════════════════════════════════════
--  RLS
-- ════════════════════════════════════════════════════════════

-- Só o dono do feed marca o desfecho. Quem denunciou não arquiva a
-- própria denúncia, e o autor do conteúdo não arquiva a denúncia
-- contra si — seria o fim de a denúncia servir para alguma coisa.
drop policy if exists "denúncias: o dono resolve" on public.feed_denuncias;
create policy "denúncias: o dono resolve"
  on public.feed_denuncias for update to authenticated
  using (
    exists (select 1 from public.feed_posts p
             where p.id = feed_denuncias.post_id and p.personal_id = auth.uid())
    or exists (select 1 from public.feed_comentarios cm
                join public.feed_posts p on p.id = cm.post_id
               where cm.id = feed_denuncias.comentario_id
                 and p.personal_id = auth.uid())
  )
  with check (
    exists (select 1 from public.feed_posts p
             where p.id = feed_denuncias.post_id and p.personal_id = auth.uid())
    or exists (select 1 from public.feed_comentarios cm
                join public.feed_posts p on p.id = cm.post_id
               where cm.id = feed_denuncias.comentario_id
                 and p.personal_id = auth.uid())
  );

-- A 0029 concedeu só select e insert, porque não havia o que atualizar.
grant update on public.feed_denuncias to authenticated;

revoke all on function public.denuncias_pendentes(uuid) from public;
grant execute on function public.denuncias_pendentes(uuid) to authenticated;

notify pgrst, 'reload schema';

-- Conferência: as três colunas, o check, a política de update e a
-- função de contagem.
select
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'feed_denuncias'
      and column_name in ('resolvida_em', 'resolucao', 'resolvida_por'))  as colunas_3,
  (select count(*) from pg_constraint
    where conname = 'feed_denuncias_resolucao_check')                     as check_1,
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'feed_denuncias'
      and cmd = 'UPDATE')                                                 as policy_update_1,
  (select count(*) from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.proname = 'denuncias_pendentes')    as funcao_1,
  (select count(*) from public.feed_denuncias where resolvida_em is null) as pendentes_hoje;
