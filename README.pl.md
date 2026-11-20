# DagaDyn

[English](README.md) · [Italiano](README.it.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · **Polski** · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

Rozszerzenie do SketchUp, które ożywia obiekty. Każda właściwość grupy,
komponentu lub płaszczyzny przekroju przechodzi z jednego stanu w drugi w
czasie, który wybierzesz, wzdłuż krzywej, którą sam narysujesz, a ty widzisz
to w scenie. Drzwi, które się otwierają, windy, które jadą w górę, lampy,
które się zapalają, przekroje, które przesuwają się przez budynek.

⬇ **Pobierz**: [najnowsza wersja](https://github.com/Dagadam/dagadyn/releases/latest) (wszystkie wersje: [Releases](https://github.com/Dagadam/dagadyn/releases))

🛏 **Przykład**: [sypialnia, w której wszystko się rusza](examples/README.md) (`examples/bedroom.skp`), ze wszystkimi funkcjami DagaDyn.

## Co robi

- **Właściwości**: przesunięcie (od miejsca, gdzie stoi obiekt), położenie,
  obrót, wymiary (szerokość, głębokość, wysokość), skala, kolor, krycie,
  widoczność i znacznik. Płaszczyzny przekroju przesuwają się oraz włączają
  i wyłączają.
- **Stany i krzywe**: każda właściwość ma stan początkowy, końcowy i czas
  trwania; kolejne stany tworzą sekwencję. Każde przejście biegnie wzdłuż
  krzywej: liniowej, przyspieszenia, zwolnienia, przestrzelenia, odbicia,
  sprężystej, schodkowej, albo twojej, narysowanej w edytorze krzywych przez
  przeciąganie punktów.
- **Oś czasu**: Odtwórz, Pauza, Stop i pasek do oglądania dowolnej chwili.
  Raz, w pętli albo tam i z powrotem, z wybraną prędkością.
- **Prędkość czasu**: przycisk **⏱** obok osi czasu otwiera krzywą jak przy
  przejściach, która decyduje, jak płynie czas w całym modelu: bardziej
  stroma dla timelapse, bardziej płaska dla zwolnionego tempa, a
  odtwarzanie może trwać krócej lub dłużej niż oś czasu.
- **Start**: obiekt rusza z osią czasu, po zakończeniu innego (plus
  oczekiwanie) albo **po użyciu**: kliknięcie narzędziem *Użyj*. Może za
  każdym razem zaczynać od początku albo iść do przodu, a następnym razem
  wracać (drzwi, szuflady).
- **Łańcuchy, które podążają**: obiekty w łańcuchu za obiektem, który idzie
  do przodu i wraca, podążają za jego kierunkiem, w obie strony, każdy gdy
  poprzedni skończy (dźwignia, potem most zwodzony).
- **Projekt się nie zmienia**: animacje poruszają obiektami, nie dotykając
  modelu. *Stop* przywraca wszystko, a plik zawsze zapisuje stan spoczynku;
  *Zachowaj* zostawia obiekty takie, jakie są teraz (Ctrl+Z cofa).
- **Wewnątrz obiektów**: animacje zapisują się w pliku `.skp` i kopiują
  razem z obiektem. Gdy zaznaczonych jest kilka obiektów, zmiana dotyczy
  wszystkich, dopasowana do położenia i wymiarów każdego.
- **Trajektorie w widoku**: droga poruszających się obiektów, z punktem dla
  każdego stanu (SketchUp 2023 i nowsze).
- **Podgląd podczas edycji**: po zmianie wartości stanu obiekt pokazuje się
  w tym stanie.
- **Samodzielnie lub z [DagaWASD](https://github.com/Dagadam/dagawasd)**: DagaDyn nie
  potrzebuje niczego więcej. Gdy zainstalowany jest też DagaWASD 1.3.0 lub
  nowszy, obiekty poruszają się też, gdy chodzisz, zwiedzasz, odtwarzasz
  trasy i eksportujesz filmy (klatka po klatce, w czasie filmu). Ruchome
  platformy cię przewożą, a klawisz Użyj uruchamia obiekty, które startują po
  użyciu.
- Panel w 36 językach. Gdy DagaWASD jest zainstalowany, panel przejmuje jego
  język i wygląd.
- **Dostępność**: zob. [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Wymagania: SketchUp 2023 lub nowszy. Rozwijane i testowane w Windows; na
Macu jeszcze nie testowane.

## Jak używać

1. *Rozszerzenia › DagaDyn › Panel animacji…* (albo pasek narzędzi).
2. Zaznacz grupę, komponent lub płaszczyznę przekroju. W *Animacja ›
   Obiekt* wybierz właściwość do animowania i naciśnij *Dodaj*.
3. Wpisz stan początkowy i końcowy (*⌖ bieżąca* bierze wartość, jaką obiekt
   ma teraz), czas trwania i wybierz krzywą. Kliknij małą krzywą, aby
   narysować własną.
4. Naciśnij **▶** (albo spację w panelu). **⏹** przywraca wszystko.

Dla obiektów, które startują „po użyciu”, weź narzędzie *Użyj* (pasek albo
menu) i kliknij obiekt w modelu; Esc kończy narzędzie.
Pod kursorem obiekt, który ruszy, ma ramkę i swoją nazwę. Jeśli żaden obiekt
nie startuje z osią czasu, przycisk **▶** zmienia się w **☝**, narzędzie
*Użyj*.

## Instalacja

Pobierz **`dagadyn-<wersja>.rbz`** z [najnowszej
wersji](https://github.com/Dagadam/dagadyn/releases/latest) (w *Assets*) i
zainstaluj w *Rozszerzenia › Extension Manager › Zainstaluj rozszerzenie*.

Ustawienia są w `%APPDATA%\DagaDyn\settings.json`: aktualizacja ich nie
kasuje. Animacje są w modelach, nie w rozszerzeniu.

## Rozwój

Kod, komentarze i dziennik zmian są po włosku; jak rozszerzenie jest
zbudowane w środku, opisuje [SVILUPPO.md](SVILUPPO.md).

- `installa.bat` kopiuje źródła do folderu Plugins każdego znalezionego
  SketchUp.
- `tools\run_tests.bat` uruchamia testy (Ruby z symulowanym SketchUp; test
  krzywych potrzebuje też Node.js).
- `ruby tools\test_live.rb` testuje w prawdziwym SketchUp przez most
  DagaWASD (wymaga otwartego nowego modelu, *Plik › Nowy*, i zostawia nowy).
- `ruby tools\crea_rbz.rb` tworzy pakiet w `dist\`.
- Numer wersji jest tylko w `dagadyn.rb` (`VERSION`); każda wersja ma swoją
  sekcję w `CHANGELOG.md`.
- To README jest w kilku językach (`README.md` po angielsku,
  `README.it.md`, `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`,
  `.ru`, `.ja`, `.ko`, `.zh`): zmiana trafia do wszystkich.

Wkład jest mile widziany: zob. [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Kontakt

Błędy i pomysły najlepiej jako
[issue](https://github.com/Dagadam/dagadyn/issues), gdzie inni mogą je
zobaczyć i śledzić; problemy bezpieczeństwa idą przez [politykę
bezpieczeństwa](.github/SECURITY.md). Możesz też napisać na
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com).

Jeśli DagaDyn ci się przydaje, możesz wesprzeć jego rozwój na
[Ko-fi](https://ko-fi.com/dagadam).

## Licencja

[MIT](LICENSE) © 2026 Dagadam. Możesz swobodnie używać, zmieniać i
rozpowszechniać kod, także komercyjnie, pod warunkiem że każda kopia
zachowuje informację o prawach autorskich i tekst licencji.
