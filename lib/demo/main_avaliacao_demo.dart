import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/models/perfil.dart';
import '../core/providers/app_providers.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../modules/personal/alunos/avaliacao_bioimpedancia_screen.dart';
import '../modules/personal/alunos/avaliacao_dobras_screen.dart';
import '../modules/personal/alunos/avaliacao_morfologica_screen.dart';
import '../modules/personal/alunos/avaliacao_neuromotores_carga_screen.dart';
import '../modules/personal/alunos/avaliacao_neuromotores_flexibilidade_screen.dart';
import '../modules/personal/alunos/avaliacao_neuromotores_impulsao_screen.dart';
import '../modules/personal/alunos/avaliacao_neuromotores_resistencia_screen.dart';
import '../modules/personal/alunos/avaliacao_neuromotores_screen.dart';
import '../modules/personal/alunos/avaliacao_screen.dart';
import '../modules/personal/avaliacao/avaliacao_cardio_screen.dart';
import '../modules/personal/avaliacao/avaliacao_postural_screen.dart';
import '../modules/personal/avaliacao/avaliacao_sessao_screen.dart';
import 'banco_falso.dart';
import 'dados_demo.dart';

/// Demonstração da avaliação física, sem login e sem Supabase.
///
/// As telas são as de verdade; o banco é [BancoFalso], em memória, com a
/// aluna de [dadosDemo]. Dá para editar à vontade — recarregar a página
/// volta tudo ao começo.
///
///   flutter build web -t lib/demo/main_avaliacao_demo.dart -o build/demo_web
///
/// Depois copie `demo/fotos/*` para `build/demo_web/storage/v1/demo/` e sirva
/// a pasta. Não faz parte do app publicado.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    // A URL de assinatura das fotos sai daqui; apontar para o próprio
    // servidor da demo faz as fotos de exemplo carregarem.
    url: Uri.base.origin,
    anonKey: 'demo',
    httpClient: BancoFalso(dadosDemo()).cliente,
  );

  runApp(ProviderScope(
    overrides: [
      perfilProvider.overrideWith((ref) async => const Perfil(
            id: 'demo-personal',
            role: 'personal',
            nome: 'Rafael Prado',
            cref: '012345-G/SP',
            marcaNome: 'Prado Performance',
          )),
    ],
    child: const _Demo(),
  ));
}

GoRoute _rota(String path, Widget Function(Map<String, dynamic> aluno) tela) => GoRoute(
      path: path,
      builder: (context, state) => tela(state.extra as Map<String, dynamic>? ?? alunaDemo),
    );

final _router = GoRouter(
  initialLocation: '/alunos/avaliacao',
  initialExtra: alunaDemo,
  routes: [
    _rota('/alunos/avaliacao', (a) => AvaliacaoScreen(aluno: a)),
    _rota('/alunos/avaliacao/sessao', (a) => AvaliacaoSessaoScreen(aluno: a)),
    _rota('/alunos/avaliacao/cardio', (a) => AvaliacaoCardioScreen(aluno: a)),
    _rota('/alunos/avaliacao/postural', (a) => AvaliacaoPosturalScreen(aluno: a)),
    _rota('/alunos/avaliacao/morfologica', (a) => AvaliacaoMorfologicaScreen(aluno: a)),
    _rota('/alunos/avaliacao/morfologica/dobras', (a) => AvaliacaoDobraScreen(aluno: a)),
    _rota('/alunos/avaliacao/morfologica/bioimpedancia', (a) => AvaliacaoBioimpedanciaScreen(aluno: a)),
    _rota('/alunos/avaliacao/neuromotores', (a) => AvaliacaoNeuromotoresScreen(aluno: a)),
    _rota('/alunos/avaliacao/neuromotores/flexibilidade', (a) => AvaliacaoFlexibilidadeScreen(aluno: a)),
    _rota('/alunos/avaliacao/neuromotores/resistencia', (a) => AvaliacaoResistenciaScreen(aluno: a)),
    _rota('/alunos/avaliacao/neuromotores/impulsao', (a) => AvaliacaoImpulsaoScreen(aluno: a)),
    _rota('/alunos/avaliacao/neuromotores/carga', (a) => AvaliacaoCargaScreen(aluno: a)),
  ],
);

class _Demo extends StatelessWidget {
  const _Demo();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PHD — Avaliação física (demo)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
      // Mesma trava de largura do app: ele é desenhado para celular.
      builder: (context, child) => ColoredBox(
        color: AppColors.bg,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      ),
    );
  }
}
