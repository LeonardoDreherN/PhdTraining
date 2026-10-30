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
            if (estado.valueOrNull?.isNotEmpty ?? false) ...[
              _resumo(estado.valueOrNull!),
              const SizedBox(height: AppSpacing.md),
            ],
            _campoBusca(),
            const SizedBox(height: AppSpacing.md),
            _filtros(filtro, emAtencao),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: estado.when(
                loading: () => Center(
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
          prefixIcon: Icon(Icons.search_rounded,
              color: AppColors.textMuted, size: 19),
          suffixIcon: _busca.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: Icon(Icons.close_rounded,
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

  /// Três números no topo, que também são atalhos: tocar filtra a lista.
  Widget _resumo(List<Aluno> todos) {
    final ativos = todos.where((a) => a.ativo).length;
    final hoje = todos.where((a) => a.ativo && a.diasSemTreinar == 0).length;
    final atencao = todos.where((a) => a.precisaAtencao).length;

    Widget item(String valor, String rotulo, Color cor, FiltroAluno? filtro) => Expanded(
          child: PhdCard(
            onTap: filtro == null ? null : () => ref.read(filtroAlunoProvider.notifier).state = filtro,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(valor, style: AppText.number(20, weight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(rotulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(11.5)),
              ],
            ),
          ),
        );

    return Padding(
      padding: AppSpacing.screen,
      child: Row(
        children: [
          item('$ativos', 'ativos', AppColors.success, FiltroAluno.ativos),
          const SizedBox(width: AppSpacing.sm),
          item('$hoje', 'treinaram hoje', AppColors.accent, null),
          const SizedBox(width: AppSpacing.sm),
          item('$atencao', 'atenção', AppColors.warning, FiltroAluno.atencao),
        ],
      ),
    );
  }

  /// A linha do aluno: rosto, situação e adesão. O que antes ia numa faixa
  /// vermelha na borda agora é o ícone e a cor da linha de situação — a
  /// faixa competia com a cor da marca e fazia a lista inteira parecer alerta.
  Widget _linha(Aluno a) {
    final d = a.diasSemTreinar;
    final (icone, cor) = !a.ativo
        ? (Icons.pause_circle_outline_rounded, AppColors.textMuted)
        : !a.temFicha
            ? (Icons.assignment_late_outlined, AppColors.warningText)
            : d == 0
                ? (Icons.check_circle_rounded, AppColors.successText)
                : a.precisaAtencao
                    ? (Icons.schedule_rounded, AppColors.warningText)
                    : (Icons.history_rounded, AppColors.textSecondary);
    final etiquetas = [
      if ((a.grupo ?? '').isNotEmpty) a.grupo!,
      if (a.semAcesso) 'sem app',
    ];

    return GestureDetector(
      onLongPress: () => _opcoes(a),
      child: PhdCard(
        onTap: () async {
          await context.push('/alunos/perfil', extra: a.mapa);
          recarregarTudo(ref);
        },
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Opacity(
              opacity: a.ativo ? 1 : 0.5,
              child: PhdAvatar(
                name: a.nome,
                imageUrl: a.fotoUrl,
                size: 52,
                ringColor: d == 0 && a.ativo ? AppColors.accent : null,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong(15,
                        color: a.ativo ? AppColors.textPrimary : AppColors.textMuted),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(icone, size: 14, color: cor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(a.situacao,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(12.5, color: cor)),
                      ),
                    ],
                  ),
                  if (etiquetas.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final e in etiquetas)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.rPill),
                            child: Text(e, style: AppText.caption(10.5)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (a.adesao != null)
              PhdRing(
                valor: a.adesao!,
                tamanho: 44,
                espessura: 4.5,
                cor: a.adesao! >= 0.6
                    ? AppColors.success
                    : a.adesao! >= 0.3
                        ? AppColors.warning
                        : AppColors.danger,
                child: Text('${(a.adesao! * 100).round()}%', style: AppText.number(10.5, weight: FontWeight.w800)),
              ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  /// Segurar a linha abre as ações rápidas — as mesmas do menu do perfil.
  Future<void> _opcoes(Aluno a) async {
    final acao = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(a.ativo ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                  color: AppColors.textSecondary),
              title: Text(a.ativo ? 'Inativar ${a.nome.split(' ').first}' : 'Reativar ${a.nome.split(' ').first}',
                  style: AppText.body(14.5)),
              onTap: () => Navigator.pop(ctx, 'toggle'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: AppColors.dangerText),
              title: Text('Excluir', style: AppText.body(14.5, color: AppColors.dangerText)),
              onTap: () => Navigator.pop(ctx, 'deletar'),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (acao != null) await _acao(acao, a);
  }

  Future<void> _acao(String acao, Aluno a) async {
    if (acao == 'toggle') {
      await AlunoService.alterarStatus(a.id, !a.ativo);
      recarregarTudo(ref);
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
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
