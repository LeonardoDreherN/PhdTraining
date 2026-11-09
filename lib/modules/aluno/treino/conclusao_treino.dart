import 'package:flutter/material.dart';
import '../../../core/services/treino_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';

/// A tela de fim de treino — o momento de dizer "você fez".
///
/// Antes era um diálogo com três números. Terminar o treino é a hora em que
/// o aluno está mais orgulhoso; é aqui que a sequência de semanas e os
/// treinos do mês fazem ele querer voltar amanhã.
Future<void> mostrarConclusao(
  BuildContext context, {
  required String ficha,
  required int exercicios,
  required int minutos,
  int? series,
  String? falha,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: AppDuration.normal,
      pageBuilder: (_, __, ___) => _TelaConclusao(
        ficha: ficha,
        exercicios: exercicios,
        minutos: minutos < 1 ? 1 : minutos,
        series: series,
        falha: falha,
      ),
      transitionsBuilder: (_, a, __, filho) => FadeTransition(opacity: a, child: filho),
    ),
  );
}

class _TelaConclusao extends StatefulWidget {
  const _TelaConclusao({
    required this.ficha,
    required this.exercicios,
    required this.minutos,
    this.series,
    this.falha,
  });

  final String ficha;
  final int exercicios;
  final int minutos;
  final int? series;

  /// Preenchido quando o treino não foi gravado — aí não há festa: o aluno
  /// precisa saber que o personal não vai ver este treino.
  final String? falha;

  @override
  State<_TelaConclusao> createState() => _TelaConclusaoState();
}

class _TelaConclusaoState extends State<_TelaConclusao> {
  ({int semanas, int noMes})? _marcas;

  bool get _ok => widget.falha == null;

  @override
  void initState() {
    super.initState();
    if (_ok) _carregarMarcas();
  }

  /// Sequência de semanas com treino (contando a atual) e treinos no mês.
  Future<void> _carregarMarcas() async {
    try {
      final execs = await TreinoService.execucoesRecentes();
      final agora = DateTime.now();
      DateTime segundaDe(DateTime d) => Datas.dia(d).subtract(Duration(days: d.weekday - 1));
      final semanas = {for (final e in execs) segundaDe(e.quando)}..add(segundaDe(agora));
      var n = 0;
      var s = segundaDe(agora);
      while (semanas.contains(s)) {
        n++;
        s = s.subtract(const Duration(days: 7));
      }
      final noMes = execs.where((e) => e.quando.year == agora.year && e.quando.month == agora.month).length;
      if (mounted) setState(() => _marcas = (semanas: n, noMes: noMes));
    } catch (_) {
      // As marcas são o bônus da tela: sem elas, os números do treino bastam.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cor = _ok ? AppColors.success : AppColors.warning;
    final m = _marcas;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.huge, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.elasticOut,
                  builder: (_, v, filho) => Transform.scale(scale: v, child: filho),
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.tint(cor),
                      border: Border.all(color: cor, width: 3),
                    ),
                    child: Icon(_ok ? Icons.check_rounded : Icons.cloud_off_rounded, color: cor, size: 56),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                _ok ? 'Treino concluído!' : 'Treino feito, mas não salvo',
                textAlign: TextAlign.center,
                style: AppText.display(28),
              ),
              const SizedBox(height: 6),
              Text(widget.ficha, textAlign: TextAlign.center, style: AppText.body(15, color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(child: _numero('${widget.exercicios}', 'exercícios')),
                  if (widget.series != null && widget.series! > 0) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _numero('${widget.series}', 'séries')),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _numero('${widget.minutos}', 'minutos')),
                ],
              ),
              if (_ok && m != null) ...[
                const SizedBox(height: AppSpacing.md),
                PhdCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: AppColors.energy, size: 34),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.semanas <= 1
                                  ? 'Semana começada'
                                  : '${m.semanas}ª semana seguida',
                              style: AppText.title(16),
                            ),
                            Text(
                              '${m.noMes} ${m.noMes == 1 ? 'treino' : 'treinos'} neste mês. '
                              '${m.semanas <= 1 ? 'Volte na próxima semana para começar a sequência.' : 'Não quebre a corrente.'}',
                              style: AppText.caption(13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!_ok) ...[
                const SizedBox(height: AppSpacing.lg),
                PhdAviso(
                  texto: 'Não consegui registrar este treino, então seu personal não vai vê-lo: ${widget.falha}',
                  cor: AppColors.warning,
                ),
              ],
              const Spacer(),
              PhdButton(
                label: _ok ? 'Fechar' : 'Entendi',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numero(String valor, String rotulo) => PhdCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          children: [
            Text(valor, style: AppText.number(28)),
            Text(rotulo, style: AppText.caption(12.5)),
          ],
        ),
      );
}
