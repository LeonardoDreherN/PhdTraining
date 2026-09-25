import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text.dart';
import 'app_tokens.dart';

abstract class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.accent,
      splashFactory: InkSparkle.splashFactory,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        secondary: AppColors.surfaceHigh,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceHigh,
        outline: AppColors.line,
        error: AppColors.danger,
        onError: AppColors.onAccent,
      ),

      // Material só aceita uma família por TextTheme, então aqui vai a de
      // leitura. Número e título pedem Archivo explicitamente, via AppText.
      textTheme: TextTheme(
        displayLarge: AppText.display(40),
        displayMedium: AppText.display(32),
        displaySmall: AppText.display(26),
        headlineLarge: AppText.title(24),
        headlineMedium: AppText.title(20),
        headlineSmall: AppText.title(18),
        titleLarge: AppText.title(17),
        titleMedium: AppText.bodyStrong(15),
        titleSmall: AppText.caption(13),
        bodyLarge: AppText.body(15),
        bodyMedium: AppText.body(14),
        bodySmall: AppText.caption(12),
        labelLarge: AppText.bodyStrong(14),
        labelMedium: AppText.caption(12),
        labelSmall: AppText.label(),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.xl,
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
        titleTextStyle: AppText.title(20),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          disabledBackgroundColor: AppColors.surfaceHigh,
          disabledForegroundColor: AppColors.textMuted,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
          textStyle: AppText.bodyStrong(14.5),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.lineStrong),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.rLg),
          textStyle: AppText.bodyStrong(14.5),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size(0, kMinTouch),
          textStyle: AppText.bodyStrong(13.5),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(kMinTouch, kMinTouch),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: _border(AppColors.line),
        enabledBorder: _border(AppColors.line),
        focusedBorder: _border(AppColors.accent, width: 1.5),
        errorBorder: _border(AppColors.danger),
        focusedErrorBorder: _border(AppColors.danger, width: 1.5),
        labelStyle: AppText.caption(13),
        floatingLabelStyle: AppText.caption(12, color: AppColors.accent),
        hintStyle: AppText.body(14.5, color: AppColors.textMuted),
        errorStyle: AppText.caption(12, color: AppColors.dangerText),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.bg,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: AppText.bodyStrong(10.5),
        unselectedLabelStyle: AppText.caption(10.5),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accent,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.line,
        labelStyle: AppText.bodyStrong(14.5),
        unselectedLabelStyle: AppText.body(14.5, weight: FontWeight.w500),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceHigh,
        side: BorderSide.none,
        labelStyle: AppText.bodyStrong(12.5),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rPill),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.onAccent : AppColors.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : AppColors.surfaceHigh),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : Colors.transparent),
        checkColor: const WidgetStatePropertyAll(AppColors.onAccent),
        side: const BorderSide(color: AppColors.lineStrong, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : AppColors.lineStrong),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.surfaceHigh,
        circularTrackColor: AppColors.surfaceHigh,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: AppText.body(13.5),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.lineStrong,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rXxl),
        titleTextStyle: AppText.title(18),
        contentTextStyle: AppText.body(14),
      ),

      listTileTheme: ListTileThemeData(
        titleTextStyle: AppText.bodyStrong(14.5),
        subtitleTextStyle: AppText.caption(12),
        iconColor: AppColors.textSecondary,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rXl),
      ),
    );
  }

  static OutlineInputBorder _border(Color c, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.rMd,
        borderSide: BorderSide(color: c, width: width),
      );
}
