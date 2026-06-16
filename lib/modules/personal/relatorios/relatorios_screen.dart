import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/execucao_service.dart';

class RelatoriosScreen extends StatefulWidget {
  const RelatoriosScreen({super.key});

  @override
  State<RelatoriosScreen> createState() => _RelatoriosScreenState();
}

class _RelatoriosScreenState extends State<RelatoriosScreen> {
  List<Map<String, dynamic>> _execucoes = [];
  List<Map<String, dynamic>> _filtradas = [];
  bool _carregando = true;
  final Set<String> _expandidos = {};
  final _buscaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await ExecucaoService.listarParaPersonal();
      setState(() {
        _execucoes = lista;
        _filtradas = lista;
      });
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _filtrar(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtradas = _execucoes;
      } else {
        final q = query.toLowerCase();
        _filtradas = _execucoes.where((e) {
          final nome = (e['aluno_nome'] ?? '').toString().toLowerCase();
          final ficha = (e['ficha_nome'] ?? '').toString().toLowerCase();
          return nome.contains(q) || ficha.contains(q);
        }).toList();
      }
    });
  }

  double _calcularVolume(List<dynamic> detalhes) {
    double total = 0;
    for (final ex in detalhes) {
      for (final s in (ex['series'] as List<dynamic>? ?? [])) {
        final carga = (s['carga_kg'] as num?)?.toDouble() ?? 0;
        final repsStr = s['repeticoes']?.toString() ?? '0';
        final reps = int.tryParse(repsStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        total += carga * reps;
      }
    }
    return total;
  }

  String _formatarData(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final agora = DateTime.now();
      final ontem = agora.subtract(const Duration(days: 1));
      final hora =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      if (dt.day == agora.day && dt.month == agora.month && dt.year == agora.year) {
        return 'Hoje, $hora';
      } else if (dt.day == ontem.day && dt.month == ontem.month && dt.year == ontem.year) {
        return 'Ontem, $hora';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às $hora';
    } catch (_) {
      return iso;
    }
  }

  Map<String, dynamic> _calcularStats() {
    final agora = DateTime.now();
    double volumeTotal = 0;
    int treinosMes = 0;
    final alunosUnicos = <String>{};

    for (final e in _execucoes) {
      try {
        final dt = DateTime.parse(e['executado_em']?.toString() ?? '');
        if (dt.month == agora.month && dt.year == agora.year) {
          treinosMes++;
          alunosUnicos.add(e['aluno_id']?.toString() ?? '');
          volumeTotal += _calcularVolume(e['detalhes'] as List<dynamic>? ?? []);
        }
      } catch (_) {}
    }

    return {
      'treinos': treinosMes,
      'alunos': alunosUnicos.length,
      'volume': volumeTotal,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: const Text('Relatórios'),
        centerTitle: false,
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _carregar,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        children: [
                          _buildStats(),
                          const SizedBox(height: 16),
                          _buildBusca(),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                  _filtradas.isEmpty
                      ? SliverFillRemaining(child: _buildVazio())
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _buildCard(_filtradas[i]),
                              childCount: _filtradas.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildStats() {
    final stats = _calcularStats();
    final volume = stats['volume'] as double;
    final volumeLabel = volume >= 1000
        ? '${(volume / 1000).toStringAsFixed(1)}t'
        : volume > 0
            ? '${volume.toStringAsFixed(0)}kg'
            : '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumo deste mês',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('${stats['treinos']}', 'treinos', Icons.fitness_center_rounded),
              ),
              Container(width: 1, height: 48, color: AppColors.divider),
              Expanded(
                child: _buildStatItem('${stats['alunos']}', 'alunos', Icons.people_rounded),
              ),
              Container(width: 1, height: 48, color: AppColors.divider),
              Expanded(
                child: _buildStatItem(volumeLabel, 'volume', Icons.monitor_weight_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildBusca() {
    return TextField(
      controller: _buscaCtrl,
      onChanged: _filtrar,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Buscar aluno ou treino...',
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
        suffixIcon: _buscaCtrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                onPressed: () {
                  _buscaCtrl.clear();
                  _filtrar('');
                },
              )
            : null,
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> ex) {
    final id = ex['id']?.toString() ?? '';
    final expandido = _expandidos.contains(id);
    final detalhes = ex['detalhes'] as List<dynamic>? ?? [];
    final volume = _calcularVolume(detalhes);
    final alunoNome = ex['aluno_nome'] ?? 'Aluno';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (expandido) {
                _expandidos.remove(id);
              } else {
                _expandidos.add(id);
              }
            }),
            borderRadius: expandido
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        alunoNome.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alunoNome,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        Text(ex['ficha_nome'] ?? '',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          children: [
                            _buildTag(Icons.schedule_rounded,
                                _formatarData(ex['executado_em']?.toString())),
                            _buildTag(Icons.timer_outlined,
                                '${ex['duracao_minutos'] ?? 0} min'),
                            _buildTag(Icons.fitness_center,
                                '${ex['total_exercicios'] ?? 0} ex.'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (volume > 0) ...[
                        Text(
                          '${volume.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                              color: AppColors.active, fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const Text('volume',
                            style: TextStyle(color: AppColors.textHint, fontSize: 10)),
                        const SizedBox(height: 4),
                      ],
                      Icon(
                        expandido
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 22,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (expandido) _buildDetalhes(detalhes, volume),
        ],
      ),
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textHint, size: 11),
        const SizedBox(width: 3),
        Text(text, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
      ],
    );
  }

  Widget _buildDetalhes(List<dynamic> detalhes, double volumeTotal) {
    return Column(
      children: [
        const Divider(height: 1, color: AppColors.divider),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detalhes.isEmpty)
                const Text('Nenhum detalhe registrado',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ...detalhes.map((ex) => _buildExercicioDetalhe(ex as Map<String, dynamic>)),
              if (volumeTotal > 0) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.active.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.active.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Volume total do treino',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      Text('${volumeTotal.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                              color: AppColors.active, fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExercicioDetalhe(Map<String, dynamic> ex) {
    final series = ex['series'] as List<dynamic>? ?? [];
    double volumeEx = 0;
    for (final s in series) {
      final carga = (s['carga_kg'] as num?)?.toDouble() ?? 0;
      final reps =
          int.tryParse(s['repeticoes']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0') ?? 0;
      volumeEx += carga * reps;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ex['exercicio_nome'] ?? '',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                    if ((ex['grupo_muscular'] as String?)?.isNotEmpty == true)
                      Text(ex['grupo_muscular'],
                          style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                  ],
                ),
              ),
              if (volumeEx > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.active.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${volumeEx.toStringAsFixed(0)} kg',
                      style: const TextStyle(
                          color: AppColors.active, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...series.asMap().entries.map((entry) {
            final s = entry.value;
            final carga = s['carga_kg'];
            final reps = s['repeticoes'] ?? '-';
            final serieNum = s['numero'] ?? entry.key + 1;

            // Volume da série
            final cargaVal = (carga as num?)?.toDouble() ?? 0;
            final repsVal =
                int.tryParse(reps.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            final volSerie = cargaVal * repsVal;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text('$serieNum',
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      carga != null && cargaVal > 0
                          ? '${carga}kg × $reps reps'
                          : '$reps reps (sem carga)',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  if (volSerie > 0)
                    Text('= ${volSerie.toStringAsFixed(0)}kg',
                        style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(Icons.bar_chart_rounded, color: AppColors.textHint, size: 40),
            ),
            const SizedBox(height: 20),
            const Text('Nenhum relatório ainda',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Os relatórios aparecem aqui quando seus alunos completam treinos no app',
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
