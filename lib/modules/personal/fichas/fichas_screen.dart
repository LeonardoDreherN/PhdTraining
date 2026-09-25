import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/ficha.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Aba "Treinos".
///
/// Antes esta aba abria a biblioteca de exercícios. Mas exercício é
/// catálogo — consultado de vez em quando. O que o personal mexe todo dia é
/// ficha. A biblioteca virou destino secundário, acessível daqui.
class FichasScreen extends ConsumerWidget {
  const FichasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(fichasProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _cabecalho(context, ref, estado.valueOrNull?.length ?? 0),
            _atalhoBiblioteca(context),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: estado.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não consegui carregar',
                  message: '$e',
                  actionLabel: 'Tentar de novo',
                  onAction: () => ref.invalidate(fichasProvider),
                ),
                data: (fichas) => fichas.isEmpty
                    ? PhdEmptyState(
                        icon: Icons.fitness_center_rounded,
                        title: 'Nenhuma ficha ainda',
                        message: 'Uma ficha é um treino montado: exercícios, '
                            'séries e cargas. Depois você atribui aos alunos.',
                        actionLabel: 'Criar primeira ficha',
                        onAction: () => _criar(context, ref),
                      )
                    : _lista(context, ref, fichas),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(BuildContext context, WidgetRef ref, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md,
      ),
      child: Row(
        children: [
          Text('Treinos', style: AppText.display(28)),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              total == 0 ? '' : '$total',
              style: AppText.number(15, color: AppColors.textMuted),
            ),
          ),
          PhdButton(
            label: 'Nova ficha',
            icon: Icons.add_rounded,
            size: PhdButtonSize.small,
            expand: false,
            onPressed: () => _criar(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _atalhoBiblioteca(BuildContext context) {
    return Padding(
      padding: AppSpacing.screen,
      child: PhdCard(
        onTap: () => context.push('/exercicios'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2,
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded,
                size: 19, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Biblioteca de exercícios',
                style: AppText.bodyStrong(13.5),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 19, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _lista(BuildContext context, WidgetRef ref, List<Ficha> fichas) {
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.invalidate(fichasProvider);
        await ref.read(fichasProvider.future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge * 2,
        ),
        itemCount: fichas.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _cartao(context, ref, fichas[i]),
      ),
    );
  }

  Widget _cartao(BuildContext context, WidgetRef ref, Ficha f) {
    return PhdCard(
      // Só a ficha vazia ganha faixa: é a única que exige ação antes de
      // servir para alguma coisa.
      accentBar: f.vazia ? AppColors.accent : null,
      onTap: () async {
        await context.push('/fichas/detalhe', extra: f.mapa);
        recarregarTudo(ref);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      f.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title(16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      f.resumo,
                      style: AppText.caption(12,
                          color: f.vazia ? AppColors.accent : null),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surfaceHigh,
                surfaceTintColor: Colors.transparent,
                tooltip: 'Opções da ficha ${f.nome}',
                shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted, size: 20),
                onSelected: (v) => _menu(context, ref, v, f),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'renomear', child: Text('Renomear', style: AppText.body(14))),
                  PopupMenuItem(value: 'duplicar', child: Text('Duplicar', style: AppText.body(14))),
                  PopupMenuItem(
                    value: 'deletar',
                    child: Text('Excluir',
                        style: AppText.body(14, color: AppColors.dangerText)),
                  ),
                ],
              ),
            ],
          ),
          if (f.grupos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in f.grupos) PhdStatusChip(label: g),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Ações ───────────────────────────────────────────────────

  Future<void> _criar(BuildContext context, WidgetRef ref) async {
    final dados = await _dialogoFicha(context, titulo: 'Nova ficha');
    if (dados == null) return;
    final nova = await FichaService.criar(nome: dados.$1, descricao: dados.$2);
    if (!context.mounted) return;
    recarregarTudo(ref);
    // Leva direto para montar: ficha criada e vazia não serve para nada, e
    // parar na lista faria o personal ter de achá-la de novo.
    await context.push('/fichas/detalhe', extra: nova);
    if (context.mounted) recarregarTudo(ref);
  }

  Future<void> _menu(
      BuildContext context, WidgetRef ref, String acao, Ficha f) async {
    switch (acao) {
      case 'renomear':
        final dados = await _dialogoFicha(
          context,
          titulo: 'Renomear ficha',
          nome: f.nome,
          descricao: f.descricao,
        );
        if (dados == null) return;
        await FichaService.atualizar(f.id, dados.$1, dados.$2);
        if (context.mounted) recarregarTudo(ref);

      case 'duplicar':
        final copia = await FichaService.criar(
          nome: '${f.nome} (cópia)',
          descricao: f.descricao,
        );
        if (!context.mounted) return;
        recarregarTudo(ref);
        // A cópia nasce sem exercícios: copiar `ficha_exercicios` junto
        // exige uma função no banco, e fica para quando o montador for
        // reescrito. Por isso vai direto para a tela de montagem.
        await context.push('/fichas/detalhe', extra: copia);
        if (context.mounted) recarregarTudo(ref);

      case 'deletar':
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Excluir "${f.nome}"?', style: AppText.title(17)),
            content: Text(
              f.atribuida
                  ? 'Ela está atribuída a ${f.qtdAlunos} '
                      '${f.qtdAlunos == 1 ? 'aluno' : 'alunos'}. '
                      'Eles ficam sem esse treino imediatamente.'
                  : 'Os exercícios continuam na biblioteca — só a montagem '
                      'desta ficha é apagada.',
              style: AppText.body(13.5, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar',
                    style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Excluir',
                    style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
              ),
            ],
          ),
        );
        if (ok != true) return;
        try {
          await FichaService.deletar(f.id);
          if (context.mounted) recarregarTudo(ref);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Não consegui excluir: $e')),
            );
          }
        }
    }
  }

  /// Devolve (nome, descrição) ou `null` se cancelar.
  Future<(String, String?)?> _dialogoFicha(
    BuildContext context, {
    required String titulo,
    String? nome,
    String? descricao,
  }) async {
    final ctrlNome = TextEditingController(text: nome);
    final ctrlDesc = TextEditingController(text: descricao);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo, style: AppText.title(17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhdField(
              label: 'Nome',
              controller: ctrlNome,
              hint: 'Treino A · Peito e tríceps',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            PhdField(
              label: 'Descrição',
              controller: ctrlDesc,
              hint: 'Opcional',
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Salvar',
                style: AppText.bodyStrong(13.5, color: AppColors.accent)),
          ),
        ],
      ),
    );

    final n = ctrlNome.text.trim();
    final d = ctrlDesc.text.trim();
    ctrlNome.dispose();
    ctrlDesc.dispose();

    if (ok != true || n.isEmpty) return null;
    return (n, d.isEmpty ? null : d);
  }
}
