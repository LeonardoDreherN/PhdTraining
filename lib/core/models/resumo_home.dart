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
  });

  final int alunosAtivos;
  final int alunosInativos;
  final bool temFicha;

  final int recebidoCentavos;
  final int aReceberCentavos;
  final int atrasadoCentavos;
  final int cobrancasAtrasadas;

  /// Alunos que precisam de uma ação hoje.
  final List<Pendencia> pendencias;

  int get totalAlunos => alunosAtivos + alunosInativos;

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

enum TipoPendencia { mensalidadeAtrasada, semTreinar, semFicha }

class Pendencia {
  const Pendencia({
    required this.alunoId,
    required this.alunoNome,
    required this.tipo,
    required this.detalhe,
    this.valorCentavos,
    this.avatarUrl,
  });

  final String alunoId;
  final String alunoNome;
  final TipoPendencia tipo;

  /// Frase curta que explica o problema: "vencida há 6 dias".
  final String detalhe;

  final int? valorCentavos;
  final String? avatarUrl;

  /// O texto do botão muda com o problema — é o que transforma a lista de
  /// avisos em lista de ações.
  String get acao => switch (tipo) {
        TipoPendencia.mensalidadeAtrasada => 'Cobrar',
        TipoPendencia.semTreinar => 'Falar',
        TipoPendencia.semFicha => 'Montar',
      };
}
