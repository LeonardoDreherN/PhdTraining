/// Tipo MIME a partir do nome do arquivo.
///
/// Existe porque três serviços montavam o tipo concatenando a extensão:
/// `'image/$ext'` e `'video/$ext'`. Para `.png` e `.mp4` dá certo por
/// coincidência; para `.jpg` vira `image/jpg` e para `.mov` vira `video/mov`
/// — nenhum dos dois existe. O Storage recusava com 415 e o personal via
/// "erro ao fazer upload" sem saber por quê, justamente nos dois formatos
/// mais comuns de celular.
abstract class Midia {
  static const _porExtensao = <String, String>{
    // Imagem
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    // Padrão de foto do iPhone desde 2017. Sem ele, metade dos usuários
    // não consegue enviar foto nenhuma.
    'heic': 'image/heic',
    'heif': 'image/heif',

    // Vídeo
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'm4v': 'video/x-m4v',
    'webm': 'video/webm',
    '3gp': 'video/3gpp',
  };

  /// Extensão em minúsculas, sem ponto. Vazio se não houver.
  static String extensaoDe(String nomeArquivo) {
    final i = nomeArquivo.lastIndexOf('.');
    if (i < 0 || i == nomeArquivo.length - 1) return '';
    return nomeArquivo.substring(i + 1).toLowerCase();
  }

  /// `null` quando o formato não é reconhecido — nesse caso vale barrar antes
  /// de subir o arquivo, em vez de esperar o 415 depois de enviar 100 MB.
  static String? tipoDe(String nomeArquivo) =>
      _porExtensao[extensaoDe(nomeArquivo)];

  static bool ehVideo(String nomeArquivo) =>
      tipoDe(nomeArquivo)?.startsWith('video/') ?? false;

  static bool ehImagem(String nomeArquivo) =>
      tipoDe(nomeArquivo)?.startsWith('image/') ?? false;

  /// Mensagem para quem escolheu um formato que não dá para enviar.
  static String recusa(String nomeArquivo, {required bool video}) {
    final ext = extensaoDe(nomeArquivo);
    final aceitos = video ? 'MP4, MOV, WEBM ou 3GP' : 'JPG, PNG, WEBP ou HEIC';
    return ext.isEmpty
        ? 'Esse arquivo não tem extensão. Envie $aceitos.'
        : 'Arquivos .$ext não são suportados. Envie $aceitos.';
  }
}
