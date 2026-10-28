import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/utils/dieta_calculos.dart';

void main() {
  group('TMB', () {
    test('Mifflin-St Jeor, homem', () {
      // 10×80 + 6,25×180 − 5×30 + 5
      final r = tmb(
        formula: FormulaTmb.mifflin,
        sexo: Sexo.masculino,
        pesoKg: 80,
        alturaCm: 180,
        idade: 30,
      );
      expect(r, closeTo(1780, 0.01));
    });

    test('Mifflin-St Jeor, mulher: a constante é outra', () {
      // 10×60 + 6,25×165 − 5×30 − 161
      final r = tmb(
        formula: FormulaTmb.mifflin,
        sexo: Sexo.feminino,
        pesoKg: 60,
        alturaCm: 165,
        idade: 30,
      );
      expect(r, closeTo(1320.25, 0.01));
    });

    test('Harris-Benedict revisada, homem', () {
      final r = tmb(
        formula: FormulaTmb.harrisBenedict,
        sexo: Sexo.masculino,
        pesoKg: 80,
        alturaCm: 180,
        idade: 30,
      );
      expect(r, closeTo(1853.632, 0.01));
    });

    test('Harris-Benedict revisada, mulher', () {
      final r = tmb(
        formula: FormulaTmb.harrisBenedict,
        sexo: Sexo.feminino,
        pesoKg: 60,
        alturaCm: 165,
        idade: 30,
      );
      expect(r, closeTo(1383.683, 0.01));
    });

    test('Cunningham usa massa magra, não peso total', () {
      // 80 kg com 15% de gordura → 68 kg de massa magra → 500 + 22×68 = 1996
      final r = tmb(
        formula: FormulaTmb.cunningham,
        sexo: Sexo.masculino,
        pesoKg: 80,
        alturaCm: 180,
        idade: 30,
        percentualGordura: 15,
      );
      expect(r, closeTo(1996, 0.01));
    });

    test('Cunningham sem percentual de gordura não calcula', () {
      // Melhor devolver nada do que uma TMB chutada: ela vira meta
      // calórica, e ninguém perceberia o erro olhando o número.
      final r = tmb(
        formula: FormulaTmb.cunningham,
        sexo: Sexo.masculino,
        pesoKg: 80,
        alturaCm: 180,
        idade: 30,
      );
      expect(r, isNull);
    });

    test('faltando altura ou idade, não calcula', () {
      expect(
        tmb(
          formula: FormulaTmb.mifflin,
          sexo: Sexo.masculino,
          pesoKg: 80,
          alturaCm: null,
          idade: 30,
        ),
        isNull,
      );
      expect(
        tmb(
          formula: FormulaTmb.mifflin,
          sexo: Sexo.masculino,
          pesoKg: 80,
          alturaCm: 180,
          idade: null,
        ),
        isNull,
      );
    });

    test('peso zero ou negativo não calcula', () {
      expect(
        tmb(
          formula: FormulaTmb.mifflin,
          sexo: Sexo.masculino,
          pesoKg: 0,
          alturaCm: 180,
          idade: 30,
        ),
        isNull,
      );
    });
  });

  group('GET e meta', () {
    test('GET multiplica a TMB pelo fator de atividade', () {
      expect(get(1780, NivelAtividade.moderado), closeTo(2759, 0.01));
      expect(get(1780, NivelAtividade.sedentario), closeTo(2136, 0.01));
    });

    test('GET sem TMB não calcula', () {
      expect(get(null, NivelAtividade.moderado), isNull);
    });

    test('emagrecimento corta 20%, hipertrofia soma 15%', () {
      expect(metaCalorica(2000, ObjetivoDieta.emagrecimento), closeTo(1600, 0.01));
      expect(metaCalorica(2000, ObjetivoDieta.manutencao), closeTo(2000, 0.01));
      expect(metaCalorica(2000, ObjetivoDieta.hipertrofia), closeTo(2300, 0.01));
    });
  });

  group('Macros', () {
    test('proteína e gordura por peso, carboidrato com o resto', () {
      // 80 kg: 144 g de proteína (576 kcal) + 72 g de gordura (648 kcal)
      // = 1224 kcal. Sobram 776 para carboidrato → 194 g.
      final m = macros(metaKcal: 2000, pesoKg: 80);
      expect(m, isNotNull);
      expect(m!.proteina, closeTo(144, 0.01));
      expect(m.gordura, closeTo(72, 0.01));
      expect(m.carboidrato, closeTo(194, 0.01));
    });

    test('a soma dos macros bate com a meta calórica', () {
      final m = macros(metaKcal: 2500, pesoKg: 70)!;
      final total = m.proteina * Atwater.proteina +
          m.carboidrato * Atwater.carboidrato +
          m.gordura * Atwater.gordura;
      expect(total, closeTo(2500, 0.01));
    });

    test('meta baixa demais não gera carboidrato negativo', () {
      // 100 kg com proteína e gordura padrão já passam de 1700 kcal.
      // Mostrar "−30 g de carboidrato" seria pior do que não mostrar.
      expect(macros(metaKcal: 1200, pesoKg: 100), isNull);
    });

    test('sem peso não calcula', () {
      expect(macros(metaKcal: 2000, pesoKg: null), isNull);
    });

    test('distribuição percentual soma perto de 100', () {
      final d = distribuicao(proteinaG: 144, carboidratoG: 194, gorduraG: 72)!;
      expect(d.proteina + d.carboidrato + d.gordura, inInclusiveRange(99, 101));
      expect(d.proteina, 29);
    });
  });

  group('Somar alimentos', () {
    test('converte de 100 g para a quantidade servida', () {
      const arroz = ValoresPor100g(
        kcal: 128, proteina: 2.5, carboidrato: 28.1, gordura: 0.2, fibra: 1.6,
      );
      const frango = ValoresPor100g(
        kcal: 163, proteina: 31.5, carboidrato: 0, gordura: 3.2,
      );

      final r = somar([
        (valores: arroz, gramas: 150),
        (valores: frango, gramas: 120),
      ]);

      // Arroz: 128 × 1,5 = 192. Frango: 163 × 1,2 = 195,6.
      expect(r.kcal, closeTo(387.6, 0.01));
      expect(r.proteina, closeTo(2.5 * 1.5 + 31.5 * 1.2, 0.01));
      // Fibra ausente conta como zero, não quebra a soma.
      expect(r.fibra, closeTo(1.6 * 1.5, 0.01));
    });

    test('lista vazia soma zero', () {
      final r = somar(const []);
      expect(r.kcal, 0);
      expect(r.proteina, 0);
    });
  });

  group('Auxiliares', () {
    test('água: 35 ml por quilo', () {
      expect(aguaMl(80), closeTo(2800, 0.01));
      expect(aguaMl(null), isNull);
      expect(aguaMl(0), isNull);
    });

    test('proporção não passa de 1', () {
      expect(proporcao(500, 2000), closeTo(0.25, 0.001));
      expect(proporcao(3000, 2000), 1);
      expect(proporcao(100, null), 0);
      expect(proporcao(100, 0), 0);
    });

    test('idade só conta aniversário já ocorrido', () {
      final nasceu = DateTime(1990, 6, 15);
      expect(idadeEm(nasceu, DateTime(2026, 6, 14)), 35);
      expect(idadeEm(nasceu, DateTime(2026, 6, 15)), 36);
      expect(idadeEm(nasceu, DateTime(2026, 12, 1)), 36);
      expect(idadeEm(null), isNull);
    });
  });
}
