import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/widgets.dart';

/// Cadastro de personal.
///
/// Primeira tela do app escrita inteira com o design system. Até existir,
/// não havia como criar o segundo usuário: `AuthService.cadastrarPersonal`
/// estava no código mas nada o chamava.
class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();

  bool _enviando = false;
  String? _erro;

  /// O Supabase pode exigir confirmação de e-mail. Nesse caso o cadastro dá
  /// certo mas não vem sessão, e mandar a pessoa para a home só produziria
  /// uma tela vazia. Então a tela troca de estado e explica o que fazer.
  bool _aguardandoConfirmacao = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _criarConta() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });

    try {
      final r = await AuthService.cadastrarPersonal(
        nome: _nome.text.trim(),
        email: _email.text.trim(),
        password: _senha.text,
      );

      if (!mounted) return;

      if (r.session != null) {
        // O gatilho `handle_new_user` já criou o perfil com role 'personal'.
        context.go('/home');
      } else {
        setState(() => _aguardandoConfirmacao = true);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _erro = _traduzir(e.message));
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não consegui criar a conta. Tente de novo em instantes.');
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _traduzir(String m) {
    final t = m.toLowerCase();
    if (t.contains('already registered') || t.contains('already been registered')) {
      return 'Já existe uma conta com esse e-mail. Tente entrar.';
    }
    if (t.contains('password') && t.contains('6')) {
      return 'A senha precisa de pelo menos 6 caracteres.';
    }
    if (t.contains('weak password')) {
      return 'Senha muito fraca. Misture letras e números.';
    }
    if (t.contains('invalid') && t.contains('email')) {
      return 'Esse e-mail não parece válido.';
    }
    if (t.contains('rate limit') || t.contains('too many')) {
      return 'Muitas tentativas seguidas. Espere um minuto.';
    }
    return 'Não consegui criar a conta: $m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.huge,
          ),
          child: _aguardandoConfirmacao ? _confirmacao() : _formulario(),
        ),
      ),
    );
  }

  // ── Formulário ──────────────────────────────────────────────

  Widget _formulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: PhdIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Voltar para o login',
              onPressed: () => context.go('/login'),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          Text('Criar conta', style: AppText.display(34)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Seus alunos, seus treinos e o seu financeiro num lugar só.',
            style: AppText.body(14.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.huge),

          PhdField(
            label: 'Seu nome',
            controller: _nome,
            hint: 'Como seus alunos te chamam',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Informe seu nome';
              if (t.length < 2) return 'Nome muito curto';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          PhdField(
            label: 'E-mail',
            controller: _email,
            hint: 'voce@email.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.isEmpty) return 'Informe o e-mail';
              // Proposital: só o essencial. Regex de e-mail rigoroso rejeita
              // endereço válido mais vezes do que pega endereço errado —
              // quem confirma de verdade é o e-mail de verificação.
              if (!t.contains('@') || !t.contains('.')) return 'E-mail inválido';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          PhdField(
            label: 'Senha',
            controller: _senha,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            ajuda: 'Mínimo de 6 caracteres',
            onSubmitted: _enviando ? null : _criarConta,
            validator: (v) {
              if ((v ?? '').isEmpty) return 'Crie uma senha';
              if (v!.length < 6) return 'Mínimo de 6 caracteres';
              return null;
            },
          ),

          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.xl),
            PhdAviso(texto: _erro!),
          ],

          const SizedBox(height: AppSpacing.huge),
          PhdButton(
            label: 'Criar conta',
            loading: _enviando,
            onPressed: _criarConta,
          ),
          const SizedBox(height: AppSpacing.xl),

          Center(
            child: TextButton(
              onPressed: _enviando ? null : () => context.go('/login'),
              child: Text.rich(
                TextSpan(
                  text: 'Já tem conta? ',
                  style: AppText.body(13.5, color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                      text: 'Entrar',
                      style: AppText.bodyStrong(13.5, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Depois do cadastro, quando falta confirmar ──────────────

  Widget _confirmacao() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.huge),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.tint(AppColors.accent),
            borderRadius: AppRadius.rXl,
          ),
          child: const Icon(Icons.mark_email_unread_outlined,
              color: AppColors.accent, size: 28),
        ),
        const SizedBox(height: AppSpacing.xxl),

        Text('Confirme seu e-mail', style: AppText.display(30)),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Mandei um link para ${_email.text.trim()}. '
          'Abra o e-mail e clique nele para ativar a conta.',
          style: AppText.body(14.5, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Se não chegar em alguns minutos, olhe o spam.',
          style: AppText.caption(13),
        ),

        const SizedBox(height: AppSpacing.huge),
        PhdButton(
          label: 'Ir para o login',
          onPressed: () => context.go('/login'),
        ),
      ],
    );
  }
}
