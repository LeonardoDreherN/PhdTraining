import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/desktop.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import 'menu_lateral.dart';

class PersonalShell extends StatelessWidget {
  const PersonalShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final caminho = GoRouterState.of(context).uri.path;
    final atual = AbaPersonal.indiceDe(caminho);
    final desktop = ehDesktop(context);
    const abas = AbaPersonal.todas;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // No desktop o menu vai para a esquerda e o conteúdo (telas desenhadas
      // para celular) fica numa coluna centralizada. A árvore é a mesma nos
      // dois casos — só muda o limite — para a tela não ser recriada quando
      // a janela cruza a largura de desktop.
      body: Row(
        children: [
          if (desktop) MenuLateral(caminho: caminho),
          Expanded(
            key: const ValueKey('conteudo'),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: desktop ? 620 : double.infinity),
                child: child,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: desktop ? null : Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < abas.length; i++)
                  Expanded(
                    child: _BotaoAba(
                      aba: abas[i],
                      selecionado: i == atual,
                      // `go` e não `push`: as abas trocam a tela, não
                      // empilham. Com push, o botão "voltar" do navegador
                      // percorreria todas as abas já visitadas.
                      onTap: () => context.go(abas[i].rota),
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

class _BotaoAba extends StatelessWidget {
  const _BotaoAba({
    required this.aba,
    required this.selecionado,
    required this.onTap,
  });

  final AbaPersonal aba;
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
