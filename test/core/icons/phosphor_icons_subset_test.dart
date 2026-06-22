import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phosphor icon subset guard', () {
    late String iconsSource;
    late String shScript;
    late String ps1Script;

    setUp(() {
      iconsSource = File('lib/core/icons/phosphor_icons.dart').readAsStringSync();
      shScript = File('tool/subset_phosphor_icons.sh').readAsStringSync();
      ps1Script = File('tool/subset_phosphor_icons.ps1').readAsStringSync();
    });

    test('every IconData codepoint in phosphor_icons.dart is in subset scripts', () {
      final regularFromDart = _codepointsByFamily(iconsSource, 'PhosphorRegular');
      final fillFromDart = _codepointsByFamily(iconsSource, 'PhosphorFill');

      final regularFromSh = _parseUnicodeList(shScript, r"REGULAR='([^']+)'");
      final fillFromSh = _parseUnicodeList(shScript, r"FILL='([^']+)'");
      final regularFromPs1 = _parseUnicodeList(
        ps1Script,
        "regularUnicodes = '([^']+)'",
      );
      final fillFromPs1 = _parseUnicodeList(
        ps1Script,
        "fillUnicodes = '([^']+)'",
      );

      expect(regularFromSh, equals(regularFromPs1));
      expect(fillFromSh, equals(fillFromPs1));

      for (final codepoint in regularFromDart) {
        expect(
          regularFromSh,
          contains(codepoint),
          reason:
              'Regular icon 0x${codepoint.toRadixString(16)} is missing from '
              'tool/subset_phosphor_icons.{sh,ps1}',
        );
      }

      for (final codepoint in fillFromDart) {
        expect(
          fillFromSh,
          contains(codepoint),
          reason:
              'Fill icon 0x${codepoint.toRadixString(16)} is missing from '
              'tool/subset_phosphor_icons.{sh,ps1}',
        );
      }
    });
  });
}

Set<int> _codepointsByFamily(String source, String fontFamily) {
  final pattern = RegExp(
    'IconData\\(\\s*(0x[0-9a-fA-F]+),\\s*fontFamily:\\s*\'$fontFamily\'',
    multiLine: true,
  );
  return pattern
      .allMatches(source)
      .map((match) => int.parse(match.group(1)!))
      .toSet();
}

Set<int> _parseUnicodeList(String script, String patternSource) {
  final match = RegExp(patternSource).firstMatch(script);
  expect(match, isNotNull, reason: 'Unicode list not found in subset script');

  return match!
      .group(1)!
      .split(',')
      .map((token) => int.parse(token.trim().replaceFirst('U+', ''), radix: 16))
      .toSet();
}
