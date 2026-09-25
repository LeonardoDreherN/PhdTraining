import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'phd_button.dart';

/// Cabeçalho de seção: rótulo em caixa alta à esquerda, ação à direita.
///
/// É o que substitui as linhas divisórias do app antigo. Rótulo pequeno e
/// espaçado separa blocos melhor que um traço, e ainda diz o que vem abaixo.
class PhdSectionHeader extends StatelessWidget {
  const PhdSectionHeader({
    super.key,
    required this.label,
    this.trailing,
    this.onTrailingTap,
    this.trailingColor,
  });

  final String label;

  /// Texto da ação à direita: "Ver todas", uma contagem, etc.
  final String? trailing;
  final VoidCallback? onTrailingTap;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: AppText.label(),
          ),
        ),
        if (trailing != null)
          onTrailingTap == null
              ? Text(
                  trailing!,
                  style: AppText.bodyStrong(12, color: trailingColor ?? AppColors.accent),
                )
              : InkWell(
                  onTap: onTrailingTap,
                  borderRadius: AppRadius.rSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      trailing!,
                      style: AppText.bodyStrong(12,
                          color: trailingColor ?? AppColors.textSecondary),
                    ),
                  ),
                ),
      ],
    );
  }
}

/// Estado vazio com saída.
///
/// Um vazio sem botão é um beco sem saída — e o app antigo tinha vários. Se
/// não existe ação possível, pelo menos a mensagem explica o que faria
/// aparecer algo aqui.
class PhdEmptyState extends StatelessWidget {
  const PhdEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(title, textAlign: TextAlign.center, style: AppText.title(18)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.body(13.5, color: AppColors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              PhdButton(
                label: actionLabel!,
                onPressed: onAction,
                size: PhdButtonSize.medium,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
