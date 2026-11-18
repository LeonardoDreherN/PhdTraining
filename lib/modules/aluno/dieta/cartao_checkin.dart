import 'package:flutter/material.dart';

import '../../../core/models/checkin.dart';
import '../../../core/services/checkin_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';
import 'checkin_sheet.dart';

/// O cartão do check-in mensal na casa do aluno.
///
/// Carrega o próprio dado, como o cartão de água: a casa do aluno já
/// busca sete coisas, e enfiar a oitava no `_carregar` dela deixa a tela
/// esperando o item mais lento de todos.
///
/// Quando o mês já foi respondido o cartão NÃO desaparece — fica
/// discreto, mostrando o que foi dito e permitindo corrigir. Sumir
/// seria tirar do aluno o único lugar onde ele vê o que relatou.
class CartaoCheckin extends StatefulWidget {
  const CartaoCheckin({super.key, required this.alunoId});

  final String alunoId;

  @override
  State<CartaoCheckin> createState() => _CartaoCheckinState();
}

class _CartaoCheckinState extends State<CartaoCheckin> {
  CheckinNutricional? _c;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final c = await CheckinService.doMes(widget.alunoId);
      if (mounted) setState(() => _c = c);
    } catch (_) {
      // Sem check-in carregado o cartão se oferece como pendente, que é
      // o estado menos errado dos dois: o pior caso é o aluno abrir o
      // formulário e ver o que já havia respondido.
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrir() async {
    final enviou = await abrirCheckin(
      context,
      alunoId: widget.alunoId,
      existente: _c,
    );
    if (enviou) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    // Nada de esqueleto nem spinner enquanto carrega: o cartão aparecer
    // meio segundo depois é melhor do que a tela pular duas vezes.
    if (_carregando) return const SizedBox.shrink();

    final feito = _c != null;

    return Padding(
      padding: AppSpacing.screen,
      child: PhdCard(
        onTap: _abrir,
        accentBar: feito ? null : AppColors.accent,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.tint(feito ? AppColors.success : AppColors.accent),
                borderRadius: AppRadius.rMd,
              ),
              child: Icon(
                feito ? Icons.task_alt_rounded : Icons.assignment_outlined,
                size: 21,
                color: feito ? AppColors.successText : AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    feito
                        ? 'Check-in de ${_c!.mesNome} enviado'
                        : 'Check-in de ${Datas.mesAno(CheckinNutricional.mesAtual())}',
                    style: AppText.bodyStrong(13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feito
                        ? _c!.adesaoRotulo
                        : 'Conte como foi o mês — leva um minuto.',
                    style: AppText.caption(11.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 19, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
