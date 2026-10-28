import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/avaliacao.dart';
import '../../../core/services/avaliacao_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';
import '../avaliacao/avaliacao_widgets.dart';
import 'avaliacao_anamnese_view_screen.dart';

/// Entrada da avaliação física de um aluno: as avaliações feitas, a
/// próxima, e o botão de começar uma nova.
///
/// Antes esta tela era um menu de categorias com FC de repouso e VO₂máx
/// soltos embaixo, sem data — não dava para saber de quando era o número.
/// Agora tudo isso mora dentro da sessão do dia.
class AvaliacaoScreen extends StatefulWidget {
  const AvaliacaoScreen({super.key, required this.aluno});

  final Map<String, dynamic> aluno;

  @override
  State<AvaliacaoScreen> createState() => _AvaliacaoScreenState();
}

class _AvaliacaoScreenState extends State<AvaliacaoScreen> {
  List<ResumoSessao> _sessoes = [];
  bool _carregando = true;
  String? _erro;

  String get _alunoId => widget.aluno['id'] as String;
  String get _nome => widget.aluno['nome'] as String? ?? 'Aluno';

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
      final lista = await AvaliacaoService.listar(_alunoId);
      if (mounted) setState(() => _sessoes = lista);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrir(DateTime data) async {
    await context.push('/alunos/avaliacao/sessao', extra: alunoNaSessao(widget.aluno, data));
    _carregar();
  }

  Future<void> _outraData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      helpText: 'Data da avaliação',
    );
    if (escolhida != null) _abrir(escolhida);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: appBarAvaliacao(_nome, 'Avaliação física'),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _erro != null
              ? PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não deu para carregar',
                  message: 'Se o banco ainda não tem a migration 0008, rode-a no '
                      'Supabase e tente de novo.\n\n$_erro',
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
                      if (_proximaCard() case final card?) ...[
                        card,
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      PhdButton(
                        label: _temHoje ? 'Continuar avaliação de hoje' : 'Nova avaliação',
                        icon: _temHoje ? Icons.arrow_forward_rounded : Icons.add_rounded,
                        onPressed: () => _abrir(DateTime.now()),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PhdButton(
                        label: 'Registrar em outra data',
                        variant: PhdButtonVariant.ghost,
                        size: PhdButtonSize.medium,
                        onPressed: _outraData,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      PhdSectionHeader(
                        label: 'Avaliações',
                        trailing: _sessoes.isEmpty ? null : '${_sessoes.length}',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_sessoes.isEmpty)
                        PhdCard(
                          child: Text(
                            'Nenhuma avaliação ainda. Uma avaliação junta tudo o que '
                            'for medido no mesmo dia: medidas, composição corporal, '
                            'testes físicos, cardio e postura.',
                            style: AppText.body(13.5, color: AppColors.textSecondary),
                          ),
                        )
                      else
                        for (final (i, s) in _sessoes.indexed) ...[
                          _linhaSessao(s, i),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      const SizedBox(height: AppSpacing.xxl),
                      const PhdSectionHeader(label: 'Histórico de saúde'),
                      const SizedBox(height: AppSpacing.md),
                      PhdListRow(
                        title: 'Anamnese',
                        subtitle: 'Respostas do aluno sobre saúde e hábitos',
                        leading: const _Icone(Icons.assignment_outlined),
                        trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AvaliacaoAnamneseViewScreen(aluno: widget.aluno),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  bool get _temHoje =>
      _sessoes.any((s) => Datas.dia(s.sessao.data) == Datas.dia(DateTime.now()));

  Widget? _proximaCard() {
    if (_sessoes.isEmpty) return null;
    final proxima = _sessoes.first.sessao.proximaAvaliacao;
    if (proxima == null) return null;
    final dias = Datas.dia(proxima).difference(Datas.dia(DateTime.now())).inDays;
    final (texto, tom) = dias < 0
        ? ('Atrasada há ${-dias} ${-dias == 1 ? 'dia' : 'dias'}', PhdTone.danger)
        : dias == 0
            ? ('É hoje', PhdTone.accent)
            : dias <= 7
                ? ('Em $dias ${dias == 1 ? 'dia' : 'dias'}', PhdTone.warning)
                : ('Em $dias dias', PhdTone.neutral);
    return PhdCard(
      accentBar: tom == PhdTone.neutral ? null : tom.solid,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PRÓXIMA AVALIAÇÃO', style: AppText.label()),
                const SizedBox(height: 4),
                Text(Datas.longa(proxima), style: AppText.title(18)),
              ],
            ),
          ),
          PhdStatusChip(label: texto, tone: tom),
        ],
      ),
    );
  }

  Widget _linhaSessao(ResumoSessao s, int i) {
    // A lista vem da mais nova para a mais antiga: a "anterior" desta é a
    // próxima da lista.
    final anterior = i + 1 < _sessoes.length ? _sessoes[i + 1] : null;
    final delta = deltaBr(s.percGordura, anterior?.percGordura);
    final partes = [
      s.testes == 0 ? 'Sem testes' : '${s.testes} ${s.testes == 1 ? 'teste' : 'testes'}',
      if (s.peso != null) '${numBr(s.peso)} kg',
    ];
    return PhdListRow(
      title: Datas.longa(s.sessao.data),
      subtitle: partes.join(' · '),
      leading: _Icone(Icons.event_note_rounded, destaque: i == 0),
      trailingValue: s.percGordura == null ? null : '${numBr(s.percGordura)}%',
      trailingLabel: s.percGordura == null
          ? null
          : delta == null || delta == '='
              ? 'gordura'
              : '$delta pp',
      trailingValueColor: delta == null || delta == '='
          ? null
          : delta.startsWith('−')
              ? AppColors.successText
              : AppColors.warningText,
      trailing: s.percGordura == null
          ? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)
          : null,
      onTap: () => _abrir(s.sessao.data),
    );
  }
}

class _Icone extends StatelessWidget {
  const _Icone(this.icone, {this.destaque = false});
  final IconData icone;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: destaque ? AppColors.tint(AppColors.accent) : AppColors.surfaceHigh,
        borderRadius: AppRadius.rMd,
      ),
      child: Icon(icone, size: 20, color: destaque ? AppColors.accent : AppColors.textSecondary),
    );
  }
}
