/// Um exercício dentro de uma ficha, já com os dados do exercício em si.
///
/// A tela antes mexia no `Map` cru vindo do PostgREST, com `item['series']`
/// espalhado. Um campo renomeado no banco só aparecia como tela em branco em
/// tempo de execução.
class FichaExercicio {
  const FichaExercicio({
    required this.id,
    required this.fichaId,
    required this.exercicioId,
    required this.nome,
    this.grupoMuscular,
    this.midiaUrl,
    this.series = 3,
    this.repeticoes,
    this.carga,
    this.descansoSegundos,
    this.observacoes,
    this.metodo = 'normal',
    this.ordem = 0,
  });

  final String id;
  final String fichaId;
  final String exercicioId;

  /// Do exercício da biblioteca, não da linha da ficha.
  final String nome;
  final String? grupoMuscular;
  final String? midiaUrl;

  final int series;
  final String? repeticoes;
  final String? carga;
  final int? descansoSegundos;
  final String? observacoes;

  /// 'normal', 'bi_set', 'drop_set', 'piramide' — a coluna existe desde o
  /// 0001. A interface ainda só escreve 'normal'.
  final String metodo;

  final int ordem;

  /// "3 × 12" — o que o personal lê primeiro no cartão.
  String get prescricao {
    final reps = (repeticoes == null || repeticoes!.trim().isEmpty)
        ? '?'
        : repeticoes!.trim();
    return '$series × $reps';
  }

  /// A carga é texto livre no banco: cabe "70", "70kg", "12RM" ou "corporal".
  /// Por isso não dá para concatenar "kg" cegamente — quem digitou "70kg"
  /// via "70kgkg" na tela antiga.
  String? get cargaFormatada {
    final c = carga?.trim();
    if (c == null || c.isEmpty) return null;
    final soNumero = RegExp(r'^[\d.,]+$').hasMatch(c);
    return soNumero ? '$c kg' : c;
  }

  String? get descansoFormatado {
    final s = descansoSegundos;
    if (s == null || s <= 0) return null;
    if (s < 60) return '${s}s';
    final min = s ~/ 60;
    final resto = s % 60;
    return resto == 0 ? '${min}min' : '${min}min ${resto}s';
  }

  factory FichaExercicio.doMapa(Map<String, dynamic> m) {
    final ex = (m['exercicios'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FichaExercicio(
      id: m['id'] as String,
      fichaId: m['ficha_id'] as String,
      exercicioId: m['exercicio_id'] as String,
      nome: ex['nome'] as String? ?? 'Exercício removido',
      grupoMuscular: ex['grupo_muscular'] as String?,
      midiaUrl: ex['midia_url'] as String?,
      series: (m['series'] as num?)?.toInt() ?? 3,
      repeticoes: m['repeticoes'] as String?,
      carga: m['carga'] as String?,
      descansoSegundos: (m['descanso_segundos'] as num?)?.toInt(),
      observacoes: m['observacoes'] as String?,
      metodo: m['metodo'] as String? ?? 'normal',
      ordem: (m['ordem'] as num?)?.toInt() ?? 0,
    );
  }

  FichaExercicio copyWith({int? ordem}) => FichaExercicio(
        id: id,
        fichaId: fichaId,
        exercicioId: exercicioId,
        nome: nome,
        grupoMuscular: grupoMuscular,
        midiaUrl: midiaUrl,
        series: series,
        repeticoes: repeticoes,
        carga: carga,
        descansoSegundos: descansoSegundos,
        observacoes: observacoes,
        metodo: metodo,
        ordem: ordem ?? this.ordem,
      );
}
