import 'package:flutter/material.dart';
import '../../../core/models/dieta.dart';
import '../../../core/services/dia_aluno_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';

const _semana = ['domingo', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado'];
const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

/// Um dia do aluno, visto pelo personal: o que ele tinha para fazer
/// (treino, refeições, água) e o que fez. O dia muda pelas setas ou tocando
/// num dia da grade de frequência.
class DiaDoAlunoCartao extends StatefulWidget {
  const DiaDoAlunoCartao({
    super.key,
    required this.alunoId,
    required this.dia,
    required this.aoTrocarDia,
    this.fichas = const [],
    this.plano,
    this.pesoAtual,
  });

  final String alunoId;
  final DateTime dia;
  final ValueChanged<DateTime> aoTrocarDia;
  final List<Map<String, dynamic>> fichas;
  final PlanoAlimentar? plano;
  final double? pesoAtual;

  @override
  State<DiaDoAlunoCartao> createState() => _DiaDoAlunoCartaoState();
}

class _DiaDoAlunoCartaoState extends State<DiaDoAlunoCartao> {
  DiaDoAluno? _d;
  bool _carregando = true;

  /// Respostas de um dia antigo podem chegar depois das do dia novo, se o
  /// personal passar as setas rápido. Só a última pedida vale.
  int _pedido = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(DiaDoAlunoCartao antigo) {
    super.didUpdateWidget(antigo);
    if (antigo.dia != widget.dia || antigo.plano != widget.plano || antigo.fichas != widget.fichas) _carregar();
  }

  Future<void> _carregar() async {
    final n = ++_pedido;
    setState(() => _carregando = true);
    final d = await DiaAlunoService.carregar(
      alunoId: widget.alunoId,
      dia: widget.dia,
      fichas: widget.fichas,
      plano: widget.plano,
      pesoAtual: widget.pesoAtual,
    );
    if (!mounted || n != _pedido) return;
    setState(() {
      _d = d;
      _carregando = false;
    });
  }

  DateTime get _hoje => Datas.dia(DateTime.now());

  String _rotuloDia(DateTime d) {
    final dif = _hoje.difference(d).inDays;
    final data = '${d.day} ${_meses[d.month - 1]}';
    if (dif == 0) return 'Hoje · $data';
    if (dif == 1) return 'Ontem · $data';
    return '${_semana[d.weekday % 7][0].toUpperCase()}${_semana[d.weekday % 7].substring(1)} · $data';
  }

  @override
  Widget build(BuildContext context) {
    final dia = widget.dia;
    final ehHoje = dia == _hoje;

    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _seta(Icons.chevron_left_rounded, 'Dia anterior',
                  () => widget.aoTrocarDia(dia.subtract(const Duration(days: 1)))),
              Expanded(
                child: Column(
                  children: [
                    Text(_rotuloDia(dia), textAlign: TextAlign.center, style: AppText.title(15.5)),
                    if (!ehHoje)
                      GestureDetector(
                        onTap: () => widget.aoTrocarDia(_hoje),
                        child: Text('voltar para hoje', style: AppText.bodyStrong(11.5, color: AppColors.accent)),
                      ),
                  ],
                ),
              ),
              _seta(Icons.chevron_right_rounded, 'Próximo dia',
                  ehHoje ? null : () => widget.aoTrocarDia(dia.add(const Duration(days: 1)))),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnimatedSwitcher(
            duration: AppDuration.fast,
            child: _carregando && _d == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Opacity(
                    key: ValueKey(_d?.dia),
                    opacity: _carregando ? 0.5 : 1,
                    child: _conteudo(_d!),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _seta(IconData icone, String dica, VoidCallback? onTap) => IconButton(
        tooltip: dica,
        onPressed: onTap,
        style: IconButton.styleFrom(backgroundColor: AppColors.surfaceHigh),
        icon: Icon(icone, color: onTap == null ? AppColors.lineStrong : AppColors.textPrimary),
      );

  Widget _conteudo(DiaDoAluno d) {
    final inicioPlano = widget.plano?.dataInicio;
    final antesDoPlano = inicioPlano != null && d.dia.isBefore(Datas.dia(inicioPlano));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _veredito(d),
        const SizedBox(height: AppSpacing.lg),
        _bloco(
          icone: Icons.fitness_center_rounded,
          titulo: 'Treino',
          resumo: d.treinos.isEmpty
              ? 'dia de descanso'
              : '${d.treinos.where((t) => t.feito).length} de ${d.treinos.length}',
          ok: d.treinos.isEmpty ? null : d.treinos.every((t) => t.feito),
          filhos: [
            for (final t in d.treinos)
              _linha(
                t.feito,
                t.nome,
                t.feito ? (t.minutos != null && t.minutos! > 0 ? '${t.minutos} min' : 'feito') : 'não fez',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _bloco(
          icone: Icons.restaurant_menu_rounded,
          titulo: 'Dieta',
          resumo: !d.temPlano
              ? 'sem plano ativo'
              : '${d.refeicoesFeitas} de ${d.refeicoes.length} refeições',
          ok: d.temPlano ? d.refeicoesFeitas == d.refeicoes.length : null,
          filhos: [
            if (antesDoPlano)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  'O plano atual começou em ${inicioPlano.day}/${inicioPlano.month}: neste dia o aluno ainda não seguia ele.',
                  style: AppText.caption(11.5, color: AppColors.warningText),
                ),
              ),
            for (final r in d.refeicoes)
              _linha(
                r.registro?.feita ?? false,
                r.refeicao.nome,
                !(r.registro?.feita ?? false)
                    ? 'não marcou'
                    : r.registro!.alterada
                        ? 'trocou · ${r.kcal.round()} kcal'
                        : '${r.kcal.round()} kcal',
                apoio: r.refeicao.horarioTexto,
                aviso: (r.registro?.feita ?? false) && r.registro!.alterada,
              ),
            if (d.temPlano && d.metaKcal != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: Text('Calorias do dia', style: AppText.caption(12))),
                  Text('${d.kcalConsumidas.round()} / ${d.metaKcal!.round()} kcal', style: AppText.number(12.5)),
                ],
              ),
              const SizedBox(height: 5),
              PhdProgressBar(value: (d.kcalConsumidas / d.metaKcal!).clamp(0.0, 1.0), height: 6),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _bloco(
          icone: Icons.water_drop_outlined,
          titulo: 'Água',
          resumo: '${(d.aguaMl / 1000).toStringAsFixed(1)} de ${(d.metaAguaMl / 1000).toStringAsFixed(1)} L',
          ok: d.metaAguaMl > 0 ? d.bebeuAgua : null,
          filhos: [
            PhdProgressBar(
              value: d.metaAguaMl == 0 ? 0 : (d.aguaMl / d.metaAguaMl).clamp(0.0, 1.0),
              height: 6,
              color: const Color(0xFF3B82F6),
            ),
          ],
        ),
        if (d.peso != null) ...[
          const SizedBox(height: AppSpacing.md),
          _bloco(
            icone: Icons.monitor_weight_outlined,
            titulo: 'Peso',
            resumo: '${d.peso!.toStringAsFixed(1).replaceAll('.', ',')} kg',
            ok: null,
            filhos: const [],
          ),
        ],
      ],
    );
  }

  /// A resposta em uma linha, antes dos detalhes.
  Widget _veredito(DiaDoAluno d) {
    final futuroOuVazio = d.total == 0;
    final p = d.proporcao;
    final (texto, tom) = futuroOuVazio
        ? ('Nada previsto para este dia', PhdTone.neutral)
        : p >= 1
            ? ('Seguiu tudo', PhdTone.success)
            : p >= 0.6
                ? ('Seguiu quase tudo', PhdTone.warning)
                : p > 0
                    ? ('Seguiu pouco', PhdTone.danger)
                    : ('Não seguiu', PhdTone.danger);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.tint(tom.solid),
        borderRadius: AppRadius.rLg,
      ),
      child: Row(
        children: [
          PhdRing(
            valor: p,
            tamanho: 46,
            espessura: 5,
            cor: tom.solid,
            child: Text('${(p * 100).round()}%', style: AppText.number(11)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(texto, style: AppText.title(15, color: tom.onDark)),
                if (!futuroOuVazio)
                  Text('${d.cumpridos} de ${d.total} itens cumpridos', style: AppText.caption(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bloco({
    required IconData icone,
    required String titulo,
    required String resumo,
    required bool? ok,
    required List<Widget> filhos,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icone, size: 17, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(titulo, style: AppText.bodyStrong(13.5)),
            const Spacer(),
            Text(resumo, style: AppText.caption(12)),
            if (ok != null) ...[
              const SizedBox(width: 6),
              Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  size: 16, color: ok ? AppColors.successText : AppColors.warningText),
            ],
          ],
        ),
        if (filhos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Padding(padding: const EdgeInsets.only(left: 25), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: filhos)),
        ],
      ],
    );
  }

  Widget _linha(bool feito, String nome, String status, {String? apoio, bool aviso = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            feito ? Icons.check_rounded : Icons.close_rounded,
            size: 15,
            color: feito ? AppColors.successText : AppColors.dangerText,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: nome, style: AppText.body(13)),
                if (apoio != null) TextSpan(text: '  $apoio', style: AppText.caption(11, color: AppColors.textMuted)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            status,
            style: AppText.caption(11.5,
                color: aviso
                    ? AppColors.warningText
                    : feito
                        ? AppColors.textSecondary
                        : AppColors.dangerText),
          ),
        ],
      ),
    );
  }
}
