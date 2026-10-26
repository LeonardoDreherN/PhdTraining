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

    var aluno = await _db
        .from('alunos')
        .select('id, nome, personal_id')
        .eq('user_id', user.id)
        .maybeSingle();

    // Nem todo aluno tem `user_id` preenchido — quem foi cadastrado antes do
    // vínculo automático só tem o e-mail. Sem este segundo caminho, o treino
    // dessas pessoas nunca era gravado.
    if (aluno == null && user.email != null) {
      aluno = await _db
          .from('alunos')
          .select('id, nome, personal_id')
          .eq('email', user.email!)
          .maybeSingle();
    }

    // Antes era `return` seco: o aluno terminava o treino, lia "concluído" e
    // nada ia para o banco. O personal não via a execução e ninguém
    // descobria, porque não havia erro em lugar nenhum.
    if (aluno == null) {
      throw Exception(
        'Sua conta ainda não está vinculada a um cadastro de aluno. '
        'Peça ao seu personal para conferir seu e-mail no sistema.',
      );
    }

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
