import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dieta.dart';
import '../utils/datas.dart';
import 'diario_service.dart';
import 'dieta_service.dart';

/// Uma ficha que o aluno tinha para o dia e se ele fez.
typedef TreinoDoDia = ({String nome, bool feito, int? minutos});

/// Uma refeição do plano e o que o aluno marcou nela.
typedef RefeicaoDoDia = ({Refeicao refeicao, RegistroRefeicao? registro, double kcal});

/// O que o aluno tinha para fazer num dia e o que fez — o "seguiu tudo?"
/// que o personal confere no perfil.
class DiaDoAluno {
  const DiaDoAluno({
    required this.dia,
    this.treinos = const [],
    this.refeicoes = const [],
    this.metaKcal,
    this.aguaMl = 0,
    this.metaAguaMl = 0,
    this.peso,
  });

  final DateTime dia;

  /// Previstos (pelos dias da ficha) e também os feitos fora da previsão.
  final List<TreinoDoDia> treinos;
  final List<RefeicaoDoDia> refeicoes;
  final double? metaKcal;
  final int aguaMl;
  final int metaAguaMl;
  final double? peso;

  bool get temPlano => refeicoes.isNotEmpty;

  /// Calorias que o aluno marcou como comidas: o plano de cada refeição
  /// feita, ou o que ele disse ter comido quando ajustou a refeição.
  double get kcalConsumidas => refeicoes.fold(0, (s, r) => s + r.kcal);

  int get refeicoesFeitas => refeicoes.where((r) => r.registro?.feita ?? false).length;

  bool get bebeuAgua => metaAguaMl > 0 && aguaMl >= metaAguaMl;

  /// Cada coisa que dava para cumprir no dia: cada treino previsto, cada
  /// refeição do plano e a meta de água.
  int get total => treinos.length + refeicoes.length + (metaAguaMl > 0 ? 1 : 0);

  int get cumpridos =>
      treinos.where((t) => t.feito).length + refeicoesFeitas + (bebeuAgua ? 1 : 0);

  double get proporcao => total == 0 ? 0 : cumpridos / total;
}

class DiaAlunoService {
  static final _db = Supabase.instance.client;

  /// Monta o dia a partir das fichas e do plano que o perfil já carregou.
  ///
  /// O plano usado é o ativo hoje: o app não guarda versões antigas do
  /// plano. Para um dia antes do início dele, a dieta é comparada com um
  /// plano que o aluno ainda não seguia — a tela avisa quando é o caso.
  static Future<DiaDoAluno> carregar({
    required String alunoId,
    required DateTime dia,
    required List<Map<String, dynamic>> fichas,
    PlanoAlimentar? plano,
    double? pesoAtual,
  }) async {
    final d = Datas.dia(dia);
    final fim = d.add(const Duration(days: 1));

    final (execucoes, registros, agua, pesos) = await (
      _talvez(_db
          .from('treino_execucoes')
          .select('ficha_id, ficha_nome, duracao_minutos')
          .eq('aluno_id', alunoId)
          .gte('executado_em', d.toUtc().toIso8601String())
          .lt('executado_em', fim.toUtc().toIso8601String())),
      _talvez(DietaService.registrosDoDia(alunoId: alunoId, dia: d)),
      _talvez(DiarioService.aguaDoDia(alunoId, d)),
      _talvez(DiarioService.pesos(alunoId, limite: 120)),
    ).wait;

    // ── Treino ──
    final feitas = List<Map<String, dynamic>>.from(execucoes ?? const []);
    final usadas = <int>{};
    final treinos = <TreinoDoDia>[];
    for (final f in fichas) {
      final dias = [for (final x in (f['dias_semana'] as List?) ?? const []) (x as num).toInt()];
      // Ficha sem dia fixo não é obrigação de nenhum dia: só entra se feita.
      if (!dias.contains(d.weekday % 7)) continue;
      final ficha = (f['fichas'] as Map?) ?? const {};
      final i = feitas.indexWhere((e) => '${e['ficha_id']}' == '${ficha['id']}');
      if (i >= 0) usadas.add(i);
      treinos.add((
        nome: ficha['nome'] as String? ?? 'Treino',
        feito: i >= 0,
        minutos: i >= 0 ? (feitas[i]['duracao_minutos'] as num?)?.toInt() : null,
      ));
    }
    for (final (i, e) in feitas.indexed) {
      if (usadas.contains(i)) continue;
      treinos.add((
        nome: e['ficha_nome'] as String? ?? 'Treino',
        feito: true,
        minutos: (e['duracao_minutos'] as num?)?.toInt(),
      ));
    }

    // ── Dieta ──
    final regs = registros ?? const <String, RegistroRefeicao>{};
    final refeicoes = <RefeicaoDoDia>[
      for (final r in plano?.refeicoes ?? const <Refeicao>[])
        if (!r.vazia)
          (
            refeicao: r,
            registro: regs[r.id],
            kcal: switch (regs[r.id]) {
              final g? when g.feita && g.alterada => somarConsumo(g.itens!).kcal,
              final g? when g.feita => r.total.kcal,
              _ => 0,
            },
          ),
    ];

    // ── Água e peso ──
    final pesoDoDia = (pesos ?? const []).where((p) => Datas.dia(p.data) == d).lastOrNull?.pesoKg;

    return DiaDoAluno(
      dia: d,
      treinos: treinos,
      refeicoes: refeicoes,
      metaKcal: plano?.metaKcal,
      aguaMl: (agua ?? const []).fold(0, (s, a) => s + a.ml),
      metaAguaMl: DiarioService.metaAgua(metaDoPlano: plano?.aguaMl, pesoKg: pesoDoDia ?? pesoAtual),
      peso: pesoDoDia,
    );
  }

  static Future<T?> _talvez<T>(Future<T> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }
}
