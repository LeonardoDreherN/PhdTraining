/// O que o app mostra a um aluno, decidido pelo profissional.
///
/// Guardado em `alunos.recursos` (jsonb). Chave ausente = ligado: o padrão
/// é mostrar tudo, e o profissional desliga o que não quer para aquele
/// paciente.
class RecursosAluno {
  const RecursosAluno({
    this.diario = true,
    this.peso = true,
    this.nutricional = true,
    this.listaCompras = true,
    this.chat = true,
    this.trocarAlimentos = true,
  });

  /// Diário alimentar com foto.
  final bool diario;

  /// O aluno registra o próprio peso.
  final bool peso;

  /// Calorias e macros visíveis. Desligado, o aluno vê o que comer e as
  /// quantidades, mas nenhum número de kcal — para quem não deve contar.
  final bool nutricional;

  final bool listaCompras;

  /// Mensagens pelo app. Desligado, o contato fica pelo WhatsApp.
  final bool chat;

  /// O aluno troca, tira e acrescenta alimentos na refeição do dia. O plano
  /// não muda; muda o que conta como consumido.
  final bool trocarAlimentos;

  static const todos = RecursosAluno();

  factory RecursosAluno.doMapa(Object? m) {
    if (m is! Map) return todos;
    bool ler(String k) => m[k] is bool ? m[k] as bool : true;
    return RecursosAluno(
      diario: ler('diario'),
      peso: ler('peso'),
      nutricional: ler('nutricional'),
      listaCompras: ler('lista_compras'),
      chat: ler('chat'),
      trocarAlimentos: ler('trocar_alimentos'),
    );
  }

  Map<String, dynamic> paraMapa() => {
        'diario': diario,
        'peso': peso,
        'nutricional': nutricional,
        'lista_compras': listaCompras,
        'chat': chat,
        'trocar_alimentos': trocarAlimentos,
      };

  RecursosAluno copiar({
    bool? diario,
    bool? peso,
    bool? nutricional,
    bool? listaCompras,
    bool? chat,
    bool? trocarAlimentos,
  }) =>
      RecursosAluno(
        diario: diario ?? this.diario,
        peso: peso ?? this.peso,
        nutricional: nutricional ?? this.nutricional,
        listaCompras: listaCompras ?? this.listaCompras,
        chat: chat ?? this.chat,
        trocarAlimentos: trocarAlimentos ?? this.trocarAlimentos,
      );
}

/// Um combinado da consulta: "2 L de água por dia".
class MetaAluno {
  const MetaAluno({
    required this.id,
    required this.alunoId,
    required this.titulo,
    this.descricao,
    this.prazo,
    this.concluidaEm,
  });

  final String id;
  final String alunoId;
  final String titulo;
  final String? descricao;
  final DateTime? prazo;
  final DateTime? concluidaEm;

  bool get concluida => concluidaEm != null;

  factory MetaAluno.doMapa(Map<String, dynamic> m) => MetaAluno(
        id: m['id'] as String,
        alunoId: m['aluno_id'] as String,
        titulo: m['titulo'] as String? ?? 'Meta',
        descricao: m['descricao'] as String?,
        prazo: DateTime.tryParse(m['prazo'] as String? ?? ''),
        concluidaEm: DateTime.tryParse(m['concluida_em'] as String? ?? '')?.toLocal(),
      );
}
