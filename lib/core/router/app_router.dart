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

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final loggedIn = AuthService.isLoggedIn;
      final path = state.matchedLocation;

      // Rotas que existem antes de haver conta. Sem `/cadastro` aqui, o
      // redirect devolveria o visitante para o login justamente quando ele
      // tenta se cadastrar.
      const publicas = {'/login', '/cadastro'};

      if (!loggedIn) {
        return publicas.contains(path) ? null : '/login';
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
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ArquivosScreen(
            alunoId: extra['alunoId'] as String,
            alunoNome: extra['alunoNome'] as String,
          );
        },
      ),
      GoRoute(
        path: '/alunos/perfil',
        builder: (context, state) => AlunoPerfilScreen(
          aluno: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/alunos/adicionar',
        builder: (context, state) => const AddAlunoScreen(),
      ),
      GoRoute(
        path: '/alunos/avaliacao',
        builder: (context, state) => AvaliacaoScreen(
          aluno: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/morfologica',
        builder: (context, state) => AvaliacaoMorfologicaScreen(
          aluno: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/morfologica/dobras',
        builder: (context, state) => AvaliacaoDobraScreen(
          aluno: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/morfologica/bioimpedancia',
        builder: (context, state) => AvaliacaoBioimpedanciaScreen(
          aluno: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores',
        builder: (context, state) => AvaliacaoNeuromotoresScreen(
          aluno: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores/flexibilidade',
        builder: (context, state) => AvaliacaoFlexibilidadeScreen(
          aluno: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores/resistencia',
        builder: (context, state) => AvaliacaoResistenciaScreen(
          aluno: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores/impulsao',
        builder: (context, state) => AvaliacaoImpulsaoScreen(
          aluno: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/alunos/avaliacao/neuromotores/carga',
        builder: (context, state) => AvaliacaoCargaScreen(
          aluno: state.extra as Map<String, dynamic>,
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
        builder: (context, state) => FichaDetalheScreen(
          ficha: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/aluno/home',
        builder: (context, state) => const AlunoHomeScreen(),
      ),
      GoRoute(
        path: '/aluno/treino-simples',
        builder: (context, state) => TreinoSimplesScreen(
          ficha: state.extra as Map<String, dynamic>,
        ),
      ),
      GoRoute(
        path: '/aluno/progresso',
        builder: (context, state) => const ProgressoScreen(),
      ),
      GoRoute(
        path: '/aluno/treino',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return ExecutarTreinoScreen(
            ficha: extra['ficha'] as Map<String, dynamic>,
            modoVideo: extra['modoVideo'] as bool? ?? false,
            diaSelecionado: extra['diaSelecionado'] as int? ?? DateTime.now().weekday % 7,
          );
        },
      ),
    ],
  );
});
