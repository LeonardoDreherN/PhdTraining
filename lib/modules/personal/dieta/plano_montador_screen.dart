import 'package:flutter/material.dart';
import '../../../core/models/dieta.dart';
import '../../../core/services/dieta_service.dart';
import '../../../core/services/modelo_plano_service.dart';
import '../../../core/services/receita_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dieta_calculos.dart';
import '../../../core/widgets/widgets.dart';
import 'busca_alimento_sheet.dart';
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
