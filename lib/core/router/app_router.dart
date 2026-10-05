import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../../modules/personal/shell/personal_shell.dart';
import '../../modules/personal/home/home_screen.dart';
import '../../modules/personal/alunos/add_aluno_screen.dart';
import '../../modules/personal/alunos/alunos_screen.dart';
import '../../modules/personal/alunos/aluno_perfil_screen.dart';
import '../../modules/personal/alunos/arquivos_screen.dart';
import '../../modules/personal/exercicios/exercicios_screen.dart';
import '../../modules/personal/exercicios/add_exercicio_screen.dart';
import '../../modules/personal/fichas/fichas_screen.dart';
import '../../modules/personal/fichas/ficha_detalhe_screen.dart';
import '../../modules/personal/relatorios/relatorios_screen.dart';
import '../../modules/personal/perfil/personal_perfil_screen.dart';
import '../../modules/aluno/home/aluno_home_screen.dart';
import '../../modules/aluno/treino/executar_treino_screen.dart';
import '../../modules/aluno/treino/treino_simples_screen.dart';
import '../../modules/aluno/progresso/progresso_screen.dart';
import '../../modules/auth/cadastro_screen.dart';
import '../../modules/auth/landing_screen.dart';
import '../../modules/auth/login_screen.dart';
import '../../modules/personal/alunos/avaliacao_screen.dart';
import '../../modules/personal/alunos/avaliacao_morfologica_screen.dart';
import '../../modules/personal/alunos/avaliacao_dobras_screen.dart';
import '../../modules/personal/alunos/avaliacao_bioimpedancia_screen.dart';
import '../../modules/personal/alunos/avaliacao_neuromotores_screen.dart';
import '../../modules/personal/alunos/avaliacao_neuromotores_flexibilidade_screen.dart';
import '../../modules/personal/alunos/avaliacao_neuromotores_resistencia_screen.dart';
import '../../modules/personal/alunos/avaliacao_neuromotores_impulsao_screen.dart';
import '../../modules/personal/alunos/avaliacao_neuromotores_carga_screen.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/widgets.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final loggedIn = AuthService.isLoggedIn;
      final path = state.matchedLocation;

      // Rotas que existem antes de haver conta. Sem `/cadastro` aqui, o
      // redirect devolveria o visitante para o login justamente quando ele
      // tenta se cadastrar.
      const publicas = {'/', '/login', '/cadastro'};

      if (!loggedIn) {
        // Quem chega sem conta cai na apresentação, não direto no
        // formulário: o aluno precisa saber que quem cria o acesso dele
        // é o personal, e o personal precisa saber o que é isto.
        return publicas.contains(path) ? null : '/';
      }

      // Already logged in — skip the login screen
      if (publicas.contains(path)) {
        try {
          final role = await ProfileService.getRole();
          return role == 'personal' ? '/home' : '/aluno/home';
        } catch (_) {
          return '/home';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/cadastro',
        builder: (context, state) => const CadastroScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => PersonalShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          // `/fichas` e `/exercicios` ficam dentro do Shell para manter a
          // barra inferior visível: as duas são destino de aba, e sair da
          // navegação no meio do fluxo desorienta.
          GoRoute(
            path: '/fichas',
            builder: (context, state) => const FichasScreen(),
          ),
          GoRoute(
            path: '/exercicios',
            builder: (context, state) => const ExerciciosScreen(),
          ),
          GoRoute(
            path: '/alunos',
            builder: (context, state) => const AlunosScreen(),
          ),
          GoRoute(
            path: '/relatorios',
            builder: (context, state) => const RelatoriosScreen(),
          ),
          GoRoute(
            path: '/perfil',
            builder: (context, state) => const PersonalPerfilScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/alunos/arquivos',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => ArquivosScreen(
            alunoId: e['alunoId'] as String,
            alunoNome: e['alunoNome'] as String,
          ),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/perfil',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AlunoPerfilScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/adicionar',
        builder: (context, state) => const AddAlunoScreen(),
      ),
      GoRoute(
        path: '/alunos/avaliacao',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AvaliacaoScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/morfologica',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AvaliacaoMorfologicaScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/morfologica/dobras',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AvaliacaoDobraScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/morfologica/bioimpedancia',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AvaliacaoBioimpedanciaScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AvaliacaoNeuromotoresScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores/flexibilidade',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AvaliacaoFlexibilidadeScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores/resistencia',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AvaliacaoResistenciaScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores/impulsao',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AvaliacaoImpulsaoScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores/carga',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => AvaliacaoCargaScreen(aluno: e),
          voltarPara: '/alunos',
        ),
      ),
      GoRoute(
        path: '/exercicios/adicionar',
        builder: (context, state) => AddExercicioScreen(
          exercicio: state.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(
        path: '/fichas/detalhe',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => FichaDetalheScreen(ficha: e),
          voltarPara: '/fichas',
        ),
      ),
      GoRoute(
        path: '/aluno/home',
        builder: (context, state) => const AlunoHomeScreen(),
      ),
      GoRoute(
        path: '/aluno/treino-simples',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => TreinoSimplesScreen(ficha: e),
          voltarPara: '/aluno/home',
        ),
      ),
      GoRoute(
        path: '/aluno/progresso',
        builder: (context, state) => const ProgressoScreen(),
      ),
      GoRoute(
        path: '/aluno/treino',
        builder: (context, state) => _exigeExtra(
          state,
          (e) => ExecutarTreinoScreen(
            ficha: e['ficha'] as Map<String, dynamic>,
            modoVideo: e['modoVideo'] as bool? ?? false,
            diaSelecionado:
                e['diaSelecionado'] as int? ?? DateTime.now().weekday % 7,
          ),
          voltarPara: '/aluno/home',
        ),
      ),
    ],
  );
});

/// Protege as rotas que dependem de `state.extra`.
///
/// `extra` é um objeto Dart em memória: ele **não** sobrevive a um
/// recarregamento do navegador nem a um link colado. Quando isso acontece o
/// Flutter web reconstrói a rota com `extra` nulo, e o `as Map<String,
/// dynamic>` lançava dentro do `builder` — o que no navegador aparece como
/// tela preta, sem mensagem nenhuma. Foi o que o personal viu.
///
/// A correção de fundo é passar o id pela URL (`/fichas/:id`) e buscar os
/// dados na tela. Enquanto essa mudança não acontece, isto garante que a
/// pessoa veja o que houve e tenha como voltar.
Widget _exigeExtra(
  GoRouterState state,
  Widget Function(Map<String, dynamic> extra) constroi, {
  required String voltarPara,
}) {
  final extra = state.extra;
  if (extra is Map<String, dynamic>) return constroi(extra);
  return _ContextoPerdido(voltarPara: voltarPara);
}

class _ContextoPerdido extends StatelessWidget {
  const _ContextoPerdido({required this.voltarPara});

  final String voltarPara;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: PhdEmptyState(
          icon: Icons.refresh_rounded,
          title: 'Precisa abrir de novo',
          message: 'Esta tela depende do item que você selecionou, e essa '
              'informação se perde quando a página é recarregada. '
              'Volte e escolha de novo.',
          actionLabel: 'Voltar',
          onAction: () => context.go(voltarPara),
        ),
      ),
    );
  }
}
