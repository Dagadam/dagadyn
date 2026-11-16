# DagaDyn

[English](README.md) · **Italiano** · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Português](README.pt.md) · [Nederlands](README.nl.md) · [Svenska](README.sv.md) · [Polski](README.pl.md) · [Čeština](README.cs.md) · [Русский](README.ru.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [中文](README.zh.md)

Un'estensione per SketchUp che rende dinamici gli oggetti. Ogni proprietà di
un gruppo, di un componente o di un piano di sezione passa da uno stato
all'altro nel tempo che scegli, lungo una curva che disegni tu, e la vedi
succedere nella scena. Porte che si aprono, ascensori che salgono, lampade
che si accendono, sezioni che attraversano un edificio.

⬇ **Scarica**: [ultima versione](https://github.com/Dagadam/dagadyn/releases/latest) (tutte le versioni: [Releases](https://github.com/Dagadam/dagadyn/releases))

## Cosa fa

- **Proprietà**: spostamento (da dov'è l'oggetto), posizione, rotazione,
  dimensioni (larghezza, profondità, altezza), scala, colore, opacità,
  visibilità e tag. I piani di sezione si spostano e si accendono e spengono.
- **Stati e curve**: ogni proprietà ha uno stato iniziale, uno finale e una
  durata; altri stati fanno una sequenza. Ogni transizione segue una curva:
  lineare, accelera, rallenta, oltre e ritorno, rimbalzo, elastica, a
  gradini, oppure una tua, disegnata nell'editor delle curve trascinandone i
  pallini.
- **Timeline**: Play, Pausa, Stop e una barra per vedere qualsiasi istante.
  Una volta, in ciclo o avanti e indietro, alla velocità che vuoi.
- **Partenze**: un oggetto parte con la timeline, dopo che un altro ha finito
  (più un'attesa), oppure **quando lo si aziona**: un clic con lo strumento
  *Aziona*. Può ripartire ogni volta da capo, o andare avanti e la volta dopo
  indietro (porte, cassetti).
- **Catene che seguono**: gli oggetti in catena dietro uno che va avanti e
  indietro ne seguono la direzione, all'andata e al ritorno, ognuno quando il
  precedente ha finito (una leva, poi il ponte levatoio).
- **Il progetto non cambia**: le animazioni muovono gli oggetti senza toccare
  il modello. *Stop* rimette tutto a posto e il file salva sempre lo stato di
  riposo; *Tieni* lascia gli oggetti come sono adesso (Ctrl+Z lo annulla).
- **Dentro gli oggetti**: le animazioni si salvano nel file `.skp` e si
  copiano con l'oggetto. Con più oggetti selezionati una modifica vale per
  tutti, adattata a posizione e dimensioni di ciascuno.
- **Traiettorie nella vista**: il percorso degli oggetti che si muovono, con
  un punto per ogni stato (SketchUp 2023 e successivi).
- **Anteprima mentre modifichi**: cambiando il valore di uno stato l'oggetto
  si mostra in quello stato.
- **Da sola o con [DagaWASD](https://github.com/Dagadam/dagawasd)**: DagaDyn non ha
  bisogno d'altro. Con DagaWASD 1.3.0 o successiva installata, gli oggetti si
  muovono anche mentre cammini, esplori, riproduci i percorsi ed esporti i
  video (fotogramma per fotogramma, al tempo del video). Le piattaforme in
  movimento ti portano con sé e il tasto Aziona fa partire gli oggetti che
  partono quando li si aziona.
- Pannello in 36 lingue. Con DagaWASD installata ne segue lingua e aspetto.
- **Accessibilità**: vedi [ACCESSIBILITY.md](.github/ACCESSIBILITY.md).

Requisiti: SketchUp 2023 o successivo. Sviluppata e provata su Windows; su
Mac non è ancora stata provata.

## Come si usa

1. *Estensioni › DagaDyn › Pannello animazioni…* (o la barra degli
   strumenti).
2. Seleziona un gruppo, un componente o un piano di sezione. In
   *Animazione › Oggetto* scegli una proprietà da animare e premi
   *Aggiungi*.
3. Scrivi lo stato iniziale e quello finale (*⌖ attuale* prende il valore che
   l'oggetto ha adesso), la durata, e scegli una curva. Un clic sulla piccola
   curva per disegnarne una tua.
4. Premi **▶** (o Spazio nel pannello). **⏹** rimette tutto a posto.

Per gli oggetti che partono «quando li si aziona», prendi lo strumento
*Aziona* (barra o menu) e fai clic sull'oggetto nel modello; Esc esce dallo
strumento.
Sotto il mouse l'oggetto che partirà ha un riquadro colorato e il suo nome. Se
nessun oggetto parte con la timeline, il tasto **▶** diventa **☝**, lo
strumento *Aziona*.

## Installazione

Scarica **`dagadyn-<versione>.rbz`** dall'[ultima
versione](https://github.com/Dagadam/dagadyn/releases/latest) (sotto
*Assets*) e installalo da *Estensioni › Gestore estensioni › Installa
estensione*.

Le impostazioni stanno in `%APPDATA%\DagaDyn\settings.json`: un
aggiornamento non le cancella. Le animazioni stanno nei modelli, non
nell'estensione.

## Sviluppo

Il codice, i commenti e il changelog sono in italiano; com'è fatta
l'estensione dentro è in [SVILUPPO.md](SVILUPPO.md).

- `installa.bat` copia il sorgente nella cartella Plugins di ogni SketchUp
  che trova.
- `tools\run_tests.bat` esegue le prove (Ruby con una SketchUp simulata; la
  prova delle curve vuole anche Node.js).
- `ruby tools\test_live.rb` prova nel SketchUp vero, attraverso il ponte di
  DagaWASD (vuole aperto un modello nuovo, *File › Nuovo*, e ne lascia uno
  nuovo).
- `ruby tools\crea_rbz.rb` fa il pacchetto in `dist\`.
- Il numero di versione sta solo in `dagadyn.rb` (`VERSION`); ogni versione
  ha la sua sezione in `CHANGELOG.md`.
- Questo README è in più lingue (`README.md` in inglese, `README.it.md`,
  `.es`, `.fr`, `.de`, `.pt`, `.nl`, `.sv`, `.pl`, `.cs`, `.ru`, `.ja`,
  `.ko`, `.zh`): una modifica va in tutti.

I contributi sono benvenuti: vedi [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## Contatti

Errori e idee è meglio scriverli come
[issue](https://github.com/Dagadam/dagadyn/issues), dove altri li vedono e li
seguono; i problemi di sicurezza passano dalla [politica di
sicurezza](.github/SECURITY.md). Puoi anche scrivere a
[DagaWASD@icloud.com](mailto:DagaWASD@icloud.com).

Se DagaDyn ti è utile, puoi sostenerne lo sviluppo su
[Ko-fi](https://ko-fi.com/dagadam).

## Licenza

[MIT](LICENSE) © 2026 Dagadam. Puoi usare, modificare e ridistribuire il
codice liberamente, anche a scopo commerciale, purché ogni copia mantenga
l'avviso di copyright e il testo della licenza.
