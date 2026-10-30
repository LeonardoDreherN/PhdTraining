import 'package:flutter/material.dart';

/// Os valores de uma paleta. Existem duas — [AppColors.escuro] e
/// [AppColors.claro] — com os mesmos papéis; muda o valor, nunca o nome.
class PhdPalette {
  const PhdPalette({
    required this.brilho,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.line,
    required this.lineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.onAccent,
    required this.energy,
    required this.success,
    required this.successText,
    required this.warning,
    required this.warningText,
    required this.danger,
    required this.dangerText,
  });

  final Brightness brilho;
  final Color bg, surface, surfaceHigh;
  final Color line, lineStrong;
  final Color textPrimary, textSecondary, textMuted;
  final Color accent, accentLight, accentDark, onAccent;
  final Color energy;
  final Color success, successText;
  final Color warning, warningText;
  final Color danger, dangerText;
}

/// Paleta do PHD: vermelho da marca no que pede ação, neutros no resto,
/// laranja nos alertas.
///
/// Laranja, e não vermelho, para alerta: com a marca vermelha, "mensalidade
/// atrasada" pintada da mesma cor de "Começar treino" deixaria de parecer
/// aviso — e o botão passaria a parecer erro.
///
/// As cores são lidas da paleta ativa, que o app troca em [usar] conforme o
/// tema (claro, escuro ou o do celular). Por isso são getters e não `const`:
/// um `const` congelaria a cor do tema em que o arquivo foi compilado.
///
/// Os nomes no bloco "Legado" existem porque dezenas de arquivos já os
/// usam. Eles apontam para os tokens novos — então o app inteiro adota a
/// linguagem nova sem precisar migrar tela por tela.
abstract class AppColors {
  // ── Escuro ────────────────────────────────────────────────
  // Preto profundo, não preto puro: no OLED, #000 encosta em qualquer
  // borda clara e o olho vê a borda "vibrar". Texto conferido sobre `bg`:
  // primário 18:1, secundário 7:1, apagado 4.6:1.
  static const escuro = PhdPalette(
    brilho: Brightness.dark,
    bg: Color(0xFF0A0A0B),
    surface: Color(0xFF141417),
    surfaceHigh: Color(0xFF1D1D21),
    line: Color(0xFF27272B),
    lineStrong: Color(0xFF3A3A40),
    textPrimary: Color(0xFFF4F4F5),
    textSecondary: Color(0xFF9A9AA2),
    textMuted: Color(0xFF7A7A83),
    // Branco sobre #DC2626 passa 4.8:1; um vermelho mais vivo ficaria
    // abaixo de 4.5 e o texto dos botões perderia leitura.
    accent: Color(0xFFDC2626),
    accentLight: Color(0xFFEF4444),
    accentDark: Color(0xFFB91C1C),
    onAccent: Color(0xFFFFFFFF),
    energy: Color(0xFFEF4444),
    success: Color(0xFF4ADE80),
    successText: Color(0xFF7DEBA8),
    warning: Color(0xFFFBBF24),
    warningText: Color(0xFFFCD34D),
    danger: Color(0xFFFB923C),
    dangerText: Color(0xFFFDBA74),
  );

  // ── Claro ─────────────────────────────────────────────────
  // Fundo cinza-gelo e cartão branco: a separação vem do contraste entre
  // os dois e de uma sombra curta, sem moldura. Os tons `...Text` descem
  // para passar contraste sobre branco.
  static const claro = PhdPalette(
    brilho: Brightness.light,
    bg: Color(0xFFF3F4F7),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEDEFF3),
    line: Color(0xFFE2E5EB),
    lineStrong: Color(0xFFCBD0D9),
    textPrimary: Color(0xFF0D0F14),
    textSecondary: Color(0xFF545B6B),
    textMuted: Color(0xFF6B7282),
    accent: Color(0xFFDC2626),
    accentLight: Color(0xFFEF4444),
    accentDark: Color(0xFFB91C1C),
    onAccent: Color(0xFFFFFFFF),
    energy: Color(0xFFDC2626),
    success: Color(0xFF16A34A),
    successText: Color(0xFF15803D),
    warning: Color(0xFFF59E0B),
    warningText: Color(0xFFB45309),
    danger: Color(0xFFEA580C),
    dangerText: Color(0xFFC2410C),
  );

  static PhdPalette _p = escuro;

  /// Troca a paleta. Só o app chama isto, antes de montar o tema — e
  /// remonta a árvore inteira em seguida, porque cada tela leu as cores
  /// da paleta anterior.
  static void usar(Brightness brilho) =>
      _p = brilho == Brightness.light ? claro : escuro;

  static Brightness get brilho => _p.brilho;
  static bool get ehClaro => _p.brilho == Brightness.light;

  // ── Superfícies ───────────────────────────────────────────
  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceHigh => _p.surfaceHigh;

  // ── Traços ────────────────────────────────────────────────
  static Color get line => _p.line;
  static Color get lineStrong => _p.lineStrong;

  // ── Texto ─────────────────────────────────────────────────
  static Color get textPrimary => _p.textPrimary;
  static Color get textSecondary => _p.textSecondary;
  static Color get textMuted => _p.textMuted;

  // ── Acento ────────────────────────────────────────────────
  // Vermelho da marca. Só aparece onde há decisão a tomar: ação primária, métrica que
  // importa, item selecionado. Se estiver em tudo, não destaca nada.
  static Color get accent => _p.accent;
  static Color get onAccent => _p.onAccent;

  /// Energia: sequência, recorde, o "hoje". É o vermelho da marca —
  /// pontual, para não competir com os botões.
  static Color get energy => _p.energy;

  // ── Estado ────────────────────────────────────────────────
  // O par é proposital: o tom cheio pinta ponto, barra e borda; o tom
  // `...Text` é o que passa contraste quando vira texto ou ícone.
  static Color get success => _p.success;
  static Color get successText => _p.successText;
  static Color get warning => _p.warning;
  static Color get warningText => _p.warningText;
  static Color get danger => _p.danger;
  static Color get dangerText => _p.dangerText;

  /// Fundo translúcido para chip de estado.
  static Color tint(Color c) => c.withValues(alpha: ehClaro ? 0.12 : 0.14);

  // ── Legado ────────────────────────────────────────────────
  static Color get primary => accent;
  static Color get primaryDark => _p.accentDark;
  static Color get primaryLight => _p.accentLight;

  static Color get background => bg;
  static Color get surfaceVariant => surfaceHigh;
  static Color get bottomNav => bg;

  static Color get textHint => textMuted;

  static Color get active => success;
  static Color get inactive => textSecondary;
  static Color get error => danger;

  static Color get inputFill => surface;
  static Color get inputBorder => line;
  static Color get inputFocused => accent;

  static Color get divider => line;
}
