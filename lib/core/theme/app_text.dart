import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Duas famílias, com papéis separados.
///
/// **Archivo** carrega número, título e rótulo. É condensada o bastante para
/// um "R$ 1.799,90" caber em 390px sem encolher, e pesada o bastante para
/// criar hierarquia sem moldura.
///
/// **Manrope** carrega tudo que se lê em frase.
///
/// Se estiver em dúvida: é um valor ou um nome curto? Archivo. É uma frase?
/// Manrope.
abstract class AppText {
  // ── Archivo ───────────────────────────────────────────────

  /// Título de tela. O tracking negativo é o que segura a leitura junta
  /// em corpo grande — sem ele, 40px vira uma fileira de letras soltas.
  static TextStyle display(double size, {Color? color}) => GoogleFonts.archivo(
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: size * -0.04,
        color: color ?? AppColors.textPrimary,
      );

  /// Valores: dinheiro, peso, repetição, porcentagem.
  static TextStyle number(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.archivo(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w700,
        height: 1.15,
        letterSpacing: size * -0.025,
        color: color ?? AppColors.textPrimary,
      );

  /// Título de cartão ou de seção dentro da tela.
  static TextStyle title(double size, {Color? color}) => GoogleFonts.archivo(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.3,
        color: color ?? AppColors.textPrimary,
      );

  /// Rótulo de seção — sempre em caixa alta, sempre discreto.
  /// É o que separa blocos sem precisar de linha divisória.
  static TextStyle label({Color? color}) => GoogleFonts.archivo(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: color ?? AppColors.textMuted,
      );

  // ── Manrope ───────────────────────────────────────────────

  static TextStyle body(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: weight ?? FontWeight.w400,
        height: 1.5,
        color: color ?? AppColors.textPrimary,
      );

  static TextStyle bodyStrong(double size, {Color? color}) => GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.35,
        color: color ?? AppColors.textPrimary,
      );

  /// Texto de apoio: subtítulo de linha de lista, data, unidade.
  static TextStyle caption(double size, {Color? color}) => GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: color ?? AppColors.textSecondary,
      );
}
