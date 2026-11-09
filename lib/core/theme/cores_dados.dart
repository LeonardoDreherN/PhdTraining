import 'package:flutter/material.dart';

/// Cores de dado — categorias, não estados.
///
/// O vermelho da marca é ação (botão, aba ativa, "hoje") e o laranja é
/// alerta. Macro, água e gráfico não são nenhum dos dois: com vermelho, uma
/// barra de proteína quase cheia parecia problema. Tons médios, que leem
/// sobre o fundo escuro e o claro.
class CoresDados {
  // Azul fixo, não a cor da marca: proteína em vermelho ficaria colada na
  // gordura (rosa) e no botão.
  static const proteina = Color(0xFF3B82F6);
  static const carboidrato = Color(0xFFF59E0B);
  static const gordura = Color(0xFFEC4899);
  static const agua = Color(0xFF38BDF8);
  static const energia = Color(0xFF22C55E);
}
