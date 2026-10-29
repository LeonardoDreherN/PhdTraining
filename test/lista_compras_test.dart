import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:phd_personal/core/models/dieta.dart';
import 'package:phd_personal/core/utils/lista_compras.dart';
import 'package:phd_personal/modules/personal/dieta/plano_pdf.dart';

Alimento _a(String id, {String grupo = 'Cereais', double? medida, String? caseira}) => Alimento(
      id: id,
      nome: id,
      grupo: grupo,
      oficial: true,
      fonte: 'teste',
      kcal: 100,
      proteina: 1,
      carboidrato: 1,
      gordura: 1,
      medidaGramas: medida,
      medidaCaseira: caseira,
    );

ItemRefeicao _i(String id, Alimento a, double g, {String? grupo}) => ItemRefeicao(
      id: id,
      refeicaoId: 'r',
      alimento: a,
      quantidadeG: g,
      grupoSubstituicao: grupo,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final arroz = _a('arroz');
  final batata = _a('batata', grupo: 'Hortaliças');
  final ovo = _a('ovo', grupo: 'Ovos', medida: 50, caseira: 'unidade');
  final banana = _a('banana', grupo: 'Frutas', medida: 80, caseira: 'unidade média');

  test('mesmo alimento em refeições diferentes vira uma linha, vezes os dias', () {
    final plano = PlanoAlimentar(id: 'p', alunoId: 'a', nome: 'P', refeicoes: [
      Refeicao(id: 'r1', planoId: 'p', nome: 'Café', itens: [_i('1', ovo, 100)]),
      Refeicao(id: 'r2', planoId: 'p', nome: 'Jantar', itens: [_i('2', ovo, 50)]),
    ]);
    final lista = listaDeCompras(plano, dias: 7);
    expect(lista, hasLength(1));
    expect(lista.single.gramas, 1050);
    expect(lista.single.pesoTexto, '1,1 kg');
    expect(lista.single.medidaTexto, '≈ 21 × unidade');
  });

  test('grupo de troca entra com todas as opções, marcadas', () {
    final plano = PlanoAlimentar(id: 'p', alunoId: 'a', nome: 'P', refeicoes: [
      Refeicao(id: 'r1', planoId: 'p', nome: 'Almoço', itens: [
        _i('1', arroz, 120, grupo: 'g'),
        _i('2', batata, 150, grupo: 'g'),
        _i('3', ovo, 100),
      ]),
    ]);
    final lista = listaDeCompras(plano, dias: 1);
    expect(lista.where((i) => !i.deTroca).map((i) => i.alimento.id), ['ovo']);
    expect(lista.where((i) => i.deTroca).map((i) => i.alimento.id), containsAll(['arroz', 'batata']));
  });

  test('grupo com um item só é comprado como fixo', () {
    final plano = PlanoAlimentar(id: 'p', alunoId: 'a', nome: 'P', refeicoes: [
      Refeicao(id: 'r1', planoId: 'p', nome: 'Almoço', itens: [_i('1', arroz, 120, grupo: 'g')]),
    ]);
    expect(listaDeCompras(plano, dias: 1).single.deTroca, isFalse);
  });

  test('receita entra pelos ingredientes, na proporção das porções', () {
    final receita = Receita(id: 'rc', nome: 'Panqueca', rendimentoPorcoes: 2, ingredientes: [
      IngredienteReceita(alimento: banana, quantidadeG: 160),
      IngredienteReceita(alimento: ovo, quantidadeG: 100),
    ]);
    final plano = PlanoAlimentar(id: 'p', alunoId: 'a', nome: 'P', refeicoes: [
      Refeicao(id: 'r1', planoId: 'p', nome: 'Café', receitas: [
        ReceitaNaRefeicao(id: 'x', refeicaoId: 'r1', receita: receita, porcoes: 1),
      ]),
    ]);
    final lista = listaDeCompras(plano, dias: 7);
    // Uma porção = metade da receita, por 7 dias.
    expect(lista.firstWhere((i) => i.alimento.id == 'banana').gramas, 560);
    expect(lista.firstWhere((i) => i.alimento.id == 'ovo').gramas, 350);
  });

  test('receita conta no total da refeição', () {
    final receita = Receita(id: 'rc', nome: 'R', rendimentoPorcoes: 2, ingredientes: [
      IngredienteReceita(alimento: arroz, quantidadeG: 200),
    ]);
    final r = Refeicao(id: 'r1', planoId: 'p', nome: 'Café', itens: [_i('1', ovo, 100)], receitas: [
      ReceitaNaRefeicao(id: 'x', refeicaoId: 'r1', receita: receita, porcoes: 1.5),
    ]);
    // ovo 100 g = 100 kcal; receita: 200 kcal / 2 porções × 1,5 = 150 kcal.
    expect(r.total.kcal, closeTo(250, 0.01));
    expect(r.vazia, isFalse);
  });

  test('o PDF do plano é gerado, com trocas e receita', () async {
    final receita = Receita(id: 'rc', nome: 'Panqueca de banana', rendimentoPorcoes: 2, tempoMinutos: 15,
        modoPreparo: 'Amasse a banana e misture com os ovos.', ingredientes: [
      IngredienteReceita(alimento: banana, quantidadeG: 160),
      IngredienteReceita(alimento: ovo, quantidadeG: 100),
    ]);
    final plano = PlanoAlimentar(
      id: 'p', alunoId: 'a', nome: 'Recomposição', metaKcal: 1850, metaProteina: 140,
      metaCarboidrato: 190, metaGordura: 55, aguaMl: 2500, observacoes: 'Beba água ao longo do dia.',
      refeicoes: [
        Refeicao(id: 'r1', planoId: 'p', nome: 'Café da manhã', horario: '07:00:00', receitas: [
          ReceitaNaRefeicao(id: 'x', refeicaoId: 'r1', receita: receita),
        ]),
        Refeicao(id: 'r2', planoId: 'p', nome: 'Almoço', horario: '12:30:00', itens: [
          _i('1', arroz, 120, grupo: 'g'),
          _i('2', batata, 150, grupo: 'g'),
          _i('3', ovo, 100),
        ]),
      ],
    );
    final bytes = await PlanoPdf.gerar(plano, alunoNome: 'Marina Costa');
    const destino = String.fromEnvironment('PDF_SAIDA');
    if (destino.isNotEmpty) File(destino).writeAsBytesSync(bytes);
    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
