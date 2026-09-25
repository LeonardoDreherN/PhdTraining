import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

enum PhdButtonVariant {
  /// A ação da tela. Uma por tela — se houver duas, nenhuma é primária.
  primary,

  /// Alternativa legítima ao lado da primária. Contorno, sem preenchimento.
  secondary,

  /// Ação terciária: cancelar, pular, ações dentro de um cartão.
  ghost,

  /// Só para o que destrói algo: excluir, cancelar assinatura.
  danger,
}

enum PhdButtonSize { large, medium, small }

class PhdButton extends StatelessWidget {
  const PhdButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PhdButtonVariant.primary,
    this.size = PhdButtonSize.large,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PhdButtonVariant variant;
  final PhdButtonSize size;
  final IconData? icon;
  final bool loading;

  /// `true` ocupa a largura toda; `false` encolhe ao conteúdo.
  final bool expand;

  double get _height => switch (size) {
        PhdButtonSize.large => 50,
        PhdButtonSize.medium => kMinTouch,
        PhdButtonSize.small => 36,
      };

  double get _fontSize => switch (size) {
        PhdButtonSize.large => 14.5,
        PhdButtonSize.medium => 13.5,
        PhdButtonSize.small => 12.5,
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      PhdButtonVariant.primary => (AppColors.accent, AppColors.onAccent, null),
      PhdButtonVariant.secondary => (
          Colors.transparent,
          AppColors.textPrimary,
          const BorderSide(color: AppColors.lineStrong),
        ),
      PhdButtonVariant.ghost => (AppColors.surfaceHigh, AppColors.textPrimary, null),
      PhdButtonVariant.danger => (
          AppColors.tint(AppColors.danger),
          AppColors.dangerText,
          null,
        ),
    };

    // Enquanto carrega o botão continua desabilitado, mas mantém a altura e a
    // largura — se encolher, o resto da tela pula.
    final enabled = onPressed != null && !loading;

    return SizedBox(
      height: _height,
      width: expand ? double.infinity : null,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: loading ? bg : AppColors.surfaceHigh,
          disabledForegroundColor: loading ? fg : AppColors.textMuted,
          side: border,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: size == PhdButtonSize.small ? AppSpacing.md : AppSpacing.lg,
          ),
          minimumSize: Size(expand ? double.infinity : 0, _height),
          shape: RoundedRectangleBorder(
            borderRadius: size == PhdButtonSize.small ? AppRadius.rMd : AppRadius.rLg,
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: _fontSize + 4),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong(_fontSize, color: fg),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Botão redondo só de ícone, para cabeçalho de tela.
class PhdIconButton extends StatelessWidget {
  const PhdIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.badge = false,
  });

  final IconData icon;

  /// Obrigatório: um botão só de ícone sem rótulo é invisível para leitor de
  /// tela, e o tooltip é o que o descreve.
  final String tooltip;

  final VoidCallback? onPressed;

  /// Ponto de acento no canto, para notificação pendente.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: kMinTouch,
          height: kMinTouch,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(icon, size: 20, color: AppColors.textPrimary),
                  ),
                ),
              ),
              if (badge)
                Positioned(
                  top: 7,
                  right: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
