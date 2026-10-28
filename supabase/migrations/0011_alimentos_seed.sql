-- ════════════════════════════════════════════════════════════
--  0011 — Alimentos iniciais
--
--  ⚠ LEIA ANTES DE PRESCREVER EM CIMA DISTO
--
--  Estes valores NÃO são a TACO oficial. São uma base inicial de
--  composição de alimentos comuns no Brasil, montada para que o
--  montador de plano tenha o que buscar desde o primeiro dia. Os
--  números são aproximados e coerentes entre si, mas não foram
--  conferidos linha a linha contra a tabela publicada.
--
--  Por isso `fonte = 'seed_inicial'`, e não 'taco'. O app mostra essa
--  marca na busca: o profissional vê de onde veio o dado antes de usar.
--
--  Para substituir pela TACO de verdade:
--    1. Baixe a tabela da UNICAMP (https://www.cfn.org.br/ ou NEPA)
--    2. Importe com fonte = 'taco' e codigo_origem = número do alimento
--    3. `delete from alimentos where fonte = 'seed_inicial'`
--  O índice único (fonte, codigo_origem) impede duplicar na reimportação.
--
--  Valores por 100 g de parte comestível, alimento preparado quando o
--  nome diz (cozido, grelhado), cru quando não diz.
--
--  Depende do 0010. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

insert into public.alimentos
  (codigo_origem, fonte, oficial, nome, grupo, medida_caseira, medida_gramas,
   kcal, proteina, carboidrato, gordura, fibra, sodio)
values
  -- ── Cereais, tubérculos e massas ──────────────────────────
  ('s001','seed_inicial',true,'Arroz branco cozido','Cereais e massas','1 colher de servir',80, 128, 2.5, 28.1, 0.2, 1.6, 1),
  ('s002','seed_inicial',true,'Arroz integral cozido','Cereais e massas','1 colher de servir',80, 124, 2.6, 25.8, 1.0, 2.7, 1),
  ('s003','seed_inicial',true,'Macarrão cozido','Cereais e massas','1 escumadeira',110, 158, 5.8, 30.9, 1.1, 1.8, 1),
  ('s004','seed_inicial',true,'Pão francês','Cereais e massas','1 unidade',50, 300, 8.0, 58.6, 3.1, 2.3, 648),
  ('s005','seed_inicial',true,'Pão de forma integral','Cereais e massas','1 fatia',25, 253, 9.4, 49.9, 3.5, 6.9, 506),
  ('s006','seed_inicial',true,'Aveia em flocos','Cereais e massas','1 colher de sopa',15, 394, 13.9, 66.6, 8.5, 9.1, 5),
  ('s007','seed_inicial',true,'Tapioca (goma hidratada)','Cereais e massas','1 unidade média',60, 240, 0.0, 59.0, 0.0, 0.5, 2),
  ('s008','seed_inicial',true,'Batata inglesa cozida','Cereais e massas','1 unidade média',120, 86, 1.8, 18.5, 0.1, 1.3, 2),
  ('s009','seed_inicial',true,'Batata-doce cozida','Cereais e massas','1 unidade pequena',100, 77, 0.6, 18.4, 0.1, 2.2, 10),
  ('s010','seed_inicial',true,'Mandioca cozida','Cereais e massas','1 pedaço médio',100, 125, 0.6, 30.1, 0.3, 1.6, 2),
  ('s011','seed_inicial',true,'Cuscuz de milho cozido','Cereais e massas','1 fatia',80, 113, 2.4, 25.3, 0.5, 1.4, 5),
  ('s012','seed_inicial',true,'Granola tradicional','Cereais e massas','1 colher de sopa',15, 471, 9.4, 64.0, 19.0, 7.0, 25),

  -- ── Leguminosas ───────────────────────────────────────────
  ('s020','seed_inicial',true,'Feijão carioca cozido','Leguminosas','1 concha média',80, 76, 4.8, 13.6, 0.5, 8.5, 2),
  ('s021','seed_inicial',true,'Feijão preto cozido','Leguminosas','1 concha média',80, 77, 4.5, 14.0, 0.5, 8.4, 2),
  ('s022','seed_inicial',true,'Lentilha cozida','Leguminosas','1 colher de servir',70, 93, 6.3, 16.3, 0.5, 7.9, 2),
  ('s023','seed_inicial',true,'Grão-de-bico cozido','Leguminosas','1 colher de servir',70, 164, 8.9, 27.4, 2.6, 7.6, 6),
  ('s024','seed_inicial',true,'Ervilha cozida','Leguminosas','1 colher de sopa',25, 81, 5.4, 14.5, 0.4, 5.1, 3),

  -- ── Carnes e ovos ─────────────────────────────────────────
  ('s030','seed_inicial',true,'Peito de frango grelhado','Carnes e ovos','1 filé médio',100, 163, 31.5, 0.0, 3.2, 0.0, 65),
  ('s031','seed_inicial',true,'Coxa de frango assada sem pele','Carnes e ovos','1 unidade',80, 184, 27.0, 0.0, 7.8, 0.0, 86),
  ('s032','seed_inicial',true,'Patinho moído cozido','Carnes e ovos','1 colher de servir',60, 219, 35.9, 0.0, 7.3, 0.0, 58),
  ('s033','seed_inicial',true,'Alcatra grelhada','Carnes e ovos','1 bife médio',100, 241, 31.9, 0.0, 11.8, 0.0, 51),
  ('s034','seed_inicial',true,'Contrafilé grelhado','Carnes e ovos','1 bife médio',100, 278, 31.2, 0.0, 16.0, 0.0, 49),
  ('s035','seed_inicial',true,'Lombo suíno assado','Carnes e ovos','1 fatia',80, 210, 35.7, 0.0, 6.4, 0.0, 56),
  ('s036','seed_inicial',true,'Ovo de galinha cozido','Carnes e ovos','1 unidade',50, 146, 13.3, 0.6, 9.5, 0.0, 140),
  ('s037','seed_inicial',true,'Clara de ovo cozida','Carnes e ovos','1 unidade',33, 59, 13.5, 0.0, 0.1, 0.0, 180),
  ('s038','seed_inicial',true,'Linguiça de frango grelhada','Carnes e ovos','1 unidade',60, 218, 20.0, 1.5, 14.6, 0.0, 790),

  -- ── Pescados ──────────────────────────────────────────────
  ('s040','seed_inicial',true,'Tilápia grelhada','Pescados','1 filé médio',100, 128, 26.1, 0.0, 2.2, 0.0, 56),
  ('s041','seed_inicial',true,'Salmão grelhado','Pescados','1 posta',120, 211, 23.5, 0.0, 12.9, 0.0, 61),
  ('s042','seed_inicial',true,'Atum em conserva em água','Pescados','1 lata drenada',120, 116, 25.5, 0.0, 1.0, 0.0, 320),
  ('s043','seed_inicial',true,'Sardinha em conserva','Pescados','1 unidade',25, 208, 24.6, 0.0, 11.5, 0.0, 400),

  -- ── Leite e derivados ─────────────────────────────────────
  ('s050','seed_inicial',true,'Leite integral','Leite e derivados','1 copo',200, 61, 2.9, 4.3, 3.2, 0.0, 44),
  ('s051','seed_inicial',true,'Leite desnatado','Leite e derivados','1 copo',200, 35, 3.4, 4.9, 0.1, 0.0, 52),
  ('s052','seed_inicial',true,'Iogurte natural integral','Leite e derivados','1 pote',170, 61, 3.5, 4.7, 3.3, 0.0, 46),
  ('s053','seed_inicial',true,'Iogurte natural desnatado','Leite e derivados','1 pote',170, 41, 4.1, 5.0, 0.2, 0.0, 52),
  ('s054','seed_inicial',true,'Queijo minas frescal','Leite e derivados','1 fatia',30, 264, 17.4, 3.2, 20.2, 0.0, 31),
  ('s055','seed_inicial',true,'Queijo mussarela','Leite e derivados','1 fatia',20, 330, 25.0, 3.0, 25.0, 0.0, 580),
  ('s056','seed_inicial',true,'Queijo cottage','Leite e derivados','1 colher de sopa',30, 98, 11.1, 3.4, 4.3, 0.0, 364),
  ('s057','seed_inicial',true,'Requeijão cremoso','Leite e derivados','1 colher de sopa',20, 257, 9.6, 3.4, 22.3, 0.0, 580),

  -- ── Frutas ────────────────────────────────────────────────
  ('s060','seed_inicial',true,'Banana prata','Frutas','1 unidade média',70, 98, 1.3, 26.0, 0.1, 2.0, 1),
  ('s061','seed_inicial',true,'Maçã com casca','Frutas','1 unidade média',130, 56, 0.3, 15.2, 0.0, 1.3, 2),
  ('s062','seed_inicial',true,'Laranja pera','Frutas','1 unidade média',130, 37, 1.0, 8.9, 0.1, 0.8, 1),
  ('s063','seed_inicial',true,'Mamão formosa','Frutas','1 fatia média',170, 45, 0.8, 11.6, 0.1, 1.8, 4),
  ('s064','seed_inicial',true,'Melancia','Frutas','1 fatia',200, 33, 0.9, 8.1, 0.0, 0.1, 1),
  ('s065','seed_inicial',true,'Abacate','Frutas','1 colher de sopa',30, 96, 1.2, 6.0, 8.4, 6.3, 1),
  ('s066','seed_inicial',true,'Morango','Frutas','1 xícara',150, 30, 0.9, 6.8, 0.3, 1.7, 1),
  ('s067','seed_inicial',true,'Uva itália','Frutas','1 cacho pequeno',100, 53, 0.7, 13.6, 0.2, 0.9, 1),
  ('s068','seed_inicial',true,'Manga palmer','Frutas','1 unidade pequena',150, 72, 0.4, 19.4, 0.2, 1.6, 1),
  ('s069','seed_inicial',true,'Abacaxi','Frutas','1 fatia',75, 48, 0.9, 12.3, 0.1, 1.0, 1),

  -- ── Verduras e legumes ────────────────────────────────────
  ('s070','seed_inicial',true,'Alface crespa','Verduras e legumes','1 prato de sobremesa',40, 11, 1.3, 1.7, 0.2, 1.8, 7),
  ('s071','seed_inicial',true,'Tomate','Verduras e legumes','1 unidade média',110, 15, 1.1, 3.1, 0.2, 1.2, 1),
  ('s072','seed_inicial',true,'Brócolis cozido','Verduras e legumes','1 colher de servir',60, 25, 2.1, 4.4, 0.5, 3.4, 4),
  ('s073','seed_inicial',true,'Cenoura crua','Verduras e legumes','1 unidade média',80, 34, 1.3, 7.7, 0.2, 3.2, 65),
  ('s074','seed_inicial',true,'Abobrinha cozida','Verduras e legumes','1 colher de servir',60, 19, 1.1, 4.3, 0.2, 1.6, 2),
  ('s075','seed_inicial',true,'Couve manteiga refogada','Verduras e legumes','1 colher de servir',40, 90, 1.7, 3.9, 7.9, 3.1, 5),
  ('s076','seed_inicial',true,'Beterraba cozida','Verduras e legumes','1 colher de servir',60, 32, 1.3, 7.2, 0.1, 1.9, 36),
  ('s077','seed_inicial',true,'Pepino','Verduras e legumes','1 unidade pequena',100, 10, 0.9, 2.0, 0.0, 1.1, 1),
  ('s078','seed_inicial',true,'Chuchu cozido','Verduras e legumes','1 colher de servir',60, 19, 0.4, 4.8, 0.1, 1.0, 1),

  -- ── Gorduras e oleaginosas ────────────────────────────────
  ('s080','seed_inicial',true,'Azeite de oliva extravirgem','Gorduras','1 colher de sopa',8, 884, 0.0, 0.0, 100.0, 0.0, 2),
  ('s081','seed_inicial',true,'Óleo de soja','Gorduras','1 colher de sopa',8, 884, 0.0, 0.0, 100.0, 0.0, 0),
  ('s082','seed_inicial',true,'Manteiga com sal','Gorduras','1 ponta de faca',5, 726, 0.4, 0.1, 82.4, 0.0, 579),
  ('s083','seed_inicial',true,'Castanha-do-pará','Gorduras','1 unidade',5, 643, 14.5, 15.1, 63.5, 7.9, 1),
  ('s084','seed_inicial',true,'Amendoim torrado','Gorduras','1 colher de sopa',15, 544, 27.2, 20.3, 43.9, 8.0, 5),
  ('s085','seed_inicial',true,'Pasta de amendoim integral','Gorduras','1 colher de sopa',20, 588, 25.0, 20.0, 50.0, 6.0, 17),
  ('s086','seed_inicial',true,'Castanha de caju torrada','Gorduras','1 colher de sopa',15, 570, 18.5, 29.1, 46.3, 3.7, 16),

  -- ── Suplementos ───────────────────────────────────────────
  ('s090','seed_inicial',true,'Whey protein concentrado','Suplementos','1 scoop',30, 400, 75.0, 10.0, 6.0, 0.0, 200),
  ('s091','seed_inicial',true,'Whey protein isolado','Suplementos','1 scoop',30, 370, 88.0, 2.0, 1.0, 0.0, 180),
  ('s092','seed_inicial',true,'Albumina em pó','Suplementos','1 colher de sopa',15, 370, 80.0, 5.0, 1.0, 0.0, 600),
  ('s093','seed_inicial',true,'Creatina monoidratada','Suplementos','1 colher de chá',5, 0, 0.0, 0.0, 0.0, 0.0, 0),
  ('s094','seed_inicial',true,'Maltodextrina','Suplementos','1 colher de sopa',15, 380, 0.0, 95.0, 0.0, 0.0, 10),

  -- ── Açúcares e outros ─────────────────────────────────────
  ('s100','seed_inicial',true,'Açúcar refinado','Açúcares','1 colher de chá',5, 387, 0.0, 99.5, 0.0, 0.0, 1),
  ('s101','seed_inicial',true,'Mel de abelha','Açúcares','1 colher de sopa',20, 309, 0.4, 84.0, 0.0, 0.0, 6),
  ('s102','seed_inicial',true,'Chocolate meio amargo 70%','Açúcares','1 quadrado',10, 540, 7.8, 45.9, 35.4, 10.9, 20),
  ('s103','seed_inicial',true,'Café coado sem açúcar','Bebidas','1 xícara',50, 2, 0.1, 0.3, 0.0, 0.0, 1),
  ('s104','seed_inicial',true,'Suco de laranja natural','Bebidas','1 copo',200, 37, 0.7, 8.7, 0.1, 0.2, 1),
  ('s105','seed_inicial',true,'Água de coco','Bebidas','1 copo',200, 22, 0.0, 5.3, 0.0, 0.1, 25)

on conflict (fonte, codigo_origem) do update set
  nome           = excluded.nome,
  grupo          = excluded.grupo,
  medida_caseira = excluded.medida_caseira,
  medida_gramas  = excluded.medida_gramas,
  kcal           = excluded.kcal,
  proteina       = excluded.proteina,
  carboidrato    = excluded.carboidrato,
  gordura        = excluded.gordura,
  fibra          = excluded.fibra,
  sodio          = excluded.sodio;

notify pgrst, 'reload schema';

-- Conferência: quantos alimentos por grupo.
select grupo, count(*) as quantidade
  from public.alimentos
 where fonte = 'seed_inicial'
 group by grupo
 order by grupo;
