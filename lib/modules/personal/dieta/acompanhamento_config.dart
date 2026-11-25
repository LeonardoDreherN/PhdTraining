import 'package:flutter/material.dart';

import '../../../core/services/acompanhamento_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// O que o profissional pede a ESTE aluno.
///
/// A especificação é explícita: "o profissional deve poder configurar
/// ou ajustar metas, frequência e solicitações de check-in conforme o
/// plano individual". Antes disto a frequência de pesagem era semanal
/// e cravada no código, e as fotos mensais não eram pedidas por
/// ninguém — "Aluno disciplinado" não tinha como ser conquistada,
/// porque o pedido que ela atende não existia.
class AcompanhamentoConfig extends StatefulWidget {
  const AcompanhamentoConfig({super.key, required this.alunoId});

  final String alunoId;

  @override
  State<AcompanhamentoConfig> createState() => _AcompanhamentoConfigState();
}

class _AcompanhamentoConfigState extends State<AcompanhamentoConfig> {
  ConfigAcompanhamento _c = const ConfigAcompanhamento();
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final c = await AcompanhamentoService.doAluno(widget.alunoId);
      if (mounted) setState(() => _c = c);
    } catch (_) {
      // Sem a 0034 a tabela não existe. Os padrões valem igual.
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Grava a cada toque, como a configuração da comunidade: uma tela de
  /// interruptores com botão "Salvar" é onde a pessoa mexe em três e
  /// sai sem salvar nenhum.
  Future<void> _mudar(ConfigAcompanhamento novo) async {
    final antes = _c;
    setState(() {
      _c = novo;
      _salvando = true;
    });
    try {
      await AcompanhamentoService.salvar(widget.alunoId, novo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _c = antes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não consegui salvar: $e', style: AppText.body(13.5)),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return PhdCard(
        child: SizedBox(
          height: 44,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            ),
          ),
        ),
      );
    }

    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Pesagem', style: AppText.bodyStrong(13.5)),
              ),
              if (_salvando)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            // A regra que a especificação proíbe quebrar, dita em voz
            // alta em vez de escondida no código.
            'Não existe opção diária: pesar todo dia não ajuda ninguém, e '
            'a conquista é sobre registrar com regularidade — nunca sobre '
            'o número da balança.',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (var i = 1; i <= 4; i++)
                PhdFilterChip(
                  label: ConfigAcompanhamento(pesoFrequenciaSemanas: i)
                      .frequenciaRotulo,
                  selected: _c.pesoFrequenciaSemanas == i,
                  onTap: () => _mudar(_c.copiaCom(pesoFrequenciaSemanas: i)),
                ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.line, height: 1),
          const SizedBox(height: AppSpacing.md),

          _chave(
            'Pedir fotos todo mês',
            'O aluno passa a ver o pedido, e a conquista "Aluno '
                'disciplinado" só existe com ele ligado.',
            _c.fotosMensais,
            (v) => _mudar(_c.copiaCom(fotosMensais: v)),
          ),
          _chave(
            'Check-in mensal',
            'Cinco perguntas rápidas sobre o mês, respondidas pelo aluno.',
            _c.checkinMensal,
            (v) => _mudar(_c.copiaCom(checkinMensal: v)),
          ),
        ],
      ),
    );
  }

  Widget _chave(
    String titulo,
    String descricao,
    bool valor,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titulo, style: AppText.bodyStrong(13.5)),
                const SizedBox(height: 2),
                Text(descricao,
                    style: AppText.caption(11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch(
            value: valor,
            activeThumbColor: AppColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
