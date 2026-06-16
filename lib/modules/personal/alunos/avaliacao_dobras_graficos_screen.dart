import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

// Colors
const _cMM   = Color(0xFF4FC3F7); // light blue — Massa Magra
const _cMG   = Color(0xFFEF5350); // red        — Massa Gorda
const _cBar  = Color(0xFFFFC107); // amber      — individual bars
const _cLine1 = Color(0xFFFFC107); // amber line — %MM
const _cLine2 = Color(0xFFEF5350); // red line   — %MG

// ── measurement maps ────────────────────────────────────────────────
const _perimetria = [
  ('Pescoço',       'pesco_co'),
  ('Ombro',         'ombro'),
  ('Tórax',         'torax'),
  ('Braço Esquerdo','braco_esq'),
  ('Braço Direito', 'braco_dir'),
  ('Cintura',       'cintura'),
  ('Abdômen',       'abdomen'),
  ('Quadril',       'quadril'),
  ('Coxa Direita',  'coxa_dir'),
  ('Coxa Esquerda', 'coxa_esq'),
  ('Perna Direita', 'perna_dir'),
  ('Perna Esquerda','perna_esq'),
];

const _dobras = [
  ('Tricipital',    'tricipital'),
  ('Subescapular',  'subescapular'),
  ('Peitoral',      'peitoral'),
  ('Abdominal',     'abdominal'),
  ('Suprailíaca',   'supraoiliaca'),
  ('Coxa (dobra)',  'coxa'),
  ('Perna (panturrilha)', 'perna'),
  ('Axilar Média',  'axilar_media'),
];

// ── helpers ─────────────────────────────────────────────────────────
String _dateFmt(String? raw, {bool short = false}) {
  if (raw == null) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return '';
  if (short) return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
  return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year.toString().substring(2)}';
}

double? _d(Map<String, dynamic> av, String key) =>
    (av[key] as num?)?.toDouble();

// ════════════════════════════════════════════════════════════════════
class AvaliacaoDobraGraficosScreen extends StatefulWidget {
  final List<Map<String, dynamic>> avaliacoes; // sorted ASC by date
  final Map<String, dynamic> aluno;
  const AvaliacaoDobraGraficosScreen({
    super.key, required this.avaliacoes, required this.aluno,
  });
  @override
  State<AvaliacaoDobraGraficosScreen> createState() =>
      _AvaliacaoDobraGraficosScreenState();
}

enum _Modo { simplificado, completo }

class _AvaliacaoDobraGraficosScreenState
    extends State<AvaliacaoDobraGraficosScreen> {
  _Modo _modo = _Modo.simplificado;

  @override
  Widget build(BuildContext context) {
    final avs    = widget.avaliacoes;
    final latest = avs.last;
    final nome   = (widget.aluno['nome'] as String? ?? '').split(' ').take(2).join(' ');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(nome, style: GoogleFonts.montserrat(
              color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          Text('Evolução — Dobras Cutâneas', style: GoogleFonts.montserrat(
              color: AppColors.textSecondary, fontSize: 11)),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── toggle ─────────────────────────────
            _ModoToggle(modo: _modo, onChange: (m) => setState(() => _modo = m)),
            const SizedBox(height: 16),

            // ── donut: peso corporal (kg) ──────────
            _ChartCard(
              titulo: 'PESO CORPORAL (KG)',
              child: _DonutPeso(av: latest),
            ),

            // ── donut: massa corporal (%) ──────────
            _ChartCard(
              titulo: 'MASSA CORPORAL (%)',
              child: _DonutPerc(av: latest),
            ),

            // ── bar: evolução do peso ──────────────
            if (avs.length >= 2) ...[
              _ChartCard(
                titulo: 'EVOLUÇÃO DO PESO (KG)',
                child: _BarEvoPeso(avs: avs),
              ),
              _ChartCard(
                titulo: 'EVOLUÇÃO DA MASSA (%)',
                child: _LineEvoMassa(avs: avs),
              ),
            ],

            // ── COMPLETO: perimétrica ───────────────
            if (_modo == _Modo.completo && avs.length >= 2) ...[
              const SizedBox(height: 8),
              Center(child: Text('EVOLUÇÃO PERIMÉTRICA',
                  style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary, fontSize: 13,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8))),
              const SizedBox(height: 12),
              ..._perimetria
                  .where((e) => avs.any((av) => _d(av, e.$2) != null))
                  .map((e) => _ChartCard(
                        titulo: e.$1.toUpperCase(),
                        child: _BarMedida(avs: avs, campo: e.$2, unidade: 'cm'),
                      )),
              const SizedBox(height: 8),
              Center(child: Text('EVOLUÇÃO DAS DOBRAS',
                  style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary, fontSize: 13,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8))),
              const SizedBox(height: 12),
              ..._dobras
                  .where((e) => avs.any((av) => _d(av, e.$2) != null))
                  .map((e) => _ChartCard(
                        titulo: e.$1.toUpperCase(),
                        child: _BarMedida(avs: avs, campo: e.$2, unidade: 'mm'),
                      )),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Toggle SIMPLIFICADO / COMPLETO
// ════════════════════════════════════════════════════════════════════
class _ModoToggle extends StatelessWidget {
  final _Modo modo;
  final void Function(_Modo) onChange;
  const _ModoToggle({required this.modo, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      for (final m in _Modo.values)
        GestureDetector(
          onTap: () => onChange(m),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: modo == m ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: modo == m ? Colors.white : Colors.white30),
            ),
            child: Text(
              m == _Modo.simplificado ? 'SIMPLIFICADO' : 'COMPLETO',
              style: GoogleFonts.montserrat(
                color: modo == m ? Colors.black : AppColors.textSecondary,
                fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
// Chart card wrapper
// ════════════════════════════════════════════════════════════════════
class _ChartCard extends StatelessWidget {
  final String titulo;
  final Widget child;
  const _ChartCard({required this.titulo, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(titulo,
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 0.6)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Donut — Peso Corporal (KG)
// ════════════════════════════════════════════════════════════════════
class _DonutPeso extends StatelessWidget {
  final Map<String, dynamic> av;
  const _DonutPeso({required this.av});

  @override
  Widget build(BuildContext context) {
    final mm   = _d(av, 'massa_magra') ?? 0;
    final mg   = _d(av, 'massa_gorda') ?? 0;
    final peso = _d(av, 'peso') ?? (mm + mg);

    if (mm == 0 && mg == 0) {
      return _semDados();
    }

    return Column(children: [
      SizedBox(
        height: 180,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sections: [
              PieChartSectionData(value: mm, color: _cMM, title: '', radius: 55),
              PieChartSectionData(value: mg, color: _cMG, title: '', radius: 55),
            ],
            centerSpaceRadius: 55,
            sectionsSpace: 3,
            startDegreeOffset: -90,
          )),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(peso.toStringAsFixed(0),
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
            Text('KG', style: GoogleFonts.montserrat(
                color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      _LegendaRow(
        cor1: _cMM, texto1: 'Massa Magra ${mm.toStringAsFixed(1)} kg',
        cor2: _cMG, texto2: 'Massa Gorda ${mg.toStringAsFixed(1)} kg',
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
// Donut — Massa Corporal (%)
// ════════════════════════════════════════════════════════════════════
class _DonutPerc extends StatelessWidget {
  final Map<String, dynamic> av;
  const _DonutPerc({required this.av});

  @override
  Widget build(BuildContext context) {
    final percMG = _d(av, 'perc_gordura') ?? 0;
    final percMM = 100 - percMG;

    if (percMG == 0) return _semDados();

    return Column(children: [
      SizedBox(
        height: 180,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(PieChartData(
            sections: [
              PieChartSectionData(value: percMM, color: _cLine1, title: '', radius: 55),
              PieChartSectionData(value: percMG, color: _cMG,    title: '', radius: 55),
            ],
            centerSpaceRadius: 55,
            sectionsSpace: 3,
            startDegreeOffset: -90,
          )),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text('100', style: GoogleFonts.montserrat(
                color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700)),
            Text('%', style: GoogleFonts.montserrat(
                color: AppColors.textSecondary, fontSize: 11)),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      _LegendaRow(
        cor1: _cLine1, texto1: 'Massa Magra ${percMM.toStringAsFixed(1)}%',
        cor2: _cMG,    texto2: 'Massa Gorda ${percMG.toStringAsFixed(1)}%',
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
// Grouped Bar — Evolução do Peso (KG)
// ════════════════════════════════════════════════════════════════════
class _BarEvoPeso extends StatelessWidget {
  final List<Map<String, dynamic>> avs;
  const _BarEvoPeso({required this.avs});

  @override
  Widget build(BuildContext context) {
    final grupos = avs.asMap().entries.map((e) {
      final mm = _d(e.value, 'massa_magra') ?? 0;
      final mg = _d(e.value, 'massa_gorda') ?? 0;
      return BarChartGroupData(
        x: e.key,
        groupVertically: false,
        barRods: [
          BarChartRodData(toY: mm, color: _cMM, width: 18, borderRadius: BorderRadius.circular(3)),
          BarChartRodData(toY: mg, color: _cMG, width: 18, borderRadius: BorderRadius.circular(3)),
        ],
        showingTooltipIndicators: [0, 1],
      );
    }).toList();

    final allVals = avs.expand((av) => [
      _d(av, 'massa_magra') ?? 0, _d(av, 'massa_gorda') ?? 0,
    ]).toList();
    final maxY = (allVals.fold(0.0, (p, v) => v > p ? v : p) * 1.65).ceilToDouble();

    return SizedBox(
      height: 200,
      child: BarChart(BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barGroups: grupos,
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white12, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 6,
            getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
              rod.toY.toStringAsFixed(1),
              GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 22,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= avs.length) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(_dateFmt(avs[i]['data_avaliacao'] as String?),
                    style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 9)));
            },
          )),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      )),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Line Chart — Evolução da Massa (%)
// ════════════════════════════════════════════════════════════════════
class _LineEvoMassa extends StatelessWidget {
  final List<Map<String, dynamic>> avs;
  const _LineEvoMassa({required this.avs});

  @override
  Widget build(BuildContext context) {
    final spotsPercMM = <FlSpot>[];
    final spotsPercMG = <FlSpot>[];
    for (var i = 0; i < avs.length; i++) {
      final mg = _d(avs[i], 'perc_gordura');
      if (mg != null) {
        spotsPercMG.add(FlSpot(i.toDouble(), mg));
        spotsPercMM.add(FlSpot(i.toDouble(), 100 - mg));
      }
    }
    if (spotsPercMG.length < 2) return _semDados();

    return Column(children: [
      SizedBox(
        height: 180,
        child: LineChart(LineChartData(
          minY: 0, maxY: 100,
          gridData: FlGridData(
            show: true, drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white12, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 22, interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= avs.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 4),
                  child: Text(_dateFmt(avs[i]['data_avaliacao'] as String?),
                      style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 9)));
              },
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true, reservedSize: 30, interval: 20,
              getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                  style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 9)),
            )),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              tooltipBorder: const BorderSide(color: Colors.white24),
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                '${s.y.toStringAsFixed(1)}%',
                GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 10),
              )).toList(),
            ),
          ),
          lineBarsData: [
            _lineBar(spotsPercMM, _cLine1),
            _lineBar(spotsPercMG, _cLine2),
          ],
        )),
      ),
      const SizedBox(height: 10),
      const _LegendaRow(
        cor1: _cLine1, texto1: 'Massa Magra',
        cor2: _cLine2, texto2: 'Massa Gorda',
      ),
    ]);
  }

  LineChartBarData _lineBar(List<FlSpot> spots, Color color) =>
      LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2.5,
        isCurved: true,
        curveSmoothness: 0.3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
            radius: 4, color: color,
            strokeWidth: 2, strokeColor: AppColors.background,
          ),
        ),
        belowBarData: BarAreaData(show: false),
      );
}

// ════════════════════════════════════════════════════════════════════
// Individual measurement bar chart
// ════════════════════════════════════════════════════════════════════
class _BarMedida extends StatelessWidget {
  final List<Map<String, dynamic>> avs;
  final String campo;
  final String unidade;
  const _BarMedida({required this.avs, required this.campo, required this.unidade});

  @override
  Widget build(BuildContext context) {
    final dados = avs
        .asMap()
        .entries
        .where((e) => _d(e.value, campo) != null)
        .toList();
    if (dados.isEmpty) return _semDados();

    final maxY = (dados.map((e) => _d(e.value, campo)!).reduce((a, b) => a > b ? a : b) * 1.25).ceilToDouble();

    final grupos = dados.map((e) => BarChartGroupData(
      x: e.key,
      barRods: [BarChartRodData(
        toY: _d(e.value, campo)!,
        color: _cBar,
        width: dados.length <= 4 ? 36 : 24,
        borderRadius: BorderRadius.circular(3),
      )],
      showingTooltipIndicators: [0],
    )).toList();

    return SizedBox(
      height: 150,
      child: BarChart(BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barGroups: grupos,
        gridData: FlGridData(
          show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white12, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.transparent,
            tooltipPadding: EdgeInsets.zero,
            tooltipMargin: 4,
            getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
              rod.toY.toStringAsFixed(1),
              GoogleFonts.montserrat(
                  color: _cBar, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, reservedSize: 20,
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              final entry = dados.where((e) => e.key == i).firstOrNull;
              if (entry == null) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 4),
                child: Text(_dateFmt(entry.value['data_avaliacao'] as String?, short: true),
                    style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 9)));
            },
          )),
          leftTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      )),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Shared helpers
// ════════════════════════════════════════════════════════════════════

class _LegendaRow extends StatelessWidget {
  final Color cor1, cor2;
  final String texto1, texto2;
  const _LegendaRow({required this.cor1, required this.texto1, required this.cor2, required this.texto2});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 11);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Flexible(child: Text(texto1, overflow: TextOverflow.ellipsis, style: style)),
          const SizedBox(width: 5),
          Container(width: 10, height: 10, decoration: BoxDecoration(color: cor1, shape: BoxShape.circle)),
        ])),
        const SizedBox(width: 12),
        Expanded(child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: cor2, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Flexible(child: Text(texto2, overflow: TextOverflow.ellipsis, style: style)),
        ])),
      ]),
    );
  }
}

Widget _semDados() => Padding(
  padding: const EdgeInsets.symmetric(vertical: 20),
  child: Center(child: Text('Sem dados suficientes',
      style: GoogleFonts.montserrat(color: AppColors.textHint, fontSize: 12))),
);
