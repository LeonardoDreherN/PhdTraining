import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/perfil.dart';
import '../../../core/models/resumo_home.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/moeda.dart';
import '../../../core/widgets/widgets.dart';

/// Home do personal.
///
/// Duas telas em uma. Conta nova cai no roteiro do que fazer primeiro —
/// mostrar "R$ 0,00" como número principal para quem ainda não tem aluno
/// não informa nada. Depois do primeiro aluno, vira painel: dinheiro no
/// topo e uma fila do que precisa de ação hoje.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilProvider).valueOrNull;
    final resumo = ref.watch(resumoHomeProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(perfilProvider);
            ref.invalidate(resumoHomeProvider);
            await ref.read(resumoHomeProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.huge * 2),
            children: [
              _Cabecalho(perfil: perfil),
              const SizedBox(height: AppSpacing.sm),
              resumo.when(
                loading: () => const _Carregando(),
                error: (e, _) => _Erro(
                  erro: e,
                  aoTentar: () => ref.invalidate(resumoHomeProvider),
                ),
                data: (r) => r.primeiroAcesso
                    ? _PrimeiroAcesso(perfil: perfil, resumo: r)
                    : _Painel(resumo: r),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre uma tela e recarrega a home ao voltar.
///
/// Um `FutureProvider` guarda o resultado até alguém invalidar. Sem isto,
/// cadastrar um aluno e voltar mostrava a home antiga — o dado estava no
/// banco, mas a tela ainda exibia a resposta de antes.
Future<void> _abrir(BuildContext context, WidgetRef ref, String rota) async {
  await context.push(rota);
  ref.invalidate(resumoHomeProvider);
  ref.invalidate(perfilProvider);
}

// ══════════════════════════════════════════════════════════════
//  Cabeçalho
// ══════════════════════════════════════════════════════════════

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({this.perfil});

  final Perfil? perfil;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md,
      ),
      child: Row(
        children: [
          PhdAvatar(
            name: perfil?.nomeExibicao ?? 'PHD',
            imageUrl: perfil?.avatarUrl,
            size: 42,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(saudacao(), style: AppText.caption(12.5)),
                const SizedBox(height: 1),
                Text(
                  perfil?.primeiroNome ?? '...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(17),
                ),
              ],
            ),
          ),
          PhdIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notificações',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Conta nova — o que fazer primeiro
// ══════════════════════════════════════════════════════════════

class _PrimeiroAcesso extends ConsumerWidget {
  const _PrimeiroAcesso({this.perfil, required this.resumo});

  final Perfil? perfil;
  final ResumoHome resumo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilCompleto = (perfil?.nome?.trim().isNotEmpty ?? false);
    final passos = [
      (
        'Complete seu perfil',
        'Seu nome e sua foto aparecem para os alunos',
        perfilCompleto,
        '/perfil',
      ),
      (
        'Cadastre seu primeiro aluno',
        'É a partir dele que tudo começa',
        resumo.totalAlunos > 0,
        '/alunos/adicionar',
      ),
      (
        'Monte a primeira ficha',
        'Escolha os exercícios e atribua ao aluno',
        resumo.temFicha,
        '/fichas',
      ),
    ];

    final feitos = passos.where((p) => p.$3).length;

    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text('Vamos começar', style: AppText.display(30)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Três passos e seu primeiro aluno já está treinando.',
            style: AppText.body(14.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),

          PhdSegments(total: passos.length, filled: feitos),
          const SizedBox(height: AppSpacing.xxl),

          for (final (titulo, descricao, feito, rota) in passos) ...[
            PhdCard(
              onTap: feito ? null : () => _abrir(context, ref, rota),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: feito ? AppColors.accent : Colors.transparent,
                      border: feito
                          ? null
                          : Border.all(color: AppColors.lineStrong, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                    child: feito
                        ? const Icon(Icons.check_rounded,
                            size: 16, color: AppColors.onAccent)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titulo,
                          style: AppText.bodyStrong(14.5,
                              color: feito
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(descricao, style: AppText.caption(12)),
                      ],
                    ),
                  ),
                  if (!feito)
                    const Icon(Icons.chevron_right_rounded,
                        size: 20, color: AppColors.textMuted),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
          ],

          const SizedBox(height: AppSpacing.lg),
          PhdButton(
            label: 'Cadastrar aluno',
            icon: Icons.add_rounded,
            onPressed: () => _abrir(context, ref, '/alunos/adicionar'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Painel — quando já há alunos
// ══════════════════════════════════════════════════════════════

class _Painel extends ConsumerWidget {
  const _Painel({required this.resumo});

  final ResumoHome resumo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heroFinanceiro(context),
          const SizedBox(height: AppSpacing.xxl),
          _atalhos(context, ref),
          if (resumo.pendencias.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xxl),
            PhdSectionHeader(
              label: 'Precisa de você',
              trailing: '${resumo.pendencias.length}',
            ),
            const SizedBox(height: AppSpacing.md),
            for (final p in resumo.pendencias) ...[
              _linhaPendencia(context, p),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          const SizedBox(height: AppSpacing.xxl),
          _blocoAlunos(context),
        ],
      ),
    );
  }

  Widget _heroFinanceiro(BuildContext context) {
    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.lg + 2),
      radius: AppRadius.rXxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhdStat(
            label: 'Recebido em ${mesPorExtenso(DateTime.now())}',
            value: Moeda.formatarCurto(resumo.recebidoCentavos),
            valueSize: 36,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(color: AppColors.line),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _mini(
                  'A receber',
                  Moeda.formatar(resumo.aReceberCentavos),
                  null,
                ),
              ),
              Container(width: 1, height: 34, color: AppColors.line),
              Expanded(
                child: _mini(
                  resumo.cobrancasAtrasadas == 0
                      ? 'Atrasado'
                      : 'Atrasado · ${resumo.cobrancasAtrasadas}',
                  Moeda.formatar(resumo.atrasadoCentavos),
                  resumo.atrasadoCentavos > 0 ? AppColors.dangerText : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String rotulo, String valor, Color? cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rotulo, style: AppText.caption(11.5)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(valor, style: AppText.number(17, color: cor)),
        ),
      ],
    );
  }

  Widget _atalhos(BuildContext context, WidgetRef ref) {
    final itens = [
      (Icons.person_add_alt_1_rounded, 'Aluno', '/alunos/adicionar', true),
      (Icons.fitness_center_rounded, 'Ficha', '/fichas', false),
      (Icons.menu_book_rounded, 'Exercícios', '/exercicios', false),
    ];

    return Row(
      children: [
        for (final (icone, rotulo, rota, destaque) in itens) ...[
          Expanded(
            child: PhdCard(
              onTap: () => _abrir(context, ref, rota),
              color: destaque ? AppColors.accent : AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone,
                      size: 21,
                      color: destaque ? AppColors.onAccent : AppColors.textPrimary),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    rotulo,
                    style: AppText.bodyStrong(11.5,
                        color: destaque ? AppColors.onAccent : AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          if (rotulo != itens.last.$2) const SizedBox(width: AppSpacing.sm + 2),
        ],
      ],
    );
  }

  Widget _linhaPendencia(BuildContext context, Pendencia p) {
    final cor = switch (p.tipo) {
      TipoPendencia.mensalidadeAtrasada => AppColors.danger,
      TipoPendencia.semTreinar => AppColors.warning,
      TipoPendencia.semFicha => AppColors.accent,
    };

    final detalhe = p.valorCentavos == null
        ? p.detalhe
        : '${p.detalhe} · ${Moeda.formatar(p.valorCentavos!)}';

    return PhdListRow(
      title: p.alunoNome,
      subtitle: detalhe,
      accentBar: cor,
      leading: PhdAvatar(name: p.alunoNome, imageUrl: p.avatarUrl, size: 38),
      trailing: PhdButton(
        label: p.acao,
        variant: PhdButtonVariant.ghost,
        size: PhdButtonSize.small,
        expand: false,
        onPressed: () => context.go('/alunos'),
      ),
    );
  }

  Widget _blocoAlunos(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhdSectionHeader(
          label: 'Alunos',
          trailing: 'Ver todos',
          onTrailingTap: () => context.go('/alunos'),
        ),
        const SizedBox(height: AppSpacing.md),
        PhdCard(
          onTap: () => context.go('/alunos'),
          child: Row(
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Ativos',
                  value: '${resumo.alunosAtivos}',
                  valueSize: 26,
                  valueColor: AppColors.accent,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.line),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: PhdStat(
                  label: 'Inativos',
                  value: '${resumo.alunosInativos}',
                  valueSize: 26,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Estados de carga e erro
// ══════════════════════════════════════════════════════════════

class _Carregando extends StatelessWidget {
  const _Carregando();

  @override
  Widget build(BuildContext context) {
    // Blocos do tamanho do conteúdo real em vez de spinner: a tela não
    // "pula" quando os dados chegam.
    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bloco(148, AppRadius.xxl),
          const SizedBox(height: AppSpacing.xxl),
          _bloco(74, AppRadius.xl),
          const SizedBox(height: AppSpacing.xxl),
          _bloco(66, AppRadius.xl),
          const SizedBox(height: AppSpacing.sm),
          _bloco(66, AppRadius.xl),
        ],
      ),
    );
  }

  Widget _bloco(double altura, double raio) => Container(
        height: altura,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(raio),
        ),
      );
}

class _Erro extends StatelessWidget {
  const _Erro({required this.erro, required this.aoTentar});

  final Object erro;
  final VoidCallback aoTentar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.huge, AppSpacing.xl, AppSpacing.xl,
      ),
      child: PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        // A mensagem crua fica visível de propósito: sem ela, "algo deu
        // errado" obriga a abrir o DevTools para descobrir qualquer coisa.
        message: '$erro',
        actionLabel: 'Tentar de novo',
        onAction: aoTentar,
      ),
    );
  }
}
