import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- Figma Design System Color Palette ---

  // Basic Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color white2 = Color(0xFFF8F8FF);
  static const Color black = Color(0xFF141414);

  // Charcoal Palette (Neutrals)
  static const Color charcoal50 = Color(0xFFF5F5F7);
  static const Color charcoal100 = Color(0xFFE5E5E8);
  static const Color charcoal200 = Color(0xFFC2C2C6);
  static const Color charcoal300 = Color(0xFFA0A0A2);
  static const Color charcoal400 = Color(0xFF7D7D80);
  static const Color charcoal500 = Color(0xFF5C5C5E);
  static const Color charcoal600 = Color(0xFF404041);
  static const Color charcoal700 = Color(0xFF292929);
  static const Color charcoal800 = Color(0xFF1A1A1A);
  static const Color charcoal900 = Color(0xFF141414);

  // Ocean Palette (Primary Accents)
  static const Color ocean50 = Color(0xFFF0F6FF);
  static const Color ocean100 = Color(0xFFC4DBFF);
  static const Color ocean200 = Color(0xFF98C0FF);
  static const Color ocean300 = Color(0xFF669DF2); // Hero Accent ⭐
  static const Color ocean400 = Color(0xFF5286D5);
  static const Color ocean500 = Color(0xFF4170B8);
  static const Color ocean600 = Color(0xFF315B9B);
  static const Color ocean700 = Color(0xFF24477D);
  static const Color ocean800 = Color(0xFF183560);
  static const Color ocean900 = Color(0xFF0F2343);

  // Semantic Colors
  static const Color green = Color(0xFF2CC75C); // Success ⭐
  static const Color coral50 = Color(0xFFFFEFEF);
  static const Color coral = Color(0xFFFF6464); // Error / Delete ⭐
  static const Color coral600 = Color(0xFF992929);
  static const Color orange = Color(0xFFBA6B27); // Warning ⭐
  static const Color teal = Color(0xFF3BC9BC); // Accent 2 ⭐
  static const Color yellow = Color(0xFFFFDC49); // Highlight ⭐

  // --- Semantic Color Mappings for App ---
  static const Color darkBackground = charcoal900;
  static const Color darkSurface = charcoal800;
  static const Color darkCard = charcoal700;

  static const Color lightBackground = charcoal50;
  static const Color lightSurface = white;
  static const Color lightCard = charcoal50;

  // Accents matching old variables for compilation safety
  static const Color primaryOcean = ocean300;
  static const Color secondaryTeal = teal;
  static const Color accentGreen = green;
  static const Color deleteRed = coral;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      fontFamily: GoogleFonts.nunito().fontFamily,
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(
        primary: primaryOcean,
        secondary: secondaryTeal,
        surface: darkSurface,
        onSurface: Colors.white,
        error: deleteRed,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1.5,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryOcean, width: 2),
        ),
        labelStyle: GoogleFonts.nunito(color: Colors.white70),
        hintStyle: GoogleFonts.nunito(color: Colors.white38),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryOcean,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      fontFamily: GoogleFonts.nunito().fontFamily,
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.light().textTheme),
      colorScheme: const ColorScheme.light(
        primary: ocean500, // ocean500 is better for contrast on white bg
        secondary: secondaryTeal,
        surface: lightSurface,
        onSurface: charcoal900,
        error: deleteRed,
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.black.withValues(alpha: 0.04),
            width: 1.5,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: lightBackground,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: charcoal900,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: ocean500, width: 2),
        ),
        labelStyle: GoogleFonts.nunito(color: charcoal600),
        hintStyle: GoogleFonts.nunito(color: charcoal300),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ocean500,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
