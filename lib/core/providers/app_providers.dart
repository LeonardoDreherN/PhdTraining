import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/aluno.dart';
import '../models/ficha.dart';
import '../models/perfil.dart';
import '../models/resumo_home.dart';
import '../services/aluno_service.dart';
import '../services/ficha_service.dart';
import '../services/home_service.dart';
import '../services/profile_service.dart';

/// Providers do app.
///
/// Riverpod sem geração de código de propósito: `riverpod_generator` está no
/// pubspec, mas usá-lo obriga a rodar `build_runner` a cada mudança de
/// provider. Para o tamanho disto, o ganho não paga o passo extra no fluxo
/// de trabalho.
///
/// O que estes providers resolvem, e que `setState` não resolvia: três telas
/// pediam o mesmo perfil e faziam três consultas; agora fazem uma, e
/// `ref.invalidate` atualiza todas de uma vez depois de uma edição.

/// Perfil de quem está logado. `null` quando não há sessão.
final perfilProvider = FutureProvider<Perfil?>((ref) async {
  final mapa = await ProfileService.getPerfil();
  if (mapa == null) return null;
  return Perfil.doMapa(mapa);
});

/// Resumo da home do personal.
final resumoHomeProvider = FutureProvider<ResumoHome>((ref) async {
  return HomeService.carregar();
});

/// Alunos do personal, com ficha, último treino e adesão já calculados.
final alunosProvider = FutureProvider<List<Aluno>>((ref) async {
  return AlunoService.listarComResumo();
});

/// Filtro selecionado na lista. Fora do `FutureProvider` de propósito:
/// trocar de aba não deve disparar consulta nova, só filtrar o que já veio.
final filtroAlunoProvider = StateProvider<FiltroAluno>((ref) => FiltroAluno.todos);

/// Texto da busca.
final buscaAlunoProvider = StateProvider<String>((ref) => '');

/// A lista já filtrada e buscada — é isto que a tela desenha.
final alunosVisiveisProvider = Provider<List<Aluno>>((ref) {
  final todos = ref.watch(alunosProvider).valueOrNull ?? const <Aluno>[];
  final filtro = ref.watch(filtroAlunoProvider);
  final busca = ref.watch(buscaAlunoProvider).trim().toLowerCase();

  return todos.where((a) {
    if (!filtro.aceita(a)) return false;
    if (busca.isEmpty) return true;
    return a.nome.toLowerCase().contains(busca) ||
        (a.email?.toLowerCase().contains(busca) ?? false);
  }).toList();
});

/// Quantos alunos precisam de atenção — alimenta o número na aba do filtro.
final alunosEmAtencaoProvider = Provider<int>((ref) {
  final todos = ref.watch(alunosProvider).valueOrNull ?? const <Aluno>[];
  return todos.where((a) => a.precisaAtencao).length;
});

/// Fichas do personal, com contagem de exercícios, alunos e grupos.
final fichasProvider = FutureProvider<List<Ficha>>((ref) async {
  return FichaService.listarComResumo();
});

/// Chame depois de qualquer coisa que mexa em aluno, ficha ou cobrança.
void recarregarTudo(WidgetRef ref) {
  ref.invalidate(resumoHomeProvider);
  ref.invalidate(alunosProvider);
  ref.invalidate(fichasProvider);
}
