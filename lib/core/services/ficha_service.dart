import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ficha.dart';
import '../models/ficha_exercicio.dart';

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
      _db.from('fichas').select().eq('personal_id', _personalId).order('nome', ascending: true),
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
        .order('nome', ascending: true);
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

  static Future<List<FichaExercicio>> listarExercicios(String fichaId) async {
    final linhas = await _db
        .from('ficha_exercicios')
        .select('*, exercicios(id, nome, grupo_muscular, midia_url, video_url, thumb_url, instrucoes, equipamento)')
        .eq('ficha_id', fichaId)
        // `ascending: true` é obrigatório: no postgrest-dart o `order` é
        // DECRESCENTE por padrão, e sem ele o aluno fazia o treino de trás
        // para frente.
        .order('ordem', ascending: true);
    return List<Map<String, dynamic>>.from(linhas)
        .map(FichaExercicio.doMapa)
        .toList();
  }

  /// Mesma consulta, no formato `Map` cru.
  ///
  /// Existe só para `executar_treino_screen` e `treino_simples_screen`, que
  /// ainda leem `item['series']` em dezenas de pontos. Some quando essas duas
  /// telas do aluno forem reescritas sobre `FichaExercicio`.
  static Future<List<Map<String, dynamic>>> listarExerciciosBruto(
      String fichaId) async {
    final linhas = await _db
        .from('ficha_exercicios')
        .select('*, exercicios(id, nome, grupo_muscular, midia_url, video_url, thumb_url, instrucoes, equipamento)')
        .eq('ficha_id', fichaId)
        .order('ordem', ascending: true);
    return List<Map<String, dynamic>>.from(linhas);
  }

  static Future<void> adicionarExercicio({
    required String fichaId,
    required String exercicioId,
    required int series,
    required String repeticoes,
    String? carga,
    int? descansoSegundos,
    String? observacoes,
    required int ordem,
  }) async {
    await _db.from('ficha_exercicios').insert({
      'ficha_id': fichaId,
      'exercicio_id': exercicioId,
      'series': series,
      'repeticoes': repeticoes,
      'carga': carga,
      'descanso_segundos': descansoSegundos,
      'observacoes': observacoes,
      'ordem': ordem,
    });
  }

  static Future<void> removerExercicio(String fichaExercicioId) async {
    await _db.from('ficha_exercicios').delete().eq('id', fichaExercicioId);
  }

  static Future<void> atualizarExercicio(String id, Map<String, dynamic> dados) async {
    await _db.from('ficha_exercicios').update(dados).eq('id', id);
  }

  /// Grava a ordem da lista inteira numa ida só.
  ///
  /// Antes era um `update` por exercício, em sequência: arrastar um item numa
  /// ficha de dez disparava dez requisições, e se uma falhasse no meio a ficha
  /// ficava com a ordem pela metade — sem nada na tela dizendo isso.
  ///
  /// O `upsert` só escreve as colunas enviadas; `repeticoes`, `carga` e o
  /// resto ficam intactos. `ficha_id`, `exercicio_id` e `series` vão junto
  /// porque são NOT NULL e o upsert precisa deles no caminho de inserção.
  static Future<void> reordenar(List<FichaExercicio> itens) async {
    if (itens.isEmpty) return;
    await _db.from('ficha_exercicios').upsert([
      for (var i = 0; i < itens.length; i++)
        {
          'id': itens[i].id,
          'ficha_id': itens[i].fichaId,
          'exercicio_id': itens[i].exercicioId,
          'series': itens[i].series,
          'ordem': i,
        },
    ]);
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

  /// Fichas ativas do aluno, já com quantos exercícios cada uma tem.
  ///
  /// A contagem vem numa segunda consulta, não num laço: o aluno costuma ter
  /// três a cinco fichas, e uma requisição por cartão na rede da academia é
  /// a diferença entre a tela abrir e a tela parecer travada.
  static Future<List<Map<String, dynamic>>> fichasDoAluno(String alunoId) async {
    final linhas = List<Map<String, dynamic>>.from(
      await _db
          .from('aluno_fichas')
          .select('*, fichas(id, nome, descricao)')
          .eq('aluno_id', alunoId)
          .eq('ativa', true),
    );
    if (linhas.isEmpty) return linhas;

    final ids = linhas
        .map((l) => (l['fichas'] as Map?)?['id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return linhas;

    // Séries, descanso e grupo muscular vêm junto: o cartão do treino do
    // aluno mostra os grupos e uma estimativa de duração, e é a mesma
    // consulta que já contava os exercícios.
    final exercicios = List<Map<String, dynamic>>.from(
      await _db
          .from('ficha_exercicios')
          .select('ficha_id, series, descanso_segundos, exercicios(grupo_muscular)')
          .inFilter('ficha_id', ids),
    );

    final contagem = <String, int>{};
    final series = <String, int>{};
    final segundos = <String, int>{};
    final grupos = <String, Map<String, int>>{};
    for (final e in exercicios) {
      final fid = e['ficha_id'] as String?;
      if (fid == null) continue;
      final s = (e['series'] as num?)?.toInt() ?? 3;
      contagem[fid] = (contagem[fid] ?? 0) + 1;
      series[fid] = (series[fid] ?? 0) + s;
      // ~40s de execução por série, mais o descanso prescrito (90s quando
      // o personal não definiu).
      final descanso = (e['descanso_segundos'] as num?)?.toInt() ?? 90;
      segundos[fid] = (segundos[fid] ?? 0) + s * (40 + descanso);
      final g = ((e['exercicios'] as Map?)?['grupo_muscular'] as String?)?.trim();
      if (g != null && g.isNotEmpty) {
        final porGrupo = grupos.putIfAbsent(fid, () => {});
        porGrupo[g] = (porGrupo[g] ?? 0) + 1;
      }
    }

    for (final l in linhas) {
      final fid = (l['fichas'] as Map?)?['id'] as String?;
      l['qtd_exercicios'] = fid == null ? 0 : (contagem[fid] ?? 0);
      l['qtd_series'] = fid == null ? 0 : (series[fid] ?? 0);
      // Arredonda para 5 min: "~55 min" é promessa, "~53 min" é falsa precisão.
      final min = (segundos[fid] ?? 0) / 60;
      l['minutos_estimados'] = min == 0 ? 0 : ((min / 5).round() * 5).clamp(5, 999);
      final g = grupos[fid]?.entries.toList() ?? [];
      g.sort((a, b) => b.value.compareTo(a.value));
      l['grupos'] = [for (final e in g) e.key];
    }
    return linhas;
  }
}
