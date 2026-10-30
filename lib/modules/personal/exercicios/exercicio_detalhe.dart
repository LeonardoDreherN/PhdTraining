import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Abre o exercício: o vídeo tocando em cima, e embaixo como executar.
///
/// É onde o personal confere se o vídeo que enviou ficou certo — antes ele
/// só via "Vídeo tutorial adicionado ✓", sem como assistir.
///
/// Devolve 'editar', 'excluir' ou `null`. Com [acoes] falso (de dentro da
/// ficha, por exemplo), só mostra.
Future<String?> abrirExercicio(
  BuildContext context,
  Map<String, dynamic> exercicio, {
  bool acoes = true,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _FolhaExercicio(exercicio: exercicio, acoes: acoes),
  );
}

class _FolhaExercicio extends StatelessWidget {
  const _FolhaExercicio({required this.exercicio, required this.acoes});

  final Map<String, dynamic> exercicio;
  final bool acoes;

  @override
  Widget build(BuildContext context) {
    final video = (exercicio['video_url'] as String?)?.trim();
    final imagem = (exercicio['midia_url'] as String?)?.trim();
    final grupo = exercicio['grupo_muscular'] as String?;
    final equip = (exercicio['equipamento'] as String?)?.trim();
    final como = [
      (exercicio['descricao'] as String?)?.trim(),
      (exercicio['instrucoes'] as String?)?.trim(),
    ].where((t) => t != null && t.isNotEmpty).join('\n\n');

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        children: [
          if (video != null && video.isNotEmpty)
            PhdVideo(url: video)
          else if (imagem != null && imagem.isNotEmpty)
            ClipRRect(
              borderRadius: AppRadius.rXl,
              child: Image.network(imagem, fit: BoxFit.cover, height: 240, width: double.infinity),
            )
          else
            Container(
              height: 160,
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.rXl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam_outlined, color: AppColors.textMuted, size: 30),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Sem vídeo ainda', style: AppText.bodyStrong(13.5)),
                  Text('Um vídeo curto da execução ajuda muito o aluno.', style: AppText.caption(12)),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(exercicio['nome'] as String? ?? 'Exercício', style: AppText.display(24)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (grupo != null && grupo.isNotEmpty) PhdStatusChip(label: grupo, tone: PhdTone.accent),
              if (equip != null && equip.isNotEmpty) PhdStatusChip(label: equip),
              if (video != null && video.isNotEmpty) const PhdStatusChip(label: 'com vídeo', tone: PhdTone.success),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('COMO EXECUTAR', style: AppText.label()),
          const SizedBox(height: AppSpacing.sm),
          Text(
            como.isEmpty ? 'Sem instruções. Toque em Editar para escrever o passo a passo.' : como,
            style: AppText.body(14.5, color: como.isEmpty ? AppColors.textMuted : AppColors.textPrimary),
          ),
          if (acoes) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: PhdButton(
                    label: 'Excluir',
                    variant: PhdButtonVariant.ghost,
                    icon: Icons.delete_outline_rounded,
                    onPressed: () => Navigator.pop(context, 'excluir'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PhdButton(
                    label: 'Editar',
                    icon: Icons.edit_outlined,
                    onPressed: () => Navigator.pop(context, 'editar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
