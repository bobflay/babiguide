import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BgPalette {
  final Color bg;
  final Color bgDeep;
  final Color card;
  final Color cardBorder;
  final Color ink;
  final Color inkMuted;
  final Color orange;
  final Color orangeDeep;
  final Color orangeSoft;
  final Color green;

  const BgPalette({
    required this.bg,
    required this.bgDeep,
    required this.card,
    required this.cardBorder,
    required this.ink,
    required this.inkMuted,
    required this.orange,
    required this.orangeDeep,
    required this.orangeSoft,
    required this.green,
  });

  static const BgPalette light = BgPalette(
    bg: Color(0xFFFBF6EE),
    bgDeep: Color(0xFFF2EADC),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0x1A785028),
    ink: Color(0xFF2A1A0E),
    inkMuted: Color(0xFF8C7561),
    orange: Color(0xFFF37221),
    orangeDeep: Color(0xFFC8551A),
    orangeSoft: Color(0xFFFFEEDD),
    green: Color(0xFF3F6B4E),
  );

  static const BgPalette dark = BgPalette(
    bg: Color(0xFF1A1208),
    bgDeep: Color(0xFF241810),
    card: Color(0xFF241810),
    cardBorder: Color(0x1AFFDCB4),
    ink: Color(0xFFFBF6EE),
    inkMuted: Color(0xFFA89380),
    orange: Color(0xFFF37221),
    orangeDeep: Color(0xFFFFA060),
    orangeSoft: Color(0x2EF37221),
    green: Color(0xFF7BAE8C),
  );
}

class BgFonts {
  static TextStyle display({
    double size = 16,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double letterSpacing = -0.2,
    double height = 1.15,
  }) {
    return GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
    double height = 1.4,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0.4,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }
}

class FrameSize {
  static const double width = 402;
  static const double height = 874;
}
