import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/financeiro.dart';
import '../../../core/services/pagamento_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/moeda.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/widgets/widgets.dart';

String _semException(Object e) => '$e'.replaceFirst('Exception: ', '');

// ════════════════════════════════════════════════════════════════
//  Link de pagamento
// ════════════════════════════════════════════════════════════════

/// Gera (ou reabre) o link da fatura do gateway para uma cobrança e mostra
/// as formas de mandar ao aluno. Devolve `true` se a cobrança mudou — a
/// tela recarrega para ela aparecer como "pelo app".
Future<bool> mostrarLinkDePagamento(BuildContext context, Cobranca c) async {
  final mensageiro = ScaffoldMessenger.of(context);
  String? link = c.linkPagamento;
  var mudou = false;

  if (link == null) {
    try {
      var r = await PagamentoService.linkDeCobranca(c.id);
      if (r.precisaCpf) {
        if (!context.mounted) return false;
        final cpf = await _pedirCpf(context, c.alunoNome);
        if (cpf == null) return false;
        r = await PagamentoService.linkDeCobranca(c.id, cpf: cpf);
      }
      link = r.link;
      mudou = true;
    } catch (e) {
      mensageiro.showSnackBar(SnackBar(content: Text(_semException(e))));
      return false;
    }
  }
  if (link == null || !context.mounted) return mudou;

  final zap = linkWhatsApp(
    c.alunoWhatsapp,
    mensagem: 'Oi, ${c.alunoNome.split(' ').first}! Segue o link para pagar a '
        '${c.descricao ?? 'mensalidade'} de ${c.valor} (Pix, boleto ou cartão): $link',
  );

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Link de pagamento', style: AppText.title(18)),
            const SizedBox(height: 4),
            Text(
              '${c.alunoNome} · ${c.valor}. O aluno escolhe Pix, boleto ou cartão, '
              'e a baixa acontece sozinha quando ele pagar.',
              style: AppText.caption(12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.rMd),
              child: SelectableText(link!, style: AppText.body(13)),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (zap != null) ...[
              PhdButton(
                label: 'Mandar no WhatsApp',
                icon: Icons.chat_rounded,
                onPressed: () => launchUrl(zap, mode: LaunchMode.externalApplication),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Expanded(
                  child: PhdButton(
                    label: 'Copiar',
                    icon: Icons.copy_rounded,
                    variant: PhdButtonVariant.secondary,
                    size: PhdButtonSize.medium,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link!));
                      mensageiro.showSnackBar(const SnackBar(content: Text('Link copiado')));
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PhdButton(
                    label: 'Abrir',
                    icon: Icons.open_in_new_rounded,
                    variant: PhdButtonVariant.secondary,
                    size: PhdButtonSize.medium,
                    onPressed: () => launchUrl(Uri.parse(link!), mode: LaunchMode.externalApplication),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return mudou;
}

/// O gateway não gera cobrança sem CPF do pagador. Pergunta uma vez; o
/// servidor guarda no cadastro do aluno.
Future<String?> _pedirCpf(BuildContext context, String aluno) async {
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text('CPF de $aluno', style: AppText.title(17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'O gateway pede o CPF de quem paga. Fica salvo no cadastro do aluno; '
            'só você e ele veem.',
            style: AppText.caption(12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          PhdField(label: 'CPF', controller: ctrl, keyboardType: TextInputType.number),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Gerar link', style: AppText.bodyStrong(13.5, color: AppColors.accent)),
        ),
      ],
    ),
  );
  final cpf = ctrl.text.replaceAll(RegExp(r'\D'), '');
  ctrl.dispose();
  return ok == true && cpf.isNotEmpty ? cpf : null;
}

// ════════════════════════════════════════════════════════════════
//  Saldo e saque
// ════════════════════════════════════════════════════════════════

/// Saldo da subconta (lido do gateway, nunca somado aqui), botão de sacar e
/// os últimos saques.
class CartaoCarteira extends StatefulWidget {
  const CartaoCarteira({super.key});

  @override
  State<CartaoCarteira> createState() => _CartaoCarteiraState();
}

class _CartaoCarteiraState extends State<CartaoCarteira> {
  int? _saldo;
  List<Map<String, dynamic>> _saques = const [];
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final (saldo, saques) = await (PagamentoService.saldoCentavos(), PagamentoService.saques()).wait;
      if (mounted) {
        setState(() {
          _saldo = saldo;
          _saques = saques;
          _erro = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    }
  }

  Future<void> _sacar() async {
    final saldo = _saldo;
    if (saldo == null || saldo < 100) return;
    final feito = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SaqueSheet(saldoCentavos: saldo),
    );
    if (feito == true) _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final saldo = _saldo;
    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Disponível para saque',
                  value: _erro != null
                      ? '—'
                      : saldo == null
                          ? '...'
                          : Moeda.formatar(saldo),
                  valueSize: 22,
                ),
              ),
              PhdButton(
                label: 'Sacar',
                icon: Icons.south_west_rounded,
                size: PhdButtonSize.small,
                expand: false,
                onPressed: saldo != null && saldo >= 100 ? _sacar : null,
              ),
            ],
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Não consegui consultar o saldo: ${_semException(_erro!)}',
                style: AppText.caption(12, color: AppColors.warningText)),
          ],
          if (_saques.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(color: AppColors.line, height: 1),
            const SizedBox(height: AppSpacing.sm),
            for (final s in _saques.take(3)) _linhaSaque(s),
          ],
        ],
      ),
    );
  }

  Widget _linhaSaque(Map<String, dynamic> s) {
    final (rotulo, tom) = switch (s['status']) {
      'concluido' => ('concluído', PhdTone.success),
      'falhou' => ('falhou', PhdTone.danger),
      'cancelado' => ('cancelado', PhdTone.neutral),
      _ => ('processando', PhdTone.warning),
    };
    final quando = DateTime.tryParse(s['solicitado_em'] as String? ?? '')?.toLocal();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              [
                Moeda.formatar((s['valor_centavos'] as num).toInt()),
                if (quando != null) '${quando.day.toString().padLeft(2, '0')}/${quando.month.toString().padLeft(2, '0')}',
              ].join('  ·  '),
              style: AppText.body(13),
            ),
          ),
          PhdStatusChip(label: rotulo, tone: tom),
        ],
      ),
    );
  }
}

class _SaqueSheet extends StatefulWidget {
  const _SaqueSheet({required this.saldoCentavos});
  final int saldoCentavos;

  @override
  State<_SaqueSheet> createState() => _SaqueSheetState();
}

class _SaqueSheetState extends State<_SaqueSheet> {
  late final _valor = TextEditingController(
      text: (widget.saldoCentavos / 100).toStringAsFixed(2).replaceAll('.', ','));
  final _chave = TextEditingController();
  String _tipo = 'CPF';
  bool _enviando = false;
  String? _erro;

  /// Uma por abertura da folha: tocar duas vezes em "Sacar" manda a mesma
  /// chave, e o servidor devolve o saque que já existe em vez de criar outro.
  final _idempotencia =
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  static const _tipos = [
    (valor: 'CPF', rotulo: 'CPF'),
    (valor: 'CNPJ', rotulo: 'CNPJ'),
    (valor: 'EMAIL', rotulo: 'E-mail'),
    (valor: 'PHONE', rotulo: 'Celular'),
    (valor: 'EVP', rotulo: 'Aleatória'),
  ];

  @override
  void dispose() {
    _valor.dispose();
    _chave.dispose();
    super.dispose();
  }

  int? get _centavos {
    final t = _valor.text.trim().replaceAll('.', '').replaceAll(',', '.');
    final v = double.tryParse(t);
    return v == null ? null : (v * 100).round();
  }

  Future<void> _confirmar() async {
    final c = _centavos;
    if (c == null || c < 100) return setState(() => _erro = 'O saque mínimo é R\$ 1,00.');
    if (c > widget.saldoCentavos) return setState(() => _erro = 'Maior que o saldo disponível.');
    if (_chave.text.trim().isEmpty) return setState(() => _erro = 'Informe a chave Pix.');
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      var chave = _chave.text.trim();
      if (_tipo == 'CPF' || _tipo == 'CNPJ' || _tipo == 'PHONE') chave = chave.replaceAll(RegExp(r'\D'), '');
      await PagamentoService.sacar(
        valorCentavos: c,
        chavePix: chave,
        tipoChave: _tipo,
        idempotencia: _idempotencia,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enviando = false;
          _erro = _semException(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sacar por Pix', style: AppText.title(18)),
                const SizedBox(height: 4),
                Text('Disponível: ${Moeda.formatar(widget.saldoCentavos)}',
                    style: AppText.caption(12.5, color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.lg),
                PhdField(
                  label: 'Valor (R\$)',
                  controller: _valor,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Tipo da chave', style: AppText.caption(12.5)),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final t in _tipos)
                      PhdFilterChip(
                        label: t.rotulo,
                        selected: _tipo == t.valor,
                        onTap: () => setState(() => _tipo = t.valor),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                PhdField(
                  label: 'Chave Pix',
                  controller: _chave,
                  keyboardType: _tipo == 'EMAIL'
                      ? TextInputType.emailAddress
                      : _tipo == 'EVP'
                          ? TextInputType.text
                          : TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'O dinheiro vai para a conta dessa chave. Confira antes: Pix enviado não volta.',
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  PhdAviso(texto: _erro!),
                ],
                const SizedBox(height: AppSpacing.lg),
                PhdButton(
                  label: _centavos == null ? 'Sacar' : 'Sacar ${Moeda.formatar(_centavos!)}',
                  icon: Icons.south_west_rounded,
                  loading: _enviando,
                  onPressed: _enviando ? null : _confirmar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
