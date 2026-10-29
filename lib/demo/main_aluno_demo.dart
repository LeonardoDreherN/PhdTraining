import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/tema.dart';
import '../core/utils/datas.dart';
import '../modules/aluno/dieta/aluno_dieta_screen.dart';
import '../modules/aluno/home/aluno_home_screen.dart';
import 'banco_falso.dart';
import 'dados_demo.dart';

/// Demonstração da home do aluno, sem login e sem Supabase.
///
/// Mesma ideia de `main_avaliacao_demo.dart`: telas de verdade sobre o
/// [BancoFalso]. A aluna é a mesma das avaliações, agora com fichas, dez
/// semanas de treinos e um plano alimentar.
///
///   flutter build web -t lib/demo/main_aluno_demo.dart -o build/demo_aluno
///
/// Não faz parte do app publicado.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Uri.base.origin,
    anonKey: 'demo',
    httpClient: BancoFalso({...dadosDemo(), ..._dadosDoAluno()}).cliente,
  );

  // A home lê `auth.currentUser`. Um token que não é JWT não tem `exp`, e
  // o gotrue trata sessão sem `exp` como válida — não tenta renovar.
  await Supabase.instance.client.auth.recoverSession(jsonEncode({
    'access_token': 'demo',
    'token_type': 'bearer',
    'refresh_token': 'demo',
    'user': {
      'id': _userId,
      'email': alunaDemo['email'],
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': '2026-01-01T00:00:00Z',
    },
  }));

  runApp(ProviderScope(
    overrides: [temaProvider.overrideWith(() => TemaNotifier(_temaDaUrl()))],
    child: const _Demo(),
  ));
}

const _userId = 'demo-user';

Map<String, List<Map<String, dynamic>>> _dadosDoAluno() {
  const a = 'demo-aluna';
  final agora = DateTime.now();
  final hoje = Datas.dia(agora);
  final segunda = hoje.subtract(Duration(days: hoje.weekday - 1));

  const fichas = [
    ('ficha-a', 'Treino A — Superiores', [1, 4]),
    ('ficha-b', 'Treino B — Inferiores', [2, 5]),
    ('ficha-c', 'Treino C — Glúteos e core', [3, 6]),
  ];
  const exercicios = {
    'ficha-a': [('Peito', 4), ('Peito', 3), ('Costas', 4), ('Costas', 3), ('Ombros', 3), ('Bíceps', 3), ('Tríceps', 3)],
    'ficha-b': [('Quadríceps', 4), ('Quadríceps', 4), ('Posterior', 3), ('Posterior', 3), ('Panturrilha', 4), ('Adutores', 3)],
    'ficha-c': [('Glúteos', 4), ('Glúteos', 4), ('Glúteos', 3), ('Abdômen', 3), ('Abdômen', 3), ('Lombar', 3)],
  };

  // Dez semanas para trás, três treinos por semana — menos uma semana
  // falhada lá atrás, para a sequência não ser "desde sempre".
  final execucoes = <Map<String, dynamic>>[];
  for (var semana = 9; semana >= 1; semana--) {
    if (semana == 7) continue;
    for (final (i, f) in fichas.indexed) {
      final dia = segunda.subtract(Duration(days: 7 * semana)).add(Duration(days: f.$3.first - 1));
      execucoes.add(_execucao(a, f.$1, f.$2, dia.add(Duration(hours: 18 + i)), 48 + i * 6));
    }
  }
  // Esta semana: os dias antes de hoje que tinham treino.
  for (final f in fichas) {
    for (final d in f.$3) {
      final dia = segunda.add(Duration(days: d - 1));
      if (dia.isBefore(hoje)) {
        execucoes.add(_execucao(a, f.$1, f.$2, dia.add(const Duration(hours: 7)), 52));
      }
    }
  }

  const alimentos = {
    'ovo': {'nome': 'Ovo cozido', 'kcal': 146, 'proteina': 13.3, 'carboidrato': 0.6, 'gordura': 9.5},
    'pao': {'nome': 'Pão integral', 'kcal': 253, 'proteina': 9.4, 'carboidrato': 49.9, 'gordura': 3.7},
    'arroz': {'nome': 'Arroz integral cozido', 'kcal': 124, 'proteina': 2.6, 'carboidrato': 25.8, 'gordura': 1},
    'frango': {'nome': 'Peito de frango grelhado', 'kcal': 159, 'proteina': 32, 'carboidrato': 0, 'gordura': 2.5},
    'feijao': {'nome': 'Feijão carioca cozido', 'kcal': 76, 'proteina': 4.8, 'carboidrato': 13.6, 'gordura': 0.5},
    'iogurte': {'nome': 'Iogurte natural', 'kcal': 51, 'proteina': 4.1, 'carboidrato': 1.9, 'gordura': 3},
    'banana': {'nome': 'Banana prata', 'kcal': 98, 'proteina': 1.3, 'carboidrato': 26, 'gordura': 0.1},
    'tilapia': {'nome': 'Tilápia grelhada', 'kcal': 128, 'proteina': 26, 'carboidrato': 0, 'gordura': 2.7},
    'batata': {'nome': 'Batata-doce cozida', 'kcal': 77, 'proteina': 0.6, 'carboidrato': 18.4, 'gordura': 0.1},
    'whey': {'nome': 'Whey protein', 'kcal': 400, 'proteina': 80, 'carboidrato': 8, 'gordura': 6},
  };
  const refeicoes = [
    ('r1', 'Café da manhã', '07:00', [('ovo', 100), ('pao', 50), ('banana', 80)]),
    ('r2', 'Lanche da manhã', '10:00', [('iogurte', 170), ('whey', 30)]),
    ('r3', 'Almoço', '12:30', [('arroz', 120), ('feijao', 100), ('frango', 130)]),
    ('r4', 'Pré-treino', '16:30', [('banana', 100), ('pao', 50)]),
    ('r5', 'Jantar', '20:00', [('tilapia', 150), ('batata', 150)]),
  ];

  return {
    'alunos': [
      {...alunaDemo, 'user_id': _userId, 'anamnese_tipo': 'nenhuma'},
    ],
    'profiles': [
      {'id': _userId, 'role': 'aluno', 'nome': 'Marina Costa'},
      {
        'id': 'demo-personal',
        'nome': 'Rafael Prado',
        'cref': '012345-G/SP',
        'whatsapp': '(11) 98765-4321',
        'marca_nome': 'Prado Performance',
      },
    ],
    'aluno_fichas': [
      for (final f in fichas)
        {
          'id': 'af-${f.$1}',
          'aluno_id': a,
          'ativa': true,
          'dias_semana': f.$3,
          'ficha_id': f.$1,
          'fichas': {'id': f.$1, 'nome': f.$2, 'descricao': null},
        },
    ],
    'ficha_exercicios': [
      for (final e in exercicios.entries)
        for (final (i, x) in e.value.indexed)
          {
            'id': '${e.key}-$i',
            'ficha_id': e.key,
            'series': x.$2,
            'descanso_segundos': 75,
            'ordem': i,
            'exercicios': {'grupo_muscular': x.$1},
          },
    ],
    'treino_execucoes': execucoes,
    'planos_alimentares': [
      {
        'id': 'plano-1',
        'aluno_id': a,
        'nome': 'Recomposição corporal',
        'objetivo': 'emagrecimento',
        'ativo': true,
        'meta_kcal': 1850,
        'meta_proteina': 140,
        'meta_carboidrato': 190,
        'meta_gordura': 55,
        'agua_ml': 2500,
      },
    ],
    'plano_refeicoes': [
      for (final (i, r) in refeicoes.indexed)
        {'id': r.$1, 'plano_id': 'plano-1', 'nome': r.$2, 'horario': '${r.$3}:00', 'ordem': i},
    ],
    'refeicao_itens': [
      for (final r in refeicoes)
        for (final (i, it) in r.$4.indexed)
          {
            'id': '${r.$1}-$i',
            'refeicao_id': r.$1,
            'alimento_id': it.$1,
            'quantidade_g': it.$2,
            'ordem': i,
            'alimentos': {'id': it.$1, ...alimentos[it.$1]!},
          },
    ],
    'refeicoes_registro': [
      for (final r in ['r1', 'r2'])
        {'aluno_id': a, 'refeicao_id': r, 'data': Datas.iso(hoje), 'feita': true},
    ],
  };
}

Map<String, dynamic> _execucao(String alunoId, String fichaId, String nome, DateTime quando, int min) => {
      'id': '$fichaId-${quando.millisecondsSinceEpoch}',
      'aluno_id': alunoId,
      'aluno_user_id': _userId,
      'ficha_id': fichaId,
      'ficha_nome': nome,
      'executado_em': quando.toUtc().toIso8601String(),
      'duracao_minutos': min,
      'total_exercicios': 6,
    };

/// `?tema=claro` ou `?tema=escuro` na URL fixa o tema da demo.
TemaApp _temaDaUrl() => TemaApp.values.firstWhere(
      (t) => t.name == Uri.base.queryParameters['tema'],
      orElse: () => TemaApp.sistema,
    );

final _router = GoRouter(
  initialLocation: '/aluno/home',
  routes: [
    GoRoute(path: '/aluno/home', builder: (_, __) => const AlunoHomeScreen()),
    GoRoute(
      path: '/aluno/dieta',
      builder: (_, s) => AlunoDietaScreen(
        alunoId: (s.extra as Map?)?['alunoId'] as String? ?? 'demo-aluna',
      ),
    ),
  ],
);

class _Demo extends StatelessWidget {
  const _Demo();

  @override
  Widget build(BuildContext context) {
    return PhdMaterialApp(
      title: 'PHD — Home do aluno (demo)',
      routerConfig: _router,
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
