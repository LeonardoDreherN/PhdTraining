import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/datas.dart';
import '../modules/personal/alunos/aluno_perfil_screen.dart';
import '../modules/personal/home/home_screen.dart';
import '../modules/personal/shell/personal_shell.dart';
import 'banco_falso.dart';

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

  runApp(const ProviderScope(child: _Demo()));
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
    ('Lidiane Caroline Lohn', '47999887766', '1988-${_mmdd(hoje.add(const Duration(days: 2)))}', 120, <int>[]),
    ('Bruno Almeida', '11955554444', '1995-08-21', 90, [0, 2, 4, 6]),
    ('Camila Ribeiro', '21988887777', '1997-12-03', 60, [1, 2, 4]),
    ('Thiago Nunes', '31977776666', '1985-02-17', 45, [0, 3]),
    ('Júlia Martins', '41966665555', '1999-07-09', 20, [2, 5]),
    ('Pedro Henrique', '11944443333', '2000-10-30', 6, [1]),
  ];
  const fichas = ['Treino A — Superiores', 'Treino B — Inferiores', 'Treino C — Glúteos e core'];

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
      'criado_em': hoje.subtract(Duration(days: a.$4)).toUtc().toIso8601String(),
    });

    for (final (j, d) in a.$5.indexed) {
      final quando = hoje.subtract(Duration(days: d)).add(Duration(hours: d == 0 ? 7 + i % 3 : 18));
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
        'vencimento': Datas.iso(m == 0 && pendente ? hoje.add(const Duration(days: 5)) : venc),
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
      },
    ],
    'alunos': linhasAlunos,
    'fichas': [
      for (final (i, f) in fichas.indexed) {'id': 'ficha-$i', 'personal_id': _personal, 'nome': f},
    ],
    'cobrancas': cobrancas,
    'treino_execucoes': execucoes,
  };
}

String _mmdd(DateTime d) => '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// As outras abas não fazem parte da demo.
class _EmBreve extends StatelessWidget {
  const _EmBreve(this.titulo);
  final String titulo;

  @override
  Widget build(BuildContext context) => Center(
        child: Text('$titulo — fora da demo', style: AppText.caption(14)),
      );
}

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
    GoRoute(path: '/alunos/adicionar', builder: (_, __) => const Scaffold(body: _EmBreve('Novo aluno'))),
    GoRoute(
      path: '/alunos/perfil',
      builder: (_, s) => AlunoPerfilScreen(aluno: s.extra as Map<String, dynamic>),
    ),
  ],
);

class _Demo extends StatelessWidget {
  const _Demo();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PHD — Home do personal (demo)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
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
