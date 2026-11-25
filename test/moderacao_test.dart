import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/feed.dart';

Map<String, dynamic> linha({
  String? postId = 'p1',
  String? comentarioId,
  Map<String, dynamic>? post,
  Map<String, dynamic>? comentario,
  String? resolucao,
  String? resolvidaEm,
  String? motivo,
}) =>
    {
      'id': 'd1',
      'criado_em': '2026-11-20T10:00:00Z',
      'post_id': postId,
      'comentario_id': comentarioId,
      'motivo': motivo,
      'resolucao': resolucao,
      'resolvida_em': resolvidaEm,
      'feed_posts': post,
      'feed_comentarios': comentario,
    };

void main() {
  group('Denúncia', () {
    test('denúncia de publicação lê o texto do post', () {
      final d = DenunciaFeed.doMapa(linha(post: {
        'id': 'p1',
        'texto': 'conteúdo ruim',
        'oculto': false,
        'aluno_id': 'a1',
        'alunos': {'nome': 'Ana Silva'},
      }));
      expect(d.ehComentario, isFalse);
      expect(d.texto, 'conteúdo ruim');
      expect(d.alunoId, 'a1');
      expect(d.autorConteudo, 'Ana Silva');
    });

    test('denúncia de comentário lê o texto do comentário, não do post', () {
      final d = DenunciaFeed.doMapa(linha(
        postId: null,
        comentarioId: 'c1',
        post: {'id': 'p1', 'texto': 'o post está ok'},
        comentario: {
          'id': 'c1',
          'texto': 'o comentário é o problema',
          'oculto': false,
          'autor': {'nome': 'Bruno'},
        },
      ));
      expect(d.ehComentario, isTrue);
      expect(d.texto, 'o comentário é o problema');
      expect(d.autorConteudo, 'Bruno');
    });

    test('conteúdo apagado depois da denúncia é detectado', () {
      // A linha sobrevive ao conteúdo quando alguém apaga antes de o
      // profissional olhar. Sem esta leitura, a tela mostraria um
      // retângulo vazio e ninguém entenderia o que julgar.
      final d = DenunciaFeed.doMapa(linha(post: null));
      expect(d.conteudoSumiu, isTrue);
    });

    test('post só com imagem não conta como conteúdo sumido', () {
      final d = DenunciaFeed.doMapa(linha(post: {
        'id': 'p1',
        'texto': null,
        'midia_url': 'https://exemplo/foto.jpg',
      }));
      expect(d.conteudoSumiu, isFalse);
    });

    test('pendente enquanto não há data de resolução', () {
      expect(DenunciaFeed.doMapa(linha(post: {'texto': 'x'})).pendente, isTrue);

      final resolvida = DenunciaFeed.doMapa(linha(
        post: {'texto': 'x'},
        resolucao: 'arquivada',
        resolvidaEm: '2026-11-21T09:00:00Z',
      ));
      expect(resolvida.pendente, isFalse);
      expect(resolvida.resolucaoRotulo, 'Arquivada');
    });

    test('cada desfecho tem rótulo', () {
      for (final r in ['arquivada', 'ocultada', 'removida']) {
        final d = DenunciaFeed.doMapa(linha(
          post: {'texto': 'x'},
          resolucao: r,
          resolvidaEm: '2026-11-21T09:00:00Z',
        ));
        expect(d.resolucaoRotulo, isNot('Pendente'), reason: r);
      }
    });
  });
}
