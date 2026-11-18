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
    this.videoUrl,
    this.instrucoes,
    this.equipamento,
    this.series = 3,
    this.repeticoes,
    this.carga,
    this.descansoSegundos,
    this.observacoes,
    this.metodo = 'normal',
    this.grupoId,
    this.thumbUrl,
    this.ordem = 0,
  });

  final String id;
  final String fichaId;
  final String exercicioId;

  /// Do exercício da biblioteca, não da linha da ficha.
  final String nome;
  final String? grupoMuscular;
  final String? midiaUrl;

  /// Vídeo da execução, gravado pelo personal. A consulta da ficha não
  /// trazia esta coluna, então a tela de demonstração do aluno recebia
  /// sempre nulo — o vídeo era enviado e nunca exibido.
  final String? videoUrl;

  final String? instrucoes;
  final String? equipamento;

  final int series;
  final String? repeticoes;
  final String? carga;
  final int? descansoSegundos;
  final String? observacoes;

  /// 'normal', 'bi_set', 'drop_set', 'piramide'.
  final String metodo;

  /// Exercícios com o mesmo `grupoId` são executados juntos — bi-set,
  /// tri-set, circuito. Nulo é exercício solto.
  final String? grupoId;

  /// Capa do vídeo. Serve de miniatura: a imagem aparece parada e o vídeo
  /// só roda se o aluno tocar, em vez de carregar vídeo de todo exercício
  /// ao abrir a lista.
  final String? thumbUrl;

  final int ordem;

  bool get emGrupo => grupoId != null && grupoId!.isNotEmpty;

  /// O rótulo do método, para a tela do aluno. 'normal' não vira etiqueta:
  /// escrever "normal" em todo exercício só tira a atenção dos que não são.
  String? get metodoRotulo => switch (metodo) {
        'bi_set' => 'Bi-set',
        'tri_set' => 'Tri-set',
        'drop_set' => 'Drop-set',
        'piramide' => 'Pirâmide',
        'circuito' => 'Circuito',
        'back_off' => 'Back-off',
        'super_set' => 'Super-set',
        _ => null,
      };

  /// A imagem que representa o exercício: a capa do vídeo quando há,
  /// senão a foto cadastrada.
  String? get capa {
    final t = thumbUrl?.trim();
    if (t != null && t.isNotEmpty) return t;
    final m = midiaUrl?.trim();
    return (m == null || m.isEmpty) ? null : m;
  }

  bool get temVideo => (videoUrl?.trim().isNotEmpty ?? false);

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
      videoUrl: ex['video_url'] as String?,
      instrucoes: ex['instrucoes'] as String?,
      equipamento: ex['equipamento'] as String?,
      series: (m['series'] as num?)?.toInt() ?? 3,
      repeticoes: m['repeticoes'] as String?,
      carga: m['carga'] as String?,
      descansoSegundos: (m['descanso_segundos'] as num?)?.toInt(),
      observacoes: m['observacoes'] as String?,
      metodo: m['metodo'] as String? ?? 'normal',
      grupoId: m['grupo_id'] as String?,
      thumbUrl: ex['thumb_url'] as String?,
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
        videoUrl: videoUrl,
        instrucoes: instrucoes,
        equipamento: equipamento,
        series: series,
        repeticoes: repeticoes,
        carga: carga,
        descansoSegundos: descansoSegundos,
        observacoes: observacoes,
        metodo: metodo,
        grupoId: grupoId,
        thumbUrl: thumbUrl,
        ordem: ordem ?? this.ordem,
      );
}
