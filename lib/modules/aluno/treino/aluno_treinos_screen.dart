import 'package:flutter/material.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/services/treino_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import 'iniciar_treino.dart';

const _diasCurto = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

/// A aba Treino do aluno: tudo de treino num lugar só.
///
/// A home responde "o que eu treino hoje?". Aqui o aluno vê o resto — a
/// semana inteira, todas as fichas que o personal montou (com os dias de
/// cada uma) e o que já fez. Qualquer ficha pode ser aberta, não só a do
/// dia: quem trocou o treino de quarta pelo de quinta precisa conseguir.
class AlunoTreinosScreen extends StatefulWidget {
  const AlunoTreinosScreen({super.key, required this.alunoId});

  final String alunoId;

  @override
  State<AlunoTreinosScreen> createState() => _AlunoTreinosScreenState();
}

class _AlunoTreinosScreenState extends State<AlunoTreinosScreen> {
  List<Map<String, dynamic>> _fichas = [];
  Map<int, Set<String>> _feitoPorDia = {};
  List<Map<String, dynamic>> _historico = [];
  bool _carregando = true;
  String? _erro;

  int get _hoje => DateTime.now().weekday % 7;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final (fichas, feitos, historico) = await (
        FichaService.fichasDoAluno(widget.alunoId),
        TreinoService.concluidosDaSemana(),
        TreinoService.historico(limite: 12),
      ).wait;
      if (!mounted) return;
      setState(() {
        _fichas = fichas;
        _feitoPorDia = feitos;
        _historico = historico;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<int> _dias(Map<String, dynamic> f) =>
      [for (final d in (f['dias_semana'] as List?) ?? const []) (d as num).toInt()]..sort();

  /// Ficha sem dia marcado vale para qualquer dia.
  bool _ehDoDia(Map<String, dynamic> f, int dia) {
    final d = _dias(f);
    return d.isEmpty || d.contains(dia);
  }

  String? _idFicha(Map<String, dynamic> f) => (f['fichas'] as Map?)?['id'] as String?;

  bool _feitaEstaSemana(Map<String, dynamic> f) =>
      _feitoPorDia.values.any((s) => s.contains(_idFicha(f)));

  bool _feitaHoje(Map<String, dynamic> f) => _feitoPorDia[_hoje]?.contains(_idFicha(f)) ?? false;

  Future<void> _abrir(Map<String, dynamic> f) async {
    final ficha = (f['fichas'] as Map?)?.cast<String, dynamic>();
    if (ficha == null) return;
    if (await iniciarTreino(context, ficha, dia: _hoje) && mounted) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _carregando
            ? Center(child: CircularProgressIndicator(color: AppColors.accent))
            : _erro != null
                ? PhdEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Não consegui carregar',
                    message: _erro!,
                    actionLabel: 'Tentar de novo',
                    onAction: _carregar,
                  )
                : RefreshIndicator(
                    color: AppColors.accent,
                    backgroundColor: AppColors.surface,
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
                      children: [
                        Text('TREINO', style: AppText.label()),
                        const SizedBox(height: 6),
                        Text('Seus treinos', style: AppText.display(26)),
                        const SizedBox(height: AppSpacing.xl),
                        if (_fichas.isEmpty)
                          const PhdEmptyState(
                            icon: Icons.fitness_center_rounded,
                            title: 'Nenhuma ficha ainda',
                            message: 'Assim que seu personal montar seu treino, ele aparece aqui.',
                          )
                        else ...[
                          _semana(),
                          const SizedBox(height: AppSpacing.xxl),
                          PhdSectionHeader(label: 'Suas fichas', trailing: '${_fichas.length}'),
                          const SizedBox(height: AppSpacing.md),
                          for (final f in _ordenadas())
                            Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _cartaoFicha(f),
                            ),
                        ],
                        if (_historico.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xxl),
                          const PhdSectionHeader(label: 'O que você já fez'),
                          const SizedBox(height: AppSpacing.md),
                          _historicoCartao(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  /// As do dia primeiro, depois na ordem do nome (Treino A, B, C).
  List<Map<String, dynamic>> _ordenadas() {
    String nome(Map<String, dynamic> f) => ((f['fichas'] as Map?)?['nome'] as String?) ?? '';
    return [..._fichas]..sort((a, b) {
        final hojeA = _ehDoDia(a, _hoje) && _dias(a).isNotEmpty ? 0 : 1;
        final hojeB = _ehDoDia(b, _hoje) && _dias(b).isNotEmpty ? 0 : 1;
        if (hojeA != hojeB) return hojeA.compareTo(hojeB);
        return nome(a).compareTo(nome(b));
      });
  }

  /// A semana, de segunda a domingo, com o que tem em cada dia.
  Widget _semana() {
    const ordem = [1, 2, 3, 4, 5, 6, 0];
    final feitos = _feitoPorDia.values.where((s) => s.isNotEmpty).length;

    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, AppSpacing.md),
            child: Row(
              children: [
                Expanded(child: Text('ESTA SEMANA', style: AppText.label())),
                Text.rich(TextSpan(children: [
                  TextSpan(text: '$feitos', style: AppText.number(15, color: AppColors.accent, weight: FontWeight.w800)),
                  TextSpan(text: feitos == 1 ? ' treino feito' : ' treinos feitos', style: AppText.caption(12.5)),
                ])),
              ],
            ),
          ),
          for (final d in ordem) _linhaDia(d),
        ],
      ),
    );
  }

  Widget _linhaDia(int dia) {
    final fichas = _fichas.where((f) => _dias(f).contains(dia)).toList();
    final treinou = (_feitoPorDia[dia] ?? const {}).isNotEmpty;
    final ehHoje = dia == _hoje;
    final nomes = fichas.map((f) => ((f['fichas'] as Map?)?['nome'] as String?) ?? 'Treino').join(' + ');

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 9),
      decoration: BoxDecoration(
        color: ehHoje ? AppColors.tint(AppColors.accent) : Colors.transparent,
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(_diasCurto[dia],
                style: AppText.bodyStrong(13, color: ehHoje ? AppColors.accent : AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(
              fichas.isEmpty ? 'Descanso' : nomes,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: fichas.isEmpty ? AppText.caption(13, color: AppColors.textMuted) : AppText.body(13.5),
            ),
          ),
          if (treinou)
            Icon(Icons.check_circle_rounded, size: 18, color: AppColors.success)
          else if (ehHoje && fichas.isNotEmpty)
            Text('hoje', style: AppText.bodyStrong(11.5, color: AppColors.accent)),
        ],
      ),
    );
  }

  Widget _cartaoFicha(Map<String, dynamic> f) {
    final ficha = (f['fichas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final nome = ficha['nome'] as String? ?? 'Treino';
    final qtd = (f['qtd_exercicios'] as num?)?.toInt() ?? 0;
    final minutos = (f['minutos_estimados'] as num?)?.toInt() ?? 0;
    final grupos = [for (final g in (f['grupos'] as List?) ?? const []) '$g'];
    final dias = _dias(f);
    final deHoje = dias.isNotEmpty && dias.contains(_hoje);
    final feitaHoje = _feitaHoje(f);
    final m = RegExp(r'^treino\s+([a-z0-9])(?![a-z0-9])', caseSensitive: false).firstMatch(nome.trim());
    final sigla = m?.group(1)?.toUpperCase() ?? (nome.trim().isEmpty ? '?' : nome.trim()[0].toUpperCase());

    return PhdCard(
      onTap: qtd == 0 ? null : () => _abrir(f),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: feitaHoje ? AppColors.success : AppColors.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: feitaHoje
                    ? Icon(Icons.check_rounded, color: AppColors.onAccent, size: 26)
                    : Text(sigla, style: AppText.display(24, color: AppColors.onAccent)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(nome, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title(15.5)),
                        ),
                        if (deHoje && !feitaHoje) const PhdStatusChip(label: 'hoje', tone: PhdTone.accent),
                        if (feitaHoje) const PhdStatusChip(label: 'feito hoje', tone: PhdTone.success),
                        if (!feitaHoje && !deHoje && _feitaEstaSemana(f))
                          const PhdStatusChip(label: 'feito na semana', tone: PhdTone.success),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        '$qtd ${qtd == 1 ? 'exercício' : 'exercícios'}',
                        if (minutos > 0) '~$minutos min',
                        dias.isEmpty ? 'qualquer dia' : dias.map((d) => _diasCurto[d]).join(' · '),
                      ].join('  ·  '),
                      style: AppText.caption(12),
                    ),
                    if (grupos.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [for (final g in grupos.take(4)) PhdStatusChip(label: g)],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (qtd > 0) ...[
            const SizedBox(height: AppSpacing.md),
            PhdButton(
              label: feitaHoje ? 'Treinar de novo' : 'Começar treino',
              icon: Icons.play_arrow_rounded,
              size: PhdButtonSize.medium,
              variant: deHoje && !feitaHoje ? PhdButtonVariant.primary : PhdButtonVariant.secondary,
              onPressed: () => _abrir(f),
            ),
          ],
        ],
      ),
    );
  }

  Widget _historicoCartao() {
    return PhdCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          for (final (i, h) in _historico.indexed) ...[
            if (i > 0) Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h['ficha_nome'] as String? ?? 'Treino',
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(13.5)),
                        Text(
                          [
                            _quando(h['executado_em'] as String?),
                            if ((h['total_exercicios'] as num?) case final n? when n > 0) '$n exercícios',
                          ].join(' · '),
                          style: AppText.caption(12),
                        ),
                      ],
                    ),
                  ),
                  Text(_duracao(h['duracao_minutos']), style: AppText.number(13.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _quando(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final hoje = DateTime.now();
    final dias = DateTime(hoje.year, hoje.month, hoje.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    if (dias == 0) return 'Hoje';
    if (dias == 1) return 'Ontem';
    if (dias < 7) return '${_diasCurto[d.weekday % 7]}, há $dias dias';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  String _duracao(Object? minutos) {
    final m = (minutos as num?)?.toInt();
    if (m == null || m <= 0) return '';
    if (m < 60) return '${m}min';
    final resto = m % 60;
    return resto == 0 ? '${m ~/ 60}h' : '${m ~/ 60}h$resto';
  }
}
