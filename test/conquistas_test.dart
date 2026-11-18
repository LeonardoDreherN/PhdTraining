import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/conquista.dart';

NumerosDoAluno n({
  int treinos = 0,
  int diasPrevistos = 0,
  int semanasCompletas = 0,
  int sequenciaSemanas = 0,
  int exercicios = 0,
  int catalogo = 0,
}) =>
    NumerosDoAluno(
      treinos: treinos,
      diasPrevistos: diasPrevistos,
      semanasCompletas: semanasCompletas,
      sequenciaSemanas: sequenciaSemanas,
      exercicios: exercicios,
      catalogo: catalogo,
    );

Conquista cod(String c) => Conquista.porCodigo(c)!;

void main() {
  group('Catálogo', () {
    test('tem os marcos de treino da especificação', () {
      for (final m in [1, 10, 25, 50, 100, 250, 500]) {
        expect(Conquista.porCodigo('treinos_$m'), isNotNull,
            reason: 'falta o marco de $m treinos');
      }
    });

    test('tem os marcos de consistência da especificação', () {
      // 1, 2, 4, 8, 12 semanas e seis meses (26 semanas).
      for (final m in [1, 2, 4, 8, 12, 26]) {
        expect(Conquista.porCodigo('semanas_$m'), isNotNull,
            reason: 'falta o marco de $m semanas');
      }
    });

    test('nenhum código repetido', () {
      final vistos = <String>{};
      for (final c in Conquista.catalogoTreino) {
        expect(vistos.add(c.codigo), isTrue, reason: 'repetido: ${c.codigo}');
      }
    });

    test('código desconhecido devolve nulo em vez de estourar', () {
      expect(Conquista.porCodigo('nao_existe'), isNull);
    });
  });

  group('Progresso', () {
    test('zero quando não começou', () {
      expect(cod('treinos_10').progresso(n()), 0);
    });

    test('proporcional no meio do caminho', () {
      expect(cod('treinos_10').progresso(n(treinos: 5)), closeTo(0.5, 0.001));
    });

    test('não passa de 1 depois de conquistada', () {
      // Sem o limite, a barra de "250 treinos" ficaria com 200% para quem
      // tem 500 e a tela desenharia fora do cartão.
      expect(cod('treinos_10').progresso(n(treinos: 500)), 1);
    });

    test('o texto mostra quanto falta, não porcentagem', () {
      expect(cod('treinos_50').progressoTexto(n(treinos: 37)), '37 de 50');
    });

    test('o texto não passa da meta', () {
      expect(cod('treinos_50').progressoTexto(n(treinos: 80)), '50 de 50');
    });
  });

  group('Consistência é sobre a própria programação', () {
    test('três treinos por semana valem igual a cinco', () {
      // O critério central do documento: quem cumpre a própria
      // programação conquista, independente do volume. As duas contas
      // chegam ao mesmo marco porque ambas fecharam 4 semanas.
      final tresPorSemana = n(diasPrevistos: 3, sequenciaSemanas: 4);
      final cincoPorSemana = n(diasPrevistos: 5, sequenciaSemanas: 4);

      expect(cod('semanas_4').progresso(tresPorSemana), 1);
      expect(cod('semanas_4').progresso(cincoPorSemana), 1);
    });

    test('quem treina mais não ganha medalha de consistência por volume', () {
      // 200 treinos, mas sem nenhuma semana completa: nenhuma medalha de
      // consistência. É o que impede a conquista de premiar tempo livre.
      final muitoTreino = n(treinos: 200, sequenciaSemanas: 0);
      expect(cod('semanas_1').progresso(muitoTreino), 0);
      expect(cod('treinos_100').progresso(muitoTreino), 1);
    });
  });

  group('Barra de desbloqueios', () {
    test('o exemplo da especificação: 125 de 500 dá 25%', () {
      expect(n(exercicios: 125, catalogo: 500).progressoCatalogo,
          closeTo(0.25, 0.0001));
    });

    test('catálogo vazio não divide por zero', () {
      expect(n(exercicios: 10, catalogo: 0).progressoCatalogo, 0);
    });

    test('mais desbloqueios que o catálogo não passa de 100%', () {
      // Acontece se o personal prescreveu exercícios próprios, que não
      // entram no denominador oficial.
      expect(n(exercicios: 600, catalogo: 500).progressoCatalogo, 1);
    });
  });

  group('Leitura do banco', () {
    test('campo ausente vira zero em vez de estourar', () {
      final x = NumerosDoAluno.doMapa({'treinos': 7});
      expect(x.treinos, 7);
      expect(x.catalogo, 0);
      expect(x.sequenciaSemanas, 0);
    });

    test('a conquista guarda a data e o valor que a disparou', () {
      final c = ConquistaDoAluno.doMapa({
        'codigo': 'treinos_50',
        'desbloqueado_em': '2026-03-15T10:00:00Z',
        'valor': 50,
      });
      expect(c.codigo, 'treinos_50');
      expect(c.desbloqueadoEm.year, 2026);
      expect(c.valor, 50);
      expect(c.conquista?.nome, '50 treinos');
    });

    test('conquista de código desconhecido não quebra a tela', () {
      // Pode acontecer se o banco tiver um código de uma versão futura
      // do app. A tela ignora em vez de estourar.
      final c = ConquistaDoAluno.doMapa({
        'codigo': 'medalha_do_futuro',
        'desbloqueado_em': '2026-03-15T10:00:00Z',
      });
      expect(c.conquista, isNull);
    });
  });
}
