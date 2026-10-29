import 'package:flutter/material.dart';
import '../../../core/models/diario.dart';
import '../../../core/services/diario_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';
import '../../aluno/dieta/cartao_agua.dart' show corAgua, litrosTexto;

/// O que o aluno registrou nos últimos 7 dias: água, peso e diário.
///
/// É a outra metade do plano. O plano diz o que comer; aqui o profissional
/// vê o que aconteceu — a foto do prato, onde o aluno fugiu, se está
/// bebendo água — e ajusta na próxima consulta com base nisso.
class AcompanhamentoAluno extends StatefulWidget {
  const AcompanhamentoAluno({super.key, required this.alunoId, this.metaAguaMl});

  final String alunoId;
  final int? metaAguaMl;

  @override
  State<AcompanhamentoAluno> createState() => _AcompanhamentoAlunoState();
}

class _AcompanhamentoAlunoState extends State<AcompanhamentoAluno> {
  List<RegistroDiario> _diario = const [];
  Map<DateTime, int> _agua = const {};
  List<RegistroPeso> _pesos = const [];
  bool _carregou = false;
  bool _semTabela = false;

  static const _dias = 7;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final de = Datas.dia(DateTime.now()).subtract(const Duration(days: _dias - 1));
    try {
      final (diario, agua, pesos) = await (
        DiarioService.listar(alunoId: widget.alunoId, de: de),
        DiarioService.aguaPorDia(widget.alunoId, dias: _dias),
        DiarioService.pesos(widget.alunoId, limite: 12),
      ).wait;
      if (!mounted) return;
      setState(() {
        _diario = diario;
        _agua = agua;
        _pesos = pesos;
      });
    } catch (_) {
      // Tabela ainda não criada (migration 0014 não aplicada): a seção
      // avisa em vez de sumir sem explicação.
      if (mounted) setState(() => _semTabela = true);
    } finally {
      if (mounted) setState(() => _carregou = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_carregou) {
      return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
    }
    if (_semTabela) {
      return PhdCard(
        child: Text(
          'O acompanhamento do aluno ainda não está disponível neste servidor.',
          style: AppText.caption(13),
        ),
      );
    }

    final hoje = Datas.dia(DateTime.now());
    final dias = [for (var i = _dias - 1; i >= 0; i--) hoje.subtract(Duration(days: i))];
    final aguaSemana = [for (final d in dias) _agua[d] ?? 0];
    final diasComAgua = aguaSemana.where((v) => v > 0).length;
    final mediaAgua = diasComAgua == 0 ? 0 : aguaSemana.fold(0, (s, v) => s + v) ~/ diasComAgua;

    final doPlano = _diario.where((r) => r.aderencia != null).toList();
    final seguiu = doPlano.where((r) => r.aderencia != Aderencia.fora).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _resumo(
                icone: Icons.fact_check_outlined,
                cor: AppColors.accent,
                valor: doPlano.isEmpty ? '—' : '${(seguiu * 100 / doPlano.length).round()}%',
                legenda: 'refeições no plano',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _resumo(
                icone: Icons.water_drop_rounded,
                cor: corAgua,
                valor: mediaAgua == 0 ? '—' : litrosTexto(mediaAgua),
                legenda: 'água por dia',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _resumo(
                icone: Icons.monitor_weight_outlined,
                cor: AppColors.energy,
                valor: _pesos.isEmpty
                    ? '—'
                    : '${_pesos.last.pesoKg.toStringAsFixed(1).replaceAll('.', ',')} kg',
                legenda: _pesos.isEmpty ? 'sem pesagem' : 'peso em ${_dm(_pesos.last.data)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PhdCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('ÁGUA NA SEMANA', style: AppText.label())),
                  if (widget.metaAguaMl != null)
                    Text('meta ${litrosTexto(widget.metaAguaMl!)}',
                        style: AppText.caption(11.5, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              PhdBars(
                valores: aguaSemana,
                destaque: _dias - 1,
                altura: 44,
                cor: corAgua,
                rotulos: [for (final d in dias) const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'][d.weekday - 1]],
              ),
              if (_pesos.length >= 2) ...[
                const SizedBox(height: AppSpacing.lg),
                Text('PESO', style: AppText.label()),
                const SizedBox(height: AppSpacing.sm),
                PhdSparkline(valores: [for (final p in _pesos) p.pesoKg], cor: AppColors.energy),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('DIÁRIO', style: AppText.label()),
        const SizedBox(height: AppSpacing.sm),
        if (_diario.isEmpty)
          PhdCard(
            child: Text(
              'Nenhum registro nos últimos 7 dias. O aluno registra pela tela '
              'da dieta, com foto do prato.',
              style: AppText.caption(13),
            ),
          )
        else
          for (final d in dias.reversed)
            if (_diario.where((r) => Datas.dia(r.data) == d).toList() case final doDia
                when doDia.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                child: Text(_rotuloDia(d, hoje), style: AppText.bodyStrong(12.5, color: AppColors.textSecondary)),
              ),
              PhdCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Column(
                  children: [
                    for (final (i, r) in doDia.indexed) ...[
                      if (i > 0) Divider(height: 1, color: AppColors.line),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: _linha(r),
                      ),
                    ],
                  ],
                ),
              ),
            ],
      ],
    );
  }

  Widget _resumo({
    required IconData icone,
    required Color cor,
    required String valor,
    required String legenda,
  }) {
    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 19, color: cor),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor, style: AppText.number(19, weight: FontWeight.w800)),
          ),
          Text(legenda, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(11)),
        ],
      ),
    );
  }

  Widget _linha(RegistroDiario r) {
    final (tom, rotulo) = switch (r.aderencia) {
      Aderencia.seguiu => (PhdTone.success, 'Seguiu'),
      Aderencia.parecido => (PhdTone.accent, 'Parecido'),
      Aderencia.fora => (PhdTone.warning, 'Fugiu'),
      null => (PhdTone.neutral, 'Fora do plano'),
    };
    final hora = '${r.registradoEm.hour.toString().padLeft(2, '0')}:'
        '${r.registradoEm.minute.toString().padLeft(2, '0')}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.rMd,
          child: SizedBox.square(
            dimension: 64,
            child: r.fotoUrl == null
                ? ColoredBox(
                    color: AppColors.surfaceHigh,
                    child: Icon(Icons.notes_rounded, color: AppColors.textMuted),
                  )
                : GestureDetector(
                    onTap: () => _verFoto(r.fotoUrl!),
                    child: Image.network(
                      r.fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: AppColors.surfaceHigh,
                        child: Icon(Icons.image_not_supported_outlined, color: AppColors.textMuted),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(r.titulo,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(13.5)),
                  ),
                  const SizedBox(width: 6),
                  Text(hora, style: AppText.caption(11.5, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 4),
              PhdStatusChip(label: rotulo, tone: tom),
              if (r.descricao != null) ...[
                const SizedBox(height: 4),
                Text(r.descricao!, style: AppText.caption(12.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _verFoto(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: SizedBox.expand(
            child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }

  static String _dm(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static String _rotuloDia(DateTime d, DateTime hoje) {
    final dif = hoje.difference(d).inDays;
    if (dif == 0) return 'Hoje';
    if (dif == 1) return 'Ontem';
    const nomes = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
    return '${nomes[d.weekday - 1]}, ${_dm(d)}';
  }
}
