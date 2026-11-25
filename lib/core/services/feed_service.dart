import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/midia.dart';
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

    return _montar(linhas);
  }

  /// Monta os posts já com a mídia assinada.
  ///
  /// A assinatura acontece aqui, na leitura, e a tela recebe `midiaUrl`
  /// pronta para um `Image.network` — sem saber que o bucket é privado.
  static Future<List<PostFeed>> _montar(dynamic linhas) async {
    final lista = List<Map<String, dynamic>>.from(linhas as List);

    final urls = await assinarMidia([
      for (final l in lista)
        if (l['midia_url'] case final String c) c,
    ]).catchError((_) => <String, String>{});

    return [
      for (final l in lista)
        PostFeed.doMapa(
          {
            ...l,
            'midia_url': switch (l['midia_url']) {
              final String c => urls[c] ?? (c.startsWith('http') ? c : null),
              _ => null,
            },
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

  // ── Mídia ───────────────────────────────────────────────────

  static const _bucket = 'feed-midia';

  /// Envia a foto e devolve o CAMINHO dentro do bucket.
  ///
  /// Caminho, não URL: o bucket é privado e a URL assinada expira. Uma
  /// URL vencida gravada na linha seria inútil no dia seguinte, e a
  /// publicação ficaria com um retângulo quebrado para sempre.
  ///
  /// A pasta É a permissão. `<personal_id>/<user_id>/<arquivo>`: a
  /// primeira diz de que comunidade é a foto, e é o que a policy
  /// confere na leitura; a segunda impede sobrescrever a foto de outra
  /// pessoa.
  static Future<String> enviarMidia({
    required String personalId,
    required XFile foto,
  }) async {
    final bytes = await foto.readAsBytes();
    final nome = foto.name.isNotEmpty ? foto.name : foto.path;

    final contentType = Midia.tipoDe(nome);
    if (contentType == null || !contentType.startsWith('image/')) {
      throw Exception(Midia.recusa(nome, video: false));
    }

    final caminho = '$personalId/$_uid/'
        '${DateTime.now().millisecondsSinceEpoch}.${Midia.extensaoDe(nome)}';

    await _db.storage.from(_bucket).uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );

    return caminho;
  }

  /// Assina os caminhos de mídia de uma leva de posts.
  ///
  /// Numa chamada só: uma assinatura por publicação deixaria o feed
  /// esperando trinta idas ao servidor para desenhar a primeira tela.
  static Future<Map<String, String>> assinarMidia(List<String> caminhos) async {
    final pendentes =
        caminhos.where((c) => c.isNotEmpty && !c.startsWith('http')).toList();
    if (pendentes.isEmpty) return const {};

    // `createSignedUrlsResult` e não `createSignedUrls`: a versão antiga
    // engolia os caminhos que falharam, e uma foto apagada do bucket
    // sumia da lista sem deixar rastro. Aqui o que falhou simplesmente
    // não entra no mapa, e a publicação aparece sem imagem — que é o
    // certo quando o arquivo não existe mais.
    final assinadas =
        await _db.storage.from(_bucket).createSignedUrlsResult(pendentes, 3600);

    return {
      for (final a in assinadas)
        if (a is SignedUrlSuccess) a.path: a.signedUrl,
    };
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

  // ── Avisos ──────────────────────────────────────────────────

  /// O número do sino. Zero não desenha nada.
  static Future<int> avisosNaoLidos() async {
    final r = await _db.rpc('avisos_nao_lidos');
    return (r as num?)?.toInt() ?? 0;
  }

  /// A caixa de avisos de quem está logado.
  ///
  /// A RLS limita a quem é — não há filtro por usuário aqui, porque
  /// filtrar no cliente o que a RLS já resolve dá a ilusão de que a
  /// proteção mora no app.
  static Future<List<AvisoFeed>> avisos({int limite = 50}) async {
    final linhas = await _db
        .from('feed_notificacoes')
        .select(
          'id, tipo, criado_em, lida_em, post_id, '
          'origem:profiles!feed_notificacoes_origem_id_fkey(nome, avatar_url), '
          'feed_posts(texto, conquista_codigo)',
        )
        .order('criado_em', ascending: false)
        .limit(limite);

    return [
      for (final l in List<Map<String, dynamic>>.from(linhas))
        AvisoFeed.doMapa(l),
    ];
  }

  /// Marca tudo como lido. Devolve quantos eram.
  ///
  /// Tudo de uma vez, e não um a um ao tocar: a pessoa abriu a caixa e
  /// leu. Obrigar a tocar em cada linha para zerar o sino é trabalho
  /// que o app inventa para ela.
  static Future<int> marcarAvisosLidos() async {
    final r = await _db.rpc('marcar_avisos_lidos');
    return (r as num?)?.toInt() ?? 0;
  }

  /// As três chaves de aviso do aluno (§5: "permitir que o aluno ajuste
  /// as notificações do feed").
  static Future<({bool conquista, bool interacao, bool aviso})>
      prefsDeAviso(String alunoId) async {
    final linha = await _db
        .from('aluno_feed_prefs')
        .select('avisa_conquista, avisa_interacao, avisa_aviso')
        .eq('aluno_id', alunoId)
        .maybeSingle();

    // Sem linha, tudo ligado: a ausência significa "nunca mexeu", e o
    // padrão do banco é true.
    return (
      conquista: linha?['avisa_conquista'] as bool? ?? true,
      interacao: linha?['avisa_interacao'] as bool? ?? true,
      aviso: linha?['avisa_aviso'] as bool? ?? true,
    );
  }

  static Future<void> definirPrefsDeAviso(
    String alunoId, {
    bool? conquista,
    bool? interacao,
    bool? aviso,
  }) async {
    await _db.from('aluno_feed_prefs').upsert({
      'aluno_id': alunoId,
      if (conquista != null) 'avisa_conquista': conquista,
      if (interacao != null) 'avisa_interacao': interacao,
      if (aviso != null) 'avisa_aviso': aviso,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'aluno_id');
  }

  // ── Moderação ───────────────────────────────────────────────
  /// As publicações que o profissional tirou do feed.
  ///
  /// Até a 0033 ele não conseguia nem ver o que ocultou — a policy de
  /// leitura abria exceção só para o autor, e o autor de uma publicação
  /// de aluno é o aluno. Ocultar era apagar com outro nome.
  static Future<List<PostFeed>> postsOcultos(String personalId) async {
    final linhas = await _db
        .from('feed_posts')
        .select(_campos)
        .eq('personal_id', personalId)
        .eq('oculto', true)
        .order('criado_em', ascending: false)
        .limit(100);

    return _montar(linhas);
  }

  /// Os alunos silenciados agora. Sem isto o silêncio de sete dias não
  /// teria como ser interrompido antes da hora — e punição sem perdão é
  /// defeito, não política.
  static Future<List<({String alunoId, String nome, DateTime ate})>>
      alunosSilenciados() async {
    final linhas = await _db
        .from('aluno_feed_prefs')
        .select('aluno_id, bloqueado_ate, alunos(nome)')
        .gt('bloqueado_ate', DateTime.now().toUtc().toIso8601String())
        .order('bloqueado_ate', ascending: true);

    return [
      for (final l in List<Map<String, dynamic>>.from(linhas))
        (
          alunoId: l['aluno_id'] as String,
          nome: (l['alunos'] as Map?)?['nome'] as String? ?? 'Aluno',
          ate: DateTime.tryParse(l['bloqueado_ate'] as String? ?? '') ??
              DateTime.now(),
        ),
    ];
  }


  /// Quantas denúncias esperam o profissional. Zero some da tela.
  static Future<int> denunciasPendentes(String personalId) async {
    final r = await _db
        .rpc('denuncias_pendentes', params: {'p_personal_id': personalId});
    return (r as num?)?.toInt() ?? 0;
  }

  /// As denúncias do feed, com o conteúdo junto.
  ///
  /// A RLS já limita ao que é do profissional — a 0029 dá leitura ao
  /// dono do post e a quem denunciou, e nada mais. Por isso aqui não há
  /// filtro por `personal_id`: filtrar no cliente o que a RLS já
  /// resolve dá a ilusão de que a proteção mora aqui.
  ///
  /// Quem denunciou não é lido de propósito: o profissional julga o
  /// conteúdo, e o nome de quem apertou o botão não entra nisso.
  static Future<List<DenunciaFeed>> denuncias({bool pendentes = true}) async {
    var q = _db.from('feed_denuncias').select(
          'id, motivo, criado_em, resolvida_em, resolucao, '
          'post_id, comentario_id, '
          'feed_posts(id, texto, midia_url, oculto, aluno_id, '
          'autor:profiles!feed_posts_autor_id_fkey(nome), alunos(nome)), '
          'feed_comentarios(id, texto, oculto, '
          'autor:profiles!feed_comentarios_autor_id_fkey(nome))',
        );

    if (pendentes) q = q.isFilter('resolvida_em', null);

    final linhas = await q.order('criado_em', ascending: false).limit(100);
    return [
      for (final l in List<Map<String, dynamic>>.from(linhas))
        DenunciaFeed.doMapa(l),
    ];
  }

  /// Marca o desfecho. `arquivada`, `ocultada` ou `removida`.
  ///
  /// Separada das ações sobre o conteúdo porque são decisões
  /// diferentes: ocultar o post é moderação, encerrar a denúncia é
  /// administração. Encerrar sem agir é um desfecho legítimo — a maior
  /// parte das denúncias de qualquer comunidade é improcedente.
  static Future<void> resolverDenuncia(String id, String resolucao) async {
    await _db.from('feed_denuncias').update({
      'resolvida_em': DateTime.now().toUtc().toIso8601String(),
      'resolucao': resolucao,
      'resolvida_por': _uid,
    }).eq('id', id);
  }

  /// Tira o comentário do feed sem apagar. A publicação já tinha
  /// `ocultar`; o comentário não tinha, e a moderação precisa dos dois.
  static Future<void> ocultarComentario(String id, {bool oculto = true}) async {
    await _db.from('feed_comentarios').update({'oculto': oculto}).eq('id', id);
  }

  /// Gera os destaques da semana na hora. O agendado roda sozinho; isto
  /// é para o profissional ver antes, ou refazer.
  static Future<int> gerarDestaques(String personalId) async {
    final r = await _db
        .rpc('gerar_destaques', params: {'p_personal_id': personalId});
    return (r as num?)?.toInt() ?? 0;
  }
}
