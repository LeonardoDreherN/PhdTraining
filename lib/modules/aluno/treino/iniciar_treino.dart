import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Pergunta como o aluno quer treinar e abre o treino nesse modo.
///
/// Usado pela home e pela aba Treino. Devolve `true` se um treino foi
/// aberto (e fechado) — quem chamou recarrega para mostrar o check.
Future<bool> iniciarTreino(BuildContext context, Map<String, dynamic> ficha, {required int dia}) async {
  final modo = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => const _FolhaModo(),
  );
  if (modo == null || !context.mounted) return false;

  if (modo == 'lista') {
    await context.push('/aluno/treino-simples', extra: ficha);
  } else {
    await context.push('/aluno/treino', extra: {
      'ficha': ficha,
      'modoVideo': modo == 'video',
      'diaSelecionado': dia,
    });
  }
  return true;
}

/// Como o aluno quer executar: guiado série a série, com vídeo, ou só a
/// lista para quem já sabe o treino de cor.
class _FolhaModo extends StatelessWidget {
  const _FolhaModo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Como quer treinar?', style: AppText.title(17)),
          const SizedBox(height: AppSpacing.lg),
          _opcao(
            context,
            valor: 'guiado',
            icone: Icons.timer_outlined,
            titulo: 'Guiado',
            descricao: 'Um exercício por vez, com cronômetro de descanso.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _opcao(
            context,
            valor: 'video',
            icone: Icons.play_circle_outline_rounded,
            titulo: 'Guiado com vídeo',
            descricao: 'Mostra a execução antes de cada exercício.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _opcao(
            context,
            valor: 'lista',
            icone: Icons.list_alt_rounded,
            titulo: 'Só a lista',
            descricao: 'Para quem já sabe o treino e quer consultar rápido.',
          ),
        ],
      ),
    );
  }

  Widget _opcao(
    BuildContext context, {
    required String valor,
    required IconData icone,
    required String titulo,
    required String descricao,
  }) {
    return PhdCard(
      onTap: () => Navigator.pop(context, valor),
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icone, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titulo, style: AppText.bodyStrong(14)),
                const SizedBox(height: 2),
                Text(descricao, style: AppText.caption(12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 19, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
