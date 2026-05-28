import 'package:flutter/material.dart';

/// Semantic color tokens (UX §1.2). Access via [AstraThemeContext.astraColors].
@immutable
class AstraColors extends ThemeExtension<AstraColors> {
  const AstraColors({
    required this.bgBase,
    required this.bgElevated,
    required this.bgSubtle,
    required this.borderDefault,
    required this.borderFocus,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textInverse,
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
  final Color borderFocus;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textInverse;

  // Accent & data (shared hex; opacity set in factories)
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

  /// Shared accent/status/data colors (same hex in both themes).
  static AstraColors _sharedTokens({
    required Color bgBase,
    required Color bgElevated,
    required Color bgSubtle,
    required Color borderDefault,
    required Color borderFocus,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color textInverse,
  }) {
    const accent = Color(0xFFEAD55E);
    return AstraColors(
      bgBase: bgBase,
      bgElevated: bgElevated,
      bgSubtle: bgSubtle,
      borderDefault: borderDefault,
      borderFocus: borderFocus,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textMuted: textMuted,
      textInverse: textInverse,
      accentPrimary: accent,
      accentPrimaryMuted: accent.withValues(alpha: 0.28),
      accentSecondary: const Color(0xFF94A3B8),
      dataPositive: const Color(0xFFA3E635).withValues(alpha: 0.8),
      dataNegative: const Color(0xFFFCA5A5),
      dataGoalLine: accent.withValues(alpha: 0.35),
      statusOk: const Color(0xFF86EFAC),
      statusStale: const Color(0xFFFBBF24),
      statusDanger: const Color(0xFFF87171),
      statusInfo: const Color(0xFF93C5FD),
    );
  }

  factory AstraColors.light() => _sharedTokens(
        bgBase: const Color(0xFFF8F9FB),
        bgElevated: const Color(0xFFFFFFFF),
        bgSubtle: const Color(0xFFEEF0F4),
        borderDefault: const Color(0xFFD1D5DB),
        borderFocus: const Color(0xFF9CA3AF),
        textPrimary: const Color(0xFF0F1114),
        textSecondary: const Color(0xFF4B5563),
        textMuted: const Color(0xFF6B7280),
        textInverse: const Color(0xFFF4F5F7),
      );

  factory AstraColors.dark() => _sharedTokens(
        bgBase: const Color(0xFF0F1114),
        bgElevated: const Color(0xFF1A1D23),
        bgSubtle: const Color(0xFF252830),
        borderDefault: const Color(0xFF2E3340),
        borderFocus: const Color(0xFF4A5568),
        textPrimary: const Color(0xFFF4F5F7),
        textSecondary: const Color(0xFF9CA3AF),
        textMuted: const Color(0xFF6B7280),
        textInverse: const Color(0xFF0F1114),
      );

  @override
  AstraColors copyWith({
    Color? bgBase,
    Color? bgElevated,
    Color? bgSubtle,
    Color? borderDefault,
    Color? borderFocus,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textInverse,
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
      borderFocus: borderFocus ?? this.borderFocus,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textInverse: textInverse ?? this.textInverse,
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
      borderFocus: _lerpColor(borderFocus, other.borderFocus, t)!,
      textPrimary: _lerpColor(textPrimary, other.textPrimary, t)!,
      textSecondary: _lerpColor(textSecondary, other.textSecondary, t)!,
      textMuted: _lerpColor(textMuted, other.textMuted, t)!,
      textInverse: _lerpColor(textInverse, other.textInverse, t)!,
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
