# DagaDyn

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · **Nederlands** · [Svenska](README.sv.md) · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

Een SketchUp-extensie die objecten dynamisch maakt. Elke eigenschap van een
groep, een component of een snedevlak gaat van de ene toestand naar de
andere in de tijd die je kiest, langs een curve die je zelf tekent, en je
ziet het gebeuren in de scène. Deuren die opengaan, liften die stijgen,
lampen die aangaan, sneden die door een gebouw schuiven.

⬇ **Downloaden**: [nieuwste versie](https://github.com/Dagadam/dagadyn/releases/latest) (alle versies: [Releases](https://github.com/Dagadam/dagadyn/releases))

🛏 **Voorbeeld**: [een slaapkamer waarin alles beweegt](examples/README.md) (`examples/bedroom.skp`), met alle functies van DagaDyn.

## Wat het doet

- **Eigenschappen**: verplaatsen (vanaf waar het object staat), positie,
  rotatie, afmetingen (breedte, diepte, hoogte), schaal, kleur, dekking,
  zichtbaarheid en tag. Snedevlakken verschuiven en gaan aan en uit.
- **Toestanden en curves**: elke eigenschap heeft een begintoestand, een
  eindtoestand en een duur; meer toestanden vormen een reeks. Elke overgang
  volgt een curve: lineair, versnellen, afremmen, doorschieten, stuiteren,
  elastisch, treden, of je eigen curve, getekend in de curve-editor door de
  punten te slepen.
- **Tijdlijn**: Afspelen, Pauze, Stop en een balk om elk moment te bekijken.
  Eén keer, in een lus of heen en terug, op de snelheid die je wilt.
- **Snelheid van de tijd**: met de knop **⏱** naast de tijdlijn bepaalt een
  curve zoals bij de overgangen hoe de tijd in het hele model verloopt:
  steiler voor een timelapse, vlakker voor slow motion, en het afspelen kan
  korter of langer duren dan de tijdlijn.
- **Formules en koppelingen**: een overgang kan een formule volgen in plaats
  van de curve (bijvoorbeeld `v0 + (2 - v0) * u`) en via parameters andere
  sporen lezen, ook van andere objecten: hun waarde of de voortgang van een
  van hun overgangen. De plaat wordt breder terwijl de kubus groeit. Het paneel tekent de formule en kan die omzetten naar een puntcurve; gekoppelde objecten die samen gekopieerd worden, blijven aan elkaar gekoppeld. → [`formulas.skp`](examples/README.md#formulas-objects-that-read-each-other)
- **Starten**: een object start met de tijdlijn, nadat een ander klaar is
  (plus een wachttijd), of **bij bedienen**: een klik met het gereedschap
  *Bedienen*. Het kan elke keer opnieuw beginnen, of vooruit gaan en de
  volgende keer terug (deuren, laden).
- **Ketens die volgen**: objecten in een keten achter een object dat heen en
  terug gaat volgen zijn richting, heen en terug, elk zodra het vorige klaar
  is (een hendel, dan de ophaalbrug).
- **Het project verandert niet**: animaties bewegen de objecten zonder het
  model aan te raken. *Stop* zet alles terug en het bestand bewaart altijd
  de rusttoestand; *Houden* laat de objecten zoals ze nu zijn (Ctrl+Z maakt
  het ongedaan).
- **In de objecten**: animaties worden in het `.skp`-bestand opgeslagen en
  met het object gekopieerd. Met meerdere objecten geselecteerd geldt een
  wijziging voor allemaal, aangepast aan de positie en afmetingen van elk.
- **Banen in de weergave**: de route van de objecten die bewegen, met een
  punt voor elke toestand (SketchUp 2023 en later).
- **Voorbeeld tijdens bewerken**: als je de waarde van een toestand
  verandert, toont het object zich in die toestand.
- **Alleen of met [DagaWASD](https://github.com/Dagadam/dagawasd)**: DagaDyn heeft
  verder niets nodig. Met DagaWASD 1.3.0 of nieuwer ook geïnstalleerd, bewegen
  objecten ook terwijl je loopt, verkent, paden afspeelt en video's exporteert
  (beeld voor beeld, op de tijd van de video). Bewegende platforms nemen je
  mee en de Bedienen-toets start de objecten die bij bedienen starten.
- Paneel in 36 talen. Met DagaWASD geïnstalleerd volgt het de taal en het
  uiterlijk daarvan.
- **Toegankelijkheid**: zie [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Vereisten: SketchUp 2023 of nieuwer. Ontwikkeld en getest op Windows; op een
Mac nog niet getest.

## Gebruik

1. *Extensies › DagaDyn › Animatiepaneel…* (of de werkbalk).
2. Selecteer een groep, een component of een snedevlak. Kies in
   *Animatie › Object* een eigenschap om te animeren en druk op
   *Toevoegen*.
3. Vul de begin- en de eindtoestand in (*⌖ huidig* neemt de waarde die het
   object nu heeft), de duur, en kies een curve. Klik op het kleine curvetje
   om je eigen curve te tekenen.
4. Druk op **▶** (of Spatie in het paneel). **⏹** zet alles terug.

Voor objecten die «bij bedienen» starten: neem het gereedschap *Bedienen*
(werkbalk of menu) en klik op het object in het model; Esc verlaat het
gereedschap.
Onder de muis krijgt het object dat zal starten een kader en zijn naam.
Start geen enkel object met de tijdlijn, dan wordt de knop **▶** een **☝**,
het gereedschap *Bedienen*.

## Installatie

Download **`dagadyn-<versie>.rbz`** uit de [nieuwste
versie](https://github.com/Dagadam/dagadyn/releases/latest) (onder *Assets*)
en installeer het via *Extensies › Extension Manager › Extensie
installeren*.

De instellingen staan in `%APPDATA%\DagaDyn\settings.json`: een update wist
ze niet. De animaties zitten in de modellen, niet in de extensie.

## Ontwikkeling

De code, het commentaar en de changelog zijn in het Italiaans; hoe de
extensie van binnen in elkaar zit, staat in [SVILUPPO.md](SVILUPPO.md).

- `installa.bat` kopieert de broncode naar de Plugins-map van elke SketchUp
  die het vindt.
- `tools\run_tests.bat` draait de tests (Ruby met een gesimuleerde SketchUp;
  de curvetest heeft ook Node.js nodig).
- `ruby tools\test_live.rb` test in de echte SketchUp, via de brug van
  DagaWASD (wil een nieuw model open, *Bestand › Nieuw*, en laat een nieuw
  model achter).
- `ruby tools\crea_rbz.rb` maakt het pakket in `dist\`.
- Het versienummer staat alleen in `dagadyn.rb` (`VERSION`); elke versie
  heeft een eigen sectie in `CHANGELOG.md`.
- Deze README bestaat in meerdere talen (`README.md` in het Engels,
  `README.it.md`, `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`,
  `.ru`, `.ja`, `.ko`, `.zh`): een wijziging gaat in allemaal.

Bijdragen zijn welkom: zie [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Contact

Bugs en ideeën liefst als
[issue](https://github.com/Dagadam/dagadyn/issues), waar anderen ze kunnen
zien en volgen; beveiligingsproblemen gaan via het
[beveiligingsbeleid](.github/SECURITY.md). Je kunt ook schrijven naar
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com).

Heb je iets aan DagaDyn, dan kun je de ontwikkeling steunen op
[Ko-fi](https://ko-fi.com/dagadam).

## Licentie

[MIT](LICENSE) © 2026 Dagadam. Je mag de code vrij gebruiken, aanpassen en
verspreiden, ook commercieel, zolang elke kopie de copyrightvermelding en de
licentietekst behoudt.
