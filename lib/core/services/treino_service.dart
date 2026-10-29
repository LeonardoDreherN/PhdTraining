import 'package:supabase_flutter/supabase_flutter.dart';

class TreinoService {
  static final _db = Supabase.instance.client;

  /// Segunda-feira da semana corrente, à meia-noite local.
  static DateTime _segundaDaSemana() {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    return hoje.subtract(Duration(days: agora.weekday - 1));
  }

  /// Treinos já feitos nesta semana, agrupados por dia (0=Dom … 6=Sáb).
  ///
  /// Uma consulta para a semana inteira. A versão anterior chamava
  /// `getConcluidos` dentro de um `List.generate(7, …)`: sete requisições
  /// só para pintar os pontinhos da régua de dias, toda vez que o aluno
  /// abria o app — na rede da academia, que raramente é boa.
  static Future<Map<int, Set<String>>> concluidosDaSemana() async {
    final vazio = {for (var i = 0; i < 7; i++) i: <String>{}};

    final user = _db.auth.currentUser;
    if (user == null) return vazio;

    final segunda = _segundaDaSemana();
    final fim = segunda.add(const Duration(days: 7));

    final linhas = await _db
        .from('treino_execucoes')
        .select('ficha_id, executado_em')
        .eq('aluno_user_id', user.id)
        .gte('executado_em', segunda.toUtc().toIso8601String())
        .lt('executado_em', fim.toUtc().toIso8601String());

    for (final r in List<Map<String, dynamic>>.from(linhas)) {
      final fichaId = r['ficha_id']?.toString();
      if (fichaId == null || fichaId.isEmpty) continue;

      // `executado_em` chega em UTC; o dia da semana tem de ser lido no
      // fuso do aluno, senão um treino da noite cai no dia seguinte.
      final quando = DateTime.tryParse(r['executado_em'] as String? ?? '')
          ?.toLocal();
      if (quando == null) continue;

      vazio[quando.weekday % 7]!.add(fichaId);
    }

    return vazio;
  }

  /// Execuções dos últimos [dias], só data e duração: é o que a home precisa
  /// para sequência de semanas, treinos do mês e tempo da semana. Uma
  /// consulta enxuta em vez de puxar o `detalhes` de cada treino.
  static Future<List<({DateTime quando, int minutos})>> execucoesRecentes({
    int dias = 120,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) return [];
    final de = DateTime.now().subtract(Duration(days: dias));
    final linhas = await _db
        .from('treino_execucoes')
        .select('executado_em, duracao_minutos')
        .eq('aluno_user_id', user.id)
        .gte('executado_em', de.toUtc().toIso8601String())
        .order('executado_em', ascending: false);

    return [
      for (final r in List<Map<String, dynamic>>.from(linhas))
        if (DateTime.tryParse(r['executado_em'] as String? ?? '') case final d?)
          (
            quando: d.toLocal(),
            minutos: (r['duracao_minutos'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  /// Últimos treinos registrados, do mais recente para o mais antigo.
  static Future<List<Map<String, dynamic>>> historico({int limite = 8}) async {
    final user = _db.auth.currentUser;
    if (user == null) return [];
    final linhas = await _db
        .from('treino_execucoes')
        .select('ficha_nome, executado_em, duracao_minutos, total_exercicios')
        .eq('aluno_user_id', user.id)
        .order('executado_em', ascending: false)
        .limit(limite);
    return List<Map<String, dynamic>>.from(linhas);
  }
}
