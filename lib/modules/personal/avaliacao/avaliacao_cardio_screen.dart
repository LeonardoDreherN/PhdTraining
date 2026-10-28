import 'package:flutter/material.dart';
import '../../../core/models/avaliacao.dart';
import '../../../core/services/avaliacao_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/avaliacao_calculos.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';
import 'avaliacao_widgets.dart';

/// Teste cardiorrespiratório da sessão: escolhe o protocolo, digita o que
/// o teste mede e o VO₂máx sai na hora, já classificado.
class AvaliacaoCardioScreen extends StatefulWidget {
  const AvaliacaoCardioScreen({super.key, required this.aluno});

  final Map<String, dynamic> aluno;

  @override
  State<AvaliacaoCardioScreen> createState() => _AvaliacaoCardioScreenState();
}

class _AvaliacaoCardioScreenState extends State<AvaliacaoCardioScreen> {
  late final DateTime _data = dataDaSessao(widget.aluno);
  String get _alunoId => widget.aluno['id'] as String;

  AvaliacaoCompleta? _av;
  List<Map<String, dynamic>> _historico = [];
  bool _carregando = true;
  bool _salvando = false;
  String? _erro;

  ProtocoloCardio _protocolo = ProtocoloCardio.todos.first;
  final _distancia = TextEditingController();
  final _minutos = TextEditingController();
  final _segundos = TextEditingController();
  final _fc = TextEditingController();
  final _peso = TextEditingController();
  final _obs = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    for (final c in [_distancia, _minutos, _segundos, _fc, _peso, _obs]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final r = await Future.wait([
        AvaliacaoService.carregar(widget.aluno, _data),
        AvaliacaoService.historicoCardio(_alunoId),
      ]);
      if (!mounted) return;
      setState(() {
        _av = r[0] as AvaliacaoCompleta;
        _historico = r[1] as List<Map<String, dynamic>>;
        if (_peso.text.isEmpty && _av!.peso != null) _peso.text = numBr(_av!.peso, casas: 2);
        // Abre no protocolo que já foi feito hoje, se houver: o personal
        // normalmente volta aqui para corrigir, não para fazer outro.
        final hoje = _av!.cardio;
        if (hoje.isNotEmpty) _preencher(hoje.first);
      });
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _preencher(Map<String, dynamic> linha) {
    _protocolo = ProtocoloCardio.porId(linha['protocolo'] as String?) ?? _protocolo;
    final d = (linha['distancia_m'] as num?)?.toDouble();
    _distancia.text = d == null ? '' : numBr(d, casas: 0);
    final t = (linha['tempo_seg'] as num?)?.toInt();
    _minutos.text = t == null ? '' : '${t ~/ 60}';
    _segundos.text = t == null ? '' : '${t % 60}';
    final fc = (linha['fc_final'] as num?)?.toInt();
    _fc.text = fc?.toString() ?? '';
    final p = (linha['peso'] as num?)?.toDouble();
    if (p != null) _peso.text = numBr(p, casas: 2);
    _obs.text = linha['observacoes'] as String? ?? '';
  }

  double? _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  int? get _tempoSeg {
    final m = int.tryParse(_minutos.text.trim());
    final s = int.tryParse(_segundos.text.trim());
    if (m == null && s == null) return null;
    return (m ?? 0) * 60 + (s ?? 0);
  }

  EntradaCardio? get _entrada {
    final av = _av;
    if (av == null) return null;
    return EntradaCardio(
      masculino: av.masculino,
      idade: av.idade,
      pesoKg: _num(_peso),
      distanciaM: _num(_distancia),
      tempoSeg: _tempoSeg,
      fcFinal: _num(_fc)?.round(),
    );
  }

  double? get _vo2 => _entrada == null ? null : _protocolo.vo2max(_entrada!);

  Classificacao? get _classe =>
      classificarVo2(_vo2, masculino: _av?.masculino ?? true, idade: _av?.idade);

  Future<void> _salvar() async {
    final vo2 = _vo2;
    final e = _entrada;
    if (vo2 == null || e == null) return;
    setState(() => _salvando = true);
    try {
      await AvaliacaoService.salvarCardio({
        'aluno_id': _alunoId,
        'data_avaliacao': Datas.iso(_data),
        'protocolo': _protocolo.id,
        'genero': _av!.genero,
        'idade': e.idade,
        'peso': _protocolo.campos.contains(CampoCardio.peso) ? e.pesoKg : null,
        'distancia_m': _protocolo.campos.contains(CampoCardio.distancia) ? e.distanciaM : null,
        'tempo_seg': _protocolo.campos.contains(CampoCardio.tempo) ? e.tempoSeg : null,
        'fc_final': _protocolo.campos.contains(CampoCardio.fcFinal) ? e.fcFinal : null,
        'vo2max': double.parse(vo2.toStringAsFixed(1)),
        'classificacao': _classe?.rotulo,
        'observacoes': _obs.text.trim().isEmpty ? null : _obs.text.trim(),
      });
      if (!mounted) return;
      avisar(context, 'Teste salvo');
      Navigator.pop(context);
    } catch (err) {
      if (mounted) avisar(context, 'Não salvou: $err', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluir(Map<String, dynamic> linha) async {
    try {
      await AvaliacaoService.excluirCardio(linha['id'] as String);
      _carregar();
    } catch (e) {
      if (mounted) avisar(context, 'Não excluiu: $e', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: appBarAvaliacao(
          widget.aluno['nome'] as String? ?? 'Aluno', 'Cardio · ${Datas.curta(_data)}'),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _av == null
              ? PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não deu para abrir',
                  message: _erro ?? '',
                  actionLabel: 'Tentar de novo',
                  onAction: _carregar,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
                  children: [
                    const PhdSectionHeader(label: 'Protocolo'),
                    const SizedBox(height: AppSpacing.md),
                    // A barra já traz o respiro lateral da tela; o
                    // OverflowBox a deixa encostar nas bordas para rolar
                    // de ponta a ponta, como nas outras listas do app.
                    LayoutBuilder(
                      builder: (context, c) => SizedBox(
                        height: 38,
                        child: OverflowBox(
                          maxWidth: c.maxWidth + AppSpacing.xl * 2,
                          child: PhdFilterBar(children: [
                            for (final p in ProtocoloCardio.todos)
                              PhdFilterChip(
                                label: p.nomeCurto,
                                selected: p.id == _protocolo.id,
                                onTap: () => setState(() => _protocolo = p),
                              ),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PhdCard(
                      color: AppColors.surfaceHigh,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_protocolo.nome, style: AppText.bodyStrong(14.5)),
                          const SizedBox(height: 4),
                          Text(_protocolo.instrucao, style: AppText.body(13.5)),
                          const SizedBox(height: 6),
                          Text(_protocolo.referencia,
                              style: AppText.caption(11.5, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    if (_av!.idade == null) ...[
                      const SizedBox(height: AppSpacing.md),
                      const PhdAviso(
                        texto: 'O aluno está sem data de nascimento no cadastro. A '
                            'classificação usa a faixa de 30 a 39 anos, e o Rockport '
                            'não calcula sem idade.',
                        icone: Icons.info_outline_rounded,
                        cor: AppColors.warning,
                        corTexto: AppColors.warningText,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const PhdSectionHeader(label: 'Resultado do teste'),
                    const SizedBox(height: AppSpacing.md),
                    ..._campos(),
                    const SizedBox(height: AppSpacing.lg),
                    _resultado(),
                    const SizedBox(height: AppSpacing.lg),
                    PhdField(
                      label: 'Observações (opcional)',
                      controller: _obs,
                      hint: 'Condições do teste, como o aluno se sentiu…',
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PhdButton(
                      label: _av!.cardio.any((c) => c['protocolo'] == _protocolo.id)
                          ? 'Atualizar teste'
                          : 'Salvar teste',
                      loading: _salvando,
                      onPressed: _vo2 == null || _salvando ? null : _salvar,
                    ),
                    if (_historico.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.huge),
                      PhdSectionHeader(label: 'Histórico', trailing: '${_historico.length}'),
                      const SizedBox(height: AppSpacing.md),
                      for (final h in _historico) ...[
                        _linhaHistorico(h),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ],
                ),
    );
  }

  List<Widget> _campos() {
    void mudou(String _) => setState(() {});
    final campos = _protocolo.campos;
    return [
      if (campos.contains(CampoCardio.distancia)) ...[
        PhdField(
          label: 'Distância percorrida (metros)',
          controller: _distancia,
          hint: 'Ex.: 2400',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: mudou,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (campos.contains(CampoCardio.tempo)) ...[
        Row(
          children: [
            Expanded(
              child: PhdField(
                label: 'Tempo — minutos',
                controller: _minutos,
                hint: '0',
                keyboardType: TextInputType.number,
                onChanged: mudou,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: PhdField(
                label: 'segundos',
                controller: _segundos,
                hint: '0',
                keyboardType: TextInputType.number,
                onChanged: mudou,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (campos.contains(CampoCardio.fcFinal)) ...[
        PhdField(
          label: _protocolo.id == 'banco_queens'
              ? 'FC de recuperação (bpm, 15 s × 4)'
              : 'FC ao terminar (bpm)',
          controller: _fc,
          hint: 'Ex.: 150',
          keyboardType: TextInputType.number,
          onChanged: mudou,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
      if (campos.contains(CampoCardio.peso)) ...[
        PhdField(
          label: 'Peso (kg)',
          controller: _peso,
          ajuda: _av!.peso != null ? 'Veio da avaliação de hoje' : null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: mudou,
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }

  Widget _resultado() {
    final vo2 = _vo2;
    final c = _classe;
    return PhdCard(
      accentBar: c?.nivel.tom.solid,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VO₂MÁX ESTIMADO', style: AppText.label()),
                const SizedBox(height: 6),
                vo2 == null
                    ? Text('Preencha os campos acima', style: AppText.caption(13, color: AppColors.textMuted))
                    : Text.rich(TextSpan(children: [
                        TextSpan(text: numBr(vo2), style: AppText.number(32, weight: FontWeight.w800)),
                        TextSpan(text: '  ml/kg/min', style: AppText.caption(13)),
                      ])),
              ],
            ),
          ),
          if (c != null) PhdStatusChip(label: c.rotulo, tone: c.nivel.tom),
        ],
      ),
    );
  }

  Widget _linhaHistorico(Map<String, dynamic> h) {
    final data = Datas.ler(h['data_avaliacao']);
    final ehHoje = data != null && Datas.dia(data) == Datas.dia(_data);
    final nome = ProtocoloCardio.porId(h['protocolo'] as String?)?.nome ?? h['protocolo'] as String? ?? '';
    return PhdListRow(
      title: nome,
      subtitle: [
        if (data != null) Datas.curta(data),
        if (h['classificacao'] != null) h['classificacao'] as String,
      ].join(' · '),
      trailingValue: numBr((h['vo2max'] as num?)?.toDouble()),
      trailingLabel: 'ml/kg/min',
      accentBar: ehHoje ? AppColors.accent : null,
      onTap: ehHoje
          ? () => showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.surface,
                builder: (ctx) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_outlined, color: AppColors.textPrimary),
                        title: Text('Editar', style: AppText.body(14)),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _preencher(h));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerText),
                        title: Text('Excluir', style: AppText.body(14, color: AppColors.dangerText)),
                        onTap: () {
                          Navigator.pop(ctx);
                          _excluir(h);
                        },
                      ),
                    ],
                  ),
                ),
              )
          : null,
    );
  }
}
