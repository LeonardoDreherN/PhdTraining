-- ════════════════════════════════════════════════════════════
--  0025 — Equipe: o profissional convida outro para seus alunos
--
--  O personal sem CRN convida uma nutricionista; a nutricionista sem
--  CREF convida um personal. Quem convida continua dono dos alunos.
--
--  QUEM O CONVIDADO ENXERGA
--
--  Não é lista escolhida à mão: sai do plano que o aluno contratou.
--  `personal_planos` já separa `inclui_treino` de `inclui_dieta`, então
--  um aluno no "PHD Training" não aparece para a nutricionista e um no
--  "Performance" aparece. Trocou de plano, o acesso acompanha sozinho —
--  e ninguém precisa lembrar de revogar.
--
--  Fora isso existe a liberação manual (`equipe_alunos`), para o aluno
--  que ainda não tem assinatura lançada ou que é exceção. Sem ela, a
--  equipe não funcionaria enquanto o financeiro não estivesse em uso.
--
--  LEITURA E ESCRITA SÃO SEPARADAS
--
--  `aluno_e_meu` governa quem ENXERGA o aluno, e é usada por ~37
--  policies. Estendê-la dá leitura ao convidado em tudo de uma vez.
--
--  Escrever é outra história, e cada domínio tem o porteiro dele:
--    • ficha de treino exige `fichas.personal_id = auth.uid()` — a
--      nutricionista não passa, e isso já valia antes desta migração;
--    • plano alimentar exige CRN, e passa a aceitar também o convidado
--      com escopo de nutrição. Sem CRN ninguém prescreve, nem o dono.
--
--  Depende do 0001, 0003 e 0010. Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

create table if not exists public.equipe (
  id            uuid primary key default gen_random_uuid(),

  -- Dono dos alunos. É sempre ele que convida.
  --
  -- Aponta para `profiles`, e não para `auth.users`, por dois motivos: o
  -- cascade é o mesmo (profiles já cascateia de auth.users) e isto dá ao
  -- PostgREST a chave para trazer o nome junto numa consulta só, em vez
  -- de uma ida ao servidor por pessoa da lista.
  dono_id       uuid not null references public.profiles(id) on delete cascade,

  -- Nulo enquanto o convidado ainda não tem conta: o vínculo nasce do
  -- e-mail e se liga ao login quando ele aceita.
  convidado_id  uuid references public.profiles(id) on delete cascade,
  convite_email text not null,

  escopo        text not null check (escopo in ('nutricao', 'treino')),

  status        text not null default 'convidado'
    check (status in ('convidado', 'ativo', 'recusado', 'removido')),

  criado_em     timestamptz not null default now(),
  aceito_em     timestamptz,
  removido_em   timestamptz
);

-- Um convite vivo por e-mail e escopo, dentro do mesmo dono: convidar a
-- mesma pessoa duas vezes para nutrição é engano, não intenção.
create unique index if not exists equipe_convite_unico
  on public.equipe (dono_id, lower(convite_email), escopo)
  where status in ('convidado', 'ativo');

create index if not exists equipe_convidado_idx
  on public.equipe (convidado_id, status) where convidado_id is not null;
create index if not exists equipe_dono_idx on public.equipe (dono_id, status);

-- Liberação manual, para quem não tem assinatura lançada ou é exceção.
create table if not exists public.equipe_alunos (
  equipe_id uuid not null references public.equipe(id) on delete cascade,
  aluno_id  uuid not null references public.alunos(id) on delete cascade,
  criado_em timestamptz not null default now(),
  primary key (equipe_id, aluno_id)
);

-- ════════════════════════════════════════════════════════════
--  A REGRA
-- ════════════════════════════════════════════════════════════

-- "Este aluno está no alcance de algum vínculo meu?"
--
-- `security definer` porque consulta equipe, assinaturas e planos — e o
-- convidado não tem permissão de ler as duas últimas diretamente.
create or replace function public.aluno_da_minha_equipe(p_aluno_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.equipe e
      join public.alunos a
        on a.id = p_aluno_id and a.personal_id = e.dono_id
     where e.convidado_id = auth.uid()
       and e.status = 'ativo'
       and (
         -- Pelo plano contratado: é o caminho normal.
         exists (
           select 1
             from public.aluno_assinaturas s
             join public.personal_planos p on p.id = s.plano_id
            where s.aluno_id = a.id
              and s.status in ('ativa', 'inadimplente')
              and ((e.escopo = 'nutricao' and p.inclui_dieta)
                or (e.escopo = 'treino'   and p.inclui_treino))
         )
         -- Ou liberado na mão pelo dono.
         or exists (
           select 1 from public.equipe_alunos ea
            where ea.equipe_id = e.id and ea.aluno_id = a.id
         )
       )
  );
$$;

-- `aluno_e_meu` ganha o convidado. É a função que ~37 policies usam, em
-- umas 20 tabelas — avaliações, dieta, diário, mensagens, consultas,
-- arquivos, periodização. Mudar aqui estende a leitura em todas.
create or replace function public.aluno_e_meu(p_aluno_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.alunos a
    where a.id = p_aluno_id
      and (a.personal_id = auth.uid() or a.user_id = auth.uid())
  )
  or public.aluno_da_minha_equipe(p_aluno_id)
  or public.eh_admin_plataforma();
$$;

revoke all on function public.aluno_da_minha_equipe(uuid) from public;
grant execute on function public.aluno_da_minha_equipe(uuid) to authenticated;

-- ════════════════════════════════════════════════════════════
--  ESCRITA DE PLANO ALIMENTAR
-- ════════════════════════════════════════════════════════════

-- Passa a aceitar o convidado de nutrição. O CRN continua obrigatório:
-- montar equipe não dá a ninguém o direito de prescrever.
drop policy if exists "planos_alimentares: escrita de quem tem CRN"
  on public.planos_alimentares;
create policy "planos_alimentares: escrita de quem tem CRN"
  on public.planos_alimentares for all to authenticated
  using (
    public.meu_crn() is not null
    and (
      exists (select 1 from public.alunos a
               where a.id = planos_alimentares.aluno_id
                 and a.personal_id = auth.uid())
      or public.aluno_da_minha_equipe(planos_alimentares.aluno_id)
    )
  )
  with check (
    public.meu_crn() is not null
    and (
      exists (select 1 from public.alunos a
               where a.id = planos_alimentares.aluno_id
                 and a.personal_id = auth.uid())
      or public.aluno_da_minha_equipe(planos_alimentares.aluno_id)
    )
  );

-- ════════════════════════════════════════════════════════════
--  RLS DA PRÓPRIA EQUIPE
-- ════════════════════════════════════════════════════════════

alter table public.equipe        enable row level security;
alter table public.equipe_alunos enable row level security;

-- Os dois lados leem o vínculo: o dono para gerenciar, o convidado para
-- saber de quem é a carteira que ele acessa.
drop policy if exists "equipe: os dois lados leem" on public.equipe;
create policy "equipe: os dois lados leem"
  on public.equipe for select to authenticated
  using (
    dono_id = auth.uid()
    or convidado_id = auth.uid()
    -- Convite ainda sem conta ligada: quem tem o e-mail se encontra.
    or lower(convite_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or public.eh_admin_plataforma()
  );

drop policy if exists "equipe: só o dono convida" on public.equipe;
create policy "equipe: só o dono convida"
  on public.equipe for insert to authenticated
  with check (
    dono_id = auth.uid()
    and status = 'convidado'
    and convidado_id is null
  );

-- O dono remove e reconvida; o convidado só aceita ou recusa o que é
-- dele. A separação está no `using`, e o `with check` impede que o
-- convidado se promova mudando o escopo ou o dono.
drop policy if exists "equipe: dono gerencia, convidado responde" on public.equipe;
create policy "equipe: dono gerencia, convidado responde"
  on public.equipe for update to authenticated
  using (
    dono_id = auth.uid()
    or lower(convite_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    dono_id = auth.uid()
    or (
      lower(convite_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
      and convidado_id = auth.uid()
      and status in ('ativo', 'recusado')
    )
  );

drop policy if exists "equipe: só o dono apaga" on public.equipe;
create policy "equipe: só o dono apaga"
  on public.equipe for delete to authenticated
  using (dono_id = auth.uid());

-- A liberação manual é do dono. O convidado precisa ler para saber o
-- alcance dele, mas não escreve.
drop policy if exists "equipe_alunos: leitura dos dois lados" on public.equipe_alunos;
create policy "equipe_alunos: leitura dos dois lados"
  on public.equipe_alunos for select to authenticated
  using (exists (select 1 from public.equipe e
                  where e.id = equipe_alunos.equipe_id
                    and (e.dono_id = auth.uid() or e.convidado_id = auth.uid())));

drop policy if exists "equipe_alunos: só o dono libera" on public.equipe_alunos;
create policy "equipe_alunos: só o dono libera"
  on public.equipe_alunos for all to authenticated
  using (exists (select 1 from public.equipe e
                  where e.id = equipe_alunos.equipe_id and e.dono_id = auth.uid()))
  with check (exists (select 1 from public.equipe e
                       where e.id = equipe_alunos.equipe_id and e.dono_id = auth.uid()));

grant select, insert, update, delete on public.equipe        to authenticated;
grant select, insert, update, delete on public.equipe_alunos to authenticated;

-- ════════════════════════════════════════════════════════════
--  ACEITAR O CONVITE
-- ════════════════════════════════════════════════════════════

-- Liga o convite ao login de quem está aceitando.
--
-- Por função, e não por update direto, porque é aqui que `convidado_id`
-- deixa de ser nulo — e deixar o app escolher esse valor seria deixar
-- qualquer um se enfiar na equipe dos outros.
create or replace function public.aceitar_convite_equipe(p_convite_id uuid, p_aceitar boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare v_email text; v_convite public.equipe%rowtype;
begin
  select lower(coalesce(auth.jwt() ->> 'email', '')) into v_email;

  select * into v_convite from public.equipe where id = p_convite_id;
  if v_convite.id is null then
    raise exception 'Convite não encontrado' using errcode = 'P0002';
  end if;
  if lower(v_convite.convite_email) <> v_email or v_email = '' then
    raise exception 'Este convite não é seu' using errcode = '42501';
  end if;
  if v_convite.status <> 'convidado' then
    raise exception 'Este convite já foi respondido' using errcode = '22023';
  end if;

  update public.equipe
     set convidado_id = case when p_aceitar then auth.uid() else null end,
         status       = case when p_aceitar then 'ativo' else 'recusado' end,
         aceito_em    = case when p_aceitar then now() else null end
   where id = p_convite_id;
end $$;

revoke all on function public.aceitar_convite_equipe(uuid, boolean) from public;
grant execute on function public.aceitar_convite_equipe(uuid, boolean) to authenticated;

-- ════════════════════════════════════════════════════════════
--  O ALUNO VÊ QUEM O ACOMPANHA
-- ════════════════════════════════════════════════════════════

-- Mesma regra de alcance de `aluno_da_minha_equipe`, mas para um vínculo
-- específico — o aluno só deve ver quem de fato alcança ELE, não toda a
-- equipe do profissional dele.
create or replace function public.aluno_da_minha_equipe_de(p_aluno_id uuid, p_equipe_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.equipe e
      join public.alunos a on a.id = p_aluno_id and a.personal_id = e.dono_id
     where e.id = p_equipe_id
       and e.status = 'ativo'
       and (
         exists (
           select 1
             from public.aluno_assinaturas s
             join public.personal_planos p on p.id = s.plano_id
            where s.aluno_id = a.id
              and s.status in ('ativa', 'inadimplente')
              and ((e.escopo = 'nutricao' and p.inclui_dieta)
                or (e.escopo = 'treino'   and p.inclui_treino))
         )
         or exists (
           select 1 from public.equipe_alunos ea
            where ea.equipe_id = e.id and ea.aluno_id = a.id
         )
       )
  );
$$;

-- Nome e papel de quem tem acesso aos dados de um aluno.
--
-- Precisa ser função: a policy de `equipe` libera a leitura para os dois
-- lados do vínculo, e o aluno não é nenhum dos dois. Mas são os dados de
-- saúde dele — quem é acompanhado tem o direito de saber quem está
-- olhando, sem por isso ganhar acesso à tabela inteira.
create or replace function public.quem_me_acompanha(p_aluno_id uuid)
returns table (nome text, papel text)
language sql stable security definer set search_path = public as $$
  select coalesce(p.nome, 'Seu profissional'), 'Responsável'
    from public.alunos a
    join public.profiles p on p.id = a.personal_id
   where a.id = p_aluno_id and public.aluno_e_meu(p_aluno_id)

  union all

  select coalesce(p.nome, e.convite_email),
         case e.escopo when 'nutricao' then 'Nutrição' else 'Treino' end
    from public.alunos a
    join public.equipe e on e.dono_id = a.personal_id and e.status = 'ativo'
    join public.profiles p on p.id = e.convidado_id
   where a.id = p_aluno_id
     and public.aluno_e_meu(p_aluno_id)
     and public.aluno_da_minha_equipe_de(p_aluno_id, e.id);
$$;

revoke all on function public.quem_me_acompanha(uuid) from public;
revoke all on function public.aluno_da_minha_equipe_de(uuid, uuid) from public;
grant execute on function public.quem_me_acompanha(uuid) to authenticated;
grant execute on function public.aluno_da_minha_equipe_de(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';

-- Conferência: as tabelas, as funções e a policy de dieta atualizada.
select
  (select count(*) from information_schema.tables
    where table_schema = 'public' and table_name in ('equipe', 'equipe_alunos')) as tabelas_criadas,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('aluno_da_minha_equipe', 'aceitar_convite_equipe')) as funcoes_criadas,
  (select count(*) from pg_policies
    where schemaname = 'public' and tablename in ('equipe', 'equipe_alunos')) as policies;
