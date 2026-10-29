import 'package:flutter/material.dart';
import '../../../core/models/dieta.dart';
import '../../../core/services/avaliacao_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dieta_calculos.dart';
import '../../../core/widgets/widgets.dart';

/// Define as metas do plano: TMB, gasto total, calorias e macros.
///
/// As metas ficam gravadas no plano já calculadas, com o nome da fórmula.
/// Se amanhã o app mudar de fórmula, o plano de hoje continua dizendo o que
/// dizia hoje — e o nutricionista tem como defender o que prescreveu.
class PlanoMetasScreen extends StatefulWidget {
  const PlanoMetasScreen({
    super.key,
    required this.aluno,
    this.plano,
  });

  final Map<String, dynamic> aluno;

  /// Quando vem preenchido, a tela edita as metas desse plano em vez de
  /// criar um novo.
  final PlanoAlimentar? plano;

  @override
  State<PlanoMetasScreen> createState() => _PlanoMetasScreenState();
}

class _PlanoMetasScreenState extends State<PlanoMetasScreen> {
  final _nome = TextEditingController();
  final _peso = TextEditingController();
  final _altura = TextEditingController();
  final _gordura = TextEditingController();
  final _idade = TextEditingController();
  final _proteinaPorKg = TextEditingController(text: '1.8');
  final _gorduraPorKg = TextEditingController(text: '0.9');

  late Sexo _sexo;
  FormulaTmb _formula = FormulaTmb.mifflin;
  NivelAtividade _nivel = NivelAtividade.moderado;
  ObjetivoDieta _objetivo = ObjetivoDieta.manutencao;

  bool _salvando = false;
  bool _buscandoAvaliacao = true;

  @override
  void initState() {
    super.initState();

    // Gênero e idade saem do cadastro: são dados que o personal já digitou,
    // e pedir de novo é onde aparece divergência entre as duas telas.
    _sexo = _sexoDoCadastro();
    final idade = idadeEm(_dataNascimento());
    if (idade != null) _idade.text = idade.toString();

    final p = widget.plano;
    if (p != null) {
      _nome.text = p.nome;
      _objetivo = p.objetivoEnum;
      if (p.fatorAtividade != null) {
        _nivel = NivelAtividade.values.firstWhere(
          (n) => (n.fator - p.fatorAtividade!).abs() < 0.001,
          orElse: () => NivelAtividade.moderado,
        );
      }
      _formula = FormulaTmb.values.firstWhere(
        (f) => f.nome == p.formulaTmb,
        orElse: () => FormulaTmb.mifflin,
      );
    } else {
      _nome.text = 'Plano alimentar';
    }

    _preencherDaAvaliacao();
  }

  @override
  void dispose() {
    _nome.dispose();
    _peso.dispose();
    _altura.dispose();
    _gordura.dispose();
    _idade.dispose();
    _proteinaPorKg.dispose();
    _gorduraPorKg.dispose();
    super.dispose();
  }

  Sexo _sexoDoCadastro() {
    final g = (widget.aluno['genero'] as String?)?.trim().toLowerCase() ?? '';
    return g.startsWith('f') ? Sexo.feminino : Sexo.masculino;
  }

  DateTime? _dataNascimento() {
    final v = widget.aluno['data_nascimento'];
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }

  /// Puxa peso e percentual de gordura da avaliação mais recente.
  ///
  /// Digitar o peso de novo aqui seria pedir um dado que o app já tem — e
  /// abriria espaço para a dieta ser calculada sobre um peso diferente do
  /// que está na avaliação.
  Future<void> _preencherDaAvaliacao() async {
    try {
      final sessoes = await AvaliacaoService.listar(
        widget.aluno['id'].toString(),
      );
      final comPeso = sessoes.where((s) => s.peso != null);
      if (comPeso.isNotEmpty && mounted) {
        final ultima = comPeso.first;
        setState(() {
          if (_peso.text.isEmpty) _peso.text = _texto(ultima.peso);
          if (_gordura.text.isEmpty && ultima.percGordura != null) {
            _gordura.text = _texto(ultima.percGordura);
          }
        });
      }
    } catch (_) {
      // Sem avaliação a tela segue: os campos ficam em branco para digitar.
    } finally {
      if (mounted) setState(() => _buscandoAvaliacao = false);
    }
  }

  // ── Cálculo ao vivo ─────────────────────────────────────────

  double? get _pesoKg => _lerNumero(_peso);
  double? get _alturaCm => _lerNumero(_altura);
  double? get _percGordura => _lerNumero(_gordura);
  int? get _idadeAnos => _lerNumero(_idade)?.round();

  double? get _tmb => tmb(
        formula: _formula,
        sexo: _sexo,
        pesoKg: _pesoKg,
        alturaCm: _alturaCm,
        idade: _idadeAnos,
        percentualGordura: _percGordura,
      );

  double? get _getTotal => get(_tmb, _nivel);
  double? get _metaKcal => metaCalorica(_getTotal, _objetivo);

  ({double proteina, double carboidrato, double gordura})? get _macros => macros(
        metaKcal: _metaKcal,
        pesoKg: _pesoKg,
        proteinaPorKg: _lerNumero(_proteinaPorKg) ?? 1.8,
        gorduraPorKg: _lerNumero(_gorduraPorKg) ?? 0.9,
      );

  @override
  Widget build(BuildContext context) {
    final editando = widget.plano != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          editando ? 'Metas do plano' : 'Novo plano alimentar',
          style: AppText.title(16),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge * 2,
        ),
        children: [
          if (!editando) ...[
            PhdField(
              label: 'Nome do plano',
              controller: _nome,
              hint: 'Plano de março · cutting',
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          const PhdSectionHeader(label: 'Dados do aluno'),
          const SizedBox(height: AppSpacing.md),
          if (_buscandoAvaliacao)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                'Buscando a última avaliação...',
                style: AppText.caption(11.5, color: AppColors.textMuted),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: PhdField(
                  label: 'Peso (kg)',
                  controller: _peso,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PhdField(
                  label: 'Altura (cm)',
                  controller: _altura,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PhdField(
                  label: 'Idade',
                  controller: _idade,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PhdField(
                  label: '% de gordura',
                  controller: _gordura,
                  hint: 'opcional',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  ajuda: _formula == FormulaTmb.cunningham
                      ? 'Cunningham exige este dado'
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Sexo biológico', style: AppText.caption(12.5)),
          const SizedBox(height: 7),
          PhdFilterBar(
            children: [
              for (final s in Sexo.values)
                PhdFilterChip(
                  label: s == Sexo.masculino ? 'Masculino' : 'Feminino',
                  selected: _sexo == s,
                  onTap: () => setState(() => _sexo = s),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          const PhdSectionHeader(label: 'Fórmula'),
          const SizedBox(height: AppSpacing.md),
          for (final f in FormulaTmb.values) _opcaoFormula(f),

          const SizedBox(height: AppSpacing.xl),
          const PhdSectionHeader(label: 'Nível de atividade'),
          const SizedBox(height: AppSpacing.md),
          for (final n in NivelAtividade.values) _opcaoNivel(n),

          const SizedBox(height: AppSpacing.xl),
          const PhdSectionHeader(label: 'Objetivo'),
          const SizedBox(height: AppSpacing.md),
          PhdFilterBar(
            children: [
              for (final o in ObjetivoDieta.values)
                PhdFilterChip(
                  label: o.nome,
                  selected: _objetivo == o,
                  onTap: () => setState(() => _objetivo = o),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          const PhdSectionHeader(label: 'Macros por quilo'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: PhdField(
                  label: 'Proteína g/kg',
                  controller: _proteinaPorKg,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: PhdField(
                  label: 'Gordura g/kg',
                  controller: _gorduraPorKg,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'O carboidrato recebe as calorias que sobram. É o macro de '
            'ajuste: proteína e gordura têm mínimos que não convém cortar.',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),

          const SizedBox(height: AppSpacing.xl),
          _resultado(),

          const SizedBox(height: AppSpacing.xl),
          PhdButton(
            label: editando ? 'Salvar metas' : 'Criar plano',
            icon: editando ? Icons.check_rounded : Icons.arrow_forward_rounded,
            loading: _salvando,
            onPressed: _metaKcal == null ? null : _salvar,
          ),
          if (_metaKcal == null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _faltando(),
              textAlign: TextAlign.center,
              style: AppText.caption(11.5, color: AppColors.warningText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _opcaoFormula(FormulaTmb f) {
    final ativa = _formula == f;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PhdCard(
        accentBar: ativa ? AppColors.accent : null,
        onTap: () => setState(() => _formula = f),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              ativa
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: ativa ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.nome, style: AppText.bodyStrong(13.5)),
                  const SizedBox(height: 2),
                  Text(
                    f.fonte,
                    style: AppText.caption(11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcaoNivel(NivelAtividade n) {
    final ativa = _nivel == n;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PhdCard(
        accentBar: ativa ? AppColors.accent : null,
        onTap: () => setState(() => _nivel = n),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              ativa
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: ativa ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.nome, style: AppText.bodyStrong(13.5)),
                  const SizedBox(height: 2),
                  Text(
                    n.descricao,
                    style: AppText.caption(11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Text(
              '×${n.fator}',
              style: AppText.number(12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultado() {
    final t = _tmb;
    final g = _getTotal;
    final meta = _metaKcal;
    final m = _macros;
    final agua = aguaMl(_pesoKg);

    final dist = m == null
        ? null
        : distribuicao(
            proteinaG: m.proteina,
            carboidratoG: m.carboidrato,
            gorduraG: m.gordura,
          );

    return PhdCard(
      color: AppColors.surfaceHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resultado', style: AppText.label()),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PhdStat(
                  label: 'TMB',
                  value: t == null ? '—' : '${t.round()}',
                  valueSize: 22,
                  valueColor: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: 'Gasto total',
                  value: g == null ? '—' : '${g.round()}',
                  valueSize: 22,
                  valueColor: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: 'Meta',
                  value: meta == null ? '—' : '${meta.round()}',
                  valueSize: 26,
                ),
              ),
            ],
          ),
          if (m != null && dist != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Divider(color: AppColors.line, height: 1),
            const SizedBox(height: AppSpacing.lg),
            _linhaMacro('Proteína', m.proteina, dist.proteina),
            const SizedBox(height: AppSpacing.sm),
            _linhaMacro('Carboidrato', m.carboidrato, dist.carboidrato),
            const SizedBox(height: AppSpacing.sm),
            _linhaMacro('Gordura', m.gordura, dist.gordura),
          ],
          if (agua != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Água sugerida: ${(agua / 1000).toStringAsFixed(1)} L por dia '
              '(35 ml/kg)',
              style: AppText.caption(11.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _linhaMacro(String nome, double gramas, int percentual) {
    return Row(
      children: [
        Expanded(child: Text(nome, style: AppText.body(13.5))),
        Text(
          '${gramas.round()} g',
          style: AppText.number(13.5),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 44,
          child: Text(
            '$percentual%',
            textAlign: TextAlign.right,
            style: AppText.caption(12, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }

  /// Diz exatamente qual dado falta, em vez de só desligar o botão.
  String _faltando() {
    if (_pesoKg == null) return 'Informe o peso para calcular as metas.';
    if (_formula == FormulaTmb.cunningham && _percGordura == null) {
      return 'A fórmula de Cunningham usa massa magra: informe o percentual '
          'de gordura ou troque de fórmula.';
    }
    if (_alturaCm == null) return 'Informe a altura.';
    if (_idadeAnos == null) return 'Informe a idade.';
    if (_macros == null) {
      return 'A meta calórica não cobre a proteína e a gordura pedidas. '
          'Reduza g/kg ou revise o objetivo.';
    }
    return 'Faltam dados para calcular.';
  }

  // ── Gravação ────────────────────────────────────────────────

  Map<String, dynamic> _metas() {
    final m = _macros;
    return {
      'objetivo': _objetivo.name,
      'formula_tmb': _formula.nome,
      'tmb': _tmb,
      'fator_atividade': _nivel.fator,
      'get': _getTotal,
      'meta_kcal': _metaKcal,
      'meta_proteina': m?.proteina,
      'meta_carboidrato': m?.carboidrato,
      'meta_gordura': m?.gordura,
      'agua_ml': aguaMl(_pesoKg),
    };
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      // A tela só devolve o que foi calculado. Quem grava é quem chamou:
      // criar plano e editar metas são escritas diferentes, e decidir aqui
      // qual é faria esta tela conhecer o fluxo das outras duas.
      if (!mounted) return;
      Navigator.pop(context, (nome: _nome.text.trim(), metas: _metas()));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  double? _lerNumero(TextEditingController c) {
    final t = c.text.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    if (v == null || v <= 0) return null;
    return v;
  }

  String _texto(double? v) {
    if (v == null) return '';
    return v == v.truncateToDouble()
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
  }
}

/// O que a tela de metas devolve.
typedef MetasDefinidas = ({String nome, Map<String, dynamic> metas});
