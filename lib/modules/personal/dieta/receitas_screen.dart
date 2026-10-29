import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/models/dieta.dart';
import '../../../core/services/receita_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import 'busca_alimento_sheet.dart';

/// Abre a biblioteca para escolher uma receita e as porções.
Future<({Receita receita, double porcoes})?> escolherReceita(BuildContext context) {
  return Navigator.push<({Receita receita, double porcoes})>(
    context,
    MaterialPageRoute(builder: (_) => const ReceitasScreen(escolhendo: true)),
  );
}

/// Biblioteca de receitas do profissional.
///
/// Com [escolhendo], tocar numa receita pede as porções e devolve a
/// escolha — é o caminho do montador. Sem, tocar abre para editar.
class ReceitasScreen extends StatefulWidget {
  const ReceitasScreen({super.key, this.escolhendo = false});

  final bool escolhendo;

  @override
  State<ReceitasScreen> createState() => _ReceitasScreenState();
}

class _ReceitasScreenState extends State<ReceitasScreen> {
  List<Receita> _receitas = const [];
  bool _carregando = true;
  Object? _erro;
  String _busca = '';

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
      final r = await ReceitaService.listar();
      if (mounted) setState(() => _receitas = r);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _editar([Receita? r]) async {
    final salvou = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReceitaEditorScreen(receita: r)),
    );
    if (salvou == true && mounted) await _carregar();
  }

  Future<void> _tocar(Receita r) async {
    if (!widget.escolhendo) return _editar(r);
    final porcoes = await pedirPorcoes(context, titulo: r.nome, inicial: 1);
    if (porcoes == null || !mounted) return;
    Navigator.pop(context, (receita: r, porcoes: porcoes));
  }

  @override
  Widget build(BuildContext context) {
    final termo = _busca.trim().toLowerCase();
    final lista = termo.isEmpty
        ? _receitas
        : _receitas.where((r) => r.nome.toLowerCase().contains(termo)).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.escolhendo ? 'Escolher receita' : 'Receitas', style: AppText.title(16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        onPressed: _editar,
        icon: const Icon(Icons.add_rounded),
        label: Text('Nova receita', style: AppText.bodyStrong(14, color: AppColors.onAccent)),
      ),
      body: _carregando && _receitas.isEmpty
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _erro != null
              ? PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não consegui carregar',
                  message: '$_erro',
                  actionLabel: 'Tentar de novo',
                  onAction: _carregar,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 96,
                  ),
                  children: [
                    if (_receitas.length > 4) ...[
                      TextField(
                        onChanged: (v) => setState(() => _busca = v),
                        style: AppText.body(14.5),
                        decoration: InputDecoration(
                          hintText: 'Buscar receita',
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    if (_receitas.isEmpty)
                      const PhdEmptyState(
                        icon: Icons.menu_book_rounded,
                        title: 'Sua biblioteca está vazia',
                        message: 'Monte receitas com a base de alimentos — os macros por '
                            'porção saem sozinhos — e use em qualquer plano.',
                      ),
                    for (final r in lista)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _cartao(r),
                      ),
                  ],
                ),
    );
  }

  Widget _cartao(Receita r) {
    final p = r.porPorcao;
    return PhdCard(
      onTap: () => _tocar(r),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.tint(AppColors.accent),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.menu_book_rounded, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(14.5)),
                const SizedBox(height: 2),
                Text(
                  [
                    '${p.kcal.round()} kcal/porção',
                    'P ${p.proteina.round()} C ${p.carboidrato.round()} G ${p.gordura.round()}',
                    r.rendimentoTexto,
                    if (r.tempoMinutos != null) '${r.tempoMinutos} min',
                  ].join(' · '),
                  maxLines: 2,
                  style: AppText.caption(11.5),
                ),
              ],
            ),
          ),
          if (widget.escolhendo)
            IconButton(
              tooltip: 'Editar ${r.nome}',
              icon: Icon(Icons.edit_outlined, size: 19, color: AppColors.textMuted),
              onPressed: () => _editar(r),
            )
          else
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Pede um número de porções (aceita meia porção).
Future<double?> pedirPorcoes(BuildContext context, {required String titulo, double inicial = 1}) {
  final campo = TextEditingController(text: porcoesTexto(inicial));
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      void confirmar() {
        final v = double.tryParse(campo.text.replaceAll(',', '.'));
        if (v != null && v > 0 && v <= 20) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(titulo, style: AppText.title(17)),
        content: TextField(
          controller: campo,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
          style: AppText.body(15),
          decoration: const InputDecoration(labelText: 'Porções', suffixText: 'porção(ões)'),
          onSubmitted: (_) => confirmar(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: confirmar,
            child: Text('Confirmar', style: AppText.bodyStrong(13.5, color: AppColors.accent)),
          ),
        ],
      );
    },
  );
}

// ══════════════════════════════════════════════════════════════
//  Editor
// ══════════════════════════════════════════════════════════════

/// Cria ou edita uma receita. Devolve `true` quando salvou.
class ReceitaEditorScreen extends StatefulWidget {
  const ReceitaEditorScreen({super.key, this.receita});

  final Receita? receita;

  @override
  State<ReceitaEditorScreen> createState() => _ReceitaEditorScreenState();
}

class _ReceitaEditorScreenState extends State<ReceitaEditorScreen> {
  late final _nome = TextEditingController(text: widget.receita?.nome);
  late final _porcoes = TextEditingController(
    text: porcoesTexto(widget.receita?.rendimentoPorcoes ?? 1),
  );
  late final _tempo = TextEditingController(text: widget.receita?.tempoMinutos?.toString());
  late final _preparo = TextEditingController(text: widget.receita?.modoPreparo);
  late final _ingredientes = [...?widget.receita?.ingredientes];
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _porcoes.dispose();
    _tempo.dispose();
    _preparo.dispose();
    super.dispose();
  }

  double get _rendimento => double.tryParse(_porcoes.text.replaceAll(',', '.')) ?? 1;

  Receita get _rascunho => Receita(
        id: widget.receita?.id ?? '',
        nome: _nome.text,
        rendimentoPorcoes: _rendimento <= 0 ? 1 : _rendimento,
        ingredientes: _ingredientes,
      );

  Future<void> _adicionar() async {
    final e = await escolherAlimento(context);
    if (e == null || !mounted) return;
    setState(() => _ingredientes.add(IngredienteReceita(
          alimento: e.alimento,
          quantidadeG: e.gramas,
          medidaExibicao: e.medidaExibicao,
        )));
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    final rend = double.tryParse(_porcoes.text.replaceAll(',', '.'));
    String? erro;
    if (nome.isEmpty) {
      erro = 'Dê um nome para a receita.';
    } else if (rend == null || rend <= 0) {
      erro = 'O rendimento precisa ser maior que zero.';
    } else if (_ingredientes.isEmpty) {
      erro = 'Adicione pelo menos um ingrediente: é deles que saem os macros.';
    }
    if (erro != null) {
      setState(() => _erro = erro);
      return;
    }

    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ReceitaService.salvar(
        id: widget.receita?.id,
        nome: nome,
        rendimentoPorcoes: rend!,
        tempoMinutos: int.tryParse(_tempo.text.trim()),
        modoPreparo: _preparo.text,
        ingredientes: _ingredientes,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não consegui salvar: $e';
          _salvando = false;
        });
      }
    }
  }

  Future<void> _excluir() async {
    final r = widget.receita;
    if (r == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Excluir "${r.nome}"?', style: AppText.title(17)),
        content: Text('A receita sai da sua biblioteca.', style: AppText.body(13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ReceitaService.excluir(r.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      // Receita em uso num plano: o banco recusa (`on delete restrict`).
      if (mounted) {
        setState(() => _erro = 'Esta receita está em um plano alimentar. Tire-a do '
            'plano antes de excluir.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _rascunho.porPorcao;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.receita == null ? 'Nova receita' : 'Editar receita', style: AppText.title(16)),
        actions: [
          if (widget.receita != null)
            IconButton(
              tooltip: 'Excluir receita',
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
              onPressed: _excluir,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
        children: [
          PhdField(
            controller: _nome,
            label: 'Nome',
            hint: 'Panqueca de banana',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: PhdField(
                  controller: _porcoes,
                  label: 'Rende (porções)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PhdField(
                  controller: _tempo,
                  label: 'Tempo (min)',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: PhdStat(label: 'Por porção', value: '${p.kcal.round()} kcal', valueSize: 22),
                ),
                Text(
                  'P ${p.proteina.round()} g\nC ${p.carboidrato.round()} g\nG ${p.gordura.round()} g',
                  textAlign: TextAlign.right,
                  style: AppText.caption(12),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PhdSectionHeader(label: 'Ingredientes', trailing: '${_ingredientes.length}'),
          const SizedBox(height: AppSpacing.sm),
          for (final (i, ing) in _ingredientes.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: PhdCard(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ing.alimento.rotulo, style: AppText.body(13.5)),
                          Text(ing.quantidadeTexto, style: AppText.caption(11.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remover ${ing.alimento.nome}',
                      icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                      onPressed: () => setState(() => _ingredientes.removeAt(i)),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          PhdAddCard(label: 'Adicionar ingrediente', height: 44, onTap: _adicionar),
          const SizedBox(height: AppSpacing.xl),
          PhdField(
            controller: _preparo,
            label: 'Modo de preparo',
            hint: 'Amasse a banana, misture os ovos…',
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.md),
            PhdAviso(texto: _erro!),
          ],
          const SizedBox(height: AppSpacing.xl),
          PhdButton(label: 'Salvar receita', icon: Icons.check_rounded, loading: _salvando, onPressed: _salvar),
        ],
      ),
    );
  }
}
