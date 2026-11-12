import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/periodizacao.dart';

EtapaPeriodizacao _e(String id, DateTime inicio, [DateTime? fim]) =>
    EtapaPeriodizacao(id: id, alunoId: 'a', nome: id, dataInicio: inicio, dataFim: fim);

void main() {
  final hoje = DateTime(2026, 11, 11);
  final etapas = [
    _e('nov', DateTime(2026, 11, 1), DateTime(2026, 11, 30)),
    _e('dez', DateTime(2026, 12, 1), DateTime(2026, 12, 31)),
    _e('jan', DateTime(2027, 1, 1)),
  ];

  group('Etapa atual', () {
    test('é a última que já começou', () {
      expect(EtapaPeriodizacao.idDaAtual(etapas, hoje), 'nov');
      expect(EtapaPeriodizacao.idDaAtual(etapas, DateTime(2026, 12, 1)), 'dez');
      expect(EtapaPeriodizacao.idDaAtual(etapas, DateTime(2027, 3, 1)), 'jan');
    });

    test('antes da primeira não há atual', () {
      expect(EtapaPeriodizacao.idDaAtual(etapas, DateTime(2026, 10, 1)), isNull);
    });

    test('etapa vencida sem próxima continua sendo a atual', () {
      final so = [_e('nov', DateTime(2026, 11, 1), DateTime(2026, 11, 30))];
      expect(EtapaPeriodizacao.idDaAtual(so, DateTime(2026, 12, 15)), 'nov');
    });

    test('momento de cada uma', () {
      const id = 'nov';
      expect(etapas[0].momento(id, hoje), MomentoEtapa.atual);
      expect(etapas[1].momento(id, hoje), MomentoEtapa.proxima);
      expect(_e('out', DateTime(2026, 10, 1)).momento(id, hoje), MomentoEtapa.anterior);
    });
  });

  test('grava sem espaços e sem palavra-chave vazia', () {
    final m = EtapaPeriodizacao(
      alunoId: 'a',
      nome: '  Dezembro ',
      dataInicio: DateTime(2026, 12, 1),
      dataFim: DateTime(2026, 12, 31),
      volume: '  ',
      palavrasChave: const ['progressão', ' ', 'falha '],
    ).paraMapa();
    expect(m['nome'], 'Dezembro');
    expect(m['data_inicio'], '2026-12-01');
    expect(m['volume'], isNull);
    expect(m['palavras_chave'], ['progressão', 'falha']);
  });

  test('período por extenso', () {
    expect(etapas[0].periodoTexto, '01/11 – 30/11/2026');
    expect(etapas[2].periodoTexto, 'desde 01/01/2027');
  });
}
