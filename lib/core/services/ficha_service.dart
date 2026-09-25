import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ficha.dart';

class FichaService {
  static final _db = Supabase.instance.client;
  static String get _personalId => _db.auth.currentUser!.id;

  /// Lista as fichas já com contagem de exercícios, de alunos e os grupos
  /// musculares que elas cobrem.
  ///
  /// Três consultas, não uma por ficha: buscar os exercícios dentro do laço
  /// faria uma ida ao servidor por cartão da lista.
  static Future<List<Ficha>> listarComResumo() async {
    final resultados = await Future.wait([
      _db.from('fichas').select().eq('personal_id', _personalId).order('nome'),
      _db.from('ficha_exercicios').select('ficha_id, exercicios(grupo_muscular)'),
      _db.from('aluno_fichas').select('ficha_id').eq('ativa', true),
    ]);

    final linhas = List<Map<String, dynamic>>.from(resultados[0]);
    final exercicios = List<Map<String, dynamic>>.from(resultados[1]);
    final atribuicoes = List<Map<String, dynamic>>.from(resultados[2]);

    final contagemEx = <String, int>{};
    final gruposPorFicha = <String, Map<String, int>>{};

    for (final e in exercicios) {
      final fid = e['ficha_id'] as String?;
      if (fid == null) continue;
      contagemEx[fid] = (contagemEx[fid] ?? 0) + 1;

      final grupo = (e['exercicios'] as Map?)?['grupo_muscular'] as String?;
      if (grupo == null || grupo.trim().isEmpty) continue;
      final mapa = gruposPorFicha.putIfAbsent(fid, () => <String, int>{});
      mapa[grupo] = (mapa[grupo] ?? 0) + 1;
    }

    final contagemAlunos = <String, int>{};
    for (final a in atribuicoes) {
      final fid = a['ficha_id'] as String?;
      if (fid == null) continue;
      contagemAlunos[fid] = (contagemAlunos[fid] ?? 0) + 1;
    }

    return linhas.map((m) {
      final id = m['id'] as String;
      final grupos = (gruposPorFicha[id] ?? {}).entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Ficha.doMapa(
        m,
        qtdExercicios: contagemEx[id] ?? 0,
        qtdAlunos: contagemAlunos[id] ?? 0,
        grupos: grupos.take(3).map((e) => e.key).toList(),
      );
    }).toList();
  }

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
    // `onConflict` é obrigatório aqui. Sem ele o PostgREST usa a chave
    // primária, e como o `id` vem gerado no banco ele nunca colide — então
    // reatribuir a mesma ficha inseria uma linha nova e o aluno via o treino
    // duplicado. O índice único (aluno_id, ficha_id) do 0001 é o par certo.
    await _db.from('aluno_fichas').upsert({
      'aluno_id': alunoId,
      'ficha_id': fichaId,
      'ativa': true,
      'dias_semana': diasSemana,
      'data_inicio': DateTime.now().toIso8601String().split('T').first,
    }, onConflict: 'aluno_id,ficha_id');
  }

  static Future<List<Map<String, dynamic>>> fichasDoAluno(String alunoId) async {
    return await _db
        .from('aluno_fichas')
        .select('*, fichas(id, nome, descricao)')
        .eq('aluno_id', alunoId)
        .eq('ativa', true);
  }
}
