import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/avaliacao_calculos.dart';
import '../../../core/widgets/widgets.dart';

/// Peças que só a avaliação física usa. O que servir a outra área do app
/// sobe para `core/widgets`.

extension NivelTom on Nivel {
  PhdTone get tom => switch (this) {
        Nivel.bom => PhdTone.success,
        Nivel.atencao => PhdTone.warning,
        Nivel.risco => PhdTone.danger,
        Nivel.neutro => PhdTone.neutral,
      };
}

/// Número com vírgula, sem zeros sobrando: 72 → "72", 72.5 → "72,5".
String numBr(num? v, {int casas = 1}) {
  if (v == null) return '—';
  final s = v.toStringAsFixed(casas);
  final limpo = s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  return limpo.replaceAll('.', ',');
}

/// "18,4%" junto, "81,2 kg" separado — como se escreve em português.
String comUnidade(String valor, String unidade) =>
    unidade.isEmpty ? valor : unidade == '%' ? '$valor%' : '$valor $unidade';

/// Diferença com sinal: "+1,2" / "−0,8". `null` quando falta um dos lados.
String? deltaBr(num? atual, num? anterior, {int casas = 1}) {
  if (atual == null || anterior == null) return null;
  final d = atual - anterior;
  if (d.abs() < 0.05) return '=';
  return '${d > 0 ? '+' : '−'}${numBr(d.abs(), casas: casas)}';
}

/// Cartão de índice: nome, valor grande, classificação colorida.
class IndiceTile extends StatelessWidget {
  const IndiceTile({
    super.key,
    required this.rotulo,
    required this.valor,
    this.unidade,
    this.classificacao,
    this.referencia,
    this.vazio = 'Falta medida',
  });

  final String rotulo;
  final String? valor;
  final String? unidade;
  final Classificacao? classificacao;
  final String? referencia;

  /// O que aparece no lugar do valor quando ele não pode ser calculado —
  /// dizer o que falta, e não só "—", é o que faz o personal ir medir.
  final String vazio;

  @override
  Widget build(BuildContext context) {
    final c = classificacao;
    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(rotulo.toUpperCase(), style: AppText.label(), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          if (valor == null)
            Text(vazio, style: AppText.caption(12.5, color: AppColors.textMuted))
          else
            Text.rich(
              TextSpan(children: [
                TextSpan(text: valor, style: AppText.number(22, weight: FontWeight.w800)),
                if (unidade != null)
                  TextSpan(text: ' $unidade', style: AppText.caption(12)),
              ]),
              maxLines: 1,
            ),
          if (c != null) ...[
            const SizedBox(height: 4),
            Text(
              c.rotulo,
              style: AppText.bodyStrong(12, color: c.nivel.tom.onDark),
              maxLines: 2,
            ),
          ],
          if (referencia != null && valor != null) ...[
            const SizedBox(height: 2),
            Text(referencia!, style: AppText.caption(10, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}

/// Grade de duas colunas que não estica: cada linha tem a altura do maior
/// cartão dela. `GridView` com `childAspectRatio` cortava a classificação
/// de duas linhas em celular pequeno.
class GradeDupla extends StatelessWidget {
  const GradeDupla({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final linhas = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      linhas.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < children.length) linhas.add(const SizedBox(height: AppSpacing.sm + 2));
    }
    return Column(children: linhas);
  }
}

/// Linha "rótulo …… valor" tocável, para medidas editáveis.
class LinhaMedida extends StatelessWidget {
  const LinhaMedida({
    super.key,
    required this.rotulo,
    required this.valor,
    this.origem,
    this.onTap,
  });

  final String rotulo;
  final String valor;

  /// "da dobra", "da avaliação anterior": de onde veio um valor que o
  /// personal não digitou nesta sessão.
  final String? origem;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kMinTouch + 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(child: Text(rotulo, style: AppText.body(14, color: AppColors.textSecondary))),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(valor, style: AppText.number(15)),
                  if (origem != null)
                    Text(origem!, style: AppText.caption(10.5, color: AppColors.textMuted)),
                ],
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.edit_outlined, size: 16, color: AppColors.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Resultado do editor de número: o valor, ou "apagar" (que é diferente de
/// cancelar — o personal pode querer tirar um valor digitado errado).
class ValorEditado {
  const ValorEditado(this.valor);
  final double? valor;
}

/// Pede um número numa folha inferior. Devolve `null` se cancelou.
Future<ValorEditado?> editarNumero(
  BuildContext context, {
  required String titulo,
  String? unidade,
  num? atual,
  bool decimal = true,
  String? ajuda,
}) {
  final ctrl = TextEditingController(text: atual == null ? '' : numBr(atual, casas: 2));
  return showModalBottomSheet<ValorEditado>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
    builder: (ctx) {
      void confirmar() {
        final t = ctrl.text.trim().replaceAll(',', '.');
        if (t.isEmpty) {
          Navigator.pop(ctx, const ValorEditado(null));
          return;
        }
        final v = double.tryParse(t);
        if (v == null) return;
        Navigator.pop(ctx, ValorEditado(v));
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: AppText.title(18)),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.numberWithOptions(decimal: decimal),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]')),
              ],
              onSubmitted: (_) => confirmar(),
              style: AppText.number(28),
              decoration: InputDecoration(
                suffixText: unidade,
                suffixStyle: AppText.caption(15),
                hintText: '0',
                hintStyle: AppText.number(28, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceHigh,
                border: OutlineInputBorder(borderRadius: AppRadius.rMd, borderSide: BorderSide.none),
              ),
            ),
            if (ajuda != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(ajuda, style: AppText.caption(12, color: AppColors.textMuted)),
            ],
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                if (atual != null) ...[
                  Expanded(
                    child: PhdButton(
                      label: 'Apagar',
                      variant: PhdButtonVariant.ghost,
                      onPressed: () => Navigator.pop(ctx, const ValorEditado(null)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(flex: 2, child: PhdButton(label: 'Salvar', onPressed: confirmar)),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// Cabeçalho padrão das telas de avaliação: nome do aluno em cima, o que é
/// a tela embaixo.
PreferredSizeWidget appBarAvaliacao(String aluno, String titulo, {List<Widget>? actions}) {
  return AppBar(
    backgroundColor: AppColors.bg,
    surfaceTintColor: Colors.transparent,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: AppText.title(17)),
        Text(aluno, style: AppText.caption(12)),
      ],
    ),
    actions: actions,
  );
}

void avisar(BuildContext context, String texto, {bool erro = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(texto, style: AppText.body(13.5, color: erro ? AppColors.textPrimary : AppColors.onAccent)),
    backgroundColor: erro ? AppColors.surfaceHigh : AppColors.accent,
    behavior: SnackBarBehavior.floating,
  ));
}
