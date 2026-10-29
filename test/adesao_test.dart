import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/utils/adesao.dart';

void main() {
  final agora = DateTime(2026, 10, 29, 12);
  const aluno = {'id': 'a', 'nome': 'Marina Costa'};

  AdesaoAluno calc({int feitas = 0, int fugas = 0, DateTime? ultimo, int dias = 7}) => calcularAdesao(
        aluno: aluno,
        refeicoesPorDia: 5,
        dias: dias,
        feitas: feitas,
        fugas: fugas,
        agora: agora,
        ultimoRegistro: ultimo,
      );

  test('sem registro nenhum, ou há 3 dias, é "sem registro"', () {
    expect(calc().situacao, SituacaoAdesao.semRegistro);
    expect(
      calc(feitas: 30, ultimo: agora.subtract(const Duration(days: 3))).situacao,
      SituacaoAdesao.semRegistro,
    );
  });

  test('menos de 60% das refeições é "com dificuldade"', () {
    final r = calc(feitas: 20, ultimo: agora); // 20 de 35
    expect(r.percentual, closeTo(0.571, 0.001));
    expect(r.situacao, SituacaoAdesao.dificuldade);
  });

  test('marcar tudo mas fugir do plano 3 vezes também é dificuldade', () {
    expect(calc(feitas: 35, fugas: 3, ultimo: agora).situacao, SituacaoAdesao.dificuldade);
    expect(calc(feitas: 35, fugas: 2, ultimo: agora).situacao, SituacaoAdesao.noCaminho);
  });

  test('plano novo só cobra os dias que já passaram', () {
    // Dois dias de plano, 8 de 10 refeições: está no caminho.
    final r = calc(feitas: 8, dias: 2, ultimo: agora);
    expect(r.previstas, 10);
    expect(r.situacao, SituacaoAdesao.noCaminho);
  });

  test('a ordem do enum é a prioridade do painel', () {
    expect(SituacaoAdesao.values.first, SituacaoAdesao.semRegistro);
    expect(SituacaoAdesao.values.last, SituacaoAdesao.noCaminho);
  });
}
