import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Superfície padrão. Sem borda e sem sombra: a separação vem da diferença
/// entre `bg` e `surface`, não de um contorno. Empilhar borda com contraste
/// de fundo é o que deixava o app antigo com cara de wireframe.
class PhdCard extends StatelessWidget {
  const PhdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.accentBar,
    this.color,
    this.radius,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Faixa fina na esquerda, para sinalizar urgência numa lista sem pintar
  /// o cartão inteiro. Use com moderação: se toda linha tem faixa, some o
  /// sinal.
  final Color? accentBar;

  final Color? color;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? AppRadius.rXl;

    // A faixa lateral é BORDA, não filho de um Row.
    //
    // A primeira versão usava `Row` com `CrossAxisAlignment.stretch` para
    // esticar a faixa até a altura do cartão. Dentro de uma Column sem
    // altura definida — que é todo cartão numa lista — `stretch` propaga
    // `h=Infinity` e o layout inteiro quebra. Como borda, ela acompanha a
    // altura sozinha, e o Container já recolhe o conteúdo os 3px.
    final Widget content = Container(
      padding: padding,
      decoration: accentBar == null
          ? null
          : BoxDecoration(
              border: Border(left: BorderSide(color: accentBar!, width: 3)),
            ),
      child: child,
    );

    return Material(
      color: color ?? AppColors.surface,
      borderRadius: r,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Cartão de contorno tracejado, para "adicionar item". Nunca para conteúdo:
/// o tracejado significa "aqui ainda não tem nada".
class PhdAddCard extends StatelessWidget {
  const PhdAddCard({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add_rounded,
    this.height = 48,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rLg,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: AppColors.lineStrong,
            radius: AppRadius.lg,
          ),
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: AppColors.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    // Percorre o contorno arredondado em trechos de 6px com 4px de vão, em
    // vez de desenhar quatro linhas — assim o tracejado acompanha os cantos.
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
