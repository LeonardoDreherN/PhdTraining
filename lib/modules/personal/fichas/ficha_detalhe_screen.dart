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
import '../exercicios/exercicio_detalhe.dart';

/// Montador de ficha: onde o treino é de fato construído.
///
/// Tudo numa rolagem só: o resumo do treino (duração, séries, músculos),
/// quem está treinando com ela e, embaixo, os exercícios na ordem em que o
/// aluno vai fazer. Cada exercício mostra a miniatura com o selo de vídeo —
/// e ao abrir, o vídeo toca ali mesmo, para o personal conferir.
class FichaDetalheScreen extends ConsumerStatefulWidget {
  const FichaDetalheScreen({super.key, required this.ficha});

  final Map<String, dynamic> ficha;

  @override
  ConsumerState<FichaDetalheScreen> createState() => _FichaDetalheScreenState();
}

class _FichaDetalheScreenState extends ConsumerState<FichaDetalheScreen> {
  List<FichaExercicio> _itens = [];
  List<Map<String, dynamic>> _alunos = [];
  bool _carregando = true;
  String? _erro;

  late String _nome = widget.ficha['nome'] as String? ?? 'Ficha';
  late String? _descricao = _limpo(widget.ficha['descricao'] as String?);

  String get _fichaId => widget.ficha['id'] as String;

  static String? _limpo(String? t) => (t == null || t.trim().isEmpty) ? null : t.trim();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final (lista, alunos) = await (
        FichaService.listarExercicios(_fichaId),
        FichaService.alunosDaFicha(_fichaId),
      ).wait;
      if (mounted) {
        setState(() {
          _itens = lista;
          _alunos = alunos;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Quem estiver olhando a lista de fichas precisa ver a contagem nova.
  void _avisarMudanca() => ref.invalidate(fichasProvider);

  /// Mesma conta da lista de fichas: ~40 s por série + o descanso prescrito,
  /// arredondado a 5 min. Responde "cabe em uma hora?", não é cronômetro.
  int get _minutos {
    var seg = 0;
    for (final i in _itens) {
      seg += i.series * (40 + (i.descansoSegundos ?? 90));
    }
    return (seg / 60 / 5).round() * 5;
  }

  int get _series => _itens.fold(0, (s, i) => s + i.series);

  List<String> get _grupos {
    final c = <String, int>{};
    for (final i in _itens) {
      final g = i.grupoMuscular;
      if (g != null && g.trim().isNotEmpty) c[g] = (c[g] ?? 0) + 1;
    }
    final l = c.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in l) e.key];
  }

  String get _sigla {
    final m = RegExp(r'^treino\s+([a-z0-9])(?![a-z0-9])', caseSensitive: false).firstMatch(_nome.trim());
    if (m != null) return m.group(1)!.toUpperCase();
    return _nome.trim().isEmpty ? '?' : _nome.trim()[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Ficha', style: AppText.title(17)),
        actions: [
          IconButton(
            tooltip: 'Renomear',
            onPressed: _renomear,
            icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(top: false, child: _corpo()),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
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

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _carregar,
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge),
        header: _cabecalho(),
        footer: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: PhdAddCard(label: 'Adicionar exercício', onTap: _adicionarExercicio),
        ),
        itemCount: _itens.length,
        onReorderItem: _reordenar,
        proxyDecorator: (child, _, __) => Material(color: Colors.transparent, child: child),
        itemBuilder: (_, i) => Padding(
          key: ValueKey(_itens[i].id),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _cartao(_itens[i], i),
        ),
      ),
    );
  }

  // ── Cabeçalho ───────────────────────────────────────────────

  Widget _cabecalho() {
    final vazia = _itens.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: vazia ? AppColors.surfaceHigh : AppColors.accent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                _sigla,
                style: AppText.display(28, color: vazia ? AppColors.textMuted : AppColors.onAccent),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_nome, style: AppText.display(22)),
                  if (_descricao != null) ...[
                    const SizedBox(height: 3),
                    Text(_descricao!, style: AppText.caption(13)),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(child: _numero('${_itens.length}', _itens.length == 1 ? 'exercício' : 'exercícios')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _numero('$_series', 'séries')),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _numero(vazia ? '—' : '~$_minutos', 'minutos')),
          ],
        ),
        if (_grupos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, g) in _grupos.indexed)
                PhdStatusChip(label: g, tone: i == 0 ? PhdTone.accent : PhdTone.neutral),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            Expanded(
              child: PhdButton(
                label: 'Exercício',
                icon: Icons.add_rounded,
                size: PhdButtonSize.medium,
                onPressed: _adicionarExercicio,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: PhdButton(
                label: 'Atribuir',
                icon: Icons.person_add_alt_rounded,
                variant: PhdButtonVariant.secondary,
                size: PhdButtonSize.medium,
                // Atribuir ficha vazia manda o aluno abrir o app e não achar
                // nada. Enquanto não houver exercício, fica apagado.
                onPressed: vazia ? null : _atribuirAluno,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        _secaoAlunos(),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Text('EXERCÍCIOS', style: AppText.label()),
            const Spacer(),
            if (_itens.length > 1)
              Text('segure ⠿ para reordenar', style: AppText.caption(11.5, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (vazia)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PhdCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.playlist_add_rounded, color: AppColors.textMuted, size: 26),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Ficha vazia. A ordem em que você adicionar é a ordem que o aluno vai seguir.',
                      style: AppText.body(13.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _numero(String valor, String rotulo) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: AppText.number(22)),
            Text(rotulo, style: AppText.caption(11.5)),
          ],
        ),
      );

  Widget _secaoAlunos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('QUEM TREINA COM ELA', style: AppText.label()),
            const Spacer(),
            if (_alunos.isNotEmpty) Text('${_alunos.length}', style: AppText.number(13, color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_alunos.isEmpty)
          Text(
            _itens.isEmpty ? 'Monte os exercícios e depois atribua aos alunos.' : 'Ninguém ainda. Toque em Atribuir.',
            style: AppText.caption(12.5),
          )
        else
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _alunos.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => _alunoChip(_alunos[i]),
            ),
          ),
      ],
    );
  }

  Widget _alunoChip(Map<String, dynamic> linha) {
    final aluno = (linha['alunos'] as Map?)?.cast<String, dynamic>() ?? const {};
    final nome = aluno['nome'] as String? ?? '—';
    final dias = ((linha['dias_semana'] as List?) ?? const []).map((d) => (d as num).toInt()).toList()..sort();
    const nomesDias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final textoDias = dias.isEmpty ? 'livre' : dias.map((d) => nomesDias[d % 7]).join(' · ');

    return SizedBox(
      width: 112,
      child: PhdCard(
        onTap: () => _opcoesAluno(aluno),
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          children: [
            PhdAvatar(name: nome, imageUrl: aluno['foto_url'] as String?, size: 36),
            const SizedBox(height: 4),
            Text(nome.split(' ').first, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(12.5)),
            Text(textoDias,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(10.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── Cartão do exercício ─────────────────────────────────────

  Widget _cartao(FichaExercicio item, int index) {
    final obs = item.observacoes?.trim();
    final temVideo = (item.videoUrl ?? '').trim().isNotEmpty;

    return PhdCard(
      onTap: () => _editarExercicio(item),
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PhdMiniaturaExercicio(
                imagemUrl: item.midiaUrl,
                temVideo: temVideo,
                tamanho: 64,
                raio: AppRadius.rMd,
              ),
              // A posição importa: é a ordem em que o aluno vai executar.
              Positioned(
                left: -4,
                top: -4,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Text('${index + 1}', style: AppText.number(10.5, color: AppColors.onAccent)),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 2),
                Text(item.nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(14)),
                if (item.grupoMuscular != null)
                  Text(item.grupoMuscular!, style: AppText.caption(11.5, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _pilula(Icons.repeat_rounded, item.prescricao, destaque: true),
                    if (item.cargaFormatada != null) _pilula(Icons.fitness_center_rounded, item.cargaFormatada!),
                    if (item.descansoFormatado != null) _pilula(Icons.timer_outlined, item.descansoFormatado!),
                  ],
                ),
                if (obs != null && obs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.sticky_note_2_outlined, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(obs,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption(11.5, color: AppColors.textMuted)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.lg),
              child: Icon(Icons.drag_indicator_rounded, size: 20, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pilula(IconData icone, String texto, {bool destaque = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: destaque ? AppColors.tint(AppColors.accent) : AppColors.surfaceHigh,
          borderRadius: AppRadius.rPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 11, color: destaque ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 3),
            Text(texto,
                style: AppText.bodyStrong(11, color: destaque ? AppColors.accent : AppColors.textSecondary)),
          ],
        ),
      );

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

  Future<void> _renomear() async {
    final r = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => _DialogoNome(nome: _nome, descricao: _descricao),
    );
    if (r == null || !mounted) return;
    try {
      await FichaService.atualizar(_fichaId, r.$1, r.$2);
      setState(() {
        _nome = r.$1;
        _descricao = r.$2;
      });
      _avisarMudanca();
    } catch (e) {
      if (mounted) _avisar('Não consegui renomear: $e', erro: true);
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
        heightFactor: 0.9,
        child: _SeletorExercicio(
          exercicios: biblioteca,
          naFicha: {for (final i in _itens) i.exercicioId},
        ),
      ),
    );
    if (escolhido == null || !mounted) return;

    final dados = await _abrirConfig(
      titulo: escolhido['nome'] as String,
      grupo: escolhido['grupo_muscular'] as String?,
      video: escolhido['video_url'] as String?,
      imagem: escolhido['midia_url'] as String?,
    );
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

  /// Toque no cartão reabre a folha de configuração, agora preenchida —
  /// com o vídeo do exercício no topo.
  Future<void> _editarExercicio(FichaExercicio item) async {
    final dados = await _abrirConfig(
      titulo: item.nome,
      grupo: item.grupoMuscular,
      video: item.videoUrl,
      imagem: item.midiaUrl,
      atual: item,
    );
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
    final ok = await _confirmar(
      titulo: 'Remover da ficha?',
      texto: '"${item.nome}" sai desta ficha. Ele continua na biblioteca e pode ser adicionado de novo.',
      acao: 'Remover',
    );
    if (!ok) return;

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
    String? grupo,
    String? video,
    String? imagem,
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
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.92),
          child: _FolhaConfig(
            titulo: titulo,
            grupo: grupo,
            video: _limpo(video),
            imagem: _limpo(imagem),
            atual: atual,
          ),
        ),
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

    // Quem já está com a ficha sai da lista: mudar os dias é pelo cartão
    // do aluno, lá em cima.
    final jaTem = {
      for (final l in _alunos) ((l['alunos'] as Map?)?['id']),
    };
    final livres = alunos.where((a) => !jaTem.contains(a['id'])).toList();
    if (livres.isEmpty) {
      _avisar(alunos.isEmpty
          ? 'Você ainda não tem alunos ativos para atribuir.'
          : 'Todos os seus alunos ativos já estão com esta ficha.');
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
        child: _SeletorAluno(alunos: livres),
      ),
    );
    if (aluno == null || !mounted) return;

    final dias = await _escolherDias(aluno['nome'] as String? ?? 'o aluno');
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
      await _carregar();
      if (mounted) _avisar('Ficha atribuída a ${aluno['nome']}.', ok: true);
    } catch (e) {
      if (mounted) _avisar('Não consegui atribuir: $e', erro: true);
    }
  }

  Future<List<int>?> _escolherDias(String nome, [List<int> atuais = const []]) {
    return showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _SeletorDias(nome: nome, iniciais: atuais),
    );
  }

  Future<void> _opcoesAluno(Map<String, dynamic> aluno) async {
    final nome = aluno['nome'] as String? ?? 'aluno';
    final linha = _alunos.firstWhere((l) => (l['alunos'] as Map?)?['id'] == aluno['id']);
    final atuais = ((linha['dias_semana'] as List?) ?? const []).map((d) => (d as num).toInt()).toList();

    final acao = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Puxador(),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                PhdAvatar(name: nome, imageUrl: aluno['foto_url'] as String?, size: 44),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(nome, style: AppText.title(17))),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PhdListRow(
              title: 'Mudar os dias',
              leading: Icon(Icons.calendar_month_outlined, color: AppColors.textSecondary),
              onTap: () => Navigator.pop(ctx, 'dias'),
            ),
            PhdListRow(
              title: 'Tirar a ficha deste aluno',
              leading: Icon(Icons.person_remove_outlined, color: AppColors.dangerText),
              onTap: () => Navigator.pop(ctx, 'tirar'),
            ),
          ],
        ),
      ),
    );
    if (acao == null || !mounted) return;

    try {
      if (acao == 'dias') {
        final dias = await _escolherDias(nome, atuais);
        if (dias == null || !mounted) return;
        await FichaService.atribuirAluno(alunoId: aluno['id'] as String, fichaId: _fichaId, diasSemana: dias);
      } else {
        final ok = await _confirmar(
          titulo: 'Tirar a ficha de $nome?',
          texto: 'O histórico de treinos continua salvo. Você pode atribuir de novo depois.',
          acao: 'Tirar',
        );
        if (!ok) return;
        await FichaService.desatribuirAluno(alunoId: aluno['id'] as String, fichaId: _fichaId);
      }
      _avisarMudanca();
      await _carregar();
    } catch (e) {
      if (mounted) _avisar('Não consegui salvar: $e', erro: true);
    }
  }

  Future<bool> _confirmar({required String titulo, required String texto, required String acao}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(titulo, style: AppText.title(17)),
        content: Text(texto, style: AppText.body(13.5, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(acao, style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    return ok == true;
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
          style: AppText.body(13.5, color: (erro || ok) ? AppColors.onAccent : AppColors.textPrimary),
        ),
      ),
    );
  }
}

/// Nome e descrição da ficha.
class _DialogoNome extends StatefulWidget {
  const _DialogoNome({required this.nome, this.descricao});

  final String nome;
  final String? descricao;

  @override
  State<_DialogoNome> createState() => _DialogoNomeState();
}

class _DialogoNomeState extends State<_DialogoNome> {
  late final _nome = TextEditingController(text: widget.nome);
  late final _desc = TextEditingController(text: widget.descricao ?? '');

  @override
  void dispose() {
    _nome.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _salvar() {
    final n = _nome.text.trim();
    if (n.isEmpty) return;
    final d = _desc.text.trim();
    Navigator.pop(context, (n, d.isEmpty ? null : d));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text('Renomear ficha', style: AppText.title(17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhdField(
            label: 'Nome',
            controller: _nome,
            hint: 'Treino A — Superiores',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
          PhdField(
            label: 'Descrição (opcional)',
            controller: _desc,
            hint: 'Foco em força, 3x por semana',
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: _salvar,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _salvar,
          child: Text('Salvar', style: AppText.bodyStrong(13.5, color: AppColors.accent)),
        ),
      ],
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

/// Séries, repetições, carga, descanso e observação — com o vídeo do
/// exercício no topo, para o personal conferir o movimento enquanto prescreve.
///
/// É um widget próprio — e não um `showDialog` com controllers soltos — para
/// que o `dispose` deles seja garantido pelo ciclo de vida do Flutter.
class _FolhaConfig extends StatefulWidget {
  const _FolhaConfig({required this.titulo, this.grupo, this.video, this.imagem, this.atual});

  final String titulo;
  final String? grupo;
  final String? video;
  final String? imagem;
  final FichaExercicio? atual;

  @override
  State<_FolhaConfig> createState() => _FolhaConfigState();
}

class _FolhaConfigState extends State<_FolhaConfig> {
  late int _series = widget.atual?.series ?? 3;
  late int _descanso = widget.atual?.descansoSegundos ?? 60;
  late final _reps = TextEditingController(text: widget.atual?.repeticoes ?? '12');
  late final _carga = TextEditingController(text: widget.atual?.carga ?? '');
  late final _obs = TextEditingController(text: widget.atual?.observacoes ?? '');
  bool _verVideo = false;

  static const _descansos = [30, 45, 60, 90, 120, 180];

  bool get _editando => widget.atual != null;

  @override
  void dispose() {
    _reps.dispose();
    _carga.dispose();
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
        series: _series,
        repeticoes: reps.isEmpty ? '12' : reps,
        carga: carga.isEmpty ? null : carga,
        descanso: _descanso,
        observacoes: obs.isEmpty ? null : obs,
      ),
    );
  }

  String _rotuloDescanso(int s) => s < 60 ? '${s}s' : (s % 60 == 0 ? '${s ~/ 60} min' : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}');

  @override
  Widget build(BuildContext context) {
    final descansos = {..._descansos, _descanso}.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Puxador(),
          const SizedBox(height: AppSpacing.lg),
          _midia(),
          const SizedBox(height: AppSpacing.lg),
          Text('SÉRIES', style: AppText.label()),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _botaoPasso(Icons.remove_rounded, _series > 1 ? () => setState(() => _series--) : null),
              Expanded(
                child: Text('$_series', textAlign: TextAlign.center, style: AppText.number(28)),
              ),
              _botaoPasso(Icons.add_rounded, _series < 10 ? () => setState(() => _series++) : null),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PhdField(
                  label: 'Repetições',
                  controller: _reps,
                  hint: '12 ou 8-10',
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PhdField(
                  label: 'Carga',
                  controller: _carga,
                  // Texto livre de propósito: cabe "70", "12RM" e "corporal".
                  hint: '70, 12RM, corporal',
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('DESCANSO', style: AppText.label()),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in descansos)
                PhdFilterChip(
                  label: _rotuloDescanso(s),
                  selected: s == _descanso,
                  onTap: () => setState(() => _descanso = s),
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
            icon: Icons.check_rounded,
            onPressed: _salvar,
          ),
          if (_editando) ...[
            const SizedBox(height: AppSpacing.sm),
            PhdButton(
              label: 'Remover da ficha',
              variant: PhdButtonVariant.ghost,
              onPressed: () => Navigator.pop(context, const _ConfigExercicio.remover()),
            ),
          ],
        ],
      ),
    );
  }

  /// O vídeo só começa a tocar quando o personal pede: abrir a folha para
  /// trocar uma carga não precisa baixar o vídeo inteiro.
  Widget _midia() {
    final video = widget.video;
    if (_verVideo && video != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhdVideo(url: video, altura: 210),
          const SizedBox(height: AppSpacing.sm),
          Text(widget.titulo, style: AppText.title(17)),
          if (widget.grupo != null) Text(widget.grupo!, style: AppText.caption(12.5)),
        ],
      );
    }
    return Row(
      children: [
        GestureDetector(
          onTap: video == null ? null : () => setState(() => _verVideo = true),
          child: PhdMiniaturaExercicio(
            imagemUrl: widget.imagem,
            temVideo: video != null,
            tamanho: 72,
            raio: AppRadius.rLg,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.titulo, style: AppText.title(17)),
              if (widget.grupo != null) Text(widget.grupo!, style: AppText.caption(12.5)),
              const SizedBox(height: 4),
              if (video != null)
                GestureDetector(
                  onTap: () => setState(() => _verVideo = true),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_fill_rounded, size: 16, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text('Ver vídeo da execução', style: AppText.bodyStrong(12.5, color: AppColors.accent)),
                    ],
                  ),
                )
              else
                Text('Sem vídeo — dá para enviar na biblioteca.',
                    style: AppText.caption(11.5, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botaoPasso(IconData icone, VoidCallback? onTap) => Material(
        color: AppColors.surfaceHigh,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: kMinTouch,
            height: kMinTouch,
            child: Icon(icone, color: onTap == null ? AppColors.textMuted : AppColors.textPrimary),
          ),
        ),
      );
}

/// A biblioteca em grade, igual à tela de exercícios: o personal reconhece
/// pela imagem, vê quem tem vídeo e pode assistir antes de escolher.
class _SeletorExercicio extends StatefulWidget {
  const _SeletorExercicio({required this.exercicios, required this.naFicha});

  final List<Map<String, dynamic>> exercicios;
  final Set<String> naFicha;

  @override
  State<_SeletorExercicio> createState() => _SeletorExercicioState();
}

class _SeletorExercicioState extends State<_SeletorExercicio> {
  final _busca = TextEditingController();
  String _grupo = 'Todos';
  bool _soComVideo = false;

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  static bool _temVideo(Map<String, dynamic> e) => ((e['video_url'] as String?) ?? '').trim().isNotEmpty;

  List<String> get _grupos {
    final s = <String>{};
    for (final e in widget.exercicios) {
      final g = e['grupo_muscular'] as String?;
      if (g != null && g.trim().isNotEmpty) s.add(g);
    }
    return ['Todos', ...s.toList()..sort()];
  }

  List<Map<String, dynamic>> get _filtrados {
    final termo = _busca.text.trim().toLowerCase();
    return widget.exercicios.where((e) {
      if (_grupo != 'Todos' && e['grupo_muscular'] != _grupo) return false;
      if (_soComVideo && !_temVideo(e)) return false;
      return termo.isEmpty || (e['nome'] as String? ?? '').toLowerCase().contains(termo);
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
          child: Row(
            children: [
              Text('Escolha o exercício', style: AppText.title(17)),
              const Spacer(),
              Text('${lista.length}', style: AppText.number(13, color: AppColors.textMuted)),
            ],
          ),
        ),
        Padding(
          padding: AppSpacing.screen,
          child: TextField(
            controller: _busca,
            onChanged: (_) => setState(() {}),
            style: AppText.body(14.5),
            decoration: InputDecoration(
              hintText: 'Buscar exercício',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 19),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.screen,
            children: [
              PhdFilterChip(
                label: 'Com vídeo',
                selected: _soComVideo,
                tone: PhdTone.success,
                onTap: () => setState(() => _soComVideo = !_soComVideo),
              ),
              const SizedBox(width: AppSpacing.sm),
              for (final g in grupos) ...[
                PhdFilterChip(label: g, selected: g == _grupo, onTap: () => setState(() => _grupo = g)),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: lista.isEmpty
              ? Center(child: Text('Nenhum exercício encontrado', style: AppText.caption(13)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: lista.length,
                  itemBuilder: (_, i) => _cartao(lista[i]),
                ),
        ),
      ],
    );
  }

  Widget _cartao(Map<String, dynamic> e) {
    final jaTem = widget.naFicha.contains(e['id']);
    return PhdCard(
      onTap: () => Navigator.pop(context, e),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              PhdMiniaturaExercicio(
                imagemUrl: e['midia_url'] as String?,
                temVideo: _temVideo(e),
                tamanho: null,
                raio: AppRadius.rLg,
              ),
              // Ver antes de escolher: abre o vídeo sem tirar da seleção.
              Positioned(
                right: 4,
                top: 4,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => abrirExercicio(context, e, acoes: false),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.visibility_outlined, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (jaTem)
                const Positioned(left: 4, top: 4, child: PhdStatusChip(label: 'na ficha', tone: PhdTone.accent)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(e['nome'] as String? ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(13.5)),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(e['grupo_muscular'] as String? ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(11.5)),
          ),
        ],
      ),
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
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Atribuir para', style: AppText.title(17)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
            itemCount: alunos.length,
            itemBuilder: (_, i) {
              final a = alunos[i];
              final nome = a['nome'] as String? ?? '—';
              return PhdListRow(
                title: nome,
                subtitle: a['grupo'] as String?,
                leading: PhdAvatar(name: nome, imageUrl: a['foto_url'] as String?, size: 36),
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
  const _SeletorDias({required this.nome, this.iniciais = const []});

  final String nome;
  final List<int> iniciais;

  @override
  State<_SeletorDias> createState() => _SeletorDiasState();
}

class _SeletorDiasState extends State<_SeletorDias> {
  late final Set<int> _sel = {...widget.iniciais};

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
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Puxador(),
          const SizedBox(height: AppSpacing.lg),
          Text('Em quais dias ${widget.nome.split(' ').first} treina esta ficha?', style: AppText.title(17)),
          const SizedBox(height: 4),
          Text('Serve para o aluno saber quando treinar. Pode deixar em branco.', style: AppText.caption(12.5)),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _dias.map((d) {
              final marcado = _sel.contains(d.$3);
              return Column(
                children: [
                  GestureDetector(
                    onTap: () => setState(() => marcado ? _sel.remove(d.$3) : _sel.add(d.$3)),
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: marcado ? AppColors.accent : AppColors.surfaceHigh,
                        shape: BoxShape.circle,
                        border: Border.all(color: marcado ? AppColors.accent : AppColors.line),
                      ),
                      child: Text(
                        d.$1,
                        style: AppText.bodyStrong(13.5, color: marcado ? AppColors.onAccent : AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(d.$2, style: AppText.caption(10.5, color: AppColors.textMuted)),
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
