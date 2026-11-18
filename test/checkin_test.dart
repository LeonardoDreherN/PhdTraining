import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/checkin.dart';

CheckinNutricional c({
  int adesao = 3,
  int? energia,
  List<String> dificuldades = const [],
  String? intestino,
  String? observacoes,
}) =>
    CheckinNutricional(
      mes: DateTime(2026, 11),
      adesao: adesao,
      energia: energia,
      dificuldades: dificuldades,
      intestino: intestino,
      observacoes: observacoes,
    );

void main() {
  group('Check-in nutricional', () {
    test('o mês de referência é sempre o dia 1', () {
      final m = CheckinNutricional.mesAtual();
      expect(m.day, 1);
      expect(m.month, DateTime.now().month);
      expect(m.year, DateTime.now().year);
    });

    test('a escala de adesão tem rótulo em todos os degraus', () {
      for (var i = 1; i <= 5; i++) {
        expect(c(adesao: i).adesaoRotulo, isNot('—'), reason: 'adesão $i');
      }
    });

    test('observação em branco vira nulo, não string vazia', () {
      // Sem isto, o profissional vê um bloco de observação vazio no
      // cartão — e um espaço reservado para texto que não existe parece
      // defeito.
      expect(c(observacoes: '   ').paraBanco()['observacoes'], isNull);
      expect(c(observacoes: null).paraBanco()['observacoes'], isNull);
      expect(c(observacoes: ' oi ').paraBanco()['observacoes'], 'oi');
    });

    test('o mês vai para o banco em ISO, com o dia 1', () {
      expect(c().paraBanco()['mes'], '2026-11-01');
    });

    test('dificuldade sem rótulo no catálogo volta como o próprio código', () {
      // Um código gravado por uma versão mais nova do app não pode
      // sumir da tela de quem está numa versão antiga.
      expect(c(dificuldades: ['rotina', 'xyz']).dificuldadesRotulos,
          ['Rotina corrida', 'xyz']);
    });

    test('intestino não respondido não tem rótulo', () {
      expect(c().intestinoRotulo, isNull);
      expect(c(intestino: 'inchaco').intestinoRotulo, 'Inchaço');
    });

    test('limpar o intestino na cópia realmente apaga', () {
      // `copiaCom(intestino: null)` não dá para distinguir de "não
      // mexer", e é por isso que existe a bandeira: é assim que o aluno
      // volta a não responder a pergunta.
      final comResposta = c(intestino: 'bem');
      expect(comResposta.copiaCom(intestino: null).intestino, 'bem');
      expect(comResposta.copiaCom(limpaIntestino: true).intestino, isNull);
    });

    test('lê o que o banco devolve', () {
      final lido = CheckinNutricional.doMapa({
        'id': 'abc',
        'mes': '2026-10-01',
        'adesao': 5,
        'energia': 4,
        'dificuldades': ['viagem'],
        'intestino': 'bem',
        'observacoes': 'mês bom',
        'criado_em': '2026-10-28T12:00:00Z',
      });
      expect(lido.mes, DateTime(2026, 10));
      expect(lido.adesao, 5);
      expect(lido.adesaoRotulo, 'Segui tudo');
      expect(lido.dificuldadesRotulos, ['Viagens']);
      expect(lido.criadoEm, isNotNull);
    });

    test('registro sem dificuldades e sem energia é válido', () {
      // Só a adesão é obrigatória. Formulário que exige tudo é
      // formulário que o aluno abandona no segundo mês.
      final mapa = c().paraBanco();
      expect(mapa['adesao'], 3);
      expect(mapa['energia'], isNull);
      expect(mapa['dificuldades'], isEmpty);
    });
  });
}
