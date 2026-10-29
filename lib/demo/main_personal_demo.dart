import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/tema.dart';
import '../core/utils/datas.dart';
import '../modules/personal/alunos/aluno_perfil_screen.dart';
import '../modules/personal/agenda/agenda_screen.dart';
import '../modules/personal/dieta/adesao_screen.dart';
import '../modules/personal/dieta/dieta_screen.dart';
import '../modules/personal/dieta/plano_montador_screen.dart';
import '../modules/personal/dieta/receitas_screen.dart';
import '../modules/personal/mensagens/caixa_screen.dart';
import '../modules/personal/home/home_screen.dart';
import '../modules/personal/shell/personal_shell.dart';
import 'banco_falso.dart';
import 'plano_demo.dart';

/// Demonstração da home do personal, sem login e sem Supabase.
///
/// Mesma ideia das outras demos: a tela de verdade sobre o [BancoFalso].
/// Oito alunos, seis meses de mensalidades e dez dias de treinos.
///
///   flutter build web -t lib/demo/main_personal_demo.dart -o build/demo_personal
///
/// Não faz parte do app publicado.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Uri.base.origin,
    anonKey: 'demo',
    httpClient: BancoFalso(_dados()).cliente,
  );

  // Token que não é JWT não tem `exp`: o gotrue trata como sessão válida.
  await Supabase.instance.client.auth.recoverSession(jsonEncode({
    'access_token': 'demo',
    'token_type': 'bearer',
    'refresh_token': 'demo',
    'user': {
      'id': _personal,
      'email': 'rafael@exemplo.com',
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

const _personal = 'demo-personal';

Map<String, List<Map<String, dynamic>>> _dados() {
  final agora = DateTime.now();
  final hoje = Datas.dia(agora);

  // (nome, whatsapp, nascimento, dias desde o cadastro, dias de treino
  // nos últimos 10 dias — 0 é hoje)
  final alunos = [
    ('Marina Costa', '11987654321', '1993-05-14', 200, [0, 1, 3, 5, 7]),
    ('Leonardo Dreher', '11912345678', '1990-03-02', 150, <int>[]),
    (
      'Lidiane Caroline Lohn',
      '47999887766',
      '1988-${_mmdd(hoje.add(const Duration(days: 2)))}',
      120,
      <int>[]
    ),
    ('Bruno Almeida', '11955554444', '1995-08-21', 90, [0, 2, 4, 6]),
    ('Camila Ribeiro', '21988887777', '1997-12-03', 60, [1, 2, 4]),
    ('Thiago Nunes', '31977776666', '1985-02-17', 45, [0, 3]),
    ('Júlia Martins', '41966665555', '1999-07-09', 20, [2, 5]),
    ('Pedro Henrique', '11944443333', '2000-10-30', 6, [1]),
  ];
  const fichas = [
    'Treino A — Superiores',
    'Treino B — Inferiores',
    'Treino C — Glúteos e core'
  ];

  final linhasAlunos = <Map<String, dynamic>>[];
  final execucoes = <Map<String, dynamic>>[];
  final cobrancas = <Map<String, dynamic>>[];

  for (final (i, a) in alunos.indexed) {
    final id = 'aluno-$i';
    linhasAlunos.add({
      'id': id,
      'personal_id': _personal,
      'nome': a.$1,
      'whatsapp': a.$2,
      'data_nascimento': a.$3,
      'ativo': true,
      'anamnese_tipo': 'nenhuma',
      'criado_em':
          hoje.subtract(Duration(days: a.$4)).toUtc().toIso8601String(),
    });

    for (final (j, d) in a.$5.indexed) {
      final quando = hoje
          .subtract(Duration(days: d))
          .add(Duration(hours: d == 0 ? 7 + i % 3 : 18));
      if (quando.isAfter(agora)) continue;
      execucoes.add({
        'id': 'ex-$i-$j',
        'personal_id': _personal,
        'aluno_id': id,
        'aluno_nome': a.$1,
        'ficha_nome': fichas[(i + j) % 3],
        'executado_em': quando.toUtc().toIso8601String(),
        'duracao_minutos': 45 + (i * 7 + j * 5) % 25,
      });
    }

    // Mensalidade de R$ 280 a 450, paga nos últimos seis meses — quem
    // entrou depois só paga a partir do mês em que entrou.
    final valor = 28000 + (i % 4) * 5500;
    for (var m = 5; m >= 0; m--) {
      final venc = DateTime(agora.year, agora.month - m, 10);
      if (venc.isBefore(hoje.subtract(Duration(days: a.$4)))) continue;
      final atrasado = i == 2 && m == 0;
      final pendente = m == 0 && i >= 6;
      cobrancas.add({
        'id': 'cob-$i-$m',
        'personal_id': _personal,
        'aluno_id': id,
        'valor_centavos': valor,
        'vencimento': Datas.iso(
            m == 0 && pendente ? hoje.add(const Duration(days: 5)) : venc),
        'status': atrasado ? 'atrasado' : (pendente ? 'pendente' : 'pago'),
        'pago_em': atrasado || pendente
            ? null
            : venc.add(Duration(days: i % 3)).toUtc().toIso8601String(),
      });
    }
  }

  return {
    'profiles': [
      {
        'id': _personal,
        'role': 'personal',
        'nome': 'Rafael Prado',
        'cref': '012345-G/SP',
        'marca_nome': 'Prado Performance',
        'crn': '12345/P',
      },
    ],
    'alunos': linhasAlunos,
    'fichas': [
      for (final (i, f) in fichas.indexed)
        {'id': 'ficha-$i', 'personal_id': _personal, 'nome': f},
    ],
    'cobrancas': cobrancas,
    'treino_execucoes': execucoes,
    ..._nutricao(hoje),
    ..._agendaEChat(hoje, linhasAlunos),
  };
}

/// Consultas da semana e algumas conversas, com mensagens não lidas.
Map<String, List<Map<String, dynamic>>> _agendaEChat(
    DateTime hoje, List<Map<String, dynamic>> alunos) {
  Map<String, dynamic> aluno(int i) => {
        'id': alunos[i]['id'],
        'nome': alunos[i]['nome'],
        'whatsapp': alunos[i]['whatsapp'],
      };
  String em(int dias, int h, [int m = 0]) => hoje
      .add(Duration(days: dias, hours: h, minutes: m))
      .toUtc()
      .toIso8601String();

  // (aluno, dia, hora, minuto, tipo, status, local)
  const agenda = [
    (0, 0, 8, 0, 'retorno', 'realizada', 'Academia Prado'),
    (3, 0, 17, 30, 'avaliacao', 'confirmada', 'Academia Prado'),
    (5, 0, 19, 0, 'online', 'agendada', null),
    (4, 1, 7, 30, 'nutricao', 'remarcar', 'Consultório'),
    (6, 2, 18, 0, 'treino', 'agendada', 'Academia Prado'),
  ];
  return {
    'consultas': [
      for (final (i, c) in agenda.indexed)
        {
          'id': 'c$i',
          'personal_id': _personal,
          'aluno_id': alunos[c.$1]['id'],
          'inicio': em(c.$2, c.$3, c.$4),
          'duracao_min': 60,
          'tipo': c.$5,
          'status': c.$6,
          'local': c.$7,
          'link':
              c.$5 == 'online' ? 'https://meet.google.com/abc-defg-hij' : null,
          'nota': c.$6 == 'realizada' ? 5 : null,
          'alunos': aluno(c.$1),
        },
    ],
    'mensagens': [
      {
        'id': 'mg1',
        'aluno_id': alunos[0]['id'],
        'autor_id': 'aluno-user-0',
        'texto': 'Posso trocar o arroz por batata-doce no almoço?',
        'criado_em': em(0, 11, 5)
      },
      {
        'id': 'mg2',
        'aluno_id': alunos[3]['id'],
        'autor_id': 'aluno-user-3',
        'texto': 'Hoje não consigo ir, posso treinar amanhã cedo?',
        'criado_em': em(0, 9, 40)
      },
      {
        'id': 'mg3',
        'aluno_id': alunos[3]['id'],
        'autor_id': 'aluno-user-3',
        'texto': 'Senti dor no joelho no agachamento ontem',
        'criado_em': em(0, 9, 41)
      },
      {
        'id': 'mg4',
        'aluno_id': alunos[4]['id'],
        'autor_id': _personal,
        'texto': 'Mandei o plano novo, dá uma olhada!',
        'criado_em': em(-1, 18),
        'lida_em': em(-1, 19)
      },
    ],
  };
}

/// Planos e registros da semana para o painel de adesão: uma aluna
/// exemplar, um que foge do plano, um sumido e uma no meio do caminho.
Map<String, List<Map<String, dynamic>>> _nutricao(DateTime hoje) {
  // (índice do aluno, refeições marcadas por dia, fugas na semana, último dia com registro)
  const perfis = [
    (0, 5, 0, 0),
    (3, 2, 1, 0),
    (1, 0, 0, 9),
    (4, 5, 3, 1),
    (5, 4, 0, 0)
  ];
  final planos = <Map<String, dynamic>>[];
  final refeicoes = <Map<String, dynamic>>[];
  final marcadas = <Map<String, dynamic>>[];
  final diario = <Map<String, dynamic>>[];
  final agua = <Map<String, dynamic>>[];
  final extras = <String, List<Map<String, dynamic>>>{};

  for (final (aluno, porDia, fugas, ultimo) in perfis) {
    final a = 'aluno-$aluno';
    final plano = 'plano-$aluno';
    if (aluno == 0) {
      final completo = planoDemo(
        alunoId: a,
        planoId: plano,
        idsRefeicoes: [for (var r = 0; r < 5; r++) '$plano-r$r'],
        assinado: true,
      );
      for (final e in completo.entries) {
        extras.putIfAbsent(e.key, () => []).addAll(e.value);
      }
    } else {
      planos.add({
        'id': plano,
        'aluno_id': a,
        'nome': 'Plano',
        'ativo': true,
        'agua_ml': 2500,
        'data_inicio': Datas.iso(hoje.subtract(const Duration(days: 30))),
      });
      for (var r = 0; r < 5; r++) {
        refeicoes.add({
          'id': '$plano-r$r',
          'plano_id': plano,
          'nome': 'Refeição $r',
          'ordem': r
        });
      }
    }
    if (ultimo > 6) continue; // sumido: nada na semana
    for (var d = ultimo; d < 7; d++) {
      final dia = hoje.subtract(Duration(days: d));
      for (var r = 0; r < porDia; r++) {
        marcadas.add({
          'id': '$a-m$d$r',
          'aluno_id': a,
          'refeicao_id': '$plano-r$r',
          'data': Datas.iso(dia),
          'feita': true,
          'criado_em':
              dia.add(Duration(hours: 8 + r * 3)).toUtc().toIso8601String(),
        });
      }
      agua.add({
        'id': '$a-a$d',
        'aluno_id': a,
        'data': Datas.iso(dia),
        'ml': 1500 + aluno * 150,
        'registrado_em':
            dia.add(const Duration(hours: 20)).toUtc().toIso8601String(),
      });
    }
    for (var f = 0; f < fugas; f++) {
      final dia = hoje.subtract(Duration(days: ultimo + f));
      diario.add({
        'id': '$a-d$f',
        'aluno_id': a,
        'data': Datas.iso(dia),
        'titulo': 'Lanche',
        'aderencia': 'fora',
        'registrado_em':
            dia.add(const Duration(hours: 16)).toUtc().toIso8601String(),
      });
    }
  }
  // Diário da Marina com foto de prato não existe na demo, mas o resto sim:
  // como foi cada refeição e o peso das últimas semanas.
  const comoFoi = [
    'seguiu',
    'seguiu',
    'parecido',
    'seguiu',
    'fora',
    'seguiu',
    'parecido'
  ];
  for (var d = 0; d < 7; d++) {
    final dia = hoje.subtract(Duration(days: d));
    diario.add({
      'id': 'mar-d$d',
      'aluno_id': 'aluno-0',
      'data': Datas.iso(dia),
      'refeicao_id': comoFoi[d] == 'fora' ? null : 'plano-0-r2',
      'titulo': comoFoi[d] == 'fora' ? 'Pizza com a família' : 'Almoço',
      'aderencia': comoFoi[d] == 'fora' ? null : comoFoi[d],
      'descricao': switch (comoFoi[d]) {
        'parecido' => 'Troquei o frango por carne moída magra',
        'fora' => '2 fatias de muçarela',
        _ => null,
      },
      'registrado_em': dia
          .add(const Duration(hours: 12, minutes: 40))
          .toUtc()
          .toIso8601String(),
    });
  }
  return {
    ...extras.map((k, v) => MapEntry(k, v)),
    'receitas': receitasDemo(),
    'planos_modelos': [
      {
        'id': 'mod1',
        'profissional_id': _personal,
        'nome': 'Hipertrofia 2.400 kcal',
        'objetivo': 'hipertrofia',
        'conteudo': {
          'metas': {'meta_kcal': 2400},
          'refeicoes': [{}, {}, {}, {}, {}, {}]
        },
      },
      {
        'id': 'mod2',
        'profissional_id': _personal,
        'nome': 'Emagrecimento 1.600 kcal',
        'objetivo': 'emagrecimento',
        'conteudo': {
          'metas': {'meta_kcal': 1600},
          'refeicoes': [{}, {}, {}, {}, {}]
        },
      },
    ],
    'metas_aluno': [
      {
        'id': 'm1',
        'aluno_id': 'aluno-0',
        'titulo': 'Beber 2,5 L de água por dia',
        'criado_em':
            hoje.subtract(const Duration(days: 10)).toUtc().toIso8601String()
      },
      {
        'id': 'm2',
        'aluno_id': 'aluno-0',
        'titulo': 'Uma fruta no lanche da tarde',
        'prazo': Datas.iso(hoje.add(const Duration(days: 20))),
        'criado_em':
            hoje.subtract(const Duration(days: 9)).toUtc().toIso8601String()
      },
      {
        'id': 'm3',
        'aluno_id': 'aluno-0',
        'titulo': 'Registrar todas as refeições por 3 dias',
        'concluida_em':
            hoje.subtract(const Duration(days: 2)).toUtc().toIso8601String(),
        'criado_em':
            hoje.subtract(const Duration(days: 8)).toUtc().toIso8601String()
      },
    ],
    'peso_registros': [
      for (var i = 5; i >= 0; i--)
        {
          'id': 'mp$i',
          'aluno_id': 'aluno-0',
          'data': Datas.iso(hoje.subtract(Duration(days: 7 * i))),
          'peso_kg': 66.4 - (5 - i) * 0.35
        },
    ],
    'planos_alimentares': [...planos, ...?extras['planos_alimentares']],
    'plano_refeicoes': [...refeicoes, ...?extras['plano_refeicoes']],
    'refeicoes_registro': marcadas,
    'diario_registros': diario,
    'agua_registros': agua,
  };
}

String _mmdd(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A aluna que o vídeo acompanha na tela de Nutrição.
const _marina = <String, dynamic>{
  'id': 'aluno-0',
  'personal_id': _personal,
  'nome': 'Marina Costa',
  'whatsapp': '11987654321',
  'ativo': true,
};

/// As outras abas não fazem parte da demo.
class _EmBreve extends StatelessWidget {
  const _EmBreve(this.titulo);
  final String titulo;

  @override
  Widget build(BuildContext context) => Center(
        child: Text('$titulo — fora da demo', style: AppText.caption(14)),
      );
}

/// `?tema=claro` ou `?tema=escuro` na URL fixa o tema da demo.
TemaApp _temaDaUrl() => TemaApp.values.firstWhere(
      (t) => t.name == Uri.base.queryParameters['tema'],
      orElse: () => TemaApp.sistema,
    );

final _router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (_, __, child) => PersonalShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        for (final (p, t) in const [
          ('/alunos', 'Alunos'),
          ('/fichas', 'Treinos'),
          ('/exercicios', 'Exercícios'),
          ('/relatorios', 'Relatórios'),
          ('/perfil', 'Perfil'),
        ])
          GoRoute(path: p, builder: (_, __) => _EmBreve(t)),
      ],
    ),
    GoRoute(path: '/adesao', builder: (_, __) => const AdesaoScreen()),
    GoRoute(path: '/receitas', builder: (_, __) => const ReceitasScreen()),
    GoRoute(
      path: '/alunos/dieta',
      builder: (_, s) =>
          DietaScreen(aluno: s.extra as Map<String, dynamic>? ?? _marina),
    ),
    GoRoute(
      path: '/alunos/dieta/montar',
      builder: (_, s) {
        final e = s.extra as Map<String, dynamic>? ??
            const {'planoId': 'plano-0', 'alunoNome': 'Marina Costa'};
        return PlanoMontadorScreen(
            planoId: e['planoId'] as String,
            alunoNome: e['alunoNome'] as String);
      },
    ),
    GoRoute(path: '/agenda', builder: (_, __) => const AgendaScreen()),
    GoRoute(
        path: '/mensagens', builder: (_, __) => const CaixaMensagensScreen()),
    GoRoute(
        path: '/alunos/adicionar',
        builder: (_, __) => const Scaffold(body: _EmBreve('Novo aluno'))),
    GoRoute(
      path: '/alunos/perfil',
      builder: (_, s) =>
          AlunoPerfilScreen(aluno: s.extra as Map<String, dynamic>),
    ),
  ],
);

class _Demo extends StatelessWidget {
  const _Demo();

  @override
  Widget build(BuildContext context) {
    return PhdMaterialApp(
      title: 'PHD — Home do personal (demo)',
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
