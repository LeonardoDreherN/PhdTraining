-- ════════════════════════════════════════════════════════════
--  Os nove planos do Pedro
--
--  Training, Nutrition e Performance, cada um em mensal, trimestral e
--  semestral. Preços das artes, em centavos.
--
--  A diferença entre as três famílias mora em `inclui_treino` e
--  `inclui_dieta` — não no nome. É por esses dois campos que o app sabe
--  se o aluno tem direito à aba de dieta.
--
--  Não é migração: é dado de uma pessoa. Rode uma vez; rodar de novo não
--  duplica (o `not exists` por nome).
--
--  Para MUDAR um preço depois, este arquivo não serve: ele só insere o
--  que falta. Edite o plano direto, ou pela tela quando ela existir.
-- ════════════════════════════════════════════════════════════

insert into public.personal_planos
  (personal_id, nome, descricao, periodicidade, preco_centavos,
   inclui_treino, inclui_dieta, max_parcelas, link_slug, ativo)
select u.id, v.nome, v.descricao, v.periodicidade, v.preco,
       v.treino, v.dieta, v.parcelas, v.slug, true
  from auth.users u
  cross join (values
    -- ── PHD Training — consultoria online de treinos ──────────
    ('PHD Training Mensal',          'Consultoria online de treinos',  'mensal',      24990, true,  false, 1,  'phd-training-mensal'),
    ('PHD Training Trimestral',      'Consultoria online de treinos',  'trimestral',  54990, true,  false, 3,  'phd-training-trimestral'),
    ('PHD Training Semestral',       'Consultoria online de treinos',  'semestral',   89990, true,  false, 6,  'phd-training-semestral'),

    -- ── PHD Nutrition — consultoria online nutricional ────────
    ('PHD Nutrition Mensal',         'Consultoria online nutricional', 'mensal',      34990, false, true,  1,  'phd-nutrition-mensal'),
    ('PHD Nutrition Trimestral',     'Consultoria online nutricional', 'trimestral',  69990, false, true,  3,  'phd-nutrition-trimestral'),
    ('PHD Nutrition Semestral',      'Consultoria online nutricional', 'semestral',  109990, false, true,  6,  'phd-nutrition-semestral'),

    -- ── PHD Performance — treino + dieta ──────────────────────
    ('PHD Performance Mensal',       'Treino e dieta integrados',      'mensal',      49990, true,  true,  1,  'phd-performance-mensal'),
    ('PHD Performance Trimestral',   'Treino e dieta integrados',      'trimestral',  99990, true,  true,  3,  'phd-performance-trimestral'),
    ('PHD Performance Semestral',    'Treino e dieta integrados',      'semestral',  149990, true,  true,  6,  'phd-performance-semestral')
  ) as v(nome, descricao, periodicidade, preco, treino, dieta, parcelas, slug)
 where u.email = 'pedrodreher17@gmail.com'
   and not exists (
     select 1 from public.personal_planos p
      where p.personal_id = u.id and p.nome = v.nome
   );

notify pgrst, 'reload schema';

-- Conferência: nove linhas, com o preço mensal equivalente ao lado para
-- bater com o que está escrito nas artes.
select nome,
       periodicidade,
       to_char(preco_centavos / 100.0, 'FM999G999D00')      as preco,
       to_char(preco_centavos / 100.0
               / case periodicidade
                   when 'mensal' then 1 when 'trimestral' then 3
                   when 'semestral' then 6 else 1 end,
               'FM999G999D00')                              as por_mes,
       inclui_treino,
       inclui_dieta
  from public.personal_planos
 where personal_id = (select id from auth.users
                       where email = 'pedrodreher17@gmail.com')
 order by inclui_dieta, inclui_treino, preco_centavos;
