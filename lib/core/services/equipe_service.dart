import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/equipe.dart';

/// Vínculos entre profissionais.
///
/// Quem decide o que o convidado enxerga é o banco, pela função
/// `aluno_da_minha_equipe` do 0025 — o alcance sai do plano que o aluno
/// contratou. Este serviço só monta e desmonta o vínculo.
class EquipeService {
  static final _db = Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;
  static String get _email =>
      (_db.auth.currentUser?.email ?? '').trim().toLowerCase();

  static const _campos =
      '*, dono:profiles!equipe_dono_id_fkey(nome), '
      'convidado:profiles!equipe_convidado_id_fkey(nome), '
      'equipe_alunos(aluno_id)';

  /// Quem eu convidei.
  static Future<List<VinculoEquipe>> minhaEquipe() async {
    final linhas = await _db
        .from('equipe')
        .select(_campos)
        .eq('dono_id', _uid)
        .neq('status', 'removido')
        .order('criado_em', ascending: false);
    return List<Map<String, dynamic>>.from(linhas)
        .map(VinculoEquipe.doMapa)
        .toList();
  }

  /// Carteiras de que eu participo como convidado, e os convites que
  /// ainda não respondi.
  ///
  /// O convite pendente é achado pelo e-mail, não pelo id: quando ele foi
  /// criado, quem convidou não sabia se eu tinha conta.
  static Future<List<VinculoEquipe>> ondeSouConvidado() async {
    if (_email.isEmpty) return const [];
    final linhas = await _db
        .from('equipe')
        .select(_campos)
        .or('convidado_id.eq.$_uid,convite_email.eq.$_email')
        .neq('status', 'removido')
        .order('criado_em', ascending: false);
    return List<Map<String, dynamic>>.from(linhas)
        .map(VinculoEquipe.doMapa)
        .where((v) => v.donoId != _uid)
        .toList();
  }

  /// Convida por e-mail. Se a pessoa ainda não tem conta, o convite
  /// espera: ele se liga ao login quando ela entrar com esse e-mail.
  static Future<void> convidar({
    required String email,
    required String escopo,
  }) async {
    final limpo = email.trim().toLowerCase();
    if (limpo.isEmpty || !limpo.contains('@')) {
      throw Exception('Informe um e-mail válido.');
    }
    if (limpo == _email) {
      throw Exception('Esse é o seu próprio e-mail.');
    }
    try {
      await _db.from('equipe').insert({
        'dono_id': _uid,
        'convite_email': limpo,
        'escopo': escopo,
      });
    } on PostgrestException catch (e) {
      // 23505 = o índice único de (dono, e-mail, escopo) entre os vivos.
      if (e.code == '23505') {
        throw Exception('Você já convidou essa pessoa para $escopo.');
      }
      rethrow;
    }
  }

  /// Aceita ou recusa. Vai por função porque é aqui que `convidado_id`
  /// deixa de ser nulo, e esse valor não pode vir do app.
  static Future<void> responder(String conviteId, {required bool aceitar}) =>
      _db.rpc('aceitar_convite_equipe', params: {
        'p_convite_id': conviteId,
        'p_aceitar': aceitar,
      });

  /// Tira o acesso. Marca como removido em vez de apagar: saber que
  /// alguém teve acesso aos dados de um aluno, e até quando, é o tipo de
  /// coisa que se precisa responder depois.
  static Future<void> remover(String vinculoId) async {
    await _db.from('equipe').update({
      'status': 'removido',
      'removido_em': DateTime.now().toIso8601String(),
    }).eq('id', vinculoId);
  }

  // ── Liberação manual ────────────────────────────────────────

  /// Alunos liberados na mão num vínculo.
  static Future<Set<String>> alunosLiberados(String vinculoId) async {
    final linhas = await _db
        .from('equipe_alunos')
        .select('aluno_id')
        .eq('equipe_id', vinculoId);
    return {
      for (final l in List<Map<String, dynamic>>.from(linhas))
        l['aluno_id'] as String,
    };
  }

  static Future<void> liberarAluno(String vinculoId, String alunoId) async {
    await _db.from('equipe_alunos').insert({
      'equipe_id': vinculoId,
      'aluno_id': alunoId,
    });
  }

  static Future<void> tirarAluno(String vinculoId, String alunoId) async {
    await _db
        .from('equipe_alunos')
        .delete()
        .eq('equipe_id', vinculoId)
        .eq('aluno_id', alunoId);
  }

  /// Quem acompanha o aluno, para ele mesmo ver.
  ///
  /// Vai por função porque a policy de `equipe` libera a leitura só para
  /// os dois lados do vínculo, e o aluno não é nenhum dos dois. São os
  /// dados de saúde dele: tem o direito de saber quem olha, sem por isso
  /// ganhar acesso à tabela inteira.
  ///
  /// A função também filtra pelo alcance — ele vê quem alcança ELE, não
  /// a equipe inteira do profissional.
  static Future<List<({String nome, String papel})>> quemAcompanha(
    String alunoId,
  ) async {
    final linhas = await _db.rpc(
      'quem_me_acompanha',
      params: {'p_aluno_id': alunoId},
    );
    return [
      for (final l in List<Map<String, dynamic>>.from(linhas as List))
        (
          nome: l['nome'] as String? ?? '',
          papel: l['papel'] as String? ?? '',
        ),
    ];
  }
}
