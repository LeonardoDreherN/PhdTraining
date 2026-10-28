import '../../../core/models/avaliacao.dart';
import '../../../core/utils/avaliacao_calculos.dart';
import '../alunos/avaliacao_dobras_screen.dart';
import 'avaliacao_widgets.dart';

/// Os testes do dia em texto, do jeito que aparecem na sessão e no PDF.
///
/// Um lugar só para os dois, para o relatório que o aluno recebe dizer
/// exatamente o que o personal viu na tela.
class LinhaTeste {
  const LinhaTeste(this.titulo, this.valor, [this.detalhe]);
  final String titulo;
  final String valor;

  /// A análise que o formulário antigo já calcula ("Bom", "Na média"...).
  final String? detalhe;
}

String? _txt(Object? v) {
  final s = (v as String?)?.trim();
  return s == null || s.isEmpty ? null : s;
}

double? _d(Object? v) => (v as num?)?.toDouble();

List<LinhaTeste> linhasComposicao(AvaliacaoCompleta av) {
  final linhas = <LinhaTeste>[];
  final dobras = av.dobras;
  if (dobras != null) {
    final proto = DobraProtocolos.nomeForId(dobras['protocolo'] as String? ?? '');
    linhas.add(LinhaTeste('Dobras cutâneas', '${numBr(_d(dobras['perc_gordura']))}% gordura', proto));
    if (_d(dobras['soma_dobras']) != null) {
      linhas.add(LinhaTeste('Soma das dobras', '${numBr(_d(dobras['soma_dobras']))} mm'));
    }
  }
  final bio = av.bioimpedancia;
  if (bio != null) {
    linhas.add(LinhaTeste('Bioimpedância', '${numBr(_d(bio['perc_gordura']))}% gordura'));
  }
  return linhas;
}

List<LinhaTeste> linhasNeuromotoras(AvaliacaoCompleta av) {
  return [
    for (final f in av.flexibilidade)
      LinhaTeste('Flexibilidade (sentar e alcançar)', '${numBr(_d(f['alcance']))} cm', _txt(f['analise'])),
    for (final r in av.resistencia)
      r['tipo'] == 'braco'
          ? LinhaTeste('Flexão de braço', '${r['flexao_braco_reps'] ?? '—'} repetições', _txt(r['analise']))
          : LinhaTeste('Abdominal em 1 minuto', '${r['abdominal_reps'] ?? '—'} repetições', _txt(r['analise'])),
    for (final i in av.impulsao)
      i['tipo'] == 'vertical'
          ? LinhaTeste('Impulsão vertical', '${numBr(_d(i['impulsao_vertical']), casas: 0)} cm', _txt(i['analise']))
          : LinhaTeste('Impulsão horizontal', '${numBr(_d(i['impulsao_horizontal']), casas: 0)} cm', _txt(i['analise'])),
    for (final c in av.carga)
      LinhaTeste(
        'Força — ${_txt(c['exercicio']) ?? 'exercício'}',
        '1RM ${numBr(_d(c['rm_calculado']))} kg',
        '${numBr(_d(c['carga_kg']))} kg × ${c['repeticoes'] ?? '—'} repetições',
      ),
  ];
}

List<LinhaTeste> linhasCardio(AvaliacaoCompleta av) {
  return [
    for (final c in av.cardio)
      LinhaTeste(
        ProtocoloCardio.porId(c['protocolo'] as String?)?.nome ?? (c['protocolo'] as String? ?? 'Teste'),
        '${numBr(_d(c['vo2max']))} ml/kg/min',
        _txt(c['classificacao']),
      ),
  ];
}

/// Linha de comparação com a avaliação anterior.
class LinhaComparacao {
  const LinhaComparacao(this.rotulo, this.anterior, this.atual, this.unidade, {this.menorEhMelhor});
  final String rotulo;
  final double anterior;
  final double atual;
  final String unidade;

  /// `true` quando cair é bom (gordura, cintura), `false` quando subir é
  /// bom (massa magra, VO₂), `null` quando depende do objetivo (peso).
  final bool? menorEhMelhor;

  double get diferenca => atual - anterior;

  Nivel get nivel {
    if (menorEhMelhor == null || diferenca.abs() < 0.05) return Nivel.neutro;
    final melhorou = menorEhMelhor! ? diferenca < 0 : diferenca > 0;
    return melhorou ? Nivel.bom : Nivel.atencao;
  }
}

List<LinhaComparacao> comparacao(AvaliacaoCompleta av) {
  final ant = av.anterior;
  if (ant == null) return const [];
  final pares = <(String, double?, double?, String, bool?)>[
    ('Peso', ant.peso, av.peso, 'kg', null),
    ('Gordura', ant.percGordura, av.percGordura, '%', true),
    ('Massa magra', ant.massaMagra, av.massaMagra, 'kg', false),
    ('Massa gorda', ant.massaGorda, av.massaGorda, 'kg', true),
    ('Cintura', ant.cintura, av.cintura, 'cm', true),
    ('Quadril', ant.quadril, av.quadril, 'cm', null),
    ('IMC', ant.imc?.valor, av.imc?.valor, '', null),
    ('VO₂máx', ant.vo2max, av.vo2max, 'ml/kg/min', false),
  ];
  return [
    for (final (rotulo, a, b, u, menor) in pares)
      if (a != null && b != null) LinhaComparacao(rotulo, a, b, u, menorEhMelhor: menor),
  ];
}
