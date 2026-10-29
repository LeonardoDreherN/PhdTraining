-- ════════════════════════════════════════════════════════════
--  0012 — O aluno marca a própria anamnese e a própria foto
--
--  O BUG
--
--  A policy de escrita de `alunos` é só do personal:
--
--    create policy "alunos: só o personal escreve"
--      on public.alunos for all to authenticated
--      using (personal_id = auth.uid()) with check (...);
--
--  O aluno é `user_id` nessa linha, não `personal_id`. Então o
--  `update alunos set anamnese_preenchida = true` que o app roda ao
--  fim do questionário casava com ZERO linhas.
--
--  E UPDATE que não casa linha nenhuma **não é erro**: o PostgREST
--  devolve sucesso. O app fechava o formulário achando que salvou, a
--  flag continuava `false`, e o questionário voltava no próximo abrir.
--  Para sempre. Era o que o aluno via.
--
--  As respostas nunca foram perdidas: a tabela `anamnese` tem policy
--  via `aluno_e_meu`, que aceita o aluno. Só a flag não virava.
--
--  O mesmo silêncio acontecia em `alunos.foto_url`: o aluno trocava a
--  foto, ela ia para `profiles.avatar_url` (linha dele, policy dele),
--  mas o espelho em `alunos` era recusado sem avisar — e o personal
--  continuava vendo a lista sem rosto.
--
--  A CORREÇÃO
--
--  Não é afrouxar a policy de `alunos`. RLS vale para a linha inteira:
--  liberar UPDATE para `user_id = auth.uid()` deixaria o aluno mudar
--  também `ativo`, `grupo`, `notas` e até `personal_id` — trocar de
--  personal sozinho.
--
--  Então vão duas funções `security definer`, cada uma escrevendo UMA
--  coluna, no mesmo padrão de `aluno_e_meu` e `meu_crn`. E as duas
--  levantam erro quando não acham a linha, para o app nunca mais
--  receber sucesso de uma escrita que não aconteceu.
--
--  Seguro rodar mais de uma vez.
-- ════════════════════════════════════════════════════════════

-- Marca a anamnese como preenchida. Serve ao aluno e ao personal dono:
-- `aluno_e_meu` já aceita os dois, e o personal preencher junto na
-- primeira consulta é uso normal.
create or replace function public.marcar_anamnese_preenchida(p_aluno_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare afetadas integer;
begin
  if not public.aluno_e_meu(p_aluno_id) then
    raise exception 'Sem permissão para este aluno'
      using errcode = '42501';
  end if;

  update public.alunos
     set anamnese_preenchida = true
   where id = p_aluno_id;

  get diagnostics afetadas = row_count;
  if afetadas = 0 then
    raise exception 'Aluno % não existe', p_aluno_id
      using errcode = 'P0002';
  end if;
end $$;

-- Espelha a foto do perfil no cadastro, para o personal ver na lista.
-- Age só na linha do próprio login — não recebe id de fora.
create or replace function public.definir_minha_foto(p_url text)
returns void
language plpgsql security definer set search_path = public as $$
declare afetadas integer;
begin
  update public.alunos
     set foto_url = p_url
   where user_id = auth.uid();

  get diagnostics afetadas = row_count;
  if afetadas = 0 then
    raise exception 'Nenhum cadastro de aluno vinculado a este login'
      using errcode = 'P0002';
  end if;
end $$;

revoke all on function public.marcar_anamnese_preenchida(uuid) from public;
revoke all on function public.definir_minha_foto(text)         from public;
grant execute on function public.marcar_anamnese_preenchida(uuid) to authenticated;
grant execute on function public.definir_minha_foto(text)         to authenticated;

comment on function public.marcar_anamnese_preenchida(uuid) is
  'Vira alunos.anamnese_preenchida. Existe porque a policy de escrita de alunos é só do personal, e o UPDATE do aluno casava zero linhas em silêncio — o questionário voltava para sempre.';

comment on function public.definir_minha_foto(text) is
  'Espelha a foto do aluno em alunos.foto_url, que a policy de escrita de alunos recusaria sem avisar.';

notify pgrst, 'reload schema';

-- Conferência: as duas funções existem e estão liberadas.
select p.proname,
       pg_get_function_identity_arguments(p.oid) as argumentos,
       has_function_privilege('authenticated', p.oid, 'execute') as authenticated_executa
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public'
   and p.proname in ('marcar_anamnese_preenchida', 'definir_minha_foto')
 order by p.proname;
