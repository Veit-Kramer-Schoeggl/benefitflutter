# Device Smoke Checklist

Manual on-device smoke tests for changes from Phase 1 rounds 2a / 2b / 3 and Phase 2
(background-tracking runtime), collected so they can be walked through in one pass on a
physical device (reference: Xiaomi Mi 11, Android 14). Run a **debug** build
(`flutter install` re-seeds the DB: `test@gmail.com` / `1234`, `test2@gmail.com` / `1234`).

**Legend:** ✅ done/confirmed · 🟡 partially verified (logic covered by tests / automated
boot smoke, full UI flow not yet hand-ticked) · ⬜ pending

**Last updated:** 2026-08-28 · branch `feat/phase-2-background-tracking`. Smoke findings from the
2026-06-12 device pass are tracked in [ROADMAP.md](ROADMAP.md) → "Geräte-Smoke-Findings"
(F1/F5/F6 fixed and merged in PR #9 / `cec0879`; **F3 and F4 are still open**).

---

## Phase 2 — Background-Tracking-Runtime *(WP1–WP5 im Code, on-device noch offen — WP6)*

> Voraussetzung: echtes Gerät (Xiaomi Mi 11 / Android 14) — im Emulator/Unit-Test ist nur die
> Settings-Konstruktion prüfbar. Detail-Fahrplan: [sessions/BACKGROUND_TRACKING_PLAN.md](sessions/BACKGROUND_TRACKING_PLAN.md).
> **Stand 2026-08-28:** WP1–WP5 sind auf `feat/phase-2-background-tracking` committet; WP3
> (Permission-Flow) ist umgesetzt, alle Punkte unten sind damit testbar. Nur der
> `ensureNotificationPermission`-Pfad ist ausschließlich per Geräte-Smoke abgedeckt.

### Foreground-Service / GPS im Hintergrund (WP2)
- [ ] ⬜ **GPS läuft im Hintergrund weiter (Kern):** Session starten → App in den Hintergrund / Display sperren → ~5–10 min bewegen → zurück/Stop → Route & Distanz vollständig, keine Lücke. *(geolocator-Foreground-Service)*
- [ ] ⬜ **Foreground-Notification:** während aktiver Session erscheint die dauerhafte „BeneFit — Recording your activity session…"-Notification (nicht wegwischbar, `setOngoing`); verschwindet bei Stop.
- [ ] ⬜ **Logcat FGS-Typ:** beim Session-Start KEINE `MissingForegroundServiceTypeException` / „FGS type not allowed" (Android 14+, targetSdk 36).
- [ ] ⬜ **Display aus / Wakelock:** bei gesperrtem Display sampelt GPS weiter (kein Einfrieren bis zum Aufwecken).
- [ ] ⬜ **Dauer korrekt nach Hintergrund (WP4):** Session starten → mehrere Minuten Hintergrund/Display aus → zurück → angezeigte **und** gespeicherte Dauer = reale aktive Zeit (kein Untercount durch gedrosselten Timer); eine Pause zählt nicht mit.
- [ ] ⬜ **Phase-A-Grenze (erwartet, kein Bug):** App aus den Recents wischen → Tracking endet (kein Background-Isolate); App-Neustart verhält sich sauber (Session nicht korrupt).
- [ ] ⬜ **Buffer-Verlust begrenzt (WP5):** Session starten, ~2 min bewegen → App hart killen (`adb shell am force-stop us.benefit4.benefitflutter`) → Session-Detail öffnen: es fehlen höchstens die letzten **4 Punkte bzw. 60 s** (der Flush feuert, sobald der 5. Punkt eintrifft) (`_gpsBatchSize = 5`, `_maxBufferAge = 60 s`, punkt-getriggerter Alters-Flush in `_onGpsPoint` — kein Hintergrund-Timer). *(Logik durch Unit-Tests abgedeckt: `test/unit/providers/activity_provider_test.dart:250` (7 Batching-Tests) + `:449` (Staleness).)*
- [ ] ⬜ **OEM-Batterie (MIUI):** beobachten, ob MIUI den Prozess trotz FGS killt → ggf. Whitelisting-Hinweis nötig (Phase-2-Folgepunkt).

### Permissions (WP3 — implementiert, Geräte-Verifikation offen)
- [ ] ⬜ **Location „while in use" reicht:** erste Session promptet Standort; „Beim Verwenden der App erlauben" genügt fürs Hintergrund-Tracking (kein „Immer" nötig).
- [ ] ⬜ **POST_NOTIFICATIONS (Android 13+):** erste Session promptet Benachrichtigungs-Permission; bei Ablehnung zeichnet der FGS weiter auf (Notification unsichtbar) — Verhalten beobachten.
- [ ] ⬜ **System-Ortung aus:** mit deaktivierter Geräte-Ortung → klare Fehlermeldung beim Start, kein Crash.

---

## Round 3 — go_router migration

### Auth gate / routing
- [x] ✅ **Cold start, unauthenticated** → splash loader → lands on `/login` (no flash of home). *(automated smoke 2026-06-11)*
- [x] ✅ **Login → home** (`test@gmail.com`/`1234`) → `/home/activity`, Activity tab active, 5-tab bottom bar. *(automated smoke)*
- [x] ✅ **Tab switch → Progress** triggers `ProgressProvider.loadActivities()` reload. *(automated smoke — log "Loaded 6 total sessions")*
- [ ] 🟡 **Cold start, authenticated** (after a prior login, app killed & relaunched) → splash → `/home/activity` directly (auto-login, no `/login` flash). *(Widget test: `test/widget/navigation/auth_redirect_test.dart:19`.)*
- [ ] 🟡 **All 5 tabs** (Community / Progress / Activity / Benefit / Profile) render; per-tab scroll/state preserved when switching back. *(Tab switching: `test/widget/navigation/tab_navigation_test.dart:11,20`; E2E: `integration_test/app_happy_path_test.dart:32`.)*
- [ ] ⬜ **Android back button:** from a full-screen push → returns to the correct tab; on `/home/*` → exits the app (no back to `/login`).
- [ ] ⬜ **Unknown route** → `errorBuilder` shows splash (and logs `Router: unknown route …`).

### Full-screen pushes (must cover the bottom bar; back returns correctly)
- [ ] 🟡 **Session detail:** Progress → tap an activity → `/session/:id` (covers bottom bar) → back → Progress tab. *(4 widget tests incl. the F1 date format: `test/widget/screens/session_detail_screen_test.dart:75,91,104,119`; F1 fix `6157ca6`, confirmed on device. Only the push/back gesture path is left to hand-tick.)*
- [ ] ⬜ **Device connection:** from Activity (heart-rate tap) **and** from Profile (Connected Devices) → `/device-connection` → back.
- [ ] ⬜ **Device pairing return:** Device connection → pair → `/device-pairing` → complete (pops `true`) → device list reloads. *(⚠️ Known open finding **F3**: after the user grants the permissions, the flow does not re-check them on return → it keeps showing "connection failed". Deliberately not fixed on its own — decision **F4**: delegate pairing to the OS / Health Connect and replace the `flutter_blue_plus` scan, which removes this flow. Until F4 lands, this item and the "Device connection" item above cannot be usefully ticked.)*
- [ ] 🟡 **Benefit QR:** Benefit tab → tap a **redeemed** benefit → `/benefit-qr` shows the correct benefit (`extra` VM). *(On a process-kill restore the screen shows the graceful "could not be loaded" fallback, not a crash — fallback covered by `test/widget/screens/benefit_qr_screen_test.dart:74`.)*

### Auth flows
- [ ] 🟡 **Register → verify → home:** register → "Continue to Verification" → `/verify` → enter code → `/home/activity`. *(`test/widget/flows/register_verify_test.dart:12`.)*
- [ ] 🟡 **Verify guard:** reach `/verify` with no pending registration → bounces to `/register`. *(`test/widget/flows/register_verify_test.dart:201`.)*
- [ ] 🟡 **Forgot → reset → login:** Login → Forgot Password → submit → `/reset-password` → reset → "Sign In" → `/login`. *(`test/widget/flows/forgot_reset_test.dart:11`.)*
- [ ] 🟡 **Reset guard:** `/reset-password` with no pending reset and no token → bounces to `/forgot-password`. *(`test/widget/flows/forgot_reset_test.dart:82`.)*
- [x] ✅ **Deep-link reset (warm):** app running → open `benefit://reset-password?token=XXX` → reset screen with code prefilled, NOT bounced. *(Was smoke finding **F5**: go_router also received the raw URI, did not match it and fell through to `errorBuilder`/splash — the app hung on "Loading…". Fixed by `customSchemeRedirect()` at the very top of the redirect (`lib/core/router/app_router.dart:54,73`), 7 unit tests in `test/unit/router/deep_link_redirect_test.dart`; PR #9 / `cec0879`, re-verified on device.)*
- [x] ✅ **Deep-link reset (cold):** app terminated → open the link → app launches → after init lands on reset with token prefilled. *(Verified on device in the same F5 round. The canonical cold-start path stays `DeepLinkHandler`'s buffered replay — the `!auth.isInitialized` → `/splash` gate in `app_router.dart:79-81` overrides the redirect on a cold start.)*
- [ ] 🟡 **Logout:** Profile → logout → `/login`; back doesn't return to home. *(`test/widget/navigation/auth_redirect_test.dart:27`.)*
- [ ] 🟡 **App-lock → password:** background/foreground to trigger lock → `AppLockScreen` overlays (even over a pushed screen) → choose password path → forced logout → `/login` (no ghost dialogs left over). *(Prerequisite was **F6**: the biometric card was hidden on MIUI so app-lock could not be enabled at all — fixed in `96d8cd2` (`strong`/`weak` → fingerprint in `biometric_service.dart:105`, `FlutterFragmentActivity`, `USE_BIOMETRIC`) and verified on device. The password-fallback path itself is still not hand-ticked.)*

---

## Round 2b — quick wins

- [ ] ⬜ **GPS batching:** start an activity, move so > 5 GPS points accumulate (batch size is 5 since WP5) → Pause (flush) → Resume → Stop → open the session detail/map: the route/distance is complete (no lost points). *(Logic covered by 7 batching unit tests + 1 staleness test (WP5) over the real GPS stream — `test/unit/providers/activity_provider_test.dart:250,449`.)*
- [x] ✅ **Secure-storage cipher migration:** after removing the deprecated `encryptedSharedPreferences`, the app boots and migrates (`RSA18 → AES_GCM_NoPadding`) without crashing or losing the session. *(confirmed via logcat 2026-06-11)*

---

## Round 2a — providers split & durable auth

- [x] ✅ **Password change is durable:** change password → log out → log in with the **new** password (and the old one is rejected) — survives an app restart. *(confirmed by user 2026-06-11; also covered by unit tests)*
- [x] ✅ **App boots cleanly** after the AuthProvider/ProfileProvider split (clean cold start → login). *(confirmed)*
- [ ] 🟡 **Profile edit syncs identity:** edit name/biometrics/preferences → Save → values persist after reload (exercises `ProfileProvider` → `AuthProvider.setCurrentUser`). *(unit-tested; quick UI re-confirm welcome.)*
- [ ] 🟡 **Account deletion (2-step):** request → confirm with code → account removed → `/login`; deletes the **authenticated** user by id. *(unit-tested; UI flow re-confirm welcome.)*
- [ ] 🟡 **Registered user survives restart:** register + verify a new account → kill app → log in with the new credentials (validates the `verifyEmail` password-hash fix). *(unit-tested.)*
