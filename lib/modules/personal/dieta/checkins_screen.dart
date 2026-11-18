import 'package:flutter/material.dart';

import '../../../core/models/checkin.dart';
import '../../../core/services/checkin_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';

/// Os check-ins mensais do aluno, do mais recente ao mais antigo.
///
/// Leitura, só. O profissional não responde no lugar do aluno — o banco
/// recusa (0030), e um autorrelato escrito por outra pessoa não relata
/// nada.
class CheckinsScreen extends StatefulWidget {
  const CheckinsScreen({super.key, required this.aluno});

  final Map<String, dynamic> aluno;

  @override
  State<CheckinsScreen> createState() => _CheckinsScreenState();
}

class _CheckinsScreenState extends State<CheckinsScreen> {
  List<CheckinNutricional> _itens = const [];
  bool _carregando = true;
  Object? _erro;

  String get _id => widget.aluno['id'] as String;

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
      final l = await CheckinService.historico(_id);
      if (mounted) setState(() => _itens = l);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nome = (widget.aluno['nome'] as String?)?.split(' ').first ?? 'Aluno';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Check-ins · $nome', style: AppText.title(16)),
      ),
      body: _corpo(nome),
    );
  }

  Widget _corpo(String nome) {
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
    if (_itens.isEmpty) {
      return PhdEmptyState(
        icon: Icons.assignment_outlined,
        title: 'Nenhum check-in ainda',
        message: '$nome responde o check-in pela casa dele, no cartão '
            'abaixo da dieta. O cartão aparece quando existe plano '
            'alimentar ativo.',
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge,
        ),
        itemCount: _itens.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) =>
            i == 0 ? _resumo() : _cartao(_itens[i - 1]),
      ),
    );
  }

  /// A linha do tempo da adesão, em uma olhada.
  ///
  /// Vem antes dos cartões porque é a pergunta que o profissional faz
  /// primeiro: está melhorando ou piorando? Ler seis cartões para
  /// descobrir isso é trabalho que o app devia poupar.
  Widget _resumo() {
    // Do mais antigo para o mais recente: a leitura da esquerda para a
    // direita precisa ser a do tempo passando.
    final serie = _itens.reversed.toList();

    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PhdSectionHeader(label: 'Adesão relatada'),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 58,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final c in serie) ...[
                  if (c != serie.first) const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 8 + (c.adesao / 5) * 34,
                          decoration: BoxDecoration(
                            color: c.adesaoCor(
                              AppColors.danger,
                              AppColors.warning,
                              AppColors.success,
                            ),
                            borderRadius: AppRadius.rSm,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          Datas.mesAno(c.mes).split(' ').first.substring(0, 3),
                          maxLines: 1,
                          style: AppText.caption(9.5,
                              color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_itens.length} ${_itens.length == 1 ? 'check-in' : 'check-ins'} '
            '· escala de 1 a 5',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _cartao(CheckinNutricional c) {
    final cor = c.adesaoCor(
      AppColors.danger,
      AppColors.warning,
      AppColors.success,
    );

    return PhdCard(
      accentBar: cor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(c.mesNome, style: AppText.title(15))),
              PhdStatusChip(
                label: '${c.adesao}/5',
                tone: switch (c.adesao) {
                  1 || 2 => PhdTone.danger,
                  3 => PhdTone.warning,
                  _ => PhdTone.success,
                },
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(c.adesaoRotulo, style: AppText.bodyStrong(13, color: cor)),

          if (c.energia != null) ...[
            const SizedBox(height: AppSpacing.md),
            _linha(Icons.bolt_rounded, 'Disposição', '${c.energia}/5'),
          ],

          if (c.dificuldades.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('DIFICULDADES', style: AppText.label()),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in c.dificuldadesRotulos)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: AppRadius.rPill,
                    ),
                    child: Text(r, style: AppText.caption(11.5)),
                  ),
              ],
            ),
          ],

          if (c.intestinoRotulo != null) ...[
            const SizedBox(height: AppSpacing.md),
            _linha(Icons.water_drop_outlined, 'Intestino', c.intestinoRotulo!),
          ],

          if ((c.observacoes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppRadius.rMd,
              ),
              child: Text(
                c.observacoes!.trim(),
                style: AppText.body(13.5).copyWith(height: 1.45),
              ),
            ),
          ],

          if (c.criadoEm != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Respondido em ${Datas.curta(c.criadoEm!)}',
                style: AppText.caption(10.5, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _linha(IconData icone, String rotulo, String valor) => Row(
        children: [
          Icon(icone, size: 15, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.sm),
          Text('$rotulo: ', style: AppText.caption(12)),
          Text(valor, style: AppText.bodyStrong(12.5)),
        ],
      );
}
