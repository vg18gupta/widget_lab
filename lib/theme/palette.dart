import 'package:flutter/material.dart';

/// Every colour the app uses. Change the look here, not in the widgets.
/// Light studio: off-white surfaces, indigo accent.
abstract final class Palette {
  // Surfaces, from the page background up to the panel body.
  static const background = Color(0xffF6F7FB); // page
  static const canvas = Color(0xffEBEEF5); // grid area behind the panels
  static const surface = Color(0xffFFFFFF); // panel body, hub
  static const header = Color(0xffF1F3F9); // panel header
  static const tile = Color(0xffF1F3F9); // hub tiles
  static const cardTint = Color(0xffEEF2FF); // stat tile
  static const console = Color(0xffF3F4F6); // script console

  // Lines.
  static const border = Color(0xffD5DBE7);
  static const gridLine = Color(0xffDDE2EC);

  // Accent (indigo) and its tints.
  static const accent = Color(0xff4F46E5);
  static const accentStrong = Color(0xcc4F46E5); // drop-shadow outline
  static const accentSoft = Color(0x1F4F46E5); // selected row, drop shadow fill
  static const accentFill = Color(0x264F46E5); // area under the chart line

  // Text.
  static const textPrimary = Color(0xff111827);
  static const textSecondary = Color(0xff374151);
  static const textMuted = Color(0xff6B7280);
  static const textFaint = Color(0xff9CA3AF);

  static const error = Color(0xffDC2626);
}

/// The app's theme, built from [Palette].
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Palette.accent, brightness: Brightness.light)
    .copyWith(primary: Palette.accent, surface: Palette.surface);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.background,
    dividerColor: Palette.border,
  );
}
