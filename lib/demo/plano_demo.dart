import '../core/utils/datas.dart';

/// Os alimentos das demos, por 100 g (como a TACO publica).
const alimentosDemo = {
  'ovo': {'nome': 'Ovo cozido', 'grupo': 'Ovos', 'kcal': 146, 'proteina': 13.3, 'carboidrato': 0.6, 'gordura': 9.5, 'medida_caseira': 'unidade', 'medida_gramas': 50},
  'pao': {'nome': 'Pão integral', 'grupo': 'Cereais', 'kcal': 253, 'proteina': 9.4, 'carboidrato': 49.9, 'gordura': 3.7, 'medida_caseira': 'fatia', 'medida_gramas': 25},
  'arroz': {'nome': 'Arroz integral cozido', 'grupo': 'Cereais', 'kcal': 124, 'proteina': 2.6, 'carboidrato': 25.8, 'gordura': 1},
  'frango': {'nome': 'Peito de frango grelhado', 'grupo': 'Carnes', 'kcal': 159, 'proteina': 32, 'carboidrato': 0, 'gordura': 2.5},
  'feijao': {'nome': 'Feijão carioca cozido', 'grupo': 'Leguminosas', 'kcal': 76, 'proteina': 4.8, 'carboidrato': 13.6, 'gordura': 0.5},
  'iogurte': {'nome': 'Iogurte natural', 'grupo': 'Laticínios', 'kcal': 51, 'proteina': 4.1, 'carboidrato': 1.9, 'gordura': 3, 'medida_caseira': 'pote', 'medida_gramas': 170},
  'banana': {'nome': 'Banana prata', 'grupo': 'Frutas', 'kcal': 98, 'proteina': 1.3, 'carboidrato': 26, 'gordura': 0.1, 'medida_caseira': 'unidade média', 'medida_gramas': 80},
  'tilapia': {'nome': 'Tilápia grelhada', 'grupo': 'Peixes', 'kcal': 128, 'proteina': 26, 'carboidrato': 0, 'gordura': 2.7},
  'batata': {'nome': 'Batata-doce cozida', 'grupo': 'Tubérculos', 'kcal': 77, 'proteina': 0.6, 'carboidrato': 18.4, 'gordura': 0.1},
  'whey': {'nome': 'Whey protein', 'grupo': 'Suplementos', 'kcal': 400, 'proteina': 80, 'carboidrato': 8, 'gordura': 6},
  'aveia': {'nome': 'Aveia em flocos', 'grupo': 'Cereais', 'kcal': 394, 'proteina': 13.9, 'carboidrato': 66.6, 'gordura': 8.5},
  'brocolis': {'nome': 'Brócolis cozido', 'grupo': 'Hortaliças', 'kcal': 25, 'proteina': 2.1, 'carboidrato': 4.4, 'gordura': 0.5},
};

Map<String, dynamic> _alimento(String id) => {'id': id, 'oficial': true, ...alimentosDemo[id]!};

/// As receitas da biblioteca do profissional, com ingredientes embutidos
/// (o banco falso não faz o join do PostgREST).
List<Map<String, dynamic>> receitasDemo({String profissionalId = 'demo-personal'}) {
  Map<String, dynamic> receita(String id, String nome, double rende, int min, String preparo,
          List<(String, int)> ingredientes) =>
      {
        'id': id,
        'profissional_id': profissionalId,
        'nome': nome,
        'rendimento_porcoes': rende,
        'tempo_minutos': min,
        'modo_preparo': preparo,
        'receita_ingredientes': [
          for (final (i, it) in ingredientes.indexed)
            {
              'id': '$id-i$i',
              'receita_id': id,
              'alimento_id': it.$1,
              'quantidade_g': it.$2,
              'ordem': i,
              'alimentos': _alimento(it.$1),
            },
        ],
      };

  return [
    receita('rc1', 'Panqueca de banana', 2, 15,
        'Amasse as bananas, misture os ovos e a aveia. Doure dos dois lados em frigideira antiaderente.',
        [('banana', 160), ('ovo', 100), ('aveia', 40)]),
    receita('rc2', 'Frango com legumes na marmita', 4, 40,
        'Grelhe o frango em cubos, cozinhe o brócolis no vapor e monte 4 marmitas com arroz.',
        [('frango', 520), ('brocolis', 400), ('arroz', 480)]),
    receita('rc3', 'Overnight oats proteico', 1, 5,
        'Misture aveia, iogurte e whey num pote. Geladeira de um dia para o outro.',
        [('aveia', 40), ('iogurte', 170), ('whey', 15)]),
  ];
}

/// Um plano completo — refeições, alimentos, uma troca no almoço e uma
/// receita no pré-treino — para o aluno [alunoId].
///
/// [idsRefeicoes] são cinco ids: as demos usam ids fixos para os
/// registros de "refeição feita" apontarem para elas.
Map<String, List<Map<String, dynamic>>> planoDemo({
  required String alunoId,
  required String planoId,
  required List<String> idsRefeicoes,
  bool assinado = false,
}) {
  final hoje = Datas.dia(DateTime.now());
  // (nome, horário, itens: (alimento, gramas, grupo de troca))
  const refeicoes = [
    ('Café da manhã', '07:00', [('ovo', 100, null), ('pao', 50, null), ('banana', 80, null)]),
    ('Lanche da manhã', '10:00', [('iogurte', 170, null), ('whey', 30, null)]),
    ('Almoço', '12:30', [('arroz', 120, 'troca-almoco'), ('batata', 150, 'troca-almoco'), ('feijao', 100, null), ('frango', 130, null)]),
    ('Pré-treino', '16:30', [('banana', 100, null)]),
    ('Jantar', '20:00', [('tilapia', 150, null), ('brocolis', 100, null), ('batata', 120, null)]),
  ];

  return {
    'planos_alimentares': [
      {
        'id': planoId,
        'aluno_id': alunoId,
        'nome': 'Recomposição corporal',
        'objetivo': 'emagrecimento',
        'ativo': true,
        'data_inicio': Datas.iso(hoje.subtract(const Duration(days: 30))),
        'meta_kcal': 1850,
        'meta_proteina': 140,
        'meta_carboidrato': 190,
        'meta_gordura': 55,
        'agua_ml': 2500,
        'observacoes': 'Beba água ao longo do dia. Tempere com ervas e limão; '
            'evite molhos prontos.',
        if (assinado) ...{
          'crn_assinatura': '12345/P',
          'assinado_em': hoje.subtract(const Duration(days: 29)).toUtc().toIso8601String(),
          'autor_id': 'demo-personal',
        },
      },
    ],
    'plano_refeicoes': [
      for (final (i, r) in refeicoes.indexed)
        {'id': idsRefeicoes[i], 'plano_id': planoId, 'nome': r.$1, 'horario': '${r.$2}:00', 'ordem': i},
    ],
    'refeicao_itens': [
      for (final (i, r) in refeicoes.indexed)
        for (final (j, it) in r.$3.indexed)
          {
            'id': '${idsRefeicoes[i]}-$j',
            'refeicao_id': idsRefeicoes[i],
            'alimento_id': it.$1,
            'quantidade_g': it.$2,
            'grupo_substituicao': it.$3,
            'ordem': j,
            'alimentos': _alimento(it.$1),
          },
    ],
    'refeicao_receitas': [
      {
        'id': '$planoId-rr1',
        'refeicao_id': idsRefeicoes[3],
        'receita_id': 'rc1',
        'porcoes': 1,
        'ordem': 0,
        'receitas': receitasDemo().first,
      },
    ],
  };
}
