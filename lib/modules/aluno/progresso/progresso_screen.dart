import 'dart:typed_data';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/diario.dart';
import '../../../core/models/recursos_aluno.dart';
import '../../../core/services/aluno_service.dart';
import '../../../core/services/diario_service.dart';
import '../../../core/services/progresso_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/utils/navegacao.dart';
import '../../../core/widgets/widgets.dart';
import '../avaliacoes/aluno_avaliacoes_screen.dart';
import '../dieta/folhas_registro.dart';

/// Cores dos gráficos: são dados, não ação — por isso nada de vermelho,
/// que no app é o botão e o alerta.
const _corPeso = Color(0xFF3B82F6);
const _corGordura = Color(0xFFF59E0B);
const _corMagra = Color(0xFF22C55E);

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

enum _Secao { corpo, fotos, cargas }

/// A aba Progresso do aluno: o corpo mudando (peso e avaliações), as fotos
/// e a evolução das cargas — a prova de que o treino está funcionando.
class ProgressoScreen extends StatefulWidget {
  const ProgressoScreen({super.key, this.emAba = false});

  /// Aberta como aba do menu do aluno: sem seta de voltar, porque não há
  /// para onde voltar — a navegação é pela barra de baixo.
  final bool emAba;

  @override
  State<ProgressoScreen> createState() => _ProgressoScreenState();
}

class _ProgressoScreenState extends State<ProgressoScreen> {
  final _db = Supabase.instance.client;

  _Secao _secao = _Secao.corpo;
  Map<String, dynamic>? _aluno;
  List<Map<String, dynamic>> _fotos = [];
  List<Map<String, dynamic>> _avaliacoes = [];
  List<Map<String, dynamic>> _execucoes = [];
  List<RegistroPeso> _pesos = [];
  bool _carregando = true;
  bool _enviando = false;

  String? get _alunoId => _aluno?['id']?.toString();
  RecursosAluno get _recursos => RecursosAluno.doMapa(_aluno?['recursos']);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      _aluno ??= await AlunoService.doUsuarioAtual();
      final id = _alunoId;
      if (id == null) return;
      final (fotos, avaliacoes, execucoes, pesos) = await (
        _talvez(ProgressoService.listarFotos(id)),
        _carregarAvaliacoes(id),
        _carregarExecucoes(id),
        _talvez(DiarioService.pesos(id)),
      ).wait;
      if (!mounted) return;
      setState(() {
        _fotos = fotos ?? [];
        _avaliacoes = avaliacoes;
        _execucoes = execucoes;
        _pesos = pesos ?? [];
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  static Future<T?> _talvez<T>(Future<T> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _carregarAvaliacoes(String alunoId) async {
    try {
      final bio = await _db
          .from('avaliacao_morfologica_bioimpedancia')
          .select()
          .eq('aluno_id', alunoId)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: true);
      if ((bio as List).isNotEmpty) return List<Map<String, dynamic>>.from(bio);
      final dobras = await _db
          .from('avaliacao_morfologica_dobras')
          .select()
          .eq('aluno_id', alunoId)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: true);
      return List<Map<String, dynamic>>.from(dobras);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _carregarExecucoes(String alunoId) async {
    try {
      final data = await _db
          .from('treino_execucoes')
          .select('executado_em, detalhes')
          .eq('aluno_id', alunoId)
          .order('executado_em', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  // ── Dados ───────────────────────────────────────────────────

  /// Peso ao longo do tempo: pesagens de casa e o peso anotado nas fotos,
  /// um por dia. No mesmo dia, a pesagem de casa vence.
  List<({DateTime data, double peso})> get _seriePeso {
    final porDia = <DateTime, double>{};
    for (final f in _fotos) {
      final d = DateTime.tryParse(f['registrado_em'] as String? ?? '')?.toLocal();
      final p = (f['peso_kg'] as num?)?.toDouble();
      if (d != null && p != null) porDia[Datas.dia(d)] = p;
    }
    for (final p in _pesos) {
      porDia[Datas.dia(p.data)] = p.pesoKg;
    }
    return [for (final e in porDia.entries) (data: e.key, peso: e.value)]..sort((a, b) => a.data.compareTo(b.data));
  }

  /// Maior carga por exercício em cada treino; só exercícios com 2+ pontos.
  Map<String, List<({DateTime data, double carga})>> get _cargas {
    final r = <String, List<({DateTime data, double carga})>>{};
    for (final ex in _execucoes) {
      final data = DateTime.tryParse(ex['executado_em'] as String? ?? '')?.toLocal();
      final detalhes = ex['detalhes'];
      if (data == null || detalhes is! List) continue;
      for (final item in detalhes) {
        if (item is! Map) continue;
        final nome = item['exercicio_nome'] as String? ?? '';
        final series = item['series'];
        if (nome.isEmpty || series is! List) continue;
        var max = 0.0;
        for (final s in series) {
          final c = s is Map ? (s['carga_kg'] as num?)?.toDouble() : null;
          if (c != null && c > max) max = c;
        }
        if (max > 0) r.putIfAbsent(nome, () => []).add((data: data, carga: max));
      }
    }
    r.removeWhere((_, v) => v.length < 2);
    return r;
  }

  // ── Ações ───────────────────────────────────────────────────

  Future<void> _registrarPeso() async {
    final id = _alunoId;
    if (id == null) return;
    final salvo = await registrarPeso(context, alunoId: id, ultimo: _seriePeso.lastOrNull?.peso);
    if (salvo != null && mounted) _carregar();
  }

  Future<void> _adicionarFoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => const _FolhaOrigem(),
    );
    if (source == null || !mounted) return;
    final foto = await ImagePicker().pickImage(source: source, imageQuality: 75, maxWidth: 1200);
    if (foto == null || !mounted) return;
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _FotoFormDialog(foto: foto),
    );
    final id = _alunoId;
    if (result == null || id == null || !mounted) return;
    setState(() => _enviando = true);
    try {
      await ProgressoService.adicionarFoto(
        alunoId: id,
        foto: foto,
        pesoKg: result['peso'] as double?,
        observacoes: result['observacoes'] as String?,
      );
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui enviar: $e', style: AppText.body(13.5))),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── Tela ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: widget.emAba
          ? null
          : AppBar(
              backgroundColor: AppColors.bg,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => context.voltar(senaoPara: '/aluno/home'),
              ),
            ),
      body: SafeArea(
        child: _carregando
            ? Center(child: CircularProgressIndicator(color: AppColors.accent))
            : RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.surface,
                onRefresh: _carregar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
                  children: [
                    Text('PROGRESSO', style: AppText.label()),
                    const SizedBox(height: 6),
                    Text('Sua evolução', style: AppText.display(26)),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        for (final (s, rotulo) in const [
                          (_Secao.corpo, 'Corpo'),
                          (_Secao.fotos, 'Fotos'),
                          (_Secao.cargas, 'Cargas'),
                        ]) ...[
                          PhdFilterChip(label: rotulo, selected: _secao == s, onTap: () => setState(() => _secao = s)),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (_alunoId == null)
                      const PhdEmptyState(
                        icon: Icons.link_off_rounded,
                        title: 'Conta ainda não vinculada',
                        message: 'Peça ao seu personal para conferir o e-mail do seu cadastro.',
                      )
                    else
                      ...switch (_secao) {
                        _Secao.corpo => _corpo(),
                        _Secao.fotos => _secaoFotos(),
                        _Secao.cargas => _secaoCargas(),
                      },
                  ],
                ),
              ),
      ),
    );
  }

  // ── Corpo ───────────────────────────────────────────────────

  List<Widget> _corpo() {
    final serie = _seriePeso;
    final atual = serie.lastOrNull;
    final primeiro = serie.firstOrNull;
    final temComp = _avaliacoes.length >= 2;

    return [
      PhdCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PESO', style: AppText.label()),
                      const SizedBox(height: 4),
                      Text.rich(TextSpan(children: [
                        TextSpan(text: atual == null ? '—' : _n(atual.peso), style: AppText.number(32)),
                        TextSpan(text: ' kg', style: AppText.caption(14)),
                      ])),
                      Text(
                        atual == null ? 'Nenhum registro ainda' : 'em ${Datas.longa(atual.data)}',
                        style: AppText.caption(12.5),
                      ),
                    ],
                  ),
                ),
                if (atual != null && primeiro != null && serie.length >= 2)
                  _variacao(atual.peso - primeiro.peso, 'kg', 'desde ${Datas.longa(primeiro.data)}'),
              ],
            ),
            if (serie.length >= 2) ...[
              const SizedBox(height: AppSpacing.lg),
              _grafico(
                [for (final p in serie) p.peso],
                [for (final p in serie) p.data],
                _corPeso,
                'kg',
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              Text('Registre seu peso uma vez por semana, no mesmo horário, para ver a curva aqui.',
                  style: AppText.body(13.5, color: AppColors.textSecondary)),
            ],
            if (_recursos.peso) ...[
              const SizedBox(height: AppSpacing.lg),
              PhdButton(
                label: 'Registrar peso',
                icon: Icons.monitor_weight_outlined,
                variant: PhdButtonVariant.secondary,
                size: PhdButtonSize.medium,
                onPressed: _registrarPeso,
              ),
            ],
          ],
        ),
      ),
      if (temComp) ...[
        const SizedBox(height: AppSpacing.md),
        _cartaoGrafico('Gordura corporal', '%', _corGordura, 'perc_gordura', bomQuandoDesce: true),
        const SizedBox(height: AppSpacing.md),
        _cartaoGrafico('Massa magra', 'kg', _corMagra, 'massa_magra', bomQuandoDesce: false),
      ],
      const SizedBox(height: AppSpacing.md),
      PhdCard(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlunoAvaliacoesScreen())),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: AppColors.tint(_corGordura), borderRadius: AppRadius.rMd),
              child: const Icon(Icons.monitor_heart_outlined, color: _corGordura),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Avaliações físicas', style: AppText.bodyStrong(14.5)),
                  Text(
                    _avaliacoes.isEmpty
                        ? 'Composição, medidas e testes feitos pelo seu personal'
                        : '${_avaliacoes.length} ${_avaliacoes.length == 1 ? 'avaliação' : 'avaliações'} de composição',
                    style: AppText.caption(12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    ];
  }

  Widget _cartaoGrafico(String titulo, String unidade, Color cor, String campo, {required bool bomQuandoDesce}) {
    final pontos = [
      for (final a in _avaliacoes)
        if ((a[campo] as num?)?.toDouble() case final v?)
          if (DateTime.tryParse(a['data_avaliacao'] as String? ?? '') case final d?) (data: d, valor: v),
    ];
    if (pontos.length < 2) return const SizedBox.shrink();
    final delta = pontos.last.valor - pontos.first.valor;

    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo.toUpperCase(), style: AppText.label()),
                    const SizedBox(height: 4),
                    Text.rich(TextSpan(children: [
                      TextSpan(text: _n(pontos.last.valor), style: AppText.number(26)),
                      TextSpan(text: ' $unidade', style: AppText.caption(13)),
                    ])),
                  ],
                ),
              ),
              _variacao(delta, unidade, 'desde a 1ª avaliação', bomQuandoDesce: bomQuandoDesce),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _grafico([for (final p in pontos) p.valor], [for (final p in pontos) p.data], cor, unidade),
        ],
      ),
    );
  }

  /// "+1,2 kg" — verde quando é bom, âmbar quando não é, cinza quando
  /// depende do objetivo (peso sozinho não diz se melhorou).
  Widget _variacao(double delta, String unidade, String apoio, {bool? bomQuandoDesce}) {
    final cor = delta.abs() < 0.05 || bomQuandoDesce == null
        ? AppColors.textSecondary
        : (delta < 0) == bomQuandoDesce
            ? AppColors.successText
            : AppColors.warningText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${delta > 0 ? '+' : ''}${_n(delta)} $unidade', style: AppText.number(15, color: cor)),
        Text(apoio, style: AppText.caption(12)),
      ],
    );
  }

  Widget _grafico(List<double> valores, List<DateTime> datas, Color cor, String unidade) {
    final spots = [for (final (i, v) in valores.indexed) FlSpot(i.toDouble(), v)];
    final ordenados = [...valores]..sort();
    final folga = ((ordenados.last - ordenados.first) * 0.2).clamp(0.5, double.infinity);

    return SizedBox(
      height: 140,
      child: LineChart(LineChartData(
        minY: ordenados.first - folga,
        maxY: ordenados.last + folga,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: AppColors.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                  ? const SizedBox.shrink()
                  : Text(v.toStringAsFixed(0), style: AppText.caption(11)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: spots.length <= 6 ? 1 : (spots.length / 4).roundToDouble(),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= datas.length || v != i.toDouble()) return const SizedBox.shrink();
                final d = datas[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${d.day}/${d.month}', style: AppText.caption(11)),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceHigh,
            getTooltipItems: (s) =>
                [for (final p in s) LineTooltipItem('${_n(p.y)} $unidade', AppText.bodyStrong(12, color: cor))],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: cor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              getDotPainter: (_, __, ___, ____) =>
                  FlDotCirclePainter(radius: 3.5, color: cor, strokeWidth: 2, strokeColor: AppColors.surface),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [cor.withValues(alpha: 0.18), cor.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      )),
    );
  }

  // ── Fotos ───────────────────────────────────────────────────

  List<Widget> _secaoFotos() {
    final botao = PhdButton(
      label: _enviando ? 'Enviando…' : 'Nova foto',
      icon: Icons.add_a_photo_outlined,
      loading: _enviando,
      onPressed: _enviando ? null : _adicionarFoto,
    );
    if (_fotos.isEmpty) {
      return [
        const PhdEmptyState(
          icon: Icons.photo_camera_outlined,
          title: 'Registre seu ponto de partida',
          message: 'Uma foto por mês, na mesma luz e posição. Em 3 meses a diferença aparece — mesmo quando a balança não mostra.',
        ),
        const SizedBox(height: AppSpacing.lg),
        botao,
      ];
    }

    final primeira = DateTime.parse(_fotos.last['registrado_em'] as String).toLocal();
    return [
      Row(
        children: [
          Expanded(child: _numero('${_fotos.length}', _fotos.length == 1 ? 'foto' : 'fotos')),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _numero('${_meses[primeira.month - 1].substring(0, 3)} ${primeira.year}', 'primeira')),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      botao,
      const SizedBox(height: AppSpacing.lg),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 0.62,
        ),
        itemCount: _fotos.length,
        itemBuilder: (_, i) => _cartaoFoto(_fotos[i]),
      ),
    ];
  }

  Widget _numero(String valor, String rotulo) => PhdCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(valor, style: AppText.number(20)),
            Text(rotulo, style: AppText.caption(12)),
          ],
        ),
      );

  Widget _cartaoFoto(Map<String, dynamic> foto) {
    final peso = (foto['peso_kg'] as num?)?.toDouble();
    final d = DateTime.parse(foto['registrado_em'] as String).toLocal();
    final obs = (foto['observacoes'] as String?)?.trim();
    return PhdCard(
      onTap: () => _verFoto(foto['foto_url'] as String),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              child: Image.network(
                foto['foto_url'] as String,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(
                  color: AppColors.surfaceHigh,
                  child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${d.day} ${_meses[d.month - 1].substring(0, 3)} ${d.year}', style: AppText.bodyStrong(13)),
                Text(
                  [if (peso != null) '${_n(peso)} kg', if (obs != null && obs.isNotEmpty) obs].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _verFoto(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: SizedBox.expand(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain))),
        ),
      ),
    );
  }

  // ── Cargas ──────────────────────────────────────────────────

  List<Widget> _secaoCargas() {
    final cargas = _cargas;
    if (cargas.isEmpty) {
      return const [
        PhdEmptyState(
          icon: Icons.fitness_center_rounded,
          title: 'Sem histórico de cargas',
          message: 'Anote a carga ao fazer o treino guiado. A curva de cada exercício aparece a partir do 2º treino com carga.',
        ),
      ];
    }
    // Quem mais evoluiu primeiro: é o que o aluno quer ver.
    final nomes = cargas.keys.toList()
      ..sort((a, b) {
        double ganho(String n) => cargas[n]!.last.carga - cargas[n]!.first.carga;
        return ganho(b).compareTo(ganho(a));
      });

    return [
      for (final nome in nomes) ...[
        _cartaoCarga(nome, [...cargas[nome]!]..sort((a, b) => a.data.compareTo(b.data))),
        const SizedBox(height: AppSpacing.md),
      ],
    ];
  }

  Widget _cartaoCarga(String nome, List<({DateTime data, double carga})> pontos) {
    final delta = pontos.last.carga - pontos.first.carga;
    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(14.5)),
                    Text('${pontos.length} treinos com carga', style: AppText.caption(12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_n(pontos.last.carga)} kg', style: AppText.number(17)),
                  if (delta.abs() >= 0.05)
                    Text('${delta > 0 ? '+' : ''}${_n(delta)} kg',
                        style: AppText.bodyStrong(12, color: delta > 0 ? AppColors.successText : AppColors.warningText)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _grafico([for (final p in pontos) p.carga], [for (final p in pontos) p.data], _corMagra, 'kg'),
        ],
      ),
    );
  }

  /// "72,5" — vírgula, uma casa, sem ",0".
  static String _n(double v) {
    final s = v.toStringAsFixed(1).replaceAll('.', ',');
    return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
  }
}

class _FolhaOrigem extends StatelessWidget {
  const _FolhaOrigem();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Adicionar foto', style: AppText.title(17)),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: _opcao(context, ImageSource.camera, Icons.photo_camera_outlined, 'Câmera')),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _opcao(context, ImageSource.gallery, Icons.photo_library_outlined, 'Galeria')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _opcao(BuildContext ctx, ImageSource src, IconData icone, String rotulo) => PhdCard(
        onTap: () => Navigator.pop(ctx, src),
        color: AppColors.surfaceHigh,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(icone, color: AppColors.accent, size: 30),
            const SizedBox(height: AppSpacing.sm),
            Text(rotulo, style: AppText.bodyStrong(14)),
          ],
        ),
      );
}

class _FotoFormDialog extends StatefulWidget {
  const _FotoFormDialog({required this.foto});
  final XFile foto;

  @override
  State<_FotoFormDialog> createState() => _FotoFormDialogState();
}

class _FotoFormDialogState extends State<_FotoFormDialog> {
  final _peso = TextEditingController();
  final _obs = TextEditingController();
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    widget.foto.readAsBytes().then((b) {
      if (mounted) setState(() => _bytes = b);
    });
  }

  @override
  void dispose() {
    _peso.dispose();
    _obs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text('Nova foto', style: AppText.title(17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: AppRadius.rLg,
              child: SizedBox(
                height: 180,
                child: _bytes == null
                    ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                    : Image.memory(_bytes!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PhdField(
              label: 'Peso de hoje (opcional)',
              controller: _peso,
              hint: '72,5',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: AppSpacing.md),
            PhdField(label: 'Como você está se sentindo? (opcional)', controller: _obs, maxLines: 2),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            final obs = _obs.text.trim();
            Navigator.pop(context, {
              'peso': double.tryParse(_peso.text.replaceAll(',', '.')),
              'observacoes': obs.isEmpty ? null : obs,
            });
          },
          child: Text('Salvar foto', style: AppText.bodyStrong(13.5, color: AppColors.accent)),
        ),
      ],
    );
  }
}
