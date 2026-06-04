import 'package:flutter/material.dart';

import 'astra_accent_palette.dart';
import 'astra_accent_preset.dart';

/// Semantic color tokens (UX §1.2). Access via [AstraThemeContext.astraColors].
@immutable
class AstraColors extends ThemeExtension<AstraColors> {
  const AstraColors({
    required this.bgBase,
    required this.bgElevated,
    required this.bgSubtle,
    required this.borderDefault,
    required this.borderPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textInverse,
    required this.neutralGray,
    required this.accentPrimary,
    required this.accentPrimaryMuted,
    required this.accentSecondary,
    required this.dataPositive,
    required this.dataNegative,
    required this.dataGoalLine,
    required this.statusOk,
    required this.statusStale,
    required this.statusDanger,
    required this.statusInfo,
  });

  // Surfaces & borders
  final Color bgBase;
  final Color bgElevated;
  final Color bgSubtle;
  final Color borderDefault;
  final Color borderPrimary;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textInverse;
  final Color neutralGray;

  // Accent & data
  final Color accentPrimary;
  final Color accentPrimaryMuted;
  final Color accentSecondary;
  final Color dataPositive;
  final Color dataNegative;
  final Color dataGoalLine;

  // Status
  final Color statusOk;
  final Color statusStale;
  final Color statusDanger;
  final Color statusInfo;

  static const _neutralGray = Color(0xFFA0A0AA);
  static const _statusOk = Color(0xFF7CEA89);
  static const _statusDanger = Color(0xFFE52F2F);
  static const _statusStale = Color(0xFFFBBF24);
  static const _statusInfo = Color(0xFF93C5FD);

  factory AstraColors.light({
    AstraAccentPreset preset = kDefaultAccentPreset,
  }) =>
      _forBrightness(Brightness.light, preset);

  factory AstraColors.dark({
    AstraAccentPreset preset = kDefaultAccentPreset,
  }) =>
      _forBrightness(Brightness.dark, preset);

  static AstraColors _forBrightness(
    Brightness brightness,
    AstraAccentPreset preset,
  ) {
    final palette = accentPaletteFor(preset);
    final primary = palette.primary;
    final (bgBase, bgElevated, bgSubtle, textPrimary, textSecondary, textMuted, textInverse) =
        switch (brightness) {
      Brightness.light => (
          const Color(0xFFF8F9FB),
          const Color(0xFFFFFFFF),
          const Color(0xFFEEF0F4),
          const Color(0xFF323337),
          const Color(0xFF4B5563),
          const Color(0xFF6B7280),
          const Color(0xFFF4F5F7),
        ),
      Brightness.dark => (
          const Color(0xFF101115),
          const Color(0xFF1A1D26),
          const Color(0xFF3E4457),
          const Color(0xFFC8C8D7),
          const Color(0xFF9CA3AF),
          const Color(0xFF6B7280),
          const Color(0xFF0F1114),
        ),
    };

    return AstraColors(
      bgBase: bgBase,
      bgElevated: bgElevated,
      bgSubtle: bgSubtle,
      borderDefault: _neutralGray,
      borderPrimary: primary,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textMuted: textMuted,
      textInverse: textInverse,
      neutralGray: _neutralGray,
      accentPrimary: primary,
      accentPrimaryMuted: primary.withValues(alpha: 0.28),
      accentSecondary: palette.secondary,
      dataPositive: primary,
      dataNegative: primary.withValues(alpha: 0.33),
      dataGoalLine: primary.withValues(alpha: 0.35),
      statusOk: _statusOk,
      statusStale: _statusStale,
      statusDanger: _statusDanger,
      statusInfo: _statusInfo,
    );
  }

  @override
  AstraColors copyWith({
    Color? bgBase,
    Color? bgElevated,
    Color? bgSubtle,
    Color? borderDefault,
    Color? borderPrimary,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textInverse,
    Color? neutralGray,
    Color? accentPrimary,
    Color? accentPrimaryMuted,
    Color? accentSecondary,
    Color? dataPositive,
    Color? dataNegative,
    Color? dataGoalLine,
    Color? statusOk,
    Color? statusStale,
    Color? statusDanger,
    Color? statusInfo,
  }) {
    return AstraColors(
      bgBase: bgBase ?? this.bgBase,
      bgElevated: bgElevated ?? this.bgElevated,
      bgSubtle: bgSubtle ?? this.bgSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderPrimary: borderPrimary ?? this.borderPrimary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textInverse: textInverse ?? this.textInverse,
      neutralGray: neutralGray ?? this.neutralGray,
      accentPrimary: accentPrimary ?? this.accentPrimary,
      accentPrimaryMuted: accentPrimaryMuted ?? this.accentPrimaryMuted,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      dataPositive: dataPositive ?? this.dataPositive,
      dataNegative: dataNegative ?? this.dataNegative,
      dataGoalLine: dataGoalLine ?? this.dataGoalLine,
      statusOk: statusOk ?? this.statusOk,
      statusStale: statusStale ?? this.statusStale,
      statusDanger: statusDanger ?? this.statusDanger,
      statusInfo: statusInfo ?? this.statusInfo,
    );
  }

  static Color? _lerpColor(Color? a, Color? b, double t) =>
      a != null && b != null ? Color.lerp(a, b, t) : null;

  @override
  AstraColors lerp(covariant ThemeExtension<AstraColors>? other, double t) {
    if (other is! AstraColors) return this;
    return AstraColors(
      bgBase: _lerpColor(bgBase, other.bgBase, t)!,
      bgElevated: _lerpColor(bgElevated, other.bgElevated, t)!,
      bgSubtle: _lerpColor(bgSubtle, other.bgSubtle, t)!,
      borderDefault: _lerpColor(borderDefault, other.borderDefault, t)!,
      borderPrimary: _lerpColor(borderPrimary, other.borderPrimary, t)!,
      textPrimary: _lerpColor(textPrimary, other.textPrimary, t)!,
      textSecondary: _lerpColor(textSecondary, other.textSecondary, t)!,
      textMuted: _lerpColor(textMuted, other.textMuted, t)!,
      textInverse: _lerpColor(textInverse, other.textInverse, t)!,
      neutralGray: _lerpColor(neutralGray, other.neutralGray, t)!,
      accentPrimary: _lerpColor(accentPrimary, other.accentPrimary, t)!,
      accentPrimaryMuted:
          _lerpColor(accentPrimaryMuted, other.accentPrimaryMuted, t)!,
      accentSecondary: _lerpColor(accentSecondary, other.accentSecondary, t)!,
      dataPositive: _lerpColor(dataPositive, other.dataPositive, t)!,
      dataNegative: _lerpColor(dataNegative, other.dataNegative, t)!,
      dataGoalLine: _lerpColor(dataGoalLine, other.dataGoalLine, t)!,
      statusOk: _lerpColor(statusOk, other.statusOk, t)!,
      statusStale: _lerpColor(statusStale, other.statusStale, t)!,
      statusDanger: _lerpColor(statusDanger, other.statusDanger, t)!,
      statusInfo: _lerpColor(statusInfo, other.statusInfo, t)!,
    );
  }
}

/// Convenient access: `context.astraColors.bgBase`
extension AstraThemeContext on BuildContext {
  AstraColors get astraColors =>
      Theme.of(this).extension<AstraColors>()!;
}
