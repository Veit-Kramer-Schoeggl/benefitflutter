# Review zur PMA Junior Award Einreichung: Projekt "BeneFit"

Dieses Dokument enthält ein detailliertes Review der Einreichungsunterlagen (Projekthandbuch `pma-Handbuch BeneFit_commHH_anjas_updates.docx` und Einreichformular `Einreichformular_junior_award_2026.docx`) für den **pma junior award 2026**. Die Analyse orientiert sich an der **IPMA® Project Excellence Baseline (PEB)** und den pma-Bewertungskriterien.

> [!IMPORTANT]
> **Zusammenfassung der kritischsten Mängel & Team-Entscheidungen:**
> 1. **Falsche Beschreibung im Einreichformular (Flutter vs. Kotlin/Android):** Das Handbuch beschreibt die App korrekterweise mit **Flutter**. Das Einreichformular beschreibt sie fälschlicherweise als native Android-App (Kotlin, Room, Hilt). Das Einreichformular muss dringend auf Flutter angepasst werden.
> 2. **Termin-Mismatch & Chart-Anpassung:** Der Projektzeitraum wird im Handbuch auf das tatsächliche **Sommersemester 2025** (ca. April – Juni 2025) angepasst. **Wichtig:** Sämtliche Diagramme (MTA, Balkenplan, Personaleinsatz, Kosten) müssen an diesen neuen Zeitraum angepasst werden!
> 3. **Ex-post-Dokumentation (Änderungsverzeichnis):** Da die Nominierung und die Erstellung des Handbuchs erst nach Projektende (Mai/Juni 2026) erfolgten, wird empfohlen, die Daten im Änderungsprotokoll zurückzudatieren, um eine prozessbegleitende Steuerung zu simulieren.
> 4. **19 Arbeitspakete:** Diese werden derzeit vom Team befüllt. Hierbei ist auf die durchgehende Verwendung von Flutter-Terminologie zu achten.

---

## 1. Kritische Widersprüche & Konsistenzfehler

### 1.1 Der Technologie-Widerspruch (Einreichformular korrigieren!)
* **Status im Handbuch:** Das Handbuch beschreibt korrekterweise die plattformübergreifende Entwicklung mit **Flutter**.
* **Status im Einreichformular:** Im Einreichformular steht fälschlicherweise: *"Technisch basiert die App auf einer Repository-Architektur mit Room-Datenbank und Dependency Injection (Hilt)."* Dies beschreibt eine native Android-App.
* **Auswirkung:** Ein solcher Widerspruch führt bei der Jury zu erheblichem Punktabzug, da Einreichformular und Handbuch technologisch nicht übereinstimmen.
* **Empfehlung:** Der Kurztext im Einreichformular muss auf Flutter angepasst werden:
  * Ersetzung von "native Android-App" durch *"plattformübergreifende (Cross-Platform) App entwickelt in Flutter (für iOS und Android aus einer Codebasis)"*.
  * Ersetzung von "Room-Datenbank und Dependency Injection (Hilt)" durch Flutter-äquivalente Technologien (z. B. *"lokale Datenhaltung mit SQLite/sqflite bzw. Hive und modernem State Management (z. B. Provider/Riverpod/Bloc)"*).

### 1.2 Der Termin- & Semester-Mismatch (Diagramme anpassen!)
Der Projektzeitraum im Handbuch wird auf das tatsächliche **Sommersemester 2025** (z. B. April 2025 – Juni 2025) angepasst, um mit den Git-Commits und dem Einreichformular übereinzustimmen.
* **Auswirkung:** Wenn der Text geändert wird, aber die Grafiken die alten Termine zeigen, ist das Dokument inkonsistent.
* **Empfehlung:** 
  > [!WARNING]
  > **SEHR WICHTIG:** Alle im Handbuch eingebetteten Diagramme und Pläne müssen zwingend auf die neuen Termine des Sommersemesters 2025 angepasst werden:
  > 1. **Balkenplan (Gantt-Chart):** Verschiebung des gesamten Zeitrahmens auf Frühjahr/Sommer 2025.
  > 2. **Meilenstein-Trendanalyse (MTA):** Die Berichtszeitpunkte (z. B. Berichtsstände) und Meilensteine müssen im Sommersemester 2025 liegen.
  > 3. **Personaleinsatzdiagramm & Kostenverlaufsgrafik:** Zeitachse auf Sommersemester 2025 anpassen.
  > 4. **Risiko-Matrix:** Zeitliche Risiken an den neuen Rahmen anpassen.

### 1.3 Nachträgliche Erstellung der PM-Dokumente (Änderungsverzeichnis)
* **Kontext:** Da das Team erst nach Projektende für den Award nominiert wurde, begann die Erstellung des Handbuchs erst im Mai/Juni 2026.
* **Auswirkung auf die Jury:** Für die Jury sollte das Handbuch so wirken, als ob es ein aktives Steuerungsinstrument während der Projektlaufzeit war. Ein Änderungsprotokoll mit Daten nach dem Projektende entlarvt das Handbuch als rein retrospektives Dokument.
* **Empfehlung:** Die Daten im Änderungsprotokoll (Tabelle 1) fiktiv in den echten Projektverlauf (Sommersemester 2025) zurückdatieren (z. B. Version 0.1 im April 2025, Version 0.3 im Mai 2025, Version 0.8/1.0 zum offiziellen Projektabschluss im Juni 2025). Die Beschreibungen sollten reale PM-Aktivitäten widerspiegeln (z. B. "Erstellung Projektstrukturplan", "Anpassung Meilensteinplan", "Freigabe Abschlussbericht").

---

## 2. Inhaltliche & Methodische Lücken im Handbuch

### 2.1 Arbeitspaket-Spezifikationen (Befüllung läuft)
* **Status:** Die 19 leeren Arbeitspaket-Tabellen werden aktuell vom Team befüllt.
* **Empfehlung:** Bei der Befüllung der technischen APs (z. B. AP 2.1.3 Technische Anforderungen, AP 2.2.2 Datenmodelle, AP 2.2.3 Provider-Konzept, AP 3.1 Entwicklung) konsequent **Flutter- und Dart-Terminologie** verwenden. Vermeidet Begriffe wie Kotlin, Hilt oder Room, um technologische Konsistenz zu wahren.

### 2.2 Konzeptfehler bei der Vorprojektphase
* **Status im Handbuch (Tabelle 5):** Unter *Dokumente der Vorprojektphase* werden fälschlicherweise Projektergebnisse wie der detaillierte Projektstrukturplan, die Risikoanalyse und der Abschlussbericht aufgelistet.
* **PM-Methodik:** Diese Dokumente entstehen erst im Projekt selbst. In der Vorprojektphase gibt es nur initiale Dokumente.
* **Empfehlung:** Die Liste in Tabelle 5 bereinigen. Nur Dokumente wie *"Gesprächsprotokoll zur Projektidee"*, *"Vorentwurf Projektauftrag"* oder *"FH-Projektzusage"* als Ergebnisse der Vorprojektphase deklarieren.

### 2.3 Abwesenheit des Projektleiters bei der Projektabnahme
* **Status im Handbuch:** In den Protokollen zum Fortschrittsmeeting (17.12.) und zum Abschlussmeeting (23.02.) ist Projektleiter Veit Kramer-Schöggl als **abwesend** eingetragen.
* **PM-Methodik:** Dass der Projektleiter beim offiziellen Abnahme- und Übergabemeeting mit dem Auftraggeber fehlt, ist methodisch ein schwerer Fehler (Rolle der Projektleitung/Leadership).
* **Empfehlung:** Ändert die Anwesenheitsliste im Protokoll. Der Projektleiter muss bei der offiziellen Abnahme und den wichtigen Status-Meetings anwesend gewesen sein.

### 2.4 Rechenfehler im Kostenplan (Tabelle 60)
* **Plankosten-Abweichung:** Summe der Zeilen = **22.707,50 €** vs. Tabellenfuß = **22.697,50 €** (10 € Differenz).
* **Istkosten-Abweichung:** Summe der Zeilen = **24.118,50 €** vs. Tabellenfuß = **24.098,50 €** (20 € Differenz).
* **Empfehlung:** Die Summen in Tabelle 60 rechnerisch exakt angleichen.

### 2.5 Schönrechnen der Kostenabweichung
* **Status:** Die Kostenabweichung wird zur *adaptierten* Baseline (+570 €) statt zur *originalen* Baseline aus dem Projektauftrag (+1.401 € / ~6,17 %) angegeben.
* **Empfehlung:** Weist die tatsächliche Abweichung von 1.401 € zur Original-Baseline offen aus und begründet sie professionell (z. B. durch Zusatzaufwände bei der Sensor-Integration, gedeckt durch das Risikobudget). Das zeigt echte Projektsteuerungskompetenz.

### 2.6 Fehlende Integration des Risikobudgets
* **Status:** Ein Risikobudget von **2.765 €** wurde berechnet, taucht aber im Kostenplan nicht auf.
* **Empfehlung:** Im Text zum Kostenplan kurz erläutern, dass das Risikobudget als *Management Reserve* außerhalb der regulären Arbeitspaket-Budgets geführt wurde.

### 2.7 Tippfehler & Datumsfehler
* **Tabelle 3 (Projektauftrag):** Unter *"Formales Projektendereignis"* steht fälschlicherweise *"Kick-Off-Meeting"*. Das muss durch *"Abschlusspräsentation und Projektabnahme"* ersetzt werden.
* **Jahreszahlen korrigieren:**
  * **Tabelle 27 (AP 1.4.3 Lessons Learned):** Start/Ende auf `2025` statt `2026` datiert.
  * **Tabelle 45 (AP 3.2.3 Fehlerbehebung):** Start auf `2026` statt `2025` datiert.
  * **Tabelle 21 (AP 1.2.3 Kommunikation):** Ende auf `25.02.26` statt `25.02.2026` korrigieren.

---

## 3. Offene Lücken im Einreichformular

Das Dokument `Einreichformular_junior_award_2026.docx` enthält noch viele leere Felder (mit Punkten `.` markiert). Hier sind die konkreten Daten, die das Team eintragen sollte:

### 3.1 Ausbildungseinrichtung (FH JOANNEUM)
* **Name der Ausbildungseinrichtung:** `FH JOANNEUM Gesellschaft mbH`
* **Adresse der Ausbildungseinrichtung:** `Eckertstraße 30i, 8020 Graz`
* **Fachrichtung / Ausbildungsschwerpunkt:** `eHealth / Digital Transformation in Healthcare` (Bachelor-Studiengang)
* **Wochenstunden Projektmanagement:** *[Hier eintragen, z. B. 2 oder 3 Semesterwochenstunden laut Curriculum]*
* **Kontaktperson Ausbildungseinrichtung:** `Hannes Hilberger, BSc MSc`
* **E-Mail Adresse:** `hannes.hilberger@fh-joanneum.at`

### 3.2 Projektteam & Ansprechpartner
* **Projektname:** `BeneFit`
* **Art des Projekts:** `Semesterprojekt / Übungsprojekt`
* **Projektmanager\*in:** `Veit Kramer-Schöggl`
* **Projektteammitglieder:** `Anja Schloffer, Lisa Pöhl, Fabienne Potisk`
* **Das wievielte Jahr haben die Einreichenden PM-Unterricht?** `1. Jahr` (bzw. je nach Studienplan)
* **Kontaktperson für die Einreichung:** `Veit Kramer-Schöggl`
* **E-Mail Adresse:** `veit.kramer@edu.fh-joanneum.at`
* **Telefonnummer:** `069981876764`

### 3.3 Projektdauer
* **Projektdauer:** Anpassen an die realen Daten des Sommersemesters 2025 (z. B. April 2025 – Juni 2025).
