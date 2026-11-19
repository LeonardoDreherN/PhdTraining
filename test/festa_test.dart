import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/modules/aluno/conquistas/festa_conquista.dart';

void main() {
  group('Festa de conquista', () {
    test('traduz códigos do banco em conquistas do catálogo', () {
      final c = conquistasDeCodigos(['treinos_1', 'checkin_1']);
      expect(c.map((x) => x.codigo), ['treinos_1', 'checkin_1']);
    });

    test('código que o catálogo não conhece é ignorado, não quebra', () {
      // Um marco criado por uma versão mais nova do app chega como
      // código desconhecido para quem está numa versão antiga. Virar
      // medalha sem nome na tela é pior do que não aparecer.
      final c = conquistasDeCodigos(['treinos_1', 'marco_do_futuro']);
      expect(c.map((x) => x.codigo), ['treinos_1']);
    });

    test('lista vazia não vira festa', () {
      expect(conquistasDeCodigos(const []), isEmpty);
    });
  });
}
