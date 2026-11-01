import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/avaliacao.dart';
import 'package:phd_personal/core/utils/avaliacao_calculos.dart';
import 'package:phd_personal/core/utils/circunferencias.dart';
import 'package:phd_personal/modules/personal/avaliacao/avaliacao_resumo.dart';

void main() {
  group('Últimas medidas para o plano alimentar', () {
    test('cada medida vem da avaliação mais recente que a tem', () {
      final m = UltimasMedidas.de(
        sessoes: const [
          {'data_avaliacao': '2026-10-20', 'peso': 74.0},
          {'data_avaliacao': '2026-06-01', 'peso': 78.0, 'estatura': 158},
        ],
        dobras: const [
          {'data_avaliacao': '2026-06-01', 'peso': 77.5, 'perc_gordura': 34.2, 'massa_magra': 51},
        ],
        bioimpedancia: const [
          {'data_avaliacao': '2026-03-01', 'perc_gordura': 36},
        ],
      );
      expect(m.peso!.valor, 74);
      expect(m.estatura!.valor, 158);
      expect(m.percGordura!.valor, 34.2);
      expect(m.percGordura!.origem, 'Dobras cutâneas');
      expect(m.percGordura!.data, DateTime(2026, 6, 1));
      expect(m.massaMagra!.valor, 51);
    });

    test('no mesmo dia, a sessão vence a dobra', () {
      final m = UltimasMedidas.de(
        sessoes: const [{'data_avaliacao': '2026-10-20', 'peso': 74.0}],
        dobras: const [{'data_avaliacao': '2026-10-20', 'peso': 74.6}],
      );
      expect(m.peso!.valor, 74);
      expect(m.peso!.origem, isNull);
    });

    test('sem avaliação fica vazia', () {
      expect(UltimasMedidas.de().vazia, isTrue);
    });
  });

  group('Circunferências', () {
    test('a sessão vence a dobra, que vence a bioimpedância', () {
      final m = Circunferencia.mesclar(
        bioimpedancia: const {'braco_dir': 30, 'torax': 90, 'perc_gordura': 20},
        dobras: const {'braco_dir': 31, 'cintura': 80},
        daSessao: const {'braco_dir': 32, 'Punho': 16},
        cintura: 79,
      );
      expect(m, {'braco_dir': 32, 'torax': 90, 'cintura': 79, 'Punho': 16});
    });

    test('jsonb ignora o que não é número', () {
      expect(Circunferencia.lerJson({'ombro': 110, 'x': 'abc', 'y': null}), {'ombro': 110.0});
      expect(Circunferencia.lerJson(null), isEmpty);
    });

    test('nome digitado reaproveita a chave do catálogo', () {
      expect(Circunferencia.chaveDoNome('  cintura '), 'cintura');
      expect(Circunferencia.chaveDoNome('panturrilha direita'), 'perna_dir');
      expect(Circunferencia.chaveDoNome('punho   esquerdo'), 'Punho esquerdo');
      expect(Circunferencia.chaveDoNome('   '), isNull);
    });

    test('ordem anatômica, personalizadas no fim', () {
      expect(Circunferencia.ordenar(['Punho', 'quadril', 'pesco_co', 'cintura', 'Antebraço x']),
          ['pesco_co', 'cintura', 'quadril', 'Antebraço x', 'Punho']);
    });

    test('a sessão serializa e lê de volta', () {
      final s = AvaliacaoSessao(alunoId: 'a', data: DateTime(2026, 11, 1), circunferencias: const {'ombro': 112});
      final volta = AvaliacaoSessao.doMapa({...s.paraMapa(), 'aluno_id': 'a'});
      expect(volta.circunferencias, {'ombro': 112.0});
    });

    test('comparação inclui as circunferências medidas nas duas datas', () {
      final anterior = AvaliacaoCompleta(
        sessao: AvaliacaoSessao(
            alunoId: 'a', data: DateTime(2026, 7, 1), cintura: 90, circunferencias: const {'abdomen': 98, 'ombro': 110}),
        aluno: const {'id': 'a'},
      );
      final av = AvaliacaoCompleta(
        sessao: AvaliacaoSessao(
            alunoId: 'a', data: DateTime(2026, 10, 1), cintura: 86, circunferencias: const {'abdomen': 94, 'Punho': 16}),
        aluno: const {'id': 'a'},
        anterior: anterior,
      );
      final linhas = {for (final l in comparacao(av)) l.rotulo: l};
      expect(linhas['Cintura']!.nivel, Nivel.bom);
      expect(linhas['Abdômen']!.diferenca, -4);
      expect(linhas.containsKey('Ombros'), isFalse);
      expect(linhas.containsKey('Punho'), isFalse);
    });
  });
}
