import 'package:material_ui/material_ui.dart';

/// "Hallmark" Furrow theme: warm paper, ink rules, one tangerine accent,
/// Red Hat fonts. Colours are the web app's OKLCH tokens converted to sRGB.
class Furrow {
  static const error = Color(0xFFBE2323);
  static const errorSoft = Color(0xFFFFDEDA);
  static const paper = Color(0xFFF5F1EA);
  static const paper2 = Color(0xFFFFFDFA);
  static const paper3 = Color(0xFFE9E4D9);
  static const ink = Color(0xFF14110F);
  static const ink2 = Color(0xFF2C2825);
  static const muted = Color(0xFF58514C);
  static const rule = Color(0xFFDBD7CE);
  static const accent = Color(0xFFFC6B33);
  static const accentSoft = Color(0xFFFED8C4);
  static const green = Color(0xFF246E3A);
  static const greenSoft = Color(0xFFD3EDD7);
  static const contour = Color(0xFFA67C5C);
  static const water = Color(0xFF628699);
  static const hedge = Color(0xFF337344);
  static const grid = Color(0xFFE2DDD4);
  static const gridStrong = Color(0xFFD3CDC1);
  static const sheet = Color(0xFFFEFDFA);

  static const radiusCard = 10.0;
  static const radiusEntry = 14.0;
  static const radiusPill = 6.0;

  static TextStyle display(double size, {Color color = ink}) => TextStyle(
    fontFamily: 'RedHatDisplay',
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.035 * size,
    height: 1.05,
    color: color,
  );
  static TextStyle mono(double size, {Color color = ink, FontWeight weight = FontWeight.w400}) => TextStyle(
    fontFamily: 'RedHatMono',
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static TextStyle body(double size, {Color color = ink, FontWeight weight = FontWeight.w400}) =>
      TextStyle(fontFamily: 'RedHatText', fontSize: size, fontWeight: weight, color: color, height: 1.45);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: ink,
        secondary: green,
        surface: paper2,
        onSurface: ink,
        error: error,
        outline: rule,
      ),
      scaffoldBackgroundColor: paper,
      fontFamily: 'RedHatText',
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink, fontFamily: 'RedHatText'),
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: display(19),
        shape: const Border(bottom: BorderSide(color: ink, width: 1)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: accent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(body(11.5, weight: FontWeight.w500)),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: paper,
        indicatorColor: accent,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        selectedLabelTextStyle: body(13, weight: FontWeight.w500),
        unselectedLabelTextStyle: body(13, color: ink2, weight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper2,
        labelStyle: body(13, color: muted, weight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: const BorderSide(color: muted),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: const BorderSide(color: muted),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: ink,
          disabledBackgroundColor: accent.withValues(alpha: 0.4),
          minimumSize: const Size(0, 44),
          textStyle: body(15, weight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: paper2,
          foregroundColor: ink,
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: rule),
          textStyle: body(15, weight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: body(14, color: paper2),
      ),
      dividerTheme: const DividerThemeData(color: rule, thickness: 1, space: 1),
    );
  }
}
