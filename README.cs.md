# DagaDyn

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · [Polski](README.pl.md) · **Čeština** · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

Rozšíření pro SketchUp, které oživuje objekty. Každá vlastnost skupiny,
komponenty nebo roviny řezu přejde z jednoho stavu do druhého za čas, který
zvolíte, podle křivky, kterou si nakreslíte, a vy to vidíte ve scéně.
Dveře, které se otvírají, výtahy, které stoupají, lampy, které se
rozsvěcují, řezy, které procházejí budovou.

⬇ **Stáhnout**: [nejnovější verze](https://github.com/Dagadam/dagadyn/releases/latest) (všechny verze: [Releases](https://github.com/Dagadam/dagadyn/releases))

🛏 **Ukázka**: [ložnice, kde se všechno hýbe](examples/README.md) (`examples/bedroom.skp`), se všemi funkcemi DagaDyn.

## Co umí

- **Vlastnosti**: posun (odkud objekt stojí), poloha, otočení, rozměry
  (šířka, hloubka, výška), měřítko, barva, krytí, viditelnost a štítek.
  Roviny řezu se posouvají a zapínají a vypínají.
- **Stavy a křivky**: každá vlastnost má počáteční stav, koncový stav a
  délku; další stavy tvoří sekvenci. Každý přechod sleduje křivku: lineární,
  zrychlení, zpomalení, přestřelení, odraz, pružnou, schody, nebo vaši
  vlastní, nakreslenou v editoru křivek tažením bodů.
- **Časová osa**: Přehrát, Pauza, Stop a lišta pro zobrazení libovolného
  okamžiku. Jednou, ve smyčce nebo tam a zpět, rychlostí, jakou chcete.
- **Rychlost času**: tlačítko **⏱** vedle časové osy otevře křivku jako u
  přechodů, která určuje, jak plyne čas v celém modelu: strmější pro
  časosběr, plošší pro zpomalení, a přehrávání může trvat kratší nebo delší
  dobu než časová osa.
- **Spuštění**: objekt začne s časovou osou, po skončení jiného (plus
  čekání), nebo **po použití**: kliknutím nástrojem *Použít*. Může pokaždé
  začít od začátku, nebo jít dopředu a příště zpět (dveře, zásuvky).
- **Řetězy, které následují**: objekty v řetězu za objektem, který jde
  dopředu a zpět, sledují jeho směr, tam i zpátky, každý až skončí předchozí
  (páka, potom padací most).
- **Projekt se nemění**: animace pohybují objekty, aniž by sahaly na model.
  *Stop* vše vrátí a soubor vždy ukládá klidový stav; *Ponechat* nechá
  objekty tak, jak jsou teď (Ctrl+Z to vrátí).
- **Uvnitř objektů**: animace se ukládají do souboru `.skp` a kopírují se s
  objektem. Při výběru více objektů platí změna pro všechny, přizpůsobená
  poloze a rozměrům každého z nich.
- **Trajektorie v pohledu**: dráha pohybujících se objektů, s bodem pro
  každý stav (SketchUp 2023 a novější).
- **Náhled při úpravách**: při změně hodnoty stavu se objekt ukáže v tomto
  stavu.
- **Samostatně nebo s [DagaWASD](https://github.com/Dagadam/dagawasd)**: DagaDyn nic
  dalšího nepotřebuje. S nainstalovaným DagaWASD 1.3.0 nebo novějším se
  objekty pohybují i při chůzi, průzkumu, přehrávání tras a exportu videí
  (snímek po snímku, v čase videa). Pohyblivé plošiny vás vezou a klávesa
  Použít spouští objekty, které začínají po použití.
- Panel ve 36 jazycích. S nainstalovaným DagaWASD přebírá jeho jazyk a vzhled.
- **Přístupnost**: viz [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Požadavky: SketchUp 2023 nebo novější. Vyvíjeno a testováno ve Windows; na
Macu zatím netestováno.

## Jak se používá

1. *Rozšíření › DagaDyn › Panel animací…* (nebo panel nástrojů).
2. Vyberte skupinu, komponentu nebo rovinu řezu. V *Animace › Objekt*
   zvolte vlastnost k animaci a stiskněte *Přidat*.
3. Zadejte počáteční a koncový stav (*⌖ aktuální* vezme hodnotu, kterou
   objekt má teď), délku a zvolte křivku. Kliknutím na malou křivku si
   nakreslíte vlastní.
4. Stiskněte **▶** (nebo mezerník v panelu). **⏹** vše vrátí.

U objektů, které začínají „po použití“, vezměte nástroj *Použít* (panel
nástrojů nebo nabídka) a klikněte na objekt v modelu; Esc nástroj ukončí.
Pod myší má objekt, který se spustí, rámeček a své jméno. Pokud s časovou
osou nezačíná žádný objekt, tlačítko **▶** se změní na **☝**, nástroj
*Použít*.

## Instalace

Stáhněte **`dagadyn-<verze>.rbz`** z [nejnovější
verze](https://github.com/Dagadam/dagadyn/releases/latest) (v části
*Assets*) a nainstalujte jej přes *Rozšíření › Extension Manager ›
Instalovat rozšíření*.

Nastavení se ukládá do `%APPDATA%\DagaDyn\settings.json`: aktualizace ho
nesmaže. Animace jsou v modelech, ne v rozšíření.

## Vývoj

Kód, komentáře a seznam změn jsou v italštině; jak je rozšíření postavené
uvnitř, popisuje [SVILUPPO.md](SVILUPPO.md).

- `installa.bat` zkopíruje zdrojové soubory do složky Plugins každého
  nalezeného SketchUpu.
- `tools\run_tests.bat` spustí testy (Ruby se simulovaným SketchUpem; test
  křivek potřebuje i Node.js).
- `ruby tools\test_live.rb` testuje ve skutečném SketchUpu přes most
  DagaWASD (potřebuje otevřený nový model, *Soubor › Nový*, a nový i
  nechá).
- `ruby tools\crea_rbz.rb` vytvoří balíček v `dist\`.
- Číslo verze je jen v `dagadyn.rb` (`VERSION`); každá verze má svůj oddíl v
  `CHANGELOG.md`.
- Toto README je ve více jazycích (`README.md` anglicky, `README.it.md`,
  `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`, `.ru`, `.ja`,
  `.ko`, `.zh`): změna patří do všech.

Příspěvky jsou vítány: viz [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Kontakt

Chyby a nápady nejlépe jako
[issue](https://github.com/Dagadam/dagadyn/issues), kde je ostatní uvidí a
mohou je sledovat; bezpečnostní problémy jdou přes [bezpečnostní
zásady](.github/SECURITY.md). Můžete také napsat na
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com).

Pokud je vám DagaDyn užitečný, můžete jeho vývoj podpořit na
[Ko-fi](https://ko-fi.com/dagadam).

## Licence

[MIT](LICENSE) © 2026 Dagadam. Kód můžete volně používat, upravovat a šířit,
i komerčně, pokud každá kopie zachová upozornění na autorská práva a text
licence.
