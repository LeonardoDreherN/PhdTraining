import 'dart:math' as math;
import '../models/dieta.dart';

/// Uma linha da lista de compras.
class ItemCompra {
  const ItemCompra({required this.alimento, required this.gramas, this.deTroca = false});

  final Alimento alimento;
  final double gramas;

  /// Vem de um grupo "escolha um": o aluno compra só a opção que vai comer.
  final bool deTroca;

  /// Chave estável para lembrar o que já foi marcado no mercado.
  String get chave => '${alimento.id}${deTroca ? ':troca' : ''}';

  /// `350 g`, `1,4 kg`.
  String get pesoTexto {
    if (gramas >= 1000) {
      return '${(gramas / 1000).toStringAsFixed(1).replaceAll('.', ',')} kg';
    }
    // Arredonda para 10 g: ninguém pede 347 g no açougue.
    final g = gramas < 10 ? gramas.ceil() : (gramas / 10).ceil() * 10;
    return '$g g';
  }

  /// `≈ 14 × unidade média`, quando o alimento tem medida caseira.
  String? get medidaTexto {
    final mg = alimento.medidaGramas;
    final m = alimento.medidaCaseira?.trim();
    if (mg == null || mg <= 0 || m == null || m.isEmpty) return null;
    final n = (gramas / mg).ceil();
    return '≈ $n × $m';
  }
}

/// A lista de compras de [dias] dias do plano.
///
/// - Item fixo entra com a quantidade × dias.
/// - Grupo de troca entra com **todas** as opções, marcadas [ItemCompra.deTroca]:
///   quem decide qual comprar é o aluno, e a lista não pode escolher por ele.
/// - Receita entra pelos ingredientes, na proporção das porções prescritas.
///
/// O mesmo alimento em várias refeições vira uma linha só. A ordem é por
/// grupo da base (hortifrúti junto, carnes junto) e, dentro dele, por nome —
/// a ordem dos corredores, mais ou menos.
List<ItemCompra> listaDeCompras(PlanoAlimentar plano, {required int dias}) {
  final fixos = <String, ({Alimento a, double g})>{};
  final trocas = <String, ({Alimento a, double g})>{};

  void somar(Map<String, ({Alimento a, double g})> mapa, Alimento a, double gramas) {
    final atual = mapa[a.id];
    mapa[a.id] = (a: a, g: (atual?.g ?? 0) + gramas * dias);
  }

  for (final r in plano.refeicoes) {
    final porGrupo = <String, List<ItemRefeicao>>{};
    for (final i in r.itens) {
      final g = i.grupoSubstituicao;
      if (g == null) {
        somar(fixos, i.alimento, i.quantidadeG);
      } else {
        porGrupo.putIfAbsent(g, () => []).add(i);
      }
    }
    for (final grupo in porGrupo.values) {
      // Grupo de um item só não é escolha: compra como fixo.
      final destino = grupo.length == 1 ? fixos : trocas;
      for (final i in grupo) {
        somar(destino, i.alimento, i.quantidadeG);
      }
    }
    for (final rr in r.receitas) {
      final fator = rr.porcoes / math.max(rr.receita.rendimentoPorcoes, 0.01);
      for (final ing in rr.receita.ingredientes) {
        somar(fixos, ing.alimento, ing.quantidadeG * fator);
      }
    }
  }

  int ordem(ItemCompra a, ItemCompra b) {
    final ga = a.alimento.grupo ?? 'zzz', gb = b.alimento.grupo ?? 'zzz';
    final c = ga.compareTo(gb);
    return c != 0 ? c : a.alimento.nome.compareTo(b.alimento.nome);
  }

  return [
    ...[for (final v in fixos.values) ItemCompra(alimento: v.a, gramas: v.g)]..sort(ordem),
    ...[for (final v in trocas.values) ItemCompra(alimento: v.a, gramas: v.g, deTroca: true)]
      ..sort(ordem),
  ];
}
