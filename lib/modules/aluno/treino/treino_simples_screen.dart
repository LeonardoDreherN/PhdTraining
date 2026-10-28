import 'package:flutter/material.dart';
import '../../../core/models/ficha_exercicio.dart';
import '../../../core/services/execucao_service.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Modo "só a lista": para quem já sabe o treino de cor e não quer ser
/// conduzido série a série.
///
/// Mesmo sem o passo a passo, o aluno marca o que fez. Sem isso o personal
/// recebia uma execução de zero minuto e zero exercício — ou seja, ficava
/// sabendo que o aluno treinou e nada mais.
class TreinoSimplesScreen extends StatefulWidget {
  const TreinoSimplesScreen({super.key, required this.ficha});

  final Map<String, dynamic> ficha;

  @override
  State<TreinoSimplesScreen> createState() => _TreinoSimplesScreenState();
}

class _TreinoSimplesScreenState extends State<TreinoSimplesScreen> {
  List<FichaExercicio> _itens = [];
  final Set<String> _feitos = {};

  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  /// Conta desde que a tela abriu. A versão anterior gravava
  /// `duracaoMinutos: 0` fixo, então todo treino deste modo aparecia como
  /// zero minuto no relatório do personal.
  final _abertura = DateTime.now();

  String get _nomeFicha => widget.ficha['nome'] as String? ?? 'Treino';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await FichaService.listarExercicios(
        widget.ficha['id'] as String,
      );
      if (mounted) setState(() => _itens = lista);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  int get _totalSeries => _itens.fold<int>(0, (s, e) => s + e.series);

  Future<void> _concluir() async {
    setState(() => _salvando = true);
    final minutos = DateTime.now().difference(_abertura).inMinutes;

    try {
      await ExecucaoService.salvar(
        fichaId: widget.ficha['id'].toString(),
        fichaNome: _nomeFicha,
        // Sem carga por série — este modo não pergunta — mas ao menos o
        // personal fica sabendo quais exercícios o aluno marcou.
        detalhes: [
          for (final e in _itens.where((e) => _feitos.contains(e.id)))
            {
              'exercicio_id': e.exercicioId,
              'exercicio_nome': e.nome,
              'grupo_muscular': e.grupoMuscular ?? '',
              'series': const <Map<String, dynamic>>[],
            },
        ],
        duracaoMinutos: minutos < 1 ? 1 : minutos,
        totalExercicios: _feitos.isEmpty ? _itens.length : _feitos.length,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Não consegui registrar o treino: $e',
              style: AppText.body(13.5, color: AppColors.onAccent)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(_nomeFicha, style: AppText.title(17)),
      ),
      body: SafeArea(top: false, child: _corpo()),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: _erro!,
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }
    if (_itens.isEmpty) {
      return PhdEmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'Treino vazio',
        message: 'Seu personal ainda não montou os exercícios desta ficha.',
        actionLabel: 'Voltar',
        onAction: () => Navigator.of(context).pop(),
      );
    }

    return Column(
      children: [
        _resumo(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg,
            ),
            itemCount: _itens.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _linha(_itens[i], i),
          ),
        ),
        _rodape(),
      ],
    );
  }

  Widget _resumo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg,
      ),
      child: Row(
        children: [
          Text(
            '${_itens.length} ${_itens.length == 1 ? 'exercício' : 'exercícios'}'
            '  ·  $_totalSeries séries',
            style: AppText.caption(12.5),
          ),
          const Spacer(),
          if (_feitos.isNotEmpty)
            Text('${_feitos.length} marcados',
                style: AppText.caption(12.5, color: AppColors.success)),
        ],
      ),
    );
  }

  Widget _linha(FichaExercicio item, int i) {
    final feito = _feitos.contains(item.id);
    final detalhes = <String>[
      item.prescricao,
      if (item.cargaFormatada != null) item.cargaFormatada!,
      if (item.descansoFormatado != null) item.descansoFormatado!,
    ];
    final obs = item.observacoes?.trim();

    return PhdCard(
      onTap: () => setState(() {
        if (feito) {
          _feitos.remove(item.id);
        } else {
          _feitos.add(item.id);
        }
      }),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Alvo grande: a marcação é feita com a mão suada, de relance.
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: feito ? AppColors.success : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: feito ? AppColors.success : AppColors.lineStrong,
                width: 1.5,
              ),
            ),
            child: feito
                ? const Icon(Icons.check_rounded, size: 15, color: AppColors.bg)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${i + 1}. ${item.nome}',
                  style: AppText.bodyStrong(14).copyWith(
                    decoration: feito ? TextDecoration.lineThrough : null,
                    color: feito ? AppColors.textMuted : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(detalhes.join('  ·  '), style: AppText.caption(12)),
                if (obs != null && obs.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.campaign_outlined,
                          size: 12, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(obs,
                            style: AppText.caption(11.5,
                                color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rodape() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.lg,
      ),
      child: PhdButton(
        label: 'Registrar treino',
        icon: Icons.check_rounded,
        loading: _salvando,
        onPressed: _salvando ? null : _concluir,
      ),
    );
  }
}
