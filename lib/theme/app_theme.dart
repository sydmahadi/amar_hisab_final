import 'package:flutter/material.dart';

class AppTheme {
  // =========================
  // Main Colors
  // =========================

  static const Color green = Color(0xFF176B45);
  static const Color darkGreen = Color(0xFF0F5132);
  static const Color greenLight = Color(0xFF23845A);
  static const Color greenSoft = Color(0xFF2D8A63);

  static const Color gold = Color(0xFFB99550);
  static const Color goldLight = Color(0xFFD8BB78);
  static const Color goldSoft = Color(0xFFA98343);

  // Transaction colors
  static const Color incomeColor = Color(0xFF4F9A72);
  static const Color expenseColor = Color(0xFFC56B68);
  static const Color transferColor = Color(0xFFB99550);

  // =========================
  // Light Theme
  // =========================

  static const Color lightBackground = Color(0xFFF4F1E9);
  static const Color lightSurface = Color(0xFFFAF9F5);
  static const Color lightCard = Color(0xFFFFFEFB);

  static const Color lightText = Color(0xFF18221D);
  static const Color secondaryTextLight = Color(0xFF6C756F);

  // =========================
  // Dark Theme
  // =========================

  static const Color darkBackground = Color(0xFF08120F);
  static const Color darkSurface = Color(0xFF0D1915);
  static const Color darkCard = Color(0xFF12221B);
  static const Color darkCard2 = Color(0xFF182C23);

  static const Color darkText = Color(0xFFF1EEE6);
  static const Color secondaryTextDark = Color(0xFFAEB9B3);

  // =========================
  // Light Theme
  // =========================

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.light,
    ).copyWith(
      primary: green,
      onPrimary: Colors.white,
      secondary: gold,
      onSecondary: Colors.white,
      surface: lightSurface,
      onSurface: lightText,
      surfaceContainerHighest: const Color(0xFFE9E5DC),
      onSurfaceVariant: secondaryTextLight,
      error: const Color(0xFFC56B68),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      scaffoldBackgroundColor: lightBackground,

      colorScheme: colorScheme,

      canvasColor: lightBackground,

      cardColor: lightCard,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(20),
          ),
        ),
      ),

      iconTheme: const IconThemeData(
        color: lightText,
        size: 22,
      ),

      dividerTheme: DividerThemeData(
        color: lightText.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.70),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: lightText.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: lightText.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: green,
            width: 1.4,
          ),
        ),
        hintStyle: const TextStyle(
          color: secondaryTextLight,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: green,
          side: BorderSide(
            color: green.withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(
            lightText,
          ),
          overlayColor: WidgetStatePropertyAll(
            green.withValues(alpha: 0.08),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),

      floatingActionButtonTheme:
          const FloatingActionButtonThemeData(
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 7,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkGreen,
        contentTextStyle: const TextStyle(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: lightSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  // =========================
  // Dark Theme
  // =========================

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: Brightness.dark,
    ).copyWith(
      primary: greenLight,
      onPrimary: Colors.white,
      secondary: goldLight,
      onSecondary: darkBackground,
      surface: darkSurface,
      onSurface: darkText,
      surfaceContainerHighest: darkCard2,
      onSurfaceVariant: secondaryTextDark,
      error: const Color(0xFFC56B68),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: darkBackground,

      colorScheme: colorScheme,

      canvasColor: darkBackground,

      cardColor: darkCard,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(20),
          ),
        ),
      ),

      iconTheme: const IconThemeData(
        color: darkText,
        size: 22,
      ),

      dividerTheme: DividerThemeData(
        color: darkText.withValues(alpha: 0.08),
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: darkText.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: darkText.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: greenLight,
            width: 1.4,
          ),
        ),
        hintStyle: const TextStyle(
          color: secondaryTextDark,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldLight,
          side: BorderSide(
            color: goldLight.withValues(alpha: 0.35),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 13,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: goldLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(
            darkText,
          ),
          overlayColor: WidgetStatePropertyAll(
            greenLight.withValues(alpha: 0.10),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),

      floatingActionButtonTheme:
          const FloatingActionButtonThemeData(
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 7,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkCard2,
        contentTextStyle: const TextStyle(
          color: darkText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
