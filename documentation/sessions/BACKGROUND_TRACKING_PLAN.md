---
> **Documentation Type:** IMPLEMENTATION PLAN (Phase 2 · Work-Package Fahrplan + Erkenntnisse)
>
> **Roadmap-Eintrag:** [ROADMAP.md](../ROADMAP.md) → Phase 2, „Background-Tracking-Runtime"
>
> **Design-Kontext:** [SESSION_DESIGN.md](./SESSION_DESIGN.md) (Phase 5) · [SESSION_PLAN.md](./SESSION_PLAN.md) (Sprint 4/7)
>
> **Related:** [SENSORS.md](../../lib/features/shared/sensors/SENSORS.md) | [DEVICE_SMOKE_CHECKLIST.md](../DEVICE_SMOKE_CHECKLIST.md)
---

# Background-Tracking-Runtime — Implementierungs-Fahrplan

> **Stand:** 2026-06-13 · **Branch:** `feat/phase-2-background-tracking` · **Status:** WP1 ✅ abgeschlossen & verifiziert · WP2 als nächstes.
> Lebendes Dokument — wird pro Work-Package fortgeschrieben (siehe [Decision-Log](#decision-log) & [Changelog](#changelog)).

## 1. Kontext & Ziel

ROADMAP Phase 2, erster Task. Heute läuft GPS-Tracking **nur im Vordergrund**: Geht die App in den
Hintergrund, flusht [main.dart](../../lib/main.dart) lediglich den GPS-Puffer — die Session zeichnet
**nichts weiter auf**. Ohne native Background-Runtime nimmt „Aktivität aufzeichnen" im Produktivbetrieb
nichts auf, sobald der User das Display sperrt oder die App wechselt.

**Ziel:** GPS (und perspektivisch HR) laufen während einer **aktiven Session** zuverlässig weiter,
auch wenn die App im Hintergrund ist.

## 2. Scope-Entscheidung

**Phasenansatz — bestätigt:** *Erst aktive Sessions (`manual`), `continuousDaily` (All-Day-Passiv) später.*

| Phase | Inhalt | Ansatz |
|-------|--------|--------|
| **A (jetzt)** | Background-Tracking für **aktive** Workout-Sessions | **Option 1** — geolocator-eigener Foreground-Service, **keine neue Dependency** |
| B (später) | `continuousDaily` All-Day-Passiv-Tracking, überlebt App-Kill | **Option 2** — `flutter_background_service` (separates, sticky Isolate) |
| — (verworfen) | Sehr robust, motion-getriggert | Option 3 — `flutter_background_geolocation` (kommerziell, Vendor-Lock-in) |

Die Code-Naht (WP2) wird so gelegt, dass Phase B ohne Bruch andockt:
[gps_tracking_config.dart](../../lib/core/config/gps_tracking_config.dart) hält bereits getrennte
Profile (manual: high/5 m · continuous: 100 m/300 s).

## 3. Status quo — bestehende Tracking-Pipeline

Die gesamte Pipeline existiert und funktioniert; sie läuft nur nicht im Hintergrund weiter:

```
GpsSensor (geolocator stream) → SensorManager → ActivityProvider
   → Puffer (_pendingGpsPoints, 10er-Batch) → GpsPointDao.insertBatch → SQLite
```

| Baustein | Ort | Zustand |
|---|---|---|
| GPS-Stream | [gps_sensor.dart:153-172](../../lib/features/shared/sensors/gps_sensor.dart) | `const LocationSettings(accuracy: high, distanceFilter: 5)` — **plain**, kein FGS, kein BG-Flag |
| GPS-Subscription/Buffer | [activity_provider.dart:657-699](../../lib/providers/activity_provider.dart) | funktioniert, plattformneutral |
| Lifecycle | [main.dart](../../lib/main.dart) `didChangeAppLifecycleState` | flusht Puffer bei `paused` (führt nicht weiter) |
| Dauer | [activity_provider.dart:636-642](../../lib/providers/activity_provider.dart) | 1-s-`Timer.periodic` → driftet im Hintergrund (s. Erkenntnisse) |
| `continuousDaily` | [activity_provider.dart:602](../../lib/providers/activity_provider.dart) | **nur Gerüst** („placeholder for future continuous tracking module") |
| Android-Manifest | [AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml) | Location-Perms da; **FGS-Perms fehlen** |
| iOS-Plist | [Info.plist](../../ios/Runner/Info.plist) | NSLocation-Strings da; **`UIBackgroundModes` fehlt** |

## 4. Verifizierte Erkenntnisse

> Quelle: Verifikations-Workflow (Android/iOS-Verifier + adversarischer Reviewer, mit Web-Recherche)
> + Gegenprüfung an den Android-Docs.

### 4.1 Kern (warum keine Dependency nötig)
- **`targetSdk` ist real 36** (Flutter 3.44.1; verifiziert in `FlutterExtension.kt`), nicht 34/35 →
  FGS-Regeln werden **strikt** erzwungen.
- `geolocator ^14.0.2` (resolved `geolocator_android 5.0.2` / `geolocator_apple 2.3.13`) deklariert
  den Service `GeolocatorLocationService` mit `android:foregroundServiceType="location"` **im
  Plugin-Manifest** → **kein eigener `<service>` nötig** (Duplikat = Merge-Konflikt). Das Plugin
  liefert **keine** `uses-permission` → die App muss sie ergänzen.
- `AndroidSettings` / `AppleSettings` / `ForegroundNotificationConfig` sind aus
  `package:geolocator/geolocator.dart` importierbar (Re-Export).
- `ForegroundNotificationConfig` bringt `enableWakeLock` & `setOngoing` mit → **kein separates
  wakelock-Paket**.

### 4.2 Android — Permissions
- **Aktive Sessions brauchen `ACCESS_BACKGROUND_LOCATION` NICHT.** Ein Location-FGS, der *im
  Vordergrund* gestartet wird, darf mit „while-in-use" weiter Location lesen, auch wenn die App in
  den Hintergrund geht. Android-Docs wörtlich: *„If your app has a foreground service … then you
  don't have to request background location access"* bzw. *„If you start a location foreground
  service while your app is in the foreground, you only need the while-in-use permission and do not
  need `ACCESS_BACKGROUND_LOCATION`."*
  → **Entscheidung: für Phase A entfernen** (vermeidet die Google-Play-Background-Location-Review);
  kommt in Phase B (continuousDaily, das aus dem Hintergrund startet) sauber zurück.
- Benötigt (App-Manifest): `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` (ab API 34 Pflicht,
  sonst `MissingForegroundServiceTypeException` beim `startForeground`), `POST_NOTIFICATIONS`,
  `WAKE_LOCK` (gekoppelt an `enableWakeLock:true`).
- **Nicht** hand-ergänzen: `ACCESS_NETWORK_STATE` (kommt transitiv via anderes Plugin ins gemergte
  Manifest).

### 4.3 iOS
- **Fehlendes `UIBackgroundModes:location` = STILLES Versagen** (kein Crash): `geolocator_apple`
  guardet `allowsBackgroundLocationUpdates` gegen den Plist-Key — ohne Key fließen Background-Updates
  einfach nicht, obwohl der Dart-Default `allowBackgroundLocationUpdates=true` ist. Im Test leicht
  zu übersehen.
- „While In Use" reicht für aktive (im Vordergrund gestartete) Sessions; **„Always" erst Phase B**.
- `PrivacyInfo.xcprivacy` **nicht** nötig — CoreLocation ist keine „required-reason"-API; das Plugin
  bringt eine eigene (leere) Privacy-Manifest-Datei mit. Kein Entitlement-/Signing-Change.
- `activityType: fitness` hält Updates auch bei langsamer Bewegung (Wandern) aktiv.

### 4.4 Querschnitt-Fallen (für WP2–WP6)
- **Dauer-vom-Timer driftet im Hintergrund** — `Timer.periodic` wird gedrosselt/pausiert, während
  GPS via FGS weiterläuft → **Dauer aus Timestamps ableiten** (WP4, kritisch).
- **FGS muss im VORDERGRUND gestartet werden** (beide Plattformen): Android verbietet FGS-Start aus
  dem Hintergrund; iOS-18 darf den Stream nicht aus Suspended kalt starten. Stream-Start muss
  getriggert sein, **bevor** der User minimiert/sperrt; Auto-Start nach Crash in den Hintergrund
  schlägt fehl. (WP2)
- **Android 14: `startForeground()` muss denselben `location`-Typ mitgeben** — Plugin tut das, aber
  im WP2-Smoke per **Logcat** auf `MissingForegroundServiceType` / „FGS type not allowed" prüfen.
- **`POST_NOTIFICATIONS` nicht nur kosmetisch:** ohne sichtbare Notification beendet das OS den FGS
  auf manchen Android-Versionen → Runtime-Permission (WP3) sicherstellen + Ablehnung testen.
- **Android-BLE-im-Hintergrund hängt am Location-FGS** (flutter_blue_plus steuert kein Manifest
  bei) — stirbt der FGS, stirbt HR. Start-Reihenfolge: Location-Stream zuerst. (WP2-HR)
- **`notificationIcon` muss ein echtes Drawable sein** (`@mipmap/ic_launcher`), sonst kann
  `startForeground` fehlschlagen (auch unter R8/Shrink prüfen). (WP2)
- **OEM-Batterie-Killer (Xiaomi/MIUI, Huawei …):** killen Prozesse trotz FGS bei aktiver
  Batterie-Optimierung → FGS allein reicht dort oft nicht. In-App-Whitelisting-Hinweis
  (Battery-Optimization-Exemption) ist ein Phase-2-Folgepunkt.
- **Datenverlust bei App-Kill:** killt das OS die App trotz FGS (Speicherdruck), gehen ungeflushte
  Punkte aus dem Dart-Heap verloren → WP5-Flush-Intervall (s.u.).
- Verifikation nur verlässlich über das **gemergte** Manifest (post-build grep).
- Gerätevoraussetzung (separat von der App-Permission): `Geolocator.isLocationServiceEnabled()` —
  der Location-FGS startet nur, wenn die System-Ortung an ist (in [gps_sensor.dart](../../lib/features/shared/sensors/gps_sensor.dart) `initialize()` bereits geprüft).

### 4.5 Quellen
- https://developer.android.com/develop/sensors-and-location/location/permissions
- https://developer.android.com/develop/sensors-and-location/location/permissions/background
- https://developer.android.com/develop/background-work/services/fgs/service-types
- https://developer.android.com/develop/background-work/services/fgs/declare
- https://developer.android.com/about/versions/14/changes/fgs-types-required
- https://developer.android.com/develop/ui/views/notifications/notification-permission
- https://support.google.com/googleplay/android-developer/answer/9799150
- https://developer.apple.com/documentation/corelocation/cllocationmanager/allowsbackgroundlocationupdates
- https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
- https://developer.apple.com/app-store/review/guidelines/ (2.5.4)
- pub.dev/packages/geolocator + Plugin-Quellen (`apple_settings.dart`, `GeolocationHandler.m`, `PrivacyInfo.xcprivacy`)

## 5. Reconciliation mit bestehendem Design

[SESSION_DESIGN.md](./SESSION_DESIGN.md) (Phase 5 „Background Service") und
[SESSION_PLAN.md](./SESSION_PLAN.md) (Sprint 4 „Permissions & Background", Sprint 7 „BG Polish")
hatten Background-Tracking bereits skizziert — mit einem **eigenen**
`lib/core/services/foreground_service.dart` + manuell deklariertem Service + Notification-Channel.

**Abweichung (bewusst):** Wir nutzen den **eingebauten** geolocator-Foreground-Service.
- ✅ Vorteil: deutlich weniger nativer Code (kein `foreground_service.dart`, keine eigene
  Service-/Channel-Deklaration).
- ⚠️ Trade-off: `ForegroundNotificationConfig` unterstützt **keine** Notification-Actions
  (pause/stop/open), die SESSION_DESIGN Sprint 7 vorsah. → Falls Actions oder echtes
  All-Day-Tracking Pflicht werden, ist das genau der Punkt, an dem `flutter_background_service`
  (Option 2 / Phase B) einzieht.

WP1–WP6 mappen auf die Intentionen von Sprint 4 (Permissions + Manifest/Plist) und Sprint 7
(Notification-Polish).

## 6. Fahrplan (Work-Packages)

| WP | Inhalt | Dateien (Kern) | Aufwand | Status |
|----|--------|----------------|---------|--------|
| **WP1** | **Native Config** (Manifest + Plist) | AndroidManifest.xml, Info.plist | S | ✅ done |
| WP2 | GpsSensor: plattformspez. Settings + FGS; Stream im Vordergrund starten; Naht für continuousDaily | gps_sensor.dart, gps_tracking_config.dart | S–M | ⬜ |
| WP3 | Permission-Flow (while-in-use + Runtime-POST_NOTIFICATIONS + LocationService-Check) | gps_sensor.dart + aufrufender Screen | S–M | ⬜ |
| WP4 | Dauer aus Timestamps (Background-Drift-Fix) | activity_provider.dart | S | ⬜ |
| WP5 | Buffer-Robustheit (zeitbasierter Flush) | activity_provider.dart | S | ⬜ |
| WP6 | Tests + Geräte-Smoke (inkl. Logcat-FGS-Check) | test/…, DEVICE_SMOKE_CHECKLIST.md | M | ⬜ |

### WP1 — Native Konfiguration (reine Config, kein Dart)
**`android/app/src/main/AndroidManifest.xml`:**
- **+** `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `WAKE_LOCK`
- **−** `ACCESS_BACKGROUND_LOCATION` (durch erklärenden Kommentar ersetzt; Phase B re-add)
- **kein** eigener `<service>`, **kein** `ACCESS_NETWORK_STATE`

**`ios/Runner/Info.plist`:**
- **+** `UIBackgroundModes` → `[location]`
- `NSLocation…UsageDescription`-Strings auf aktiven-Session/Workout-Route-Zweck schärfen
- **kein** `bluetooth-central`, **kein** `PrivacyInfo.xcprivacy`, **kein** Entitlement

**Done-Kriterien:** `dart analyze`/`flutter test` grün; `flutter build apk --debug` baut; gemergtes
Manifest enthält `FOREGROUND_SERVICE(_LOCATION)` + `GeolocatorLocationService` und **kein**
`ACCESS_BACKGROUND_LOCATION`.

### WP2 — GpsSensor (Foreground-Service)
- [gps_sensor.dart](../../lib/features/shared/sensors/gps_sensor.dart) `startStreaming()`:
  `const LocationSettings` → Plattform-Branch (`defaultTargetPlatform`):
  - **Android:** `AndroidSettings(foregroundNotificationConfig: ForegroundNotificationConfig(notificationTitle, notificationText, notificationIcon: @mipmap/ic_launcher, enableWakeLock: true, setOngoing: true), accuracy, distanceFilter)`
  - **iOS:** `AppleSettings(allowBackgroundLocationUpdates: true, pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true, activityType: ActivityType.fitness, accuracy, distanceFilter)`
- Stream erst starten, wenn die Session ACTIVE wird und die App im **Vordergrund** ist.
- **Phase-B-Naht:** `startStreaming()` erhält ein `TrackingMode`/Profil-Argument → `accuracy`/
  `distanceFilter` aus [gps_tracking_config.dart](../../lib/core/config/gps_tracking_config.dart).

### WP3 — Permission-Flow
- While-in-use (FINE/COARSE) + Runtime-`POST_NOTIFICATIONS` (Android 13+) + `isLocationServiceEnabled`-
  Check vor Session-Start. Zweistufiger „Always"-Flow erst Phase B.

### WP4 — Dauer aus Timestamps
- [activity_provider.dart](../../lib/providers/activity_provider.dart): `_elapsedSeconds` selbst-
  korrigierend (`now − startTime`); `durationSeconds` final aus `endTime − startTime`.

### WP5 — Buffer-Robustheit
- Zusätzlicher **zeitbasierter Flush alle 60 s**; Punkte-Batch von **10 → 5** senken. Bestehender
  Flush bei `lifecycle.paused` bleibt.

### WP6 — Tests + Geräte-Smoke
- Unit: LocationSettings-Builder (Plattform-Branch → korrekte Settings). Bestehende Suite grün.
- Geräte-Smoke (Xiaomi Mi 11): Session starten → App in Hintergrund + Display aus → ~5–10 min →
  `gps_points` laufen weiter, Notification sichtbar; **Logcat** auf FGS-Typ-Fehler prüfen.

## 7. Out-of-scope (offene Punkte → [ROADMAP.md](../ROADMAP.md) „Übergreifende Lücken")

- **Google Play:** FGS-Typ-Deklaration im Console (seit 2024-08-31 **auch für foreground-only**
  Pflicht) + Data-Safety + prominente In-App-Disclosure.
- **App Store:** 2.5.4 (persistente Background-Location braucht erkennbares Feature) +
  Precise-Location-Nutrition-Label.
- **DSGVO/Art. 9:** Consent für kontinuierliches GPS/HR.
- **OEM-Battery-Optimization-Whitelisting**-Hinweis (Xiaomi/Huawei) — Phase-2-Folgepunkt.
- **`continuousDaily`-Runtime** (Phase B / Option 2 / `flutter_background_service`).

## Decision-Log

| Datum | Entscheidung | Begründung |
|-------|--------------|------------|
| 2026-06-13 | Phasenansatz: erst aktive Sessions (Option 1), `continuousDaily` später | Risikoarm, keine Dependency; Naht bleibt offen |
| 2026-06-13 | Eingebauter geolocator-FGS statt eigenem `foreground_service.dart` | Weniger nativer Code; Trade-off (keine Notification-Actions) bewusst akzeptiert |
| 2026-06-13 | `ACCESS_BACKGROUND_LOCATION` für Phase A entfernen | Für im-Vordergrund-gestartete Location-FGS nicht nötig; vermeidet Play-BG-Location-Review; Phase B re-add |
| 2026-06-13 | `bluetooth-central` (iOS) deferren | Nicht für Background-GPS nötig; App-Store-2.5.4-Risiko bei ungenutztem Mode |

## Changelog

| Datum | WP | Änderung |
|-------|----|---------|
| 2026-06-13 | — | Doc angelegt; Status-quo, verifizierte Erkenntnisse, Fahrplan WP1–WP6 |
| 2026-06-13 | WP1 | Native Config umgesetzt & verifiziert — Manifest: +`FOREGROUND_SERVICE(_LOCATION)`/`POST_NOTIFICATIONS`/`WAKE_LOCK`, −`ACCESS_BACKGROUND_LOCATION`; Plist: +`UIBackgroundModes:[location]`, Usage-Strings geschärft. `dart analyze` clean, 813 Tests grün, Debug-APK baut, gemergtes Manifest geprüft (FGS-Perms + `GeolocatorLocationService` da, kein aktives `ACCESS_BACKGROUND_LOCATION`). |
