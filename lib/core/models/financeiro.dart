import '../utils/moeda.dart';

/// Um plano que o personal vende.
///
/// A diferença entre Training, Nutrition e Performance não está no nome:
/// está em [incluiTreino] e [incluiDieta]. É por esses dois campos que o
/// app decide o que o aluno vê — o nome é só rótulo comercial.
class PlanoVenda {
  const PlanoVenda({
    required this.id,
    required this.nome,
    this.descricao,
    required this.periodicidade,
    required this.precoCentavos,
    this.incluiTreino = true,
    this.incluiDieta = false,
    this.maxParcelas = 1,
    this.ativo = true,
  });

  final String id;
  final String nome;
  final String? descricao;

  /// mensal, trimestral, semestral, anual, avulso.
  final String periodicidade;
  final int precoCentavos;
  final bool incluiTreino;
  final bool incluiDieta;
  final int maxParcelas;
  final bool ativo;

  /// Quantos meses o plano cobre. É o que transforma o preço cheio no
  /// valor por mês, e o que define quantas cobranças gerar.
  int get meses => switch (periodicidade) {
        'mensal' => 1,
        'trimestral' => 3,
        'semestral' => 6,
        'anual' => 12,
        _ => 1,
      };

  /// O "equivale a R$ X/mês" das artes. Só faz sentido acima de um mês.
  int? get porMesCentavos =>
      meses <= 1 ? null : (precoCentavos / meses).round();

  String get preco => Moeda.formatar(precoCentavos);
  String get periodicidadeNome => switch (periodicidade) {
        'mensal' => 'Mensal',
        'trimestral' => 'Trimestral',
        'semestral' => 'Semestral',
        'anual' => 'Anual',
        _ => 'Avulso',
      };

  /// Resumo do que o plano entrega, para o cartão não depender do nome.
  String get inclui {
    if (incluiTreino && incluiDieta) return 'Treino e dieta';
    if (incluiDieta) return 'Só dieta';
    return 'Só treino';
  }

  factory PlanoVenda.doMapa(Map<String, dynamic> m) => PlanoVenda(
        id: m['id'] as String,
        nome: m['nome'] as String? ?? 'Plano',
        descricao: m['descricao'] as String?,
        periodicidade: m['periodicidade'] as String? ?? 'mensal',
        precoCentavos: (m['preco_centavos'] as num?)?.toInt() ?? 0,
        incluiTreino: m['inclui_treino'] as bool? ?? true,
        incluiDieta: m['inclui_dieta'] as bool? ?? false,
        maxParcelas: (m['max_parcelas'] as num?)?.toInt() ?? 1,
        ativo: m['ativo'] as bool? ?? true,
      );
}

/// A assinatura de um aluno: qual plano ele tem e desde quando.
class Assinatura {
  const Assinatura({
    required this.id,
    required this.alunoId,
    required this.alunoNome,
    this.alunoFotoUrl,
    this.alunoWhatsapp,
    required this.planoId,
    required this.planoNome,
    required this.precoCentavos,
    required this.status,
    this.diaVencimento,
    required this.inicio,
    this.fim,
  });

  final String id;
  final String alunoId;
  final String alunoNome;
  final String? alunoFotoUrl;
  final String? alunoWhatsapp;

  final String planoId;
  final String planoNome;
  final int precoCentavos;

  /// ativa, inadimplente, pausada, cancelada, encerrada.
  final String status;
  final int? diaVencimento;
  final DateTime inicio;
  final DateTime? fim;

  bool get viva => status == 'ativa' || status == 'inadimplente';
  String get preco => Moeda.formatar(precoCentavos);

  String get statusNome => switch (status) {
        'ativa' => 'Em dia',
        'inadimplente' => 'Em atraso',
        'pausada' => 'Pausada',
        'cancelada' => 'Cancelada',
        _ => 'Encerrada',
      };

  factory Assinatura.doMapa(Map<String, dynamic> m) {
    final aluno = m['alunos'] as Map<String, dynamic>?;
    final plano = m['personal_planos'] as Map<String, dynamic>?;
    return Assinatura(
      id: m['id'] as String,
      alunoId: m['aluno_id'] as String,
      alunoNome: aluno?['nome'] as String? ?? 'Aluno',
      alunoFotoUrl: aluno?['foto_url'] as String?,
      alunoWhatsapp: aluno?['whatsapp'] as String?,
      planoId: m['plano_id'] as String,
      planoNome: plano?['nome'] as String? ?? 'Plano',
      precoCentavos: (plano?['preco_centavos'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'ativa',
      diaVencimento: (m['dia_vencimento'] as num?)?.toInt(),
      inicio: DateTime.tryParse(m['inicio'] as String? ?? '') ?? DateTime.now(),
      fim: DateTime.tryParse(m['fim'] as String? ?? ''),
    );
  }
}

/// Uma cobrança. É a linha que o personal marca como paga.
class Cobranca {
  const Cobranca({
    required this.id,
    this.alunoId,
    required this.alunoNome,
    this.alunoWhatsapp,
    this.descricao,
    required this.valorCentavos,
    required this.status,
    required this.vencimento,
    this.pagoEm,
    this.metodo,
    this.origem = 'manual',
    this.parcelaNumero,
    this.parcelas = 1,
  });

  final String id;
  final String? alunoId;
  final String alunoNome;
  final String? alunoWhatsapp;
  final String? descricao;
  final int valorCentavos;

  /// pendente, pago, atrasado, estornado, cancelado, falhou.
  final String status;
  final DateTime vencimento;
  final DateTime? pagoEm;
  final String? metodo;

  /// 'manual' = recebido por fora (Pix direto, dinheiro). Entra no
  /// relatório, mas nunca na carteira — esse dinheiro não passou pelo
  /// gateway, então não há o que sacar.
  final String origem;

  final int? parcelaNumero;
  final int parcelas;

  bool get paga => status == 'pago';

  /// Vencida é questão de data, não só de status: uma cobrança gravada
  /// como 'pendente' ontem já está atrasada hoje, e nenhuma rotina passou
  /// por ela para mudar isso.
  bool get vencida {
    if (paga || status == 'cancelado' || status == 'estornado') return false;
    final hoje = DateTime.now();
    return vencimento.isBefore(DateTime(hoje.year, hoje.month, hoje.day));
  }

  int get diasDeAtraso {
    if (!vencida) return 0;
    final hoje = DateTime.now();
    return DateTime(hoje.year, hoje.month, hoje.day)
        .difference(vencimento)
        .inDays;
  }

  String get valor => Moeda.formatar(valorCentavos);

  String get vencimentoTexto =>
      '${vencimento.day.toString().padLeft(2, '0')}/'
      '${vencimento.month.toString().padLeft(2, '0')}/${vencimento.year}';

  /// "2 de 6" quando o plano foi dividido; vazio quando é parcela única.
  String get parcelaTexto =>
      parcelas <= 1 || parcelaNumero == null ? '' : '$parcelaNumero de $parcelas';

  factory Cobranca.doMapa(Map<String, dynamic> m) {
    final aluno = m['alunos'] as Map<String, dynamic>?;
    return Cobranca(
      id: m['id'] as String,
      alunoId: m['aluno_id'] as String?,
      alunoNome: aluno?['nome'] as String? ?? 'Sem aluno',
      alunoWhatsapp: aluno?['whatsapp'] as String?,
      descricao: m['descricao'] as String?,
      valorCentavos: (m['valor_centavos'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'pendente',
      vencimento:
          DateTime.tryParse(m['vencimento'] as String? ?? '') ?? DateTime.now(),
      pagoEm: DateTime.tryParse(m['pago_em'] as String? ?? ''),
      metodo: m['metodo'] as String?,
      origem: m['origem'] as String? ?? 'manual',
      parcelaNumero: (m['parcela_numero'] as num?)?.toInt(),
      parcelas: (m['parcelas'] as num?)?.toInt() ?? 1,
    );
  }
}

/// Os números do mês, já somados.
class ResumoFinanceiro {
  const ResumoFinanceiro({
    this.recebidoCentavos = 0,
    this.aReceberCentavos = 0,
    this.atrasadoCentavos = 0,
    this.assinaturasAtivas = 0,
    this.alunosEmAtraso = 0,
    this.recorrenteCentavos = 0,
  });

  final int recebidoCentavos;
  final int aReceberCentavos;
  final int atrasadoCentavos;
  final int assinaturasAtivas;
  final int alunosEmAtraso;

  /// Quanto as assinaturas vivas representam por mês. É o número que diz
  /// se o negócio cresce, independente de quem pagou este mês.
  final int recorrenteCentavos;
}
