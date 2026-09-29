# TradeHub Demo - Flutter customer app (Android)

A generic, sanitized demo of a distribution / wholesale marketplace app. It talks
to the TradeHub Demo backend and shows **synthetic data only**. A persistent
"Demonstration Environment - synthetic data" strip is shown on every screen
(including login), enriched from `GET {API_BASE_URL}/demo/info` when reachable.

- Brand: TradeHub Demo - "Distribution made simple"
- Android application id / namespace: `com.demo.tradehub`
- iOS and web targets were deliberately removed (Android only)

## Requirements

- Flutter 3.44+ (Dart ^3.10.7), Android SDK with accepted licences
  (`flutter doctor --android-licenses`), JDK 17
- The demo backend running locally (default port 5050)

## Run / build against the demo API

The API base URL is **never hard-coded**. It is passed only through
`--dart-define=API_BASE_URL=...`. Without it the app refuses to start and shows a
full-screen "Configuration required" message.

```bash
flutter pub get

# Android emulator (10.0.2.2 = host machine)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5050/api/v1

# Physical device via USB: adb reverse tcp:5050 tcp:5050
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5050/api/v1

# APKs
flutter build apk --debug   --dart-define=API_BASE_URL=http://10.0.2.2:5050/api/v1
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:5050/api/v1
```

Quality checks: `flutter analyze` and `flutter test`.

## Demo accounts

Password for all accounts: `Demo@12345`

| Role        | Where to sign in                                   | Identifier                   |
|-------------|----------------------------------------------------|------------------------------|
| Buyer       | This app, login screen, role toggle **Customer**   | phone `9000000003`           |
| Wholesaler  | This app, login screen, role toggle **Wholesaler** | phone `9000000002`           |
| Admin       | Admin console (not this app)                       | email `admin@tradehub.example` |

Login fields (confirmed from `lib/screens/auth/auth_screen.dart` and
`lib/core/providers/auth_provider.dart`): the app has a single phone + password
form (`POST /auth/login-phone` with `phone`, `password`, `expectedRole` =
`buyer` | `wholesaler`). The role toggle at the top of the form sets
`expectedRole`; choose the toggle that matches the account. Admins do not use
this app.

## What was changed from the original client app

- Removed: hard-coded production API URL, Firebase / FCM (no google-services
  plugin/JSON, no `firebase_*` packages, no push-token registration - only
  in-app and local notifications remain), store-listing redirects (the
  mandatory-update check is disabled), WhatsApp actions (wa.me links, receipt
  share to WhatsApp, the Android WhatsApp method channel), the client keystore
  reference, client contact details, client brand sorting rules, partner-brand
  list and city entries, and all client legal text.
- Added: central brand constants (`lib/core/config/brand_config.dart`), the
  configuration-required screen, the demo banner (`lib/widgets/demo_banner.dart`),
  generic launcher icons / logo / launch image (generated), placeholder legal
  texts (`assets/legal/demo_*.txt`, all marked "Demo placeholder"), a new
  optional **Message / delivery requirement** field on the wholesaler
  "Send Requirement" sheet (sent as `message`, capped at 500 characters and shown
  in the negotiation detail screen when the API returns it).
- Renamed: the old customer "demo mode" is now "preview mode" (guest preview) so
  it is not confused with the demo environment.
- Theme: brand primary changed to deep teal (`#0F766E`) in
  `lib/core/theme/app_theme.dart` (plus the hard-coded former brand blue).

## Release signing

Release builds use the **debug** signing key so the APK builds out of the box.
For anything you distribute, create your own keystore, keep it outside source
control, add an untracked `android/key.properties`, and change the `release`
build type in `android/app/build.gradle.kts` to use a `signingConfig` that reads
it (see https://docs.flutter.dev/deployment/android#sign-the-app).

## Known limitations

- Push notifications are not available (no Firebase). Notifications appear in the
  in-app notification centre and as local notifications only.
- The mandatory-update flow is disabled (`AppUpdateService.isEnabled = false`).
- Some unrouted mock screens (e.g. landing, shipment detail, admin alerts hub)
  still contain generic placeholder text and third-party stock image URLs; they
  are not reachable from the app.
- Product imagery, brands and categories come entirely from the backend seed
  data; generic icon placeholders are used when an image is missing.
- Map tiles use the public OpenStreetMap tile server.
- Generated Android launcher icons are simple PIL-drawn monograms; replace them
  with proper artwork for a real product.
