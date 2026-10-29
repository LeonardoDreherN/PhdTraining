import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/tema.dart';
import '../core/utils/datas.dart';
import '../core/models/dieta.dart';
import '../core/services/dieta_service.dart';
import '../modules/aluno/dieta/aluno_dieta_screen.dart';
import '../modules/aluno/dieta/lista_compras_screen.dart';
import '../modules/aluno/dieta/receita_screen.dart';
import '../modules/aluno/home/aluno_home_screen.dart';
import '../modules/chat/chat_screen.dart';
import 'banco_falso.dart';
import 'dados_demo.dart';
import 'plano_demo.dart';

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
    ...planoDemo(
      alunoId: a,
      planoId: 'plano-1',
      idsRefeicoes: const ['r1', 'r2', 'r3', 'r4', 'r5'],
      assinado: true,
    ),
    'refeicoes_registro': [
      for (final r in ['r1', 'r2'])
        {'aluno_id': a, 'refeicao_id': r, 'data': Datas.iso(hoje), 'feita': true},
    ],
    'consultas': [
      {
        'id': 'c1', 'personal_id': 'demo-personal', 'aluno_id': a,
        'inicio': hoje.add(const Duration(days: 1, hours: 17, minutes: 30)).toUtc().toIso8601String(),
        'duracao_min': 60, 'tipo': 'avaliacao', 'status': 'agendada', 'local': 'Academia Prado',
        'observacoes': 'Venha de jejum de 4 horas e sem treinar antes: é para a bioimpedância.',
      },
      {
        'id': 'c0', 'personal_id': 'demo-personal', 'aluno_id': a,
        'inicio': hoje.subtract(const Duration(days: 5)).add(const Duration(hours: 8)).toUtc().toIso8601String(),
        'duracao_min': 45, 'tipo': 'retorno', 'status': 'realizada', 'local': 'Academia Prado',
      },
    ],
    'mensagens': [
      {
        'id': 'mg1', 'aluno_id': a, 'autor_id': _userId,
        'texto': 'Posso trocar o arroz por batata-doce no almoço?',
        'criado_em': hoje.add(const Duration(hours: 11, minutes: 5)).toUtc().toIso8601String(),
        'lida_em': hoje.add(const Duration(hours: 11, minutes: 20)).toUtc().toIso8601String(),
      },
      {
        'id': 'mg2', 'aluno_id': a, 'autor_id': 'demo-personal',
        'texto': 'Pode sim! 150 g de batata-doce no lugar dos 120 g de arroz. Mantém o feijão.',
        'criado_em': hoje.add(const Duration(hours: 11, minutes: 22)).toUtc().toIso8601String(),
      },
    ],
    'metas_aluno': [
      {
        'id': 'm1', 'aluno_id': a, 'titulo': 'Beber 2,5 L de água por dia',
        'criado_em': hoje.subtract(const Duration(days: 10)).toUtc().toIso8601String(),
      },
      {
        'id': 'm2', 'aluno_id': a, 'titulo': 'Uma fruta no lanche da tarde',
        'prazo': Datas.iso(hoje.add(const Duration(days: 20))),
        'criado_em': hoje.subtract(const Duration(days: 10)).toUtc().toIso8601String(),
      },
      {
        'id': 'm3', 'aluno_id': a, 'titulo': 'Registrar todas as refeições por 3 dias',
        'concluida_em': hoje.subtract(const Duration(days: 2)).toUtc().toIso8601String(),
        'criado_em': hoje.subtract(const Duration(days: 10)).toUtc().toIso8601String(),
      },
    ],
    // Diário de hoje: o café seguiu o plano, o lanche foi trocado, e um
    // pão de queijo fora do plano.
    'diario_registros': [
      {
        'id': 'd1', 'aluno_id': a, 'data': Datas.iso(hoje), 'refeicao_id': 'r1',
        'titulo': 'Café da manhã', 'aderencia': 'seguiu',
        'registrado_em': hoje.add(const Duration(hours: 7, minutes: 12)).toUtc().toIso8601String(),
      },
      {
        'id': 'd2', 'aluno_id': a, 'data': Datas.iso(hoje), 'refeicao_id': 'r2',
        'titulo': 'Lanche da manhã', 'aderencia': 'parecido',
        'descricao': 'Troquei o whey por 2 ovos cozidos',
        'registrado_em': hoje.add(const Duration(hours: 10, minutes: 5)).toUtc().toIso8601String(),
      },
      {
        'id': 'd3', 'aluno_id': a, 'data': Datas.iso(hoje), 'refeicao_id': null,
        'titulo': 'Café com a equipe', 'descricao': '1 pão de queijo e café sem açúcar',
        'registrado_em': hoje.add(const Duration(hours: 9)).toUtc().toIso8601String(),
      },
    ],
    'agua_registros': [
      for (final (i, ml) in const [500, 250, 250].indexed)
        {
          'id': 'ag$i', 'aluno_id': a, 'data': Datas.iso(hoje), 'ml': ml,
          'registrado_em': hoje.add(Duration(hours: 7 + i * 2)).toUtc().toIso8601String(),
        },
    ],
    // Pesagens de casa, uma por semana, descendo devagar.
    'peso_registros': [
      for (var i = 6; i >= 1; i--)
        {
          'id': 'p$i', 'aluno_id': a,
          'data': Datas.iso(hoje.subtract(Duration(days: 7 * i - 3))),
          'peso_kg': 66.2 - (6 - i) * 0.3,
        },
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
    // Rotas só da demo, para o vídeo abrir cada tela direto.
    GoRoute(
      path: '/compras',
      builder: (_, __) => _ComPlano((p) => ListaComprasScreen(plano: p)),
    ),
    GoRoute(
      path: '/receita',
      builder: (_, __) => _ComPlano((p) {
        final rr = p.refeicoes.expand((r) => r.receitas).first;
        return ReceitaScreen(receita: rr.receita, porcoes: rr.porcoes);
      }),
    ),
    GoRoute(
      path: '/chat',
      builder: (_, __) => const ChatScreen(alunoId: 'demo-aluna', titulo: 'Rafael Prado', subtitulo: 'Seu personal'),
    ),
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

/// Carrega o plano da aluna e monta a tela com ele.
class _ComPlano extends StatelessWidget {
  const _ComPlano(this.tela);

  final Widget Function(PlanoAlimentar) tela;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlanoAlimentar?>(
      future: DietaService.planoAtivo('demo-aluna'),
      builder: (_, s) => s.data == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : tela(s.data!),
    );
  }
}
