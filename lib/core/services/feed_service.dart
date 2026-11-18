import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/feed.dart';

/// O feed da comunidade.
///
/// Quem decide o que pode ser publicado é a RLS do 0029 — este serviço
/// não confere permissão, pede. Conferir aqui daria a ilusão de controle
/// num lugar onde o controle não mora.
class FeedService {
  static final _db = Supabase.instance.client;
  static String? get _uid => _db.auth.currentUser?.id;

  static const _campos =
      '*, autor:profiles!feed_posts_autor_id_fkey(nome, avatar_url), '
      'alunos(nome, foto_url), '
      'feed_reacoes(usuario_id, tipo), '
      'feed_comentarios(count)';

  // ── Configuração ────────────────────────────────────────────

  static Future<ConfigComunidade> config(String personalId) async {
    final linha = await _db
        .from('comunidade_config')
        .select()
        .eq('personal_id', personalId)
        .maybeSingle();
    return linha == null
        ? const ConfigComunidade()
        : ConfigComunidade.doMapa(linha);
  }

  static Future<void> salvarConfig(ConfigComunidade c) async {
    await _db.from('comunidade_config').upsert({
      'personal_id': _uid,
      ...c.paraMapa(),
      'atualizado_em': DateTime.now().toIso8601String(),
    }, onConflict: 'personal_id');
  }

  // ── Consentimento do aluno ──────────────────────────────────

  /// `false` enquanto o aluno não disser que sim. É opt-in de verdade:
  /// sem linha na tabela, nada é publicado.
  static Future<bool> compartilhaConquistas(String alunoId) async {
    final linha = await _db
        .from('aluno_feed_prefs')
        .select('compartilha_conquistas')
        .eq('aluno_id', alunoId)
        .maybeSingle();
    return linha?['compartilha_conquistas'] as bool? ?? false;
  }

  static Future<void> definirCompartilhamento(String alunoId, bool valor) async {
    await _db.from('aluno_feed_prefs').upsert({
      'aluno_id': alunoId,
      'compartilha_conquistas': valor,
      'atualizado_em': DateTime.now().toIso8601String(),
    }, onConflict: 'aluno_id');

    // Ligou agora: publica o que ele já tinha. Sem isto, quem conquistou
    // antes de consentir só apareceria na próxima medalha.
    if (valor) await publicarConquistas(alunoId);
  }

  /// Bloqueia o aluno de postar por um tempo. Moderação do profissional.
  static Future<void> bloquearAluno(String alunoId, Duration por) async {
    await _db.from('aluno_feed_prefs').upsert({
      'aluno_id': alunoId,
      'bloqueado_ate': DateTime.now().add(por).toIso8601String(),
    }, onConflict: 'aluno_id');
  }

  static Future<void> desbloquearAluno(String alunoId) async {
    await _db
        .from('aluno_feed_prefs')
        .update({'bloqueado_ate': null}).eq('aluno_id', alunoId);
  }

  // ── Leitura ─────────────────────────────────────────────────

  /// O feed, com os fixados no topo.
  static Future<List<PostFeed>> posts(String personalId, {int limite = 50}) async {
    final linhas = await _db
        .from('feed_posts')
        .select(_campos)
        .eq('personal_id', personalId)
        .eq('oculto', false)
        .order('fixado', ascending: false)
        .order('criado_em', ascending: false)
        .limit(limite);

    return [
      for (final l in List<Map<String, dynamic>>.from(linhas))
        PostFeed.doMapa(
          {
            ...l,
            'comentarios_contagem':
                ((l['feed_comentarios'] as List?)?.firstOrNull
                        as Map?)?['count'] ??
                    0,
          },
          meuId: _uid,
        ),
    ];
  }

  static Future<List<ComentarioFeed>> comentarios(String postId) async {
    final linhas = await _db
        .from('feed_comentarios')
        .select('*, autor:profiles!feed_comentarios_autor_id_fkey(nome, avatar_url)')
        .eq('post_id', postId)
        .eq('oculto', false)
        .order('criado_em', ascending: true);
    return [
      for (final l in List<Map<String, dynamic>>.from(linhas))
        ComentarioFeed.doMapa(l, meuId: _uid),
    ];
  }

  // ── Publicar ────────────────────────────────────────────────

  /// Aviso do profissional.
  static Future<void> publicarAviso({
    required String texto,
    String? midiaUrl,
    bool fixado = false,
  }) async {
    await _db.from('feed_posts').insert({
      'personal_id': _uid,
      'autor_id': _uid,
      'tipo': 'aviso',
      'texto': texto.trim(),
      'midia_url': midiaUrl,
      'fixado': fixado,
    });
  }

  /// Publicação do aluno.
  static Future<void> publicarDoAluno({
    required String alunoId,
    required String personalId,
    required String texto,
    String? midiaUrl,
  }) async {
    await _db.from('feed_posts').insert({
      'personal_id': personalId,
      'autor_id': _uid,
      'aluno_id': alunoId,
      'tipo': 'aluno',
      'texto': texto.trim(),
      'midia_url': midiaUrl,
    });
  }

  /// Publica as conquistas que o aluno autorizou.
  ///
  /// As três portas — feed ativo, conquistas automáticas e consentimento
  /// do aluno — são conferidas no banco, não aqui.
  static Future<int> publicarConquistas(String alunoId) async {
    final r =
        await _db.rpc('publicar_conquistas', params: {'p_aluno_id': alunoId});
    return (r as num?)?.toInt() ?? 0;
  }

  static Future<void> editar(String postId, String texto) async {
    await _db.from('feed_posts').update({'texto': texto.trim()}).eq('id', postId);
  }

  static Future<void> excluir(String postId) async {
    await _db.from('feed_posts').delete().eq('id', postId);
  }

  /// Esconde sem apagar.
  ///
  /// É o que a especificação pede para a publicação automática: tirar do
  /// feed sem apagar a conquista do histórico do aluno. Apagar o post
  /// não apagaria a medalha, mas esconder deixa o registro de que ela
  /// chegou a ser publicada.
  static Future<void> ocultar(String postId, bool oculto) async {
    await _db.from('feed_posts').update({'oculto': oculto}).eq('id', postId);
  }

  static Future<void> fixar(String postId, bool fixado) async {
    await _db.from('feed_posts').update({'fixado': fixado}).eq('id', postId);
  }

  // ── Interações ──────────────────────────────────────────────

  static Future<void> reagir(String postId, String? tipo) async {
    if (tipo == null) {
      await _db
          .from('feed_reacoes')
          .delete()
          .eq('post_id', postId)
          .eq('usuario_id', _uid as Object);
      return;
    }
    await _db.from('feed_reacoes').upsert({
      'post_id': postId,
      'usuario_id': _uid,
      'tipo': tipo,
    }, onConflict: 'post_id,usuario_id');
  }

  static Future<void> comentar(String postId, String texto) async {
    await _db.from('feed_comentarios').insert({
      'post_id': postId,
      'autor_id': _uid,
      'texto': texto.trim(),
    });
  }

  static Future<void> excluirComentario(String id) async {
    await _db.from('feed_comentarios').delete().eq('id', id);
  }

  /// Denuncia conteúdo. Um dos dois ids, nunca os dois.
  static Future<void> denunciar({
    String? postId,
    String? comentarioId,
    String? motivo,
  }) async {
    await _db.from('feed_denuncias').insert({
      if (postId != null) 'post_id': postId,
      if (comentarioId != null) 'comentario_id': comentarioId,
      'autor_id': _uid,
      'motivo': motivo,
    });
  }

  /// Gera os destaques da semana na hora. O agendado roda sozinho; isto
  /// é para o profissional ver antes, ou refazer.
  static Future<int> gerarDestaques(String personalId) async {
    final r = await _db
        .rpc('gerar_destaques', params: {'p_personal_id': personalId});
    return (r as num?)?.toInt() ?? 0;
  }
}
