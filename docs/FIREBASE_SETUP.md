# Firebase push setup (optional)

Push notifications are **off** in the demo until you connect your own Firebase project.
Everything keeps working without it: the app, the admin panel and the backend build and run
with no Firebase files, and notifications still arrive in the in-app notification centre.

This guide creates a new, separate Firebase project for the demo and connects three parts:

| Part | What it needs | Where it goes |
|------|---------------|---------------|
| Android app (push to phones) | `google-services.json` | `app/android/app/google-services.json` |
| Admin panel (browser alerts) | 7 web keys, `NEXT_PUBLIC_FIREBASE_*` | `admin/.env.local` |
| Backend (sends the pushes) | service account values + project id | `backend/.env` |

Use a project that has nothing to do with any real customer. Android package name: `com.demo.demomart`.

## 1. Create the Firebase project

1. Open <https://console.firebase.google.com> and sign in with your own Google account.
2. **Create a project** (or **Add project**). Pick a name such as `demomart-demo`. Note the
   **Project ID** shown under the name (for example `demomart-demo-4f2a`). You need it three times.
3. Google Analytics is not needed: turn it off.
4. Cloud Messaging (FCM) is on by default. If **Project settings > Cloud Messaging** shows the
   "Firebase Cloud Messaging API (V1)" as disabled, enable it there.

## 2. Android app: `google-services.json`

1. **Project settings** (gear icon) > **General** > **Your apps** > **Add app** > Android.
2. **Android package name:** `com.demo.demomart` (exactly). Nickname is optional. SHA-1 is not
   needed for push.
3. Register the app, then **Download google-services.json**.
4. Put the file at `app/android/app/google-services.json` (next to `app/android/app/build.gradle.kts`).
   It is gitignored. Skip the console's "Add Firebase SDK" steps: the project already has them.
5. Build and run as usual:

   ```bash
   cd app
   flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:5050/api/v1
   ```

   When the file exists the Google services Gradle plugin is applied automatically and push starts
   at launch. Delete the file (and rebuild) to turn push off again. To keep the file but force push
   off, add `--dart-define=ENABLE_PUSH=false`.

## 3. Admin panel: browser alerts

1. **Project settings > General > Your apps > Add app > Web** (`</>`). Nickname `demomart-admin`.
   Skip Firebase Hosting. Register the app.
2. The console shows a `firebaseConfig` object. Copy its values into `admin/.env.local`
   (create the file; it is gitignored):

   ```bash
   NEXT_PUBLIC_FIREBASE_API_KEY=<apiKey>
   NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=<authDomain>
   NEXT_PUBLIC_FIREBASE_PROJECT_ID=<projectId>
   NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=<storageBucket>
   NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=<messagingSenderId>
   NEXT_PUBLIC_FIREBASE_APP_ID=<appId>
   NEXT_PUBLIC_FIREBASE_VAPID_KEY=<see next step>
   ```

3. **Project settings > Cloud Messaging > Web configuration > Web Push certificates >
   Generate key pair.** Copy the **public key** into `NEXT_PUBLIC_FIREBASE_VAPID_KEY`.
4. Restart the admin panel (`npm run dev`, or `npm run build` for a production build). This
   regenerates `public/sw.js` (the service worker that receives alerts while the tab is closed)
   from those values. With these variables empty, `sw.js` is the plain offline-shell worker with
   no Firebase code, and the Notifications page says "Browser alerts are not configured for this
   environment".
5. Browser alerts need a secure context: `http://localhost` is fine, any other host needs HTTPS.

## 4. Backend: service account and project id

1. **Project settings > Service accounts > Generate new private key.** A JSON file downloads.
   Keep it **outside the repository** (it is a secret) or delete it after copying the values.
2. Open `backend/.env` and set (names are in `backend/.env.example`):

   ```bash
   DEMO_FIREBASE_PROJECT_ID=<project_id from the JSON>
   FIREBASE_PROJECT_ID=<the same project_id>
   FIREBASE_CLIENT_EMAIL=<client_email from the JSON>
   FIREBASE_PRIVATE_KEY="<private_key from the JSON, on one line, newlines written as \n>"
   FIREBASE_STORAGE_BUCKET=            # optional, leave empty
   ```

   `FIREBASE_PRIVATE_KEY` goes on a single line with the line breaks written as `\n`, exactly as it
   appears in the JSON file. Wrapping it in double quotes is fine.
3. Demo mode refuses to start the backend unless `FIREBASE_PROJECT_ID` is set and **equals**
   `DEMO_FIREBASE_PROJECT_ID`, the service account e-mail belongs to that project
   (`...@<project id>.iam.gserviceaccount.com`), and no Firebase value contains one of the production
   markers listed in `backend/src/config/demoGuard.js`. A mismatch prints the reason and exits.
4. Restart the backend. If you see "Firebase credentials not configured" the values were not
   picked up; "Firebase initialized successfully" means they were.

## 5. Test it

1. Start MongoDB, the backend, the admin panel, and install the debug APK on an emulator
   (an image with Google Play services / "Google APIs") or a phone.
2. In the app, sign in as the wholesaler (`9000000002`, password in the README) and allow
   notifications when asked (Android 13+ shows a permission prompt on first launch).
   In the debug console look for `[FCM] Token registered with backend`.
3. Open a **Coming Soon** product and tap **Notify me**.
4. In the admin panel open the product (Products > edit) and switch **Coming Soon** off and save. That
   launches it and sends "now available" to everyone who tapped Notify me.
5. A push arrives on the device (in the foreground it appears as a local notification, in the
   background as a system notification). Tapping it opens the product page.
6. Browser alerts: in the admin panel open **Notifications**, click **Enable alerts** and allow the
   browser prompt. Then place an order from the app (cart > place order). Close the admin tab or
   switch away: a browser alert "New order" appears; clicking it opens the panel. The choice is
   remembered per admin (`adminPushWanted:<userId>`) and restored silently after the next sign-in.

If nothing arrives: check the backend log (`No FCM tokens found for user ...` means the device never
registered; `FCM delivery failed ...` shows the Firebase error), confirm the package name is
`com.demo.demomart`, and that the emulator has Google Play services and internet access.

## Never commit these

All are covered by `.gitignore`, but check `git status` before committing:

- `app/android/app/google-services.json` and any `GoogleService-Info.plist` / `*.plist`
- the service account JSON you downloaded (`*-firebase-adminsdk-*.json`) and anything containing
  `FIREBASE_PRIVATE_KEY`
- `backend/.env`, `admin/.env.local` and any other `.env*` file except the `.env.example` files
- `admin/public/sw.js` (generated; it embeds your web config)
