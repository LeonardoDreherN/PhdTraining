import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';

class PersonalShell extends StatelessWidget {
  final Widget child;
  const PersonalShell({super.key, required this.child});

  static const _tabs = [
    ('/home', Icons.home_outlined, Icons.home, 'Início'),
    ('/exercicios', Icons.fitness_center_outlined, Icons.fitness_center, 'Treinos'),
    ('/alunos', Icons.people_outline, Icons.people, 'Alunos'),
    ('/relatorios', Icons.bar_chart_outlined, Icons.bar_chart, 'Relatórios'),
    ('/perfil', Icons.person_outline, Icons.person, 'Perfil'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (var i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bottomNav,
          border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final selected = i == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => context.go(tab.$1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? tab.$3 : tab.$2,
                          color: selected ? AppColors.primary : AppColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.$4,
                          style: TextStyle(
                            color: selected ? AppColors.primary : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
