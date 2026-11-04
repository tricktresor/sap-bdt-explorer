# sap-bdt-Explorer
[![abaplint](https://github.com/tricktresor/sap-bdt-explorer/actions/workflows/abaplint.yml/badge.svg)](https://github.com/tricktresor/sap-bdt-explorer/actions/workflows/abaplint.yml)

SAP Business Data Toolset Explorer

Report `ZBDT_EXPLORER` zeigt das BDT-Customizing eines Applikationsobjekts (z. B. `BUPA`) als ALV-Baum direkt auf dem Selektionsbild und kann ausgewählte Einträge samt abhängiger Einträge in einen Customizing-Auftrag schreiben.

## Funktionen

- **Hierarchie** (lazy geladen beim Aufklappen, Aufklapp-Pfeil nur bei vorhandenem Inhalt, keine leeren Ordner)
  - Applikationen (TBZ0A) → Sichten der Applikation
  - Bildfolgen (TBZ3) → Bilder (TBZ3K/TBZ3A) → Abschnitte (TBZ3I/TBZ3C) → Sichten (TBZ3H/TBZ3E) → Feldgruppen (TBZ3S/TBZ3W) → Felder (TBZ3R)
  - Ereignisse (TBZ1F) → registrierte Funktionsbausteine
  - Datenmengen (TBZ0Q), Tabellen (TBZ1H), Aktivitäten (TBZ0O)
  - Objektteile (TBZ0), benannt wie im Applikationsobjekt (bei BUPA „BP Views“ / „BP View“), darunter wie im View-Cluster `BUPA_TBZ0`: Data Sets (TBZ0S), Calling Applications (TBZ0C), Screen Sequences (TBZ0U), Views (TBZ0F), Subheader ID (TBZJ2)
- **Applikationsfilter**: Es erscheinen nur Bildfolgen und Bilder, die eine Sicht der Applikation enthalten, Datenmengen ihrer Sichten und Objektteile, die die Applikation aufrufen (darunter nur Einträge mit Bezug zur Applikation). Unter einem solchen Bild werden alle Abschnitte mit allen Sichten gezeigt. Tabellen und Aktivitäten haben keinen Applikationsbezug und entfallen.
- **Feldmodifikation**: unter jeder Feldgruppe der Feldstatus je Aktivität (`+` Muss, `.` Kann, `*` Anzeige, `-` Ausgeblendet) aus TBZ0O
- **Alles aufklappen** (Button *Expand all*): lädt und öffnet alles unter den markierten Knoten, ohne Markierung den ganzen Baum
- **Verwendungsnachweis** (Button *Where-used*): Feld/Struktur, Funktionsbaustein, Programm/Dynpro oder Feldgruppe; Treffer lassen sich nach oben aufklappen (Feldgruppe → Sicht → Abschnitt → Bild → Bildfolge)
- **Transport** (Button *Transport*): mehrere Knoten markieren, wählen ob abhängige Einträge mitgenommen werden, Vorschau der Tabellenschlüssel, dann Auswahl eines Customizing-Auftrags (`TR_ORDER_CHOICE_CORRECTION` / `TR_APPEND_TO_COMM_OBJS_KEYS`)
  - „Mit Abhängigen“ nimmt alles mit, was der Baum unter dem Knoten zeigt; bei einer Applikation zusätzlich ihre Ereignis-FBs
  - Mit Applikationsfilter: Abschnitte und Sichten anderer Applikationen werden nur als Zuordnung zum eigenen Bild bzw. Abschnitt mitgenommen (TBZ3I/TBZ3H); das Applikationsobjekt selbst (TBZ1) und die Bildfolgen-Zuordnung eines Objektteils (TBZ0U) gar nicht
  - Die Einträge werden wie bei SM30/SM34 aufgezeichnet: je Pflegedialog ein Objekt `CDAT`/`VDAT` (z. B. `BUPA_TBZ3E`, `V_TBZ0A`), die Schlüssel mit View-Cluster und View
  - Zuordnungseinträge zum Nachbarknoten (TBZ3K, TBZ3I, TBZ3H, TBZ3S) werden mitgenommen, Texttabellen in allen Sprachen
  - Der Feldstatus (TBZ0O) wird nur bei expliziter Auswahl transportiert, weil ein Eintrag die Status aller Feldgruppen einer Aktivität enthält
- **Navigation ins Customizing** per Klick auf den Knotentext, wie die Transaktionen BUS1–BUS23 (Report `BUSVIEWS`), positioniert auf den Eintrag:

  | Knoten | Pflege |
  |---|---|
  | Objekt | View-Cluster `BUPA_TBZ1` |
  | Applikation | View `V_TBZ0A` |
  | Bildfolge | View-Cluster `BUPA_TBZ3` |
  | Bild | View-Cluster `BUPATBZ3A` |
  | Abschnitt | View-Cluster `BUPA_TBZ3C` |
  | Sicht | View-Cluster `BUPA_TBZ3E` |
  | Feldgruppe, Feld | View-Cluster `BUPAFLDMOD` |
  | Ereignis, Ereignis-FB | View-Cluster `BUPATBZ1AR` |
  | Tabelle | View `V_TBZ1H` |
  | Datenmenge | View `V_TBZ0Q` |
  | Objektteil und alles direkt darunter | View-Cluster `BUPA_TBZ0`, Startobjekt je Unterordner (`V_TBZ0S`, `V_TBZ0C`, `V_TBZ0U`, `V_TBZ0F`, `V_TBZJ2`) |
  | Aktivität, Feldstatus | View `V_TBZ0O_2` |

  Kennt eine Pflege ein Feld der Positionierung nicht, öffnet sie nur mit dem Applikationsobjekt.
- **Navigation zu Entwicklungsobjekten** per Doppelklick: Funktionsbaustein (SE37), Programm der Sicht, Tabelle/Struktur (SE11)

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

## Statische Prüfung

Jeder Push auf `main` und jeder Pull Request wird per GitHub Action mit [abaplint](https://abaplint.org) geprüft (Konfiguration: `.abaplint.json`, Syntaxstand 7.40 SP08). SAP-Standardobjekte wie die TBZ*-Tabellen sind dort nicht bekannt und werden als „void“ behandelt; geprüft wird der Code im Namensraum `Z`/`Y`.

## Status

Alle Datenbankzugriffe sind statisch; beim Transport werden nur die Schlüsselspalten gelesen und direkt als E071K-TABKEY verwendet.

Alle verwendeten TBZ*-Tabellen (Schlüssel, Felder, Datenelemente) und die Schnittstellen der aufgerufenen Funktionsbausteine sind gegen DD03L bzw. FUPARAREF abgeglichen.
