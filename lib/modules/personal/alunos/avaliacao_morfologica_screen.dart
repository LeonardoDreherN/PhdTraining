import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class AvaliacaoMorfologicaScreen extends StatelessWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoMorfologicaScreen({super.key, required this.aluno});

  @override
  Widget build(BuildContext context) {
    final protocolos = [
      const _Protocolo(
        id: 'dobras',
        label: 'Dobras',
        desc: 'Avaliação de gordura corporal por medidas de dobras cutâneas',
        icon: Icons.straighten_rounded,
      ),
      const _Protocolo(
        id: 'bioimpedancia',
        label: 'Bioimpedância',
        desc: 'Análise de gordura e massa muscular por corrente elétrica',
        icon: Icons.electrical_services_rounded,
      ),
      const _Protocolo(
        id: 'personalizada',
        label: 'Personalizada',
        desc: 'Cria um modelo de avaliação adaptado ao aluno',
        icon: Icons.tune_rounded,
      ),
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
            Text(
              aluno['nome'] as String? ?? 'Aluno',
              style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Morfológica',
              style: GoogleFonts.montserrat(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 14),
              child: Text(
                'Escolha o protocolo:',
                style: GoogleFonts.montserrat(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ...protocolos.map((p) => _buildCard(context, p)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _Protocolo p) {
    final ativo = p.id == 'dobras' || p.id == 'bioimpedancia';
    return GestureDetector(
      onTap: () {
        if (p.id == 'dobras') {
          context.push('/alunos/avaliacao/morfologica/dobras', extra: aluno);
        } else if (p.id == 'bioimpedancia') {
          context.push('/alunos/avaliacao/morfologica/bioimpedancia', extra: aluno);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${p.label} — em breve',
                  style: GoogleFonts.montserrat(color: Colors.black)),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
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
                color: ativo
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.divider.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                p.icon,
                color: ativo ? AppColors.primary : AppColors.textHint,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.label,
                    style: GoogleFonts.montserrat(
                      color: ativo ? AppColors.textPrimary : AppColors.textHint,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.desc,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: ativo ? AppColors.textSecondary : AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Protocolo {
  final String id;
  final String label;
  final String desc;
  final IconData icon;
  const _Protocolo(
      {required this.id,
      required this.label,
      required this.desc,
      required this.icon});
}
