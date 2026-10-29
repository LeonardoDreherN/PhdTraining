import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/adesao_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/adesao.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/widgets/widgets.dart';

extension on SituacaoAdesao {
  PhdTone get tom => switch (this) {
        SituacaoAdesao.semRegistro => PhdTone.danger,
        SituacaoAdesao.dificuldade => PhdTone.warning,
        SituacaoAdesao.noCaminho => PhdTone.success,
      };
}

/// Painel de adesão: quem está seguindo a dieta, quem está com dificuldade
/// e quem sumiu — numa tela, em vez de abrir aluno por aluno.
///
/// A ordem é de quem precisa de contato primeiro. O botão de WhatsApp já
/// leva a mensagem certa para cada situação.
class AdesaoScreen extends StatefulWidget {
  const AdesaoScreen({super.key});

  @override
  State<AdesaoScreen> createState() => _AdesaoScreenState();
}

class _AdesaoScreenState extends State<AdesaoScreen> {
  List<AdesaoAluno> _alunos = const [];
  int _semPlano = 0;
  bool _carregando = true;
  Object? _erro;
  SituacaoAdesao? _filtro;

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
      final r = await AdesaoService.painel();
      if (!mounted) return;
      setState(() {
        _alunos = r.alunos;
        _semPlano = r.semPlano;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contagem = {
      for (final s in SituacaoAdesao.values) s: _alunos.where((a) => a.situacao == s).length,
    };
    final lista = _filtro == null ? _alunos : _alunos.where((a) => a.situacao == _filtro).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adesão à dieta', style: AppText.title(16)),
            Text('Últimos ${AdesaoService.dias} dias',
                style: AppText.caption(11.5, color: AppColors.textMuted)),
          ],
        ),
      ),
      body: _carregando && _alunos.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _erro != null
              ? PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não consegui carregar',
                  message: '$_erro',
                  actionLabel: 'Tentar de novo',
                  onAction: _carregar,
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge,
                    ),
                    children: [
                      Row(
                        children: [
                          for (final s in SituacaoAdesao.values) ...[
                            Expanded(child: _contador(s, contagem[s]!)),
                            if (s != SituacaoAdesao.values.last) const SizedBox(width: AppSpacing.sm),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (_alunos.isEmpty)
                        const PhdEmptyState(
                          icon: Icons.restaurant_menu_rounded,
                          title: 'Nenhum aluno com plano ativo',
                          message: 'O painel acompanha quem tem plano alimentar. Monte o '
                              'plano na tela de Nutrição do aluno.',
                        )
                      else
                        for (final a in lista)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _linha(a),
                          ),
                      if (_semPlano > 0) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          '$_semPlano ${_semPlano == 1 ? 'aluno ativo está' : 'alunos ativos estão'} '
                          'sem plano alimentar.',
                          textAlign: TextAlign.center,
                          style: AppText.caption(12, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _contador(SituacaoAdesao s, int n) {
    final ativo = _filtro == s;
    return PhdCard(
      onTap: () => setState(() => _filtro = ativo ? null : s),
      color: ativo ? AppColors.tint(s.tom.solid) : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: s.tom.solid, shape: BoxShape.circle),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('$n', style: AppText.number(24, weight: FontWeight.w800)),
          Text(s.rotulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(11.5)),
        ],
      ),
    );
  }

  Widget _linha(AdesaoAluno a) {
    final perc = a.percentual;
    final primeiro = a.nome.split(' ').first;
    final zap = a.situacao == SituacaoAdesao.noCaminho
        ? null
        : linkWhatsApp(
            a.aluno['whatsapp'] as String?,
            mensagem: a.situacao == SituacaoAdesao.semRegistro
                ? 'Oi $primeiro, tudo bem? Não vi registros da dieta nos últimos dias. '
                    'Está conseguindo seguir? Me conta o que está difícil que a gente ajusta.'
                : 'Oi $primeiro! Vi que a semana na dieta está puxada. Quer conversar '
                    'sobre o que está pegando? Dá para adaptar o plano à sua rotina.',
          );

    final detalhes = [
      if (a.previstas > 0) '${a.feitas} de ${a.previstas} refeições',
      if (a.fugas > 0) '${a.fugas} ${a.fugas == 1 ? 'fuga' : 'fugas'}',
      if (a.aguaMediaMl != null)
        'água ${(a.aguaMediaMl! / 1000).toStringAsFixed(1).replaceAll('.', ',')} L/dia',
    ];

    return PhdCard(
      onTap: () async {
        await context.push('/alunos/dieta', extra: a.aluno);
        if (mounted) _carregar();
      },
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhdAvatar(name: a.nome, imageUrl: a.aluno['foto_url'] as String?, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(14)),
                    Text(_ultimo(a.ultimoRegistro), style: AppText.caption(11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              PhdStatusChip(label: a.situacao.rotulo, tone: a.situacao.tom),
            ],
          ),
          if (perc != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: PhdProgressBar(value: perc, height: 6, color: a.situacao.tom.solid)),
                const SizedBox(width: AppSpacing.sm),
                Text('${(perc * 100).round()}%', style: AppText.number(13)),
              ],
            ),
          ],
          if (detalhes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(detalhes.join(' · '), style: AppText.caption(12)),
          ],
          if (zap != null) ...[
            const SizedBox(height: AppSpacing.md),
            PhdButton(
              label: a.situacao == SituacaoAdesao.semRegistro ? 'Chamar no WhatsApp' : 'Oferecer ajuda',
              icon: Icons.chat_rounded,
              variant: PhdButtonVariant.ghost,
              size: PhdButtonSize.small,
              onPressed: () => launchUrl(zap, mode: LaunchMode.externalApplication),
            ),
          ],
        ],
      ),
    );
  }

  static String _ultimo(DateTime? d) {
    if (d == null) return 'Nenhum registro na semana';
    final dias = DateTime.now().difference(d).inDays;
    if (dias == 0) return 'Registrou hoje';
    if (dias == 1) return 'Último registro ontem';
    return 'Último registro há $dias dias';
  }
}

/// Resumo do painel para a home do profissional: três números e um toque.
/// Some quando ninguém tem plano — não há o que acompanhar.
class CartaoAdesaoNutricao extends StatefulWidget {
  const CartaoAdesaoNutricao({super.key});

  @override
  State<CartaoAdesaoNutricao> createState() => _CartaoAdesaoNutricaoState();
}

class _CartaoAdesaoNutricaoState extends State<CartaoAdesaoNutricao> {
  List<AdesaoAluno>? _alunos;

  @override
  void initState() {
    super.initState();
    AdesaoService.painel().then((r) {
      if (mounted) setState(() => _alunos = r.alunos);
    }).catchError((_) {
      // Sem tabelas de dieta ou sem rede: a home segue sem o cartão.
    });
  }

  @override
  Widget build(BuildContext context) {
    final alunos = _alunos;
    if (alunos == null || alunos.isEmpty) return const SizedBox.shrink();

    int n(SituacaoAdesao s) => alunos.where((a) => a.situacao == s).length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: PhdCard(
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const AdesaoScreen()),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Adesão à dieta', style: AppText.bodyStrong(13.5))),
                Text('Ver painel', style: AppText.bodyStrong(12.5, color: AppColors.accent)),
                Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.accent),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final s in SituacaoAdesao.values.reversed)
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: s.tom.solid, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text('${n(s)}', style: AppText.number(18, weight: FontWeight.w800)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            s == SituacaoAdesao.noCaminho
                                ? 'no caminho'
                                : s == SituacaoAdesao.dificuldade
                                    ? 'difícil'
                                    : 'sumidos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption(11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
