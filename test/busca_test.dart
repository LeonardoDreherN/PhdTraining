import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/utils/busca.dart';

void main() {
  group('Busca de alimentos', () {
    test('tira acento, pontuação e caixa — como o banco', () {
      expect(normalizarBusca('Pão, trigo, francês'), 'pao trigo frances');
      expect(normalizarBusca('  Maçã,  Fuji (com casca) '), 'maca fuji com casca');
      expect(normalizarBusca('Açaí'), 'acai');
    });

    test('quebra em palavras', () {
      expect(palavrasDaBusca('Pão   francês'), ['pao', 'frances']);
      expect(palavrasDaBusca(' , '), isEmpty);
    });

    test('as palavras de "pao frances" estão no nome da TACO', () {
      final nome = normalizarBusca('Pão, trigo, francês');
      expect(palavrasDaBusca('pão francês').every(nome.contains), isTrue);
    });
  });
}
