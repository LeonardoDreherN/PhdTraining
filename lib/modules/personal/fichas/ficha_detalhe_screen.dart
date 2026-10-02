import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/ficha_exercicio.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/aluno_service.dart';
import '../../../core/services/exercicio_service.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Montador de ficha: onde o treino é de fato construído.
class FichaDetalheScreen extends ConsumerStatefulWidget {
  const FichaDetalheScreen({super.key, required this.ficha});

  final Map<String, dynamic> ficha;

  @override
  ConsumerState<FichaDetalheScreen> createState() => _FichaDetalheScreenState();
}

class _FichaDetalheScreenState extends ConsumerState<FichaDetalheScreen> {
  List<FichaExercicio> _itens = [];
  bool _carregando = true;
  String? _erro;

  String get _fichaId => widget.ficha['id'] as String;
  String get _fichaNome => widget.ficha['nome'] as String? ?? 'Ficha';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final lista = await FichaService.listarExercicios(_fichaId);
      if (mounted) setState(() => _itens = lista);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Quem estiver olhando a lista de fichas precisa ver a contagem nova.
  void _avisarMudanca() => ref.invalidate(fichasProvider);

  /// Soma, série a série, o trabalho e o descanso prescrito.
  ///
  /// Os 40s por série são média — o personal não cronometra a execução. O
  /// número responde "esse treino cabe em uma hora?", não é cronômetro. Por
  /// isso a tela mostra "~".
  int get _minutosEstimados {
    var seg = 0;
    for (final i in _itens) {
      seg += i.series * (40 + (i.descansoSegundos ?? 60));
    }
    return (seg / 60).round();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(_fichaNome, style: AppText.title(17)),
        actions: [
          TextButton.icon(
            // Atribuir ficha vazia manda o aluno abrir o app e não achar
            // nada. Enquanto não houver exercício, a ação fica apagada.
            onPressed: _itens.isEmpty ? null : _atribuirAluno,
            icon: const Icon(Icons.person_add_alt_rounded, size: 17),
            label: const Text('Atribuir'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              disabledForegroundColor: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(top: false, child: _corpo()),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: _erro!,
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }

    return Column(
      children: [
        if (_itens.isNotEmpty) _resumo(),
        Expanded(
          child: _itens.isEmpty
              ? PhdEmptyState(
                  icon: Icons.playlist_add_rounded,
                  title: 'Ficha vazia',
                  message: 'Adicione exercícios da biblioteca. A ordem que '
                      'você montar aqui é a ordem que o aluno vai seguir.',
                  actionLabel: 'Adicionar exercício',
                  onAction: _adicionarExercicio,
                )
              : _lista(),
        ),
        if (_itens.isNotEmpty) _rodape(),
      ],
    );
  }

  Widget _resumo() {
    final n = _itens.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Text(
            '$n ${n == 1 ? "exercício" : "exercícios"}  ·  ~$_minutosEstimados min',
            style: AppText.caption(12.5),
          ),
          const Spacer(),
          Text(
            'arraste para reordenar',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _lista() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      itemCount: _itens.length,
      onReorderItem: _reordenar,
      proxyDecorator: (child, _, __) =>
          Material(color: Colors.transparent, child: child),
      itemBuilder: (_, i) => Padding(
        key: ValueKey(_itens[i].id),
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: _cartao(_itens[i], i),
      ),
    );
  }

  Widget _cartao(FichaExercicio item, int index) {
    final detalhes = <String>[
      item.prescricao,
      if (item.cargaFormatada != null) item.cargaFormatada!,
      if (item.descansoFormatado != null) 'descanso ${item.descansoFormatado}',
    ];
    final obs = item.observacoes?.trim();

    return PhdCard(
      onTap: () => _editarExercicio(item),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A posição importa: é a ordem em que o aluno vai executar.
          SizedBox(
            width: 20,
            child: Text(
              '${index + 1}',
              style: AppText.number(13, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _miniatura(item),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong(14),
                ),
                const SizedBox(height: 3),
                Text(detalhes.join('  ·  '), style: AppText.caption(12)),
                if (obs != null && obs.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.sticky_note_2_outlined,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          obs,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(
                            11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Icon(
                Icons.drag_handle_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniatura(FichaExercicio item) {
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.rSm,
      ),
      child: item.midiaUrl == null
          ? const Icon(
              Icons.fitness_center_rounded,
              size: 18,
              color: AppColors.textMuted,
            )
          : Image.network(
              item.midiaUrl!,
              fit: BoxFit.cover,
              // Mídia quebrada não pode virar um X vermelho no meio da
              // ficha: cai no ícone padrão, igual a quem não tem imagem.
              errorBuilder: (_, __, ___) => const Icon(
                Icons.fitness_center_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
    );
  }

  Widget _rodape() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: PhdAddCard(
        label: 'Adicionar exercício',
        onTap: _adicionarExercicio,
      ),
    );
  }

  // ── Ações ───────────────────────────────────────────────────

  Future<void> _reordenar(int de, int para) async {
    // `onReorderItem` já entrega o índice ajustado; o `onReorder` antigo
    // exigia subtrair 1 ao descer, e era origem clássica de item fora do lugar.
    final anterior = List<FichaExercicio>.from(_itens);
    setState(() {
      final item = _itens.removeAt(de);
      _itens.insert(para, item);
    });
    try {
      await FichaService.reordenar(_itens);
      _avisarMudanca();
    } catch (e) {
      // Sem isto a tela mostraria a ordem nova e o banco teria a antiga — o
      // personal só descobriria ao recarregar, ou nunca.
      if (!mounted) return;
      setState(() => _itens = anterior);
      _avisar('Não consegui salvar a ordem: $e', erro: true);
    }
  }

  Future<void> _adicionarExercicio() async {
    final List<Map<String, dynamic>> biblioteca;
    try {
      biblioteca = await ExercicioService.listar();
    } catch (e) {
      if (mounted) _avisar('Não consegui abrir a biblioteca: $e', erro: true);
      return;
    }
    if (!mounted) return;

    if (biblioteca.isEmpty) {
      _avisar('A biblioteca de exercícios está vazia.');
      return;
    }

    final escolhido = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: _SeletorExercicio(exercicios: biblioteca),
      ),
    );
    if (escolhido == null || !mounted) return;

    final dados = await _abrirConfig(titulo: escolhido['nome'] as String);
    if (dados == null || !mounted) return;

    try {
      await FichaService.adicionarExercicio(
        fichaId: _fichaId,
        exercicioId: escolhido['id'] as String,
        series: dados.series,
        repeticoes: dados.repeticoes,
        carga: dados.carga,
        descansoSegundos: dados.descanso,
        observacoes: dados.observacoes,
        ordem: _itens.length,
      );
      _avisarMudanca();
      await _carregar();
    } catch (e) {
      if (mounted) _avisar('Não consegui adicionar: $e', erro: true);
    }
  }

  /// Toque no cartão reabre a folha de configuração, agora preenchida.
  ///
  /// Antes não havia caminho nenhum para isto: corrigir uma carga digitada
  /// errada exigia remover o exercício e adicioná-lo de novo, o que também
  /// perdia a posição dele na ficha.
  Future<void> _editarExercicio(FichaExercicio item) async {
    final dados = await _abrirConfig(titulo: item.nome, atual: item);
    if (dados == null || !mounted) return;

    if (dados.remover) {
      await _removerExercicio(item);
      return;
    }

    try {
      await FichaService.atualizarExercicio(item.id, {
        'series': dados.series,
        'repeticoes': dados.repeticoes,
        'carga': dados.carga,
        'descanso_segundos': dados.descanso,
        'observacoes': dados.observacoes,
      });
      _avisarMudanca();
      await _carregar();
    } catch (e) {
      if (mounted) _avisar('Não consegui salvar: $e', erro: true);
    }
  }

  Future<void> _removerExercicio(FichaExercicio item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Remover da ficha?', style: AppText.title(17)),
        content: Text(
          '"${item.nome}" sai desta ficha. Ele continua na biblioteca e pode '
          'ser adicionado de novo.',
          style: AppText.body(13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: AppText.bodyStrong(13.5, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Remover',
              style: AppText.bodyStrong(13.5, color: AppColors.dangerText),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FichaService.removerExercicio(item.id);
      _avisarMudanca();
      await _carregar();
    } catch (e) {
      if (mounted) _avisar('Não consegui remover: $e', erro: true);
    }
  }

  Future<_ConfigExercicio?> _abrirConfig({
    required String titulo,
    FichaExercicio? atual,
  }) {
    return showModalBottomSheet<_ConfigExercicio>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => Padding(
        // Sem isto o teclado cobre os campos de baixo na hora de digitar.
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FolhaConfig(titulo: titulo, atual: atual),
      ),
    );
  }

  Future<void> _atribuirAluno() async {
    final List<Map<String, dynamic>> alunos;
    try {
      alunos = await AlunoService.listar(ativo: true);
    } catch (e) {
      if (mounted) _avisar('Não consegui carregar os alunos: $e', erro: true);
      return;
    }
    if (!mounted) return;

    if (alunos.isEmpty) {
      _avisar('Você ainda não tem alunos ativos para atribuir.');
      return;
    }

    final aluno = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.7,
        child: _SeletorAluno(alunos: alunos),
      ),
    );
    if (aluno == null || !mounted) return;

    final dias = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const _SeletorDias(),
    );
    // Fechar a folha arrastando devolve null: aí a atribuição não acontece,
    // em vez de gravar "nenhum dia" sem o personal ter decidido isso.
    if (dias == null || !mounted) return;

    try {
      await FichaService.atribuirAluno(
        alunoId: aluno['id'] as String,
        fichaId: _fichaId,
        diasSemana: dias,
      );
      _avisarMudanca();
      if (mounted) _avisar('Ficha atribuída a ${aluno['nome']}.', ok: true);
    } catch (e) {
      if (mounted) _avisar('Não consegui atribuir: $e', erro: true);
    }
  }

  void _avisar(String texto, {bool erro = false, bool ok = false}) {
    final fundo = erro
        ? AppColors.danger
        : ok
        ? AppColors.success
        : AppColors.surfaceHigh;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: fundo,
        content: Text(
          texto,
          style: AppText.body(
            13.5,
            color: (erro || ok) ? AppColors.onAccent : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// O que a folha de configuração devolve.
class _ConfigExercicio {
  const _ConfigExercicio({
    required this.series,
    required this.repeticoes,
    this.carga,
    this.descanso,
    this.observacoes,
  }) : remover = false;

  const _ConfigExercicio.remover()
    : series = 0,
      repeticoes = '',
      carga = null,
      descanso = null,
      observacoes = null,
      remover = true;

  final int series;
  final String repeticoes;
  final String? carga;
  final int? descanso;
  final String? observacoes;
  final bool remover;
}

/// Séries, repetições, carga, descanso e observação.
///
/// É um widget próprio — e não um `showDialog` com controllers soltos — para
/// que o `dispose` deles seja garantido pelo ciclo de vida do Flutter. Na
/// versão anterior, quatro controllers vazavam a cada exercício adicionado.
class _FolhaConfig extends StatefulWidget {
  const _FolhaConfig({required this.titulo, this.atual});

  final String titulo;
  final FichaExercicio? atual;

  @override
  State<_FolhaConfig> createState() => _FolhaConfigState();
}

class _FolhaConfigState extends State<_FolhaConfig> {
  late final TextEditingController _series;
  late final TextEditingController _reps;
  late final TextEditingController _carga;
  late final TextEditingController _descanso;
  late final TextEditingController _obs;

  bool get _editando => widget.atual != null;

  @override
  void initState() {
    super.initState();
    final a = widget.atual;
    _series = TextEditingController(text: '${a?.series ?? 3}');
    _reps = TextEditingController(text: a?.repeticoes ?? '12');
    _carga = TextEditingController(text: a?.carga ?? '');
    _descanso = TextEditingController(text: '${a?.descansoSegundos ?? 60}');
    _obs = TextEditingController(text: a?.observacoes ?? '');
  }

  @override
  void dispose() {
    _series.dispose();
    _reps.dispose();
    _carga.dispose();
    _descanso.dispose();
    _obs.dispose();
    super.dispose();
  }

  void _salvar() {
    final carga = _carga.text.trim();
    final obs = _obs.text.trim();
    final reps = _reps.text.trim();
    Navigator.pop(
      context,
      _ConfigExercicio(
        series: int.tryParse(_series.text.trim()) ?? 3,
        repeticoes: reps.isEmpty ? '12' : reps,
        carga: carga.isEmpty ? null : carga,
        descanso: int.tryParse(_descanso.text.trim()),
        observacoes: obs.isEmpty ? null : obs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Puxador(),
          const SizedBox(height: AppSpacing.lg),
          Text(widget.titulo, style: AppText.title(17)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PhdField(
                  label: 'Séries',
                  controller: _series,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PhdField(
                  label: 'Repetições',
                  controller: _reps,
                  hint: '12 ou 8-10',
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PhdField(
                  label: 'Carga',
                  controller: _carga,
                  // Texto livre de propósito: cabe "70", "12RM" e "corporal".
                  hint: '70, 12RM, corporal',
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PhdField(
                  label: 'Descanso (s)',
                  controller: _descanso,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdField(
            label: 'Observação',
            controller: _obs,
            hint: 'Opcional — o aluno lê durante o treino',
            textInputAction: TextInputAction.done,
            onSubmitted: _salvar,
          ),
          const SizedBox(height: AppSpacing.xl),
          PhdButton(
            label: _editando ? 'Salvar' : 'Adicionar à ficha',
            onPressed: _salvar,
          ),
          if (_editando) ...[
            const SizedBox(height: AppSpacing.sm),
            PhdButton(
              label: 'Remover da ficha',
              variant: PhdButtonVariant.ghost,
              onPressed: () =>
                  Navigator.pop(context, const _ConfigExercicio.remover()),
            ),
          ],
        ],
      ),
    );
  }
}

/// Busca na biblioteca, com filtro por grupo muscular.
class _SeletorExercicio extends StatefulWidget {
  const _SeletorExercicio({required this.exercicios});

  final List<Map<String, dynamic>> exercicios;

  @override
  State<_SeletorExercicio> createState() => _SeletorExercicioState();
}

class _SeletorExercicioState extends State<_SeletorExercicio> {
  final _busca = TextEditingController();
  String _termo = '';
  String _grupo = 'Todos';

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  List<String> get _grupos {
    final s = <String>{};
    for (final e in widget.exercicios) {
      final g = e['grupo_muscular'] as String?;
      if (g != null && g.trim().isNotEmpty) s.add(g);
    }
    final ordenados = s.toList()..sort();
    return ['Todos', ...ordenados];
  }

  List<Map<String, dynamic>> get _filtrados {
    final termo = _termo.trim().toLowerCase();
    return widget.exercicios.where((e) {
      final nome = (e['nome'] as String? ?? '').toLowerCase();
      final okNome = termo.isEmpty || nome.contains(termo);
      final okGrupo = _grupo == 'Todos' || e['grupo_muscular'] == _grupo;
      return okNome && okGrupo;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    final grupos = _grupos;

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        const _Puxador(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Text('Biblioteca', style: AppText.title(17)),
              const Spacer(),
              Text(
                '${lista.length}',
                style: AppText.number(13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: PhdField(
            label: 'Buscar',
            controller: _busca,
            hint: 'Nome do exercício',
            icon: Icons.search_rounded,
            onChanged: (v) => setState(() => _termo = v),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: grupos.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, i) => PhdFilterChip(
              label: grupos[i],
              selected: grupos[i] == _grupo,
              onTap: () => setState(() => _grupo = grupos[i]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: lista.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum exercício encontrado',
                    style: AppText.caption(13),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.xl,
                  ),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final e = lista[i];
                    return PhdListRow(
                      title: e['nome'] as String? ?? '—',
                      subtitle: e['grupo_muscular'] as String?,
                      onTap: () => Navigator.pop(context, e),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _SeletorAluno extends StatelessWidget {
  const _SeletorAluno({required this.alunos});

  final List<Map<String, dynamic>> alunos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        const _Puxador(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.md,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Atribuir para', style: AppText.title(17)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            itemCount: alunos.length,
            itemBuilder: (_, i) {
              final a = alunos[i];
              final nome = a['nome'] as String? ?? '—';
              return PhdListRow(
                title: nome,
                subtitle: a['grupo'] as String?,
                leading: PhdAvatar(name: nome, size: 36),
                onTap: () => Navigator.pop(context, a),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SeletorDias extends StatefulWidget {
  const _SeletorDias();

  @override
  State<_SeletorDias> createState() => _SeletorDiasState();
}

class _SeletorDiasState extends State<_SeletorDias> {
  final Set<int> _sel = {};

  // (inicial, rótulo, valor) — o valor segue o padrão do banco, domingo = 0.
  static const _dias = [
    ('D', 'Dom', 0),
    ('S', 'Seg', 1),
    ('T', 'Ter', 2),
    ('Q', 'Qua', 3),
    ('Q', 'Qui', 4),
    ('S', 'Sex', 5),
    ('S', 'Sáb', 6),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Puxador(),
          const SizedBox(height: AppSpacing.lg),
          Text('Em quais dias?', style: AppText.title(17)),
          const SizedBox(height: 4),
          Text(
            'Serve para o aluno saber quando treinar. Pode deixar em branco.',
            style: AppText.caption(12.5),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _dias.map((d) {
              final marcado = _sel.contains(d.$3);
              return Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() {
                      if (marcado) {
                        _sel.remove(d.$3);
                      } else {
                        _sel.add(d.$3);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: marcado
                            ? AppColors.accent
                            : AppColors.surfaceHigh,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: marcado ? AppColors.accent : AppColors.line,
                        ),
                      ),
                      child: Text(
                        d.$1,
                        style: AppText.bodyStrong(
                          13.5,
                          color: marcado
                              ? AppColors.onAccent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.$2,
                    style: AppText.caption(10.5, color: AppColors.textMuted),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
          PhdButton(
            label: 'Confirmar',
            onPressed: () => Navigator.pop(context, _sel.toList()..sort()),
          ),
        ],
      ),
    );
  }
}

/// A barrinha do topo das folhas — sinaliza que dá para arrastar e fechar.
class _Puxador extends StatelessWidget {
  const _Puxador();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 34,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.lineStrong,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
