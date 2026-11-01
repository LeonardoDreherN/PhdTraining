import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/dieta.dart';
import 'package:phd_personal/core/utils/dieta_calculos.dart';

// Valores da TACO, por 100 g.
const _paoIntegral = ValoresPor100g(kcal: 253, proteina: 9.4, carboidrato: 49.9, gordura: 3.7);
const _tapioca = ValoresPor100g(kcal: 348, proteina: 0.1, carboidrato: 63.6, gordura: 10.9);
const _frango = ValoresPor100g(kcal: 159, proteina: 32, carboidrato: 0, gordura: 2.5);
const _ovo = ValoresPor100g(kcal: 146, proteina: 13.3, carboidrato: 0.6, gordura: 9.5);
const _acucar = ValoresPor100g(kcal: 387, proteina: 0.3, carboidrato: 99.5, gordura: 0);
const _azeite = ValoresPor100g(kcal: 884, proteina: 0, carboidrato: 0, gordura: 100);

ItemRefeicao _item(String id, int ordem, {String? grupo, String? nome}) => ItemRefeicao(
      id: id,
      refeicaoId: 'r',
      alimento: Alimento(id: 'a$id', nome: 'Alimento $id'),
      quantidadeG: 50,
      grupoSubstituicao: grupo,
      nomeExibicao: nome,
      ordem: ordem,
    );

void main() {
  group('Equivalência de substitutos', () {
    test('mesmo carboidrato de 50 g de pão integral', () {
      final g = gramasEquivalentes(
        principal: _paoIntegral,
        gramasPrincipal: 50,
        substituto: _tapioca,
        base: BaseEquivalencia.carboidrato,
      )!;
      expect(g * _tapioca.carboidrato / 100, closeTo(50 * _paoIntegral.carboidrato / 100, 1e-9));
      expect(g, closeTo(39.2, 0.1));
    });

    test('mesmas calorias', () {
      final g = gramasEquivalentes(
        principal: _frango,
        gramasPrincipal: 100,
        substituto: _ovo,
        base: BaseEquivalencia.energia,
      )!;
      expect(g, closeTo(108.9, 0.1));
    });

    test('sem o nutriente não há equivalência', () {
      expect(
        gramasEquivalentes(
          principal: _ovo,
          gramasPrincipal: 50,
          substituto: _azeite,
          base: BaseEquivalencia.proteina,
        ),
        isNull,
      );
    });

    test('a base padrão é o macro que domina as calorias', () {
      expect(BaseEquivalencia.padraoPara(_paoIntegral), BaseEquivalencia.carboidrato);
      expect(BaseEquivalencia.padraoPara(_frango), BaseEquivalencia.proteina);
      expect(BaseEquivalencia.padraoPara(_azeite), BaseEquivalencia.gordura);
      expect(BaseEquivalencia.padraoPara(_acucar), BaseEquivalencia.carboidrato);
      // Ovo: ~59% das calorias da gordura, mas ~36% da proteína.
      expect(BaseEquivalencia.padraoPara(_ovo), BaseEquivalencia.proteina);
      expect(BaseEquivalencia.padraoPara(const ValoresPor100g(kcal: 0, proteina: 0, carboidrato: 0, gordura: 0)),
          BaseEquivalencia.energia);
    });
  });

  group('Blocos da refeição', () {
    test('substitutos juntam no principal, mesmo separados na lista', () {
      final r = Refeicao(id: 'r', planoId: 'p', nome: 'Café', itens: [
        _item('pao', 0, grupo: 'g1'),
        _item('cafe', 1),
        _item('tapioca', 2, grupo: 'g1'),
        _item('aveia', 3, grupo: 'g1'),
      ]);
      final b = r.blocos;
      expect(b.length, 2);
      expect(b[0].principal.id, 'pao');
      expect(b[0].substitutos.map((i) => i.id), ['tapioca', 'aveia']);
      expect(b[1].principal.id, 'cafe');
      expect(b[1].temSubstitutos, isFalse);
      expect(r.blocoDe(r.itens[2])!.principal.id, 'pao');
    });

    test('o total conta só o principal do grupo', () {
      const r = Refeicao(id: 'r', planoId: 'p', nome: 'Café', itens: [
        ItemRefeicao(id: '1', refeicaoId: 'r', quantidadeG: 50, grupoSubstituicao: 'g',
            alimento: Alimento(id: 'p', nome: 'Pão', kcal: 253)),
        ItemRefeicao(id: '2', refeicaoId: 'r', quantidadeG: 40, grupoSubstituicao: 'g',
            alimento: Alimento(id: 't', nome: 'Tapioca', kcal: 348)),
      ]);
      expect(r.total.kcal, closeTo(126.5, 0.01));
    });

    test('nome para o aluno', () {
      expect(_item('1', 0, nome: 'Ovo cozido, grelhado ou mexido').nome, 'Ovo cozido, grelhado ou mexido');
      expect(_item('1', 0, nome: '  ').nome, 'Alimento 1');
      expect(_item('1', 0).renomeado, isFalse);
    });
  });
}
