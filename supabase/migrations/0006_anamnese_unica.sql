-- ============================================================
-- 0006 — Uma anamnese por aluno
--
-- Correção de um erro meu no 0001.
--
-- Eu criei o índice único em (aluno_id, tipo), imaginando histórico por
-- tipo de questionário. Mas o app não tem esse modelo:
--
--   • `alunos.anamnese_tipo` é UMA coluna — o aluno tem um tipo, não vários
--   • o upsert usa `onConflict: 'aluno_id'`
--   • a leitura é `.eq('aluno_id', ...).maybeSingle()`, que LANÇA EXCEÇÃO
--     se voltar mais de uma linha
--
-- Com (aluno_id, tipo), o upsert falharia na hora — não existe constraint
-- que case com 'aluno_id' sozinho. E se um dia o personal trocasse o tipo
-- do questionário, nasceriam duas linhas e a tela de visualização quebraria
-- no `maybeSingle()`.
--
-- Seguro rodar mais de uma vez.
-- ============================================================

drop index if exists public.anamnese_aluno_tipo_key;

create unique index if not exists anamnese_aluno_key
  on public.anamnese (aluno_id);

comment on table public.anamnese is
  'Uma linha por aluno. Trocar `alunos.anamnese_tipo` substitui as respostas em vez de criar um novo questionário — se um dia for preciso guardar histórico, isto vira (aluno_id, tipo) e a leitura precisa passar a filtrar por tipo.';
