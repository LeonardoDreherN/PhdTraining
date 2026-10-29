import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dieta.dart';

/// Biblioteca de receitas do profissional, e receitas dentro do plano.
class ReceitaService {
  static final _db = Supabase.instance.client;

  static const _completa = '*, receita_ingredientes(*, alimentos(*))';

  /// As receitas de quem está logado — para o profissional, as dele.
  static Future<List<Receita>> listar() async {
    final linhas = await _db
        .from('receitas')
        .select(_completa)
        .eq('profissional_id', _db.auth.currentUser!.id)
        .order('nome', ascending: true);
    return List<Map<String, dynamic>>.from(linhas).map(Receita.doMapa).toList();
  }

  static Future<Receita?> carregar(String id) async {
    final linha = await _db.from('receitas').select(_completa).eq('id', id).maybeSingle();
    return linha == null ? null : Receita.doMapa(linha);
  }

  /// Cria ou atualiza a receita e grava os ingredientes.
  ///
  /// Os ingredientes são trocados em bloco (apaga e insere) em vez de
  /// comparar um a um: a lista é curta, e o diff seria o lugar onde um
  /// ingrediente fantasma sobreviveria a uma edição.
  static Future<String> salvar({
    String? id,
    required String nome,
    required double rendimentoPorcoes,
    int? tempoMinutos,
    String? modoPreparo,
    required List<IngredienteReceita> ingredientes,
  }) async {
    final dados = {
      'nome': nome,
      'rendimento_porcoes': rendimentoPorcoes,
      'tempo_minutos': tempoMinutos,
      'modo_preparo': (modoPreparo?.trim().isEmpty ?? true) ? null : modoPreparo!.trim(),
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };

    final String receitaId;
    if (id == null) {
      final linha = await _db.from('receitas').insert(dados).select('id').single();
      receitaId = linha['id'] as String;
    } else {
      await _db.from('receitas').update(dados).eq('id', id);
      await _db.from('receita_ingredientes').delete().eq('receita_id', id);
      receitaId = id;
    }

    if (ingredientes.isNotEmpty) {
      await _db.from('receita_ingredientes').insert([
        for (final (i, ing) in ingredientes.indexed)
          {
            'receita_id': receitaId,
            'alimento_id': ing.alimento.id,
            'quantidade_g': ing.quantidadeG,
            'medida_exibicao': ing.medidaExibicao,
            'ordem': i,
          },
      ]);
    }
    return receitaId;
  }

  /// Falha (e a tela explica) se a receita está em algum plano: o banco
  /// recusa por `on delete restrict`, que é o que protege o plano do aluno.
  static Future<void> excluir(String id) async {
    await _db.from('receitas').delete().eq('id', id);
  }

  // ── No plano ────────────────────────────────────────────────

  static Future<void> adicionarNaRefeicao({
    required String refeicaoId,
    required String receitaId,
    required double porcoes,
    required int ordem,
  }) async {
    await _db.from('refeicao_receitas').insert({
      'refeicao_id': refeicaoId,
      'receita_id': receitaId,
      'porcoes': porcoes,
      'ordem': ordem,
    });
  }

  static Future<void> alterarPorcoes(String id, double porcoes) async {
    await _db.from('refeicao_receitas').update({'porcoes': porcoes}).eq('id', id);
  }

  static Future<void> removerDaRefeicao(String id) async {
    await _db.from('refeicao_receitas').delete().eq('id', id);
  }
}
