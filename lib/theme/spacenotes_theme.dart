import 'package:flutter/material.dart';

class SpaceNotesTheme {
  static const Color bg = Color(0xFF0D0D0F);
  static const Color bgAlt = Color(0xFF131315);
  static const Color card = Color(0xFF101013);
  static const Color fg = Color(0xFFECECEC);
  static const Color muted = Color(0xFF9A9A9A);
  static const Color dim = Color(0xFF5A5A5A);
  static const Color hairline = Color(0xFF1A1A1D);
  static const Color hairlineStrong = Color(0xFF26262B);
  static const Color accent = Color(0xFF7DD3FC);
  static const Color accent2 = Color(0xFFC4A4F7);
  static const Color offline = Color(0xFFE8766E);

  static const Color background = bg;
  static const Color surface = card;
  static const Color inputSurface = bgAlt;
  static const Color dialogSurface = card;
  static const Color primary = accent;
  static const Color primaryMuted = Color(0xFF4A8FAE);
  static const Color secondary = accent2;
  static const Color text = fg;
  static const Color textSecondary = muted;
  static const Color error = offline;
  static const Color warning = Color(0xFFE0B37A);
  static const Color success = accent;

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space12 = 48;
  static const double space18 = 72;

  static const double radiusNone = 0;
  static const double radiusXs = 2;
  static const double radiusSm = 4;
  static const double radiusDock = 6;

  static const String fontSans = 'Geist';
  static const String fontMono = 'JetBrainsMono';

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontSans,
      colorScheme: const ColorScheme.dark(
        surface: card,
        primary: accent,
        secondary: accent2,
        onSurface: fg,
        onPrimary: bg,
        onSecondary: bg,
        error: offline,
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        centerTitle: false,
      ),
      dividerTheme: const DividerThemeData(
        color: hairline,
        thickness: 1,
        space: 1,
      ),
      textTheme: SpaceNotesTextStyles.textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXs),
          borderSide: const BorderSide(color: hairlineStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXs),
          borderSide: const BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXs),
          borderSide: const BorderSide(color: accent),
        ),
        hintStyle: const TextStyle(color: dim),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusSm)),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontSans,
          fontSize: 16,
          color: fg,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontSans,
          fontSize: 14,
          color: fg,
          height: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusXs),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: hairline, width: 1),
        ),
      ),
    );
  }
}

class SpaceNotesType {
  static const TextStyle display = TextStyle(
    fontFamily: SpaceNotesTheme.fontSans,
    fontSize: 38,
    fontWeight: FontWeight.w500,
    letterSpacing: -1.2,
    height: 1.0,
    color: SpaceNotesTheme.fg,
  );

  static const TextStyle h1 = TextStyle(
    fontFamily: SpaceNotesTheme.fontSans,
    fontSize: 28,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.6,
    height: 1.15,
    color: SpaceNotesTheme.fg,
  );

  static const TextStyle prose = TextStyle(
    fontFamily: SpaceNotesTheme.fontSans,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.7,
    color: SpaceNotesTheme.muted,
  );

  static const TextStyle proseBody = TextStyle(
    fontFamily: SpaceNotesTheme.fontSans,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.7,
    color: SpaceNotesTheme.fg,
  );

  static const TextStyle ui = TextStyle(
    fontFamily: SpaceNotesTheme.fontMono,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.3,
    color: SpaceNotesTheme.fg,
  );

  static const TextStyle micro = TextStyle(
    fontFamily: SpaceNotesTheme.fontMono,
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.5,
    color: SpaceNotesTheme.muted,
  );
}

class SpaceNotesTextStyles {
  static const String _fontFamily = SpaceNotesTheme.fontMono;
  static const String _sansFamily = SpaceNotesTheme.fontSans;

  static const TextStyle terminal = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: SpaceNotesTheme.fg,
    height: 1.4,
  );

  static const TextStyle prompt = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    color: SpaceNotesTheme.accent,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle code = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    color: SpaceNotesTheme.fg,
    backgroundColor: SpaceNotesTheme.bgAlt,
  );

  static const TextStyle userMessage = TextStyle(
    fontFamily: _sansFamily,
    fontSize: 15,
    color: SpaceNotesTheme.fg,
    height: 1.55,
  );

  static const TextStyle assistantMessage = TextStyle(
    fontFamily: _sansFamily,
    fontSize: 15,
    color: SpaceNotesTheme.fg,
    height: 1.55,
  );

  static const TextStyle toolExecution = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    color: SpaceNotesTheme.muted,
    letterSpacing: 0.3,
    height: 1.4,
  );

  static const TextStyle connectionStatus = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    color: SpaceNotesTheme.muted,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.5,
  );

  static TextTheme get textTheme {
    return const TextTheme(
      displayLarge: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 38,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.2,
        height: 1.0,
      ),
      displayMedium: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 32,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.0,
        height: 1.05,
      ),
      displaySmall: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 28,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.6,
        height: 1.15,
      ),
      headlineLarge: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 24,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 20,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 17,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      titleLarge: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 16,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 14,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      bodyLarge: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 17,
        color: SpaceNotesTheme.fg,
        height: 1.7,
      ),
      bodyMedium: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 15,
        color: SpaceNotesTheme.fg,
        height: 1.55,
      ),
      bodySmall: TextStyle(
        fontFamily: _sansFamily,
        fontSize: 13,
        color: SpaceNotesTheme.muted,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        color: SpaceNotesTheme.fg,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      labelMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        color: SpaceNotesTheme.muted,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        color: SpaceNotesTheme.muted,
        fontWeight: FontWeight.w400,
        letterSpacing: 1.5,
      ),
    );
  }
}

class SpaceNotesSymbols {
  static const String prompt = '›';
  static const String pipe = '|';
  static const String cancel = '^C';
  static const String loading = '.....';
  static const String connected = '●';
  static const String disconnected = '○';
  static const String reconnecting = '◐';
}
