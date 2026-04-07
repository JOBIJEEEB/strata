import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2BB673);
  static const Color primaryDark = Color(0xFF1E8A55);
  static const Color primaryLight = Color(0xFF5DCB97);

  // Light Mode Colors
  static const Color backgroundLight = Color(0xFFF2FAF5); // Very light subtle green tint
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color onBackgroundLight = Color(0xFF0F1A14);
  static const Color onSurfaceLight = Color(0xFF18261E);
  static const Color dividerLight = Color(0xFFCEE5D8);

  // Dark Mode Colors
  static const Color backgroundDark = Color(0xFF000000); // True Black
  static const Color surfaceDark = Color(0xFF111412); // Deep elevated contrast
  static const Color cardDark = Color(0xFF161A18);
  static const Color onBackgroundDark = Color(0xFFFFFFFF);
  static const Color onSurfaceDark = Color(0xFFF0F0F0);
  static const Color dividerDark = Color(0xFF202A24);

  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFFFFB4AB);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        colorScheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          secondary: Color(0xFF4D7A62),
          onSecondary: AppColors.onPrimary,
          surface: AppColors.surfaceLight,
          onSurface: AppColors.onSurfaceLight,
          error: AppColors.errorLight,
          onError: AppColors.onPrimary,
          outline: Color(0xFF6F8F7C),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundLight,
          foregroundColor: AppColors.onBackgroundLight,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(color: AppColors.onBackgroundLight, fontSize: 22, fontWeight: FontWeight.w600),
          iconTheme: IconThemeData(color: AppColors.onBackgroundLight),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceLight,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Color(0xFF6F8F7C),
          elevation: 16,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surfaceLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.dividerLight),
          ),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.dividerLight, thickness: 1),
        textTheme: _buildTextTheme(AppColors.onBackgroundLight),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.primary,
          onPrimary: Color(0xFF003823),
          secondary: Color(0xFFB4CCBC),
          onSecondary: Color(0xFF20382C),
          surface: AppColors.surfaceDark,
          onSurface: AppColors.onSurfaceDark,
          error: AppColors.errorDark,
          onError: Color(0xFF690005),
          outline: Color(0xFF4A5C52),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.backgroundDark,
          foregroundColor: AppColors.onBackgroundDark,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(color: AppColors.onBackgroundDark, fontSize: 22, fontWeight: FontWeight.w600),
          iconTheme: IconThemeData(color: AppColors.onBackgroundDark),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDark,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Color(0xFF688273),
          elevation: 16,
          type: BottomNavigationBarType.fixed,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.dividerDark),
          ),
        ),
        dividerTheme: const DividerThemeData(color: AppColors.dividerDark, thickness: 1),
        textTheme: _buildTextTheme(AppColors.onBackgroundDark),
      );

  static TextTheme _buildTextTheme(Color baseColor) {
    return GoogleFonts.poppinsTextTheme(
      TextTheme(
        headlineLarge: TextStyle(color: baseColor, fontSize: 32, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(color: baseColor, fontSize: 28, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: baseColor, fontSize: 24, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: baseColor, fontSize: 22, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: baseColor, fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: baseColor, fontSize: 14, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: baseColor, fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(color: baseColor, fontSize: 14, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(color: baseColor, fontSize: 12, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(color: baseColor, fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: baseColor, fontSize: 12, fontWeight: FontWeight.w500),
        labelSmall: TextStyle(color: baseColor, fontSize: 11, fontWeight: FontWeight.w500),
      )
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(20),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.65),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: card);
    }
    return card;
  }
}
