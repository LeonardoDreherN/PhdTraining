/// O que o aluno vê de um profissional: o dele, ou um indicado num cupom.
/// Vem de `perfil_publico` (migração 0022), que só devolve a vitrine.
class PerfilPublico {
  const PerfilPublico({
    required this.id,
    this.nome,
    this.avatarUrl,
    this.cref,
    this.crn,
    this.bio,
    this.formacoes = const [],
    this.whatsapp,
  });

  final String id;
  final String? nome;
  final String? avatarUrl;
  final String? cref;
  final String? crn;
  final String? bio;
  final List<String> formacoes;
  final String? whatsapp;

  String get nomeExibicao {
    final n = nome?.trim() ?? '';
    return n.isEmpty ? 'Profissional' : n;
  }

  /// "CREF 034340-G/SC · CRN 12345": os registros que ele tem.
  String? get registros {
    final r = [
      if (cref?.trim().isNotEmpty ?? false) 'CREF ${cref!.trim()}',
      if (crn?.trim().isNotEmpty ?? false) 'CRN ${crn!.trim()}',
    ];
    return r.isEmpty ? null : r.join(' · ');
  }

  factory PerfilPublico.doMapa(Map<String, dynamic> m) => PerfilPublico(
        id: m['id'] as String,
        nome: m['nome'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        cref: m['cref'] as String?,
        crn: m['crn'] as String?,
        bio: m['bio'] as String?,
        formacoes: lerFormacoes(m['formacoes']),
        whatsapp: m['whatsapp'] as String?,
      );
}

/// `profiles.formacoes` é jsonb: uma lista de textos. O banco não confere
/// o formato, então o que não for texto fica de fora.
List<String> lerFormacoes(Object? bruto) => bruto is List
    ? [for (final f in bruto) if (f is String && f.trim().isNotEmpty) f.trim()]
    : const [];

/// Um desconto que o profissional oferece aos alunos dele.
class Cupom {
  const Cupom({
    this.id,
    required this.titulo,
    this.descricao,
    this.codigo,
    this.link,
    this.indicadoId,
    this.indicadoNome,
    this.validoAte,
    this.ativo = true,
    this.ordem = 0,
  });

  final String? id;
  final String titulo;
  final String? descricao;
  final String? codigo;
  final String? link;

  /// Outro profissional do PHD que este cupom indica.
  final String? indicadoId;

  /// Só para a tela do profissional mostrar quem foi indicado; não é
  /// gravado (o nome vem do perfil, que pode mudar).
  final String? indicadoNome;
  final DateTime? validoAte;
  final bool ativo;
  final int ordem;

  bool get vencido {
    final v = validoAte;
    if (v == null) return false;
    final hoje = DateTime.now();
    return v.isBefore(DateTime(hoje.year, hoje.month, hoje.day));
  }

  factory Cupom.doMapa(Map<String, dynamic> m) => Cupom(
        id: m['id'] as String?,
        titulo: m['titulo'] as String? ?? 'Cupom',
        descricao: m['descricao'] as String?,
        codigo: m['codigo'] as String?,
        link: m['link'] as String?,
        indicadoId: m['indicado_id'] as String?,
        validoAte: DateTime.tryParse(m['valido_ate'] as String? ?? ''),
        ativo: m['ativo'] as bool? ?? true,
        ordem: (m['ordem'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> paraMapa() {
    String? t(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    final v = validoAte;
    return {
      'titulo': titulo.trim(),
      'descricao': t(descricao),
      'codigo': t(codigo),
      'link': t(link),
      'indicado_id': indicadoId,
      'valido_ate': v == null
          ? null
          : '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}',
      'ativo': ativo,
      'ordem': ordem,
    };
  }
}
