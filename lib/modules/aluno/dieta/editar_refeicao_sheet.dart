import 'package:flutter/material.dart';
import '../../../core/models/dieta.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../personal/dieta/busca_alimento_sheet.dart';

/// O que a folha devolve: a lista do que o aluno comeu, ou `null` dentro
/// do record para "voltar ao plano". A folha fechada sem salvar devolve
/// `null` de fora.
typedef ConsumoEditado = ({List<ItemConsumido>? itens});

/// O aluno ajusta a refeição ao que comeu de fato: troca um item, muda a
/// quantidade, tira ou acrescenta. O plano não muda — muda o consumido do
/// dia, que o profissional vê no acompanhamento.
Future<ConsumoEditado?> editarRefeicao(
  BuildContext context, {
  required Refeicao refeicao,
  List<ItemConsumido>? atual,
  bool mostrarNumeros = true,
}) {
  return showModalBottomSheet<ConsumoEditado>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditarRefeicaoSheet(
      refeicao: refeicao,
      atual: atual,
      mostrarNumeros: mostrarNumeros,
    ),
  );
}

class _EditarRefeicaoSheet extends StatefulWidget {
  const _EditarRefeicaoSheet({
    required this.refeicao,
    required this.atual,
    required this.mostrarNumeros,
  });

  final Refeicao refeicao;
  final List<ItemConsumido>? atual;
  final bool mostrarNumeros;

  @override
  State<_EditarRefeicaoSheet> createState() => _EditarRefeicaoSheetState();
}

class _EditarRefeicaoSheetState extends State<_EditarRefeicaoSheet> {
  late List<ItemConsumido> _itens = [...widget.atual ?? widget.refeicao.comoPrescrito];

  /// Falso enquanto a lista é a do plano: salvar assim grava "comeu o
  /// plano" (nulo), e não uma cópia que deixaria de acompanhar o plano se o
  /// profissional o mudasse mais tarde.
  late bool _mudou = widget.atual != null;

  Refeicao get _r => widget.refeicao;

  void _mudar(void Function() f) => setState(() {
        f();
        _mudou = true;
      });

  /// Para a busca calcular a equivalência, o item consumido vira um item de
  /// plano de mentira com os mesmos nutrientes.
  ItemRefeicao _comoItem(ItemConsumido c) => ItemRefeicao(
        id: c.itemPlanoId ?? '',
        refeicaoId: _r.id,
        alimento: Alimento(
          id: c.alimentoId ?? '',
          nome: c.nome,
          kcal: c.valores.kcal,
          proteina: c.valores.proteina,
          carboidrato: c.valores.carboidrato,
          gordura: c.valores.gordura,
          fibra: c.valores.fibra,
        ),
        quantidadeG: c.gramas,
        nomeExibicao: c.nome,
      );

  Future<void> _tocar(int indice) async {
    final c = _itens[indice];
    // Os substitutos que o profissional já deixou no plano vêm primeiro:
    // são as trocas que ele aprovou, com a quantidade que ele definiu.
    final planejado = _r.itens.where((i) => i.id == c.itemPlanoId).firstOrNull;
    final bloco = planejado == null ? null : _r.blocoDe(planejado);
    final opcoes = [
      if (bloco != null)
        for (final i in [bloco.principal, ...bloco.substitutos])
          if (i.alimento.id != c.alimentoId) i,
    ];

    final acao = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c.nome, style: AppText.title(16)),
              Text(_quantidade(c), style: AppText.caption(12, color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.md),
              if (opcoes.isNotEmpty) ...[
                Text('TROCAS DO SEU PLANO', style: AppText.label()),
                for (final o in opcoes)
                  PhdListRow(
                    title: o.nome,
                    subtitle: o.quantidadeTexto,
                    leading: Icon(Icons.swap_horiz_rounded, size: 19, color: AppColors.accent),
                    onTap: () => Navigator.pop(ctx, o),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
              PhdListRow(
                title: 'Trocar por outro alimento',
                subtitle: 'A quantidade vem calculada para equivaler',
                leading: Icon(Icons.search_rounded, size: 19, color: AppColors.textSecondary),
                onTap: () => Navigator.pop(ctx, 'buscar'),
              ),
              if (!c.receita)
                PhdListRow(
                  title: 'Mudar a quantidade',
                  leading: Icon(Icons.scale_rounded, size: 19, color: AppColors.textSecondary),
                  onTap: () => Navigator.pop(ctx, 'quantidade'),
                ),
              PhdListRow(
                title: 'Não comi',
                leading: Icon(Icons.remove_circle_outline_rounded, size: 19, color: AppColors.dangerText),
                onTap: () => Navigator.pop(ctx, 'remover'),
              ),
            ],
          ),
        ),
      ),
    );
    if (acao == null || !mounted) return;

    if (acao is ItemRefeicao) {
      _mudar(() => _itens[indice] = ItemConsumido.deAlimento(
            acao.alimento,
            acao.quantidadeG,
            nome: acao.nome,
            // O principal de volta é o plano; um substituto é troca, mesmo
            // que aprovada.
            origem: acao.id == bloco?.principal.id ? OrigemConsumo.plano : OrigemConsumo.troca,
            itemPlanoId: c.itemPlanoId,
          ));
      return;
    }
    switch (acao) {
      case 'buscar':
        final e = await escolherAlimento(
          context,
          substitutoDe: _comoItem(c),
          doAluno: true,
          mostrarNumeros: widget.mostrarNumeros,
        );
        if (e == null) return;
        _mudar(() => _itens[indice] = ItemConsumido.deAlimento(
              e.alimento,
              e.gramas,
              origem: c.itemPlanoId == null ? OrigemConsumo.extra : OrigemConsumo.troca,
              itemPlanoId: c.itemPlanoId,
            ));
      case 'quantidade':
        final g = await _pedirGramas(c);
        if (g != null) _mudar(() => _itens[indice] = c.comGramas(g));
      case 'remover':
        _mudar(() => _itens.removeAt(indice));
    }
  }

  Future<void> _adicionar() async {
    final e = await escolherAlimento(context, doAluno: true, mostrarNumeros: widget.mostrarNumeros);
    if (e == null) return;
    _mudar(() => _itens.add(ItemConsumido.deAlimento(e.alimento, e.gramas)));
  }

  Future<double?> _pedirGramas(ItemConsumido c) async {
    final ctrl = TextEditingController(text: c.gramas.round().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Quanto você comeu?', style: AppText.title(17)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.nome, style: AppText.caption(12, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            PhdField(
              label: 'Gramas',
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Salvar', style: AppText.bodyStrong(13.5, color: AppColors.accent)),
          ),
        ],
      ),
    );
    final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
    ctrl.dispose();
    if (ok != true || v == null || v <= 0) return null;
    return v;
  }

  String _quantidade(ItemConsumido c) => c.receita ? 'receita do plano' : '${c.gramas.round()} g';

  @override
  Widget build(BuildContext context) {
    final fundoTeclado = MediaQuery.of(context).viewInsets.bottom;
    final agora = somarConsumo(_itens);
    final plano = _r.total;

    return Padding(
      padding: EdgeInsets.only(bottom: fundoTeclado),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scroll) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.md),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lineStrong,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('O que você comeu no ${_r.nome.toLowerCase()}', style: AppText.title(18)),
                    const SizedBox(height: 2),
                    Text(
                      'Toque num alimento para trocar, mudar a quantidade ou tirar. '
                      'Seu plano não muda.',
                      style: AppText.caption(12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  children: [
                    if (_itens.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Text('Nada nesta refeição.',
                            style: AppText.body(13.5, color: AppColors.textMuted)),
                      ),
                    for (final (i, c) in _itens.indexed) _linha(i, c),
                    const SizedBox(height: AppSpacing.sm),
                    PhdAddCard(label: 'Comi outra coisa também', height: 44, onTap: _adicionar),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.mostrarNumeros) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'P ${agora.proteina.round()} · C ${agora.carboidrato.round()} · '
                                'G ${agora.gordura.round()}',
                                style: AppText.caption(12, color: AppColors.textSecondary),
                              ),
                            ),
                            Text('${agora.kcal.round()} kcal', style: AppText.number(16)),
                          ],
                        ),
                        if (_mudou)
                          Text(
                            'No plano: ${plano.kcal.round()} kcal',
                            style: AppText.caption(11.5, color: AppColors.textMuted),
                          ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Row(
                        children: [
                          if (_mudou) ...[
                            Expanded(
                              child: PhdButton(
                                label: 'Voltar ao plano',
                                variant: PhdButtonVariant.ghost,
                                size: PhdButtonSize.medium,
                                onPressed: () => setState(() {
                                  _itens = _r.comoPrescrito;
                                  _mudou = false;
                                }),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Expanded(
                            flex: 2,
                            child: PhdButton(
                              label: 'Salvar e marcar feita',
                              icon: Icons.check_rounded,
                              size: PhdButtonSize.medium,
                              onPressed: () => Navigator.pop<ConsumoEditado>(
                                context,
                                (itens: _mudou ? _itens : null),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linha(int i, ItemConsumido c) {
    final rotulo = switch (c.origem) {
      OrigemConsumo.plano => null,
      OrigemConsumo.troca => c.itemPlanoId == null ? 'alterado' : 'trocado',
      OrigemConsumo.extra => 'a mais',
    };
    return InkWell(
      borderRadius: AppRadius.rMd,
      onTap: () => _tocar(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(c.nome,
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body(14)),
                      ),
                      if (rotulo != null) ...[
                        const SizedBox(width: 6),
                        PhdStatusChip(label: rotulo, tone: PhdTone.accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(_quantidade(c), style: AppText.caption(11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (widget.mostrarNumeros) ...[
              const SizedBox(width: AppSpacing.sm),
              Text('${c.nutrientes.kcal.round()}',
                  style: AppText.number(13, color: AppColors.textSecondary)),
            ],
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
