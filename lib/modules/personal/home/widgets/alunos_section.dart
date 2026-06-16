import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/services/aluno_service.dart';

class AlunosSection extends StatefulWidget {
  const AlunosSection({super.key});

  @override
  State<AlunosSection> createState() => _AlunosSectionState();
}

class _AlunosSectionState extends State<AlunosSection> {
  int _ativos = 0;
  int _inativos = 0;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final contagem = await AlunoService.contagem();
      if (mounted) {
        setState(() {
          _ativos = contagem['ativos'] ?? 0;
          _inativos = contagem['inativos'] ?? 0;
          _carregando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.alunos,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _carregando
            ? const SizedBox(
                height: 30,
                child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
              )
            : Row(
                children: [
                  _buildBadge(label: AppStrings.ativos, count: _ativos, color: AppColors.active),
                  const SizedBox(width: 10),
                  _buildBadge(label: AppStrings.inativos, count: _inativos, color: AppColors.inactive),
                ],
              ),
      ],
    );
  }

  Widget _buildBadge({required String label, required int count, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          Text('$count', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
