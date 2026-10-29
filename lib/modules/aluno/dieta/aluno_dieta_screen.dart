import 'package:flutter/material.dart';
import '../../../core/models/dieta.dart';
import '../../../core/services/dieta_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dieta_calculos.dart';
import '../../../core/widgets/widgets.dart';

/// A dieta do aluno: o que comer hoje, e o que ele já comeu.
///
/// O aluno marca a refeição quando faz. Daí sai o consumido do dia e a
/// adesão que o profissional vê — por isso marcar tem de ser um toque, sem
/// confirmação no caminho.
class AlunoDietaScreen extends StatefulWidget {
  const AlunoDietaScreen({super.key, required this.alunoId});

  final String alunoId;

  @override
  State<AlunoDietaScreen> createState() => _AlunoDietaScreenState();
}

class _AlunoDietaScreenState extends State<AlunoDietaScreen> {
  PlanoAlimentar? _plano;
  Set<String> _feitas = const {};
  bool _carregando = true;
  Object? _erro;

  /// Dia que está sendo visto. Começa hoje, mas dá para voltar: quem esqueceu
  /// de marcar o jantar ontem conseguir corrigir é o que mantém a adesão
  /// parecida com a realidade.
  late DateTime _dia = _soData(DateTime.now());

  /// Refeições cuja marcação está indo para o servidor. A linha fica
  /// marcada na hora e só desfaz se a gravação falhar.
  final _gravando = <String>{};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  static DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final plano = await DietaService.planoAtivo(widget.alunoId);
      final feitas = await DietaService.refeicoesFeitas(
        alunoId: widget.alunoId,
        dia: _dia,
      );
      if (!mounted) return;
      setState(() {
        _plano = plano;
        _feitas = feitas;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _trocarDia(DateTime novo) async {
    setState(() => _dia = _soData(novo));
    try {
      final feitas = await DietaService.refeicoesFeitas(
        alunoId: widget.alunoId,
        dia: _dia,
      );
      if (mounted) setState(() => _feitas = feitas);
    } catch (_) {
      if (mounted) setState(() => _feitas = const {});
    }
  }

  Future<void> _marcar(Refeicao r, bool feita) async {
    // Marca na tela primeiro: esperar a ida ao servidor para o check
    // aparecer faz a pessoa tocar de novo achando que não pegou.
    setState(() {
      _gravando.add(r.id);
      _feitas = feita ? {..._feitas, r.id} : (_feitas.toSet()..remove(r.id));
    });

    try {
      await DietaService.marcarRefeicao(
        alunoId: widget.alunoId,
        refeicaoId: r.id,
        dia: _dia,
        feita: feita,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Desfaz: mostrar marcado o que não foi salvo seria mentir para os
        // dois lados — o aluno acha que registrou e o profissional não vê.
        _feitas = feita ? (_feitas.toSet()..remove(r.id)) : {..._feitas, r.id};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não consegui registrar: $e', style: AppText.body(13.5)),
        ),
      );
    } finally {
      if (mounted) setState(() => _gravando.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Minha dieta', style: AppText.title(16)),
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_carregando && _plano == null) {
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

    final p = _plano;
    if (p == null || p.vazio) {
      return const PhdEmptyState(
        icon: Icons.restaurant_menu_rounded,
        title: 'Sem plano alimentar',
        message: 'Seu profissional ainda não montou sua dieta. Quando montar, '
            'ela aparece aqui.',
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
          _tiraDeDias(),
          const SizedBox(height: AppSpacing.lg),
          _resumoDoDia(p),
          const SizedBox(height: AppSpacing.xl),
          const PhdSectionHeader(label: 'Refeições'),
          const SizedBox(height: AppSpacing.sm),
          for (final r in p.refeicoes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _cartaoRefeicao(r),
            ),
          if (p.observacoes != null && p.observacoes!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const PhdSectionHeader(label: 'Orientações'),
            const SizedBox(height: AppSpacing.sm),
            PhdCard(
              child: Text(
                p.observacoes!,
                style: AppText.body(13.5, color: AppColors.textSecondary),
              ),
            ),
          ],
          if (p.assinado) ...[
            const SizedBox(height: AppSpacing.xl),
            _rodapeAssinatura(p),
          ],
        ],
      ),
    );
  }

  // ── Dias ────────────────────────────────────────────────────

  Widget _tiraDeDias() {
    final hoje = _soData(DateTime.now());
    // Sete dias, do mais antigo para hoje: a ordem do calendário, com hoje
    // na ponta onde o dedo já está.
    final dias = [
      for (var i = 6; i >= 0; i--) hoje.subtract(Duration(days: i)),
    ];

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: dias.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final d = dias[dias.length - 1 - i];
          return _botaoDia(d, ehHoje: d == hoje);
        },
      ),
    );
  }

  Widget _botaoDia(DateTime d, {required bool ehHoje}) {
    final selecionado = d == _dia;
    return InkWell(
      borderRadius: AppRadius.rMd,
      onTap: selecionado ? null : () => _trocarDia(d),
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          color: selecionado ? AppColors.accent : AppColors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: selecionado ? AppColors.accent : AppColors.line,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _diaDaSemana(d),
              style: AppText.caption(
                10.5,
                color: selecionado ? AppColors.onAccent : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ehHoje ? 'hoje' : d.day.toString(),
              style: AppText.number(
                ehHoje ? 12 : 15,
                color: selecionado ? AppColors.onAccent : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _diaDaSemana(DateTime d) => switch (d.weekday) {
        DateTime.monday => 'seg',
        DateTime.tuesday => 'ter',
        DateTime.wednesday => 'qua',
        DateTime.thursday => 'qui',
        DateTime.friday => 'sex',
        DateTime.saturday => 'sáb',
        _ => 'dom',
      };

  // ── Resumo ──────────────────────────────────────────────────

  /// Soma só as refeições marcadas: é o consumido, não o prescrito.
  ({double kcal, double proteina, double carboidrato, double gordura, double fibra})
      _consumido(PlanoAlimentar p) {
    var kcal = 0.0, pr = 0.0, c = 0.0, g = 0.0, f = 0.0;
    for (final r in p.refeicoes) {
      if (!_feitas.contains(r.id)) continue;
      final t = r.total;
      kcal += t.kcal;
      pr += t.proteina;
      c += t.carboidrato;
      g += t.gordura;
      f += t.fibra;
    }
    return (kcal: kcal, proteina: pr, carboidrato: c, gordura: g, fibra: f);
  }

  Widget _resumoDoDia(PlanoAlimentar p) {
    final consumido = _consumido(p);
    final meta = p.metaKcal;
    final feitas = p.refeicoes.where((r) => _feitas.contains(r.id)).length;

    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Consumido',
                  value: '${consumido.kcal.round()}',
                  valueSize: 34,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: meta == null ? 'kcal' : 'Meta do dia',
                  value: meta == null ? 'kcal' : '${meta.round()} kcal',
                  valueSize: 15,
                  valueColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (meta != null) ...[
            const SizedBox(height: AppSpacing.md),
            PhdProgressBar(value: proporcao(consumido.kcal, meta), height: 9),
          ],
          const SizedBox(height: AppSpacing.lg),
          PhdSegments(total: p.refeicoes.length, filled: feitas),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$feitas de ${p.refeicoes.length} refeições marcadas',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.line, height: 1),
          const SizedBox(height: AppSpacing.lg),
          _macro('Proteína', consumido.proteina, p.metaProteina),
          const SizedBox(height: AppSpacing.md),
          _macro('Carboidrato', consumido.carboidrato, p.metaCarboidrato),
          const SizedBox(height: AppSpacing.md),
          _macro('Gordura', consumido.gordura, p.metaGordura),
          if (p.aguaMl != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Icon(Icons.water_drop_outlined,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Beba ${(p.aguaMl! / 1000).toStringAsFixed(1)} L de água hoje',
                  style: AppText.caption(12, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _macro(String nome, double consumido, double? meta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(nome, style: AppText.caption(12))),
            Text(
              meta == null
                  ? '${consumido.round()} g'
                  : '${consumido.round()} / ${meta.round()} g',
              style: AppText.number(12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
        if (meta != null) ...[
          const SizedBox(height: 5),
          PhdProgressBar(value: proporcao(consumido, meta)),
        ],
      ],
    );
  }

  // ── Refeição ────────────────────────────────────────────────

  Widget _cartaoRefeicao(Refeicao r) {
    final feita = _feitas.contains(r.id);
    final ocupada = _gravando.contains(r.id);
    final t = r.total;

    return PhdCard(
      accentBar: feita ? AppColors.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.nome, style: AppText.title(15.5)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (r.horarioTexto != null) r.horarioTexto!,
                        '${t.kcal.round()} kcal',
                      ].join('  ·  '),
                      style: AppText.caption(11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: ocupada ? null : () => _marcar(r, !feita),
                tooltip: feita
                    ? 'Desmarcar ${r.nome}'
                    : 'Marcar ${r.nome} como feita',
                icon: Icon(
                  feita
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 28,
                  color: feita ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._blocosDeItens(r),
        ],
      ),
    );
  }

  /// Monta as linhas da refeição, com os substitutos juntos.
  ///
  /// Item solto é uma linha. Grupo de substitutos vira um bloco "escolha um",
  /// porque o aluno precisa entender que come **um** deles — listar os três
  /// em sequência faria ele comer os três.
  List<Widget> _blocosDeItens(Refeicao r) {
    final soltos = <ItemRefeicao>[];
    final grupos = <String, List<ItemRefeicao>>{};

    for (final i in r.itens) {
      final g = i.grupoSubstituicao;
      if (g == null) {
        soltos.add(i);
      } else {
        grupos.putIfAbsent(g, () => []).add(i);
      }
    }

    return [
      for (final i in soltos) _linhaItem(i),
      for (final itens in grupos.values)
        if (itens.length == 1)
          // Grupo que sobrou com um item só não é escolha: mostra como
          // item normal em vez de "escolha um" com uma opção.
          _linhaItem(itens.first)
        else
          _blocoSubstitutos(itens),
    ];
  }

  Widget _linhaItem(ItemRefeicao i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: AppSpacing.sm),
            child: Icon(Icons.circle, size: 5, color: AppColors.textMuted),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.alimento.rotulo, style: AppText.body(14)),
                const SizedBox(height: 1),
                Text(
                  i.quantidadeTexto,
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (i.observacoes != null && i.observacoes!.trim().isNotEmpty)
            Tooltip(
              message: i.observacoes!,
              child: Icon(Icons.info_outline_rounded,
                  size: 15, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _blocoSubstitutos(List<ItemRefeicao> itens) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.sm + 2, AppSpacing.md, AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded,
                  size: 15, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(
                'Escolha um',
                style: AppText.caption(11, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final i in itens)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(i.alimento.rotulo, style: AppText.body(13.5)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    i.quantidadeTexto,
                    style: AppText.caption(11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _rodapeAssinatura(PlanoAlimentar p) {
    final em = p.assinadoEm!;
    return Row(
      children: [
        Icon(Icons.verified_rounded, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Plano prescrito por nutricionista · CRN ${p.crnAssinatura} · '
            '${em.day.toString().padLeft(2, '0')}/'
            '${em.month.toString().padLeft(2, '0')}/${em.year}',
            style: AppText.caption(11, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}
