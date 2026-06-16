import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

class CredentialsModal extends StatefulWidget {
  final String email;
  final String? senhaGerada;
  final VoidCallback onClose;

  const CredentialsModal({
    super.key,
    required this.email,
    this.senhaGerada,
    required this.onClose,
  });

  @override
  State<CredentialsModal> createState() => _CredentialsModalState();
}

class _CredentialsModalState extends State<CredentialsModal> {
  late final String _senha;

  @override
  void initState() {
    super.initState();
    _senha = widget.senhaGerada ?? _generatePassword();
  }

  String _generatePassword() {
    final rand = Random();
    return List.generate(5, (_) => rand.nextInt(10)).join();
  }

  void _copyCredentials() {
    final text = 'Login: ${widget.email}\nSenha: $_senha';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Credenciais copiadas!'),
        backgroundColor: AppColors.active,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendWhatsapp() async {
    final msg = Uri.encodeComponent(
      'Olá! Aqui estão seus dados de acesso ao app PHD Personal:\n'
      'Login: ${widget.email}\n'
      'Senha: $_senha',
    );
    final uri = Uri.parse('https://wa.me/?text=$msg');
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
            const Text(
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
                      const TextSpan(
                        text: '${AppStrings.senhaLabel} ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: _senha,
                        style: const TextStyle(
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
                  child: const Text(
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
              widget.senhaGerada != null
                  ? 'Data de nascimento sem barras'
                  : AppStrings.geraSenha,
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
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
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
