/// Um aluno, com o que a lista precisa saber sobre ele.
///
/// Os três últimos campos não vêm da tabela `alunos` — são calculados por
/// `AlunoService.listarComResumo` a partir de fichas e execuções. Ficam
/// aqui porque a lista sem eles é só uma agenda de contatos: é `ultimoTreino`
/// e `adesao` que dizem de quem o personal precisa cuidar hoje.
class Aluno {
  const Aluno({
    required this.id,
    required this.personalId,
    required this.nome,
    this.userId,
    this.email,
    this.whatsapp,
    this.dataNascimento,
    this.genero,
    this.grupo,
    this.fotoUrl,
    this.notas,
    this.ativo = true,
    this.anamneseTipo = 'nenhuma',
    this.anamnesePreenchida = false,
    this.ultimoTreino,
    this.temFicha = false,
    this.adesao,
  });

  final String id;
  final String personalId;
  final String nome;
  final String? userId;
  final String? email;
  final String? whatsapp;
  final DateTime? dataNascimento;
  final String? genero;
  final String? grupo;
  final String? fotoUrl;
  final String? notas;
  final bool ativo;
  final String anamneseTipo;
  final bool anamnesePreenchida;

  final DateTime? ultimoTreino;
  final bool temFicha;

  /// 0 a 1 nos últimos 30 dias. `null` quando o aluno não tem ficha — aí
  /// não existe denominador, e mostrar "0%" culparia o aluno por algo que
  /// é tarefa do personal.
  final double? adesao;

  /// Ainda não fez login no app.
  bool get semAcesso => userId == null;

  int? get diasSemTreinar {
    if (ultimoTreino == null) return null;
    final hoje = DateTime.now();
    return DateTime(hoje.year, hoje.month, hoje.day)
        .difference(DateTime(ultimoTreino!.year, ultimoTreino!.month, ultimoTreino!.day))
        .inDays;
  }

  /// O que aparece embaixo do nome na lista. A ordem é a da urgência:
  /// primeiro o que exige ação do personal, depois o status normal.
  String get situacao {
    if (!ativo) return 'Inativo';
    if (!temFicha) return 'Sem ficha atribuída';
    final d = diasSemTreinar;
    if (d == null) return 'Ainda não treinou';
    if (d == 0) return 'Treinou hoje';
    if (d == 1) return 'Treinou ontem';
    if (d >= 10) return 'Sem treinar há $d dias';
    return 'Treinou há $d dias';
  }

  bool get precisaAtencao {
    if (!ativo) return false;
    if (!temFicha) return true;
    final d = diasSemTreinar;
    return d == null || d >= 10;
  }

  factory Aluno.doMapa(
    Map<String, dynamic> m, {
    DateTime? ultimoTreino,
    bool temFicha = false,
    double? adesao,
  }) {
    return Aluno(
      id: m['id'] as String,
      personalId: m['personal_id'] as String,
      nome: m['nome'] as String? ?? 'Sem nome',
      userId: m['user_id'] as String?,
      email: m['email'] as String?,
      whatsapp: m['whatsapp'] as String?,
      dataNascimento: DateTime.tryParse(m['data_nascimento'] as String? ?? ''),
      genero: m['genero'] as String?,
      grupo: m['grupo'] as String?,
      fotoUrl: m['foto_url'] as String?,
      notas: m['notas'] as String?,
      ativo: m['ativo'] as bool? ?? true,
      anamneseTipo: m['anamnese_tipo'] as String? ?? 'nenhuma',
      anamnesePreenchida: m['anamnese_preenchida'] as bool? ?? false,
      ultimoTreino: ultimoTreino,
      temFicha: temFicha,
      adesao: adesao,
    );
  }

  /// O mapa que as telas antigas ainda esperam via `state.extra`.
  /// Sai quando `aluno_perfil_screen` for reescrita.
  Map<String, dynamic> get mapa => {
        'id': id,
        'personal_id': personalId,
        'user_id': userId,
        'nome': nome,
        'email': email,
        'whatsapp': whatsapp,
        'data_nascimento': dataNascimento?.toIso8601String().split('T').first,
        'genero': genero,
        'grupo': grupo,
        'foto_url': fotoUrl,
        'notas': notas,
        'ativo': ativo,
        'anamnese_tipo': anamneseTipo,
        'anamnese_preenchida': anamnesePreenchida,
      };
}

enum FiltroAluno { todos, ativos, atencao, inativos }

extension FiltroAlunoRotulo on FiltroAluno {
  String get rotulo => switch (this) {
        FiltroAluno.todos => 'Todos',
        FiltroAluno.ativos => 'Ativos',
        FiltroAluno.atencao => 'Atenção',
        FiltroAluno.inativos => 'Inativos',
      };

  bool aceita(Aluno a) => switch (this) {
        FiltroAluno.todos => true,
        FiltroAluno.ativos => a.ativo,
        FiltroAluno.atencao => a.precisaAtencao,
        FiltroAluno.inativos => !a.ativo,
      };
}
