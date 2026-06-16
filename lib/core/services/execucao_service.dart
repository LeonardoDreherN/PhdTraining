import 'package:supabase_flutter/supabase_flutter.dart';

class ExecucaoService {
  static final _db = Supabase.instance.client;

  static Future<void> salvar({
    required String fichaId,
    required String fichaNome,
    required List<Map<String, dynamic>> detalhes,
    required int duracaoMinutos,
    required int totalExercicios,
  }) async {
    final user = _db.auth.currentUser!;

    final aluno = await _db
        .from('alunos')
        .select('id, nome, personal_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (aluno == null) return;

    await _db.from('treino_execucoes').insert({
      'aluno_user_id': user.id,
      'aluno_id': aluno['id'],
      'aluno_nome': aluno['nome'],
      'ficha_id': fichaId,
      'ficha_nome': fichaNome,
      'personal_id': aluno['personal_id'],
      'duracao_minutos': duracaoMinutos,
      'total_exercicios': totalExercicios,
      'detalhes': detalhes,
    });
  }

  static Future<List<Map<String, dynamic>>> listarParaPersonal() async {
    final user = _db.auth.currentUser!;
    return await _db
        .from('treino_execucoes')
        .select()
        .eq('personal_id', user.id)
        .order('executado_em', ascending: false);
  }
}
