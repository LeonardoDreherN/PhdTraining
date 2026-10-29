import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Anel de progresso — calorias do dia, adesão da semana.
///
/// O centro é do chamador: o anel só desenha a trilha e o arco. Começa no
/// topo e anda no sentido horário, como um relógio, que é como o olho lê
/// "quanto já foi".
class PhdRing extends StatelessWidget {
  const PhdRing({
    super.key,
    required this.valor,
    required this.child,
    this.tamanho = 96,
    this.espessura = 9,
    this.cor = AppColors.accent,
  });

  /// 0 a 1; fora disso é preso.
  final double valor;
  final Widget child;
  final double tamanho;
  final double espessura;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: tamanho,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: valor.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, filho) => CustomPaint(
          painter: _RingPainter(valor: v, espessura: espessura, cor: cor),
          child: filho,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.valor, required this.espessura, required this.cor});

  final double valor;
  final double espessura;
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(espessura / 2);
    final trilha = Paint()
      ..color = AppColors.surfaceHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = espessura;
    canvas.drawArc(rect, 0, math.pi * 2, false, trilha);

    if (valor <= 0) return;
    final arco = Paint()
      ..color = cor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = espessura;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * valor, false, arco);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.valor != valor || old.cor != cor || old.espessura != espessura;
}

/// Linha fina de tendência, sem eixo e sem rótulo.
///
/// Na home a pergunta é só "está descendo ou subindo?". O gráfico com eixo,
/// data e valor exato mora na tela de avaliações.
class PhdSparkline extends StatelessWidget {
  const PhdSparkline({
    super.key,
    required this.valores,
    this.cor = AppColors.accent,
    this.altura = 44,
  });

  final List<double> valores;
  final Color cor;
  final double altura;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      width: double.infinity,
      child: CustomPaint(painter: _SparklinePainter(valores, cor)),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.valores, this.cor);

  final List<double> valores;
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.length < 2) return;
    final minV = valores.reduce(math.min);
    final maxV = valores.reduce(math.max);
    // Variação pequena (0,3 kg) não pode virar uma montanha na tela.
    // A faixa mínima fica centrada nos dados, para a linha não grudar no
    // chão nem no teto.
    final faixa = math.max(maxV - minV, 1.0);
    final base = (minV + maxV) / 2 - faixa / 2;
    const margem = 5.0;

    Offset ponto(int i) => Offset(
          margem + (size.width - margem * 2) * i / (valores.length - 1),
          margem + (size.height - margem * 2) * (1 - (valores[i] - base) / faixa),
        );

    final linha = Path()..moveTo(ponto(0).dx, ponto(0).dy);
    for (var i = 1; i < valores.length; i++) {
      final a = ponto(i - 1);
      final b = ponto(i);
      final meio = (a.dx + b.dx) / 2;
      linha.cubicTo(meio, a.dy, meio, b.dy, b.dx, b.dy);
    }

    final area = Path.from(linha)
      ..lineTo(ponto(valores.length - 1).dx, size.height)
      ..lineTo(ponto(0).dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cor.withValues(alpha: 0.22), cor.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      linha,
      Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final ultimo = ponto(valores.length - 1);
    canvas.drawCircle(ultimo, 5, Paint()..color = AppColors.surface);
    canvas.drawCircle(ultimo, 3.5, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.valores != valores || old.cor != cor;
}

/// Barras verticais com rótulo embaixo — receita por mês, treinos por dia.
///
/// A barra em [destaque] leva o acento; as outras ficam em cinza. Sem eixo
/// e sem valor: quem quer o número exato toca no cartão.
class PhdBars extends StatelessWidget {
  const PhdBars({
    super.key,
    required this.valores,
    required this.rotulos,
    this.destaque,
    this.altura = 64,
    this.cor = AppColors.accent,
  });

  final List<num> valores;
  final List<String> rotulos;
  final int? destaque;
  final double altura;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final maximo = valores.fold<num>(0, (m, v) => v > m ? v : m);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < valores.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(
                      begin: 0,
                      // Barra zerada ainda aparece como um traço: some de
                      // vez e a pessoa acha que o gráfico quebrou.
                      end: maximo <= 0 ? 4 : (altura * valores[i] / maximo).clamp(4, altura),
                    ),
                    duration: Duration(milliseconds: 500 + i * 60),
                    curve: Curves.easeOutCubic,
                    // Barra fina, não bloco: com a coluna inteira pintada
                    // o gráfico vira uma fileira de tijolos.
                    builder: (_, h, __) => FractionallySizedBox(
                      widthFactor: 0.42,
                      child: Container(
                        height: h,
                        decoration: BoxDecoration(
                          color: i == destaque ? cor : AppColors.lineStrong,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rotulos[i],
                    style: AppText.caption(
                      10.5,
                      color: i == destaque ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
