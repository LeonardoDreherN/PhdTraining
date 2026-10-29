import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/models/dieta.dart';
import '../../../core/services/dieta_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// O que a folha devolve: o alimento escolhido e quanto dele.
///
/// `medidaExibicao` é o texto que o aluno vai ler ("2 colheres de sopa").
/// Guardamos ele junto das gramas porque é o que a pessoa entende na
/// cozinha, enquanto as gramas são o que entra no cálculo.
typedef AlimentoEscolhido = ({
  Alimento alimento,
  double gramas,
  String? medidaExibicao,
});

/// Busca um alimento e define a quantidade, em duas etapas na mesma folha.
///
/// Devolve `null` se a pessoa fechar sem escolher.
Future<AlimentoEscolhido?> escolherAlimento(BuildContext context) {
  return showModalBottomSheet<AlimentoEscolhido>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BuscaAlimentoSheet(),
  );
}

class _BuscaAlimentoSheet extends StatefulWidget {
  const _BuscaAlimentoSheet();

  @override
  State<_BuscaAlimentoSheet> createState() => _BuscaAlimentoSheetState();
}

class _BuscaAlimentoSheetState extends State<_BuscaAlimentoSheet> {
  final _busca = TextEditingController();

  List<String> _grupos = const ['Todos'];
  String _grupo = 'Todos';

  List<Alimento> _resultados = const [];
  bool _carregando = true;
  Object? _erro;

  /// A busca dispara a cada tecla, mas espera a pessoa parar de digitar.
  /// Sem isso, "frango" seriam seis consultas e a última a chegar poderia
  /// não ser a da palavra inteira.
  Timer? _debounce;

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
      final r = await DietaService.buscarAlimentos(
        termo: _busca.text,
        grupo: _grupo,
      );
      if (mounted) setState(() => _resultados = r);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _buscarComAtraso(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _buscar);
  }

  @override
  Widget build(BuildContext context) {
    // A folha ocupa a altura do teclado também: sem isso o campo de busca
    // fica escondido atrás dele no celular.
    final fundoTeclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: fundoTeclado),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xxl),
            ),
          ),
          child: Column(
            children: [
              _puxador(),
              _cabecalho(),
              _filtros(),
              const SizedBox(height: AppSpacing.md),
              Expanded(child: _corpo(scroll)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _puxador() => Container(
        margin: const EdgeInsets.only(top: AppSpacing.md),
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.lineStrong,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      );

  Widget _cabecalho() => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adicionar alimento', style: AppText.title(18)),
            const SizedBox(height: AppSpacing.md),
            PhdField(
              label: 'Buscar',
              controller: _busca,
              hint: 'frango, arroz, whey...',
              icon: Icons.search_rounded,
              onChanged: _buscarComAtraso,
              onSubmitted: _buscar,
            ),
          ],
        ),
      );

  Widget _filtros() {
    if (_grupos.length <= 1) return const SizedBox.shrink();
    return PhdFilterBar(
      children: [
        for (final g in _grupos)
          PhdFilterChip(
            label: g,
            selected: _grupo == g,
            onTap: () {
              if (_grupo == g) return;
              setState(() => _grupo = g);
              _buscar();
            },
          ),
      ],
    );
  }

  Widget _corpo(ScrollController scroll) {
    if (_carregando && _resultados.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
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
        message: 'Tente uma palavra mais curta — "frang" acha '
            '"Peito de frango grelhado".',
      );
    }

    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge,
      ),
      itemCount: _resultados.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _linha(_resultados[i]),
    );
  }

  Widget _linha(Alimento a) {
    return PhdCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md,
      ),
      onTap: () => _definirQuantidade(a),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.rotulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong(14),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${a.kcal.round()} kcal',
                style: AppText.number(13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'por 100 g · P ${_g(a.proteina)} · C ${_g(a.carboidrato)} · '
            'G ${_g(a.gordura)}',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
          if (_procedencia(a) != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _procedencia(a)!,
          ],
        ],
      ),
    );
  }

  /// Mostra de onde vem o dado nutricional.
  ///
  /// Tabela conferida não precisa de aviso. O que precisa é o contrário: um
  /// valor aproximado usado numa prescrição, sem o profissional saber que
  /// era aproximado.
  Widget? _procedencia(Alimento a) {
    return switch (a.fonte) {
      'seed_inicial' => const PhdStatusChip(
          label: 'valor aproximado',
          tone: PhdTone.warning,
        ),
      'profissional' => const PhdStatusChip(label: 'seu cadastro'),
      'taco' => null,
      _ => null,
    };
  }

  Future<void> _definirQuantidade(Alimento a) async {
    final escolha = await showModalBottomSheet<AlimentoEscolhido>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuantidadeSheet(alimento: a),
    );
    if (escolha != null && mounted) Navigator.pop(context, escolha);
  }
}

/// Segunda etapa: quanto desse alimento.
///
/// É um StatefulWidget próprio para o controlador ter dispose. Num diálogo
/// montado dentro de um builder, o controlador criado na função vaza a cada
/// abertura.
class _QuantidadeSheet extends StatefulWidget {
  const _QuantidadeSheet({required this.alimento});

  final Alimento alimento;

  @override
  State<_QuantidadeSheet> createState() => _QuantidadeSheetState();
}

class _QuantidadeSheetState extends State<_QuantidadeSheet> {
  late final TextEditingController _ctrl;

  /// `true` = a pessoa digita medidas caseiras; `false` = gramas.
  /// Começa em medidas quando o alimento tem uma cadastrada, porque é assim
  /// que o nutricionista prescreve na consulta.
  late bool _porMedida = widget.alimento.medidaGramas != null;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _porMedida ? '1' : '100');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _quantidade {
    final t = _ctrl.text.trim().replaceAll(',', '.');
    return double.tryParse(t) ?? 0;
  }

  /// Gramas efetivas, que é o que vai para o banco e para o cálculo.
  double get _gramas {
    if (!_porMedida) return _quantidade;
    return widget.alimento.gramasDeMedidas(_quantidade) ?? _quantidade;
  }

  /// Texto que o aluno lê. Em gramas puro não vale a pena guardar: o app já
  /// mostra as gramas de qualquer forma, e repetir viraria "100 g · 100 g".
  String? get _medidaExibicao {
    if (!_porMedida) return null;
    final medida = widget.alimento.medidaCaseira?.trim();
    if (medida == null || medida.isEmpty) return null;
    final q = _quantidade;
    final qTexto = q == q.truncateToDouble()
        ? q.toStringAsFixed(0)
        : q.toStringAsFixed(1);
    return '$qTexto × $medida';
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alimento;
    final n = a.paraGramas(_gramas);
    final fundoTeclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: fundoTeclado),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.rotulo, style: AppText.title(17)),
              const SizedBox(height: AppSpacing.lg),
              if (a.medidaGramas != null) _alternador(a),
              const SizedBox(height: AppSpacing.lg),
              PhdField(
                label: _porMedida ? 'Quantas medidas' : 'Gramas',
                controller: _ctrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                ajuda: _porMedida && a.medidaCaseira != null
                    ? '1 × ${a.medidaCaseira} = ${a.medidaGramas!.round()} g'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.lg),
              _previa(n),
              const SizedBox(height: AppSpacing.xl),
              PhdButton(
                label: 'Adicionar',
                icon: Icons.add_rounded,
                // Quantidade zero não é prescrição. Desligar o botão explica
                // melhor que aceitar e gravar uma linha de 0 g.
                onPressed: _gramas <= 0
                    ? null
                    : () => Navigator.pop(context, (
                          alimento: a,
                          gramas: _gramas,
                          medidaExibicao: _medidaExibicao,
                        )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alternador(Alimento a) => PhdFilterBar(
        children: [
          PhdFilterChip(
            label: 'Medida caseira',
            selected: _porMedida,
            onTap: () {
              if (_porMedida) return;
              setState(() {
                _porMedida = true;
                _ctrl.text = '1';
              });
            },
          ),
          PhdFilterChip(
            label: 'Gramas',
            selected: !_porMedida,
            onTap: () {
              if (!_porMedida) return;
              setState(() {
                // Mantém a quantidade que a pessoa já tinha escolhido em vez
                // de voltar para 100: ela converteu de propósito.
                final g = _gramas;
                _porMedida = false;
                _ctrl.text = g > 0 ? g.round().toString() : '100';
              });
            },
          ),
        ],
      );

  Widget _previa(
    ({double kcal, double proteina, double carboidrato, double gordura, double fibra}) n,
  ) {
    return PhdCard(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _gramas <= 0 ? '—' : '${_gramas.round()} g',
                style: AppText.bodyStrong(13.5),
              ),
              Text(
                '${n.kcal.round()} kcal',
                style: AppText.number(17, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'P ${_g(n.proteina)} · C ${_g(n.carboidrato)} · G ${_g(n.gordura)}'
            '${n.fibra > 0 ? ' · Fibra ${_g(n.fibra)}' : ''}',
            style: AppText.caption(12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Gramas sem decimal inútil: "28 g" em vez de "28.0 g".
String _g(double v) {
  if (v >= 10 || v == v.truncateToDouble()) return '${v.round()} g';
  return '${v.toStringAsFixed(1)} g';
}
