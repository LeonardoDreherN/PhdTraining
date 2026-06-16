import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => PersonalShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
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
        path: '/fichas',
        builder: (context, state) => const FichasScreen(),
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
