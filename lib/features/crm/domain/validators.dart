// Pure-logic validators for the sales-app CRM flows.
//
// Two groups:
//   1. Field-level validators (NIK / phone / email / step gating)
//      used by the new-lead wizard.
//   2. Coverage-verdict styling — the verdict → colour pair shown
//      on the coverage banner. Extracted from the wizard so tests
//      can pin the visual contract.
//
// These mirror the rules the Go handlers enforce in
// backend/internal/crm/usecase/lead.go. When the backend tightens
// validation, update both sides — the mobile copy is for fast UX
// feedback only; the backend remains authoritative.

import 'package:flutter/material.dart';
import 'package:ion_sales_app/shared.dart';

// =============================================================================
// Field-level validators
// =============================================================================

/// Indonesian NIK (KTP number) is exactly 16 numeric digits.
/// Empty input is treated as "not yet entered" (valid for an optional
/// field, the caller decides whether to gate on it).
bool isValidNik(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return true;
  if (s.length != 16) return false;
  return s.codeUnits.every((c) => c >= 0x30 && c <= 0x39);
}

/// Indonesian phone. Accepts:
///   - 08xxxxxxxxxx  (local, 10–13 digits)
///   - +628xxxxxxxxxx / 628xxxxxxxxxx (international, 11–14 digits)
/// Whitespace + dashes are stripped before checking.
bool isValidIDPhone(String raw) {
  final s = raw.trim().replaceAll(RegExp(r'[\s\-()]'), '');
  if (s.isEmpty) return false;
  // Normalise to a plain digit string.
  var digits = s;
  if (digits.startsWith('+')) digits = digits.substring(1);
  if (digits.startsWith('62')) {
    digits = '0' + digits.substring(2);
  }
  if (!digits.startsWith('08')) return false;
  if (digits.length < 10 || digits.length > 13) return false;
  return digits.codeUnits.every((c) => c >= 0x30 && c <= 0x39);
}

/// Minimal email check — non-empty, contains "@" and a "." after it,
/// no whitespace. Same heuristic the backend uses for soft validation.
bool isValidEmail(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return false;
  if (s.contains(RegExp(r'\s'))) return false;
  final at = s.indexOf('@');
  if (at <= 0 || at == s.length - 1) return false;
  final dot = s.indexOf('.', at);
  return dot > at + 1 && dot < s.length - 1;
}

// =============================================================================
// New-lead wizard step gating
// =============================================================================

/// The wizard has three steps:
///   0 — address + GPS + coverage check
///   1 — full name + phone
///   2 — product selection
///
/// `canAdvanceFromStep` says whether the user has filled in enough
/// to move forward from a given step. Returns false for unknown
/// step numbers (defensive).
bool canAdvanceFromStep({
  required int step,
  required String address,
  required double? gpsLat,
  required String? coverageVerdict,
  required String fullName,
  required String phone,
  required String? productId,
}) {
  switch (step) {
    case 0:
      return address.trim().isNotEmpty &&
          gpsLat != null &&
          coverageVerdict != null &&
          coverageVerdict != 'no_coverage';
    case 1:
      return fullName.trim().isNotEmpty && phone.trim().length >= 8;
    case 2:
      return productId != null;
    default:
      return false;
  }
}

// =============================================================================
// Coverage-verdict styling
// =============================================================================

/// Background tint for the coverage banner.
Color coverageBg(String verdict) {
  switch (verdict) {
    case 'covered':
      return Colors.green.shade50;
    case 'covered_with_excess':
      return Colors.amber.shade50;
    case 'no_coverage':
      return Colors.red.shade50;
    default:
      return Colors.grey.shade100;
  }
}

/// Foreground (text) colour for the coverage banner.
Color coverageFg(String verdict) {
  switch (verdict) {
    case 'covered':
      return Colors.green.shade800;
    case 'covered_with_excess':
      return Colors.amber.shade800;
    case 'no_coverage':
      return Colors.red.shade800;
    default:
      return IonColors.ink;
  }
}

/// True when the verdict means the customer needs to opt-in to the
/// excess-cable surcharge before the lead can be submitted.
bool requiresAcceptExcess(String? verdict) => verdict == 'covered_with_excess';

/// True when the verdict means the order can proceed without further
/// gating — either fully inside the footprint or excess already
/// accepted by the customer.
bool isCoverageSubmittable(String? verdict, {required bool acceptedExcess}) {
  switch (verdict) {
    case 'covered':
      return true;
    case 'covered_with_excess':
      return acceptedExcess;
    case 'no_coverage':
      return false;
    default:
      return false;
  }
}
