# Govee Studio

**Dein Bildschirm. Dein Sound. Dein Licht.**

Eine native macOS-App für Desktop-Ambilight, lokale Lichtshows und Musikreaktionen mit kompatiblen Govee-Leuchten. SwiftUI statt Browser-Wrapper, ScreenCaptureKit für Bildschirm und Systemaudio, direkte LAN-Ausgabe für lokale Effekte.

Created by **Naiklas**. Aus einem persönlichen Lichtlabor entstanden — inklusive einer kleinen Portion Neon-Schlat.

> Eigenständiges Community-Projekt, nicht von Govee entwickelt, unterstützt oder geprüft. Derzeit private Entwicklung, noch keine Open-Source-Lizenz erteilt.

## Was drin ist

- **Ambilight:** Bildschirmbereiche auf Panels und Strip-Segmente legen; Helligkeit, Sättigung, Glättung und schwarze Bildränder abstimmen.
- **Setup-Editor:** Zonen verschieben und skalieren, Mehrfachauswahl, Gruppenbewegung, Segmenttests und gespeicherte Profile.
- **Lokale Szenen:** elf Looks von Aurora und Glutwerk bis Prism Drift und Liquid Chrome; eigene Grundfarbe, Bewegung und Intensität.
- **Mac-Musik:** acht Reaktionen und zehn Paletten. Bass, Mitten, Höhen und Audioanstiege steuern Lichtmuster. Optional läuft Ambilight als separat einstellbarer Hintergrund mit.
- **Govee-Gerätemusik:** gerätespezifische Original-Musikmodi im ganzen Raum. Empfindlichkeit, Helligkeit und Raum-Farbschemata einstellen; bei passenden Hexagons mit herstellereigenen Flächeneffekten.
- **Original- und DIY-Szenen:** Katalog durchsuchen, einzelne Geräte steuern oder für jedes Gerät einen Originaleffekt wählen und alle mit einem Knopf starten.
- **Optionaler Raum-Mix:** etwa Govee-Musik auf den Hexagons und Ambilight auf den Strips. Genau eine Ausgabequelle pro Gerät.

Die Oberfläche ist derzeit auf Deutsch. Das Projekt ist experimentell; die Kompatibilität hängt vom konkreten Gerät und seiner Firmware ab.

## Voraussetzungen

- macOS 14 oder neuer laut Build-Konfiguration. Die tatsächlichen Hardwaretests fanden auf Apple Silicon mit macOS 26 statt; ältere Systeme und Intel-Macs sind nicht verifiziert.
- Für den Quellcode-Build: vollständiges Xcode mit Swift 6 oder neuer. Das Package verwendet aktuell Swift-5-Sprachmodus.
- Govee-Leuchten mit aktivierter **LAN-Steuerung** in Govee Home, erreichbar vom Mac im lokalen Netzwerk.
- Für lokale Ambilight-/Szenen-/Mac-Musik-Ausgabe ist **kein API-Key** nötig.
- Optional: eigener Govee-API-Key und Internet für Original-/DIY-Szenen und Gerätemusik-Steuerbefehle.

## Bauen und starten

Im geklonten Repository:

```sh
./scripts/test.sh
./scripts/build-app.sh --install
open "$HOME/Applications/Govee Studio.app"
```

Das Script bevorzugt `/Applications/Xcode.app`, ohne die globale `xcode-select`-Einstellung zu ändern. Es installiert die App unter `~/Applications` und erstellt `dist/Govee-Studio.zip`. Ohne `--install` wird nur gebaut und verpackt.

Die App ist lokal ad-hoc signiert, nicht notarisiert und kein App-Store-Release. Das Script baut für die Architektur des ausführenden Macs; es erstellt kein Universal-Binary. Es werden keine privaten Konfigurationsdateien in das Bundle kopiert.

## Erstes Setup

1. Pro Leuchte **LAN-Steuerung** in Govee Home aktivieren. Mac und Leuchten müssen einander im Netzwerk erreichen können.
2. Govee Studio öffnen, zu **Setup** wechseln und **Geräte suchen** ausführen. Falls macOS nach lokalem Netzwerkzugriff fragt, diesen erlauben.
3. Für Ambilight oder Mac-Systemaudio die macOS-Freigabe für Bildschirm-/Systemaudioaufnahme erteilen; gegebenenfalls die App anschließend neu starten.
4. Bildschirm und Leuchten auswählen. Zonen im Editor auf die gewünschten Bildschirmbereiche legen. Mehrfachauswahl ist mit Steuerung + Mausklick möglich.
5. Segmentzahl und Reihenfolge mit dem kurzen Segmenttest überprüfen. Voreinstellungen sind Startwerte, keine automatische Hardware-Kalibrierung.
6. **Ambilight**, **Szenen** oder **Musik** öffnen und die gewünschte Ausgabe starten. **Stoppen** oder `⌘.` beendet sie und sendet die gesicherten Grundwerte zurück.

Der Editor speichert Einstellungen automatisch. Benannte Profile sichern Zuordnung und Lichtparameter. **Vorschau** arbeitet ohne Lichtausgabe. Die App schließt ihre eigenen Fenster aus der Bildschirmaufnahme aus.

### Originaleffekte und Gerätemusik

Im Govee-Bereich einen eigenen API-Key eingeben. **Dauerhaft speichern** legt ihn im macOS-Schlüsselbund ab; bei weiteren Starts wird er automatisch geladen. Danach **Katalog aktualisieren** beziehungsweise **Musikmodi abrufen** wählen.

Unter **Szenen → Govee · Original & DIY → Ganzer Raum · Original** pro aktivierter Leuchte einen Effekt wählen und die vollständige Auswahl starten. Es werden ausschließlich die jeweiligen gerätespezifischen Szenen-IDs verwendet. Einzelgeräte und DIY bleiben separat auswählbar.

**Mac · Systemaudio** und **Govee · Geräte-Musik** sind unterschiedliche Engines: Govees interne Musikmodi reagieren am Gerät und bekommen keinen Mac-Audiostream. Die laufende interne Reaktion benötigt keinen fortlaufenden Cloud-Stream; Start, Farbwahl und Empfindlichkeit werden über die Cloud gesteuert. Reines Dimmen läuft über LAN.

## Kompatibilität und Grenzen

| Modell | Bisher überprüft |
| --- | --- |
| H606A / Hexagon Ultra | LAN-Farben, lokales Kanalstreaming, Originaleffekte und interne Musikreaktionen auf mehreren Flächen |
| H61A0 / Neon Rope Light | LAN-Farben, lokales Kanalstreaming und interne Musikreaktion |
| H61A2 / Neon Rope Light | LAN-Farben, lokales Kanalstreaming und interne Musikreaktion |

Diese Liste beschreibt bisherige Tests, keine Garantie für jede Firmware oder jeden Effekt. Unbekannte Modelle starten mit einer Zone im Ganzgeräte-Modus. Segmentzahlen müssen überprüft werden.

- Freie H606A-Innen-/Außen- oder Teilflächensteuerung durch die lokale Engine ist noch nicht geklärt. Die beeindruckenden Flächeneffekte stammen aus Govees internen Modi.
- Die abgefragten nativen Musikfähigkeiten bieten keine getrennten Regler für Geschwindigkeit, Nachleuchten oder ein Mindestlicht unter der Musikreaktion.
- Govee-Gerätemusik und Ambilight lassen sich auf verschiedene Leuchten verteilen, nicht auf derselben Leuchte überlagern.
- Cloud-Befehle erfolgen nacheinander; ein gemeinsamer Start ist keine taktsynchrone Animation.
- Stoppen stellt grundlegende Ein-/Aus-, Farb-, Farbtemperatur- und Helligkeitswerte wieder her. Eine zuvor laufende Govee-Animation lässt sich aus diesen Werten nicht rekonstruieren.
- Cloud-Bestätigung und erfolgreich gesendete UDP-Pakete beweisen keine sichtbare Lichtwirkung. Hardwaretests brauchen Sichtkontrolle.

## Datenschutz und lokale Dateien

Bildschirmframes und Mac-Audio werden für die Lichtberechnung lokal verarbeitet. Die App speichert keine Aufnahmen und lädt sie nicht hoch. Die optionale Govee-Anbindung sendet Gerätekennungen und Steuerbefehle an die offizielle Govee-API.

`~/Library/Application Support/GoveeStudio/` enthält Geräteadressen, Layouts, Profile, Szenenkataloge, Raum-Auswahl und Wiederherstellungsdaten. Diese Dateien sind privat und gehören **nicht** ins Repository. Der API-Key liegt separat im macOS-Schlüsselbund, nicht in JSON, Quellcode oder App-Bundle.

Builds und Diagnosen unter `.build/`, `dist/` und `.local/` sind ebenfalls ausgeschlossen. Vor einem Commit kann `python3 scripts/check-publication.py` die vorgemerkten Dateien prüfen.

## Wenn nichts leuchtet

- LAN-Steuerung, macOS-Netzwerkfreigabe und Erreichbarkeit prüfen; Gastnetz/Client-Isolation kann Geräte trennen.
- Andere Lichtcontroller schließen. Die lokale App verwendet UDP-Port 4002 für Antworten.
- Erst Ganzgeräte-Farben, danach Segmentstreaming testen. Nicht jedes LAN-fähige Modell unterstützt denselben Streamingmodus.
- Bei ausstehender Wiederherstellung Geräte wieder erreichbar machen und die Wiederherstellung abschließen. Die Sicherung nicht vorschnell löschen.
- Bei Cloud-Fehlern Key und Internet prüfen; bei Rate-Limits später erneut versuchen.

Weitere technische Hinweise: [Architektur und Tests](docs/VERIFICATION.md), [Mitwirken](CONTRIBUTING.md), [Datenschutz bei Fehlerberichten](SECURITY.md).

## Schnittstellen und Referenzen

- [Apple ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)
- [Govee LAN API](https://app-h5.govee.com/user-manual/wlan-guide)
- [Govee Developer API](https://developer.govee.com/)
- [LedFx Govee-Implementierung](https://github.com/LedFx/LedFx/blob/main/ledfx/devices/govee.py)
- [GoveeDreamView](https://github.com/LeoSko/GoveeDreamView)

Es gibt noch keine Projektlizenz. Eine öffentliche Veröffentlichung und Lizenzwahl stehen aus.
