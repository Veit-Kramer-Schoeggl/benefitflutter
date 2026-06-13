# Device Smoke Checklist

Manual on-device smoke tests for changes from Phase 1 rounds 2a / 2b / 3 and Phase 2
(background-tracking runtime), collected so they can be walked through in one pass on a
physical device (reference: Xiaomi Mi 11, Android 14). Run a **debug** build
(`flutter install` re-seeds the DB: `test@gmail.com` / `1234`, `test2@gmail.com` / `1234`).

**Legend:** ✅ done/confirmed · 🟡 partially verified (logic covered by tests / automated
boot smoke, full UI flow not yet hand-ticked) · ⬜ pending

---

## Phase 2 — Background-Tracking-Runtime *(WP1–WP2 im Code, on-device noch offen)*

> Voraussetzung: echtes Gerät (Xiaomi Mi 11 / Android 14) — im Emulator/Unit-Test ist nur die
> Settings-Konstruktion prüfbar. Detail-Fahrplan: [sessions/BACKGROUND_TRACKING_PLAN.md](sessions/BACKGROUND_TRACKING_PLAN.md).
> Einige Punkte werden erst durch **WP3** (Permission-Flow) testbar.

### Foreground-Service / GPS im Hintergrund (WP2)
- [ ] ⬜ **GPS läuft im Hintergrund weiter (Kern):** Session starten → App in den Hintergrund / Display sperren → ~5–10 min bewegen → zurück/Stop → Route & Distanz vollständig, keine Lücke. *(geolocator-Foreground-Service)*
- [ ] ⬜ **Foreground-Notification:** während aktiver Session erscheint die dauerhafte „BeneFit — Recording your activity session…"-Notification (nicht wegwischbar, `setOngoing`); verschwindet bei Stop.
- [ ] ⬜ **Logcat FGS-Typ:** beim Session-Start KEINE `MissingForegroundServiceTypeException` / „FGS type not allowed" (Android 14+, targetSdk 36).
- [ ] ⬜ **Display aus / Wakelock:** bei gesperrtem Display sampelt GPS weiter (kein Einfrieren bis zum Aufwecken).
- [ ] ⬜ **Phase-A-Grenze (erwartet, kein Bug):** App aus den Recents wischen → Tracking endet (kein Background-Isolate); App-Neustart verhält sich sauber (Session nicht korrupt).
- [ ] ⬜ **OEM-Batterie (MIUI):** beobachten, ob MIUI den Prozess trotz FGS killt → ggf. Whitelisting-Hinweis nötig (Phase-2-Folgepunkt).

### Permissions (WP3 — erst nach Umsetzung testbar)
- [ ] ⬜ **Location „while in use" reicht:** erste Session promptet Standort; „Beim Verwenden der App erlauben" genügt fürs Hintergrund-Tracking (kein „Immer" nötig).
- [ ] ⬜ **POST_NOTIFICATIONS (Android 13+):** erste Session promptet Benachrichtigungs-Permission; bei Ablehnung zeichnet der FGS weiter auf (Notification unsichtbar) — Verhalten beobachten.
- [ ] ⬜ **System-Ortung aus:** mit deaktivierter Geräte-Ortung → klare Fehlermeldung beim Start, kein Crash.

---

## Round 3 — go_router migration

### Auth gate / routing
- [x] ✅ **Cold start, unauthenticated** → splash loader → lands on `/login` (no flash of home). *(automated smoke 2026-06-11)*
- [x] ✅ **Login → home** (`test@gmail.com`/`1234`) → `/home/activity`, Activity tab active, 5-tab bottom bar. *(automated smoke)*
- [x] ✅ **Tab switch → Progress** triggers `ProgressProvider.loadActivities()` reload. *(automated smoke — log "Loaded 6 total sessions")*
- [ ] ⬜ **Cold start, authenticated** (after a prior login, app killed & relaunched) → splash → `/home/activity` directly (auto-login, no `/login` flash).
- [ ] ⬜ **All 5 tabs** (Community / Progress / Activity / Benefit / Profile) render; per-tab scroll/state preserved when switching back.
- [ ] ⬜ **Android back button:** from a full-screen push → returns to the correct tab; on `/home/*` → exits the app (no back to `/login`).
- [ ] ⬜ **Unknown route** → `errorBuilder` shows splash (and logs `Router: unknown route …`).

### Full-screen pushes (must cover the bottom bar; back returns correctly)
- [ ] ⬜ **Session detail:** Progress → tap an activity → `/session/:id` (covers bottom bar) → back → Progress tab.
- [ ] ⬜ **Device connection:** from Activity (heart-rate tap) **and** from Profile (Connected Devices) → `/device-connection` → back.
- [ ] ⬜ **Device pairing return:** Device connection → pair → `/device-pairing` → complete (pops `true`) → device list reloads.
- [ ] ⬜ **Benefit QR:** Benefit tab → tap a **redeemed** benefit → `/benefit-qr` shows the correct benefit (`extra` VM). *(On a process-kill restore the screen shows the graceful "could not be loaded" fallback, not a crash.)*

### Auth flows
- [ ] ⬜ **Register → verify → home:** register → "Continue to Verification" → `/verify` → enter code → `/home/activity`.
- [ ] ⬜ **Verify guard:** reach `/verify` with no pending registration → bounces to `/register`.
- [ ] ⬜ **Forgot → reset → login:** Login → Forgot Password → submit → `/reset-password` → reset → "Sign In" → `/login`.
- [ ] ⬜ **Reset guard:** `/reset-password` with no pending reset and no token → bounces to `/forgot-password`.
- [ ] ⬜ **Deep-link reset (warm):** app running → open `benefit://reset-password?token=XXX` → reset screen with code prefilled, NOT bounced.
- [ ] ⬜ **Deep-link reset (cold):** app terminated → open the link → app launches → after init lands on reset with token prefilled *(the cold-start buffering race — verify carefully)*.
- [ ] ⬜ **Logout:** Profile → logout → `/login`; back doesn't return to home.
- [ ] ⬜ **App-lock → password:** background/foreground to trigger lock → `AppLockScreen` overlays (even over a pushed screen) → choose password path → forced logout → `/login` (no ghost dialogs left over).

---

## Round 2b — quick wins

- [ ] ⬜ **GPS batching:** start an activity, move so > 10 GPS points accumulate → Pause (flush) → Resume → Stop → open the session detail/map: the route/distance is complete (no lost points). *(Logic covered by 7 unit tests via the real GPS stream.)*
- [x] ✅ **Secure-storage cipher migration:** after removing the deprecated `encryptedSharedPreferences`, the app boots and migrates (`RSA18 → AES_GCM_NoPadding`) without crashing or losing the session. *(confirmed via logcat 2026-06-11)*

---

## Round 2a — providers split & durable auth

- [x] ✅ **Password change is durable:** change password → log out → log in with the **new** password (and the old one is rejected) — survives an app restart. *(confirmed by user 2026-06-11; also covered by unit tests)*
- [x] ✅ **App boots cleanly** after the AuthProvider/ProfileProvider split (clean cold start → login). *(confirmed)*
- [ ] 🟡 **Profile edit syncs identity:** edit name/biometrics/preferences → Save → values persist after reload (exercises `ProfileProvider` → `AuthProvider.setCurrentUser`). *(unit-tested; quick UI re-confirm welcome.)*
- [ ] 🟡 **Account deletion (2-step):** request → confirm with code → account removed → `/login`; deletes the **authenticated** user by id. *(unit-tested; UI flow re-confirm welcome.)*
- [ ] 🟡 **Registered user survives restart:** register + verify a new account → kill app → log in with the new credentials (validates the `verifyEmail` password-hash fix). *(unit-tested.)*
