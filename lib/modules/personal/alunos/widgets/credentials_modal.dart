import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/whatsapp.dart';

class CredentialsModal extends StatefulWidget {
  final String email;

  /// A senha que foi **de fato** gravada no cadastro.
  ///
  /// Obrigatória, e o modal nunca inventa outra. Antes ela era opcional e,
  /// faltando, este modal sorteava uma de 5 dígitos — enquanto a tela
  /// gravava no banco uma de 6. O aluno recebia uma senha que não entrava.
  final String senha;

  /// Para a mensagem ir direto para ele, em vez de abrir o WhatsApp vazio
  /// e o personal ter de procurar o contato na lista.
  final String? whatsapp;

  final String? nome;

  /// Muda só a linha de ajuda embaixo da senha, para o personal saber o
  /// que dizer se o aluno esquecer.
  final bool senhaEhNascimento;

  final VoidCallback onClose;

  const CredentialsModal({
    super.key,
    required this.email,
    required this.senha,
    this.whatsapp,
    this.nome,
    this.senhaEhNascimento = false,
    required this.onClose,
  });

  @override
  State<CredentialsModal> createState() => _CredentialsModalState();
}

class _CredentialsModalState extends State<CredentialsModal> {
  String get _senha => widget.senha;

  /// Texto único para copiar e para o WhatsApp: duas versões divergiriam
  /// na primeira vez que alguém mexesse em uma só.
  String get _mensagem {
    final primeiro = (widget.nome ?? '').trim().split(' ').first;
    return '${primeiro.isEmpty ? 'Olá' : 'Olá, $primeiro'}! '
        'Seu acesso ao PHD Training está pronto.\n\n'
        'Entre em: ${AppConfig.login}\n'
        'Login: ${widget.email}\n'
        'Senha: $_senha';
  }

  void _copyCredentials() {
    Clipboard.setData(ClipboardData(text: _mensagem));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Credenciais copiadas!'),
        backgroundColor: AppColors.active,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendWhatsapp() async {
    // `linkWhatsApp` monta o `wa.me` com o DDI e devolve nulo quando o
    // número não dá para discar. Sem número, abre o WhatsApp só com o
    // texto e o personal escolhe o contato.
    final uri = linkWhatsApp(widget.whatsapp, mensagem: _mensagem) ??
        Uri.https('wa.me', '/', {'text': _mensagem});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.envieInfoAluno,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _buildCredentialRow(
              label: AppStrings.loginLabel,
              value: widget.email,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${AppStrings.senhaLabel} ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: _senha,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _copyCredentials,
                  child: Text(
                    AppStrings.copiar,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.senhaEhNascimento
                  ? 'Data de nascimento sem barras'
                  : AppStrings.geraSenha,
              style: TextStyle(color: AppColors.textHint, fontSize: 12),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _sendWhatsapp,
              child: const Text(AppStrings.enviarWhatsapp),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: widget.onClose,
              child: const Text(AppStrings.fechar),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow({required String label, required String value}) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
