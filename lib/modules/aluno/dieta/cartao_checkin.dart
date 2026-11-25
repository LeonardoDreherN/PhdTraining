import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/checkin.dart';
import '../../../core/services/acompanhamento_service.dart';
import '../../../core/services/checkin_service.dart';
import '../../../core/services/progresso_service.dart';
import '../../../core/services/feed_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';
import '../conquistas/festa_conquista.dart';
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

  /// O que o profissional pede a este aluno. Sem a 0034, os padrões.
  ConfigAcompanhamento _config = const ConfigAcompanhamento();

  /// Já enviou foto de acompanhamento neste mês?
  bool _fotoDoMes = false;

  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final (c, config) = await (
        CheckinService.doMes(widget.alunoId),
        AcompanhamentoService.doAluno(widget.alunoId)
            .catchError((_) => const ConfigAcompanhamento()),
      ).wait;

      // A lista de fotos só é buscada se o profissional pediu — não há
      // motivo para uma ida ao servidor por um cartão que não aparece.
      var temFoto = false;
      if (config.fotosMensais) {
        try {
          final fotos = await ProgressoService.listarFotos(widget.alunoId);
          final agora = DateTime.now();
          temFoto = fotos.any((f) {
            final d = DateTime.tryParse(f['registrado_em'] as String? ?? '');
            return d != null && d.year == agora.year && d.month == agora.month;
          });
        } catch (_) {
          // Sem a lista, o cartão aparece como pendente: pior caso, o
          // aluno abre a tela de progresso e vê que já enviou.
        }
      }

      if (mounted) {
        setState(() {
          _c = c;
          _config = config;
          _fotoDoMes = temFoto;
        });
      }
    } catch (_) {
      // Sem check-in carregado o cartão se oferece como pendente, que é
      // o estado menos errado dos dois: o pior caso é o aluno abrir o
      // formulário e ver o que já havia respondido.
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrir() async {
    final novas = await abrirCheckin(
      context,
      alunoId: widget.alunoId,
      existente: _c,
    );
    if (novas == null) return;

    await _carregar();

    if (novas.isNotEmpty) {
      try {
        await FeedService.publicarConquistas(widget.alunoId);
      } catch (_) {
        // O feed publica na próxima abertura; a medalha já é do aluno.
      }
      if (mounted) await celebrarConquistas(context, novas);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nada de esqueleto nem spinner enquanto carrega: o cartão aparecer
    // meio segundo depois é melhor do que a tela pular duas vezes.
    if (_carregando) return const SizedBox.shrink();

    final mostraCheckin = _config.checkinMensal;
    final mostraFoto = _config.fotosMensais;
    if (!mostraCheckin && !mostraFoto) return const SizedBox.shrink();

    return Column(
      children: [
        if (mostraCheckin) _cartaoCheckin(),
        if (mostraCheckin && mostraFoto) const SizedBox(height: AppSpacing.md),
        if (mostraFoto) _cartaoFoto(),
      ],
    );
  }

  /// O pedido de fotos do mês.
  ///
  /// Só existe quando o profissional pediu — é o pedido que a conquista
  /// "Aluno disciplinado" atende, e sem ele na tela do aluno a medalha
  /// seria por algo que ninguém falou que precisava fazer.
  Widget _cartaoFoto() {
    return Padding(
      padding: AppSpacing.screen,
      child: PhdCard(
        onTap: () => context.push('/aluno/progresso'),
        accentBar: _fotoDoMes ? null : AppColors.accent,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.tint(
                    _fotoDoMes ? AppColors.success : AppColors.accent),
                borderRadius: AppRadius.rMd,
              ),
              child: Icon(
                _fotoDoMes
                    ? Icons.photo_library_rounded
                    : Icons.photo_camera_outlined,
                size: 21,
                color: _fotoDoMes ? AppColors.successText : AppColors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _fotoDoMes
                        ? 'Fotos do mês enviadas'
                        : 'Fotos de acompanhamento',
                    style: AppText.bodyStrong(13.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _fotoDoMes
                        ? 'Toque para ver ou enviar outra.'
                        : 'Seu profissional pede as fotos deste mês.',
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

  Widget _cartaoCheckin() {
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
