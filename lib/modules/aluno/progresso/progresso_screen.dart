import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/progresso_service.dart';

class ProgressoScreen extends StatefulWidget {
  const ProgressoScreen({super.key});

  @override
  State<ProgressoScreen> createState() => _ProgressoScreenState();
}

class _ProgressoScreenState extends State<ProgressoScreen>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  late final TabController _tab;

  List<Map<String, dynamic>> _fotos = [];
  List<Map<String, dynamic>> _avaliacoes = [];
  List<Map<String, dynamic>> _execucoes = [];
  bool _carregando = true;
  bool _enviando = false;
  String? _alunoId;

  static const _meses = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      _alunoId = await ProgressoService.getAlunoId();
      if (_alunoId == null) return;

      final results = await Future.wait([
        ProgressoService.listarFotos(_alunoId!),
        _carregarAvaliacoes(_alunoId!),
        _carregarExecucoes(_alunoId!),
      ]);
      setState(() {
        _fotos = (results[0] as List).cast<Map<String, dynamic>>();
        _avaliacoes = (results[1] as List).cast<Map<String, dynamic>>();
        _execucoes = (results[2] as List).cast<Map<String, dynamic>>();
      });
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<List<Map<String, dynamic>>> _carregarAvaliacoes(String alunoId) async {
    try {
      final bio = await _db
          .from('avaliacao_morfologica_bioimpedancia')
          .select()
          .eq('aluno_id', alunoId)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: true);
      if ((bio as List).isNotEmpty) {
        return List<Map<String, dynamic>>.from(bio);
      }
      final dobras = await _db
          .from('avaliacao_morfologica_dobras')
          .select()
          .eq('aluno_id', alunoId)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: true);
      return List<Map<String, dynamic>>.from(dobras);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _carregarExecucoes(String alunoId) async {
    try {
      final data = await _db
          .from('treino_execucoes')
          .select('executado_em, detalhes')
          .eq('aluno_id', alunoId)
          .order('executado_em', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  // ── Extracted exercise loads ─────────────────────────────────────────────
  // Returns: { exercicioNome: [ {data: DateTime, maxCarga: double} ] }
  Map<String, List<_PontoLoad>> get _loadsPorExercicio {
    final result = <String, List<_PontoLoad>>{};
    for (final ex in _execucoes) {
      final data = DateTime.tryParse(ex['executado_em'] as String? ?? '');
      if (data == null) continue;
      final detalhes = ex['detalhes'];
      if (detalhes == null) continue;
      final lista = detalhes is List ? detalhes : [];
      for (final item in lista) {
        if (item is! Map) continue;
        final nome = item['exercicio_nome'] as String? ?? '';
        if (nome.isEmpty) continue;
        final series = item['series'];
        if (series is! List) continue;
        double maxCarga = 0;
        for (final s in series) {
          if (s is! Map) continue;
          final c = s['carga_kg'];
          if (c == null) continue;
          final v = (c as num).toDouble();
          if (v > maxCarga) maxCarga = v;
        }
        if (maxCarga > 0) {
          result.putIfAbsent(nome, () => []).add(_PontoLoad(data, maxCarga));
        }
      }
    }
    // Only exercises with ≥ 2 data points
    result.removeWhere((k, v) => v.length < 2);
    return result;
  }

  // ── Add photo ────────────────────────────────────────────────────────────
  Future<void> _adicionarFoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SourceSheet(),
    );
    if (source == null || !mounted) return;
    final picker = ImagePicker();
    final foto = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 1200);
    if (foto == null || !mounted) return;
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => _FotoFormDialog(foto: foto),
    );
    if (result == null || _alunoId == null || !mounted) return;
    setState(() => _enviando = true);
    try {
      await ProgressoService.adicionarFoto(
        alunoId: _alunoId!,
        foto: foto,
        pesoKg: result['peso'] as double?,
        observacoes: result['observacoes'] as String?,
      );
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Meu Progresso',
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w400, fontSize: 13),
          tabs: const [
            Tab(text: 'Fotos'),
            Tab(text: 'Evolução'),
            Tab(text: 'Cargas'),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 0 && _alunoId != null
          ? FloatingActionButton.extended(
              onPressed: _enviando ? null : _adicionarFoto,
              backgroundColor: AppColors.primary,
              icon: _enviando
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.add_a_photo_rounded),
              label: Text(_enviando ? 'Enviando...' : 'Nova foto',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            )
          : null,
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tab,
              children: [
                _buildFotosTab(),
                _buildEvolucaoTab(),
                _buildCargasTab(),
              ],
            ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 1 — FOTOS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildFotosTab() {
    if (_fotos.isEmpty) return _buildVazioFotos();

    final items = <dynamic>[];
    String? lastMes;
    for (final foto in _fotos) {
      final mes = _mesAno(foto['registrado_em']);
      if (mes != lastMes) {
        items.add(mes);
        lastMes = mes;
      }
      items.add(foto);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _carregar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: items.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) return _buildResumoFotos();
          final item = items[i - 1];
          if (item is String) {
            return Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 12),
              child: Row(children: [
                Text(item,
                    style: GoogleFonts.montserrat(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                const SizedBox(width: 10),
                const Expanded(child: Divider(color: AppColors.divider, height: 1)),
              ]),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildFotoCard(item as Map<String, dynamic>),
          );
        },
      ),
    );
  }

  Widget _buildVazioFotos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 24),
            Text('Registre seu progresso',
                style: GoogleFonts.montserrat(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('Envie uma foto por mês e acompanhe\nsua evolução ao longo do tempo',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            SizedBox(
              width: 200, height: 50,
              child: ElevatedButton.icon(
                onPressed: _adicionarFoto,
                icon: const Icon(Icons.camera_alt_rounded),
                label: Text('Enviar foto',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumoFotos() {
    final primeira = DateTime.parse(_fotos.last['registrado_em']).toLocal();
    final peso = _fotos.first['peso_kg'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(children: [
        Expanded(child: _resumoItem('${_fotos.length}', 'fotos')),
        Container(width: 1, height: 40, color: AppColors.divider),
        Expanded(
          child: _resumoItem(
            '${_meses[primeira.month - 1].substring(0, 3)} ${primeira.year}', 'início'),
        ),
        if (peso != null) ...[
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(child: _resumoItem('${peso}kg', 'peso atual')),
        ],
      ]),
    );
  }

  Widget _resumoItem(String v, String l) => Column(children: [
    Text(v, style: GoogleFonts.montserrat(
        color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
    Text(l, style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 11)),
  ]);

  Widget _buildFotoCard(Map<String, dynamic> foto) {
    final peso = foto['peso_kg'];
    final obs = foto['observacoes'] as String?;
    return GestureDetector(
      onTap: () => _verFotoFullscreen(foto['foto_url']),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.network(
                foto['foto_url'], fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: AppColors.background,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary, strokeWidth: 2))),
                errorBuilder: (_, __, ___) => Container(
                    color: AppColors.background,
                    child: const Center(
                        child: Icon(Icons.broken_image, color: AppColors.textHint, size: 48))),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_formatarData(foto['registrado_em']),
                  style: GoogleFonts.montserrat(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
              if (peso != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.monitor_weight_outlined,
                      color: AppColors.primary, size: 15),
                  const SizedBox(width: 6),
                  Text('$peso kg',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ],
              if (obs != null && obs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('"$obs"',
                    style: GoogleFonts.montserrat(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text('Toque para ampliar',
                    style: GoogleFonts.montserrat(
                        color: AppColors.textHint, fontSize: 11)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  void _verFotoFullscreen(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black, insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: SizedBox.expand(
            child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 2 — EVOLUÇÃO
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildEvolucaoTab() {
    final temPeso = _fotos.where((f) => f['peso_kg'] != null).length >= 2;
    final temComp = _avaliacoes.length >= 2;

    if (!temPeso && !temComp) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.show_chart_rounded, color: AppColors.textHint, size: 56),
            const SizedBox(height: 16),
            Text('Dados insuficientes',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Registre pelo menos 2 fotos com peso\nou aguarde 2 avaliações físicas.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: AppColors.textHint, fontSize: 13)),
          ]),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (temPeso) ...[
          _buildChartCard(
            title: 'Peso corporal',
            unit: 'kg',
            color: AppColors.primary,
            spots: _fotosComPesoSpots(),
            labels: _fotosComPesoLabels(),
          ),
          const SizedBox(height: 16),
        ],
        if (temComp) ...[
          _buildChartCard(
            title: '% Gordura',
            unit: '%',
            color: AppColors.error,
            spots: _avaliacaoSpots('perc_gordura'),
            labels: _avaliacaoLabels(),
          ),
          const SizedBox(height: 16),
          _buildChartCard(
            title: 'Massa Magra',
            unit: 'kg',
            color: const Color(0xFF4FC3F7),
            spots: _avaliacaoSpots('massa_magra'),
            labels: _avaliacaoLabels(),
          ),
          const SizedBox(height: 16),
          _buildChartCard(
            title: 'Massa Gorda',
            unit: 'kg',
            color: AppColors.error,
            spots: _avaliacaoSpots('massa_gorda'),
            labels: _avaliacaoLabels(),
          ),
        ],
      ]),
    );
  }

  List<FlSpot> _fotosComPesoSpots() {
    final comPeso = _fotos
        .where((f) => f['peso_kg'] != null)
        .toList()
        ..sort((a, b) => (a['registrado_em'] as String)
            .compareTo(b['registrado_em'] as String));
    return comPeso.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value['peso_kg'] as num).toDouble()))
        .toList();
  }

  List<String> _fotosComPesoLabels() {
    final comPeso = _fotos
        .where((f) => f['peso_kg'] != null)
        .toList()
        ..sort((a, b) => (a['registrado_em'] as String)
            .compareTo(b['registrado_em'] as String));
    return comPeso.map((f) {
      final dt = DateTime.tryParse(f['registrado_em'] as String? ?? '');
      if (dt == null) return '';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    }).toList();
  }

  List<FlSpot> _avaliacaoSpots(String campo) {
    return _avaliacoes.asMap().entries
        .map((e) {
          final v = (e.value[campo] as num?)?.toDouble();
          return v != null ? FlSpot(e.key.toDouble(), v) : null;
        })
        .whereType<FlSpot>()
        .toList();
  }

  List<String> _avaliacaoLabels() {
    return _avaliacoes.map((av) {
      final dt = DateTime.tryParse(av['data_avaliacao'] as String? ?? '');
      if (dt == null) return '';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    }).toList();
  }

  Widget _buildChartCard({
    required String title,
    required String unit,
    required Color color,
    required List<FlSpot> spots,
    required List<String> labels,
  }) {
    if (spots.length < 2) return const SizedBox.shrink();
    final vals = spots.map((s) => s.y).toList()..sort();
    final minY = (vals.first * 0.93).floorToDouble();
    final maxY = (vals.last * 1.07).ceilToDouble();
    final delta = spots.last.y - spots.first.y;
    final isUp = delta >= 0;
    final deltaStr = '${isUp ? '+' : ''}${delta.toStringAsFixed(1)} $unit';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          Text('${spots.last.y.toStringAsFixed(1)} $unit',
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(deltaStr,
              style: GoogleFonts.montserrat(
                  color: delta == 0
                      ? AppColors.textSecondary
                      : (title.contains('Gordura') ? (isUp ? AppColors.error : AppColors.active)
                          : (isUp ? AppColors.active : AppColors.error)),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 130,
          child: LineChart(LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 38,
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
                    if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(labels[i],
                          style: GoogleFonts.montserrat(
                              color: AppColors.textSecondary, fontSize: 9)),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.surface,
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} $unit',
                        GoogleFonts.montserrat(color: color, fontSize: 11, fontWeight: FontWeight.w600)))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: color,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 4,
                    color: color,
                    strokeWidth: 2,
                    strokeColor: AppColors.background,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0)],
                  ),
                ),
              ),
            ],
          )),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB 3 — CARGAS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCargasTab() {
    final loads = _loadsPorExercicio;
    if (loads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.fitness_center_rounded, color: AppColors.textHint, size: 56),
            const SizedBox(height: 16),
            Text('Sem histórico de cargas',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Registre cargas ao executar treinos.\nAparece após 2+ execuções com carga.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(color: AppColors.textHint, fontSize: 13)),
          ]),
        ),
      );
    }

    final exercicios = loads.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final nome in exercicios) ...[
            _buildCargaCard(nome, loads[nome]!),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildCargaCard(String nome, List<_PontoLoad> pontos) {
    final sorted = [...pontos]..sort((a, b) => a.data.compareTo(b.data));
    final spots = sorted.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.carga))
        .toList();
    final labels = sorted
        .map((p) =>
            '${p.data.day.toString().padLeft(2, '0')}/${p.data.month.toString().padLeft(2, '0')}')
        .toList();

    final maxCarga = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final minCarga = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final atual = sorted.last.carga;
    final delta = sorted.last.carga - sorted.first.carga;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(nome,
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
          Text('${atual.toStringAsFixed(1)} kg',
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          if (delta != 0)
            Text(
              '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
              style: GoogleFonts.montserrat(
                  color: delta > 0 ? AppColors.active : AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: LineChart(LineChartData(
            minY: (minCarga * 0.9).floorToDouble(),
            maxY: (maxCarga * 1.1).ceilToDouble(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: Colors.white10, strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(0),
                    style: GoogleFonts.montserrat(
                        color: AppColors.textSecondary, fontSize: 9),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 20,
                  interval: spots.length <= 6 ? 1 : (spots.length / 4).roundToDouble(),
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(labels[i],
                          style: GoogleFonts.montserrat(
                              color: AppColors.textSecondary, fontSize: 9)),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.surface,
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)} kg',
                        GoogleFonts.montserrat(
                            color: AppColors.active,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)))
                    .toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.active,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3.5,
                    color: AppColors.active,
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
                      AppColors.active.withValues(alpha: 0.15),
                      AppColors.active.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
          )),
        ),
      ]),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _formatarData(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day} de ${_meses[dt.month - 1]} de ${dt.year}';
  }

  String _mesAno(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${_meses[dt.month - 1].toUpperCase()} ${dt.year}';
  }
}

// ─────────────────────────────────────────────────────────────
class _PontoLoad {
  final DateTime data;
  final double carga;
  const _PontoLoad(this.data, this.carga);
}

// ─────────────────────────────────────────────────────────────
class _SourceSheet extends StatelessWidget {
  const _SourceSheet();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Adicionar foto',
              style: GoogleFonts.montserrat(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _opc(context, ImageSource.camera, Icons.camera_alt_rounded, 'Câmera')),
            const SizedBox(width: 12),
            Expanded(child: _opc(context, ImageSource.gallery, Icons.photo_library_rounded, 'Galeria')),
          ]),
        ],
      ),
    );
  }

  Widget _opc(BuildContext ctx, ImageSource src, IconData icon, String label) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, src),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider)),
        child: Column(children: [
          Icon(icon, color: AppColors.primary, size: 36),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.montserrat(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _FotoFormDialog extends StatefulWidget {
  final XFile foto;
  const _FotoFormDialog({required this.foto});
  @override
  State<_FotoFormDialog> createState() => _FotoFormDialogState();
}

class _FotoFormDialogState extends State<_FotoFormDialog> {
  final _pesoCtrl = TextEditingController();
  final _obsCtrl = TextEditingController();
  Uint8List? _previewBytes;

  @override
  void initState() {
    super.initState();
    widget.foto.readAsBytes().then((bytes) {
      if (mounted) setState(() => _previewBytes = bytes);
    });
  }

  @override
  void dispose() {
    _pesoCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity, height: 180,
                child: _previewBytes != null
                    ? Image.memory(_previewBytes!, fit: BoxFit.cover)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
            const SizedBox(height: 20),
            Text('Registrar medidas',
                style: GoogleFonts.montserrat(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Opcionais — mas ajudam a acompanhar sua evolução',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: _pesoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Peso corporal (kg)',
                hintText: 'Ex: 75.5',
                prefixIcon: const Icon(Icons.monitor_weight_outlined,
                    color: AppColors.textSecondary, size: 20),
                labelStyle: GoogleFonts.montserrat(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _obsCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Observações',
                hintText: 'Como você está se sentindo?',
                prefixIcon: const Icon(Icons.notes_rounded,
                    color: AppColors.textSecondary, size: 20),
                labelStyle: GoogleFonts.montserrat(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: Text('Cancelar',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () {
                    final peso = double.tryParse(_pesoCtrl.text.replaceAll(',', '.'));
                    final obs = _obsCtrl.text.trim();
                    Navigator.pop(context, {
                      'peso': peso,
                      'observacoes': obs.isNotEmpty ? obs : null,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: Text('Salvar foto',
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
