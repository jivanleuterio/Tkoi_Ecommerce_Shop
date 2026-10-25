import 'package:flutter/material.dart';

abstract final class AppColors {
  static const koiOrange = Color(0xFFF97316);
  static const vermilion = Color(0xFFDC2626);
  static const coral = Color(0xFFFB5A3C);
  static const gold = Color(0xFFFBBF24);
  static const warmWhite = Color(0xFFFFF8F0);
  static const cream = Color(0xFFFFF1E6);
  static const pondBlue = Color(0xFF0E7490);
  static const deepWater = Color(0xFF164E63);
  static const aqua = Color(0xFF2DD4BF);
  static const sumi = Color(0xFF172033);
  static const softGray = Color(0xFF64748B);
  static const mist = Color(0xFFE7F4F3);
  static const border = Color(0xFFE8DED4);
  static const success = Color(0xFF15803D);

  static const koiGradient = LinearGradient(
    colors: [koiOrange, vermilion],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const waterGradient = LinearGradient(
    colors: [deepWater, pondBlue, aqua],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const creamGradient = LinearGradient(
    colors: [warmWhite, cream],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const softShadow = [
    BoxShadow(color: Color(0x16172033), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadii {
  static const small = 12.0;
  static const medium = 18.0;
  static const large = 24.0;
  static const pill = 999.0;
}
