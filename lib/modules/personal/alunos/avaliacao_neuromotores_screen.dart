import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class AvaliacaoNeuromotoresScreen extends StatelessWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoNeuromotoresScreen({super.key, required this.aluno});

  @override
  Widget build(BuildContext context) {
    final subcats = [
      const _Sub('flexibilidade', 'Flexibilidade', 'Banco de Wells',
          Icons.self_improvement_rounded),
      const _Sub('resistencia', 'Resistência', 'Abdominal / Braços',
          Icons.fitness_center_rounded),
      const _Sub('impulsao', 'Impulsão', 'Horizontal / Vertical',
          Icons.arrow_upward_rounded),
      const _Sub('carga', 'Carga Máxima', 'Repetição máxima (1RM)',
          Icons.monitor_weight_rounded),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aluno['nome'] as String? ?? 'Aluno',
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text('Neuromotores e Flexibilidade',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: subcats.map((s) => _buildCard(context, s)).toList(),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _Sub s) {
    return GestureDetector(
      onTap: () => context.push(
          '/alunos/avaliacao/neuromotores/${s.id}',
          extra: aluno),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(s.icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.label,
                      style: GoogleFonts.montserrat(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(s.sub,
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Sub {
  final String id, label, sub;
  final IconData icon;
  const _Sub(this.id, this.label, this.sub, this.icon);
}
