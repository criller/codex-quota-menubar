# Codex Quota Menu Bar

Sehen Sie Ihr **verbleibendes wöchentliches Codex-Kontingent** direkt in der macOS-Menüleiste, ähnlich einer Akkuanzeige. Native App mit Swift und AppKit, ohne Bibliotheken von Drittanbietern.

[English](README.md) · [简体中文](README.zh-CN.md) · [Français](README.fr.md) · [Deutsch](README.de.md)

![Wöchentliches Codex-Kontingent mit geöffnetem Menü](docs/media/screenshot.png)

## Demonstration

https://github.com/user-attachments/assets/a06aa77e-f319-4634-bfe9-c256333c639c

Aufnahme der laufenden macOS-App: Menü öffnen, aktualisieren und Zeitpunkt der Zurücksetzung anzeigen. Der Hintergrund ist isoliert; die Werte gelten für den Aufnahmezeitpunkt.

[MP4-Aufnahme herunterladen](docs/media/demo.mp4)

Die Oberfläche der App ist derzeit auf Chinesisch verfügbar. Die Dokumentation gibt es auf Englisch, Chinesisch, Französisch und Deutsch. Dies ist ein unabhängiges Open-Source-Projekt.

## Herunterladen und installieren

1. Laden Sie `Codex-Quota-v1.0.0-macos-arm64.zip` von der [Release-Seite](https://github.com/criller/codex-quota-menubar/releases/latest) herunter.
2. Entpacken Sie das Archiv und verschieben Sie `Codex Quota.app` in den Ordner Programme oder in Ihren persönlichen Ordner `~/Applications`.
3. Öffnen Sie die App im Finder. Während des Ladens erscheint `Codex …`, danach der verbleibende Prozentsatz.

**Voraussetzungen:** ein Mac mit Apple Silicon (M1 oder neuer), macOS 14 oder neuer und eine lokale Codex-Installation mit angemeldetem ChatGPT-Konto. Das fertige Programmpaket wird nur für arm64 angeboten. Build und Abfrage des tatsächlichen Kontingents wurden unter macOS 27 auf Apple Silicon geprüft. Ältere macOS-Versionen wurden nicht einzeln getestet.

Die App ist ad hoc signiert. Sie besitzt weder eine Apple-Developer-ID-Signatur noch eine Notarisierung. macOS kann den ersten Start blockieren. Prüfen Sie die Downloadquelle und folgen Sie dann den Freigabehinweisen des Systems. Alternativ können Sie die App selbst kompilieren.

## Funktionen

- Verbleibendes Wochenkontingent direkt in der Menüleiste.
- Aktualisierung alle fünf Minuten, erneuter Versuch jede Minute nach einem Fehler und Aktualisierung nach dem Aufwachen.
- Manuelle Aktualisierung, Zeitpunkt der Zurücksetzung in Ihrer Zeitzone und Zeitpunkt der letzten Aktualisierung.
- Kennzeichnung alter Werte mit `!` nach einem Abfragefehler, zehn Minuten ohne erfolgreiche Aktualisierung oder Ablauf des Kontingentzeitraums.
- Anzeige von `Codex --`, wenn noch kein Kontingent gelesen werden konnte. Fehlende Daten werden niemals als 100 % verbleibendes Kontingent ausgegeben.
- Optionaler Start bei der Anmeldung, standardmäßig deaktiviert.

Der Prozentsatz beschreibt das wöchentliche Kontingent des Kontos, **keine Anzahl verbleibender Tokens**. Die App verändert das Kontingent nicht und löst keine Zurücksetzung aus.

## Funktionsweise und Daten

Die App startet kurzzeitig den lokalen Prozess `codex app-server --stdio`. Nach dem Austausch von `initialize` / `initialized` ruft sie ausschließlich `account/rateLimits/read` auf und beendet den Prozess.

Authentifizierung und Netzwerkanfragen übernimmt Ihre installierte Codex-Version. Die App verwendet die standardmäßige lokale Codex-Anmeldung. Sie startet keine Modellanfragen, liest keine Unterhaltungen und kopiert keine Zugangsdaten. Das Projekt betreibt keinen eigenen Server. Ein OpenAI-API-Schlüssel allein liefert kein ChatGPT-Abonnementkontingent.

Die App sucht zuerst nach dem mit ChatGPT/Codex gelieferten Codex-Programm, danach nach Installationen über Homebrew, `~/.local/bin` und nvm. Sie erkennt den Siebentageszeitraum an `windowDurationMins == 10080` in primary oder secondary. `rateLimitsByLimitId.codex` hat Vorrang; das ältere Feld `rateLimits` wird ebenfalls unterstützt. Der verbleibende Prozentsatz entspricht `100 - usedPercent`, abgerundet auf eine ganze Zahl.

Referenz: [OpenAI Codex App Server-Protokoll](https://learn.chatgpt.com/docs/app-server). Änderungen an Anmeldung, Installationspfaden oder Protokoll können eine Aktualisierung erforderlich machen.

## Aus dem Quellcode bauen

Installieren Sie die macOS Command Line Tools und eine Toolchain mit Unterstützung für Swift 5.9 oder neuer.

```bash
git clone https://github.com/criller/codex-quota-menubar.git
cd codex-quota-menubar
bash build.sh
```

Die fertige App liegt unter `dist/Codex Quota.app`. Das Skript führt die zentralen Regressionstests aus, erstellt die arm64-App und bringt eine Ad-hoc-Signatur an, die anschließend geprüft wird.

So prüfen Sie die Kontingentabfrage ohne Benutzeroberfläche:

```bash
"dist/Codex Quota.app/Contents/MacOS/CodexQuota" --check
```

Der Befehl verwendet denselben Client wie die Menüleiste und gibt nur den verbleibenden Prozentsatz und den Zeitpunkt der Zurücksetzung aus. Veröffentlichen Sie keine Anmeldedateien oder ungeprüften Codex-Protokolle in öffentlichen Issues.

So erstellen Sie ein Release-Archiv mit SHA-256-Prüfsumme:

```bash
bash package.sh
```

Prüfen Sie einen Download im Ordner mit der ZIP-Datei und `SHA256SUMS.txt`:

```bash
shasum -a 256 -c SHA256SUMS.txt
```

## Fehlerbehebung

- **Codex nicht gefunden:** installieren oder aktualisieren Sie Codex lokal. Ein mit `app-server` kompatibles Programm muss vorhanden sein.
- **Anmeldung erforderlich:** melden Sie sich in Codex mit Ihrem ChatGPT-Konto an und aktualisieren Sie die Anzeige.
- **`!` oder `Codex --`:** prüfen Sie im Menü die Fehlermeldung und den letzten Aktualisierungszeitpunkt, kontrollieren Sie die Verbindung und versuchen Sie es erneut.
- **Start bei der Anmeldung wartet auf Freigabe:** erlauben Sie die App in den macOS-Einstellungen für Anmeldeobjekte.

## Deinstallieren

Deaktivieren Sie den Start bei der Anmeldung im App-Menü, beenden Sie die App und löschen Sie `Codex Quota.app`.

## Lizenz

[MIT](LICENSE) © 2026 criller
