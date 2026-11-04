# sap-bdt-Explorer
SAP Business Data Toolset Explorer

Report `ZBDT_EXPLORER` zeigt das BDT-Customizing eines Applikationsobjekts (z. B. `BUPA`) als ALV-Baum direkt auf dem Selektionsbild und kann ausgewählte Einträge samt abhängiger Einträge in einen Customizing-Auftrag schreiben.

## Funktionen

- **Hierarchie** (lazy geladen beim Aufklappen)
  - Applikationen (TBZ0A) → Sichten und Ereignis-FBs der Applikation
  - Bildfolgen (TBZ3) → Bilder (TBZ3K/TBZ3A) → Abschnitte (TBZ3I/TBZ3C) → Sichten (TBZ3H/TBZ3E) → Feldgruppen (TBZ3S/TBZ3W) → Felder (TBZ3R)
  - Ereignisse (TBZ1F) → registrierte Funktionsbausteine
  - Tabellen (TBZ1H), Datenmengen (TBZ0Q), Aktivitäten (TBZ0O)
- **Feldmodifikation**: unter jeder Feldgruppe der Feldstatus je Aktivität (`+` Muss, `.` Kann, `*` Anzeige, `-` Ausgeblendet) aus TBZ0O
- **Verwendungsnachweis** (Button *Where-used*): Feld/Struktur, Funktionsbaustein, Programm/Dynpro oder Feldgruppe; Treffer lassen sich nach oben aufklappen (Feldgruppe → Sicht → Abschnitt → Bild → Bildfolge)
- **Transport** (Button *Transport*): mehrere Knoten markieren, wählen ob abhängige Einträge mitgenommen werden, Vorschau der Tabellenschlüssel, dann Auswahl eines Customizing-Auftrags (`TR_ORDER_CHOICE_CORRECTION` / `TR_APPEND_TO_COMM_OBJS_KEYS`)
  - Zuordnungseinträge zum Nachbarknoten (TBZ3K, TBZ3I, TBZ3H, TBZ3S) werden mitgenommen, Texttabellen in allen Sprachen
  - Der Feldstatus (TBZ0O) wird nur bei expliziter Auswahl transportiert, weil ein Eintrag die Status aller Feldgruppen einer Aktivität enthält
  - Ein Applikationsfilter wird beim Transport berücksichtigt
- **Navigation** per Doppelklick: Funktionsbaustein (SE37), Programm der Sicht, Tabelle/Struktur (SE11)

## Installation

Mit [abapGit](https://abapgit.org) in ein Paket (z. B. `$BDT_EXPLORER` oder `ZBDT_EXPLORER`) ziehen. Voraussetzung: ABAP 7.40 SP08 oder höher.

## Objekte

| Objekt | Zweck |
|---|---|
| `ZBDT_EXPLORER` | Report mit Selektionsbild und Docking-Container |
| `ZIF_BDT_EXPLORER_TYPES` | Knotentypen, Knotenstruktur |
| `ZCL_BDT_EXPLORER_MODEL` | Lesen der TBZ*-Tabellen, Hierarchie und Verwendungsnachweis |
| `ZCL_BDT_EXPLORER_TRANSPORT` | Sammeln der Einträge, Schlüsselaufbau (E071K), Auftrag |
| `ZCL_BDT_EXPLORER_TREE` | SALV-Baum, Toolbar, Ereignisse |

## Status

Erste Version, noch nicht in einem SAP-System aktiviert. Alle Datenbankzugriffe sind statisch; beim Transport werden nur die Schlüsselspalten gelesen und direkt als E071K-TABKEY verwendet.

Gegen DD03L geprüfte Schlüssel: TBZ0O, TBZ0R, TBZ1C, TBZ1F, TBZ3H, TBZ3K, TBZ3R, TBZ4A. Die übrigen Schlüssel stammen aus DDIC-Referenzen (sapdatasheet.org).
