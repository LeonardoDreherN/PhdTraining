import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/services/treino_service.dart';
import '../../../core/services/execucao_service.dart';

class ExecutarTreinoScreen extends StatefulWidget {
  final Map<String, dynamic> ficha;
  final bool modoVideo;
  final int diaSelecionado;
  const ExecutarTreinoScreen({
    super.key,
    required this.ficha,
    this.modoVideo = false,
    required this.diaSelecionado,
  });

  @override
  State<ExecutarTreinoScreen> createState() => _ExecutarTreinoScreenState();
}

class _ExecutarTreinoScreenState extends State<ExecutarTreinoScreen>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _exercicios = [];
  bool _carregando = true;
  int _exercicioAtual = 0;
  int _serieAtual = 1;
  bool _processando = false;

  // Timer descanso
  Timer? _timer;
  int _segundosRestantes = 0;
  bool _timerAtivo = false;

  // Countdown início
  bool _showCountdown = true;
  int _countdown = 3;
  Timer? _countdownTimer;
  late AnimationController _countdownController;

  // Modo demonstração
  bool _mostrandoDemo = false;

  // Log de execução
  final List<Map<String, dynamic>> _execucaoLog = [];
  List<Map<String, dynamic>> _seriesLog = [];

  final _inicioTreino = DateTime.now();

  @override
  void initState() {
    super.initState();
    _mostrandoDemo = false; // ativa apenas após o countdown
    _countdownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _carregar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _countdownController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final lista = await FichaService.listarExercicios(widget.ficha['id']);
    if (!mounted) return;
    setState(() {
      _exercicios = lista;
      _carregando = false;
    });
    _iniciarContagem();
  }

  void _iniciarContagem() {
    _countdownController.forward(from: 0);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_countdown > 1) {
        setState(() => _countdown--);
        _countdownController.forward(from: 0);
      } else {
        t.cancel();
        setState(() => _countdown = 0);
        Future.delayed(const Duration(milliseconds: 650), () {
          if (mounted) {
            setState(() {
              _showCountdown = false;
              _mostrandoDemo = widget.modoVideo;
            });
          }
        });
      }
    });
  }

  void _iniciarTimer(int segundos) {
    _timer?.cancel();
    setState(() {
      _segundosRestantes = segundos;
      _timerAtivo = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_segundosRestantes <= 0) {
        t.cancel();
        setState(() => _timerAtivo = false);
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  Future<void> _proximaSerie() async {
    if (_processando) return;
    setState(() => _processando = true);
    try {
      final ex = _exercicios[_exercicioAtual];
      final exercicio = ex['exercicios'] as Map<String, dynamic>;
      final totalSeries = ex['series'] as int? ?? 3;

      final carga = await _mostrarInputCarga(
        serieNum: _serieAtual,
        exercicioNome: exercicio['nome'] ?? '',
      );

      if (!mounted) return;

      _seriesLog.add({
        'numero': _serieAtual,
        'carga_kg': carga,
        'repeticoes': ex['repeticoes'] ?? '-',
      });

      if (_serieAtual < totalSeries) {
        final descanso = ex['descanso_segundos'] as int? ?? 60;
        setState(() => _serieAtual++);
        _iniciarTimer(descanso);
      } else {
        _finalizarExercicioAtual();
        if (_exercicioAtual < _exercicios.length - 1) {
          _timer?.cancel();
          setState(() {
            _exercicioAtual++;
            _serieAtual = 1;
            _timerAtivo = false;
            if (widget.modoVideo) _mostrandoDemo = true;
          });
        } else {
          await _finalizarTreino();
        }
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _finalizarExercicioAtual() {
    final ex = _exercicios[_exercicioAtual];
    final exercicio = ex['exercicios'] as Map<String, dynamic>;
    _execucaoLog.add({
      'exercicio_id': exercicio['id']?.toString() ?? '',
      'exercicio_nome': exercicio['nome'] ?? '',
      'grupo_muscular': exercicio['grupo_muscular'] ?? '',
      'series': List<Map<String, dynamic>>.from(_seriesLog),
    });
    _seriesLog = [];
  }

  Future<double?> _mostrarInputCarga({
    required int serieNum,
    required String exercicioNome,
  }) async {
    if (!mounted) return null;
    final ctrl = TextEditingController();
    return showModalBottomSheet<double?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.active.withValues(alpha:0.25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.active.withValues(alpha:0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: AppColors.active, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Série $serieNum concluída!',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(exercicioNome,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Qual foi a carga desta série?',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(color: AppColors.textHint, fontSize: 40),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text('kg',
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 24,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const Divider(color: AppColors.divider),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 50),
                      ),
                      child: const Text('Sem carga'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        final val = double.tryParse(ctrl.text.replaceAll(',', '.'));
                        Navigator.pop(ctx, val);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        minimumSize: const Size(0, 50),
                      ),
                      child: const Text('Confirmar',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmarEncerrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Encerrar treino?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('O progresso até aqui será salvo no relatório.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Encerrar', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) await _finalizarTreino();
  }

  Future<void> _finalizarTreino() async {
    _timer?.cancel();
    if (_seriesLog.isNotEmpty) _finalizarExercicioAtual();

    await TreinoService.marcarConcluido(widget.ficha['id'].toString(), widget.diaSelecionado);

    try {
      await ExecucaoService.salvar(
        fichaId: widget.ficha['id'].toString(),
        fichaNome: widget.ficha['nome'] ?? '',
        detalhes: _execucaoLog,
        duracaoMinutos: DateTime.now().difference(_inicioTreino).inMinutes,
        totalExercicios: _exercicios.length,
      );
    } catch (e) {
      debugPrint('Relatório: $e');
    }

    if (!mounted) return;

    final minutos = DateTime.now().difference(_inicioTreino).inMinutes;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConcluidoModal(
        nomeFicha: widget.ficha['nome'] ?? '',
        totalExercicios: _exercicios.length,
        minutos: minutos < 1 ? 1 : minutos,
        onFinalizar: () {
          Navigator.pop(context);
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildConteudo(),
          if (_showCountdown)
            Positioned.fill(
              child: _CountdownOverlay(
                numero: _countdown,
                controller: _countdownController,
                nomeFicha: widget.ficha['nome'] ?? '',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConteudo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_exercicios.isEmpty) {
      return Column(children: [
        AppBar(backgroundColor: AppColors.background, title: Text(widget.ficha['nome'] ?? '')),
        const Expanded(
          child: Center(
            child: Text('Nenhum exercício nesta ficha',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ]);
    }
    if (_mostrandoDemo) return _buildDemo();

    final ex = _exercicios[_exercicioAtual];
    final exercicio = ex['exercicios'] as Map<String, dynamic>;
    final totalSeries = ex['series'] as int? ?? 3;

    return Column(
      children: [
        AppBar(
          backgroundColor: AppColors.background,
          title: Text(widget.ficha['nome'] ?? ''),
          actions: [
            TextButton(
              onPressed: _confirmarEncerrar,
              child: const Text('Encerrar', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
        _buildProgressBar(_exercicios.length),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildExercicioCard(exercicio, ex),
                const SizedBox(height: 24),
                _buildSeriesIndicador(totalSeries),
                const SizedBox(height: 24),
                if (_timerAtivo) _buildTimer() else _buildBotaoSerie(totalSeries),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── DEMONSTRAÇÃO (modo vídeo) ──────────────────────────────
  Widget _buildDemo() {
    final ex = _exercicios[_exercicioAtual];
    final exercicio = ex['exercicios'] as Map<String, dynamic>;
    final midia = exercicio['midia_url'] as String?;
    final isFirst = _exercicioAtual == 0;

    return Column(
      children: [
        AppBar(
          backgroundColor: AppColors.background,
          title: Text(isFirst ? 'Primeiro Exercício' : 'Próximo Exercício'),
          actions: [
            TextButton(
              onPressed: () => setState(() => _mostrandoDemo = false),
              child: const Text('Pular', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
        _buildProgressBar(_exercicios.length),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: midia != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(midia, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const _SemMidia()),
                        )
                      : const _SemMidia(),
                ),
                const SizedBox(height: 20),
                Text(
                  exercicio['nome'] ?? '',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                if ((exercicio['grupo_muscular'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha:0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(exercicio['grupo_muscular'],
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildInfoChip(Icons.repeat_rounded, '${ex['series'] ?? 3} séries'),
                    _buildInfoChip(Icons.tag, '${ex['repeticoes'] ?? '-'} reps'),
                    if (ex['descanso_segundos'] != null)
                      _buildInfoChip(Icons.timer_outlined, '${ex['descanso_segundos']}s descanso'),
                    if (ex['carga'] != null && ex['carga'].toString().isNotEmpty)
                      _buildInfoChip(Icons.monitor_weight_outlined, '${ex['carga']}kg sugerido'),
                  ],
                ),
                if (midia != null) ...[
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(midia);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.play_circle_outline, size: 20),
                      label: const Text('Assistir execução'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => setState(() => _mostrandoDemo = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Iniciar Exercício',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 15),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  // ── TREINO NORMAL ──────────────────────────────────────────
  Widget _buildProgressBar(int total) {
    return Column(
      children: [
        LinearProgressIndicator(
          value: (_exercicioAtual + 1) / total,
          backgroundColor: AppColors.surface,
          color: AppColors.primary,
          minHeight: 4,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exercício ${_exercicioAtual + 1} de $total',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text('${((_exercicioAtual + 1) / total * 100).toInt()}%',
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExercicioCard(Map<String, dynamic> exercicio, Map<String, dynamic> ex) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: exercicio['midia_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(exercicio['midia_url'], fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.fitness_center, color: AppColors.primary, size: 48)),
                  )
                : const Icon(Icons.fitness_center, color: AppColors.primary, size: 48),
          ),
          const SizedBox(height: 16),
          Text(exercicio['nome'] ?? '',
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          if ((exercicio['grupo_muscular'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(exercicio['grupo_muscular'],
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoBox('Séries', '${ex['series'] ?? 3}'),
              _buildInfoBox('Reps', ex['repeticoes'] ?? '-'),
              if (ex['carga'] != null && ex['carga'].toString().isNotEmpty)
                _buildInfoBox('Carga', '${ex['carga']}kg'),
              if (ex['descanso_segundos'] != null)
                _buildInfoBox('Descanso', '${ex['descanso_segundos']}s'),
            ],
          ),
          // Series log for current exercise
          if (_seriesLog.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 8),
            ..._seriesLog.map((s) {
              final carga = s['carga_kg'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(color: AppColors.active, shape: BoxShape.circle),
                      child: Center(
                        child: Text('${s['numero']}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      carga != null
                          ? '${carga}kg × ${s['repeticoes']} reps'
                          : '${s['repeticoes']} reps',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBox(String label, String value) {
    return Column(
      children: [
        Text(value.toString(),
            style: const TextStyle(
                color: AppColors.primary, fontSize: 22, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _buildSeriesIndicador(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final feita = i < _serieAtual - 1;
        final atual = i == _serieAtual - 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: atual ? 32 : 24,
          height: 8,
          decoration: BoxDecoration(
            color: feita ? AppColors.active : atual ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: feita ? AppColors.active : atual ? AppColors.primary : AppColors.divider,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimer() {
    final m = _segundosRestantes ~/ 60;
    final s = _segundosRestantes % 60;
    return Column(
      children: [
        const Text('Descanso', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 8),
        Text('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
            style: const TextStyle(
                color: AppColors.primary, fontSize: 56, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            _timer?.cancel();
            setState(() => _timerAtivo = false);
          },
          style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
          child: const Text('Pular Descanso'),
        ),
      ],
    );
  }

  Widget _buildBotaoSerie(int totalSeries) {
    final ultima = _serieAtual == totalSeries && _exercicioAtual == _exercicios.length - 1;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _processando ? null : _proximaSerie,
        style: ElevatedButton.styleFrom(
          backgroundColor: ultima ? AppColors.active : AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _processando
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(
                ultima
                    ? 'Finalizar Treino'
                    : _serieAtual == totalSeries
                        ? 'Última Série — Concluir Exercício'
                        : 'Série $_serieAtual concluída — Próxima',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

// ── PLACEHOLDER SEM MÍDIA ─────────────────────────────────────
class _SemMidia extends StatelessWidget {
  const _SemMidia();
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.fitness_center, color: AppColors.primary, size: 64),
        SizedBox(height: 8),
        Text('Sem imagem de demonstração',
            style: TextStyle(color: AppColors.textHint, fontSize: 12)),
      ],
    );
  }
}

// ── COUNTDOWN OVERLAY ─────────────────────────────────────────
class _CountdownOverlay extends StatelessWidget {
  final int numero;
  final AnimationController controller;
  final String nomeFicha;

  const _CountdownOverlay({
    required this.numero,
    required this.controller,
    required this.nomeFicha,
  });

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 34),
              const SizedBox(height: 10),
              Text(nomeFicha,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 52),
              AnimatedBuilder(
                animation: controller,
                builder: (_, __) => SizedBox(
                  width: 210,
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(210, 210),
                        painter: _CirclePainter(controller.value),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: Tween<double>(begin: 0.3, end: 1.0).animate(
                            CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                          ),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Text(
                          numero > 0 ? '$numero' : 'Vai!',
                          key: ValueKey(numero),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: numero > 0 ? 90 : 50,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 52),
              Text(
                'Prepare-se para treinar',
                style: TextStyle(color: AppColors.textSecondary.withValues(alpha:0.55), fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  final double progress;
  _CirclePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const stroke = 12.0;
    final radius = size.width / 2 - stroke / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha:0.07)
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke,
    );

    final curved = Curves.easeIn.transform(progress.clamp(0.0, 1.0));
    if (curved > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * curved,
        false,
        Paint()
          ..color = AppColors.primary
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CirclePainter old) => old.progress != progress;
}

// ── MODAL DE CONCLUSÃO ────────────────────────────────────────
class _ConcluidoModal extends StatefulWidget {
  final String nomeFicha;
  final int totalExercicios;
  final int minutos;
  final VoidCallback onFinalizar;

  const _ConcluidoModal({
    required this.nomeFicha,
    required this.totalExercicios,
    required this.minutos,
    required this.onFinalizar,
  });

  @override
  State<_ConcluidoModal> createState() => _ConcluidoModalState();
}

class _ConcluidoModalState extends State<_ConcluidoModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.45, curve: Curves.easeIn));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.active.withValues(alpha:0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.active.withValues(alpha:0.12),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.active.withValues(alpha:0.12),
                    border: Border.all(color: AppColors.active.withValues(alpha:0.35), width: 2),
                  ),
                  child: const Icon(Icons.emoji_events_rounded, color: AppColors.active, size: 50),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Treino Concluído!',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(widget.nomeFicha,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStat(Icons.fitness_center_rounded, '${widget.totalExercicios}', 'exercícios'),
                    Container(width: 1, height: 36, color: AppColors.divider),
                    _buildStat(Icons.timer_outlined, '${widget.minutos}', 'minutos'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: widget.onFinalizar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.active,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Finalizar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.active, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
      ],
    );
  }
}
