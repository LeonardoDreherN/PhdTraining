import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_text.dart';

// A landing tem paleta própria, sempre escura: é vitrine, não ferramenta.
// Seguir o tema claro do aparelho aqui deixaria a primeira impressão com
// cara de formulário. As cores são as do app (mesmo vermelho, mesmo verde).
const _fundo = Color(0xFF07070A);
const _cartao = Color(0xFF111115);
const _cartao2 = Color(0xFF19191E);
const _linha = Color(0xFF26262C);
const _branco = Color(0xFFF5F5F6);
const _cinza = Color(0xFFA1A1AA);
const _cinza2 = Color(0xFF71717A);
const _vermelho = Color(0xFFDC2626);
const _vermelhoClaro = Color(0xFFEF4444);
const _verde = Color(0xFF4ADE80);
const _azul = Color(0xFF3B82F6);
const _ambar = Color(0xFFF59E0B);
const _rosa = Color(0xFFEC4899);

const _larguraMax = 1180.0;

/// A primeira tela de quem abre o link sem estar logado.
///
/// Quem precisa ser convencido é o personal: a página mostra o produto
/// funcionando (telas de verdade, desenhadas com os mesmos componentes do
/// app) em vez de prometer com adjetivo. O aluno, que já tem acesso, acha
/// o "Entrar" no topo e um aviso de que quem cria a conta dele é o personal.
/// Os dois botões levam ao mesmo login — o papel já está no perfil.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.sizeOf(context).width;
    final desktop = largura >= 1000;

    return Scaffold(
      backgroundColor: _fundo,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Hero(desktop: desktop),
            const _Faixa(),
            _Secao(child: _Frentes(colunas: desktop ? 3 : (largura >= 680 ? 2 : 1))),
            _Secao(child: _DoisLados(desktop: desktop)),
            _Secao(child: _Notebook(desktop: desktop)),
            _Secao(child: _Passos(desktop: desktop)),
            _Secao(child: _Chamada(desktop: desktop)),
            const _Rodape(),
          ],
        ),
      ),
    );
  }
}

// ── Peças comuns ──────────────────────────────────────────────

class _Secao extends StatelessWidget {
  const _Secao({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 680;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: estreito ? 20 : 32, vertical: estreito ? 48 : 72),
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: _larguraMax), child: child),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 18, height: 2, color: _vermelho),
          const SizedBox(width: 10),
          Text(texto.toUpperCase(), style: AppText.label(color: _vermelhoClaro)),
        ],
      );
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, {this.centro = false});
  final String texto;
  final bool centro;

  @override
  Widget build(BuildContext context) {
    final grande = MediaQuery.sizeOf(context).width >= 680;
    return Text(
      texto,
      textAlign: centro ? TextAlign.center : TextAlign.start,
      style: AppText.display(grande ? 46 : 32, color: _branco).copyWith(height: 1.05),
    );
  }
}

class _Botao extends StatefulWidget {
  const _Botao(this.rotulo, {required this.onTap, this.primario = true, this.icone});
  final String rotulo;
  final VoidCallback onTap;
  final bool primario;
  final IconData? icone;

  @override
  State<_Botao> createState() => _BotaoState();
}

class _BotaoState extends State<_Botao> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.primario;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          transform: Matrix4.translationValues(0, _sobre ? -2 : 0, 0),
          decoration: BoxDecoration(
            color: p ? (_sobre ? _vermelhoClaro : _vermelho) : (_sobre ? _cartao2 : Colors.transparent),
            borderRadius: BorderRadius.circular(14),
            border: p ? null : Border.all(color: _sobre ? _cinza2 : _linha),
            boxShadow: p
                ? [BoxShadow(color: _vermelho.withValues(alpha: _sobre ? 0.55 : 0.35), blurRadius: _sobre ? 28 : 20, offset: const Offset(0, 8))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.rotulo, style: AppText.bodyStrong(15, color: _branco)),
              if (widget.icone != null) ...[
                const SizedBox(width: 8),
                Icon(widget.icone, size: 18, color: _branco),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrada suave: sobe e aparece. [atraso] escalona os blocos do hero.
class _Surge extends StatelessWidget {
  const _Surge({required this.child, this.atraso = 0});
  final Widget child;
  final int atraso;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + atraso),
      curve: Interval(atraso / (700 + atraso), 1, curve: Curves.easeOutCubic),
      builder: (_, v, filho) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: filho),
      ),
      child: child,
    );
  }
}

/// Flutua devagar — os cartões em volta do celular parecem vivos.
class _Flutua extends StatefulWidget {
  const _Flutua({required this.child, this.fase = 0}) : amplitude = 8;
  final Widget child;
  final double fase;
  final double amplitude;

  @override
  State<_Flutua> createState() => _FlutuaState();
}

class _FlutuaState extends State<_Flutua> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, filho) => Transform.translate(
          offset: Offset(0, math.sin((_c.value + widget.fase) * 2 * math.pi) * widget.amplitude),
          child: filho,
        ),
        child: widget.child,
      );
}

// ── Hero ──────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.desktop});
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 680;
    final texto = Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        _Surge(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _vermelho.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _vermelho.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: _vermelhoClaro, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Para personal trainers e nutricionistas', style: AppText.bodyStrong(12.5, color: _branco)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _Surge(
          atraso: 120,
          child: Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'Seu aluno no app.\n'),
              TextSpan(text: 'Você no controle.', style: TextStyle(foreground: Paint()..shader = _gradienteTexto)),
            ]),
            textAlign: desktop ? TextAlign.start : TextAlign.center,
            style: AppText.display(desktop ? 72 : (estreito ? 40 : 56), color: _branco).copyWith(height: 1.0),
          ),
        ),
        const SizedBox(height: 24),
        _Surge(
          atraso: 240,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Treino com vídeo, plano alimentar, avaliação física e o dia a dia de cada aluno — '
              'no celular dele e no seu notebook. Você monta, ele segue, e você vê se seguiu.',
              textAlign: desktop ? TextAlign.start : TextAlign.center,
              style: AppText.body(estreito ? 16 : 18, color: _cinza).copyWith(height: 1.55),
            ),
          ),
        ),
        const SizedBox(height: 36),
        _Surge(
          atraso: 360,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: desktop ? WrapAlignment.start : WrapAlignment.center,
            children: [
              _Botao('Criar minha conta', icone: Icons.arrow_forward_rounded, onTap: () => context.go('/cadastro')),
              _Botao('Já tenho conta', primario: false, onTap: () => context.go('/login')),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _Surge(
          atraso: 480,
          child: Text(
            'Aluno? Entre com o acesso que seu personal criou para você.',
            textAlign: desktop ? TextAlign.start : TextAlign.center,
            style: AppText.caption(13, color: _cinza2),
          ),
        ),
      ],
    );

    return Stack(
      children: [
        // Brilho vermelho atrás do celular e a grade do fundo.
        const Positioned.fill(child: _FundoHero()),
        Column(
          children: [
            _Topo(estreito: estreito),
            Padding(
              padding: EdgeInsets.fromLTRB(estreito ? 20 : 32, estreito ? 32 : 56, estreito ? 20 : 32, estreito ? 48 : 88),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _larguraMax),
                  child: desktop
                      ? Row(
                          children: [
                            Expanded(flex: 11, child: texto),
                            const SizedBox(width: 32),
                            const Expanded(flex: 9, child: _Surge(atraso: 200, child: _CenaCelular())),
                          ],
                        )
                      : Column(
                          children: [
                            texto,
                            const SizedBox(height: 56),
                            const _Surge(atraso: 300, child: _CenaCelular()),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

final _gradienteTexto = const LinearGradient(colors: [_vermelhoClaro, Color(0xFFFF7A59)])
    .createShader(const Rect.fromLTWH(0, 0, 520, 80));

class _FundoHero extends StatelessWidget {
  const _FundoHero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _Grade())),
        Positioned(
          right: -200,
          top: 40,
          child: Container(
            width: 760,
            height: 760,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_vermelho.withValues(alpha: 0.28), _vermelho.withValues(alpha: 0)]),
            ),
          ),
        ),
        // Desce o fundo para preto, para a faixa seguinte não cortar a grade.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.6, 1],
                colors: [_fundo.withValues(alpha: 0), _fundo],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Grade extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const passo = 56.0;
    for (var x = 0.0; x < size.width; x += passo) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = 0.0; y < size.height; y += passo) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_Grade old) => false;
}

class _Topo extends StatelessWidget {
  const _Topo({required this.estreito});
  final bool estreito;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: estreito ? 20 : 32, vertical: 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _larguraMax),
          child: Row(
            children: [
              Image.asset('assets/images/logo_white.png', height: estreito ? 26 : 30, filterQuality: FilterQuality.medium),
              const Spacer(),
              if (!estreito) ...[
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text('Entrar', style: AppText.bodyStrong(14, color: _branco)),
                ),
                const SizedBox(width: 8),
                _Botao('Criar conta', onTap: () => context.go('/cadastro')),
              ] else
                TextButton(
                  onPressed: () => context.go('/login'),
                  style: TextButton.styleFrom(
                    side: const BorderSide(color: _linha),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Entrar', style: AppText.bodyStrong(14, color: _branco)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// O celular com a home do aluno e dois cartões flutuando em volta: o que o
/// aluno vê e o que o personal fica sabendo.
class _CenaCelular extends StatelessWidget {
  const _CenaCelular();

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 480;
    final escala = estreito ? 0.86 : 1.0;
    return SizedBox(
      height: 640 * escala,
      child: Transform.scale(
        scale: escala,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const _Celular(),
            Positioned(
              right: estreito ? -20 : -6,
              top: 90,
              child: const _Flutua(
                child: _CartaoFlutuante(
                  icone: Icons.check_circle_rounded,
                  cor: _verde,
                  titulo: 'Marina seguiu tudo hoje',
                  apoio: 'Treino · 5/5 refeições · 2,5 L',
                ),
              ),
            ),
            Positioned(
              left: estreito ? -20 : -10,
              bottom: 120,
              child: const _Flutua(
                fase: 0.5,
                child: _CartaoFlutuante(
                  icone: Icons.local_fire_department_rounded,
                  cor: Color(0xFFFF7A59),
                  titulo: '4ª semana seguida',
                  apoio: 'Treino A concluído · 46 min',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoFlutuante extends StatelessWidget {
  const _CartaoFlutuante({required this.icone, required this.cor, required this.titulo, required this.apoio});
  final IconData icone;
  final Color cor;
  final String titulo;
  final String apoio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
      decoration: BoxDecoration(
        color: _cartao2.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: cor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
            child: Icon(icone, color: cor, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(titulo, style: AppText.bodyStrong(13.5, color: _branco)),
              Text(apoio, style: AppText.caption(12, color: _cinza)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Um celular desenhado com widgets — a home do aluno de verdade, em
/// miniatura. Nada de imagem estática que envelhece a cada mudança de tela.
class _Celular extends StatelessWidget {
  const _Celular();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: 620,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1F),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: const Color(0xFF34343C), width: 1.5),
        boxShadow: [
          BoxShadow(color: _vermelho.withValues(alpha: 0.25), blurRadius: 80, spreadRadius: -10),
          BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 30)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: ColoredBox(
          color: const Color(0xFF0A0A0B),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('9:41', style: AppText.bodyStrong(12, color: _branco)),
                    const Spacer(),
                    Container(width: 80, height: 22, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12))),
                    const Spacer(),
                    const Icon(Icons.signal_cellular_alt_rounded, size: 13, color: _branco),
                    const SizedBox(width: 3),
                    const Icon(Icons.battery_full_rounded, size: 14, color: _branco),
                  ],
                ),
                const SizedBox(height: 16),
                Text('QUINTA, 13 DE NOVEMBRO', style: AppText.label(color: _cinza2).copyWith(fontSize: 8.5, letterSpacing: 1.6)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text('Bom dia, Marina', style: AppText.display(21, color: _branco))),
                    const CircleAvatar(radius: 15, backgroundColor: _cartao2, child: Text('MC', style: TextStyle(fontSize: 10, color: _branco, fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 14),
                _miniSemana(),
                const SizedBox(height: 10),
                _miniTreino(),
                const SizedBox(height: 10),
                _miniDia(),
                const SizedBox(height: 10),
                _miniDieta(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _caixa({required Widget child, EdgeInsets padding = const EdgeInsets.all(12)}) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: _cartao, borderRadius: BorderRadius.circular(16), border: Border.all(color: _linha)),
        child: child,
      );

  Widget _miniSemana() {
    const letras = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    return _caixa(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(
                children: [
                  Text(letras[i], style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: i == 3 ? _vermelhoClaro : _cinza2)),
                  const SizedBox(height: 5),
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < 3 ? _verde.withValues(alpha: 0.15) : Colors.transparent,
                      border: Border.all(color: i < 3 ? _verde : (i == 3 ? _vermelho : _linha), width: 1.3),
                    ),
                    child: i < 3
                        ? const Icon(Icons.check_rounded, size: 13, color: _verde)
                        : Text('${10 + i}', style: const TextStyle(fontSize: 9.5, color: _branco, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniTreino() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_vermelhoClaro, Color(0xFFB91C1C)]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TREINO DE HOJE', style: AppText.label(color: Colors.white70).copyWith(fontSize: 8.5, letterSpacing: 1.6)),
          const SizedBox(height: 4),
          Text('Treino A — Superiores', style: AppText.display(17, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('7 exercícios  ·  ~45 min  ·  23 séries', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Container(
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill_rounded, size: 15, color: _vermelho),
                SizedBox(width: 6),
                Text('Começar treino', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _vermelho)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniDia() {
    Widget item(IconData i, String r, String v, bool ok) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: ok ? _verde.withValues(alpha: 0.12) : _cartao2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(ok ? Icons.check_circle_rounded : i, size: 14, color: ok ? _verde : _cinza),
                const SizedBox(height: 2),
                Text(r, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _branco)),
                Text(v, style: const TextStyle(fontSize: 8.5, color: _cinza)),
              ],
            ),
          ),
        );
    return _caixa(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SEU DIA', style: AppText.label(color: _cinza2).copyWith(fontSize: 8.5, letterSpacing: 1.6)),
          const SizedBox(height: 8),
          Row(
            children: [
              item(Icons.fitness_center_rounded, 'Treino', 'feito', true),
              const SizedBox(width: 6),
              item(Icons.restaurant_menu_rounded, 'Refeições', '3/5', false),
              const SizedBox(width: 6),
              item(Icons.water_drop_outlined, 'Água', '2,5 L', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniDieta() {
    Widget barra(Color c, double v) => Expanded(
          child: Container(
            height: 5,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: _cartao2, borderRadius: BorderRadius.circular(3)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            ),
          ),
        );
    return _caixa(
      child: Row(
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const CircularProgressIndicator(value: 0.62, strokeWidth: 5, backgroundColor: _cartao2, color: _verde),
                Text('62%', style: AppText.number(10.5, color: _branco)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('1.148 de 1.850 kcal', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _branco)),
                const SizedBox(height: 6),
                Row(children: [barra(_azul, 0.7), barra(_ambar, 0.55), barra(_rosa, 0.6)]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Faixa que corre ───────────────────────────────────────────

class _Faixa extends StatefulWidget {
  const _Faixa();

  @override
  State<_Faixa> createState() => _FaixaState();
}

class _FaixaState extends State<_Faixa> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  static const _itens = [
    'Fichas com vídeo',
    'Treino guiado série a série',
    'Tabela TACO completa',
    'Substitutos equivalentes',
    'Lista de compras',
    'Dobras cutâneas',
    'Bioimpedância',
    'Avaliação postural',
    'Testes neuromotores',
    'Periodização',
    'Agenda de consultas',
    'Chat com o aluno',
    'Mensalidades',
    'Versão para notebook',
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final linha = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in _itens) ...[
          Text(t, style: AppText.title(17, color: _branco)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Icon(Icons.add_rounded, size: 16, color: _vermelho),
          ),
        ],
      ],
    );
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: _cartao,
        border: Border.symmetric(horizontal: BorderSide(color: _linha)),
      ),
      child: ClipRect(
        child: LayoutBuilder(
          builder: (_, __) => AnimatedBuilder(
            animation: _c,
            builder: (_, filho) => FractionalTranslation(
              translation: Offset(-_c.value / 2, 0),
              child: filho,
            ),
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: Row(mainAxisSize: MainAxisSize.min, children: [linha, linha]),
            ),
          ),
        ),
      ),
    );
  }
}

// ── As frentes ────────────────────────────────────────────────

class _Frentes extends StatelessWidget {
  const _Frentes({required this.colunas});
  final int colunas;

  @override
  Widget build(BuildContext context) {
    final cartoes = <Widget>[
      _Frente(
        icone: Icons.play_circle_outline_rounded,
        titulo: 'Fichas com vídeo de cada exercício',
        texto: 'Monte o treino em minutos. O aluno executa guiado, série a série, com cronômetro de descanso e a carga anotada.',
        visual: _VisualTreino(),
      ),
      _Frente(
        icone: Icons.restaurant_menu_rounded,
        titulo: 'Plano alimentar de verdade',
        texto: 'Tabela TACO completa, substitutos equivalentes, lista de compras e PDF assinado com seu CRN.',
        visual: _VisualDieta(),
      ),
      _Frente(
        icone: Icons.monitor_heart_outlined,
        titulo: 'Avaliação física completa',
        texto: 'Dobras, bioimpedância, perimetria, postural e testes neuromotores — com a evolução em gráfico.',
        visual: _VisualAvaliacao(),
      ),
      _Frente(
        icone: Icons.fact_check_outlined,
        titulo: 'Saiba se ele seguiu tudo',
        texto: 'Escolha um dia e veja treino, refeições e água. A adesão de cada aluno, sem precisar perguntar.',
        visual: _VisualDia(),
      ),
      _Frente(
        icone: Icons.forum_outlined,
        titulo: 'Agenda e conversa no app',
        texto: 'Consultas com confirmação do aluno e o chat no mesmo lugar do treino. Sem perder nada no WhatsApp.',
        visual: _VisualChat(),
      ),
      _Frente(
        icone: Icons.payments_outlined,
        titulo: 'Mensalidades em dia',
        texto: 'Cobranças de cada aluno e quem está atrasado, na tela inicial. O financeiro deixa de ser planilha.',
        visual: _VisualFinanceiro(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Etiqueta('Tudo num lugar só'),
        const SizedBox(height: 16),
        const _Titulo('Treino, dieta, avaliação\ne acompanhamento.'),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Chega de fichas em PDF, planilha de dieta e avaliação no caderno. Cada aluno tem tudo dele num app só — e você enxerga a carteira inteira.',
            style: AppText.body(16, color: _cinza).copyWith(height: 1.55),
          ),
        ),
        const SizedBox(height: 40),
        LayoutBuilder(
          builder: (_, c) {
            const gap = 16.0;
            final w = (c.maxWidth - gap * (colunas - 1)) / colunas;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final card in cartoes) SizedBox(width: w, child: card)],
            );
          },
        ),
      ],
    );
  }
}

class _Frente extends StatefulWidget {
  const _Frente({required this.icone, required this.titulo, required this.texto, required this.visual});
  final IconData icone;
  final String titulo;
  final String texto;
  final Widget visual;

  @override
  State<_Frente> createState() => _FrenteState();
}

class _FrenteState extends State<_Frente> {
  bool _sobre = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _sobre = true),
      onExit: (_) => setState(() => _sobre = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 420,
        padding: const EdgeInsets.all(24),
        transform: Matrix4.translationValues(0, _sobre ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: _cartao,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _sobre ? _vermelho.withValues(alpha: 0.5) : _linha),
          gradient: _sobre
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_vermelho.withValues(alpha: 0.08), _cartao],
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: widget.visual)),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(widget.icone, size: 20, color: _vermelhoClaro),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.titulo, style: AppText.title(18, color: _branco))),
              ],
            ),
            const SizedBox(height: 8),
            Text(widget.texto, style: AppText.body(14, color: _cinza).copyWith(height: 1.5)),
          ],
        ),
      ),
    );
  }
}

Widget _pilula(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
      child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
    );

class _VisualTreino extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget linha(int n, String nome, String presc, bool video) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _cartao2, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: _vermelho.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                    child: Icon(video ? Icons.play_arrow_rounded : Icons.fitness_center_rounded, color: _vermelhoClaro, size: 22),
                  ),
                  Positioned(
                    left: -5,
                    top: -5,
                    child: CircleAvatar(radius: 9, backgroundColor: _vermelho, child: Text('$n', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800))),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, style: AppText.bodyStrong(13, color: _branco)),
                    const SizedBox(height: 3),
                    _pilula(presc, _vermelhoClaro),
                  ],
                ),
              ),
            ],
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        linha(1, 'Supino reto com barra', '4 × 8-10', true),
        linha(2, 'Puxada frontal', '4 × 10', true),
        linha(3, 'Desenvolvimento', '3 × 12', false),
      ],
    );
  }
}

class _VisualDieta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget macro(String n, Color c, double v, String t) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(n, style: AppText.caption(12, color: _cinza)),
                const Spacer(),
                Text(t, style: AppText.number(12, color: _branco)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: _cartao2, color: c),
              ),
            ],
          ),
        );
    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox.expand(child: CircularProgressIndicator(value: 0.88, strokeWidth: 10, backgroundColor: _cartao2, color: _verde)),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('1.627', style: AppText.number(22, color: _branco)),
                  Text('de 1.850 kcal', style: AppText.caption(12, color: _cinza)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              macro('Proteína', _azul, 0.95, '133 g'),
              macro('Carboidrato', _ambar, 0.8, '152 g'),
              macro('Gordura', _rosa, 0.7, '38 g'),
            ],
          ),
        ),
      ],
    );
  }
}

class _VisualAvaliacao extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('18,4', style: AppText.number(40, color: _branco)),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text('% gordura', style: AppText.caption(13, color: _cinza)),
            ),
            const Spacer(),
            _pilula('−4,1 pts', _verde),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(height: 110, width: double.infinity, child: CustomPaint(painter: _Curva())),
      ],
    );
  }
}

class _Curva extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const valores = [22.5, 21.9, 21.0, 20.4, 19.8, 19.1, 18.4];
    double y(double v) => size.height - (v - 17.5) / (23 - 17.5) * size.height;
    final pontos = [
      for (final (i, v) in valores.indexed) Offset(i / (valores.length - 1) * size.width, y(v)),
    ];
    final caminho = Path()..moveTo(pontos.first.dx, pontos.first.dy);
    for (var i = 1; i < pontos.length; i++) {
      final a = pontos[i - 1], b = pontos[i];
      final m = (a.dx + b.dx) / 2;
      caminho.cubicTo(m, a.dy, m, b.dy, b.dx, b.dy);
    }
    final area = Path.from(caminho)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ambar.withValues(alpha: 0.3), _ambar.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      caminho,
      Paint()
        ..color = _ambar
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (final p in pontos) {
      canvas.drawCircle(p, 4.5, Paint()..color = _cartao);
      canvas.drawCircle(p, 3, Paint()..color = _ambar);
    }
  }

  @override
  bool shouldRepaint(_Curva old) => false;
}

class _VisualDia extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget linha(bool ok, String t, String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(ok ? Icons.check_rounded : Icons.close_rounded, size: 16, color: ok ? _verde : const Color(0xFFFB923C)),
              const SizedBox(width: 8),
              Expanded(child: Text(t, style: AppText.body(13, color: _branco))),
              Text(s, style: AppText.caption(12, color: ok ? _cinza : const Color(0xFFFDBA74))),
            ],
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _ambar.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(value: 0.86, strokeWidth: 5, backgroundColor: _cartao2, color: _ambar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seguiu quase tudo', style: AppText.title(15, color: const Color(0xFFFCD34D))),
                    Text('Ontem · 6 de 7 itens', style: AppText.caption(12, color: _cinza)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        linha(true, 'Treino B — Inferiores', '52 min'),
        linha(true, 'Almoço', '432 kcal'),
        linha(false, 'Lanche da tarde', 'não marcou'),
        linha(true, 'Água', '2,6 de 2,5 L'),
      ],
    );
  }
}

class _VisualChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget balao(String t, bool meu) => Align(
          alignment: meu ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 230),
            decoration: BoxDecoration(
              color: meu ? _vermelho : _cartao2,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(meu ? 16 : 4),
                bottomRight: Radius.circular(meu ? 4 : 16),
              ),
            ),
            child: Text(t, style: AppText.body(13, color: _branco).copyWith(height: 1.35)),
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: _cartao2, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Container(
                width: 38,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(color: _vermelho, borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  const Text('SEX', style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.w700)),
                  Text('14', style: AppText.number(15, color: Colors.white)),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Avaliação física', style: AppText.bodyStrong(13, color: _branco)),
                    Text('17:30 · Academia', style: AppText.caption(12, color: _cinza)),
                  ],
                ),
              ),
              _pilula('confirmada', _verde),
            ],
          ),
        ),
        balao('Posso trocar o arroz por batata-doce?', false),
        balao('Pode! Já deixei como substituto no seu plano 👊', true),
      ],
    );
  }
}

class _VisualFinanceiro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget linha(String n, String v, String s, Color c) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: _cartao2, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              CircleAvatar(radius: 14, backgroundColor: _cartao, child: Text(n.substring(0, 1), style: const TextStyle(fontSize: 12, color: _branco, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(child: Text(n, style: AppText.bodyStrong(13, color: _branco))),
              Text(v, style: AppText.number(13, color: _branco)),
              const SizedBox(width: 10),
              _pilula(s, c),
            ],
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recebido em novembro', style: AppText.caption(12, color: _cinza)),
        Text('R\$ 6.840', style: AppText.number(34, color: _branco)),
        const SizedBox(height: 12),
        linha('Marina', 'R\$ 280', 'paga', _verde),
        linha('Bruno', 'R\$ 335', 'paga', _verde),
        linha('Camila', 'R\$ 390', 'atrasada', const Color(0xFFFB923C)),
      ],
    );
  }
}

// ── Os dois lados ─────────────────────────────────────────────

class _DoisLados extends StatefulWidget {
  const _DoisLados({required this.desktop});
  final bool desktop;

  @override
  State<_DoisLados> createState() => _DoisLadosState();
}

class _DoisLadosState extends State<_DoisLados> {
  bool _aluno = false;

  static const _personal = [
    (Icons.dashboard_customize_outlined, 'Sua carteira numa tela', 'Quem treinou hoje, quem sumiu, quem está com a mensalidade atrasada.'),
    (Icons.edit_note_rounded, 'Monte uma vez, reaproveite', 'Duplique fichas, salve planos como modelo e atribua a vários alunos.'),
    (Icons.insights_rounded, 'Evolução que convence', 'Gráficos de composição corporal e cargas para mostrar resultado na renovação.'),
    (Icons.verified_outlined, 'Prescrição com respaldo', 'Plano alimentar assinado com CRN e PDF com a sua marca.'),
  ];

  static const _alunoItens = [
    (Icons.today_rounded, 'Abre e sabe o que fazer', 'O treino do dia em destaque e a próxima refeição logo abaixo.'),
    (Icons.ondemand_video_rounded, 'Vídeo antes de cada série', 'Execução certa, com cronômetro de descanso e a carga anotada.'),
    (Icons.swap_horiz_rounded, 'Troca sem sair da dieta', 'Substitutos que o personal liberou, com as mesmas calorias.'),
    (Icons.emoji_events_outlined, 'Vontade de voltar amanhã', 'Sequência de semanas, dia completo e a curva do próprio corpo.'),
  ];

  @override
  Widget build(BuildContext context) {
    final itens = _aluno ? _alunoItens : _personal;

    final lista = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey(_aluno),
        children: [
          for (final (icone, titulo, texto) in itens)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _vermelho.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _vermelho.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icone, color: _vermelhoClaro, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: AppText.title(17, color: _branco)),
                        const SizedBox(height: 4),
                        Text(texto, style: AppText.body(14.5, color: _cinza).copyWith(height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final seletor = Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(color: _cartao, borderRadius: BorderRadius.circular(16), border: Border.all(color: _linha)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (aluno, rotulo) in const [(false, 'Para o personal'), (true, 'Para o aluno')])
            GestureDetector(
              onTap: () => setState(() => _aluno = aluno),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: _aluno == aluno ? _vermelho : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(rotulo, style: AppText.bodyStrong(14, color: _aluno == aluno ? Colors.white : _cinza)),
                ),
              ),
            ),
        ],
      ),
    );

    final cabeca = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Etiqueta('Feito para os dois lados'),
        const SizedBox(height: 16),
        const _Titulo('Você trabalha menos.\nEle desiste menos.'),
        const SizedBox(height: 28),
        seletor,
        const SizedBox(height: 36),
        lista,
      ],
    );

    if (!widget.desktop) return cabeca;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: cabeca),
        const SizedBox(width: 64),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: _aluno
                ? const SizedBox(key: ValueKey('a'), height: 560, child: Center(child: _Celular()))
                : const _PainelPersonal(key: ValueKey('p')),
          ),
        ),
      ],
    );
  }
}

/// A home do personal em miniatura: a carteira de alunos com o estado de cada um.
class _PainelPersonal extends StatelessWidget {
  const _PainelPersonal({super.key});

  @override
  Widget build(BuildContext context) {
    Widget aluno(String n, String s, Color c, IconData i, double adesao) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: _cartao2, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _cartao,
                child: Text(n.split(' ').map((p) => p[0]).take(2).join(), style: const TextStyle(fontSize: 12, color: _branco, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n, style: AppText.bodyStrong(14, color: _branco)),
                    Row(children: [
                      Icon(i, size: 13, color: c),
                      const SizedBox(width: 4),
                      Text(s, style: AppText.caption(12, color: c)),
                    ]),
                  ],
                ),
              ),
              SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: adesao, strokeWidth: 4, backgroundColor: _cartao, color: adesao > 0.7 ? _verde : _ambar),
                    Text('${(adesao * 100).round()}', style: AppText.number(10.5, color: _branco)),
                  ],
                ),
              ),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cartao,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _linha),
        boxShadow: [BoxShadow(color: _vermelho.withValues(alpha: 0.12), blurRadius: 60)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alunos', style: AppText.display(26, color: _branco)),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final (v, r, c) in const [('24', 'ativos', _verde), ('11', 'treinaram hoje', _vermelhoClaro), ('3', 'atenção', _ambar)])
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _cartao2, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(radius: 3.5, backgroundColor: c),
                          const SizedBox(width: 6),
                          Text(v, style: AppText.number(20, color: _branco)),
                        ]),
                        Text(r, style: AppText.caption(12, color: _cinza)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          aluno('Marina Costa', 'Treinou hoje', _verde, Icons.check_circle_rounded, 0.92),
          aluno('Bruno Almeida', 'Treinou ontem', _cinza, Icons.history_rounded, 0.78),
          aluno('Camila Ribeiro', '6 dias sem treinar', _ambar, Icons.schedule_rounded, 0.41),
          aluno('Thiago Nunes', 'Mensalidade atrasada', const Color(0xFFFB923C), Icons.payments_outlined, 0.65),
        ],
      ),
    );
  }
}

// ── Notebook ──────────────────────────────────────────────────

class _Notebook extends StatelessWidget {
  const _Notebook({required this.desktop});
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Etiqueta('No celular e no notebook'),
        const SizedBox(height: 16),
        const _Titulo('Monte a dieta com\nespaço de sobra.', centro: true),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'O aluno usa no celular. Você monta no notebook: refeições lado a lado, busca de alimentos sempre aberta e os totais na sua frente o tempo todo.',
            textAlign: TextAlign.center,
            style: AppText.body(16, color: _cinza).copyWith(height: 1.55),
          ),
        ),
        const SizedBox(height: 44),
        const _TelaNotebook(),
      ],
    );
  }
}

class _TelaNotebook extends StatelessWidget {
  const _TelaNotebook();

  @override
  Widget build(BuildContext context) {
    // Desenhada a 1000px e escalada para caber: no celular vira miniatura,
    // mas continua sendo a tela inteira.
    return LayoutBuilder(
      builder: (_, c) {
        final escala = math.min(1.0, c.maxWidth / 1000);
        return SizedBox(
          height: 560 * escala + 26 * escala,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                Container(
                  width: 1000,
                  height: 560,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1F),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                    border: Border.all(color: const Color(0xFF34343C)),
                    boxShadow: [
                      BoxShadow(color: _vermelho.withValues(alpha: 0.18), blurRadius: 90, spreadRadius: -10),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: const ColoredBox(color: Color(0xFF0A0A0B), child: _MontadorMini()),
                  ),
                ),
                Container(
                  width: 1120,
                  height: 26,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF2A2A30), Color(0xFF3A3A42), Color(0xFF2A2A30)]),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MontadorMini extends StatelessWidget {
  const _MontadorMini();

  @override
  Widget build(BuildContext context) {
    Widget menu(String t, bool on) => Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: on ? _vermelho.withValues(alpha: 0.15) : null, borderRadius: BorderRadius.circular(8)),
          child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: on ? _vermelhoClaro : _cinza)),
        );
    Widget item(String n, String q, String k) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: _linha))),
          child: Row(children: [
            Expanded(child: Text(n, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _branco))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _cartao2, borderRadius: BorderRadius.circular(6)),
              child: Text(q, style: const TextStyle(fontSize: 10.5, color: _cinza)),
            ),
            SizedBox(width: 40, child: Text(k, textAlign: TextAlign.right, style: AppText.number(11.5, color: _branco))),
          ]),
        );
    Widget refeicao(String n, String h, String kcal, List<Widget> itens, {bool destino = false}) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: destino ? const Color(0xFF1C1012) : _cartao,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: destino ? _vermelho : _linha, width: destino ? 1.4 : 1),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(color: destino ? _vermelho : _cartao2, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.restaurant_rounded, size: 14, color: destino ? Colors.white : _cinza),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _branco)),
                    Text(destino ? 'recebendo alimentos' : h,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: destino ? _vermelhoClaro : _cinza2)),
                  ]),
                ),
                Text(kcal, style: AppText.number(13, color: _branco)),
              ]),
            ),
            ...itens,
          ]),
        );
    Widget macro(String n, String v, Color c, double p) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: const TextStyle(fontSize: 10.5, color: _cinza)),
            Text(v, style: AppText.number(15, color: _branco)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: p, minHeight: 5, backgroundColor: _cartao2, color: c),
            ),
          ]),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: _cartao, border: Border(right: BorderSide(color: _linha))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Image.asset('assets/images/logo_white.png', height: 18),
            const SizedBox(height: 18),
            menu('Início', false),
            menu('Alunos', true),
            menu('Treinos', false),
            menu('Relatórios', false),
            menu('Perfil', false),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Marina Costa  /  Plano alimentar', style: TextStyle(fontSize: 10.5, color: _cinza2)),
              Text('Recomposição corporal', style: AppText.display(20, color: _branco)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _cartao, borderRadius: BorderRadius.circular(14), border: Border.all(color: _linha)),
                child: Row(children: [
                  const SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(value: 0.88, strokeWidth: 5, backgroundColor: _cartao2, color: _verde),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('1.627 / 1.850 kcal', style: AppText.number(16, color: _branco)),
                    const Text('faltam 223 kcal', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFFCD34D))),
                  ]),
                  const SizedBox(width: 24),
                  macro('Proteína', '153 g', _azul, 0.95),
                  const SizedBox(width: 16),
                  macro('Carboidrato', '183 g', _ambar, 0.9),
                  const SizedBox(width: 16),
                  macro('Gordura', '35 g', _rosa, 0.62),
                ]),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(children: [
                      refeicao('Café da manhã', '07:00', '351', [item('Ovo cozido', '2 unidades', '146'), item('Pão integral', '2 fatias', '127'), item('Banana prata', '1 un.', '78')]),
                      refeicao('Almoço', '12:30', '432', [item('Frango grelhado', '150 g', '239'), item('Arroz integral', '4 col.', '149')]),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(children: [
                      refeicao('Lanche', '16:00', '198', [item('Whey protein', '30 g', '120')]),
                      refeicao('Jantar', '20:00', '309', [item('Tilápia grelhada', '150 g', '192'), item('Batata-doce', '120 g', '92')], destino: true),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        Container(
          width: 250,
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(color: _cartao, border: Border(left: BorderSide(color: _linha))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text.rich(TextSpan(children: [
              TextSpan(text: 'Adicionar em ', style: TextStyle(color: _branco)),
              TextSpan(text: 'Jantar', style: TextStyle(color: _vermelhoClaro)),
            ]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _vermelho)),
              child: const Row(children: [
                Icon(Icons.search_rounded, size: 15, color: _cinza),
                SizedBox(width: 6),
                Text('azeite', style: TextStyle(fontSize: 12, color: _branco, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 10),
            for (final (n, k, sel) in const [
              ('Azeite de oliva', '884 kcal · 100 g', true),
              ('Azeitona verde', '137 kcal · 100 g', false),
              ('Salada com azeite', 'receita · 96 kcal', false),
            ])
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: sel ? _vermelho.withValues(alpha: 0.14) : null, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _branco)),
                      Text(k, style: const TextStyle(fontSize: 10, color: _cinza2)),
                    ]),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: sel ? _vermelho : null,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sel ? _vermelho : _linha),
                    ),
                    child: Icon(Icons.add_rounded, size: 14, color: sel ? Colors.white : _cinza),
                  ),
                ]),
              ),
            const Spacer(),
            Container(
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _vermelho, borderRadius: BorderRadius.circular(10)),
              child: const Text('Adicionar em Jantar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Passos ────────────────────────────────────────────────────

class _Passos extends StatelessWidget {
  const _Passos({required this.desktop});
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    const passos = [
      ('01', 'Crie sua conta', 'Seu nome, sua marca e seu CREF ou CRN. Leva dois minutos.'),
      ('02', 'Cadastre o aluno', 'Ele recebe o acesso e já abre o app com o seu nome e a sua marca.'),
      ('03', 'Monte e acompanhe', 'Treino, dieta e avaliação. Depois é só ver, dia a dia, se ele está seguindo.'),
    ];
    final cartoes = [
      for (final (n, t, d) in passos)
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _cartao,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _linha),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: AppText.display(48, color: _vermelho).copyWith(height: 1)),
              const SizedBox(height: 20),
              Text(t, style: AppText.title(20, color: _branco)),
              const SizedBox(height: 8),
              Text(d, style: AppText.body(14.5, color: _cinza).copyWith(height: 1.5)),
            ],
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Etiqueta('Como começar'),
        const SizedBox(height: 16),
        const _Titulo('Do cadastro ao primeiro\ntreino no mesmo dia.'),
        const SizedBox(height: 40),
        if (desktop)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in cartoes.indexed) ...[
                  if (i > 0) const SizedBox(width: 16),
                  Expanded(child: c),
                ],
              ],
            ),
          )
        else
          for (final c in cartoes) Padding(padding: const EdgeInsets.only(bottom: 14), child: c),
      ],
    );
  }
}

// ── Chamada final ─────────────────────────────────────────────

class _Chamada extends StatelessWidget {
  const _Chamada({required this.desktop});
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 680;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: estreito ? 24 : 56, vertical: estreito ? 44 : 64),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEF4444), Color(0xFF991B1B)],
        ),
        boxShadow: [BoxShadow(color: _vermelho.withValues(alpha: 0.35), blurRadius: 80, offset: const Offset(0, 20))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: estreito ? -40 : 0,
            top: -20,
            bottom: -20,
            child: Opacity(
              opacity: 0.12,
              child: Image.asset('assets/images/logo_white.png', height: estreito ? 120 : 220, fit: BoxFit.contain),
            ),
          ),
          Column(
            crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Text(
                'Seu próximo aluno já\npode treinar no app.',
                textAlign: desktop ? TextAlign.start : TextAlign.center,
                style: AppText.display(estreito ? 32 : 48, color: Colors.white).copyWith(height: 1.05),
              ),
              const SizedBox(height: 16),
              Text(
                'Crie sua conta, cadastre um aluno e monte o primeiro treino hoje.',
                textAlign: desktop ? TextAlign.start : TextAlign.center,
                style: AppText.body(17, color: Colors.white.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: desktop ? WrapAlignment.start : WrapAlignment.center,
                children: [
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => context.go('/cadastro'),
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Criar minha conta', style: AppText.bodyStrong(15.5, color: _vermelho)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 18, color: _vermelho),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _Botao('Entrar', primario: false, onTap: () => context.go('/login')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape();

  @override
  Widget build(BuildContext context) {
    final estreito = MediaQuery.sizeOf(context).width < 680;
    return Container(
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _linha))),
      padding: EdgeInsets.symmetric(horizontal: estreito ? 20 : 32, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _larguraMax),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 14,
            spacing: 24,
            children: [
              Image.asset('assets/images/logo_white.png', height: 22),
              Text('Aluno? Seu acesso é criado pelo seu personal.', style: AppText.caption(13, color: _cinza2)),
              Text('© ${DateTime.now().year} PHD Training & Nutrition', style: AppText.caption(13, color: _cinza2)),
            ],
          ),
        ),
      ),
    );
  }
}
