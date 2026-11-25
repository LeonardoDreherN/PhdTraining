import 'package:flutter/material.dart';

import '../../core/models/feed.dart';
import '../../core/services/feed_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/datas.dart';
import '../../core/widgets/widgets.dart';

/// O que a tela de moderação mostra de cada vez.
enum _Aba {
  pendentes('Pendentes'),
  resolvidas('Resolvidas'),
  ocultas('Ocultas'),
  silenciados('Silenciados');

  const _Aba(this.rotulo);
  final String rotulo;
}

/// As denúncias que esperam o profissional.
///
/// Até aqui elas entravam na tabela e paravam ali: o app dizia ao aluno
/// "Denúncia enviada ao profissional" e ninguém era avisado. Esta tela
/// é o outro lado dessa frase.
///
/// Quem denunciou não aparece em lugar nenhum. Uma denúncia em que o
/// denunciado descobre quem apertou o botão é uma denúncia que ninguém
/// aperta de novo — e o profissional julga o conteúdo, não a pessoa que
/// reportou.
class ModeracaoScreen extends StatefulWidget {
  const ModeracaoScreen({super.key, required this.personalId});

  /// Necessário para listar as publicações ocultas: elas são buscadas
  /// pelo feed, não pela denúncia.
  final String personalId;

  @override
  State<ModeracaoScreen> createState() => _ModeracaoScreenState();
}

class _ModeracaoScreenState extends State<ModeracaoScreen> {
  List<DenunciaFeed> _itens = const [];
  List<PostFeed> _ocultos = const [];
  List<({String alunoId, String nome, DateTime ate})> _silenciados = const [];

  _Aba _aba = _Aba.pendentes;
  bool _carregando = true;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      switch (_aba) {
        case _Aba.pendentes:
        case _Aba.resolvidas:
          final l = await FeedService.denuncias(
            pendentes: _aba == _Aba.pendentes,
          );
          if (mounted) setState(() => _itens = l);
        case _Aba.ocultas:
          final l = await FeedService.postsOcultos(widget.personalId);
          if (mounted) setState(() => _ocultos = l);
        case _Aba.silenciados:
          final l = await FeedService.alunosSilenciados();
          if (mounted) setState(() => _silenciados = l);
      }
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        content: Text(texto, style: AppText.body(13.5)),
      ),
    );
  }

  // ── Decisões ────────────────────────────────────────────────

  /// Encerra sem agir. É o desfecho mais comum de qualquer comunidade:
  /// a maior parte das denúncias não procede, e não ter como dizer isso
  /// faria a lista crescer até o profissional parar de abri-la.
  Future<void> _arquivar(DenunciaFeed d) async {
    try {
      await FeedService.resolverDenuncia(d.id, 'arquivada');
      await _carregar();
    } catch (e) {
      _avisar('Não consegui arquivar: $e');
    }
  }

  Future<void> _ocultar(DenunciaFeed d) async {
    try {
      if (d.ehComentario) {
        await FeedService.ocultarComentario(d.comentarioId!);
      } else {
        await FeedService.ocultar(d.postId!, true);
      }
      await FeedService.resolverDenuncia(d.id, 'ocultada');
      await _carregar();
    } catch (e) {
      _avisar('Não consegui ocultar: $e');
    }
  }

  Future<void> _remover(DenunciaFeed d) async {
    final ok = await _confirmar(
      'Apagar o conteúdo?',
      'Isso não tem volta. Se a ideia é só tirar do feed, "Ocultar" '
          'guarda o conteúdo e deixa você voltar atrás.',
      'Apagar',
    );
    if (ok != true) return;

    try {
      // A denúncia primeiro: apagar o conteúdo leva a denúncia junto
      // (`on delete cascade`), e aí não haveria linha para marcar. O
      // desfecho ficaria perdido e a lista pareceria ter engolido o
      // caso sem registro.
      await FeedService.resolverDenuncia(d.id, 'removida');
      if (d.ehComentario) {
        await FeedService.excluirComentario(d.comentarioId!);
      } else {
        await FeedService.excluir(d.postId!);
      }
      await _carregar();
    } catch (e) {
      _avisar('Não consegui remover: $e');
    }
  }

  /// Silencia o aluno por sete dias. A publicação some junto, porque
  /// quem está sendo silenciado por um conteúdo não deveria continuar
  /// com ele no ar.
  Future<void> _bloquear(DenunciaFeed d) async {
    final ok = await _confirmar(
      'Silenciar por 7 dias?',
      'O aluno continua vendo o feed e comentando — só não publica. '
          'Passados os sete dias, volta sozinho.',
      'Silenciar',
    );
    if (ok != true) return;

    try {
      await FeedService.bloquearAluno(d.alunoId!, const Duration(days: 7));
      if (!d.ehComentario) await FeedService.ocultar(d.postId!, true);
      await FeedService.resolverDenuncia(d.id, 'ocultada');
      await _carregar();
    } catch (e) {
      _avisar('Não consegui silenciar: $e');
    }
  }

  Future<bool?> _confirmar(String titulo, String corpo, String acao) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(titulo, style: AppText.title(17)),
        content: Text(corpo,
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
            child: Text(acao,
                style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
  }

  // ── Tela ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Denúncias', style: AppText.title(16)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final a in _Aba.values) ...[
                    if (a != _Aba.values.first) const SizedBox(width: 7),
                    PhdFilterChip(
                      label: a.rotulo,
                      selected: _aba == a,
                      onTap: () {
                        if (_aba == a) return;
                        setState(() => _aba = a);
                        _carregar();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(child: _corpo()),
        ],
      ),
    );
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
    return switch (_aba) {
      _Aba.pendentes || _Aba.resolvidas => _listaDenuncias(),
      _Aba.ocultas => _listaOcultas(),
      _Aba.silenciados => _listaSilenciados(),
    };
  }

  Widget _lista(int total, Widget Function(int) item) {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge,
        ),
        itemCount: total,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) => item(i),
      ),
    );
  }

  Widget _vazio(IconData icone, String titulo, String mensagem) =>
      PhdEmptyState(icon: icone, title: titulo, message: mensagem);

  Widget _listaDenuncias() {
    if (_itens.isEmpty) {
      return _aba == _Aba.pendentes
          ? _vazio(
              Icons.verified_user_outlined,
              'Nada pendente',
              'Quando um aluno denunciar uma publicação ou um comentário, '
                  'ele aparece aqui.',
            )
          : _vazio(
              Icons.inbox_outlined,
              'Nenhuma resolvida',
              'O que você arquivar, ocultar ou apagar fica guardado aqui.',
            );
    }
    return _lista(_itens.length, (i) => _cartao(_itens[i]));
  }

  // ── Ocultas ─────────────────────────────────────────────────

  Widget _listaOcultas() {
    if (_ocultos.isEmpty) {
      return _vazio(
        Icons.visibility_off_outlined,
        'Nada oculto',
        'O que você tirar do feed fica aqui, e daqui você pode devolver.',
      );
    }
    return _lista(_ocultos.length, (i) => _cartaoOculto(_ocultos[i]));
  }

  Widget _cartaoOculto(PostFeed p) {
    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_off_outlined,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(p.alunoNome ?? p.autorNome ?? 'Publicação',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong(13.5)),
              ),
              Text(Datas.curta(p.criadoEm),
                  style: AppText.caption(10.5, color: AppColors.textMuted)),
            ],
          ),
          if ((p.texto ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppRadius.rMd,
              ),
              child: Text(p.texto!.trim(),
                  style: AppText.body(13.5).copyWith(height: 1.45)),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PhdButton(
                label: 'Devolver ao feed',
                size: PhdButtonSize.small,
                variant: PhdButtonVariant.secondary,
                expand: false,
                onPressed: () async {
                  try {
                    await FeedService.ocultar(p.id, false);
                    await _carregar();
                  } catch (e) {
                    _avisar('Não consegui devolver: $e');
                  }
                },
              ),
              PhdButton(
                label: 'Apagar de vez',
                size: PhdButtonSize.small,
                variant: PhdButtonVariant.danger,
                expand: false,
                onPressed: () async {
                  final ok = await _confirmar(
                    'Apagar a publicação?',
                    'Isso não tem volta. Oculta, ela continua guardada e '
                        'você pode devolver quando quiser.',
                    'Apagar',
                  );
                  if (ok != true) return;
                  try {
                    await FeedService.excluir(p.id);
                    await _carregar();
                  } catch (e) {
                    _avisar('Não consegui apagar: $e');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Silenciados ─────────────────────────────────────────────

  Widget _listaSilenciados() {
    if (_silenciados.isEmpty) {
      return _vazio(
        Icons.volume_up_outlined,
        'Ninguém silenciado',
        'Todo mundo pode publicar na sua comunidade agora.',
      );
    }
    return _lista(_silenciados.length, (i) => _cartaoSilenciado(_silenciados[i]));
  }

  Widget _cartaoSilenciado(({String alunoId, String nome, DateTime ate}) s) {
    final dias = s.ate.difference(DateTime.now()).inDays;

    return PhdCard(
      child: Row(
        children: [
          PhdAvatar(name: s.nome, size: 38),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.nome, style: AppText.bodyStrong(13.5)),
                const SizedBox(height: 2),
                Text(
                  dias <= 0
                      ? 'Volta a publicar hoje'
                      : 'Volta em $dias ${dias == 1 ? 'dia' : 'dias'} '
                          '· ${Datas.curta(s.ate)}',
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PhdButton(
            label: 'Liberar',
            size: PhdButtonSize.small,
            variant: PhdButtonVariant.secondary,
            expand: false,
            onPressed: () async {
              try {
                await FeedService.desbloquearAluno(s.alunoId);
                await _carregar();
              } catch (e) {
                _avisar('Não consegui liberar: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _cartao(DenunciaFeed d) {
    return PhdCard(
      accentBar: d.pendente ? AppColors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                d.ehComentario
                    ? Icons.mode_comment_outlined
                    : Icons.article_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  d.ehComentario ? 'Comentário' : 'Publicação',
                  style: AppText.caption(12),
                ),
              ),
              Text(Datas.curta(d.criadoEm),
                  style: AppText.caption(10.5, color: AppColors.textMuted)),
            ],
          ),

          if (d.autorConteudo != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('De ${d.autorConteudo}', style: AppText.bodyStrong(13.5)),
          ],

          const SizedBox(height: AppSpacing.md),
          _conteudo(d),

          if ((d.motivo ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('MOTIVO INFORMADO', style: AppText.label()),
            const SizedBox(height: 3),
            Text(d.motivo!.trim(), style: AppText.body(13)),
          ],

          if (!d.pendente) ...[
            const SizedBox(height: AppSpacing.md),
            PhdStatusChip(
              label: d.resolucaoRotulo,
              tone: d.resolucao == 'arquivada'
                  ? PhdTone.neutral
                  : PhdTone.success,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            _acoes(d),
          ],
        ],
      ),
    );
  }

  Widget _conteudo(DenunciaFeed d) {
    if (d.conteudoSumiu) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: AppRadius.rMd,
        ),
        child: Text(
          // Sem isto a tela mostraria um retângulo vazio, e o
          // profissional ficaria tentando entender o que julgar.
          'O conteúdo já não existe — foi apagado depois da denúncia.',
          style: AppText.caption(12, color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((d.texto ?? '').trim().isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: AppRadius.rMd,
            ),
            child: Text(d.texto!.trim(),
                style: AppText.body(13.5).copyWith(height: 1.45)),
          ),
        if (d.midiaUrl != null) ...[
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: AppRadius.rMd,
            child: Image.network(
              d.midiaUrl!,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
        if (d.ocultoAgora) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Já está oculto do feed.',
              style: AppText.caption(11.5, color: AppColors.textMuted)),
        ],
      ],
    );
  }

  Widget _acoes(DenunciaFeed d) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        PhdButton(
          label: 'Arquivar',
          size: PhdButtonSize.small,
          variant: PhdButtonVariant.secondary,
          expand: false,
          onPressed: () => _arquivar(d),
        ),
        if (!d.conteudoSumiu && !d.ocultoAgora)
          PhdButton(
            label: 'Ocultar',
            size: PhdButtonSize.small,
            variant: PhdButtonVariant.ghost,
            expand: false,
            onPressed: () => _ocultar(d),
          ),
        if (!d.conteudoSumiu)
          PhdButton(
            label: 'Apagar',
            size: PhdButtonSize.small,
            variant: PhdButtonVariant.danger,
            expand: false,
            onPressed: () => _remover(d),
          ),
        // Só para publicação de aluno: o bloqueio age sobre o aluno, e
        // comentário não diz de que aluno é — o autor pode ser o próprio
        // profissional ou alguém da equipe.
        if (!d.ehComentario && d.alunoId != null)
          PhdButton(
            label: 'Silenciar 7 dias',
            size: PhdButtonSize.small,
            variant: PhdButtonVariant.danger,
            expand: false,
            onPressed: () => _bloquear(d),
          ),
      ],
    );
  }
}
