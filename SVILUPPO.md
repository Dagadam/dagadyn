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
  formula.rb            transizioni a formula: interprete (niente eval), parametri che leggono altre tracce,
                        controllo per il pannello (errori, collegamenti circolari)
  color.rb              colori, miscela in OKLab
  tracks.rb             dati negli attributi dell'istanza (dizionario "DagaDyn", chiave "data");
                        velocità del tempo in quelli del modello (chiave "time")
  props.rb              valori di riposo, trasformazione animata, materiali temporanei
  player.rb             motore: sessione, tempo, partenze (catene, azionati), advance(now), view.animation
  api.rb                collegamento con DagaWASD: ext_begin/ext_tick/ext_end, carry, kinematic?, use
  paths.rb              traiettorie nella vista (Overlay) e strumento Aziona
  observers.rb          modello aperto, salvataggio, annulla, selezione
  panel.rb  ui.rb       pannello (HtmlDialog), menu e barra
dagadyn/panel.html      pannello: telaio di DagaWASD + timeline, tracce, editor delle curve
dagadyn/lang/           36 lingue (index.json come DagaWASD)
tools/test_curves.rb    le curve di Ruby e del pannello devono coincidere (serve node)
tools/test_panel.rb     funzioni del pannello in node con un DOM finto (editor delle curve e selezione, timeline,
                        transizioni a formula)
tools/test_engine.rb    valori delle tracce nel tempo, partenze, azionati, senza SketchUp
tools/test_link.rb      il motore in una SketchUp finta (tools/fake_sketchup.rb) e l'aggancio a DagaWASD
tools/test_live.rb      nel SketchUp vero, dal ponte di DagaWASD: tempi, salvataggio, Ctrl+Z, File › Nuovo
                        (solo con un modello nuovo aperto, mai salvato: al più la figura del
                        modello di partenza; ne lascia uno nuovo)
tools/crea_rbz.rb       pacchetto dist/dagadyn-<versione>.rbz (vuole la sezione nel CHANGELOG)
tools/esempio_cameretta.rb  costruisce in SketchUp la cameretta di examples/bedroom.skp (tutte le funzioni)
tools/esempio_formule.rb    costruisce examples/formulas.skp (transizioni a formula, tre oggetti in serie)
tools/crea_esempio.rb   dal ponte di DagaWASD, in un modello nuovo: costruisce un esempio e lo salva (formato 2021);
                        senza argomento la cameretta, con «formulas» le formule
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
tools\run_tests.bat         tutte le prove: test_engine, test_link, test_curves, test_panel (vuole node)
ruby tools/crea_rbz.rb      pacchetto in dist\
```

## DagaWASD

Il collegamento sta in DagaWASD, `lib/dyn_link.rb`, e chiama solo i metodi pubblici di `DagaDyn`
(`lib/api.rb`). Nessuna delle due estensioni ha bisogno dell'altra. DagaWASD batte il tempo: camminata e
esploratore in tempo reale, video al tempo del video (fotogramma k → k / fps). Mentre DagaWASD guida, il Play
di DagaDyn aspetta.

Lingua e aspetto del pannello: con DagaWASD caricata sono i suoi (stesse chiavi `language` e `ui_*`, tranne
`ui_logo`; `SHARED_UI` e `panel_cfg` in `lib/settings.rb`). In Sistema spariscono Lingua e Aspetto, i valori
propri restano in `settings.json` per quando DagaDyn è da sola, e se cambiano in DagaWASD il pannello aperto
li segue entro un secondo. Menu e barra nascono prima che DagaWASD sia caricata: per loro si legge il suo
`settings.json`, se `dagawasd.rb` è nella cartella Plugins.

## Regole del motore

- La trasformazione non si accumula: a ogni fotogramma si ricalcola dal riposo
  (`Trasla · Rz · Ry · Rx · R0 · Scala attorno al pivot`).
- Le trasformazioni si cambiano con `move!`, che non lascia voci di annullamento. Colore e opacità passano
  da un materiale temporaneo per oggetto, in operazioni trasparenti accodate a una sola voce.
- `move!` però non aggiorna né le ombre della vista né l'ingombro che SketchUp usa per i piani di taglio:
  restano quelli della posa di riposo. Per questo, con le ombre accese, a ogni fotogramma la stessa
  trasformazione si rimette anche dentro l'operazione della sessione (`shadow_sync`, non nel video di
  DagaWASD, dove `write_image` ricalcola da sé), e un Overlay senza disegno (`ExtentsOverlay`) dà a
  SketchUp l'ingombro attuale con `getExtents`. Senza, le nuvole di DagaWASD sparivano e le ombre
  restavano quelle dei blocchi a riposo.
- Stop rimette tutto a riposo. Al salvataggio il modello torna a riposo e poi riprende, così nel file
  finisce sempre lo stato di progetto.
- Il motore non dipende da chi batte il tempo: `advance(now)` con `view.animation`, `ext_tick(secondi)`
  con DagaWASD.
- Due tempi: l'orologio della riproduzione `c` (quello che battono Play e DagaWASD) e il tempo della
  timeline `t = warp(c)`, uguali finché il modello non ha una velocità del tempo. Quella è una curva come
  le transizioni, negli attributi del modello (chiave `time`, JSON `{v, preset, curve, dur}`; `read_time` e
  `write_time` in `lib/tracks.rb`): in x la riproduzione da 0 a P (`dur`, o la durata della timeline T), in
  y la timeline da 0 a T. Fine e «Ripeti» si decidono su `c` (`play_len`), perché una curva che va oltre
  la meta supera T prima della fine; oggetti e barra usano `t`. Spostare la barra cerca il punto della
  curva che dà quell'istante, il più vicino a dov'era (`unwarp`); se cambiano la curva o la durata della
  timeline, `warp_keep` lascia la timeline dov'è e cambia solo da lì in avanti.
- Transizioni a formula (`lib/formula.rb`): accanto alla curva, nello stato di arrivo, `fx = {on, expr,
  params}`. Un interprete proprio (mai `eval`: le formule arrivano dentro file .skp di altri) traduce la
  formula in un albero, una volta (`fx_cached`). `track_value(tr, t, ctx)`: `ctx` dice da dove leggere gli
  altri oggetti (`fx_world_session` nel Play, `fx_world_model` per le traiettorie) e a che istante della
  timeline corrisponde il tempo locale (`off`). I parametri si leggono nello stesso istante della timeline;
  il valore da cui parte una transizione dopo una formula è quello della formula alla sua fine, con i
  parametri di quel momento (`seg_from`). Ogni fotogramma ricorda i valori già letti (`memo`) e un giro
  chiuso (A legge B che legge A nello stesso istante) dà nil invece di un ciclo infinito: l'oggetto resta al
  valore di partenza, e `fx_check` lo segnala nel pannello prima ancora di salvare. `fx_check` restituisce
  anche il grafico di ogni formula (`fx_samples`, al primo giro, con `fx_world_model`); `fx_bake` («Converti in
  curva») taglia la formula a ogni inversione di marcia e per ogni tratto sceglie i punti della curva con
  Douglas-Peucker, poi aggiunge quelli dove la curva PCHIP del motore sbaglia di più.
- Copie: ogni oggetto porta il proprio persistent_id (`SELF_KEY` nel dizionario, scritto da `write_data`). Dopo ogni
  operazione `copies_adopt` (lib/tracks.rb) guarda gli oggetti animati nuovi rispetto a `copies_known`: in una copia
  il segno non è il suo, e i collegamenti (`start.after`, parametri delle formule) verso oggetti copiati nella stessa
  operazione passano alle copie. Più copie dello stesso oggetto: quella spostata come la copia che legge. Dati senza
  segno: l'originale è l'oggetto di prima con gli stessi dati. Le modifiche vanno in un'operazione trasparente.
- Una sessione non prende oggetti non validi o fuori dal modello (`session_start`): un'operazione nostra chiude
  quella ancora aperta di uno script, e ciò che lo script aveva cancellato sparisce a metà elenco.
- Colore, opacità, visibilità, tag e piani di sezione cambiano il modello: vanno in operazioni trasparenti
  accodate alla prima voce della sessione. Dopo un Ctrl+Z la sessione apre una voce nuova.
