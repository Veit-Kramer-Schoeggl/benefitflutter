# Skripte – pma junior award (Diagramme & DOCX-Bearbeitung)

**Python:** unbedingt `/home/veit/miniconda3/bin/python3` verwenden (hat lxml, openpyxl, python-docx, matplotlib, Pillow). Das System-`python3` hat diese Pakete **nicht**.
Abhängigkeiten: siehe `requirements.txt`. System-Binaries: `dot` (graphviz), `soffice` (LibreOffice).

## Render-Skripte (re-runnbar, schreiben nach `../Diagramme/`)
| Skript | Erzeugt | Tool |
|--------|---------|------|
| `mta.py` | `Meilenstein-Trendanalyse.png` (MTA-Dreieck, Berichtszeitpunkte teils geschätzt) | matplotlib |
| `psp.py` (+ `psp.dot`) | `Projektstrukturplan.png` (PSP, phasen-farbcodiert) | graphviz |
| `umwelt.py` (+ `umwelt.dot`) | `Projektumweltanalyse_graphviz.png` (Generator-Version) | graphviz |

Ausführen z. B.: `cd scripts && /home/veit/miniconda3/bin/python3 mta.py`

⚠️ **Umweltanalyse:** Die im Handbuch verwendete Fassung wurde **manuell in LibreOffice Draw** überarbeitet. **Master = `../Diagramme/Projektumweltanalyse.odg`** (→ daraus PNG/SVG exportieren). `umwelt.py` erzeugt nur die ursprüngliche Generator-Version (`*_graphviz.png`) und überschreibt die editierte Fassung NICHT.

## Historische Einmal-Skripte (Referenz, NICHT direkt re-runnbar)
Diese liefen gegen ein temporäres `/tmp/hb_work` (entpacktes Handbuch) und dienen als Nachvollziehbarkeit der vorgenommenen DOCX-Edits:
`edit1.py` (Endereignis/Vorprojektphase/Ziele), `cost.py` (Kostenplan-Rekonziliation), `datefix.py` (Datumskorrekturen), `legend.py` (Risiko-Legendentabelle), `risk.py` (Risiko-Punktfarben), `ein_edit.py` (Einreichformular Flutter), `mta_embed.py` (Chart→Bild im DOCX), `docedit.py` (Hilfsfunktionen).

## DOCX-Workflow (falls erneut bearbeitet werden muss)
1. `unzip` der `.docx` in einen Arbeitsordner.
2. XML knoten-basiert mit **lxml** ändern (keine Regex-Struktur-Edits), **UTF-8 ohne BOM** schreiben, `<?xml … standalone="yes"?>` erhalten.
3. Bei Diagramm-Werten: Chart-`<c:v>`-Cache **und** eingebettete `word/embeddings/*.xlsx` synchron halten.
4. Mit Python `zipfile` strukturerhaltend neu packen (Reihenfolge beibehalten), dann `unzip -t` + `soffice --headless --convert-to pdf` zur Validierung.
