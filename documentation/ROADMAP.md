# BeneFit — Roadmap (Maßnahmen-Checkliste)

> **Stand:** 2026-06-11 · Kurzfassung von [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md).
> Aufwand: **S** < 1 Tag · **M** 1–3 Tage · **L** ~1 Woche · **XL** > 1 Woche.

## 🔴 Phase 0 — Sofort-Blocker & Fundament *(zuerst)*

Tag-1-Blocker (alle am Code verifiziert):

- [ ] **(S)** Test-Login-Backdoor gaten/entfernen — `login_screen.dart:514-524` (hinter `kDebugMode`)
- [ ] **(S)** Echte Release-Signing-Config — `android/app/build.gradle.kts:37` (kein Debug-Key)
- [ ] **(S)** Runner-PNGs (73 MB) → ~1080px WebP + `cacheWidth/cacheHeight` bei `Image.asset`
- [ ] **(S)** `PRAGMA foreign_keys = ON` via `onConfigure` (+ einmaliger Orphan-Cleanup)
- [ ] **(S)** `created_at`-Überschreiben bei `update()` fixen (User/Session/Benefit-DAO)
- [ ] **(S)** PII/Secrets aus Logs entfernen (Reset-Token, E-Mail, Reset-Code, Hash)
- [ ] **(S)** Alle Deps auf Caret-Ranges pinnen (aus `pubspec.lock`), Lock committed lassen
- [ ] **(S)** `RepositoryConfig`-Getter typisieren (statt `dynamic`)
- [ ] **(S)** Live-GPS-Writes via `insertBatch()` bündeln; Per-Emission-`debugPrint` entfernen
- [ ] **(S)** Profilbild-Picker auf `maxWidth/maxHeight 512`, `imageQuality 80` begrenzen

Fundament:

- [ ] **(S)** Globaler Error-Handler (`FlutterError.onError` + `PlatformDispatcher.onError` + `runZonedGuarded`)
- [ ] **(M)** Crash-Reporting (`sentry_flutter`) mit `beforeSend`-PII-Scrubbing
- [ ] **(M)** CI (GitHub Actions): format, `analyze --fatal-infos`, `test --coverage`, Build — required
- [ ] **(M)** Analyzer härten (`strict-casts`/`strict-raw-types`, `avoid_print`, Import-Boundary-Lints)
- [ ] **(M)** `AppLogger`-Fassade (`logger`) mit Leveln + Redaction; Error-Level → Sentry

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
