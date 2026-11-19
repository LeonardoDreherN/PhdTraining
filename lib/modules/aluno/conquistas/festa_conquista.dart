import 'package:flutter/material.dart';

import '../../../core/models/conquista.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// O momento de dizer "você desbloqueou".
///
/// `conceder_conquistas` sempre devolveu as NOVAS, e até aqui ninguém
/// usava essa lista: a medalha era gravada no banco e o aluno descobria
/// dias depois, se abrisse a tela de recordes. Uma gamificação em que a
/// conquista nunca chega no instante em que foi merecida é uma lista de
/// troféus, não um retorno.
///
/// Os códigos vêm do banco; o texto sai do catálogo do app. Código que
/// o catálogo não conhece é ignorado — um app antigo lendo um marco
/// novo não pode mostrar caixa vazia.
List<Conquista> conquistasDeCodigos(List<String> codigos) => [
      for (final c in codigos)
        if (Conquista.porCodigo(c) case final q?) q,
    ];

/// Mostra as medalhas novas. Não faz nada se não houver nenhuma — quem
/// chama não precisa conferir antes.
Future<void> celebrarConquistas(
  BuildContext context,
  List<String> codigos,
) async {
  final novas = conquistasDeCodigos(codigos);
  if (novas.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _FestaSheet(novas: novas),
  );
}

class _FestaSheet extends StatelessWidget {
  const _FestaSheet({required this.novas});

  final List<Conquista> novas;

  @override
  Widget build(BuildContext context) {
    final uma = novas.length == 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              uma ? 'Conquista desbloqueada!' : '${novas.length} conquistas!',
              textAlign: TextAlign.center,
              style: AppText.display(23),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Mais de quatro vira parede de ícone e a festa perde graça.
            // O resto fica para a tela de recordes, que é feita para
            // olhar medalha com calma.
            for (final c in novas.take(4)) ...[
              _MedalhaNova(conquista: c),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (novas.length > 4) ...[
              const SizedBox(height: 2),
              Text(
                'E mais ${novas.length - 4} — veja todas nas suas conquistas.',
                textAlign: TextAlign.center,
                style: AppText.caption(12, color: AppColors.textMuted),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            PhdButton(
              label: 'Boa!',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// A medalha entrando. A animação é o que separa "você conquistou" de
/// "aqui está uma linha de lista".
class _MedalhaNova extends StatelessWidget {
  const _MedalhaNova({required this.conquista});

  final Conquista conquista;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Curves.elasticOut,
      builder: (_, v, filho) => Transform.scale(scale: v, child: filho),
      child: PhdCard(
        color: AppColors.surfaceHigh,
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.accent),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              child: Icon(conquista.icone, color: AppColors.accent, size: 25),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(conquista.nome, style: AppText.title(15)),
                  const SizedBox(height: 2),
                  Text(conquista.descricao,
                      style:
                          AppText.caption(11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A mesma festa, mas embutida numa tela que já existe — a de fim de
/// treino. Ali o aluno já está parado, lendo os números: abrir uma folha
/// por cima seria interromper a própria comemoração.
class CartaoConquistasNovas extends StatelessWidget {
  const CartaoConquistasNovas({super.key, required this.codigos});

  final List<String> codigos;

  @override
  Widget build(BuildContext context) {
    final novas = conquistasDeCodigos(codigos);
    if (novas.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded,
                size: 17, color: AppColors.accent),
            const SizedBox(width: AppSpacing.sm),
            Text(
              novas.length == 1
                  ? 'Conquista desbloqueada'
                  : '${novas.length} conquistas desbloqueadas',
              style: AppText.bodyStrong(13, color: AppColors.accent),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final c in novas.take(3)) ...[
          _MedalhaNova(conquista: c),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (novas.length > 3)
          Text(
            'E mais ${novas.length - 3} nas suas conquistas.',
            textAlign: TextAlign.center,
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
      ],
    );
  }
}
