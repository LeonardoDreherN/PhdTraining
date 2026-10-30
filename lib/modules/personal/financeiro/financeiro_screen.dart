import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/financeiro.dart';
import '../../../core/services/financeiro_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/moeda.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/widgets/widgets.dart';
import 'nova_assinatura_sheet.dart';

/// O financeiro do personal.
///
/// Esta versão é controle manual: o dinheiro entra por fora (Pix,
/// dinheiro, maquininha) e o personal dá baixa aqui. A tela foi montada em
/// volta da pergunta que ele faz todo dia — "quem me deve?" —, e não em
/// volta do total do mês, que é consequência.
class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

enum _Aba { atrasadas, mes, assinaturas, planos }

class _FinanceiroScreenState extends State<FinanceiroScreen> {
  List<PlanoVenda> _planos = const [];
  List<Assinatura> _assinaturas = const [];
  List<Cobranca> _cobrancas = const [];

  bool _carregando = true;
  Object? _erro;
  _Aba _aba = _Aba.atrasadas;

  /// Ids em gravação. A linha fica desabilitada enquanto a baixa vai ao
  /// servidor, para dois toques não virarem duas baixas.
  final _gravando = <String>{};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = _cobrancas.isEmpty;
      _erro = null;
    });
    try {
      final (planos, assinaturas, cobrancas) = await (
        FinanceiroService.planos(),
        FinanceiroService.assinaturas(),
        FinanceiroService.cobrancas(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _planos = planos;
        _assinaturas = assinaturas;
        _cobrancas = cobrancas;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  ResumoFinanceiro get _resumo =>
      FinanceiroService.resumir(_cobrancas, _assinaturas);

  List<Cobranca> get _atrasadas {
    final l = _cobrancas.where((c) => c.vencida).toList();
    // Mais antiga primeiro: é a que está há mais tempo sem resolver.
    l.sort((a, b) => a.vencimento.compareTo(b.vencimento));
    return l;
  }

  List<Cobranca> get _doMes {
    final agora = DateTime.now();
    final inicio = DateTime(agora.year, agora.month);
    final fim = DateTime(agora.year, agora.month + 1);
    final l = _cobrancas
        .where((c) =>
            c.status != 'cancelado' &&
            !c.vencimento.isBefore(inicio) &&
            c.vencimento.isBefore(fim))
        .toList();
    l.sort((a, b) => a.vencimento.compareTo(b.vencimento));
    return l;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: _corpo(),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando && _cobrancas.isEmpty && _planos.isEmpty) {
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

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge * 2,
        ),
        children: [
          Row(
            children: [
              Expanded(child: Text('Financeiro', style: AppText.display(28))),
              PhdButton(
                label: 'Assinar',
                icon: Icons.add_rounded,
                size: PhdButtonSize.small,
                expand: false,
                onPressed: _planos.isEmpty ? null : _novaAssinatura,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _painel(),
          const SizedBox(height: AppSpacing.lg),
          _filtros(),
          const SizedBox(height: AppSpacing.lg),
          ..._conteudo(),
        ],
      ),
    );
  }

  // ── Painel ──────────────────────────────────────────────────

  Widget _painel() {
    final r = _resumo;
    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Recebido em ${mesPorExtenso(DateTime.now())}',
                  value: Moeda.formatarCurto(r.recebidoCentavos),
                  valueSize: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.line, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PhdStat(
                  label: 'A receber',
                  value: Moeda.formatarCurto(r.aReceberCentavos),
                  valueSize: 17,
                  valueColor: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: r.alunosEmAtraso == 1 ? '1 em atraso' : '${r.alunosEmAtraso} em atraso',
                  value: Moeda.formatarCurto(r.atrasadoCentavos),
                  valueSize: 17,
                  valueColor: r.atrasadoCentavos > 0
                      ? AppColors.dangerText
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            // O recorrente é o número que diz se o negócio cresce. O
            // recebido do mês oscila com quem atrasou; este não.
            '${r.assinaturasAtivas} ${r.assinaturasAtivas == 1 ? 'assinatura ativa' : 'assinaturas ativas'}'
            '  ·  ${Moeda.formatar(r.recorrenteCentavos)} por ciclo',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _filtros() => PhdFilterBar(
        children: [
          PhdFilterChip(
            label: 'Em atraso',
            count: _atrasadas.isEmpty ? null : _atrasadas.length,
            tone: PhdTone.danger,
            selected: _aba == _Aba.atrasadas,
            onTap: () => setState(() => _aba = _Aba.atrasadas),
          ),
          PhdFilterChip(
            label: 'Este mês',
            selected: _aba == _Aba.mes,
            onTap: () => setState(() => _aba = _Aba.mes),
          ),
          PhdFilterChip(
            label: 'Assinaturas',
            selected: _aba == _Aba.assinaturas,
            onTap: () => setState(() => _aba = _Aba.assinaturas),
          ),
          PhdFilterChip(
            label: 'Planos',
            selected: _aba == _Aba.planos,
            onTap: () => setState(() => _aba = _Aba.planos),
          ),
        ],
      );

  List<Widget> _conteudo() => switch (_aba) {
        _Aba.atrasadas => _listaCobrancas(
            _atrasadas,
            vazio: const PhdEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Ninguém em atraso',
              message: 'Todas as cobranças vencidas foram pagas.',
            ),
          ),
        _Aba.mes => _listaCobrancas(
            _doMes,
            vazio: const PhdEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nenhuma cobrança este mês',
              message: 'Assine um aluno num plano para as cobranças '
                  'aparecerem aqui.',
            ),
          ),
        _Aba.assinaturas => _listaAssinaturas(),
        _Aba.planos => _listaPlanos(),
      };

  // ── Cobranças ───────────────────────────────────────────────

  List<Widget> _listaCobrancas(List<Cobranca> lista, {required Widget vazio}) {
    if (lista.isEmpty) return [vazio];
    return [
      for (final c in lista)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _cartaoCobranca(c),
        ),
    ];
  }

  Widget _cartaoCobranca(Cobranca c) {
    final ocupada = _gravando.contains(c.id);
    final zap = linkWhatsApp(
      c.alunoWhatsapp,
      mensagem: 'Oi, ${c.alunoNome.split(' ').first}! Passando para lembrar '
          'da ${c.descricao ?? 'mensalidade'} de ${c.valor}, '
          'que venceu em ${c.vencimentoTexto}.',
    );

    return PhdCard(
      accentBar: c.vencida ? AppColors.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.alunoNome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.title(15)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        c.descricao ?? 'Cobrança',
                        if (c.parcelaTexto.isNotEmpty) c.parcelaTexto,
                        'vence ${c.vencimentoTexto}',
                      ].join('  ·  '),
                      style: AppText.caption(11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(c.valor, style: AppText.number(16)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (c.paga)
                const PhdStatusChip(label: 'pago', tone: PhdTone.success)
              else if (c.vencida)
                PhdStatusChip(
                  label: c.diasDeAtraso == 1
                      ? '1 dia de atraso'
                      : '${c.diasDeAtraso} dias de atraso',
                  tone: PhdTone.danger,
                )
              else
                const PhdStatusChip(label: 'em aberto'),
              const Spacer(),
              if (!c.paga && zap != null)
                PhdIconButton(
                  icon: Icons.chat_outlined,
                  tooltip: 'Cobrar ${c.alunoNome} no WhatsApp',
                  onPressed: () => _abrir(zap),
                ),
              const SizedBox(width: AppSpacing.sm),
              PhdButton(
                label: c.paga ? 'Desfazer' : 'Recebi',
                variant:
                    c.paga ? PhdButtonVariant.ghost : PhdButtonVariant.primary,
                size: PhdButtonSize.small,
                expand: false,
                loading: ocupada,
                onPressed: ocupada ? null : () => _alternarPaga(c),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _alternarPaga(Cobranca c) async {
    setState(() => _gravando.add(c.id));
    try {
      if (c.paga) {
        await FinanceiroService.desmarcarPaga(c.id);
      } else {
        final metodo = await _escolherMetodo();
        if (metodo == null) return;
        await FinanceiroService.marcarPaga(c.id, metodo: metodo);
      }
      await _carregar();
    } catch (e) {
      if (mounted) _falhou(e);
    } finally {
      if (mounted) setState(() => _gravando.remove(c.id));
    }
  }

  /// Como o dinheiro entrou. Perguntar custa um toque e é o que permite o
  /// relatório separar Pix de dinheiro depois — sem isso, tudo vira
  /// "recebido" e a informação não existe mais.
  Future<String?> _escolherMetodo() => showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Como você recebeu?', style: AppText.title(16)),
                const SizedBox(height: AppSpacing.lg),
                for (final (valor, rotulo, icone) in const [
                  ('pix', 'Pix', Icons.pix_rounded),
                  ('dinheiro', 'Dinheiro', Icons.payments_outlined),
                  ('cartao', 'Cartão / maquininha', Icons.credit_card_rounded),
                  ('outro', 'Outro', Icons.more_horiz_rounded),
                ])
                  PhdListRow(
                    title: rotulo,
                    leading: Icon(icone,
                        size: 19, color: AppColors.textSecondary),
                    onTap: () => Navigator.pop(ctx, valor),
                  ),
              ],
            ),
          ),
        ),
      );

  // ── Assinaturas ─────────────────────────────────────────────

  List<Widget> _listaAssinaturas() {
    final vivas = _assinaturas.where((a) => a.viva).toList();
    if (vivas.isEmpty) {
      return [
        PhdEmptyState(
          icon: Icons.card_membership_outlined,
          title: 'Nenhuma assinatura',
          message: 'Assine um aluno num plano para gerar as cobranças dele.',
          actionLabel: _planos.isEmpty ? null : 'Assinar aluno',
          onAction: _planos.isEmpty ? null : _novaAssinatura,
        ),
      ];
    }

    return [
      for (final a in vivas)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PhdCard(
            child: Row(
              children: [
                PhdAvatar(name: a.alunoNome, imageUrl: a.alunoFotoUrl, size: 40),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.alunoNome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong(14)),
                      const SizedBox(height: 2),
                      Text(
                        '${a.planoNome}  ·  ${a.preco}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.caption(11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  color: AppColors.surfaceHigh,
                  surfaceTintColor: Colors.transparent,
                  tooltip: 'Opções da assinatura de ${a.alunoNome}',
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                  icon: Icon(Icons.more_vert_rounded,
                      color: AppColors.textMuted, size: 19),
                  onSelected: (v) => _menuAssinatura(v, a),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pausada',
                      child: Text('Pausar', style: AppText.body(14)),
                    ),
                    PopupMenuItem(
                      value: 'cancelada',
                      child: Text('Cancelar assinatura',
                          style:
                              AppText.body(14, color: AppColors.dangerText)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Future<void> _menuAssinatura(String acao, Assinatura a) async {
    if (acao == 'cancelada') {
      final ok = await _confirmar(
        titulo: 'Cancelar a assinatura de ${a.alunoNome}?',
        mensagem: 'As cobranças que já venceram continuam na lista. '
            'As futuras você pode cancelar uma a uma.',
        acao: 'Cancelar assinatura',
      );
      if (!ok) return;
    }
    try {
      await FinanceiroService.mudarStatusAssinatura(a.id, acao);
      await _carregar();
    } catch (e) {
      if (mounted) _falhou(e);
    }
  }

  Future<void> _novaAssinatura() async {
    final criou = await abrirNovaAssinatura(context, _planos);
    if (criou == true && mounted) await _carregar();
  }

  // ── Planos ──────────────────────────────────────────────────

  List<Widget> _listaPlanos() {
    if (_planos.isEmpty) {
      return [
        const PhdEmptyState(
          icon: Icons.sell_outlined,
          title: 'Nenhum plano cadastrado',
          message: 'Os planos definem o preço e o que o aluno recebe — '
              'treino, dieta ou os dois.',
        ),
      ];
    }

    return [
      for (final p in _planos)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PhdCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nome, style: AppText.bodyStrong(14)),
                      const SizedBox(height: 2),
                      Text(
                        '${p.inclui}  ·  ${p.periodicidadeNome}',
                        style:
                            AppText.caption(11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(p.preco, style: AppText.number(15)),
                    if (p.porMesCentavos != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${Moeda.formatar(p.porMesCentavos!)}/mês',
                        style: AppText.caption(10.5,
                            color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
  }

  // ── Auxiliares ──────────────────────────────────────────────

  Future<void> _abrir(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) _falhou('não consegui abrir o WhatsApp');
    }
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensagem,
    required String acao,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(titulo, style: AppText.title(17)),
        content: Text(mensagem,
            style: AppText.body(13.5, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Voltar',
                style: AppText.bodyStrong(13.5,
                    color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(acao,
                style:
                    AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _falhou(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        content: Text('Não deu certo: $e', style: AppText.body(13.5)),
      ),
    );
  }
}
