import 'package:flutter/material.dart';

/// Paleta do PHD.
///
/// Os nomes no bloco "Legado" existem porque 59 arquivos já os usam. Eles
/// continuam funcionando, mas agora apontam para os tokens novos — então o
/// app inteiro adota a linguagem nova sem precisar migrar tela por tela.
/// Conforme cada tela for reescrita, troque o nome legado pelo token e, no
/// fim, o bloco desaparece.
abstract class AppColors {
  // ── Superfícies ───────────────────────────────────────────
  // Preto profundo, não preto puro: no OLED, #000 encosta em qualquer
  // borda clara e o olho vê a borda "vibrar".
  static const Color bg = Color(0xFF0A0A0B);
  static const Color surface = Color(0xFF141417);
  static const Color surfaceHigh = Color(0xFF1D1D21);

  // ── Traços ────────────────────────────────────────────────
  static const Color line = Color(0xFF27272B);
  static const Color lineStrong = Color(0xFF3A3A40);

  // ── Texto ─────────────────────────────────────────────────
  // Todos conferidos sobre `bg`: textPrimary 18:1, textSecondary 7:1,
  // textMuted 4.6:1. Abaixo disso não entra texto de leitura.
  static const Color textPrimary = Color(0xFFF4F4F5);
  static const Color textSecondary = Color(0xFF9A9AA2);
  static const Color textMuted = Color(0xFF7A7A83);

  // ── Acento ────────────────────────────────────────────────
  // Só aparece onde há decisão a tomar: ação primária, métrica que
  // importa, item selecionado. Se estiver em tudo, não destaca nada.
  static const Color accent = Color(0xFFD7FF3E);
  static const Color onAccent = Color(0xFF0A0A0B);

  // ── Estado ────────────────────────────────────────────────
  // O par é proposital: o tom cheio pinta ponto, barra e borda; o tom
  // `...Text` é o que passa contraste quando vira texto ou ícone.
  static const Color success = Color(0xFF4ADE80);
  static const Color successText = Color(0xFF7DEBA8);
  static const Color warning = Color(0xFFFBBF24);
  static const Color warningText = Color(0xFFFCD34D);
  static const Color danger = Color(0xFFF87171);
  static const Color dangerText = Color(0xFFFCA5A5);

  /// Fundo translúcido para chip de estado.
  static Color tint(Color c) => c.withValues(alpha: 0.14);

  // ── Legado ────────────────────────────────────────────────
  // `primary` era branco. Agora é o acento — é isso que faz os botões,
  // a navegação e os indicadores do app atual virarem Volt de uma vez.
  static const Color primary = accent;
  static const Color primaryDark = Color(0xFFB8DB2A);
  static const Color primaryLight = Color(0xFFE8FF7A);

  static const Color background = bg;
  static const Color surfaceVariant = surfaceHigh;
  static const Color bottomNav = bg;

  static const Color textHint = textMuted;

  static const Color active = success;
  static const Color inactive = textSecondary;
  static const Color error = danger;

  static const Color inputFill = surface;
  static const Color inputBorder = line;
  static const Color inputFocused = accent;

  static const Color divider = line;
}
