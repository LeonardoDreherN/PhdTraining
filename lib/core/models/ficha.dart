/// Uma ficha de treino, com o que a lista precisa mostrar sobre ela.
///
/// `qtdExercicios`, `qtdAlunos` e `grupos` não estão na tabela `fichas` —
/// vêm calculados de `ficha_exercicios` e `aluno_fichas`. Sem eles a lista
/// é só uma fila de nomes, e o personal precisa abrir uma por uma para
/// lembrar o que tem dentro.
class Ficha {
  const Ficha({
    required this.id,
    required this.personalId,
    required this.nome,
    this.descricao,
    this.criadoEm,
    this.qtdExercicios = 0,
    this.qtdAlunos = 0,
    this.grupos = const [],
    this.minutos = 0,
  });

  final String id;
  final String personalId;
  final String nome;
  final String? descricao;
  final DateTime? criadoEm;

  final int qtdExercicios;
  final int qtdAlunos;

  /// Grupos musculares presentes, do mais frequente para o menos.
  final List<String> grupos;

  /// Duração estimada (~40 s por série + descanso), arredondada a 5 min.
  final int minutos;

  /// A letra do selo do cartão: "Treino A — Superiores" vira "A"; um nome
  /// sem letra de treino usa a inicial.
  String get sigla {
    final m = RegExp(r'^treino\s+([a-z0-9])(?![a-z0-9])', caseSensitive: false).firstMatch(nome.trim());
    if (m != null) return m.group(1)!.toUpperCase();
    return nome.trim().isEmpty ? '?' : nome.trim()[0].toUpperCase();
  }

  /// Ficha sem exercício não serve para nada — e é o estado logo depois de
  /// criar. Vale sinalizar, em vez de o personal descobrir quando o aluno
  /// abrir o treino e não achar nada.
  bool get vazia => qtdExercicios == 0;

  bool get atribuida => qtdAlunos > 0;

  String get resumo {
    if (vazia) return 'Sem exercícios ainda';
    final ex = '$qtdExercicios ${qtdExercicios == 1 ? 'exercício' : 'exercícios'}';
    if (qtdAlunos == 0) return '$ex · não atribuída';
    return '$ex · $qtdAlunos ${qtdAlunos == 1 ? 'aluno' : 'alunos'}';
  }

  factory Ficha.doMapa(
    Map<String, dynamic> m, {
    int qtdExercicios = 0,
    int qtdAlunos = 0,
    List<String> grupos = const [],
    int minutos = 0,
  }) {
    final desc = (m['descricao'] as String?)?.trim();
    return Ficha(
      id: m['id'] as String,
      personalId: m['personal_id'] as String,
      nome: m['nome'] as String? ?? 'Sem nome',
      descricao: (desc == null || desc.isEmpty) ? null : desc,
      criadoEm: DateTime.tryParse(m['criado_em'] as String? ?? ''),
      qtdExercicios: qtdExercicios,
      qtdAlunos: qtdAlunos,
      grupos: grupos,
      minutos: minutos,
    );
  }

  /// O mapa que `ficha_detalhe_screen` ainda espera via `state.extra`.
  /// Sai quando aquela tela for reescrita.
  Map<String, dynamic> get mapa => {
        'id': id,
        'personal_id': personalId,
        'nome': nome,
        'descricao': descricao,
      };
}
