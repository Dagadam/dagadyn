# Novità di DagaDyn

## [0.3.0] — 2026-11-16

### Novità
- **In catena dietro un oggetto azionato «avanti/indietro» si segue la sua direzione** (leva → ponte levatoio,
  pulsante → cancello): in tutte e due le direzioni si parte quando l'azionato ha finito (più l'attesa), e si
  riprende da dove si era arrivati. Prima al ritorno l'oggetto in catena scattava di colpo allo stato iniziale.
- **Velocità del tempo** (⏱ accanto alla timeline, che c'è solo quando ci sono oggetti sulla timeline): con la
  stessa curva a pallini delle transizioni decidi come scorre il tempo di tutto il modello. Più ripida è un
  time-lapse, più piatta un rallentatore, in discesa il tempo torna indietro; e la riproduzione può durare meno o
  più della timeline (60 s di timeline in 10 s: sei volte più veloce). Vale per il Play, la barra, gli oggetti
  azionati e, con DagaWASD, anche camminando e nei video. Sta nel modello e si annulla con Ctrl+Z; «Tempo
  normale» la toglie. Con «Ripeti», o con oggetti in ciclo, ricomincia a ogni giro della timeline.
- **Transizioni a formula e collegamenti fra oggetti**: spuntando «ƒ Formula» su una transizione, al posto della
  curva a pallini e del valore di arrivo c'è un'espressione, per esempio `v0 + (2 - v0) * u` (u avanzamento 0–1,
  t secondi, d durata, v0 valore di partenza; + − × ÷ ^, seni e coseni in gradi, sqrt, min, max…). I parametri
  leggono altre tracce, di questo o di altri oggetti, nello stesso istante: il loro valore o l'avanzamento (0–1)
  di una loro transizione. Così la larghezza di una lastra può seguire l'altezza di un cubo mentre cresce. Valori
  nelle unità del pannello; la transizione dopo riparte da dove l'ha lasciata la formula. Il pannello segnala
  formule sbagliate, oggetti o tracce che non ci sono più e collegamenti circolari. Le formule non eseguono
  codice: un interprete conosce solo numeri, operatori e quelle funzioni.

### Esempio
- **examples/bedroom.skp**: una cameretta in cui si muove tutto, con tutte le funzioni di DagaDyn (giorno e
  notte fuori dalla finestra, porta, armadio, cassetti, lampada, tende, scatola a sorpresa, piano di sezione, giochi).
  Si apre in SketchUp 2023 o successivo; examples/README.md spiega cosa cliccare e cosa mostra ogni oggetto.
- **examples/formulas.skp**: le transizioni a formula. Tre oggetti in serie (l'altezza di un cubo fa la larghezza
  di una lastra, che fa la rotazione di una pala), un ascensore con contrappeso (valore) e barra di avanzamento
  (avanzamento 0–1 della transizione), un pendolo e un'onda fatti solo di formule.

### Pannello
- In alto non c'è più il secondo tasto Play (faceva lo stesso del Play della timeline): restano guida, registro
  errori e lo stato (In riproduzione / In pausa / Fermo).
- Se nessun oggetto parte con la timeline (solo oggetti azionati e catene dietro di loro), al posto della barra e
  del timer, che non avrebbero niente da mostrare, una riga lo spiega, e il tasto Play diventa lo strumento Aziona
  (☝; anche con la barra spaziatrice).
- «Riferimento»: «Origine dell'oggetto» invece di «Origine del componente», che valeva anche per i gruppi.
- Più veloce nei modelli grandi: cambiando selezione il pannello non scorre più tutto il modello ogni volta, e un
  Ctrl+Z durante l'animazione ricalcola la scena una volta sola invece che una per ogni oggetto animato.

### Strumento Aziona
- Sotto il mouse l'oggetto che si aziona ha il riquadro colorato, il nome accanto e il cursore con il simbolo di
  Aziona: si vede prima di cliccare che cosa partirà.

### Correzioni
- **Il quadrato rosso (Stop) della barra non faceva niente**: ora ferma l'animazione come Stop nel menu.
- **Ombre giuste durante il movimento**: prima restavano quelle della posizione di riposo (un oggetto abbassato
  lasciava a terra l'ombra lunga e faceva ombra sugli oggetti vicini).
- **Oggetti e cielo non vengono più tagliati** quando un oggetto animato esce dalla posizione di riposo (più alto,
  spostato): con DagaWASD le nuvole sparivano a ogni ciclo.
- **Un oggetto animato dentro un altro gruppo non sparisce più**: lontano dalla posizione di riposo, a tratti
  SketchUp non lo disegnava e ne restava solo l'ombra (lo decideva dall'ingombro di riposo del gruppo che lo
  contiene, che non si aggiornava).
- **Catene lunghe**: in una sequenza «dopo un altro oggetto» dal 18° oggetto in poi non partiva più niente; ora
  nessun limite, e l'ordine degli oggetti nel modello non conta.
- **Strumento Aziona**: la barra di stato mostra il nome dell'oggetto azionato invece di «{name}».
- **Editor delle curve**: se cambi selezione mentre è aperto si chiude, invece di modificare la curva di un altro
  oggetto (o bloccarsi).
- **Velocità cambiata durante il Play**: la timeline non salta più avanti o indietro.
- **Annulla dopo lo Stop**: se durante l'animazione facevi un'operazione tua (Sposta, una modifica delle tracce),
  dopo lo Stop un Ctrl+Z riportava nel modello i materiali temporanei (un oggetto restava del colore di metà
  animazione). Ora l'animazione ha una voce sua, e dopo ogni annulla o ripeti DagaDyn rimette i materiali
  originali e, fra le voci nate durante l'animazione, il riposo degli oggetti.
- **Un oggetto azionato a fine timeline tornava indietro**: se la timeline finiva mentre un oggetto azionato (o in
  catena dietro di lui) si muoveva ancora, alla fine scattava alla posa che aveva quando era finita la timeline
  (un ponte levatoio restava quasi alzato).
- **Anteprima di uno stato** anche per gli oggetti in catena dietro un oggetto azionato.
- **Piani di sezione copiati** (Copia/Incolla, Sposta con Ctrl): ora si animano come l'originale.
- **Salvataggio durante l'animazione**: nel file non finiscono più i materiali temporanei, un oggetto nascosto a
  mano resta nascosto, e uno spostato a mano in pausa resta dove l'hai messo.
- **Dopo File › Nuovo o File › Apri DagaDyn smetteva di seguire il modello** (Windows riusa lo stesso modello per
  Ruby, ma stacca ciò che vi era agganciato): niente traiettorie, cielo e oggetti di nuovo tagliati, pannello che
  non seguiva la selezione, salvataggio senza ritorno a riposo, e «invalid overlay» nel registro cambiando
  un'impostazione. Ora a ogni documento nuovo o aperto si riaggancia tutto.
- Un materiale eliminato durante l'animazione (Elimina inutilizzati) non impedisce più il ripristino allo Stop.
- **Componenti non più usati**: un oggetto animato dentro un componente tolto dal modello (resta fra i componenti
  «Nel modello») compariva ancora nella Scena e allungava la timeline. Ora conta solo ciò che è nel modello.
- **Editor delle curve**: «Usa per tutte le transizioni» compariva anche quando la traccia ne ha una sola.
- Con «Segui la selezione» spento, dopo un Ctrl+Z la Scena del pannello restava quella di prima.

### Con DagaWASD
- **Lingua e aspetto del pannello sono quelli di DagaWASD**: in Sistema non compaiono Lingua e Aspetto, e se li
  cambi in DagaWASD il pannello di DagaDyn li segue subito. Il logo resta quello di DagaDyn; da sola DagaDyn usa
  di nuovo i suoi.
- **La barra della timeline mostrava un tempo senza senso** mentre si camminava, si esplorava o si registrava un
  video con DagaWASD (spesso un numero enorme, con il cursore in fondo): ora mostra l'istante che si vede.

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
