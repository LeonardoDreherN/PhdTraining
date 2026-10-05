-- ════════════════════════════════════════════════════════════
--  0007 — Formatos de mídia que os buckets aceitam
--
--  O app passou a enviar o tipo MIME correto (antes montava
--  'image/' + extensão, o que gerava "image/jpg" e "video/mov",
--  nomes que não existem). Agora que os nomes estão certos, a
--  lista dos buckets precisa cobrir o que um celular produz:
--
--  - HEIC/HEIF é o padrão de foto do iPhone desde 2017. Sem ele,
--    o usuário de iPhone não consegue enviar foto nenhuma.
--  - M4V e 3GP aparecem em vídeos de câmeras e Android antigo.
--
--  MOV já era aceito como video/quicktime — o problema nunca foi
--  o bucket, era o nome que o cliente mandava.
-- ════════════════════════════════════════════════════════════

update storage.buckets
   set allowed_mime_types = array[
         'image/jpeg','image/png','image/webp','image/heic','image/heif'
       ]
 where id in ('avatars', 'progresso-fotos');

update storage.buckets
   set allowed_mime_types = array[
         'image/jpeg','image/png','image/webp','image/heic','image/heif',
         'video/mp4','video/quicktime','video/webm','video/x-m4v','video/3gpp'
       ]
 where id = 'exercicios-midia';

-- Conferência: deve listar os três buckets com as listas acima.
-- select id, allowed_mime_types from storage.buckets order by id;
