import 'package:flutter/material.dart';

import '../../core/models/feed.dart';
import '../../core/services/feed_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/datas.dart';
import '../../core/widgets/widgets.dart';

/// A caixa de avisos do feed.
///
/// O §5 da especificação pede avisar o aluno quando uma conquista dele
/// for publicada, quando interagirem com a publicação dele e quando o
/// profissional publicar um aviso importante. É esta tela.
///
/// Os avisos são escritos por gatilhos no banco — o app lê e marca como
/// lido, nunca escreve. Um aviso que o app pudesse inserir seria um
/// aviso que qualquer um escreve na caixa de outra pessoa.
class AvisosScreen extends StatefulWidget {
  const AvisosScreen({super.key, this.alunoId});

  /// Presente quando quem abre é aluno. O profissional também recebe
  /// avisos (interação nos avisos dele), mas não tem preferências para
  /// ajustar — elas são do aluno.
  final String? alunoId;

  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> {
  List<AvisoFeed> _itens = const [];
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
      final l = await FeedService.avisos();
      if (mounted) setState(() => _itens = l);

      // Marca lido ao abrir, não ao tocar em cada linha: a pessoa abriu
      // a caixa e leu. Obrigar a tocar em cada uma para zerar o sino é
      // trabalho que o app inventa para ela.
      //
      // A lista na tela mantém o destaque de "não lida" desta vez — é
      // o que mostra o que chegou desde a última visita. Na próxima
      // abertura, já estarão apagadas.
      if (l.any((a) => a.naoLida)) {
        await FeedService.marcarAvisosLidos();
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
        title: Text('Avisos', style: AppText.title(16)),
        actions: [
          if (widget.alunoId != null)
            IconButton(
              tooltip: 'O que me avisar',
              icon: Icon(Icons.tune_rounded, color: AppColors.textPrimary),
              onPressed: _abrirPreferencias,
            ),
        ],
      ),
      body: _corpo(),
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
    if (_itens.isEmpty) {
      return const PhdEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'Nenhum aviso',
        message: 'Aqui chegam suas conquistas publicadas, as reações e os '
            'comentários nas suas publicações, e os avisos fixados pelo '
            'seu profissional.',
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge,
        ),
        itemCount: _itens.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _linha(_itens[i]),
      ),
    );
  }

  Widget _linha(AvisoFeed a) {
    return PhdCard(
      accentBar: a.naoLida ? AppColors.accent : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.accent),
              shape: BoxShape.circle,
            ),
            child: Icon(a.icone, size: 19, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.texto,
                    style: a.naoLida
                        ? AppText.bodyStrong(13.5)
                        : AppText.body(13.5)),
                if ((a.postTexto ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    a.postTexto!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(11.5, color: AppColors.textMuted),
                  ),
                ],
                const SizedBox(height: 3),
                Text(_quando(a.criadoEm),
                    style: AppText.caption(10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _quando(DateTime d) {
    final dif = DateTime.now().difference(d);
    if (dif.inMinutes < 1) return 'agora';
    if (dif.inHours < 1) return '${dif.inMinutes} min';
    if (dif.inDays < 1) return '${dif.inHours} h';
    if (dif.inDays < 7) return '${dif.inDays} d';
    return Datas.curta(d);
  }

  // ── Preferências ────────────────────────────────────────────

  Future<void> _abrirPreferencias() async {
    final alunoId = widget.alunoId;
    if (alunoId == null) return;

    var p = await FeedService.prefsDeAviso(alunoId);

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('O que me avisar', style: AppText.title(17)),
                const SizedBox(height: AppSpacing.lg),

                _chave(
                  'Minhas conquistas publicadas',
                  p.conquista,
                  (v) {
                    setLocal(() => p = (
                          conquista: v,
                          interacao: p.interacao,
                          aviso: p.aviso
                        ));
                    FeedService.definirPrefsDeAviso(alunoId, conquista: v);
                  },
                ),
                _chave(
                  'Reações e comentários nas minhas publicações',
                  p.interacao,
                  (v) {
                    setLocal(() => p = (
                          conquista: p.conquista,
                          interacao: v,
                          aviso: p.aviso
                        ));
                    FeedService.definirPrefsDeAviso(alunoId, interacao: v);
                  },
                ),
                _chave(
                  'Avisos fixados pelo meu profissional',
                  p.aviso,
                  (v) {
                    setLocal(() => p = (
                          conquista: p.conquista,
                          interacao: p.interacao,
                          aviso: v
                        ));
                    FeedService.definirPrefsDeAviso(alunoId, aviso: v);
                  },
                ),

                const SizedBox(height: AppSpacing.md),
                Text(
                  'Desligar aqui não tira você da comunidade — só para de '
                  'encher esta caixa.',
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chave(String titulo, bool valor, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(titulo, style: AppText.body(13.5))),
          const SizedBox(width: AppSpacing.md),
          Switch(
            value: valor,
            activeThumbColor: AppColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
