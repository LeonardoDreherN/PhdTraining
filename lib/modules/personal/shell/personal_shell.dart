import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';

class PersonalShell extends StatelessWidget {
  const PersonalShell({super.key, required this.child});

  final Widget child;

  static const _abas = <_Aba>[
    _Aba('/home', Icons.home_outlined, Icons.home_rounded, 'Início'),
    _Aba('/alunos', Icons.people_outline_rounded, Icons.people_rounded, 'Alunos'),
    // A aba Treinos abre as fichas, mas também fica acesa na biblioteca de
    // exercícios — senão, entrar na biblioteca acenderia "Início" e a
    // pessoa perderia a noção de onde está.
    _Aba('/fichas', Icons.fitness_center_outlined, Icons.fitness_center_rounded,
        'Treinos', ['/exercicios']),
    _Aba('/relatorios', Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Relatórios'),
    _Aba('/perfil', Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  int _indiceAtual(BuildContext context) {
    final rota = GoRouterState.of(context).uri.path;
    for (var i = 0; i < _abas.length; i++) {
      if (_abas[i].cobre(rota)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final atual = _indiceAtual(context);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _abas.length; i++)
                  Expanded(
                    child: _BotaoAba(
                      aba: _abas[i],
                      selecionado: i == atual,
                      // `go` e não `push`: as abas trocam a tela, não
                      // empilham. Com push, o botão "voltar" do navegador
                      // percorreria todas as abas já visitadas.
                      onTap: () => context.go(_abas[i].rota),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Aba {
  const _Aba(this.rota, this.icone, this.iconeCheio, this.rotulo,
      [this.tambem = const []]);

  /// Para onde o toque leva.
  final String rota;

  /// Outras rotas que mantêm esta aba acesa.
  final List<String> tambem;

  final IconData icone;
  final IconData iconeCheio;
  final String rotulo;

  bool cobre(String caminho) =>
      caminho.startsWith(rota) || tambem.any(caminho.startsWith);
}

class _BotaoAba extends StatelessWidget {
  const _BotaoAba({
    required this.aba,
    required this.selecionado,
    required this.onTap,
  });

  final _Aba aba;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cor = selecionado ? AppColors.accent : AppColors.textMuted;

    return Semantics(
      button: true,
      selected: selecionado,
      label: aba.rotulo,
      child: InkWell(
        onTap: onTap,
        // Sem respingo nem realce: numa barra de 5 itens, o retângulo cinza
        // do Material aparece antes da troca de tela e parece travamento.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selecionado ? 1 : 0.94,
              duration: AppDuration.fast,
              child: Icon(
                selecionado ? aba.iconeCheio : aba.icone,
                size: 22,
                color: cor,
              ),
            ),
            const SizedBox(height: AppSpacing.xs + 1),
            Text(
              aba.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: selecionado
                  ? AppText.bodyStrong(10.5, color: cor)
                  : AppText.caption(10.5, color: cor),
            ),
          ],
        ),
      ),
    );
  }
}
