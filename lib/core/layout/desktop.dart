import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';

/// A partir desta largura o personal está num notebook ou monitor, e as
/// telas que têm layout próprio de desktop passam a usá-lo.
///
/// Abaixo dela nada muda: o app continua sendo o de celular.
const double kLarguraDesktop = 1100;

bool ehDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kLarguraDesktop;

/// Rotas com layout de desktop. As demais continuam na coluna de celular
/// centralizada mesmo numa janela larga — esticar uma tela pensada para
/// 390px é pior do que deixá-la estreita.
const rotasComDesktop = {
  '/home',
  '/alunos',
  '/fichas',
  '/exercicios',
  '/relatorios',
  '/perfil',
  '/alunos/dieta/montar',
};

/// O caminho da tela que está no topo, inclusive as abertas com `push`.
String rotaNoTopo(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  if (config.isEmpty) return '';
  return config.last.matchedLocation;
}

/// No navegador a janela pode ter 2000px, e um campo de e-mail esticado nessa
/// largura é impossível de usar — o olho perde a linha entre o rótulo e o
/// campo. O app é desenhado para 390px, então acima de [maxLargura] ele para
/// de crescer e fica centralizado, com o fundo preenchendo o resto.
///
/// A exceção são as [rotasComDesktop] numa janela de desktop: essas recebem
/// a largura inteira e cuidam do próprio layout.
class LarguraDeLeitura extends StatelessWidget {
  const LarguraDeLeitura({super.key, required this.router, required this.child});

  static const double maxLargura = 480;

  final GoRouter router;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final livre = ehDesktop(context) && rotasComDesktop.contains(rotaNoTopo(router));
        // A árvore é a mesma nos dois casos, só muda o limite: trocar a
        // estrutura recriaria o Navigator e perderia a pilha de telas.
        return ColoredBox(
          color: AppColors.bg,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: livre ? double.infinity : maxLargura),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
