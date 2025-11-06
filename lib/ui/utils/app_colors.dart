import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF5FA4AF);
  static const Color secondary = Color(0xFFC13134);
  static const Color background = Color(0xFFF5F5F5);
  static const Color text = Color(0xFF212121);
  static const Color accent = Color(0xFF03DAC6);
  static const Color logo = Color(0xFF465058);
}

List<Color> hslPalette(Color color) {
  final shades = <Color>[];

  // Make the color in HSL format
  final hslColor = HSLColor.fromColor(color);
  final baseHue = hslColor.hue;
  final baseSaturation = hslColor.saturation;
  final baseLightness = hslColor.lightness;

  for (int i = 0; i < 10; i++) {
    // Arbitray value, adjust it to your needs
    final step = i / 14;
    //

    // Color to be added
    Color shadeColor;
    //

    if (i < 5) {
      // Increase lightness to make it brighter
      final increasedLightness = (baseLightness + step).clamp(0, 1).toDouble();
      shadeColor =
          HSLColor.fromAHSL(1, baseHue, baseSaturation, increasedLightness)
              .toColor();
    } else {
      // Decrease lightness to make it darker
      final decreasedLightness =
          (baseLightness - (step / 5)).clamp(0, 1).toDouble();
      shadeColor =
          HSLColor.fromAHSL(1, baseHue, baseSaturation, decreasedLightness)
              .toColor();
    }
    shades.add(shadeColor);
  }
  return shades;
}

Map<int, Color> getColorSwatch(Color color) {
  final colorSwatch = <int, Color>{};
  final palette = hslPalette(color);

  for (int i = 0; i < palette.length; i++) {
    final key = i == 0 ? 50 : i * 100;

    if (i < 5) {
      // The most bright color is in the middle, so if i < 5
      // take first the items in the middle
      colorSwatch[key] = palette[4 - i];
    } else {
      colorSwatch[key] = palette[i];
    }
  }

  return colorSwatch;
}
