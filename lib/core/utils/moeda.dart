/// Formatação de dinheiro em reais.
///
/// Escrito à mão em vez de `intl` porque o `NumberFormat` com locale exige
/// carregar dados de locale, o que no Flutter web falha em silêncio e
/// devolve formato americano — "R$ 1,234.56" numa tela de mensalidade.
/// A regra do português é curta o bastante para não valer esse risco.
///
/// Todo valor no app trafega em CENTAVOS, como inteiro. Dinheiro em
/// `double` acumula erro de ponto flutuante, e num saldo isso vira
/// divergência de centavo que ninguém consegue explicar depois.
abstract class Moeda {
  /// `123456` → `R$ 1.234,56`
  static String formatar(int centavos, {bool comSimbolo = true}) {
    final negativo = centavos < 0;
    final abs = centavos.abs();
    final reais = abs ~/ 100;
    final resto = abs % 100;

    final buffer = StringBuffer();
    final digitos = reais.toString();
    for (var i = 0; i < digitos.length; i++) {
      if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digitos[i]);
    }

    final centavosStr = resto.toString().padLeft(2, '0');
    final sinal = negativo ? '−' : '';
    final simbolo = comSimbolo ? r'R$ ' : '';
    return '$sinal$simbolo$buffer,$centavosStr';
  }

  /// `123456` → `R$ 1.234` — para número grande de painel, onde os centavos
  /// só poluem.
  static String formatarCurto(int centavos) {
    final reais = centavos.abs() ~/ 100;
    final buffer = StringBuffer();
    final digitos = reais.toString();
    for (var i = 0; i < digitos.length; i++) {
      if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digitos[i]);
    }
    return '${centavos < 0 ? '−' : ''}R\$ $buffer';
  }
}

const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho',
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

String mesPorExtenso(DateTime d) => _meses[d.month - 1];

String saudacao([DateTime? agora]) {
  final h = (agora ?? DateTime.now()).hour;
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}
