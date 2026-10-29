import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/dieta.dart';
import '../../../core/services/dieta_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import 'plano_metas_screen.dart';

/// Planos alimentares de um aluno: o que vale hoje e o histórico.
///
/// Um plano ativo por aluno, garantido por índice no banco. O histórico fica
/// porque plano alimentar é documento: o aluno pode perguntar o que estava
/// comendo em março, e a resposta precisa existir.
class DietaScreen extends StatefulWidget {
  const DietaScreen({super.key, required this.aluno});

  final Map<String, dynamic> aluno;

  @override
  State<DietaScreen> createState() => _DietaScreenState();
}

class _DietaScreenState extends State<DietaScreen> {
  List<PlanoAlimentar> _planos = const [];
  bool _carregando = true;
  Object? _erro;

  /// Nulo enquanto não checou. Guardado para a tela explicar a falta do CRN
  /// antes de a pessoa montar um plano que não vai poder assinar.
  String? _crn;
  bool _crnChecado = false;

  String get _alunoId => widget.aluno['id'].toString();
  String get _alunoNome => (widget.aluno['nome'] as String?) ?? 'Aluno';

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
      final linhas = await DietaService.listarPlanos(_alunoId);
      final crn = await DietaService.meuCrn();
      if (!mounted) return;
      setState(() {
        _planos = linhas.map(PlanoAlimentar.doMapa).toList();
        _crn = crn;
        _crnChecado = true;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ativo = _planos.where((p) => p.ativo).firstOrNull;
    final anteriores = _planos.where((p) => !p.ativo).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrição', style: AppText.title(16)),
            Text(
              _alunoNome,
              style: AppText.caption(11.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
      body: _corpo(ativo, anteriores),
    );
  }

  Widget _corpo(PlanoAlimentar? ativo, List<PlanoAlimentar> anteriores) {
    if (_carregando && _planos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
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
          if (_crnChecado && _crn == null) ...[
            const PhdAviso(
              texto: 'Você não tem CRN no perfil. Pode montar o plano, mas '
                  'não assinar — a prescrição dietética é privativa do '
                  'nutricionista.',
              icone: Icons.gpp_maybe_outlined,
              cor: AppColors.warning,
              corTexto: AppColors.warningText,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          if (ativo == null)
            PhdEmptyState(
              icon: Icons.restaurant_menu_rounded,
              title: 'Nenhum plano ativo',
              message: 'Um plano alimentar define as calorias e os macros do '
                  'aluno, e as refeições que ele vai seguir.',
              actionLabel: 'Criar plano',
              onAction: _criar,
            )
          else ...[
            const PhdSectionHeader(label: 'Plano atual'),
            const SizedBox(height: AppSpacing.sm),
            _cartao(ativo, atual: true),
            const SizedBox(height: AppSpacing.md),
            PhdAddCard(label: 'Criar novo plano', onTap: _criar),
          ],

          if (anteriores.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            PhdSectionHeader(
              label: 'Anteriores',
              trailing: '${anteriores.length}',
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final p in anteriores)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _cartao(p, atual: false),
              ),
          ],
        ],
      ),
    );
  }

  Widget _cartao(PlanoAlimentar p, {required bool atual}) {
    return PhdCard(
      accentBar: atual ? AppColors.accent : null,
      onTap: () => _abrir(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(15.5),
                ),
              ),
              if (p.assinado)
                const PhdStatusChip(label: 'assinado', tone: PhdTone.success)
              else
                const PhdStatusChip(label: 'não assinado', tone: PhdTone.warning),
              PopupMenuButton<String>(
                color: AppColors.surfaceHigh,
                surfaceTintColor: Colors.transparent,
                tooltip: 'Opções de ${p.nome}',
                shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted, size: 19),
                onSelected: (v) => _menu(v, p),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'metas',
                    child: Text('Ajustar metas', style: AppText.body(14)),
                  ),
                  if (!p.ativo)
                    PopupMenuItem(
                      value: 'ativar',
                      child: Text('Tornar o plano atual',
                          style: AppText.body(14)),
                    ),
                  PopupMenuItem(
                    value: 'excluir',
                    child: Text('Excluir',
                        style: AppText.body(14, color: AppColors.dangerText)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Meta diária',
                  value: p.metaKcal == null
                      ? '—'
                      : '${p.metaKcal!.round()} kcal',
                  valueSize: 20,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: 'Objetivo',
                  value: p.objetivoEnum.nome,
                  valueSize: 15,
                  valueColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (p.metaProteina != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'P ${p.metaProteina!.round()} g · '
              'C ${p.metaCarboidrato?.round() ?? 0} g · '
              'G ${p.metaGordura?.round() ?? 0} g',
              style: AppText.caption(12, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            _periodo(p),
            style: AppText.caption(11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _periodo(PlanoAlimentar p) {
    final i = p.dataInicio;
    if (i == null) return '';
    final inicio = '${i.day.toString().padLeft(2, '0')}/'
        '${i.month.toString().padLeft(2, '0')}/${i.year}';
    if (p.crnAssinatura != null) {
      return 'Desde $inicio · CRN ${p.crnAssinatura}';
    }
    return 'Desde $inicio';
  }

  // ── Ações ───────────────────────────────────────────────────

  Future<void> _abrir(PlanoAlimentar p) async {
    await context.push('/alunos/dieta/montar', extra: {
      'planoId': p.id,
      'alunoNome': _alunoNome,
    });
    if (mounted) await _carregar();
  }

  Future<void> _criar() async {
    final definidas = await context.push<MetasDefinidas>(
      '/alunos/dieta/metas',
      extra: {'aluno': widget.aluno},
    );
    if (definidas == null || !mounted) return;

    try {
      final id = await DietaService.criarPlano(
        alunoId: _alunoId,
        nome: definidas.nome.isEmpty ? 'Plano alimentar' : definidas.nome,
        objetivo: definidas.metas['objetivo'] as String?,
        metas: definidas.metas,
      );
      if (!mounted) return;
      // Vai direto montar: plano com metas e sem refeição nenhuma não serve
      // para o aluno, e voltar para a lista faria procurá-lo de novo.
      await context.push('/alunos/dieta/montar', extra: {
        'planoId': id,
        'alunoNome': _alunoNome,
      });
      if (mounted) await _carregar();
    } catch (e) {
      if (mounted) _falhou(e);
    }
  }

  Future<void> _menu(String acao, PlanoAlimentar p) async {
    switch (acao) {
      case 'metas':
        final definidas = await context.push<MetasDefinidas>(
          '/alunos/dieta/metas',
          extra: {'aluno': widget.aluno, 'plano': p},
        );
        if (definidas == null || !mounted) return;
        try {
          await DietaService.atualizarPlano(p.id, definidas.metas);
          if (mounted) await _carregar();
        } catch (e) {
          if (mounted) _falhou(e);
        }

      case 'ativar':
        try {
          await DietaService.ativarPlano(p.id, _alunoId);
          if (mounted) await _carregar();
        } catch (e) {
          if (mounted) _falhou(e);
        }

      case 'excluir':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceHigh,
            title: Text('Excluir "${p.nome}"?', style: AppText.title(17)),
            content: Text(
              p.ativo
                  ? 'É o plano atual: o aluno fica sem dieta imediatamente. '
                      'As refeições e os registros de adesão também são apagados.'
                  : 'As refeições e os registros de adesão deste plano são '
                      'apagados junto.',
              style: AppText.body(13.5, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar',
                    style: AppText.bodyStrong(13.5,
                        color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Excluir',
                    style: AppText.bodyStrong(13.5,
                        color: AppColors.dangerText)),
              ),
            ],
          ),
        );
        if (ok != true) return;
        try {
          await DietaService.excluirPlano(p.id);
          if (mounted) await _carregar();
        } catch (e) {
          if (mounted) _falhou(e);
        }
    }
  }

  void _falhou(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        content: Text('Não consegui salvar: $e', style: AppText.body(13.5)),
      ),
    );
  }
}
