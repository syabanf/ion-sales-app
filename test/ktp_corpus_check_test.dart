// KTP OCR accuracy harness — developer-run, not CI.
//
// The mobile binary is provider-agnostic: it POSTs the image and renders
// whatever fields come back. So "OCR accuracy" is really a property of
// the *server-side* provider (stub | tesseract | future cloud vendor),
// not the mobile code. This test exercises the end-to-end shape against
// a corpus of real KTP photos + ground-truth JSON sidecars.
//
// How to use:
//
//   1. Drop scans under: mobile/sales_app/test/fixtures/ktp_corpus/
//      Each scan needs two files with matching basenames:
//        - <name>.jpg          (or .jpeg / .png)
//        - <name>.truth.json   ({ "nik": "...", "full_name": "...", ... })
//
//   2. Start a crm-svc binary built with the provider you want to test:
//        go build -tags=tesseract -o /tmp/crm-svc ./cmd/crm-svc
//        KTP_OCR_PROVIDER=tesseract /tmp/crm-svc
//
//   3. Run the harness pointing at it:
//        KTP_CORPUS_DIR=mobile/sales_app/test/fixtures/ktp_corpus \
//        KTP_OCR_ENDPOINT=http://localhost:8080/api/crm/ktp-ocr \
//        flutter test test/ktp_corpus_check_test.dart
//
// Default behaviour: if KTP_CORPUS_DIR is unset (CI, fresh checkout)
// the test prints a skip note and passes. We never commit real KTP
// images — they contain PII.
//
// The harness reports per-field match rate and asserts NIK accuracy
// >= the threshold (default 0.95). Tune via KTP_CORPUS_NIK_THRESHOLD.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KTP OCR corpus accuracy', () async {
    final corpusDir = Platform.environment['KTP_CORPUS_DIR'];
    if (corpusDir == null || corpusDir.isEmpty) {
      // Soft skip — keeps CI green while still being a documented harness.
      // ignore: avoid_print
      print('[ktp-corpus] KTP_CORPUS_DIR not set — skipping. '
          'See file header for usage.');
      return;
    }
    final dir = Directory(corpusDir);
    if (!dir.existsSync()) {
      fail('KTP_CORPUS_DIR points to a missing dir: $corpusDir');
    }
    final endpoint = Platform.environment['KTP_OCR_ENDPOINT'] ??
        'http://localhost:8080/api/crm/ktp-ocr';
    final nikThreshold = double.tryParse(
            Platform.environment['KTP_CORPUS_NIK_THRESHOLD'] ?? '') ??
        0.95;

    final entries = dir
        .listSync()
        .whereType<File>()
        .where((f) => _isImage(f.path))
        .toList();
    if (entries.isEmpty) {
      // ignore: avoid_print
      print('[ktp-corpus] corpus dir is empty — nothing to check.');
      return;
    }

    var total = 0;
    var nikMatches = 0;
    final fieldMatches = <String, int>{};
    final fieldTotal = <String, int>{};

    for (final image in entries) {
      final base = image.path.replaceFirst(RegExp(r'\.[^./]+$'), '');
      final truthFile = File('$base.truth.json');
      if (!truthFile.existsSync()) {
        // ignore: avoid_print
        print('[ktp-corpus] skipping ${image.path}: no .truth.json sidecar');
        continue;
      }
      final truth = json.decode(await truthFile.readAsString())
          as Map<String, dynamic>;
      final bytes = await image.readAsBytes();
      final contentType =
          image.path.endsWith('.png') ? 'image/png' : 'image/jpeg';

      final client = HttpClient();
      final req = await client.postUrl(Uri.parse(endpoint));
      req.headers.set(HttpHeaders.contentTypeHeader, contentType);
      req.headers.set(HttpHeaders.contentLengthHeader, bytes.length.toString());
      req.add(bytes);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      if (res.statusCode != 200) {
        fail('OCR endpoint returned ${res.statusCode}: $body');
      }
      final actual = json.decode(body) as Map<String, dynamic>;

      total++;
      if (_eq(truth['nik'], actual['nik'])) nikMatches++;
      for (final key in truth.keys) {
        fieldTotal[key] = (fieldTotal[key] ?? 0) + 1;
        if (_eq(truth[key], actual[key])) {
          fieldMatches[key] = (fieldMatches[key] ?? 0) + 1;
        }
      }
    }

    // ignore: avoid_print
    print('[ktp-corpus] processed $total images');
    for (final entry in fieldTotal.entries) {
      final matches = fieldMatches[entry.key] ?? 0;
      final rate = matches / entry.value;
      // ignore: avoid_print
      print('  ${entry.key.padRight(16)} '
          '${(rate * 100).toStringAsFixed(1)}%  ($matches/${entry.value})');
    }

    expect(total, greaterThan(0),
        reason: 'corpus dir had images but no matching truth sidecars');
    final nikRate = nikMatches / total;
    expect(nikRate, greaterThanOrEqualTo(nikThreshold),
        reason: 'NIK accuracy ${(nikRate * 100).toStringAsFixed(1)}% '
            'below threshold ${(nikThreshold * 100).toStringAsFixed(0)}%');
  }, timeout: const Timeout(Duration(minutes: 10)));
}

bool _isImage(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png');
}

bool _eq(Object? a, Object? b) {
  if (a == null || b == null) return a == b;
  return a.toString().trim().toLowerCase() == b.toString().trim().toLowerCase();
}
