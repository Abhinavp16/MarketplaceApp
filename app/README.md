# DemoMart - Flutter customer app (Android)

A generic demo of a distribution / wholesale marketplace app. It talks to the
DemoMart backend and shows **synthetic data only**.

- Brand: DemoMart - "Distribution made simple"
- Android application id / namespace: `com.demo.demomart`
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
| Admin       | Admin console (not this app)                       | email `admin@demomart.example` |

Login fields (confirmed from `lib/screens/auth/auth_screen.dart` and
`lib/core/providers/auth_provider.dart`): the app has a single phone + password
form (`POST /auth/login-phone` with `phone`, `password`, `expectedRole` =
`buyer` | `wholesaler`). The role toggle at the top of the form sets
`expectedRole`; choose the toggle that matches the account. Admins do not use
this app.

## What is demo-only / differs from a production app

- No built-in backend URL: it comes only from `--dart-define=API_BASE_URL`.
- Push (Firebase Cloud Messaging) is off until you add your own `google-services.json`
  (see "Push notifications (optional)"); without it, notifications arrive through the
  in-app notification centre (`/notifications/my`) and local notifications.
- No store listings: the mandatory-update check is disabled
  (`AppUpdateService.isEnabled = false`).
- No WhatsApp actions: order receipts are shared through the system share sheet
  and order details can be copied; help screens offer call and e-mail.
- Shared product links use the placeholder host `demo.demomart.example`
  (`lib/core/services/deep_link_service.dart`). The Android intent filter is a
  plain, unverified one (the domain is not real), so there is no verified App
  Link behaviour.
- Generic brand constants live in `lib/core/config/brand_config.dart`; legal
  texts are placeholders (`assets/legal/demo_*.txt`).
- Theme: the design system (`lib/core/theme/app_theme.dart`, `lib/widgets/ui/*`,
  shaders in `shaders/`) uses the platform's leaf-green palette (primary `#1F8A3B`).
- Launcher icons, `assets/images/logo.png` and `assets/images/wholesale_worker.png`
  are simple generated artwork; replace them with real artwork for a real product.
- The old customer "demo mode" wording is "preview mode" (guest preview), so it
  is not confused with the demo environment.

## Push notifications (optional)

Push is implemented (`lib/core/services/firebase_push_service.dart`) but disabled by default.
`main()` calls `FirebasePushService.bootstrap()`; if Firebase cannot initialise (no
`google-services.json`, or `--dart-define=ENABLE_PUSH=false`) the app keeps `NoopPushService`
(`pushServiceProvider`, `lib/core/services/notification_service.dart`) and logs it once in debug.
Nothing else changes and nothing crashes.

To turn it on, follow `../docs/FIREBASE_SETUP.md`: create a Firebase project, add an Android app
with id `com.demo.demomart` and download `google-services.json` into `android/app/`. The file is
gitignored; when it exists the Google services Gradle plugin is applied automatically
(`android/app/build.gradle.kts`), otherwise the build skips it.

What it does: asks for the notification permission through the existing onboarding flow, registers
the FCM token with `POST /notifications/register-token` (retries, refreshes on token rotation) and
unregisters it with `POST /notifications/unregister-token` just before logout. Foreground messages
are shown with `LocalNotificationService`, taps (also from the terminated state) go through
`NotificationNavigationService.handlePayload`, and `firebaseMessagingBackgroundHandler` is the
top-level background entry point. Tokens are printed in debug builds only.

Push data the app reads: `type` (for example `product_launched`, `order_update`,
`negotiation_countered`, `price_change_campaign_*`, `ROLE_UPDATED`) plus `productId`,
`negotiationId`, `orderId`, `effectiveAt`, `title` and `body`.

## Release signing

Release builds use the **debug** signing key so the APK builds out of the box.
For anything you distribute, create your own keystore, keep it outside source
control, add an untracked `android/key.properties`, and change the `release`
build type in `android/app/build.gradle.kts` to use a `signingConfig` that reads
it (see https://docs.flutter.dev/deployment/android#sign-the-app).

## Known limitations

- Some unrouted mock screens (e.g. landing, shipment detail, admin alerts hub)
  still contain generic placeholder text and third-party stock image URLs; they
  are not reachable from the app.
- Product imagery, brands and categories come entirely from the backend seed
  data; generic icon placeholders are used when an image is missing.
- Map tiles use the public OpenStreetMap tile server.
