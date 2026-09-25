import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import 'phd_chip.dart';

/// Rótulo em cima, número grande embaixo, variação opcional.
///
/// A ordem importa: o número é o que a pessoa procura, então ele fica no
/// maior corpo da tela e o rótulo vira apoio — o contrário do app antigo,
/// onde "Alunos" tinha o mesmo peso que a contagem.
class PhdStat extends StatelessWidget {
  const PhdStat({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaTone = PhdTone.success,
    this.valueSize = 28,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? delta;
  final PhdTone deltaTone;
  final double valueSize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: AppText.label()),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppText.number(valueSize, color: valueColor, weight: FontWeight.w800)),
        ),
        if (delta != null) ...[
          const SizedBox(height: 4),
          Text(delta!, style: AppText.bodyStrong(12.5, color: deltaTone.onDark)),
        ],
      ],
    );
  }
}

/// Barra de progresso contínua — adesão, meta do mês, macro.
class PhdProgressBar extends StatelessWidget {
  const PhdProgressBar({
    super.key,
    required this.value,
    this.height = 7,
    this.color,
    this.track,
  });

  /// 0 a 1. Valores fora da faixa são presos, porque dado de produção
  /// eventualmente vem com 1.04 e a barra não pode estourar o cartão.
  final double value;
  final double height;
  final Color? color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.rPill,
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: track ?? AppColors.surfaceHigh,
        valueColor: AlwaysStoppedAnimation(color ?? AppColors.accent),
      ),
    );
  }
}

/// Progresso em passos discretos — semana 3 de 8, exercício 3 de 6.
///
/// Segmento em vez de barra porque aqui o número de passos é informação:
/// a pessoa conta quantos faltam.
class PhdSegments extends StatelessWidget {
  const PhdSegments({
    super.key,
    required this.total,
    required this.filled,
    this.height = 5,
    this.color,
  });

  final int total;
  final int filled;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$filled de $total',
      child: Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: i < filled ? (color ?? AppColors.accent) : AppColors.line,
                  borderRadius: AppRadius.rPill,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Meta com percentual, barra e a linha de "quanto falta".
class PhdGoal extends StatelessWidget {
  const PhdGoal({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.format,
  });

  final String label;
  final double current;
  final double target;

  /// Como transformar número em texto — moeda, peso, o que for.
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final ratio = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    final pct = (ratio * 100).round();
    final missing = (target - current).clamp(0, double.infinity).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(label.toUpperCase(), style: AppText.label())),
            Text('$pct%', style: AppText.number(15, color: AppColors.accent, weight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PhdProgressBar(value: ratio, height: 8),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                '${format(current)} de ${format(target)}',
                style: AppText.caption(12),
              ),
            ),
            Text(
              missing > 0 ? 'Faltam ${format(missing)}' : 'Meta batida',
              style: AppText.bodyStrong(12,
                  color: missing > 0 ? AppColors.textPrimary : AppColors.successText),
            ),
          ],
        ),
      ],
    );
  }
}
