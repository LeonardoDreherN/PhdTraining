/// O que a home do personal precisa saber, numa consulta só.
class ResumoHome {
  const ResumoHome({
    required this.alunosAtivos,
    required this.alunosInativos,
    required this.temFicha,
    required this.recebidoCentavos,
    required this.aReceberCentavos,
    required this.atrasadoCentavos,
    required this.cobrancasAtrasadas,
    required this.pendencias,
    this.cobrancasAReceber = 0,
    this.receitaMeses = const [],
    this.treinosPorDia = const [0, 0, 0, 0, 0, 0, 0],
    this.adesaoSemana = 0,
    this.novosNoMes = 0,
    this.treinaramHoje = const [],
    this.recentes = const [],
    this.alunos = const [],
    this.aniversarios = const [],
  });

  final int alunosAtivos;
  final int alunosInativos;
  final bool temFicha;

  final int recebidoCentavos;
  final int aReceberCentavos;
  final int atrasadoCentavos;
  final int cobrancasAtrasadas;
  final int cobrancasAReceber;

  /// Recebido nos últimos seis meses, do mais antigo ao atual. É o que
  /// desenha o gráfico do cartão de receita.
  final List<int> receitaMeses;

  /// Treinos feitos por todos os alunos em cada dia da semana corrente,
  /// segunda primeiro.
  final List<int> treinosPorDia;

  /// Parte dos alunos ativos que treinou nos últimos 7 dias, de 0 a 1.
  final double adesaoSemana;

  final int novosNoMes;
  final List<AlunoResumo> treinaramHoje;
  final List<TreinoRecente> recentes;

  /// Ativos, de quem treinou por último para quem sumiu.
  final List<AlunoResumo> alunos;

  /// Aniversários nos próximos 7 dias.
  final List<({AlunoResumo aluno, DateTime dia})> aniversarios;

  /// Alunos que precisam de uma ação hoje.
  final List<Pendencia> pendencias;

  int get totalAlunos => alunosAtivos + alunosInativos;
  int get treinosNaSemana => treinosPorDia.fold(0, (s, n) => s + n);

  /// Variação do mês atual sobre o anterior, em fração (0.18 = +18%).
  /// `null` quando o mês anterior foi zero — "+∞%" não ajuda ninguém.
  double? get variacaoReceita {
    if (receitaMeses.length < 2) return null;
    final anterior = receitaMeses[receitaMeses.length - 2];
    if (anterior <= 0) return null;
    return (receitaMeses.last - anterior) / anterior;
  }

  /// Conta recém-criada: ainda não dá para mostrar faturamento, porque
  /// "R$ 0,00" como número principal da tela não informa nada — só
  /// desanima. A home troca para uma lista do que fazer primeiro.
  bool get primeiroAcesso => totalAlunos == 0;

  static const vazio = ResumoHome(
    alunosAtivos: 0,
    alunosInativos: 0,
    temFicha: false,
    recebidoCentavos: 0,
    aReceberCentavos: 0,
    atrasadoCentavos: 0,
    cobrancasAtrasadas: 0,
    pendencias: [],
  );
}

/// Um aluno como a home o mostra: rosto, nome e quando treinou.
class AlunoResumo {
  const AlunoResumo({required this.linha, this.ultimoTreino});

  /// A linha inteira de `alunos`: é o `extra` que a tela de perfil espera.
  final Map<String, dynamic> linha;
  final DateTime? ultimoTreino;

  String get id => linha['id'] as String;
  String get nome => (linha['nome'] as String?)?.trim() ?? 'Aluno';
  String get primeiroNome => nome.split(' ').first;
  String? get fotoUrl => linha['foto_url'] as String?;
  String? get whatsapp => linha['whatsapp'] as String?;
}

class TreinoRecente {
  const TreinoRecente({
    required this.aluno,
    required this.fichaNome,
    required this.quando,
    this.minutos,
  });

  final AlunoResumo aluno;
  final String fichaNome;
  final DateTime quando;
  final int? minutos;
}

enum TipoPendencia { mensalidadeAtrasada, semTreinar, semFicha }

class Pendencia {
  const Pendencia({
    required this.alunoId,
    required this.alunoNome,
    required this.tipo,
    required this.detalhe,
    this.valorCentavos,
    this.avatarUrl,
    this.whatsapp,
  });

  final String alunoId;
  final String alunoNome;
  final TipoPendencia tipo;

  /// Frase curta que explica o problema: "vencida há 6 dias".
  final String detalhe;

  final int? valorCentavos;
  final String? avatarUrl;
  final String? whatsapp;

  /// O texto do botão muda com o problema — é o que transforma a lista de
  /// avisos em lista de ações.
  String get acao => switch (tipo) {
        TipoPendencia.mensalidadeAtrasada => 'Cobrar',
        TipoPendencia.semTreinar => 'Falar',
        TipoPendencia.semFicha => 'Montar',
      };
}
