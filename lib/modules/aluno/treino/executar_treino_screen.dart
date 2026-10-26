import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/models/ficha_exercicio.dart';
import '../../../core/services/execucao_service.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// A tela mais usada do produto: o aluno com o celular na mão, no meio da
/// academia, entre uma série e outra.
///
/// Tudo aqui é desenhado para ser lido de relance e tocado com a mão suada:
/// um alvo grande para avançar, números grandes, e nenhuma decisão que possa
/// ser tomada errada por acidente.
class ExecutarTreinoScreen extends StatefulWidget {
  const ExecutarTreinoScreen({
    super.key,
    required this.ficha,
    this.modoVideo = false,
    required this.diaSelecionado,
  });

  final Map<String, dynamic> ficha;
  final bool modoVideo;
  final int diaSelecionado;

  @override
  State<ExecutarTreinoScreen> createState() => _ExecutarTreinoScreenState();
}

class _ExecutarTreinoScreenState extends State<ExecutarTreinoScreen>
    with TickerProviderStateMixin {
  List<FichaExercicio> _itens = [];
  bool _carregando = true;
  String? _erro;

  int _ix = 0;
  int _serie = 1;
  bool _ocupado = false;

  Timer? _descanso;
  int _restam = 0;
  bool _descansando = false;

  bool _contando = true;
  int _contagem = 3;
  Timer? _timerContagem;
  late final AnimationController _pulso;

  bool _demo = false;

  /// Séries já registradas do exercício atual.
  List<Map<String, dynamic>> _seriesDoExercicio = [];

  /// Exercícios já fechados, no formato que vai para `treino_execucoes`.
  final List<Map<String, dynamic>> _log = [];

  /// Última carga usada em cada exercício, para já vir preenchida na próxima
  /// série. Entre séries do mesmo exercício a carga quase nunca muda, e
  /// digitar de novo com a mão suada é o atrito que faz o aluno desistir de
  /// registrar.
  final Map<String, String> _ultimaCarga = {};

  final _inicio = DateTime.now();

  FichaExercicio get _atual => _itens[_ix];
  bool get _ultimoExercicio => _ix == _itens.length - 1;
  bool get _ultimaSerie => _serie >= _atual.series;

  @override
  void initState() {
    super.initState();
    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
    _carregar();
  }

  @override
  void dispose() {
    _descanso?.cancel();
    _timerContagem?.cancel();
    _pulso.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await FichaService.listarExercicios(
        widget.ficha['id'] as String,
      );
      if (!mounted) return;
      setState(() => _itens = lista);
      // Ficha vazia não tem contagem regressiva para quê.
      if (lista.isNotEmpty) _iniciarContagem();
    } catch (e) {
      // Antes não havia `catch`: uma falha de rede deixava o aluno olhando
      // para um indicador de carregamento que nunca terminava.
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _iniciarContagem() {
    _pulso.forward(from: 0);
    _timerContagem = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_contagem > 1) {
        setState(() => _contagem--);
        _pulso.forward(from: 0);
        return;
      }
      t.cancel();
      setState(() => _contagem = 0);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() {
          _contando = false;
          _demo = widget.modoVideo;
        });
      });
    });
  }

  void _comecarDescanso(int segundos) {
    _descanso?.cancel();
    if (segundos <= 0) return;
    setState(() {
      _restam = segundos;
      _descansando = true;
    });
    _descanso = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_restam <= 1) {
        t.cancel();
        setState(() {
          _restam = 0;
          _descansando = false;
        });
      } else {
        setState(() => _restam--);
      }
    });
  }

  void _pularDescanso() {
    _descanso?.cancel();
    setState(() {
      _descansando = false;
      _restam = 0;
    });
  }

  // ── Fluxo ───────────────────────────────────────────────────

  Future<void> _concluirSerie() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      final item = _atual;
      final carga = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _FolhaCarga(
            serie: _serie,
            total: item.series,
            exercicio: item.nome,
            repeticoes: item.repeticoes,
            sugestao: _ultimaCarga[item.id] ?? item.carga,
          ),
        ),
      );
      // Fechar a folha arrastando cancela a série, em vez de registrar uma
      // série sem carga que o aluno não confirmou.
      if (carga == null || !mounted) return;

      if (carga.trim().isNotEmpty) _ultimaCarga[item.id] = carga.trim();

      _seriesDoExercicio.add({
        'numero': _serie,
        'carga': carga.trim(),
        'repeticoes': item.repeticoes ?? '-',
      });

      if (!_ultimaSerie) {
        setState(() => _serie++);
        _comecarDescanso(item.descansoSegundos ?? 60);
        return;
      }

      _fecharExercicio();
      if (!_ultimoExercicio) {
        _descanso?.cancel();
        setState(() {
          _ix++;
          _serie = 1;
          _descansando = false;
          _demo = widget.modoVideo;
        });
      } else {
        await _finalizar();
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Desfaz a última série registrada deste exercício.
  ///
  /// Toque errado acontece o tempo todo com a mão suada, e sem isto o aluno
  /// só podia seguir adiante com o número errado gravado.
  void _desfazerSerie() {
    if (_seriesDoExercicio.isEmpty) return;
    _descanso?.cancel();
    setState(() {
      _seriesDoExercicio.removeLast();
      _serie = _seriesDoExercicio.length + 1;
      _descansando = false;
      _restam = 0;
    });
  }

  void _fecharExercicio() {
    final item = _atual;
    _log.add({
      'exercicio_id': item.exercicioId,
      'exercicio_nome': item.nome,
      'grupo_muscular': item.grupoMuscular ?? '',
      'series': List<Map<String, dynamic>>.from(_seriesDoExercicio),
    });
    _seriesDoExercicio = [];
  }

  Future<void> _finalizar() async {
    _descanso?.cancel();
    if (_seriesDoExercicio.isNotEmpty) _fecharExercicio();

    final minutos = DateTime.now().difference(_inicio).inMinutes;

    String? falha;
    try {
      await ExecucaoService.salvar(
        fichaId: widget.ficha['id'].toString(),
        fichaNome: widget.ficha['nome'] as String? ?? '',
        detalhes: _log,
        duracaoMinutos: minutos,
        totalExercicios: _itens.length,
      );
    } catch (e) {
      // A versão anterior fazia `debugPrint` e seguia para a tela de
      // parabéns. O aluno treinava, lia "concluído", e nada tinha sido
      // gravado — o personal não via a execução e ninguém descobria.
      falha = '$e';
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _Concluido(
        ficha: widget.ficha['nome'] as String? ?? 'Treino',
        exercicios: _itens.length,
        minutos: minutos < 1 ? 1 : minutos,
        series: _log.fold<int>(
          0,
          (s, e) => s + (e['series'] as List).length,
        ),
        falha: falha,
      ),
    );
    if (mounted) context.pop();
  }

  Future<bool> _confirmarSaida() async {
    if (_log.isEmpty && _seriesDoExercicio.isEmpty) return true;
    final sair = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Sair do treino?', style: AppText.title(17)),
        content: Text(
          'As séries que você já marcou não serão salvas.',
          style: AppText.body(13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Continuar treinando',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sair',
                style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    return sair ?? false;
  }

  // ── Interface ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmarSaida() && mounted) {
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Stack(
          children: [
            SafeArea(child: _corpo()),
            if (_contando && _itens.isNotEmpty)
              Positioned.fill(
                child: _Contagem(
                  numero: _contagem,
                  pulso: _pulso,
                  ficha: widget.ficha['nome'] as String? ?? 'Treino',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar o treino',
        message: _erro!,
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }
    if (_itens.isEmpty) {
      return PhdEmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'Treino vazio',
        message: 'Seu personal ainda não montou os exercícios desta ficha. '
            'Fale com ele.',
        actionLabel: 'Voltar',
        onAction: () => context.pop(),
      );
    }
    if (_demo) return _telaDemo();
    return _telaExercicio();
  }

  Widget _barraTopo({required Widget? acao}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              if (await _confirmarSaida() && mounted && context.mounted) {
                context.pop();
              }
            },
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textSecondary, size: 22),
            tooltip: 'Sair do treino',
          ),
          Expanded(
            child: Text(
              '${_ix + 1} de ${_itens.length}',
              style: AppText.number(13, color: AppColors.textMuted),
            ),
          ),
          if (acao != null) acao,
        ],
      ),
    );
  }

  Widget _progresso() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: PhdSegments(total: _itens.length, filled: _ix),
    );
  }

  // ── Demonstração ────────────────────────────────────────────

  Widget _telaDemo() {
    final item = _atual;
    return Column(
      children: [
        _barraTopo(
          acao: TextButton(
            onPressed: () => setState(() => _demo = false),
            child: Text('Pular',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
        ),
        _progresso(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _ix == 0 ? 'Primeiro exercício' : 'Próximo exercício',
                  style: AppText.caption(12.5),
                ),
                const SizedBox(height: 4),
                Text(item.nome, style: AppText.display(24)),
                const SizedBox(height: AppSpacing.lg),
                ClipRRect(
                  borderRadius: AppRadius.rLg,
                  child: _Demonstracao(
                    videoUrl: item.videoUrl,
                    imagemUrl: item.midiaUrl,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    PhdStatusChip(label: item.prescricao),
                    if (item.cargaFormatada != null)
                      PhdStatusChip(label: item.cargaFormatada!),
                    if (item.descansoFormatado != null)
                      PhdStatusChip(label: 'descanso ${item.descansoFormatado}'),
                    if (item.equipamento != null &&
                        item.equipamento!.trim().isNotEmpty)
                      PhdStatusChip(label: item.equipamento!),
                  ],
                ),
                if (item.instrucoes != null &&
                    item.instrucoes!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(item.instrucoes!.trim(),
                      style: AppText.body(13.5, color: AppColors.textSecondary)),
                ],
                _recado(item),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: PhdButton(
            label: 'Começar',
            icon: Icons.play_arrow_rounded,
            onPressed: () => setState(() => _demo = false),
          ),
        ),
      ],
    );
  }

  /// A observação que o personal escreveu para este exercício.
  ///
  /// Ela existe no banco desde o começo e nenhuma tela do aluno mostrava —
  /// o personal escrevia "desce devagar, 3 segundos" e isso não chegava a
  /// ninguém.
  Widget _recado(FichaExercicio item) {
    final obs = item.observacoes?.trim();
    if (obs == null || obs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.tint(AppColors.accent),
          borderRadius: AppRadius.rMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.campaign_outlined, size: 17, color: AppColors.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(obs, style: AppText.body(13, color: AppColors.textPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Execução ────────────────────────────────────────────────

  Widget _telaExercicio() {
    final item = _atual;

    return Column(
      children: [
        _barraTopo(
          acao: item.videoUrl == null && item.midiaUrl == null
              ? null
              : IconButton(
                  onPressed: () => setState(() => _demo = true),
                  icon: const Icon(Icons.ondemand_video_rounded,
                      color: AppColors.textSecondary, size: 20),
                  tooltip: 'Ver demonstração',
                ),
        ),
        _progresso(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.grupoMuscular != null)
                  Text(item.grupoMuscular!.toUpperCase(),
                      style: AppText.caption(11, color: AppColors.accent)),
                const SizedBox(height: 4),
                Text(item.nome, style: AppText.display(26)),
                const SizedBox(height: AppSpacing.xl),
                _serieAtualCartao(item),
                _recado(item),
                if (_seriesDoExercicio.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  _seriesFeitas(),
                ],
              ],
            ),
          ),
        ),
        _rodape(item),
      ],
    );
  }

  Widget _serieAtualCartao(FichaExercicio item) {
    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _numero('Série', '$_serie/${item.series}'),
              _numero('Reps', item.repeticoes?.trim().isEmpty ?? true
                  ? '—'
                  : item.repeticoes!.trim()),
              _numero('Carga', _ultimaCarga[item.id] ?? item.cargaFormatada ?? '—'),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(item.series, (i) {
              final feita = i < _serie - 1;
              final agora = i == _serie - 1;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: agora ? 30 : 22,
                height: 7,
                decoration: BoxDecoration(
                  color: feita
                      ? AppColors.success
                      : agora
                          ? AppColors.accent
                          : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _numero(String rotulo, String valor) {
    return Column(
      children: [
        Text(rotulo, style: AppText.caption(11.5)),
        const SizedBox(height: 4),
        Text(valor, style: AppText.number(22)),
      ],
    );
  }

  Widget _seriesFeitas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Séries registradas', style: AppText.caption(12)),
            ),
            GestureDetector(
              onTap: _desfazerSerie,
              child: Text('Desfazer última',
                  style: AppText.bodyStrong(12.5, color: AppColors.accent)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final s in _seriesDoExercicio)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 15, color: AppColors.success),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Série ${s['numero']}'
                  '${(s['carga'] as String).isEmpty ? '' : '  ·  ${s['carga']}'}',
                  style: AppText.body(13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rodape(FichaExercicio item) {
    if (_descansando) {
      final m = (_restam ~/ 60).toString().padLeft(2, '0');
      final s = (_restam % 60).toString().padLeft(2, '0');
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Text('Descanso', style: AppText.caption(13)),
            const SizedBox(height: 2),
            Text('$m:$s', style: AppText.number(46, color: AppColors.accent)),
            const SizedBox(height: AppSpacing.lg),
            PhdButton(
              label: 'Pular descanso',
              variant: PhdButtonVariant.secondary,
              onPressed: _pularDescanso,
            ),
          ],
        ),
      );
    }

    final ultimaDeTodas = _ultimaSerie && _ultimoExercicio;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: PhdButton(
        label: ultimaDeTodas
            ? 'Finalizar treino'
            : _ultimaSerie
                ? 'Concluir e ir para o próximo'
                : 'Concluir série $_serie',
        icon: ultimaDeTodas ? Icons.flag_rounded : Icons.check_rounded,
        loading: _ocupado,
        onPressed: _ocupado ? null : _concluirSerie,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  Folha de carga
// ════════════════════════════════════════════════════════════

/// Pergunta a carga da série recém-concluída.
///
/// Widget próprio para que o `TextEditingController` tenha `dispose`. Na
/// versão anterior ele era criado dentro de `showModalBottomSheet` e nunca
/// liberado: um treino de cinco exercícios por quatro séries vazava vinte.
class _FolhaCarga extends StatefulWidget {
  const _FolhaCarga({
    required this.serie,
    required this.total,
    required this.exercicio,
    this.repeticoes,
    this.sugestao,
  });

  final int serie;
  final int total;
  final String exercicio;
  final String? repeticoes;
  final String? sugestao;

  @override
  State<_FolhaCarga> createState() => _FolhaCargaState();
}

class _FolhaCargaState extends State<_FolhaCarga> {
  late final TextEditingController _carga;

  @override
  void initState() {
    super.initState();
    _carga = TextEditingController(text: widget.sugestao ?? '');
  }

  @override
  void dispose() {
    _carga.dispose();
    super.dispose();
  }

  void _confirmar() => Navigator.pop(context, _carga.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rXl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.tint(AppColors.success),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Série ${widget.serie} de ${widget.total}',
                        style: AppText.title(16)),
                    Text(widget.exercicio,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          PhdField(
            label: 'Carga usada',
            controller: _carga,
            hint: '70, 12RM ou corporal',
            textInputAction: TextInputAction.done,
            onSubmitted: _confirmar,
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdButton(label: 'Confirmar', onPressed: _confirmar),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, ''),
              child: Text('Não registrar carga',
                  style: AppText.bodyStrong(13, color: AppColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  Demonstração
// ════════════════════════════════════════════════════════════

class _Demonstracao extends StatelessWidget {
  const _Demonstracao({this.videoUrl, this.imagemUrl});

  final String? videoUrl;
  final String? imagemUrl;

  @override
  Widget build(BuildContext context) {
    if (videoUrl != null) return _VideoDemo(url: videoUrl!);
    if (imagemUrl != null) {
      return Image.network(
        imagemUrl!,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _SemDemonstracao(),
      );
    }
    return const _SemDemonstracao();
  }
}

class _SemDemonstracao extends StatelessWidget {
  const _SemDemonstracao();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 180,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined,
              size: 30, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.sm),
          Text('Sem demonstração para este exercício',
              style: AppText.caption(12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _VideoDemo extends StatefulWidget {
  const _VideoDemo({required this.url});

  final String url;

  @override
  State<_VideoDemo> createState() => _VideoDemoState();
}

class _VideoDemoState extends State<_VideoDemo> {
  VideoPlayerController? _ctrl;
  bool _pronto = false;
  bool _falhou = false;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _ctrl = c;
    c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _pronto = true);
      c.setLooping(true);
      c.play();
    }).catchError((_) {
      // Vídeo corrompido ou formato que o navegador não toca não pode
      // derrubar a tela no meio do treino.
      if (mounted) setState(() => _falhou = true);
    });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_falhou) return const _SemDemonstracao();

    final c = _ctrl;
    if (!_pronto || c == null) {
      return Container(
        width: double.infinity,
        height: 200,
        color: AppColors.surface,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return GestureDetector(
      onTap: () => setState(() {
        c.value.isPlaying ? c.pause() : c.play();
      }),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
          AnimatedOpacity(
            opacity: c.value.isPlaying ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 34),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  Contagem e conclusão
// ════════════════════════════════════════════════════════════

class _Contagem extends StatelessWidget {
  const _Contagem({
    required this.numero,
    required this.pulso,
    required this.ficha,
  });

  final int numero;
  final AnimationController pulso;
  final String ficha;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Container(
        color: AppColors.bg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ficha, style: AppText.caption(14)),
              const SizedBox(height: AppSpacing.lg),
              ScaleTransition(
                scale: Tween<double>(begin: 1.25, end: 1).animate(
                  CurvedAnimation(parent: pulso, curve: Curves.easeOutBack),
                ),
                child: Text(
                  numero > 0 ? '$numero' : 'Vai!',
                  style: AppText.display(numero > 0 ? 88 : 54,
                      color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Concluido extends StatelessWidget {
  const _Concluido({
    required this.ficha,
    required this.exercicios,
    required this.minutos,
    required this.series,
    this.falha,
  });

  final String ficha;
  final int exercicios;
  final int minutos;
  final int series;

  /// Quando a gravação falhou. O aluno precisa saber — senão ele acha que
  /// está registrado e o personal nunca vê o treino.
  final String? falha;

  @override
  Widget build(BuildContext context) {
    final ok = falha == null;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.tint(ok ? AppColors.success : AppColors.warning),
              shape: BoxShape.circle,
            ),
            child: Icon(
              ok ? Icons.check_rounded : Icons.cloud_off_rounded,
              color: ok ? AppColors.success : AppColors.warning,
              size: 30,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(ok ? 'Treino concluído' : 'Treino feito, mas não salvo',
              textAlign: TextAlign.center, style: AppText.title(18)),
          const SizedBox(height: 4),
          Text(ficha, textAlign: TextAlign.center, style: AppText.caption(13)),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _stat('$exercicios', 'exercícios'),
              _stat('$series', 'séries'),
              _stat('$minutos', 'minutos'),
            ],
          ),
          if (!ok) ...[
            const SizedBox(height: AppSpacing.xl),
            PhdAviso(
              texto: 'Não consegui registrar este treino: $falha',
              cor: AppColors.warning,
            ),
          ],
        ],
      ),
      actions: [
        PhdButton(
          label: 'Fechar',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _stat(String valor, String rotulo) {
    return Column(
      children: [
        Text(valor, style: AppText.number(24, color: AppColors.accent)),
        const SizedBox(height: 2),
        Text(rotulo, style: AppText.caption(11.5)),
      ],
    );
  }
}
