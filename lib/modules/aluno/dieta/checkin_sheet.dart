import 'package:flutter/material.dart';

import '../../../core/models/checkin.dart';
import '../../../core/services/checkin_service.dart';
import '../../../core/services/conquista_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Abre o check-in do mês. Devolve `true` se o aluno enviou.
Future<bool> abrirCheckin(
  BuildContext context, {
  required String alunoId,
  CheckinNutricional? existente,
}) async {
  final enviou = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CheckinSheet(alunoId: alunoId, existente: existente),
  );
  return enviou ?? false;
}

class _CheckinSheet extends StatefulWidget {
  const _CheckinSheet({required this.alunoId, this.existente});

  final String alunoId;
  final CheckinNutricional? existente;

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  final _obs = TextEditingController();

  late CheckinNutricional _c = widget.existente ??
      CheckinNutricional(mes: CheckinNutricional.mesAtual(), adesao: 3);

  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _obs.text = widget.existente?.observacoes ?? '';
  }

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      await CheckinService.salvar(
        widget.alunoId,
        _c.copiaCom(observacoes: _obs.text),
      );
      // O check-in é critério de três conquistas. Conceder aqui faz a
      // medalha aparecer na hora, e não na próxima vez que o aluno
      // abrir a tela de recordes.
      await ConquistaService.conceder(widget.alunoId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não consegui enviar: $e', style: AppText.body(13.5)),
        ),
      );
    }
  }

  /// "Nenhuma dificuldade" não convive com as outras: marcar as duas
  /// coisas é dizer que não houve dificuldade e listar quais foram.
  void _mexerDificuldade(String cod) {
    final atuais = [..._c.dificuldades];
    if (cod == 'nenhuma') {
      setState(() => _c = _c.copiaCom(
            dificuldades: atuais.contains('nenhuma') ? const [] : ['nenhuma'],
          ));
      return;
    }
    atuais.remove('nenhuma');
    atuais.contains(cod) ? atuais.remove(cod) : atuais.add(cod);
    setState(() => _c = _c.copiaCom(dificuldades: atuais));
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.existente != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
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
                  borderRadius: AppRadius.rPill,
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.lg,
                  ),
                  children: [
                    Text('Check-in de ${_c.mesNome}',
                        style: AppText.title(19)),
                    const SizedBox(height: 4),
                    Text(
                      editando
                          ? 'Você já respondeu este mês. Pode corrigir o que '
                              'quiser antes de enviar de novo.'
                          : 'Cinco perguntas rápidas. Serve para o seu '
                              'profissional ajustar o plano ao mês que você '
                              'teve de verdade.',
                      style: AppText.caption(12.5, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    _escala(
                      'Como foi seguir o plano?',
                      _c.adesao,
                      (v) => setState(() => _c = _c.copiaCom(adesao: v)),
                      rotulo: _c.adesaoRotulo,
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    _escala(
                      'E a sua disposição?',
                      _c.energia,
                      (v) => setState(() => _c = _c.copiaCom(energia: v)),
                      rotulo: switch (_c.energia) {
                        1 => 'Muito baixa',
                        2 => 'Baixa',
                        3 => 'Normal',
                        4 => 'Boa',
                        5 => 'Ótima',
                        _ => 'Toque para responder',
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    const PhdSectionHeader(label: 'O que dificultou'),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Pode marcar mais de uma.',
                        style:
                            AppText.caption(11.5, color: AppColors.textMuted)),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final e in dificuldadesCheckin.entries)
                          PhdFilterChip(
                            label: e.value,
                            selected: _c.dificuldades.contains(e.key),
                            onTap: () => _mexerDificuldade(e.key),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    const PhdSectionHeader(label: 'Intestino'),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Se preferir não responder, deixe em branco.',
                        style:
                            AppText.caption(11.5, color: AppColors.textMuted)),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        for (final e in intestinoCheckin.entries)
                          PhdFilterChip(
                            label: e.value,
                            selected: _c.intestino == e.key,
                            // Tocar no que já está marcado desmarca: é
                            // como o aluno volta a não responder.
                            onTap: () => setState(() => _c = _c.intestino == e.key
                                ? _c.copiaCom(limpaIntestino: true)
                                : _c.copiaCom(intestino: e.key)),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    PhdField(
                      label: 'Quer contar mais alguma coisa?',
                      controller: _obs,
                      hint: 'Opcional',
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    PhdAviso(
                      texto: 'Só o seu profissional lê este check-in. '
                          'Nada daqui vai para o feed da comunidade.',
                      icone: Icons.lock_outline_rounded,
                      cor: AppColors.success,
                      corTexto: AppColors.successText,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    PhdButton(
                      label: editando ? 'Salvar correção' : 'Enviar check-in',
                      icon: Icons.check_rounded,
                      loading: _enviando,
                      onPressed: _enviando ? null : _enviar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Escala de 1 a 5. Cinco toques grandes em vez de um slider: slider
  /// em valor discreto é preciso de menos e erra mais no celular.
  Widget _escala(
    String titulo,
    int? valor,
    ValueChanged<int> onEscolher, {
    required String rotulo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pergunta em caixa normal, não no rótulo de seção: uma pergunta
        // em maiúsculas soa como ordem.
        Text(titulo, style: AppText.bodyStrong(14)),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            for (var i = 1; i <= 5; i++) ...[
              if (i > 1) const SizedBox(width: 7),
              Expanded(
                child: InkWell(
                  onTap: () => onEscolher(i),
                  borderRadius: AppRadius.rMd,
                  child: Container(
                    height: kMinTouch,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: valor == i
                          ? AppColors.accent
                          : AppColors.surfaceHigh,
                      borderRadius: AppRadius.rMd,
                      border: Border.all(
                        color: valor == i ? Colors.transparent : AppColors.line,
                      ),
                    ),
                    child: Text(
                      '$i',
                      style: AppText.number(
                        15,
                        color: valor == i
                            ? AppColors.onAccent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(rotulo, style: AppText.bodyStrong(12.5, color: AppColors.accent)),
      ],
    );
  }
}
