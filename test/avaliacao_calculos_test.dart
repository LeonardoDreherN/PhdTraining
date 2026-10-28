import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/avaliacao.dart';
import 'package:phd_personal/core/utils/avaliacao_calculos.dart';
import 'package:phd_personal/modules/personal/avaliacao/avaliacao_pdf.dart';
import 'package:phd_personal/modules/personal/avaliacao/avaliacao_resumo.dart';

ProtocoloCardio _p(String id) => ProtocoloCardio.porId(id)!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Índices', () {
    test('IMC e classificação da OMS', () {
      final i = Indices.imc(70, 175)!;
      expect(i.valor, closeTo(22.86, 0.01));
      expect(i.classificacao!.rotulo, 'Peso adequado');
      expect(Indices.imc(95, 170)!.classificacao!.rotulo, 'Obesidade grau I');
      expect(Indices.imc(null, 170), isNull);
      expect(Indices.imc(70, 0), isNull);
    });

    test('RCQ usa corte diferente por sexo', () {
      expect(Indices.rcq(90, 100, masculino: true)!.classificacao!.nivel, Nivel.risco);
      expect(Indices.rcq(84, 100, masculino: false)!.classificacao!.nivel, Nivel.bom);
      expect(Indices.rcq(86, 100, masculino: false)!.classificacao!.nivel, Nivel.risco);
    });

    test('RCE: metade da altura é o corte', () {
      expect(Indices.rce(84, 170)!.classificacao!.rotulo, 'Adequada');
      expect(Indices.rce(85, 170)!.classificacao!.rotulo, 'Risco aumentado');
      expect(Indices.rce(110, 170)!.classificacao!.rotulo, 'Risco alto');
    });

    test('IAC de Bergman', () {
      // 100 / 1,7^1,5 − 18
      expect(Indices.iac(100, 170)!.valor, closeTo(27.12, 0.01));
    });
  });

  group('Pressão arterial (Diretriz Brasileira 2020)', () {
    test('faixas', () {
      expect(Cardiaco.pressao(119, 79)!.rotulo, 'Ótima');
      expect(Cardiaco.pressao(120, 80)!.rotulo, 'Normal');
      expect(Cardiaco.pressao(135, 80)!.rotulo, 'Pré-hipertensão');
      expect(Cardiaco.pressao(145, 95)!.rotulo, 'Hipertensão estágio 1');
    });

    test('vale a maior das duas', () {
      expect(Cardiaco.pressao(118, 112)!.rotulo, 'Hipertensão estágio 3');
    });
  });

  group('Frequência cardíaca', () {
    test('FCmáx', () {
      expect(Cardiaco.fcMaxTanaka(30), 187);
      expect(Cardiaco.fcMaxClassica(30), 190);
      expect(Cardiaco.fcMaxTanaka(null), isNull);
    });

    test('Karvonen', () {
      final z = Cardiaco.zonas(190, 60);
      expect(z, hasLength(5));
      expect(z.first.bpmDe, 125);
      expect(z.first.bpmAte, 138);
      expect(z.last.bpmAte, 190);
    });

    test('sem FC de repouso usa % da FCmáx', () {
      expect(Cardiaco.zonas(200, null).first.bpmDe, 100);
    });
  });

  group('VO₂máx', () {
    const homem30 = EntradaCardio(masculino: true, idade: 30);

    test('Cooper 12 min', () {
      const e = EntradaCardio(masculino: true, idade: 30, distanciaM: 2400);
      expect(_p('cooper12').vo2max(e), closeTo(42.37, 0.01));
    });

    test('Corrida de 2.400 m em 12 minutos', () {
      const e = EntradaCardio(masculino: true, idade: 30, tempoSeg: 720);
      expect(_p('corrida2400').vo2max(e), closeTo(43.5, 0.01));
    });

    test('Rockport', () {
      const e = EntradaCardio(masculino: true, idade: 30, pesoKg: 80, tempoSeg: 900, fcFinal: 140);
      expect(_p('rockport').vo2max(e), closeTo(43.09, 0.02));
    });

    test('Rockport sem idade não calcula', () {
      const e = EntradaCardio(masculino: true, pesoKg: 80, tempoSeg: 900, fcFinal: 140);
      expect(_p('rockport').vo2max(e), isNull);
    });

    test('Banco de Queens College', () {
      expect(_p('banco_queens').vo2max(const EntradaCardio(masculino: true, fcFinal: 150)),
          closeTo(48.33, 0.01));
      expect(_p('banco_queens').vo2max(const EntradaCardio(masculino: false, fcFinal: 150)),
          closeTo(38.11, 0.01));
    });

    test('Bruce', () {
      expect(_p('bruce').vo2max(const EntradaCardio(masculino: false, tempoSeg: 600)), closeTo(39.9, 0.01));
      expect(_p('bruce').vo2max(const EntradaCardio(masculino: true, tempoSeg: 600)), closeTo(34.11, 0.01));
    });

    test('resultado impossível vira null, não número', () {
      expect(_p('cooper12').vo2max(homem30), isNull);
      const e = EntradaCardio(masculino: true, idade: 30, distanciaM: 300);
      expect(_p('cooper12').vo2max(e), isNull);
    });

    test('classificação AHA', () {
      expect(classificarVo2(42.4, masculino: true, idade: 25)!.rotulo, 'Regular');
      expect(classificarVo2(43, masculino: true, idade: 25)!.rotulo, 'Boa');
      expect(classificarVo2(36, masculino: false, idade: 35)!.rotulo, 'Boa');
      // Fora da tabela: aproxima pela faixa vizinha.
      expect(classificarVo2(54, masculino: true, idade: 17)!.rotulo, 'Excelente');
      expect(classificarVo2(10, masculino: true, idade: 80)!.rotulo, 'Muito fraca');
    });
  });

  group('Sexo para as fórmulas', () {
    test('cadastro', () {
      expect(sexoParaFormula('Masculino'), isTrue);
      expect(sexoParaFormula('Feminino'), isFalse);
      expect(sexoParaFormula('Outro'), isNull);
      expect(ehMasculino(null), isTrue);
    });
  });

  group('Sessão', () {
    AvaliacaoCompleta sessao() {
      final anterior = AvaliacaoCompleta(
        sessao: AvaliacaoSessao(alunoId: 'a', data: DateTime(2026, 7, 20), peso: 84, cintura: 92),
        aluno: const {'id': 'a'},
        dobras: const {'perc_gordura': 22.0, 'massa_magra': 65.5, 'estatura': 178},
      );
      return AvaliacaoCompleta(
        sessao: AvaliacaoSessao(
          alunoId: 'a',
          data: DateTime(2026, 10, 26),
          cintura: 88,
          paSistolica: 128,
          paDiastolica: 82,
          fcRepouso: 62,
          observacoes: 'Manter o déficit calórico e subir o volume de cardio.',
          proximaAvaliacao: DateTime(2027, 1, 24),
        ),
        aluno: const {
          'id': 'a',
          'nome': 'João da Silva',
          'genero': 'Masculino',
          'data_nascimento': '1990-03-10',
          'avaliacao_data': '2026-10-26',
        },
        dobras: const {'peso': 81.2, 'quadril': 99, 'perc_gordura': 18.4, 'massa_magra': 66.3, 'protocolo': 'pollock7'},
        cardio: const [
          {'protocolo': 'cooper12', 'vo2max': 44.1, 'classificacao': 'Boa'},
        ],
        flexibilidade: const [
          {'alcance': 31.5, 'analise': 'Bom'},
        ],
        postural: const {'desvios': {'hipercifose': 'leve', 'joelho_valgo': 'moderado', 'lixo': 'x'}},
        estaturaAnterior: 178,
        anterior: anterior,
      );
    }

    test('medidas vêm do teste quando a sessão não tem', () {
      final av = sessao();
      expect(av.peso, 81.2);
      expect(av.estatura, 178);
      expect(av.cintura, 88);
      expect(av.idade, 36);
      expect(av.imc!.valor, closeTo(25.63, 0.01));
      expect(av.origemGordura, 'Dobras cutâneas');
    });

    test('desvios ignoram grau desconhecido', () {
      expect(sessao().desvios.keys, unorderedEquals(['hipercifose', 'joelho_valgo']));
    });

    test('comparação marca o que melhorou', () {
      final linhas = {for (final l in comparacao(sessao())) l.rotulo: l};
      expect(linhas['Gordura']!.nivel, Nivel.bom);
      expect(linhas['Massa magra']!.nivel, Nivel.bom);
      expect(linhas['Cintura']!.diferenca, -4);
      expect(linhas['Peso']!.nivel, Nivel.neutro);
    });

    test('a data da sessão viaja no mapa do aluno', () {
      expect(dataDaSessao(sessao().aluno), DateTime(2026, 10, 26));
      final copia = alunoNaSessao(const {'id': 'a'}, DateTime(2026, 1, 5));
      expect(copia[kDataDaSessao], '2026-01-05');
    });

    test('o PDF é gerado', () async {
      final bytes = await AvaliacaoPdf.gerar(sessao(), null);
      const destino = String.fromEnvironment('PDF_SAIDA');
      if (destino.isNotEmpty) File(destino).writeAsBytesSync(bytes);
      expect(bytes.length, greaterThan(2000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
