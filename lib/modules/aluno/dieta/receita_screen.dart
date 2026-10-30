import 'package:flutter/material.dart';
import '../../../core/models/dieta.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Uma receita do plano, vista pelo aluno.
///
/// Os ingredientes começam na quantidade da **porção dele**, não da receita
/// inteira: é o que ele vai pôr no prato. Quem cozinha para a semana troca
/// para a receita inteira.
class ReceitaScreen extends StatefulWidget {
  const ReceitaScreen({
    super.key,
    required this.receita,
    this.porcoes = 1,
    this.mostrarNumeros = true,
  });

  final Receita receita;

  /// Porções prescritas na refeição.
  final double porcoes;

  /// Calorias e macros — desligado quando o profissional escondeu os
  /// números deste aluno.
  final bool mostrarNumeros;

  @override
  State<ReceitaScreen> createState() => _ReceitaScreenState();
}

class _ReceitaScreenState extends State<ReceitaScreen> {
  bool _inteira = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.receita;
    final fator = _inteira
        ? 1.0
        : widget.porcoes / (r.rendimentoPorcoes <= 0 ? 1 : r.rendimentoPorcoes);
    final p = r.porPorcao;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Receita', style: AppText.title(16)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
        children: [
          Text(r.nome, style: AppText.display(28)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              PhdStatusChip(label: 'Rende ${r.rendimentoTexto}'),
              if (r.tempoMinutos != null)
                PhdStatusChip(label: '${r.tempoMinutos} min'),
              PhdStatusChip(
                label: 'Sua porção: ${porcoesTexto(widget.porcoes)}',
                tone: PhdTone.accent,
              ),
            ],
          ),
          if (widget.mostrarNumeros) ...[
            const SizedBox(height: AppSpacing.lg),
            PhdCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(child: _macro('kcal', p.kcal, destaque: true)),
                  Expanded(child: _macro('Prot.', p.proteina, unidade: 'g')),
                  Expanded(child: _macro('Carb.', p.carboidrato, unidade: 'g')),
                  Expanded(child: _macro('Gord.', p.gordura, unidade: 'g')),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text('Por porção',
                style: AppText.caption(11.5, color: AppColors.textMuted)),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              const Expanded(child: PhdSectionHeader(label: 'Ingredientes')),
              PhdFilterChip(
                label: 'Sua porção',
                selected: !_inteira,
                onTap: () => setState(() => _inteira = false),
              ),
              const SizedBox(width: 6),
              PhdFilterChip(
                label: 'Receita inteira',
                selected: _inteira,
                onTap: () => setState(() => _inteira = true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PhdCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                for (final (n, i) in r.ingredientes.indexed) ...[
                  if (n > 0) Divider(height: 1, color: AppColors.line),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(i.alimento.rotulo,
                                style: AppText.body(14))),
                        Text(_gramas(i.quantidadeG * fator),
                            style: AppText.number(13.5)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (r.modoPreparo?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xl),
            const PhdSectionHeader(label: 'Modo de preparo'),
            const SizedBox(height: AppSpacing.sm),
            PhdCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(r.modoPreparo!.trim(), style: AppText.body(14.5)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _macro(String rotulo, double v,
          {String unidade = '', bool destaque = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo.toUpperCase(), style: AppText.label()),
          const SizedBox(height: 4),
          Text(
            '${v.round()}${unidade.isEmpty ? '' : ' $unidade'}',
            style: AppText.number(destaque ? 20 : 16,
                color: destaque ? AppColors.accent : AppColors.textPrimary,
                weight: FontWeight.w800),
          ),
        ],
      );

  static String _gramas(double g) {
    if (g >= 1000) {
      return '${(g / 1000).toStringAsFixed(2).replaceAll('.', ',')} kg';
    }
    return '${g.round()} g';
  }
}
