import 'package:flutter/material.dart';

import '../../../core/models/conquista.dart';
import '../../../core/services/conquista_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// A biblioteca pessoal do aluno: os exercícios que ele já recebeu.
///
/// Só aparece o que foi prescrito para ele. O que nunca veio não entra
/// nem como bloqueado — a especificação é explícita, e mostrar cadeado em
/// cima de exercício alheio viraria vitrine de treino que não é dele.
class DesbloqueiosScreen extends StatefulWidget {
  const DesbloqueiosScreen({super.key, required this.alunoId});

  final String alunoId;

  @override
  State<DesbloqueiosScreen> createState() => _DesbloqueiosScreenState();
}

class _DesbloqueiosScreenState extends State<DesbloqueiosScreen> {
  List<Map<String, dynamic>> _itens = const [];
  NumerosDoAluno _n = const NumerosDoAluno();
  String _grupo = 'Todos';

  bool _carregando = true;
  Object? _erro;

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
      final (itens, numeros) = await (
        ConquistaService.exerciciosDesbloqueados(widget.alunoId),
        ConquistaService.numeros(widget.alunoId),
      ).wait;
      if (!mounted) return;
      setState(() {
        _itens = itens;
        _n = numeros;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<String> get _grupos {
    final s = <String>{};
    for (final e in _itens) {
      final g = (e['grupo_muscular'] as String?)?.trim();
      if (g != null && g.isNotEmpty) s.add(g);
    }
    final l = s.toList()..sort();
    return ['Todos', ...l];
  }

  List<Map<String, dynamic>> get _visiveis => _grupo == 'Todos'
      ? _itens
      : _itens.where((e) => e['grupo_muscular'] == _grupo).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Desbloqueios', style: AppText.title(16)),
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: '$_erro',
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge * 2,
        ),
        children: [
          _progresso(),
          if (_itens.isEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const PhdEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'Nenhum exercício ainda',
              message: 'Cada exercício que seu professor prescrever entra '
                  'aqui — e fica, mesmo quando o treino mudar.',
            ),
          ] else ...[
            if (_grupos.length > 2) ...[
              const SizedBox(height: AppSpacing.lg),
              PhdFilterBar(
                children: [
                  for (final g in _grupos)
                    PhdFilterChip(
                      label: g,
                      selected: _grupo == g,
                      onTap: () => setState(() => _grupo = g),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            for (final e in _visiveis) _linha(e),
          ],
        ],
      ),
    );
  }

  Widget _progresso() {
    final pct = (_n.progressoCatalogo * 100).round();
    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_n.exercicios}', style: AppText.display(34)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('de ${_n.catalogo} exercícios',
                    style: AppText.caption(12.5, color: AppColors.textMuted)),
              ),
              const Spacer(),
              Text('$pct%',
                  style: AppText.number(20, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PhdProgressBar(value: _n.progressoCatalogo, height: 9),
          const SizedBox(height: AppSpacing.sm),
          Text(
            // O denominador é o catálogo oficial da plataforma, não o
            // acervo do professor: senão o percentual do aluno mudaria
            // toda vez que o professor cadastrasse um exercício novo.
            'Sobre o catálogo oficial do PHD.',
            style: AppText.caption(11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _linha(Map<String, dynamic> e) {
    final quando = DateTime.tryParse(e['desbloqueado_em'] as String? ?? '');
    final grupo = (e['grupo_muscular'] as String?)?.trim();
    final equip = (e['equipamento'] as String?)?.trim();

    return PhdListRow(
      title: e['nome'] as String? ?? 'Exercício',
      subtitle: [
        if (grupo != null && grupo.isNotEmpty) grupo,
        if (equip != null && equip.isNotEmpty) equip,
      ].join(' · '),
      leading: PhdMiniaturaExercicio(
        imagemUrl: (e['thumb_url'] as String?) ?? (e['midia_url'] as String?),
        temVideo: ((e['video_url'] as String?)?.trim().isNotEmpty ?? false),
        tamanho: 44,
      ),
      trailingLabel: quando == null ? null : 'desbloqueado',
      trailingValue: quando == null
          ? null
          : '${quando.day.toString().padLeft(2, '0')}/'
              '${quando.month.toString().padLeft(2, '0')}',
    );
  }
}
