import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recursos_aluno.dart';
import '../utils/datas.dart';

/// Metas do aluno e o que o app mostra a ele.
class MetasService {
  static final _db = Supabase.instance.client;

  /// Abertas primeiro; dentro de cada grupo, as mais novas em cima.
  static Future<List<MetaAluno>> listar(String alunoId) async {
    final linhas = await _db
        .from('metas_aluno')
        .select()
        .eq('aluno_id', alunoId)
        .order('criado_em', ascending: false);
    final metas = List<Map<String, dynamic>>.from(linhas).map(MetaAluno.doMapa).toList();
    metas.sort((a, b) => (a.concluida ? 1 : 0).compareTo(b.concluida ? 1 : 0));
    return metas;
  }

  static Future<void> salvar({
    String? id,
    required String alunoId,
    required String titulo,
    String? descricao,
    DateTime? prazo,
  }) async {
    final dados = {
      'aluno_id': alunoId,
      'titulo': titulo,
      'descricao': (descricao?.trim().isEmpty ?? true) ? null : descricao!.trim(),
      'prazo': prazo == null ? null : Datas.iso(prazo),
    };
    if (id == null) {
      await _db.from('metas_aluno').insert(dados);
    } else {
      await _db.from('metas_aluno').update(dados).eq('id', id);
    }
  }

  static Future<void> excluir(String id) async {
    await _db.from('metas_aluno').delete().eq('id', id);
  }

  /// Pela função do banco, não por UPDATE: o aluno só pode mexer nesta
  /// coluna (ver migration 0016).
  static Future<void> concluir(String id, bool concluida) async {
    await _db.rpc('concluir_meta', params: {'p_meta_id': id, 'p_concluida': concluida});
  }

  // ── Recursos ────────────────────────────────────────────────

  static Future<RecursosAluno> recursos(String alunoId) async {
    try {
      final linha = await _db.from('alunos').select('recursos').eq('id', alunoId).maybeSingle();
      return RecursosAluno.doMapa(linha?['recursos']);
    } on PostgrestException {
      // Coluna ainda não criada (0016 não aplicada): mostra tudo.
      return RecursosAluno.todos;
    }
  }

  /// Só o profissional grava: a policy de `alunos` é dele.
  static Future<void> salvarRecursos(String alunoId, RecursosAluno r) async {
    final linhas = await _db
        .from('alunos')
        .update({'recursos': r.paraMapa()})
        .eq('id', alunoId)
        .select('id');
    // UPDATE barrado por RLS não dá erro, só não muda nada. Sem esta
    // conferência a tela diria "salvo" e o aluno continuaria vendo tudo.
    if (List.from(linhas).isEmpty) {
      throw Exception('Não consegui salvar as permissões deste aluno.');
    }
  }
}
