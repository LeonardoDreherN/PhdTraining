import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Abre o treino do dia.
///
/// Antes perguntava "como quer treinar?" com três respostas — guiado,
/// guiado com vídeo, só a lista. Virou um caminho só: a visualização
/// completa, de onde o aluno começa quando estiver pronto.
///
/// As três opções pediam uma decisão antes de ele saber o que ia fazer, e
/// duas delas eram a mesma coisa com e sem vídeo. Agora o vídeo está em
/// todo exercício, e quem só quer consultar simplesmente não toca em
/// "Começar".
///
/// Devolve `true` se o treino chegou a ser aberto — quem chamou recarrega
/// para mostrar o check.
Future<bool> iniciarTreino(
  BuildContext context,
  Map<String, dynamic> ficha, {
  required int dia,
}) async {
  final r = await context.push<bool>('/aluno/treino/ver', extra: {
    'ficha': ficha,
    'dia': dia,
  });
  return r ?? true;
}
