import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/datas.dart';

/// O planejamento alimentar da semana.
///
/// O aluno confirma que organizou a semana — olhou o plano, viu o que
/// falta comprar, separou o que precisa preparar. É um ato de
/// organização, não de alimentação, e por isso ele marca: ninguém tem
/// como medir por ele.
class PlanejamentoService {
  static final _db = Supabase.instance.client;

  static const _tabela = 'planejamento_semana';

  /// A segunda-feira da semana de [d].
  ///
  /// Segunda porque é onde o `date_trunc('week')` do Postgres começa, e
  /// é a mesma semana que as conquistas de treino e de peso usam. Duas
  /// definições de semana no mesmo app seriam a origem de "a tela diz 5
  /// e a conquista diz 4".
  static DateTime segundaDe(DateTime d) {
    final dia = Datas.dia(d);
    return dia.subtract(Duration(days: dia.weekday - 1));
  }

  static DateTime get semanaAtual => segundaDe(DateTime.now());
  static DateTime get proximaSemana =>
      semanaAtual.add(const Duration(days: 7));

  /// As semanas já planejadas, da mais recente para a mais antiga.
  static Future<Set<DateTime>> semanas(String alunoId) async {
    final linhas = await _db
        .from(_tabela)
        .select('semana')
        .eq('aluno_id', alunoId)
        .order('semana', ascending: false)
        .limit(60);

    return {
      for (final l in List<Map<String, dynamic>>.from(linhas))
        if (Datas.ler(l['semana']) case final d?) Datas.dia(d),
    };
  }

  static Future<void> planejar(
    String alunoId,
    DateTime semana, {
    String? observacoes,
  }) async {
    await _db.from(_tabela).insert({
      'aluno_id': alunoId,
      'semana': Datas.iso(segundaDe(semana)),
      'observacoes': (observacoes?.trim().isEmpty ?? true)
          ? null
          : observacoes!.trim(),
    });
  }

  /// Desmarca o que foi marcado por engano. O banco só permite enquanto
  /// a semana não passou.
  static Future<void> desmarcar(String alunoId, DateTime semana) async {
    await _db
        .from(_tabela)
        .delete()
        .eq('aluno_id', alunoId)
        .eq('semana', Datas.iso(segundaDe(semana)));
  }
}
