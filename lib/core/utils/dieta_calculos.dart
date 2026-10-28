/// Cálculos de gasto energético e distribuição de macronutrientes.
///
/// Cada fórmula aqui é publicada e citável — o nutricionista precisa saber
/// qual foi usada para defender a prescrição dele, e o PDF mostra o nome.
/// Nada de "fórmula da casa".
library;

import 'dart:math' as math;

/// Quantas quilocalorias cada grama de macronutriente fornece.
///
/// Fatores de Atwater, os mesmos que a rotulagem brasileira usa (RDC 429/2020).
abstract class Atwater {
  static const double proteina = 4;
  static const double carboidrato = 4;
  static const double gordura = 9;
  static const double alcool = 7;
}

enum Sexo { masculino, feminino }

/// Fórmula de taxa metabólica basal.
enum FormulaTmb {
  /// Mifflin-St Jeor (1990). É a recomendada pela Academy of Nutrition and
  /// Dietetics para adultos não atletas: erra menos que Harris-Benedict,
  /// que foi construída em 1919 com uma amostra pequena e tende a
  /// superestimar quem tem sobrepeso.
  mifflin,

  /// Harris-Benedict revisada por Roza & Shizgal (1984). Continua sendo a
  /// mais pedida em prova e em protocolo antigo, então existe aqui.
  harrisBenedict,

  /// Cunningham (1980). Usa massa magra, não peso total — por isso é a
  /// escolha para atleta e para quem tem composição corporal fora da média.
  /// Exige percentual de gordura medido.
  cunningham,
}

extension FormulaTmbNome on FormulaTmb {
  String get nome => switch (this) {
        FormulaTmb.mifflin => 'Mifflin-St Jeor',
        FormulaTmb.harrisBenedict => 'Harris-Benedict (Roza & Shizgal)',
        FormulaTmb.cunningham => 'Cunningham',
      };

  /// Citação curta para o rodapé do laudo.
  String get fonte => switch (this) {
        FormulaTmb.mifflin => 'Mifflin MD et al., Am J Clin Nutr, 1990',
        FormulaTmb.harrisBenedict => 'Roza AM, Shizgal HM, Am J Clin Nutr, 1984',
        FormulaTmb.cunningham => 'Cunningham JJ, Am J Clin Nutr, 1980',
      };
}

/// Nível de atividade física, com o multiplicador clássico do GET.
enum NivelAtividade {
  sedentario(1.2, 'Sedentário', 'Trabalho sentado, sem exercício'),
  leve(1.375, 'Levemente ativo', 'Exercício leve, 1 a 3 dias por semana'),
  moderado(1.55, 'Moderadamente ativo', 'Exercício moderado, 3 a 5 dias'),
  intenso(1.725, 'Muito ativo', 'Exercício intenso, 6 a 7 dias'),
  atleta(1.9, 'Extremamente ativo', 'Trabalho físico ou dois treinos por dia');

  const NivelAtividade(this.fator, this.nome, this.descricao);
  final double fator;
  final String nome;
  final String descricao;
}

enum ObjetivoDieta {
  emagrecimento('Emagrecimento', -0.20),
  manutencao('Manutenção', 0),
  hipertrofia('Hipertrofia', 0.15);

  const ObjetivoDieta(this.nome, this.ajuste);
  final String nome;

  /// Fração aplicada sobre o GET. −20% e +15% são faixas conservadoras:
  /// déficit mais agressivo custa massa magra, e superávit maior vira
  /// gordura em vez de músculo.
  final double ajuste;
}

/// Taxa metabólica basal, em kcal/dia.
///
/// Devolve `null` quando falta dado — e não um número aproximado. Uma TMB
/// chutada vira meta calórica errada, e o nutricionista não teria como
/// perceber olhando o resultado.
double? tmb({
  required FormulaTmb formula,
  required Sexo sexo,
  required double? pesoKg,
  required double? alturaCm,
  required int? idade,
  double? percentualGordura,
}) {
  if (pesoKg == null || pesoKg <= 0) return null;

  if (formula == FormulaTmb.cunningham) {
    if (percentualGordura == null ||
        percentualGordura <= 0 ||
        percentualGordura >= 100) {
      return null;
    }
    final massaMagra = pesoKg * (1 - percentualGordura / 100);
    return 500 + 22 * massaMagra;
  }

  if (alturaCm == null || alturaCm <= 0 || idade == null || idade <= 0) {
    return null;
  }

  return switch (formula) {
    FormulaTmb.mifflin => switch (sexo) {
        Sexo.masculino => 10 * pesoKg + 6.25 * alturaCm - 5 * idade + 5,
        Sexo.feminino => 10 * pesoKg + 6.25 * alturaCm - 5 * idade - 161,
      },
    FormulaTmb.harrisBenedict => switch (sexo) {
        Sexo.masculino =>
          88.362 + 13.397 * pesoKg + 4.799 * alturaCm - 5.677 * idade,
        Sexo.feminino =>
          447.593 + 9.247 * pesoKg + 3.098 * alturaCm - 4.330 * idade,
      },
    FormulaTmb.cunningham => null, // tratado acima
  };
}

/// Gasto energético total: TMB vezes o fator de atividade.
double? get(double? tmbValor, NivelAtividade nivel) {
  if (tmbValor == null || tmbValor <= 0) return null;
  return tmbValor * nivel.fator;
}

/// Meta calórica do plano, já com o ajuste do objetivo.
double? metaCalorica(double? getValor, ObjetivoDieta objetivo) {
  if (getValor == null || getValor <= 0) return null;
  return getValor * (1 + objetivo.ajuste);
}

/// Gramas de cada macro para uma meta calórica.
///
/// A ordem importa e não é arbitrária: proteína e gordura são definidas por
/// peso corporal, porque abaixo de um mínimo há perda de massa magra e
/// prejuízo hormonal. O carboidrato fica com o que sobra — é o macro de
/// ajuste, não o primeiro a ser cortado às cegas.
({double proteina, double carboidrato, double gordura})? macros({
  required double? metaKcal,
  required double? pesoKg,
  double proteinaPorKg = 1.8,
  double gorduraPorKg = 0.9,
}) {
  if (metaKcal == null || metaKcal <= 0) return null;
  if (pesoKg == null || pesoKg <= 0) return null;

  final proteinaG = pesoKg * proteinaPorKg;
  final gorduraG = pesoKg * gorduraPorKg;

  final kcalRestante =
      metaKcal - proteinaG * Atwater.proteina - gorduraG * Atwater.gordura;

  // Meta baixa com proteína e gordura altas pode não deixar sobra. Devolver
  // carboidrato negativo faria a tela mostrar "-30 g" como se fosse normal.
  if (kcalRestante < 0) return null;

  return (
    proteina: proteinaG,
    carboidrato: kcalRestante / Atwater.carboidrato,
    gordura: gorduraG,
  );
}

/// Percentual de cada macro sobre o total — o "40/30/30" que o nutricionista
/// usa para conferir se a distribuição está onde ele queria.
({int proteina, int carboidrato, int gordura})? distribuicao({
  required double proteinaG,
  required double carboidratoG,
  required double gorduraG,
}) {
  final total = proteinaG * Atwater.proteina +
      carboidratoG * Atwater.carboidrato +
      gorduraG * Atwater.gordura;
  if (total <= 0) return null;
  return (
    proteina: (proteinaG * Atwater.proteina / total * 100).round(),
    carboidrato: (carboidratoG * Atwater.carboidrato / total * 100).round(),
    gordura: (gorduraG * Atwater.gordura / total * 100).round(),
  );
}

/// Água recomendada por dia, em mililitros: 35 ml por quilo.
///
/// Referência de adulto saudável. Quem tem restrição renal ou cardíaca segue
/// orientação individual — por isso o plano mostra como sugestão, não regra.
double? aguaMl(double? pesoKg) {
  if (pesoKg == null || pesoKg <= 0) return null;
  return pesoKg * 35;
}

/// Soma nutricional de uma lista de (alimento por 100 g, gramas servidos).
({double kcal, double proteina, double carboidrato, double gordura, double fibra})
    somar(Iterable<({ValoresPor100g valores, double gramas})> itens) {
  var kcal = 0.0, p = 0.0, c = 0.0, g = 0.0, f = 0.0;
  for (final i in itens) {
    final fator = i.gramas / 100;
    kcal += i.valores.kcal * fator;
    p += i.valores.proteina * fator;
    c += i.valores.carboidrato * fator;
    g += i.valores.gordura * fator;
    f += (i.valores.fibra ?? 0) * fator;
  }
  return (kcal: kcal, proteina: p, carboidrato: c, gordura: g, fibra: f);
}

/// Composição por 100 g — a unidade em que tabela oficial publica e em que o
/// banco guarda.
class ValoresPor100g {
  const ValoresPor100g({
    required this.kcal,
    required this.proteina,
    required this.carboidrato,
    required this.gordura,
    this.fibra,
    this.sodio,
  });

  final double kcal;
  final double proteina;
  final double carboidrato;
  final double gordura;
  final double? fibra;
  final double? sodio;
}

/// Quanto da meta já foi atingido, limitado a 1 para a barra não estourar.
double proporcao(double consumido, double? meta) {
  if (meta == null || meta <= 0) return 0;
  return math.min(consumido / meta, 1);
}

/// Idade em anos completos.
int? idadeEm(DateTime? nascimento, [DateTime? referencia]) {
  if (nascimento == null) return null;
  final hoje = referencia ?? DateTime.now();
  var anos = hoje.year - nascimento.year;
  final fezAniversario = hoje.month > nascimento.month ||
      (hoje.month == nascimento.month && hoje.day >= nascimento.day);
  if (!fezAniversario) anos--;
  return anos < 0 ? null : anos;
}
