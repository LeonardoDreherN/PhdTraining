import 'package:flutter/material.dart';

import '../../../core/models/equipe.dart';
import '../../../core/services/equipe_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import 'liberar_alunos_sheet.dart';

/// Quem mais acessa meus alunos, e de quem eu acesso.
///
/// O personal sem CRN convida uma nutricionista; a nutricionista sem
/// CREF convida um personal. Quem convida continua dono dos alunos — o
/// convidado só enxerga, dentro do escopo dele.
class EquipeScreen extends StatefulWidget {
  const EquipeScreen({super.key});

  @override
  State<EquipeScreen> createState() => _EquipeScreenState();
}

class _EquipeScreenState extends State<EquipeScreen> {
  List<VinculoEquipe> _minha = const [];
  List<VinculoEquipe> _convidado = const [];
  bool _carregando = true;
  Object? _erro;
  final _ocupado = <String>{};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = _minha.isEmpty && _convidado.isEmpty;
      _erro = null;
    });
    try {
      final (minha, convidado) = await (
        EquipeService.minhaEquipe(),
        EquipeService.ondeSouConvidado(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _minha = minha;
        _convidado = convidado;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Equipe', style: AppText.title(16)),
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return Center(
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

    final pendentes = _convidado.where((v) => v.pendente).toList();
    final participo = _convidado.where((v) => v.ativo).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge * 2,
        ),
        children: [
          if (pendentes.isNotEmpty) ...[
            const PhdSectionHeader(label: 'Convites para você'),
            const SizedBox(height: AppSpacing.sm),
            for (final v in pendentes) _cartaoConvite(v),
            const SizedBox(height: AppSpacing.xl),
          ],

          const PhdSectionHeader(label: 'Quem acessa meus alunos'),
          const SizedBox(height: AppSpacing.sm),
          if (_minha.isEmpty)
            PhdEmptyState(
              icon: Icons.groups_outlined,
              title: 'Nenhum profissional convidado',
              message: 'Convide quem cuida do que você não cuida. Um '
                  'nutricionista passa a ver os alunos cujo plano inclui '
                  'dieta, e monta o plano alimentar deles.',
              actionLabel: 'Convidar',
              onAction: _convidar,
            )
          else ...[
            for (final v in _minha) _cartaoVinculo(v),
            const SizedBox(height: AppSpacing.sm),
            PhdAddCard(label: 'Convidar profissional', onTap: _convidar),
          ],

          if (participo.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const PhdSectionHeader(label: 'Carteiras que eu acompanho'),
            const SizedBox(height: AppSpacing.sm),
            for (final v in participo) _cartaoParticipo(v),
          ],

          const SizedBox(height: AppSpacing.xl),
          Text(
            'O convidado vê os alunos cujo plano inclui a área dele — quem '
            'está só no treino não aparece para o nutricionista. Prescrever '
            'dieta continua exigindo CRN.',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Cartões ─────────────────────────────────────────────────

  Widget _cartaoConvite(VinculoEquipe v) {
    final ocupado = _ocupado.contains(v.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PhdCard(
        accentBar: AppColors.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${v.donoNome ?? 'Um profissional'} convidou você',
              style: AppText.title(15),
            ),
            const SizedBox(height: 3),
            Text(
              'Para acompanhar ${v.escopo == 'nutricao' ? 'a nutrição' : 'o treino'} '
              'dos alunos dele. Você vai ver os dados de saúde desses alunos.',
              style: AppText.caption(12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: PhdButton(
                    label: 'Recusar',
                    variant: PhdButtonVariant.ghost,
                    size: PhdButtonSize.small,
                    onPressed: ocupado ? null : () => _responder(v, false),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PhdButton(
                    label: 'Aceitar',
                    size: PhdButtonSize.small,
                    loading: ocupado,
                    onPressed: ocupado ? null : () => _responder(v, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoVinculo(VinculoEquipe v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PhdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PhdAvatar(name: v.rotulo, size: 38),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.rotulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong(14)),
                      const SizedBox(height: 2),
                      Text(v.escopoDescricao,
                          style: AppText.caption(11.5,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: AppColors.surfaceHigh,
                  surfaceTintColor: Colors.transparent,
                  tooltip: 'Opções de ${v.rotulo}',
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                  icon: Icon(Icons.more_vert_rounded,
                      color: AppColors.textMuted, size: 19),
                  onSelected: (a) => _menu(a, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'alunos',
                      child: Text('Liberar alunos', style: AppText.body(14)),
                    ),
                    PopupMenuItem(
                      value: 'remover',
                      child: Text('Tirar o acesso',
                          style:
                              AppText.body(14, color: AppColors.dangerText)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                PhdStatusChip(
                  label: v.statusNome.toLowerCase(),
                  tone: v.ativo ? PhdTone.success : PhdTone.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                PhdStatusChip(label: v.escopoNome.toLowerCase()),
                const Spacer(),
                if (v.alunosLiberados > 0)
                  Text(
                    v.alunosLiberados == 1
                        ? '+1 aluno liberado'
                        : '+${v.alunosLiberados} alunos liberados',
                    style: AppText.caption(11, color: AppColors.textMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartaoParticipo(VinculoEquipe v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PhdCard(
        child: Row(
          children: [
            PhdAvatar(name: v.donoNome ?? '?', size: 38),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(v.donoNome ?? 'Profissional',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong(14)),
                  const SizedBox(height: 2),
                  Text('Você acompanha ${v.escopoNome.toLowerCase()}',
                      style:
                          AppText.caption(11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            const PhdStatusChip(label: 'ativo', tone: PhdTone.success),
          ],
        ),
      ),
    );
  }

  // ── Ações ───────────────────────────────────────────────────

  Future<void> _responder(VinculoEquipe v, bool aceitar) async {
    setState(() => _ocupado.add(v.id));
    try {
      await EquipeService.responder(v.id, aceitar: aceitar);
      await _carregar();
    } catch (e) {
      if (mounted) _falhou(e);
    } finally {
      if (mounted) setState(() => _ocupado.remove(v.id));
    }
  }

  Future<void> _menu(String acao, VinculoEquipe v) async {
    switch (acao) {
      case 'alunos':
        final mudou = await abrirLiberarAlunos(context, v);
        if (mudou == true && mounted) await _carregar();

      case 'remover':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceHigh,
            title: Text('Tirar o acesso de ${v.rotulo}?',
                style: AppText.title(17)),
            content: Text(
              'Ele deixa de ver seus alunos agora. O que já foi prescrito '
              'continua valendo, e o registro do vínculo fica guardado.',
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
                child: Text('Tirar acesso',
                    style: AppText.bodyStrong(13.5,
                        color: AppColors.dangerText)),
              ),
            ],
          ),
        );
        if (ok != true) return;
        try {
          await EquipeService.remover(v.id);
          await _carregar();
        } catch (e) {
          if (mounted) _falhou(e);
        }
    }
  }

  Future<void> _convidar() async {
    final ctrl = TextEditingController();
    var escopo = 'nutricao';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: Text('Convidar profissional', style: AppText.title(17)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhdField(
                label: 'E-mail',
                controller: ctrl,
                hint: 'nutricionista@email.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('O que ele vai acompanhar', style: AppText.caption(12.5)),
              const SizedBox(height: 7),
              PhdFilterBar(
                children: [
                  for (final (valor, rotulo) in const [
                    ('nutricao', 'Nutrição'),
                    ('treino', 'Treino'),
                  ])
                    PhdFilterChip(
                      label: rotulo,
                      selected: escopo == valor,
                      onTap: () => setLocal(() => escopo = valor),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Se essa pessoa ainda não tem conta, o convite espera: ele '
                'se liga ao login dela quando entrar com esse e-mail.',
                style: AppText.caption(11.5, color: AppColors.textMuted),
              ),
            ],
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
              child: Text('Convidar',
                  style:
                      AppText.bodyStrong(13.5, color: AppColors.accent)),
            ),
          ],
        ),
      ),
    );

    final email = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true || email.isEmpty) return;

    try {
      await EquipeService.convidar(email: email, escopo: escopo);
      if (mounted) await _carregar();
    } catch (e) {
      if (mounted) _falhou(e);
    }
  }

  void _falhou(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        content: Text('$e'.replaceFirst('Exception: ', ''),
            style: AppText.body(13.5)),
      ),
    );
  }
}
