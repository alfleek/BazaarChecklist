# Skill: run-app

Launch the BazaarChecklist Flutter app on the Android emulator (or another target).

---

## How to invoke

`/run-app` — boot the Android emulator (if needed) and launch the app
`/run-app android` — same as above (explicit)
`/run-app windows` — run as a Windows desktop app (no emulator needed, fastest)
`/run-app chrome` — run as a web app in Chrome

---

## Available devices (no setup needed)

| Target | Device ID | Notes |
|---|---|---|
| Android emulator | `emulator-5554` (when running) | AVD: `Medium_Phone_API_36.1` (Android 16) |
| Windows desktop | `windows` | Fastest; no emulator boot time |
| Chrome | `chrome` | Web mode |

---

## Step 1 — Pick a target

If the user didn't specify, ask:
- Android emulator
- Windows desktop
- Chrome

---

## Step 2 — Boot the emulator (Android only)

Check if the emulator is already running:

```powershell
flutter devices
```

If `emulator-5554` is **not** listed:

```powershell
flutter emulators --launch Medium_Phone_API_36.1
```

Then poll until it appears (runs from repo root or anywhere with Flutter in PATH):

```powershell
$timeout = 120; $elapsed = 0
do {
  Start-Sleep 5; $elapsed += 5
  $devices = flutter devices 2>&1
  $ready = $devices -match "emulator-5554"
  Write-Output "[$elapsed s] waiting..."
} while (-not $ready -and $elapsed -lt $timeout)
```

---

## Step 3 — Run the app

Run from `mobile/`:

```powershell
Set-Location "C:\Users\lewis\Code\BazaarChecklist\mobile"
flutter run -d <device-id>
```

Where `<device-id>` is:
- `emulator-5554` for Android
- `windows` for Windows desktop
- `chrome` for web

Run this **in the background** so the session stays responsive. The first build takes ~100s (Gradle); subsequent runs are fast.

### Expected successful output

```
√ Built build\app\outputs\flutter-apk\app-debug.apk
Installing ...
Flutter run key commands.
  r Hot reload.
  R Hot restart.
  q Quit.
A Dart VM Service on ... is available at: http://127.0.0.1:...
```

Firebase Auth notifying id token listeners confirms the app reached the authenticated screen.

---

## Known warnings (non-fatal, ignore)

- `UnityVersionFallbackWarning` — from the Python pipeline, not the Flutter app
- `GoogleApiManager: Failed to get service from broker` — Play Services quirk on API 36 stock emulator; Firebase Auth still works
- `Skipped N frames` on first launch — GC warm-up, clears after a few seconds
- `ProviderInstaller: Failed to load providerinstaller module` — non-fatal on emulator

---

## Hot reload / restart

Once the app is running (flutter run is active in a terminal), use:
- `r` — hot reload (preserves state, applies widget/code changes instantly)
- `R` — hot restart (clears state, full re-init)
- `q` — quit

These only work in an interactive terminal running `flutter run`. From Claude Code, use:

```powershell
# Trigger hot reload via Dart VM service (if devtools URL is known)
# Otherwise just re-run the flutter run command — APK is already built
```

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `flutter: command not found` | Flutter not in PATH — open a terminal that has Flutter configured |
| Emulator never appears in `flutter devices` | Open Android Studio → Device Manager → start `Medium Phone API 36.1` manually |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Run `flutter clean` then retry |
| App crashes immediately | Check `flutter run` output for Dart exceptions; run `flutter analyze` from `mobile/` |
| White/blank screen on launch | Firebase not initialized — check `google-services.json` is present in `mobile/android/app/` |
