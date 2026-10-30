import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ui/theme/colors.dart';

/// Tema global "Obsidian Kinetic" (docs/designer.md §3, §5, §6, §7 y §14).
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.dark(
    surface: kSurface,
    surfaceContainerLowest: kSurfaceContainerLowest,
    surfaceContainerLow: kSurfaceContainerLow,
    surfaceContainer: kSurfaceContainer,
    surfaceContainerHigh: kSurfaceContainerHigh,
    surfaceContainerHighest: kSurfaceContainerHighest,
    onSurface: kOnSurface,
    onSurfaceVariant: kOnSurfaceVariant,
    primary: kPrimary,
    onPrimary: kOnPrimary,
    secondary: kSecondary,
    outline: kOutline,
    outlineVariant: kOutlineVariant,
    error: kError,
    errorContainer: kErrorContainer,
    onErrorContainer: kOnErrorContainer,
    tertiaryContainer: kTertiaryContainer,
    onTertiaryContainer: kOnTertiaryContainer,
  );

  const textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 44,
      fontWeight: FontWeight.w600,
      height: 48 / 44,
      letterSpacing: -0.04 * 44,
      color: kOnSurface,
    ),
    headlineLarge: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 32,
      fontWeight: FontWeight.w600,
      height: 38 / 32,
      letterSpacing: -0.03 * 32,
      color: kOnSurface,
    ),
    headlineMedium: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 26,
      fontWeight: FontWeight.w600,
      height: 32 / 26,
      letterSpacing: -0.02 * 26,
      color: kOnSurface,
    ),
    headlineSmall: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 20,
      fontWeight: FontWeight.w500,
      height: 26 / 20,
      letterSpacing: -0.02 * 20,
      color: kOnSurface,
    ),
    titleLarge: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 36,
      fontWeight: FontWeight.w700,
      height: 40 / 36,
      letterSpacing: -0.03 * 36,
      color: kOnSurface,
    ),
    titleMedium: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 22,
      fontWeight: FontWeight.w600,
      height: 26 / 22,
      letterSpacing: -0.02 * 22,
      color: kOnSurface,
    ),
    titleSmall: TextStyle(
      fontFamily: 'Geist',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
      letterSpacing: -0.01 * 16,
      color: kOnSurface,
    ),
    bodyLarge: TextStyle(
      fontFamily: 'Geist',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 24 / 16,
      letterSpacing: -0.01 * 16,
      color: kOnSurface,
    ),
    bodyMedium: TextStyle(
      fontFamily: 'Geist',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
      letterSpacing: -0.005 * 14,
      color: kOnSurface,
    ),
    bodySmall: TextStyle(
      fontFamily: 'Geist',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 16 / 12,
      letterSpacing: 0.04 * 12,
      color: kOnSurface,
    ),
    labelLarge: TextStyle(
      fontFamily: 'Geist',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 16 / 12,
      letterSpacing: 0.04 * 12,
      color: kOnSurface,
    ),
    labelMedium: TextStyle(
      fontFamily: 'Geist',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      height: 14 / 11,
      letterSpacing: 0.06 * 11,
      color: kOnSurface,
    ),
    labelSmall: TextStyle(
      fontFamily: 'Geist',
      fontSize: 10,
      fontWeight: FontWeight.w400,
      height: 14 / 10,
      letterSpacing: 0.02 * 10,
      color: kOnSurface,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: kSurface,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: kSurfaceContainerHigh,
    focusColor: kSurfaceContainerHigh,
    iconTheme: const IconThemeData(color: kOnSurfaceVariant, size: 20),
    dividerColor: kOutlineVariant,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: kOnSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 64,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: IconThemeData(color: kOnSurface, size: 20),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        foregroundColor: kOnPrimary,
        disabledBackgroundColor: kSurfaceContainerHigh,
        disabledForegroundColor: kOutline,
        elevation: 0,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontFamily: 'Geist',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.01 * 16,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kOnSurfaceVariant,
        minimumSize: const Size(64, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceContainerHighest,
      hintStyle: textTheme.bodyMedium?.copyWith(color: kOnSurfaceVariant),
      labelStyle: textTheme.bodyMedium?.copyWith(color: kOnSurfaceVariant),
      floatingLabelStyle:
          textTheme.bodyMedium?.copyWith(color: kOnSurface),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: kOnSurface),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: kSurfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Geist',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: kOnSurface,
      ),
    ),
    extensions: const [HevyColors.dark],
  );
}

/// Colores semánticos sin equivalente en `ColorScheme` (designer.md §2.4).
/// Uso: `Theme.of(context).extension<HevyColors>()!.oliveAccent`.
@immutable
class HevyColors extends ThemeExtension<HevyColors> {
  const HevyColors({
    required this.oliveAccent,
    required this.surfaceBright,
  });

  final Color oliveAccent;
  final Color surfaceBright;

  static const dark = HevyColors(
    oliveAccent: kOliveAccent,
    surfaceBright: kSurfaceBright,
  );

  @override
  HevyColors copyWith({Color? oliveAccent, Color? surfaceBright}) {
    return HevyColors(
      oliveAccent: oliveAccent ?? this.oliveAccent,
      surfaceBright: surfaceBright ?? this.surfaceBright,
    );
  }

  @override
  HevyColors lerp(HevyColors? other, double t) {
    if (other is! HevyColors) return this;
    return HevyColors(
      oliveAccent: Color.lerp(oliveAccent, other.oliveAccent, t)!,
      surfaceBright: Color.lerp(surfaceBright, other.surfaceBright, t)!,
    );
  }
}
