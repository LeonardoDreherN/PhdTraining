import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

enum _Metrica { gordura, massaGorda, massaMagra }

class AvaliacaoEvolucaoChart extends StatefulWidget {
  /// Lista de avaliações ordenadas por data (ascendente).
  /// Cada mapa deve ter: data_avaliacao, perc_gordura, massa_gorda, massa_magra.
  final List<Map<String, dynamic>> avaliacoes;

  const AvaliacaoEvolucaoChart({super.key, required this.avaliacoes});

  @override
  State<AvaliacaoEvolucaoChart> createState() => _AvaliacaoEvolucaoChartState();
}

class _AvaliacaoEvolucaoChartState extends State<AvaliacaoEvolucaoChart> {
  _Metrica _selecionada = _Metrica.gordura;

  static const _tabs = [
    (_Metrica.gordura,    '% Gordura'),
    (_Metrica.massaGorda, 'M. Gorda'),
    (_Metrica.massaMagra, 'M. Magra'),
  ];

  double? _valor(Map<String, dynamic> av) {
    switch (_selecionada) {
      case _Metrica.gordura:    return (av['perc_gordura'] as num?)?.toDouble();
      case _Metrica.massaGorda: return (av['massa_gorda']  as num?)?.toDouble();
      case _Metrica.massaMagra: return (av['massa_magra']  as num?)?.toDouble();
    }
  }

  String _unidade() {
    return _selecionada == _Metrica.gordura ? '%' : 'kg';
  }

  String _dataLabel(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Only evaluations that have the selected metric
    final dados = widget.avaliacoes
        .map((av) => (av: av, val: _valor(av)))
        .where((e) => e.val != null)
        .toList();

    if (dados.length < 2) return const SizedBox.shrink();

    final spots = dados
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.val!))
        .toList();

    final vals = spots.map((s) => s.y).toList()..sort();
    final minY = (vals.first * 0.90).floorToDouble();
    final maxY = (vals.last  * 1.10).ceilToDouble();
    final unidade = _unidade();

    // delta used for y axis interval
    final range = maxY - minY;
    final interval = range < 5 ? 1.0 : range < 20 ? 5.0 : 10.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Evolução',
                  style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              // latest value badge
              Text(
                '${spots.last.y.toStringAsFixed(1)} $unidade',
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // tab selector
          Row(
            children: _tabs.map((t) {
              final sel = t.$1 == _selecionada;
              return GestureDetector(
                onTap: () => setState(() => _selecionada = t.$1),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Colors.white : Colors.white30),
                  ),
                  child: Text(t.$2,
                      style: GoogleFonts.montserrat(
                          color: sel ? Colors.black : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          // chart
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: Colors.white12,
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: interval,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(v % 1 == 0 ? 0 : 1),
                        style: GoogleFonts.montserrat(
                            color: AppColors.textSecondary, fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= dados.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _dataLabel(dados[i].av['data_avaliacao'] as String?),
                            style: GoogleFonts.montserrat(
                                color: AppColors.textSecondary, fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surface,
                    tooltipBorder: const BorderSide(color: Colors.white24),
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} $unidade\n'
                      '${_dataLabel(dados[s.spotIndex].av['data_avaliacao'] as String?)}',
                      GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 11),
                    )).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: Colors.white,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: AppColors.background,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.15),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
