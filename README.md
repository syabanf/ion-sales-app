# ion-sales-app

Field sales-rep app for the ION Network ISP. Sales reps use it to
capture new leads on-site — coverage check (ODP picker + GPS pin),
customer details, KTP photo, product pick — then track the lead
through to conversion + commission accrual.

Part of a 5-repo system:

| Repo | What it is |
|---|---|
| [ion-backend](https://github.com/syabanf/ion-backend) | Go services, migrations, e2e suite |
| [ion-frontend](https://github.com/syabanf/ion-frontend) | Next.js admin dashboard |
| [ion-customer-app](https://github.com/syabanf/ion-customer-app) | Flutter customer portal |
| **ion-sales-app** (this) | Flutter sales-rep app |
| [ion-tech-app](https://github.com/syabanf/ion-tech-app) | Flutter technician app |

---

## Tech stack

| Layer | Choice | Notes |
|---|---|---|
| Framework | **Flutter** (stable channel) | Single codebase → web, Android, iOS |
| Language | **Dart 3** | Sound null safety, sealed classes for events/states |
| State | **flutter_bloc** | Event-driven, deterministic state per feature |
| Routing | **go_router** | Declarative routes, deep-link friendly |
| HTTP | **Dio** | Auth interceptor, single-flight 401 refresh |
| DI | **get_it** | Constructor-free repo lookup |
| Maps | **flutter_map** + OpenStreetMap tiles | Coverage map with ODP pins (no Google Maps API key needed) |
| Secure storage | **flutter_secure_storage** | Staff JWT access + refresh |
| Push | **firebase_messaging** (gated by `ION_PUSH_ENABLED`) | Kill-switched until FCM credentials land |
| Tests | `flutter_test` + **bloc_test** + **mocktail** | Bloc-driven unit + widget tests |
| Equality | **equatable** | `==`/`hashCode` without boilerplate on states |

---

## Quick start

### Prerequisites

- Flutter SDK 3.x (stable channel)
- A running ION backend on `http://localhost:8080` (see
  [ion-backend](https://github.com/syabanf/ion-backend))

### Run on web (the canonical dev surface)

```bash
flutter pub get
flutter run -d chrome --web-port=9101 \
  --dart-define=API_URL=http://localhost:8080
```

Opens at `http://localhost:9101`.

### Sign in (with seed-demo)

Email `sales@ion.local` / password `IonDemo!2026Tour` (the sales_rep
account). Other staff roles work too — see
[ion-backend's seed-demo](https://github.com/syabanf/ion-backend) for
the full user list.

### Run on Android / iOS

```bash
flutter pub get
flutter run
# Or pick a specific device:
flutter run -d "Pixel 7"
```

### Build for production

```bash
flutter build web --release          # build/web/
flutter build apk --release          # build/app/outputs/flutter-apk/
flutter build ios --release
```

### Enable push notifications

```bash
flutter run -d chrome \
  --dart-define=API_URL=https://api.your-domain.com \
  --dart-define=ION_PUSH_ENABLED=true
```

Requires `google-services.json` / `GoogleService-Info.plist` in the
standard locations. PushNotifier in `lib/push/` is a no-op until
the flag flips.

---

## Project structure

```
lib/
├── main.dart                   # Entry — wires AuthRepo + Bloc + Router
├── shared.dart                 # Barrel export (theme, DI, primitives)
├── app/
│   ├── sales_app.dart          # Root MaterialApp.router + BlocProviders
│   └── router.dart             # go_router routes
├── auth/
│   ├── data/auth_api.dart      # /auth/login, /auth/refresh
│   ├── domain/                 # AuthSession + AuthRepository
│   └── presentation/
│       ├── bloc/auth_bloc.dart # AuthBloc + AuthEvent + AuthState
│       └── pages/login_page.dart
├── core/
│   ├── api/api_client.dart     # Dio with auth interceptor
│   ├── di/injector.dart        # get_it setup
│   ├── errors/api_exception.dart
│   ├── storage/token_storage.dart
│   └── theme/app_theme.dart    # ION-brand tokens
├── features/
│   ├── crm/
│   │   ├── data/               # Lead API + repository
│   │   ├── domain/             # Lead + LeadStatus + Validators
│   │   ├── presentation/
│   │   │   ├── bloc/leads_bloc.dart
│   │   │   ├── pages/          # leads_list, lead_capture (wizard), lead_detail
│   │   │   └── widgets/
│   │   │       ├── coverage_map.dart        # flutter_map + ODP pins
│   │   │       ├── ktp_uploader.dart
│   │   │       └── product_picker.dart
│   ├── opportunities/          # Enterprise pipeline kanban
│   ├── commission/             # Own commission ledger view
│   └── profile/                # Avatar, settings, dark-mode toggle
├── push/push_notifier.dart     # FCM bootstrap (kill-switched)
├── gps/gps.dart                # GPS streaming + coverage hint
└── widgets/                    # Cross-feature primitives

test/
├── coverage_map_widget_test.dart
├── ktp_corpus_check_test.dart
├── leads_bloc_test.dart
├── login_page_widget_test.dart
├── role_gate_test.dart
├── validators_test.dart
└── wizard_predicates_test.dart
```

---

## Authentication flow

Standard staff JWT (different from the customer portal flow in
ion-customer-app):

1. Email + password → POST `/api/identity/auth/login`
2. Server returns `{access_token, refresh_token, ...}` — both stored
   in `flutter_secure_storage`
3. Dio interceptor attaches `Authorization: Bearer <access>` on every
   request
4. 401 triggers single-flight refresh via `/api/identity/auth/refresh`
5. Refresh failure → fire `onAuthLost` → AuthBloc transitions to
   `unauthenticated` → router redirects to /login

The bearer token carries the user's `permissions[]` claim (resolved
from `identity.role_permissions`). Feature pages check via the
`RoleGate` widget — e.g. `RoleGate(any: ["crm.lead.create"])` hides
the "New lead" CTA from accounts without that permission.

---

## Lead capture flow (the canonical happy path)

```
LoginPage
   │
   ▼
LeadsListPage ──────────────────────► LeadDetailPage
   │ "New lead" CTA                       (status, docs, convert)
   ▼
LeadCaptureWizard
   ├── Step 1: Customer (name, phone, NIK, email)
   ├── Step 2: Address + GPS pin
   ├── Step 3: Coverage check (ODP picker, excess cable consent)
   ├── Step 4: Product pick (BB-10/30/50/100 from crm.products)
   ├── Step 5: KTP photo (OCR client-side stub; real OCR is server-side)
   └── Step 6: Review + submit
                │
                ▼ POST /api/crm/leads
              Backend assigns lead_number, coverage_verdict, status='qualified'
                │
                ▼ Push: "New lead captured"
              (notifyx event; surfaces on dashboard + sales-mgr's app)
```

---

## Testing

```bash
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test                                              # full suite
flutter test test/leads_bloc_test.dart                    # one file
flutter test --coverage                                   # writes coverage/lcov.info
```

Test inventory:

- **Pure-function**: validators (phone, NIK, GPS bounds), KTP corpus
  check, wizard step predicates
- **Bloc**: LeadsBloc — event → state transitions, error paths
- **Widget**: coverage_map (mounts in three GPS/coverage states),
  login_page (renders fields + error message + spinner-on-authenticating)
- **RoleGate**: permission gating works in all role configurations

---

## Where this fits

```
                       ┌──────────────────┐
  Sales rep's phone    │  ion-sales-app   │
                       └────────┬─────────┘
                                │ /api/* via gateway
                                ▼
                       ┌──────────────────┐
                       │   api-gateway    │
                       │     :8080        │
                       └────────┬─────────┘
                                ▼
                  identity-svc · crm-svc · network-svc
                  (auth)      (leads)  (ODP coverage)
```

Lead created here → admin sees it on `ion-frontend`'s `/crm/leads`
page → admin converts → install WO created → technician picks it up
on `ion-tech-app` → BAST → NOC approves → customer ACTIVE. Sales rep
sees commission accrued on their profile page.

---

## Browser support

Modern Chromium / Safari / Firefox / Edge. The coverage map uses
OpenStreetMap tiles (no API key) so any browser with WebGL2 works.
