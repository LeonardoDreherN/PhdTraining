import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/conversa.dart';
import '../../../core/services/agenda_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../personal/agenda/agenda_screen.dart' show StatusConsultaTom, quandoConsulta;

/// A próxima consulta do aluno, com confirmar e remarcar num toque — e,
/// depois que uma consulta acontece, o pedido de avaliação.
///
/// Some quando não há nada a mostrar: aluno sem consulta marcada não
/// precisa de um cartão dizendo isso na home.
class CartaoConsulta extends StatefulWidget {
  const CartaoConsulta({super.key, required this.alunoId});

  final String alunoId;

  @override
  State<CartaoConsulta> createState() => _CartaoConsultaState();
}

class _CartaoConsultaState extends State<CartaoConsulta> {
  List<Consulta> _consultas = const [];
  bool _gravando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final c = await AgendaService.doAluno(widget.alunoId);
      if (!mounted) return;
      setState(() => _consultas = c);
      // Lembretes seguem a agenda: remarcou, o aviso acompanha.
      unawaited(NotificationService.agendarConsultas([
        for (final x in c)
          if (x.ativa && !x.passou) (titulo: x.tipo.rotulo, inicio: x.inicio),
      ]));
    } catch (_) {
      // Sem a tabela de consultas: a home segue sem o cartão.
    }
  }

  Future<void> _responder(Consulta c, bool confirmar) async {
    setState(() => _gravando = true);
    try {
      await AgendaService.responder(c.id, confirmar: confirmar);
      await _carregar();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          confirmar ? 'Presença confirmada.' : 'Avisamos seu profissional que você precisa remarcar.',
          style: AppText.body(13.5),
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui responder: $e', style: AppText.body(13.5))),
        );
      }
    } finally {
      if (mounted) setState(() => _gravando = false);
    }
  }

  Future<void> _avaliar(Consulta c) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _FolhaAvaliacao(consulta: c),
    );
    if (ok == true) await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final proxima = _consultas.where((c) => c.ativa && !c.passou && c.status != StatusConsulta.realizada).firstOrNull;
    final paraAvaliar = _consultas.reversed
        .where((c) => c.passou && c.ativa && c.nota == null)
        .firstOrNull;

    if (proxima == null && paraAvaliar == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (proxima != null) _proxima(proxima),
        if (paraAvaliar != null) ...[
          if (proxima != null) const SizedBox(height: AppSpacing.sm),
          PhdCard(
            onTap: () => _avaliar(paraAvaliar),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: AppColors.warning, size: 26),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Como foi sua consulta?', style: AppText.bodyStrong(14)),
                      Text('${paraAvaliar.tipo.rotulo} · ${quandoConsulta(paraAvaliar)}',
                          style: AppText.caption(12)),
                    ],
                  ),
                ),
                Text('Avaliar', style: AppText.bodyStrong(13, color: AppColors.accent)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _proxima(Consulta c) {
    final aguardando = c.status == StatusConsulta.agendada;
    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('PRÓXIMA CONSULTA', style: AppText.label())),
              PhdStatusChip(label: c.status.rotulo, tone: c.status.tom),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: AppColors.accent, borderRadius: AppRadius.rLg),
                child: Column(
                  children: [
                    Text(
                      const ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'][
                          c.inicio.month - 1],
                      style: AppText.caption(10.5, color: AppColors.onAccent),
                    ),
                    Text('${c.inicio.day}', style: AppText.number(20, color: AppColors.onAccent, weight: FontWeight.w800)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.tipo.rotulo, style: AppText.title(16)),
                    Text(
                      [quandoConsulta(c), '${c.duracaoMin} min', if (c.local != null) c.local!].join(' · '),
                      style: AppText.caption(12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (c.observacoes != null) ...[
            const SizedBox(height: AppSpacing.md),
            PhdAviso(
              texto: c.observacoes!,
              icone: Icons.info_outline_rounded,
              cor: AppColors.accent,
              corTexto: AppColors.textPrimary,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (c.link != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: PhdButton(
                label: 'Entrar na chamada',
                icon: Icons.videocam_rounded,
                size: PhdButtonSize.medium,
                onPressed: () => launchUrl(Uri.parse(c.link!), mode: LaunchMode.externalApplication),
              ),
            ),
          Row(
            children: [
              if (aguardando) ...[
                Expanded(
                  child: PhdButton(
                    label: 'Confirmar',
                    icon: Icons.check_rounded,
                    size: PhdButtonSize.medium,
                    loading: _gravando,
                    onPressed: () => _responder(c, true),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              if (c.status != StatusConsulta.remarcar)
                Expanded(
                  child: PhdButton(
                    label: 'Preciso remarcar',
                    variant: PhdButtonVariant.ghost,
                    size: PhdButtonSize.medium,
                    onPressed: _gravando ? null : () => _responder(c, false),
                  ),
                )
              else
                Expanded(
                  child: Text(
                    'Seu profissional vai combinar um novo horário com você.',
                    style: AppText.caption(12.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FolhaAvaliacao extends StatefulWidget {
  const _FolhaAvaliacao({required this.consulta});

  final Consulta consulta;

  @override
  State<_FolhaAvaliacao> createState() => _FolhaAvaliacaoState();
}

class _FolhaAvaliacaoState extends State<_FolhaAvaliacao> {
  int _nota = 0;
  final _comentario = TextEditingController();
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_nota == 0) {
      setState(() => _erro = 'Toque nas estrelas para dar a nota.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await AgendaService.avaliar(widget.consulta.id, _nota, _comentario.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não consegui enviar: $e';
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Como foi a consulta?', style: AppText.title(19)),
          const SizedBox(height: 4),
          Text('${widget.consulta.tipo.rotulo} · ${quandoConsulta(widget.consulta)}', style: AppText.caption(13)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
                  iconSize: 40,
                  onPressed: () => setState(() => _nota = i),
                  icon: Icon(
                    i <= _nota ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= _nota ? AppColors.warning : AppColors.lineStrong,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PhdField(
            controller: _comentario,
            label: 'Quer contar algo? (opcional)',
            hint: 'O que foi bom, o que pode melhorar',
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.md),
            PhdAviso(texto: _erro!),
          ],
          const SizedBox(height: AppSpacing.lg),
          PhdButton(label: 'Enviar avaliação', loading: _salvando, onPressed: _salvar),
        ],
      ),
    );
  }
}
