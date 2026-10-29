import '../utils/dieta_calculos.dart';

/// Um alimento da tabela de composição ou criado pelo profissional.
///
/// Os valores são por 100 g, como a tabela oficial publica. A conversão para
/// a quantidade servida acontece em [paraGramas].
class Alimento {
  const Alimento({
    required this.id,
    required this.nome,
    this.grupo,
    this.marca,
    this.oficial = false,
    this.fonte = 'manual',
    this.codigoOrigem,
    this.medidaCaseira,
    this.medidaGramas,
    this.kcal = 0,
    this.proteina = 0,
    this.carboidrato = 0,
    this.gordura = 0,
    this.fibra,
    this.sodio,
  });

  final String id;
  final String nome;
  final String? grupo;
  final String? marca;

  /// Veio de tabela de composição e vale para todo mundo.
  final bool oficial;
  final String fonte;
  final String? codigoOrigem;

  /// "1 colher de sopa cheia" e quantos gramas ela tem. É assim que o aluno
  /// entende a quantidade — ninguém pesa 23 g de arroz na correria da manhã.
  final String? medidaCaseira;
  final double? medidaGramas;

  final double kcal;
  final double proteina;
  final double carboidrato;
  final double gordura;
  final double? fibra;
  final double? sodio;

  ValoresPor100g get valores => ValoresPor100g(
        kcal: kcal,
        proteina: proteina,
        carboidrato: carboidrato,
        gordura: gordura,
        fibra: fibra,
        sodio: sodio,
      );

  /// Nome como aparece na busca: inclui a marca quando houver, porque
  /// "Whey" sozinho não diferencia dois produtos com macros diferentes.
  String get rotulo {
    final m = marca?.trim();
    return (m == null || m.isEmpty) ? nome : '$nome · $m';
  }

  /// Composição para uma porção em gramas.
  ({double kcal, double proteina, double carboidrato, double gordura, double fibra})
      paraGramas(double gramas) =>
          somar([(valores: valores, gramas: gramas)]);

  /// Quantas gramas correspondem a N medidas caseiras, quando a medida é
  /// conhecida. Devolve `null` quando o alimento não tem medida cadastrada —
  /// aí a interface pede gramas direto.
  double? gramasDeMedidas(double quantidade) {
    final g = medidaGramas;
    if (g == null || g <= 0) return null;
    return g * quantidade;
  }

  factory Alimento.doMapa(Map<String, dynamic> m) => Alimento(
        id: m['id'] as String,
        nome: m['nome'] as String? ?? 'Sem nome',
        grupo: m['grupo'] as String?,
        marca: m['marca'] as String?,
        oficial: m['oficial'] as bool? ?? false,
        fonte: m['fonte'] as String? ?? 'manual',
        codigoOrigem: m['codigo_origem'] as String?,
        medidaCaseira: m['medida_caseira'] as String?,
        medidaGramas: _num(m['medida_gramas']),
        kcal: _num(m['kcal']) ?? 0,
        proteina: _num(m['proteina']) ?? 0,
        carboidrato: _num(m['carboidrato']) ?? 0,
        gordura: _num(m['gordura']) ?? 0,
        fibra: _num(m['fibra']),
        sodio: _num(m['sodio']),
      );

  Map<String, dynamic> paraMapa() => {
        'nome': nome,
        'grupo': grupo,
        'marca': marca,
        'medida_caseira': medidaCaseira,
        'medida_gramas': medidaGramas,
        'kcal': kcal,
        'proteina': proteina,
        'carboidrato': carboidrato,
        'gordura': gordura,
        'fibra': fibra,
        'sodio': sodio,
      };
}

/// Um alimento dentro de uma refeição, com a quantidade prescrita.
class ItemRefeicao {
  const ItemRefeicao({
    required this.id,
    required this.refeicaoId,
    required this.alimento,
    required this.quantidadeG,
    this.medidaExibicao,
    this.grupoSubstituicao,
    this.observacoes,
    this.ordem = 0,
  });

  final String id;
  final String refeicaoId;
  final Alimento alimento;
  final double quantidadeG;

  /// O que o aluno lê: "2 colheres de sopa". Quando vazio, a tela mostra
  /// os gramas.
  final String? medidaExibicao;

  /// Itens da mesma refeição com este mesmo valor são intercambiáveis.
  /// Nulo = item fixo, sem substituto.
  final String? grupoSubstituicao;

  final String? observacoes;
  final int ordem;

  bool get temSubstitutos => grupoSubstituicao != null;

  String get quantidadeTexto {
    final m = medidaExibicao?.trim();
    if (m != null && m.isNotEmpty) return '$m (${_g(quantidadeG)})';
    return _g(quantidadeG);
  }

  ({double kcal, double proteina, double carboidrato, double gordura, double fibra})
      get nutrientes => alimento.paraGramas(quantidadeG);

  factory ItemRefeicao.doMapa(Map<String, dynamic> m) => ItemRefeicao(
        id: m['id'] as String,
        refeicaoId: m['refeicao_id'] as String,
        alimento: Alimento.doMapa(
          (m['alimentos'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{'id': m['alimento_id'], 'nome': '—'},
        ),
        quantidadeG: _num(m['quantidade_g']) ?? 0,
        medidaExibicao: m['medida_exibicao'] as String?,
        grupoSubstituicao: m['grupo_substituicao'] as String?,
        observacoes: m['observacoes'] as String?,
        ordem: (m['ordem'] as num?)?.toInt() ?? 0,
      );
}

/// Uma refeição do plano, com seus itens.
class Refeicao {
  const Refeicao({
    required this.id,
    required this.planoId,
    required this.nome,
    this.horario,
    this.observacoes,
    this.ordem = 0,
    this.itens = const [],
    this.receitas = const [],
  });

  final String id;
  final String planoId;
  final String nome;

  /// "07:30". Texto porque é como o Postgres devolve `time` e é como a tela
  /// exibe — converter para DateTime só para formatar de volta não ajuda.
  final String? horario;

  final String? observacoes;
  final int ordem;
  final List<ItemRefeicao> itens;

  /// Receitas da biblioteca do profissional, com as porções prescritas.
  final List<ReceitaNaRefeicao> receitas;

  bool get vazia => itens.isEmpty && receitas.isEmpty;

  /// Soma da refeição. Itens substituíveis contam **uma vez por grupo**: se
  /// a refeição oferece "arroz OU macarrão", o aluno come um dos dois, e
  /// somar os dois dobraria as calorias do plano inteiro.
  ({double kcal, double proteina, double carboidrato, double gordura, double fibra})
      get total {
    final gruposVistos = <String>{};
    final considerados = <ItemRefeicao>[];

    for (final i in itens) {
      final g = i.grupoSubstituicao;
      if (g == null) {
        considerados.add(i);
        continue;
      }
      if (gruposVistos.add(g)) considerados.add(i);
    }

    final alimentos = somar([
      for (final i in considerados)
        (valores: i.alimento.valores, gramas: i.quantidadeG),
    ]);
    var kcal = alimentos.kcal, p = alimentos.proteina, c = alimentos.carboidrato;
    var g = alimentos.gordura, f = alimentos.fibra;
    for (final r in receitas) {
      final n = r.nutrientes;
      kcal += n.kcal;
      p += n.proteina;
      c += n.carboidrato;
      g += n.gordura;
      f += n.fibra;
    }
    return (kcal: kcal, proteina: p, carboidrato: c, gordura: g, fibra: f);
  }

  /// Horário formatado para exibição, sem os segundos que o Postgres manda.
  String? get horarioTexto {
    final h = horario?.trim();
    if (h == null || h.isEmpty) return null;
    final partes = h.split(':');
    if (partes.length < 2) return h;
    return '${partes[0].padLeft(2, '0')}:${partes[1].padLeft(2, '0')}';
  }

  factory Refeicao.doMapa(
    Map<String, dynamic> m, {
    List<ItemRefeicao> itens = const [],
    List<ReceitaNaRefeicao> receitas = const [],
  }) =>
      Refeicao(
        id: m['id'] as String,
        planoId: m['plano_id'] as String,
        nome: m['nome'] as String? ?? 'Refeição',
        horario: m['horario'] as String?,
        observacoes: m['observacoes'] as String?,
        ordem: (m['ordem'] as num?)?.toInt() ?? 0,
        itens: itens,
        receitas: receitas,
      );
}

/// Um ingrediente de receita: alimento da base e gramas na receita inteira.
class IngredienteReceita {
  const IngredienteReceita({
    required this.alimento,
    required this.quantidadeG,
    this.id,
    this.medidaExibicao,
    this.ordem = 0,
  });

  /// Nulo enquanto a receita está sendo montada e ainda não foi salva.
  final String? id;
  final Alimento alimento;
  final double quantidadeG;
  final String? medidaExibicao;
  final int ordem;

  String get quantidadeTexto {
    final m = medidaExibicao?.trim();
    if (m != null && m.isNotEmpty) return '$m (${_g(quantidadeG)})';
    return _g(quantidadeG);
  }

  factory IngredienteReceita.doMapa(Map<String, dynamic> m) => IngredienteReceita(
        id: m['id'] as String?,
        alimento: Alimento.doMapa(
          (m['alimentos'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{'id': m['alimento_id'], 'nome': '—'},
        ),
        quantidadeG: _num(m['quantidade_g']) ?? 0,
        medidaExibicao: m['medida_exibicao'] as String?,
        ordem: (m['ordem'] as num?)?.toInt() ?? 0,
      );
}

/// Receita da biblioteca do profissional.
class Receita {
  const Receita({
    required this.id,
    required this.nome,
    this.rendimentoPorcoes = 1,
    this.tempoMinutos,
    this.modoPreparo,
    this.ingredientes = const [],
  });

  final String id;
  final String nome;
  final double rendimentoPorcoes;
  final int? tempoMinutos;
  final String? modoPreparo;
  final List<IngredienteReceita> ingredientes;

  ({double kcal, double proteina, double carboidrato, double gordura, double fibra})
      get total => somar([
            for (final i in ingredientes) (valores: i.alimento.valores, gramas: i.quantidadeG),
          ]);

  /// O que importa para o plano: uma porção.
  ({double kcal, double proteina, double carboidrato, double gordura, double fibra})
      get porPorcao {
    final t = total;
    final n = rendimentoPorcoes <= 0 ? 1 : rendimentoPorcoes;
    return (
      kcal: t.kcal / n,
      proteina: t.proteina / n,
      carboidrato: t.carboidrato / n,
      gordura: t.gordura / n,
      fibra: t.fibra / n,
    );
  }

  String get rendimentoTexto => '${porcoesTexto(rendimentoPorcoes)} '
      '${rendimentoPorcoes == 1 ? 'porção' : 'porções'}';

  factory Receita.doMapa(Map<String, dynamic> m) {
    final ingredientes = [
      for (final i in (m['receita_ingredientes'] as List? ?? const []))
        IngredienteReceita.doMapa((i as Map).cast<String, dynamic>()),
    ]..sort((a, b) => a.ordem.compareTo(b.ordem));
    return Receita(
      id: m['id'] as String,
      nome: m['nome'] as String? ?? 'Receita',
      rendimentoPorcoes: _num(m['rendimento_porcoes']) ?? 1,
      tempoMinutos: (m['tempo_minutos'] as num?)?.toInt(),
      modoPreparo: m['modo_preparo'] as String?,
      ingredientes: ingredientes,
    );
  }
}

/// Uma receita dentro de uma refeição do plano.
class ReceitaNaRefeicao {
  const ReceitaNaRefeicao({
    required this.id,
    required this.refeicaoId,
    required this.receita,
    this.porcoes = 1,
    this.ordem = 0,
  });

  final String id;
  final String refeicaoId;
  final Receita receita;
  final double porcoes;
  final int ordem;

  ({double kcal, double proteina, double carboidrato, double gordura, double fibra})
      get nutrientes {
    final p = receita.porPorcao;
    return (
      kcal: p.kcal * porcoes,
      proteina: p.proteina * porcoes,
      carboidrato: p.carboidrato * porcoes,
      gordura: p.gordura * porcoes,
      fibra: p.fibra * porcoes,
    );
  }

  String get porcoesTextoCompleto =>
      '${porcoesTexto(porcoes)} ${porcoes == 1 ? 'porção' : 'porções'}';

  factory ReceitaNaRefeicao.doMapa(Map<String, dynamic> m) => ReceitaNaRefeicao(
        id: m['id'] as String,
        refeicaoId: m['refeicao_id'] as String,
        receita: Receita.doMapa(
          (m['receitas'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{'id': m['receita_id'], 'nome': 'Receita'},
        ),
        porcoes: _num(m['porcoes']) ?? 1,
        ordem: (m['ordem'] as num?)?.toInt() ?? 0,
      );
}

/// `1`, `1,5`, `0,5` — porção sem zeros sobrando.
String porcoesTexto(double v) {
  final s = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);
  return s.replaceAll('.', ',');
}

/// O plano alimentar completo.
class PlanoAlimentar {
  const PlanoAlimentar({
    required this.id,
    required this.alunoId,
    required this.nome,
    this.objetivo,
    this.autorId,
    this.crnAssinatura,
    this.assinadoEm,
    this.dataInicio,
    this.dataFim,
    this.ativo = true,
    this.formulaTmb,
    this.tmb,
    this.fatorAtividade,
    this.get,
    this.metaKcal,
    this.metaProteina,
    this.metaCarboidrato,
    this.metaGordura,
    this.aguaMl,
    this.observacoes,
    this.refeicoes = const [],
  });

  final String id;
  final String alunoId;
  final String nome;
  final String? objetivo;

  /// Quem assinou e sob qual registro. O CRN fica aqui, e não só no perfil,
  /// porque o plano é um documento: se o profissional mudar de registro, o
  /// plano antigo tem de continuar mostrando o que valia quando foi assinado.
  final String? autorId;
  final String? crnAssinatura;
  final DateTime? assinadoEm;

  final DateTime? dataInicio;
  final DateTime? dataFim;
  final bool ativo;

  final String? formulaTmb;
  final double? tmb;
  final double? fatorAtividade;
  final double? get;
  final double? metaKcal;
  final double? metaProteina;
  final double? metaCarboidrato;
  final double? metaGordura;
  final double? aguaMl;

  final String? observacoes;
  final List<Refeicao> refeicoes;

  bool get assinado => assinadoEm != null && (crnAssinatura?.trim().isNotEmpty ?? false);
  bool get vazio => refeicoes.isEmpty || refeicoes.every((r) => r.vazia);

  /// Soma de todas as refeições — o que o plano de fato prescreve, que pode
  /// não bater com a meta. A diferença entre os dois é o que o nutricionista
  /// precisa ver enquanto monta.
  ({double kcal, double proteina, double carboidrato, double gordura, double fibra})
      get totalPrescrito {
    var kcal = 0.0, p = 0.0, c = 0.0, g = 0.0, f = 0.0;
    for (final r in refeicoes) {
      final t = r.total;
      kcal += t.kcal;
      p += t.proteina;
      c += t.carboidrato;
      g += t.gordura;
      f += t.fibra;
    }
    return (kcal: kcal, proteina: p, carboidrato: c, gordura: g, fibra: f);
  }

  /// Quanto o prescrito se afasta da meta, em kcal. Positivo = acima.
  double? get desvioKcal {
    final meta = metaKcal;
    if (meta == null || meta <= 0) return null;
    return totalPrescrito.kcal - meta;
  }

  ObjetivoDieta get objetivoEnum => switch (objetivo) {
        'emagrecimento' => ObjetivoDieta.emagrecimento,
        'hipertrofia' => ObjetivoDieta.hipertrofia,
        _ => ObjetivoDieta.manutencao,
      };

  factory PlanoAlimentar.doMapa(
    Map<String, dynamic> m, {
    List<Refeicao> refeicoes = const [],
  }) =>
      PlanoAlimentar(
        id: m['id'] as String,
        alunoId: m['aluno_id'] as String,
        nome: m['nome'] as String? ?? 'Plano alimentar',
        objetivo: m['objetivo'] as String?,
        autorId: m['autor_id'] as String?,
        crnAssinatura: m['crn_assinatura'] as String?,
        assinadoEm: DateTime.tryParse(m['assinado_em'] as String? ?? ''),
        dataInicio: DateTime.tryParse(m['data_inicio'] as String? ?? ''),
        dataFim: DateTime.tryParse(m['data_fim'] as String? ?? ''),
        ativo: m['ativo'] as bool? ?? true,
        formulaTmb: m['formula_tmb'] as String?,
        tmb: _num(m['tmb']),
        fatorAtividade: _num(m['fator_atividade']),
        get: _num(m['get']),
        metaKcal: _num(m['meta_kcal']),
        metaProteina: _num(m['meta_proteina']),
        metaCarboidrato: _num(m['meta_carboidrato']),
        metaGordura: _num(m['meta_gordura']),
        aguaMl: _num(m['agua_ml']),
        observacoes: m['observacoes'] as String?,
        refeicoes: refeicoes,
      );
}

/// Postgres devolve `numeric` como String em alguns caminhos do PostgREST e
/// como num em outros. Ler os dois evita um nulo silencioso que viraria
/// "0 kcal" na tela.
double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.'));
}

String _g(double gramas) {
  if (gramas >= 1000) {
    final kg = gramas / 1000;
    return '${kg.toStringAsFixed(kg.truncateToDouble() == kg ? 0 : 2)} kg';
  }
  return '${gramas.toStringAsFixed(gramas.truncateToDouble() == gramas ? 0 : 1)} g';
}
