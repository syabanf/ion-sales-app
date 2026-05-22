// Tests for the sales-app CRM validators.
//
// Pure-function tests — no widget rendering, no platform plugins,
// no API mocks. The point is to pin the field-validation +
// wizard-gating contracts so the new-lead flow doesn't silently
// regress when someone tweaks one branch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ion_sales_app/features/crm/domain/validators.dart';

void main() {
  group('isValidNik', () {
    test('empty is valid (treated as not entered)', () {
      expect(isValidNik(''), isTrue);
      expect(isValidNik('   '), isTrue);
    });

    test('exactly 16 digits is valid', () {
      expect(isValidNik('1234567890123456'), isTrue);
    });

    test('wrong length is invalid', () {
      expect(isValidNik('123'), isFalse);
      expect(isValidNik('12345678901234567'), isFalse); // 17
    });

    test('non-numeric is invalid', () {
      expect(isValidNik('1234abcd56789012'), isFalse);
      expect(isValidNik('1234.567890123456'), isFalse);
    });

    test('whitespace is trimmed before length check', () {
      expect(isValidNik('  1234567890123456  '), isTrue);
    });
  });

  group('isValidIDPhone', () {
    test('canonical 08xx format', () {
      expect(isValidIDPhone('081234567890'), isTrue);
    });

    test('international +62 format normalises to 08', () {
      expect(isValidIDPhone('+6281234567890'), isTrue);
      expect(isValidIDPhone('6281234567890'), isTrue);
    });

    test('dashes + parens + spaces are stripped', () {
      expect(isValidIDPhone('0812-3456-7890'), isTrue);
      expect(isValidIDPhone('(0812) 3456 7890'), isTrue);
    });

    test('too short / too long', () {
      expect(isValidIDPhone('081234'),               isFalse); // 6
      expect(isValidIDPhone('08123456789012345'),    isFalse); // 17
    });

    test('non-08 prefix rejected', () {
      expect(isValidIDPhone('071234567890'), isFalse);
      expect(isValidIDPhone('21234567890'),  isFalse);
    });

    test('empty rejected', () {
      expect(isValidIDPhone(''),   isFalse);
      expect(isValidIDPhone('   '), isFalse);
    });
  });

  group('isValidEmail', () {
    test('simple address is valid', () {
      expect(isValidEmail('a@b.co'), isTrue);
      expect(isValidEmail('first.last@ion.local'), isTrue);
    });

    test('whitespace inside is rejected', () {
      expect(isValidEmail('a b@x.com'), isFalse);
    });

    test('missing @ rejected', () {
      expect(isValidEmail('hello.world'), isFalse);
    });

    test('missing . after @ rejected', () {
      expect(isValidEmail('user@host'), isFalse);
    });

    test('@ at start / . at end rejected', () {
      expect(isValidEmail('@host.com'), isFalse);
      expect(isValidEmail('user@host.'), isFalse);
    });
  });

  group('canAdvanceFromStep', () {
    // Convenience defaults for the irrelevant fields per step.
    bool advance({
      required int step,
      String address = '',
      double? gpsLat,
      String? coverageVerdict,
      String fullName = '',
      String phone = '',
      String? productId,
    }) => canAdvanceFromStep(
      step: step, address: address, gpsLat: gpsLat,
      coverageVerdict: coverageVerdict, fullName: fullName, phone: phone,
      productId: productId,
    );

    test('step 0 requires address + GPS + non-no-coverage verdict', () {
      // Missing address.
      expect(advance(step: 0, gpsLat: 1.0, coverageVerdict: 'covered'), isFalse);
      // Missing GPS.
      expect(advance(step: 0, address: 'somewhere', coverageVerdict: 'covered'), isFalse);
      // No coverage.
      expect(advance(step: 0, address: 'x', gpsLat: 1.0, coverageVerdict: 'no_coverage'), isFalse);
      // Verdict not yet computed.
      expect(advance(step: 0, address: 'x', gpsLat: 1.0, coverageVerdict: null), isFalse);
      // All present + covered.
      expect(advance(step: 0, address: 'x', gpsLat: 1.0, coverageVerdict: 'covered'), isTrue);
      // covered_with_excess is fine at step 0; the accept-flag is checked separately.
      expect(advance(step: 0, address: 'x', gpsLat: 1.0, coverageVerdict: 'covered_with_excess'), isTrue);
    });

    test('step 1 needs name + 8+ digit phone', () {
      expect(advance(step: 1, fullName: '',     phone: '081234567'),  isFalse);
      expect(advance(step: 1, fullName: 'A B',  phone: '0812345'),    isFalse); // 7 chars
      expect(advance(step: 1, fullName: 'A B',  phone: '08123456'),   isTrue);  // 8 chars
    });

    test('step 2 needs a product chosen', () {
      expect(advance(step: 2, productId: null), isFalse);
      expect(advance(step: 2, productId: 'some-uuid'), isTrue);
    });

    test('unknown step is always false (defensive)', () {
      expect(advance(step: 7), isFalse);
      expect(advance(step: -1), isFalse);
    });
  });

  group('Coverage banner styling', () {
    test('covered = green family', () {
      expect(coverageBg('covered'), Colors.green.shade50);
      expect(coverageFg('covered'), Colors.green.shade800);
    });

    test('covered_with_excess = amber family', () {
      expect(coverageBg('covered_with_excess'), Colors.amber.shade50);
      expect(coverageFg('covered_with_excess'), Colors.amber.shade800);
    });

    test('no_coverage = red family', () {
      expect(coverageBg('no_coverage'), Colors.red.shade50);
      expect(coverageFg('no_coverage'), Colors.red.shade800);
    });

    test('unknown verdict falls back to grey/ink', () {
      expect(coverageBg('something_new'), Colors.grey.shade100);
      // ink is the brand default — we just check it's NOT one of the
      // verdict-specific colours.
      expect(coverageFg('something_new'), isNot(Colors.green.shade800));
      expect(coverageFg('something_new'), isNot(Colors.red.shade800));
    });
  });

  group('requiresAcceptExcess + isCoverageSubmittable', () {
    test('covered is always submittable', () {
      expect(requiresAcceptExcess('covered'), isFalse);
      expect(isCoverageSubmittable('covered', acceptedExcess: false), isTrue);
      expect(isCoverageSubmittable('covered', acceptedExcess: true),  isTrue);
    });

    test('covered_with_excess needs the opt-in', () {
      expect(requiresAcceptExcess('covered_with_excess'), isTrue);
      expect(isCoverageSubmittable('covered_with_excess', acceptedExcess: false), isFalse);
      expect(isCoverageSubmittable('covered_with_excess', acceptedExcess: true),  isTrue);
    });

    test('no_coverage is never submittable', () {
      expect(isCoverageSubmittable('no_coverage', acceptedExcess: true), isFalse);
    });

    test('null / unknown verdict is not submittable', () {
      expect(isCoverageSubmittable(null,             acceptedExcess: true), isFalse);
      expect(isCoverageSubmittable('something_new',  acceptedExcess: true), isFalse);
    });
  });
}
