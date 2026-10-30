import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/dieta.dart';
import '../../../core/layout/desktop.dart';
import '../../../core/services/dieta_service.dart';
import '../../../core/services/modelo_plano_service.dart';
import '../../../core/services/receita_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dieta_calculos.dart';
import '../../../core/widgets/widgets.dart';
import '../shell/menu_lateral.dart';
import 'busca_alimento_sheet.dart';
import 'painel_alimentos.dart';
import 'plano_pdf.dart';
import 'receitas_screen.dart';

/// Monta o plano alimentar: refeições, alimentos, quantidades.
///
/// A tela mostra o tempo todo a diferença entre o que a meta pede e o que o
/// plano já prescreve. Montar dieta sem esse número na frente é somar de
/// cabeça, e o erro só aparece depois que o aluno já está seguindo.
class PlanoMontadorScreen extends StatefulWidget {
  const PlanoMontadorScreen({
    super.key,
    required this.planoId,
    required this.alunoNome,
  });

  final String planoId;
  final String alunoNome;

  @override
  State<PlanoMontadorScreen> createState() => _PlanoMontadorScreenState();
}

class _PlanoMontadorScreenState extends State<PlanoMontadorScreen> {
  PlanoAlimentar? _plano;
  bool _carregando = true;
  Object? _erro;

  /// Quando não é nulo, a refeição desse id está em modo de seleção para
  /// agrupar substitutos, e [_selecionados] guarda os itens marcados.
  String? _agrupandoEm;
  final _selecionados = <String>{};

  /// Desktop: refeição que recebe o que for escolhido no painel da direita.
  String? _destino;
  final _focoBusca = FocusNode();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _focoBusca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final p = await DietaService.carregarPlano(widget.planoId);
      if (mounted) setState(() => _plano = p);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Toda escrita passa por aqui: grava, recarrega e mostra a falha.
  ///
  /// Recarregar inteiro depois de cada mudança é mais consultas do que o
  /// mínimo, mas o total do plano depende de todos os itens e de quais estão
  /// agrupados. Recalcular na mão em memória é onde apareceria a divergência
  /// entre o que a tela mostra e o que está salvo.
  Future<void> _gravar(Future<void> Function() acao) async {
    try {
      await acao();
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não consegui salvar: $e', style: AppText.body(13.5)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ehDesktop(context)) return _desktop();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_plano?.nome ?? 'Plano alimentar', style: AppText.title(16)),
            Text(
              widget.alunoNome,
              style: AppText.caption(11.5, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          if (_plano != null && !_carregando)
            PopupMenuButton<String>(
              color: AppColors.surfaceHigh,
              surfaceTintColor: Colors.transparent,
              tooltip: 'Opções do plano',
              shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
              icon: Icon(Icons.more_vert_rounded,
                  color: AppColors.textMuted, size: 20),
              onSelected: _menuPlano,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'assinar',
                  child: Text(
                    _plano!.assinado ? 'Assinar de novo' : 'Assinar plano',
                    style: AppText.body(14),
                  ),
                ),
                PopupMenuItem(
                  value: 'observacoes',
                  child: Text('Orientações gerais', style: AppText.body(14)),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: Text('Gerar PDF do plano', style: AppText.body(14)),
                ),
                PopupMenuItem(
                  value: 'modelo',
                  child: Text('Salvar como modelo', style: AppText.body(14)),
                ),
                PopupMenuItem(
                  value: 'receitas',
                  child: Text('Minhas receitas', style: AppText.body(14)),
                ),
              ],
            ),
        ],
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_carregando && _plano == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: '$_erro',
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }
    final p = _plano;
    if (p == null) {
      return PhdEmptyState(
        icon: Icons.help_outline_rounded,
        title: 'Plano não encontrado',
        message: 'Ele pode ter sido excluído em outro dispositivo.',
        actionLabel: 'Voltar',
        onAction: () => Navigator.pop(context),
      );
    }

    return ReorderableListView.builder(
      // A alça é o ícone à esquerda do nome (ReorderableDragStartListener).
      // No navegador e no desktop o Flutter ainda desenharia uma segunda
      // alça à direita, por cima das calorias de cada item.
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge * 2,
      ),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _resumo(p),
          const SizedBox(height: AppSpacing.xl),
          PhdSectionHeader(label: 'Refeições', trailing: '${p.refeicoes.length}'),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md),
        child: PhdAddCard(
          label: 'Adicionar refeição',
          onTap: _adicionarRefeicao,
        ),
      ),
      itemCount: p.refeicoes.length,
      // `onReorderItem` já devolve o índice de destino corrigido para a
      // remoção do item arrastado. O `onReorder` antigo não, e era aí que
      // nascia o clássico "arrastei para baixo e foi para o lugar errado".
      onReorderItem: (de, para) {
        final lista = [...p.refeicoes];
        final r = lista.removeAt(de);
        lista.insert(para, r);
        // A tela já mostra a ordem nova antes da ida ao servidor: arrastar
        // e ver voltar ao lugar enquanto grava parece que não funcionou.
        setState(() => _plano = _comRefeicoes(p, lista));
        _gravar(() => DietaService.reordenarRefeicoes(lista));
      },
      itemBuilder: (_, i) => Padding(
        key: ValueKey(p.refeicoes[i].id),
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _cartaoRefeicao(p.refeicoes[i], i),
      ),
    );
  }

  // ── Desktop ─────────────────────────────────────────────────
  //
  // Mesmo estado e mesmas ações do celular, outra disposição: menu à
  // esquerda, totais presos no topo, refeições em duas colunas e a busca de
  // alimentos sempre aberta à direita. O layout de celular acima não muda.

  Widget _desktop() {
    final p = _plano;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): _focoBusca.requestFocus,
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _focoBusca.requestFocus,
        },
        child: Focus(
          autofocus: true,
          child: Row(
            children: [
              const MenuLateral(caminho: '/alunos'),
              Expanded(
                child: Column(
                  children: [
                    _topoDesktop(p),
                    Expanded(
                      child: p == null
                          ? _corpo()
                          : Row(
                              children: [
                                Expanded(child: _centroDesktop(p)),
                                SizedBox(
                                  width: 400,
                                  child: PainelAlimentos(
                                    destinos: [for (final r in p.refeicoes) (id: r.id, nome: r.nome)],
                                    destino: _destinoValido(p),
                                    aoTrocarDestino: (id) => setState(() => _destino = id),
                                    aoAdicionar: _adicionarDoPainel,
                                    focoBusca: _focoBusca,
                                    kcalAtual: p.totalPrescrito.kcal,
                                    metaKcal: p.metaKcal,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A refeição que recebe o que for escolhido no painel. Se a escolhida
  /// sumiu (foi excluída), cai na primeira vazia — é a que mais precisa.
  String? _destinoValido(PlanoAlimentar p) {
    if (p.refeicoes.any((r) => r.id == _destino)) return _destino;
    for (final r in p.refeicoes) {
      if (r.vazia) return r.id;
    }
    return p.refeicoes.isEmpty ? null : p.refeicoes.first.id;
  }

  Future<void> _adicionarDoPainel(AlimentoEscolhido e) async {
    final p = _plano;
    if (p == null) return;
    final id = _destinoValido(p);
    final r = p.refeicoes.where((x) => x.id == id).firstOrNull;
    if (r == null) return;
    await _gravar(
      () => DietaService.adicionarItem(
        refeicaoId: r.id,
        alimentoId: e.alimento.id,
        quantidadeG: e.gramas,
        medidaExibicao: e.medidaExibicao,
        ordem: r.itens.length,
      ),
    );
  }

  Widget _topoDesktop(PlanoAlimentar? p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl, AppSpacing.lg),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          PhdAvatar(name: widget.alunoNome, size: 46, ringColor: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alunos  /  ${widget.alunoNome}  /  Plano alimentar',
                    style: AppText.caption(12, color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text(p?.nome ?? 'Plano alimentar', style: AppText.display(21)),
                if (p != null) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      if ((p.objetivo ?? '').trim().isNotEmpty) PhdStatusChip(label: p.objetivo!, tone: PhdTone.accent),
                      PhdStatusChip(
                        label: p.assinado ? 'assinado · CRN ${p.crnAssinatura}' : 'não assinado',
                        tone: p.assinado ? PhdTone.success : PhdTone.warning,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (p != null) ...[
            _botaoTopo('Receitas', Icons.menu_book_outlined, () => _menuPlano('receitas')),
            _botaoTopo('Orientações', Icons.notes_rounded, () => _menuPlano('observacoes')),
            _botaoTopo('PDF', Icons.picture_as_pdf_outlined, () => _menuPlano('pdf')),
            _botaoTopo('Salvar modelo', Icons.bookmark_add_outlined, () => _menuPlano('modelo')),
            PhdButton(
              label: p.assinado ? 'Assinar de novo' : 'Assinar plano',
              icon: Icons.verified_outlined,
              size: PhdButtonSize.medium,
              expand: false,
              variant: p.assinado ? PhdButtonVariant.secondary : PhdButtonVariant.primary,
              onPressed: () => _menuPlano('assinar'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _botaoTopo(String rotulo, IconData icone, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: PhdButton(
          label: rotulo,
          icon: icone,
          size: PhdButtonSize.medium,
          expand: false,
          variant: PhdButtonVariant.secondary,
          onPressed: onTap,
        ),
      );

  Widget _centroDesktop(PlanoAlimentar p) {
    final n = p.refeicoes.length;
    final meio = (n + 1) ~/ 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
          child: _totaisDesktop(p),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.huge),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < meio; i++) _refeicaoDesktop(p, p.refeicoes[i], i),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = meio; i < n; i++) _refeicaoDesktop(p, p.refeicoes[i], i),
                      PhdAddCard(label: 'Nova refeição', onTap: _adicionarRefeicao),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _totaisDesktop(PlanoAlimentar p) {
    final t = p.totalPrescrito;
    final meta = p.metaKcal;
    final desvio = p.desvioKcal;
    final kcalMacros = t.proteina * 4 + t.carboidrato * 4 + t.gordura * 9;
    int pct(double kcal) => kcalMacros <= 0 ? 0 : (kcal / kcalMacros * 100).round();

    final String textoDesvio;
    final Color corDesvio;
    if (desvio == null) {
      textoDesvio = 'sem meta definida';
      corDesvio = AppColors.textMuted;
    } else if (desvio.abs() <= 50) {
      // Até 50 kcal é arredondamento de porção, não erro de montagem.
      textoDesvio = 'na meta';
      corDesvio = AppColors.successText;
    } else if (desvio < 0) {
      textoDesvio = 'faltam ${_milhar(-desvio)} kcal';
      corDesvio = AppColors.warningText;
    } else {
      textoDesvio = '${_milhar(desvio)} kcal acima';
      corDesvio = AppColors.warningText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.rXl,
        border: Border.all(color: AppColors.line),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            PhdRing(
              valor: meta == null ? 0 : proporcao(t.kcal, meta),
              tamanho: 60,
              espessura: 7,
              child: Text(
                meta == null ? '—' : '${(t.kcal / meta * 100).round()}%',
                style: AppText.number(12.5),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ENERGIA', style: AppText.label()),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: _milhar(t.kcal), style: AppText.number(24)),
                    TextSpan(
                      text: meta == null ? ' kcal' : ' / ${_milhar(meta)} kcal',
                      style: AppText.caption(12.5, color: AppColors.textMuted),
                    ),
                  ]),
                ),
                Text(textoDesvio, style: AppText.bodyStrong(11.5, color: corDesvio)),
              ],
            ),
            _divisor(),
            Expanded(child: _macroDesktop('Proteína', t.proteina, p.metaProteina)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: _macroDesktop('Carboidrato', t.carboidrato, p.metaCarboidrato)),
            const SizedBox(width: AppSpacing.lg),
            Expanded(child: _macroDesktop('Gordura', t.gordura, p.metaGordura)),
            _divisor(),
            SizedBox(
              width: 170,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DISTRIBUIÇÃO', style: AppText.label()),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: AppRadius.rPill,
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: kcalMacros <= 0
                            ? [Expanded(child: ColoredBox(color: AppColors.surfaceHigh))]
                            : [
                                Expanded(flex: (t.proteina * 4).round() + 1, child: ColoredBox(color: AppColors.accent)),
                                Expanded(flex: (t.carboidrato * 4).round() + 1, child: ColoredBox(color: AppColors.warning)),
                                Expanded(flex: (t.gordura * 9).round() + 1, child: ColoredBox(color: AppColors.textSecondary)),
                              ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'P ${pct(t.proteina * 4)}%  ·  C ${pct(t.carboidrato * 4)}%  ·  G ${pct(t.gordura * 9)}%',
                    style: AppText.caption(11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divisor() => Container(
        width: 1,
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        color: AppColors.line,
      );

  Widget _macroDesktop(String nome, double prescrito, double? meta) {
    final falta = meta == null ? null : meta - prescrito;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nome, style: AppText.caption(11.5)),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: '${prescrito.round()}', style: AppText.number(17)),
            TextSpan(
              text: meta == null ? ' g' : ' / ${meta.round()} g',
              style: AppText.caption(12, color: AppColors.textMuted),
            ),
          ]),
        ),
        const SizedBox(height: 5),
        PhdProgressBar(value: meta == null ? 0 : proporcao(prescrito, meta), height: 6),
        const SizedBox(height: 3),
        Text(
          falta == null
              ? 'sem meta'
              : falta.abs() < 3
                  ? 'na meta'
                  : falta > 0
                      ? 'faltam ${falta.round()} g'
                      : '${(-falta).round()} g acima',
          style: AppText.caption(10.5, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _refeicaoDesktop(PlanoAlimentar p, Refeicao r, int indice) {
    final t = r.total;
    final agrupando = _agrupandoEm == r.id;
    final destino = _destinoValido(p) == r.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        decoration: BoxDecoration(
          color: destino ? Color.alphaBlend(AppColors.tint(AppColors.accent), AppColors.surface) : AppColors.surface,
          borderRadius: AppRadius.rXl,
          border: Border.all(
            color: destino ? AppColors.accent : AppColors.line,
            width: destino ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Clicar no cabeçalho escolhe a refeição como destino do painel.
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
              onTap: () => setState(() => _destino = r.id),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: destino ? AppColors.accent : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_iconeRefeicao(r.nome),
                          size: 17, color: destino ? AppColors.onAccent : AppColors.textSecondary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title(14.5)),
                          Text(
                            destino ? 'recebendo alimentos' : (r.horarioTexto ?? 'sem horário'),
                            style: destino
                                ? AppText.bodyStrong(11.5, color: AppColors.accent)
                                : AppText.caption(11.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(text: '${t.kcal.round()}', style: AppText.number(15)),
                          TextSpan(text: ' kcal', style: AppText.caption(11, color: AppColors.textMuted)),
                        ])),
                        Text(
                          'P ${t.proteina.round()} · C ${t.carboidrato.round()} · G ${t.gordura.round()}',
                          style: AppText.caption(10.5, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    PopupMenuButton<String>(
                      color: AppColors.surfaceHigh,
                      surfaceTintColor: Colors.transparent,
                      tooltip: 'Opções de ${r.nome}',
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                      icon: Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 19),
                      onSelected: (v) {
                        if (v == 'subir') return _moverRefeicao(p, indice, indice - 1);
                        if (v == 'descer') return _moverRefeicao(p, indice, indice + 1);
                        _menuRefeicao(v, r);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'editar', child: Text('Nome e horário', style: AppText.body(14))),
                        if (r.itens.length > 1)
                          PopupMenuItem(
                            value: 'agrupar',
                            child: Text(agrupando ? 'Sair da seleção' : 'Marcar substitutos', style: AppText.body(14)),
                          ),
                        if (indice > 0)
                          PopupMenuItem(value: 'subir', child: Text('Mover para antes', style: AppText.body(14))),
                        if (indice < p.refeicoes.length - 1)
                          PopupMenuItem(value: 'descer', child: Text('Mover para depois', style: AppText.body(14))),
                        PopupMenuItem(
                          value: 'remover',
                          child: Text('Excluir refeição', style: AppText.body(14, color: AppColors.dangerText)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (agrupando)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                child: PhdAviso(
                  texto: 'Marque os alimentos que podem ser trocados entre si. O aluno escolhe um '
                      'deles, e o total da refeição conta só uma vez.',
                  icone: Icons.swap_horiz_rounded,
                  cor: AppColors.accent,
                  corTexto: AppColors.accent,
                ),
              ),
            for (final item in r.itens) _itemDesktop(item, r, agrupando),
            if (r.receitas.isNotEmpty && !agrupando)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
                child: Column(children: [for (final rr in r.receitas) _linhaReceita(rr)]),
              ),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: agrupando
                  ? Row(
                      children: [
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            _agrupandoEm = null;
                            _selecionados.clear();
                          }),
                          child: Text('Cancelar', style: AppText.bodyStrong(12.5, color: AppColors.textSecondary)),
                        ),
                        TextButton(
                          onPressed: _selecionados.length < 2 ? null : _confirmarGrupo,
                          child: Text('Agrupar',
                              style: AppText.bodyStrong(12.5,
                                  color: _selecionados.length < 2 ? AppColors.textMuted : AppColors.accent)),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _destino = r.id);
                            _focoBusca.requestFocus();
                          },
                          icon: Icon(Icons.add_rounded, size: 16, color: AppColors.textSecondary),
                          label: Text('Alimento', style: AppText.bodyStrong(12.5, color: AppColors.textSecondary)),
                        ),
                        TextButton.icon(
                          onPressed: () => _adicionarReceita(r),
                          icon: Icon(Icons.menu_book_outlined, size: 15, color: AppColors.textSecondary),
                          label: Text('Receita', style: AppText.bodyStrong(12.5, color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemDesktop(ItemRefeicao item, Refeicao r, bool agrupando) {
    final n = item.nutrientes;
    final marcado = _selecionados.contains(item.id);

    return InkWell(
      onTap: agrupando
          ? () => setState(() {
                if (!_selecionados.remove(item.id)) _selecionados.add(item.id);
              })
          : () => _editarItem(item, r),
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            if (agrupando)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(
                  marcado ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: marcado ? AppColors.accent : AppColors.textMuted,
                ),
              ),
            if (item.temSubstitutos)
              Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Icon(Icons.swap_horiz_rounded, size: 15, color: AppColors.accent),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.alimento.rotulo,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(12.5)),
                  Text(
                    'P ${n.proteina.toStringAsFixed(1)}   C ${n.carboidrato.toStringAsFixed(1)}   '
                    'G ${n.gordura.toStringAsFixed(1)}',
                    style: AppText.caption(10.5, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              constraints: const BoxConstraints(minWidth: 84, maxWidth: 150),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.rSm),
              child: Text(
                item.quantidadeTexto,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(11.5, color: AppColors.textSecondary),
              ),
            ),
            SizedBox(
              width: 48,
              child: Text('${n.kcal.round()}', textAlign: TextAlign.right, style: AppText.number(12.5)),
            ),
          ],
        ),
      ),
    );
  }

  void _moverRefeicao(PlanoAlimentar p, int de, int para) {
    final lista = [...p.refeicoes];
    final r = lista.removeAt(de);
    lista.insert(para, r);
    setState(() => _plano = _comRefeicoes(p, lista));
    _gravar(() => DietaService.reordenarRefeicoes(lista));
  }

  static IconData _iconeRefeicao(String nome) {
    final n = nome.toLowerCase();
    if (n.contains('café') || n.contains('cafe') || n.contains('desjejum')) return Icons.free_breakfast_outlined;
    if (n.contains('almoço') || n.contains('almoco')) return Icons.restaurant_rounded;
    if (n.contains('jantar')) return Icons.dinner_dining_outlined;
    if (n.contains('ceia')) return Icons.nightlight_outlined;
    if (n.contains('treino')) return Icons.bolt_rounded;
    return Icons.bakery_dining_outlined;
  }

  /// "1.850" — milhar com ponto, como o personal escreve.
  static String _milhar(double v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  // ── Resumo: meta contra prescrito ───────────────────────────

  Widget _resumo(PlanoAlimentar p) {
    final total = p.totalPrescrito;
    final desvio = p.desvioKcal;

    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Prescrito',
                  value: '${total.kcal.round()}',
                  valueSize: 32,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: p.metaKcal == null ? 'Meta não definida' : 'Meta',
                  value: p.metaKcal == null
                      ? '—'
                      : '${p.metaKcal!.round()}',
                  valueSize: 32,
                  valueColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (desvio != null) ...[
            const SizedBox(height: AppSpacing.md),
            _linhaDesvio(desvio),
          ],
          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.line, height: 1),
          const SizedBox(height: AppSpacing.lg),
          _macro('Proteína', total.proteina, p.metaProteina),
          const SizedBox(height: AppSpacing.md),
          _macro('Carboidrato', total.carboidrato, p.metaCarboidrato),
          const SizedBox(height: AppSpacing.md),
          _macro('Gordura', total.gordura, p.metaGordura),
          if (total.fibra > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Fibra ${total.fibra.round()} g'
              '${p.aguaMl != null ? '  ·  Água ${(p.aguaMl! / 1000).toStringAsFixed(1)} L/dia' : ''}',
              style: AppText.caption(12, color: AppColors.textMuted),
            ),
          ],
          if (p.formulaTmb != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Meta por ${p.formulaTmb}'
              '${p.fatorAtividade != null ? ' · fator ${p.fatorAtividade}' : ''}',
              style: AppText.caption(11, color: AppColors.textMuted),
            ),
          ],
          _assinatura(p),
        ],
      ),
    );
  }

  Widget _linhaDesvio(double desvio) {
    // Até 50 kcal de diferença não é erro de montagem: é arredondamento de
    // porção. Pintar de vermelho aí faria o nutricionista perseguir zero.
    final dentro = desvio.abs() <= 50;
    final tom = dentro ? PhdTone.success : PhdTone.warning;
    final sinal = desvio > 0 ? '+' : '';

    return Row(
      children: [
        PhdStatusChip(
          label: dentro
              ? 'na meta'
              : '$sinal${desvio.round()} kcal',
          tone: tom,
        ),
        const SizedBox(width: AppSpacing.sm),
        if (!dentro)
          Expanded(
            child: Text(
              desvio > 0 ? 'acima da meta' : 'abaixo da meta',
              style: AppText.caption(11.5, color: AppColors.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _macro(String nome, double prescrito, double? meta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(nome, style: AppText.caption(12))),
            Text(
              meta == null
                  ? '${prescrito.round()} g'
                  : '${prescrito.round()} / ${meta.round()} g',
              style: AppText.number(12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
        if (meta != null) ...[
          const SizedBox(height: 5),
          PhdProgressBar(value: proporcao(prescrito, meta)),
        ],
      ],
    );
  }

  Widget _assinatura(PlanoAlimentar p) {
    if (!p.assinado) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: PhdAviso(
          texto: 'Plano não assinado. A prescrição dietética é privativa do '
              'nutricionista — assine com seu CRN antes de liberar para o aluno.',
          icone: Icons.gpp_maybe_outlined,
          cor: AppColors.warning,
          corTexto: AppColors.warningText,
        ),
      );
    }
    final em = p.assinadoEm!;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        children: [
          Icon(Icons.verified_rounded,
              size: 16, color: AppColors.successText),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Assinado · CRN ${p.crnAssinatura} · '
              '${em.day.toString().padLeft(2, '0')}/'
              '${em.month.toString().padLeft(2, '0')}/${em.year}',
              style: AppText.caption(11.5, color: AppColors.successText),
            ),
          ),
        ],
      ),
    );
  }

  // ── Refeição ────────────────────────────────────────────────

  Widget _cartaoRefeicao(Refeicao r, int indice) {
    final t = r.total;
    final agrupando = _agrupandoEm == r.id;

    return PhdCard(
      accentBar: r.vazia ? AppColors.accent : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: indice,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Icon(Icons.drag_indicator_rounded,
                      size: 18, color: AppColors.textMuted),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.nome, style: AppText.title(15)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (r.horarioTexto != null) r.horarioTexto!,
                        if (r.vazia)
                          'sem alimentos'
                        else
                          '${t.kcal.round()} kcal · P ${t.proteina.round()} '
                              'C ${t.carboidrato.round()} G ${t.gordura.round()}',
                      ].join('  ·  '),
                      style: AppText.caption(
                        11.5,
                        color: r.vazia ? AppColors.accent : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.surfaceHigh,
                surfaceTintColor: Colors.transparent,
                tooltip: 'Opções de ${r.nome}',
                shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
                icon: Icon(Icons.more_vert_rounded,
                    color: AppColors.textMuted, size: 19),
                onSelected: (v) => _menuRefeicao(v, r),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'editar',
                    child: Text('Nome e horário', style: AppText.body(14)),
                  ),
                  if (r.itens.length > 1)
                    PopupMenuItem(
                      value: 'agrupar',
                      child: Text(
                        agrupando ? 'Sair da seleção' : 'Marcar substitutos',
                        style: AppText.body(14),
                      ),
                    ),
                  PopupMenuItem(
                    value: 'remover',
                    child: Text('Excluir refeição',
                        style: AppText.body(14, color: AppColors.dangerText)),
                  ),
                ],
              ),
            ],
          ),
          if (agrupando) ...[
            const SizedBox(height: AppSpacing.md),
            PhdAviso(
              texto: 'Marque os alimentos que podem ser trocados entre si. '
                  'O aluno escolhe um deles, e o total da refeição conta '
                  'só uma vez.',
              icone: Icons.swap_horiz_rounded,
              cor: AppColors.accent,
              corTexto: AppColors.accent,
            ),
          ],
          if (r.itens.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            for (final item in r.itens) _linhaItem(item, r, agrupando),
          ],
          if (r.receitas.isNotEmpty && !agrupando) ...[
            if (r.itens.isEmpty) const SizedBox(height: AppSpacing.md),
            for (final rr in r.receitas) _linhaReceita(rr),
          ],
          const SizedBox(height: AppSpacing.md),
          if (agrupando)
            Row(
              children: [
                Expanded(
                  child: PhdButton(
                    label: 'Cancelar',
                    variant: PhdButtonVariant.ghost,
                    size: PhdButtonSize.small,
                    onPressed: () => setState(() {
                      _agrupandoEm = null;
                      _selecionados.clear();
                    }),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PhdButton(
                    label: 'Agrupar',
                    size: PhdButtonSize.small,
                    // Um item só não forma grupo: trocar um alimento por
                    // nada não é substituição.
                    onPressed: _selecionados.length < 2 ? null : _confirmarGrupo,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: PhdAddCard(
                    label: 'Alimento',
                    height: 42,
                    onTap: () => _adicionarItem(r),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PhdAddCard(
                    label: 'Receita',
                    icon: Icons.menu_book_rounded,
                    height: 42,
                    onTap: () => _adicionarReceita(r),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _linhaItem(ItemRefeicao item, Refeicao r, bool agrupando) {
    final n = item.nutrientes;
    final marcado = _selecionados.contains(item.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.rMd,
        onTap: agrupando
            ? () => setState(() {
                  if (!_selecionados.remove(item.id)) _selecionados.add(item.id);
                })
            : () => _editarItem(item, r),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (agrupando)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Icon(
                    marcado
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 19,
                    color: marcado ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.temSubstitutos)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: Icon(Icons.swap_horiz_rounded,
                                size: 15, color: AppColors.accent),
                          ),
                        Expanded(
                          child: Text(
                            item.alimento.rotulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(13.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.quantidadeTexto,
                      style: AppText.caption(11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${n.kcal.round()}',
                style: AppText.number(13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linhaReceita(ReceitaNaRefeicao rr) {
    final n = rr.nutrientes;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.rMd,
        onTap: () => _editarReceita(rr),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.tint(AppColors.accent),
            borderRadius: AppRadius.rMd,
          ),
          child: Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 17, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rr.receita.nome,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(13.5)),
                    const SizedBox(height: 2),
                    Text('Receita · ${rr.porcoesTextoCompleto}',
                        style: AppText.caption(11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('${n.kcal.round()}', style: AppText.number(13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _adicionarReceita(Refeicao r) async {
    final escolha = await escolherReceita(context);
    if (escolha == null) return;
    await _gravar(
      () => ReceitaService.adicionarNaRefeicao(
        refeicaoId: r.id,
        receitaId: escolha.receita.id,
        porcoes: escolha.porcoes,
        ordem: r.receitas.length,
      ),
    );
  }

  Future<void> _editarReceita(ReceitaNaRefeicao rr) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.pie_chart_outline_rounded, color: AppColors.textSecondary),
              title: Text('Alterar porções', style: AppText.body(14.5)),
              subtitle: Text(rr.porcoesTextoCompleto, style: AppText.caption(12)),
              onTap: () => Navigator.pop(ctx, 'porcoes'),
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: AppColors.textSecondary),
              title: Text('Editar a receita', style: AppText.body(14.5)),
              subtitle: Text('Muda em todos os planos que a usam', style: AppText.caption(12)),
              onTap: () => Navigator.pop(ctx, 'editar'),
            ),
            ListTile(
              leading: Icon(Icons.remove_circle_outline_rounded, color: AppColors.dangerText),
              title: Text('Tirar da refeição', style: AppText.body(14.5, color: AppColors.dangerText)),
              onTap: () => Navigator.pop(ctx, 'remover'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (acao == null || !mounted) return;

    switch (acao) {
      case 'porcoes':
        final v = await pedirPorcoes(context, titulo: rr.receita.nome, inicial: rr.porcoes);
        if (v == null) return;
        await _gravar(() => ReceitaService.alterarPorcoes(rr.id, v));
      case 'editar':
        final salvou = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => ReceitaEditorScreen(receita: rr.receita)),
        );
        if (salvou == true) await _carregar();
      case 'remover':
        await _gravar(() => ReceitaService.removerDaRefeicao(rr.id));
    }
  }

  // ── Ações do plano ──────────────────────────────────────────

  Future<void> _menuPlano(String acao) async {
    final p = _plano;
    if (p == null) return;

    switch (acao) {
      case 'assinar':
        await _assinar(p);

      case 'pdf':
        await compartilharPlanoPdf(context, p, alunoNome: widget.alunoNome);

      case 'receitas':
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const ReceitasScreen()),
        );
        await _carregar();

      case 'modelo':
        final nome = await _dialogoTexto(
          titulo: 'Salvar como modelo',
          rotulo: 'Nome do modelo',
          dica: 'Hipertrofia 2.400 kcal',
          inicial: p.nome,
          linhas: 1,
        );
        if (nome == null || nome.isEmpty) return;
        try {
          await ModeloPlanoService.salvar(p, nome: nome);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.surfaceHigh,
              content: Text('Modelo "$nome" salvo. Use ao criar o plano de outro aluno.',
                  style: AppText.body(13.5)),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.surfaceHigh,
              content: Text('Não consegui salvar o modelo: $e', style: AppText.body(13.5)),
            ),
          );
        }

      case 'observacoes':
        final texto = await _dialogoTexto(
          titulo: 'Orientações gerais',
          rotulo: 'Orientações',
          dica: 'Beba água ao longo do dia, evite...',
          inicial: p.observacoes,
          linhas: 5,
        );
        if (texto == null) return;
        await _gravar(
          () => DietaService.atualizarPlano(p.id, {
            'observacoes': texto.isEmpty ? null : texto,
          }),
        );
    }
  }

  Future<void> _assinar(PlanoAlimentar p) async {
    // Checa o CRN antes de abrir a confirmação: pedir para confirmar e
    // depois falhar é pior do que explicar o que falta agora.
    final crn = await DietaService.meuCrn();
    if (!mounted) return;

    if (crn == null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: Text('Falta o CRN', style: AppText.title(17)),
          content: Text(
            'A prescrição dietética é privativa do nutricionista. Preencha '
            'seu CRN no perfil para poder assinar planos alimentares.',
            style: AppText.body(13.5, color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Entendi',
                  style: AppText.bodyStrong(13.5, color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }

    if (p.vazio) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Adicione alimentos antes de assinar.',
              style: AppText.body(13.5)),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Assinar com CRN $crn?', style: AppText.title(17)),
        content: Text(
          'O plano fica registrado como prescrito por você, nesta data e sob '
          'este registro. O aluno passa a ver o plano como assinado.',
          style: AppText.body(13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Assinar',
                style: AppText.bodyStrong(13.5, color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _gravar(() => DietaService.assinarPlano(p.id));
  }

  // ── Ações de refeição ───────────────────────────────────────

  Future<void> _adicionarRefeicao() async {
    final p = _plano;
    if (p == null) return;

    final dados = await _dialogoRefeicao(titulo: 'Nova refeição');
    if (dados == null) return;

    await _gravar(
      () => DietaService.adicionarRefeicao(
        planoId: p.id,
        nome: dados.nome,
        horario: dados.horario,
        ordem: p.refeicoes.length,
      ),
    );
  }

  Future<void> _menuRefeicao(String acao, Refeicao r) async {
    switch (acao) {
      case 'editar':
        final dados = await _dialogoRefeicao(
          titulo: 'Editar refeição',
          nome: r.nome,
          horario: r.horarioTexto,
        );
        if (dados == null) return;
        await _gravar(
          () => DietaService.atualizarRefeicao(r.id, {
            'nome': dados.nome,
            'horario': dados.horario,
          }),
        );

      case 'agrupar':
        setState(() {
          if (_agrupandoEm == r.id) {
            _agrupandoEm = null;
            _selecionados.clear();
          } else {
            _agrupandoEm = r.id;
            // Já marca o grupo existente, se houver: quem abre a seleção
            // numa refeição que já tem substitutos quer ajustar o grupo,
            // não montar de novo do zero.
            _selecionados
              ..clear()
              ..addAll(r.itens.where((i) => i.temSubstitutos).map((i) => i.id));
          }
        });

      case 'remover':
        final ok = await _confirmar(
          titulo: 'Excluir "${r.nome}"?',
          mensagem: r.vazia
              ? 'A refeição está vazia.'
              : 'Os ${r.itens.length} alimentos dela saem do plano.',
          acao: 'Excluir',
        );
        if (!ok) return;
        if (_agrupandoEm == r.id) {
          setState(() {
            _agrupandoEm = null;
            _selecionados.clear();
          });
        }
        await _gravar(() => DietaService.removerRefeicao(r.id));
    }
  }

  Future<void> _confirmarGrupo() async {
    final ids = _selecionados.toList();
    setState(() {
      _agrupandoEm = null;
      _selecionados.clear();
    });
    await _gravar(() => DietaService.agruparSubstitutos(ids));
  }

  // ── Ações de item ───────────────────────────────────────────

  Future<void> _adicionarItem(Refeicao r) async {
    final escolha = await escolherAlimento(context);
    if (escolha == null) return;

    await _gravar(
      () => DietaService.adicionarItem(
        refeicaoId: r.id,
        alimentoId: escolha.alimento.id,
        quantidadeG: escolha.gramas,
        medidaExibicao: escolha.medidaExibicao,
        ordem: r.itens.length,
      ),
    );
  }

  Future<void> _editarItem(ItemRefeicao item, Refeicao r) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FolhaAcoesItem(item: item),
    );
    if (acao == null || !mounted) return;

    switch (acao) {
      case 'quantidade':
        final g = await _dialogoGramas(item);
        if (g == null) return;
        await _gravar(
          () => DietaService.atualizarItem(item.id, {
            'quantidade_g': g,
            // A medida caseira antiga deixa de valer quando as gramas mudam:
            // manter "2 × colher" ao lado de 150 g mentiria para o aluno.
            'medida_exibicao': null,
          }),
        );

      case 'desagrupar':
        await _gravar(() => DietaService.agruparSubstitutos([item.id]));

      case 'remover':
        await _gravar(() => DietaService.removerItem(item.id));
    }
  }

  // ── Diálogos ────────────────────────────────────────────────

  Future<({String nome, String? horario})?> _dialogoRefeicao({
    required String titulo,
    String? nome,
    String? horario,
  }) async {
    final ctrlNome = TextEditingController(text: nome);
    final ctrlHora = TextEditingController(text: horario);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(titulo, style: AppText.title(17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhdField(
              label: 'Nome',
              controller: ctrlNome,
              hint: 'Café da manhã',
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            PhdField(
              label: 'Horário',
              controller: ctrlHora,
              hint: '07:30 (opcional)',
              keyboardType: TextInputType.datetime,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Salvar',
                style: AppText.bodyStrong(13.5, color: AppColors.accent)),
          ),
        ],
      ),
    );

    final n = ctrlNome.text.trim();
    final h = ctrlHora.text.trim();
    ctrlNome.dispose();
    ctrlHora.dispose();

    if (ok != true || n.isEmpty) return null;
    return (nome: n, horario: h.isEmpty ? null : h);
  }

  Future<double?> _dialogoGramas(ItemRefeicao item) async {
    final ctrl = TextEditingController(
      text: item.quantidadeG.round().toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Quantidade', style: AppText.title(17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.alimento.rotulo,
                style: AppText.caption(12, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            PhdField(
              label: 'Gramas',
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Salvar',
                style: AppText.bodyStrong(13.5, color: AppColors.accent)),
          ),
        ],
      ),
    );

    final valor = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    ctrl.dispose();

    if (ok != true || valor == null || valor <= 0) return null;
    return valor;
  }

  Future<String?> _dialogoTexto({
    required String titulo,
    required String rotulo,
    String? dica,
    String? inicial,
    int linhas = 1,
  }) async {
    final ctrl = TextEditingController(text: inicial);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(titulo, style: AppText.title(17)),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                maxLines: linhas,
                minLines: linhas,
                style: AppText.body(14),
                cursorColor: AppColors.accent,
                decoration: InputDecoration(labelText: rotulo, hintText: dica),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Salvar',
                style: AppText.bodyStrong(13.5, color: AppColors.accent)),
          ),
        ],
      ),
    );

    final texto = ctrl.text.trim();
    ctrl.dispose();
    return ok == true ? texto : null;
  }

  Future<bool> _confirmar({
    required String titulo,
    required String mensagem,
    required String acao,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(titulo, style: AppText.title(17)),
        content: Text(mensagem,
            style: AppText.body(13.5, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(acao,
                style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    return ok == true;
  }
}

/// Cópia do plano com outra lista de refeições, só para a tela refletir a
/// ordem nova antes da gravação.
PlanoAlimentar _comRefeicoes(PlanoAlimentar p, List<Refeicao> refeicoes) =>
    PlanoAlimentar(
      id: p.id,
      alunoId: p.alunoId,
      nome: p.nome,
      objetivo: p.objetivo,
      autorId: p.autorId,
      crnAssinatura: p.crnAssinatura,
      assinadoEm: p.assinadoEm,
      dataInicio: p.dataInicio,
      dataFim: p.dataFim,
      ativo: p.ativo,
      formulaTmb: p.formulaTmb,
      tmb: p.tmb,
      fatorAtividade: p.fatorAtividade,
      get: p.get,
      metaKcal: p.metaKcal,
      metaProteina: p.metaProteina,
      metaCarboidrato: p.metaCarboidrato,
      metaGordura: p.metaGordura,
      aguaMl: p.aguaMl,
      observacoes: p.observacoes,
      refeicoes: refeicoes,
    );

/// Ações de um item já prescrito.
class _FolhaAcoesItem extends StatelessWidget {
  const _FolhaAcoesItem({required this.item});

  final ItemRefeicao item;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.alimento.rotulo, style: AppText.title(16)),
            const SizedBox(height: 3),
            Text(item.quantidadeTexto,
                style: AppText.caption(12, color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.lg),
            PhdListRow(
              title: 'Mudar quantidade',
              leading: Icon(Icons.scale_rounded,
                  size: 19, color: AppColors.textSecondary),
              onTap: () => Navigator.pop(context, 'quantidade'),
            ),
            if (item.temSubstitutos)
              PhdListRow(
                title: 'Tirar do grupo de substitutos',
                leading: Icon(Icons.swap_horiz_rounded,
                    size: 19, color: AppColors.textSecondary),
                onTap: () => Navigator.pop(context, 'desagrupar'),
              ),
            PhdListRow(
              title: 'Remover do plano',
              subtitleColor: AppColors.dangerText,
              leading: Icon(Icons.delete_outline_rounded,
                  size: 19, color: AppColors.dangerText),
              onTap: () => Navigator.pop(context, 'remover'),
            ),
          ],
        ),
      ),
    );
  }
}
