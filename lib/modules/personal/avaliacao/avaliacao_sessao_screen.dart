import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/avaliacao.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/avaliacao_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/avaliacao_calculos.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';
import 'avaliacao_pdf.dart';
import 'avaliacao_resumo.dart';
import 'avaliacao_widgets.dart';

/// Uma avaliação: tudo o que foi medido no mesmo dia, os índices que saem
/// disso, a comparação com a anterior e o relatório.
///
/// Recebe o aluno já com a data da sessão (`alunoNaSessao`). Esse mesmo
/// mapa é repassado aos testes, que assim nascem neste dia.
class AvaliacaoSessaoScreen extends ConsumerStatefulWidget {
  const AvaliacaoSessaoScreen({super.key, required this.aluno});

  final Map<String, dynamic> aluno;

  @override
  ConsumerState<AvaliacaoSessaoScreen> createState() => _AvaliacaoSessaoScreenState();
}

class _AvaliacaoSessaoScreenState extends ConsumerState<AvaliacaoSessaoScreen> {
  AvaliacaoCompleta? _av;
  bool _carregando = true;
  bool _gerandoPdf = false;
  String? _erro;
  final _obsCtrl = TextEditingController();
  bool _obsAlterada = false;

  late final DateTime _data = dataDaSessao(widget.aluno);
  String get _alunoId => widget.aluno['id'] as String;
  String get _nome => widget.aluno['nome'] as String? ?? 'Aluno';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final av = await AvaliacaoService.carregar(widget.aluno, _data);
      if (!mounted) return;
      setState(() {
        _av = av;
        if (!_obsAlterada) _obsCtrl.text = av.sessao.observacoes ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvarCampos(Map<String, dynamic> campos) async {
    try {
      await AvaliacaoService.atualizar(_alunoId, _data, campos);
      await _carregar();
    } catch (e) {
      if (mounted) avisar(context, 'Não salvou: $e', erro: true);
    }
  }

  Future<void> _editar(String coluna, String titulo, String unidade, num? atual,
      {bool decimal = true, String? ajuda}) async {
    final r = await editarNumero(context,
        titulo: titulo, unidade: unidade, atual: atual, decimal: decimal, ajuda: ajuda);
    if (r == null) return;
    final v = r.valor;
    await _salvarCampos({coluna: decimal ? v : v?.round()});
  }

  Future<void> _editarPressao() async {
    final s = _av!.sessao;
    final sis = await editarNumero(context,
        titulo: 'Pressão sistólica (máxima)', unidade: 'mmHg', atual: s.paSistolica, decimal: false,
        ajuda: 'O número de cima. Ex.: 12 por 8 é 120.');
    if (sis == null || !mounted) return;
    if (sis.valor == null) {
      await _salvarCampos({'pa_sistolica': null, 'pa_diastolica': null});
      return;
    }
    final dia = await editarNumero(context,
        titulo: 'Pressão diastólica (mínima)', unidade: 'mmHg', atual: s.paDiastolica, decimal: false,
        ajuda: 'O número de baixo. Ex.: 12 por 8 é 80.');
    if (dia == null) return;
    await _salvarCampos({
      'pa_sistolica': sis.valor!.round(),
      'pa_diastolica': dia.valor?.round(),
    });
  }

  Future<void> _escolherProxima() async {
    final atual = _av!.sessao.proximaAvaliacao;
    final escolhida = await showDatePicker(
      context: context,
      initialDate: atual ?? _data.add(const Duration(days: 90)),
      firstDate: _data,
      lastDate: _data.add(const Duration(days: 730)),
      helpText: 'Próxima avaliação',
    );
    if (escolhida != null) await _salvarCampos({'proxima_avaliacao': Datas.iso(escolhida)});
  }

  Future<void> _salvarObs() async {
    await _salvarCampos({'observacoes': _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim()});
    if (mounted) {
      setState(() => _obsAlterada = false);
      avisar(context, 'Observações salvas');
    }
  }

  Future<void> _abrirTeste(String rota) async {
    await context.push(rota, extra: widget.aluno);
    _carregar();
  }

  Future<void> _gerarPdf() async {
    final av = _av;
    if (av == null) return;
    setState(() => _gerandoPdf = true);
    try {
      final perfil = await ref.read(perfilProvider.future);
      await AvaliacaoPdf.compartilhar(av, perfil);
    } catch (e) {
      if (mounted) avisar(context, 'Não foi possível gerar o PDF: $e', erro: true);
    } finally {
      if (mounted) setState(() => _gerandoPdf = false);
    }
  }

  Future<void> _excluir() async {
    final av = _av;
    if (av == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Excluir a avaliação de ${Datas.curta(_data)}?', style: AppText.title(17)),
        content: Text(
          av.totalTestes == 0
              ? 'Ela ainda não tem testes.'
              : 'Os ${av.totalTestes} testes deste dia também serão apagados, '
                  'inclusive as fotos posturais. Não dá para desfazer.',
          style: AppText.body(14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: AppText.bodyStrong(14, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AvaliacaoService.excluir(_alunoId, _data);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) avisar(context, 'Não excluiu: $e', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final av = _av;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: appBarAvaliacao(_nome, 'Avaliação de ${Datas.curta(_data)}', actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
          color: AppColors.surfaceHigh,
          onSelected: (v) {
            if (v == 'excluir') _excluir();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'excluir',
              child: Text('Excluir avaliação', style: AppText.body(14, color: AppColors.dangerText)),
            ),
          ],
        ),
      ]),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : av == null
              ? PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não deu para abrir',
                  message: _erro ?? 'Erro desconhecido',
                  actionLabel: 'Tentar de novo',
                  onAction: _carregar,
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  color: AppColors.accent,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
                    children: [
                      if (av.sexoIndefinido) ...[
                        const PhdAviso(
                          texto: 'O cadastro do aluno não diz se é masculino ou feminino. '
                              'Os índices estão usando os valores de referência masculinos.',
                          icone: Icons.info_outline_rounded,
                          cor: AppColors.warning,
                          corTexto: AppColors.warningText,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _secao('Medidas'),
                      _medidas(av),
                      const SizedBox(height: AppSpacing.xxl),
                      _secao('Sinais vitais'),
                      _vitais(av),
                      const SizedBox(height: AppSpacing.xxl),
                      _secao('Índices'),
                      _indices(av),
                      const SizedBox(height: AppSpacing.xxl),
                      _secao('Testes do dia', trailing: '${av.totalTestes}'),
                      _testes(av),
                      const SizedBox(height: AppSpacing.xxl),
                      _secao('Capacidade cardiorrespiratória'),
                      _cardio(av),
                      if (comparacao(av) case final linhas when linhas.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxl),
                        _secao('Desde ${Datas.curta(av.anterior!.data)}'),
                        _comparacao(linhas),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      _secao('Fechamento'),
                      _fechamento(av),
                      const SizedBox(height: AppSpacing.xxl),
                      PhdButton(
                        label: 'Gerar relatório em PDF',
                        icon: Icons.picture_as_pdf_outlined,
                        loading: _gerandoPdf,
                        onPressed: _gerandoPdf ? null : _gerarPdf,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Com a sua marca, para enviar ao aluno.',
                        textAlign: TextAlign.center,
                        style: AppText.caption(12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _secao(String rotulo, {String? trailing}) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: PhdSectionHeader(label: rotulo, trailing: trailing, trailingColor: AppColors.textMuted),
      );

  Widget _cartaoDeLinhas(List<Widget> linhas) => PhdCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, l) in linhas.indexed) ...[
              if (i > 0) const Divider(height: 1, thickness: 0.5, color: AppColors.line, indent: AppSpacing.lg),
              l,
            ],
          ],
        ),
      );

  /// De onde veio um valor que não foi digitado nesta sessão.
  String? _origem(Object? daSessao, Object? daDobra, Object? daBio, {bool anterior = false}) {
    if (daSessao != null) return null;
    if (daDobra != null) return 'da dobra cutânea';
    if (daBio != null) return 'da bioimpedância';
    if (anterior) return 'da avaliação anterior';
    return null;
  }

  Widget _medidas(AvaliacaoCompleta av) {
    final s = av.sessao;
    String v(double? x, String u) => x == null ? 'Medir' : '${numBr(x)} $u';
    return _cartaoDeLinhas([
      LinhaMedida(
        rotulo: 'Peso',
        valor: v(av.peso, 'kg'),
        origem: _origem(s.peso, av.dobras?['peso'], av.bioimpedancia?['peso']),
        onTap: () => _editar('peso', 'Peso', 'kg', av.peso),
      ),
      LinhaMedida(
        rotulo: 'Estatura',
        valor: v(av.estatura, 'cm'),
        origem: _origem(s.estatura, av.dobras?['estatura'], av.bioimpedancia?['estatura'],
            anterior: av.estatura != null),
        onTap: () => _editar('estatura', 'Estatura', 'cm', av.estatura, ajuda: 'Em centímetros. Ex.: 172'),
      ),
      LinhaMedida(
        rotulo: 'Cintura',
        valor: v(av.cintura, 'cm'),
        origem: _origem(s.cintura, av.dobras?['cintura'], av.bioimpedancia?['cintura']),
        onTap: () => _editar('cintura', 'Cintura', 'cm', av.cintura,
            ajuda: 'No ponto médio entre a última costela e a crista ilíaca.'),
      ),
      LinhaMedida(
        rotulo: 'Quadril',
        valor: v(av.quadril, 'cm'),
        origem: _origem(s.quadril, av.dobras?['quadril'], av.bioimpedancia?['quadril']),
        onTap: () => _editar('quadril', 'Quadril', 'cm', av.quadril,
            ajuda: 'Na maior circunferência dos glúteos.'),
      ),
    ]);
  }

  Widget _vitais(AvaliacaoCompleta av) {
    final s = av.sessao;
    final pa = av.pressao;
    final fc = Cardiaco.fcRepouso(s.fcRepouso);
    return Column(
      children: [
        _cartaoDeLinhas([
          LinhaMedida(
            rotulo: 'Pressão arterial',
            valor: s.paSistolica == null || s.paDiastolica == null
                ? 'Medir'
                : '${s.paSistolica}/${s.paDiastolica} mmHg',
            onTap: _editarPressao,
          ),
          LinhaMedida(
            rotulo: 'FC de repouso',
            valor: s.fcRepouso == null ? 'Medir' : '${s.fcRepouso} bpm',
            onTap: () => _editar('fc_repouso', 'FC de repouso', 'bpm', s.fcRepouso,
                decimal: false, ajuda: 'Sentado, após 5 minutos em repouso.'),
          ),
        ]),
        if (pa != null || fc != null) ...[
          const SizedBox(height: AppSpacing.sm + 2),
          GradeDupla(children: [
            IndiceTile(
              rotulo: 'Pressão',
              valor: pa == null ? null : '${s.paSistolica}/${s.paDiastolica}',
              classificacao: pa,
              referencia: 'Diretriz Brasileira 2020',
            ),
            IndiceTile(
              rotulo: 'FC repouso',
              valor: s.fcRepouso?.toString(),
              unidade: 'bpm',
              classificacao: fc,
            ),
          ]),
        ],
      ],
    );
  }

  Widget _indices(AvaliacaoCompleta av) {
    final imc = av.imc, rcq = av.rcq, rce = av.rce, cin = av.indiceCintura, iac = av.iac;
    return GradeDupla(children: [
      IndiceTile(
        rotulo: 'IMC',
        valor: imc == null ? null : numBr(imc.valor),
        classificacao: imc?.classificacao,
        referencia: imc?.referencia,
        vazio: 'Falta peso e estatura',
      ),
      IndiceTile(
        rotulo: '% Gordura',
        valor: av.percGordura == null ? null : numBr(av.percGordura),
        unidade: '%',
        referencia: av.origemGordura,
        vazio: 'Faça dobras ou bioimpedância',
      ),
      IndiceTile(
        rotulo: 'Cintura-quadril',
        valor: rcq == null ? null : numBr(rcq.valor, casas: 2),
        classificacao: rcq?.classificacao,
        referencia: rcq?.referencia,
        vazio: 'Falta cintura e quadril',
      ),
      IndiceTile(
        rotulo: 'Cintura-altura',
        valor: rce == null ? null : numBr(rce.valor, casas: 2),
        classificacao: rce?.classificacao,
        referencia: rce?.referencia,
        vazio: 'Falta cintura e estatura',
      ),
      IndiceTile(
        rotulo: 'Cintura',
        valor: cin == null ? null : numBr(cin.valor),
        unidade: 'cm',
        classificacao: cin?.classificacao,
        referencia: cin?.referencia,
        vazio: 'Falta cintura',
      ),
      IndiceTile(
        rotulo: 'IAC',
        valor: iac == null ? null : numBr(iac.valor),
        unidade: '% est.',
        referencia: iac == null ? null : 'Estimativa sem adipômetro · ${iac.referencia}',
        vazio: 'Falta quadril e estatura',
      ),
      if (av.massaMagra != null || av.massaGorda != null) ...[
        IndiceTile(
          rotulo: 'Massa magra',
          valor: av.massaMagra == null ? null : numBr(av.massaMagra),
          unidade: 'kg',
        ),
        IndiceTile(
          rotulo: 'Massa gorda',
          valor: av.massaGorda == null ? null : numBr(av.massaGorda),
          unidade: 'kg',
        ),
      ],
    ]);
  }

  Widget _testes(AvaliacaoCompleta av) {
    final comp = linhasComposicao(av);
    final neuro = linhasNeuromotoras(av);
    final cardio = linhasCardio(av);
    final desvios = av.desvios.length;
    final fotos = av.postural == null
        ? 0
        : VistaPostural.values.where((v) => (av.postural![v.coluna] as String?)?.isNotEmpty ?? false).length;

    Widget linha(String titulo, IconData icone, String rota, bool feito, String resumo) => PhdListRow(
          title: titulo,
          subtitle: resumo,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: feito ? AppColors.tint(AppColors.success) : AppColors.surfaceHigh,
              borderRadius: AppRadius.rMd,
            ),
            child: Icon(feito ? Icons.check_rounded : icone,
                size: 20, color: feito ? AppColors.successText : AppColors.textSecondary),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: () => _abrirTeste(rota),
        );

    return Column(
      children: [
        linha(
          'Composição corporal',
          Icons.accessibility_new_rounded,
          '/alunos/avaliacao/morfologica',
          comp.isNotEmpty,
          comp.isEmpty ? 'Dobras cutâneas ou bioimpedância' : comp.map((l) => l.valor).join(' · '),
        ),
        const SizedBox(height: AppSpacing.sm),
        linha(
          'Neuromotores',
          Icons.electric_bolt_rounded,
          '/alunos/avaliacao/neuromotores',
          neuro.isNotEmpty,
          neuro.isEmpty
              ? 'Flexibilidade, resistência, impulsão e força'
              : '${neuro.length} ${neuro.length == 1 ? 'teste' : 'testes'}: '
                  '${neuro.map((l) => l.titulo.split(' ').first).toSet().join(', ')}',
        ),
        const SizedBox(height: AppSpacing.sm),
        linha(
          'Cardiorrespiratório',
          Icons.favorite_border_rounded,
          '/alunos/avaliacao/cardio',
          cardio.isNotEmpty,
          cardio.isEmpty ? 'Cooper, Rockport, banco, esteira' : cardio.map((l) => l.valor).join(' · '),
        ),
        const SizedBox(height: AppSpacing.sm),
        linha(
          'Postural',
          Icons.person_outline_rounded,
          '/alunos/avaliacao/postural',
          av.postural != null,
          av.postural == null
              ? 'Fotos com grade e checklist de desvios'
              : '$fotos ${fotos == 1 ? 'foto' : 'fotos'} · '
                  '${desvios == 0 ? 'sem desvios marcados' : '$desvios ${desvios == 1 ? 'desvio' : 'desvios'}'}',
        ),
      ],
    );
  }

  Widget _cardio(AvaliacaoCompleta av) {
    final vo2 = av.vo2max;
    final fcMax = av.fcMax;
    final classica = Cardiaco.fcMaxClassica(av.idade);
    return Column(
      children: [
        GradeDupla(children: [
          IndiceTile(
            rotulo: 'VO₂máx',
            valor: vo2 == null ? null : numBr(vo2),
            unidade: 'ml/kg/min',
            classificacao: av.classificacaoVo2,
            referencia: vo2 == null ? null : 'AHA',
            vazio: 'Faça um teste cardio',
          ),
          IndiceTile(
            rotulo: 'FC máxima',
            valor: fcMax?.toString(),
            unidade: 'bpm',
            referencia: fcMax == null ? null : 'Tanaka · 220 − idade = $classica',
            vazio: 'Falta data de nascimento',
          ),
        ]),
        if (av.zonas.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm + 2),
          PhdCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ZONAS DE TREINO', style: AppText.label()),
                const SizedBox(height: 4),
                Text(
                  av.sessao.fcRepouso == null
                      ? '% da FC máxima. Com a FC de repouso, passa a usar Karvonen.'
                      : 'Karvonen, com FC de repouso de ${av.sessao.fcRepouso} bpm.',
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final z in av.zonas)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(width: 30, child: Text(z.id, style: AppText.number(13, color: _corZona(z.id)))),
                        Expanded(child: Text(z.nome, style: AppText.body(13.5))),
                        Text('${(z.pctDe * 100).round()}–${(z.pctAte * 100).round()}%',
                            style: AppText.caption(11.5, color: AppColors.textMuted)),
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(
                          width: 76,
                          child: Text('${z.bpmDe}–${z.bpmAte}',
                              textAlign: TextAlign.end, style: AppText.number(14)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Color _corZona(String id) => switch (id) {
        'Z1' => AppColors.textSecondary,
        'Z2' => AppColors.successText,
        'Z3' => AppColors.accent,
        'Z4' => AppColors.warningText,
        _ => AppColors.dangerText,
      };

  Widget _comparacao(List<LinhaComparacao> linhas) {
    return PhdCard(
      child: Column(
        children: [
          for (final l in linhas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(l.rotulo, style: AppText.body(13.5, color: AppColors.textSecondary))),
                  Text(numBr(l.anterior), style: AppText.caption(13, color: AppColors.textMuted)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.textMuted),
                  ),
                  Text(comUnidade(numBr(l.atual), l.unidade), style: AppText.number(14)),
                  SizedBox(
                    width: 64,
                    child: Text(
                      deltaBr(l.atual, l.anterior) ?? '',
                      textAlign: TextAlign.end,
                      style: AppText.bodyStrong(12.5, color: l.nivel.tom.onDark),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _fechamento(AvaliacaoCompleta av) {
    final proxima = av.sessao.proximaAvaliacao;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cartaoDeLinhas([
          LinhaMedida(
            rotulo: 'Próxima avaliação',
            valor: proxima == null ? 'Definir' : Datas.longa(proxima),
            onTap: _escolherProxima,
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _obsCtrl,
          minLines: 3,
          maxLines: 8,
          onChanged: (_) {
            if (!_obsAlterada) setState(() => _obsAlterada = true);
          },
          style: AppText.body(14),
          decoration: InputDecoration(
            hintText: 'Observações e orientações — entram no relatório do aluno',
            hintStyle: AppText.body(14, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: AppRadius.rXl, borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
          ),
        ),
        if (_obsAlterada) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: PhdButton(
              label: 'Salvar observações',
              size: PhdButtonSize.small,
              expand: false,
              variant: PhdButtonVariant.secondary,
              onPressed: _salvarObs,
            ),
          ),
        ],
      ],
    );
  }
}
