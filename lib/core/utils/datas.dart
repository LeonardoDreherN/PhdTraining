/// Datas em português, sem `intl`.
///
/// Mesma razão de `Moeda`: o `DateFormat` com locale precisa carregar dados
/// de locale, e no Flutter web isso falha em silêncio e devolve "Oct".
abstract class Datas {
  static const _meses = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  static String _dd(int n) => n.toString().padLeft(2, '0');

  /// `26/10/2026`
  static String curta(DateTime d) => '${_dd(d.day)}/${_dd(d.month)}/${d.year}';

  /// `26 out 2026`
  static String longa(DateTime d) => '${d.day} ${_meses[d.month - 1]} ${d.year}';

  /// `out 2026` — eixo de gráfico, cabeçalho de comparação.
  static String mesAno(DateTime d) => '${_meses[d.month - 1]} ${d.year}';

  /// `2026-10-26`, o formato das colunas `date` do Postgres.
  static String iso(DateTime d) => '${d.year}-${_dd(d.month)}-${_dd(d.day)}';

  static DateTime? ler(Object? v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  /// Só o dia, sem hora: é o que permite comparar "mesma data" com `==`.
  static DateTime dia(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Idade completa em [em]. `null` quando não há nascimento.
  static int? idade(DateTime? nascimento, [DateTime? em]) {
    if (nascimento == null) return null;
    final ref = em ?? DateTime.now();
    var anos = ref.year - nascimento.year;
    if (ref.month < nascimento.month ||
        (ref.month == nascimento.month && ref.day < nascimento.day)) {
      anos--;
    }
    return anos;
  }
}
