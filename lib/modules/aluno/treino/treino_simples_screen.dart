import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/services/execucao_service.dart';

class TreinoSimplesScreen extends StatefulWidget {
  final Map<String, dynamic> ficha;
  const TreinoSimplesScreen({super.key, required this.ficha});

  @override
  State<TreinoSimplesScreen> createState() => _TreinoSimplesScreenState();
}

class _TreinoSimplesScreenState extends State<TreinoSimplesScreen> {
  List<Map<String, dynamic>> _exercicios = [];
  bool _carregando = true;
  bool _concluindo = false;
  bool _concluido = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final lista = await FichaService.listarExercicios(widget.ficha['id']);
    if (!mounted) return;
    setState(() {
      _exercicios = lista;
      _carregando = false;
    });
  }

  Future<void> _concluir() async {
    setState(() => _concluindo = true);
    try {
      await ExecucaoService.salvar(
        fichaId: widget.ficha['id'].toString(),
        fichaNome: widget.ficha['nome'] ?? 'Treino',
        detalhes: [],
        duracaoMinutos: 0,
        totalExercicios: _exercicios.length,
      );
      if (!mounted) return;
      setState(() {
        _concluido = true;
        _concluindo = false;
      });
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _concluindo = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.ficha['nome'] ?? 'Treino'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _exercicios.isEmpty
              ? const Center(
                  child: Text('Nenhum exercício nesta ficha.',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              : Column(
                  children: [
                    _buildResumo(),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _exercicios.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildCard(i),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _carregando || _exercicios.isEmpty
          ? null
          : _buildBotaoConcluir(),
    );
  }

  Widget _buildResumo() {
    final totalSeries = _exercicios.fold<int>(
        0, (sum, e) => sum + ((e['series'] as int?) ?? 0));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildResumoItem('${_exercicios.length}', 'exercícios'),
          Container(width: 1, height: 32, color: AppColors.divider),
          _buildResumoItem('$totalSeries', 'séries totais'),
        ],
      ),
    );
  }

  Widget _buildResumoItem(String valor, String label) {
    return Column(
      children: [
        Text(valor,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildCard(int index) {
    final item = _exercicios[index];
    final ex = item['exercicios'] as Map<String, dynamic>;
    final nome = ex['nome'] ?? '';
    final grupo = ex['grupo_muscular'] ?? '';
    final series = item['series'] ?? 0;
    final reps = item['repeticoes'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                if (grupo.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(grupo,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$series × $reps',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 17),
              ),
              const Text('séries × reps',
                  style: TextStyle(color: AppColors.textHint, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoConcluir() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _concluido
              ? Container(
                  key: const ValueKey('ok'),
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.active.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.active.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.active, size: 22),
                      SizedBox(width: 8),
                      Text('Treino concluído!',
                          style: TextStyle(
                              color: AppColors.active,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                    ],
                  ),
                )
              : SizedBox(
                  key: const ValueKey('btn'),
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _concluindo ? null : _concluir,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _concluindo
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2.5))
                        : const Text('Concluir treino',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
        ),
      ),
    );
  }
}
