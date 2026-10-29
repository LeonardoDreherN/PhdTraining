import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_colors.dart';
import 'app_theme.dart';

/// Aparência escolhida no perfil. Fica no aparelho, não na conta: quem usa
/// o celular no claro e o tablet da academia no escuro quer os dois assim.
enum TemaApp {
  sistema('Sistema'),
  claro('Claro'),
  escuro('Escuro');

  const TemaApp(this.rotulo);
  final String rotulo;

  static const _chave = 'tema_app';

  /// Lido antes do `runApp`, para o app já abrir no tema certo em vez de
  /// piscar no escuro e trocar.
  static Future<TemaApp> carregar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final nome = p.getString(_chave);
      return TemaApp.values.firstWhere((t) => t.name == nome, orElse: () => sistema);
    } catch (_) {
      return sistema;
    }
  }

  Brightness brilho(BuildContext context) => switch (this) {
        claro => Brightness.light,
        escuro => Brightness.dark,
        sistema => MediaQuery.platformBrightnessOf(context),
      };
}

class TemaNotifier extends Notifier<TemaApp> {
  TemaNotifier([this._inicial = TemaApp.sistema]);

  final TemaApp _inicial;

  @override
  TemaApp build() => _inicial;

  Future<void> escolher(TemaApp t) async {
    state = t;
    final p = await SharedPreferences.getInstance();
    await p.setString(TemaApp._chave, t.name);
  }
}

final temaProvider = NotifierProvider<TemaNotifier, TemaApp>(TemaNotifier.new);

/// Monta o `MaterialApp` no tema escolhido.
///
/// As cores do app são lidas da paleta ativa na hora do build, então trocar
/// de tema exige duas coisas: ativar a paleta antes de montar o `ThemeData`
/// e remontar a árvore abaixo — é o `KeyedSubtree` com o brilho como chave.
/// A rota atual fica (ela mora no GoRouter, acima disso); o estado das telas
/// abertas recomeça, o que é aceitável para algo que se troca raramente.
class PhdMaterialApp extends ConsumerWidget {
  const PhdMaterialApp({
    super.key,
    required this.title,
    required this.routerConfig,
    this.builder,
  });

  final String title;
  final RouterConfig<Object> routerConfig;
  final Widget Function(BuildContext, Widget?)? builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brilho = ref.watch(temaProvider).brilho(context);
    AppColors.usar(brilho);

    return MaterialApp.router(
      title: title,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.atual,
      routerConfig: routerConfig,
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(brilho),
        child: builder?.call(context, child) ?? child ?? const SizedBox.shrink(),
      ),
    );
  }
}
