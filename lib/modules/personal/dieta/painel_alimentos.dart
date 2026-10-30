import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/models/dieta.dart';
import '../../../core/services/dieta_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import 'busca_alimento_sheet.dart';

/// A busca de alimentos como painel fixo ao lado das refeições — o modo
/// desktop do montador. Escolher um alimento abre a quantidade embaixo, no
/// próprio painel, e o personal adiciona sem nenhuma folha cobrindo o plano.
///
/// No celular quem faz isso é `escolherAlimento`, em duas folhas.
class PainelAlimentos extends StatefulWidget {
  const PainelAlimentos({
    super.key,
    required this.destinos,
    required this.destino,
    required this.aoTrocarDestino,
    required this.aoAdicionar,
    required this.focoBusca,
    this.kcalAtual = 0,
    this.metaKcal,
  });

  /// As refeições do plano; [destino] é a que recebe o próximo alimento.
  final List<({String id, String nome})> destinos;
  final String? destino;
  final ValueChanged<String> aoTrocarDestino;
  final Future<void> Function(AlimentoEscolhido escolha) aoAdicionar;
  final FocusNode focoBusca;

  /// Total do plano agora, para mostrar como ele fica depois de adicionar.
  final double kcalAtual;
  final double? metaKcal;

  @override
  State<PainelAlimentos> createState() => _PainelAlimentosState();
}

class _PainelAlimentosState extends State<PainelAlimentos> {
  final _busca = TextEditingController();
  final _qtd = TextEditingController();
  final _focoQtd = FocusNode();

  List<String> _grupos = const ['Todos'];
  String _grupo = 'Todos';
  List<Alimento> _resultados = const [];
  bool _carregando = true;
  bool _adicionando = false;
  Object? _erro;
  Timer? _debounce;

  Alimento? _sel;
  bool _porMedida = false;

  @override
  void initState() {
    super.initState();
    _carregarGrupos();
    _buscar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    _qtd.dispose();
    _focoQtd.dispose();
    super.dispose();
  }

  Future<void> _carregarGrupos() async {
    try {
      final g = await DietaService.gruposDeAlimentos();
      if (mounted) setState(() => _grupos = g);
    } catch (_) {
      // Filtro é conveniência: sem ele a busca por nome continua servindo.
    }
  }

  Future<void> _buscar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final r = await DietaService.buscarAlimentos(termo: _busca.text, grupo: _grupo);
      if (mounted) setState(() => _resultados = r);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _escolher(Alimento a) {
    setState(() {
      _sel = a;
      _porMedida = a.medidaGramas != null;
      _qtd.text = _porMedida ? '1' : '100';
    });
    // Escolheu, já pode digitar a quantidade e dar Enter.
    _focoQtd.requestFocus();
    _qtd.selection = TextSelection(baseOffset: 0, extentOffset: _qtd.text.length);
  }

  double get _quantidade => double.tryParse(_qtd.text.trim().replaceAll(',', '.')) ?? 0;

  double get _gramas {
    final a = _sel;
    if (a == null) return 0;
    if (!_porMedida) return _quantidade;
    return a.gramasDeMedidas(_quantidade) ?? _quantidade;
  }

  String? get _medidaExibicao {
    final medida = _sel?.medidaCaseira?.trim();
    if (!_porMedida || medida == null || medida.isEmpty) return null;
    return '${_numero(_quantidade)} × $medida';
  }

  String get _nomeDestino {
    for (final d in widget.destinos) {
      if (d.id == widget.destino) return d.nome;
    }
    return 'refeição';
  }

  Future<void> _adicionar() async {
    final a = _sel;
    if (a == null || _gramas <= 0 || widget.destino == null || _adicionando) return;
    setState(() => _adicionando = true);
    try {
      await widget.aoAdicionar((alimento: a, gramas: _gramas, medidaExibicao: _medidaExibicao));
      if (!mounted) return;
      // A busca continua: é comum adicionar vários alimentos parecidos em
      // seguida. Só a seleção zera, e o foco volta para o campo de busca.
      setState(() => _sel = null);
      widget.focoBusca.requestFocus();
      _busca.selection = TextSelection(baseOffset: 0, extentOffset: _busca.text.length);
    } finally {
      if (mounted) setState(() => _adicionando = false);
    }
  }

  void _passo(double delta) {
    final novo = (_quantidade + delta).clamp(0, 9999).toDouble();
    setState(() => _qtd.text = _numero(novo));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('Adicionar em', style: AppText.title(15)),
                    const SizedBox(width: 6),
                    Expanded(child: _seletorDestino()),
                    _tecla('Ctrl K'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _busca,
                  focusNode: widget.focoBusca,
                  style: AppText.body(14),
                  cursorColor: AppColors.accent,
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 320), _buscar);
                  },
                  // Enter na busca escolhe o primeiro resultado.
                  onSubmitted: (_) {
                    if (_resultados.isNotEmpty) _escolher(_resultados.first);
                  },
                  decoration: InputDecoration(
                    hintText: 'Buscar alimento — frango, arroz, whey...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 19),
                  ),
                ),
                if (_grupos.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final g in _grupos) ...[
                          PhdFilterChip(
                            label: g,
                            selected: _grupo == g,
                            onTap: () {
                              if (_grupo == g) return;
                              setState(() => _grupo = g);
                              _buscar();
                            },
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(child: _lista()),
          if (_sel != null) _quantidadeSelecionada(_sel!),
        ],
      ),
    );
  }

  Widget _seletorDestino() {
    return PopupMenuButton<String>(
      color: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      tooltip: 'Escolher a refeição',
      shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
      onSelected: widget.aoTrocarDestino,
      itemBuilder: (_) => [
        for (final d in widget.destinos)
          PopupMenuItem(
            value: d.id,
            child: Text(
              d.nome,
              style: AppText.body(14, color: d.id == widget.destino ? AppColors.accent : AppColors.textPrimary),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _nomeDestino,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title(15).copyWith(color: AppColors.accent),
            ),
          ),
          Icon(Icons.arrow_drop_down_rounded, color: AppColors.accent),
        ],
      ),
    );
  }

  Widget _tecla(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lineStrong),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(t, style: AppText.number(10, color: AppColors.textMuted)),
      );

  Widget _lista() {
    if (_carregando && _resultados.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui buscar',
        message: '$_erro',
        actionLabel: 'Tentar de novo',
        onAction: _buscar,
      );
    }
    if (_resultados.isEmpty) {
      return const PhdEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nada com esse nome',
        message: 'Tente uma palavra mais curta — "frang" acha "Peito de frango grelhado".',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.md),
      itemCount: _resultados.length,
      itemBuilder: (_, i) => _linhaResultado(_resultados[i]),
    );
  }

  Widget _linhaResultado(Alimento a) {
    final marcado = _sel?.id == a.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: marcado ? AppColors.tint(AppColors.accent) : Colors.transparent,
        borderRadius: AppRadius.rMd,
        child: InkWell(
          borderRadius: AppRadius.rMd,
          onTap: () => _escolher(a),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.rotulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(13)),
                      const SizedBox(height: 2),
                      Text(
                        '${a.kcal.round()} kcal / 100 g  ·  P ${_g(a.proteina)}  C ${_g(a.carboidrato)}  '
                        'G ${_g(a.gordura)}${a.fonte == 'seed_inicial' ? '  ·  aproximado' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption(11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: marcado ? AppColors.accent : Colors.transparent,
                    border: Border.all(color: marcado ? AppColors.accent : AppColors.line),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.add_rounded,
                      size: 17, color: marcado ? AppColors.onAccent : AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quantidadeSelecionada(Alimento a) {
    final n = a.paraGramas(_gramas);
    final depois = widget.kcalAtual + n.kcal;
    final meta = widget.metaKcal;
    final passa = meta != null && depois > meta + 50;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(a.rotulo, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title(14.5)),
              ),
              IconButton(
                tooltip: 'Cancelar',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _sel = null),
                icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
              ),
            ],
          ),
          if (a.medidaGramas != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                PhdFilterChip(
                  label: a.medidaCaseira ?? 'Medida caseira',
                  selected: _porMedida,
                  onTap: () {
                    if (_porMedida) return;
                    setState(() {
                      _porMedida = true;
                      _qtd.text = '1';
                    });
                  },
                ),
                const SizedBox(width: 6),
                PhdFilterChip(
                  label: 'Gramas',
                  selected: !_porMedida,
                  onTap: () {
                    if (!_porMedida) return;
                    setState(() {
                      // Mantém a quantidade escolhida, convertida.
                      final g = _gramas;
                      _porMedida = false;
                      _qtd.text = g > 0 ? g.round().toString() : '100';
                    });
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _botaoPasso(Icons.remove_rounded, () => _passo(_porMedida ? -0.5 : -10)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _qtd,
                  focusNode: _focoQtd,
                  textAlign: TextAlign.center,
                  style: AppText.number(20),
                  cursorColor: AppColors.accent,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _adicionar(),
                  decoration: InputDecoration(
                    isDense: true,
                    suffixText: _porMedida ? '× ${a.medidaCaseira ?? 'medida'}' : 'g',
                    suffixStyle: AppText.caption(12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _botaoPasso(Icons.add_rounded, () => _passo(_porMedida ? 0.5 : 10)),
            ],
          ),
          if (_porMedida && a.medidaGramas != null) ...[
            const SizedBox(height: 4),
            Text('= ${_gramas.round()} g', textAlign: TextAlign.center, style: AppText.caption(11.5)),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _mini('${n.kcal.round()}', 'kcal'),
              _mini(_g(n.proteina), 'prot'),
              _mini(_g(n.carboidrato), 'carb'),
              _mini(_g(n.gordura), 'gord'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            meta == null
                ? 'O plano fica com ${depois.round()} kcal'
                : 'O plano fica com ${depois.round()} de ${meta.round()} kcal',
            style: AppText.caption(11.5, color: passa ? AppColors.warningText : AppColors.successText),
          ),
          const SizedBox(height: AppSpacing.md),
          PhdButton(
            label: 'Adicionar em $_nomeDestino',
            icon: Icons.add_rounded,
            loading: _adicionando,
            onPressed: _gramas <= 0 || widget.destino == null ? null : _adicionar,
          ),
        ],
      ),
    );
  }

  Widget _mini(String valor, String rotulo) => Expanded(
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 7),
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.rMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(valor, style: AppText.number(14)),
              Text(rotulo, style: AppText.caption(10.5, color: AppColors.textMuted)),
            ],
          ),
        ),
      );

  Widget _botaoPasso(IconData icone, VoidCallback onTap) => Material(
        color: AppColors.surfaceHigh,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 38, height: 38, child: Icon(icone, size: 18, color: AppColors.textPrimary)),
        ),
      );
}

String _numero(double q) => q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);

/// Gramas sem decimal inútil: "28 g" em vez de "28.0 g".
String _g(double v) {
  if (v >= 10 || v == v.truncateToDouble()) return '${v.round()} g';
  return '${v.toStringAsFixed(1)} g';
}
