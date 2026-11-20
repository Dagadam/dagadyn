# Example: a bedroom where everything moves

**English** · [Italiano](#italiano)

[`bedroom.skp`](bedroom.skp) is a small bedroom that shows every feature of
DagaDyn. Open it in SketchUp 2023 or later with DagaDyn installed.

1. Press **▶** in the animation panel (*Extensions › DagaDyn › Animation
   panel…*): day turns into night outside the window, the toys play, the
   blocks fall one after the other.
2. Pick the **Use** tool (☝ on the toolbar) and click the objects that start
   when used: under the mouse they get a coloured box and their name.
3. **⏹** puts everything back. The file always keeps the rest state.
4. **⏱** next to the timeline is the speed of time: type 4 in *The playback
   lasts* and the 16-second day goes by in 4, the whole room in a
   time-lapse; with *Speed up* time starts slowly and then races. *Normal
   time* puts it back.

Select any object and look at its tracks in the panel to see how it is made.

| Object | What it shows |
|---|---|
| Sky, Sun, Moon, Night sky | a 16-second day and night in several states: colour, move, visibility, all in a loop |
| Glow stars (above the bed) | the **tag** property: by day on a hidden tag, at night on a visible one |
| Door | used, forward and back: rotation around the hinges (reference point *Object origin*) |
| Wardrobe doors | a **chain** behind a used object: the right door follows the left one, both ways |
| Drawers 1, 2, 3 | the same move with three curves: *Slow down*, *Overshoot*, *Bounce* |
| Laptop lid → screen | a hinge (rotation X), then the screen lights up: a colour on an object **inside** another one |
| Bedside lamp → glow | colour with the *Steps* curve, then visibility and **opacity** of the glow |
| Blanket | **size** Y from the *Corner (minimum)*: it folds towards the foot of the bed |
| Curtain cord → curtains | two objects chained behind the same one; size X from the minimum corner and from the origin |
| Jack-in-the-box lid → spring, clown | used, **starts over** at every click; behind the lid the spring stretches from its base (size Z) and the clown rides on it, both with the *Elastic* curve |
| Red switch (left wall) → section plane | a **section plane** that comes down and cuts the room |
| Blocks 1–5 | a long chain with a wait: each block appears and falls when the one before has landed |
| Toy car | absolute **position** X and Y plus rotation, many states in a loop: a lap of the rug. In the bends two hand-drawn curves (a sine and its mirror) make a quarter circle, so the nose follows the road |
| Ball | a bounce in a loop |
| Rocking horse | **two tracks together**, *Back and forth*: rotation Y around the centre of the rockers (*Object origin*) and move X, so it rolls on its rockers instead of sliding |
| Desk chair | a curve **drawn by hand**, back and forth |
| Wall clock | a hand-drawn curve in 12 steps: the hand ticks |
| Globe | rotation on the **object's axes** (it is tilted) |
| Spinning top | rotation on the **world's axes**: tilted, it circles around |
| Balloon | **scale** and move, back and forth with different durations |
| Plant | size Z from its base, after a **delay** at the start |
| Night light | the option *Also faces with their own material*: a rainbow in a loop on painted faces |

With [DagaWASD](https://github.com/Dagadam/dagawasd) 1.3.0 or later you can
also walk into the room: the objects move while you walk, and DagaWASD's Use
key starts the ones you look at.

The model is built by [`tools/esempio_cameretta.rb`](../tools/esempio_cameretta.rb);
`ruby tools/crea_esempio.rb` builds it again in a new SketchUp model through
DagaWASD's bridge and saves it here.

---

## Italiano

[`bedroom.skp`](bedroom.skp) è una cameretta che mostra tutte le funzioni di
DagaDyn. Aprila in SketchUp 2023 o successivo, con DagaDyn installata.

1. Premi **▶** nel pannello delle animazioni (*Estensioni › DagaDyn ›
   Pannello animazioni…*): fuori dalla finestra il giorno diventa notte, i
   giochi si muovono, i cubi cadono uno dopo l'altro.
2. Scegli lo strumento **Aziona** (☝ nella barra) e clicca gli oggetti che
   partono quando li azioni: sotto il mouse hanno il riquadro colorato e il
   nome.
3. **⏹** rimette tutto a posto. Il file conserva sempre lo stato di riposo.
4. **⏱** accanto alla timeline è la velocità del tempo: scrivi 4 in *La
   riproduzione dura* e il giorno di 16 secondi passa in 4, tutta la stanza
   in time-lapse; con *Accelera* il tempo parte piano e poi corre. *Tempo
   normale* lo rimette com'era.

Seleziona un oggetto e guarda le sue tracce nel pannello per vedere com'è
fatto. Cosa mostra:

- **Cielo, sole, luna, stelle**: un giorno e una notte di 16 secondi in più
  stati (colore, spostamento, visibilità), in loop. Le **stelle adesive**
  sopra il letto cambiano **tag**: di giorno uno nascosto, di notte uno
  visibile.
- **Porta**: azionata avanti e indietro, gira sui cardini (riferimento
  *Origine dell'oggetto*). **Ante dell'armadio**: la destra in **catena** dietro la
  sinistra, nei due versi.
- **Cassetti**: lo stesso movimento con tre curve (*Decelera*, *Oltre e
  ritorno*, *Rimbalzo*). **Portatile**: il coperchio sulla cerniera, poi lo
  schermo (un oggetto **dentro** un altro) si accende.
- **Abat-jour**: colore con la curva *A scatti*, poi visibilità e **opacità** dell'alone.
  **Coperta**: **dimensione** Y dall'angolo minimo, si ripiega.
- **Cordino delle tende**: due oggetti in catena dietro lo stesso; dimensione
  X dall'angolo minimo e dall'origine.
- **Scatola a sorpresa**: azionata, **riparte da capo** a ogni clic; dietro
  il coperchio la molla si allunga dalla base (dimensione Z) e il pupazzo
  sale con lei, tutti e due con la curva *Elastico*.
- **Interruttore rosso** sulla parete: il **piano di sezione** scende e
  taglia la stanza.
- **Cubi**: una catena lunga con attesa. **Macchinina**: **posizione**
  assoluta X e Y più rotazione, in molti stati, il giro del tappeto; nelle
  curve due curve disegnate (un seno e la sua speculare) fanno un quarto
  di cerchio, così il muso segue la strada.
- **Palla** (rimbalzo in loop), **sedia** (curva **disegnata a mano**),
  **orologio** (curva a 12 scatti).
- **Cavallo a dondolo**: **due tracce insieme**, *Avanti e indietro*:
  rotazione Y attorno al centro dei pattini (*Origine dell'oggetto*) e
  spostamento X, così rotola sui pattini invece di strisciare.
- **Mappamondo**: rotazione sugli **assi dell'oggetto**, inclinato.
  **Trottola**: sugli **assi del mondo**, gira inclinata.
- **Palloncino**: **scala** e spostamento con durate diverse. **Pianta**:
  cresce dalla base dopo un'**attesa**. **Luce notturna**: colore anche
  sulle facce dipinte, arcobaleno in loop.

Con [DagaWASD](https://github.com/Dagadam/dagawasd) 1.3.0 o successivo puoi
anche entrare nella stanza camminando: gli oggetti si muovono mentre cammini
e il tasto Aziona di DagaWASD fa partire quelli che guardi.

Il modello lo costruisce [`tools/esempio_cameretta.rb`](../tools/esempio_cameretta.rb);
`ruby tools/crea_esempio.rb` lo rifà in un modello nuovo di SketchUp
attraverso il ponte di DagaWASD e lo salva qui.
