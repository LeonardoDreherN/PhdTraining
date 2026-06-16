import 'package:supabase_flutter/supabase_flutter.dart';

class TreinoService {
  static final _db = Supabase.instance.client;

  // diaSemana: 0=Dom, 1=Seg, ..., 6=Sáb  (DateTime.now().weekday % 7)
  static DateTime _dataParaDia(int diaSemana) {
    final now = DateTime.now();
    // Monday of current week
    final segunda = now.subtract(Duration(days: now.weekday - 1));
    // diaSemana 1=Seg→+0, 2=Ter→+1, ..., 6=Sáb→+5, 0=Dom→+6
    final offset = diaSemana == 0 ? 6 : diaSemana - 1;
    final dia = segunda.add(Duration(days: offset));
    return DateTime(dia.year, dia.month, dia.day);
  }

  static Future<Set<String>> getConcluidos(int diaSemana) async {
    final user = _db.auth.currentUser;
    if (user == null) return {};

    final dia = _dataParaDia(diaSemana);
    final inicio = dia.toUtc().toIso8601String();
    final fim = dia.add(const Duration(days: 1)).toUtc().toIso8601String();

    final rows = await _db
        .from('treino_execucoes')
        .select('ficha_id')
        .eq('aluno_user_id', user.id)
        .gte('executado_em', inicio)
        .lt('executado_em', fim);

    return (rows as List)
        .map((r) => r['ficha_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  // Mantido por compatibilidade — o dado real já vai ao Supabase via ExecucaoService
  static Future<void> marcarConcluido(String fichaId, int diaSemana) async {}
}
