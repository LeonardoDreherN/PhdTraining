/// Um vínculo entre dois profissionais.
///
/// Quem convida continua dono dos alunos. O convidado ganha acesso ao
/// escopo dele — nutrição ou treino — e só aos alunos cujo plano inclui
/// aquele escopo, ou aos liberados na mão.
class VinculoEquipe {
  const VinculoEquipe({
    required this.id,
    required this.donoId,
    this.donoNome,
    this.convidadoId,
    this.convidadoNome,
    required this.conviteEmail,
    required this.escopo,
    required this.status,
    this.criadoEm,
    this.aceitoEm,
    this.alunosLiberados = 0,
  });

  final String id;

  final String donoId;
  final String? donoNome;

  /// Nulo enquanto o convidado não aceitou: o vínculo nasce do e-mail.
  final String? convidadoId;
  final String? convidadoNome;
  final String conviteEmail;

  /// nutricao ou treino.
  final String escopo;

  /// convidado, ativo, recusado, removido.
  final String status;

  final DateTime? criadoEm;
  final DateTime? aceitoEm;

  /// Quantos alunos foram liberados na mão, além dos que o plano já dá.
  final int alunosLiberados;

  bool get ativo => status == 'ativo';
  bool get pendente => status == 'convidado';

  String get escopoNome =>
      escopo == 'nutricao' ? 'Nutrição' : 'Treino';

  /// O que o convidado faz, em uma linha. "Escopo: nutrição" não diz
  /// nada a quem nunca viu a tela.
  String get escopoDescricao => escopo == 'nutricao'
      ? 'Monta e acompanha o plano alimentar'
      : 'Monta e acompanha os treinos';

  String get statusNome => switch (status) {
        'ativo' => 'Ativo',
        'convidado' => 'Convite enviado',
        'recusado' => 'Recusado',
        _ => 'Removido',
      };

  /// Como chamar essa pessoa na tela: o nome quando já tem conta, o
  /// e-mail enquanto não aceitou.
  String get rotulo {
    final n = convidadoNome?.trim();
    return (n == null || n.isEmpty) ? conviteEmail : n;
  }

  factory VinculoEquipe.doMapa(Map<String, dynamic> m) {
    final dono = m['dono'] as Map<String, dynamic>?;
    final convidado = m['convidado'] as Map<String, dynamic>?;
    return VinculoEquipe(
      id: m['id'] as String,
      donoId: m['dono_id'] as String,
      donoNome: dono?['nome'] as String?,
      convidadoId: m['convidado_id'] as String?,
      convidadoNome: convidado?['nome'] as String?,
      conviteEmail: m['convite_email'] as String? ?? '',
      escopo: m['escopo'] as String? ?? 'nutricao',
      status: m['status'] as String? ?? 'convidado',
      criadoEm: DateTime.tryParse(m['criado_em'] as String? ?? ''),
      aceitoEm: DateTime.tryParse(m['aceito_em'] as String? ?? ''),
      alunosLiberados:
          (m['equipe_alunos'] as List?)?.length ?? 0,
    );
  }
}
