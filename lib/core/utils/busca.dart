/// Texto de busca: minúsculo, sem acento, sem pontuação.
///
/// É a mesma conta de `alimento_nome_busca` no banco (migração 0020). As
/// duas precisam bater: o app normaliza o que a pessoa digitou e compara
/// com a coluna `nome_busca`, que o banco normalizou do nome.
String normalizarBusca(String texto) {
  final semAcento = texto.toLowerCase().split('').map((c) => _acentos[c] ?? c).join();
  return semAcento.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// As palavras de uma busca, já normalizadas. "Pão francês" → [pao, frances].
List<String> palavrasDaBusca(String texto) =>
    normalizarBusca(texto).split(' ').where((p) => p.isNotEmpty).toList();

const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};
