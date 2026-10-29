import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/perfil.dart';
import '../../../core/models/resumo_home.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/moeda.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/widgets/widgets.dart';

/// Home do personal.
///
/// Duas telas em uma. Conta nova cai no roteiro do que fazer primeiro —
/// mostrar "R$ 0,00" como número principal para quem ainda não tem aluno
/// não informa nada. Depois do primeiro aluno, vira painel no jeito de um
/// admin de loja: receita com a curva do semestre no topo, ações rápidas,
/// a semana dos alunos em números, a fila do que precisa de ação hoje, a
/// vitrine de alunos e o que acabou de acontecer.
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
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          PhdAvatar(
            name: perfil?.nomeExibicao ?? 'PHD',
            imageUrl: perfil?.avatarUrl,
            size: 46,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  [
                    saudacao(),
                    if (perfil?.marcaNome?.trim().isNotEmpty ?? false)
                      perfil!.marcaNome!.trim()
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(12.5),
                ),
                const SizedBox(height: 2),
                Text(
                  perfil?.primeiroNome ?? '...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(22),
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
                        ? Icon(Icons.check_rounded,
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
                    Icon(Icons.chevron_right_rounded,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: AppSpacing.screen, child: _receita()),
        const SizedBox(height: AppSpacing.xl),
        _acoes(context, ref),
        const SizedBox(height: AppSpacing.xxl),
        Padding(
          padding: AppSpacing.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PhdSectionHeader(label: 'Esta semana'),
              const SizedBox(height: AppSpacing.md),
              _semana(),
              const SizedBox(height: AppSpacing.sm),
              _indicadores(),
              if (resumo.pendencias.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                PhdSectionHeader(
                  label: 'Precisa de você',
                  trailing: '${resumo.pendencias.length}',
                  trailingColor: AppColors.warningText,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final p in resumo.pendencias) ...[
                  _pendencia(context, p),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
              for (final a in resumo.aniversarios) ...[
                const SizedBox(height: AppSpacing.sm),
                _aniversario(context, a.aluno, a.dia),
              ],
            ],
          ),
        ),
        if (resumo.alunos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          Padding(
            padding: AppSpacing.screen,
            child: PhdSectionHeader(
              label: 'Seus alunos',
              trailing: 'Ver todos',
              onTrailingTap: () => context.go('/alunos'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _carrossel(context, ref),
        ],
        if (resumo.recentes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          Padding(
            padding: AppSpacing.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PhdSectionHeader(label: 'Atividade recente'),
                const SizedBox(height: AppSpacing.md),
                _atividade(context, ref),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Receita ─────────────────────────────────────────────────

  /// O cartão de cima é o extrato: quanto entrou, a curva dos últimos
  /// seis meses e o que ainda está na rua. É a primeira coisa que um dono
  /// de negócio procura ao abrir o painel.
  Widget _receita() {
    final agora = DateTime.now();
    final variacao = resumo.variacaoReceita;
    final meses = resumo.receitaMeses.length == 6
        ? resumo.receitaMeses
        : List.filled(6, 0);
    final semHistorico = meses.every((m) => m == 0);
    final anterior = DateTime(agora.year, agora.month - 1);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            // Brilho azul no canto, sobre a própria superfície: a cor da
            // marca sem pintar o cartão inteiro.
            Color.alphaBlend(
              AppColors.accent.withValues(alpha: AppColors.ehClaro ? 0.10 : 0.18),
              AppColors.surface,
            ),
            AppColors.surface,
            AppColors.surface,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'RECEBIDO EM ${mesPorExtenso(agora).toUpperCase()}',
                  style: AppText.label(),
                ),
              ),
              if (variacao != null)
                _chipVariacao(
                    variacao, 'vs ${mesPorExtenso(anterior).substring(0, 3)}'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Moeda.formatarCurto(resumo.recebidoCentavos),
              style: AppText.display(40),
            ),
          ),
          if (semHistorico) ...[
            const SizedBox(height: 4),
            Text(
              'Os pagamentos dos seus alunos aparecem aqui.',
              style: AppText.caption(12.5),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          PhdBars(
            valores: meses,
            destaque: 5,
            altura: 56,
            rotulos: [
              for (var i = 5; i >= 0; i--)
                mesPorExtenso(DateTime(agora.year, agora.month - i))
                    .substring(0, 3),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _caixa(
                  'A receber',
                  Moeda.formatar(resumo.aReceberCentavos),
                  resumo.cobrancasAReceber == 0
                      ? 'Nada pendente'
                      : '${resumo.cobrancasAReceber} ${resumo.cobrancasAReceber == 1 ? 'cobrança' : 'cobranças'}',
                  null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _caixa(
                  'Atrasado',
                  Moeda.formatar(resumo.atrasadoCentavos),
                  resumo.cobrancasAtrasadas == 0
                      ? 'Tudo em dia'
                      : '${resumo.cobrancasAtrasadas} ${resumo.cobrancasAtrasadas == 1 ? 'aluno' : 'alunos'}',
                  resumo.atrasadoCentavos > 0 ? AppColors.dangerText : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipVariacao(double v, String contra) {
    final sobe = v >= 0;
    final cor = sobe ? AppColors.successText : AppColors.dangerText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tint(sobe ? AppColors.success : AppColors.danger),
        borderRadius: AppRadius.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sobe ? Icons.north_east_rounded : Icons.south_east_rounded,
              size: 12, color: cor),
          const SizedBox(width: 3),
          Text('${(v.abs() * 100).round()}% $contra',
              style: AppText.bodyStrong(11, color: cor)),
        ],
      ),
    );
  }

  Widget _caixa(String rotulo, String valor, String apoio, Color? cor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.55),
        borderRadius: AppRadius.rLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: AppText.caption(11.5)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: AppText.number(17, color: cor)),
          ),
          const SizedBox(height: 1),
          Text(apoio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // ── Ações rápidas ───────────────────────────────────────────

  Widget _acoes(BuildContext context, WidgetRef ref) {
    final itens = [
      (
        Icons.person_add_alt_1_rounded,
        'Novo aluno',
        () => _abrir(context, ref, '/alunos/adicionar'),
        true
      ),
      (
        Icons.edit_note_rounded,
        'Nova ficha',
        () => _abrir(context, ref, '/fichas'),
        false
      ),
      (
        Icons.menu_book_rounded,
        'Exercícios',
        () => _abrir(context, ref, '/exercicios'),
        false
      ),
      (
        Icons.insights_rounded,
        'Relatórios',
        () => context.go('/relatorios'),
        false
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          for (final (icone, rotulo, acao, destaque) in itens)
            Expanded(
              child: Semantics(
                button: true,
                label: rotulo,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: acao,
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color:
                              destaque ? AppColors.accent : AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: destaque
                              ? null
                              : Border.all(color: AppColors.line),
                        ),
                        child: Icon(
                          icone,
                          size: 24,
                          color: destaque
                              ? AppColors.onAccent
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(rotulo,
                          style: AppText.bodyStrong(11.5,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Semana ──────────────────────────────────────────────────

  Widget _semana() {
    final hoje = DateTime.now().weekday - 1;
    final quem = resumo.treinaramHoje;

    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${resumo.treinosNaSemana}', style: AppText.display(34)),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  resumo.treinosNaSemana == 1
                      ? 'treino concluído'
                      : 'treinos concluídos',
                  style: AppText.caption(13),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdBars(
            valores: resumo.treinosPorDia,
            destaque: hoje,
            altura: 48,
            rotulos: const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(height: 1, color: AppColors.line),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              if (quem.isNotEmpty) ...[
                _pilhaAvatares(quem),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Text(
                  switch (quem.length) {
                    0 => 'Ninguém treinou hoje ainda',
                    1 => '${quem.first.primeiroNome} treinou hoje',
                    2 =>
                      '${quem[0].primeiroNome} e ${quem[1].primeiroNome} treinaram hoje',
                    _ =>
                      '${quem.first.primeiroNome} e mais ${quem.length - 1} treinaram hoje',
                  },
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(12.5,
                      color: quem.isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Rostos sobrepostos — até quatro; o resto vira "+N".
  Widget _pilhaAvatares(List<AlunoResumo> alunos) {
    const tamanho = 32.0;
    const passo = tamanho * 0.74;
    final visiveis = alunos.take(4).toList();
    final extra = alunos.length - visiveis.length;
    final total = visiveis.length + (extra > 0 ? 1 : 0);

    return SizedBox(
      width: tamanho + (total - 1) * passo,
      height: tamanho,
      child: Stack(
        children: [
          for (final (i, a) in visiveis.indexed)
            Positioned(
              left: i * passo,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: PhdAvatar(
                    name: a.nome, imageUrl: a.fotoUrl, size: tamanho - 4),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: visiveis.length * passo,
              child: Container(
                width: tamanho,
                height: tamanho,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Text('+$extra', style: AppText.bodyStrong(10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _indicadores() {
    final adesao = resumo.adesaoSemana;
    final pct = (adesao * 100).round();

    // IntrinsicHeight + stretch: os dois cartões ficam da mesma altura
    // mesmo com textos de tamanhos diferentes.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PhdCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  PhdRing(
                    valor: adesao,
                    tamanho: 52,
                    espessura: 6,
                    cor: adesao >= 0.6
                        ? AppColors.accent
                        : adesao >= 0.3
                            ? AppColors.warning
                            : AppColors.danger,
                    child: Text('$pct%',
                        style: AppText.number(12.5, weight: FontWeight.w800)),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Adesão', style: AppText.bodyStrong(13.5)),
                        Text('treinaram em 7 dias',
                            maxLines: 2, style: AppText.caption(11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: PhdCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text('${resumo.alunosAtivos}',
                          style: AppText.number(26,
                              color: AppColors.accent,
                              weight: FontWeight.w800)),
                      const Spacer(),
                      if (resumo.novosNoMes > 0)
                        PhdStatusChip(
                            label: '+${resumo.novosNoMes} no mês',
                            tone: PhdTone.success),
                    ],
                  ),
                  Text(
                    resumo.alunosInativos == 0
                        ? 'alunos ativos'
                        : 'ativos · ${resumo.alunosInativos} inativos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(11.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Pendências ──────────────────────────────────────────────

  Widget _pendencia(BuildContext context, Pendencia p) {
    final (cor, icone) = switch (p.tipo) {
      TipoPendencia.mensalidadeAtrasada => (
          AppColors.danger,
          Icons.payments_rounded
        ),
      TipoPendencia.semTreinar => (AppColors.warning, Icons.snooze_rounded),
      TipoPendencia.semFicha => (AppColors.accent, Icons.edit_note_rounded),
    };
    final primeiro = p.alunoNome.split(' ').first;
    final mensagem = switch (p.tipo) {
      TipoPendencia.mensalidadeAtrasada =>
        'Oi $primeiro, tudo bem? Passando para lembrar da mensalidade'
            '${p.valorCentavos == null ? '' : ' de ${Moeda.formatar(p.valorCentavos!)}'}, que está em aberto.',
      TipoPendencia.semTreinar =>
        'Oi $primeiro, senti sua falta nos treinos! Está tudo bem? Bora voltar essa semana?',
      TipoPendencia.semFicha => null,
    };
    final zap = linkWhatsApp(p.whatsapp, mensagem: mensagem);

    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              PhdAvatar(name: p.alunoNome, imageUrl: p.avatarUrl, size: 44),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: cor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: Icon(icone, size: 10, color: AppColors.onAccent),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.alunoNome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong(14)),
                const SizedBox(height: 1),
                Text(
                  p.valorCentavos == null
                      ? p.detalhe
                      : '${p.detalhe} · ${Moeda.formatar(p.valorCentavos!)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(12),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _botaoAcao(
            rotulo: p.acao,
            icone: zap == null ? null : Icons.chat_rounded,
            onTap: zap == null
                ? () => context.go('/alunos')
                : () => _abrirLink(context, zap),
          ),
        ],
      ),
    );
  }

  Widget _botaoAcao(
      {required String rotulo, IconData? icone, required VoidCallback onTap}) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: AppRadius.rPill,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 14, color: AppColors.successText),
                const SizedBox(width: 6),
              ],
              Text(rotulo, style: AppText.bodyStrong(12.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aniversario(BuildContext context, AlunoResumo a, DateTime dia) {
    final hoje = DateTime.now();
    final faltam = DateTime(dia.year, dia.month, dia.day)
        .difference(DateTime(hoje.year, hoje.month, hoje.day))
        .inDays;
    final quando = switch (faltam) {
      0 => 'faz aniversário hoje',
      1 => 'faz aniversário amanhã',
      _ => 'faz aniversário ${_diaSemana(dia)}',
    };
    final zap = linkWhatsApp(
      a.whatsapp,
      mensagem:
          'Parabéns, ${a.primeiroNome}! Muita saúde e muitos treinos pela frente. 🎉',
    );

    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEC4899).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.cake_rounded,
                size: 22, color: Color(0xFFEC4899)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: a.primeiroNome, style: AppText.bodyStrong(13.5)),
                TextSpan(text: ' $quando', style: AppText.caption(13)),
              ]),
              maxLines: 2,
            ),
          ),
          if (zap != null) ...[
            const SizedBox(width: AppSpacing.sm),
            _botaoAcao(
                rotulo: faltam == 0 ? 'Parabenizar' : 'Lembrar',
                onTap: () => _abrirLink(context, zap)),
          ],
        ],
      ),
    );
  }

  static String _diaSemana(DateTime d) => const [
        'na segunda',
        'na terça',
        'na quarta',
        'na quinta',
        'na sexta',
        'no sábado',
        'no domingo',
      ][d.weekday - 1];

  // ── Alunos ──────────────────────────────────────────────────

  /// Vitrine horizontal, como a de produtos numa loja: o rosto primeiro.
  /// O anel acende em quem treinou nos últimos dois dias.
  Widget _carrossel(BuildContext context, WidgetRef ref) {
    final alunos = resumo.alunos.take(12).toList();

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screen,
        itemCount: alunos.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) {
          if (i == alunos.length) {
            return _itemCarrossel(
              topo: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.lineStrong),
                ),
                child: Icon(Icons.arrow_forward_rounded,
                    color: AppColors.textSecondary),
              ),
              nome: 'Ver todos',
              apoio: '${resumo.alunosAtivos} ativos',
              onTap: () => context.go('/alunos'),
            );
          }
          final a = alunos[i];
          final recente = a.ultimoTreino != null &&
              DateTime.now().difference(a.ultimoTreino!).inHours < 48;
          return _itemCarrossel(
            topo: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: recente ? AppColors.accent : AppColors.line,
                  width: 2,
                ),
              ),
              child: PhdAvatar(name: a.nome, imageUrl: a.fotoUrl, size: 51),
            ),
            nome: a.primeiroNome,
            apoio: _haQuanto(a.ultimoTreino),
            apoioCor: recente ? AppColors.accent : null,
            onTap: () async {
              await context.push('/alunos/perfil', extra: a.linha);
              ref.invalidate(resumoHomeProvider);
            },
          );
        },
      ),
    );
  }

  Widget _itemCarrossel({
    required Widget topo,
    required String nome,
    required String apoio,
    Color? apoioCor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 66,
        child: Column(
          children: [
            topo,
            const SizedBox(height: AppSpacing.sm),
            Text(nome,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong(12)),
            Text(apoio,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption(10.5,
                    color: apoioCor ?? AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  /// "agora", "há 3 h", "ontem", "há 4 d". Sem treino nos últimos 10 dias
  /// (a janela que a home consulta) vira "+10 d".
  static String _haQuanto(DateTime? d) {
    if (d == null) return '+10 d';
    final agora = DateTime.now();
    final diff = agora.difference(d);
    if (diff.inMinutes < 60) return 'agora';
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dias = hoje.difference(DateTime(d.year, d.month, d.day)).inDays;
    if (dias == 0) return 'há ${diff.inHours} h';
    if (dias == 1) return 'ontem';
    return 'há $dias d';
  }

  // ── Atividade ───────────────────────────────────────────────

  Widget _atividade(BuildContext context, WidgetRef ref) {
    return PhdCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          for (final (i, t) in resumo.recentes.indexed) ...[
            if (i > 0) Divider(height: 1, color: AppColors.line),
            InkWell(
              onTap: () async {
                await context.push('/alunos/perfil', extra: t.aluno.linha);
                ref.invalidate(resumoHomeProvider);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Row(
                  children: [
                    PhdAvatar(
                        name: t.aluno.nome,
                        imageUrl: t.aluno.fotoUrl,
                        size: 36),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: t.aluno.primeiroNome,
                                  style: AppText.bodyStrong(13)),
                              TextSpan(
                                  text: ' concluiu ',
                                  style: AppText.caption(13)),
                              TextSpan(
                                  text: t.fichaNome,
                                  style: AppText.bodyStrong(13)),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            [
                              _haQuanto(t.quando),
                              if (t.minutos != null && t.minutos! > 0)
                                '${t.minutos} min',
                            ].join(' · '),
                            style: AppText.caption(11.5,
                                color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle_rounded,
                        size: 18, color: AppColors.success),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _abrirLink(BuildContext context, Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui abrir o WhatsApp.')),
      );
    }
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
        AppSpacing.xl,
        AppSpacing.huge,
        AppSpacing.xl,
        AppSpacing.xl,
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
