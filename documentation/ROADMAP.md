# BeneFit — Roadmap (Maßnahmen-Checkliste)

> **Stand:** 2026-06-11 · Kurzfassung von [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md).
> Aufwand: **S** < 1 Tag · **M** 1–3 Tage · **L** ~1 Woche · **XL** > 1 Woche.

## 🔴 Phase 0 — Sofort-Blocker & Fundament

> **Status (2026-06-11):** Phase 0 ✅ **abgeschlossen** — Sofort-Blocker (Branch `chore/phase-0-sofort-blocker`,
> nach `main` gemerged, auf Xiaomi Mi 11 / Android 14 getestet) **und** Fundament (Branch
> `chore/phase-0-foundation`: Error-Handler, Sentry DSN-gated, AppLogger, kuratierte Lints, CI).
> Toolchain auf **Flutter 3.44.1 / Dart 3.12** angehoben. Offen nur noch GPS-Batching (→ Phase 1).

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
- [ ] **(S)** Live-GPS-Writes via `insertBatch()` bündeln *(verschoben → Phase 1, Tracking-Hot-Path)*

Fundament:

- [x] **(S)** Globaler Error-Handler (`FlutterError.onError` + `PlatformDispatcher.onError` + `runZonedGuarded`)
- [x] **(M)** Crash-Reporting (`sentry_flutter`, **DSN-gated**) mit `beforeSend`-PII-Scrubbing *(EU-DSN/DPA/Consent → Go-Live)*
- [x] **(M)** CI (GitHub Actions): Format + `dart analyze lib` (errors-only) + Debug-Build **required**; `flutter analyze`/`flutter test` non-blocking *(fatal-infos + Test-Gate → Phase 1)*
- [x] **(M)** Analyzer kuratiert gehärtet (`avoid_print`, `unawaited_futures`, `avoid_dynamic_calls`, `cast_nullable_to_non_nullable`, …) *(strict-casts/`fatal-infos`/Import-Boundary → Phase 1)*
- [x] **(M)** `AppLogger`-Fassade (`logger`) mit Leveln + Redaction; Hot-Path migriert (169 → 56 debugPrint), Error-Level → Sentry

## 🟠 Phase 1 — Korrektheit, Datenintegrität & Entkopplung

Daten (Reihenfolge beachten!): Schema-Single-Source → Migrationstests → Orphan-Cleanup → FK an.

- [ ] **(S)** Schema-Single-Source-of-Truth (`onCreate` vs `onUpgrade` vereinheitlichen)
- [ ] **(M)** Migrationstests (In-Memory `sqflite_common_ffi`), in CI
- [ ] **(M)** `db.transaction` um Mehrzeilen-Writes + `UNIQUE(users.email)` nach De-Dup
- [ ] **(M)** DI-Naht in jeden Provider; kaputte Provider-Tests reparieren; fehlende Tests ergänzen
- [ ] **(L)** `UserProvider` → `AuthProvider` + `ProfileProvider`; `_pending*` in screen-scoped State
- [ ] **(M)** Typisierte `AppConfig` via `--dart-define-from-file` (dev/staging/prod)
- [ ] **(L)** `go_router` + Redirect-Auth-Guard (`StatefulShellRoute` für 5 Tabs)
- [ ] **(L)** Widget-Test-Layer für kritische Flows (`pump_app.dart`)

## 🟡 Phase 2 — Echtes Backend, Sync & Auth *(der große Schritt)*

- [ ] **(L)** Background-Tracking-Runtime (Android Foreground-Service / iOS `UIBackgroundModes`)
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
- [ ] Store-Policy Background-Location (Play-Deklaration + In-App-Disclosure; iOS „Always"-Rationale)
- [ ] Datenverlust offline-only: Export/Backup, `allowBackup`-Strategie
- [ ] Reward-Integrity / Anti-Cheat (server-seitige Validierung)
- [ ] Akku-Budget (mAh/h-Ziel, adaptive Sampling, Doze/App-Standby-Test)
- [ ] Rollout-Mechanik (Staged Rollout, Force-Update / Min-Version-Gate, API-Versionierung)

## 🚫 Bewusst NICHT (Anti-Over-Engineering)

Kein Riverpod/Bloc · kein get_it/injectable · kein drift/floor (jetzt) · kein mockito+build_runner ·
kein melos-Monorepo · kein auto_route · kein fl_chart/syncfusion · keine 100%-Coverage-Jagd.
