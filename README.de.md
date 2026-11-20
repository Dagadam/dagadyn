# DagaDyn

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Français](README.fr.md) · **Deutsch** · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

Eine SketchUp-Erweiterung, die Objekte dynamisch macht. Jede Eigenschaft
einer Gruppe, einer Komponente oder einer Schnittebene geht in der Zeit, die
du wählst, entlang einer Kurve, die du zeichnest, von einem Zustand in einen
anderen über, und du siehst es in der Szene geschehen. Türen, die aufgehen,
Aufzüge, die hochfahren, Lampen, die angehen, Schnitte, die durch ein
Gebäude wandern.

⬇ **Download**: [neueste Version](https://github.com/Dagadam/dagadyn/releases/latest) (alle Versionen: [Releases](https://github.com/Dagadam/dagadyn/releases))

🛏 **Beispiel**: [ein Kinderzimmer, in dem sich alles bewegt](examples/README.md) (`examples/bedroom.skp`), mit allen Funktionen von DagaDyn.

## Was sie kann

- **Eigenschaften**: Verschiebung (von dort, wo das Objekt ist), Position,
  Drehung, Abmessungen (Breite, Tiefe, Höhe), Maßstab, Farbe, Deckkraft,
  Sichtbarkeit und Tag. Schnittebenen verschieben sich und schalten sich ein
  und aus.
- **Zustände und Kurven**: Jede Eigenschaft hat einen Anfangszustand, einen
  Endzustand und eine Dauer; weitere Zustände ergeben eine Folge. Jeder
  Übergang folgt einer Kurve: linear, beschleunigen, bremsen,
  Überschwingen, Abprallen, elastisch, Stufen, oder deine eigene, im
  Kurveneditor gezeichnet, indem du ihre Punkte ziehst.
- **Zeitleiste**: Abspielen, Pause, Stopp und ein Balken, um jeden
  Augenblick zu sehen. Einmal, in Schleife oder hin und zurück, in der
  Geschwindigkeit, die du willst.
- **Geschwindigkeit der Zeit**: Mit der Taste **⏱** neben der Zeitleiste
  bestimmt eine Kurve wie bei den Übergängen, wie die Zeit im ganzen Modell
  vergeht: steiler für einen Zeitraffer, flacher für eine Zeitlupe, und die
  Wiedergabe kann kürzer oder länger dauern als die Zeitleiste.
- **Starts**: Ein Objekt startet mit der Zeitleiste, nachdem ein anderes
  fertig ist (plus Wartezeit), oder **beim Benutzen**: ein Klick mit dem
  Werkzeug *Benutzen*. Es kann jedes Mal von vorn beginnen oder vorwärts
  laufen und beim nächsten Mal zurück (Türen, Schubladen).
- **Ketten, die folgen**: Objekte, die hinter einem vor- und zurücklaufenden
  Objekt verkettet sind, folgen seiner Richtung, hin und zurück, jedes, sobald
  das vorige fertig ist (ein Hebel, dann die Zugbrücke).
- **Das Projekt ändert sich nicht**: Animationen bewegen die Objekte, ohne
  das Modell anzurühren. *Stopp* stellt alles zurück, und die Datei speichert
  immer den Ruhezustand; *Behalten* lässt die Objekte, wie sie gerade sind
  (Strg+Z macht es rückgängig).
- **In den Objekten**: Animationen werden in der `.skp`-Datei gespeichert und
  mit dem Objekt kopiert. Bei mehreren ausgewählten Objekten gilt eine
  Änderung für alle, angepasst an Position und Abmessungen jedes einzelnen.
- **Bahnen in der Ansicht**: der Weg der Objekte, die sich bewegen, mit einem
  Punkt für jeden Zustand (SketchUp 2023 und neuer).
- **Vorschau beim Bearbeiten**: Wenn du den Wert eines Zustands änderst,
  zeigt sich das Objekt in diesem Zustand.
- **Allein oder mit [DagaWASD](https://github.com/Dagadam/dagawasd)**: DagaDyn braucht
  nichts weiter. Ist zusätzlich DagaWASD 1.3.0 oder neuer installiert,
  bewegen sich die Objekte auch, während du gehst, erkundest, Pfade abspielst
  und Videos exportierst (Bild für Bild, in der Zeit des Videos). Bewegliche
  Plattformen nehmen dich mit, und die Benutzen-Taste startet die Objekte, die
  beim Benutzen starten.
- Panel in 36 Sprachen. Ist DagaWASD installiert, folgt es dessen Sprache und
  Aussehen.
- **Barrierefreiheit**: siehe [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Voraussetzungen: SketchUp 2023 oder neuer. Unter Windows entwickelt und
getestet; auf dem Mac noch nicht getestet.

## Benutzung

1. *Erweiterungen › DagaDyn › Animations-Panel…* (oder die Symbolleiste).
2. Wähle eine Gruppe, eine Komponente oder eine Schnittebene aus. Wähle unter
   *Animation › Objekt* eine Eigenschaft zum Animieren und drücke
   *Hinzufügen*.
3. Trage den Anfangs- und den Endzustand ein (*⌖ aktuell* übernimmt den
   Wert, den das Objekt gerade hat), die Dauer, und wähle eine Kurve. Ein
   Klick auf die kleine Kurve, um deine eigene zu zeichnen.
4. Drücke **▶** (oder die Leertaste im Panel). **⏹** stellt alles zurück.

Für Objekte, die «beim Benutzen» starten, nimm das Werkzeug *Benutzen*
(Symbolleiste oder Menü) und klicke im Modell auf das Objekt; Esc beendet
das Werkzeug.
Unter der Maus wird das Objekt, das starten wird, umrahmt und mit seinem
Namen gezeigt. Startet kein Objekt mit der Zeitleiste, wird die Taste **▶**
zu **☝**, dem Werkzeug *Benutzen*.

## Installation

Lade **`dagadyn-<Version>.rbz`** aus der [neuesten
Version](https://github.com/Dagadam/dagadyn/releases/latest) herunter (unter
*Assets*) und installiere es über *Erweiterungen › Extension Manager ›
Erweiterung installieren*.

Die Einstellungen liegen in `%APPDATA%\DagaDyn\settings.json`: Ein Update
löscht sie nicht. Die Animationen liegen in den Modellen, nicht in der
Erweiterung.

## Entwicklung

Code, Kommentare und Änderungsprotokoll sind auf Italienisch; wie die
Erweiterung innen aufgebaut ist, steht in [SVILUPPO.md](SVILUPPO.md).

- `installa.bat` kopiert den Quellcode in den Plugins-Ordner jedes
  gefundenen SketchUp.
- `tools\run_tests.bat` führt die Tests aus (Ruby mit simuliertem SketchUp;
  der Kurventest braucht zusätzlich Node.js).
- `ruby tools\test_live.rb` testet im echten SketchUp über die Brücke von
  DagaWASD (braucht ein neues Modell, *Datei › Neu*, und hinterlässt ein
  neues).
- `ruby tools\crea_rbz.rb` erstellt das Paket in `dist\`.
- Die Versionsnummer steht nur in `dagadyn.rb` (`VERSION`); jede Version hat
  ihren Abschnitt in `CHANGELOG.md`.
- Dieses README gibt es in mehreren Sprachen (`README.md` auf Englisch,
  `README.it.md`, `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`,
  `.ru`, `.ja`, `.ko`, `.zh`): Eine Änderung kommt in alle.

Beiträge sind willkommen: siehe [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Kontakt

Fehler und Ideen am besten als
[Issue](https://github.com/Dagadam/dagadyn/issues), wo andere sie sehen und
verfolgen können; Sicherheitsprobleme laufen über die
[Sicherheitsrichtlinie](.github/SECURITY.md). Du kannst auch an
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com) schreiben.

Wenn dir DagaDyn nützt, kannst du die Entwicklung auf
[Ko-fi](https://ko-fi.com/dagadam) unterstützen.

## Lizenz

[MIT](LICENSE) © 2026 Dagadam. Du darfst den Code frei verwenden, ändern und
weitergeben, auch kommerziell, solange jede Kopie den Urheberrechtshinweis
und den Lizenztext enthält.
