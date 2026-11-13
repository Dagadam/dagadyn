# Novità di DagaDyn

## [Prossima versione]

### Correzioni
- **Il quadrato rosso (Stop) della barra non faceva niente**: ora ferma l'animazione come Stop nel menu.
- **Ombre giuste durante il movimento**: prima restavano quelle della posizione di riposo (un oggetto abbassato
  lasciava a terra l'ombra lunga e faceva ombra sugli oggetti vicini).
- **Oggetti e cielo non vengono più tagliati** quando un oggetto animato esce dalla posizione di riposo (più alto,
  spostato): con DagaWASD le nuvole sparivano a ogni ciclo.

### Con DagaWASD
- **Lingua e aspetto del pannello sono quelli di DagaWASD**: in Sistema non compaiono Lingua e Aspetto, e se li
  cambi in DagaWASD il pannello di DagaDyn li segue subito. Il logo resta quello di DagaDyn; da sola DagaDyn usa
  di nuovo i suoi.

## [0.2.0] — 2026-11-11

### Nuove proprietà
- **Spostamento X/Y/Z**: di quanto si sposta l'oggetto da dov'è (porte scorrevoli, ascensori), invece di una
  posizione assoluta.
- **Visibile** e **Tag**: cambiano quando la transizione arriva allo stato.
- **Piani di sezione**: si spostano (spostamento X/Y/Z) e si accendono o spengono.

### Partenze
- Ogni oggetto parte **con la timeline**, **dopo un altro oggetto** (quando quello finisce, più un'attesa) oppure
  **quando lo si aziona**: ogni volta da capo, o avanti e poi indietro (porte, cassetti).
- **Strumento Aziona** (menu e barra): un clic sull'oggetto lo fa partire. Mentre lo strumento è attivo la
  timeline va avanti da sola.

### Oggetto
- **Rotazioni attorno agli assi del modello**, oltre a quelli dell'oggetto.
- **Colore e opacità anche sulle facce con materiale proprio** (opzione dell'oggetto).
- **Più oggetti selezionati**: le modifiche valgono per tutti; posizioni e dimensioni si riportano a ciascuno.
- **Anteprima mentre modifichi**: cambiando il valore di uno stato l'oggetto si mostra in quello stato. Il pallino
  accanto a ogni stato fa lo stesso.

### Vista
- **Traiettorie**: il percorso degli oggetti che si muovono, con un punto per ogni stato (SketchUp 2023 e
  successivi). Dei selezionati o di tutti.
- **Ombre spente durante il Play**, per i modelli pesanti: si riaccendono alla pausa, allo stop e prima di salvare.

### DagaWASD
- Con DagaWASD (dalla versione che contiene `lib/dyn_link.rb`) gli oggetti si muovono anche **camminando,
  esplorando, nei percorsi e nei video**. Nei video seguono il tempo del video, fotogramma per fotogramma.
- Le **piattaforme** animate portano il giocatore con sé, anche girandolo.
- Gli oggetti animati **non si prendono e non si calciano**: si muovono da soli.
- Il **tasto Aziona** fa partire gli oggetti che partono «quando li si aziona».
- Mentre DagaWASD registra, riproduce un percorso o esplora, il Play di DagaDyn aspetta invece di interrompere
  il suo lavoro.

## [0.1.0] — 2026-11-11

Prima versione: posizione, rotazione, dimensioni, scala, colore e opacità di gruppi e componenti, da uno stato
all'altro con curve disegnabili; timeline con Play, pausa, Stop e «Tieni»; pannello, lingue e impostazioni di
sistema come DagaWASD.
