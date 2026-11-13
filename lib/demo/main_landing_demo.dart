import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/layout/desktop.dart';
import '../core/theme/app_text.dart';
import '../core/theme/tema.dart';
import '../modules/auth/landing_screen.dart';

/// Só a landing, sem Supabase — para ver a página como o visitante vê.
///
///   flutter build web -t lib/demo/main_landing_demo.dart -o build/demo_landing
///
/// Não faz parte do app publicado.
void main() {
  runApp(const ProviderScope(child: _Demo()));
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
    for (final (p, t) in const [('/login', 'Login'), ('/cadastro', 'Cadastro')])
      GoRoute(
        path: p,
        builder: (context, __) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.go('/'),
              child: Text('$t — fora da demo. Voltar', style: AppText.body(15)),
            ),
          ),
        ),
      ),
  ],
);

class _Demo extends StatelessWidget {
  const _Demo();

  @override
  Widget build(BuildContext context) {
    return PhdMaterialApp(
      title: 'PHD Training & Nutrition',
      routerConfig: _router,
      builder: (context, child) => LarguraDeLeitura(router: _router, child: child),
    );
  }
}
