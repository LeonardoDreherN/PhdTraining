import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';
import '../theme/tema.dart';

/// "Aparência: Sistema · Claro · Escuro", para as telas de perfil.
class PhdSeletorTema extends ConsumerWidget {
  const PhdSeletorTema({super.key});

  static const _icones = {
    TemaApp.sistema: Icons.phone_iphone_rounded,
    TemaApp.claro: Icons.light_mode_rounded,
    TemaApp.escuro: Icons.dark_mode_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atual = ref.watch(temaProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.rLg,
      ),
      child: Row(
        children: [
          for (final t in TemaApp.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: t == atual,
                label: 'Tema ${t.rotulo}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(temaProvider.notifier).escolher(t),
                  child: AnimatedContainer(
                    duration: AppDuration.fast,
                    height: kMinTouch,
                    decoration: BoxDecoration(
                      color: t == atual ? AppColors.surface : Colors.transparent,
                      borderRadius: AppRadius.rMd,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _icones[t],
                          size: 17,
                          color: t == atual ? AppColors.accent : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          t.rotulo,
                          style: AppText.bodyStrong(
                            13,
                            color: t == atual ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
