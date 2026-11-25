import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/feed.dart';
import '../../core/services/feed_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/widgets.dart';
import 'comentarios_sheet.dart';

/// O feed da comunidade.
///
/// A mesma tela serve ao profissional e ao aluno: o que muda é o que
/// cada um pode fazer, e isso já é decidido pela RLS. Duas telas quase
/// iguais divergiriam na primeira mudança.
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.personalId,
    this.alunoId,
    this.souProfissional = false,
  });

  final String personalId;

  /// Nulo quando quem abre é o profissional.
  final String? alunoId;
  final bool souProfissional;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  ConfigComunidade _config = const ConfigComunidade();
  List<PostFeed> _posts = const [];
  bool _carregando = true;
  Object? _erro;
  final _ocupado = <String>{};

  /// Denúncias esperando o profissional. Só ele vê este número.
  int _denuncias = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = _posts.isEmpty;
      _erro = null;
    });
    try {
      final config = await FeedService.config(widget.personalId);
      if (!mounted) return;
      setState(() => _config = config);

      // Feed desligado não carrega post nenhum: a tela avisa e pronto.
      if (!config.feedAtivo) {
        setState(() => _posts = const []);
        return;
      }

      // Publica o que o aluno autorizou antes de ler, senão a conquista
      // de hoje só apareceria amanhã.
      if (widget.alunoId != null) {
        await FeedService.publicarConquistas(widget.alunoId!);
      }

      final posts = await FeedService.posts(widget.personalId);
      if (mounted) setState(() => _posts = posts);

      // O aviso de moderação. Num `try` próprio e depois dos posts: o
      // feed não pode deixar de abrir porque a contagem falhou, e sem a
      // 0032 esta função ainda não existe.
      if (widget.souProfissional) {
        try {
          final n = await FeedService.denunciasPendentes(widget.personalId);
          if (mounted) setState(() => _denuncias = n);
        } catch (_) {
          // Sem número, sem aviso. O botão continua no perfil.
        }
      }
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Comunidade', style: AppText.title(16)),
        actions: [
          // Só aparece quando há o que moderar. Um ícone de denúncia
          // sempre aceso vira parte do cenário e para de ser aviso.
          if (widget.souProfissional && _denuncias > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: TextButton.icon(
                onPressed: () async {
                  await context.push('/comunidade/denuncias',
                      extra: {'personalId': widget.personalId});
                  if (mounted) await _carregar();
                },
                icon: Icon(Icons.flag_rounded,
                    size: 17, color: AppColors.dangerText),
                label: Text('$_denuncias',
                    style:
                        AppText.bodyStrong(13, color: AppColors.dangerText)),
              ),
            ),
        ],
      ),
      body: _corpo(),
      floatingActionButton: _podePublicar
          ? FloatingActionButton(
              backgroundColor: AppColors.accent,
              onPressed: _publicar,
              child: Icon(Icons.add_rounded, color: AppColors.onAccent),
            )
          : null,
    );
  }

  bool get _podePublicar {
    if (!_config.feedAtivo) return false;
    if (widget.souProfissional) return true;
    return _config.alunosPostam && widget.alunoId != null;
  }

  Widget _corpo() {
    if (_carregando) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: '$_erro',
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }

    if (!_config.feedAtivo) {
      return PhdEmptyState(
        icon: Icons.groups_outlined,
        title: 'Comunidade desligada',
        message: widget.souProfissional
            ? 'Ligue a comunidade no seu perfil para publicar avisos e '
                'reconhecer quem está constante.'
            : 'Seu profissional ainda não abriu a comunidade.',
      );
    }

    if (_posts.isEmpty) {
      return PhdEmptyState(
        icon: Icons.forum_outlined,
        title: 'Nada por aqui ainda',
        message: widget.souProfissional
            ? 'Publique um aviso para começar.'
            : 'As conquistas e os avisos aparecem aqui.',
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _carregar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge * 2,
        ),
        itemCount: _posts.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _cartao(_posts[i]),
        ),
      ),
    );
  }

  // ── Cartão ──────────────────────────────────────────────────

  Widget _cartao(PostFeed p) {
    return PhdCard(
      accentBar: p.fixado ? AppColors.accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cabecalho(p),
          if (p.ehAutomatico) ...[
            const SizedBox(height: AppSpacing.md),
            _automatico(p),
          ] else if ((p.texto?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.md),
            Text(p.texto!.trim(),
                style: AppText.body(14).copyWith(height: 1.5)),
          ],
          if (p.midiaUrl != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadius.rMd,
              child: Image.network(
                p.midiaUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _acoes(p),
        ],
      ),
    );
  }

  Widget _cabecalho(PostFeed p) {
    final nome = p.ehAutomatico
        ? (p.alunoNome ?? 'Aluno')
        : (p.autorNome ?? 'Alguém');
    final foto = p.ehAutomatico ? p.alunoFoto : p.autorFoto;

    return Row(
      children: [
        PhdAvatar(name: nome, imageUrl: foto, size: 36),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong(13.5)),
                  ),
                  // O aviso do profissional é visualmente oficial: o
                  // aluno precisa distinguir orientação de conversa.
                  if (p.ehOficial) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.verified_rounded,
                        size: 14, color: AppColors.accent),
                  ],
                ],
              ),
              const SizedBox(height: 1),
              Text(_quando(p.criadoEm),
                  style: AppText.caption(11, color: AppColors.textMuted)),
            ],
          ),
        ),
        if (p.fixado)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Icon(Icons.push_pin_rounded,
                size: 15, color: AppColors.accent),
          ),
        _menu(p),
      ],
    );
  }

  Widget _automatico(PostFeed p) {
    final texto = p.textoAutomatico;
    if (texto == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadius.rMd,
        color: AppColors.tint(AppColors.accent),
      ),
      child: Row(
        children: [
          Icon(
            p.tipo == TipoPost.destaque
                ? Icons.workspace_premium_rounded
                : (p.conquista?.icone ?? Icons.emoji_events_rounded),
            size: 26,
            color: AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto, style: AppText.bodyStrong(14)),
                if (p.destaqueSemana != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Semana de ${_data(p.destaqueSemana!)}',
                    style: AppText.caption(11, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _acoes(PostFeed p) {
    final ocupado = _ocupado.contains(p.id);
    return Row(
      children: [
        if (_config.reacoes) ...[
          for (final r in reacoesDisponiveis)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _botaoReacao(p, r, ocupado),
            ),
          if (p.reacoes > 0)
            Text('${p.reacoes}',
                style: AppText.number(12, color: AppColors.textSecondary)),
        ],
        const Spacer(),
        if (_config.comentarios)
          TextButton.icon(
            onPressed: () => _abrirComentarios(p),
            icon: Icon(Icons.mode_comment_outlined,
                size: 16, color: AppColors.textSecondary),
            label: Text(
              p.comentarios == 0 ? 'Comentar' : '${p.comentarios}',
              style: AppText.caption(12, color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _botaoReacao(
    PostFeed p,
    ({String valor, String rotulo, String emoji}) r,
    bool ocupado,
  ) {
    final minha = p.minhaReacao == r.valor;
    return InkWell(
      borderRadius: AppRadius.rPill,
      onTap: ocupado ? null : () => _reagir(p, minha ? null : r.valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: AppRadius.rPill,
          color: minha ? AppColors.tint(AppColors.accent) : Colors.transparent,
          border: Border.all(
            color: minha ? AppColors.accent : AppColors.line,
          ),
        ),
        child: Text(r.emoji, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  // ── Menu de moderação ───────────────────────────────────────

  Widget _menu(PostFeed p) {
    final souDono = widget.souProfissional;
    final meuPost = p.souAutor;

    // Quem não pode fazer nada não ganha botão que não faz nada.
    if (!souDono && !meuPost && !_config.feedAtivo) {
      return const SizedBox.shrink();
    }

    return PopupMenuButton<String>(
      color: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      tooltip: 'Opções da publicação',
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      icon: Icon(Icons.more_horiz_rounded, size: 19, color: AppColors.textMuted),
      onSelected: (v) => _acaoMenu(v, p),
      itemBuilder: (_) => [
        if (souDono)
          PopupMenuItem(
            value: 'fixar',
            child: Text(p.fixado ? 'Desafixar' : 'Fixar no topo',
                style: AppText.body(14)),
          ),
        if (souDono)
          PopupMenuItem(
            value: 'ocultar',
            // Esconder, e não apagar: a conquista continua no histórico
            // do aluno, como a especificação pede.
            child: Text('Tirar do feed', style: AppText.body(14)),
          ),
        // Editar só o que é texto escrito por alguém. Conquista e
        // destaque são montados na leitura, a partir do catálogo: não
        // existe texto guardado para editar.
        if (meuPost && !p.ehAutomatico)
          PopupMenuItem(
            value: 'editar',
            child: Text('Editar', style: AppText.body(14)),
          ),
        if (meuPost && !p.ehAutomatico)
          PopupMenuItem(
            value: 'excluir',
            child: Text('Excluir',
                style: AppText.body(14, color: AppColors.dangerText)),
          ),
        if (!meuPost)
          PopupMenuItem(
            value: 'denunciar',
            child: Text('Denunciar',
                style: AppText.body(14, color: AppColors.dangerText)),
          ),
      ],
    );
  }

  Future<void> _acaoMenu(String acao, PostFeed p) async {
    try {
      switch (acao) {
        case 'fixar':
          await FeedService.fixar(p.id, !p.fixado);
        case 'ocultar':
          await FeedService.ocultar(p.id, true);
          if (mounted) {
            // Sem este aviso, o post simplesmente some e não há pista
            // de que dá para trazer de volta.
            _avisar('Tirado do feed. Dá para devolver em Denúncias › Ocultas.');
          }
        case 'editar':
          final novo = await _editarTexto(p.texto ?? '');
          if (novo == null) return;
          await FeedService.editar(p.id, novo);
        case 'excluir':
          final ok = await _confirmar(
            'Excluir publicação?',
            'Ela sai do feed para todo mundo.',
          );
          if (!ok) return;
          await FeedService.excluir(p.id);
        case 'denunciar':
          await FeedService.denunciar(postId: p.id);
          if (mounted) _avisar('Denúncia enviada ao profissional.');
          return;
      }
      await _carregar();
    } catch (e) {
      if (mounted) _avisar('Não deu certo: $e');
    }
  }

  // ── Ações ───────────────────────────────────────────────────

  Future<void> _reagir(PostFeed p, String? tipo) async {
    setState(() => _ocupado.add(p.id));
    try {
      await FeedService.reagir(p.id, tipo);
      await _carregar();
    } catch (e) {
      if (mounted) _avisar('Não deu certo: $e');
    } finally {
      if (mounted) setState(() => _ocupado.remove(p.id));
    }
  }

  Future<void> _abrirComentarios(PostFeed p) async {
    await abrirComentarios(context, p, podeComentar: _config.comentarios);
    if (mounted) await _carregar();
  }

  /// Devolve o texto novo, ou nulo se desistiu. Vazio também é nulo:
  /// esvaziar uma publicação é apagá-la pela metade, e para apagar
  /// existe "Excluir".
  Future<String?> _editarTexto(String atual) async {
    final ctrl = TextEditingController(text: atual);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Editar publicação', style: AppText.title(17)),
        content: SizedBox(
          width: 420,
          child: PhdField(
            label: 'Texto',
            controller: ctrl,
            maxLines: 5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style:
                    AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Salvar',
                style: AppText.bodyStrong(13.5, color: AppColors.accent)),
          ),
        ],
      ),
    );

    final texto = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || texto.isEmpty || texto == atual.trim()) return null;
    return texto;
  }

  Future<void> _publicar() async {
    final ctrl = TextEditingController();
    var fixar = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: Text(
            widget.souProfissional ? 'Novo aviso' : 'Publicar',
            style: AppText.title(17),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PhdField(
                  label: widget.souProfissional ? 'Aviso' : 'O que quer contar?',
                  controller: ctrl,
                  maxLines: 4,
                  hint: widget.souProfissional
                      ? 'Comunicado, orientação, novidade...'
                      : 'Compartilhe com a comunidade',
                ),
                if (widget.souProfissional) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Switch(
                        value: fixar,
                        activeThumbColor: AppColors.accent,
                        onChanged: (v) => setLocal(() => fixar = v),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text('Fixar no topo',
                            style: AppText.body(13.5)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: AppText.bodyStrong(13.5,
                      color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Publicar',
                  style: AppText.bodyStrong(13.5, color: AppColors.accent)),
            ),
          ],
        ),
      ),
    );

    final texto = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || texto.isEmpty) return;

    try {
      if (widget.souProfissional) {
        await FeedService.publicarAviso(texto: texto, fixado: fixar);
      } else {
        await FeedService.publicarDoAluno(
          alunoId: widget.alunoId!,
          personalId: widget.personalId,
          texto: texto,
        );
      }
      await _carregar();
    } catch (e) {
      if (mounted) _avisar('Não consegui publicar: $e');
    }
  }

  // ── Auxiliares ──────────────────────────────────────────────

  Future<bool> _confirmar(String titulo, String texto) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(titulo, style: AppText.title(17)),
        content: Text(texto,
            style: AppText.body(13.5, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style:
                    AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir',
                style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        content: Text(texto, style: AppText.body(13.5)),
      ),
    );
  }

  String _data(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  String _quando(DateTime d) {
    final dif = DateTime.now().difference(d);
    if (dif.inMinutes < 1) return 'agora';
    if (dif.inHours < 1) return '${dif.inMinutes} min';
    if (dif.inDays < 1) return '${dif.inHours} h';
    if (dif.inDays < 7) return '${dif.inDays} d';
    return '${_data(d)}/${d.year}';
  }
}
