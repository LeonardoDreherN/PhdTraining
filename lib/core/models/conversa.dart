/// Uma mensagem do chat entre aluno e profissional.
class Mensagem {
  const Mensagem({
    required this.id,
    required this.alunoId,
    required this.autorId,
    required this.texto,
    required this.criadoEm,
    this.lidaEm,
  });

  final String id;

  /// A conversa: há uma por aluno.
  final String alunoId;
  final String autorId;
  final String texto;
  final DateTime criadoEm;
  final DateTime? lidaEm;

  factory Mensagem.doMapa(Map<String, dynamic> m) => Mensagem(
        id: m['id'] as String,
        alunoId: m['aluno_id'] as String,
        autorId: m['autor_id'] as String,
        texto: m['texto'] as String? ?? '',
        criadoEm: DateTime.tryParse(m['criado_em'] as String? ?? '')?.toLocal() ?? DateTime.now(),
        lidaEm: DateTime.tryParse(m['lida_em'] as String? ?? '')?.toLocal(),
      );
}

enum TipoConsulta {
  avaliacao('Avaliação física'),
  retorno('Retorno'),
  nutricao('Consulta de nutrição'),
  treino('Ajuste de treino'),
  online('Consulta online');

  const TipoConsulta(this.rotulo);
  final String rotulo;

  static TipoConsulta de(String? v) =>
      TipoConsulta.values.where((t) => t.name == v).firstOrNull ?? TipoConsulta.retorno;
}

enum StatusConsulta {
  agendada('Aguardando confirmação'),
  confirmada('Confirmada'),
  remarcar('Pediu para remarcar'),
  cancelada('Cancelada'),
  realizada('Realizada');

  const StatusConsulta(this.rotulo);
  final String rotulo;

  static StatusConsulta de(String? v) =>
      StatusConsulta.values.where((s) => s.name == v).firstOrNull ?? StatusConsulta.agendada;
}

/// Uma consulta na agenda do profissional.
class Consulta {
  const Consulta({
    required this.id,
    required this.alunoId,
    required this.inicio,
    this.duracaoMin = 60,
    this.tipo = TipoConsulta.retorno,
    this.status = StatusConsulta.agendada,
    this.local,
    this.link,
    this.observacoes,
    this.nota,
    this.comentario,
    this.aluno,
  });

  final String id;
  final String alunoId;
  final DateTime inicio;
  final int duracaoMin;
  final TipoConsulta tipo;
  final StatusConsulta status;
  final String? local;
  final String? link;
  final String? observacoes;
  final int? nota;
  final String? comentario;

  /// Linha do aluno, quando veio junto na consulta (agenda do profissional).
  final Map<String, dynamic>? aluno;

  DateTime get fim => inicio.add(Duration(minutes: duracaoMin));
  bool get passou => fim.isBefore(DateTime.now());
  bool get ativa => status != StatusConsulta.cancelada;
  String get alunoNome => (aluno?['nome'] as String?)?.trim() ?? 'Aluno';

  /// `14:30`
  String get horaTexto =>
      '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}';

  factory Consulta.doMapa(Map<String, dynamic> m) => Consulta(
        id: m['id'] as String,
        alunoId: m['aluno_id'] as String,
        inicio: DateTime.parse(m['inicio'] as String).toLocal(),
        duracaoMin: (m['duracao_min'] as num?)?.toInt() ?? 60,
        tipo: TipoConsulta.de(m['tipo'] as String?),
        status: StatusConsulta.de(m['status'] as String?),
        local: m['local'] as String?,
        link: m['link'] as String?,
        observacoes: m['observacoes'] as String?,
        nota: (m['nota'] as num?)?.toInt(),
        comentario: m['comentario'] as String?,
        aluno: (m['alunos'] as Map?)?.cast<String, dynamic>(),
      );
}
