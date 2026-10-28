import '../core/utils/datas.dart';

/// A aluna da demonstração e três avaliações dela, a última hoje.
///
/// Os números contam uma história plausível de seis meses de treino:
/// gordura caindo de 29% para 23%, cintura fechando, VO₂ subindo. Os
/// percentuais de gordura são os que o Pollock de 3 dobras (mulheres) dá
/// para as dobras abaixo — não foram inventados à parte.
const alunaDemo = <String, dynamic>{
  'id': 'demo-aluna',
  'personal_id': 'demo-personal',
  'nome': 'Marina Costa',
  'email': 'marina@exemplo.com',
  'genero': 'Feminino',
  'data_nascimento': '1993-05-14',
  'ativo': true,
};

Map<String, List<Map<String, dynamic>>> dadosDemo() {
  final hoje = Datas.dia(DateTime.now());
  final d3 = Datas.iso(hoje);
  final d2 = Datas.iso(hoje.subtract(const Duration(days: 96)));
  final d1 = Datas.iso(hoje.subtract(const Duration(days: 188)));
  const a = 'demo-aluna';
  var n = 0;
  String id() => 'demo-${n++}';
  // Os testes de cada dia foram criados em ordem; criado_em só precisa
  // respeitar isso para as listas ordenarem igual ao banco.
  String criado(String dia) => '${dia}T10:00:00Z';

  Map<String, dynamic> dobras(String dia, double peso, double cintura, double quadril,
          double tri, double supra, double coxa, double perc, int idade) =>
      {
        'id': id(),
        'aluno_id': a,
        'protocolo': 'pollock3f',
        'genero': 'Feminino',
        'data_avaliacao': dia,
        'peso': peso,
        'estatura': 165,
        'idade': idade,
        'cintura': cintura,
        'quadril': quadril,
        'abdomen': cintura + 4,
        'braco_dir': 28.5,
        'coxa_dir': 56,
        'tricipital': tri,
        'supraoiliaca': supra,
        'coxa': coxa,
        'soma_dobras': tri + supra + coxa,
        'perc_gordura': perc,
        'massa_gorda': double.parse((peso * perc / 100).toStringAsFixed(2)),
        'massa_magra': double.parse((peso - peso * perc / 100).toStringAsFixed(2)),
        'perc_proposta': 22,
        'objetivo': 'Emagrecimento com ganho de força',
        'criado_em': criado(dia),
      };

  return {
    'alunos': [alunaDemo],
    'avaliacoes': [
      {
        'id': id(), 'aluno_id': a, 'data_avaliacao': d1,
        'pa_sistolica': 126, 'pa_diastolica': 84, 'fc_repouso': 76,
        'proxima_avaliacao': d2, 'criado_em': criado(d1),
      },
      {
        'id': id(), 'aluno_id': a, 'data_avaliacao': d2,
        'pa_sistolica': 122, 'pa_diastolica': 80, 'fc_repouso': 70,
        'proxima_avaliacao': d3, 'criado_em': criado(d2),
      },
      {
        'id': id(), 'aluno_id': a, 'data_avaliacao': d3,
        'pa_sistolica': 118, 'pa_diastolica': 76, 'fc_repouso': 64,
        'observacoes': 'Ótima evolução: -6 pontos de gordura em seis meses sem perder massa magra. '
            'Próximo ciclo: manter 3 treinos de força, subir o cardio para 3x 35 min na Z2 '
            'e incluir mobilidade de quadril para a anteversão pélvica.',
        'proxima_avaliacao': Datas.iso(hoje.add(const Duration(days: 91))),
        'criado_em': criado(d3),
      },
    ],
    'avaliacao_morfologica_dobras': [
      dobras(d1, 68.4, 78, 102, 24, 22, 30, 29.3, 32),
      dobras(d2, 66.1, 75, 100, 21, 18, 27, 26.2, 33),
      dobras(d3, 64.3, 72, 98.5, 18, 15, 24, 23.3, 33),
    ],
    'avaliacao_cardio': [
      {
        'id': id(), 'aluno_id': a, 'data_avaliacao': d2, 'protocolo': 'rockport',
        'genero': 'Feminino', 'idade': 33, 'peso': 66.1, 'tempo_seg': 940, 'fc_final': 152,
        'vo2max': 33.9, 'classificacao': 'Regular', 'criado_em': criado(d2),
      },
      {
        'id': id(), 'aluno_id': a, 'data_avaliacao': d3, 'protocolo': 'rockport',
        'genero': 'Feminino', 'idade': 33, 'peso': 64.3, 'tempo_seg': 890, 'fc_final': 146,
        'vo2max': 37.9, 'classificacao': 'Boa', 'criado_em': criado(d3),
      },
    ],
    'avaliacao_neuromotores_flexibilidade': [
      {'id': id(), 'aluno_id': a, 'data_avaliacao': d2, 'genero': 'Feminino', 'idade': 33,
       'alcance': 28, 'analise': 'Média', 'criado_em': criado(d2)},
      {'id': id(), 'aluno_id': a, 'data_avaliacao': d3, 'genero': 'Feminino', 'idade': 33,
       'alcance': 32.5, 'analise': 'Acima da média', 'criado_em': criado(d3)},
    ],
    'avaliacao_neuromotores_resistencia': [
      {'id': id(), 'aluno_id': a, 'data_avaliacao': d3, 'genero': 'Feminino', 'idade': 33,
       'tipo': 'abdominal', 'abdominal_reps': 34, 'analise': 'Bom', 'criado_em': criado(d3)},
    ],
    'avaliacao_neuromotores_carga': [
      {'id': id(), 'aluno_id': a, 'data_avaliacao': d3, 'genero': 'Feminino',
       'exercicio': 'Agachamento livre', 'carga_kg': 60, 'repeticoes': 8, 'rm_calculado': 74.5,
       'criado_em': criado(d3)},
    ],
    'avaliacao_postural': [
      {
        'id': id(), 'aluno_id': a, 'data_avaliacao': d3,
        'foto_frente': '$a/postural/frente.png',
        'foto_costas': '$a/postural/costas.png',
        'foto_lado_dir': '$a/postural/lado_dir.png',
        'foto_lado_esq': '$a/postural/lado_esq.png',
        'desvios': {
          'cabeca_anteriorizada': 'leve',
          'ombros_desnivelados': 'leve',
          'hiperlordose': 'moderado',
          'pelve_anteversao': 'moderado',
          'joelho_valgo': 'leve',
        },
        'observacoes': 'Ombro direito levemente mais baixo. Anteversão compatível com o '
            'encurtamento de flexores de quadril relatado na anamnese.',
        'criado_em': criado(d3),
      },
    ],
  };
}
