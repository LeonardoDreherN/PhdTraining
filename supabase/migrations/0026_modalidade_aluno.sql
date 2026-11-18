-- ════════════════════════════════════════════════════════════
--  0026 — Modalidade do atendimento
--
--  Online ou presencial. É o recorte que o personal usa para organizar o
--  dia: quem ele vê na academia e quem acompanha à distância.
--
--  Nulo é "não informado", e não um terceiro tipo. Os alunos que já
--  existem ficam assim até alguém dizer — chutar "presencial" para todo
--  mundo encheria o filtro de resposta errada, que é pior que resposta
--  nenhuma.
--
--  O OUTRO FILTRO NÃO PRECISA DE COLUNA
--
--  Separar por serviço contratado (treino, dieta, os dois) sai do plano
--  que o aluno assinou: `personal_planos` já tem `inclui_treino` e
--  `inclui_dieta`. Guardar isso de novo em `alunos` criaria duas
--  verdades que divergem na primeira troca de plano.
--
--  Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

alter table public.alunos
  add column if not exists modalidade text
    check (modalidade in ('online', 'presencial'));

-- A modalidade já existia disfarçada: o cadastro oferecia só
-- 'Presencial' e 'Online' no campo `grupo`, que é texto livre. Traz
-- esses valores para a coluna certa e deixa `grupo` livre para o que ele
-- deveria ser — turma, horário, o que o personal quiser.
--
-- Só converte o que bate exatamente com os dois rótulos; qualquer outra
-- coisa que alguém tenha digitado em `grupo` fica onde está.
update public.alunos
   set modalidade = lower(btrim(grupo))
 where modalidade is null
   and lower(btrim(coalesce(grupo, ''))) in ('online', 'presencial');

comment on column public.alunos.modalidade is
  'online | presencial | null quando não informado. O filtro por serviço contratado não mora aqui: sai de personal_planos via aluno_assinaturas.';

-- O filtro da carteira passa por esta coluna junto com personal_id.
create index if not exists alunos_modalidade_idx
  on public.alunos (personal_id, modalidade) where modalidade is not null;

notify pgrst, 'reload schema';

-- Conferência: a coluna existe e ninguém foi preenchido no chute.
select count(*)                                            as alunos,
       count(*) filter (where modalidade = 'online')       as online,
       count(*) filter (where modalidade = 'presencial')   as presencial,
       count(*) filter (where modalidade is null)          as nao_informado,
       count(*) filter (where modalidade is null
                          and coalesce(btrim(grupo), '') <> '')
                                                           as grupo_nao_convertido
  from public.alunos;
