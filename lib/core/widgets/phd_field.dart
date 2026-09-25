import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

/// Campo de formulário com rótulo acima.
///
/// Rótulo acima e não `labelText` flutuante de propósito: o rótulo flutuante
/// do Material some para dentro da borda quando o campo é preenchido, e num
/// formulário longo a pessoa perde a referência do que está digitando ao
/// revisar. Acima, ele fica sempre legível.
class PhdField extends StatefulWidget {
  const PhdField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.icon,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autofillHints,
    this.enabled = true,
    this.ajuda,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final IconData? icon;

  /// Liga o olho de mostrar/ocultar.
  final bool obscure;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final bool enabled;

  /// Linha discreta abaixo do campo: "mínimo 6 caracteres", por exemplo.
  /// Some quando há erro de validação, para não competir com a mensagem.
  final String? ajuda;

  final VoidCallback? onSubmitted;

  @override
  State<PhdField> createState() => _PhdFieldState();
}

class _PhdFieldState extends State<PhdField> {
  late bool _escondido = widget.obscure;
  String? _erro;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.caption(12.5)),
        const SizedBox(height: 7),
        TextFormField(
          controller: widget.controller,
          obscureText: _escondido,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          style: AppText.body(15),
          cursorColor: AppColors.accent,
          onFieldSubmitted: widget.onSubmitted == null ? null : (_) => widget.onSubmitted!(),
          validator: (v) {
            final e = widget.validator?.call(v);
            // Guardado no estado só para decidir se a linha de ajuda aparece.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _erro != e) setState(() => _erro = e);
            });
            return e;
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.icon == null
                ? null
                : Icon(widget.icon, color: AppColors.textMuted, size: 19),
            suffixIcon: !widget.obscure
                ? null
                : IconButton(
                    onPressed: () => setState(() => _escondido = !_escondido),
                    icon: Icon(
                      _escondido
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.textMuted,
                      size: 19,
                    ),
                    tooltip: _escondido ? 'Mostrar senha' : 'Ocultar senha',
                  ),
          ),
        ),
        if (widget.ajuda != null && _erro == null) ...[
          const SizedBox(height: 6),
          Text(widget.ajuda!, style: AppText.caption(11.5, color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

/// Aviso dentro de um formulário — erro do servidor, alerta, confirmação.
/// Fica no fluxo da tela em vez de SnackBar porque mensagem que some sozinha
/// é mensagem que a pessoa não leu.
class PhdAviso extends StatelessWidget {
  const PhdAviso({
    super.key,
    required this.texto,
    this.icone = Icons.error_outline_rounded,
    this.cor = AppColors.danger,
    this.corTexto = AppColors.dangerText,
  });

  final String texto;
  final IconData icone;
  final Color cor;
  final Color corTexto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 2,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: AppRadius.rMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: corTexto),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(texto, style: AppText.body(13, color: corTexto))),
        ],
      ),
    );
  }
}
