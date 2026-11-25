import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/conquista.dart';
import '../../../core/services/conquista_service.dart';
import '../../../core/services/feed_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Recordes e conquistas do aluno.
///
/// As medalhas premiam **consistência em relação à própria programação**,
/// não volume: quem treina três vezes por semana e cumpre as três vale
/// igual a quem treina cinco e cumpre as cinco. Era o critério central do
/// documento, e é o que impede a medalha de virar prêmio para quem tem
/// mais tempo livre.
class RecordesScreen extends StatefulWidget {
  const RecordesScreen({
    super.key,
    required this.alunoId,
    this.categoria = CategoriaConquista.treino,
  });

  final String alunoId;

  /// Treino ou nutrição. A tela é a mesma de propósito: a especificação
  /// pede o visual alinhado entre as duas, e duas telas iguais mantidas
  /// à mão divergem na primeira mudança.
  final CategoriaConquista categoria;

  bool get _ehTreino => categoria == CategoriaConquista.treino;

  @override
  State<RecordesScreen> createState() => _RecordesScreenState();
}

class _RecordesScreenState extends State<RecordesScreen> {
  NumerosDoAluno _n = const NumerosDoAluno();
  Set<String> _tenho = const {};
  Map<String, DateTime> _quando = const {};

  bool _carregando = true;
  Object? _erro;

  /// Opt-in: nasce falso e só vira verdadeiro se o aluno disser.
  bool _compartilha = false;
  bool _mudandoCompartilhamento = false;

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
      // Concede antes de ler: se o aluno bateu um marco e ninguém
      // recalculou, a medalha apareceria só na próxima vez que ele
      // concluísse um treino.
      await ConquistaService.conceder(widget.alunoId);

      final (numeros, minhas) = await (
        ConquistaService.numeros(widget.alunoId),
        ConquistaService.doAluno(widget.alunoId),
      ).wait;

      final compartilha =
          await FeedService.compartilhaConquistas(widget.alunoId);

      if (!mounted) return;
      setState(() {
        _n = numeros;
        _tenho = {for (final c in minhas) c.codigo};
        _quando = {for (final c in minhas) c.codigo: c.desbloqueadoEm};
        _compartilha = compartilha;
      });
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget._ehTreino ? 'Recordes' : 'Conquistas da dieta',
          style: AppText.title(16),
        ),
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: '$_erro',
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }

    final catalogo = Conquista.de(widget.categoria);
    final conquistadas = catalogo.where((c) => _tenho.contains(c.codigo)).toList();
    final proximas = catalogo.where((c) => !_tenho.contains(c.codigo)).toList()
      ..sort((a, b) => b.progresso(_n).compareTo(a.progresso(_n)));

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge * 2,
        ),
        children: [
          widget._ehTreino ? _numeros() : _numerosNutricao(),
          if (widget._ehTreino) ...[
            const SizedBox(height: AppSpacing.xl),
            _desbloqueios(),
          ],

          const SizedBox(height: AppSpacing.xl),
          PhdSectionHeader(
            label: 'Conquistadas',
            trailing: '${conquistadas.length} de ${catalogo.length}',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (conquistadas.isEmpty)
            PhdAviso(
              texto: 'Sua primeira medalha vem no primeiro treino concluído.',
              icone: Icons.emoji_events_outlined,
              cor: AppColors.accent,
              corTexto: AppColors.accent,
            )
          else
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final c in conquistadas) _medalha(c, _quando[c.codigo]),
              ],
            ),

          const SizedBox(height: AppSpacing.xl),
          _compartilhamento(),

          if (proximas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const PhdSectionHeader(label: 'Próximas'),
            const SizedBox(height: AppSpacing.sm),
            // As mais perto primeiro: "faltam 3" motiva, "faltam 480" não.
            for (final c in proximas.take(4)) _proxima(c),
          ],
        ],
      ),
    );
  }

  // ── Números ─────────────────────────────────────────────────

  Widget _numeros() {
    return PhdCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Treinos concluídos',
                  value: '${_n.treinos}',
                  valueSize: 30,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: 'Semanas completas',
                  value: '${_n.semanasCompletas}',
                  valueSize: 30,
                  valueColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.line, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Melhor sequência',
                  value: _n.sequenciaSemanas == 1
                      ? '1 semana'
                      : '${_n.sequenciaSemanas} semanas',
                  valueSize: 16,
                  valueColor: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: 'Dias seguidos',
                  value: '${_n.sequenciaDias}',
                  valueSize: 16,
                  valueColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (_n.diasPrevistos == 0) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              // Sem ficha não há denominador: dizer "0 semanas completas"
              // culparia o aluno por algo que é tarefa do personal.
              'Semana completa depende de ter uma ficha com dias marcados.',
              style: AppText.caption(11.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Os três indicadores que a especificação pede no menu de dieta:
  /// dias no plano, registros fotográficos e pesagens semanais.
  Widget _numerosNutricao() {
    return PhdCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Dias no plano',
                  value: '${_n.diasPlanoCompleto}',
                  valueSize: 30,
                ),
              ),
              Expanded(
                child: PhdStat(
                  // Fotos de ACOMPANHAMENTO, não as do diário de
                  // refeição: é o indicador que a especificação pede, e
                  // é a mesma fonte das conquistas de foto.
                  label: 'Meses com foto',
                  value: '${_n.mesesComFoto}',
                  valueSize: 30,
                  valueColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.line, height: 1),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PhdStat(
                  // Semanas com registro, não quilos perdidos: a
                  // conquista é sobre constância, nunca sobre o número
                  // da balança.
                  label: 'Semanas pesando',
                  value: '${_n.semanasComPeso}',
                  valueSize: 16,
                  valueColor: AppColors.textSecondary,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: 'Melhor sequência',
                  value: _n.sequenciaDiasPlano == 1
                      ? '1 dia'
                      : '${_n.sequenciaDiasPlano} dias',
                  valueSize: 16,
                  valueColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Dias no plano somam, não precisam ser seguidos — um dia fora '
            'não apaga o que já foi.',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _desbloqueios() {
    return PhdCard(
      onTap: () => context.push('/aluno/desbloqueios',
          extra: {'alunoId': widget.alunoId}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Exercícios desbloqueados',
                    style: AppText.bodyStrong(14)),
              ),
              Text('${_n.exercicios}', style: AppText.number(17)),
              Text(' / ${_n.catalogo}',
                  style: AppText.caption(12, color: AppColors.textMuted)),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  size: 19, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PhdProgressBar(value: _n.progressoCatalogo, height: 8),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Cada exercício que seu professor prescreve entra na sua '
            'biblioteca e fica.',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// O consentimento do aluno para o feed.
  ///
  /// Começa desligado e fica desligado até ele ligar. A especificação
  /// exige escolha explícita, e o jeito de respeitar isso é não publicar
  /// nada até o sim — não publicar e oferecer um botão de parar.
  ///
  /// Fica aqui, junto das medalhas, porque é aqui que a pergunta faz
  /// sentido: ele acabou de ver o que conquistou.
  Widget _compartilhamento() {
    return PhdCard(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            _compartilha ? Icons.visibility_rounded : Icons.lock_outline_rounded,
            size: 18,
            color: _compartilha ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Mostrar na comunidade',
                    style: AppText.bodyStrong(13.5)),
                const SizedBox(height: 2),
                Text(
                  _compartilha
                      ? 'Suas medalhas aparecem no feed. Peso, medidas e '
                          'fotos nunca aparecem.'
                      : 'Suas conquistas ficam só para você.',
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: _compartilha,
            activeThumbColor: AppColors.accent,
            onChanged: _mudandoCompartilhamento ? null : _mudarCompartilhamento,
          ),
        ],
      ),
    );
  }

  Future<void> _mudarCompartilhamento(bool valor) async {
    final antes = _compartilha;
    setState(() {
      _compartilha = valor;
      _mudandoCompartilhamento = true;
    });
    try {
      await FeedService.definirCompartilhamento(widget.alunoId, valor);
    } catch (e) {
      if (!mounted) return;
      // Desfaz: deixar marcado o que não gravou faria o aluno achar que
      // autorizou — ou que parou de autorizar — sem ter acontecido.
      setState(() => _compartilha = antes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não consegui salvar: $e', style: AppText.body(13.5)),
        ),
      );
    } finally {
      if (mounted) setState(() => _mudandoCompartilhamento = false);
    }
  }

  // ── Medalhas ────────────────────────────────────────────────

  Widget _medalha(Conquista c, DateTime? quando) {
    return SizedBox(
      width: 104,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent,
                  AppColors.accent.withValues(alpha: 0.55),
                ],
              ),
            ),
            child: Icon(c.icone, size: 28, color: AppColors.onAccent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(c.nome,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong(12.5)),
          if (quando != null) ...[
            const SizedBox(height: 2),
            Text(
              '${quando.day.toString().padLeft(2, '0')}/'
              '${quando.month.toString().padLeft(2, '0')}/${quando.year}',
              style: AppText.caption(10.5, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _proxima(Conquista c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PhdCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceHigh,
              ),
              child: Icon(c.icone, size: 19, color: AppColors.textMuted),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.nome, style: AppText.bodyStrong(13.5)),
                  const SizedBox(height: 2),
                  Text(c.descricao,
                      style:
                          AppText.caption(11.5, color: AppColors.textMuted)),
                  const SizedBox(height: 7),
                  PhdProgressBar(value: c.progresso(_n), height: 5),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(c.progressoTexto(_n),
                style: AppText.number(12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
