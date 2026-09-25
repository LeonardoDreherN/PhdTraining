import 'package:flutter/widgets.dart';

/// Espaçamento em escala de 4. Se um valor não está aqui, ou o layout
/// precisa de outra coisa, ou o valor está errado.
abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;

  /// Respiro lateral padrão das telas.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: xl);
}

/// Dois raios fazem quase tudo: `md` para controle, `xl` para cartão.
/// A escala completa existe para os casos de borda, não para variar à toa.
abstract class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;
  static const double pill = 999;

  static BorderRadius get rSm => BorderRadius.circular(sm);
  static BorderRadius get rMd => BorderRadius.circular(md);
  static BorderRadius get rLg => BorderRadius.circular(lg);
  static BorderRadius get rXl => BorderRadius.circular(xl);
  static BorderRadius get rXxl => BorderRadius.circular(xxl);
  static BorderRadius get rPill => BorderRadius.circular(pill);
}

abstract class AppDuration {
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
}

/// Altura mínima de alvo de toque. Abaixo de 44 o dedo erra.
const double kMinTouch = 44;
