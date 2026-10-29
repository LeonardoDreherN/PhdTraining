import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dieta.dart';
import 'dieta_service.dart';

/// Um modelo salvo, como aparece na lista.
class ModeloPlano {
  const ModeloPlano({
    required this.id,
    required this.nome,
    required this.conteudo,
    this.objetivo,
  });

  final String id;
  final String nome;
  final String? objetivo;
  final Map<String, dynamic> conteudo;

  int get qtdRefeicoes => (conteudo['refeicoes'] as List?)?.length ?? 0;
  double? get metaKcal => ((conteudo['metas'] as Map?)?['meta_kcal'] as num?)?.toDouble();
}

/// Modelos de plano: salvar um plano para reaproveitar e aplicar num aluno.
///
/// O modelo é uma fotografia do plano em jsonb (ver migration 0015). Aplicar
/// recria refeições, itens e receitas num plano novo do aluno — com as
/// regras de sempre, inclusive a do CRN.
class ModeloPlanoService {
  static final _db = Supabase.instance.client;

  /// Metas que vão para o modelo. Peso, altura e TMB ficam de fora: são do
  /// aluno de origem, e copiá-los faria o plano novo calcular com o corpo
  /// de outra pessoa.
  static const _metas = [
    'meta_kcal', 'meta_proteina', 'meta_carboidrato', 'meta_gordura', 'agua_ml',
  ];

  static Future<List<ModeloPlano>> listar() async {
    final linhas = await _db
        .from('planos_modelos')
        .select()
        .eq('profissional_id', _db.auth.currentUser!.id)
        .order('criado_em', ascending: false);
    return [
      for (final l in List<Map<String, dynamic>>.from(linhas))
        ModeloPlano(
          id: l['id'] as String,
          nome: l['nome'] as String? ?? 'Modelo',
          objetivo: l['objetivo'] as String?,
          conteudo: (l['conteudo'] as Map).cast<String, dynamic>(),
        ),
    ];
  }

  static Future<void> salvar(PlanoAlimentar p, {required String nome}) async {
    await _db.from('planos_modelos').insert({
      'nome': nome,
      'objetivo': p.objetivo,
      'conteudo': {
        'metas': {
          'meta_kcal': p.metaKcal,
          'meta_proteina': p.metaProteina,
          'meta_carboidrato': p.metaCarboidrato,
          'meta_gordura': p.metaGordura,
          'agua_ml': p.aguaMl,
        },
        'observacoes': p.observacoes,
        'refeicoes': [
          for (final r in p.refeicoes)
            {
              'nome': r.nome,
              'horario': r.horario,
              'observacoes': r.observacoes,
              'itens': [
                for (final i in r.itens)
                  {
                    'alimento_id': i.alimento.id,
                    'quantidade_g': i.quantidadeG,
                    'medida_exibicao': i.medidaExibicao,
                    'grupo_substituicao': i.grupoSubstituicao,
                    'observacoes': i.observacoes,
                  },
              ],
              'receitas': [
                for (final rr in r.receitas)
                  {'receita_id': rr.receita.id, 'porcoes': rr.porcoes},
              ],
            },
        ],
      },
    });
  }

  static Future<void> excluir(String id) async {
    await _db.from('planos_modelos').delete().eq('id', id);
  }

  /// Cria o plano do aluno a partir do modelo e devolve o id dele.
  static Future<String> aplicar(ModeloPlano m, {required String alunoId}) async {
    final c = m.conteudo;
    final metas = (c['metas'] as Map?)?.cast<String, dynamic>() ?? const {};

    final planoId = await DietaService.criarPlano(
      alunoId: alunoId,
      nome: m.nome,
      objetivo: m.objetivo,
      metas: {
        for (final k in _metas)
          if (metas[k] != null) k: metas[k],
        if (c['observacoes'] != null) 'observacoes': c['observacoes'],
      },
    );

    final refeicoes = (c['refeicoes'] as List? ?? const []).cast<Map>();
    for (final (ordem, r) in refeicoes.indexed) {
      final refeicaoId = await DietaService.adicionarRefeicao(
        planoId: planoId,
        nome: r['nome'] as String? ?? 'Refeição',
        horario: r['horario'] as String?,
        ordem: ordem,
      );

      // O grupo de substituição é o id do primeiro item do grupo no plano
      // de origem. No plano novo esse id não existe, mas o valor só precisa
      // ser igual entre os itens do mesmo grupo — e continua sendo.
      final itens = (r['itens'] as List? ?? const []).cast<Map>();
      if (itens.isNotEmpty) {
        await _db.from('refeicao_itens').insert([
          for (final (i, it) in itens.indexed)
            {
              'refeicao_id': refeicaoId,
              'alimento_id': it['alimento_id'],
              'quantidade_g': it['quantidade_g'],
              'medida_exibicao': it['medida_exibicao'],
              'grupo_substituicao': it['grupo_substituicao'],
              'observacoes': it['observacoes'],
              'ordem': i,
            },
        ]);
      }

      final receitas = (r['receitas'] as List? ?? const []).cast<Map>();
      if (receitas.isNotEmpty) {
        await _db.from('refeicao_receitas').insert([
          for (final (i, rr) in receitas.indexed)
            {
              'refeicao_id': refeicaoId,
              'receita_id': rr['receita_id'],
              'porcoes': rr['porcoes'],
              'ordem': i,
            },
        ]);
      }
    }
    return planoId;
  }
}
