import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dieta.dart';

/// Acesso aos dados de dieta.
///
/// Escrever plano exige CRN — mas quem garante isso é a policy do banco
/// (migração 0010), não este arquivo. Aqui só expomos [podePrescrever] para
/// a interface não oferecer um botão que vai falhar.
class DietaService {
  static final _db = Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Permissão ───────────────────────────────────────────────

  /// Lê o CRN do próprio perfil. Vazio ou nulo = não pode prescrever.
  static Future<String?> meuCrn() async {
    final p = await _db
        .from('profiles')
        .select('crn')
        .eq('id', _uid)
        .maybeSingle();
    final crn = (p?['crn'] as String?)?.trim();
    return (crn == null || crn.isEmpty) ? null : crn;
  }

  static Future<bool> podePrescrever() async => (await meuCrn()) != null;

  // ── Alimentos ───────────────────────────────────────────────

  /// Busca por nome. Vazio devolve os primeiros em ordem alfabética, para a
  /// tela nunca abrir sem nada — lista vazia parece defeito.
  static Future<List<Alimento>> buscarAlimentos({
    String termo = '',
    String? grupo,
    int limite = 60,
  }) async {
    var q = _db.from('alimentos').select();

    final t = termo.trim();
    if (t.isNotEmpty) {
      // `ilike` com % dos dois lados: o nutricionista digita "frang" e
      // espera achar "Frango, peito, grelhado".
      q = q.ilike('nome', '%$t%');
    }
    if (grupo != null && grupo != 'Todos') {
      q = q.eq('grupo', grupo);
    }

    final linhas = await q.order('nome', ascending: true).limit(limite);
    return List<Map<String, dynamic>>.from(linhas)
        .map(Alimento.doMapa)
        .toList();
  }

  static Future<List<String>> gruposDeAlimentos() async {
    final linhas = await _db
        .from('alimentos')
        .select('grupo')
        .not('grupo', 'is', null);
    final s = <String>{};
    for (final l in List<Map<String, dynamic>>.from(linhas)) {
      final g = (l['grupo'] as String?)?.trim();
      if (g != null && g.isNotEmpty) s.add(g);
    }
    final ordenados = s.toList()..sort();
    return ['Todos', ...ordenados];
  }

  /// Cria um alimento do profissional — whey de marca, marmita, receita.
  static Future<Alimento> criarAlimento(Alimento a) async {
    final linha = await _db
        .from('alimentos')
        .insert({
          ...a.paraMapa(),
          'profissional_id': _uid,
          'oficial': false,
          'fonte': 'profissional',
        })
        .select()
        .single();
    return Alimento.doMapa(linha);
  }

  static Future<void> atualizarAlimento(String id, Map<String, dynamic> dados) async {
    await _db.from('alimentos').update(dados).eq('id', id);
  }

  static Future<void> excluirAlimento(String id) async {
    await _db.from('alimentos').delete().eq('id', id);
  }

  // ── Planos ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> listarPlanos(String alunoId) async {
    final linhas = await _db
        .from('planos_alimentares')
        .select()
        .eq('aluno_id', alunoId)
        .order('data_inicio', ascending: false);
    return List<Map<String, dynamic>>.from(linhas);
  }

  /// Carrega o plano inteiro: cabeçalho, refeições e itens com os alimentos.
  ///
  /// Três consultas, não uma por refeição. Um plano tem cinco a sete
  /// refeições; buscar os itens dentro de um laço seriam sete idas ao
  /// servidor toda vez que a tela abre.
  static Future<PlanoAlimentar?> carregarPlano(String planoId) async {
    final cabecalho = await _db
        .from('planos_alimentares')
        .select()
        .eq('id', planoId)
        .maybeSingle();
    if (cabecalho == null) return null;

    final refeicoes = List<Map<String, dynamic>>.from(
      await _db
          .from('plano_refeicoes')
          .select()
          .eq('plano_id', planoId)
          .order('ordem', ascending: true),
    );
    if (refeicoes.isEmpty) return PlanoAlimentar.doMapa(cabecalho);

    final ids = refeicoes.map((r) => r['id'] as String).toList();
    final (itensBrutos, receitasBrutas) = await (
      _db
          .from('refeicao_itens')
          .select('*, alimentos(*)')
          .inFilter('refeicao_id', ids)
          .order('ordem', ascending: true),
      _receitasDasRefeicoes(ids),
    ).wait;
    final itens = List<Map<String, dynamic>>.from(itensBrutos);

    final porRefeicao = <String, List<ItemRefeicao>>{};
    for (final i in itens) {
      final rid = i['refeicao_id'] as String;
      porRefeicao.putIfAbsent(rid, () => []).add(ItemRefeicao.doMapa(i));
    }

    final receitasPorRefeicao = <String, List<ReceitaNaRefeicao>>{};
    for (final r in receitasBrutas) {
      final rr = ReceitaNaRefeicao.doMapa(r);
      receitasPorRefeicao.putIfAbsent(rr.refeicaoId, () => []).add(rr);
    }

    return PlanoAlimentar.doMapa(
      cabecalho,
      refeicoes: [
        for (final r in refeicoes)
          Refeicao.doMapa(
            r,
            itens: porRefeicao[r['id'] as String] ?? const [],
            receitas: receitasPorRefeicao[r['id'] as String] ?? const [],
          ),
      ],
    );
  }

  /// Receitas das refeições, com ingredientes e alimentos numa consulta só.
  /// Sem a tabela (migration 0015 ainda não aplicada) o plano abre sem elas.
  static Future<List<Map<String, dynamic>>> _receitasDasRefeicoes(List<String> ids) async {
    try {
      return List<Map<String, dynamic>>.from(
        await _db
            .from('refeicao_receitas')
            .select('*, receitas(*, receita_ingredientes(*, alimentos(*)))')
            .inFilter('refeicao_id', ids)
            .order('ordem', ascending: true),
      );
    } on PostgrestException {
      return const [];
    }
  }

  /// O plano que vale hoje para o aluno.
  static Future<PlanoAlimentar?> planoAtivo(String alunoId) async {
    final linha = await _db
        .from('planos_alimentares')
        .select('id')
        .eq('aluno_id', alunoId)
        .eq('ativo', true)
        .maybeSingle();
    if (linha == null) return null;
    return carregarPlano(linha['id'] as String);
  }

  /// Cria um plano. Ativar este desativa o anterior — existe índice único
  /// de um ativo por aluno, e sem desativar antes o insert falharia.
  static Future<String> criarPlano({
    required String alunoId,
    required String nome,
    String? objetivo,
    bool ativar = true,
    Map<String, dynamic> metas = const {},
  }) async {
    if (ativar) {
      await _db
          .from('planos_alimentares')
          .update({'ativo': false})
          .eq('aluno_id', alunoId)
          .eq('ativo', true);
    }

    final linha = await _db
        .from('planos_alimentares')
        .insert({
          'aluno_id': alunoId,
          'nome': nome,
          'objetivo': objetivo,
          'ativo': ativar,
          ...metas,
        })
        .select('id')
        .single();
    return linha['id'] as String;
  }

  static Future<void> atualizarPlano(String id, Map<String, dynamic> dados) async {
    await _db.from('planos_alimentares').update({
      ...dados,
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Assina o plano com o CRN de quem está logado.
  ///
  /// Sem CRN não assina: a policy recusaria de qualquer forma, mas falhar
  /// aqui dá uma mensagem que explica, em vez do erro cru do Postgres.
  static Future<void> assinarPlano(String id) async {
    final crn = await meuCrn();
    if (crn == null) {
      throw Exception(
        'Para assinar um plano alimentar é preciso ter o CRN no seu perfil. '
        'A prescrição dietética é privativa do nutricionista.',
      );
    }
    await _db.from('planos_alimentares').update({
      'autor_id': _uid,
      'crn_assinatura': crn,
      'assinado_em': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> ativarPlano(String id, String alunoId) async {
    await _db
        .from('planos_alimentares')
        .update({'ativo': false})
        .eq('aluno_id', alunoId)
        .eq('ativo', true);
    await _db.from('planos_alimentares').update({'ativo': true}).eq('id', id);
  }

  static Future<void> excluirPlano(String id) async {
    // Refeições e itens caem por `on delete cascade` do 0010.
    await _db.from('planos_alimentares').delete().eq('id', id);
  }

  // ── Refeições ───────────────────────────────────────────────

  static Future<String> adicionarRefeicao({
    required String planoId,
    required String nome,
    String? horario,
    required int ordem,
  }) async {
    final linha = await _db
        .from('plano_refeicoes')
        .insert({
          'plano_id': planoId,
          'nome': nome,
          'horario': horario,
          'ordem': ordem,
        })
        .select('id')
        .single();
    return linha['id'] as String;
  }

  static Future<void> atualizarRefeicao(String id, Map<String, dynamic> dados) async {
    await _db.from('plano_refeicoes').update(dados).eq('id', id);
  }

  static Future<void> removerRefeicao(String id) async {
    await _db.from('plano_refeicoes').delete().eq('id', id);
  }

  /// Grava a ordem das refeições numa ida só.
  static Future<void> reordenarRefeicoes(List<Refeicao> refeicoes) async {
    if (refeicoes.isEmpty) return;
    await _db.from('plano_refeicoes').upsert([
      for (var i = 0; i < refeicoes.length; i++)
        {
          'id': refeicoes[i].id,
          'plano_id': refeicoes[i].planoId,
          'nome': refeicoes[i].nome,
          'ordem': i,
        },
    ]);
  }

  // ── Itens ───────────────────────────────────────────────────

  static Future<void> adicionarItem({
    required String refeicaoId,
    required String alimentoId,
    required double quantidadeG,
    String? medidaExibicao,
    String? grupoSubstituicao,
    String? observacoes,
    required int ordem,
  }) async {
    await _db.from('refeicao_itens').insert({
      'refeicao_id': refeicaoId,
      'alimento_id': alimentoId,
      'quantidade_g': quantidadeG,
      'medida_exibicao': medidaExibicao,
      'grupo_substituicao': grupoSubstituicao,
      'observacoes': observacoes,
      'ordem': ordem,
    });
  }

  static Future<void> atualizarItem(String id, Map<String, dynamic> dados) async {
    await _db.from('refeicao_itens').update(dados).eq('id', id);
  }

  static Future<void> removerItem(String id) async {
    await _db.from('refeicao_itens').delete().eq('id', id);
  }

  /// Marca um conjunto de itens como intercambiáveis entre si.
  ///
  /// Passar uma lista com um item só desfaz o grupo: substituição de um
  /// alimento por nada não existe.
  static Future<void> agruparSubstitutos(List<String> itemIds) async {
    if (itemIds.isEmpty) return;

    if (itemIds.length == 1) {
      await _db
          .from('refeicao_itens')
          .update({'grupo_substituicao': null})
          .eq('id', itemIds.first);
      return;
    }

    // O id do primeiro item serve de identificador do grupo: já é um uuid
    // único e evita gerar um à toa.
    final grupo = itemIds.first;
    await _db
        .from('refeicao_itens')
        .update({'grupo_substituicao': grupo})
        .inFilter('id', itemIds);
  }

  // ── Registro do aluno ───────────────────────────────────────

  /// Refeições marcadas num dia. Devolve os ids das refeições feitas.
  static Future<Set<String>> refeicoesFeitas({
    required String alunoId,
    required DateTime dia,
  }) async {
    final data = _iso(dia);
    final linhas = await _db
        .from('refeicoes_registro')
        .select('refeicao_id, feita')
        .eq('aluno_id', alunoId)
        .eq('data', data);

    return {
      for (final l in List<Map<String, dynamic>>.from(linhas))
        if (l['feita'] as bool? ?? false) l['refeicao_id'] as String,
    };
  }

  static Future<void> marcarRefeicao({
    required String alunoId,
    required String refeicaoId,
    required DateTime dia,
    required bool feita,
    String? observacoes,
  }) async {
    await _db.from('refeicoes_registro').upsert({
      'aluno_id': alunoId,
      'refeicao_id': refeicaoId,
      'data': _iso(dia),
      'feita': feita,
      'observacoes': observacoes,
      // O índice único é (aluno_id, refeicao_id, data). Sem informar o
      // `onConflict` certo, o PostgREST usaria a chave primária — que nunca
      // colide — e cada toque criaria uma linha nova.
    }, onConflict: 'aluno_id,refeicao_id,data');
  }

  /// Adesão dos últimos dias: quantas refeições foram marcadas sobre o
  /// total prescrito no período.
  static Future<Map<DateTime, int>> adesaoPorDia({
    required String alunoId,
    required int dias,
  }) async {
    final ate = DateTime.now();
    final de = DateTime(ate.year, ate.month, ate.day)
        .subtract(Duration(days: dias - 1));

    final linhas = await _db
        .from('refeicoes_registro')
        .select('data, feita')
        .eq('aluno_id', alunoId)
        .gte('data', _iso(de));

    final contagem = <DateTime, int>{};
    for (final l in List<Map<String, dynamic>>.from(linhas)) {
      if (!(l['feita'] as bool? ?? false)) continue;
      final d = DateTime.tryParse(l['data'] as String? ?? '');
      if (d == null) continue;
      final chave = DateTime(d.year, d.month, d.day);
      contagem[chave] = (contagem[chave] ?? 0) + 1;
    }
    return contagem;
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
