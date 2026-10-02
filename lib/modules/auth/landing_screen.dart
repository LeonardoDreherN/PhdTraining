import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/widgets.dart';

/// A primeira tela de quem abre o link sem estar logado.
///
/// Duas pessoas muito diferentes chegam aqui: o personal, que talvez nunca
/// tenha ouvido falar do sistema, e o aluno, que recebeu o link do personal
/// dele e já tem senha. A página orienta os dois — mas as duas seções levam
/// ao MESMO login, porque o papel já está gravado no perfil e o app decide
/// o destino sozinho. Perguntar "você é aluno ou personal?" só criaria uma
/// chance de errar.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.huge,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Marca(),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Treino, avaliação e\nacompanhamento\nno mesmo lugar.',
                style: AppText.display(30).copyWith(height: 1.18),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'O sistema que o personal usa para montar os treinos e '
                'acompanhar a evolução — e que o aluno abre na academia.',
                style: AppText.body(14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.huge),

              // ── Personal ────────────────────────────────────
              _Secao(
                etiqueta: 'Para personais',
                titulo: 'Seus alunos organizados',
                // Só o que já funciona. Prometer financeiro ou dieta aqui
                // seria quebrar a confiança no primeiro minuto de uso.
                itens: const [
                  'Fichas de treino montadas exercício a exercício',
                  'Avaliação física: dobras, bioimpedância, neuromotores',
                  'Progresso do aluno com histórico e fotos',
                  'Biblioteca de exercícios compartilhada',
                ],
                acao: PhdButton(
                  label: 'Criar conta de personal',
                  onPressed: () => context.go('/cadastro'),
                ),
                secundaria: TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'Já tenho conta',
                    style: AppText.bodyStrong(13.5, color: AppColors.textSecondary),
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Aluno ───────────────────────────────────────
              _Secao(
                etiqueta: 'Para alunos',
                titulo: 'Seu treino no celular',
                itens: const [
                  'O treino que seu personal montou, na ordem certa',
                  'Marque as séries conforme executa',
                  'Veja sua evolução ao longo das semanas',
                ],
                acao: PhdButton(
                  label: 'Entrar',
                  variant: PhdButtonVariant.secondary,
                  onPressed: () => context.go('/login'),
                ),
                // O aluno não se cadastra sozinho: quem cria o acesso dele é
                // o personal. Sem este aviso ele procura um "criar conta"
                // que não serve para ele, e trava logo na primeira tela.
                nota: 'Quem cria seu acesso é o seu personal. Use o e-mail e '
                    'a senha que ele passou — se não funcionar, fale com ele.',
              ),

              const SizedBox(height: AppSpacing.huge),
              Center(
                child: Text(
                  'PHD Training',
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: AppRadius.rMd,
          ),
          child: Text(
            'P',
            style: AppText.display(19, color: AppColors.onAccent),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text('PHD', style: AppText.display(19)),
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  const _Secao({
    required this.etiqueta,
    required this.titulo,
    required this.itens,
    required this.acao,
    this.secundaria,
    this.nota,
  });

  final String etiqueta;
  final String titulo;
  final List<String> itens;
  final Widget acao;
  final Widget? secundaria;
  final String? nota;

  @override
  Widget build(BuildContext context) {
    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: AppText.caption(11, color: AppColors.accent).copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(titulo, style: AppText.title(18)),
          const SizedBox(height: AppSpacing.lg),
          for (final item in itens) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 5),
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item,
                    style: AppText.body(13.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (nota != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: AppRadius.rSm,
              ),
              child: Text(
                nota!,
                style: AppText.caption(12, color: AppColors.textMuted),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          acao,
          if (secundaria != null)
            Align(alignment: Alignment.center, child: secundaria!),
        ],
      ),
    );
  }
}
