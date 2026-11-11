# DagaDyn — note per lo sviluppo

Come è fatta l'estensione dentro: file, prove, regole del motore. Per chi la usa c'è il
[README](README.md); per chi vuole contribuire, [CONTRIBUTING](.github/CONTRIBUTING.md).

## Struttura

```
dagadyn.rb              loader (VERSION, register_extension): va nella cartella Plugins
dagadyn/main.rb         carica lib/ nell'ordine giusto
dagadyn/lib/
  config.rb             costanti, DEFAULT, proprietà animabili (PROPS)
  i18n.rb  settings.rb  win32.rb      come in DagaWASD (lingue, settings.json, registro, appunti)
  curves.rb             curve PCHIP con punti ad angolo, preset   ← stessa copia in panel.html
  color.rb              colori, miscela in OKLab
  tracks.rb             dati negli attributi dell'istanza (dizionario "DagaDyn", chiave "data")
  props.rb              valori di riposo, trasformazione animata, materiali temporanei
  player.rb             motore: sessione, tempo, partenze (catene, azionati), advance(now), view.animation
  api.rb                collegamento con DagaWASD: ext_begin/ext_tick/ext_end, carry, kinematic?, use
  paths.rb              traiettorie nella vista (Overlay) e strumento Aziona
  observers.rb          modello aperto, salvataggio, annulla, selezione
  panel.rb  ui.rb       pannello (HtmlDialog), menu e barra
dagadyn/panel.html      pannello: telaio di DagaWASD + timeline, tracce, editor delle curve
dagadyn/lang/           36 lingue (index.json come DagaWASD)
tools/test_curves.rb    le curve di Ruby e del pannello devono coincidere (serve node)
tools/test_engine.rb    valori delle tracce nel tempo, partenze, azionati, senza SketchUp
tools/test_link.rb      il motore in una SketchUp finta (tools/fake_sketchup.rb) e l'aggancio a DagaWASD
tools/crea_rbz.rb       pacchetto dist/dagadyn-<versione>.rbz (vuole la sezione nel CHANGELOG)
```

## Sviluppo

Due modi di avere in SketchUp la copia su cui si lavora:

- `installa.bat` copia `dagadyn.rb` e la cartella `dagadyn` nella cartella Plugins di ogni SketchUp
  trovata; dopo ogni modifica si rilancia e si riavvia SketchUp.
- Un loader di sviluppo, `Plugins/dagadyn_dev.rb`, che fa `require` di `dagadyn.rb` dalla cartella dei
  sorgenti: le modifiche si vedono riavviando SketchUp, o con `load '<sorgenti>/dagadyn/lib/<file>.rb'`
  dalla console Ruby (panel.html si ricarica chiudendo e riaprendo il pannello). Dove c'è questo
  loader, `installa.bat` non copia niente, per non registrare l'estensione due volte.

```
tools\run_tests.bat         tutte le prove: test_engine, test_link, test_curves (vuole node)
ruby tools/crea_rbz.rb      pacchetto in dist\
```

## DagaWASD

Il collegamento sta in DagaWASD, `lib/dyn_link.rb`, e chiama solo i metodi pubblici di `DagaDyn`
(`lib/api.rb`). Nessuna delle due estensioni ha bisogno dell'altra. DagaWASD batte il tempo: camminata e
esploratore in tempo reale, video al tempo del video (fotogramma k → k / fps). Mentre DagaWASD guida, il Play
di DagaDyn aspetta.

## Regole del motore

- La trasformazione non si accumula: a ogni fotogramma si ricalcola dal riposo
  (`Trasla · Rz · Ry · Rx · R0 · Scala attorno al pivot`).
- Le trasformazioni si cambiano con `move!`, che non lascia voci di annullamento. Colore e opacità passano
  da un materiale temporaneo per oggetto, in operazioni trasparenti accodate a una sola voce.
- Stop rimette tutto a riposo. Al salvataggio il modello torna a riposo e poi riprende, così nel file
  finisce sempre lo stato di progetto.
- Il motore non dipende da chi batte il tempo: `advance(now)` con `view.animation`, `ext_tick(secondi)`
  con DagaWASD.
- Colore, opacità, visibilità, tag e piani di sezione cambiano il modello: vanno in operazioni trasparenti
  accodate alla prima voce della sessione. Dopo un Ctrl+Z la sessione apre una voce nuova.
