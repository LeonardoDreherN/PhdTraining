-- ════════════════════════════════════════════════════════════
--  0039 — A tabela do check-in, que nunca chegou a existir
--
--  Recordes e Desbloqueios não abriam:
--
--    relation "public.nutricao_checkins" does not exist   (42P01)
--
--  A tabela é do 0030. Só ela faltava no banco: conferi as dez tabelas
--  e as doze funções do 0029 ao 0038, e todo o resto estava lá.
--
--  POR QUE NINGUÉM PERCEBEU
--
--  O corpo de uma função plpgsql não é conferido quando ela é criada —
--  só quando roda. Então o 0031, o 0034, o 0035 e o 0038 recriaram
--  `numeros_do_aluno` lendo uma tabela inexistente, e os quatro
--  disseram "Success". O banco só reclamou quando alguém abriu a tela.
--
--  Esta é também a razão de a conferência do 0038 ter passado: ela
--  olhou o TEXTO da função, não a execução. Olhar texto não prova nada
--  aqui — a do fim deste arquivo lista objetos que faltam.
--
--  O QUE ESTE ARQUIVO FAZ
--
--  Só a tabela, os índices e as policies do 0030, palavra por palavra.
--  Nada de função: as versões vivas já são as do 0038, mais novas, e
--  recriá-las a partir do 0030 seria desfazer oito migrations.
--
--  Depende do 0001. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create table if not exists public.nutricao_checkins (
  id         uuid primary key default gen_random_uuid(),
  aluno_id   uuid not null references public.alunos(id) on delete cascade,

  -- Sempre o dia 1 do mês de referência.
  mes        date not null check (mes = date_trunc('month', mes)::date),

  -- 1 a 5: o quanto conseguiu seguir o plano, e como está a disposição.
  -- Escala, não nota: o texto de cada degrau mora no app.
  adesao     smallint not null check (adesao between 1 and 5),
  energia    smallint check (energia is null or energia between 1 and 5),

  -- O que dificultou. Lista de códigos; os rótulos moram no catálogo do
  -- app, pelo mesmo motivo das conquistas — texto em banco envelhece
  -- sem migration.
  dificuldades text[] not null default '{}',

  -- Digestão. Opcional de propósito: é a pergunta mais invasiva do
  -- formulário, e obrigar a responder é a melhor forma de fazer o aluno
  -- abandonar o check-in.
  intestino  text check (intestino is null or intestino in
               ('bem', 'inchaco', 'constipacao', 'solto')),

  observacoes text check (observacoes is null or length(btrim(observacoes)) <= 2000),

  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),

  unique (aluno_id, mes)
);

create index if not exists nutricao_checkins_idx
  on public.nutricao_checkins (aluno_id, mes desc);

-- ════════════════════════════════════════════════════════════
--  RLS
-- ════════════════════════════════════════════════════════════

alter table public.nutricao_checkins enable row level security;

-- Lê quem acompanha o aluno — ele mesmo, o personal, e a equipe com
-- escopo de nutrição (é o que `aluno_e_meu` já resolve desde o 0025).
drop policy if exists "check-in: quem acompanha lê" on public.nutricao_checkins;
create policy "check-in: quem acompanha lê"
  on public.nutricao_checkins for select to authenticated
  using (public.aluno_e_meu(aluno_id));

-- Escreve só o aluno. O profissional não responde no lugar dele: um
-- autorrelato preenchido por outra pessoa não é autorrelato, e a
-- conquista viraria medalha por algo que o aluno não fez.
drop policy if exists "check-in: só o aluno responde" on public.nutricao_checkins;
create policy "check-in: só o aluno responde"
  on public.nutricao_checkins for insert to authenticated
  with check (
    exists (select 1 from public.alunos a
             where a.id = nutricao_checkins.aluno_id and a.user_id = auth.uid())
    -- Não dá para responder mês que não chegou.
    and mes <= date_trunc('month', current_date)::date
  );

-- Corrigir, mas só o do mês corrente. Reescrever o de março em
-- novembro não é correção, é reconstrução de memória — e o
-- profissional já leu o original.
drop policy if exists "check-in: o aluno corrige o do mês" on public.nutricao_checkins;
create policy "check-in: o aluno corrige o do mês"
  on public.nutricao_checkins for update to authenticated
  using (
    mes = date_trunc('month', current_date)::date
    and exists (select 1 from public.alunos a
                 where a.id = nutricao_checkins.aluno_id and a.user_id = auth.uid())
  )
  with check (
    mes = date_trunc('month', current_date)::date
    and exists (select 1 from public.alunos a
                 where a.id = nutricao_checkins.aluno_id and a.user_id = auth.uid())
  );

-- Sem política de DELETE: ninguém apaga check-in. O histórico é o
-- produto aqui — uma série que pode ser editada para trás não serve
-- para acompanhar ninguém.

grant select, insert, update on public.nutricao_checkins to authenticated;

notify pgrst, 'reload schema';

-- ════════════════════════════════════════════════════════════
--  CONFERÊNCIA
--
--  Não "a tabela nasceu", e sim "o que ainda falta no banco inteiro".
--  Deve vir VAZIA. Qualquer linha aqui é uma migration que disse
--  "Success" sem ter feito o que dizia.
-- ════════════════════════════════════════════════════════════

with esperado(migracao, tipo, nome) as (values
  ('0029','tabela','feed_posts'),        ('0029','tabela','feed_reacoes'),
  ('0029','tabela','feed_comentarios'),  ('0029','tabela','feed_denuncias'),
  ('0029','tabela','comunidade_config'), ('0029','tabela','aluno_feed_prefs'),
  ('0030','tabela','nutricao_checkins'),
  ('0034','tabela','acompanhamento_config'),
  ('0035','tabela','planejamento_semana'),
  ('0037','tabela','feed_notificacoes'),
  ('0029','funcao','gerar_destaques'),      ('0029','funcao','feed_e_meu'),
  ('0029','funcao','publicar_conquistas'),  ('0029','funcao','rodar_destaques_agendados'),
  ('0031','funcao','desbloquear_da_ficha'), ('0032','funcao','denuncias_pendentes'),
  ('0037','funcao','avisos_nao_lidos'),     ('0037','funcao','marcar_avisos_lidos'),
  ('0037','funcao','quer_aviso'),           ('0037','funcao','usuario_do_aluno'),
  ('0038','funcao','numeros_do_aluno'),     ('0038','funcao','conceder_conquistas')
)
select e.migracao, e.tipo, e.nome
  from esperado e
 where not case when e.tipo = 'tabela'
            then exists (select 1 from information_schema.tables
                          where table_schema = 'public' and table_name = e.nome)
            else exists (select 1 from pg_proc p
                           join pg_namespace n on n.oid = p.pronamespace
                          where n.nspname = 'public' and p.proname = e.nome)
       end
 order by e.migracao, e.tipo, e.nome;
