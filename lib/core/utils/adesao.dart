/// Em que pé está o aluno com a dieta nos últimos dias.
enum SituacaoAdesao {
  /// Ordem é prioridade: o painel lista primeiro quem precisa de contato.
  semRegistro('Sem registro'),
  dificuldade('Com dificuldade'),
  noCaminho('No caminho');

  const SituacaoAdesao(this.rotulo);
  final String rotulo;
}

/// O resumo de um aluno no painel de adesão.
class AdesaoAluno {
  const AdesaoAluno({
    required this.aluno,
    required this.situacao,
    required this.feitas,
    required this.previstas,
    required this.fugas,
    this.aguaMediaMl,
    this.metaAguaMl,
    this.ultimoRegistro,
  });

  /// A linha de `alunos` — é o `extra` da tela de nutrição do aluno.
  final Map<String, dynamic> aluno;
  final SituacaoAdesao situacao;
  final int feitas;
  final int previstas;

  /// Registros do diário marcados "fugi do plano".
  final int fugas;
  final int? aguaMediaMl;
  final int? metaAguaMl;
  final DateTime? ultimoRegistro;

  String get nome => (aluno['nome'] as String?)?.trim() ?? 'Aluno';

  /// De 0 a 1; nulo quando o plano não tem refeição para cumprir.
  double? get percentual => previstas == 0 ? null : (feitas / previstas).clamp(0.0, 1.0);
}

/// Dias sem registro nenhum até o aluno virar "sem registro".
const diasSemRegistroLimite = 3;

/// Abaixo disto das refeições marcadas, o aluno está "com dificuldade".
const adesaoMinima = 0.6;

/// Fugas do plano na janela que contam como dificuldade, mesmo com as
/// refeições marcadas — quem marca tudo e foge todo dia não está bem.
const fugasLimite = 3;

/// Classifica um aluno a partir do que ele registrou.
///
/// Pura de propósito: é a regra que o profissional vai questionar ("por que
/// a Marina está com dificuldade?"), então mora num lugar só e tem teste.
AdesaoAluno calcularAdesao({
  required Map<String, dynamic> aluno,
  required int refeicoesPorDia,
  required int dias,
  required int feitas,
  required int fugas,
  required DateTime agora,
  DateTime? ultimoRegistro,
  int? aguaTotalMl,
  int diasComAgua = 0,
  int? metaAguaMl,
}) {
  final previstas = refeicoesPorDia * (dias < 1 ? 1 : dias);
  final perc = previstas == 0 ? null : feitas / previstas;

  final SituacaoAdesao situacao;
  if (ultimoRegistro == null ||
      agora.difference(ultimoRegistro).inDays >= diasSemRegistroLimite) {
    situacao = SituacaoAdesao.semRegistro;
  } else if ((perc != null && perc < adesaoMinima) || fugas >= fugasLimite) {
    situacao = SituacaoAdesao.dificuldade;
  } else {
    situacao = SituacaoAdesao.noCaminho;
  }

  return AdesaoAluno(
    aluno: aluno,
    situacao: situacao,
    feitas: feitas,
    previstas: previstas,
    fugas: fugas,
    aguaMediaMl: (aguaTotalMl == null || diasComAgua == 0) ? null : aguaTotalMl ~/ diasComAgua,
    metaAguaMl: metaAguaMl,
    ultimoRegistro: ultimoRegistro,
  );
}
