import 'package:supabase_flutter/supabase_flutter.dart';

class FichaService {
  static final _db = Supabase.instance.client;
  static String get _personalId => _db.auth.currentUser!.id;

  // ── Fichas ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> listar() async {
    return await _db
        .from('fichas')
        .select()
        .eq('personal_id', _personalId)
        .order('nome');
  }

  static Future<Map<String, dynamic>> criar({
    required String nome,
    String? descricao,
  }) async {
    return await _db.from('fichas').insert({
      'personal_id': _personalId,
      'nome': nome,
      'descricao': descricao,
    }).select().single();
  }

  static Future<void> atualizar(String id, String nome, String? descricao) async {
    await _db.from('fichas').update({'nome': nome, 'descricao': descricao}).eq('id', id);
  }

  static Future<void> deletar(String id) async {
    // Remove atribuições e exercícios antes de deletar a ficha (FK constraints)
    await _db.from('aluno_fichas').delete().eq('ficha_id', id);
    await _db.from('ficha_exercicios').delete().eq('ficha_id', id);
    await _db.from('fichas').delete().eq('id', id);
  }

  // ── Exercícios da ficha ──────────────────────────────────

  static Future<List<Map<String, dynamic>>> listarExercicios(String fichaId) async {
    return await _db
        .from('ficha_exercicios')
        .select('*, exercicios(id, nome, grupo_muscular, midia_url)')
        .eq('ficha_id', fichaId)
        .order('ordem');
  }

  static Future<void> adicionarExercicio({
    required String fichaId,
    required String exercicioId,
    required int series,
    required String repeticoes,
    String? carga,
    int? descansoSegundos,
    required int ordem,
  }) async {
    await _db.from('ficha_exercicios').insert({
      'ficha_id': fichaId,
      'exercicio_id': exercicioId,
      'series': series,
      'repeticoes': repeticoes,
      'carga': carga,
      'descanso_segundos': descansoSegundos,
      'ordem': ordem,
    });
  }

  static Future<void> removerExercicio(String fichaExercicioId) async {
    await _db.from('ficha_exercicios').delete().eq('id', fichaExercicioId);
  }

  static Future<void> atualizarExercicio(String id, Map<String, dynamic> dados) async {
    await _db.from('ficha_exercicios').update(dados).eq('id', id);
  }

  // ── Atribuir ficha ao aluno ──────────────────────────────

  static Future<void> atribuirAluno({
    required String alunoId,
    required String fichaId,
    List<int> diasSemana = const [],
  }) async {
    await _db.from('aluno_fichas').upsert({
      'aluno_id': alunoId,
      'ficha_id': fichaId,
      'ativa': true,
      'dias_semana': diasSemana,
      'data_inicio': DateTime.now().toIso8601String().split('T').first,
    });
  }

  static Future<List<Map<String, dynamic>>> fichasDoAluno(String alunoId) async {
    return await _db
        .from('aluno_fichas')
        .select('*, fichas(id, nome, descricao)')
        .eq('aluno_id', alunoId)
        .eq('ativa', true);
  }
}
