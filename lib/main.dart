import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/layout/desktop.dart';
import 'core/theme/tema.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await NotificationService.init();
  final tema = await TemaApp.carregar();

  runApp(ProviderScope(
    overrides: [temaProvider.overrideWith(() => TemaNotifier(tema))],
    child: const PHDApp(),
  ));
}

class PHDApp extends ConsumerWidget {
  const PHDApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return PhdMaterialApp(
      title: 'PHD Personal',
      routerConfig: router,
      builder: (context, child) => LarguraDeLeitura(router: router, child: child),
    );
  }
}
