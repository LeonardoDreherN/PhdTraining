import 'package:flutter/material.dart';

import '../../core/models/feed.dart';
import '../../core/services/feed_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/widgets.dart';

/// Comentários de uma publicação.
Future<void> abrirComentarios(
  BuildContext context,
  PostFeed post, {
  required bool podeComentar,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ComentariosSheet(post: post, podeComentar: podeComentar),
  );
}

class _ComentariosSheet extends StatefulWidget {
  const _ComentariosSheet({required this.post, required this.podeComentar});

  final PostFeed post;
  final bool podeComentar;

  @override
  State<_ComentariosSheet> createState() => _ComentariosSheetState();
}

class _ComentariosSheetState extends State<_ComentariosSheet> {
  final _ctrl = TextEditingController();
  List<ComentarioFeed> _itens = const [];
  bool _carregando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final l = await FeedService.comentarios(widget.post.id);
      if (mounted) setState(() => _itens = l);
    } catch (_) {
      // Lista vazia já mostra o estado certo.
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;

    setState(() => _enviando = true);
    try {
      await FeedService.comentar(widget.post.id, texto);
      _ctrl.clear();
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não consegui comentar: $e', style: AppText.body(13.5)),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fundoTeclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: fundoTeclado),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.md),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lineStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Text('Comentários', style: AppText.title(17)),
                    const SizedBox(width: AppSpacing.sm),
                    if (_itens.isNotEmpty)
                      Text('${_itens.length}',
                          style: AppText.number(13,
                              color: AppColors.textMuted)),
                  ],
                ),
              ),
              Expanded(child: _lista(scroll)),
              if (widget.podeComentar) _campo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lista(ScrollController scroll) {
    if (_carregando) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_itens.isEmpty) {
      return const PhdEmptyState(
        icon: Icons.mode_comment_outlined,
        title: 'Nenhum comentário',
        message: 'Seja o primeiro a comentar.',
      );
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md,
      ),
      itemCount: _itens.length,
      itemBuilder: (_, i) => _linha(_itens[i]),
    );
  }

  Widget _linha(ComentarioFeed c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhdAvatar(name: c.autorNome ?? '?', imageUrl: c.autorFoto, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.autorNome ?? 'Alguém',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong(13)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(_quando(c.criadoEm),
                        style:
                            AppText.caption(10.5, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(c.texto, style: AppText.body(13.5).copyWith(height: 1.45)),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.surfaceHigh,
            surfaceTintColor: Colors.transparent,
            tooltip: 'Opções do comentário',
            shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
            icon: Icon(Icons.more_horiz_rounded,
                size: 17, color: AppColors.textMuted),
            onSelected: (v) => _acao(v, c),
            itemBuilder: (_) => [
              if (c.souAutor)
                PopupMenuItem(
                  value: 'excluir',
                  child: Text('Excluir',
                      style: AppText.body(14, color: AppColors.dangerText)),
                )
              else
                PopupMenuItem(
                  value: 'denunciar',
                  child: Text('Denunciar',
                      style: AppText.body(14, color: AppColors.dangerText)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acao(String acao, ComentarioFeed c) async {
    try {
      if (acao == 'excluir') {
        await FeedService.excluirComentario(c.id);
        await _carregar();
      } else {
        await FeedService.denunciar(comentarioId: c.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceHigh,
            content: Text('Denúncia enviada ao profissional.',
                style: AppText.body(13.5)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não deu certo: $e', style: AppText.body(13.5)),
        ),
      );
    }
  }

  Widget _campo() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: AppText.body(16),
                cursorColor: AppColors.accent,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Escreva algo...'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PhdIconButton(
              icon: Icons.send_rounded,
              tooltip: 'Enviar',
              onPressed: _enviando ? null : _enviar,
            ),
          ],
        ),
      ),
    );
  }

  String _quando(DateTime d) {
    final dif = DateTime.now().difference(d);
    if (dif.inMinutes < 1) return 'agora';
    if (dif.inHours < 1) return '${dif.inMinutes} min';
    if (dif.inDays < 1) return '${dif.inHours} h';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}';
  }
}
