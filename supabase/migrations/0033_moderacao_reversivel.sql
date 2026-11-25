-- ════════════════════════════════════════════════════════════
--  0033 — Ocultar com volta
--
--  "Tirar do feed" não tinha volta.
--
--  A policy de leitura da 0029 deixa ver o post oculto só para quem o
--  escreveu:
--
--      using (feed_e_meu(personal_id) and (not oculto or autor_id = auth.uid()))
--
--  O profissional oculta a publicação de um ALUNO, e o autor é o aluno,
--  não ele. A partir daquele instante o post desaparece da vista dele
--  também — não há lista, não há tela, não há como restaurar. Ocultar
--  virava apagar, com a diferença de que a linha continua no banco e
--  ninguém sabe que existe.
--
--  Esta migration acrescenta o dono do feed à exceção. Ele passa a ver
--  o que ocultou, e só isso: o aluno continua sem ver o post oculto de
--  outro aluno, e quem ocultou pode voltar atrás.
--
--  A diferença entre ocultar e apagar só existe de verdade quando
--  ocultar é reversível. Até aqui eram a mesma coisa com nomes
--  diferentes.
--
--  Depende do 0029. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

drop policy if exists "posts: a comunidade lê o que não está oculto" on public.feed_posts;
create policy "posts: a comunidade lê o que não está oculto"
  on public.feed_posts for select to authenticated
  using (
    public.feed_e_meu(personal_id)
    and (
      not oculto
      -- O autor vê o que é dele, mesmo oculto: ele precisa saber que
      -- ainda existe.
      or autor_id = auth.uid()
      -- E o dono do feed vê o que ocultou, senão não teria como
      -- restaurar.
      or personal_id = auth.uid()
    )
  );

-- O mesmo buraco nos comentários: a policy exige `not oculto` para
-- todo mundo, então o profissional que oculta um comentário perde o
-- comentário de vista e não pode desfazer.
drop policy if exists "comentários: a comunidade lê" on public.feed_comentarios;
create policy "comentários: a comunidade lê"
  on public.feed_comentarios for select to authenticated
  using (
    exists (
      select 1 from public.feed_posts p
       where p.id = feed_comentarios.post_id
         and public.feed_e_meu(p.personal_id)
         and (not feed_comentarios.oculto
              or feed_comentarios.autor_id = auth.uid()
              or p.personal_id = auth.uid())
    )
  );

notify pgrst, 'reload schema';

-- Conferência: as duas policies de leitura foram refeitas e já citam o
-- dono do feed.
select
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'feed_posts'
      and cmd = 'SELECT')                                       as policy_posts_1,
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'feed_comentarios'
      and cmd = 'SELECT')                                       as policy_comentarios_1,
  (select position('personal_id = auth.uid()' in qual) > 0
     from pg_policies
    where schemaname = 'public' and tablename = 'feed_posts'
      and cmd = 'SELECT')                                       as dono_ve_oculto;
