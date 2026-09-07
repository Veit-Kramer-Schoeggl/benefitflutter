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

> **Stand:** 2026-08-28 (Doc-Review; letzte Code-Änderung 2026-06-13, WP5 `fd7dfc1`) · **Branch:** `feat/phase-2-background-tracking` ·
> **Status:** WP1–WP5 ✅ abgeschlossen & verifiziert · WP6a (Unit-Tests + Smoke-Checkliste) ✅ · **WP6b (Geräte-Smoke auf echtem Gerät) ⬜ offen**.
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

Die Code-Naht (WP2) ist gelegt: `GpsSensor.buildLocationSettings(platform, mode)` branch auf den
`TrackingMode` ([gps_sensor.dart:253-283](../../lib/features/shared/sensors/gps_sensor.dart)).
Die Stream-Werte sind derzeit **lokale Konstanten** im Sensor (`_manualDistanceFilter = 5 m`,
`_continuousDistanceFilter = 50 m`, gps_sensor.dart:230-231). Getrennt davon hält
[gps_tracking_config.dart](../../lib/core/config/gps_tracking_config.dart) die **Speicher**-Schwellen
(manual 5 s/10 m · continuous 300 s/100 m) — die Zusammenführung beider Profile ist ein offener
Phase-B-Punkt (s. WP2).

## 3. Ausgangslage vor WP1 (historisch)

Die Tabelle beschreibt den Zustand **vor** WP1–WP5 und bleibt als Ausgangspunkt stehen.
Aktueller Stand: Abschnitt 6 (Fahrplan) + [Changelog](#changelog).

**Vorher:**

```
GpsSensor (plain geolocator stream) → SensorManager → ActivityProvider
   → Puffer (_pendingGpsPoints, 10er-Batch) → GpsPointDao.insertBatch → SQLite
```

**Heute (nach WP5):**

```
GpsSensor (geolocator-FGS-Stream, plattformspez. Settings)
   → SensorManager (reicht TrackingMode durch) → ActivityProvider
   → Puffer (_pendingGpsPoints, 5er-Batch + 60-s-Alters-Flush)
   → GpsPointDao.insertBatch → SQLite
```

| Baustein | Ort | Zustand vor WP1 | Heute |
|---|---|---|---|
| GPS-Stream | [gps_sensor.dart](../../lib/features/shared/sensors/gps_sensor.dart) (vor WP2: :148-172) | `const LocationSettings(accuracy: high, distanceFilter: 5)` — **plain**, kein FGS, kein BG-Flag | plattformspez. Settings inkl. FGS ([gps_sensor.dart:253-283](../../lib/features/shared/sensors/gps_sensor.dart)) ✅ WP2 |
| GPS-Subscription/Buffer | [activity_provider.dart:823-890](../../lib/providers/activity_provider.dart) (heute) | funktioniert, plattformneutral | Batch **5** + 60-s-Alters-Flush ([activity_provider.dart:71-72, :849-851](../../lib/providers/activity_provider.dart)) ✅ WP5 |
| Lifecycle | [main.dart](../../lib/main.dart) `didChangeAppLifecycleState` | flusht Puffer bei `paused` (führt nicht weiter) | unverändert (main.dart:237-241, :254-259) |
| Dauer | [activity_provider.dart:692-702](../../lib/providers/activity_provider.dart) (heute) | 1-s-`Timer.periodic` als Tick-Zähler → driftet im Hintergrund (s. Erkenntnisse) | Timestamp-Akkumulator ([activity_provider.dart:125-130, :713-719](../../lib/providers/activity_provider.dart)); der 1-s-Timer treibt nur noch die UI (:697) ✅ WP4 |
| `continuousDaily` | [activity_provider.dart:658-687](../../lib/providers/activity_provider.dart) (Kommentar :657) | **nur Gerüst** („placeholder for future continuous tracking module") | weiterhin nur Gerüst; auch der Storage-Pfad ist fest auf manual verdrahtet (:906 `isContinuousMode: false`) |
| Android-Manifest | [AndroidManifest.xml](../../android/app/src/main/AndroidManifest.xml) | Location-Perms da; **FGS-Perms fehlen** | FGS-Perms da ([AndroidManifest.xml:10-15](../../android/app/src/main/AndroidManifest.xml)) ✅ WP1 |
| iOS-Plist | [Info.plist](../../ios/Runner/Info.plist) | NSLocation-Strings da; **`UIBackgroundModes` fehlt** | `UIBackgroundModes:[location]` da ([Info.plist:56-59](../../ios/Runner/Info.plist)) ✅ WP1 |

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
| WP2 | GpsSensor: plattformspez. Settings + FGS; Stream im Vordergrund starten; Naht für continuousDaily | gps_sensor.dart, sensor_manager.dart, activity_provider.dart | S–M | ✅ done |
| WP3 | Permission-Flow (while-in-use + Runtime-POST_NOTIFICATIONS + LocationService-Check + Warn-UI/Retry) | gps_sensor.dart, sensor_manager.dart, activity_provider.dart, activity_screen.dart, main.dart | S–M | ✅ done |
| WP4 | Dauer aus Timestamps (Background-Drift-Fix) | activity_provider.dart | S | ✅ done |
| WP5 | Buffer-Robustheit: punkt-getriggerter Alters-Flush (**60 s**) + Batch 10 → **5** | activity_provider.dart | S | ✅ done |
| **WP6a** | Unit-Tests (LocationSettings-Builder, Warn-Kanal, Dauer, Buffer) + Smoke-Checkliste geschrieben | test/unit/features/shared/sensors/gps_location_settings_test.dart, test/unit/providers/activity_provider_test.dart, DEVICE_SMOKE_CHECKLIST.md | S | ✅ done (823 Tests grün) |
| WP6b | **Geräte-Smoke auf echtem Gerät** (Xiaomi Mi 11 / Android 14) inkl. Logcat-FGS-Check | — | M | ⬜ offen |

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
  - **Android:** `AndroidSettings(foregroundNotificationConfig: ForegroundNotificationConfig(notificationTitle, notificationText, enableWakeLock: true, setOngoing: true), accuracy, distanceFilter)`
    (die Implementierung übergibt **kein** `notificationIcon` — der geolocator-Default ist bereits
    `AndroidResource(name: "ic_launcher", defType: "mipmap")`, geolocator_android 5.0.2
    `foreground_settings.dart:56-57`; s. gps_sensor.dart:236-242.)
  - **iOS:** `AppleSettings(allowBackgroundLocationUpdates: true, pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true, activityType: ActivityType.fitness, accuracy, distanceFilter)`
- Stream erst starten, wenn die Session ACTIVE wird und die App im **Vordergrund** ist.
- **Phase-B-Naht (teilweise offen):** `startStreaming({sessionId, mode})` nimmt den `TrackingMode`
  entgegen ✅ (gps_sensor.dart:162-165; `SensorManager` reicht durch, sensor_manager.dart:181-187).
  `accuracy`/`distanceFilter` kommen aber noch aus **lokalen Konstanten** (gps_sensor.dart:230-231,
  5 m/50 m) und **nicht** aus
  [gps_tracking_config.dart](../../lib/core/config/gps_tracking_config.dart) — der Sensor importiert
  die Config gar nicht.
  ⬜ Offen für Phase B: Profile aus `GpsTrackingConfig` beziehen **und**
  `ActivityProvider._shouldStoreGpsPoint` (activity_provider.dart:906) von `isContinuousMode: false`
  auf den Session-Modus umstellen.

### WP3 — Permission-Flow
- While-in-use (FINE/COARSE) + Runtime-`POST_NOTIFICATIONS` (Android 13+) + `isLocationServiceEnabled`-
  Check vor Session-Start. Zweistufiger „Always"-Flow erst Phase B.

### WP4 — Dauer aus Timestamps ✅
- [activity_provider.dart](../../lib/providers/activity_provider.dart): Dauer = Summe der **aktiven
  Segmente** (`_accumulatedActive` + laufendes `_segmentStart`, UTC), bei jedem Lesen aus der
  Wall-Clock berechnet (:125-130); `_finalizeSegment()` schließt ein Segment bei Pause/Stop
  (:713-719). Der 1-s-`Timer.periodic` triggert nur noch `notifyListeners()` (:692-702).
- Persistiert wird `durationSeconds: _elapsedSeconds` (:219, :401, :448, :516) — **nicht**
  `endTime − startTime`, damit Pausen weiterhin nicht mitzählen.
- Injizierbarer `now`-Seam (`DateTime Function()`, :54, :103-105) für deterministische Tests.
- Bekannte Limitation: Wall-Clock-/NTP-Sprünge werden nicht kompensiert, und der Akkumulator ist
  in-memory (überlebt keinen Prozess-Kill) — beides bewusst, s. Decision-Log.

### WP5 — Buffer-Robustheit ✅
- Batch **10 → 5** und **punkt-getriggerter** Alters-Flush (`_maxBufferAge = 60 s`, geprüft in
  `_onGpsPoint` bei Punkt-Ankunft — **kein** Hintergrund-Timer, der gedrosselt würde). `_lastFlush`
  via `_now()` (Session-Start + jeder Flush-Pfad). Bestehender `lifecycle.paused`-Flush bleibt.
  Restrisiko: Inaktivitäts-Fenster (gepufferte Punkte + stationär + Kill) → Phase B.

### WP6 — Tests + Geräte-Smoke
- **WP6a ✅** Unit: LocationSettings-Builder (Plattform-Branch → korrekte Settings) in
  `test/unit/features/shared/sensors/gps_location_settings_test.dart`; Warn-Kanal, Dauer-Akkumulator
  und Buffer-Verhalten in `test/unit/providers/activity_provider_test.dart`. Gesamtsuite **823 Tests
  grün** (Stand 2026-08-28).
- **WP6b ⬜ offen** — Geräte-Smoke (Xiaomi Mi 11): Session starten → App in Hintergrund + Display aus
  → ~5–10 min → `gps_points` laufen weiter, Notification sichtbar; **Logcat** auf FGS-Typ-Fehler
  prüfen. Ablauf: [DEVICE_SMOKE_CHECKLIST.md](../DEVICE_SMOKE_CHECKLIST.md).
  Nicht durch Unit-Tests abgedeckt und daher zwingend on-device: `ensureNotificationPermission`,
  der tatsächliche FGS-Start und die Notification-Sichtbarkeit.

## 7. Out-of-scope (offene Punkte → [ROADMAP.md](../ROADMAP.md) „Übergreifende Lücken")

- **Google Play:** FGS-Typ-Deklaration im Console (seit 2024-08-31 **auch für foreground-only**
  Pflicht) + Data-Safety + prominente In-App-Disclosure.
- **App Store:** 2.5.4 (persistente Background-Location braucht erkennbares Feature) +
  Precise-Location-Nutrition-Label.
- **DSGVO/Art. 9:** Consent für kontinuierliches GPS/HR.
- **OEM-Battery-Optimization-Whitelisting**-Hinweis (Xiaomi/Huawei) — Phase-2-Folgepunkt.
- **Notification-Icon (Android 11+):** System erzwingt flache, monochrome Tray-Icons → das farbige
  `ic_launcher` erscheint ggf. als weißes Quadrat. Dediziertes monochromes Icon = UI-Polish Phase 3.
- **`continuousDaily`-Runtime** (Phase B / Option 2 / `flutter_background_service`).

## Decision-Log

| Datum | Entscheidung | Begründung |
|-------|--------------|------------|
| 2026-06-13 | Phasenansatz: erst aktive Sessions (Option 1), `continuousDaily` später | Risikoarm, keine Dependency; Naht bleibt offen |
| 2026-06-13 | Eingebauter geolocator-FGS statt eigenem `foreground_service.dart` | Weniger nativer Code; Trade-off (keine Notification-Actions) bewusst akzeptiert |
| 2026-06-13 | `ACCESS_BACKGROUND_LOCATION` für Phase A entfernen | Für im-Vordergrund-gestartete Location-FGS nicht nötig; vermeidet Play-BG-Location-Review; Phase B re-add |
| 2026-06-13 | `bluetooth-central` (iOS) deferren | Nicht für Background-GPS nötig; App-Store-2.5.4-Risiko bei ungenutztem Mode |
| 2026-06-13 | WP2: `TrackingMode`-Naht via `GpsSensor`-Override (optionaler Zusatz-Param) statt `BaseSensor`-Erweiterung; `SensorManager` reicht über `is GpsSensor` durch | Hält das generische `BaseSensor`-Interface (auch `HeartRateSensor`) sauber; Mock läuft über Fallback-Zweig |
| 2026-06-13 | continuous-`distanceFilter` provisorisch 50 m | Feintuning in Phase B; Phase A nutzt manual = 5 m |
| 2026-06-13 | WP3: GPS-Ausfall via separatem `gpsStartWarning`-Kanal (nicht `_error`) melden | `_error` würde via [activity_screen.dart:218-219](../../lib/presentation/screens/activity/activity_screen.dart#L218) den ganzen Screen kapern; Session soll trotz fehlendem GPS sichtbar weiterlaufen |
| 2026-06-13 | WP3: `POST_NOTIFICATIONS` best-effort (blockiert Tracking nicht) | FGS zeichnet auch ohne sichtbare Notification auf; Ablehnung wird nur geloggt + per Geräte-Smoke beobachtet |
| 2026-06-13 | WP3: Resume-Retry (`retryGpsIfNeeded`) statt Mid-Session-Always-Flow | macht den „Open Settings"→zurück-Weg nutzbar, ohne `ACCESS_BACKGROUND_LOCATION` (das bleibt Phase B) |
| 2026-06-13 | WP4: Dauer via Timestamp-Akkumulator (aktive Segmente, UTC) statt Timer-Tick-Zähler; injizierbarer `now`-Seam | Dart-`Timer` wird im Hintergrund gedrosselt → Tick-Zähler untercountet; Akkumulator rechnet aus der Wall-Clock und schließt Pausen aus. Monotone `Stopwatch` wäre clock-jump-immun, aber nicht deterministisch testbar + überlebt keinen Restart → verworfen; Clock-Sprung bleibt bekannte Minor-Limitation |
| 2026-06-13 | WP4: Akkumulator bleibt in-memory (keine DB-Persistenz/Restore) | Session-Resume nach OS-Kill ist Phase B; deckt sich mit der Phase-A-Grenze (überlebt keinen Prozess-Kill) |
| 2026-06-13 | WP5: Alters-Flush **punkt-getriggert** (in `_onGpsPoint`) statt Hintergrund-`Timer` | ein Dart-Timer wird im Hintergrund gedrosselt — genau im Kill-Szenario unzuverlässig; GPS-Punkte treffen via FGS zuverlässig ein |
| 2026-06-13 | WP5: Batch 10 → 5 | halbiert das Verlust-Fenster; `distanceFilter` (≥5 m) begrenzt die Schreibfrequenz → kein I/O-Storm |

## Changelog

| Datum | WP | Änderung |
|-------|----|---------|
| 2026-06-13 | — | Doc angelegt; Status-quo, verifizierte Erkenntnisse, Fahrplan WP1–WP6 |
| 2026-06-13 | WP1 | Native Config umgesetzt & verifiziert — Manifest: +`FOREGROUND_SERVICE(_LOCATION)`/`POST_NOTIFICATIONS`/`WAKE_LOCK`, −`ACCESS_BACKGROUND_LOCATION`; Plist: +`UIBackgroundModes:[location]`, Usage-Strings geschärft. `dart analyze` clean, 813 Tests grün, Debug-APK baut, gemergtes Manifest geprüft (FGS-Perms + `GeolocatorLocationService` da, kein aktives `ACCESS_BACKGROUND_LOCATION`). |
| 2026-06-13 | WP2 | `GpsSensor.buildLocationSettings` (plattformspezifisch): Android `AndroidSettings` + `ForegroundNotificationConfig` (Wakelock/ongoing), iOS `AppleSettings` (Background-Updates, `pauseLocationUpdatesAutomatically:false`, `showBackgroundLocationIndicator:true`, `activityType: fitness`); `TrackingMode` durch `SensorManager.startSession` → `GpsSensor` durchgereicht (`ActivityProvider` übergibt `session.trackingMode`); neuer Builder-Unit-Test. `dart analyze` clean, **817 Tests** grün, Debug-APK baut. |
| 2026-06-13 | WP3 | Permission-Flow: `GpsSensor.ensureNotificationPermission` (Android best-effort) vor `startStreaming`; GPS-Ausfall über neuen `gpsStartWarning`-Kanal (+ `gpsNeedsSettings`) statt `_error`; `ActivityScreen` zeigt SnackBar (mit „Settings"→`openAppSettings`) + persistenten Warn-Banner; `retryGpsIfNeeded()` bei App-Resume (`main.dart`). 3 neue Provider-Tests; `ensureNotificationPermission`-Pfad nur per Geräte-Smoke (WP6) abgedeckt. `dart analyze` clean, **820 Tests** grün, Debug-APK baut. |
| 2026-06-13 | WP4 | Session-Dauer aus Timestamp-Akkumulator aktiver Segmente (UTC) statt `Timer`-Tick-Zähler → kein Background-Untercount, Pausen weiter ausgeschlossen; 1-s-Timer treibt nur noch die UI; injizierbarer `now`-Seam. 2 neue deterministische Tests; Smoke-Punkt „Dauer korrekt nach Hintergrund" ergänzt. `dart analyze` clean, **822 Tests** grün, Debug-APK baut. |
| 2026-06-13 | WP5 | Buffer-Robustheit: `_gpsBatchSize` 10 → 5 + punkt-getriggerter Alters-Flush (`_maxBufferAge` 60 s, `_lastFlush` via `_now()`) in `_onGpsPoint`; Re-Entrancy schon durch snapshot→clear→await abgesichert. Batch-Test auf 5 angepasst + neuer Staleness-Test. `dart analyze` clean, **823 Tests** grün, Debug-APK baut. |
| 2026-08-28 | — | Doc-Review gegen den Code: Abschnitt 3 als **historisch** gekennzeichnet (+ Spalte „Heute"), Pipeline-Diagramm auf 5er-Batch aktualisiert, WP2-Naht (lokale Konstanten statt `GpsTrackingConfig`) und WP4 (`durationSeconds` = Akkumulator, nicht `endTime − startTime`) richtiggestellt, `notificationIcon` aus der WP2-Spec entfernt, WP6 in WP6a (✅) / WP6b (⬜) gesplittet, stale Zeilen-Anker nachgezogen. Keine Code-Änderung. |
