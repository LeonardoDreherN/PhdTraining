import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await NotificationService.init();

  runApp(const ProviderScope(child: PHDApp()));
}

class PHDApp extends ConsumerWidget {
  const PHDApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'PHD Personal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) => _LarguraDeLeitura(child: child),
    );
  }
}

/// No navegador a janela pode ter 2000px, e um campo de e-mail esticado nessa
/// largura é impossível de usar — o olho perde a linha entre o rótulo e o
/// campo. O app é desenhado para 390px, então acima de [_maxLargura] ele para
/// de crescer e fica centralizado, com o fundo preenchendo o resto.
///
/// Quando o painel do personal ganhar um layout de desktop de verdade
/// (tabela, coluna lateral), esta trava sai para as rotas de personal e fica
/// só nas do aluno.
class _LarguraDeLeitura extends StatelessWidget {
  const _LarguraDeLeitura({required this.child});

  static const double _maxLargura = 480;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child == null) return const SizedBox.shrink();

    return ColoredBox(
      color: AppColors.bg,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxLargura),
          child: child!,
        ),
      ),
    );
  }
}
