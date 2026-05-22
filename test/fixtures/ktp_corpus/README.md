# KTP OCR corpus (developer-local, do NOT commit images)

Drop real KTP scans here paired with a `.truth.json` sidecar of the same
basename. Run the harness via:

```
KTP_CORPUS_DIR=mobile/sales_app/test/fixtures/ktp_corpus \
KTP_OCR_ENDPOINT=http://localhost:8080/api/crm/ktp-ocr \
flutter test test/ktp_corpus_check_test.dart
```

## File pairing

```
ktp_corpus/
  budi-jakarta.jpg
  budi-jakarta.truth.json
  siti-bandung.png
  siti-bandung.truth.json
```

## `*.truth.json` shape

Only fields you want to score need to be present — the harness rates
each field independently and asserts on `nik` only by default.

```json
{
  "nik": "3171234567890001",
  "full_name": "BUDI HARTONO",
  "birth_date": "12-08-1985",
  "gender": "LAKI-LAKI",
  "address": "JL. SUDIRMAN NO. 12",
  "rt_rw": "003/004",
  "kelurahan": "MENTENG",
  "kecamatan": "MENTENG"
}
```

## Privacy

Images contain PII — they MUST NOT be committed. This directory has a
`.gitignore` so only the README + .gitignore land in source control;
all scans are dev-machine-only. Ask the data team if you need a
sanctioned anonymized corpus.
