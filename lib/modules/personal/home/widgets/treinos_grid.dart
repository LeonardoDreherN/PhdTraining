import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../relatorios/frequencia_screen.dart';

class _GridItem {
  final String label;
  final IconData icon;
  final String? route;
  final Widget Function(BuildContext)? push;

  const _GridItem({required this.label, required this.icon, this.route, this.push});
}

class TreinosGrid extends StatelessWidget {
  const TreinosGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      const _GridItem(label: AppStrings.bibliotecaDeTreinos, icon: Icons.fitness_center, route: '/fichas'),
      const _GridItem(label: AppStrings.grupoDeDesafio, icon: Icons.groups),
      _GridItem(
        label: AppStrings.relatorioFrequencia,
        icon: Icons.bar_chart,
        push: (_) => const FrequenciaScreen(),
      ),
      const _GridItem(label: AppStrings.bibliotecaExercicios, icon: Icons.menu_book, route: '/exercicios'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _GridCard(item: items[index]),
    );
  }
}

class _GridCard extends StatelessWidget {
  final _GridItem item;

  const _GridCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.push != null
          ? () => Navigator.push(context, MaterialPageRoute(builder: item.push!))
          : item.route != null
              ? () => context.push(item.route!)
              : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha:0.12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary.withValues(alpha:0.3), width: 1),
              ),
              child: Icon(item.icon, color: AppColors.primary, size: 22),
            ),
            Text(
              item.label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
