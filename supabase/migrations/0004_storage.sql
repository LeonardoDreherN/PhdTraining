-- ============================================================
-- 0004 — Storage
--
-- Três buckets, que o app já usa hoje:
--   avatars          — foto de perfil (personal e aluno)
--   exercicios-midia — imagem e vídeo de exercício
--   progresso-fotos  — foto de evolução do aluno
--
-- Os dois primeiros são públicos: o app monta a URL com
-- `getPublicUrl` e joga num <img>. O terceiro NÃO é — foto de corpo
-- de aluno com URL adivinhável é vazamento, mesmo que ninguém
-- publique o link.
--
-- Depende do 0001. Seguro rodar mais de uma vez.
-- ============================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880,
   array['image/jpeg','image/png','image/webp']),

  ('exercicios-midia', 'exercicios-midia', true, 104857600,
   array['image/jpeg','image/png','image/webp','video/mp4','video/quicktime','video/webm']),

  ('progresso-fotos', 'progresso-fotos', false, 10485760,
   array['image/jpeg','image/png','image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ── avatars ─────────────────────────────────────────────────
-- ProfileService grava em '<user_id>/avatar.<ext>'. A policy exige que a
-- primeira pasta do caminho seja o id de quem está enviando — é isso que
-- impede sobrescrever o avatar de outra pessoa.

drop policy if exists "avatars: leitura pública" on storage.objects;
create policy "avatars: leitura pública"
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars: envio na própria pasta" on storage.objects;
create policy "avatars: envio na própria pasta"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars: troca o próprio" on storage.objects;
create policy "avatars: troca o próprio"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars: apaga o próprio" on storage.objects;
create policy "avatars: apaga o próprio"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ── exercicios-midia ────────────────────────────────────────
-- Os arquivos nascem como '<personal_id>_<timestamp>.<ext>' e
-- 'vid_<personal_id>_<timestamp>.<ext>' — nome achatado, sem pasta. Como
-- não dá para derivar o dono do caminho, a escrita fica aberta a qualquer
-- personal autenticado e a exclusão fica fechada.
--
-- PENDÊNCIA: quando ExercicioService for reescrito, mudar para
-- '<personal_id>/<arquivo>' e trocar estas policies pelas mesmas de
-- avatars. Até lá, um personal consegue enviar mídia — mas não apagar a
-- de ninguém, que é o dano que importa.

drop policy if exists "exercicios: leitura pública" on storage.objects;
create policy "exercicios: leitura pública"
  on storage.objects for select
  using (bucket_id = 'exercicios-midia');

drop policy if exists "exercicios: envio autenticado" on storage.objects;
create policy "exercicios: envio autenticado"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'exercicios-midia');

-- ── progresso-fotos ─────────────────────────────────────────
-- Bucket privado. O app precisa passar a usar `createSignedUrl` em vez de
-- `getPublicUrl` para exibir estas fotos.
--
-- Caminho esperado: '<aluno_id>/<arquivo>'. Quem enxerga é o próprio aluno
-- e o personal dono dele — a mesma regra da tabela `fotos_progresso`.

drop policy if exists "progresso: só o aluno e o personal dele" on storage.objects;
create policy "progresso: só o aluno e o personal dele"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'progresso-fotos'
    and public.aluno_e_meu(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "progresso: envio do aluno ou do personal" on storage.objects;
create policy "progresso: envio do aluno ou do personal"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'progresso-fotos'
    and public.aluno_e_meu(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "progresso: apaga quem pode ver" on storage.objects;
create policy "progresso: apaga quem pode ver"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'progresso-fotos'
    and public.aluno_e_meu(((storage.foldername(name))[1])::uuid)
  );
