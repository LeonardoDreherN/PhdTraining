-- ════════════════════════════════════════════════════════════
--  0019 — Circunferências livres na sessão de avaliação
--
--  A sessão só tinha cintura e quadril. O personal (ou o nutri) escolhe
--  quais circunferências mede: as do catálogo do app (braço contraído,
--  coxa proximal, panturrilha...) ou uma com nome próprio.
--
--  `circunferencias` é { "chave": cm }. A chave é a do catálogo, que mora
--  no app (`Circunferencia.catalogo`), ou o nome que o personal digitou.
--  Cintura e quadril continuam nas colunas próprias: os índices (RCQ,
--  RCE, IAC) dependem delas e as avaliações antigas já estão lá.
--
--  Depende do 0009. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

alter table public.avaliacoes
  add column if not exists circunferencias jsonb not null default '{}'::jsonb;

notify pgrst, 'reload schema';

-- Conferência: deve devolver uma linha, jsonb, com o padrão '{}'.
select column_name, data_type, column_default
  from information_schema.columns
 where table_schema = 'public'
   and table_name = 'avaliacoes'
   and column_name = 'circunferencias';
