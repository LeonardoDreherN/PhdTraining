import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';

/// Um destino da navegação principal do personal — o mesmo conjunto vira a
/// barra de baixo no celular e o menu lateral no desktop.
class AbaPersonal {
  const AbaPersonal(this.rota, this.icone, this.iconeCheio, this.rotulo, [this.tambem = const []]);

  /// Para onde o toque leva.
  final String rota;

  /// Outras rotas que mantêm esta aba acesa.
  final List<String> tambem;

  final IconData icone;
  final IconData iconeCheio;
  final String rotulo;

  bool cobre(String caminho) => caminho.startsWith(rota) || tambem.any(caminho.startsWith);

  static const todas = <AbaPersonal>[
    AbaPersonal('/home', Icons.home_outlined, Icons.home_rounded, 'Início'),
    AbaPersonal('/alunos', Icons.people_outline_rounded, Icons.people_rounded, 'Alunos'),
    // A aba Treinos abre as fichas, mas também fica acesa na biblioteca de
    // exercícios — senão, entrar na biblioteca acenderia "Início" e a
    // pessoa perderia a noção de onde está.
    AbaPersonal('/fichas', Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Treinos', ['/exercicios']),
    AbaPersonal('/relatorios', Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Relatórios'),
    AbaPersonal('/perfil', Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  static int indiceDe(String caminho) {
    for (var i = 0; i < todas.length; i++) {
      if (todas[i].cobre(caminho)) return i;
    }
    return 0;
  }
}

/// Menu fixo à esquerda, no lugar da barra de baixo, quando a janela é de
/// desktop. Telas fora do Shell (o montador de dieta) também o usam, para o
/// personal não perder a navegação ao entrar nelas.
class MenuLateral extends StatelessWidget {
  const MenuLateral({super.key, required this.caminho});

  /// Rota atual — decide qual item fica aceso.
  final String caminho;

  static const double largura = 232;

  @override
  Widget build(BuildContext context) {
    final atual = AbaPersonal.indiceDe(caminho);

    return Container(
      width: largura,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                  child: Text('PHD', style: AppText.display(12, color: AppColors.onAccent)),
                ),
                const SizedBox(width: AppSpacing.md),
                Text('PHD Training', style: AppText.display(16)),
              ],
            ),
          ),
          for (var i = 0; i < AbaPersonal.todas.length; i++)
            _Item(
              aba: AbaPersonal.todas[i],
              selecionado: i == atual,
              onTap: () => context.go(AbaPersonal.todas[i].rota),
            ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.aba, required this.selecionado, required this.onTap});

  final AbaPersonal aba;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cor = selecionado ? AppColors.accent : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selecionado ? AppColors.tint(AppColors.accent) : Colors.transparent,
        borderRadius: AppRadius.rMd,
        child: InkWell(
          borderRadius: AppRadius.rMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 11),
            child: Row(
              children: [
                Icon(selecionado ? aba.iconeCheio : aba.icone, size: 20, color: cor),
                const SizedBox(width: AppSpacing.md),
                Text(aba.rotulo, style: AppText.bodyStrong(13.5, color: cor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
