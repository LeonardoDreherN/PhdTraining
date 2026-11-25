import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/conquista.dart';

NumerosDoAluno n({
  int treinos = 0,
  int diasPrevistos = 0,
  int semanasCompletas = 0,
  int sequenciaSemanas = 0,
  int exercicios = 0,
  int catalogo = 0,
  int diasPlanoCompleto = 0,
  int sequenciaDiasPlano = 0,
  int pesagens = 0,
  int semanasComPeso = 0,
  int fotosDiario = 0,
  int diasAguaMeta = 0,
  int mesesAcompanhamento = 0,
  int checkins = 0,
  int checkinsSeguidos = 0,
  int diasComRegistro = 0,
  int fotosProgresso = 0,
  int mesesComFoto = 0,
  int mesesFotoCumpridos = 0,
}) =>
    NumerosDoAluno(
      treinos: treinos,
      diasPrevistos: diasPrevistos,
      semanasCompletas: semanasCompletas,
      sequenciaSemanas: sequenciaSemanas,
      exercicios: exercicios,
      catalogo: catalogo,
      diasPlanoCompleto: diasPlanoCompleto,
      sequenciaDiasPlano: sequenciaDiasPlano,
      pesagens: pesagens,
      semanasComPeso: semanasComPeso,
      fotosDiario: fotosDiario,
      diasAguaMeta: diasAguaMeta,
      mesesAcompanhamento: mesesAcompanhamento,
      checkins: checkins,
      checkinsSeguidos: checkinsSeguidos,
      diasComRegistro: diasComRegistro,
      fotosProgresso: fotosProgresso,
      mesesComFoto: mesesComFoto,
      mesesFotoCumpridos: mesesFotoCumpridos,
    );

Conquista cod(String c) => Conquista.porCodigo(c)!;

void main() {
  group('Catálogo', () {
    test('tem os marcos de treino da especificação', () {
      for (final m in [1, 10, 25, 50, 100, 250, 500]) {
        expect(Conquista.porCodigo('treinos_$m'), isNotNull,
            reason: 'falta o marco de $m treinos');
      }
    });

    test('tem os marcos de consistência da especificação', () {
      // 1, 2, 4, 8, 12 semanas e seis meses (26 semanas).
      for (final m in [1, 2, 4, 8, 12, 26]) {
        expect(Conquista.porCodigo('semanas_$m'), isNotNull,
            reason: 'falta o marco de $m semanas');
      }
    });

    test('nenhum código repetido', () {
      final vistos = <String>{};
      for (final c in Conquista.catalogoTreino) {
        expect(vistos.add(c.codigo), isTrue, reason: 'repetido: ${c.codigo}');
      }
    });

    test('código desconhecido devolve nulo em vez de estourar', () {
      expect(Conquista.porCodigo('nao_existe'), isNull);
    });
  });

  group('Progresso', () {
    test('zero quando não começou', () {
      expect(cod('treinos_10').progresso(n()), 0);
    });

    test('proporcional no meio do caminho', () {
      expect(cod('treinos_10').progresso(n(treinos: 5)), closeTo(0.5, 0.001));
    });

    test('não passa de 1 depois de conquistada', () {
      // Sem o limite, a barra de "250 treinos" ficaria com 200% para quem
      // tem 500 e a tela desenharia fora do cartão.
      expect(cod('treinos_10').progresso(n(treinos: 500)), 1);
    });

    test('o texto mostra quanto falta, não porcentagem', () {
      expect(cod('treinos_50').progressoTexto(n(treinos: 37)), '37 de 50');
    });

    test('o texto não passa da meta', () {
      expect(cod('treinos_50').progressoTexto(n(treinos: 80)), '50 de 50');
    });
  });

  group('Consistência é sobre a própria programação', () {
    test('três treinos por semana valem igual a cinco', () {
      // O critério central do documento: quem cumpre a própria
      // programação conquista, independente do volume. As duas contas
      // chegam ao mesmo marco porque ambas fecharam 4 semanas.
      final tresPorSemana = n(diasPrevistos: 3, sequenciaSemanas: 4);
      final cincoPorSemana = n(diasPrevistos: 5, sequenciaSemanas: 4);

      expect(cod('semanas_4').progresso(tresPorSemana), 1);
      expect(cod('semanas_4').progresso(cincoPorSemana), 1);
    });

    test('quem treina mais não ganha medalha de consistência por volume', () {
      // 200 treinos, mas sem nenhuma semana completa: nenhuma medalha de
      // consistência. É o que impede a conquista de premiar tempo livre.
      final muitoTreino = n(treinos: 200, sequenciaSemanas: 0);
      expect(cod('semanas_1').progresso(muitoTreino), 0);
      expect(cod('treinos_100').progresso(muitoTreino), 1);
    });
  });

  group('Barra de desbloqueios', () {
    test('o exemplo da especificação: 125 de 500 dá 25%', () {
      expect(n(exercicios: 125, catalogo: 500).progressoCatalogo,
          closeTo(0.25, 0.0001));
    });

    test('catálogo vazio não divide por zero', () {
      expect(n(exercicios: 10, catalogo: 0).progressoCatalogo, 0);
    });

    test('mais desbloqueios que o catálogo não passa de 100%', () {
      // Acontece se o personal prescreveu exercícios próprios, que não
      // entram no denominador oficial.
      expect(n(exercicios: 600, catalogo: 500).progressoCatalogo, 1);
    });
  });

  group('Catálogo de nutrição', () {
    test('tem os marcos de dias no plano da especificação', () {
      for (final m in [1, 7, 15, 30, 60]) {
        expect(Conquista.porCodigo('plano_$m'), isNotNull,
            reason: 'falta o marco de $m dias no plano');
      }
    });

    test('treino e nutrição não compartilham código', () {
      final treino = {for (final c in Conquista.catalogoTreino) c.codigo};
      final nutri = {for (final c in Conquista.catalogoNutricao) c.codigo};
      expect(treino.intersection(nutri), isEmpty);
    });

    test('cada catálogo devolve só a própria categoria', () {
      expect(
        Conquista.de(CategoriaConquista.nutricao)
            .every((c) => c.categoria == CategoriaConquista.nutricao),
        isTrue,
      );
      expect(
        Conquista.de(CategoriaConquista.treino)
            .every((c) => c.categoria == CategoriaConquista.treino),
        isTrue,
      );
    });
  });

  group('Regras que a especificação exige', () {
    test('dias no plano somam, não precisam ser seguidos', () {
      // "Distinguir dias acumulados de sequências consecutivas, para não
      // penalizar o aluno por situações pontuais."
      final caiuUmDia = n(diasPlanoCompleto: 30, sequenciaDiasPlano: 3);
      expect(cod('plano_30').progresso(caiuUmDia), 1);
    });

    test('semana consistente exige os sete dias seguidos', () {
      final acumuladoAlto = n(diasPlanoCompleto: 60, sequenciaDiasPlano: 3);
      expect(cod('plano_semana').progresso(acumuladoAlto), lessThan(1));

      final seteSeguidos = n(diasPlanoCompleto: 7, sequenciaDiasPlano: 7);
      expect(cod('plano_semana').progresso(seteSeguidos), 1);
    });

    test('a conquista de peso mede registro, não quilo perdido', () {
      // Nenhum critério do catálogo olha o VALOR do peso. Se alguém um
      // dia adicionar uma medalha por emagrecer, este teste cai — e é
      // para cair: a especificação proíbe.
      for (final c in Conquista.catalogoNutricao) {
        if (!c.codigo.startsWith('peso_')) continue;
        final soRegistrou = n(pesagens: 99, semanasComPeso: 99);
        final naoRegistrou = n(pesagens: 0, semanasComPeso: 0);
        expect(c.progresso(soRegistrou), 1);
        expect(c.progresso(naoRegistrou), 0);
      }
    });

    test('não existe marco diário de pesagem', () {
      // "A frequência de pesagem deve ser semanal; não criar lembretes ou
      // metas de pesagem diária." Os marcos acima do primeiro registro
      // contam SEMANAS.
      final acimaDoPrimeiro = Conquista.catalogoNutricao
          .where((c) => c.codigo.startsWith('peso_') && c.codigo != 'peso_1');
      expect(acimaDoPrimeiro, isNotEmpty);
      for (final c in acimaDoPrimeiro) {
        // Pesou 50 vezes em duas semanas: não basta, porque o critério
        // é semana com registro, não quantidade de pesagens.
        expect(c.progresso(n(pesagens: 50, semanasComPeso: 2)), lessThan(1));
      }
    });
  });

  group('Leitura do banco', () {
    test('campo ausente vira zero em vez de estourar', () {
      final x = NumerosDoAluno.doMapa({'treinos': 7});
      expect(x.treinos, 7);
      expect(x.catalogo, 0);
      expect(x.sequenciaSemanas, 0);
    });

    test('a conquista guarda a data e o valor que a disparou', () {
      final c = ConquistaDoAluno.doMapa({
        'codigo': 'treinos_50',
        'desbloqueado_em': '2026-03-15T10:00:00Z',
        'valor': 50,
      });
      expect(c.codigo, 'treinos_50');
      expect(c.desbloqueadoEm.year, 2026);
      expect(c.valor, 50);
      expect(c.conquista?.nome, '50 treinos');
    });

    test('conquista de código desconhecido não quebra a tela', () {
      // Pode acontecer se o banco tiver um código de uma versão futura
      // do app. A tela ignora em vez de estourar.
      final c = ConquistaDoAluno.doMapa({
        'codigo': 'medalha_do_futuro',
        'desbloqueado_em': '2026-03-15T10:00:00Z',
      });
      expect(c.conquista, isNull);
    });
  });

  group('Check-in mensal', () {
    test('as três conquistas da especificação existem', () {
      for (final c in ['checkin_1', 'checkin_3', 'checkin_6']) {
        expect(Conquista.porCodigo(c), isNotNull, reason: c);
      }
      expect(cod('checkin_1').nome, 'Acompanhamento em dia');
      // "Mestre da organização" saiu daqui no 0034: a especificação dá
      // esse nome a quem registra o planejamento da semana, recurso que
      // o app não tem.
      expect(cod('checkin_3').nome, 'Três meses em dia');
      expect(cod('checkin_6').nome, 'Compromisso renovado');
    });

    test('a primeira conta o acumulado', () {
      expect(cod('checkin_1').valorDe(n(checkins: 1)), 1);
      // Mesmo sem sequência: um check-in isolado já põe o aluno em dia.
      expect(cod('checkin_1').progresso(n(checkins: 1)), 1.0);
    });

    test('as de constância contam SEQUÊNCIA, não total', () {
      // Nove check-ins espalhados em dois anos não são organização.
      final espalhados = n(checkins: 9, checkinsSeguidos: 1);
      expect(cod('checkin_3').progresso(espalhados), lessThan(1.0));
      expect(cod('checkin_6').progresso(espalhados), lessThan(1.0));

      final seguidos = n(checkins: 6, checkinsSeguidos: 6);
      expect(cod('checkin_3').progresso(seguidos), 1.0);
      expect(cod('checkin_6').progresso(seguidos), 1.0);
    });

    test('"Compromisso renovado" saiu do tempo de plano', () {
      // Tempo de plano passa sozinho; o nome foi para quem renova mês a
      // mês. Se um dia alguém devolver o nome para `meses_6`, as duas
      // conquistas passam a ter o mesmo nome e este teste avisa.
      expect(cod('meses_6').nome, isNot(cod('checkin_6').nome));
      expect(cod('meses_6').valorDe(n(mesesAcompanhamento: 6)), 6);
    });
  });

  group('Especificação de nutrição', () {
    test('"30 dias de dedicação" conta participação, não perfeição', () {
      // A especificação é explícita: reconhecer a participação
      // consistente, NÃO exigir perfeição alimentar. Trinta dias com
      // registro bastam, mesmo sem nenhum dia 100%.
      final participou = n(diasComRegistro: 30, diasPlanoCompleto: 2);
      expect(cod('dedicacao_30').progresso(participou), 1.0);

      // E são conquistas diferentes: o marco dos 30 dias perfeitos
      // continua exigindo perfeição.
      expect(cod('plano_30').progresso(participou), lessThan(1.0));
    });

    test('as conquistas de foto olham a foto de acompanhamento', () {
      // Um aluno que fotografa o almoço todo dia não ganha medalha de
      // evolução: `fotosDiario` é a foto do prato e não entra em
      // conta nenhuma aqui.
      final sofotoDoPrato = n(fotosDiario: 90);
      expect(cod('fotos_1').progresso(sofotoDoPrato), 0);
      expect(cod('fotos_3').progresso(sofotoDoPrato), 0);

      expect(cod('fotos_1').progresso(n(fotosProgresso: 1)), 1.0);
    });

    test('"Fotografia da evolução" é MENSAL, não três fotos no mesmo dia', () {
      expect(cod('fotos_3').progresso(n(fotosProgresso: 9, mesesComFoto: 1)),
          lessThan(1.0));
      expect(cod('fotos_3').progresso(n(fotosProgresso: 3, mesesComFoto: 3)),
          1.0);
    });

    test('"Aluno disciplinado" só existe se o profissional pediu', () {
      // O evento que a libera, na especificação, é "fotos mensais
      // SOLICITADAS são anexadas". Sem pedido não há o que atender, e
      // o banco devolve zero.
      expect(cod('disciplinado').progresso(n(mesesComFoto: 5)), 0);
      expect(cod('disciplinado').progresso(n(mesesFotoCumpridos: 1)), 1.0);
    });

    test('nenhuma conquista se chama "Mestre da organização"', () {
      // A especificação a define como registrar o planejamento
      // alimentar da semana, "quando esse recurso estiver disponível".
      // O recurso não existe; enquanto não existir, o nome não pode
      // estar pendurado em outra coisa.
      for (final c in Conquista.todas) {
        expect(c.nome, isNot('Mestre da organização'), reason: c.codigo);
      }
    });

    test('os marcos de dia 100% são 1, 7, 15, 30 e 60', () {
      for (final m in [1, 7, 15, 30, 60]) {
        expect(Conquista.porCodigo('plano_$m'), isNotNull, reason: 'plano_$m');
      }
    });

    test('não existe marco de pesagem diária', () {
      // A especificação proíbe pedir ou incentivar pesagem diária.
      // Toda conquista de peso sai de pesagens ou de semanas com peso.
      final diario = n(pesagens: 1, semanasComPeso: 1);
      final semanal = n(pesagens: 1, semanasComPeso: 12);
      expect(cod('peso_12').progresso(diario), lessThan(1.0));
      expect(cod('peso_12').progresso(semanal), 1.0);
    });
  });
}
