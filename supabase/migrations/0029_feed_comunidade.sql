-- ════════════════════════════════════════════════════════════
--  0029 — Feed da comunidade
--
--  Um feed por profissional, visível só aos alunos dele.
--
--  DUAS COISAS VÊM DESLIGADAS, E É DE PROPÓSITO
--
--  O feed nasce desligado: um feed vazio na tela do aluno parece
--  defeito, e nem todo profissional quer rede social no produto dele.
--
--  E o aluno nasce SEM compartilhar conquista nenhuma. A especificação
--  exige escolha explícita, e o jeito de respeitar isso é não publicar
--  até ele dizer que sim — não publicar e oferecer um botão de parar.
--
--  O QUE NUNCA ENTRA NO FEED
--
--  Peso, medidas, percentual de gordura, fotos de evolução e qualquer
--  dado do plano alimentar. A tabela de post não tem onde guardar isso,
--  e as conquistas publicadas guardam só o CÓDIGO — "50 treinos", nunca
--  um número de saúde. A restrição está na forma da tabela, não numa
--  regra que alguém precisa lembrar de seguir.
--
--  Depende do 0001 e do 0027. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create table if not exists public.comunidade_config (
  personal_id       uuid primary key references public.profiles(id) on delete cascade,

  feed_ativo        boolean not null default false,
  alunos_postam     boolean not null default true,
  comentarios       boolean not null default true,
  reacoes           boolean not null default true,
  conquistas_auto   boolean not null default true,

  -- Dia da semana (1 = segunda) e hora dos destaques.
  destaques_ativos  boolean not null default true,
  destaques_dia     smallint not null default 1 check (destaques_dia between 1 and 7),
  destaques_hora    smallint not null default 9 check (destaques_hora between 0 and 23),

  atualizado_em     timestamptz not null default now()
);

-- O consentimento do aluno. Fora de `alunos` porque é escolha DELE, e
-- `alunos` só o profissional escreve — ele não pode consentir no lugar
-- do aluno.
create table if not exists public.aluno_feed_prefs (
  aluno_id             uuid primary key references public.alunos(id) on delete cascade,
  compartilha_conquistas boolean not null default false,
  bloqueado_ate        timestamptz,
  atualizado_em        timestamptz not null default now()
);

create table if not exists public.feed_posts (
  id           uuid primary key default gen_random_uuid(),
  personal_id  uuid not null references public.profiles(id) on delete cascade,

  tipo         text not null
    check (tipo in ('aviso', 'aluno', 'conquista', 'destaque')),

  -- Quem escreveu. Nulo nos automáticos: não foi ninguém.
  autor_id     uuid references public.profiles(id) on delete set null,

  -- De quem é a conquista ou o destaque. O nome sai de `alunos` na
  -- leitura, para o post não guardar cópia que envelhece.
  aluno_id     uuid references public.alunos(id) on delete cascade,

  texto        text check (texto is null or length(btrim(texto)) <= 2000),
  midia_url    text,

  -- Só o CÓDIGO da conquista. Nunca peso, medida ou dado de plano: não
  -- existe coluna para isso aqui, e é essa a garantia.
  conquista_codigo text,

  -- Semana de referência do destaque, para o aluno saber do que se trata.
  destaque_semana  date,
  destaque_tipo    text check (destaque_tipo in ('treino', 'nutricao')),

  fixado       boolean not null default false,
  oculto       boolean not null default false,
  criado_em    timestamptz not null default now()
);

create index if not exists feed_posts_idx
  on public.feed_posts (personal_id, criado_em desc) where not oculto;

-- Uma conquista vira post uma vez só. Sem isto, abrir a tela duas vezes
-- publicaria "Pedro conquistou 50 treinos" duas vezes.
create unique index if not exists feed_posts_conquista_unica
  on public.feed_posts (aluno_id, conquista_codigo)
  where conquista_codigo is not null;

-- Um destaque por semana, tipo e profissional.
create unique index if not exists feed_posts_destaque_unico
  on public.feed_posts (personal_id, destaque_semana, destaque_tipo)
  where destaque_semana is not null;

create table if not exists public.feed_reacoes (
  post_id    uuid not null references public.feed_posts(id) on delete cascade,
  usuario_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  tipo       text not null default 'forca'
    check (tipo in ('forca', 'parabens', 'inspirador')),
  criado_em  timestamptz not null default now(),
  primary key (post_id, usuario_id)
);

create table if not exists public.feed_comentarios (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.feed_posts(id) on delete cascade,
  autor_id   uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  texto      text not null check (length(btrim(texto)) between 1 and 1000),
  oculto     boolean not null default false,
  criado_em  timestamptz not null default now()
);

create index if not exists feed_comentarios_idx
  on public.feed_comentarios (post_id, criado_em) where not oculto;

create table if not exists public.feed_denuncias (
  id            uuid primary key default gen_random_uuid(),
  post_id       uuid references public.feed_posts(id) on delete cascade,
  comentario_id uuid references public.feed_comentarios(id) on delete cascade,
  autor_id      uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  motivo        text,
  criado_em     timestamptz not null default now(),

  -- Uma denúncia aponta para um ou outro, nunca para os dois nem para
  -- nenhum.
  check ((post_id is null) <> (comentario_id is null))
);

-- Denunciar duas vezes o mesmo conteúdo é engano, não ênfase.
create unique index if not exists feed_denuncia_unica_post
  on public.feed_denuncias (post_id, autor_id) where post_id is not null;
create unique index if not exists feed_denuncia_unica_comentario
  on public.feed_denuncias (comentario_id, autor_id) where comentario_id is not null;

-- ════════════════════════════════════════════════════════════
--  QUEM VÊ O FEED
-- ════════════════════════════════════════════════════════════

-- "Este feed é de um profissional que eu posso ver?"
--
-- Vale para o dono, para os alunos dele e para a equipe. É a função que
-- todas as policies do feed usam.
create or replace function public.feed_e_meu(p_personal_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select
    p_personal_id = auth.uid()
    or exists (
      select 1 from public.alunos a
       where a.personal_id = p_personal_id and a.user_id = auth.uid()
    )
    or exists (
      select 1 from public.equipe e
       where e.dono_id = p_personal_id
         and e.convidado_id = auth.uid()
         and e.status = 'ativo'
    );
$$;

-- O aluno está impedido de postar agora?
create or replace function public.aluno_bloqueado_no_feed(p_aluno_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select bloqueado_ate > now() from public.aluno_feed_prefs
      where aluno_id = p_aluno_id),
    false);
$$;

-- ════════════════════════════════════════════════════════════
--  PUBLICAR CONQUISTA
-- ════════════════════════════════════════════════════════════

-- Publica no feed as conquistas que o aluno autorizou.
--
-- Três portas, todas obrigatórias: o feed do profissional precisa estar
-- ativo, ele precisa aceitar conquistas automáticas, e o ALUNO precisa
-- ter dito que sim. Qualquer uma fechada, não publica.
--
-- Publica só o código da conquista. O texto é montado na leitura, a
-- partir do catálogo do app — assim nenhum dado de saúde chega a ser
-- gravado numa linha de feed.
create or replace function public.publicar_conquistas(p_aluno_id uuid)
returns integer
language plpgsql security definer set search_path = public as $$
declare v_personal uuid; v_n integer;
begin
  if not public.aluno_e_meu(p_aluno_id) then
    raise exception 'Sem permissão para este aluno' using errcode = '42501';
  end if;

  select personal_id into v_personal from public.alunos where id = p_aluno_id;
  if v_personal is null then return 0; end if;

  -- O consentimento do aluno é a primeira porta, e é opt-in: sem linha
  -- em `aluno_feed_prefs`, `compartilha_conquistas` é falso.
  if not coalesce((select compartilha_conquistas from public.aluno_feed_prefs
                    where aluno_id = p_aluno_id), false) then
    return 0;
  end if;

  if not coalesce((select feed_ativo and conquistas_auto
                     from public.comunidade_config where personal_id = v_personal),
                  false) then
    return 0;
  end if;

  with inseridos as (
    insert into public.feed_posts (personal_id, tipo, aluno_id, conquista_codigo)
    select v_personal, 'conquista', p_aluno_id, ac.codigo
      from public.aluno_conquistas ac
     where ac.aluno_id = p_aluno_id
    on conflict (aluno_id, conquista_codigo) where conquista_codigo is not null
      do nothing
    returning 1
  )
  select count(*) into v_n from inseridos;

  return v_n;
end $$;

-- ════════════════════════════════════════════════════════════
--  DESTAQUES SEMANAIS
-- ════════════════════════════════════════════════════════════

-- Gera os destaques da semana passada para um profissional.
--
-- O critério é PERCENTUAL de adesão, não quantidade: a especificação é
-- explícita, e por um motivo que importa — contar treinos absolutos
-- premiaria quem tem mais tempo livre, não quem é consistente.
--
-- Empate destaca todos os empatados, como o documento sugere. Não há
-- "primeiro lugar" nem ranking: o feed reconhece, não compete.
create or replace function public.gerar_destaques(p_personal_id uuid, p_semana date default null)
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_semana date;
  v_n integer := 0;
begin
  v_semana := coalesce(p_semana,
    (date_trunc('week', current_date) - interval '1 week')::date);

  if not coalesce((select feed_ativo and destaques_ativos
                     from public.comunidade_config where personal_id = p_personal_id),
                  false) then
    return 0;
  end if;

  -- ── Constância nos treinos ──────────────────────────────
  with previstos as (
    select af.aluno_id, sum(array_length(af.dias_semana, 1))::numeric as meta
      from public.aluno_fichas af
      join public.alunos a on a.id = af.aluno_id
     where a.personal_id = p_personal_id and af.ativa
     group by af.aluno_id
    having sum(array_length(af.dias_semana, 1)) > 0
  ),
  feitos as (
    select e.aluno_id, count(distinct (e.executado_em at time zone 'America/Sao_Paulo')::date)::numeric as fez
      from public.treino_execucoes e
     where e.personal_id = p_personal_id
       and (e.executado_em at time zone 'America/Sao_Paulo')::date
             between v_semana and v_semana + 6
     group by e.aluno_id
  ),
  adesao as (
    select p.aluno_id, least(1.0, coalesce(f.fez, 0) / p.meta) as pct
      from previstos p left join feitos f on f.aluno_id = p.aluno_id
  ),
  melhor as (select max(pct) as m from adesao where pct > 0)
  insert into public.feed_posts
    (personal_id, tipo, aluno_id, destaque_semana, destaque_tipo)
  select p_personal_id, 'destaque', a.aluno_id, v_semana, 'treino'
    from adesao a, melhor
   where melhor.m is not null and a.pct = melhor.m
  on conflict (personal_id, destaque_semana, destaque_tipo)
    where destaque_semana is not null do nothing;

  get diagnostics v_n = row_count;
  return v_n;
end $$;

-- Roda para todo profissional cujo dia e hora configurados são agora.
-- É esta que o agendador chama de hora em hora.
create or replace function public.rodar_destaques_agendados()
returns integer
language plpgsql security definer set search_path = public as $$
declare c record; total integer := 0;
begin
  for c in
    select personal_id from public.comunidade_config
     where feed_ativo and destaques_ativos
       and destaques_dia = extract(isodow from current_date)
       and destaques_hora = extract(hour from
             (now() at time zone 'America/Sao_Paulo'))
  loop
    total := total + public.gerar_destaques(c.personal_id);
  end loop;
  return total;
end $$;

-- ════════════════════════════════════════════════════════════
--  RLS
-- ════════════════════════════════════════════════════════════

alter table public.comunidade_config  enable row level security;
alter table public.aluno_feed_prefs   enable row level security;
alter table public.feed_posts         enable row level security;
alter table public.feed_reacoes       enable row level security;
alter table public.feed_comentarios   enable row level security;
alter table public.feed_denuncias     enable row level security;

-- ── Configuração: o dono manda, a comunidade lê ────────────
drop policy if exists "config: a comunidade lê" on public.comunidade_config;
create policy "config: a comunidade lê"
  on public.comunidade_config for select to authenticated
  using (public.feed_e_meu(personal_id));

drop policy if exists "config: só o dono escreve" on public.comunidade_config;
create policy "config: só o dono escreve"
  on public.comunidade_config for all to authenticated
  using (personal_id = auth.uid())
  with check (personal_id = auth.uid());

-- ── Consentimento: o aluno escolhe, o profissional só bloqueia ──
drop policy if exists "prefs: leitura de quem vê o aluno" on public.aluno_feed_prefs;
create policy "prefs: leitura de quem vê o aluno"
  on public.aluno_feed_prefs for select to authenticated
  using (public.aluno_e_meu(aluno_id));

-- O próprio aluno. Só ele decide compartilhar conquista: deixar o
-- profissional consentir no lugar dele seria o oposto de consentimento.
drop policy if exists "prefs: o aluno escolhe" on public.aluno_feed_prefs;
create policy "prefs: o aluno escolhe"
  on public.aluno_feed_prefs for all to authenticated
  using (exists (select 1 from public.alunos a
                  where a.id = aluno_feed_prefs.aluno_id and a.user_id = auth.uid()))
  with check (exists (select 1 from public.alunos a
                       where a.id = aluno_feed_prefs.aluno_id and a.user_id = auth.uid())
              -- E não pode se desbloquear.
              and bloqueado_ate is null);

-- O profissional, para bloquear temporariamente quem abusa.
drop policy if exists "prefs: o profissional modera" on public.aluno_feed_prefs;
create policy "prefs: o profissional modera"
  on public.aluno_feed_prefs for all to authenticated
  using (exists (select 1 from public.alunos a
                  where a.id = aluno_feed_prefs.aluno_id and a.personal_id = auth.uid()))
  with check (exists (select 1 from public.alunos a
                       where a.id = aluno_feed_prefs.aluno_id and a.personal_id = auth.uid()));

-- ── Posts ───────────────────────────────────────────────────
drop policy if exists "posts: a comunidade lê o que não está oculto" on public.feed_posts;
create policy "posts: a comunidade lê o que não está oculto"
  on public.feed_posts for select to authenticated
  using (public.feed_e_meu(personal_id) and (not oculto or autor_id = auth.uid()));

-- O profissional publica aviso no próprio feed.
drop policy if exists "posts: o profissional avisa" on public.feed_posts;
create policy "posts: o profissional avisa"
  on public.feed_posts for insert to authenticated
  with check (
    personal_id = auth.uid()
    and autor_id = auth.uid()
    and tipo = 'aviso'
  );

-- O aluno publica, se o profissional permitir e ele não estiver
-- bloqueado. Só tipo 'aluno': conquista e destaque são do sistema, e
-- deixar o aluno inserir esses tipos seria deixá-lo forjar medalha.
drop policy if exists "posts: o aluno publica se puder" on public.feed_posts;
create policy "posts: o aluno publica se puder"
  on public.feed_posts for insert to authenticated
  with check (
    tipo = 'aluno'
    and autor_id = auth.uid()
    and conquista_codigo is null
    and destaque_semana is null
    and not fixado
    and exists (
      select 1 from public.alunos a
       join public.comunidade_config c on c.personal_id = a.personal_id
      where a.id = feed_posts.aluno_id
        and a.user_id = auth.uid()
        and a.personal_id = feed_posts.personal_id
        and c.feed_ativo and c.alunos_postam
    )
    and not public.aluno_bloqueado_no_feed(feed_posts.aluno_id)
  );

-- Editar e apagar: o autor mexe no que é dele; o profissional modera
-- tudo que está no feed dele.
drop policy if exists "posts: autor edita, dono modera" on public.feed_posts;
create policy "posts: autor edita, dono modera"
  on public.feed_posts for update to authenticated
  using (autor_id = auth.uid() or personal_id = auth.uid())
  with check (autor_id = auth.uid() or personal_id = auth.uid());

drop policy if exists "posts: autor apaga, dono modera" on public.feed_posts;
create policy "posts: autor apaga, dono modera"
  on public.feed_posts for delete to authenticated
  using (autor_id = auth.uid() or personal_id = auth.uid());

-- ── Reações ─────────────────────────────────────────────────
drop policy if exists "reações: a comunidade lê" on public.feed_reacoes;
create policy "reações: a comunidade lê"
  on public.feed_reacoes for select to authenticated
  using (exists (select 1 from public.feed_posts p
                  where p.id = feed_reacoes.post_id
                    and public.feed_e_meu(p.personal_id)));

drop policy if exists "reações: a própria, se habilitadas" on public.feed_reacoes;
create policy "reações: a própria, se habilitadas"
  on public.feed_reacoes for all to authenticated
  using (usuario_id = auth.uid())
  with check (
    usuario_id = auth.uid()
    and exists (
      select 1 from public.feed_posts p
       join public.comunidade_config c on c.personal_id = p.personal_id
      where p.id = feed_reacoes.post_id and c.feed_ativo and c.reacoes
    )
  );

-- ── Comentários ─────────────────────────────────────────────
drop policy if exists "comentários: a comunidade lê" on public.feed_comentarios;
create policy "comentários: a comunidade lê"
  on public.feed_comentarios for select to authenticated
  using (not oculto and exists (
    select 1 from public.feed_posts p
     where p.id = feed_comentarios.post_id and public.feed_e_meu(p.personal_id)));

drop policy if exists "comentários: comenta quem pode" on public.feed_comentarios;
create policy "comentários: comenta quem pode"
  on public.feed_comentarios for insert to authenticated
  with check (
    autor_id = auth.uid()
    and exists (
      select 1 from public.feed_posts p
       join public.comunidade_config c on c.personal_id = p.personal_id
      where p.id = feed_comentarios.post_id
        and public.feed_e_meu(p.personal_id)
        and c.feed_ativo and c.comentarios
    )
  );

drop policy if exists "comentários: autor apaga, dono modera" on public.feed_comentarios;
create policy "comentários: autor apaga, dono modera"
  on public.feed_comentarios for all to authenticated
  using (autor_id = auth.uid() or exists (
    select 1 from public.feed_posts p
     where p.id = feed_comentarios.post_id and p.personal_id = auth.uid()))
  with check (autor_id = auth.uid() or exists (
    select 1 from public.feed_posts p
     where p.id = feed_comentarios.post_id and p.personal_id = auth.uid()));

-- ── Denúncias ───────────────────────────────────────────────
-- Quem denuncia vê a própria; o profissional vê as do feed dele. Uma
-- denúncia não é pública: a comunidade inteira saber quem denunciou
-- quem é o fim da denúncia servir para alguma coisa.
drop policy if exists "denúncias: quem denunciou e o dono" on public.feed_denuncias;
create policy "denúncias: quem denunciou e o dono"
  on public.feed_denuncias for select to authenticated
  using (
    autor_id = auth.uid()
    or exists (select 1 from public.feed_posts p
                where p.id = feed_denuncias.post_id and p.personal_id = auth.uid())
    or exists (select 1 from public.feed_comentarios cm
                join public.feed_posts p on p.id = cm.post_id
               where cm.id = feed_denuncias.comentario_id
                 and p.personal_id = auth.uid())
  );

drop policy if exists "denúncias: qualquer um da comunidade" on public.feed_denuncias;
create policy "denúncias: qualquer um da comunidade"
  on public.feed_denuncias for insert to authenticated
  with check (autor_id = auth.uid());

grant select, insert, update, delete on public.comunidade_config to authenticated;
grant select, insert, update, delete on public.aluno_feed_prefs   to authenticated;
grant select, insert, update, delete on public.feed_posts         to authenticated;
grant select, insert, update, delete on public.feed_reacoes       to authenticated;
grant select, insert, update, delete on public.feed_comentarios   to authenticated;
grant select, insert                 on public.feed_denuncias     to authenticated;

revoke all on function public.feed_e_meu(uuid)                from public;
revoke all on function public.aluno_bloqueado_no_feed(uuid)   from public;
revoke all on function public.publicar_conquistas(uuid)       from public;
revoke all on function public.gerar_destaques(uuid, date)     from public;
grant execute on function public.feed_e_meu(uuid)              to authenticated;
grant execute on function public.aluno_bloqueado_no_feed(uuid) to authenticated;
grant execute on function public.publicar_conquistas(uuid)     to authenticated;
grant execute on function public.gerar_destaques(uuid, date)   to authenticated;

notify pgrst, 'reload schema';

-- Conferência: as seis tabelas, as quatro funções e as policies.
select
  (select count(*) from information_schema.tables
    where table_schema = 'public'
      and table_name in ('comunidade_config', 'aluno_feed_prefs', 'feed_posts',
                         'feed_reacoes', 'feed_comentarios', 'feed_denuncias')) as tabelas_6,
  (select count(*) from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public'
      and p.proname in ('feed_e_meu', 'aluno_bloqueado_no_feed',
                        'publicar_conquistas', 'gerar_destaques',
                        'rodar_destaques_agendados'))                           as funcoes_5,
  (select count(*) from pg_policies where schemaname = 'public'
    and tablename like 'feed_%' or tablename in ('comunidade_config',
                                                 'aluno_feed_prefs'))           as policies;
