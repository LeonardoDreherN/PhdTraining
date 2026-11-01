-- ════════════════════════════════════════════════════════════
--  0021 — Nome do alimento para o aluno
--
--  O nutricionista escolhe "Ovo, de galinha, inteiro, cozido/10minutos"
--  pela composição, mas quer que o aluno leia "Ovo cozido, grelhado ou
--  mexido". `nome_exibicao` é esse texto: aparece para o aluno e no PDF.
--  Os nutrientes continuam vindo de `alimento_id`.
--
--  Nulo = o aluno vê o nome da tabela.
--
--  Depende do 0010. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

alter table public.refeicao_itens
  add column if not exists nome_exibicao text;

notify pgrst, 'reload schema';
