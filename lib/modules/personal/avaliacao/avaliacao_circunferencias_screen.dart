import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avaliacao.dart';
import '../../../core/services/avaliacao_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/circunferencias.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';
import 'avaliacao_resumo.dart';
import 'avaliacao_widgets.dart';

/// Evolução das circunferências: gráfico com até quatro medidas juntas e a
/// tabela comparando duas avaliações à escolha.
class AvaliacaoCircunferenciasScreen extends StatefulWidget {
  const AvaliacaoCircunferenciasScreen({super.key, required this.aluno});

  final Map<String, dynamic> aluno;

  @override
  State<AvaliacaoCircunferenciasScreen> createState() => _AvaliacaoCircunferenciasScreenState();
}

/// Quatro, e não mais: com cinco linhas no mesmo gráfico o olho já não
/// segue nenhuma, e as cores seguintes deixam de ser distinguíveis para
/// quem tem daltonismo.
const _maxSeries = 4;

// Azul, laranja, verde-água e amarelo, nesta ordem: o vermelho é a cor
// de ação do app e não pode parecer uma medida.
const _coresClaro = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100)];
const _coresEscuro = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500)];

class _AvaliacaoCircunferenciasScreenState extends State<AvaliacaoCircunferenciasScreen> {
  List<CircunferenciasDoDia> _dias = [];
  bool _carregando = true;
  String? _erro;

  /// Medida → posição na paleta. A cor acompanha a medida: tirar uma do
  /// gráfico não repinta as outras.
  final _cor = <String, int>{};
  bool _variacao = false;
  int _de = 0;
  int _ate = 0;

  String get _nome => widget.aluno['nome'] as String? ?? 'Aluno';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final dias = await AvaliacaoService.historicoCircunferencias(widget.aluno['id'] as String);
      if (!mounted) return;
      setState(() {
        _dias = dias;
        _de = 0;
        _ate = math.max(0, dias.length - 1);
        _cor.clear();
        final padrao = _medidas.where((c) => const {'cintura', 'quadril', 'abdomen'}.contains(c));
        for (final c in (padrao.isEmpty ? _medidas : padrao).take(_maxSeries)) {
          _cor[c] = _cor.length;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<String> get _medidas => Circunferencia.ordenar(_dias.expand((d) => d.medidas.keys));

  List<Color> get _paleta => AppColors.ehClaro ? _coresClaro : _coresEscuro;

  void _alternar(String chave) {
    setState(() {
      if (_cor.remove(chave) != null) return;
      if (_cor.length >= _maxSeries) {
        avisar(context, 'No máximo $_maxSeries medidas no gráfico. Tire uma para incluir outra.');
        return;
      }
      final livre = List.generate(_maxSeries, (i) => i).firstWhere((i) => !_cor.containsValue(i));
      _cor[chave] = livre;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: appBarAvaliacao(_nome, 'Evolução das circunferências'),
      body: _carregando
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _erro != null
              ? PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não deu para carregar',
                  message: 'Se o banco ainda não tem a migration 0019, rode-a no '
                      'Supabase e tente de novo.\n\n$_erro',
                  actionLabel: 'Tentar de novo',
                  onAction: _carregar,
                )
              : _dias.isEmpty
                  ? const PhdEmptyState(
                      icon: Icons.straighten_rounded,
                      title: 'Nenhuma circunferência ainda',
                      message: 'Meça as circunferências dentro de uma avaliação. '
                          'A partir da segunda, a evolução aparece aqui.',
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      color: AppColors.accent,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
                        children: [
                          if (_dias.length >= 2) ...[
                            const PhdSectionHeader(label: 'Gráfico'),
                            const SizedBox(height: AppSpacing.md),
                            _seletor(),
                            const SizedBox(height: AppSpacing.md),
                            _grafico(),
                            const SizedBox(height: AppSpacing.xxl),
                          ] else ...[
                            PhdAviso(
                              texto: 'Só há uma avaliação com circunferências. '
                                  'O gráfico aparece a partir da segunda.',
                              icone: Icons.info_outline_rounded,
                              cor: AppColors.textMuted,
                              corTexto: AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                          PhdSectionHeader(label: _dias.length >= 2 ? 'Comparativo' : 'Medidas'),
                          const SizedBox(height: AppSpacing.md),
                          _comparativo(),
                        ],
                      ),
                    ),
    );
  }

  // ── Escolha das medidas ──────────────────────────────────

  Widget _seletor() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final c in _medidas)
          _ChipMedida(
            rotulo: Circunferencia.nomeDe(c),
            cor: _cor[c] == null ? null : _paleta[_cor[c]!],
            onTap: () => _alternar(c),
          ),
      ],
    );
  }

  // ── Gráfico ──────────────────────────────────────────────

  Widget _grafico() {
    final series = Circunferencia.ordenar(_cor.keys);
    if (series.isEmpty) {
      return PhdCard(
        child: Text('Escolha acima as medidas que entram no gráfico.',
            style: AppText.body(13.5, color: AppColors.textSecondary)),
      );
    }

    // No modo variação, cada medida parte do primeiro valor dela: é o que
    // deixa pescoço (35 cm) e quadril (100 cm) lado a lado num eixo só.
    double? y(String c, int i) {
      final v = _dias[i].medidas[c];
      if (v == null) return null;
      if (!_variacao) return v;
      final base = _dias.map((d) => d.medidas[c]).firstWhere((x) => x != null)!;
      return (v - base) / base * 100;
    }

    final barras = <LineChartBarData>[];
    final todos = <double>[];
    for (final c in series) {
      final spots = [
        for (var i = 0; i < _dias.length; i++)
          if (y(c, i) case final v?) FlSpot(i.toDouble(), v),
      ];
      todos.addAll(spots.map((s) => s.y));
      final cor = _paleta[_cor[c]!];
      barras.add(LineChartBarData(
        spots: spots,
        color: cor,
        barWidth: 2,
        isStrokeCapRound: true,
        dotData: FlDotData(
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 4,
            color: cor,
            strokeWidth: 2,
            strokeColor: AppColors.surface,
          ),
        ),
      ));
    }

    var minY = todos.reduce(math.min), maxY = todos.reduce(math.max);
    final folga = math.max((maxY - minY) * 0.15, _variacao ? 1.0 : 2.0);
    minY = (minY - folga).floorToDouble();
    maxY = (maxY + folga).ceilToDouble();
    final intervalo = _intervalo(maxY - minY);
    final unidade = _variacao ? '%' : 'cm';

    String rotuloY(double v) {
      final t = numBr(v, casas: 0);
      return _variacao && v > 0 ? '+$t' : t;
    }

    return PhdCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _variacao ? 'Variação desde a primeira medida (%)' : 'Circunferência (cm)',
                    style: AppText.caption(12, color: AppColors.textSecondary),
                  ),
                ),
                _Alternador(
                  opcoes: const ['cm', '%'],
                  selecionada: _variacao ? 1 : 0,
                  onChanged: (i) => setState(() => _variacao = i == 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (_dias.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: barras,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: intervalo,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: _variacao && v == 0 ? AppColors.lineStrong : AppColors.line,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: intervalo,
                      getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                          ? const SizedBox.shrink()
                          : Text(rotuloY(v), style: AppText.caption(10, color: AppColors.textMuted)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i != v || i < 0 || i >= _dias.length) return const SizedBox.shrink();
                        // Com muitas avaliações, um rótulo sim, outro não.
                        if (_dias.length > 6 && i % 2 == 1 && i != _dias.length - 1) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_dataCurta(_dias[i].data),
                              style: AppText.caption(10, color: AppColors.textMuted)),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surfaceHigh,
                    tooltipBorder: BorderSide(color: AppColors.lineStrong),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (tocados) => [
                      for (final (n, t) in tocados.indexed)
                        LineTooltipItem(
                          '${n == 0 ? '${Datas.curta(_dias[t.x.toInt()].data)}\n' : ''}'
                          '${Circunferencia.nomeDe(series[t.barIndex])}: '
                          '${numBr(_dias[t.x.toInt()].medidas[series[t.barIndex]])} cm'
                          '${_variacao ? ' (${t.y >= 0 ? '+' : '−'}${numBr(t.y.abs())}%)' : ''}',
                          AppText.caption(11.5, color: AppColors.textPrimary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Legenda: a cor sozinha não identifica a linha.
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.sm),
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: 6,
              children: [
                for (final c in series)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: _paleta[_cor[c]!], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(Circunferencia.nomeDe(c), style: AppText.caption(12, color: AppColors.textSecondary)),
                    ],
                  ),
              ],
            ),
          ),
          if (_variacao) ...[
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Text('Toque num ponto para ver o valor em $unidade e em centímetros.',
                  style: AppText.caption(11, color: AppColors.textMuted)),
            ),
          ],
        ],
      ),
    );
  }

  double _intervalo(double faixa) {
    for (final passo in [1.0, 2.0, 5.0, 10.0, 20.0, 50.0]) {
      if (faixa / passo <= 6) return passo;
    }
    return 100;
  }

  String _dataCurta(DateTime d) {
    // Ano só quando as avaliações atravessam anos.
    final variosAnos = _dias.first.data.year != _dias.last.data.year;
    final dm = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return variosAnos ? '$dm/${d.year % 100}' : dm;
  }

  // ── Comparativo ──────────────────────────────────────────

  Widget _comparativo() {
    if (_dias.length < 2) {
      final dia = _dias.single;
      return PhdCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, c) in Circunferencia.ordenar(dia.medidas.keys).indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 0.5, color: AppColors.line, indent: AppSpacing.lg),
              LinhaMedida(rotulo: Circunferencia.nomeDe(c), valor: '${numBr(dia.medidas[c])} cm'),
            ],
          ],
        ),
      );
    }

    final de = _dias[_de], ate = _dias[_ate];
    final linhas = [
      for (final c in Circunferencia.ordenar(ate.medidas.keys.where(de.medidas.containsKey)))
        LinhaComparacao(Circunferencia.nomeDe(c), de.medidas[c]!, ate.medidas[c]!, 'cm',
            menorEhMelhor: Circunferencia.menorEhMelhorDe(c)),
    ];
    final soDeUmLado = {...de.medidas.keys, ...ate.medidas.keys}.length - linhas.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _escolhaData('De', _de, (i) => setState(() => _de = i))),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _escolhaData('Até', _ate, (i) => setState(() => _ate = i))),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PhdCard(
          child: linhas.isEmpty
              ? Text(
                  _de == _ate
                      ? 'Escolha duas avaliações diferentes.'
                      : 'Nenhuma circunferência foi medida nas duas datas.',
                  style: AppText.body(13.5, color: AppColors.textSecondary),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('MEDIDA', style: AppText.label())),
                          SizedBox(width: 52, child: Text(Datas.curta(de.data), textAlign: TextAlign.end, style: AppText.label())),
                          SizedBox(width: 60, child: Text(Datas.curta(ate.data), textAlign: TextAlign.end, style: AppText.label())),
                          const SizedBox(width: 64),
                        ],
                      ),
                    ),
                    for (final l in linhas)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(l.rotulo, style: AppText.body(13.5, color: AppColors.textSecondary)),
                            ),
                            SizedBox(
                              width: 52,
                              child: Text(numBr(l.anterior),
                                  textAlign: TextAlign.end, style: AppText.caption(13, color: AppColors.textMuted)),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(numBr(l.atual), textAlign: TextAlign.end, style: AppText.number(14)),
                            ),
                            SizedBox(
                              width: 64,
                              child: Text(
                                deltaBr(l.atual, l.anterior) ?? '',
                                textAlign: TextAlign.end,
                                style: AppText.bodyStrong(12.5, color: l.nivel.tom.onDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Valores em cm. Verde e laranja só em cintura e abdômen, onde diminuir é sempre bom; '
          'nas outras, o sentido depende do objetivo.'
          '${soDeUmLado > 0 && linhas.isNotEmpty ? ' $soDeUmLado ${soDeUmLado == 1 ? 'medida foi feita' : 'medidas foram feitas'} só numa das datas.' : ''}',
          style: AppText.caption(11.5, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _escolhaData(String rotulo, int atual, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.rMd),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: atual,
          isExpanded: true,
          dropdownColor: AppColors.surfaceHigh,
          icon: Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
          selectedItemBuilder: (_) => [
            for (final d in _dias)
              Align(
                alignment: Alignment.centerLeft,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '$rotulo  ', style: AppText.caption(12, color: AppColors.textMuted)),
                  TextSpan(text: Datas.curta(d.data), style: AppText.bodyStrong(13.5)),
                ])),
              ),
          ],
          items: [
            for (final (i, d) in _dias.indexed)
              DropdownMenuItem(value: i, child: Text(Datas.longa(d.data), style: AppText.body(14))),
          ],
          onChanged: (i) {
            if (i != null) onChanged(i);
          },
        ),
      ),
    );
  }
}

/// Chip de medida: selecionado, mostra a cor da linha dele no gráfico.
class _ChipMedida extends StatelessWidget {
  const _ChipMedida({required this.rotulo, required this.cor, required this.onTap});

  final String rotulo;
  final Color? cor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sel = cor != null;
    return Semantics(
      button: true,
      selected: sel,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rPill,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
          decoration: BoxDecoration(
            color: sel ? AppColors.surfaceHigh : Colors.transparent,
            borderRadius: AppRadius.rPill,
            border: Border.all(color: sel ? AppColors.lineStrong : AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sel) ...[
                Container(width: 9, height: 9, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                const SizedBox(width: 7),
              ],
              Text(
                rotulo,
                style: sel
                    ? AppText.bodyStrong(12.5, color: AppColors.textPrimary)
                    : AppText.caption(12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dois botões colados, um aceso: cm ou %.
class _Alternador extends StatelessWidget {
  const _Alternador({required this.opcoes, required this.selecionada, required this.onChanged});

  final List<String> opcoes;
  final int selecionada;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.rPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, o) in opcoes.indexed)
            InkWell(
              onTap: () => onChanged(i),
              borderRadius: AppRadius.rPill,
              child: Container(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 30),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: i == selecionada ? AppColors.surface : Colors.transparent,
                  borderRadius: AppRadius.rPill,
                ),
                child: Text(
                  o,
                  style: i == selecionada
                      ? AppText.bodyStrong(12.5, color: AppColors.textPrimary)
                      : AppText.caption(12.5, color: AppColors.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
