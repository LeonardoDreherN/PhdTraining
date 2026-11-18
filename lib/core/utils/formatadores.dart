import 'package:flutter/services.dart';

/// Máscara de data enquanto se digita: `15061999` vira `15/06/1999`.
///
/// Digitar as barras à mão é erro garantido num cadastro feito no celular,
/// de pé, com o aluno esperando. Aqui a pessoa digita só os números e as
/// barras aparecem sozinhas.
///
/// Apagar também funciona: o cursor atravessa a barra junto com o dígito,
/// em vez de parar nela e exigir dois toques.
class MascaraData extends TextInputFormatter {
  const MascaraData();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue antigo,
    TextEditingValue novo,
  ) {
    final digitos = novo.text.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return const TextEditingValue();

    final limitado = digitos.length > 8 ? digitos.substring(0, 8) : digitos;

    final b = StringBuffer();
    for (var i = 0; i < limitado.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(limitado[i]);
    }
    final texto = b.toString();

    return TextEditingValue(
      text: texto,
      // Cursor sempre no fim: o campo é curto e sempre preenchido da
      // esquerda para a direita, então reposicionar no meio só atrapalha.
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}

/// Lê uma data digitada em `dd/mm/aaaa` ou `ddmmaaaa` e devolve no formato
/// do banco (`aaaa-mm-dd`).
///
/// Devolve `null` quando a data não existe — 31 de fevereiro, mês 13, ano
/// de três dígitos. Antes disto, a função que fazia esse trabalho exigia
/// as barras e devolvia `null` em silêncio para quem digitava só os
/// números: a data de nascimento do aluno não era salva, e nada avisava.
String? dataParaBanco(String texto) {
  final d = texto.replaceAll(RegExp(r'\D'), '');
  if (d.length != 8) return null;

  final dia = int.tryParse(d.substring(0, 2));
  final mes = int.tryParse(d.substring(2, 4));
  final ano = int.tryParse(d.substring(4, 8));
  if (dia == null || mes == null || ano == null) return null;
  if (mes < 1 || mes > 12 || dia < 1) return null;
  if (ano < 1900 || ano > DateTime.now().year) return null;

  // `DateTime` aceita 31/02 e rola para março. Comparar de volta é o que
  // pega a data que não existe.
  final data = DateTime(ano, mes, dia);
  if (data.day != dia || data.month != mes || data.year != ano) return null;

  return '${ano.toString().padLeft(4, '0')}-'
      '${mes.toString().padLeft(2, '0')}-'
      '${dia.toString().padLeft(2, '0')}';
}

/// O inverso: `1999-06-15` vira `15/06/1999`, para preencher o campo.
String dataParaTela(String? iso) {
  if (iso == null || iso.length < 10) return '';
  final p = iso.substring(0, 10).split('-');
  if (p.length != 3) return '';
  return '${p[2]}/${p[1]}/${p[0]}';
}
