import 'package:flutter/material.dart';

import '../../../core/models/financeiro.dart';
import '../../../core/services/aluno_service.dart';
import '../../../core/services/financeiro_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/moeda.dart';
import '../../../core/widgets/widgets.dart';

/// Põe um aluno num plano e gera as cobranças. Devolve `true` se criou.
Future<bool?> abrirNovaAssinatura(
  BuildContext context,
  List<PlanoVenda> planos,
) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _NovaAssinaturaSheet(planos: planos),
  );
}

class _NovaAssinaturaSheet extends StatefulWidget {
  const _NovaAssinaturaSheet({required this.planos});

  final List<PlanoVenda> planos;

  @override
  State<_NovaAssinaturaSheet> createState() => _NovaAssinaturaSheetState();
}

class _NovaAssinaturaSheetState extends State<_NovaAssinaturaSheet> {
  List<Map<String, dynamic>> _alunos = const [];
  bool _carregandoAlunos = true;

  Map<String, dynamic>? _aluno;
  PlanoVenda? _plano;
  DateTime _vencimento = DateTime.now();

  /// Quantos ciclos gerar de uma vez. Um ano à frente no mensal cobre o
  /// caso comum sem o personal ter de voltar aqui todo mês.
  int _ciclos = 12;

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregarAlunos();
  }

  Future<void> _carregarAlunos() async {
    try {
      final l = await AlunoService.listar(ativo: true);
      if (mounted) setState(() => _alunos = l);
    } catch (_) {
      // Lista vazia já mostra o estado certo na tela.
    } finally {
      if (mounted) setState(() => _carregandoAlunos = false);
    }
  }

  /// No plano trimestral, 4 ciclos já é um ano. Gerar 12 trimestres seriam
  /// três anos de cobrança, o que ninguém quer ver na lista.
  int get _ciclosSugeridos => switch (_plano?.meses ?? 1) {
        1 => 12,
        3 => 4,
        6 => 2,
        _ => 1,
      };

  int get _totalCentavos => (_plano?.precoCentavos ?? 0) * _ciclos;

  @override
  Widget build(BuildContext context) {
    final fundoTeclado = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: fundoTeclado),
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.md),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lineStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl,
                  ),
                  children: [
                    Text('Assinar aluno', style: AppText.title(18)),
                    const SizedBox(height: AppSpacing.xl),

                    const PhdSectionHeader(label: 'Aluno'),
                    const SizedBox(height: AppSpacing.sm),
                    _seletorAluno(),

                    const SizedBox(height: AppSpacing.xl),
                    const PhdSectionHeader(label: 'Plano'),
                    const SizedBox(height: AppSpacing.sm),
                    for (final p in widget.planos) _opcaoPlano(p),

                    if (_plano != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      const PhdSectionHeader(label: 'Cobranças'),
                      const SizedBox(height: AppSpacing.sm),
                      _primeiroVencimento(),
                      const SizedBox(height: AppSpacing.lg),
                      _quantosCiclos(),
                      const SizedBox(height: AppSpacing.lg),
                      _resumo(),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    PhdButton(
                      label: 'Criar assinatura',
                      icon: Icons.check_rounded,
                      loading: _salvando,
                      onPressed:
                          (_aluno == null || _plano == null) ? null : _salvar,
                    ),
                    if (_aluno == null || _plano == null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _aluno == null
                            ? 'Escolha o aluno.'
                            : 'Escolha o plano.',
                        textAlign: TextAlign.center,
                        style: AppText.caption(11.5,
                            color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seletorAluno() {
    if (_carregandoAlunos) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accent),
          ),
        ),
      );
    }
    if (_alunos.isEmpty) {
      return PhdAviso(
        texto: 'Nenhum aluno ativo. Cadastre um aluno antes de assinar.',
        icone: Icons.info_outline_rounded,
        cor: AppColors.warning,
        corTexto: AppColors.warningText,
      );
    }

    return PhdCard(
      onTap: _escolherAluno,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (_aluno != null)
            PhdAvatar(
              name: _aluno!['nome'] as String? ?? '',
              imageUrl: _aluno!['foto_url'] as String?,
              size: 34,
            )
          else
            Icon(Icons.person_outline_rounded,
                size: 20, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              _aluno?['nome'] as String? ?? 'Escolher aluno',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _aluno == null
                  ? AppText.body(14, color: AppColors.textMuted)
                  : AppText.bodyStrong(14),
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 19, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Future<void> _escolherAluno() async {
    final escolhido = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
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
              Text('Qual aluno?', style: AppText.title(16)),
              const SizedBox(height: AppSpacing.lg),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _alunos.length,
                  itemBuilder: (_, i) => PhdListRow(
                    title: _alunos[i]['nome'] as String? ?? 'Aluno',
                    leading: PhdAvatar(
                      name: _alunos[i]['nome'] as String? ?? '',
                      imageUrl: _alunos[i]['foto_url'] as String?,
                      size: 34,
                    ),
                    onTap: () => Navigator.pop(ctx, _alunos[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (escolhido != null && mounted) setState(() => _aluno = escolhido);
  }

  Widget _opcaoPlano(PlanoVenda p) {
    final ativo = _plano?.id == p.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PhdCard(
        accentBar: ativo ? AppColors.accent : null,
        onTap: () => setState(() {
          _plano = p;
          _ciclos = _ciclosSugeridos;
        }),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(
              ativo
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: ativo ? AppColors.accent : AppColors.textMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nome, style: AppText.bodyStrong(13.5)),
                  const SizedBox(height: 2),
                  Text(p.inclui,
                      style:
                          AppText.caption(11, color: AppColors.textMuted)),
                ],
              ),
            ),
            Text(p.preco, style: AppText.number(14)),
          ],
        ),
      ),
    );
  }

  Widget _primeiroVencimento() {
    return PhdCard(
      onTap: _escolherData,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(Icons.event_outlined,
              size: 19, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text('Primeiro vencimento', style: AppText.body(13.5)),
          ),
          Text(
            '${_vencimento.day.toString().padLeft(2, '0')}/'
            '${_vencimento.month.toString().padLeft(2, '0')}/${_vencimento.year}',
            style: AppText.number(13.5),
          ),
        ],
      ),
    );
  }

  Future<void> _escolherData() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _vencimento,
      firstDate: DateTime(hoje.year - 1),
      lastDate: DateTime(hoje.year + 3),
      builder: (ctx, filho) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: AppColors.onAccent,
            surface: AppColors.surfaceHigh,
          ),
        ),
        child: filho!,
      ),
    );
    if (d != null && mounted) setState(() => _vencimento = d);
  }

  Widget _quantosCiclos() {
    final p = _plano!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quantas cobranças gerar', style: AppText.caption(12.5)),
        const SizedBox(height: 7),
        PhdFilterBar(
          children: [
            for (final n in {1, _ciclosSugeridos, _ciclosSugeridos * 2}.toList()
              ..sort())
              PhdFilterChip(
                label: n == 1
                    ? '1 cobrança'
                    : '$n × ${p.periodicidadeNome.toLowerCase()}',
                selected: _ciclos == n,
                onTap: () => setState(() => _ciclos = n),
              ),
          ],
        ),
      ],
    );
  }

  Widget _resumo() {
    final p = _plano!;
    final ultima = _ciclos <= 1
        ? _vencimento
        : _somaMeses(_vencimento, (_ciclos - 1) * p.meses);

    return PhdCard(
      color: AppColors.surfaceHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _ciclos == 1
                      ? '1 cobrança de ${p.preco}'
                      : '$_ciclos cobranças de ${p.preco}',
                  style: AppText.bodyStrong(13.5),
                ),
              ),
              Text(Moeda.formatar(_totalCentavos),
                  style: AppText.number(15, color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _ciclos == 1
                ? 'Vence em ${_dataTexto(_vencimento)}.'
                : 'De ${_dataTexto(_vencimento)} até ${_dataTexto(ultima)}, '
                    'uma a cada ${p.meses == 1 ? 'mês' : '${p.meses} meses'}.',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  String _dataTexto(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  static DateTime _somaMeses(DateTime d, int meses) {
    final ano = d.year + ((d.month - 1 + meses) ~/ 12);
    final mes = ((d.month - 1 + meses) % 12) + 1;
    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    return DateTime(ano, mes, d.day > ultimoDia ? ultimoDia : d.day);
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await FinanceiroService.assinar(
        alunoId: _aluno!['id'].toString(),
        plano: _plano!,
        primeiroVencimento: _vencimento,
        quantasCobrancas: _ciclos,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content:
              Text('Não consegui criar: $e', style: AppText.body(13.5)),
        ),
      );
    }
  }
}
