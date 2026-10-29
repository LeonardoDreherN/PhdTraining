/// Link `wa.me` a partir do número como foi cadastrado.
///
/// O `wa.me` só aceita dígitos com DDI. Número brasileiro cadastrado sem o
/// 55 (o normal no formulário) ganha o 55 aqui. Devolve `null` quando o
/// número não dá para discar — aí a tela esconde o botão em vez de abrir um
/// WhatsApp que não acha ninguém.
Uri? linkWhatsApp(String? numero, {String? mensagem}) {
  final digitos = numero?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digitos.length < 10) return null;
  final completo = digitos.length <= 11 ? '55$digitos' : digitos;
  return Uri.https('wa.me', '/$completo', {
    if (mensagem != null && mensagem.isNotEmpty) 'text': mensagem,
  });
}
