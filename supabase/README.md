# Banco — PHD

Schema reconstruído a partir do código do app, já multi-tenant. Substitui o
projeto Supabase antigo (`kewwkcsrddxsucdduvzl`), que foi removido.

## Como aplicar

No painel do Supabase → **SQL Editor** → cola e roda, **nesta ordem**:

| Ordem | Arquivo | O que cria |
|---|---|---|
| 1 | `migrations/0001_base.sql` | As 16 tabelas que o app já usa, com RLS |
| 2 | `migrations/0002_plataforma.sql` | Planos da plataforma e assinatura do personal |
| 3 | `migrations/0003_financeiro.sql` | Gateway, planos vendidos, cobranças, carteira, saques |
| 4 | `migrations/0004_storage.sql` | Os três buckets e suas policies |
| 5 | `migrations/0005_grants.sql` | Privilégios explícitos e default privileges |
| 6 | `migrations/0006_anamnese_unica.sql` | Corrige o índice da anamnese |
| 7 | `migrations/0007_midia_formatos.sql` | HEIC/HEIF e outros formatos nos buckets |
| 8 | `migrations/0008_profiles_recursao.sql` | Corrige a recursão infinita que impedia editar o perfil |
| 9 | `migrations/0009_avaliacao_sessao.sql` | Sessão de avaliação, testes cardio e postural |
| … | `migrations/0010` a `0018` | Dieta, diário, receitas, metas, mensagens, cor da marca |
| 19 | `migrations/0019_circunferencias.sql` | Circunferências livres na sessão de avaliação |
| 20 | `migrations/0020_alimentos_taco.sql` | Tabela TACO completa (591 alimentos) e busca sem acento |
| 21 | `migrations/0021_item_nome_exibicao.sql` | Nome do alimento que o aluno lê no plano |
| 22 | `migrations/0022_consumo_bio_cupons.sql` | O que o aluno comeu de fato, bio do profissional e cupons |
| 23 | `migrations/0023_gateway_asaas.sql` | CPF do aluno e cofre da chave da subconta Asaas |
| 24 | `migrations/0024_periodizacao.sql` | Etapas da periodização e treinos programados por data |

A ordem importa: do 0002 em diante tudo usa funções criadas no 0001. Todos
são seguros de rodar mais de uma vez.

Depois, `inspect.sql` confere que RLS ficou ligado em tudo.

## Depois de aplicar

**Torne-se admin da plataforma.** Crie sua conta pelo app e rode:

```sql
update public.profiles set is_platform_admin = true
 where email = 'seu@email.com';
```

Sem isso você não enxerga os outros personais nem gerencia a biblioteca
oficial de exercícios.

## Resolvido

1. **`progresso-fotos` virou bucket privado.** `ProgressoService` agora
   grava o CAMINHO do arquivo em `foto_url` (em `<aluno_id>/<arquivo>`, que
   é o que a policy confere) e assina a URL na leitura, dentro de
   `listarFotos`. As telas continuam lendo `foto_url` sem saber da
   diferença. URL assinada expira — gravar uma na linha seria inútil no dia
   seguinte.

2. **`aluno_fichas` sem `onConflict`.** Corrigido em `ficha_service.dart`
   para `'aluno_id,ficha_id'`. Sem a chave explícita o PostgREST cai na
   primary key, e como o `id` vem gerado ele sempre insere — reatribuir a
   mesma ficha duplicava o treino do aluno.

3. **Anamnese: o erro era meu, no schema.** Eu tinha afirmado aqui que o
   Dart estava sem `onConflict`. Ele tinha — `'aluno_id'` — e era o meu
   índice `(aluno_id, tipo)` que estava errado, porque o app tem uma
   anamnese por aluno (`alunos.anamnese_tipo` é coluna única, e a leitura
   usa `maybeSingle()`, que lança exceção com mais de uma linha).
   O `0006` corrige o índice.

## O que o código do app ainda precisa mudar

1. **Biblioteca oficial de exercícios.**
   `ExercicioService.importarPadrao` copia uma lista fixa em Dart para cada
   personal. Com a biblioteca oficial (`personal_id` nulo), isso deixa de
   ser necessário: todo personal já lê os oficiais. A lista some do Dart e
   vira linhas no banco.

2. **Mídia de exercício em pasta por dono.**
   Os arquivos nascem com nome achatado (`<personal_id>_<timestamp>.ext`),
   então não dá para derivar o dono do caminho e a policy de escrita ficou
   aberta a qualquer personal. Mudando para `<personal_id>/<arquivo>`, as
   policies passam a ser as mesmas de `avatars`.

## O que não está aqui

- **Dieta.** As tabelas do plano alimentar (refeições, alimentos, macros,
  substituições) ficam para quando o módulo for construído.
- **Treino avançado.** `ficha_exercicios` já tem `metodo` e `grupo_id` para
  bi-set e drop-set, mas periodização em blocos e progressão automática de
  carga pedem tabelas próprias.
