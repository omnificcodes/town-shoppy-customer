# Building Town Shoppy for the stores

How to produce the Android (`.aab`) and iOS (`.ipa`) store builds from this
repository. Written for whoever does the build, including a team that has
not worked on the app before.

| | |
|---|---|
| App name | Town Shoppy (launcher label: TownShoppy) |
| Android application ID | `com.townshoppy.customer` |
| iOS bundle ID | `com.townshoppy.customer` |
| Version | `version:` in `pubspec.yaml` (`1.0.0+1` = name 1.0.0, build 1) |
| Min Android | 7.0 (API 24) |

## 1. The server address must be passed to every build

**The app has no built-in server address.** Without the flags below it talks
to `http://10.0.2.2:8000`, an Android-emulator-only address, and a store
build made that way installs fine and then cannot sign anyone in.

Pass all four on every release build:

```
--dart-define=APP_ENV=production
--dart-define=API_BASE_URL=https://api.townshoppy.com/api/v1
--dart-define=MERCHANT_WEB_URL=https://app.townshoppy.com
--dart-define=CUSTOMER_WEB_URL=https://customer.townshoppy.com
```

After building, install the build and sign in once before uploading it.

## 2. Android signing (once)

The upload keystore and its passwords are **not** in the repository and must
never be committed (`key.properties`, `*.jks` and `*.keystore` are
git-ignored).

1. Create the upload keystore. The command asks for the passwords; choose
   them yourself and store them in a password manager:

   ```bash
   keytool -genkey -v -keystore android/app/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. Copy `android/key.properties.example` to `android/key.properties` and fill
   in the two passwords.

3. Keep a backup of the `.jks` file and the passwords somewhere safe. With
   Play App Signing enabled (the Play Console default) a lost upload key can
   be reset by Google; without it, a lost key means the app can never be
   updated again.

If `android/key.properties` is missing, a release build is signed with the
debug key and the Play Console rejects it.

## 3. Build

```bash
flutter pub get
```

Android App Bundle (output: `build/app/outputs/bundle/release/app-release.aab`):

```bash
flutter build appbundle --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.townshoppy.com/api/v1 --dart-define=MERCHANT_WEB_URL=https://app.townshoppy.com --dart-define=CUSTOMER_WEB_URL=https://customer.townshoppy.com
```

iOS (needs a Mac, Xcode and the Apple developer team's signing set up in
`ios/Runner.xcworkspace`; output under `build/ios/ipa/`):

```bash
flutter build ipa --release --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.townshoppy.com/api/v1 --dart-define=MERCHANT_WEB_URL=https://app.townshoppy.com --dart-define=CUSTOMER_WEB_URL=https://customer.townshoppy.com
```

For each later release, raise both parts of `version:` in `pubspec.yaml`
first (the number after `+` must increase on every upload).

## 4. Push notifications are not set up yet

The app is written to use Firebase Cloud Messaging, but the Firebase project
files are not in the repository (`android/app/google-services.json`,
`ios/Runner/GoogleService-Info.plist`, and the Google services Gradle
plugin). Until they are added the app runs normally and simply receives no
push notifications. iOS additionally needs the Push Notifications capability
and an APNs key uploaded to Firebase.

## 5. What the store reviewers need

- **Privacy policy:** https://townshoppy.com/privacy-policy/
- **Account deletion (web):** https://townshoppy.com/delete-account/
- **Account deletion (in app):** Profile > Account > Delete account.
- **Test login:** reviewers cannot receive a one-time code, so give them a
  mobile number and password. Create the demo customer on the API server
  (it asks for the password at a hidden prompt):

  ```bash
  php artisan account:make-review-demo 9000000001
  ```

  Run it again if a reviewer deletes the account while testing deletion.

## 6. Permissions the app asks for

Declare these in the stores' privacy forms; each is requested only when the
feature is used.

| Permission | Why |
|---|---|
| Location (while in use) | Shows shops near the customer; shop owners place their shop on a map. Not stored against the customer, no background tracking. |
| Camera | Scans a shop's QR code; shop owners photograph a logo. |
| Photos | Picking a profile photo or shop image. |
| Notifications | Coins, coupons, redemptions and prizes. |
