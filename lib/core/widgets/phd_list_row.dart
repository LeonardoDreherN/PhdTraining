import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'phd_card.dart';
import 'phd_metrics.dart';

/// A linha de lista do app — aluno, cobrança, exercício, transação.
///
/// Uma só forma para todas elas, porque é o elemento mais repetido do
/// produto: se cada tela inventar a sua, o app volta a parecer montado por
/// pessoas diferentes.
class PhdListRow extends StatelessWidget {
  const PhdListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.leading,
    this.trailing,
    this.trailingLabel,
    this.trailingValue,
    this.trailingValueColor,
    this.progress,
    this.progressColor,
    this.accentBar,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// Colore o subtítulo quando ele carrega o problema: "vencida há 6 dias".
  final Color? subtitleColor;

  final Widget? leading;

  /// Widget livre à direita. Tem precedência sobre `trailingValue`.
  final Widget? trailing;

  /// Par valor + rótulo à direita: "R$ 349,90" sobre "Atrasado", ou "92%"
  /// sobre "adesão".
  final String? trailingValue;
  final String? trailingLabel;
  final Color? trailingValueColor;

  /// Barra fina embaixo do subtítulo — adesão do aluno, por exemplo.
  final double? progress;
  final Color? progressColor;

  final Color? accentBar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PhdCard(
      onTap: onTap,
      accentBar: accentBar,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg - 2,
        vertical: AppSpacing.md + 1,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong(14.5),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(11.5, color: subtitleColor),
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: AppSpacing.sm - 2),
                  PhdProgressBar(
                    value: progress!,
                    height: 4,
                    color: progressColor ?? AppColors.lineStrong,
                    track: AppColors.surfaceHigh,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.md),
            trailing!,
          ] else if (trailingValue != null) ...[
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingValue!,
                  style: AppText.number(14, color: trailingValueColor),
                ),
                if (trailingLabel != null) ...[
                  const SizedBox(height: 3),
                  Text(trailingLabel!, style: AppText.caption(10)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
