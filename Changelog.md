# Changelog

> **Stand:** 2026-08-28 · **Branch:** `feat/phase-2-background-tracking` · Ergänzt
> [documentation/ROADMAP.md](documentation/ROADMAP.md) (Maßnahmen), [Backlog.md](Backlog.md) (offene Punkte)
> und [documentation/ARCHITECTURE_REVIEW.md](documentation/ARCHITECTURE_REVIEW.md) (Befunde).

Alle nennenswerten Änderungen an der BeneFit-Flutter-App.

Das Format folgt den Konventionen von [Keep a Changelog](https://keepachangelog.com/de/1.1.0/), die
Versionierung orientiert sich an [Semantic Versioning](https://semver.org/lang/de/). Die
Abschnittsüberschriften (`Added`, `Changed`, `Fixed`, `Removed`, `Security`, `Performance`, `Docs`,
`Build`, `Tests`) bleiben bewusst in der englischen Keep-a-Changelog-Schreibweise, die Einträge sind
deutsch.

**Hinweis zur Rekonstruktion.** Diese Datei entstand nachträglich am 2026-08-28. Das Repository enthält
**keine Git-Tags**, und `pubspec.yaml` steht durchgehend — auch auf dem aktuellen Branch-Tip — auf
`1.0.0+1`. Die Versionsnummern unten sind daher aus der Git-Historie (92 Commits, verteilt auf vier
Arbeitstage) rekonstruierte Gliederungshilfen und kein bereits gelebtes Release-Schema. Die
**Einzelhistorie vor 1.0.0 existiert in diesem Repository nicht**: Der komplette Prototyp bis zur
Award-Einreichung wurde beim Umzug ins neue Repository zu einem einzigen Squash-Commit (`6c900c6`)
verdichtet und ist deshalb als ein Block beschrieben. Jeder Eintrag nennt in Klammern die
Commit-Kurz-Hashes, über die er nachprüfbar ist (`git show <hash>`).

---

## [Unreleased]

**Phase 2 — Background-Tracking-Runtime, WP1–WP5** · Branch `feat/phase-2-background-tracking`
(2026-06-13, 8 Commits) · ⚠️ **Noch nicht nach `main` gemergt** — es existiert bisher kein Pull Request;
`main` steht unverändert auf 1.8.0 (`9fd1a87`).

**Offen:** WP6a (Unit-Tests + Smoke-Checkliste) ist erledigt, **WP6b — der Geräte-Smoke auf echtem Gerät
(Xiaomi Mi 11 / Android 14) inklusive Logcat-Prüfung des Foreground-Service-Typs — ist noch offen**. Siehe
[documentation/sessions/BACKGROUND_TRACKING_PLAN.md](documentation/sessions/BACKGROUND_TRACKING_PLAN.md)
und [documentation/DEVICE_SMOKE_CHECKLIST.md](documentation/DEVICE_SMOKE_CHECKLIST.md).

**Abgrenzung:** Alle Arbeitspakete beschränken sich auf **Phase A** (aktive, nutzergestartete Sessions).
`ACCESS_BACKGROUND_LOCATION`, der zweistufige „Immer erlauben"-Dialog und die Session-Wiederaufnahme nach
einem harten OS-Kill sind bewusst auf **Phase B** (`continuousDaily`) vertagt.

### Added
- **WP1 — Natives Fundament für Hintergrund-Tracking.** Android deklariert jetzt `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_LOCATION` (ab targetSdk 36 zwingend, sonst wirft `startForeground`),
  `POST_NOTIFICATIONS` und `WAKE_LOCK`; iOS erhält `UIBackgroundModes: [location]`, ohne das geolocator im
  Hintergrund stillschweigend keine Positionen liefert, sowie präzisere Standort-Begründungstexte
  (App-Store-Richtlinie 2.5.4). (`728f73c`)
- **WP2 — Das Tracking läuft weiter, wenn die App in den Hintergrund geht.** `GpsSensor` verwendet
  plattformspezifische Einstellungen statt eines einfachen `LocationSettings`: Android `AndroidSettings`
  mit `ForegroundNotificationConfig` und Wakelock, iOS `AppleSettings` mit
  `allowBackgroundLocationUpdates`, `activityType: fitness` und Hintergrund-Standortindikator. Die
  Einstellungen entstehen in der reinen, testbaren Funktion
  `GpsSensor.buildLocationSettings(platform, trackingMode)`; die `TrackingMode`-Naht für Phase B (gröberer
  50-m-Filter) ist bereits durchgereicht, ohne das generische `BaseSensor`-Interface zu belasten.
  (`75743f7`)
- **WP3 — Berechtigungsfluss geschlossen.** `GpsSensor.ensureNotificationPermission()` fragt auf
  Android 13+ vor dem Streamstart `POST_NOTIFICATIONS` an (best effort, blockiert das Tracking nie), damit
  die Dienstbenachrichtigung sichtbar ist. GPS-Probleme (Standort aus, verweigert, dauerhaft verweigert)
  erscheinen über den neuen Kanal `gpsStartWarning` / `gpsNeedsSettings` als SnackBar mit
  „Einstellungen öffnen" plus dauerhaftem Hinweisbanner — statt wie bisher als bildschirmfüllender Fehler;
  die Session läuft ohne Distanz sichtbar weiter. `retryGpsIfNeeded()` nimmt das GPS beim Zurückkehren in
  die App automatisch wieder auf. (`1ef548f`)

### Removed
- **WP1 —** `ACCESS_BACKGROUND_LOCATION` entfernt (auskommentiert dokumentiert): Aktive Sessions starten
  den Standort-Vordergrunddienst noch im Vordergrund, daher genügt „während der Nutzung". Das erspart die
  gesonderte Hintergrundstandort-Prüfung von Google Play. (`728f73c`)

### Fixed
- **WP4 — Die Sessiondauer stimmt nach Hintergrundphasen.** Statt eines vom Betriebssystem gedrosselten
  1-Sekunden-Zählers wird die aktive Dauer aus UTC-Zeitstempeln abgeleitet (abgeschlossene Segmente plus
  laufendes Segment) und korrigiert sich beim nächsten Auslesen selbst; Pausen bleiben wie bisher
  ausgenommen, der Timer treibt nur noch die Anzeige. Injizierbare Uhr für deterministische Tests.
  (`457c253`)

### Performance
- **WP5 — Weniger GPS-Verlust bei hartem Beenden durch das Betriebssystem.** Die Schreib-Charge sinkt von
  10 auf 5 Punkte, und ein Alterscheck leert den Puffer, sobald er älter als 60 Sekunden ist — geprüft
  beim Eintreffen eines Punktes, weil Dart-Timer im Hintergrund gedrosselt werden. (`fd7dfc1`)

### Docs
- Lebender Umsetzungsplan `documentation/sessions/BACKGROUND_TRACKING_PLAN.md` (Status quo, verifizierte
  Befunde, Abgleich mit SESSION_DESIGN/SESSION_PLAN, Arbeitspakete WP1–WP6, Entscheidungslog) sowie die
  zugehörigen Gerätetests für Hintergrund-GPS, Dienstbenachrichtigung, FGS-Typ im Logcat, Wakelock,
  App-Wisch-Grenze, OEM-Akkusparmodus und die WP3-Berechtigungswege. (`614b87c`, `0db8bf7`, `3e0c371`)

### Tests
- Unit-Tests für den `LocationSettings`-Builder (Plattform-Branch), den GPS-Warnkanal, die
  timestampbasierte Dauer und den Puffer-Alters-Flush. Suite von 813 auf **823 Tests** gewachsen
  (`75743f7` 817 → `1ef548f` 820 → `457c253` 822 → `fd7dfc1` 823).

### Verifizierter Stand (2026-08-28)
| Prüfung | Ergebnis |
| --- | --- |
| `flutter test` | ✅ 823 Tests grün (52 Testdateien unter `test/`, 1 unter `integration_test/`) |
| `dart analyze --fatal-infos lib` | ✅ sauber |
| `flutter build apk --debug` | ✅ erfolgreich |
| Zeilenabdeckung | 48,1 % (4396/9130) bei Neugenerierung — das eingecheckte `coverage/lcov.info` ist ein veraltetes, gitignoriertes Artefakt |
| `dart format --set-exit-if-changed` (CI-Gate) | 🔴 **rot** — 3 Dateien aus den WP3-/WP5-Commits; vor dem Merge zu beheben |
| Codebasis | Schema-Version 12, 16 Tabellen, 141 Dart-Dateien in `lib/`, ~30 691 Zeilen |

---

## 1.8.0 - 2026-06-12 — End-to-End-Tests auf dem Emulator

Stand von `main` (PR #14, #15).

### Changed
- Das private `_bootstrap()` in `main.dart` heißt jetzt öffentlich `bootstrap()`, damit
  Integrationstests die echte App in der eigenen Zone des Test-Bindings starten können; die
  `integration_test`-Dependency kam dazu. Reine Umbenennung ohne Verhaltensänderung. (`411d600`)

### Fixed
- Der Login-Screen bricht auf schmalen Displays nicht mehr um 2,9 px über: Die
  „Create Account"-Zeile ist jetzt ein `Wrap` statt einer `Row` — eine echte
  Robustheitsverbesserung für kleine Geräte, nicht nur eine Emulator-Kosmetik. (`09dbdd7`)

### Tests
- Erster echter End-to-End-Test über `app.bootstrap()`: Kaltstart → Splash → Login mit dem geseedeten
  Konto → Home → alle Tabs der unteren Navigation, mit echtem SQLite, echten Providern und echtem Router.
  Der Session-Detail-Screen bleibt ausgespart, weil dessen Karte OSM-Kacheln nachlädt. (`13623e8`)

### Build
- Eigener, **nicht blockierender** GitHub-Actions-Workflow `e2e.yml` führt die Integrationstests auf einem
  Android-Emulator aus (API 34, Pixel-6-Profil) — nur bei Push auf `main` und manuell, damit langsame und
  gelegentlich flakige Läufe keine Pull Requests blockieren. (`4d1398f`, `09dbdd7`, `4071ccf`, `9fd1a87`)

---

## 1.7.0 - 2026-06-12 — Widget-Test-Schicht und Behebung der Geräte-Smoke-Funde

Runden 4–7 (PR #7–#13). *Reihenfolge-Hinweis: PR #8 (Auth-Flow-Tests) erscheint im Log nach PR #9
(Smoke-Fixes), weil der Auth-Branch vor dem eigenen Merge noch `main` hereingezogen hat.*

### Fixed
- Das Startdatum im Session-Detail wird als `dd.MM.yyyy, HH:mm` angezeigt statt als roher Zeitstempel mit
  Sekunden und Millisekunden (**Smoke-Fund F1**). (`6157ca6`)
- Passwort-Reset per Deep Link funktioniert wieder (**Smoke-Fund F5**): Die rohe
  `benefit://reset-password?token=…`-URI konnte von go_router nicht zugeordnet werden, landete im
  Fehler-Builder und ließ die App auf „Loading…" hängen. Ein `customSchemeRedirect()` ganz oben in der
  Router-Weiche bildet das Custom-Schema jetzt auf `/reset-password` ab. (`f66fe50`)
- Die Biometrie-/App-Sperre-Karte im Profil erscheint auf Android-Geräten mit hinterlegtem Fingerabdruck
  wieder (**Smoke-Fund F6**, Xiaomi/MIUI): Android meldet häufig die generischen Typen `strong`/`weak`,
  die bisher weggefiltert wurden. Zusätzlich läuft `MainActivity` nun als `FlutterFragmentActivity`
  (Voraussetzung für den `local_auth`-Dialog), und die `USE_BIOMETRIC`-Berechtigung ist deklariert.
  (`96d8cd2`, `cec0879`)

### Changed
- `SessionDetailScreen` testbar gemacht: optionale Konstruktor-Parameter für Repository, `GpsPointDao` und
  `TileProvider` mit Produktions-Defaults — kein Verhaltensunterschied im Produktionspfad.
  (`05ed891`, `778f4a1`)

### Tests
- **Test-Fundament:** gemeinsame Fakes unter `test/helpers/` (Session, Benefit, Health, neu Connectivity
  und Biometrie) sowie ein `pumpApp`-Harness, das die vollständige geroutete App mit echtem go_router und
  allen 8 Providern startet — komplett ohne SQLite und Plattformkanäle, inklusive `pumpUntilFound` mit
  hartem Limit, gesäten Sessions und gemockten SharedPreferences.
  (`392531a`, `bbe7ec3`, `63c5598`, `834118e`, `9ae00d2`)
- **Routing und Auth-Wege:** Kaltstart nicht angemeldet → Login, angemeldet → Home, Logout zur Laufzeit →
  Login, Tab-Wechsel, Login-Screen und Splash. (`7eae4f2`)
- **Vollständige Auth-Flows:** Registrierung → Verifizierung → Home, Passwort-vergessen → Zurücksetzen →
  Login, Routen-Guards ohne ausstehende Registrierung/Reset, Deep-Link-Token-Vorbefüllung über `extra` und
  `?token=` sowie Fehlerfälle. (`4f78608`, `d997c2c`, `86febb0`, `9ef50de`)
- **Feature-Screens:** Community (statische Abschnitte), Benefit (leer / Erfolg / Fehler / QR-Öffnung),
  Benefit-QR (Code, Titel, Betrag, Partnerstandorte, Fallback), Progress (beide Tabs, Statistikkarten,
  gesäte Session mit Navigation ins Detail) und Activity (Lebenszyklus idle → tracking → pausiert → Stopp,
  Offline-Anzeige). (`0edb293`, `8682d93`, `eb260e2`, `c5235b8`, `3b23dba`, `f2e8104`, `862579a`)
- **Session-Detail:** inklusive Regressionsschutz für das F1-Datumsformat, „zu wenig GPS-Daten",
  Kartendarstellung ab 2 Punkten und Fehlerzustand. (`18b85d2`)
- **Profil-Screen:** Abschnittsdarstellung, Biometrie-Karte samt Umschalten der App-Sperre,
  Geschlechtsauswahl, Einstellungsdialog, Passwortwechsel-Validierung, zweistufige Kontolöschung und
  Abmelden. (`1698a58`, `c8d5a2a`)
- Suite in dieser Welle von 756 auf 813 Tests gewachsen.

---

## 1.6.0 - 2026-06-11 — Migration auf go_router und Repo-Aufräumen

Phase 1 / Runde 3 (PR #5, PR #6).

### Changed
- **Navigation vollständig auf `go_router` umgestellt:** deklarativer Routenbaum mit zentraler
  Auth-Weiche (nicht angemeldet → `/login`, angemeldet auf `/login` → `/home`), `StatefulShellRoute` für
  die fünf Tabs und eigene Vollbildrouten für Session-Detail, Geräteverbindung, Geräte-Pairing und
  Benefit-QR. Alle 13 benannten Routen und 5 imperativen Pushes migriert, der globale `navigatorKey`
  entfiel, der Splash ist reiner Lader (die ~500 ms „Welcome back"-Pause entfällt) und das
  Deep-Link-Token wird außerhalb der URL übergeben. (`0861220`, `bec95a1`, `d63138d`)

### Removed
- Der Ordner `pma_junior_award/` (Award-Einreichung, kein Code) wurde aus der Versionskontrolle genommen
  und gitignoriert — er war über ein `*.md`-Add-Glob versehentlich mitcommittet worden. Die Dateien
  bleiben auf der Platte. (`d67e21e`, `cb18dac`)

### Docs
- Gesamte Dokumentation gegen den Code nach den Runden 2a/2b/3 abgeglichen (go_router,
  Provider-Aufteilung, dauerhafte Authentifizierung, GPS-Batching, DB v12, strengere Lint-Gates) und
  `documentation/DEVICE_SMOKE_CHECKLIST.md` mit den manuellen Gerätetests ergänzt. (`11cc5b2`, `d75f351`)

---

## 1.5.0 - 2026-06-11 — Lint-Backlog geleert, GPS-Schreib-Batching, strengere Gates

Phase 1 / Runde 2b (PR #4). *PR #3 fehlt in der Nummerierung — offenbar ohne Merge geschlossen.*

### Performance
- GPS-Punkte werden während des Trackings gepuffert und gebündelt geschrieben (`insertBatch`, damals
  Schwelle 10) statt einzeln pro Punkt. Geleert wird beim Pausieren, Stoppen und beim Wechsel in den
  Hintergrund, sodass ein hartes Beenden durch das Betriebssystem höchstens eine Teilcharge verliert.
  Distanz und Anzeige lesen weiterhin den In-Memory-Puffer und bleiben unverändert. (`109598a`)

### Fixed
- Alle 34 verbliebenen Analyzer-Hinweise verhaltensneutral bereinigt: 10 Fire-and-Forget-Futures explizit
  als `unawaited` markiert (der Hintergrund-Sync loggt Fehler jetzt, statt sie zu schlucken), 14
  `BuildContext`-Zugriffe nach `await` abgesichert, 7 dynamische Zugriffe typisiert und das veraltete
  `encryptedSharedPreferences`-Flag entfernt. (`6e183cb`)

### Build
- Analyzer-Gates verschärft: `strict-casts` aktiviert und `--fatal-infos` erzwungen, damit auch Hinweise
  die CI brechen. (`a47b9c4`, `ab40bd8`)

---

## 1.4.0 - 2026-06-11 — Typisierte Konfiguration, Provider-Aufteilung, dauerhafte Anmeldung

Phase 1 / Runde 2a (PR #2).

### Added
- Typisierte Deploy-Konfiguration `AppConfig` über `--dart-define-from-file` (API-Basis-URL, Certificate
  Pinning, Seeding, HTTP-Logging, Sentry-DSN und -Umgebung) mit release-sicheren Vorgaben (Pinning an,
  Seeding aus, Logging aus) und den Profilen `config/dev.json`, `config/staging.json` und
  `config/prod.example.json`. (`dcfe8ba`)

### Changed
- Der 894-zeilige `UserProvider` wurde in **`AuthProvider`** (Identität, Login/Logout, Registrierung,
  Passwort-Reset, Kontolöschung, Rate-Limiting) und **`ProfileProvider`** (bearbeitbare Profildaten,
  Biometrie, Einstellungen) aufgeteilt; alle 9 Auth-Screens migriert, Verhalten unverändert.
  (`283f558`, `e07c010`)

### Fixed
- **Passwortänderungen überleben jetzt einen Neustart:** Login, Passwortwechsel und Passwort-Reset laufen
  gegen die dauerhafte SQLite-Nutzertabelle statt gegen flüchtige In-Memory-Maps. Vorher galt nach einem
  Neustart wieder das alte Passwort, zurückgesetzte Passwörter waren vergessen, frisch registrierte Konten
  meldeten „Kein Konto gefunden", und gelöschte Testkonten tauchten wieder auf. (`798ce8b`)
- Die Kontolöschung entfernt zwingend das angemeldete Konto (`deleteUser(userId)` statt `findFirst`) — bei
  mehreren Nutzerzeilen konnte zuvor das falsche Konto gelöscht werden. (`1f60bc0`)

### Tests
- 39 neue Tests für die Provider-Aufteilung, Gesamtsuite von 689 auf 749 gewachsen.
  (`283f558`, `798ce8b`)

---

## 1.3.0 - 2026-06-11 — Phase 1: Testreparatur, DI-Nahtstellen, Datenintegrität

Foundation Slice (PR #1, Branch `chore/phase-1-foundation`).

### Added
- **Datenbank-Migration auf Schema v12:** verwaiste Kindsätze aus der Zeit ohne Fremdschlüssel-Erzwingung
  werden gelöscht, doppelte Konten werden per E-Mail zusammengeführt (Sessions und Benefits wandern zum
  jüngsten Konto, statt verloren zu gehen), und ein UNIQUE-Index auf E-Mail verhindert künftige Dubletten.
  (`0c7b770`)

### Fixed
- **Session-Abschluss ist jetzt atomar:** Session-Zeile und Sensor-Zusammenfassung werden in einer
  einzigen Transaktion geschrieben (`SessionRepository.finalizeSession`), die Netzwerksynchronisation
  läuft erst nach dem dauerhaften Commit. Bei Fehlern bleibt die Session aktiv, statt fälschlich als
  „gestoppt" zu gelten. (`7d78aa5`)
- Frisch angelegte und migrierte Datenbanken erzeugen jetzt identische v11-Tabellen — die doppelt
  gepflegte Definition der Continuous-Tracking-Tabellen wurde auf eine idempotente Quelle reduziert.
  (`b8bf009`)
- Dependency-Injection-Nahtstellen ergänzt, damit Provider ohne Plattformkanäle testbar sind:
  `ActivityProvider.userId` als optionaler Konstruktor-Parameter, `HealthSyncService` injizierbar und der
  `ProgressProvider`-Konstruktor frei von asynchronen Seiteneffekten (Laden über `initialize()` bzw.
  `updateUserId`). (`43d82b9`, `f1eafe0`, `3df985e`)

### Tests
- **Migrations-Harness** auf Basis von `sqflite_common_ffi`: prüft, dass ein frischer `onCreate` das
  vollständige 16-Tabellen-Schema mit aktivierten Fremdschlüsseln und ohne Waisen erzeugt und dass ein
  simuliertes Upgrade dasselbe Ergebnis liefert; neuer Seam `DatabaseHelper.openAppDatabase(factory, path)`.
  (`c443f4a`)
- **Testsuite repariert und grün gestellt (689 Tests):** gemeinsamer `flutter_secure_storage`-10.x-Mock
  statt zweier veralteter Kopien (~14 Compile-Fehler), `ActivityProvider`-Tests über den neuen
  `userId`-Konstruktor, `BenefitProvider`-Tests an die argumentlose API angeglichen und
  `HealthPlatformProvider`-Tests durch einen Fake host-unabhängig gemacht.
  (`126da2c`, `79f9119`, `6f3464b`, `f1b614c`)

### Build
- `flutter test` ist ab jetzt ein Pflicht-Gate in der CI — Format, Analyze, Test und Build sind alle
  verpflichtend. (`543b0f3`, `92818ff`)

---

## 1.2.0 - 2026-06-11 — Phase 0: Logging, Observability, Lint-Gates und CI

Branch `chore/phase-0-foundation` — per Fast-forward ohne Pull Request nach `main` gebracht.

### Added
- Zentrale Logging-Fassade **`AppLogger`** (`lib/core/logging/app_logger.dart`) mit den Stufen
  `d`/`i`/`w`/`e`: In Release entfallen Debug und Info, Warnungen und Fehler bleiben; ein `redact()`-Netz
  entfernt E-Mails, Bearer-Token, `key=value`-Secrets und GPS-Koordinaten. Neue Dependency
  `logger ^2.7.0`. (`6ccb6de`)
- **Globaler Fehler-Handler:** Der App-Start läuft in `runZonedGuarded`, `FlutterError.onError` und
  `platformDispatcher.onError` landen im `AppLogger`, und in Release erscheint statt des roten
  Fehlerbildschirms eine freundliche Ersatzansicht. (`1665b04`)
- **Crash-Reporting** mit `sentry_flutter ^8.14.2`, nur aktiv wenn `--dart-define=SENTRY_DSN` gesetzt ist
  (`sendDefaultPii: false`, `tracesSampleRate: 0.0`, `beforeSend`-Scrubbing über `AppLogger.redact`).
  Ohne DSN wird nichts gesendet — DSGVO-sicher für Entwicklung und CI. (`c9fb2c9`)

### Changed
- ~112 `debugPrint`-Aufrufe in den Hot-Path-Providern (Activity, User, AppLock, Progress) auf `AppLogger`
  umgestellt: 80 Debug-Meldungen entfallen in Release, 32 Fehler gehen an Sentry, GPS-Koordinaten werden
  automatisch redigiert. (`b85c4e8`)
- Analyzer verschärft: `avoid_print`, `avoid_dynamic_calls`, `cast_nullable_to_non_nullable`,
  `unawaited_futures`, `prefer_final_locals` und `require_trailing_commas` zusätzlich zu `flutter_lints`;
  32 Befunde automatisch behoben, 34 als dokumentiertes Phase-1-Backlog offen gelassen. (`5c865b0`)
- Einheitliche Formatierung über `lib` und `test` (`dart format`, 135 Dateien) sowie `dart fix`
  (13 Korrekturen: `withOpacity` → `withValues`, `activeColor` → `activeThumbColor`, ungenutzte Importe)
  als Voraussetzung für das CI-Format-Gate. (`9f0bb90`, `e13a7e1`)

### Build
- **GitHub-Actions-Qualitäts-Gate** (Flutter 3.44.1) eingeführt: Format-Prüfung, `dart analyze lib` (nur
  Fehler) und Debug-Build sind Pflicht; `flutter analyze` und `flutter test` laufen zunächst
  nicht-blockierend. (`479b978`)

### Docs
- Sentry-Go-Live-Aufgabe für Phase 3 in der Roadmap verankert (EU-Projekt anlegen, DSN aktivieren,
  Testevent — abhängig von AVV, Datenschutzerklärung und Art.-9-Einwilligung). (`ca025c8`)

---

## 1.1.0 - 2026-06-11 — Phase 0: Sofort-Blocker

Sicherheits-, Daten- und Build-Blocker vor jeder Veröffentlichung. Branch
`chore/phase-0-sofort-blocker` — per Fast-forward ohne Pull Request nach `main` gebracht, auf
Xiaomi Mi 11 / Android 14 verifiziert.

### Security
- Test-Zugangsdaten („test@gmail.com / 1234") auf dem Login-Screen sind nur noch in Debug-Builds sichtbar
  statt für alle Nutzer. (`825bc0e`)
- Personenbezogene Daten und Geheimnisse aus den Logs entfernt: Reset-Token, E-Mail-Adressen sowie
  Verifizierungs-, Lösch- und Reset-Codes werden nur noch als Vorhanden-Marker geloggt. `debugPrint` wird
  in Release nicht entfernt — es handelte sich um ein echtes DSGVO-Leck. (`15ace32`)

### Fixed
- Profil-Updates setzen das Anlagedatum des Kontos nicht mehr zurück — `created_at` wird beim Update nicht
  mehr überschrieben. (`a48e953`)
- **Fremdschlüssel werden in SQLite jetzt tatsächlich erzwungen** (`PRAGMA foreign_keys` in
  `onConfigure`); bisher war jedes `ON DELETE CASCADE` wirkungslos und Löschvorgänge hinterließen
  verwaiste Datensätze. Zusätzlich ein einmaliger, nicht-fataler `foreign_key_check` mit Logging bereits
  bestehender Waisen. (`c2b1204`)

### Changed
- Der Composition Root gibt statt `dynamic` jetzt die Repository-Interfaces (`SessionRepository`,
  `UserRepository`, `BenefitRepository`) zurück — falsch verdrahtete Repositories scheitern zur Compile-
  statt zur Laufzeit. (`4701cca`)

### Performance
- Läuferfotos von PNG auf ~1440-px-JPG (Qualität 82) reduziert — die Assets schrumpfen von 73 MB auf
  ~0,95 MB (**−72 MB**). (`abe97e3`)
- Bilddekodierung begrenzt (`cacheWidth` 1080 an den vier Community-Render-Stellen, Profilbild-Picker auf
  512 px / Qualität 80) — verhindert Out-of-Memory auf schwächeren Geräten. (`1507c08`)

### Build
- Alle 25 von 28 unbeschränkten Dependencies (`any`) auf Caret-Ranges festgezurrt; die
  sicherheitskritischen Pakete `dio`, `flutter_secure_storage` und `local_auth` exakt gepinnt.
  (`f75b887`)
- **Release-Signierung** ergänzt: eigener `signingConfig` aus der gitignorierten
  `android/key.properties` mit lauter Warnung und Debug-Fallback plus Template mit keytool-Anleitung.
  Vorher wurden Release-Builds mit dem Debug-Keystore signiert und waren nicht veröffentlichbar.
  (`d14a481`)
- Toolchain auf Flutter 3.44.1 / Dart 3.12.1 gehoben, die Dart-Untergrenze korrekt auf `^3.10.0` gesetzt
  und die Gradle-Kompatibilitätsflags des 3.44-Migrators übernommen. (`b6fd361`)

### Docs
- Architektur-Review und Roadmap ergänzt, die zweischichtige Code-Dokumentation nach einem
  Kongruenz-Audit mit der Implementierung synchronisiert und der Phase-0-Fortschritt samt
  Toolchain-Upgrade nachgezogen. (`bbfbfd5`, `0dd4e8f`, `028f675`)

---

## 1.0.0 - 2026-02-25 — Projektabschluss / Stand der Award-Einreichung

**Dies ist die Version, auf der die Einreichung zum pma junior award 2026 beruht.** Sie wird hier
ausdrücklich benannt, weil dieser Changelog neben der Award-Dokumentation gelesen wird: Alles, was in der
Einreichung beschrieben ist, entspricht diesem Stand — die gesamte Härtungsarbeit ab 1.1.0 (Juni 2026)
ist **nach** der Einreichung entstanden.

Technisch existiert dieser Stand als ein einziger Squash-Commit `6c900c6` („First commit in new repo",
378 Dateien: 137 Dart-Dateien unter `lib/`, 31 Unit-Testdateien, 32 Markdown-Dokumente, 26 Assets).
`pubspec.yaml` stand bereits auf `1.0.0+1`, das SQLite-Schema auf **v11 mit 16 Tabellen**, alle 28 direkten
Dependencies noch auf `any`. Die Einzelhistorie davor existiert in diesem Repository nicht.

### Added
- Offline-First-App **BeneFit** mit fünf Haupt-Tabs (Activity, Progress, Benefit, Profile, Community),
  feature-modularem Aufbau (`lib/features/{auth,benefit,security,session,shared,user,wearable_integration}`)
  mit Domain-/Data-Trennung, DAO- und Repository-Schicht hinter Interfaces, `RepositoryConfig` als
  Composition Root, Provider/`ChangeNotifier` als State-Management und Navigator-1.0-Routing über benannte
  Routen.
- Lokale SQLite-Datenbank, Schema v11 mit 16 Tabellen (`users`, `user_biometrics_reported`,
  `user_preferences`, `sessions`, `gps_points`, `activity_segments`, `continuous_tracking_config`,
  `continuous_tracking_state`, `benefits`, `user_benefits`, `wearable_devices`,
  `session_biometric_data`, `session_motion_data`, `session_sensor_summary`, `health_platform_data`,
  `sync_queue`) samt Migrationspfad v1 → v11.
- GPS-Bewegungstracking mit Start/Pause/Stop-Sessions, Distanzberechnung, Session-Zusammenfassung und
  Kartenansicht der gelaufenen Route im Session-Detail (`flutter_map` + `latlong2`).
- Zwei Tracking-Modi als Enum-Naht angelegt: `manual` (nutzergestartete Workout-Session,
  Sekunden-Auflösung) und `continuousDaily` (automatische Tagessession, ~10-Minuten-Auflösung) inklusive
  `ActivitySegment`-Persistenz.
- 12 Aktivitätsarten (running, walking, cycling, swimming, strengthTraining, yoga, hiking, trailRunning,
  dancing, martialArts, teamSports, other) mit JSON-Serialisierung und Anzeigenamen.
- Wearable-Integration: Health-Connect-/HealthKit-Sync (`health`), direkte BLE-Herzfrequenzmessung
  (`flutter_blue_plus`) sowie Geräte-Pairing- und Verbindungs-Screens mit Live-Herzfrequenzanzeige.
- Benefit-System: verdiente Benefits, Partnerübersicht, Gesamtersparnis-Karte und
  QR-Einlösecode-Screen (`qr_flutter`).
- Vollständiger Authentifizierungs-Flow gegen einen Mock-Auth-Service: Registrierung,
  E-Mail-Verifizierung per 6-stelligem Code, Login, Passwort-Vergessen/Zurücksetzen via Deep Link
  (`app_links`, Schema `benefit://`), Passwortwechsel und zweistufige Kontolöschung.
- Sicherheitsschicht: biometrische App-Sperre (`local_auth`), Session-Timeout, Rate-Limiting für
  Login-Versuche, Certificate Pinning, Passwort-Hashing (`crypto`) und JWT-Ablage in
  `flutter_secure_storage`.
- Offline-First-Synchronisation über eine `sync_queue`-Tabelle, feature-spezifische Sync-Strategien
  (User/Session/Benefit) und Connectivity-Erkennung (`connectivity_plus`).
- Progress-Screen mit Statistik- und Aktivitäten-Tab (eigene Charts), Profil-Screen mit Bild-Upload
  (`image_picker`) sowie statischer Community-Screen.
- Debug-Seeding der Demo-Daten (zwei Testkonten `test@gmail.com` / `test2@gmail.com`, 4 Benefits,
  User-Benefits) für die Award-Präsentation, über `kDebugMode` gesteuert.

### Tests
- 31 Unit-Testdateien für Domain-Modelle, Auth-Ergebnistypen, Passwortvalidierung, Konfigurationen,
  `SensorManager`, Sync-Strategien und drei Provider.

### Docs
- Zweischichtige Projektdokumentation mit 32 Markdown-Dateien: technische Docs direkt neben dem Code plus
  `documentation/`-Overviews inklusive SESSION_DESIGN und SESSION_PLAN.

### Build
- Android-Build mit adaptivem Launcher-Icon (Markengrün `#78BA3F`), iOS-Runner-Projekt und 26
  Asset-Dateien (Logos, Hintergründe, Icons, Läuferfotos).

### Bekannte Schwachstellen dieses Stands
Der Prototyp trug die Lasten, die die Juni-Arbeit ab 1.1.0 adressiert hat: unbeschränkte Dependencies,
kein `PRAGMA foreign_keys` (alle CASCADE-Regeln wirkungslos), Test-Zugangsdaten unbedingt sichtbar auf dem
Login-Screen, PII und Reset-Token in `debugPrint`-Logs, Release-Signierung mit dem Debug-Keystore, 73 MB
unskalierte Läuferfotos, teils nicht mehr kompilierende Tests sowie eine In-Memory-Authentifizierung, die
Passwortänderungen bei jedem Neustart vergaß.

---

[Unreleased]: https://github.com/Veit-Kramer-Schoeggl/benefitflutter/compare/main...feat/phase-2-background-tracking
