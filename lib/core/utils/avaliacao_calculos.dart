import 'dart:math';

/// As contas da avaliação física, sem Flutter e sem banco.
///
/// Ficam isoladas para serem testadas (`test/avaliacao_calculos_test.dart`)
/// e para que a tela, o relatório em PDF e a evolução usem exatamente a
/// mesma fórmula. Antes, cada tela fazia a sua — o FCmáx do resumo e o da
/// zona de treino podiam discordar.
///
/// Toda função devolve `null` quando falta dado. Mostrar "0" no lugar de
/// "não medido" faz o personal achar que mediu e deu zero.

/// Como a classificação é lida: o tom da tela e o destaque no PDF vêm daqui.
enum Nivel { bom, atencao, risco, neutro }

class Classificacao {
  const Classificacao(this.rotulo, this.nivel);
  final String rotulo;
  final Nivel nivel;
}

/// Um índice calculado, com a classificação e de onde ela vem.
class Indice {
  const Indice({
    required this.valor,
    this.classificacao,
    this.referencia,
  });

  final double valor;
  final Classificacao? classificacao;

  /// Fonte do ponto de corte, para o personal poder justificar ao aluno.
  final String? referencia;
}

/// O cadastro guarda "Masculino", "Feminino" ou "Outro". As fórmulas só
/// conhecem dois sexos biológicos; "Outro" e vazio caem em masculino, e a
/// tela avisa ([sexoParaFormula] devolve `null` nesse caso).
bool? sexoParaFormula(String? genero) {
  final g = (genero ?? '').trim().toLowerCase();
  if (g.startsWith('f')) return false;
  if (g.startsWith('m')) return true;
  return null;
}

bool ehMasculino(String? genero) => sexoParaFormula(genero) ?? true;

// ═════════════════════════════════════════════════════════════
//  Índices antropométricos
// ═════════════════════════════════════════════════════════════

abstract class Indices {
  /// IMC com a classificação da OMS. Estatura em cm.
  static Indice? imc(double? pesoKg, double? estaturaCm) {
    if (pesoKg == null || estaturaCm == null || pesoKg <= 0 || estaturaCm <= 0) {
      return null;
    }
    final m = estaturaCm / 100;
    final v = pesoKg / (m * m);
    final Classificacao c;
    if (v < 18.5) {
      c = const Classificacao('Baixo peso', Nivel.atencao);
    } else if (v < 25) {
      c = const Classificacao('Peso adequado', Nivel.bom);
    } else if (v < 30) {
      c = const Classificacao('Sobrepeso', Nivel.atencao);
    } else if (v < 35) {
      c = const Classificacao('Obesidade grau I', Nivel.risco);
    } else if (v < 40) {
      c = const Classificacao('Obesidade grau II', Nivel.risco);
    } else {
      c = const Classificacao('Obesidade grau III', Nivel.risco);
    }
    return Indice(valor: v, classificacao: c, referencia: 'OMS');
  }

  /// Relação cintura-quadril. Corte da OMS: 0,90 homem, 0,85 mulher.
  static Indice? rcq(double? cintura, double? quadril, {required bool masculino}) {
    if (cintura == null || quadril == null || cintura <= 0 || quadril <= 0) {
      return null;
    }
    final v = cintura / quadril;
    final corte = masculino ? 0.90 : 0.85;
    return Indice(
      valor: v,
      classificacao: v >= corte
          ? const Classificacao('Risco aumentado', Nivel.risco)
          : const Classificacao('Adequada', Nivel.bom),
      referencia: 'OMS',
    );
  }

  /// Relação cintura-estatura. 0,5 é o corte que vale para os dois sexos
  /// e para qualquer idade — por isso é o índice mais fácil de explicar:
  /// "a cintura tem que ser menor que metade da altura".
  static Indice? rce(double? cintura, double? estaturaCm) {
    if (cintura == null || estaturaCm == null || cintura <= 0 || estaturaCm <= 0) {
      return null;
    }
    final v = cintura / estaturaCm;
    final Classificacao c;
    if (v < 0.4) {
      c = const Classificacao('Abaixo do esperado', Nivel.atencao);
    } else if (v < 0.5) {
      c = const Classificacao('Adequada', Nivel.bom);
    } else if (v < 0.6) {
      c = const Classificacao('Risco aumentado', Nivel.atencao);
    } else {
      c = const Classificacao('Risco alto', Nivel.risco);
    }
    return Indice(valor: v, classificacao: c, referencia: 'Ashwell');
  }

  /// Circunferência da cintura isolada (OMS / IDF).
  static Indice? cintura(double? cintura, {required bool masculino}) {
    if (cintura == null || cintura <= 0) return null;
    final (aumentado, muito) = masculino ? (94.0, 102.0) : (80.0, 88.0);
    final Classificacao c;
    if (cintura >= muito) {
      c = const Classificacao('Risco muito aumentado', Nivel.risco);
    } else if (cintura >= aumentado) {
      c = const Classificacao('Risco aumentado', Nivel.atencao);
    } else {
      c = const Classificacao('Adequada', Nivel.bom);
    }
    return Indice(valor: cintura, classificacao: c, referencia: 'OMS');
  }

  /// Índice de adiposidade corporal (Bergman, 2011): estimativa de % de
  /// gordura só com quadril e altura. Serve para quem não tem adipômetro
  /// nem balança de bioimpedância — por isso entra sem classificação, como
  /// estimativa.
  static Indice? iac(double? quadril, double? estaturaCm) {
    if (quadril == null || estaturaCm == null || quadril <= 0 || estaturaCm <= 0) {
      return null;
    }
    final m = estaturaCm / 100;
    return Indice(
      valor: quadril / pow(m, 1.5) - 18,
      referencia: 'Bergman',
    );
  }
}

// ═════════════════════════════════════════════════════════════
//  Pressão arterial e frequência cardíaca
// ═════════════════════════════════════════════════════════════

abstract class Cardiaco {
  /// Diretriz Brasileira de Hipertensão Arterial (2020). Quando sistólica
  /// e diastólica caem em faixas diferentes, vale a mais alta.
  static Classificacao? pressao(int? sistolica, int? diastolica) {
    if (sistolica == null || diastolica == null || sistolica <= 0 || diastolica <= 0) {
      return null;
    }
    int faixa(int v, List<int> cortes) {
      var i = 0;
      while (i < cortes.length && v >= cortes[i]) {
        i++;
      }
      return i;
    }

    final f = max(
      faixa(sistolica, const [120, 130, 140, 160, 180]),
      faixa(diastolica, const [80, 85, 90, 100, 110]),
    );
    return const [
      Classificacao('Ótima', Nivel.bom),
      Classificacao('Normal', Nivel.bom),
      Classificacao('Pré-hipertensão', Nivel.atencao),
      Classificacao('Hipertensão estágio 1', Nivel.risco),
      Classificacao('Hipertensão estágio 2', Nivel.risco),
      Classificacao('Hipertensão estágio 3', Nivel.risco),
    ][f];
  }

  /// Tanaka (2001). Mais preciso que 220 − idade acima dos 40 anos, onde a
  /// fórmula antiga subestima.
  static int? fcMaxTanaka(int? idade) =>
      idade == null || idade <= 0 ? null : (208 - 0.7 * idade).round();

  /// A fórmula que todo aluno já ouviu falar. Mostrada ao lado da de
  /// Tanaka para o personal não precisar explicar por que "mudou".
  static int? fcMaxClassica(int? idade) =>
      idade == null || idade <= 0 ? null : 220 - idade;

  /// FC de repouso em adulto.
  static Classificacao? fcRepouso(int? bpm) {
    if (bpm == null || bpm <= 0) return null;
    if (bpm < 60) return const Classificacao('Baixa (comum em treinados)', Nivel.bom);
    if (bpm <= 80) return const Classificacao('Adequada', Nivel.bom);
    if (bpm <= 100) return const Classificacao('Elevada', Nivel.atencao);
    return const Classificacao('Taquicardia', Nivel.risco);
  }

  /// Zonas de Karvonen. Sem FC de repouso cai no percentual da FCmáx
  /// direto, que é o que dá para fazer com o que se tem.
  static List<ZonaTreino> zonas(int fcMax, int? fcRepouso) {
    const faixas = [
      ('Z1', 'Recuperação', 0.50, 0.60),
      ('Z2', 'Aeróbio leve', 0.60, 0.70),
      ('Z3', 'Aeróbio', 0.70, 0.80),
      ('Z4', 'Limiar', 0.80, 0.90),
      ('Z5', 'Máximo', 0.90, 1.00),
    ];
    final rep = (fcRepouso != null && fcRepouso > 0 && fcRepouso < fcMax) ? fcRepouso : 0;
    int bpm(double p) => (rep + p * (fcMax - rep)).round();
    return [
      for (final (id, nome, de, ate) in faixas)
        ZonaTreino(id: id, nome: nome, pctDe: de, pctAte: ate, bpmDe: bpm(de), bpmAte: bpm(ate)),
    ];
  }
}

class ZonaTreino {
  const ZonaTreino({
    required this.id,
    required this.nome,
    required this.pctDe,
    required this.pctAte,
    required this.bpmDe,
    required this.bpmAte,
  });

  final String id;
  final String nome;
  final double pctDe;
  final double pctAte;
  final int bpmDe;
  final int bpmAte;
}

// ═════════════════════════════════════════════════════════════
//  Testes cardiorrespiratórios
// ═════════════════════════════════════════════════════════════

/// O que cada protocolo pede. A tela monta o formulário a partir disto.
enum CampoCardio { distancia, tempo, fcFinal, peso }

/// Dados de um teste já feito.
class EntradaCardio {
  const EntradaCardio({
    required this.masculino,
    this.idade,
    this.pesoKg,
    this.distanciaM,
    this.tempoSeg,
    this.fcFinal,
  });

  final bool masculino;
  final int? idade;
  final double? pesoKg;
  final double? distanciaM;
  final int? tempoSeg;
  final int? fcFinal;
}

class ProtocoloCardio {
  const ProtocoloCardio({
    required this.id,
    required this.nome,
    required this.nomeCurto,
    required this.instrucao,
    required this.campos,
    required this.referencia,
    required this.calcular,
  });

  final String id;
  final String nome;

  /// O que cabe num chip de filtro.
  final String nomeCurto;

  /// Como aplicar, em uma frase. Aparece no formulário e no PDF.
  final String instrucao;
  final List<CampoCardio> campos;
  final String referencia;
  final double? Function(EntradaCardio e) calcular;

  /// VO₂máx em ml/kg/min. `null` se faltar campo ou o resultado for
  /// fisiologicamente impossível (erro de digitação, quase sempre).
  double? vo2max(EntradaCardio e) {
    final v = calcular(e);
    if (v == null || v.isNaN || v <= 5 || v > 95) return null;
    return v;
  }

  static ProtocoloCardio? porId(String? id) {
    for (final p in todos) {
      if (p.id == id) return p;
    }
    return null;
  }

  static final List<ProtocoloCardio> todos = [
    ProtocoloCardio(
      id: 'cooper12',
      nomeCurto: 'Cooper 12 min',
      nome: 'Cooper 12 minutos',
      instrucao: 'Correr ou caminhar a maior distância possível em 12 minutos, em pista plana.',
      campos: const [CampoCardio.distancia],
      referencia: 'Cooper, 1968',
      calcular: (e) {
        final d = e.distanciaM;
        if (d == null || d <= 0) return null;
        return (d - 504.9) / 44.73;
      },
    ),
    ProtocoloCardio(
      id: 'corrida2400',
      nomeCurto: 'Corrida 2.400 m',
      nome: 'Corrida 2.400 m',
      instrucao: 'Percorrer 2.400 metros no menor tempo possível.',
      campos: const [CampoCardio.tempo],
      referencia: 'ACSM',
      calcular: (e) {
        final t = e.tempoSeg;
        if (t == null || t <= 0) return null;
        // Velocidade em m/min aplicada à equação de corrida do ACSM.
        final velocidade = 2400 / (t / 60);
        return 0.2 * velocidade + 3.5;
      },
    ),
    ProtocoloCardio(
      id: 'rockport',
      nomeCurto: 'Rockport',
      nome: 'Caminhada de 1 milha (Rockport)',
      instrucao: 'Caminhar 1.609 metros o mais rápido possível, sem correr. '
          'Anotar o tempo e a FC ao cruzar a chegada.',
      campos: const [CampoCardio.tempo, CampoCardio.fcFinal, CampoCardio.peso],
      referencia: 'Kline et al., 1987',
      calcular: (e) {
        final t = e.tempoSeg, fc = e.fcFinal, p = e.pesoKg, i = e.idade;
        if (t == null || fc == null || p == null || i == null) return null;
        final libras = p * 2.20462;
        return 132.853 -
            0.0769 * libras -
            0.3877 * i +
            6.315 * (e.masculino ? 1 : 0) -
            3.2649 * (t / 60) -
            0.1565 * fc;
      },
    ),
    ProtocoloCardio(
      id: 'banco_queens',
      nomeCurto: 'Banco',
      nome: 'Banco de Queens College',
      instrucao: 'Subir e descer um banco de 41,3 cm por 3 minutos '
          '(homens 24 e mulheres 22 ciclos/min). Medir a FC de 5 a 20 s após '
          'parar e multiplicar por 4.',
      campos: const [CampoCardio.fcFinal],
      referencia: 'McArdle et al., 1972',
      calcular: (e) {
        final fc = e.fcFinal;
        if (fc == null || fc <= 0) return null;
        return e.masculino ? 111.33 - 0.42 * fc : 65.81 - 0.1847 * fc;
      },
    ),
    ProtocoloCardio(
      id: 'bruce',
      nomeCurto: 'Esteira (Bruce)',
      nome: 'Esteira — protocolo de Bruce',
      instrucao: 'Teste em esteira com estágios de 3 minutos, até a exaustão. '
          'Anotar o tempo total de esforço.',
      campos: const [CampoCardio.tempo],
      referencia: 'Foster et al., 1984 / Pollock et al., 1982',
      calcular: (e) {
        final s = e.tempoSeg;
        if (s == null || s <= 0) return null;
        final t = s / 60;
        return e.masculino
            ? 14.8 - 1.379 * t + 0.451 * t * t - 0.012 * t * t * t
            : 4.38 * t - 3.9;
      },
    ),
  ];
}

/// Classificação do VO₂máx pela tabela da American Heart Association.
///
/// Abaixo de 20 anos usa a faixa 20–29 e acima de 69 usa 60–69: a tabela
/// não cobre essas idades, e deixar sem classificação seria pior do que
/// aproximar pela faixa vizinha.
Classificacao? classificarVo2(double? vo2, {required bool masculino, int? idade}) {
  if (vo2 == null) return null;
  // Limite inferior de "fraca", "regular", "boa" e "excelente".
  const homens = [
    [25, 34, 43, 53], // 20–29
    [23, 31, 39, 49], // 30–39
    [20, 27, 36, 45], // 40–49
    [18, 25, 34, 43], // 50–59
    [16, 23, 31, 41], // 60–69
  ];
  const mulheres = [
    [24, 31, 38, 49],
    [20, 28, 34, 45],
    [17, 24, 31, 42],
    [15, 21, 28, 38],
    [13, 18, 24, 35],
  ];
  final faixa = (((idade ?? 30) - 20) ~/ 10).clamp(0, 4);
  final cortes = (masculino ? homens : mulheres)[faixa];
  if (vo2 >= cortes[3]) return const Classificacao('Excelente', Nivel.bom);
  if (vo2 >= cortes[2]) return const Classificacao('Boa', Nivel.bom);
  if (vo2 >= cortes[1]) return const Classificacao('Regular', Nivel.atencao);
  if (vo2 >= cortes[0]) return const Classificacao('Fraca', Nivel.risco);
  return const Classificacao('Muito fraca', Nivel.risco);
}

// ═════════════════════════════════════════════════════════════
//  Postural
// ═════════════════════════════════════════════════════════════

enum VistaPostural {
  frente('foto_frente', 'Frente'),
  costas('foto_costas', 'Costas'),
  ladoDir('foto_lado_dir', 'Lateral direita'),
  ladoEsq('foto_lado_esq', 'Lateral esquerda');

  const VistaPostural(this.coluna, this.rotulo);
  final String coluna;
  final String rotulo;
}

enum GrauDesvio {
  leve('leve', 'Leve'),
  moderado('moderado', 'Moderado'),
  acentuado('acentuado', 'Acentuado');

  const GrauDesvio(this.id, this.rotulo);
  final String id;
  final String rotulo;

  static GrauDesvio? porId(Object? id) {
    for (final g in values) {
      if (g.id == id) return g;
    }
    return null;
  }
}

class DesvioPostural {
  const DesvioPostural(this.chave, this.nome);
  final String chave;
  final String nome;
}

class RegiaoPostural {
  const RegiaoPostural(this.nome, this.desvios);
  final String nome;
  final List<DesvioPostural> desvios;
}

/// A lista que vira o checklist. A chave é o que fica gravado em
/// `avaliacao_postural.desvios`; mudar uma chave apaga o histórico dela.
const regioesPosturais = [
  RegiaoPostural('Cabeça e pescoço', [
    DesvioPostural('cabeca_anteriorizada', 'Cabeça anteriorizada'),
    DesvioPostural('cabeca_inclinada', 'Inclinação lateral da cabeça'),
    DesvioPostural('cabeca_rodada', 'Rotação da cabeça'),
  ]),
  RegiaoPostural('Ombros e escápulas', [
    DesvioPostural('ombros_protrusos', 'Ombros protrusos'),
    DesvioPostural('ombros_desnivelados', 'Desnível dos ombros'),
    DesvioPostural('escapulas_aladas', 'Escápulas aladas'),
    DesvioPostural('escapulas_abduzidas', 'Escápulas abduzidas'),
  ]),
  RegiaoPostural('Coluna', [
    DesvioPostural('hipercifose', 'Hipercifose torácica'),
    DesvioPostural('hiperlordose', 'Hiperlordose lombar'),
    DesvioPostural('retificacao_lombar', 'Retificação lombar'),
    DesvioPostural('escoliose', 'Escoliose'),
  ]),
  RegiaoPostural('Pelve', [
    DesvioPostural('pelve_anteversao', 'Anteversão pélvica'),
    DesvioPostural('pelve_retroversao', 'Retroversão pélvica'),
    DesvioPostural('pelve_desnivelada', 'Desnível pélvico'),
  ]),
  RegiaoPostural('Joelhos', [
    DesvioPostural('joelho_valgo', 'Joelho valgo'),
    DesvioPostural('joelho_varo', 'Joelho varo'),
    DesvioPostural('joelho_recurvato', 'Hiperextensão (recurvato)'),
    DesvioPostural('joelho_flexo', 'Joelho flexo'),
  ]),
  RegiaoPostural('Pés', [
    DesvioPostural('pe_plano', 'Pé plano'),
    DesvioPostural('pe_cavo', 'Pé cavo'),
    DesvioPostural('pe_pronado', 'Pé pronado'),
    DesvioPostural('pe_supinado', 'Pé supinado'),
  ]),
];

String? nomeDoDesvio(String chave) {
  for (final r in regioesPosturais) {
    for (final d in r.desvios) {
      if (d.chave == chave) return d.nome;
    }
  }
  return null;
}
