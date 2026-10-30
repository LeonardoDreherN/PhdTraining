-- ════════════════════════════════════════════════════════════
--  Recupera a foto dos alunos que enviaram antes do 0012
--
--  O app mostra a foto do aluno para o personal a partir de
--  `alunos.foto_url`. Até o 0012, o espelho do aluno para essa coluna
--  era recusado pela RLS em silêncio — a foto ia só para
--  `profiles.avatar_url`, e o personal seguia vendo as iniciais.
--
--  Envios novos já gravam nos dois lugares. Isto aqui conserta os
--  antigos, sem ninguém precisar reenviar.
--
--  Rode uma vez. Rodar de novo não faz nada (o `is distinct from`).
-- ════════════════════════════════════════════════════════════

-- 1 ─ Antes: quem tem foto no perfil mas não no cadastro.
select a.id,
       a.nome,
       a.foto_url     as no_cadastro,
       p.avatar_url   as no_perfil
  from public.alunos a
  join public.profiles p on p.id = a.user_id
 where p.avatar_url is not null
   and a.foto_url is distinct from p.avatar_url;

-- 2 ─ Copia.
update public.alunos a
   set foto_url = p.avatar_url
  from public.profiles p
 where p.id = a.user_id
   and p.avatar_url is not null
   and a.foto_url is distinct from p.avatar_url;

-- 3 ─ Depois: `divergentes` tem de ser 0.
select count(*) filter (where a.foto_url is not null)        as alunos_com_foto,
       count(*) filter (where a.user_id is not null
                          and p.avatar_url is not null
                          and a.foto_url is distinct from p.avatar_url) as divergentes
  from public.alunos a
  left join public.profiles p on p.id = a.user_id;
