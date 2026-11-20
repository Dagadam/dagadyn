# DagaDyn — Costruisce l'esempio examples/bedroom.skp: una cameretta in cui
# si muove tutto quello che DagaDyn sa fare. Gira dentro SketchUp, con
# DagaDyn caricata, in un modello NUOVO:
#
#   ruby tools/crea_esempio.rb                    (dal ponte di DagaWASD: costruisce e salva)
#   load 'I:/…/tools/esempio_cameretta.rb'; DagaDynEsempio.costruisci   (Console Ruby)
#
# I nomi degli oggetti sono in inglese (il modello è per tutti): sono quelli
# che lo strumento Aziona mostra sotto il mouse.
#
# Cosa mostra (proprietà · curve · partenze · ripetizioni · riferimenti):
#   Sky, Sun, Moon, Night sky, Glow stars  ciclo giorno/notte in più stati: colore, sposta Z,
#                                          visibile, tag (le stelle adesive passano al tag visibile)
#   Door                                   azionata avanti/indietro, rotazione Z attorno ai cardini (origine)
#   Wardrobe door L → R                    catena dietro un azionato: l'anta destra segue la sinistra
#   Drawer 1/2/3                           sposta Y con tre curve: rallenta, oltre e ritorno, rimbalzo
#   Laptop lid → Laptop screen             rotazione X (cerniera) poi colore dello schermo (annidato)
#   Bedside lamp → Lamp glow               colore a scatti, poi visibile + opacità dell'alone
#   Blanket                                dimensione Y dall'angolo minimo (la coperta si ripiega)
#   Curtain cord → Curtain L, Curtain R    dimensione X, una dall'angolo minimo e una dall'origine
#   Jack-in-the-box lid → Clown spring,    azionato «riparte da capo» (play); la molla si allunga dalla base
#                         Clown            (dimensione Z) e il pupazzo sale con lei, curva elastica
#   Section switch → Section plane         il piano di sezione scende e taglia la stanza
#   Block 1…5                              catena lunga con attesa: visibile + sposta Z con rimbalzo
#   Toy car                                posizione X/Y assolute + rotazione, tracce in più stati in loop;
#                                          curve ad arco con due curve disegnate (seno e 1 − coseno)
#   Ball                                   rimbalzo in loop
#   Rocking horse                          due tracce insieme, andata e ritorno: rotazione Y attorno all'origine
#                                          (il centro dei pattini) + sposta X, così rotola senza strisciare
#   Desk chair                             curva disegnata a mano, andata e ritorno
#   Wall clock hand                        curva a scatti disegnata (12 tic), loop
#   Globe                                  rotazione sugli assi dell'oggetto (inclinato), loop lineare
#   Spinning top                           rotazione sugli assi del mondo (inclinata: precessione)
#   Balloon                                scala e sposta Z, andata e ritorno con durate diverse
#   Plant                                  dimensione Z dalla base, con attesa iniziale (delay)
#   Night light                            colore anche sulle facce dipinte (faces), arcobaleno in loop
#
# I dettagli di un oggetto animato stanno dentro il suo gruppo. Dove il
# riferimento è la base, il centro o l'angolo minimo (che si calcolano dal
# riquadro dell'oggetto), i dettagli restano dentro quel riquadro o
# simmetrici: aggiungerne non deve spostare il perno né cambiare la
# dimensione di riposo scritta nelle tracce.
module DagaDynEsempio
  module_function

  # ── Unità: si scrive in metri ──────────────────────────────────────
  def L(x) = x.to_f.m.to_f                       # metri → pollici (valori delle tracce)
  def P(*xyz) = Geom::Point3d.new(*xyz.map { |v| v.to_f.m })
  ASSI = { x: X_AXIS, y: Y_AXIS, z: Z_AXIS }.freeze

  def mat(nome, hex, alpha = nil)
    m = @model.materials[nome] || @model.materials.add(nome)
    m.color = Sketchup::Color.new(hex)
    m.alpha = alpha if alpha
    m
  end

  def finisci(g, at, m, nome)
    g.transform!(Geom::Transformation.translation(P(*at))) if at
    g.material = m if m
    g.name = nome if nome
    g
  end

  # Scatola: origine del gruppo in `at`, geometria da `lo` per `size` (tutto in metri)
  def box(ents, at, lo, size, m = nil, nome = nil)
    g = ents.add_group
    x0, y0, z0 = lo.map { |v| v.to_f.m }
    w, d, h = size.map { |v| v.to_f.m }
    f = g.entities.add_face([x0, y0, z0], [x0 + w, y0, z0], [x0 + w, y0 + d, z0], [x0, y0 + d, z0])
    f.reverse! if f.normal.z < 0
    f.pushpull(h)
    finisci(g, at, m, nome)
  end

  # Scatola nel mondo: origine nell'angolo minimo
  def wbox(ents, min, size, m = nil, nome = nil) = box(ents, min, [0, 0, 0], size, m, nome)

  # Scatola aperta in alto (un pezzo solo, senza giunte): pareti spesse `sp`, fondo `fondo`
  def vasca(ents, min, size, sp, fondo, m = nil, nome = nil)
    g = wbox(ents, min, size, m, nome)
    e = g.entities
    w, d, h = size
    q = [[sp, sp], [w - sp, sp], [w - sp, d - sp], [sp, d - sp]].map { |x, y| P(x, y, h) }
    lati = (0...4).map { |i| e.add_line(q[i], q[(i + 1) % 4]) }
    dentro = -> { e.grep(Sketchup::Face).find { |f| f.normal.z > 0.9 && (f.bounds.min.x - sp.m).abs < 0.01 } }
    lati.each(&:find_faces) unless dentro.()
    f = dentro.() or raise "vasca: il piano di sopra non si è diviso (#{nome})"
    f.pushpull(-(h - fondo).m)
    g
  end

  # Lastra in un pezzo solo: un contorno e dei fori (punti nello stesso piano),
  # spessa `sp` nel verso dato. Un contorno chiuso disegnato su una faccia non
  # la divide da solo: lo fa find_faces, poi la faccia del foro si toglie.
  def lastra(ents, contorno, fori, verso, sp, m = nil, nome = nil)
    g = ents.add_group
    e = g.entities
    e.add_face(contorno)
    fori.each do |foro|
      lati = (0...foro.size).map { |i| e.add_line(foro[i], foro[(i + 1) % foro.size]) }
      lati.each(&:find_faces)
      buco = lati.first.faces.find { |x| (x.outer_loop.edges - lati).empty? } or raise "lastra: foro non aperto (#{nome})"
      buco.erase!
    end
    f = e.grep(Sketchup::Face).first
    f.reverse! if f.normal.dot(verso) < 0
    f.pushpull(sp.to_f.m)
    finisci(g, nil, m, nome)
  end

  # Cilindro: centro della base `c`, asse :x :y :z
  def cyl(ents, c, r, h, m = nil, nome = nil, asse = :z, seg = 24)
    g = ents.add_group
    n = ASSI[asse]
    f = g.entities.add_face(g.entities.add_circle(ORIGIN, n, r.to_f.m, seg))
    f.reverse! if f.normal.dot(n) < 0
    f.pushpull(h.to_f.m)
    finisci(g, c, m, nome)
  end

  # Tronco di cono sull'asse Z: raggio r1 in basso, r2 in alto; chiuso o aperto
  # (paralume). Con pochi lati (seg < 8) gli spigoli restano vivi: una piramide.
  def tronco(ents, c, r1, r2, h, m = nil, nome = nil, chiuso = true, seg = 24)
    g = ents.add_group
    e = g.entities
    giro = lambda do |r, alt|
      (0...seg).map { |i| ang = 2 * Math::PI * i / seg; P(r * Math.cos(ang), r * Math.sin(ang), alt) }
    end
    sotto = giro.(r1, 0)
    sopra = giro.(r2, h)
    seg.times { |i| j = (i + 1) % seg; e.add_face(sotto[i], sotto[j], sopra[j], sopra[i]) }
    if chiuso
      e.add_face(sotto)
      e.add_face(sopra)
    end
    if seg >= 8
      e.grep(Sketchup::Edge).each do |ed|
        ed.soft = ed.smooth = true if ed.faces.size == 2 && ed.faces.all? { |f| f.normal.z.abs < 0.99 }
      end
    end
    finisci(g, c, m, nome)
  end

  # Sfera liscia con centro nell'origine del gruppo, messo in `c`; scala [sx, sy, sz] la schiaccia
  def sfera(ents, c, r, m = nil, nome = nil, seg = 24, scala = nil)
    g = ents.add_group
    e = g.entities
    f = e.add_face(e.add_circle(ORIGIN, X_AXIS, r.to_f.m, seg))
    path = e.add_circle(ORIGIN, Z_AXIS, r.to_f.m * 1.5, seg)
    f.followme(path)
    e.erase_entities(path.select(&:valid?))
    e.transform_entities(Geom::Transformation.scaling(ORIGIN, *scala), e.to_a) if scala
    liscia(g)
    finisci(g, c, m, nome)
  end

  # Profilo nel piano XZ (punti [x, z] in metri) estruso lungo Y da y0 per `sp`
  def profilo(ents, pts, y0, sp, m = nil, nome = nil)
    g = ents.add_group
    f = g.entities.add_face(pts.map { |x, z| P(x, y0, z) })
    f.reverse! if f.normal.y < 0
    f.pushpull(sp.to_f.m)
    finisci(g, nil, m, nome)
  end

  def gira(g, centro, asse, gradi)
    g.transform!(Geom::Transformation.rotation(P(*centro), ASSI[asse], gradi.degrees))
    g
  end

  def sposta(g, *xyz)
    g.transform!(Geom::Transformation.translation(P(*xyz)))
    g
  end

  def liscia(g)
    g.entities.grep(Sketchup::Edge).each { |ed| ed.soft = true; ed.smooth = true }
  end

  # ── Dati di DagaDyn ────────────────────────────────────────────────
  # k: uno stato (il primo senza durata); tr: una traccia
  def k(v, dur = nil, preset = 'ease_in_out', curve = nil)
    h = { 'v' => v }
    return h unless dur
    h['dur'] = dur
    h['preset'] = curve ? 'custom' : preset
    h['curve'] = curve if curve
    h
  end

  def tr(prop, keys, loop: 'none', delay: 0.0)
    { 'prop' => prop, 'keys' => keys, 'loop' => loop, 'delay' => delay }
  end

  def anima(e, tracks, start: nil, pivot: 'base', axes: 'object', faces: false)
    d = { 'pivot' => pivot, 'axes' => axes, 'faces' => faces, 'tracks' => tracks }
    d['start'] = start if start
    DagaDyn::Dyn.write_data(e, d)
  end

  TOGGLE = { 'mode' => 'trigger', 'act' => 'toggle' }.freeze
  PLAY   = { 'mode' => 'trigger', 'act' => 'play' }.freeze
  def dopo(e, wait = 0.0) = { 'mode' => 'after', 'after' => e.persistent_id, 'wait' => wait }

  # ── Il modello ─────────────────────────────────────────────────────
  # op: false quando gira dentro un'operazione già aperta (il ponte di DagaWASD)
  def costruisci(op: true)
    @model = Sketchup.active_model
    raise 'DagaDyn non è caricata' unless defined?(DagaDyn::Dyn)
    raise 'Serve un modello nuovo (File › Nuovo)' unless @model.path.empty? &&
      @model.entities.all? { |e| e.is_a?(Sketchup::ComponentInstance) && !e.attribute_dictionary('DagaDyn') }
    @model.start_operation('DagaDyn example', true) if op
    @model.entities.clear!
    @model.definitions.purge_unused
    stanza
    cielo
    letto
    scrivania
    armadio
    giochi
    sezione
    vista
    @model.commit_operation if op
    DagaDyn::Dyn.animated_instances(@model).size
  rescue
    @model.abort_operation if op && @model
    raise
  end

  # ══════════════════════════════════════════════════════════════════
  # La stanza: pavimento a listoni, due pareti con porta e finestra,
  # mensola, tappeto. x 0–4, y 0–3,5; la parete di fondo è a y 3,5, quella
  # sinistra a x 0.
  # ══════════════════════════════════════════════════════════════════
  def stanza
    ents = @model.entities
    muro   = mat('Wall', '#f2e6d8')
    bianco = mat('Trim', '#fbfaf7')
    metallo = mat('Metal', '#8d99ae')
    ottone = mat('Brass', '#d4a72c')
    stanza = ents.add_group
    stanza.name = 'Room'
    se = stanza.entities
    pavimento(se)
    # parete di fondo (y 3,5–3,62) con la finestra x 1,6–2,8, z 1,0–2,2
    lastra(se, [P(-0.12, 3.5, 0), P(4, 3.5, 0), P(4, 3.5, 2.7), P(-0.12, 3.5, 2.7)],
           [[P(1.6, 3.5, 1.0), P(2.8, 3.5, 1.0), P(2.8, 3.5, 2.2), P(1.6, 3.5, 2.2)]], Y_AXIS, 0.12, muro)
    # parete sinistra (x −0,12–0) con il vano della porta y 0,4–1,3, alto 2,1
    lastra(se, [P(0, 0, 0), P(0, 0.4, 0), P(0, 0.4, 2.1), P(0, 1.3, 2.1), P(0, 1.3, 0), P(0, 3.5, 0),
                P(0, 3.5, 2.7), P(0, 0, 2.7)], [], X_AXIS.reverse, 0.12, muro)
    # battiscopa
    wbox(se, [0, 3.48, 0], [4.0, 0.02, 0.08], bianco)
    wbox(se, [0, 1.37, 0], [0.02, 2.11, 0.08], bianco)
    wbox(se, [0, 0, 0], [0.02, 0.33, 0.08], bianco)
    # finestra: telaio, montante, traverso, maniglia, vetro
    wbox(se, [1.6, 3.53, 1.0], [1.2, 0.06, 0.05], bianco)
    wbox(se, [1.6, 3.53, 2.15], [1.2, 0.06, 0.05], bianco)
    wbox(se, [1.6, 3.53, 1.05], [0.05, 0.06, 1.1], bianco)
    wbox(se, [2.75, 3.53, 1.05], [0.05, 0.06, 1.1], bianco)
    wbox(se, [2.175, 3.53, 1.05], [0.05, 0.06, 1.1], bianco)
    wbox(se, [1.65, 3.535, 1.75], [0.525, 0.04, 0.03], bianco)
    wbox(se, [2.225, 3.535, 1.75], [0.525, 0.04, 0.03], bianco)
    wbox(se, [2.192, 3.515, 1.45], [0.016, 0.015, 0.12], metallo)
    wbox(se, [1.65, 3.555, 1.05], [1.1, 0.006, 1.1], mat('Glass', '#cfe8f3', 0.18))
    # davanzale e bastone delle tende con i pomoli
    wbox(se, [1.55, 3.42, 0.97], [1.3, 0.1, 0.03], bianco)
    cyl(se, [1.38, 3.43, 2.42], 0.012, 1.62, metallo, nil, :x)
    [1.37, 3.01].each { |x| sfera(se, [x, 3.43, 2.42], 0.025, ottone, nil, 12) }
    [1.4, 2.98].each { |x| wbox(se, [x, 3.43, 2.405], [0.02, 0.07, 0.03], metallo) }
    # stipiti della porta e interruttore della luce
    wbox(se, [0, 0.33, 0], [0.025, 0.07, 2.17], bianco)
    wbox(se, [0, 1.3, 0], [0.025, 0.07, 2.17], bianco)
    wbox(se, [0, 0.4, 2.1], [0.025, 0.9, 0.07], bianco)
    wbox(se, [0, 0.12, 1.05], [0.008, 0.08, 0.12], bianco)
    wbox(se, [0.008, 0.145, 1.09], [0.006, 0.03, 0.04], mat('Switch light', '#e9ecef'))
    mensola(se)
    tappeto
    porta
    tende
  end

  # Listoni: il piano di sopra del pavimento è fatto di facce, una per
  # listone, uno sì e uno no un po' più scuro; sotto il tappeto una faccia
  # sola (righe lì sotto trasparirebbero da lontano dal tappeto, che è
  # sottile). Le facce hanno i vertici in comune (add_line non le divideva:
  # finiva a metà di un altro spigolo) e le righe fra i listoni restano
  # nascoste: i due toni bastano, mentre righe nere sottili, viste da
  # lontano con la camera che gira, sfarfallano.
  TAPPETO = [1.85, 0.55, 1.5, 1.45].freeze          # x, y, larghezza, profondità
  def pavimento(ents)
    pav = ents.add_group
    listoni(pav.entities)
    finisci(pav, [-0.12, 0, -0.05], mat('Floor wood', '#c49a6c'), nil)
  end

  # La lastra del pavimento (4,12 × 3,62 × 0,05 m, origine nell'angolo) in pe, rifatta da capo
  def listoni(pe)
    pe.clear!
    lx = 4.12
    ly = 3.62
    h = 0.05
    w = 0.18
    tx0 = TAPPETO[0] + 0.12                          # nelle coordinate del pavimento (parte da x −0,12)
    tx1 = tx0 + TAPPETO[2]
    ty0 = TAPPETO[1]
    ty1 = ty0 + TAPPETO[3]
    ys = ((0..((ly - w / 2) / w).floor).map { |i| (i * w).round(6) } + [ty0, ty1, ly]).uniq.sort   # l'ultimo è di 20 cm
    sotto = ->(y0, y1) { y0 >= ty0 - 1e-6 && y1 <= ty1 + 1e-6 }
    xs = ->(y) { y >= ty0 - 1e-6 && y <= ty1 + 1e-6 ? [0, tx0, tx1, lx] : [0, lx] }
    scuro = mat('Floor wood dark', '#b88b5e')
    ys.each_cons(2) do |y0, y1|
      pezzi = sotto.(y0, y1) ? [[0, tx0], [tx0, tx1], [tx1, lx]] : [[0, lx]]
      pezzi.each do |x0, x1|
        giu = xs.(y0).select { |x| x >= x0 && x <= x1 }
        su = xs.(y1).select { |x| x >= x0 && x <= x1 }.reverse
        f = pe.add_face(giu.map { |x| P(x, y0, h) } + su.map { |x| P(x, y1, h) })
        f.reverse! if f.normal.z < 0
        f.material = scuro if x0 != tx0 && ((y0 + y1) / 2 / w).floor.odd?
      end
    end
    fondo = pe.add_face(P(0, 0, 0), P(0, ly, 0), P(lx, ly, 0), P(lx, 0, 0))
    fondo.reverse! if fondo.normal.z > 0
    [[0, -1], [lx, 1]].each do |x, verso|
      f = pe.add_face([P(x, 0, 0), P(x, ly, 0)] + ys.reverse.map { |y| P(x, y, h) })
      f.reverse! if f.normal.x * verso < 0
    end
    [[0, -1], [ly, 1]].each do |y, verso|
      f = pe.add_face([P(0, y, 0), P(lx, y, 0)] + xs.(y).reverse.map { |x| P(x, y, h) })
      f.reverse! if f.normal.y * verso < 0
    end
    righe_nascoste(pe)
  end

  # Nasconde le righe sul piano di sopra della lastra, tranne il contorno
  def righe_nascoste(pe)
    bb = pe.parent.bounds
    su = ->(p) { (p.z - bb.max.z).abs < 1e-3 }
    bordo = ->(a, b) { [[:x, bb.min.x], [:x, bb.max.x], [:y, bb.min.y], [:y, bb.max.y]].any? { |k, v| (a.send(k) - v).abs < 1e-3 && (b.send(k) - v).abs < 1e-3 } }
    pe.grep(Sketchup::Edge).each do |e|
      a = e.start.position
      b = e.end.position
      e.hidden = true if su.(a) && su.(b) && !bordo.(a, b)
    end
  end

  # Tappeto con due cornici disegnate sul piano di sopra
  def tappeto
    tap = wbox(@model.entities, [TAPPETO[0], TAPPETO[1], 0], [TAPPETO[2], TAPPETO[3], 0.008], mat('Rug', '#e9c46a'), 'Rug')
    te = tap.entities
    w, p = TAPPETO[2], TAPPETO[3]
    [0.06, 0.12, 0.16].each do |d|
      q = [[d, d], [w - d, d], [w - d, p - d], [d, p - d]].map { |x, y| P(x, y, 0.008) }
      (0...4).map { |i| te.add_line(q[i], q[(i + 1) % 4]) }.each(&:find_faces)
    end
    bordo  = mat('Rug border', '#e76f51')
    centro = mat('Rug centre', '#f4d58d')
    te.grep(Sketchup::Face).each do |f|
      next unless f.normal.z > 0.9
      d = f.bounds.min.x.to_m
      f.material = bordo if (d - 0.06).abs < 0.01
      f.material = centro if (d - 0.16).abs < 0.01
    end
  end

  # Mensola sopra il letto: libri (uno appoggiato agli altri) e una cornice
  def mensola(ents)
    legno = mat('Shelf', '#e5d4b8')
    wbox(ents, [0.3, 3.3, 1.5], [0.85, 0.2, 0.025], legno)
    [0.36, 1.05].each { |x| wbox(ents, [x, 3.47, 1.36], [0.03, 0.03, 0.14], legno) }
    alti    = [0.19, 0.18, 0.24, 0.2, 0.17, 0.23, 0.22]
    spessi  = [0.035, 0.03, 0.045, 0.03, 0.04, 0.03, 0.035]
    x = 0.34
    %w[#e63946 #457b9d #2a9d8f #f4a261 #6d597a #e9c46a #264653].each_with_index do |c, i|
      libro = wbox(ents, [x, 3.33, 1.525], [spessi[i], 0.15, alti[i]], mat("Book #{i + 1}", c))
      wbox(libro.entities, [0.004, -0.0005, alti[i] * 0.7], [spessi[i] - 0.008, 0.0005, 0.025], mat('Book label', '#fefae0'))
      x += spessi[i] + 0.004
    end
    # l'ultimo sta inclinato: poggia sullo spigolo in basso e tocca il vicino con quello in alto
    xb = x - 0.004 + 0.2 * Math.sin(15.degrees)
    gira(wbox(ents, [xb, 3.33, 1.525], [0.035, 0.15, 0.2], mat('Book 8', '#bc4749')), [xb, 3.33, 1.525], :y, -15)
    # cornice appoggiata alla parete, con un disegnino
    cornice = wbox(ents, [0.82, 3.42, 1.525], [0.2, 0.025, 0.25], mat('Frame', '#ffffff'))
    gira(cornice, [0.82, 3.42, 1.525], :x, -8)
    disegno = wbox(cornice.entities, [0.02, -0.002, 0.03], [0.16, 0.002, 0.19], mat('Drawing', '#a8dadc'))
    dipinto(disegno.entities)
  end

  # Il disegnino nella cornice: il foglio (16 × 19 cm, spesso 2 mm, davanti a
  # y = 0) rifatto da capo, con la faccia davanti già divisa in zone che hanno
  # i vertici in comune: prato, casetta, tetto, cielo (il colore del foglio)
  # e il sole. Niente lastrine appoggiate, che da lontano sfarfallano.
  def dipinto(de)
    de.clear!
    w, h, sp = 0.16, 0.19, 0.002
    faccia = lambda do |pts, verso, m = nil|                        # punti [x, z] o [x, z, y]
      f = de.add_face(pts.map { |x, z, y| P(x, y || 0, z) })
      f.reverse! if f.normal.dot(verso) < 0
      f.material = m if m
      f
    end
    avanti = Geom::Vector3d.new(0, -1, 0)
    faccia.([[0, 0], [w, 0], [w, 0.05], [0.11, 0.05], [0.11, 0.03], [0.04, 0.03], [0.04, 0.05], [0, 0.05]],
            avanti, mat('Drawing grass', '#80b918'))
    faccia.([[0.04, 0.03], [0.11, 0.03], [0.11, 0.05], [0.11, 0.09], [0.04, 0.09], [0.04, 0.05]], avanti,
            mat('Drawing house', '#fefae0'))
    faccia.([[0.03, 0.09], [0.04, 0.09], [0.11, 0.09], [0.12, 0.09], [0.075, 0.13]], avanti, mat('Drawing roof', '#e76f51'))
    faccia.([[0, 0.05], [0.04, 0.05], [0.04, 0.09], [0.03, 0.09], [0.075, 0.13], [0.12, 0.09], [0.11, 0.09],
             [0.11, 0.05], [w, 0.05], [w, h], [0, h]], avanti)
    sole = de.add_circle(P(0.125, 0, 0.155), Y_AXIS, 0.018.m, 12)
    sole.first.find_faces
    f = de.grep(Sketchup::Face).find { |x| (x.outer_loop.edges - sole).empty? } or raise 'dipinto: il sole'
    f.reverse! if f.normal.dot(avanti) < 0
    f.material = mat('Sun', '#ffd23f')
    # i fianchi; dietro niente: sarebbe complanare con la cornice
    faccia.([[0, 0], [w, 0], [w, 0, sp], [0, 0, sp]], Z_AXIS.reverse)
    faccia.([[0, h], [w, h], [w, h, sp], [0, h, sp]], Z_AXIS)
    faccia.([[0, 0], [0, 0.05], [0, h], [0, h, sp], [0, 0, sp]], X_AXIS.reverse)
    faccia.([[w, 0], [w, 0.05], [w, h], [w, h, sp], [w, 0, sp]], X_AXIS)
    nil
  end

  # Porta: cardini in (0, 0,4), si apre verso la stanza. Specchiature, maniglia, cerniere
  def porta
    g = @model.entities.add_group
    g.name = 'Door'
    e = g.entities
    legno  = mat('Door', '#a9714b')
    chiaro = mat('Door panel', '#b98159')
    ottone = mat('Brass', '#d4a72c')
    box(e, [0, 0, 0], [-0.04, 0, 0], [0.04, 0.9, 2.08], legno)
    [[0.15, 0.8], [1.12, 0.82]].each do |z, h|
      box(e, [0, 0.12, z], [0, 0, 0], [0.008, 0.62, h], chiaro)
      box(e, [0.008, 0.17, z + 0.05], [0, 0, 0], [0.004, 0.52, h - 0.1], legno)
    end
    box(e, [0, 0.8, 0.86], [0, -0.025, 0], [0.004, 0.05, 0.2], ottone)            # placca
    cyl(e, [0.004, 0.8, 1.0], 0.009, 0.045, ottone, nil, :x, 12)                   # perno
    box(e, [0.04, 0.8, 1.0], [0, -0.11, -0.008], [0.014, 0.118, 0.016], ottone)   # leva
    box(e, [0.004, 0.8, 0.9], [0, -0.005, 0], [0.001, 0.01, 0.03], mat('Black', '#222222'))
    [0.25, 1.05, 1.8].each { |z| cyl(e, [0.002, 0.004, z], 0.009, 0.1, ottone, nil, :z, 12) }
    sposta(g, -0.03, 0.4, 0.01)
    anima(g, [tr('rot_z', [k(0), k(-95, 1.4, 'ease_in_out')])], start: TOGGLE, pivot: 'origin')
  end

  # Tende: aperte a riposo; il cordino le chiude (e le riapre). Le pieghe e
  # gli anelli stanno dentro la larghezza di riposo (0,26): dimensione X parte da lì.
  def tende
    ents = @model.entities
    stoffa = mat('Curtain', '#e76f51')
    piega  = mat('Curtain fold', '#ee8266')
    ottone = mat('Brass', '#d4a72c')
    cord = cyl(ents, [1.36, 3.46, 1.45], 0.008, 0.9, mat('Cord', '#6d6875'), 'Curtain cord', :z, 8)
    sfera(cord.entities, [0, 0, -0.03], 0.032, mat('Cord ball', '#bc6c25'), nil, 16)
    tronco(cord.entities, [0, 0, -0.12], 0.022, 0.008, 0.065, mat('Tassel', '#f4a261'), nil, true, 12)
    anima(cord, [tr('move_z', [k(0), k(L(-0.06), 0.3, 'ease_out')])], start: TOGGLE)
    sx = box(ents, [1.42, 3.4, 0.9], [0, 0, 0], [0.26, 0.03, 1.5], stoffa, 'Curtain L')
    dx = box(ents, [2.98, 3.4, 0.9], [-0.26, 0, 0], [0.26, 0.03, 1.5], stoffa, 'Curtain R')
    [[sx, 0.0], [dx, -0.26]].each do |t, x0|
      3.times { |i| box(t.entities, [x0 + 0.03 + i * 0.08, -0.006, 0], [0, 0, 0], [0.04, 0.006, 1.5], piega) }
      4.times { |i| cyl(t.entities, [x0 + 0.03 + i * 0.065, 0.03, 1.52], 0.02, 0.006, ottone, nil, :x, 12) }
    end
    anima(sx, [tr('size_x', [k(L(0.26)), k(L(0.8), 1.6, 'ease_in_out')])], start: dopo(cord), pivot: 'min')
    anima(dx, [tr('size_x', [k(L(0.26)), k(L(0.8), 1.6, 'ease_in_out')])], start: dopo(cord), pivot: 'origin')
  end

  # ══════════════════════════════════════════════════════════════════
  # Fuori dalla finestra: cielo, colline, nuvole, sole, luna, stelle.
  # Un ciclo di 16 s: giorno 3 · tramonto 2,5 · sera 2,5 · notte 4 · alba 2 · mattino 2
  # In profondità (y): colline 3,86 · nuvole 3,875 · sole, luna e stelle 3,89 · cielo 3,9
  # ══════════════════════════════════════════════════════════════════
  def cielo
    ents = @model.entities
    sky = wbox(ents, [1.3, 3.9, 0.7], [1.8, 0.02, 1.8], mat('Sky', '#8ecae6'), 'Sky')
    anima(sky, [tr('color', [k('#8ecae6'), k('#8ecae6', 3.0, 'linear'), k('#f4a261', 2.5), k('#14213d', 2.5),
                             k('#14213d', 4.0, 'linear'), k('#f6bd60', 2.0), k('#8ecae6', 2.0)], loop: 'loop')])
    profilo(ents, [[1.3, 0.7], [3.1, 0.7], [3.1, 1.08], [2.7, 1.2], [2.3, 1.1], [1.9, 1.25], [1.5, 1.12], [1.3, 1.15]],
            3.86, 0.01, mat('Hill', '#6a994e'), 'Hills')
    nuvole = ents.add_group
    nuvole.name = 'Clouds'
    bianco = mat('Cloud', '#ffffff')
    [[1.85, 1.95], [2.55, 2.12]].each do |x, z|
      [[0, 0, 0.07], [0.08, 0.02, 0.09], [0.17, 0, 0.065]].each do |dx, dz, r|
        sfera(nuvole.entities, [x + dx, 3.875, z + dz], r, bianco, nil, 16, [1, 0.12, 0.7])
      end
    end
    giallo = mat('Sun', '#ffd23f')
    sole = cyl(ents, [2.5, 3.89, 1.85], 0.13, 0.01, giallo, 'Sun', :y)
    8.times { |i| gira(box(sole.entities, [0, 0, 0], [0.16, 0, -0.012], [0.07, 0.01, 0.024], giallo), [0, 0, 0], :y, i * 45) }
    anima(sole, [tr('move_z', [k(0), k(0, 3.0, 'linear'), k(L(-0.6), 2.5, 'ease_in'), k(L(-1.45), 2.5, 'linear'),
                               k(L(-1.45), 4.0, 'linear'), k(L(-0.7), 2.0, 'ease_out'), k(0, 2.0, 'ease_out')],
                     loop: 'loop')])
    luna = cyl(ents, [1.95, 3.89, 0.5], 0.1, 0.01, mat('Moon', '#f1f1e6'), 'Moon', :y)
    [[0.03, 0.03, 0.02], [-0.035, -0.02, 0.015], [0.01, -0.045, 0.012]].each do |x, z, r|
      cyl(luna.entities, [x, -0.002, z], r, 0.002, mat('Moon crater', '#d8d8c8'), nil, :y, 12)
    end
    anima(luna, [tr('move_z', [k(0), k(0, 5.5, 'linear'), k(L(1.25), 2.5, 'ease_out'), k(L(1.25), 4.0, 'linear'),
                               k(0, 2.0, 'ease_in'), k(0, 2.0, 'linear')], loop: 'loop')])
    stelle = ents.add_group
    stelle.name = 'Night sky'
    chiaro = mat('Star', '#fff8dc')
    [[1.7, 2.05], [1.85, 1.6], [2.05, 1.95], [2.3, 1.35], [2.45, 2.1], [2.65, 1.55], [2.05, 1.45], [1.7, 1.35]].each do |x, z|
      cyl(stelle.entities, [x, 3.895, z], 0.012, 0.004, chiaro, nil, :y, 8)
    end
    stelle.hidden = true
    anima(stelle, [tr('visible', [k(0), k(0, 5.5, 'linear'), k(1, 2.5, 'linear'), k(1, 4.0, 'linear'),
                                  k(0, 2.0, 'linear'), k(0, 2.0, 'linear')], loop: 'loop')])
    # Stelle adesive sopra il letto: di giorno su un tag spento, di notte su uno acceso
    giorno = @model.layers['Glow stars · day'] || @model.layers.add('Glow stars · day')
    notte  = @model.layers['Glow stars · night'] || @model.layers.add('Glow stars · night')
    giorno.visible = false
    notte.visible = true
    adesive = ents.add_group
    adesive.name = 'Glow stars'
    verde = mat('Glow', '#d9ed92')
    [[1.75, 1.45], [1.95, 1.75], [2.2, 1.3], [3.0, 1.75], [3.25, 1.3], [3.3, 1.8], [2.6, 1.45]].each do |y, z|
      stella(adesive.entities, y, z, verde)
    end
    cyl(adesive.entities, [0.002, 2.9, 1.42], 0.035, 0.003, verde, nil, :x, 16)
    adesive.layer = giorno
    anima(adesive, [tr('tag', [k(giorno.name), k(giorno.name, 5.5, 'linear'), k(notte.name, 2.5, 'linear'),
                               k(notte.name, 4.0, 'linear'), k(giorno.name, 2.0, 'linear'), k(giorno.name, 2.0, 'linear')],
                       loop: 'loop')])
  end

  # Stella a cinque punte sulla parete sinistra (x = 0)
  def stella(ents, y, z, m)
    pts = (0...10).map do |i|
      a = Math::PI / 2 + i * Math::PI / 5
      r = i.even? ? 0.07 : 0.028
      P(0.002, y + r * Math.cos(a), z + r * Math.sin(a))
    end
    g = ents.add_group
    f = g.entities.add_face(pts)
    f.pushpull(0.003.m)
    g.material = m
  end

  # ══════════════════════════════════════════════════════════════════
  # Letto, orologio, comodino con l'abat-jour, palloncino
  # ══════════════════════════════════════════════════════════════════
  def letto
    ents = @model.entities
    legno = mat('Bed wood', '#e5d4b8')
    inserto = mat('Bed panel', '#d4c09f')
    ottone = mat('Brass', '#d4a72c')
    # telaio, gambe, testiera a listelli, pediera
    tel = ents.add_group
    tel.name = 'Bed'
    be = tel.entities
    wbox(be, [0.2, 1.51, 0.12], [1.0, 1.91, 0.23], legno)
    [[0.2, 1.51], [1.14, 1.51], [0.2, 3.36], [1.14, 3.36]].each { |x, y| wbox(be, [x, y, 0], [0.06, 0.06, 0.12], legno) }
    [0.2, 1.14].each do |x|
      wbox(be, [x, 3.42, 0], [0.06, 0.06, 1.0], legno)
      sfera(be, [x + 0.03, 3.45, 1.03], 0.035, legno, nil, 16)
    end
    wbox(be, [0.26, 3.43, 0.88], [0.88, 0.04, 0.08], legno)
    wbox(be, [0.26, 3.43, 0.35], [0.88, 0.04, 0.06], legno)
    8.times { |i| wbox(be, [0.31 + i * 0.105, 3.435, 0.41], [0.045, 0.03, 0.47], legno) }
    wbox(be, [0.2, 1.47, 0], [1.0, 0.04, 0.55], legno)
    wbox(be, [0.25, 1.465, 0.2], [0.9, 0.005, 0.28], inserto)
    wbox(ents, [0.23, 1.53, 0.35], [0.94, 1.89, 0.2], mat('Mattress', '#fdfcfa'), 'Mattress')
    wbox(ents, [0.22, 2.95, 0.55], [0.96, 0.45, 0.012], mat('Sheet', '#ffffff'), 'Sheet')
    sfera(ents, [0.7, 3.17, 0.62], 0.2, mat('Pillow', '#a8dadc'), 'Pillow', 24, [1.7, 0.95, 0.3])
    gira(sfera(ents, [0.45, 3.37, 0.76], 0.13, mat('Cushion', '#ffb4a2'), 'Cushion', 20, [1.0, 0.4, 1.0]),
         [0.45, 3.37, 0.76], :x, -12)
    # coperta: righe sopra e falde sui fianchi, tutte nella lunghezza di riposo (1,43)
    blu = mat('Blanket', '#457b9d')
    coperta = wbox(ents, [0.21, 1.52, 0.55], [0.98, 1.43, 0.05], blu, 'Blanket')
    ce = coperta.entities
    righe = mat('Blanket stripe', '#a8dadc')
    [0.2, 0.5, 0.8, 1.1].each { |y| box(ce, [0, y, 0.05], [0, 0, 0], [0.98, 0.06, 0.003], righe) }
    [-0.01, 0.98].each { |x| box(ce, [x, 0, 0], [0, 0, -0.18], [0.01, 1.43, 0.23], blu) }
    anima(coperta, [tr('size_y', [k(L(1.43)), k(L(0.5), 1.2, 'ease_in_out')])], start: TOGGLE, pivot: 'min')

    orologio
    # comodino con due cassetti e le gambe
    com = ents.add_group
    com.name = 'Nightstand'
    ne = com.entities
    wbox(ne, [1.24, 3.08, 0.08], [0.34, 0.38, 0.42], legno)
    [[1.25, 3.09], [1.53, 3.09], [1.25, 3.41], [1.53, 3.41]].each { |x, y| wbox(ne, [x, y, 0], [0.04, 0.04, 0.08], legno) }
    [[0.3, 0.16], [0.12, 0.15]].each do |z, h|
      wbox(ne, [1.26, 3.07, z], [0.3, 0.01, h], inserto)
      sfera(ne, [1.41, 3.06, z + h / 2], 0.014, ottone, nil, 12)
    end
    wbox(ne, [1.44, 3.13, 0.5], [0.11, 0.15, 0.03], mat('Book 3', '#2a9d8f'))
    # abat-jour: base, stelo, lampadina, paralume a tronco di cono (senza
    # materiale: prende il colore dell'oggetto, quello che l'animazione cambia)
    lampada = ents.add_group
    lampada.name = 'Bedside lamp'
    le = lampada.entities
    tronco(le, [0, 0, 0], 0.065, 0.045, 0.03, mat('Lamp base', '#3d405b'))
    cyl(le, [0, 0, 0.03], 0.008, 0.15, ottone, nil, :z, 12)
    sfera(le, [0, 0, 0.19], 0.025, mat('Bulb', '#fff3c4'), nil, 12)
    tronco(le, [0, 0, 0.15], 0.11, 0.065, 0.16, nil, nil, false, 32)
    sposta(lampada, 1.36, 3.27, 0.5)
    lampada.material = mat('Lampshade', '#efe6d2')
    anima(lampada, [tr('color', [k('#efe6d2'), k('#ffd166', 0.3, 'steps')])], start: TOGGLE)
    alone = sfera(ents, [1.36, 3.27, 0.74], 0.2, mat('Lamp glow', '#ffe08a', 0.3), 'Lamp glow')
    alone.hidden = true
    anima(alone, [tr('visible', [k(0), k(1, 0.01, 'linear')]),
                  tr('opacity', [k(0.0), k(0.3, 0.8, 'ease_out')])], start: dopo(lampada), pivot: 'center')

    # palloncino legato alla pediera: nodo e filo. L'origine è il centro del
    # palloncino: la scala parte da lì.
    rosa = mat('Balloon', '#ef476f')
    pall = sfera(ents, [1.0, 1.3, 1.45], 0.16, rosa, 'Balloon', 24, [1, 1, 1.15])
    tronco(pall.entities, [0, 0, -0.2], 0.012, 0.004, 0.018, rosa, nil, true, 8)
    pall.entities.add_line(P(0, 0, -0.2), P(0.17, 0.19, -0.89))
    anima(pall, [tr('move_z', [k(0), k(L(0.08), 1.6, 'ease_in_out')], loop: 'pingpong'),
                 tr('scale', [k(1.0), k(1.06, 2.1, 'ease_in_out')], loop: 'pingpong')], pivot: 'origin')
  end

  # Orologio sulla parete sinistra, sopra il letto: cornice, tacche, ore e
  # minuti fermi sulle 10 e 10, la lancetta dei secondi che scatta
  def orologio
    ents = @model.entities
    c = [2.55, 1.95]                               # centro (y, z)
    nero = mat('Black', '#222222')
    rosso = mat('Clock hand', '#d62828')
    cyl(ents, [0, c[0], c[1]], 0.185, 0.012, mat('Clock rim', '#3d405b'), 'Wall clock', :x, 36)
    cyl(ents, [0.012, c[0], c[1]], 0.165, 0.006, mat('Clock', '#fefae0'), 'Clock face', :x, 36)
    fermi = ents.add_group
    fermi.name = 'Clock marks'
    fe = fermi.entities
    12.times do |i|
      a = i * Math::PI / 6
      lungo = (i % 3).zero? ? 0.03 : 0.015
      p = [0.018, c[0] + 0.14 * Math.sin(a), c[1] + 0.14 * Math.cos(a)]
      gira(box(fe, p, [0, -0.004, -lungo / 2], [0.003, 0.008, lungo], nero), p, :x, -i * 30)
    end
    gira(box(fe, [0.019, c[0], c[1]], [0, -0.007, -0.01], [0.004, 0.014, 0.085], nero), [0.019, c[0], c[1]], :x, 60)
    gira(box(fe, [0.021, c[0], c[1]], [0, -0.005, -0.01], [0.004, 0.01, 0.13], nero), [0.021, c[0], c[1]], :x, -60)
    lancetta = box(ents, [0.026, c[0], c[1]], [0, -0.003, -0.03], [0.004, 0.006, 0.17], rosso, 'Wall clock hand')
    cyl(lancetta.entities, [0.004, 0, 0], 0.012, 0.004, rosso, nil, :x, 16)
    passi = [[0, 0]]
    12.times do |i|
      x = (i + 1) / 12.0
      passi << [x - 0.012, i / 12.0, 1]       # fermo…
      passi << [x, x, 1] if i < 11             # …e uno scatto
    end
    anima(lancetta, [tr('rot_x', [k(0), k(-360, 12.0, nil, passi + [[1, 1]])], loop: 'loop')], pivot: 'origin')
  end

  # ══════════════════════════════════════════════════════════════════
  # Scrivania: cassetti, portatile, mappamondo, luce notturna, sedia
  # ══════════════════════════════════════════════════════════════════
  def scrivania
    ents = @model.entities
    legno = mat('Desk', '#f4f1de')
    verde = mat('Desk legs', '#81b29a')
    metallo = mat('Metal', '#8d99ae')
    ottone = mat('Brass', '#d4a72c')
    scuro = mat('Lamp base', '#3d405b')
    piano = ents.add_group
    piano.name = 'Desk'
    pe = piano.entities
    wbox(pe, [1.65, 2.9, 0.72], [1.2, 0.58, 0.03], legno)
    wbox(pe, [1.67, 2.92, 0], [0.04, 0.04, 0.72], verde)
    wbox(pe, [1.67, 3.42, 0], [0.04, 0.04, 0.72], verde)
    wbox(pe, [1.67, 2.96, 0.08], [0.04, 0.46, 0.03], verde)
    wbox(pe, [1.71, 3.44, 0.6], [0.69, 0.02, 0.12], verde)
    wbox(pe, [2.4, 2.92, 0], [0.45, 0.56, 0.72], verde)
    # sul piano: tre libri impilati, portapenne con le matite
    [['#e63946', 0.035], ['#457b9d', 0.03], ['#e9c46a', 0.04]].each_with_index do |(c, h), i|
      lib = wbox(pe, [2.45, 2.95, 0.75 + [0, 0.035, 0.065][i]], [0.24, 0.17, h], mat("Desk book #{i + 1}", c))
      gira(lib, [2.57, 3.035, 0.75], :z, [4, -6, 9][i])
    end
    portapenne(pe, [2.14, 3.38, 0.75])
    # tre cassetti, tre curve: cavi, con qualcosa dentro (quaderni, maglie, cubi);
    # frontale con la specchiatura e la maniglia a ponte
    dentro = [
      [[0.03, 0.04, 0.2, 0.28, 0.02, '#fefae0'], [0.26, 0.05, 0.11, 0.16, 0.04, '#e63946'], [0.26, 0.24, 0.11, 0.07, 0.03, '#457b9d']],
      [[0.03, 0.04, 0.17, 0.4, 0.12, '#2a9d8f'], [0.21, 0.04, 0.17, 0.4, 0.09, '#f4a261']],
      [[0.04, 0.05, 0.08, 0.08, 0.08, '#e63946'], [0.16, 0.08, 0.08, 0.08, 0.08, '#e9c46a'], [0.28, 0.04, 0.08, 0.08, 0.08, '#457b9d'],
       [0.08, 0.2, 0.08, 0.08, 0.08, '#2a9d8f'], [0.22, 0.22, 0.08, 0.08, 0.08, '#f4a261']]
    ]
    [[0.49, 'ease_out'], [0.27, 'back'], [0.03, 'bounce']].each_with_index do |(z, curva), i|
      c = vasca(ents, [2.42, 2.88, z], [0.41, 0.5, 0.21], 0.015, 0.015, legno, "Drawer #{i + 1}")
      dentro[i].each_with_index do |(x, y, w, d, h, colore), j|
        box(c.entities, [x, y, 0.015], [0, 0, 0], [w, d, h], mat("Drawer #{i + 1} item #{j + 1}", colore))
      end
      box(c.entities, [0.03, -0.004, 0.03], [0, 0, 0], [0.35, 0.004, 0.15], mat('Drawer panel', '#e9e4c9'))
      box(c.entities, [0.13, -0.03, 0.1], [0, 0, 0], [0.15, 0.012, 0.015], metallo)
      [0.135, 0.265].each { |x| box(c.entities, [x, -0.022, 0.1], [0, 0, 0], [0.01, 0.022, 0.015], metallo) }
      anima(c, [tr('move_y', [k(0), k(L(-0.32), 0.9, curva)])], start: TOGGLE)
    end
    # portatile: tastiera e touchpad sulla base, coperchio con la cerniera dietro, schermo annidato
    grigio = mat('Laptop', '#adb5bd')
    base = wbox(ents, [1.75, 3.0, 0.75], [0.34, 0.24, 0.02], grigio, 'Laptop')
    tasti = mat('Keys', '#343a40')
    4.times do |riga|
      12.times { |col| wbox(base.entities, [0.025 + col * 0.0245, 0.115 + riga * 0.024, 0.02], [0.02, 0.019, 0.0006], tasti) }
    end
    wbox(base.entities, [0.11, 0.091, 0.02], [0.12, 0.019, 0.0006], tasti)
    wbox(base.entities, [0.12, 0.02, 0.02], [0.1, 0.06, 0.0005], mat('Touchpad', '#ced4da'))
    lid = box(ents, [1.75, 3.24, 0.7725], [0, -0.24, 0], [0.34, 0.24, 0.01], grigio, 'Laptop lid')
    schermo = box(lid.entities, [0.015, -0.225, -0.0015], [0, 0, 0], [0.31, 0.2, 0.0015], mat('Screen', '#101418'),
                  'Laptop screen')
    cyl(lid.entities, [0.17, -0.12, 0.01], 0.022, 0.0008, mat('Laptop logo', '#dee2e6'), nil, :z, 16)
    anima(lid, [tr('rot_x', [k(0), k(-105, 1.0, 'back')])], start: TOGGLE, pivot: 'origin')
    anima(schermo, [tr('color', [k('#101418'), k('#4cc9f0', 0.6, 'ease_out')])], start: dopo(lid, 0.1))
    # mappamondo inclinato verso la parete: gira sul suo asse, fra i perni del mezzo meridiano
    cm = [2.65, 3.22, 0.92]
    incl = -23.5
    sup = ents.add_group
    sup.name = 'Globe stand'
    tronco(sup.entities, [cm[0], cm[1], 0.75], 0.06, 0.04, 0.025, scuro)
    cyl(sup.entities, [cm[0], cm[1], 0.775], 0.007, 0.022, ottone, nil, :z, 12)
    arco = (0..16).map { |i| a = -Math::PI / 2 + Math::PI * i / 16; [0.125 * Math.cos(a), 0.125 * Math.sin(a)] }
    mer = profilo(sup.entities, arco + arco.reverse.map { |x, z| [x * 0.92, z * 0.92] }, -0.004, 0.008, ottone)
    mer.transform!(Geom::Transformation.rotation(ORIGIN, Z_AXIS, 90.degrees))      # nel piano YZ, dal lato della parete
    mer.transform!(Geom::Transformation.rotation(ORIGIN, X_AXIS, incl.degrees))
    sposta(mer, *cm)
    globo = sfera(ents, cm, 0.11, mat('Ocean', '#3a86ff'), 'Globe')
    terra = mat('Land', '#80b918')
    rnd = Random.new(7)
    globo.entities.grep(Sketchup::Face).each { |f| f.material = terra if rnd.rand < 0.35 }
    [-0.125, 0.11].each { |z| cyl(globo.entities, [0, 0, z], 0.005, 0.015, ottone, nil, :z, 8) }
    gira(globo, cm, :x, incl)
    anima(globo, [tr('rot_z', [k(0), k(360, 10.0, 'linear')], loop: 'loop')], pivot: 'center', axes: 'object')
    # luce notturna arcobaleno: facce dipinte una per una (faces), su un piedino
    tronco(ents, [2.255, 3.325, 0.75], 0.05, 0.04, 0.015, scuro, 'Night light base')
    luce = wbox(ents, [2.21, 3.28, 0.765], [0.09, 0.09, 0.09], nil, 'Night light')
    vetro = mat('Night light glass', '#ffffff')
    luce.entities.grep(Sketchup::Face).each { |f| f.material = vetro }
    arcob = %w[#ff595e #ffca3a #8ac926 #1982c4 #6a4c93 #ff595e]
    anima(luce, [tr('color', [k(arcob[0])] + arcob.drop(1).map { |c| k(c, 1.2, 'linear') }, loop: 'loop')], faces: true)
    sedia
  end

  # Portapenne cavo (pareti 3 mm, fondo 4 mm), con la base in `c`. Le quattro
  # matite poggiano sul fondo e si appoggiano al bordo dalla parte della
  # stanza (−Y): ognuna nel suo piano X, così non si attraversano. Un cerchio
  # disegnato sul piano di sopra non lo divide da solo: lo fa find_faces.
  def portapenne(ents, c)
    r, h, sp, fondo, rm = 0.035, 0.1, 0.003, 0.004, 0.004
    tazza = cyl(ents, c, r, h, mat('Pencil cup', '#e76f51'), nil, :z, 16)
    e = tazza.entities
    e.add_circle(P(0, 0, h), Z_AXIS, (r - sp).m, 16).first.find_faces
    bocca = e.grep(Sketchup::Face).find do |f|
      f.normal.z.abs > 0.99 && (f.bounds.min.z - h.m).abs < 1e-4 && f.bounds.width < (2 * r - sp).m
    end
    raise 'portapenne: il bordo non ha diviso il piano di sopra' unless bocca
    bocca.reverse! if bocca.normal.z < 0
    bocca.pushpull(-(h - fondo).m)
    appoggio = r - sp - rm - 0.0005                      # asse della matita all'altezza del bordo
    [['#ffbe0b', -0.017, 0.018, 0.165], ['#3a86ff', -0.0055, 0.024, 0.175],
     ['#8338ec', 0.0055, 0.024, 0.158], ['#06d6a0', 0.017, 0.018, 0.17]].each_with_index do |(colore, x, y, lungh), i|
      dy = -Math.sqrt(appoggio**2 - x**2) - y
      a = Math.atan2(-dy, h - fondo)
      matita = cyl(ents, nil, rm, lungh, mat("Pencil #{i + 1}", colore), nil, :z, 6)
      matita.transform!(Geom::Transformation.translation(P(c[0] + x, c[1] + y, c[2] + fondo)) *
                        Geom::Transformation.rotation(ORIGIN, X_AXIS, a))
    end
  end

  # Sedia girevole: base a cinque razze con le ruote, braccioli. Gira
  # attorno alla colonna (l'origine del gruppo): curva disegnata, avanti e indietro
  def sedia
    g = @model.entities.add_group
    g.name = 'Desk chair'
    se = g.entities
    blu = mat('Chair', '#3d5a80')
    met = mat('Metal', '#8d99ae')
    nero = mat('Black', '#222222')
    5.times do |i|
      gira(box(se, [0, 0, 0.03], [0, -0.02, 0], [0.26, 0.04, 0.025], met), [0, 0, 0], :z, 90 + i * 72)
      a = (90 + i * 72).degrees
      sfera(se, [0.25 * Math.cos(a), 0.25 * Math.sin(a), 0.025], 0.025, nero, nil, 12)
    end
    cyl(se, [0, 0, 0.03], 0.04, 0.03, met, nil, :z, 16)
    cyl(se, [0, 0, 0.06], 0.025, 0.33, met, nil, :z, 16)
    tronco(se, [0, 0, 0.39], 0.05, 0.12, 0.03, met)
    box(se, [0, 0, 0.42], [-0.22, -0.22, 0], [0.44, 0.44, 0.07], blu)
    box(se, [0, -0.25, 0.42], [-0.02, 0, 0], [0.04, 0.03, 0.12], met)
    box(se, [0, 0, 0.53], [-0.2, -0.27, 0], [0.4, 0.05, 0.38], blu)
    [-1, 1].each do |s|
      box(se, [s * 0.235, 0, 0.44], [-0.015, -0.05, 0], [0.03, 0.03, 0.22], nero)
      box(se, [s * 0.235, 0, 0.66], [-0.025, -0.16, 0], [0.05, 0.22, 0.025], nero)
    end
    sposta(g, 2.05, 2.45, 0)
    curva = [[0, 0], [0.2, 0.02], [0.45, 0.6], [0.7, 0.92], [1, 1]]
    anima(g, [tr('rot_z', [k(-25), k(25, 2.4, nil, curva)], loop: 'pingpong')], pivot: 'origin')
  end

  # ══════════════════════════════════════════════════════════════════
  # Armadio: dentro vestiti appesi, scatole e scarpe; le ante con le
  # specchiature e le maniglie
  # ══════════════════════════════════════════════════════════════════
  def armadio
    ents = @model.entities
    legno = mat('Wardrobe', '#dcc7a1')
    cimasa = mat('Wardrobe top', '#c9b28a')
    metallo = mat('Metal', '#8d99ae')
    g = ents.add_group
    g.name = 'Wardrobe'
    e = g.entities
    wbox(e, [3.0, 2.92, 0], [0.02, 0.56, 2.1], legno)
    wbox(e, [3.93, 2.92, 0], [0.02, 0.56, 2.1], legno)
    wbox(e, [3.02, 3.46, 0], [0.91, 0.02, 2.1], legno)
    wbox(e, [3.02, 2.92, 0], [0.91, 0.54, 0.06], legno)
    wbox(e, [3.02, 2.92, 2.06], [0.91, 0.54, 0.04], legno)
    wbox(e, [2.98, 2.89, 2.1], [0.99, 0.6, 0.04], cimasa)
    wbox(e, [3.02, 2.92, 1.72], [0.91, 0.54, 0.02], legno)
    cyl(e, [3.02, 3.2, 1.6], 0.01, 0.91, metallo, nil, :x, 12)
    %w[#e63946 #2a9d8f #f4a261 #6d597a #457b9d].each_with_index do |c, i|
      x = 3.1 + i * 0.16
      wbox(e, [x, 3.0, 0.75], [0.12, 0.4, 0.78], mat("Clothes #{i + 1}", c))
      wbox(e, [x - 0.01, 3.19, 1.53], [0.14, 0.02, 0.02], mat('Hanger', '#6c584c'))
      cyl(e, [x + 0.06, 3.2, 1.55], 0.003, 0.05, metallo, nil, :z, 6)
    end
    %w[#ffb4a2 #b5e48c #cdb4db].each_with_index do |c, i|
      scat = wbox(e, [3.08 + i * 0.28, 3.05, 1.74], [0.22, 0.3, 0.12], mat("Box #{i + 1}", c))
      wbox(scat.entities, [-0.004, -0.004, 0.09], [0.228, 0.308, 0.034], mat("Box lid #{i + 1}", c))
    end
    [3.1, 3.5].each { |x| wbox(e, [x, 3.05, 0.06], [0.25, 0.3, 0.1], mat('Shoe box', '#6c584c')) }
    anta    = mat('Wardrobe door', '#e9dcc0')
    rilievo = mat('Wardrobe panel', '#f3ead6')
    ottone  = mat('Brass', '#d4a72c')
    sx = box(ents, [3.005, 2.92, 0.06], [0, -0.025, 0], [0.47, 0.025, 2.0], anta, 'Wardrobe door L')
    dx = box(ents, [3.945, 2.92, 0.06], [-0.47, -0.025, 0], [0.47, 0.025, 2.0], anta, 'Wardrobe door R')
    [[sx, 0.0, 0.43], [dx, -0.47, -0.43]].each do |a, x0, xm|
      ae = a.entities
      [[0.12, 0.85], [1.07, 0.81]].each { |z, h| box(ae, [x0 + 0.07, -0.03, z], [0, 0, 0], [0.33, 0.005, h], rilievo) }
      box(ae, [xm, -0.05, 0.85], [-0.006, 0, 0], [0.012, 0.012, 0.3], ottone)
      [0.9, 1.09].each { |z| box(ae, [xm, -0.04, z], [-0.006, 0, 0], [0.012, 0.015, 0.012], ottone) }
    end
    anima(sx, [tr('rot_z', [k(0), k(-100, 1.0, 'back')])], start: TOGGLE, pivot: 'origin')
    anima(dx, [tr('rot_z', [k(0), k(100, 1.0, 'ease_in_out')])], start: dopo(sx, 0.1), pivot: 'origin')
  end

  # ══════════════════════════════════════════════════════════════════
  # Giochi sul pavimento, e la pianta
  # ══════════════════════════════════════════════════════════════════
  def giochi
    ents = @model.entities
    # torre di cubi: cadono uno dopo l'altro (catena «dopo un altro oggetto»); un pallino sulle facce in vista
    prima = nil
    pallino = mat('Block dot', '#ffffff')
    %w[#e63946 #f4a261 #e9c46a #2a9d8f #457b9d].each_with_index do |c, i|
      cubo = wbox(ents, [1.42, 0.55, i * 0.12], [0.12, 0.12, 0.12], mat("Block #{i + 1}", c), "Block #{i + 1}")
      cyl(cubo.entities, [0.06, -0.002, 0.06], 0.03, 0.002, pallino, nil, :y, 16)
      cyl(cubo.entities, [0.12, 0.06, 0.06], 0.03, 0.002, pallino, nil, :x, 16)
      tracce = [tr('visible', [k(0), k(1, 0.01, 'linear')]),
                tr('move_z', [k(L(1.2)), k(0, 0.9, 'bounce')])]
      if prima
        anima(cubo, tracce, start: dopo(prima, 0.1))
      else
        tracce.each { |t| t['delay'] = 1.0 }
        anima(cubo, tracce)
      end
      prima = cubo
    end
    # palla che rimbalza, a sei spicchi
    palla = sfera(ents, [1.7, 1.15, 0.1], 0.1, mat('Ball', '#ffffff'), 'Ball')
    spicchi = [mat('Ball red', '#d62828'), nil, mat('Ball blue', '#1d3557'), nil, mat('Ball yellow', '#ffbe0b'), nil]
    palla.entities.grep(Sketchup::Face).each do |f|
      c = f.bounds.center
      m = spicchi[((Math.atan2(c.y, c.x) + Math::PI) / (2 * Math::PI) * 6).floor % 6]
      f.material = m if m
    end
    anima(palla, [tr('move_z', [k(L(0.9)), k(0, 1.8, 'bounce'), k(0, 0.8, 'linear'), k(L(0.9), 0.7, 'ease_out')],
                     loop: 'loop')])
    macchinina
    trottola
    cavallo
    scatola
    # pianta che cresce, dopo un'attesa: vaso, orlo, terra e sottovaso restano fermi
    cotto = mat('Pot', '#e07a5f')
    vaso = ents.add_group
    vaso.name = 'Plant pot'
    ve = vaso.entities
    tronco(ve, [3.72, 2.5, 0], 0.13, 0.13, 0.015, cotto)
    tronco(ve, [3.72, 2.5, 0.015], 0.085, 0.11, 0.16, cotto)
    tronco(ve, [3.72, 2.5, 0.175], 0.12, 0.12, 0.025, cotto)
    cyl(ve, [3.72, 2.5, 0.2], 0.105, 0.003, mat('Soil', '#5c4033'))
    pianta = ents.add_group
    pianta.name = 'Plant'
    verde  = mat('Leaves', '#52b788')
    verde2 = mat('Leaves dark', '#2d6a4f')
    fiore  = mat('Flower', '#ff8fab')
    pe = pianta.entities
    cyl(pe, [0, 0, 0], 0.012, 0.28, mat('Stem', '#6f4e37'), nil, :z, 8)
    [[0, 0, 0.36, 0.12, verde], [0.07, 0.03, 0.24, 0.09, verde2], [-0.07, -0.02, 0.27, 0.09, verde],
     [0.02, -0.07, 0.3, 0.08, verde2], [-0.02, 0.07, 0.3, 0.08, verde]].each do |x, y, z, r, m|
      sfera(pe, [x, y, z], r, m, nil, 16)
    end
    [[0.06, -0.06, 0.4], [-0.07, 0.03, 0.38], [0.0, 0.02, 0.475]].each { |p| sfera(pe, p, 0.02, fiore, nil, 8) }
    sposta(pianta, 3.72, 2.5, 0.2)
    anima(pianta, [tr('size_z', [k(L(0.06)), k(L(0.495), 5.0, 'ease_out')], delay: 1.5)])
  end

  # Macchinina: giro del tappeto (posizioni assolute), rettilinei e curve ad
  # arco di cerchio. In curva il muso segue la strada: la rotazione avanza
  # in modo lineare e intanto una coordinata va come il seno e l'altra come
  # 1 − coseno (due curve disegnate), così non slitta di lato; girare sul
  # posto, ferma, una macchina non può. Fari, luci e paraurti sporgono
  # uguali davanti e dietro, le ruote ai lati: la base (il riferimento della
  # posizione) resta al centro.
  def macchinina
    auto = @model.entities.add_group
    auto.name = 'Toy car'
    ae = auto.entities
    giallo = mat('Car', '#ffbe0b')
    vetro  = mat('Car glass', '#90e0ef')
    gomme  = mat('Tyre', '#2b2d42')
    cerchi = mat('Hubcap', '#dee2e6')
    met    = mat('Metal', '#8d99ae')
    box(ae, [0, 0, 0.02], [-0.12, -0.06, 0], [0.24, 0.12, 0.04], giallo)
    # abitacolo: tronco di piramide con i vetri sui fianchi e il tetto giallo
    cab = tronco(ae, [-0.01, 0, 0.06], 0.071, 0.052, 0.042, nil, nil, true, 4)
    cab.entities.grep(Sketchup::Face).each { |f| f.material = f.normal.z.abs > 0.9 ? giallo : vetro }
    gira(cab, [-0.01, 0, 0.06], :z, 45)
    [[-0.075, -0.07], [0.075, -0.07], [-0.075, 0.055], [0.075, 0.055]].each do |x, y|
      cyl(ae, [x, y, 0.025], 0.025, 0.015, gomme, nil, :y, 16)
      cyl(ae, [x, y < 0 ? y - 0.001 : y + 0.015, 0.025], 0.012, 0.001, cerchi, nil, :y, 12)
    end
    [[0.12, mat('Headlight', '#fff3b0')], [-0.124, mat('Tail light', '#d00000')]].each do |x, m|
      [-0.045, 0.03].each { |y| box(ae, [x, y, 0.04], [0, 0, 0], [0.004, 0.015, 0.012], m) }
    end
    [0.115, -0.125].each { |x| box(ae, [x, -0.062, 0.02], [0, 0, 0], [0.01, 0.124, 0.012], met) }
    # il giro: un rettangolo x 2,05–3,1 · y 0,8–1,75 con gli angoli di raggio rc;
    # parte dall'inizio del rettilineo davanti, verso +X
    rc = 0.25
    xa, xb, xc, xd = L(2.05), L(2.05 + rc), L(3.1 - rc), L(3.1)
    ya, yb, yc, yd = L(0.8), L(0.8 + rc), L(1.75 - rc), L(1.75)
    sposta(auto, 2.05 + rc, 0.8, 0.008)
    tx, ty, tc = 1.1, 0.9, 0.8                        # rettilinei a 0,5 m/s, le curve appena più piano
    quarto = ->(f) { [[0, 0]] + (1..7).map { |i| [i / 8.0, f.(i * Math::PI / 16).round(4)] } + [[1, 1]] }
    seno   = quarto.(->(a) { Math.sin(a) })           # rallenta fino a fermarsi: la coordinata lungo cui arrivava
    coseno = quarto.(->(a) { 1 - Math.cos(a) })       # parte da ferma e accelera: quella lungo cui ripartirà
    xs = [k(xb), k(xc, tx, 'linear'), k(xd, tc, nil, seno), k(xd, ty, 'linear'), k(xc, tc, nil, coseno),
          k(xb, tx, 'linear'), k(xa, tc, nil, seno), k(xa, ty, 'linear'), k(xb, tc, nil, coseno)]
    ys = [k(ya), k(ya, tx, 'linear'), k(yb, tc, nil, coseno), k(yc, ty, 'linear'), k(yd, tc, nil, seno),
          k(yd, tx, 'linear'), k(yc, tc, nil, coseno), k(yb, ty, 'linear'), k(ya, tc, nil, seno)]
    rz = [k(0), k(0, tx, 'linear'), k(90, tc, 'linear'), k(90, ty, 'linear'), k(180, tc, 'linear'),
          k(180, tx, 'linear'), k(270, tc, 'linear'), k(270, ty, 'linear'), k(360, tc, 'linear')]
    anima(auto, [tr('pos_x', xs, loop: 'loop'), tr('pos_y', ys, loop: 'loop'), tr('rot_z', rz, loop: 'loop')])
  end

  # Trottola inclinata: gira attorno alla verticale del mondo, sulla punta
  def trottola
    t = @model.entities.add_group
    t.name = 'Spinning top'
    te = t.entities
    giallo = mat('Top yellow', '#ffd60a')
    rossa  = mat('Top red', '#d00000')
    blu    = mat('Top blue', '#3a86ff')
    n = 16
    giro = ->(r, z) { (0...n).map { |i| a = 2 * Math::PI * i / n; P(r * Math.cos(a), r * Math.sin(a), z) } }
    basso = giro.(0.065, 0.065)
    alto  = giro.(0.05, 0.09)
    n.times do |i|
      j = (i + 1) % n
      spicchio = te.add_face(P(0, 0, 0.005), basso[i], basso[j])
      spicchio.material = spicchio.back_material = i.even? ? giallo : rossa
      fascia = te.add_face(basso[i], basso[j], alto[j], alto[i])
      fascia.material = fascia.back_material = blu
    end
    tappo = te.add_face(alto)
    tappo.material = tappo.back_material = giallo
    cyl(te, [0, 0, 0], 0.004, 0.006, mat('Metal', '#8d99ae'), nil, :z, 8)
    cyl(te, [0, 0, 0.09], 0.007, 0.05, rossa, nil, :z, 12)
    sfera(te, [0, 0, 0.142], 0.01, rossa, nil, 12)
    t.transform!(Geom::Transformation.rotation(ORIGIN, X_AXIS, 12.degrees))
    sposta(t, 2.58, 1.28, 0.008)
    anima(t, [tr('rot_z', [k(0), k(360, 0.9, 'linear')], loop: 'loop')], axes: 'world')
  end

  # Cavallo a dondolo: i pattini sono archi di raggio r con il centro in
  # alto, nell'origine del gruppo. Dondolare è rotolare sui pattini: il
  # cavallo ruota attorno a quel centro (riferimento «origine») e intanto il
  # centro avanza di r × angolo, così il punto che tocca terra non striscia.
  # Con la sola rotazione oscillerebbe come un pendolo appeso lassù, con i
  # pattini che scivolano sul pavimento. Le due tracce hanno la stessa
  # durata e la stessa curva: restano in passo a ogni istante. Qui le
  # altezze si scrivono da terra: zl le porta nelle coordinate del gruppo.
  def cavallo
    r = 0.6
    zl = ->(h) { h - r }
    cav = @model.entities.add_group
    cav.name = 'Rocking horse'
    ce = cav.entities
    legno  = mat('Horse', '#bc6c25')
    chiaro = mat('Horse light', '#dda15e')
    crine  = mat('Mane', '#283618')
    rosso  = mat('Saddle', '#9d0208')
    nero   = mat('Black', '#222222')
    arco = (0..20).map { |i| a = -0.42 + 0.84 * i / 20; [r * Math.sin(a), -r * Math.cos(a)] }
    pattino = arco + arco.reverse.map { |x, z| [x * 0.95, z * 0.95] }
    [-0.09, 0.07].each do |y|
      profilo(ce, pattino, y, 0.02, chiaro)
      # gambe e traversa 2 mm più dentro dei pattini: con i fianchi sugli
      # stessi piani dei pattini, nelle giunture le facce sfarfallavano
      yg = y < 0 ? y + 0.002 : y - 0.002
      [-0.13, 0.105].each { |x| box(ce, [x, yg, zl.(0.025)], [0, 0, 0], [0.025, 0.02, 0.275], legno) }
      box(ce, [-0.105, yg, zl.(0.1)], [0, 0, 0], [0.21, 0.02, 0.015], chiaro)
    end
    box(ce, [0, 0, zl.(0.115)], [-0.02, -0.12, 0], [0.04, 0.24, 0.015], chiaro)          # poggiapiedi
    box(ce, [0, 0, zl.(0.25)], [-0.15, -0.07, 0], [0.3, 0.14, 0.12], legno)             # corpo
    box(ce, [0, 0, zl.(0.37)], [-0.07, -0.075, 0], [0.13, 0.15, 0.015], rosso)          # sella
    [-0.075, 0.07].each { |y| box(ce, [0, y, zl.(0.31)], [-0.05, 0, 0], [0.09, 0.005, 0.06], rosso) }
    profilo(ce, [[-0.15, zl.(0.36)], [-0.2, zl.(0.37)], [-0.24, zl.(0.3)], [-0.23, zl.(0.18)], [-0.19, zl.(0.28)],
                 [-0.15, zl.(0.31)]], -0.012, 0.024, crine)                               # coda
    # collo con la criniera, inclinato in avanti
    collo = ce.add_group
    box(collo.entities, [0, 0, 0], [0, -0.035, 0], [0.07, 0.07, 0.21], legno)
    box(collo.entities, [0, 0, 0], [-0.015, -0.012, 0.03], [0.015, 0.024, 0.19], crine)
    collo.transform!(Geom::Transformation.translation(P(0.1, 0, zl.(0.33))) *
                     Geom::Transformation.rotation(ORIGIN, Y_AXIS, 22.degrees))
    # testa: muso, occhi, orecchie, ciuffo e il manubrio
    testa = ce.add_group
    te = testa.entities
    box(te, [0, 0, 0], [-0.045, -0.0375, -0.02], [0.15, 0.075, 0.085], legno)
    box(te, [0, 0, 0], [0.105, -0.03, -0.02], [0.03, 0.06, 0.055], chiaro)
    box(te, [0, 0, 0], [-0.045, -0.012, 0.065], [0.06, 0.024, 0.015], crine)
    [-0.0375, 0.0375].each { |y| sfera(te, [0.05, y, 0.04], 0.009, nero, nil, 8) }
    [-0.022, 0.022].each { |y| tronco(te, [-0.02, y, 0.065], 0.013, 0.003, 0.04, legno, nil, true, 8) }
    cyl(te, [0.01, -0.1, 0.01], 0.008, 0.2, mat('Metal', '#8d99ae'), nil, :y, 8)
    [-0.1, 0.1].each { |y| sfera(te, [0.01, y, 0.01], 0.013, rosso, nil, 8) }
    testa.transform!(Geom::Transformation.translation(P(0.2, 0, zl.(0.5))) *
                     Geom::Transformation.rotation(ORIGIN, Y_AXIS, 20.degrees))
    # davanti al tappeto (che comincia a y 0,55): dondolando i pattini non gli
    # passano sopra, e il muso in avanti resta dentro il pavimento (x 4)
    sposta(cav, 3.55, 0.42, r)
    gradi = 9
    passo = L(r * gradi * Math::PI / 180)            # strada del centro dei pattini: r × angolo in radianti
    anima(cav, [tr('rot_y', [k(-gradi), k(gradi, 1.3, 'ease_in_out')], loop: 'pingpong'),
                tr('move_x', [k(-passo), k(passo, 1.3, 'ease_in_out')], loop: 'pingpong')], pivot: 'origin')
  end

  # Scatola a sorpresa: il coperchio riparte da capo a ogni clic; dietro di
  # lui la molla si allunga dalla base e il pupazzo sale della stessa misura
  # (stessa durata, stessa curva: restano attaccati anche nei rimbalzi).
  def scatola
    ents = @model.entities
    blu    = mat('Box blue', '#4361ee')
    giallo = mat('Box trim', '#ffd60a')
    viola  = mat('Clown hat', '#7209b7')
    met    = mat('Metal', '#8d99ae')
    sc = vasca(ents, [3.55, 1.55, 0], [0.25, 0.25, 0.25], 0.02, 0.02, blu, 'Jack-in-the-box')
    se = sc.entities
    [0.0, 0.235].each do |z|                               # fasce in basso e in alto, attorno
      box(se, [0, 0, z], [-0.005, -0.005, 0], [0.26, 0.005, 0.015], giallo)
      box(se, [0, 0, z], [-0.005, 0.25, 0], [0.26, 0.005, 0.015], giallo)
      box(se, [0, 0, z], [-0.005, 0, 0], [0.005, 0.25, 0.015], giallo)
      box(se, [0, 0, z], [0.25, 0, 0], [0.005, 0.25, 0.015], giallo)
    end
    [[0.07, 0.08], [0.16, 0.15], [0.1, 0.18], [0.19, 0.06]].each { |x, z| cyl(se, [x, -0.002, z], 0.018, 0.002, giallo, nil, :y, 12) }
    cyl(se, [0.25, 0.125, 0.12], 0.012, 0.03, met, nil, :x, 12)          # manovella sul fianco
    box(se, [0.28, 0.115, 0.06], [0, 0, 0], [0.01, 0.02, 0.07], met)
    cyl(se, [0.29, 0.125, 0.065], 0.012, 0.035, viola, nil, :x, 12)
    coperchio = box(ents, [3.55, 1.8, 0.25], [0, -0.25, 0], [0.25, 0.25, 0.015], mat('Box lid', '#f72585'),
                    'Jack-in-the-box lid')
    cyl(coperchio.entities, [0.125, -0.125, 0.015], 0.04, 0.004, giallo, nil, :z, 16)
    anima(coperchio, [tr('rot_x', [k(0), k(-115, 0.5, 'back')])], start: PLAY, pivot: 'origin')
    molla = ents.add_group
    molla.name = 'Clown spring'
    cyl(molla.entities, [0, 0, 0], 0.008, 0.1, met, nil, :z, 8)
    5.times { |i| cyl(molla.entities, [0, 0, 0.01 + i * 0.018], 0.03, 0.006, met, nil, :z, 16) }
    sposta(molla, 3.675, 1.675, 0.02)
    anima(molla, [tr('size_z', [k(L(0.1)), k(L(0.27), 1.0, 'elastic')])], start: dopo(coperchio))
    pupazzo = ents.add_group
    pupazzo.name = 'Clown'
    pe = pupazzo.entities
    tronco(pe, [0, 0, 0], 0.065, 0.03, 0.02, mat('Clown ruff', '#ffd60a'), nil, true, 16)
    sfera(pe, [0, 0, 0.06], 0.05, mat('Clown face', '#ffe5d9'), nil, 16)
    sfera(pe, [0, -0.05, 0.062], 0.012, mat('Clown nose', '#d00000'), nil, 12)
    [-0.018, 0.018].each { |x| sfera(pe, [x, -0.043, 0.078], 0.007, mat('Black', '#222222'), nil, 8) }
    [-0.05, 0.05].each { |x| sfera(pe, [x, 0, 0.07], 0.018, mat('Clown hair', '#f77f00'), nil, 8) }
    tronco(pe, [0, 0, 0.095], 0.035, 0.003, 0.024, viola, nil, true, 16)
    sposta(pupazzo, 3.675, 1.675, 0.12)
    anima(pupazzo, [tr('move_z', [k(0), k(L(0.17), 1.0, 'elastic')])], start: dopo(coperchio))
  end

  # Interruttore sulla parete sinistra: il piano di sezione scende e taglia la stanza
  def sezione
    ents = @model.entities
    wbox(ents, [0, 1.42, 1.12], [0.01, 0.12, 0.12], mat('Trim', '#fbfaf7'), 'Switch plate')
    tasto = wbox(ents, [0.01, 1.45, 1.15], [0.025, 0.06, 0.06], mat('Switch', '#e63946'), 'Section switch')
    anima(tasto, [tr('move_x', [k(0), k(L(-0.012), 0.15, 'ease_out')])], start: TOGGLE)
    sp = ents.add_section_plane([P(2.0, 1.75, 3.0), Geom::Vector3d.new(0, 0, -1)])
    sp.name = 'Section plane' if sp.respond_to?(:name=)
    sp.activate
    anima(sp, [tr('move_z', [k(0), k(L(-1.95), 2.5, 'ease_in_out')])], start: dopo(tasto, 0.1))
    ro = @model.rendering_options
    ro['DisplaySectionPlanes'] = false
    ro['DisplaySectionCuts'] = true
  end

  def vista
    cam = Sketchup::Camera.new(P(6.2, -3.6, 3.6), P(1.9, 1.8, 0.8), Z_AXIS)
    cam.fov = 38
    @model.active_view.camera = cam
    @model.description = 'DagaDyn example: a bedroom where everything moves. ' \
                         'Press Play, then pick the Use tool and click the door, the drawers, the lamp…'
  end
end
