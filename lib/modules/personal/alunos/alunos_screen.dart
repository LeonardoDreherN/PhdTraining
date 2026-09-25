import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/aluno.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/aluno_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

class AlunosScreen extends ConsumerStatefulWidget {
  const AlunosScreen({super.key});

  @override
  ConsumerState<AlunosScreen> createState() => _AlunosScreenState();
}

class _AlunosScreenState extends ConsumerState<AlunosScreen> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _abrirCadastro() async {
    await context.push('/alunos/adicionar');
    recarregarTudo(ref);
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(alunosProvider);
    final visiveis = ref.watch(alunosVisiveisProvider);
    final filtro = ref.watch(filtroAlunoProvider);
    final emAtencao = ref.watch(alunosEmAtencaoProvider);
    final total = estado.valueOrNull?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _cabecalho(total),
            _campoBusca(),
            const SizedBox(height: AppSpacing.md),
            _filtros(filtro, emAtencao),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: estado.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
                error: (e, _) => PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não consegui carregar',
                  message: '$e',
                  actionLabel: 'Tentar de novo',
                  onAction: () => ref.invalidate(alunosProvider),
                ),
                data: (_) => visiveis.isEmpty
                    ? _vazio(total, filtro)
                    : _lista(visiveis),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecalho(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('Alunos', style: AppText.display(28)),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              total == 0 ? '' : '$total',
              style: AppText.number(15, color: AppColors.textMuted),
            ),
          ),
          PhdButton(
            label: 'Novo',
            icon: Icons.add_rounded,
            size: PhdButtonSize.small,
            expand: false,
            onPressed: _abrirCadastro,
          ),
        ],
      ),
    );
  }

  Widget _campoBusca() {
    return Padding(
      padding: AppSpacing.screen,
      child: TextField(
        controller: _busca,
        onChanged: (v) => ref.read(buscaAlunoProvider.notifier).state = v,
        style: AppText.body(14.5),
        cursorColor: AppColors.accent,
        decoration: InputDecoration(
          hintText: 'Buscar por nome ou e-mail',
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textMuted, size: 19),
          suffixIcon: _busca.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted, size: 18),
                  onPressed: () {
                    _busca.clear();
                    ref.read(buscaAlunoProvider.notifier).state = '';
                    setState(() {});
                  },
                ),
        ),
      ),
    );
  }

  Widget _filtros(FiltroAluno atual, int emAtencao) {
    return PhdFilterBar(
      children: [
        for (final f in FiltroAluno.values)
          PhdFilterChip(
            label: f.rotulo,
            selected: atual == f,
            count: f == FiltroAluno.atencao && emAtencao > 0 ? emAtencao : null,
            tone: f == FiltroAluno.atencao ? PhdTone.danger : PhdTone.accent,
            onTap: () => ref.read(filtroAlunoProvider.notifier).state = f,
          ),
      ],
    );
  }

  Widget _lista(List<Aluno> alunos) {
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: () async {
        ref.invalidate(alunosProvider);
        await ref.read(alunosProvider.future);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge * 2,
        ),
        itemCount: alunos.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) => _linha(alunos[i]),
      ),
    );
  }

  Widget _linha(Aluno a) {
    final atencao = a.precisaAtencao;
    final corBarra = !a.ativo
        ? null
        : !a.temFicha
            ? AppColors.accent
            : atencao
                ? AppColors.warning
                : null;

    return PhdListRow(
      title: a.nome,
      subtitle: a.situacao,
      subtitleColor: !a.ativo
          ? AppColors.textMuted
          : atencao
              ? AppColors.warningText
              : null,
      accentBar: corBarra,
      leading: PhdAvatar(
        name: a.nome,
        imageUrl: a.fotoUrl,
        size: 42,
        ringColor: a.diasSemTreinar == 0 ? AppColors.accent : null,
      ),
      progress: a.adesao,
      progressColor: (a.adesao ?? 0) >= 0.8 ? AppColors.accent : AppColors.lineStrong,
      trailing: _acoes(a),
      onTap: () async {
        await context.push('/alunos/perfil', extra: a.mapa);
        recarregarTudo(ref);
      },
    );
  }

  Widget _acoes(Aluno a) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (a.adesao != null) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(a.adesao! * 100).round()}%',
                style: AppText.number(14,
                    color: a.adesao! >= 0.8 ? AppColors.accent : null),
              ),
              const SizedBox(height: 2),
              Text('adesão', style: AppText.caption(10)),
            ],
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        PopupMenuButton<String>(
          color: AppColors.surfaceHigh,
          surfaceTintColor: Colors.transparent,
          tooltip: 'Opções de ${a.nome}',
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
          icon: const Icon(Icons.more_vert_rounded,
              color: AppColors.textMuted, size: 20),
          onSelected: (v) => _acao(v, a),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(a.ativo ? 'Inativar' : 'Reativar',
                  style: AppText.body(14)),
            ),
            PopupMenuItem(
              value: 'deletar',
              child: Text('Excluir',
                  style: AppText.body(14, color: AppColors.dangerText)),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _acao(String acao, Aluno a) async {
    if (acao == 'toggle') {
      await AlunoService.alterarStatus(a.id, !a.ativo);
      recarregarTudo(ref);
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Excluir ${a.nome}?', style: AppText.title(17)),
        content: Text(
          // O aviso é específico porque a ação é irreversível e leva junto
          // coisas que a pessoa não associa ao botão que apertou.
          'Isso apaga também as avaliações, fotos de progresso e o histórico '
          'de treinos dele. Não dá para desfazer.\n\n'
          'Se a ideia é só parar de cobrar, use "Inativar".',
          style: AppText.body(13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Excluir',
                style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );

    if (confirmado != true) return;
    await AlunoService.deletar(a.id);
    if (mounted) recarregarTudo(ref);
  }

  Widget _vazio(int total, FiltroAluno filtro) {
    if (total == 0) {
      return PhdEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Nenhum aluno ainda',
        message: 'Cadastre o primeiro e ele já aparece aqui com treino, '
            'adesão e cobrança.',
        actionLabel: 'Cadastrar aluno',
        onAction: _abrirCadastro,
      );
    }

    final buscando = ref.read(buscaAlunoProvider).trim().isNotEmpty;

    return PhdEmptyState(
      icon: buscando ? Icons.search_off_rounded : Icons.filter_alt_off_rounded,
      title: buscando ? 'Nada encontrado' : 'Nenhum aluno em "${filtro.rotulo}"',
      message: buscando
          ? 'Nenhum aluno com esse nome ou e-mail.'
          : filtro == FiltroAluno.atencao
              ? 'Todo mundo em dia. É o que a gente quer ver.'
              : 'Troque o filtro para ver os outros.',
      actionLabel: buscando ? 'Limpar busca' : null,
      onAction: buscando
          ? () {
              _busca.clear();
              ref.read(buscaAlunoProvider.notifier).state = '';
              setState(() {});
            }
          : null,
    );
  }
}
