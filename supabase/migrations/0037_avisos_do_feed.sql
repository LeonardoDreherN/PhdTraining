-- ════════════════════════════════════════════════════════════
--  0037 — Os avisos do feed
--
--  O §5 da especificação pede notificar o aluno quando uma conquista
--  dele for publicada, quando alguém interagir com a publicação dele e
--  quando o professor publicar um aviso importante. E pede que o aluno
--  possa ajustar essas notificações.
--
--  Nada disso existia. O que o app tinha era notificação AGENDADA no
--  aparelho — lembrete de treino, de refeição, de água —, que dispara
--  por horário e no navegador é um stub que não faz nada. Não serve
--  para avisar sobre algo que aconteceu no servidor.
--
--  O QUE ESTA MIGRATION FAZ, E O QUE NÃO FAZ
--
--  Faz: uma caixa de avisos dentro do app, escrita por gatilhos no
--  banco e lida pelo aluno. Funciona no navegador e no celular, não
--  depende de infraestrutura nenhuma, e o aluno vê ao abrir o app.
--
--  Não faz: a notificação que chega com o app fechado. Aquela precisa
--  de Firebase configurado e de uma função que dispare o envio. Esta
--  tabela é a base das duas — quando o push existir, ele lê daqui em
--  vez de recomeçar.
--
--  QUEM ESCREVE É O BANCO
--
--  Nenhuma policy de insert para o cliente, de propósito. Um aviso que
--  o app pudesse inserir seria um aviso que qualquer um com a chave
--  anônima escreve na caixa de outra pessoa. Só os gatilhos escrevem, e
--  eles rodam `security definer`.
--
--  Depende do 0029. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- As preferências do aluno. Tudo ligado por padrão: aqui o silêncio é
-- o estranho — ele pediu para participar da comunidade, e não saber que
-- comentaram na própria foto é defeito, não privacidade.
--
-- (Diferente do consentimento de conquista, que nasce DESLIGADO: lá a
-- escolha é expor-se aos outros, aqui é ser avisado sobre si.)
alter table public.aluno_feed_prefs
  add column if not exists avisa_conquista boolean not null default true,
  add column if not exists avisa_interacao boolean not null default true,
  add column if not exists avisa_aviso     boolean not null default true;

create table if not exists public.feed_notificacoes (
  id             uuid primary key default gen_random_uuid(),

  -- Quem deve ver. É o `profiles.id`, não o `alunos.id`: quem abre o
  -- app é um usuário, e o mesmo aviso um dia pode ir para alguém da
  -- equipe que não é aluno de ninguém.
  destinatario_id uuid not null references public.profiles(id) on delete cascade,
  personal_id     uuid not null references public.profiles(id) on delete cascade,

  tipo  text not null
    check (tipo in ('conquista', 'destaque', 'reacao', 'comentario', 'aviso')),

  -- A publicação de que o aviso fala. Apagar a publicação apaga o
  -- aviso: um aviso que leva a lugar nenhum é pior do que nenhum.
  post_id   uuid references public.feed_posts(id) on delete cascade,

  -- Quem causou. Nulo nos automáticos — não foi ninguém.
  origem_id uuid references public.profiles(id) on delete set null,

  lida_em   timestamptz,
  criado_em timestamptz not null default now()
);

-- A consulta que o app faz é sempre "o que ainda não li": índice
-- parcial, porque o não lido é pouco e o lido cresce para sempre.
create index if not exists feed_notificacoes_nao_lidas
  on public.feed_notificacoes (destinatario_id, criado_em desc)
  where lida_em is null;

create index if not exists feed_notificacoes_idx
  on public.feed_notificacoes (destinatario_id, criado_em desc);

-- Reagir, tirar a reação e reagir de novo não gera três avisos.
create unique index if not exists feed_notificacoes_interacao_unica
  on public.feed_notificacoes (destinatario_id, post_id, origem_id, tipo)
  where tipo = 'reacao';

alter table public.feed_notificacoes enable row level security;

-- Cada um vê a própria caixa. Nem o profissional lê a caixa do aluno:
-- saber que avisaram alguém não é informação dele.
drop policy if exists "avisos: cada um vê a própria caixa" on public.feed_notificacoes;
create policy "avisos: cada um vê a própria caixa"
  on public.feed_notificacoes for select to authenticated
  using (destinatario_id = auth.uid());

-- Marcar como lido é a única escrita do cliente.
drop policy if exists "avisos: marcar como lido" on public.feed_notificacoes;
create policy "avisos: marcar como lido"
  on public.feed_notificacoes for update to authenticated
  using (destinatario_id = auth.uid())
  with check (destinatario_id = auth.uid());

drop policy if exists "avisos: apagar o próprio" on public.feed_notificacoes;
create policy "avisos: apagar o próprio"
  on public.feed_notificacoes for delete to authenticated
  using (destinatario_id = auth.uid());

-- Sem `insert`: ver o cabeçalho.
grant select, update, delete on public.feed_notificacoes to authenticated;

-- ════════════════════════════════════════════════════════════
--  QUEM RECEBE
-- ════════════════════════════════════════════════════════════

-- O usuário por trás de um `alunos.id`, se houver.
--
-- Aluno sem `user_id` é cadastro que ainda não virou conta. Não há para
-- quem avisar, e o gatilho simplesmente não insere.
create or replace function public.usuario_do_aluno(p_aluno_id uuid)
returns uuid
language sql stable security definer set search_path = public as $$
  select user_id from public.alunos where id = p_aluno_id;
$$;

-- A preferência do aluno para um tipo de aviso.
--
-- Sem linha em `aluno_feed_prefs` vale `true`: as colunas nasceram com
-- default true e a ausência de linha significa "nunca mexeu".
create or replace function public.quer_aviso(p_aluno_id uuid, p_tipo text)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select case p_tipo
              when 'conquista'  then avisa_conquista
              when 'destaque'   then avisa_conquista
              when 'reacao'     then avisa_interacao
              when 'comentario' then avisa_interacao
              when 'aviso'      then avisa_aviso
            end
       from public.aluno_feed_prefs where aluno_id = p_aluno_id),
    true);
$$;

-- ════════════════════════════════════════════════════════════
--  GATILHOS
-- ════════════════════════════════════════════════════════════

-- Publicação nova: conquista e destaque avisam o aluno dela; aviso
-- FIXADO avisa a comunidade inteira.
--
-- Fixado e não todo aviso: a especificação diz "aviso IMPORTANTE", e
-- fixar no topo é exatamente como o professor diz que algo é
-- importante neste app. Avisar a cada recado transformaria o sino em
-- ruído, e um sino que toca sempre ninguém olha.
create or replace function public.tg_avisar_publicacao()
returns trigger
language plpgsql security definer set search_path = public as $$
declare v_user uuid;
begin
  if new.tipo in ('conquista', 'destaque') and new.aluno_id is not null then
    if not public.quer_aviso(new.aluno_id, new.tipo) then
      return new;
    end if;

    v_user := public.usuario_do_aluno(new.aluno_id);
    if v_user is null then return new; end if;

    insert into public.feed_notificacoes
      (destinatario_id, personal_id, tipo, post_id)
    values (v_user, new.personal_id, new.tipo, new.id);

  elsif new.tipo = 'aviso' and new.fixado then
    insert into public.feed_notificacoes
      (destinatario_id, personal_id, tipo, post_id, origem_id)
    select a.user_id, new.personal_id, 'aviso', new.id, new.autor_id
      from public.alunos a
     where a.personal_id = new.personal_id
       and a.user_id is not null
       and a.user_id <> coalesce(new.autor_id, '00000000-0000-0000-0000-000000000000'::uuid)
       and public.quer_aviso(a.id, 'aviso');
  end if;

  return new;
end $$;

drop trigger if exists avisar_publicacao on public.feed_posts;
create trigger avisar_publicacao
  after insert on public.feed_posts
  for each row execute function public.tg_avisar_publicacao();

-- Alguém reagiu ou comentou numa publicação. Avisa o autor dela.
create or replace function public.tg_avisar_interacao()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_post   record;
  v_quem   uuid;
  v_tipo   text;
  v_aluno  uuid;
begin
  v_tipo := case tg_table_name when 'feed_reacoes' then 'reacao'
                               else 'comentario' end;
  v_quem := case tg_table_name when 'feed_reacoes' then new.usuario_id
                               else new.autor_id end;

  select p.id, p.autor_id, p.personal_id, p.aluno_id
    into v_post
    from public.feed_posts p where p.id = new.post_id;

  -- Publicação automática não tem autor; e reagir à própria publicação
  -- não avisa ninguém — a pessoa sabe o que acabou de fazer.
  if v_post.autor_id is null or v_post.autor_id = v_quem then
    return new;
  end if;

  -- A preferência é do ALUNO. Quando o autor é o profissional não há
  -- aluno para consultar, e o aviso vai: ele é o dono do feed.
  v_aluno := v_post.aluno_id;
  if v_aluno is not null and not public.quer_aviso(v_aluno, v_tipo) then
    return new;
  end if;

  insert into public.feed_notificacoes
    (destinatario_id, personal_id, tipo, post_id, origem_id)
  values (v_post.autor_id, v_post.personal_id, v_tipo, v_post.id, v_quem)
  on conflict do nothing;

  return new;
end $$;

drop trigger if exists avisar_reacao on public.feed_reacoes;
create trigger avisar_reacao
  after insert on public.feed_reacoes
  for each row execute function public.tg_avisar_interacao();

drop trigger if exists avisar_comentario on public.feed_comentarios;
create trigger avisar_comentario
  after insert on public.feed_comentarios
  for each row execute function public.tg_avisar_interacao();

-- ════════════════════════════════════════════════════════════
--  LEITURA
-- ════════════════════════════════════════════════════════════

-- O número do sino.
create or replace function public.avisos_nao_lidos()
returns integer
language sql stable security definer set search_path = public as $$
  select count(*)::integer from public.feed_notificacoes
   where destinatario_id = auth.uid() and lida_em is null;
$$;

-- Marca tudo como lido de uma vez.
create or replace function public.marcar_avisos_lidos()
returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  update public.feed_notificacoes
     set lida_em = now()
   where destinatario_id = auth.uid() and lida_em is null;
  get diagnostics n = row_count;
  return n;
end $$;

revoke all on function public.usuario_do_aluno(uuid)  from public;
revoke all on function public.quer_aviso(uuid, text)  from public;
revoke all on function public.avisos_nao_lidos()      from public;
revoke all on function public.marcar_avisos_lidos()   from public;
grant execute on function public.avisos_nao_lidos()    to authenticated;
grant execute on function public.marcar_avisos_lidos() to authenticated;

notify pgrst, 'reload schema';

-- Conferência: a tabela, as três colunas de preferência, os três
-- gatilhos e as duas funções de leitura.
select
  (select count(*) from information_schema.tables
    where table_schema = 'public' and table_name = 'feed_notificacoes')  as tabela_1,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'aluno_feed_prefs'
      and column_name like 'avisa_%')                                    as prefs_3,
  (select count(*) from pg_trigger
    where not tgisinternal
      and tgname in ('avisar_publicacao', 'avisar_reacao',
                     'avisar_comentario'))                               as gatilhos_3,
  (select count(*) from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public'
      and p.proname in ('avisos_nao_lidos', 'marcar_avisos_lidos',
                        'quer_aviso', 'usuario_do_aluno'))               as funcoes_4;
