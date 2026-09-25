import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

/// Vocabulário de estado do app inteiro. Se um estado novo aparecer, ele
/// entra aqui — não vira uma cor solta dentro de uma tela.
enum PhdTone { neutral, accent, success, warning, danger }

extension PhdToneColors on PhdTone {
  /// Tom cheio: ponto, barra, faixa lateral.
  Color get solid => switch (this) {
        PhdTone.neutral => AppColors.textSecondary,
        PhdTone.accent => AppColors.accent,
        PhdTone.success => AppColors.success,
        PhdTone.warning => AppColors.warning,
        PhdTone.danger => AppColors.danger,
      };

  /// Tom claro: usado quando vira texto ou ícone, onde o cheio não passa
  /// contraste sobre fundo escuro.
  Color get onDark => switch (this) {
        PhdTone.neutral => AppColors.textSecondary,
        PhdTone.accent => AppColors.accent,
        PhdTone.success => AppColors.successText,
        PhdTone.warning => AppColors.warningText,
        PhdTone.danger => AppColors.dangerText,
      };
}

/// Etiqueta de estado — não clicável. "Pago", "Atrasado", "Ativo".
class PhdStatusChip extends StatelessWidget {
  const PhdStatusChip({
    super.key,
    required this.label,
    this.tone = PhdTone.neutral,
  });

  final String label;
  final PhdTone tone;

  @override
  Widget build(BuildContext context) {
    final fg = tone == PhdTone.accent ? AppColors.onAccent : tone.onDark;
    final bg = tone == PhdTone.accent
        ? AppColors.accent
        : tone == PhdTone.neutral
            ? AppColors.surfaceHigh
            : AppColors.tint(tone.solid);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rPill),
      child: Text(label, style: AppText.bodyStrong(10.5, color: fg)),
    );
  }
}

/// Filtro de lista. Selecionado vira acento sólido; os outros ficam de
/// contorno, para que a seleção seja óbvia de relance.
class PhdFilterChip extends StatelessWidget {
  const PhdFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.tone = PhdTone.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final PhdTone tone;

  @override
  Widget build(BuildContext context) {
    final text = count == null ? label : '$label $count';

    final fg = selected
        ? (tone == PhdTone.accent ? AppColors.onAccent : AppColors.onAccent)
        : tone == PhdTone.accent
            ? AppColors.textSecondary
            : tone.onDark;

    final bg = selected ? tone.solid : Colors.transparent;
    final borderColor = selected
        ? Colors.transparent
        : tone == PhdTone.accent
            ? AppColors.line
            : tone.solid.withValues(alpha: 0.4);

    return Semantics(
      button: true,
      selected: selected,
      label: text,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rPill,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: AppRadius.rPill,
            border: Border.all(color: borderColor),
          ),
          child: Text(
            text,
            style: selected
                ? AppText.bodyStrong(12.5, color: fg)
                : AppText.caption(12.5, color: fg),
          ),
        ),
      ),
    );
  }
}

/// Fileira de filtros que rola na horizontal sem cortar o último item.
class PhdFilterBar extends StatelessWidget {
  const PhdFilterBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screen,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }
}
