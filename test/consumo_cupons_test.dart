import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/cupom.dart';
import 'package:phd_personal/core/models/dieta.dart';

const _pao = Alimento(id: 'pao', nome: 'Pão', kcal: 253, proteina: 9.4, carboidrato: 49.9, gordura: 3.7);
const _tapioca = Alimento(id: 'tap', nome: 'Tapioca', kcal: 348, proteina: 0.1, carboidrato: 63.6, gordura: 10.9);
const _ovo = Alimento(id: 'ovo', nome: 'Ovo', kcal: 146, proteina: 13.3, carboidrato: 0.6, gordura: 9.5);

const _cafe = Refeicao(id: 'r', planoId: 'p', nome: 'Café', itens: [
  ItemRefeicao(id: 'i1', refeicaoId: 'r', alimento: _pao, quantidadeG: 50, grupoSubstituicao: 'g', ordem: 0),
  ItemRefeicao(id: 'i2', refeicaoId: 'r', alimento: _tapioca, quantidadeG: 40, grupoSubstituicao: 'g', ordem: 1),
  ItemRefeicao(id: 'i3', refeicaoId: 'r', alimento: _ovo, quantidadeG: 100, nomeExibicao: 'Ovo cozido ou mexido', ordem: 2),
]);

void main() {
  group('O que o aluno comeu', () {
    test('o ponto de partida é o plano: só o principal de cada grupo', () {
      final itens = _cafe.comoPrescrito;
      expect(itens.map((i) => i.alimentoId), ['pao', 'ovo']);
      expect(itens.every((i) => i.origem == OrigemConsumo.plano), isTrue);
      expect(itens[1].nome, 'Ovo cozido ou mexido');
      expect(somarConsumo(itens).kcal, closeTo(_cafe.total.kcal, 1e-9));
    });

    test('sem registro, o consumido é o plano; com registro, é o registro', () {
      expect(_cafe.consumido(null).kcal, closeTo(_cafe.total.kcal, 1e-9));
      const soPlano = RegistroRefeicao(refeicaoId: 'r', feita: true);
      expect(_cafe.consumido(soPlano).kcal, closeTo(_cafe.total.kcal, 1e-9));

      final comeu = RegistroRefeicao(refeicaoId: 'r', feita: true, itens: [
        ItemConsumido.deAlimento(_tapioca, 40, origem: OrigemConsumo.troca, itemPlanoId: 'i1'),
      ]);
      expect(_cafe.consumido(comeu).kcal, closeTo(348 * 0.4, 1e-9));
    });

    test('mudar a quantidade do que o plano pediu vira ajuste', () {
      final c = ItemConsumido.doItem(_cafe.itens.first).comGramas(70);
      expect(c.gramas, 70);
      expect(c.origem, OrigemConsumo.troca);
      expect(c.itemPlanoId, 'i1');
    });

    test('vai e volta do banco com os nutrientes copiados', () {
      final c = ItemConsumido.deAlimento(_ovo, 100, nome: 'Ovo mexido', itemPlanoId: 'i3');
      final volta = RegistroRefeicao.doMapa({
        'refeicao_id': 'r',
        'feita': true,
        'itens': [c.paraMapa()],
      });
      final i = volta.itens!.single;
      expect(i.nome, 'Ovo mexido');
      expect(i.origem, OrigemConsumo.extra);
      expect(i.nutrientes.proteina, closeTo(13.3, 1e-9));
      expect(volta.alterada, isTrue);
    });

    test('itens nulo no banco é "comeu o plano"', () {
      final r = RegistroRefeicao.doMapa({'refeicao_id': 'r', 'feita': true, 'itens': null});
      expect(r.alterada, isFalse);
    });
  });

  group('Cupons e bio', () {
    test('o cupom grava sem espaços sobrando e com a data no formato do banco', () {
      final m = Cupom(
        titulo: '  10% na loja ',
        codigo: ' PHD10 ',
        descricao: '   ',
        validoAte: DateTime(2026, 12, 5),
      ).paraMapa();
      expect(m['titulo'], '10% na loja');
      expect(m['codigo'], 'PHD10');
      expect(m['descricao'], isNull);
      expect(m['valido_ate'], '2026-12-05');
    });

    test('vencido é só o que passou de hoje', () {
      final hoje = DateTime.now();
      expect(Cupom(titulo: 'x', validoAte: DateTime(hoje.year, hoje.month, hoje.day)).vencido, isFalse);
      expect(Cupom(titulo: 'x', validoAte: hoje.subtract(const Duration(days: 1))).vencido, isTrue);
      expect(const Cupom(titulo: 'x').vencido, isFalse);
    });

    test('formações ignoram o que não é texto', () {
      expect(lerFormacoes(['Pós em Nutrição Esportiva', '  ', 3, null]), ['Pós em Nutrição Esportiva']);
      expect(lerFormacoes(null), isEmpty);
    });

    test('registros do profissional', () {
      expect(const PerfilPublico(id: 'p', cref: '034340-G/SC', crn: '12345').registros,
          'CREF 034340-G/SC · CRN 12345');
      expect(const PerfilPublico(id: 'p').registros, isNull);
    });
  });
}
