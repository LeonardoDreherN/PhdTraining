import '../utils/avaliacao_calculos.dart';
import '../utils/datas.dart';

/// Chave que leva a data da sessão pelo mapa do aluno.
///
/// Os formulários antigos (dobras, bioimpedância, neuromotores) recebem só
/// `aluno` e repassam esse mesmo mapa de tela em tela. Pendurar a data nele
/// faz o teste novo nascer no dia da sessão sem mexer na navegação de
/// nenhum deles. Ver `migrations/0008`: a sessão É a data.
const kDataDaSessao = 'avaliacao_data';

/// Cópia do aluno com a data da sessão. Cópia porque o mapa original é o
/// mesmo que a lista de alunos segura — escrever nele vazaria a data para
/// a próxima tela que abrir esse aluno.
Map<String, dynamic> alunoNaSessao(Map<String, dynamic> aluno, DateTime data) =>
    {...aluno, kDataDaSessao: Datas.iso(data)};

/// Data inicial de um teste novo: a da sessão, ou hoje se o formulário foi
/// aberto fora de uma.
DateTime dataDaSessao(Map<String, dynamic> aluno) =>
    Datas.ler(aluno[kDataDaSessao]) ?? DateTime.now();

double? _d(Object? v) => (v as num?)?.toDouble();
int? _i(Object? v) => (v as num?)?.toInt();

/// A linha de `avaliacoes`: o que é da avaliação inteira, não de um teste.
class AvaliacaoSessao {
  const AvaliacaoSessao({
    this.id,
    required this.alunoId,
    required this.data,
    this.peso,
    this.estatura,
    this.cintura,
    this.quadril,
    this.paSistolica,
    this.paDiastolica,
    this.fcRepouso,
    this.observacoes,
    this.proximaAvaliacao,
  });

  final String? id;
  final String alunoId;
  final DateTime data;
  final double? peso;
  final double? estatura;
  final double? cintura;
  final double? quadril;
  final int? paSistolica;
  final int? paDiastolica;
  final int? fcRepouso;
  final String? observacoes;
  final DateTime? proximaAvaliacao;

  factory AvaliacaoSessao.doMapa(Map<String, dynamic> m) => AvaliacaoSessao(
        id: m['id'] as String?,
        alunoId: m['aluno_id'] as String,
        data: Datas.ler(m['data_avaliacao']) ?? DateTime.now(),
        peso: _d(m['peso']),
        estatura: _d(m['estatura']),
        cintura: _d(m['cintura']),
        quadril: _d(m['quadril']),
        paSistolica: _i(m['pa_sistolica']),
        paDiastolica: _i(m['pa_diastolica']),
        fcRepouso: _i(m['fc_repouso']),
        observacoes: m['observacoes'] as String?,
        proximaAvaliacao: Datas.ler(m['proxima_avaliacao']),
      );

  Map<String, dynamic> paraMapa() => {
        'aluno_id': alunoId,
        'data_avaliacao': Datas.iso(data),
        'peso': peso,
        'estatura': estatura,
        'cintura': cintura,
        'quadril': quadril,
        'pa_sistolica': paSistolica,
        'pa_diastolica': paDiastolica,
        'fc_repouso': fcRepouso,
        'observacoes': observacoes,
        'proxima_avaliacao': proximaAvaliacao == null ? null : Datas.iso(proximaAvaliacao!),
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      };
}

/// Uma linha da lista de avaliações do aluno.
class ResumoSessao {
  const ResumoSessao({
    required this.sessao,
    this.peso,
    this.percGordura,
    this.testes = 0,
  });

  final AvaliacaoSessao sessao;
  final double? peso;
  final double? percGordura;

  /// Quantos testes foram feitos naquele dia, de todos os tipos.
  final int testes;
}

/// Tudo o que foi medido num dia, já com as medidas resolvidas.
///
/// Os mapas de teste continuam `Map` porque são os mesmos que os
/// formulários antigos leem e gravam. O que é calculado a partir deles
/// mora aqui, tipado, para a tela e o PDF não refazerem a conta.
class AvaliacaoCompleta {
  const AvaliacaoCompleta({
    required this.sessao,
    required this.aluno,
    this.dobras,
    this.bioimpedancia,
    this.flexibilidade = const [],
    this.resistencia = const [],
    this.impulsao = const [],
    this.carga = const [],
    this.cardio = const [],
    this.postural,
    this.estaturaAnterior,
    this.anterior,
  });

  final AvaliacaoSessao sessao;
  final Map<String, dynamic> aluno;

  /// A dobra e a bioimpedância mais recentes do dia (normalmente só há uma).
  final Map<String, dynamic>? dobras;
  final Map<String, dynamic>? bioimpedancia;

  final List<Map<String, dynamic>> flexibilidade;
  final List<Map<String, dynamic>> resistencia;
  final List<Map<String, dynamic>> impulsao;
  final List<Map<String, dynamic>> carga;
  final List<Map<String, dynamic>> cardio;

  /// Com as fotos já trocadas por URLs assinadas.
  final Map<String, dynamic>? postural;

  /// Estatura de uma avaliação passada. Adulto não muda de altura; pedir
  /// de novo a cada três meses é só atrito.
  final double? estaturaAnterior;

  /// A avaliação anterior, para a comparação. Não carrega a anterior dela.
  final AvaliacaoCompleta? anterior;

  DateTime get data => sessao.data;

  // ── Medidas resolvidas: sessão primeiro, depois os testes do dia ──

  double? get peso =>
      sessao.peso ?? _d(dobras?['peso']) ?? _d(bioimpedancia?['peso']);

  double? get estatura =>
      sessao.estatura ??
      _d(dobras?['estatura']) ??
      _d(bioimpedancia?['estatura']) ??
      estaturaAnterior;

  double? get cintura =>
      sessao.cintura ?? _d(dobras?['cintura']) ?? _d(bioimpedancia?['cintura']);

  double? get quadril =>
      sessao.quadril ?? _d(dobras?['quadril']) ?? _d(bioimpedancia?['quadril']);

  /// % de gordura medido. Dobra tem prioridade sobre bioimpedância: é a
  /// medida que o personal fez com a mão, e a bioimpedância de balança
  /// varia muito com hidratação.
  double? get percGordura =>
      _d(dobras?['perc_gordura']) ?? _d(bioimpedancia?['perc_gordura']);

  double? get massaGorda =>
      _d(dobras?['massa_gorda']) ?? _d(bioimpedancia?['massa_gorda']);

  double? get massaMagra =>
      _d(dobras?['massa_magra']) ?? _d(bioimpedancia?['massa_magra']);

  String? get origemGordura => dobras?['perc_gordura'] != null
      ? 'Dobras cutâneas'
      : bioimpedancia?['perc_gordura'] != null
          ? 'Bioimpedância'
          : null;

  // ── Aluno ──

  String? get genero => aluno['genero'] as String?;
  bool get masculino => ehMasculino(genero);

  /// O cadastro não diz o sexo biológico: as fórmulas estão assumindo um.
  bool get sexoIndefinido => sexoParaFormula(genero) == null;

  int? get idade =>
      Datas.idade(Datas.ler(aluno['data_nascimento']), data) ??
      _i(dobras?['idade']) ??
      _i(bioimpedancia?['idade']);

  // ── Índices ──

  Indice? get imc => Indices.imc(peso, estatura);
  Indice? get rcq => Indices.rcq(cintura, quadril, masculino: masculino);
  Indice? get rce => Indices.rce(cintura, estatura);
  Indice? get indiceCintura => Indices.cintura(cintura, masculino: masculino);
  Indice? get iac => Indices.iac(quadril, estatura);

  Classificacao? get pressao =>
      Cardiaco.pressao(sessao.paSistolica, sessao.paDiastolica);

  int? get fcMax => Cardiaco.fcMaxTanaka(idade);

  List<ZonaTreino> get zonas =>
      fcMax == null ? const [] : Cardiaco.zonas(fcMax!, sessao.fcRepouso);

  /// O melhor VO₂máx do dia. Se o personal aplicou dois protocolos, o
  /// maior é o que mais se aproxima da capacidade real — teste submáximo
  /// subestima, nunca superestima.
  double? get vo2max {
    double? melhor;
    for (final c in cardio) {
      final v = _d(c['vo2max']);
      if (v != null && (melhor == null || v > melhor)) melhor = v;
    }
    return melhor;
  }

  Classificacao? get classificacaoVo2 =>
      classificarVo2(vo2max, masculino: masculino, idade: idade);

  Map<String, GrauDesvio> get desvios {
    final bruto = postural?['desvios'];
    if (bruto is! Map) return const {};
    return {
      for (final e in bruto.entries)
        if (GrauDesvio.porId(e.value) != null) e.key as String: GrauDesvio.porId(e.value)!,
    };
  }

  int get totalTestes =>
      (dobras != null ? 1 : 0) +
      (bioimpedancia != null ? 1 : 0) +
      flexibilidade.length +
      resistencia.length +
      impulsao.length +
      carga.length +
      cardio.length +
      (postural != null ? 1 : 0);
}
