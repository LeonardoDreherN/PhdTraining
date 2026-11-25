import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/feed.dart';

Map<String, dynamic> linha({
  String tipo = 'aviso',
  String? lidaEm,
  Map<String, dynamic>? origem,
  Map<String, dynamic>? post,
}) =>
    {
      'id': 'a1',
      'tipo': tipo,
      'criado_em': '2026-11-20T10:00:00Z',
      'lida_em': lidaEm,
      'post_id': 'p1',
      'origem': origem,
      'feed_posts': post,
    };

void main() {
  group('Aviso do feed', () {
    test('o texto da conquista sai do catálogo, não do banco', () {
      // A linha guarda só o código. A frase é montada na leitura, como
      // o cartão do feed — assim renomear a medalha não deixa avisos
      // antigos com o nome velho.
      final a = AvisoFeed.doMapa(
          linha(tipo: 'conquista', post: {'conquista_codigo': 'treinos_50'}));
      expect(a.texto, contains('50 treinos'));
    });

    test('código desconhecido não quebra o aviso', () {
      final a = AvisoFeed.doMapa(
          linha(tipo: 'conquista', post: {'conquista_codigo': 'xyz'}));
      expect(a.texto, 'Uma conquista sua foi publicada na comunidade.');
    });

    test('interação diz quem foi, pelo primeiro nome', () {
      final a = AvisoFeed.doMapa(
          linha(tipo: 'comentario', origem: {'nome': 'Ana Paula Silva'}));
      expect(a.texto, 'Ana comentou na sua publicação.');
    });

    test('interação sem nome não vira "null comentou"', () {
      final a = AvisoFeed.doMapa(linha(tipo: 'reacao'));
      expect(a.texto, 'Alguém reagiu à sua publicação.');
    });

    test('não lida enquanto não há data de leitura', () {
      expect(AvisoFeed.doMapa(linha()).naoLida, isTrue);
      expect(
        AvisoFeed.doMapa(linha(lidaEm: '2026-11-21T08:00:00Z')).naoLida,
        isFalse,
      );
    });

    test('cada tipo tem ícone próprio', () {
      final icones = {
        for (final t in ['conquista', 'destaque', 'reacao', 'comentario', 'aviso'])
          t: AvisoFeed.doMapa(linha(tipo: t)).icone,
      };
      expect(icones.values.toSet().length, 5);
    });
  });
}
