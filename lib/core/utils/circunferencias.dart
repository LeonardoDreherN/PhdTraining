/// Uma circunferência que o personal pode medir.
///
/// A [chave] das que já existem nos testes de dobra e bioimpedância é o
/// nome da coluna de lá (`pesco_co`, `braco_dir`...): assim a medida que o
/// personal digitou no formulário antigo aparece na sessão sem cópia.
class Circunferencia {
  const Circunferencia(this.chave, this.nome, {this.ajuda, this.menorEhMelhor});

  final String chave;
  final String nome;
  final String? ajuda;

  /// Mesmo sentido de `LinhaComparacao.menorEhMelhor`: só cintura e
  /// abdômen têm direção certa. Braço e coxa crescendo é bom na
  /// hipertrofia e ruim no emagrecimento — depende do objetivo.
  final bool? menorEhMelhor;

  /// Cintura e quadril têm coluna própria em `avaliacoes`: os índices
  /// (RCQ, RCE, IAC) dependem delas. As outras moram no jsonb
  /// `circunferencias`.
  bool get temColuna => chave == 'cintura' || chave == 'quadril';

  static const catalogo = [
    Circunferencia('pesco_co', 'Pescoço', ajuda: 'Logo abaixo da proeminência laríngea.'),
    Circunferencia('ombro', 'Ombros', ajuda: 'Na maior circunferência, sobre os deltoides.'),
    Circunferencia('torax', 'Tórax', ajuda: 'Na linha dos mamilos, ao fim de uma expiração normal.'),
    Circunferencia('braco_dir', 'Braço direito relaxado', ajuda: 'No ponto médio entre acrômio e olécrano.'),
    Circunferencia('braco_esq', 'Braço esquerdo relaxado', ajuda: 'No ponto médio entre acrômio e olécrano.'),
    Circunferencia('braco_contraido_dir', 'Braço direito contraído',
        ajuda: 'Cotovelo a 90°, bíceps contraído, na maior circunferência.'),
    Circunferencia('braco_contraido_esq', 'Braço esquerdo contraído',
        ajuda: 'Cotovelo a 90°, bíceps contraído, na maior circunferência.'),
    Circunferencia('antebraco_dir', 'Antebraço direito', ajuda: 'Na maior circunferência, braço estendido.'),
    Circunferencia('antebraco_esq', 'Antebraço esquerdo', ajuda: 'Na maior circunferência, braço estendido.'),
    Circunferencia('cintura', 'Cintura',
        ajuda: 'No ponto médio entre a última costela e a crista ilíaca.', menorEhMelhor: true),
    Circunferencia('abdomen', 'Abdômen', ajuda: 'Na altura da cicatriz umbilical.', menorEhMelhor: true),
    Circunferencia('quadril', 'Quadril', ajuda: 'Na maior circunferência dos glúteos.'),
    Circunferencia('coxa_proximal_dir', 'Coxa proximal direita', ajuda: 'Logo abaixo da prega glútea.'),
    Circunferencia('coxa_proximal_esq', 'Coxa proximal esquerda', ajuda: 'Logo abaixo da prega glútea.'),
    Circunferencia('coxa_dir', 'Coxa medial direita', ajuda: 'No ponto médio entre a prega inguinal e a patela.'),
    Circunferencia('coxa_esq', 'Coxa medial esquerda', ajuda: 'No ponto médio entre a prega inguinal e a patela.'),
    Circunferencia('coxa_distal_dir', 'Coxa distal direita', ajuda: 'Cerca de 5 cm acima da patela.'),
    Circunferencia('coxa_distal_esq', 'Coxa distal esquerda', ajuda: 'Cerca de 5 cm acima da patela.'),
    Circunferencia('perna_dir', 'Panturrilha direita', ajuda: 'Na maior circunferência da panturrilha.'),
    Circunferencia('perna_esq', 'Panturrilha esquerda', ajuda: 'Na maior circunferência da panturrilha.'),
  ];

  /// As colunas de perimetria das tabelas de dobra e bioimpedância.
  static const colunasDosTestes = [
    'pesco_co', 'ombro', 'torax', 'braco_esq', 'braco_dir', 'cintura',
    'abdomen', 'quadril', 'coxa_esq', 'coxa_dir', 'perna_esq', 'perna_dir',
  ];

  static final _porChave = {for (final c in catalogo) c.chave: c};

  static Circunferencia? porChave(String chave) => _porChave[chave];

  /// Uma personalizada não está no catálogo: a chave é o próprio nome que
  /// o personal digitou.
  static String nomeDe(String chave) => _porChave[chave]?.nome ?? chave;

  static bool? menorEhMelhorDe(String chave) => _porChave[chave]?.menorEhMelhor;

  /// Ordem anatômica, de cima para baixo; as personalizadas vão para o fim,
  /// em ordem alfabética.
  static int comparar(String a, String b) {
    final ia = catalogo.indexWhere((c) => c.chave == a);
    final ib = catalogo.indexWhere((c) => c.chave == b);
    if (ia >= 0 && ib >= 0) return ia.compareTo(ib);
    if (ia >= 0) return -1;
    if (ib >= 0) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static List<String> ordenar(Iterable<String> chaves) => chaves.toSet().toList()..sort(comparar);

  /// Chave de uma circunferência digitada à mão. Se o nome bate com uma do
  /// catálogo ("cintura", "Pescoço"), usa a do catálogo — senão a mesma
  /// medida viraria duas linhas no gráfico.
  static String? chaveDoNome(String nome) {
    final t = nome.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return null;
    for (final c in catalogo) {
      if (c.nome.toLowerCase() == t.toLowerCase()) return c.chave;
    }
    return t[0].toUpperCase() + t.substring(1);
  }

  /// Junta as circunferências de um dia, da fonte mais fraca para a mais
  /// forte: bioimpedância, dobra, sessão (jsonb) e as colunas da sessão.
  /// É a mesma prioridade de `AvaliacaoCompleta.cintura`.
  static Map<String, double> mesclar({
    Map<String, dynamic>? bioimpedancia,
    Map<String, dynamic>? dobras,
    Map<String, double> daSessao = const {},
    double? cintura,
    double? quadril,
  }) {
    final r = <String, double>{};
    for (final teste in [bioimpedancia, dobras]) {
      if (teste == null) continue;
      for (final c in colunasDosTestes) {
        final v = (teste[c] as num?)?.toDouble();
        if (v != null && v > 0) r[c] = v;
      }
    }
    for (final e in daSessao.entries) {
      if (e.value > 0) r[e.key] = e.value;
    }
    if (cintura != null) r['cintura'] = cintura;
    if (quadril != null) r['quadril'] = quadril;
    return r;
  }

  /// O jsonb de `avaliacoes.circunferencias` em mapa tipado. Ignora o que
  /// não for número: o banco não confere o formato dos valores.
  static Map<String, double> lerJson(Object? bruto) {
    if (bruto is! Map) return const {};
    return {
      for (final e in bruto.entries)
        if (e.value is num) e.key as String: (e.value as num).toDouble(),
    };
  }
}
