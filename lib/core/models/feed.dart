import 'package:flutter/material.dart';

import 'conquista.dart';

/// O que o profissional habilitou na comunidade dele.
///
/// Tudo nasce desligado no que importa: o feed só existe depois que ele
/// liga. Um feed vazio na tela do aluno parece defeito, e nem todo
/// profissional quer rede social no produto dele.
class ConfigComunidade {
  const ConfigComunidade({
    this.feedAtivo = false,
    this.alunosPostam = true,
    this.comentarios = true,
    this.reacoes = true,
    this.conquistasAuto = true,
    this.destaquesAtivos = true,
    this.destaquesDia = 1,
    this.destaquesHora = 9,
  });

  final bool feedAtivo;
  final bool alunosPostam;
  final bool comentarios;
  final bool reacoes;
  final bool conquistasAuto;

  final bool destaquesAtivos;

  /// 1 = segunda.
  final int destaquesDia;
  final int destaquesHora;

  String get diaNome => switch (destaquesDia) {
        1 => 'segunda',
        2 => 'terça',
        3 => 'quarta',
        4 => 'quinta',
        5 => 'sexta',
        6 => 'sábado',
        _ => 'domingo',
      };

  factory ConfigComunidade.doMapa(Map<String, dynamic> m) => ConfigComunidade(
        feedAtivo: m['feed_ativo'] as bool? ?? false,
        alunosPostam: m['alunos_postam'] as bool? ?? true,
        comentarios: m['comentarios'] as bool? ?? true,
        reacoes: m['reacoes'] as bool? ?? true,
        conquistasAuto: m['conquistas_auto'] as bool? ?? true,
        destaquesAtivos: m['destaques_ativos'] as bool? ?? true,
        destaquesDia: (m['destaques_dia'] as num?)?.toInt() ?? 1,
        destaquesHora: (m['destaques_hora'] as num?)?.toInt() ?? 9,
      );

  Map<String, dynamic> paraMapa() => {
        'feed_ativo': feedAtivo,
        'alunos_postam': alunosPostam,
        'comentarios': comentarios,
        'reacoes': reacoes,
        'conquistas_auto': conquistasAuto,
        'destaques_ativos': destaquesAtivos,
        'destaques_dia': destaquesDia,
        'destaques_hora': destaquesHora,
      };

  ConfigComunidade copiaCom({
    bool? feedAtivo,
    bool? alunosPostam,
    bool? comentarios,
    bool? reacoes,
    bool? conquistasAuto,
    bool? destaquesAtivos,
    int? destaquesDia,
    int? destaquesHora,
  }) =>
      ConfigComunidade(
        feedAtivo: feedAtivo ?? this.feedAtivo,
        alunosPostam: alunosPostam ?? this.alunosPostam,
        comentarios: comentarios ?? this.comentarios,
        reacoes: reacoes ?? this.reacoes,
        conquistasAuto: conquistasAuto ?? this.conquistasAuto,
        destaquesAtivos: destaquesAtivos ?? this.destaquesAtivos,
        destaquesDia: destaquesDia ?? this.destaquesDia,
        destaquesHora: destaquesHora ?? this.destaquesHora,
      );
}

enum TipoPost { aviso, aluno, conquista, destaque }

/// Uma publicação do feed.
///
/// Repare no que NÃO existe aqui: peso, medida, percentual de gordura,
/// foto de evolução, dado de plano alimentar. A conquista guarda só o
/// código — "50 treinos" — e o texto é montado na leitura, a partir do
/// catálogo. A restrição mora na forma da classe, não numa regra que
/// alguém precisa lembrar de seguir.
class PostFeed {
  const PostFeed({
    required this.id,
    required this.tipo,
    required this.criadoEm,
    this.autorNome,
    this.autorFoto,
    this.alunoNome,
    this.alunoFoto,
    this.texto,
    this.midiaUrl,
    this.conquistaCodigo,
    this.destaqueSemana,
    this.destaqueTipo,
    this.fixado = false,
    this.oculto = false,
    this.reacoes = 0,
    this.comentarios = 0,
    this.minhaReacao,
    this.souAutor = false,
  });

  final String id;
  final TipoPost tipo;
  final DateTime criadoEm;

  final String? autorNome;
  final String? autorFoto;

  /// De quem é a conquista ou o destaque.
  final String? alunoNome;
  final String? alunoFoto;

  final String? texto;
  final String? midiaUrl;

  final String? conquistaCodigo;
  final DateTime? destaqueSemana;
  final String? destaqueTipo;

  final bool fixado;
  final bool oculto;

  final int reacoes;
  final int comentarios;
  final String? minhaReacao;
  final bool souAutor;

  bool get ehOficial => tipo == TipoPost.aviso;
  bool get ehAutomatico =>
      tipo == TipoPost.conquista || tipo == TipoPost.destaque;

  Conquista? get conquista =>
      conquistaCodigo == null ? null : Conquista.porCodigo(conquistaCodigo!);

  /// O texto do cartão automático, montado na leitura.
  ///
  /// "Pedro conquistou 50 treinos" — o nome e o rótulo da medalha, nada
  /// mais. Nenhum número de saúde entra aqui porque nenhum foi gravado.
  String? get textoAutomatico {
    final nome = (alunoNome ?? '').trim().split(' ').first;
    if (tipo == TipoPost.conquista) {
      final c = conquista;
      if (c == null) return null;
      return '$nome conquistou "${c.nome}".';
    }
    if (tipo == TipoPost.destaque) {
      final area = destaqueTipo == 'nutricao' ? 'na nutrição' : 'nos treinos';
      return '$nome foi destaque $area na semana.';
    }
    return null;
  }

  factory PostFeed.doMapa(Map<String, dynamic> m, {String? meuId}) {
    final autor = m['autor'] as Map<String, dynamic>?;
    final aluno = m['alunos'] as Map<String, dynamic>?;
    final minhas = (m['feed_reacoes'] as List?) ?? const [];

    return PostFeed(
      id: m['id'] as String,
      tipo: switch (m['tipo'] as String?) {
        'aviso' => TipoPost.aviso,
        'conquista' => TipoPost.conquista,
        'destaque' => TipoPost.destaque,
        _ => TipoPost.aluno,
      },
      criadoEm:
          DateTime.tryParse(m['criado_em'] as String? ?? '') ?? DateTime.now(),
      autorNome: autor?['nome'] as String?,
      autorFoto: autor?['avatar_url'] as String?,
      alunoNome: aluno?['nome'] as String?,
      alunoFoto: aluno?['foto_url'] as String?,
      texto: m['texto'] as String?,
      midiaUrl: m['midia_url'] as String?,
      conquistaCodigo: m['conquista_codigo'] as String?,
      destaqueSemana: DateTime.tryParse(m['destaque_semana'] as String? ?? ''),
      destaqueTipo: m['destaque_tipo'] as String?,
      fixado: m['fixado'] as bool? ?? false,
      oculto: m['oculto'] as bool? ?? false,
      reacoes: minhas.length,
      comentarios: (m['comentarios_contagem'] as num?)?.toInt() ?? 0,
      minhaReacao: () {
        for (final r in minhas) {
          if (r is Map && r['usuario_id'] == meuId) return r['tipo'] as String?;
        }
        return null;
      }(),
      souAutor: meuId != null && m['autor_id'] == meuId,
    );
  }
}

class ComentarioFeed {
  const ComentarioFeed({
    required this.id,
    required this.texto,
    required this.criadoEm,
    this.autorNome,
    this.autorFoto,
    this.souAutor = false,
  });

  final String id;
  final String texto;
  final DateTime criadoEm;
  final String? autorNome;
  final String? autorFoto;
  final bool souAutor;

  factory ComentarioFeed.doMapa(Map<String, dynamic> m, {String? meuId}) {
    final autor = m['autor'] as Map<String, dynamic>?;
    return ComentarioFeed(
      id: m['id'] as String,
      texto: m['texto'] as String? ?? '',
      criadoEm:
          DateTime.tryParse(m['criado_em'] as String? ?? '') ?? DateTime.now(),
      autorNome: autor?['nome'] as String?,
      autorFoto: autor?['avatar_url'] as String?,
      souAutor: meuId != null && m['autor_id'] == meuId,
    );
  }
}

/// Uma denúncia, do jeito que o profissional precisa ler: o conteúdo
/// junto, não só o id.
///
/// Quem denunciou NÃO aparece. Uma denúncia em que o denunciado — ou
/// qualquer um — descobre quem apertou o botão é uma denúncia que
/// ninguém vai apertar de novo. O profissional precisa julgar o
/// conteúdo, e para isso o nome de quem reportou não acrescenta nada.
class DenunciaFeed {
  const DenunciaFeed({
    required this.id,
    required this.criadoEm,
    required this.ehComentario,
    this.motivo,
    this.postId,
    this.comentarioId,
    this.texto,
    this.midiaUrl,
    this.autorConteudo,
    this.alunoId,
    this.ocultoAgora = false,
    this.resolvidaEm,
    this.resolucao,
  });

  final String id;
  final DateTime criadoEm;

  /// Denúncia de comentário ou de publicação. O banco garante que é um
  /// ou outro, nunca os dois.
  final bool ehComentario;

  final String? motivo;
  final String? postId;
  final String? comentarioId;

  /// O conteúdo denunciado, para o profissional julgar sem sair da
  /// tela. Nulo se o conteúdo já foi apagado por alguém.
  final String? texto;
  final String? midiaUrl;
  final String? autorConteudo;

  /// O aluno dono do conteúdo, quando é publicação de aluno. É por ele
  /// que o bloqueio temporário é aplicado.
  final String? alunoId;

  final bool ocultoAgora;
  final DateTime? resolvidaEm;
  final String? resolucao;

  bool get pendente => resolvidaEm == null;

  /// Nulo quando o conteúdo sumiu entre a denúncia e a leitura. A tela
  /// precisa saber: julgar o que não existe mais é impossível, e a
  /// denúncia só pode ser arquivada.
  bool get conteudoSumiu => texto == null && midiaUrl == null;

  String get resolucaoRotulo => switch (resolucao) {
        'arquivada' => 'Arquivada',
        'ocultada' => 'Ocultada do feed',
        'removida' => 'Conteúdo removido',
        _ => 'Pendente',
      };

  factory DenunciaFeed.doMapa(Map<String, dynamic> m) {
    final post = m['feed_posts'] as Map<String, dynamic>?;
    final comentario = m['feed_comentarios'] as Map<String, dynamic>?;
    final ehComentario = m['comentario_id'] != null;

    final fonte = ehComentario ? comentario : post;
    final autor = fonte?['autor'] as Map<String, dynamic>?;
    final aluno = post?['alunos'] as Map<String, dynamic>?;

    return DenunciaFeed(
      id: m['id'] as String,
      criadoEm:
          DateTime.tryParse(m['criado_em'] as String? ?? '') ?? DateTime.now(),
      ehComentario: ehComentario,
      motivo: m['motivo'] as String?,
      postId: m['post_id'] as String?,
      comentarioId: m['comentario_id'] as String?,
      texto: fonte?['texto'] as String?,
      midiaUrl: post?['midia_url'] as String?,
      autorConteudo: (autor?['nome'] ?? aluno?['nome']) as String?,
      alunoId: post?['aluno_id'] as String?,
      ocultoAgora: fonte?['oculto'] as bool? ?? false,
      resolvidaEm: DateTime.tryParse(m['resolvida_em'] as String? ?? ''),
      resolucao: m['resolucao'] as String?,
    );
  }
}

/// Um aviso da caixa do aluno.
class AvisoFeed {
  const AvisoFeed({
    required this.id,
    required this.tipo,
    required this.criadoEm,
    this.lida,
    this.postId,
    this.origemNome,
    this.origemFoto,
    this.postTexto,
    this.conquistaCodigo,
  });

  final String id;

  /// 'conquista', 'destaque', 'reacao', 'comentario' ou 'aviso'.
  final String tipo;

  final DateTime criadoEm;
  final DateTime? lida;

  final String? postId;
  final String? origemNome;
  final String? origemFoto;

  /// O começo do texto da publicação, para o aviso dizer de qual se
  /// trata sem o aluno precisar abrir.
  final String? postTexto;

  final String? conquistaCodigo;

  bool get naoLida => lida == null;

  /// O que o aviso diz.
  ///
  /// Montado na leitura, como o cartão automático do feed: a linha
  /// guarda o tipo e o vínculo, nunca uma frase pronta que envelhece
  /// quando o nome da medalha muda.
  String get texto {
    final quem = (origemNome ?? '').trim().split(' ').first;
    return switch (tipo) {
      'conquista' => switch (Conquista.porCodigo(conquistaCodigo ?? '')) {
          final c? => 'Sua conquista "${c.nome}" foi publicada na comunidade.',
          _ => 'Uma conquista sua foi publicada na comunidade.',
        },
      'destaque' => 'Você foi destaque da semana na comunidade.',
      'reacao' => quem.isEmpty
          ? 'Alguém reagiu à sua publicação.'
          : '$quem reagiu à sua publicação.',
      'comentario' => quem.isEmpty
          ? 'Alguém comentou na sua publicação.'
          : '$quem comentou na sua publicação.',
      _ => 'Novo aviso do seu profissional.',
    };
  }

  IconData get icone => switch (tipo) {
        'conquista' => Icons.emoji_events_rounded,
        'destaque' => Icons.auto_awesome_rounded,
        'reacao' => Icons.favorite_rounded,
        'comentario' => Icons.mode_comment_rounded,
        _ => Icons.campaign_rounded,
      };

  factory AvisoFeed.doMapa(Map<String, dynamic> m) {
    final origem = m['origem'] as Map<String, dynamic>?;
    final post = m['feed_posts'] as Map<String, dynamic>?;

    return AvisoFeed(
      id: m['id'] as String,
      tipo: m['tipo'] as String? ?? 'aviso',
      criadoEm:
          DateTime.tryParse(m['criado_em'] as String? ?? '') ?? DateTime.now(),
      lida: DateTime.tryParse(m['lida_em'] as String? ?? ''),
      postId: m['post_id'] as String?,
      origemNome: origem?['nome'] as String?,
      origemFoto: origem?['avatar_url'] as String?,
      postTexto: post?['texto'] as String?,
      conquistaCodigo: post?['conquista_codigo'] as String?,
    );
  }
}

/// As reações possíveis. Simples e positivas, como a especificação pede:
/// não existe o equivalente a um "não gostei" num feed de treino.
const reacoesDisponiveis = <({String valor, String rotulo, String emoji})>[
  (valor: 'forca', rotulo: 'Força', emoji: '💪'),
  (valor: 'parabens', rotulo: 'Parabéns', emoji: '👏'),
  (valor: 'inspirador', rotulo: 'Inspirador', emoji: '🔥'),
];
