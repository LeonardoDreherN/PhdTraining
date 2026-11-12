import '../utils/datas.dart';

/// Uma ficha dentro de uma etapa: a linha de `aluno_fichas`.
class FichaDaEtapa {
  const FichaDaEtapa({
    required this.id,
    required this.fichaId,
    required this.nome,
    required this.estado,
    this.diasSemana = const [],
  });

  /// Id da linha de `aluno_fichas`, não da ficha.
  final String id;
  final String fichaId;
  final String nome;

  /// programada, vigente ou encerrada (migração 0024).
  final String estado;
  final List<int> diasSemana;

  factory FichaDaEtapa.doMapa(Map<String, dynamic> m) {
    final f = (m['fichas'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FichaDaEtapa(
      id: m['id'] as String,
      fichaId: (f['id'] ?? m['ficha_id']) as String,
      nome: f['nome'] as String? ?? 'Ficha',
      estado: m['estado'] as String? ?? 'vigente',
      diasSemana: [for (final d in (m['dias_semana'] as List?) ?? const []) (d as num).toInt()]..sort(),
    );
  }
}

/// Em que ponto do tempo a etapa está, hoje.
enum MomentoEtapa { anterior, atual, proxima }

/// Uma fase da periodização do aluno: o planejamento do mês e as fichas
/// que entram em vigor quando ela começa.
class EtapaPeriodizacao {
  const EtapaPeriodizacao({
    this.id,
    required this.alunoId,
    required this.nome,
    required this.dataInicio,
    this.dataFim,
    this.objetivo,
    this.volume,
    this.intensidade,
    this.palavrasChave = const [],
    this.observacoes,
    this.substituiAnteriores = true,
    this.fichas = const [],
  });

  final String? id;
  final String alunoId;
  final String nome;
  final DateTime dataInicio;
  final DateTime? dataFim;
  final String? objetivo;

  /// Texto livre: "16 séries semanais por grupo", "10–12 séries de peito".
  final String? volume;

  /// Texto livre: carga, RIR, proximidade da falha, métodos.
  final String? intensidade;
  final List<String> palavrasChave;
  final String? observacoes;
  final bool substituiAnteriores;
  final List<FichaDaEtapa> fichas;

  /// Objetivos sugeridos no formulário. O campo aceita qualquer texto.
  static const objetivos = [
    'Adaptação',
    'Progressão de carga',
    'Hipertrofia',
    'Intensificação',
    'Aumento de volume',
    'Recuperação',
  ];

  /// Qual etapa vale hoje, numa lista em ordem de início: a última que já
  /// começou. Mesma regra de `_aplicar_periodizacao` no banco.
  static String? idDaAtual(List<EtapaPeriodizacao> etapas, [DateTime? hoje]) {
    final h = Datas.dia(hoje ?? DateTime.now());
    String? atual;
    for (final e in etapas) {
      if (!e.dataInicio.isAfter(h)) atual = e.id;
    }
    return atual;
  }

  MomentoEtapa momento(String? idAtual, [DateTime? hoje]) {
    if (id != null && id == idAtual) return MomentoEtapa.atual;
    return dataInicio.isAfter(Datas.dia(hoje ?? DateTime.now())) ? MomentoEtapa.proxima : MomentoEtapa.anterior;
  }

  /// "01/12 – 31/12/2026", ou "desde 01/12/2026" sem fim.
  String get periodoTexto {
    String dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    final f = dataFim;
    if (f == null) return 'desde ${Datas.curta(dataInicio)}';
    return dataInicio.year == f.year
        ? '${dm(dataInicio)} – ${Datas.curta(f)}'
        : '${Datas.curta(dataInicio)} – ${Datas.curta(f)}';
  }

  factory EtapaPeriodizacao.doMapa(Map<String, dynamic> m) => EtapaPeriodizacao(
        id: m['id'] as String?,
        alunoId: m['aluno_id'] as String,
        nome: m['nome'] as String? ?? 'Etapa',
        dataInicio: Datas.ler(m['data_inicio']) ?? DateTime.now(),
        dataFim: Datas.ler(m['data_fim']),
        objetivo: m['objetivo'] as String?,
        volume: m['volume'] as String?,
        intensidade: m['intensidade'] as String?,
        palavrasChave: [for (final p in (m['palavras_chave'] as List?) ?? const []) '$p'],
        observacoes: m['observacoes'] as String?,
        substituiAnteriores: m['substitui_anteriores'] as bool? ?? true,
        fichas: [
          for (final f in (m['aluno_fichas'] as List?) ?? const [])
            if (f is Map) FichaDaEtapa.doMapa(f.cast<String, dynamic>()),
        ],
      );

  Map<String, dynamic> paraMapa() {
    String? t(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    return {
      'aluno_id': alunoId,
      'nome': nome.trim(),
      'data_inicio': Datas.iso(dataInicio),
      'data_fim': dataFim == null ? null : Datas.iso(dataFim!),
      'objetivo': t(objetivo),
      'volume': t(volume),
      'intensidade': t(intensidade),
      'palavras_chave': [for (final p in palavrasChave) if (p.trim().isNotEmpty) p.trim()],
      'observacoes': t(observacoes),
      'substitui_anteriores': substituiAnteriores,
    };
  }
}
