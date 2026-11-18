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

/// As reações possíveis. Simples e positivas, como a especificação pede:
/// não existe o equivalente a um "não gostei" num feed de treino.
const reacoesDisponiveis = <({String valor, String rotulo, String emoji})>[
  (valor: 'forca', rotulo: 'Força', emoji: '💪'),
  (valor: 'parabens', rotulo: 'Parabéns', emoji: '👏'),
  (valor: 'inspirador', rotulo: 'Inspirador', emoji: '🔥'),
];
