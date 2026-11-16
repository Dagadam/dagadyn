# DagaDyn

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · **Svenska** · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

Ett tillägg för SketchUp som gör objekt dynamiska. Varje egenskap hos en
grupp, en komponent eller ett snittplan går från ett tillstånd till ett
annat under den tid du väljer, längs en kurva du ritar själv, och du ser det
hända i scenen. Dörrar som öppnas, hissar som åker upp, lampor som tänds,
snitt som vandrar genom en byggnad.

⬇ **Ladda ned**: [senaste versionen](https://github.com/Dagadam/dagadyn/releases/latest) (alla versioner: [Releases](https://github.com/Dagadam/dagadyn/releases))

## Vad det gör

- **Egenskaper**: flytt (från där objektet står), position, rotation,
  storlek (bredd, djup, höjd), skala, färg, opacitet, synlighet och tagg.
  Snittplan flyttas och slås på och av.
- **Tillstånd och kurvor**: varje egenskap har ett starttillstånd, ett
  sluttillstånd och en varaktighet; fler tillstånd blir en sekvens. Varje
  övergång följer en kurva: linjär, accelerera, bromsa, överskjutning,
  studs, elastisk, steg, eller din egen, ritad i kurvredigeraren genom att
  dra i punkterna.
- **Tidslinje**: Spela, Paus, Stopp och ett reglage för att se varje
  ögonblick. En gång, i slinga eller fram och tillbaka, i den hastighet du
  vill.
- **Start**: ett objekt startar med tidslinjen, efter att ett annat är klart
  (plus en väntan), eller **när det används**: ett klick med verktyget
  *Använd*. Det kan börja om från början varje gång, eller gå framåt och
  nästa gång tillbaka (dörrar, lådor).
- **Kedjor som följer**: objekt i kedja efter ett som går fram och tillbaka
  följer dess riktning, åt båda hållen, vart och ett när det föregående är
  klart (en spak, sedan vindbryggan).
- **Projektet ändras inte**: animationerna flyttar objekten utan att röra
  modellen. *Stopp* återställer allt och filen sparar alltid viloläget;
  *Behåll* lämnar objekten som de är nu (Ctrl+Z ångrar).
- **Inne i objekten**: animationerna sparas i `.skp`-filen och kopieras med
  objektet. Med flera objekt markerade gäller en ändring alla, anpassad till
  varje objekts position och storlek.
- **Banor i vyn**: vägen för objekten som rör sig, med en punkt för varje
  tillstånd (SketchUp 2023 och senare).
- **Förhandsvisning vid redigering**: när du ändrar ett tillstånds värde
  visas objektet i det tillståndet.
- **Ensamt eller med [DagaWASD](https://github.com/Dagadam/dagawasd)**: DagaDyn behöver
  inget annat. Med DagaWASD 1.3.0 eller senare också installerat rör sig
  objekten också medan du går, utforskar, spelar upp banor och exporterar
  videor (bildruta för bildruta, i videons tid). Rörliga plattformar tar dig
  med, och Använd-tangenten startar objekten som startar när de används.
- Panel på 36 språk. Med DagaWASD installerat följer den dess språk och
  utseende.
- **Tillgänglighet**: se [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Krav: SketchUp 2023 eller senare. Utvecklat och testat på Windows; på Mac är
det ännu inte testat.

## Så använder du det

1. *Tillägg › DagaDyn › Animationspanel…* (eller verktygsfältet).
2. Markera en grupp, en komponent eller ett snittplan. Välj under
   *Animation › Objekt* en egenskap att animera och tryck på *Lägg till*.
3. Skriv starttillståndet och sluttillståndet (*⌖ aktuellt* tar värdet
   objektet har nu), varaktigheten, och välj en kurva. Klicka på den lilla
   kurvan för att rita din egen.
4. Tryck på **▶** (eller mellanslag i panelen). **⏹** återställer allt.

För objekt som startar «när de används»: ta verktyget *Använd* (verktygsfält
eller meny) och klicka på objektet i modellen; Esc lämnar verktyget.
Under musen får objektet som kommer att starta en ram och sitt namn. Om
inget objekt startar med tidslinjen blir knappen **▶** en **☝**, verktyget
*Använd*.

## Installation

Ladda ned **`dagadyn-<version>.rbz`** från den [senaste
versionen](https://github.com/Dagadam/dagadyn/releases/latest) (under
*Assets*) och installera den via *Tillägg › Extension Manager › Installera
tillägg*.

Inställningarna sparas i `%APPDATA%\DagaDyn\settings.json`: en uppdatering
raderar dem inte. Animationerna finns i modellerna, inte i tillägget.

## Utveckling

Koden, dess kommentarer och ändringsloggen är på italienska; hur tillägget
är byggt inuti står i [SVILUPPO.md](SVILUPPO.md).

- `installa.bat` kopierar källkoden till Plugins-mappen i varje SketchUp den
  hittar.
- `tools\run_tests.bat` kör testerna (Ruby med ett simulerat SketchUp;
  kurvtestet behöver också Node.js).
- `ruby tools\test_live.rb` testar i det riktiga SketchUp via DagaWASD:s
  brygga (kräver en tom, aldrig ändrad modell öppen och lämnar den tom).
- `ruby tools\crea_rbz.rb` skapar paketet i `dist\`.
- Versionsnumret finns bara i `dagadyn.rb` (`VERSION`); varje version har
  sitt avsnitt i `CHANGELOG.md`.
- Den här README-filen finns på flera språk (`README.md` på engelska,
  `README.it.md`, `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`,
  `.ru`, `.ja`, `.ko`, `.zh`): en ändring ska in i alla.

Bidrag är välkomna: se [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Kontakt

Buggar och idéer helst som
[issue](https://github.com/Dagadam/dagadyn/issues), där andra kan se och
följa dem; säkerhetsproblem går via
[säkerhetspolicyn](.github/SECURITY.md). Du kan också skriva till
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com).

Om DagaDyn är till nytta för dig kan du stödja utvecklingen på
[Ko-fi](https://ko-fi.com/dagadam).

## Licens

[MIT](LICENSE) © 2026 Dagadam. Du får använda, ändra och sprida koden fritt,
även kommersiellt, så länge varje kopia behåller upphovsrättsmeddelandet och
licenstexten.
