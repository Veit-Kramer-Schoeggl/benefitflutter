# HANDOFF – pma junior award 2026 · BeneFit

> Dieses Dokument gibt einem neuen Claude-Session (oder Menschen) den **vollständigen Kontext**, um nahtlos weiterzuarbeiten. Detail-Status steht in [`TODO.md`](TODO.md), die strengere Bewertung in [`PMA_Submission_Review.md`](PMA_Submission_Review.md).

## Worum es geht
Einreichung für den **pma junior award 2026** (Projekt Management Austria). Eingereicht wird das **Bachelorprojekt „BeneFit"** – eine **Flutter**-App, die Bewegung trackt und mit monetären Anreizen/Benefits belohnt. Betreuer Hannes Hilberger hat das Projekthandbuch kommentiert; diese Arbeit setzt seine Kommentare + ein PMA-Review um.

**Wichtige Projekt-Historie (nicht verwechseln!):**
- `~/StudioProjects/BeneFit` = altes **native-Android-Semesterprojekt** (Java/Room/Hilt, Git Mai–Jun 2025). NUR Vorläufer.
- `~/AndroidStudioProjects/benefitflutter` = das **echte Bachelorprojekt in Flutter** ← hier liegt jetzt alles (Ordner `pma_junior_award/`).
- In der Einreichung wird das Projekt durchgängig als **Flutter** dargestellt.

## Beteiligte & Fristen
- **Projektteam:** Veit Kramer-Schöggl (Projektleiter), Anja Schloffer, Lisa Pöhl, Fabienne Potisk.
- **Auftraggeber/Betreuer:** Hannes Hilberger, BSc MSc – **FH JOANNEUM, Institut eHealth**.
- **Fristen:** Einreichung **bis 30.06.2026**; Gala/Verleihung **19.11.2026**.

## Verbindliche Entscheidungen (mit Veit abgestimmt – nicht eigenmächtig ändern)
- **Technologie:** als **Flutter** darstellen (Dart, Provider, SQLite/sqflite, Health Connect/HealthKit + BLE-Wearables, geolocator/GPS, €-Benefit-System).
- **Projektzeitraum:** **WS 2025/26** beibehalten (Kick-off 23.10.2025 … Abschluss 25.02.2026). **KEIN** Shift auf SS 2025.
- **Kein Rückdatieren** von Änderungslog/Anwesenheit.
- **Art des Projekts:** Bachelorprojekt.
- **Schreibweise:** „FH JOANNEUM" (Großbuchstaben), „eHealth".
- **Kosten (final, konsistent):** Personal Plan 22.707,50 € / Ist 24.108,50 €; + Sachmittel/Infrastruktur 546 € (Leihgeräte 240, Laptop-AfA 210, Homeoffice 96); **Gesamt Plan 23.253,50 € / Ist 24.654,50 €**. Ehrliche Abweichung **+1.401 € (≈6,17 %)** ggü. Original-Baseline, gedeckt durch Risikobudget (Management Reserve 2.765 €).

## Stand der Deliverables (Detail in TODO.md)
- ✅ **`pma-Handbuch BeneFit überarbeitet.docx`** – die finale, bearbeitete Fassung (alle Hannes-Kommentare + Review-Punkte umgesetzt).
- ✅ **`Einreichformular_junior_award_2026.docx`** – auf Flutter umgestellt, §3-Felder befüllt.
- ✅ Diagramme: **PSP** farbcodiert + „Architektur & Konzeption"; **MTA** als Dreieck-Bild (Berichtspunkte teils geschätzt); **Risiko-Matrix** Punkte R1–R9 + Legende; **Projektumweltanalyse** als Beziehungsgraph (von Veit in LibreOffice Draw nachbearbeitet).
- Basis-/Zwischenstände: `*_commHH.docx` (Hannes' Kommentare), `*_anjas_updates.docx` (Anja-Basis), `*geteilt.docx/pdf`.

## OFFENE Punkte (To-do)
- ⛔ **Unterschriften** im Handbuch einfügen (Projektauftrag, Fortschrittsberichte, Abschluss).
- ⛔ **MS-Project-Untertasks/Abhängigkeiten** (Balkenplan) – nicht automatisierbar.
- ⛔ Einreichformular: **Wochenstunden Projektmanagement** & **Schulstufe/Semester** ausfüllen (weiß nur das Team).
- ⛔ Appendix-Entscheidung (Corporate-Design-Guidelines/Recherche als Anhang?).
- ⛔ Ampel-Bild im Fortschrittsbericht (Haken weg / nur aktive Farbe).
- 🔧 **In Word zwingend:** bei Kosten- & Risiko-Chart einmal „Daten bearbeiten" (Neu-Rendern). MTA & Umwelt sind Bilder.

## Datei-Map (dieser Ordner `pma_junior_award/`)
```
HANDOFF.md                 ← dieses Dokument
TODO.md                    ← detailliertes Änderungsprotokoll/Status
PMA_Submission_Review.md   ← strenge Review-Punkte
pma-Handbuch BeneFit überarbeitet.docx   ← FINALE Fassung
pma-Handbuch BeneFit_commHH.docx         ← Hannes' Kommentare (Original)
pma-Handbuch BeneFit_commHH_anjas_updates.docx ← Anja-Basis
pma-Handbuch BeneFit geteilt.docx / .pdf
Einreichformular_junior_award_2026.docx
Diagramme/   Projektumweltanalyse.odg (MASTER) /.svg/.png, *_graphviz.png,
             Meilenstein-Trendanalyse.png, Projektstrukturplan.png
scripts/     Render- & Edit-Skripte (siehe scripts/README.md) + requirements.txt
referenzen/  Design_Manual_BeneFit.pdf, Figma_Benefit1-3.png
```

## Tooling / Gotchas (WICHTIG zum Weiterarbeiten)
- **Python:** `/home/veit/miniconda3/bin/python3` (hat lxml, openpyxl, python-docx, matplotlib, Pillow). System-`python3` hat sie **nicht**.
- **graphviz** (`dot`) und **LibreOffice** (`soffice`) sind installiert. Bei offener LO-Sitzung separates Profil nutzen: `-env:UserInstallation=file:///tmp/lo_conv`.
- **Diagramme ändern:**
  - Umweltanalyse: `Diagramme/Projektumweltanalyse.odg` in **LibreOffice Draw** bearbeiten → als PNG (hochauflösend) exportieren → ins Handbuch tauschen (Bild `word/media/image3.png`).
  - PSP/MTA: `scripts/psp.py` bzw. `scripts/mta.py` anpassen & re-runnen (Output landet in `Diagramme/`). MTA-Daten/Prognosen stehen oben im `mta.py`.
  - Risiko-/Kosten-Chart: native Office-Charts im DOCX (`word/charts/chart3.xml` Kosten, `chart4.xml` Risiko) – via lxml editieren, Cache + `embeddings/*.xlsx` synchron halten.
- **DOCX neu packen:** entpacken → lxml-Edits → mit `zipfile` strukturerhaltend packen → `unzip -t` + `soffice --headless --convert-to pdf` prüfen.
- **Bild im DOCX tauschen (EMU):** Original-`wp:extent`-Breite `cx` behalten, `cy = cx × (BildHöhe/BildBreite)` neu setzen (sonst Verzerrung). Beispiel-Code in `scripts/mta_embed.py`.

## So geht's weiter
`cd ~/AndroidStudioProjects/benefitflutter && claude` – das Memory zu diesem Projekt wird automatisch geladen; bei Bedarf dieses HANDOFF + `TODO.md` lesen. (Hinweis: ein `claude --resume` der alten Session funktioniert nach dem Ordnerwechsel vermutlich nicht – dieses Dokument ist der verlässliche Einstieg.)
