# BeneFit — Roadmap (Maßnahmen-Checkliste)

> **Stand:** 2026-08-28 · **Branch:** `feat/phase-2-background-tracking` · Kurzfassung von [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md).
> Aufwand: **S** < 1 Tag · **M** 1–3 Tage · **L** ~1 Woche · **XL** > 1 Woche.

## 🔴 Phase 0 — Sofort-Blocker & Fundament

> **Status (2026-08-28):** Phase 0 ✅ **und** Phase 1 ✅ **abgeschlossen** (Round 2a/2b/3, Widget-/Integration-
> Test-Layer, Bugfix-Runde `fix/smoke-findings`). **Laufend: Phase 2 — Background-Tracking-Runtime**:
> WP1–WP5 sind im Code, **WP6 (Geräte-Smoke) offen**. — Sofort-Blocker (Branch `chore/phase-0-sofort-blocker`,
> nach `main` gemerged, auf Xiaomi Mi 11 / Android 14 getestet) **und** Fundament (Branch
> `chore/phase-0-foundation`: Error-Handler, Sentry DSN-gated, AppLogger, kuratierte Lints, CI).
> Toolchain auf **Flutter 3.44.1 / Dart 3.12** angehoben. GPS-Batching wurde in Phase 1 / Round 2b nachgezogen.

Tag-1-Blocker (am Code & auf Gerät verifiziert):

- [x] **(S)** Test-Login-Backdoor hinter `kDebugMode` gegatet
- [x] **(S)** Echte Release-Signing-Config (Debug-Fallback + Warnung); Upload-Keystore aktiv
- [x] **(S)** Runner-PNGs (73 MB) → **JPG ~0,95 MB** (kein cwebp → JPG statt WebP) + `cacheWidth`/`ResizeImage`
- [x] **(S)** `PRAGMA foreign_keys = ON` via `onConfigure` + `foreign_key_check`-Logging *(Orphan-Cleanup → Phase 1)*
- [x] **(S)** `created_at`-Überschreiben in `UserDao.update()` gefixt *(Session/Benefit-DAO bereits korrekt)*
- [x] **(S)** PII/Secrets aus Debug-Logs entfernt (Reset-Token, E-Mail, Codes)
- [x] **(S)** Alle direkten Deps gepinnt (Caret + exakte Security-Trias dio/secure_storage/local_auth)
- [x] **(S)** `RepositoryConfig`-Getter typisiert (statt `dynamic`)
- [x] **(S)** Profilbild-Picker auf `maxWidth/maxHeight 512`, `imageQuality 80` begrenzt
- [x] **(—)** Flutter-Toolchain auf 3.44.1 Stable + Dart-Floor `^3.10.0` + Lock aktualisiert
- [x] **(S)** Live-GPS-Writes via `insertBatch()` bündeln *(in Phase 1 / Round 2b umgesetzt — Tracking-Hot-Path)*

Fundament:

- [x] **(S)** Globaler Error-Handler (`FlutterError.onError` + `PlatformDispatcher.onError` + `runZonedGuarded`)
- [x] **(M)** Crash-Reporting (`sentry_flutter`, **DSN-gated**) mit `beforeSend`-PII-Scrubbing *(EU-DSN/DPA/Consent → Go-Live)*
- [x] **(M)** CI (GitHub Actions): Format + `dart analyze lib` + Debug-Build + `flutter test` **required** *(fatal-infos + Test-Gate in Phase 1 nachgezogen — CI läuft jetzt `dart analyze --fatal-infos lib`)*
- [x] **(M)** Analyzer kuratiert gehärtet (`avoid_print`, `unawaited_futures`, `avoid_dynamic_calls`, `cast_nullable_to_non_nullable`, …) *(`strict-casts`/`fatal-infos` in Phase 1 / Round 2b nachgezogen; Import-Boundary weiterhin offen)*
- [x] **(M)** `AppLogger`-Fassade (`logger`) mit Leveln + Redaction; Hot-Path migriert (169 → 56 debugPrint), Error-Level → Sentry

## 🟠 Phase 1 — Korrektheit, Datenintegrität & Entkopplung

> **Foundation-Slice (2026-06-11) ✅ erledigt** auf `chore/phase-1-foundation`: Test-Suite grün
> (Suite mittlerweile **823 Tests**, davon 50 `testWidgets`; 52 Test-Dateien unter `test/` + 1 unter
> `integration_test/`; 0 Failures), CI-`flutter test`-Gate jetzt **required**.
>
> **Round 2a (Phase 1) ✅ erledigt:** Typisierte `AppConfig` (`lib/core/config/app_config.dart`,
> `--dart-define-from-file`); `UserProvider`-Split (`AuthProvider` Identität/Session + `ProfileProvider`
> editierbare Profildaten; `user_provider.dart` gelöscht); durable DB-gestützte Auth
> (`MockAuthService` + `UserRepository.getUserByEmail`) + `deleteUser(id)`.
>
> **Round 2b (Phase 1) ✅ erledigt:** Alle Analyzer-Infos beseitigt; **GPS-DB-Writes gebündelt**
> (`ActivityProvider` puffert Punkte → `GpsPointDao.insertBatch`, Flush bei Pause/Stop/Background);
> Analyzer-Gates gehärtet — `analysis_options.yaml` hat `strict-casts: true`, CI läuft
> `dart analyze --fatal-infos lib`; deprecated `encryptedSharedPreferences` aus dem Secure-Storage entfernt.
>
> **Round 3 (Phase 1) ✅ erledigt:** Navigator 1.0 → **go_router** (`lib/core/router/app_router.dart`,
> `MaterialApp.router`, Redirect-Auth-Gate, `StatefulShellRoute` für die 5 Tabs, Deep-Links über den Router).
>
> **Round 4/5 (Phase 1) ✅ erledigt:** Widget-Test-Layer über den gerouteten Harness
> `test/helpers/app_harness.dart` (50 `testWidgets` in `test/widget/{screens,flows,navigation}`),
> E2E-Smoke `integration_test/app_happy_path_test.dart` + nicht-blockierender Emulator-Workflow,
> sowie die Bugfix-Runde `fix/smoke-findings` (F1 Datumsformat, F5 Custom-Scheme-Deep-Link,
> F6 Biometrie-Erkennung). **Nächste Runde:** Phase 2 / WP6 — Geräte-Smoke der Background-Tracking-Runtime.

- [x] **(S)** Schema-Single-Source-of-Truth (`onCreate` ruft idempotenten v11-Creator; Duplikat entfernt)
- [x] **(M)** Migrationstests (In-Memory `sqflite_common_ffi`), in CI (fresh==upgraded, v12, FK-Check)
- [x] **(M)** `db.transaction` (`finalizeSession`) + v12 Orphan-Cleanup + Email-Dedup + `UNIQUE(users.email)`
- [x] **(M)** DI-Nähte (ActivityProvider userId, HealthSyncService, ProgressProvider-Ctor); 23+3 kaputte Tests repariert
- [x] **(S)** Live-GPS-Writes via `insertBatch()` bündeln *(✅ Round 2b: `ActivityProvider` puffert Punkte, Flush bei Pause/Stop/Background)*
- [x] **(L)** `UserProvider` → `AuthProvider` + `ProfileProvider` *(✅ Round 2a: Split umgesetzt — `AuthProvider` besitzt Identität/Session, `ProfileProvider` die editierbaren Profildaten; `_pending*` → screen-scoped State; `user_provider.dart` gelöscht)*
- [x] **(M)** Typisierte `AppConfig` via `--dart-define-from-file` (dev/staging/prod) *(✅ Round 2a: `lib/core/config/app_config.dart`, release-sichere Defaults)*
- [x] **(L)** `go_router` + Redirect-Auth-Guard (`StatefulShellRoute` für 5 Tabs) *(✅ Round 3: `lib/core/router/app_router.dart`, `MaterialApp.router`, Deep-Links über den Router)*
- [x] **(L)** Widget-/Integration-Test-Layer für kritische Flows *(✅ Round 4/5: umgesetzt über den neuen Harness `test/helpers/app_harness.dart`; das ältere `test/helpers/pump_app.dart` blieb ungenutzt und sollte gelöscht werden. 50 `testWidgets` in `test/widget/{screens,flows,navigation}`)*
- [x] **(M)** E2E-Smoke auf Android-Emulator (`integration_test/app_happy_path_test.dart`: Cold-Start → Login → Home-Tabs) über `.github/workflows/e2e.yml` — bewusst **nicht-blockierend** (nur `push: main` + `workflow_dispatch`, api-level 34, `profile: pixel_6`), weil der Emulator-Job ~8–12 min braucht und gelegentlich flaky ist. Blockierendes Gate bleibt `ci.yml`.
- [x] **(S)** `strict-casts`/`fatal-infos` + Info-Backlog aufräumen → `dart analyze --fatal-infos lib` required *(✅ Round 2b)*

## 🔧 Geräte-Smoke-Findings (Runde `fix/smoke-findings`, PR #9 / `cec0879`)

Befunde aus dem manuellen Geräte-Smoke (Xiaomi Mi 11 / Android 14, 2026-06-12).
Detail-Checkliste: [DEVICE_SMOKE_CHECKLIST.md](DEVICE_SMOKE_CHECKLIST.md) ·
offene Punkte laufen im [Backlog](../Backlog.md) weiter.

- [x] **F1** Session-Detail zeigt `dd.MM.yyyy, HH:mm` statt `DateTime.toString()` — `session_detail_screen.dart:132`, `6157ca6` *(auf Gerät verifiziert)*
- [x] **F5** Custom-Scheme-Deep-Link `benefit://reset-password?token=…` wird auf `/reset-password` gemappt — `customSchemeRedirect()` in `app_router.dart:54`, 7 Unit-Tests, `f66fe50` *(warm + cold auf Gerät verifiziert)*
- [x] **F6** Biometrie wird auf Android erkannt (`strong`/`weak` → fingerprint, `FlutterFragmentActivity`, `USE_BIOMETRIC`) — `biometric_service.dart:105`, `96d8cd2` *(auf Gerät verifiziert)*
- [ ] **F3** Device-Pairing prüft die Berechtigungen nach Rückkehr aus den Systemeinstellungen nicht erneut → bleibt bei „connection failed"
- [ ] **F4** BLE-Pairing an OS / Health Connect delegieren statt eigenem `flutter_blue_plus`-Scan *(Entscheidung getroffen; ersetzt den Custom-Flow und erledigt F3 mit — aufgeschoben, bis ein Testgerät verfügbar ist)*

## 🟡 Phase 2 — Echtes Backend, Sync & Auth *(der große Schritt)*

> ⚠️ **Offen am Branch `feat/phase-2-background-tracking` (2026-08-28):** das CI-Gate
> `dart format --set-exit-if-changed` ist **rot** — 3 Dateien aus den WP3/WP5-Commits sind
> unformatiert (`lib/presentation/screens/activity/activity_screen.dart`,
> `lib/providers/activity_provider.dart`, `test/unit/providers/activity_provider_test.dart`).
> `dart analyze --fatal-infos lib`, `flutter test` (823/823) und `flutter build apk --debug` sind grün.

- [ ] **(L)** Background-Tracking-Runtime — **Phase A ✅ im Code** (WP1–WP5: Manifest/Plist, `GpsSensor.buildLocationSettings` + `ForegroundNotificationConfig`, Permission-Flow inkl. `POST_NOTIFICATIONS`, Dauer aus Timestamps, Buffer-Bound 5 Punkte / 60 s); **offen: WP6 Geräte-Smoke**. Bewusste Grenze von Phase A: kein Background-Isolate → überlebt keinen Process-Kill. · [Fahrplan](sessions/BACKGROUND_TRACKING_PLAN.md)
- [ ] **(L)** Sync funktionsfähig: `SyncManager` + `SyncQueueDao` (Drain/Backoff/Dead-Letter) **oder** Sync-Engine
- [ ] **(Spike)** Backend-Entscheidung: PowerSync/Supabase vs. PostgREST → **Decision-Record** (Schritt 3)
- [ ] **(M)** Versionierte, idempotente Konfliktauflösung; Benefits als append-only Ledger
- [ ] **(L)** Echte Auth: `RealAuthService`/`ApiClient`/`AuthInterceptor` + SPKI-Pins; server-seitiges Argon2id; Token-Rotation
- [ ] **(M)** Sync-Observability + Remote-Kill-Switch vor Go-Live

## ⚪ Phase 3 — Modernisierung, Scale & Rollout-Reife

- [ ] **(S)** i18n-Gerüst (`flutter_localizations` + `l10n.yaml` + leere `.arb`) — Extraktion deferred
- [ ] **(L)** Build-Flavors (dev/staging/prod) + CD (fastlane/Actions)
- [ ] **(L)** Theming-Single-Source (Tokens, Dark Mode) + Accessibility-Baseline
- [ ] **(M)** GPS-Retention (`deleteOlderThan` + VACUUM) + Polyline-Vereinfachung
- [ ] **(L)** Feature-Konsolidierung (presentation/providers → `features/<x>/`) — opportunistisch, P2/P3
- [ ] **(S, vor Go-Live)** **Sentry scharf schalten** — EU-Sentry-Projekt anlegen → EU-DSN per `--dart-define=SENTRY_DSN=…` (+ `SENTRY_ENV`) im Release/CD-Build setzen, Test-Event verifizieren. Plumbing steht (Phase 0, DSN-gated). **Voraussetzung:** DPA mit Sentry + Datenschutzerklärungs-Eintrag + Consent-/berechtigtes-Interesse-Entscheidung (Art. 9) — siehe „Übergreifende Lücken".

## ⚖️ Übergreifende Lücken (Owner zuweisen — Launch-relevant)

- [ ] DSGVO/Art. 9: Consent für GPS+HR, Datenexport, server-seitige Löschpropagierung, Datenschutzerklärung
- [ ] Store-Policy Background-Location (Play-Deklaration + In-App-Disclosure; iOS „Always"-Rationale) — **jetzt akut**, weil der Foreground-Service seit Phase 2 / WP1+WP2 aktiv ist; `ACCESS_BACKGROUND_LOCATION` wird bewusst **nicht** angefordert (`AndroidManifest.xml:22`), was die Deklaration vereinfacht, die In-App-Disclosure aber nicht ersetzt
- [ ] Datenverlust offline-only: Export/Backup, `allowBackup`-Strategie
- [ ] Reward-Integrity / Anti-Cheat (server-seitige Validierung)
- [ ] Akku-Budget (mAh/h-Ziel, adaptive Sampling, Doze/App-Standby-Test)
- [ ] Rollout-Mechanik (Staged Rollout, Force-Update / Min-Version-Gate, API-Versionierung)

## 🚫 Bewusst NICHT (Anti-Over-Engineering)

Kein Riverpod/Bloc · kein get_it/injectable · kein drift/floor (jetzt) · kein mockito+build_runner ·
kein melos-Monorepo · kein auto_route · kein fl_chart/syncfusion · keine 100%-Coverage-Jagd.
