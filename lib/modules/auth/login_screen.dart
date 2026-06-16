import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/profile_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _senhaVisivel = false;
  bool _carregando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await AuthService.login(
        email: _emailController.text.trim(),
        password: _senhaController.text,
      );
      final role = await ProfileService.getRole();
      if (mounted) {
        if (role == 'personal') {
          context.go('/home');
        } else {
          context.go('/aluno/home');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_traduzirErro(e.message)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _traduzirErro(String message) {
    if (message.contains('Invalid login')) return 'E-mail ou senha incorretos';
    if (message.contains('Email not confirmed')) return 'Confirme seu e-mail antes de entrar';
    if (message.contains('Too many requests')) return 'Muitas tentativas. Aguarde um momento';
    return 'Erro ao entrar. Tente novamente';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                _buildLogo(),
                const SizedBox(height: 12),
                _buildSubtitle(),
                const SizedBox(height: 56),
                _buildEmailField(),
                const SizedBox(height: 16),
                _buildSenhaField(),
                const SizedBox(height: 10),
                _buildEsqueceuSenha(),
                const SizedBox(height: 32),
                _buildBotaoEntrar(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/logo_white.png',
      height: 56,
      fit: BoxFit.contain,
    );
  }

  Widget _buildSubtitle() {
    return const Text(
      'Gestão para Personal Trainers',
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('E-mail', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'seu@email.com',
            prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 20),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
            if (!v.contains('@')) return 'E-mail inválido';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSenhaField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Senha', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _senhaController,
          obscureText: !_senhaVisivel,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary, size: 20),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _senhaVisivel = !_senhaVisivel),
              child: Icon(
                _senhaVisivel ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Informe a senha';
            if (v.length < 4) return 'Senha muito curta';
            return null;
          },
        ),
      ],
    );
  }

  Future<void> _esqueceuSenha() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Redefinir senha',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informe seu e-mail para receber o link de redefinição.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'seu@email.com',
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    final email = emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) return;
    await AuthService.resetPassword(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link enviado! Verifique seu e-mail.')),
      );
    }
  }

  Widget _buildEsqueceuSenha() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: _esqueceuSenha,
        child: const Text(
          'Esqueci minha senha',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBotaoEntrar() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _carregando ? null : _entrar,
        child: _carregando
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

}
