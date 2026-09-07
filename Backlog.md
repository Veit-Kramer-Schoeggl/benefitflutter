# BeneFit — Backlog (Audit-Befunde, priorisiert)

> **Stand:** 2026-08-28 · **Branch:** `feat/phase-2-background-tracking` · **100 offene Einträge (BL-001 – BL-100).**
> Detailebene zur Maßnahmen-Checkliste [documentation/ROADMAP.md](documentation/ROADMAP.md);
> Begründungen im [Architektur-Review](documentation/ARCHITECTURE_REVIEW.md);
> was bereits geliefert wurde, steht im [Changelog](Changelog.md).
>
> Aufwand: **S** < 1 Tag · **M** 1–3 Tage · **L** ~1 Woche · **XL** > 1 Woche.
> Priorität: **P0** blockiert Demo bzw. Go-Live · **P1** vor dem Rollout · **P2** danach ·
> **P3** opportunistisch.
> Jeder Eintrag hat eine stabile ID (`BL-nnn`) zum Zitieren in Meetings; IDs werden nicht wiederverwendet.
> Innerhalb jeder Kategorie ist nach Priorität sortiert.

> **Verifizierte Kennzahlen (2026-08-28, am Code nachgemessen):**
> **823 Tests, 0 Failures** (52 Testdateien unter `test/` + 1 unter `integration_test/`) ·
> Line-Coverage **48,1 %** (4396/9130, frisch regeneriert; `coverage/` ist gitignoriert, ein lokal vorhandenes `coverage/lcov.info`
> ist daher ein veraltetes Artefakt, keine gepflegte Kennzahl) ·
> `dart analyze --fatal-infos lib` **sauber** · `flutter build apk --debug` **grün** ·
> `dart format --set-exit-if-changed` **ROT (3 Dateien)** ·
> Schema-Version **12**, **16** Tabellen · **141** Dart-Dateien in `lib/`, **~30 691** Zeilen.
> Phase-2-Stand: **WP1–WP5 im Code, WP6 (Geräte-Smoke) offen.**

---

## 🚨 Sofort / vor der nächsten Demo

Zehn Befunde, die eine Vorführung auf einem Gerät sichtbar beschädigen oder die Qualitäts-Pipeline
blockieren. Details jeweils unten in der Kategorie.

| ID | Was | P/Aufwand |
|----|-----|-----------|
| **BL-054** | **Das CI-Format-Gate ist rot.** `dart format --set-exit-if-changed` meldet 3 geänderte Dateien aus den WP3/WP5-Commits — und weil es der **erste** Schritt in `ci.yml` ist, laufen Analyze, Tests und Build am Branch gar nicht erst. | P0 · S |
| **BL-087** | **Die App installiert sich als „benefitflutter".** Unter dem Launcher-Icon steht der Projekt-Slug, nicht „BeneFit" — das Erste, was eine Jury sieht. | P0 · S |
| **BL-072** | **Die Routen-Karte rendert für keine gespeicherte Session.** Der Detail-Screen filtert gespeicherte Punkte mit einem 10-Sekunden-Frische-Kriterium — nach dem Speichern ist jeder Punkt zu alt. Die Karte bleibt immer leer. | P0 · S |
| **BL-073** | **Aus echter Aktivität entsteht nie ein Benefit.** `awardBenefit` hat genau einen Aufrufer: den Debug-Seeder. Die namensgebende Kernschleife läuft im Release-Build nicht. | P0 · M |
| **BL-046** | **Der Benefit-Katalog ist auf jedem Non-Debug-Install leer.** Seeding hängt an `kDebugMode`; ein Release-/Profile-Build startet ohne Benefits, ohne Testnutzer, ohne Sessions. | P0 · M |
| **BL-010** | **GPS zählt während der Pause weiter.** Pausieren stoppt Timer und Segment, aber nicht den GPS-Stream — Distanz wächst weiter, während die Dauer korrekt stehen bleibt. Ergebnis: unmögliche Pace-Werte. | P0 · S |
| **BL-011** | **Beim Logout wird die laufende Session nie abgeschlossen.** Ein nicht awaiteter async-Aufruf rennt gegen einen synchronen State-Reset; die Session bleibt für immer `active` in der DB. | P0 · S |
| **BL-037** | **Manuelle Aktivitäten lecken zwischen Accounts.** Sie liegen unter einem geräteglobalen SharedPreferences-Key ohne User-ID — nach einem Account-Wechsel sieht der neue Nutzer die Einträge des alten. | P0 · S |
| **BL-088** | **`android.permission.INTERNET` fehlt im Release-Manifest.** Sie kommt nur transitiv aus dem Sentry-AAR; ohne Sentry hätte der Release-Build keine Netzwerkberechtigung. | P0 · S |
| **BL-009** | **WP6 — der Geräte-Smoke des Foreground-Service steht noch aus.** WP1–WP5 sind im Code und unit-getestet, aber keine der 11 Phase-2-Checkboxen (8 Foreground-Service + 3 Permissions) ist auf einem Gerät abgehakt. | P0 · M |

> Die übrigen 13 **P0**-Einträge — **BL-001–003** (Backend & Sync), **BL-028–036** (echte Auth,
> Reward-Integrität, DSGVO) und **BL-089** (Store-Policy Hintergrund-Standort) — blockieren nicht
> die Demo, aber jeden öffentlichen Rollout.

---

## 🔌 Backend & Sync

- [ ] **BL-001 · P0 · M — Backend-Entscheidung treffen und als Decision-Record festhalten**
  - *Warum:* Fast jeder andere P0 (echte Auth, Sync, Reward-Integrität, Löschpropagierung) hängt an dieser einen Weichenstellung; solange sie offen ist, kann keiner davon begonnen werden.
  - *Evidenz:* ROADMAP.md „🟡 Phase 2" — `(Spike) Backend-Entscheidung: PowerSync/Supabase vs. PostgREST`; im Code existiert nur der Platzhalter `lib/core/network/api_client.dart` (einzige Konstruktion: `api_client.dart:15`, keine Aufrufer).
  - *Abnahme:* Ein Decision-Record unter `documentation/` nennt die gewählte Option, die verworfenen Alternativen, Kosten/DSGVO-Region und die Migrationsstrategie; ROADMAP.md verweist darauf.

- [ ] **BL-002 · P0 · L — `SyncManager` + `SyncQueueDao`: Sync ist heute ein No-Op, der Erfolg meldet**
  - *Warum:* Alle drei Sync-Strategien geben `Future.value(true)` zurück, ohne je ein Byte zu senden. Weil der Upload „erfolgreich" ist, wird der Offline-Queue-Fallback in den Repositories nie erreicht — die `sync_queue`-Tabelle bleibt leer und die Daten können das Gerät nie verlassen.
  - *Evidenz:* `lib/features/session/data/session_sync_strategy.dart:31` („For now, simulate success") und analog `user_sync_strategy.dart:28`, `benefit_sync_strategy.dart:29`; `downloadFromRemote` wirft `UnimplementedError('PostgREST not yet configured')`; `processQueue` hat repo-weit **nur Definitionen, keine Aufrufer**; `lib/providers/connectivity_provider.dart:38-49` reagiert auf Reconnect, drainiert aber nichts.
  - *Abnahme:* Ein Integrationstest schaltet offline, erzeugt Session + Benefit, schaltet online und weist nach, dass `sync_queue` befüllt, drainiert und wieder leer ist; ein fehlgeschlagener Upload landet nach *n* Retries im Dead-Letter-Zustand statt still zu verschwinden.

- [ ] **BL-003 · P0 · M — Versionierte, idempotente Konfliktauflösung statt blindem Last-Write-Wins**
  - *Warum:* Ohne Versionszähler und Idempotenzschlüssel überschreibt der zweite Client die Arbeit des ersten; bei Belohnungsdaten heißt das doppelt vergebene oder verlorene Benefits.
  - *Evidenz:* ROADMAP.md „🟡 Phase 2"; `resolveConflict` in `lib/features/session/data/session_sync_strategy.dart:44 ff.` entscheidet rein nach Session-Status, ohne Version oder Vektor-Uhr.
  - *Abnahme:* Jede synchronisierte Entität trägt eine monoton steigende `version`; ein zweimal gesendeter Upload derselben Operation erzeugt genau eine serverseitige Änderung (Test mit doppeltem Request).

- [ ] **BL-004 · P1 · M — `sync_queue`-Schema für echte Zustellgarantien härten**
  - *Warum:* Die Tabelle existiert seit v1, aber ohne Retry-Zähler-Semantik, Dead-Letter-Status und Idempotenzschlüssel ist sie nur eine Liste, keine Queue.
  - *Evidenz:* `lib/features/shared/database/database_helper.dart:787` (`CREATE TABLE sync_queue`); kein Code schreibt je hinein (siehe BL-002).
  - *Abnahme:* Migration ergänzt die fehlenden Spalten; ein Unit-Test auf dem DAO deckt Einreihen, Retry-Inkrement, Backoff-Ablauf und Dead-Letter-Übergang ab.

- [ ] **BL-005 · P1 · M — Benefits als append-only Ledger + UUID-IDs statt Timestamp + REPLACE**
  - *Warum:* `UserBenefit`-IDs werden aus `DateTime.now().millisecondsSinceEpoch` abgeleitet und mit `ConflictAlgorithm.replace` eingefügt. Zwei Vergaben in derselben Millisekunde überschreiben sich, und ein Upsert vom Server kann eine bestehende Vergabe ersetzen statt sie zu ergänzen.
  - *Evidenz:* `lib/features/benefit/data/benefit_repository_impl.dart:95-99` (Timestamp-ID) gegenüber `lib/providers/activity_provider.dart:317`, das für Sessions korrekt `Uuid().v4()` nutzt; `lib/features/benefit/data/benefit_dao.dart:97-104` (REPLACE).
  - *Abnahme:* Vergabe-IDs sind UUIDv4; das Vergabe-Journal kennt nur INSERT (Widerruf = Gegenbuchung); ein Test vergibt zweimal in derselben Millisekunde und erhält zwei Zeilen.

- [ ] **BL-006 · P1 · M — Sync-Observability: Queue-Metriken und strukturierte Fehler**
  - *Warum:* Ohne Sichtbarkeit auf Queue-Länge, Alter des ältesten Eintrags und Fehlerklassen merkt niemand, dass der Sync steht — genau die Situation, in der die App heute schon ist.
  - *Evidenz:* ROADMAP.md „🟡 Phase 2" (`Sync-Observability + Remote-Kill-Switch vor Go-Live`); kein Zähler oder Sentry-Breadcrumb im Sync-Pfad.
  - *Abnahme:* Ein Debug-Screen bzw. Sentry-Kontext zeigt Queue-Tiefe, letzte erfolgreiche Synchronisation und die letzten *n* Fehler mit Klassifikation.

- [ ] **BL-007 · P1 · S — `AuthInterceptor`-Retry umgeht den gepinnten Dio-Client**
  - *Warum:* Der Wiederholungspfad nach Token-Refresh baut sich seinen eigenen Transport und hebt damit genau die Pinning-Garantie auf, die der Hauptpfad aufstellt — die klassische Downgrade-Lücke.
  - *Evidenz:* `lib/core/network/auth_interceptor.dart:138-148` — `_retryRequest()` baut mit `Dio().request(...)` eine **frische, ungepinnte** Instanz, statt den in `lib/core/network/api_client.dart:48-53` gepinnten Client zu verwenden. Aktuell folgenlos, weil der ganze Netzwerk-Stack toter Code ist — vor der ersten echten Anfrage aber ein Blocker.
  - *Abnahme:* Der Retry benutzt dieselbe `Dio`-Instanz wie der Originalrequest; ein Test mit einem falsch gepinnten Host lässt auch den Retry scheitern.

- [ ] **BL-008 · P1 · XL — Server-seitige Anomalie-Erkennung / Fraud-Flagging**
  - *Warum:* Belohnungen ohne serverseitige Plausibilitätsprüfung laden zum Manipulieren ein; ein Fahrrad, ein Mock-Location-Provider oder ein manueller Eintrag erzeugen heute dieselben Punkte wie ein echter Lauf.
  - *Evidenz:* ROADMAP.md „⚖️ Übergreifende Lücken" (`Reward-Integrity / Anti-Cheat`); der komplette Trust-/Scoring-Layer im Client ist unbenutzt (siehe BL-017).
  - *Abnahme:* Der Server bewertet jede eingehende Session (Geschwindigkeitsprofil, Sensorquelle, Gerätetrust) und kann sie als `flagged` markieren; geflaggte Sessions erzeugen keine Belohnung, bis sie freigegeben sind.

---

## 📍 Tracking & Sensorik

- [ ] **BL-009 · P0 · M — WP6: Geräte-Smoke der Background-Tracking-Runtime (Foreground-Service + Permission-Flow)**
  - *Warum:* WP1–WP5 sind vollständig im Code und unit-abgedeckt, aber keine einzige der Phase-2-Checkboxen ist auf einem echten Gerät abgehakt. Ohne diesen Durchlauf ist unbekannt, ob die zentrale Phase-2-Investition überhaupt funktioniert.
  - *Evidenz:* Code-Seite verifiziert: `lib/features/shared/sensors/gps_sensor.dart:236-283` (`buildLocationSettings` mit `ForegroundNotificationConfig`, `enableWakeLock`, `setOngoing`), `android/app/src/main/AndroidManifest.xml:10-15` (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `WAKE_LOCK`), `ios/Runner/Info.plist:56-59` (`UIBackgroundModes: [location]`). In `documentation/DEVICE_SMOKE_CHECKLIST.md` stehen alle **8** Boxen unter „Foreground-Service / GPS im Hintergrund (WP2)" und alle **3** unter „Permissions (WP3)" auf ⬜ — elf offene Punkte.
  - *Abnahme:* Alle elf Phase-2-Checkboxen in `documentation/DEVICE_SMOKE_CHECKLIST.md` sind mit Datum abgehakt; eine 5–10-minütige Hintergrund-Session liefert eine lückenlose Route, die Ongoing-Notification erscheint und verschwindet korrekt, und logcat zeigt keine `MissingForegroundServiceTypeException` (targetSdk 36).

- [ ] **BL-010 · P0 · S — GPS akkumuliert Distanz weiter, während die Session pausiert ist**
  - *Warum:* Wer an der Ampel oder im Café pausiert und weiterläuft, sammelt Distanz, die die (korrekt aus Timestamps abgeleitete) Dauer nicht enthält. Das ergibt unmögliche Pace-Werte und eine überhöhte, belohnungsrelevante Distanz.
  - *Evidenz:* `lib/providers/activity_provider.dart:372` — `pauseSession()` stoppt Timer, schließt das Segment und flusht den Puffer, kündigt aber `_gpsSubscription` nie (`_stopGpsTracking` wird ausschließlich aus `stopSession` gerufen). `_onGpsPoint` (`:823`) prüft in `:824` nur `_currentSession == null`, nie `_trackingState`. `lib/features/shared/sensors/sensor_manager.dart:146` — `pauseSession()` ist ein dokumentierter leerer Rumpf und wird ohnehin nicht aufgerufen.
  - *Abnahme:* Solange `_trackingState == TrackingState.paused` ist, verändert kein eingehender GPS-Punkt `_currentDistance` oder `_sessionGpsPoints`. Unit-Test: start → pause → 5 Punkte à 100 m einspeisen → Distanz unverändert; resume → nächster Punkt zählt wieder, ohne die Pausenlücke zu addieren.

- [ ] **BL-011 · P0 · S — Logout/User-Wechsel: nicht awaiteter Aufruf rennt gegen den State-Reset**
  - *Warum:* Die laufende Session wird beim Abmelden nie abgeschlossen und bleibt dauerhaft als `active` in der Datenbank stehen — genau die Zeilen, die BL-012 später wiederherstellen müsste.
  - *Evidenz:* `lib/providers/activity_provider.dart:177-190` — `updateUserId()` ist ein **plain `void`** und ruft `_completeSessionOnUserChange();` ohne `await` (Zeile 185), unmittelbar gefolgt von `_resetSessionState()` (Zeile 189), das `_currentSession` auf `null` setzt. Weil `updateUserId` nicht `async` ist, greift der aktivierte Lint `unawaited_futures` hier nicht.
  - *Abnahme:* Ein Test startet eine Session, ruft `updateUserId(neueId)` und weist danach in der DB eine `completed`-Session mit gesetzter `end_time` nach; kein `Null check operator`-Fehler im Log.

- [ ] **BL-012 · P1 · L — Session-Recovery nach Process-Kill**
  - *Warum:* Phase A hat bewusst kein Background-Isolate; ein OS-Kill beendet das Tracking. Es gibt aber keinen Wiederaufnahmepfad: Dauer-Akkumulator, Punkteliste und Tracking-State liegen ausschließlich im RAM, und `SessionDao.findActive()` — die einzige Abfrage, die verwaiste Sessions finden könnte — hat repo-weit keinen Aufrufer.
  - *Evidenz:* `lib/features/session/data/session_dao.dart:49` (`findActive`, keine Aufrufer); `lib/providers/activity_provider.dart:50-61` (In-Memory-State); `lib/features/shared/sensors/gps_sensor.dart:186-188` (Kommentar „not across a process kill"). Teilweise gerettet wird nur der GPS-Puffer: `lib/main.dart:254-259` flusht bei `AppLifecycleState.paused/inactive`.
  - *Abnahme:* Nach einem erzwungenen App-Kill während einer Session bietet der nächste Start an, die Session fortzusetzen oder abzuschließen; Distanz und aktive Dauer entsprechen den persistierten Punkten/Segmenten.

- [ ] **BL-013 · P1 · M — GPS erholt sich nicht, wenn die Ortung beim App-Start ausgeschaltet war**
  - *Warum:* War „Standort" beim Kaltstart aus, bleibt der Sensor für die gesamte Prozesslaufzeit auf `unavailable` — auch nachdem der Nutzer die Ortung in den Einstellungen einschaltet. Tracking ist bis zum Neustart der App tot.
  - *Evidenz:* `lib/main.dart:121` ruft `sensorManager.initialize()` genau einmal; `lib/features/shared/sensors/sensor_manager.dart:62-63` kehrt bei erneutem Aufruf sofort zurück; `lib/features/shared/sensors/gps_sensor.dart:52-59` setzt `unavailable`, `:166-173` blockt `startStreaming`; `lib/providers/activity_provider.dart:777-787` (`retryGpsIfNeeded`) behandelt nur `denied`/`permanentlyDenied`.
  - *Abnahme:* Ortung aus → App starten → Ortung einschalten → App in den Vordergrund holen → Session starten liefert GPS-Punkte, ohne die App neu zu starten. Regressionstest über einen Fake-Sensor.

- [ ] **BL-014 · P1 · M — GPS-Stream-Fehler, Signalverlust und Zeit-/Zeitzonenwechsel sind unsichtbar**
  - *Warum:* Bricht der Standort-Stream mitten in der Session ab, läuft der Timer weiter und die UI zeigt unverändert „Tracking" — der Nutzer merkt erst am leeren Ergebnis, dass nichts aufgezeichnet wurde. Für Tunnel/Signalverlust gibt es keine definierte Semantik (interpolieren, splitten, verwerfen).
  - *Evidenz:* `lib/features/shared/sensors/gps_sensor.dart:296 ff.` (Fehlerpfad des Streams ohne UI-Kanal); `documentation/sessions/BACKGROUND_TRACKING_PLAN.md` benennt Gap-Handling und den Uhr-/Zeitzonenwechsel als bekannte WP4-Grenze; der Altersfilter des GPS-Puffers wird bei leerem Puffer nicht zurückgesetzt (`lib/providers/activity_provider.dart:805-806, 849-852`).
  - *Abnahme:* Ein Stream-Fehler und eine Lücke > *n* Sekunden erzeugen einen sichtbaren, nicht blockierenden Hinweis in der Tracking-UI; die Lückenbehandlung ist dokumentiert und durch Unit-Tests fixiert.

- [ ] **BL-015 · P1 · M — Akku-Budget: adaptives Sampling, Doze/App-Standby und OEM-Whitelisting**
  - *Warum:* Ein Foreground-Service mit `enableWakeLock` läuft dauerhaft mit der eingestellten Genauigkeit. Ohne gemessenes mAh/h-Ziel ist unbekannt, was eine Stunde Tracking kostet; auf MIUI/EMUI/One UI killt die aggressive Akku-Optimierung den Service zusätzlich, ohne dass der Nutzer davon erfährt.
  - *Evidenz:* ROADMAP.md „⚖️ Übergreifende Lücken" (`Akku-Budget (mAh/h-Ziel, adaptive Sampling, Doze/App-Standby-Test)`); `lib/features/shared/sensors/gps_sensor.dart:236-283` setzt feste Intervalle ohne Adaption; `documentation/sessions/BACKGROUND_TRACKING_PLAN.md` führt den OEM-Whitelisting-Hinweis als offenen Punkt.
  - *Abnahme:* Ein dokumentierter Messwert (mAh/h auf dem Referenzgerät) liegt vor, das Sampling passt sich an Aktivitätstyp/Geschwindigkeit an, und bei erkannter aggressiver Akku-Optimierung führt ein einmaliger Hinweis in die passenden Systemeinstellungen.

- [ ] **BL-016 · P1 · M — Scoring-/Trust-Layer verdrahten (inkl. Cross-Validation)**
  - *Warum:* Die gesamte Anti-Gaming-Schicht ist gebaut, getestet — und wird nirgends aufgerufen. Genau dieser Layer ist das fachliche Alleinstellungsmerkmal der App und läuft heute in keiner einzigen Session.
  - *Evidenz:* `lib/core/config/tracking_config.dart:22` — `TrackingConfig.` kommt außerhalb der eigenen Doc-Kommentare nirgends vor; `lib/core/config/hr_device_profiles.dart:55` wird ausschließlich von `test/core/config/hr_device_profiles_test.dart` referenziert; `lib/providers/activity_provider.dart:481-573` (`stopSession`) berechnet keinen Score.
  - *Abnahme:* `stopSession` berechnet einen Score aus Distanz, Aktivitätstyp und Sensor-Trust und persistiert ihn an der Session; ein Unit-Test belegt, dass Brustgurt- und Handgelenk-Quelle unterschiedliche Multiplikatoren ergeben.

- [ ] **BL-017 · P2 · XL — Phase B: `continuousDaily`-Runtime, die einen App-Kill überlebt**
  - *Warum:* Ein ganzes Subsystem (~750 LOC Provider-Logik, 3 Tabellen, 3 DAOs, 1 Repository) liegt unerreichbar im Code. `_startContinuousSession()` läuft nur, wenn `_wasContinuousActive` gesetzt ist — und das setzt ausschließlich `_endContinuousSessions()`, wenn es eine bereits aktive continuousDaily-Session findet. Nichts erzeugt je die erste: eine selbstbezügliche Schleife ohne Einsprungpunkt.
  - *Evidenz:* `lib/providers/activity_provider.dart:597-687`; `lib/core/enums/tracking_mode.dart:7`; `lib/features/session/data/continuous_tracking_repository_impl.dart:13-33` — `grep` nach `ContinuousTrackingRepositoryImpl|ContinuousTrackingConfigDao|ContinuousTrackingStateDao|ActivitySegmentDao` trifft nur diese vier Dateien selbst; die Tabellen liegen seit v11 im Schema (`lib/features/shared/database/database_helper.dart:114, 133, 154`).
  - *Abnahme:* Entweder ist Phase B mit Background-Isolate, Reset-Point-Scheduler und Übergangslogik manuell ↔ kontinuierlich funktionsfähig und durch einen Geräte-Smoke belegt — oder der Code und die drei Tabellen sind entfernt und die Entscheidung ist im Decision-Record festgehalten.

- [ ] **BL-018 · P2 · M — Pedometer/OS-Schrittzähler + Sensor-Capability-Detection**
  - *Warum:* GPS allein deckt Indoor-Aktivität nicht ab und ist die einfachste zu manipulierende Quelle. Ein zweiter, unabhängiger Kanal ist die Voraussetzung für die Cross-Validation aus BL-016 — und die App muss vorher wissen, welche Sensoren das Gerät überhaupt hat.
  - *Evidenz:* `documentation/sessions/BACKGROUND_TRACKING_PLAN.md` (Pedometer-Integration und Capability-Detection als eigene Arbeitspakete); in `lib/features/shared/sensors/` existiert nur `gps_sensor.dart`.
  - *Abnahme:* Ein `SensorCapabilityService` meldet pro Gerät verfügbare Quellen; Schritte werden pro Session erfasst, persistiert und in der Session-Detailansicht angezeigt.

- [ ] **BL-019 · P2 · M — BLE-/Herzfrequenz-Disconnect während einer laufenden Session**
  - *Warum:* Reißt die Verbindung zum Brustgurt ab, hört die HR-Aufzeichnung still auf; die Session wird mit einem Bruchteil der Werte gespeichert, ohne dass jemand es merkt.
  - *Evidenz:* `lib/features/wearable_integration/data/sensors/heart_rate_sensor.dart:184` (Disconnect ohne Benachrichtigungskanal); `lib/features/wearable_integration/data/sources/ble_data_source.dart:60-79` — `FlutterBluePlus.startScan(...)` läuft **vor** dem `scanResults.listen(...)` (Ergebnisse aus dem ersten Moment können verloren gehen), danach blockiert `await Future.delayed(timeout)` den ganzen Scan-Zeitraum.
  - *Abnahme:* Ein Disconnect erzeugt einen sichtbaren Hinweis und einen automatischen Reconnect-Versuch; die Session-Zusammenfassung weist die HR-Abdeckung in Prozent aus.

- [ ] **BL-020 · P3 · L — Automatische Aktivitätserkennung (Geschwindigkeitsklassifikation, später ML)**
  - *Warum:* Manuelle Typwahl ist eine Reibung im wichtigsten Flow und eine offene Flanke für Fehlklassifikation (Rad als Lauf gemeldet). Der geschwindigkeitsbasierte Klassifikator ist der pragmatische erste Schritt; ein On-Device-TFLite-Modell wäre die spätere Ausbaustufe.
  - *Evidenz:* `documentation/sessions/BACKGROUND_TRACKING_PLAN.md` (Auto-Detection und ML-Mustererkennung als spätere Pakete); `lib/core/enums/activity_type.dart` modelliert 12 Typen, die UI erzwingt einen (siehe BL-076).
  - *Abnahme:* Nach einer Session schlägt die App einen Aktivitätstyp vor, den der Nutzer bestätigen oder korrigieren kann; die Trefferquote ist auf einem Referenz-Datensatz dokumentiert.

---

## ⌚ Wearables

- [ ] **BL-021 · P1 · M — Kein durchgängiger Wearable-Pfad: die HR-UI ist abgeklemmt, Live-HR-Writes würden am Foreign Key scheitern**
  - *Warum:* Der komplette Herzfrequenz-Pfad ist gebaut, aber im ausgelieferten Build nicht erreichbar: Die Tracking-UI ruft `startSession()` ohne `heartRateDeviceId` auf, also wird der HR-Zweig nie betreten. Selbst wenn er es würde, ist das gekoppelte Gerät nie in `wearable_devices` registriert — und weil `PRAGMA foreign_keys = ON` aktiv ist, würde der erste HR-Insert an der Fremdschlüsselbedingung scheitern.
  - *Evidenz:* `lib/presentation/screens/activity/activity_screen.dart:107` (`provider.startSession()` ohne Argument) gegenüber `lib/providers/activity_provider.dart:288` (`startSession({String? heartRateDeviceId})`) und `:913-967`; `lib/features/shared/database/database_helper.dart:72` (`PRAGMA foreign_keys = ON`) und `:394` (FK auf `device_id`); einziger `WearableDeviceDao.insert`-Aufrufer ist `lib/core/seed/seed_service.dart:305-309`, also ausschließlich der Debug-Seeder.
  - *Abnahme:* Ein gekoppeltes Gerät landet als Zeile in `wearable_devices`; eine Session, die mit diesem Gerät gestartet wird, schreibt HR-Werte nach `session_biometric_data` und zeigt sie live an — auf dem Gerät verifiziert.

- [ ] **BL-022 · P1 · M — Jeder Screen konstruiert seine eigene `BleDataSource`**
  - *Warum:* Drei unabhängige Instanzen können sich Verbindungszustand konstruktionsbedingt nicht teilen. Was der Pairing-Screen verbindet, weiß der Tracking-Provider nicht — eine funktionierende Kopplung ist damit nicht übertragbar.
  - *Evidenz:* `lib/providers/activity_provider.dart:108`, `lib/presentation/screens/wearable/device_pairing_screen.dart:22`, `lib/presentation/screens/wearable/device_connection_screen.dart:31` — drei getrennte `BleDataSource()`-Konstruktionen.
  - *Abnahme:* Es existiert genau eine `BleDataSource`-Instanz (per Provider injiziert); ein Widget-Test koppelt im Pairing-Screen und liest denselben Verbindungszustand im Activity-Screen.

- [ ] **BL-023 · P1 · S — `HealthPlatformProvider.initialize()` wird nie aufgerufen**
  - *Warum:* Der Provider ist registriert, aber uninitialisiert: Der Verbindungszustand zu Health Connect / HealthKit wird nach einem Neustart nicht wiederhergestellt und der automatische Sync feuert nie.
  - *Evidenz:* `lib/main.dart:196` registriert `HealthPlatformProvider()`; `grep` nach `.initialize(` in `lib/` findet nur `sensorManager` (`main.dart:121`), `deepLinkHandler` (`:146`), `AppLockProvider` (`:222`) und `AuthProvider` — kein einziger Aufruf auf dem Health-Provider.
  - *Abnahme:* Der Provider wird beim Start (bzw. beim ersten Betreten des Wearable-Bereichs) initialisiert; ein Test belegt, dass ein zuvor verbundener Zustand nach Neustart wiederhergestellt ist.

- [ ] **BL-024 · P2 · L — F4: Pairing an OS / Health Connect delegieren statt eigenem BLE-Scan (schließt F3 mit)**
  - *Warum:* Der eigene `flutter_blue_plus`-Flow ist der aufwendigste und fehleranfälligste Teil der Wearable-Integration und produziert genau die Fehler aus dem Geräte-Smoke. Der „Grant Permission"-Button fordert obendrein gar keine Berechtigung an, und nach Rückkehr aus den Systemeinstellungen wird nichts erneut geprüft — der Screen bleibt bei „connection failed" stehen.
  - *Evidenz:* ROADMAP.md „🔧 Geräte-Smoke-Findings" F3/F4 (Entscheidung getroffen, aufgeschoben bis ein Testgerät verfügbar ist); `lib/features/wearable_integration/data/sources/ble_data_source.dart:135-144` — `requestPermissions()` fordert **nichts** an, sondern prüft nur `FlutterBluePlus.isSupported` und den Adapter-Status; es ist Zeile für Zeile identisch mit `hasPermissions()` (`:147-154`). `lib/presentation/screens/wearable/device_pairing_screen.dart:61-81` hängt den „Grant Permission"-Pfad genau daran: Fehlt die Laufzeitberechtigung `BLUETOOTH_SCAN`/`BLUETOOTH_CONNECT`, bleibt der Nutzer dauerhaft bei „Bluetooth permissions are required to scan for devices."
  - *Abnahme:* Kopplung läuft über den OS-/Health-Connect-Dialog; F3 und F4 sind in ROADMAP.md abgehakt und in `documentation/DEVICE_SMOKE_CHECKLIST.md` mit Datum auf einem Gerät bestätigt.

- [ ] **BL-025 · P2 · M — iOS-HealthKit: Entitlements-Datei ist verwaist, `configure()` wird nie aufgerufen**
  - *Warum:* Die HealthKit-Capability ist deklariert, aber nicht ins Xcode-Projekt eingebunden — der Build trägt sie nicht. Auf iOS gäbe es damit keinen Gesundheitsdaten-Zugriff, obwohl die Doku ihn zusagt.
  - *Evidenz:* `ios/Runner/Runner.entitlements:5-9` deklariert `com.apple.developer.healthkit`; `grep -c entitlement ios/Runner.xcodeproj/project.pbxproj` = **0** — die Datei ist in keiner Build-Phase referenziert. Zusätzlich findet `grep configure()` in `lib/` keinen Treffer, obwohl das `health`-Plugin ihn vor der Nutzung verlangt.
  - *Abnahme:* Die Entitlements-Datei hängt am Runner-Target, `health.configure()` läuft vor dem ersten Zugriff, und ein iOS-Build zieht die Capability nachweislich (Build-Log oder Xcode-Capability-Tab).

- [ ] **BL-026 · P2 · S — Health-Connect-Verdrahtungsfehler: invertierte Install-Erkennung, falsche Intent-Action, ungenutzte Permissions**
  - *Warum:* Drei kleine Konfigurationsfehler, die je für sich den Health-Connect-Pfad auf einem echten Gerät kippen — und die nur auf einem Gerät auffallen.
  - *Evidenz:* `lib/features/wearable_integration/data/sources/health_connect_source.dart:130-144` — `isHealthConnectInstalled()` gibt im `catch` `!e.toString().contains('permission launcher not found')` zurück, meldet also bei **jedem anderen** Fehler „installiert"; `android/app/src/main/AndroidManifest.xml:96-104` (Privacy-Policy-Activity-Alias mit einer Intent-Action, die von der im `health`-README dokumentierten abweicht); `AndroidManifest.xml:25, 47-48, 52-53` (deklarierte Health-Permissions ohne Code dahinter) gegenüber `health_sync_service.dart:116` (synchronisiert einen Typ, für den nie eine Berechtigung angefragt wird).
  - *Abnahme:* Auf einem Gerät ohne Health Connect führt der Flow in den Play-Store-Pfad statt in einen Fehler; der Privacy-Policy-Eintrag wird von Health Connect aufgelöst; Manifest-Permissions und angefragte Typen stimmen paarweise überein.

- [ ] **BL-027 · P3 · M — Herzfrequenz-Quellenerkennung (Brustgurt vs. Handgelenk) über die Health-APIs**
  - *Warum:* Die Trust-Multiplikatoren aus BL-016 setzen voraus, dass die App weiß, *woher* ein HR-Wert stammt. Ohne Quellenerkennung ist jeder Wert gleich viel wert — und damit gleich leicht zu fälschen.
  - *Evidenz:* `lib/core/config/hr_device_profiles.dart:65-80, 171-221` unterscheidet Gerätetypen bereits vollständig, wird aber nur von seinem eigenen Test benutzt; `lib/features/wearable_integration/data/services/health_sync_service.dart:269-294` liest HR ohne Quellenauswertung.
  - *Abnahme:* Importierte HR-Werte tragen ihre Quelle; die Session-Zusammenfassung zeigt sie an, und der Score verwendet den passenden Multiplikator.

---

## 🔒 Security & Datenschutz

- [ ] **BL-028 · P0 · L — Echte Auth: `RealAuthService` + `ApiClient`/`AuthInterceptor` verdrahten**
  - *Warum:* Die gesamte Authentifizierung ist ein Mock, dessen sicherheitsrelevanter Zustand im RAM einer statischen Map liegt. Der vollständige Netzwerk-Stack (Client, Interceptor, Pinning) existiert, wird aber nirgends konstruiert — es gibt keinen Pfad, auf dem ein Passwort je einen Server erreicht.
  - *Evidenz:* `lib/features/auth/data/auth_service.dart:128` (statischer In-Memory-Zustand), `:144-153`, `:317-325`; `grep 'ApiClient('` über `lib/`, `test/`, `integration_test/` liefert genau einen Treffer: die Definition in `lib/core/network/api_client.dart:15`. Die Mock-Codes werden zudem im Release-Build in der UI angezeigt (`lib/presentation/screens/auth/forgot_password_screen.dart:79`, `email_verification_screen.dart:118-123`, `lib/presentation/screens/profile/profile_screen.dart:1261-1262`) — nur der Login-Screen gated korrekt (`login_screen.dart:513`).
  - *Abnahme:* Login, Registrierung, Reset und Löschung laufen über `RealAuthService` gegen das in BL-001 gewählte Backend; `AuthService` hält keinen statischen Zustand mehr; kein Verifizierungs- oder Reset-Code erscheint im Release-Build in der UI.

- [ ] **BL-029 · P0 · M — Passwort-Hashing server-seitig (Argon2id); lokale Hashes abschaffen**
  - *Warum:* Passwörter werden mit **einer einzigen Runde SHA-256 ohne Salt** gehasht und in einer unverschlüsselten SQLite-Spalte abgelegt. Eine Rainbow-Table bricht das in Sekunden; ohne `allowBackup="false"` (siehe BL-041) kann die Datei zudem über ADB-Backup das Gerät verlassen.
  - *Evidenz:* `lib/core/utils/password_utils.dart:9-13` (`sha256.convert(utf8.encode(password))`, kein Salt, keine Iterationen); `lib/features/auth/data/auth_service.dart:128-141`; Spalte `password_hash TEXT NOT NULL` in `lib/features/shared/database/database_helper.dart:609`.
  - *Abnahme:* Auf dem Gerät liegt kein Passwort-Hash mehr; die Verifikation erfolgt server-seitig mit Argon2id (dokumentierte Parameter); ein Migrationspfad entfernt bestehende `password_hash`-Werte.

- [ ] **BL-030 · P0 · S — Echte SPKI-Pins statt Platzhaltern (und der Pinning-Hook ist invertiert)**
  - *Warum:* Die „Certificate Pinning"-Implementierung kann prinzipbedingt nichts pinnen: Die Fingerprints sind Platzhalter-Strings. Sobald der Netzwerk-Stack scharf geschaltet wird (BL-028), ist das eine stille Falschsicherheit.
  - *Evidenz:* `lib/core/network/certificate_pinning.dart:31-36` — `'sha256/PLACEHOLDER_PRIMARY_CERT_FINGERPRINT_BASE64_ENCODED'` und dasselbe für das Backup-Zertifikat, mit `// TODO: Replace with real certificate fingerprints before production`.
  - *Abnahme:* Zwei echte SPKI-Pins (aktuell + Rotationsreserve) sind hinterlegt, der Validierungs-Hook lehnt einen nicht passenden Host nachweislich ab (Test gegen ein falsches Zertifikat), und die Rotationsprozedur ist dokumentiert.

- [ ] **BL-031 · P0 · M — Echte JWT-Validierung, Ablauf und Refresh-Rotation**
  - *Warum:* Tokens haben das Format `mock::{type}::{userId}::{random}` — sie sind unsigniert, nicht verifizierbar und laufen nie ab. Die Identität steckt im Klartext im Token und ist damit vom Angreifer frei wählbar.
  - *Evidenz:* `lib/features/auth/data/auth_service.dart:201-208` (`_generateMockToken`), `:264-284`, `:287-291` (Logout invalidiert nichts); `lib/providers/auth_provider.dart:136-156`.
  - *Abnahme:* Der Client akzeptiert nur signierte Tokens mit `exp`; abgelaufene Access-Tokens werden über einen rotierenden Refresh-Token erneuert; ein Logout macht das Refresh-Token server-seitig ungültig.

- [ ] **BL-032 · P0 · M — Server-seitiges Rate-Limiting, Lockout und Autorisierung**
  - *Warum:* Der Limiter schützt ausschließlich das Login-Formular, ist geräte-global (kein Schlüssel pro Konto) und lässt sich durch Neuinstallation trivial zurücksetzen. Registrierung, Passwort-Reset, Verifizierung, Passwortwechsel und Kontolöschung sind völlig ungebremst.
  - *Evidenz:* `lib/providers/auth_provider.dart:207, 242, 286` (Limiter nur im Login-Pfad) — kein Aufruf in `:490`, `:631`, `:724`, `:770`, `:829`; `lib/features/security/data/rate_limit_storage.dart:14-16` (kein kontobezogener Schlüssel).
  - *Abnahme:* Alle fünf Auth-Endpunkte sind server-seitig pro Konto **und** pro IP begrenzt; Lockout-Zustand überlebt eine Neuinstallation; die Grenzwerte sind dokumentiert.

- [ ] **BL-033 · P0 · L — Reward-Integrität: keine Belohnungshoheit auf dem Client (inkl. sichere Codes)**
  - *Warum:* Der Client entscheidet heute allein, ob und welcher Benefit fällig ist, und erzeugt den Einlösecode selbst. Die Codes sind sechs Zeichen lang und **rein zeitabgeleitet** (`BF` + Millisekunden mod 100000) — vorhersagbar und kollisionsanfällig. Alle sicherheitsrelevante Zufälligkeit stammt zudem aus `dart:math` `Random()` statt `Random.secure()`.
  - *Evidenz:* `lib/providers/benefit_provider.dart:172-176` (`_generateRedemptionCode`); `lib/features/auth/data/auth_service.dart:194`, `:202-206`, `:295-296` (`Random()` für Delay, Token und 6-stelligen Verifizierungscode).
  - *Abnahme:* Vergabe und Einlösecode entstehen server-seitig; jede clientseitig sicherheitsrelevante Zufallszahl kommt aus `Random.secure()`; ein Test weist nach, dass zwei Codes aus derselben Millisekunde verschieden sind.

- [ ] **BL-034 · P0 · L — DSGVO Art. 9: Rechtsgrundlage und Consent-Flow für dauerhafte GPS- und Herzfrequenzdaten**
  - *Warum:* Standortverlauf und Herzfrequenz sind Gesundheitsdaten im Sinne von Art. 9 DSGVO. Ohne dokumentierte Rechtsgrundlage und expliziten, granularen Consent ist der Betrieb in Österreich/EU nicht zulässig — unabhängig davon, wie gut die Technik ist.
  - *Evidenz:* ROADMAP.md „⚖️ Übergreifende Lücken" (`DSGVO/Art. 9: Consent für GPS+HR, …`); in `lib/` existiert kein Consent-Screen und keine Consent-Persistenz.
  - *Abnahme:* Ein granularer Consent-Flow (GPS, HR, Crash-Reporting getrennt) läuft vor der ersten Erhebung, ist widerrufbar, und der Widerruf stoppt die Erhebung nachweislich; die Rechtsgrundlage ist schriftlich festgehalten.

- [ ] **BL-035 · P0 · M — Server-seitige Löschpropagierung bei Kontolöschung**
  - *Warum:* Art. 17 DSGVO verlangt, dass die Löschung überall greift. Sobald Daten das Gerät verlassen (BL-002), reicht ein lokales `DELETE` nicht mehr.
  - *Evidenz:* ROADMAP.md „⚖️ Übergreifende Lücken"; `lib/providers/auth_provider.dart:663` löscht ausschließlich lokal (`_repository.deleteUser`) und danach die Tokens.
  - *Abnahme:* Die Löschung erzeugt einen server-seitigen Auftrag, dessen Abschluss quittiert wird; ein Test belegt, dass ein zweites Gerät desselben Kontos danach keine Daten mehr erhält.

- [ ] **BL-036 · P0 · M — Datenschutzerklärung + Permission-Rationale-UX**
  - *Warum:* Sowohl Play als auch der App Store verlangen eine erreichbare Datenschutzerklärung, und der Foreground-Service macht eine In-App-Erklärung *vor* dem Systemdialog nötig. Beides fehlt.
  - *Evidenz:* ROADMAP.md „⚖️ Übergreifende Lücken"; `lib/presentation/screens/` enthält keinen Datenschutz-Screen; der Permission-Flow aus WP3 zeigt keine vorgelagerte Begründung.
  - *Abnahme:* Eine verlinkte Datenschutzerklärung ist aus Profil und Store-Eintrag erreichbar; vor jedem Standort-/Notification-Systemdialog erscheint eine In-App-Begründung.

- [ ] **BL-037 · P0 · S — Manuelle Aktivitäten lecken zwischen Accounts**
  - *Warum:* Manuell erfasste Einträge liegen unter einem geräteglobalen SharedPreferences-Schlüssel **ohne User-ID**. Nach einem Account-Wechsel auf demselben Gerät sieht der neue Nutzer die Aktivitäten des vorigen — ein Datenschutzvorfall auf jedem geteilten oder weitergegebenen Gerät.
  - *Evidenz:* `lib/providers/progress_provider.dart:24` — `static const _prefKeyManualEntries = 'manual_entries';` (keine User-ID im Schlüssel), gelesen/geschrieben in `:212-235`.
  - *Abnahme:* Manuelle Einträge sind kontogebunden (bevorzugt in der Datenbank, siehe BL-052); ein Test meldet Nutzer A ab, Nutzer B an und weist eine leere Liste nach.

- [ ] **BL-038 · P1 · S — Die Log-Redaction ist genau auf dem Melde-Pfad wirkungslos**
  - *Warum:* Drei zusammenwirkende Lücken sorgen dafür, dass die eingebaute PII-Redaction genau dort nicht greift, wo Daten das Gerät verlassen — im Sentry-Report.
  - *Evidenz:* (1) `lib/core/logging/app_logger.dart:45-50` — `e()` redigiert für den lokalen Logger, sendet an Sentry aber `error ?? message`, also die **unredigierte** Message; von 37 `AppLogger.e`-Stellen übergeben nur 5 ein `error`-Argument. (2) `app_logger.dart:65` fordert **5+ Nachkommastellen** für Koordinaten, während die häufigste PII-Logzeile der App genau **4** ausgibt: `lib/providers/activity_provider.dart:832` (`toStringAsFixed(4)`, einmal pro akzeptiertem GPS-Punkt). (3) `app_logger.dart:60-63` erkennt nur `key: value`-Formen — quotierte JSON-Schlüssel sowie camelCase/snake_case-Varianten (`accessToken`, `refresh_token`) rutschen durch. Zusätzlich werden Klarnamen unredigierbar geloggt (`lib/providers/auth_provider.dart:162, 288, 553`, `lib/providers/profile_provider.dart:72`).
  - *Abnahme:* `AppLogger.e` sendet ausschließlich redigierte Inhalte an Sentry; Unit-Tests decken 4-stellige Koordinaten, quotierte JSON-Keys, camelCase-Tokennamen und Klarnamen ab.

- [ ] **BL-039 · P1 · M — 59 `debugPrint`-Stellen umgehen `AppLogger` und werden im Release zu Sentry-Breadcrumbs**
  - *Warum:* Die Migration auf `AppLogger` ist unvollständig — 59 Aufrufe stehen weiterhin direkt im Code. `sentry_flutter` hängt sich standardmäßig an `debugPrint` und macht jede dieser Ausgaben zum Breadcrumb — an der Redaction vorbei.
  - *Evidenz:* `grep -rho debugPrint lib/ --include=*.dart | wc -l` = **59** (ROADMAP.md Phase 0 vermerkt die Migration von 169 auf 56 — seither sind wieder welche dazugekommen, u. a. die vier „NOT IMPLEMENTED"-Stubs aus BL-083); `sentry_flutter`s `DebugPrintIntegration` ist über `enablePrintBreadcrumbs = true` per Default aktiv.
  - *Abnahme:* `lib/` enthält keine `debugPrint`-Aufrufe außerhalb der Logger-Fassade (per Lint durchgesetzt), oder `enablePrintBreadcrumbs` ist explizit deaktiviert.

- [ ] **BL-040 · P1 · M — Deep-Link-Passwort-Reset ist eine Sackgasse; Links sind unverifiziert**
  - *Warum:* Der Reset-Deep-Link existiert genau für das Szenario „Nutzer kommt aus der E-Mail" — und funktioniert in diesem Szenario nicht. Zusätzlich läuft alles über ein Custom Scheme statt über verifizierte `https`-Links, das jede andere App registrieren kann.
  - *Evidenz:* `lib/presentation/screens/auth/reset_password_screen.dart:39-41, :120-123` gegenüber `lib/providers/auth_provider.dart:749, :774-778` und `lib/features/auth/data/auth_service.dart:150, :408-411`; `lib/core/deep_link/deep_link_handler.dart:84-91` gegenüber `lib/core/router/app_router.dart:54-66` (F5 hat das Routing gefixt, nicht die dahinterliegende Zustandslogik).
  - *Abnahme:* Ein aus einer echten Reset-Mail geöffneter Link führt bis zum gesetzten neuen Passwort (auf dem Gerät verifiziert, warm und kalt); Android App Links (`assetlinks.json`) und iOS Universal Links (`apple-app-site-association`) sind verifiziert ausgeliefert.

- [ ] **BL-041 · P1 · M — App-Lock ist umgehbar; Android-Backup ist nicht gehärtet**
  - *Warum:* Vier Lücken heben den App-Lock in der Praxis auf: kein `biometricOnly`, kein `FLAG_SECURE` (Screenshots und Recents-Vorschau zeigen Inhalte), der Passwort-Fallback-Pfad hat keine Aufrufer, und der Master-Schalter wird nicht gelesen. Ohne `allowBackup="false"` wandert die unverschlüsselte SQLite-Datei zudem in Cloud-/ADB-Backups.
  - *Evidenz:* `lib/features/security/services/biometric_service.dart:155-157` (kein `biometricOnly`); `grep FLAG_SECURE` über `android/`, `ios/`, `lib/` → kein Treffer; `lib/providers/app_lock_provider.dart:161, :171` (keine Aufrufer) und `:81`/`:194` gegenüber `biometric_service.dart:232-243`; `android/app/src/main/AndroidManifest.xml` enthält weder `allowBackup` noch `dataExtractionRules` oder `fullBackupContent`.
  - *Abnahme:* App-Lock verlangt Biometrie oder Geräte-PIN ohne Umgehungspfad, `FLAG_SECURE` ist in gesperrten/sensiblen Zuständen gesetzt, `allowBackup="false"` sowie `dataExtractionRules` sind deklariert und in der gemergten Release-Manifest-Datei nachweisbar.

- [ ] **BL-042 · P1 · S — Kontolöschung und Logout lassen lokale Daten zurück**
  - *Warum:* Beide Vorgänge räumen nur einen Teil auf. Nach der Löschung bleiben die manuellen Einträge, der Seed-Flag und die App-Lock-Einstellungen im SharedPreferences liegen; der Logout erreicht keinen Server und setzt den Biometrie-Zustand nicht zurück. Auf iOS überleben Keychain-Tokens sogar die Deinstallation, während die Datenbank verschwindet — der nächste Installationsvorgang startet mit Tokens ohne zugehörigen Nutzer.
  - *Evidenz:* `lib/providers/auth_provider.dart:663-675` (nur `deleteUser` + `clearTokens`, kein `SharedPreferences`-Zugriff); `:314-345` (Logout); `lib/features/security/services/biometric_service.dart:251-253` hat in `lib/` keinen Aufrufer; `lib/features/auth/data/token_storage.dart:42` nutzt `KeychainAccessibility.first_unlock_this_device` ohne Erst-Start-Bereinigung.
  - *Abnahme:* Nach Kontolöschung enthält das Gerät keine Reste des Kontos mehr (DB, Preferences, Keychain, Secure-Storage); ein Erst-Start nach Neuinstallation verwirft vorhandene Keychain-Tokens.

- [ ] **BL-043 · P1 · M — Datenexport / Portabilität (Art. 20 DSGVO)**
  - *Warum:* Gesetzlich verpflichtend — und gleichzeitig die einzige Absicherung gegen Datenverlust in einer offline-only App: Geht das Gerät verloren, sind alle Sessions weg.
  - *Evidenz:* ROADMAP.md „⚖️ Übergreifende Lücken" (`Datenverlust offline-only: Export/Backup`); in `lib/` existiert kein Exportpfad.
  - *Abnahme:* Der Nutzer kann seine Daten in einem maschinenlesbaren Format (JSON oder GPX + JSON) exportieren; ein Test belegt Vollständigkeit über alle 16 Tabellen hinweg, soweit sie den Nutzer betreffen.

- [ ] **BL-044 · P2 · S — Passwort-Policy und generische Auth-Antworten**
  - *Warum:* Zwei Standardhärtungen, die vor dem Rollout erledigt sein sollten: Ohne Maximallänge ist ein DoS über sehr lange Eingaben möglich, ohne Abgleich gegen bekannte Leaks werden kompromittierte Passwörter akzeptiert — und unterschiedliche Fehlermeldungen für „unbekannte E-Mail" und „falsches Passwort" erlauben die Aufzählung existierender Konten.
  - *Evidenz:* `lib/features/auth/utils/password_validator.dart:14-33` prüft Mindestlänge 8, Groß-/Kleinbuchstabe und Ziffer — **keine** Maximallänge, kein Abgleich gegen bekannte Leaks; `lib/features/auth/data/auth_service.dart:215 ff.` (unterscheidbare Fehlerpfade je nach Existenz des Kontos); der Vergleich in `PasswordUtils.verifyPassword` (`lib/core/utils/password_utils.dart:17-20`) ist ein einfaches `==` und damit nicht laufzeitkonstant.
  - *Abnahme:* Maximallänge durchgesetzt, Abgleich gegen eine Leak-Liste (k-Anonymity), Vergleich laufzeitkonstant, und Login/Reset liefern für existierende und nicht existierende Konten dieselbe Antwort und Antwortzeit.

- [ ] **BL-045 · P3 · S — `resetPassword` meldet Erfolg ohne Zeile; `changePassword` schreibt den Hash zweimal**
  - *Warum:* Zwei kleine Korrektheitsfehler im Mock-Auth-Service, die bei der Migration auf den echten Dienst (BL-028) sonst mitwandern.
  - *Evidenz:* `lib/features/auth/data/auth_service.dart:455-461` prüft den Zielnutzer, `:474` meldet danach trotzdem Erfolg, wenn die Zeile inzwischen verschwunden ist; `:495-497` schreibt den Hash ein zweites Mal aus möglicherweise veraltetem In-Memory-Zustand (zusammen mit `lib/providers/auth_provider.dart:845-863`).
  - *Abnahme:* Beide Pfade sind durch Unit-Tests abgedeckt und melden bei fehlendem Ziel einen Fehler statt Erfolg.

---

## 🗄️ Datenhaltung & Integrität

- [ ] **BL-046 · P0 · M — Der Benefit-Katalog ist auf jedem Non-Debug-Install leer**
  - *Warum:* Seeding hängt am Debug-Modus. Ein Release- oder Profile-Build startet ohne Benefits, ohne Testnutzer und ohne Sessions — der Benefit-Tab ist leer und die Kernschleife hat nichts, was sie vergeben könnte. Jede Demo, die nicht auf einem Debug-Build läuft, zeigt eine leere App.
  - *Evidenz:* `lib/core/seed/seed_config.dart:6` (`isEnabled => AppConfig.seedEnabled`) und `lib/core/config/app_config.dart:35-37` (Default `kDebugMode`, überschreibbar per `--dart-define=SEED_ENABLED`).
  - *Abnahme:* Der Benefit-Katalog kommt aus einer produktionstauglichen Quelle (Backend oder mitgeliefertes, versioniertes Katalog-Asset), nicht aus dem Debug-Seeder; ein Release-Build zeigt nach dem ersten Login einen befüllten Benefit-Tab.

- [ ] **BL-047 · P1 · M — Die zehn Wearable-Spalten auf `sessions` werden nie geschrieben oder gelesen**
  - *Warum:* Seit Schema v4 trägt die `sessions`-Tabelle zehn Wearable-Spalten. Der Provider setzt die entsprechenden Felder beim Beenden einer Session — aber `SessionDao` bildet sie weder in `_toMap` noch in `_fromMap` ab. Die Werte werden still verworfen; jede Auswertung über Herzfrequenz oder Kalorien aus abgeschlossenen Sessions ist strukturell unmöglich.
  - *Evidenz:* Spalten in `lib/features/shared/database/database_helper.dart:419-435`; `lib/features/session/data/session_dao.dart:140-163` (`_fromMap`) und `:167-187` (`_toMap`) enthalten **keine** dieser Spalten (`grep avg_heart_rate|max_heart_rate|heart_rate_device_id` über `session_dao.dart` = 0 Treffer); `lib/providers/activity_provider.dart:520-526` setzt die Felder trotzdem.
  - *Abnahme:* Ein Round-Trip-Test schreibt eine Session mit allen zehn Wearable-Feldern, liest sie zurück und vergleicht Feld für Feld.

- [ ] **BL-048 · P1 · S — `UserDao.insert` nutzt REPLACE gegen `UNIQUE(email)` mit CASCADE-Kindern**
  - *Warum:* `ConflictAlgorithm.replace` löscht die Konfliktzeile und fügt neu ein. Weil `sessions`, `user_benefits` und die Präferenztabellen per `ON DELETE CASCADE` an `users.id` hängen, würde eine Registrierung mit einer bereits vorhandenen E-Mail die komplette Historie des bestehenden Nutzers löschen — heute nur latent, weil der Registrierungspfad vorher prüft. Verschärft wird das dadurch, dass der UNIQUE-Index auf `email` case-**sensitiv** ist, die Lookups aber case-**insensitiv** arbeiten: `A@x.at` und `a@x.at` sind zwei Zeilen, aber ein Login-Treffer.
  - *Evidenz:* `lib/features/user/data/user_dao.dart:55-62` (REPLACE); UNIQUE-Index in `lib/features/shared/database/database_helper.dart:624`; case-insensitiver Lookup in `lib/features/user/data/user_dao.dart:36` und `lib/features/auth/data/auth_service.dart:215`.
  - *Abnahme:* `insert` nutzt `abort`/`fail` und liefert einen definierten Fehler; E-Mails werden vor dem Schreiben normalisiert (lowercase) und der Index ist auf der normalisierten Form eindeutig; ein Test versucht die Doppelregistrierung und weist nach, dass die Historie unangetastet bleibt.

- [ ] **BL-049 · P1 · S — Der v12-Orphan-Cleanup übersieht die drei `ON DELETE SET NULL`-Spalten**
  - *Warum:* Der Cleanup löscht verwaiste **Zeilen**, setzt aber keine verwaisten **Werte** auf NULL. Drei Fremdschlüssel sind als `SET NULL` deklariert; zeigen sie nach einer Altdaten-Migration ins Leere, bleibt der Verstoß bestehen und `foreign_key_check` schlägt an, obwohl der Cleanup „erfolgreich" gelaufen ist.
  - *Evidenz:* `lib/features/shared/database/database_helper.dart:246-263` (die `orphanDeletes`-Liste enthält ausschließlich `DELETE`-Statements) gegenüber `:341` (`continuous_tracking_state.current_session_id … ON DELETE SET NULL`), `:365` und `:145` (jeweils `device_id … ON DELETE SET NULL`); Prüfung in `:79-92`.
  - *Abnahme:* Der Cleanup setzt dangling `SET NULL`-Werte auf NULL; ein Migrationstest erzeugt genau diesen Zustand und weist danach ein leeres `foreign_key_check` nach.

- [ ] **BL-050 · P1 · M — Frisch erzeugtes und hochmigriertes Schema divergieren; kein v1→v12-Kettentest**
  - *Warum:* Ein `onCreate`-Schema deklariert `password_hash TEXT NOT NULL`, der Migrationspfad ergänzt dieselbe Spalte als `TEXT DEFAULT ''` (also nullable). Zwei Nutzer mit derselben App-Version haben damit unterschiedliche Constraints — der klassische Nährboden für „geht bei mir, crasht beim Kunden". Getestet werden zudem nur die letzten beiden von zwölf Schema-Versionen.
  - *Evidenz:* `lib/features/shared/database/database_helper.dart:609` (`password_hash TEXT NOT NULL` im Create) gegenüber `:474-476` (`ALTER TABLE users ADD COLUMN password_hash TEXT DEFAULT ''`); `test/features/shared/database/migration_test.dart:67-105, 137-167` prüft ausschließlich `_migrateToV11` und `_migrateToV12`.
  - *Abnahme:* Ein Test migriert von v1 durch alle Versionen auf v12 und vergleicht das Ergebnis spaltenweise (inklusive Nullability und Indizes) mit einem frisch erzeugten v12-Schema.

- [ ] **BL-051 · P2 · M — Retention: `gps_points` und die Sensortabellen wachsen unbegrenzt**
  - *Warum:* Eine Stunde Tracking erzeugt hunderte GPS-Zeilen; nichts löscht je etwas. Die Löschprimitiven existieren, haben aber keinen Aufrufer — die Datenbank wächst über die gesamte Installationsdauer monoton.
  - *Evidenz:* `lib/features/session/data/gps_point_dao.dart:243` (`deleteOlderThan`, keine Aufrufer in `lib/`); dasselbe Bild in `lib/features/wearable_integration/data/daos/session_biometric_data_dao.dart:142` und `session_motion_data_dao.dart:142`; `lib/providers/health_platform_provider.dart:260` hat keine UI-Aufrufer. ROADMAP.md „⚪ Phase 3" führt `GPS-Retention (deleteOlderThan + VACUUM)`.
  - *Abnahme:* Eine konfigurierbare Aufbewahrungsfrist läuft periodisch, gefolgt von `VACUUM`; ein Test befüllt mit Altdaten und weist Löschung plus DB-Größenreduktion nach.

- [ ] **BL-052 · P2 · M — Manuelle Einträge liegen als unescapter SharedPreferences-Text neben der Datenbank**
  - *Warum:* Ein zweiter, paralleler Persistenzpfad an der Datenbank vorbei — ohne Transaktionen, ohne Fremdschlüssel, ohne Migrationen. Serialisiert wird mit `join('::')` ohne Escaping: Ein Aktivitätstyp oder eine ID, die `::` enthält, zerstört den Datensatz beim Lesen, und fehlerhafte Zeilen werden still verworfen.
  - *Evidenz:* `lib/features/session/domain/activity_entry.dart:57` (`toPrefString`, `.join('::')`) und die zugehörige `fromPrefString`; `lib/providers/progress_provider.dart:24, 212-235`; die Datenbank besitzt mit `sessions` bereits die passende Tabelle (`lib/features/shared/database/database_helper.dart:680`).
  - *Abnahme:* Manuelle Einträge liegen als reguläre Zeilen mit `is_manual`-Flag in `sessions` (mit Migration der Bestandsdaten aus den Preferences); der Prefs-Pfad ist entfernt.

- [ ] **BL-053 · P2 · S — Robustheitsreste der Datenschicht: Teil-Seeds, `session-active`, `onDowngrade`, lazy Init**
  - *Warum:* Vier kleine Defekte, die einzeln harmlos wirken und gemeinsam für schwer reproduzierbare Zustände sorgen.
  - *Evidenz:* `lib/core/seed/seed_service.dart:186-193, 217-230, 112` — ein teilweise fehlgeschlagener Seed setzt trotzdem das „fertig"-Flag; `lib/core/seed/seed_data.dart:180-191` legt eine `session-active`-Zeile an, die nie aufgeräumt wird, und `lib/core/enums/session_status.dart:13` (`cancelled`) hat gar keinen Produzenten; `lib/features/shared/database/database_helper.dart:57-65` besitzt keinen `onDowngrade`-Handler (ein Downgrade wirft zur Laufzeit); `:22-26, 39-46` initialisieren die Datenbank lazy ohne Synchronisation, sodass zwei parallele erste Zugriffe zwei Öffnungsvorgänge auslösen können.
  - *Abnahme:* Das Seed-Flag wird nur nach vollständigem Erfolg gesetzt; `session-active` wird aufgeräumt oder entfernt; `onDowngrade: onDatabaseDowngradeDelete` (oder ein bewusster Handler) ist gesetzt; die lazy Initialisierung ist über einen Completer serialisiert und durch einen Test mit parallelen Zugriffen abgedeckt.

---

## 🧪 Qualität & Test

- [ ] **BL-054 · P0 · S — Das CI-Format-Gate ist rot; damit läuft die gesamte Quality-Kette nicht**
  - *Warum:* `dart format --set-exit-if-changed` ist das erste Quality-Gate in `ci.yml`. Weil er fehlschlägt, kommen Analyze, Tests und Debug-Build am Branch gar nicht zur Ausführung — das Qualitätssignal ist derzeit nicht „einmal rot", sondern **ungemessen**.
  - *Evidenz:* `.github/workflows/ci.yml` (Schritt „Format check", vor „Analyze", „Tests", „Build debug APK"); lokal read-only nachgestellt: `dart format --set-exit-if-changed --output=none .` → `Formatted 205 files (3 changed)` mit `lib/presentation/screens/activity/activity_screen.dart`, `lib/providers/activity_provider.dart`, `test/unit/providers/activity_provider_test.dart` — alle drei aus den WP3/WP5-Commits.
  - *Abnahme:* `dart format --set-exit-if-changed --output=none .` endet mit Exit-Code 0, und der Quality-Job auf `feat/phase-2-background-tracking` ist über alle vier Schritte grün.

- [ ] **BL-055 · P1 · S — Coverage messen und die Baseline festschreiben**
  - *Warum:* CI misst Coverage überhaupt nicht, und ein lokal herumliegendes `coverage/lcov.info` ist ein veraltetes Artefakt aus 2025 mit vier Dateien (nie versioniert — `coverage/` ist gitignoriert). Ohne Gate kann die Abdeckung unbemerkt fallen — was in einer Codebasis mit ganzen Subsystemen bei 0 % der wahrscheinlichere Verlauf ist.
  - *Evidenz:* `.github/workflows/ci.yml` (Schritt „Tests" ohne `--coverage`); frisch regeneriert: **4396/9130 Zeilen = 48,1 %**; `.gitignore` enthält `/coverage/`; die Datei war nie eingecheckt (`git ls-files coverage/` ist leer), liegt aber lokal im Arbeitsverzeichnis.
  - *Abnahme:* CI erzeugt LCOV und bricht ab, wenn die Abdeckung unter die dokumentierte Baseline (48 %) fällt; die Baseline ist dokumentiert und wird bei jedem Lauf frisch erzeugt statt aus einem lokalen Altbestand gelesen.

- [ ] **BL-056 · P1 · M — Der Persistenz-Layer ist ungetestet: jede DAO außer `UserDao` liegt bei 0 %**
  - *Warum:* Zehn DAO-Dateien haben null abgedeckte Zeilen — ebenso `DistanceCalculator` und die Progress-Aggregation. Genau die Schicht, auf der jede Zahl der App beruht (Distanz, Dauer, Ersparnis), ist die am wenigsten geprüfte.
  - *Evidenz:* Regeneriertes LCOV: 10 DAO-Dateien mit 0 abgedeckten Zeilen; es existiert kein `distance_calculator_test.dart`, `gps_point_dao_test.dart` oder `session_dao_test.dart`. Die wiederverwendbare Naht ist bereits vorhanden und in `test/features/user/data/user_dao_test.dart:20` (`DatabaseHelper.debugDatabase`) vorgeführt.
  - *Abnahme:* `SessionDao`, `GpsPointDao`, `BenefitDao` und `DistanceCalculator` haben In-Memory-Tests (sqflite_common_ffi) für Insert/Update/Query/Batch; die Persistenz-Coverage liegt über 60 %.

- [ ] **BL-057 · P1 · M — Test-Blindstellen: Security-Oberfläche, Logging/Redaction, Wearable-Adapter**
  - *Warum:* Drei Bereiche mit hohem Schadenspotenzial und null Absicherung. Biometrie, App-Lock, Pinning, Interceptor und Deep-Links sind ungetestet; Logger, Redaction, Error-Handler und Sentry-Verdrahtung ebenfalls (obwohl BL-038 zeigt, wie leicht dort etwas durchrutscht); und die drei Wearable-Adapter haben weder Test noch Geräte-Smoke.
  - *Evidenz:* Kein Testfile referenziert `CertificatePinning`, `AuthInterceptor`, `ApiClient` oder `DeepLinkHandler`; kein Dateiname passt auf `*logger*` oder `*redact*`; `test/helpers/biometric_fakes.dart` wird nur von `test/helpers/app_harness.dart:110, 159` benutzt; auf Wearable-Seite existieren nur Domain-Tests (`test/features/wearable_integration/domain/…`) plus `test/unit/providers/health_platform_provider_test.dart:16` gegen einen Fake; `documentation/DEVICE_SMOKE_CHECKLIST.md:48` (Wearable-Abschnitt) ist unabgehakt.
  - *Abnahme:* Je Bereich existiert mindestens eine Testdatei, die den kritischen Pfad abdeckt (Pinning-Ablehnung, Redaction-Muster aus BL-038, Health-Connect-Permission-Ablehnung); der Wearable-Abschnitt der Geräte-Smoke-Checkliste ist abgehakt.

- [ ] **BL-058 · P1 · S — Fehlende Provider-Unit-Tests: `ProgressProvider`, `AppLockProvider`, `ConnectivityProvider`**
  - *Warum:* Drei Provider ohne eigene Tests — darunter der, der die gesamte Fortschrittsdarstellung berechnet, und der, der den App-Lock steuert.
  - *Evidenz:* `test/unit/providers/` enthält Tests für `ActivityProvider`, `AuthProvider`, `BenefitProvider`, `ProfileProvider` und `HealthPlatformProvider`, aber keine für die drei genannten.
  - *Abnahme:* Für jeden der drei Provider existiert eine Testdatei, die Lade-, Fehler- und Leerzustand sowie die Kernberechnung abdeckt.

- [ ] **BL-059 · P1 · M — Offene Geräte-Smokes aus Round 2a/2b/3 nachziehen**
  - *Warum:* Drei abgeschlossene Ausbaustufen — `go_router`-Migration, GPS-Batching, `AppConfig`/Provider-Split — sind unit-getestet, aber nie vollständig auf einem Gerät bestätigt worden. In Round 3 sind 15 Punkte offen, dazu der Batching-Durchlauf aus Round 2b und drei Nachbestätigungen aus Round 2a.
  - *Evidenz:* `documentation/DEVICE_SMOKE_CHECKLIST.md` — Round 3 trägt 4 ⬜ und 11 🟡 („unit-getestet, Hand-Häkchen fehlt"), Round 2b ein ⬜ (GPS-Batching), Round 2a drei 🟡.
  - *Abnahme:* Alle Checkboxen dieser drei Abschnitte sind mit Datum und Gerät abgehakt; gefundene Abweichungen sind als eigene `BL-`Einträge aufgenommen.

- [ ] **BL-060 · P2 · M — Die E2E-Suite besteht aus einem Fall, blockiert nichts und fasst das Tracking nie an**
  - *Warum:* Der einzige End-to-End-Test loggt sich ein und tippt durch die fünf Tabs. Er startet, pausiert oder stoppt nie eine Session, löst nie einen Benefit ein und meidet die einzige echte Karte ausdrücklich. Die gesamte Phase-2-Investition hat damit null End-to-End-Abdeckung — und der Workflow läuft ohnehin nur auf `push: main` und manuell.
  - *Evidenz:* `integration_test/app_happy_path_test.dart` — 65 Zeilen, **ein** `testWidgets`, mit dem Kommentar `// Walk the bottom-nav tabs (avoid Session Detail — its map fetches OSM tiles).`; `.github/workflows/e2e.yml:7-10` (`push: main` + `workflow_dispatch`).
  - *Abnahme:* Mindestens ein E2E-Fall durchläuft Session starten → pausieren → fortsetzen → stoppen → Ergebnis in der Historie sehen, und einer löst einen Benefit ein.

- [ ] **BL-061 · P2 · S — Analyzer-Gate auf `test/` ausweiten und `strict-raw-types`/`strict-inference` aktivieren**
  - *Warum:* CI analysiert nur `lib/`; die 64 Test-Dateien laufen außerhalb jedes Gates — obwohl sie heute schon sauber sind, der Einstieg also kostenlos wäre. Die beiden verbleibenden strengen Analyzer-Modi sind laut Kommentar „auf Phase 1 verschoben"; Phase 1 ist abgeschlossen.
  - *Evidenz:* `.github/workflows/ci.yml` Schritt „Analyze (lib, fatal-infos)" → `dart analyze --fatal-infos lib`; lokal ist `dart analyze --fatal-infos test integration_test` bereits sauber; `analysis_options.yaml` setzt `strict-casts: true` und trägt einen inzwischen veralteten Kommentar, der `strict-raw-types` und `fatal-infos` als „deferred to Phase 1" bezeichnet.
  - *Abnahme:* CI läuft `dart analyze --fatal-infos lib test integration_test`; `strict-raw-types` (und, wenn tragbar, `strict-inference`) sind aktiv und der Backlog aufgeräumt; der veraltete Kommentar ist korrigiert.

- [ ] **BL-062 · P3 · S — Zwei parallele Test-Baum-Layouts und eine ungenutzte Helper-Datei**
  - *Warum:* Es existieren zwei konkurrierende Ablagestrukturen (`test/unit/features/…` neben `test/features/…`), was das Auffinden und Ergänzen von Tests unnötig erschwert. Zusätzlich liegt der Vorgänger des Test-Harness noch im Baum, ohne dass ihn jemand importiert.
  - *Evidenz:* `test/unit/features/shared/sensors/sensor_manager_test.dart` gegenüber `test/features/session/domain/activity_segment_test.dart`; `test/helpers/pump_app.dart` (41 Zeilen) hat **keinen** Importeur — `pumpApp` stammt aus `test/helpers/app_harness.dart:70`. ROADMAP.md Phase 1 vermerkt das bereits („blieb ungenutzt und sollte gelöscht werden").
  - *Abnahme:* Ein Layout ist dokumentiert und durchgezogen; `test/helpers/pump_app.dart` ist gelöscht und die Suite bleibt grün.

---

## 🏗️ Architektur & Code-Gesundheit

- [ ] **BL-063 · P1 · S — Import-Boundary-/Layering-Lints**
  - *Warum:* Die Schichtung (`presentation` → `providers` → `features/*/data` → `core`) existiert als Konvention, wird aber von nichts durchgesetzt. Jeder versehentliche Querimport erodiert sie unbemerkt — und macht den strukturellen Umbau (BL-071) später teurer.
  - *Evidenz:* ROADMAP.md Phase 0 vermerkt die Import-Boundary ausdrücklich als „weiterhin offen"; `analysis_options.yaml` enthält sechs kuratierte Regeln (`avoid_print`, `avoid_dynamic_calls`, `cast_nullable_to_non_nullable`, `unawaited_futures`, `prefer_final_locals`, `require_trailing_commas`) plus `strict-casts`, aber keine Layering-Regel.
  - *Abnahme:* Ein Boundary-Lint (z. B. `custom_lint`) schlägt bei einem Import aus `lib/features/**/data` nach `lib/presentation/**` fehl; CI führt ihn aus.

- [ ] **BL-064 · P1 · M — Historien-Aggregation in SQL verlagern, Liste paginieren, Index ergänzen**
  - *Warum:* Der Progress-Tab lädt **alle** Sessions des Nutzers und filtert und summiert in Dart. Bei einem Nutzer mit hunderten Sessions wird jeder Tab-Wechsel spürbar langsam, und es gibt keinen Index, der die heiße Abfrage stützt.
  - *Evidenz:* `lib/providers/progress_provider.dart:131 ff.` (Vollabruf + Filterung in Dart); die Aggregationen der Statistik-Tabs laufen ebenfalls in Dart.
  - *Abnahme:* Wochen-/Monatssummen kommen aus einer SQL-Aggregation, die Sessionliste ist paginiert, und ein Index auf `sessions(user_id, start_time)` existiert; ein Benchmark mit 500 Sessions belegt die Verbesserung.

- [ ] **BL-065 · P2 · M — Tracking-Hot-Path: selektive Rebuilds, O(n²)-Distanz, ein UPDATE pro GPS-Punkt**
  - *Warum:* Pro akzeptiertem GPS-Punkt wird die Distanz über die **gesamte** Punkteliste neu summiert, ein `UPDATE` auf die Session geschrieben und der komplette Widget-Baum neu gebaut. Bei einer langen Session wächst die Arbeit quadratisch — genau während der Akku ohnehin unter Druck steht (BL-015).
  - *Evidenz:* `lib/providers/activity_provider.dart:855-876` (Neuberechnung über die ganze Liste) mit `lib/features/session/utils/distance_calculator.dart:40-55`; `lib/features/session/data/session_dao.dart:123-131` (UPDATE je Punkt); die Tracking-UI hängt an `context.watch` statt an `Selector`/`context.select`. ROADMAP.md „⚪ Phase 3" führt zusätzlich `Polyline-Vereinfachung`, die auch das Rendern langer Routen entlastet.
  - *Abnahme:* Die Distanz wird inkrementell fortgeschrieben, DB-Updates laufen gebündelt (wie schon die Punkt-Inserts), die Tracking-UI baut nur die Werte-Widgets neu, und Polylines werden vor dem Rendern per Douglas-Peucker reduziert.

- [ ] **BL-066 · P2 · M — Uneinheitliche Datenzugriffs-Flughöhe in den Screens**
  - *Warum:* Manche Screens sprechen Repositories und DAOs direkt an, andere gehen über Provider. Dadurch gibt es keine verlässliche Stelle, an der Caching, Fehlerbehandlung oder Berechtigungsprüfungen greifen — und Widget-Tests brauchen für jeden Screen einen anderen Aufbau.
  - *Evidenz:* Direkter Repository-/DAO-Zugriff in `lib/presentation/screens/session/session_detail_screen.dart:47-49` und `lib/presentation/screens/profile/profile_screen.dart:38-40, 89`; Provider-Zugriff dagegen in `lib/presentation/screens/benefit/benefit_screen.dart:66-70` und `lib/presentation/screens/auth/login_screen.dart:154-158`.
  - *Abnahme:* Screens greifen ausschließlich über Provider zu; kein `lib/presentation/**` importiert mehr direkt aus `lib/features/**/data` (per BL-063 durchgesetzt).

- [ ] **BL-067 · P2 · S — Dead-Code-Inventar entscheiden und abräumen**
  - *Warum:* Toter Code ist keine Kosmetik: Leere Methodenrümpfe sehen aus wie Verhalten, das es nicht gibt (`SensorManager.pauseSession()` ist genau deshalb Teil von BL-010), doppelte Implementierungen driften auseinander, und Reviewer verlieren Zeit an Pfaden, die nie laufen.
  - *Evidenz:* `lib/features/shared/sensors/sensor_manager.dart:146` (leerer Rumpf mit Kommentar); doppelte Haversine-Implementierung in `lib/features/session/domain/gps_point.dart:153-177` gegenüber `lib/features/session/utils/distance_calculator.dart:87-114`; No-op-Reste in `lib/presentation/screens/benefit/benefit_screen.dart:33`, `lib/providers/app_lock_provider.dart:32-33`, `lib/providers/auth_provider.dart:691-697`; `lib/presentation/screens/progress/progress_screen.dart:367` trägt sogar ein `// ignore: unused_element — dead code`. Aus der Testabdeckung: 12 von 141 `lib/`-Dateien werden von keinem Testeinstiegspunkt aus überhaupt geladen — darunter alle vier `lib/features/session/data/continuous_tracking_*.dart` und `activity_segment_dao.dart` aus BL-017.
  - *Abnahme:* Für jeden Eintrag der Inventarliste ist entschieden — löschen oder verdrahten; die Haversine-Berechnung existiert genau einmal; kein leerer Methodenrumpf ohne explizite Begründung bleibt zurück.

- [ ] **BL-068 · P3 · S — `ConnectivityProvider` aufräumen und den Kaltstart entlasten**
  - *Warum:* Der Provider startet asynchrone Arbeit im Konstruktor, beginnt dabei als „offline" (bis der erste Check zurückkommt, sieht die App fälschlich offline aus) und kann nach `dispose` noch `notifyListeners` auslösen. Gleichzeitig baut `main()` vier `ConnectivityService`-Instanzen und 16 Repositories auf dem Kaltstartpfad auf.
  - *Evidenz:* `lib/providers/connectivity_provider.dart:24` (`bool _isOnline = false`) und `:28-30` (`_initialize()` im Konstruktor, ohne `mounted`/`dispose`-Schutz in `:38-49`); `lib/main.dart:108-110, 128, 134, 156, 165, 174, 187` (mehrfache Service- und Repository-Konstruktion).
  - *Abnahme:* Die Initialisierung ist ein explizit aufgerufenes `Future`, der Startzustand ist „unbekannt" statt „offline", `notifyListeners` nach `dispose` ist ausgeschlossen, und es existiert genau eine `ConnectivityService`-Instanz.

- [ ] **BL-069 · P3 · M — SQLite-Row-Mapping von der API-DTO-Serialisierung entkoppeln**
  - *Warum:* Dieselben `toJson`/`fromJson`-Methoden bedienen heute Datenbankzeilen und (künftig) API-Nutzlasten. Sobald das Backend steht, koppelt jede Schema- an eine API-Änderung — und umgekehrt.
  - *Evidenz:* `lib/features/session/data/session_dao.dart:167-187` (`_toMap`) neben den Domain-`toJson`-Methoden, z. B. `lib/features/session/domain/session.dart:80-135`.
  - *Abnahme:* Persistenz-Mapping und Transport-DTO sind getrennte Typen; eine Schemaänderung erfordert keine Änderung am DTO und umgekehrt (durch Tests belegt).

- [ ] **BL-070 · P3 · L — Typisiertes Fehlermodell für die `*_result.dart`-Typen**
  - *Warum:* Fehler wandern heute als freie Strings durch die Schichten. Das verhindert differenzierte Behandlung (Retry, Re-Auth, Anzeige) und ist der Grund, warum rohe Exception-Texte in der UI landen (siehe BL-084).
  - *Evidenz:* `lib/features/auth/domain/*_result.dart` und Geschwister tragen `String? error`; `lib/providers/activity_provider.dart:414` setzt `_error = 'Failed to pause session: ${e.toString()}'`.
  - *Abnahme:* Ergebnisse nutzen versiegelte Fehlertypen; die UI entscheidet anhand des Typs, nicht anhand des Textes.

- [ ] **BL-071 · P3 · XL — Struktureller Umbau: Feature-Konsolidierung, drift-Evaluierung, Schema-Kopplung (bewusst zurückgestellt)**
  - *Warum:* Drei größere Umbauten, die die ROADMAP als opportunistisch bzw. „bewusst nicht jetzt" markiert. Sie gehören ins Backlog, damit die Entscheidung sichtbar bleibt und nicht als Versehen gelesen wird.
  - *Evidenz:* ROADMAP.md „⚪ Phase 3" (`Feature-Konsolidierung (presentation/providers → features/<x>/) — opportunistisch, P2/P3`) und „🚫 Bewusst NICHT" (`kein drift/floor (jetzt)`, `kein melos-Monorepo`); `lib/features/shared/database/database_helper.dart` ist mit 861 Zeilen und 16 `CREATE TABLE` der zentrale Kopplungspunkt aller Features.
  - *Abnahme:* Die Zurückstellung ist im Decision-Record aus BL-001 begründet und mit einem Auslöser versehen (z. B. „sobald das Backend steht" oder „ab n Entwickler:innen"); ohne diesen Auslöser wird nicht begonnen.

---

## 🎨 UX & Features

- [ ] **BL-072 · P0 · S — Die Routen-Karte rendert für keine einzige gespeicherte Session**
  - *Warum:* Der Session-Detail-Screen filtert die aus der Datenbank geladenen Punkte mit demselben Qualitätskriterium, das für **Live**-Fixes gedacht ist — und das enthält eine Altersgrenze von 10 Sekunden gegenüber `DateTime.now()`. Jeder gespeicherte Punkt ist per Definition älter. Die Liste ist danach immer leer, die Karte immer ohne Route. Das ist die einzige echte Karte der App und damit der sichtbarste Demo-Defekt überhaupt.
  - *Evidenz:* `lib/presentation/screens/session/session_detail_screen.dart:67` — `_gpsPoints = points.where((p) => p.meetsQualityRequirements()).toList();`; `lib/features/session/domain/gps_point.dart:186-191` delegiert an `lib/core/config/gps_tracking_config.dart:132-147`, dessen Prüfung `if (ageSeconds > maxGpsAgeSeconds) return false;` mit `maxGpsAgeSeconds = 10` (`gps_tracking_config.dart:46`) enthält.
  - *Abnahme:* Beim Laden gespeicherter Punkte wird nur noch nach Genauigkeit gefiltert, nicht nach Alter; ein Widget-Test mit gespeicherten Punkten von gestern rendert eine Polyline mit allen Punkten.

- [ ] **BL-073 · P0 · M — Kernschleife: aus echter Aktivität entsteht nie ein Benefit**
  - *Warum:* `awardBenefit` hat genau **einen** Aufrufer — den Debug-Seeder. `stopSession` enthält keinerlei Belohnungslogik. Die namensgebende Funktion der App läuft in keinem Release-Build. Dazu passt, dass die Benefit-Ansicht durchgehend mit Platzhaltern arbeitet: Die Partnerliste ist für jeden Benefit dieselbe hartkodierte Zweierliste, und die Karte „Total Savings this week" summiert in Wahrheit **alle** jemals erhaltenen Benefits ohne Zeitfilter.
  - *Evidenz:* `grep awardBenefit` über `lib/`, `test/`, `integration_test/` liefert vier Codetreffer: Interface (`lib/features/benefit/data/benefit_repository.dart:23`), Implementierung (`benefit_repository_impl.dart:53`), Test-Fake (`test/helpers/benefit_fakes.dart:40`) und den einzigen Aufrufer `lib/core/seed/seed_service.dart:256` (debug-gated über `SeedConfig.isEnabled`). `lib/providers/activity_provider.dart:481-573` (`stopSession`) vergibt nichts. Partner: `benefit_repository_impl.dart:129-148` („Phase 1: Hardcoded mock partners", FitCafe/SportShop Pro). Label: `lib/presentation/screens/benefit/widgets/total_savings_card.dart:21` gegenüber `lib/features/benefit/data/benefit_dao.dart:114-133` (`SUM(b.discount_amount) … WHERE ub.user_id = ?` — kein Datumsfilter).
  - *Abnahme:* Eine abgeschlossene Session, die die Schwelle erreicht, erzeugt einen `UserBenefit`, der ohne Seeder im Benefit-Tab erscheint (Integrationstest); Partner kommen aus einer Datenquelle; das Ersparnis-Label und die Abfrage decken denselben Zeitraum ab.

- [ ] **BL-074 · P1 · M — Der Activity-Screen zeigt eine statische, unscharfe PNG statt der Live-Route**
  - *Warum:* Der Standard-Landing-Tab der App rendert während des Trackings **keine** Karte. Er zeichnet eine 868 KB große PNG vollflächig als Hintergrund, legt einen Blur und ein Schwarz-Overlay darüber und benutzt dieselbe Datei nochmals als „MAP PREVIEW"-Thumbnail. Die aufgezeichnete Route ist während der Session nirgends sichtbar — bei einer Vorführung fällt genau das zuerst auf.
  - *Evidenz:* `lib/presentation/screens/activity/activity_screen.dart:245` (`assets/images/backgrounds/activity/activity_map.png` als Hintergrund), `:253` (`ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0)`), `:427` (dieselbe Datei als Thumbnail); die einzige echte Karte (`flutter_map` + OSM) liegt in `lib/presentation/screens/session/session_detail_screen.dart:174-182` — also erst *nach* der Session, und dort greift BL-072.
  - *Abnahme:* Während einer laufenden Session zeigt der Activity-Screen die live wachsende Polyline auf einer echten Karte; die statische PNG ist entfernt oder auf einen Leerzustand beschränkt.

- [ ] **BL-075 · P1 · M — Kein Post-Session-Summary: `SessionSummaryScreen` ist unerreichbar**
  - *Warum:* 603 Zeilen fertige Zusammenfassung liegen im Code und sind von nirgendwo aus erreichbar. Nach dem Stopp sieht der Nutzer nur eine SnackBar „Session saved!" — der Moment, in dem der Erfolg gefeiert und die Belohnung gezeigt werden müsste, findet nicht statt.
  - *Evidenz:* `grep SessionSummaryScreen` über `lib/`, `test/`, `integration_test/` trifft nur die eigene Datei (`lib/presentation/screens/activity/session_summary_screen.dart:14, 17, 20, 23`) und einen Doku-Verweis; `lib/presentation/screens/activity/activity_screen.dart:126-134` zeigt stattdessen die SnackBar; `lib/core/router/app_router.dart` kennt keine Route dorthin.
  - *Abnahme:* `stopSession` navigiert zur Zusammenfassung mit Distanz, aktiver Dauer, Pace, HR-Abdeckung und ggf. vergebenem Benefit; ein Widget-Test deckt den Weg Stop → Summary → zurück ab.

- [ ] **BL-076 · P1 · M — Nur „running" ist trackbar, obwohl zwölf Aktivitätstypen modelliert sind**
  - *Warum:* Die Domäne, die Datenbank und die Scoring-Konfiguration kennen zwölf Typen; die UI erzwingt beim Betreten des Screens „running" und bietet keine Auswahl an. Radfahren, Wandern und Schwimmen sind damit fachlich vorhanden, aber für den Nutzer nicht existent — und die typabhängigen Score-Multiplikatoren aus BL-016 haben nichts zu unterscheiden.
  - *Evidenz:* `lib/presentation/screens/activity/activity_screen.dart:47-49` — `if (provider.selectedActivityType != ActivityType.running) provider.selectActivityType(ActivityType.running);` in `initState`; der Button-Text ist fest `"START Running"` (`:60`).
  - *Abnahme:* Vor dem Start lässt sich der Aktivitätstyp wählen, die Auswahl wird an der Session persistiert und in Historie und Detailansicht angezeigt.

- [ ] **BL-077 · P1 · S — Sackgassen, hängende Fehlerzustände und fehlende Eingabevalidierung**
  - *Warum:* Fünf kleine Defekte, die zusammen den Eindruck einer instabilen App erzeugen — und die alle in einem Demo-Durchlauf auftreten können.
  - *Evidenz:* (1) `lib/presentation/screens/activity/activity_screen.dart:219` — `ErrorDisplayWidget(message: provider.error!, onRetry: null)`; weil `onRetry` ausdrücklich `null` ist, rendert das Widget seinen „Try Again"-Button nicht (`lib/presentation/shared/widgets/error_display_widget.dart:30-38`), und der Vollbild-Fehlerzustand hat keinen Ausgang. (2) `lib/presentation/screens/progress/progress_screen.dart:363` — das Antippen einer **manuellen** Aktivität navigiert auf einen Session-Detail-Screen, zu dem es keine Session gibt (`session_detail_screen.dart:99-101` scheitert immer). (3) `progress_screen.dart:444` zeigt `'Error: … \nTap to retry'`, ist aber ein reiner `Text` ohne Tap-Handler. (4) `progress_screen.dart:249 ff.` akzeptiert beim manuellen Eintrag implausible Werte und Datumsangaben in der Zukunft. (5) `lib/presentation/screens/splash/splash_screen.dart:18` hält eine unveränderliche Statuszeile (`final String _status = 'Loading...'`) und hat weder Timeout noch Fehlerpfad — scheitert `AuthProvider.initialize()`, bleibt der Splash für immer stehen.
  - *Abnahme:* Jeder Fehlerzustand hat eine funktionierende Aktion (Retry oder Zurück); manuelle Einträge öffnen eine passende Detailansicht oder sind nicht antippbar; Distanz, Dauer und Datum werden validiert (kein Zukunftsdatum, plausible Obergrenzen), abgedeckt durch Widget-Tests.

- [ ] **BL-078 · P1 · L — Der Community-Tab ist ein statischer Mock mit hartkodierten deutschen Texten**
  - *Warum:* Einer von fünf Haupt-Tabs zeigt 415 Zeilen erfundene Inhalte — Challenges, Events, Ranglisten —, die mit keinerlei Daten hinterlegt sind. Für eine Vorführung ist das riskant (es sieht aus wie ein Feature), und es ist der einzige Ort, an dem die sonst englische App deutsch spricht.
  - *Evidenz:* `lib/presentation/screens/community/community_screen.dart:35` („Vergangene"), `:58` („Virtuelles Rennen"), `:59` („Startet in 38 Tagen"), `:66` („Beendet in 3 Tagen"); der Screen trägt bereits einen „Coming Soon"-Platzhalter (`:142`).
  - *Abnahme:* Entweder ist der Tab durch einen ehrlichen, schlanken „Coming Soon"-Zustand ersetzt (und die 2,4-MB-Grafik aus BL-090 entfernt), oder er zeigt echte Daten. Kein erfundener Inhalt bleibt als scheinbar funktionierendes Feature stehen.

- [ ] **BL-079 · P1 · S — Sprachkonsistenz herstellen und das i18n-Gerüst einziehen**
  - *Warum:* Die App ist durchgehend englisch, hat aber keinerlei Lokalisierungsinfrastruktur — und genau drei deutsche Leckstellen, von denen die prominenteste der **Release-Crash-Screen** ist: Der einzige Moment, in dem ein Nutzer Deutsch sieht, ist der Absturz. Für eine österreichische Einreichung ist die Sprachfrage zudem inhaltlich relevant.
  - *Evidenz:* `lib/main.dart:56` — `'Etwas ist schiefgelaufen. Bitte starte die App neu.'` im `kReleaseMode`-Zweig des `ErrorWidget`; deutsche Wochentagskürzel unter englischen Diagrammtiteln in `lib/presentation/screens/progress/widgets/statistics_tab.dart:96-102` und `custom_charts.dart:94`; der komplette Community-Tab (BL-078). Es gibt keine `flutter_localizations`-Abhängigkeit, keine `.arb`-Dateien und keine `localizationsDelegates`/`supportedLocales` an `MaterialApp.router`; die Spalte `user_preferences.language` (Default `'en'`) wird geschrieben, aber nie gelesen.
  - *Abnahme:* `flutter_localizations` + `l10n.yaml` + leere `.arb`-Dateien (en/de) sind eingerichtet, `MaterialApp.router` hat Delegates und `supportedLocales`, `intl`-Datumsformate nutzen die aktive Locale, und in `lib/` steht kein deutscher Literal-String mehr außerhalb der `.arb`-Dateien.

- [ ] **BL-080 · P2 · M — Theming-Single-Source: zwei Markengrüns, kein Dark Mode, schwarzes Launch-Theme**
  - *Warum:* Die Marke ist im Code nicht eindeutig definiert. Ein Grünton steht im Theme, ein zweiter ist über sieben Screens hartkodiert. Dark Mode existiert überhaupt nicht — aber das Android-Launch-Theme für Dark Mode schon, und es ist schwarz: Auf einem Gerät im Dunkelmodus blitzt bei jedem Kaltstart Schwarz auf, bevor der grüne Splash übernimmt. Weiße Schrift auf dem Markengrün erreicht zudem den WCAG-AA-Kontrast nicht.
  - *Evidenz:* `lib/core/config/theme.dart:6` (`#78BA3F`) gegenüber hartkodierten Werten in `activity_screen.dart:35-36`, `profile_screen.dart:30`, `community_screen.dart:6`, `device_connection_screen.dart:29`, `device_pairing_screen.dart:21`, `session_summary_screen.dart:24`, `heart_rate_display.dart:233`; `grep 'darkTheme|ThemeMode|Brightness.dark'` über `lib/` → **kein Treffer**; `android/app/src/main/res/values-night/styles.xml` setzt `LaunchTheme` und `NormalTheme` auf `@android:style/Theme.Black.NoTitleBar`, während `lib/presentation/screens/splash/splash_screen.dart:33` in Markengrün startet.
  - *Abnahme:* Alle Farben kommen aus einer Token-Datei (kein `Color(0x…)` in Screens), ein Dark-Theme existiert und ist umschaltbar, das Launch-Theme passt in beiden Modi zum ersten Flutter-Frame, und die Text/Hintergrund-Kombinationen erfüllen WCAG AA.

- [ ] **BL-081 · P2 · M — Accessibility-Baseline (inklusive der Long-Press-Falle)**
  - *Warum:* Über 141 Dart-Dateien hinweg gibt es **null** Semantics-Annotationen. Besonders kritisch: Eine Session lässt sich **nur** per langem Druck auf einen Mehrzweck-Button beenden — für Screenreader-Nutzer und für jeden, der die Geste nicht kennt, ist das Beenden schlicht nicht auffindbar (die App antwortet stattdessen mit „Long press only works while paused").
  - *Evidenz:* `lib/presentation/screens/activity/activity_screen.dart:120-134` (`_handleLongPress` als einziger Stop-Pfad); über ganz `lib/` hinweg **0** Treffer für `Semantics(`, `semanticLabel`, `MergeSemantics` und `ExcludeSemantics`, bei 3 `tooltip:`-Angaben, 4 `GestureDetector` und 3 `InkWell`; die geteilten Zustands-Widgets (`lib/presentation/shared/widgets/loading_widget.dart`, `error_display_widget.dart`, `empty_state_widget.dart`) werden über alle 27 Screens hinweg nur an vier Stellen benutzt.
  - *Abnahme:* Ein sichtbarer Stop-Button existiert; interaktive Elemente tragen Labels; die App bleibt bei 200 % Textskalierung bedienbar; ein Accessibility-Scanner-Durchlauf auf den fünf Haupt-Tabs ist dokumentiert.

- [ ] **BL-082 · P2 · M — Gespeicherte Nutzerpräferenzen werden nie angewendet**
  - *Warum:* Einheiten, Theme und Sprache werden erfasst, in `user_preferences` gespeichert — und danach von niemandem gelesen. Der Nutzer stellt etwas ein, und nichts passiert.
  - *Evidenz:* Tabelle in `lib/features/shared/database/database_helper.dart:655`; geschrieben über `UserPreferencesDao`/`ProfileProvider`; keine Lesestelle in `lib/presentation/**` wertet Einheiten oder Theme aus (siehe auch BL-080: es gibt gar kein Dark-Theme, das man auswählen könnte).
  - *Abnahme:* Einheitenumschaltung (km/mi) wirkt auf alle Anzeigen, die Theme-Auswahl schaltet das Theme, die Sprachauswahl schaltet die Locale (nach BL-079); je ein Widget-Test pro Präferenz.

- [ ] **BL-083 · P2 · M — `SessionTimeoutService` implementieren (Auto-Logout, tracking-bewusst)**
  - *Warum:* Es gibt keine Inaktivitätsabmeldung. Auf einem verlorenen oder geteilten Gerät bleibt eine Sitzung unbegrenzt offen — und weil Tokens nie ablaufen (BL-031), gibt es auch keine serverseitige Bremse. Der Dienst muss dabei wissen, dass eine laufende Tracking-Session kein „inaktiv" ist.
  - *Evidenz:* `lib/features/security/services/session_timeout_service.dart:92` — die Klasse existiert, aber jede Methode ist ein Stub: `recordActivity()` (`:101`), `startMonitoring()` (`:107`), `stopMonitoring()` (`:113`) und `extendSession()` (`:119`) geben nur `… - NOT IMPLEMENTED` aus. `AUTH.md:382, 405` beschreiben den Dienst als „stubbed/deferred". `lib/providers/app_lock_provider.dart` deckt nur den Vordergrund-/Hintergrundwechsel ab, nicht Inaktivität.
  - *Abnahme:* Nach konfigurierbarer Inaktivität wird abgemeldet bzw. gesperrt; eine laufende Tracking-Session verhindert das; Unit-Tests decken beide Fälle ab.

- [ ] **BL-084 · P2 · S — Nutzer-Meldungen von Exception-Texten trennen; geteilte Zustands-Widgets konsequent nutzen**
  - *Warum:* Roher Exception-Text landet in der Oberfläche — das ist unverständlich für Nutzer und kann interne Details preisgeben. Gleichzeitig existieren drei geteilte Zustands-Widgets, die fast niemand benutzt: Der Benefit-Tab ist der einzige Screen, der das gemeinsame Vokabular für Laden/Fehler/Leer verwendet.
  - *Evidenz:* `lib/providers/activity_provider.dart:414` (`'Failed to pause session: ${e.toString()}'` — eine von neun Stellen, an denen Provider rohen Exception-Text in `_error` schreiben), das in `activity_screen.dart:219` unverändert als `message` in den Vollbild-Fehlerzustand geht, sowie `lib/presentation/screens/progress/progress_screen.dart:444` (`'Error: ${provider.error}'`); Nutzung der geteilten Widgets über alle 27 Screen-Dateien: `LoadingWidget` nur in `benefit_screen.dart`, `ErrorDisplayWidget` in `benefit_screen.dart` und `activity_screen.dart`, `EmptyStateWidget` nur in `benefit/widgets/empty_benefits_widget.dart` — praktisch ausschließlich im Benefit-Bereich.
  - *Abnahme:* Provider liefern typisierte Fehler (BL-070) und die UI übersetzt sie in verständliche Texte; jeder datengetriebene Screen nutzt die geteilten Zustands-Widgets.

- [ ] **BL-085 · P2 · M — Notification-Actions und ein Settings-Bereich für kontinuierliches Tracking**
  - *Warum:* Die Foreground-Notification ist heute nur Anzeige. Pause/Stop/App öffnen direkt aus der Benachrichtigung ist bei Hintergrund-Tracking die erwartete Interaktion. Und bevor kontinuierliches Tracking (BL-017) überhaupt aktiviert werden darf, braucht es einen sichtbaren Schalter, der standardmäßig **aus** ist.
  - *Evidenz:* `lib/features/shared/sensors/gps_sensor.dart:236-283` konfiguriert `ForegroundNotificationConfig` ohne Actions; `documentation/sessions/BACKGROUND_TRACKING_PLAN.md` führt beide Punkte als offene Pakete; in `lib/presentation/screens/profile/` existiert kein Tracking-Einstellungsbereich.
  - *Abnahme:* Die Benachrichtigung bietet Pause/Stop und öffnet die App; ein Einstellungsbereich schaltet kontinuierliches Tracking (Default aus) mit erklärendem Text und Akku-Hinweis.

- [ ] **BL-086 · P2 · XL — UI-Strings nach `.arb` extrahieren (en + de)**
  - *Warum:* Die Folgestufe zu BL-079. Erst mit extrahierten Strings ist eine deutschsprachige Fassung möglich — für eine österreichische Zielgruppe der eigentliche Nutzen der Lokalisierung.
  - *Evidenz:* ROADMAP.md „⚪ Phase 3" (`i18n-Gerüst … — Extraktion deferred`); über 27 Screen-Dateien hinweg stehen die Texte als Literale im Code.
  - *Abnahme:* Alle nutzersichtbaren Strings liegen in `app_en.arb` und `app_de.arb`; ein Lint oder Test schlägt bei neuen Literalen in `lib/presentation/**` an.

---

## 🚀 Betrieb & Release

- [ ] **BL-087 · P0 · S — Die App installiert sich als „benefitflutter"; auch die übrigen Identitätsstrings sind Scaffolding-Reste**
  - *Warum:* Unter dem Launcher-Icon steht der Projekt-Slug statt „BeneFit" — das Erste, was ein Bewerter oder Tester sieht, noch vor jedem Screen. Dazu kommen widersprüchliche Identitäten über die Plattformen hinweg und ein Platzhalter-User-Agent, mit dem die App die OpenStreetMap-Tile-Server anspricht (deren Nutzungsrichtlinie eine identifizierende Kennung verlangt) — Attribution fehlt zudem ganz.
  - *Evidenz:* `android/app/src/main/AndroidManifest.xml:56` — `android:label="benefitflutter"` (im gemergten Manifest identisch); `ios/Runner/Info.plist:8` `CFBundleDisplayName = Benefitflutter`, `:16` `CFBundleName = benefitflutter`, während `CFBundleURLName` noch `com.example.benefitflutter` lautet und Androids `applicationId` `us.benefit4.benefitflutter` ist; `lib/presentation/screens/session/session_detail_screen.dart:183` — `userAgentPackageName: 'com.example.benefitflutter'`, und der Kartenblock (`:170-195`) enthält keinen OSM-Attributionshinweis.
  - *Abnahme:* Beide Plattformen zeigen „BeneFit" unter dem Icon (auf dem Gerät verifiziert); Bundle-IDs und URL-Schemes stimmen plattformübergreifend überein; der Tile-User-Agent nennt die echte Anwendungs-ID, und „© OpenStreetMap contributors" ist auf der Karte sichtbar.

- [ ] **BL-088 · P0 · S — `android.permission.INTERNET` fehlt im Release-Manifest**
  - *Warum:* Das Hauptmanifest deklariert die Berechtigung nicht; Debug und Profile ergänzen sie jeweils selbst. Im Release-Build kommt sie ausschließlich **transitiv** aus dem Sentry-AAR — die Netzwerkfähigkeit der App hängt damit an einem Crash-Reporting-Abhängigkeitsdetail. Wird Sentry entfernt oder ausgetauscht, verliert der Release-Build ohne Vorwarnung jede Netzwerkverbindung (und damit die OSM-Kartenkacheln, das einzige heute sichtbare Netzwerkfeature).
  - *Evidenz:* `grep -c INTERNET android/app/src/main/AndroidManifest.xml` = **0** bei 26 deklarierten Berechtigungen; `android/app/src/debug/AndroidManifest.xml:6` und `android/app/src/profile/AndroidManifest.xml:6` deklarieren sie je selbst; kein pub-Plugin der App bringt sie mit — nur `sentry-android-core-7.22.4.aar`.
  - *Abnahme:* `android/app/src/main/AndroidManifest.xml` deklariert `android.permission.INTERNET` explizit; das gemergte Release-Manifest enthält sie nachweislich.

- [ ] **BL-089 · P0 · M — Store-Policy: Play-Deklaration für Hintergrund-Standort, Data Safety, In-App-Disclosure**
  - *Warum:* Seit WP1/WP2 läuft ein Foreground-Service mit Standortzugriff. Google Play verlangt dafür eine Deklaration samt Demovideo, einen korrekten Data-Safety-Eintrag und eine In-App-Offenlegung **vor** dem Systemdialog; Apple verlangt eine Begründung nach Richtlinie 2.5.4. Fehlt das, wird die Einreichung abgelehnt.
  - *Evidenz:* ROADMAP.md „⚖️ Übergreifende Lücken" markiert den Punkt als „jetzt akut"; `android/app/src/main/AndroidManifest.xml:22` fordert bewusst **kein** `ACCESS_BACKGROUND_LOCATION`, was die Deklaration vereinfacht, die In-App-Offenlegung aber nicht ersetzt.
  - *Abnahme:* Die Play-Deklaration ist eingereicht und akzeptiert, der Data-Safety-Eintrag deckt Standort und Gesundheitsdaten ab, und die In-App-Offenlegung erscheint vor der ersten Standortabfrage.

- [ ] **BL-090 · P1 · M — CI baut nie ein Release-Artefakt; kein R8/Minify; das vorhandene APK ist 59,9 MB und veraltet**
  - *Warum:* Die Pipeline endet beim Debug-APK. Release-spezifische Fehler (fehlende Berechtigungen wie BL-088, ProGuard-Probleme, Signaturfehler) fallen damit erst beim manuellen Build auf. Ohne Shrinking und ABI-Split ist das Artefakt zudem unnötig groß, und das einzige auf der Platte liegende Release-APK stammt von **vor** den WP3/WP5-Commits — es enthält die ausgelieferte Phase-2-Arbeit gar nicht. Ein großer Teil des Gewichts ist Payload, der nicht gebraucht wird: `assets/` ist 4,8 MB groß, allein die Community-Grafik davon 2,4 MB, und 7 der 21 eingecheckten Bilddateien werden von keiner Dart-Datei referenziert (zwei davon legitim, weil `flutter_launcher_icons` sie nutzt).
  - *Evidenz:* `.github/workflows/ci.yml` endet mit „Build debug APK"; `grep 'minify|shrinkResources|proguard' android/app/build.gradle.kts` → kein Treffer; `build/app/outputs/apk/release/app-release.apk` = **62 765 806 Bytes (59,9 MB)**, Datum 2026-06-11, also älter als die WP3/WP4/WP5-Commits `1ef548f`, `457c253` und `fd7dfc1`; es ist ein Fat-APK mit allen drei ABIs. `assets/images/backgrounds/community/community.png` = **2 470 614 Bytes** für den „Coming Soon"-Platzhalter aus BL-078; von einer Dart-Datei unreferenziert sind `community2.png` (231 633 B), `logo_white.png` und die drei `placholder_benefit_*.png` (zusammen ~253 KB) sowie die beiden Launcher-Logos, die nur der `flutter_launcher_icons`-Block in `pubspec.yaml:180-185` braucht.
  - *Abnahme:* CI erzeugt bei jedem Merge nach `main` ein signiertes App Bundle (bzw. `--split-per-abi`), R8/`shrinkResources` sind aktiv, ungenutzte Assets sind entfernt, und die Artefaktgröße ist dokumentiert und deutlich kleiner.

- [ ] **BL-091 · P1 · L — Build-Flavors (dev/staging/prod) und CD für signierte Builds**
  - *Warum:* Es gibt genau eine Konfiguration. Ohne Flavors gibt es keine sichere Trennung zwischen Test- und Produktionsdaten und kein reproduzierbares Release. Passend dazu baut CI heute **ohne jede Konfigurationsdatei** — die typisierte `AppConfig` wird in der Pipeline nie mit echten Werten getestet.
  - *Evidenz:* ROADMAP.md „⚪ Phase 3" (`Build-Flavors (dev/staging/prod) + CD (fastlane/Actions)`); `.github/workflows/ci.yml` enthält keinen Schritt mit `--dart-define-from-file`; `config/prod.example.json` existiert, `config/prod.json` ist gitignoriert.
  - *Abnahme:* Drei Flavors mit eigenen `applicationId`-Suffixen, Namen und Konfigurationsdateien lassen sich parallel installieren; ein CD-Job erzeugt aus einem Tag ein signiertes, hochladbares Artefakt; mindestens ein CI-Build läuft mit `--dart-define-from-file`.

- [ ] **BL-092 · P1 · M — Rollout-Steuerung: Staged Rollout, Force-Update-Gate, API-Versionierung, Remote-Kill-Switch**
  - *Warum:* Sobald die App im Store ist, ist ein fehlerhaftes Release ohne diese Mechanik nicht mehr einzufangen: Es gibt keine Möglichkeit, ein Feature aus der Ferne abzuschalten oder alte Clients zum Update zu zwingen. Für die erste vernetzte Funktion (BL-002) ist der Kill-Switch die Voraussetzung, nicht die Kür.
  - *Evidenz:* ROADMAP.md „⚖️ Übergreifende Lücken" (`Rollout-Mechanik (Staged Rollout, Force-Update / Min-Version-Gate, API-Versionierung)`) und „🟡 Phase 2" (`Sync-Observability + Remote-Kill-Switch vor Go-Live`); in `lib/core/config/app_config.dart` existieren nur Compile-Zeit-Flags, kein Laufzeit-Flag-Mechanismus.
  - *Abnahme:* Ein Remote-Flag kann Sync und Tracking abschalten, ohne dass ein Release nötig ist; ein Min-Version-Gate blockiert veraltete Clients mit klarer Meldung; die API ist versioniert und die Rollout-Prozedur dokumentiert.

- [ ] **BL-093 · P1 · S — Sentry scharf schalten und die doppelte Meldung abstellen**
  - *Warum:* Das Crash-Reporting ist verdrahtet, aber DSN-gated und damit inaktiv — bis zum Go-Live gibt es keine Fehlersicht auf echte Geräte. Gleichzeitig meldet die aktuelle Verdrahtung jeden Framework- und Plattformfehler **zweimal**, weil die eigenen Handler zusätzlich zu Sentrys eigenen Integrationen feuern: Das verfälscht jede Häufigkeitsauswertung und verbraucht Kontingent.
  - *Evidenz:* ROADMAP.md „⚪ Phase 3" (`(S, vor Go-Live) Sentry scharf schalten`); `lib/main.dart:38-48` registriert `FlutterError.onError` und `PlatformDispatcher.onError` zusätzlich zu `sentry_flutter`s `FlutterErrorIntegration` und `OnErrorIntegration`.
  - *Abnahme:* Ein EU-Sentry-Projekt existiert, der DSN wird per `--dart-define` im Release gesetzt, ein Testereignis kommt an — und ein ausgelöster Framework-Fehler erzeugt genau **ein** Ereignis. Voraussetzung bleibt die DPA plus der Consent-Eintrag aus BL-034/BL-036.

- [ ] **BL-094 · P2 · M — Die iOS-Plattformkonfiguration ist ungepinnt und ungebaut**
  - *Warum:* Android pinnt `minSdk 26` bewusst, iOS pinnt gar nichts: Das Deployment-Target im Podfile ist auskommentiert, es gibt kein `Podfile.lock` und keinen macOS-Job in der CI — die iOS-Seite wird also nie gebaut. Zusätzlich erlaubt `Info.plist` Querformat, während die App nirgends eine Orientierung festlegt und für Hochformat gestaltet ist.
  - *Evidenz:* `ios/Podfile:2` — `# platform :ios, '13.0'` ist auskommentiert; im `ios/`-Verzeichnis existiert kein `Podfile.lock`; `.github/workflows/*.yml` enthalten keinen macOS-Runner; `ios/Runner/Info.plist` deklariert `UISupportedInterfaceOrientations` inklusive `LandscapeLeft`/`LandscapeRight`, und `SystemChrome.setPreferredOrientations` kommt in `lib/` nicht vor.
  - *Abnahme:* Das Deployment-Target ist gepinnt und passt zu `pubspec.yaml`, `Podfile.lock` ist eingecheckt, ein CI-Job baut iOS (mindestens `flutter build ios --no-codesign`), und die Orientierungen stimmen mit dem Design überein.

- [ ] **BL-095 · P2 · S — Release-Hygiene: Nebenplattformen, Dependency-Bot, Workflow-Aufräumen, Launcher-Icon, Keystore-Ignore**
  - *Warum:* Fünf kleine Betriebsschulden, die zusammen den Eindruck eines unfertigen Repos erzeugen und im Ernstfall teuer werden.
  - *Evidenz:* (1) `web/manifest.json` ist unverändertes Flutter-Scaffolding (`name`/`short_name` = `benefitflutter`, `background_color`/`theme_color` = `#0175C2`), ebenso `web/index.html`; `macos/`, `linux/` und `windows/` sind unangetastete Templates — vier Plattformziele, die die App nicht bedienen kann. (2) `.github/` enthält genau zwei Workflow-Dateien, `ci.yml:3-5` triggert auf `push` **und** `pull_request` (doppelte Läufe) ohne `concurrency`-Gruppe, und es gibt keinen Renovate-/Dependabot-Konfigurationseintrag, obwohl `pubspec.yaml` drei Abhängigkeiten als „exact pin (security-critical)" führt. (3) `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` definiert nur `background` und `foreground` — kein `monochrome` für Android 13+ (und die Foreground-Service-Notification hat ebenfalls kein monochromes Icon). (4) Die Root-`.gitignore` enthält **keine** Keystore-Regel; der Schutz liegt allein in `android/.gitignore:12-14` — ein Keystore außerhalb von `android/` würde committet.
  - *Abnahme:* Nicht unterstützte Plattformordner sind entfernt oder als „nicht unterstützt" dokumentiert; ein Dependency-Bot läuft mit Gruppierung; `ci.yml` hat eine `concurrency`-Gruppe und läuft je Änderung einmal; monochrome Icons existieren; die Root-`.gitignore` deckt `key.properties`, `*.jks` und `*.keystore` ab.

- [ ] **BL-096 · P3 · M — Produkt-Analytics für die Reward-Schleife**
  - *Warum:* Nach BL-073 muss messbar sein, ob die Kernschleife trägt: Wie viele Sessions werden begonnen, wie viele beendet, wie viele Benefits vergeben und eingelöst. Ohne diese Zahlen ist jede Produktentscheidung geraten.
  - *Evidenz:* In `lib/` existiert keine Analytics-Abhängigkeit; die einzige Telemetrie ist das DSN-gated Sentry aus BL-093.
  - *Abnahme:* Ein datenschutzkonformes (consent-gebundenes, siehe BL-034) Event-Schema für Session-Start/Stop, Benefit-Vergabe und -Einlösung ist definiert und liefert Zahlen in ein Dashboard.

---

## 📚 Dokumentation

> Die große Doku-Korrekturrunde vom 2026-08-28 hat die meisten Überzeichnungen bereits beseitigt —
> `database/DATABASE.md`, `lib/features/security/SECURITY.md`, `lib/features/wearable_integration/WEARABLE_INTEGRATION.md`,
> `documentation/FUTURE.md`, `documentation/sessions/SESSION_PLAN.md` und `lib/presentation/PROVIDER_GUIDE.md`
> tragen jetzt explizite „geplant, nicht gebaut"-Banner (siehe „Bereits erledigt"). Offen bleibt:

- [ ] **BL-097 · P2 · S — `AUTH.md` erwähnt das lokale Passwort-Hashing mit keinem Wort**
  - *Warum:* Das Auth-Dokument beschreibt Flows, Tokens und Testzugangsdaten, sagt aber nichts darüber, **wie** Passwörter auf dem Gerät gespeichert werden. Genau das ist der schwerwiegendste Auth-Befund (BL-029) — und wer nur die Doku liest, erfährt nichts davon.
  - *Evidenz:* `grep -i hash AUTH.md` liefert **keinen** Treffer, obwohl `lib/core/utils/password_utils.dart:9-13` ungesalzenes SHA-256 verwendet und `lib/features/shared/database/database_helper.dart:609` die Spalte `password_hash` im Klartext-Schema führt; `AUTH.md:50` („Test Credentials (MVP)") und `:171` weisen den Dienst korrekt als Mock aus.
  - *Abnahme:* `AUTH.md` benennt das aktuelle lokale Hash-Verfahren, seine Schwäche und den Zielzustand (server-seitiges Argon2id, BL-029) — in englischer Sprache, passend zum Rest der Datei.

- [ ] **BL-098 · P3 · S — Sieben von zehn Screen-Ordnern haben kein Plan-Dokument**
  - *Warum:* Der Doku-Index benennt die Lücke selbst. Ohne Plan-Dokument gibt es für diese Screens keine Referenz, gegen die man ihr Verhalten prüfen könnte — was ein Teil der Befunde BL-077 und BL-081 erst so spät sichtbar gemacht hat.
  - *Evidenz:* `documentation/README.md:40-44` („Known gap: `lib/presentation/screens/` holds ten screen folders, but only these three carry a plan document"); `lib/presentation/screens/` enthält `activity`, `auth`, `benefit`, `community`, `profile`, `progress`, `security`, `session`, `splash`, `wearable` — Plan-Dokumente existieren nur für Activity, Profile und Progress.
  - *Abnahme:* Für Session Detail, Benefit (+ QR) und Wearable existiert je ein knappes Plan-/Verhaltensdokument in der Sprache des jeweiligen Bereichs; für die übrigen ist im Index festgehalten, wodurch sie abgedeckt sind.

- [ ] **BL-099 · P3 · S — Plan-/Design-Markdown aus `lib/` nach `documentation/` ziehen**
  - *Warum:* Zwölf Markdown-Dateien liegen im Quellcodebaum. Sie werden mitgeliefert, verwirren die Ordnerstruktur und driften leichter vom Code weg als Dateien, die im Doku-Baum neben ihren Geschwistern liegen.
  - *Evidenz:* `find lib -name '*.md'` liefert 12 Dateien, darunter `lib/MAIN_AUTH.md`, `lib/features/FEATURES.md`, `lib/presentation/PROVIDER_GUIDE.md`, `lib/features/security/SECURITY.md`, `lib/features/wearable_integration/WEARABLE_INTEGRATION.md` und die drei `*_SCREEN_PLAN.md`.
  - *Abnahme:* Die Dokumente liegen unter `documentation/`, alle relativen Links (auch die aus `documentation/README.md`) funktionieren weiterhin, und keine Datei wurde dabei übersetzt.

- [ ] **BL-100 · P3 · S — Die Doku-Statusbanner haben keinen Mechanismus, der sie aktuell hält**
  - *Warum:* Der aktuelle Stand ist gut — er ist aber das Ergebnis einer manuellen Runde. Ohne Prüfung verfallen die „Stand:"-Zeilen still, und die Doku fällt in genau den Zustand zurück, den die Korrekturrunde gerade behoben hat.
  - *Evidenz:* `documentation/ROADMAP.md`, `documentation/ARCHITECTURE_REVIEW.md`, `documentation/README.md`, `documentation/FUTURE.md`, `documentation/DEVICE_SMOKE_CHECKLIST.md` und `documentation/sessions/SESSION_PLAN.md` tragen alle handgepflegte Datums-/Branch-Zeilen (aktuell 2026-08-28 / `feat/phase-2-background-tracking`).
  - *Abnahme:* Ein leichtgewichtiger CI-Check (oder ein Eintrag in der PR-Vorlage) erinnert daran, „Stand:"/„Last updated" bei Änderungen an `lib/` mitzuziehen; alle Doku-Wurzeldateien nennen denselben Stand.

---

## ✅ Bereits erledigt (aus ROADMAP/Review nachgezogen)

Punkte, die das Audit noch als offen geführt hat, die aber am Code bzw. an den Dokumenten
**bereits umgesetzt** sind. Sie stehen hier, damit sie nicht ein zweites Mal beauftragt werden.

| Was | Belegt durch |
|-----|--------------|
| **Widget-Test-Layer für kritische Flows** | 50 `testWidgets` in `test/widget/{screens,flows,navigation}` über den gerouteten Harness `test/helpers/app_harness.dart` (ROADMAP.md Phase 1 / Round 4/5 nennt 51 — nachgezählt sind es heute 50). |
| **Navigations-, Auth-Guard- und Deep-Link-Tests** | `test/widget/navigation/auth_redirect_test.dart`, `tab_navigation_test.dart`, `test/unit/router/deep_link_redirect_test.dart` (7 Tests); Deep-Link-Findings F5 gefixt und auf dem Gerät bestätigt. |
| **GPS-Writes gebündelt statt einzeln** | `ActivityProvider` puffert Punkte und schreibt über `GpsPointDao.insertBatch`; Flush bei Pause/Stop/Background (`lib/main.dart:254-259`); ROADMAP.md Phase 1 / Round 2b. Der **Geräte-Nachweis** steht allerdings noch aus → BL-059. |
| **`DATABASE.md` beschreibt die Sync-Pipeline nicht mehr als gebaut** | `database/DATABASE.md:245` („Status: not wired"), `:640` („Steps 6-8 are planned, not implemented") und `:651` („Status: planned, not implemented"). |
| **`SECURITY.md` zeichnet die Controls nicht mehr über** | `lib/features/security/SECURITY.md:42-46` führt Certificate Pinning als „built, not yet wired" mit ausdrücklichem Hinweis auf die `PLACEHOLDER_…`-Fingerprints; die App-Lock-Lücke (ungelesenes `appLockEnabled`) ist als „Known gap" dokumentiert. |
| **`WEARABLE_INTEGRATION.md` behauptet keine gemessene Abdeckung mehr** | `lib/features/wearable_integration/WEARABLE_INTEGRATION.md:46` — „**Target** (design goal, not a measured result): approximately 95% …". |
| **`FUTURE.md` ist als Zielbild gekennzeichnet** | `documentation/FUTURE.md:5-7` — „**Status: aspirational — NOT built.**" plus einer Beschreibung der tatsächlichen `lib/`-Struktur. |
| **`SESSION_PLAN.md`-Sprint-Status ist nachgezogen** | `documentation/sessions/SESSION_PLAN.md:10` (Stand 2026-08-28, Commit `fd7dfc1`); Sprint 4 ✅ (Phase A), Sprints 6/7/8 🟡 „partially delivered", Sprint 10 neu aufgenommen. |
| **`PROVIDER_GUIDE.md`-Teamzuordnung trägt eine Statusnotiz** | `lib/presentation/PROVIDER_GUIDE.md:551-559` — die Zuordnungen sind als erledigt markiert und die abweichenden „Files to Create"-Pfade ausdrücklich als Originalplan gekennzeichnet. |
| **`ROADMAP.md` und `DEVICE_SMOKE_CHECKLIST.md` sind auf dem aktuellen Stand** | Beide tragen „Stand: 2026-08-28 · Branch: `feat/phase-2-background-tracking`" und weisen WP1–WP5 als erledigt, WP6 als offen aus. |
| **Analyzer-Härtung `strict-casts` + CI `--fatal-infos`** | `analysis_options.yaml` (`strict-casts: true`); `.github/workflows/ci.yml` Schritt „Analyze (lib, fatal-infos)". Offen bleibt nur die Ausweitung auf `test/` → BL-061. |
| **Geräte-Smoke-Findings F1, F5, F6** | ROADMAP.md „🔧 Geräte-Smoke-Findings": Datumsformat (`6157ca6`), Custom-Scheme-Deep-Link (`f66fe50`), Biometrie-Erkennung (`96d8cd2`) — alle drei auf dem Gerät verifiziert. F3 und F4 laufen als BL-024 weiter. |

---

> **Pflege dieses Dokuments:** Beim Abarbeiten eines Eintrags wird die Checkbox gesetzt und der
> Eintrag in die Tabelle „Bereits erledigt" verschoben (mit dem Beleg, der ihn schließt) — die ID
> bleibt erhalten. Neue Befunde bekommen die nächste freie Nummer; Nummern werden nie recycelt.
> Bei jeder Änderung die „Stand:"-Zeile oben mitziehen (BL-100).
