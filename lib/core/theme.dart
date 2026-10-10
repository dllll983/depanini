import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Charte DÉPANINI : jaune/noir = dépannage, rouge/bleu marine = ambulance.
class Brand {
  static const yellow = Color(0xFFFFC400);
  static const black = Color(0xFF111214);
  static const red = Color(0xFFE3172C);
  static const redDark = Color(0xFFB5101F);
  static const navy = Color(0xFF0E2147);
  static const green = Color(0xFF1FA855);
  static const greenDark = Color(0xFF137A3C);
  static const grey = Color(0xFFF4F5F7);
  static const line = Color(0xFFE4E6EA);
  static const muted = Color(0xFF5A5E66);
}

enum ServiceAxis { depannage, ambulance }

extension ServiceAxisX on ServiceAxis {
  Color get primary => this == ServiceAxis.depannage ? Brand.yellow : Brand.red;
  Color get onPrimary => this == ServiceAxis.depannage ? Brand.black : Colors.white;
  Color get dark => this == ServiceAxis.depannage ? Brand.black : Brand.navy;
  String get label => this == ServiceAxis.depannage ? 'Dépannage' : 'Ambulance';
}

ThemeData buildTheme(ServiceAxis axis) {
  final scheme = ColorScheme.fromSeed(seedColor: axis.primary).copyWith(
    primary: axis.primary,
    onPrimary: axis.onPrimary,
    secondary: axis.dark,
    onSecondary: Colors.white,
    surface: Colors.white,
  );
  final text = GoogleFonts.poppinsTextTheme().apply(bodyColor: axis.dark, displayColor: axis.dark);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: Brand.grey,
    appBarTheme: AppBarTheme(
      backgroundColor: axis.dark,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: axis.primary,
        foregroundColor: axis.onPrimary,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: axis.dark,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: Brand.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Brand.line)),
    ),
  );
}

/// Carte blanche arrondie utilisée partout.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final BoxBorder? border;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = Colors.white, this.border});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), border: border),
        child: child,
      );
}

/// Logotype « DÉPANINI » (le A en couleur).
class BrandLogo extends StatelessWidget {
  final double size;
  final Color color;
  final Color accent;
  final String? suffix;
  const BrandLogo({super.key, this.size = 24, this.color = Colors.white, this.accent = Brand.yellow, this.suffix});

  @override
  Widget build(BuildContext context) {
    final style = GoogleFonts.poppins(fontSize: size, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: color);
    return Text.rich(TextSpan(style: style, children: [
      const TextSpan(text: 'DÉP'),
      TextSpan(text: 'A', style: TextStyle(color: accent)),
      const TextSpan(text: 'NINI'),
      if (suffix != null) TextSpan(text: ' $suffix', style: TextStyle(color: accent)),
    ]));
  }
}
