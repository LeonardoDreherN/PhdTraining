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
