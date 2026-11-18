import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/utils/formatadores.dart';

/// Aplica a máscara como o campo aplicaria, partindo do vazio.
String digitar(String teclas) {
  const m = MascaraData();
  var v = const TextEditingValue();
  for (final t in teclas.split('')) {
    final texto = v.text + t;
    v = m.formatEditUpdate(
      v,
      TextEditingValue(
        text: texto,
        selection: TextSelection.collapsed(offset: texto.length),
      ),
    );
  }
  return v.text;
}

void main() {
  group('Máscara de data', () {
    test('põe as barras sozinha', () {
      expect(digitar('15061999'), '15/06/1999');
    });

    test('parcial não inventa barra antes da hora', () {
      expect(digitar('1'), '1');
      expect(digitar('15'), '15');
      expect(digitar('150'), '15/0');
      expect(digitar('1506'), '15/06');
      expect(digitar('15061'), '15/06/1');
    });

    test('ignora o que não é dígito', () {
      expect(digitar('15a06b1999'), '15/06/1999');
    });

    test('não passa de oito dígitos', () {
      expect(digitar('150619991234'), '15/06/1999');
    });

    test('quem digita com barra chega no mesmo lugar', () {
      expect(digitar('15/06/1999'), '15/06/1999');
    });

    test('apagar tudo volta ao vazio', () {
      const m = MascaraData();
      final v = m.formatEditUpdate(
        const TextEditingValue(text: '15/06/1999'),
        const TextEditingValue(text: ''),
      );
      expect(v.text, '');
    });
  });

  group('Data para o banco', () {
    test('com barras', () {
      expect(dataParaBanco('15/06/1999'), '1999-06-15');
    });

    test('sem barras — era o caso que se perdia em silêncio', () {
      // A versão antiga exigia as barras e devolvia null sem avisar: a
      // data de nascimento do aluno simplesmente não era salva.
      expect(dataParaBanco('15061999'), '1999-06-15');
    });

    test('completa com zero à esquerda', () {
      expect(dataParaBanco('01/02/2000'), '2000-02-01');
    });

    test('incompleta não vale', () {
      expect(dataParaBanco('1506'), isNull);
      expect(dataParaBanco(''), isNull);
      expect(dataParaBanco('15/06/99'), isNull);
    });

    test('data que não existe não vale', () {
      // `DateTime(1999, 2, 31)` rolaria para 3 de março sem reclamar.
      expect(dataParaBanco('31/02/1999'), isNull);
      expect(dataParaBanco('32/01/1999'), isNull);
      expect(dataParaBanco('15/13/1999'), isNull);
    });

    test('29 de fevereiro só em ano bissexto', () {
      expect(dataParaBanco('29/02/2000'), '2000-02-29');
      expect(dataParaBanco('29/02/1999'), isNull);
    });

    test('ano fora da faixa plausível não vale', () {
      expect(dataParaBanco('15/06/1899'), isNull);
      expect(dataParaBanco('15/06/2999'), isNull);
    });
  });

  group('Data para a tela', () {
    test('inverte o formato do banco', () {
      expect(dataParaTela('1999-06-15'), '15/06/1999');
    });

    test('aceita timestamp e usa só o dia', () {
      expect(dataParaTela('1999-06-15T03:00:00Z'), '15/06/1999');
    });

    test('nulo ou curto vira vazio', () {
      expect(dataParaTela(null), '');
      expect(dataParaTela('1999'), '');
    });

    test('ida e volta não muda a data', () {
      expect(dataParaBanco(dataParaTela('1999-06-15')), '1999-06-15');
    });
  });
}
