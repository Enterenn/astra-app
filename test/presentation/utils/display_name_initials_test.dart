import 'package:astra_app/presentation/utils/display_name_initials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initialsFromDisplayName', () {
    test('single token returns first grapheme uppercase', () {
      expect(initialsFromDisplayName('Alex'), 'A');
    });

    test('two tokens return first and last graphemes', () {
      expect(initialsFromDisplayName('Marie Dupont'), 'MD');
    });

    test('three or more tokens use first and last word', () {
      expect(initialsFromDisplayName('Jean Paul Sartre'), 'JS');
    });

    test('trims surrounding whitespace', () {
      expect(initialsFromDisplayName('  Élise  '), 'É');
    });

    test('null and empty return null', () {
      expect(initialsFromDisplayName(null), isNull);
      expect(initialsFromDisplayName(''), isNull);
      expect(initialsFromDisplayName('   '), isNull);
    });

    test('single space returns null', () {
      expect(initialsFromDisplayName(' '), isNull);
    });

    test('punctuation-only returns first grapheme', () {
      expect(initialsFromDisplayName('!!!'), '!');
    });

    test('collapses internal whitespace', () {
      expect(initialsFromDisplayName('Marie   Dupont'), 'MD');
    });
  });

  group('hasTrimmedDisplayName', () {
    test('true when trimmed name is non-empty', () {
      expect(hasTrimmedDisplayName('Alex'), isTrue);
      expect(hasTrimmedDisplayName('  Alex  '), isTrue);
    });

    test('false when null or whitespace-only', () {
      expect(hasTrimmedDisplayName(null), isFalse);
      expect(hasTrimmedDisplayName(''), isFalse);
      expect(hasTrimmedDisplayName('   '), isFalse);
    });
  });
}
