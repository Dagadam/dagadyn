# DagaDyn — Costruisce l'esempio examples/formulas.skp: transizioni a formula
# e oggetti che si leggono l'un l'altro. Gira dentro SketchUp, con DagaDyn
# caricata, in un modello NUOVO:
#
#   ruby tools/crea_esempio.rb formulas           (dal ponte di DagaWASD: costruisce e salva)
#   load 'I:/…/tools/esempio_formule.rb'; DagaDynFormule.costruisci   (Console Ruby)
#
# I nomi degli oggetti sono in inglese (il modello è per tutti). Le formule
# lavorano nell'unità del modello: qui metri (costruisci la imposta).
#
#   1 Cube → 2 Slab → 3 Blade      in serie: altezza del cubo (pallini) → larghezza della lastra
#                                  `0.2 + K` → rotazione della pala `(L - 0.8) * 120`
#   Elevator → Counterweight,      il contrappeso legge il valore (`-H`: va al contrario), la barra
#              Progress bar        l'avanzamento 0–1 della transizione (`0.05 + 2 * P`: regolare
#                                  anche se l'ascensore accelera e frena)
#   Pendulum                       solo la formula: `30 * sin(180 * t)`, seno in gradi
#   Wave 1…6                       la stessa formula sfasata: `0.3 + 0.3 * sin(180 * t - 45 * i)`
#
# Le transizioni a formula sono in ciclo: rifatte a ogni giro, seguono
# finché la timeline gira (finita una formula, l'oggetto resterebbe fermo).
module DagaDynFormule
  module_function

  LIN = [[0.0, 0.0], [1.0, 1.0]].freeze

  def P(*xyz) = Geom::Point3d.new(*xyz.map { |v| v.to_f.m })

  def mat(nome, rgb)
    m = @model.materials[nome] || @model.materials.add(nome)
    m.color = Sketchup::Color.new(*rgb)
    m
  end

  # Scatola: angolo (x, y, z) del contenitore, misure (w, d, h) in metri;
  # off sposta la geometria rispetto all'origine del gruppo (il perno
  # «Origine dell'oggetto» del pendolo sta in cima alla sbarra).
  def box(nome, at, size, m, off: [0, 0, 0])
    w, d, h = size
    ox, oy, oz = off
    g = @ents.add_group
    f = g.entities.add_face(P(ox, oy, oz), P(ox + w, oy, oz), P(ox + w, oy + d, oz), P(ox, oy + d, oz))
    f.reverse! if f.normal.z < 0
    f.pushpull(h.m)
    g.transform!(Geom::Transformation.translation(P(*at)))
    g.name = nome
    g.material = m
    g
  end

  def key(v, dur, preset = 'linear')
    { 'v' => v, 'dur' => dur, 'preset' => preset, 'curve' => DagaDyn::Dyn.preset_points(preset) }
  end

  def fx(v0, dur, expr, params = [])
    { 'v' => v0, 'dur' => dur, 'preset' => 'linear', 'curve' => LIN,
      'fx' => { 'on' => true, 'expr' => expr, 'params' => params } }
  end

  def par(n, e, prop, at = 0) = { 'n' => n, 'pid' => e.persistent_id, 'prop' => prop, 'at' => at }
  def track(prop, loop, keys) = { 'prop' => prop, 'loop' => loop, 'keys' => keys }

  def label(text, y) = @ents.add_text(text, P(-1.2, y + 0.3, 0))

  def costruisci(op: true)
    @model = Sketchup.active_model
    @ents = @model.entities
    d = DagaDyn::Dyn
    data = {}
    @model.start_operation('DagaDyn formulas example', true) if op
    @ents.clear!                             # via la figura del modello di partenza
    uo = @model.options['UnitsOptions']
    uo['LengthFormat'] = 0                   # decimale
    uo['LengthUnit'] = 4                     # metri: le formule sono scritte in metri
    rosso  = mat('Formula red',    [220, 80, 70])
    blu    = mat('Formula blue',   [70, 130, 220])
    verde  = mat('Formula green',  [80, 180, 110])
    giallo = mat('Formula yellow', [235, 190, 60])
    grigio = mat('Formula grey',   [150, 150, 155])
    legno  = mat('Formula frame',  [120, 95, 75])
    pav    = mat('Formula floor',  [225, 225, 220])

    floor = box('Floor', [-1.5, -1.5, -0.02], [10.5, 15, 0.02], pav)
    floor.locked = true

    # 1 — In serie: Cube → Slab → Blade
    label('1 · In series: Cube → Slab → Blade', 0)
    cube  = box('1 Cube', [0, 0, 0], [0.6, 0.6, 0.6], rosso)
    slab  = box('2 Slab', [2, 0, 0], [1, 0.6, 0.1], blu)
    blade = box('3 Blade', [5.5, 0.2, 0], [2, 0.2, 0.1], verde)
    data[cube]  = { 'tracks' => [track('size_z', 'pingpong', [{ 'v' => 0.6.m }, key(2.m, 3.0, 'ease_in_out')])] }
    data[slab]  = { 'tracks' => [track('size_x', 'loop', [{ 'v' => 1.m }, fx(1.m, 6.0, '0.2 + K', [par('K', cube, 'size_z')])])] }
    data[blade] = { 'pivot' => 'center',
                    'tracks' => [track('rot_z', 'loop', [{ 'v' => 0 }, fx(0, 6.0, '(L - 0.8) * 120', [par('L', slab, 'size_x')])])] }

    # 2 — Elevator: value and progress
    label('2 · Elevator, counterweight, progress bar', 4)
    elev  = box('Elevator', [0, 4, 0], [0.8, 0.8, 0.8], giallo)
    cw    = box('Counterweight', [1.5, 4.2, 3], [0.4, 0.4, 0.8], grigio)
    bar   = box('Progress bar', [3, 4.3, 0], [0.05, 0.2, 0.05], verde)
    data[elev] = { 'tracks' => [track('move_z', 'pingpong', [{ 'v' => 0 }, key(3.m, 4.0, 'ease_in_out')])] }
    data[cw]   = { 'tracks' => [track('move_z', 'loop', [{ 'v' => 0 }, fx(0, 8.0, '-H', [par('H', elev, 'move_z')])])] }
    data[bar]  = { 'pivot' => 'min',
                   'tracks' => [track('size_x', 'loop', [{ 'v' => 0.05.m }, fx(0.05.m, 8.0, '0.05 + 2 * P', [par('P', elev, 'move_z', 1)])])] }

    # 3 — Pendulum: a formula alone, hanging from a frame
    label('3 · Pendulum: 30 * sin(180 * t)', 8)
    box('Frame post', [0.95, 7.3, 0], [0.1, 0.1, 2.6], legno)
    box('Frame post', [0.95, 8.6, 0], [0.1, 0.1, 2.6], legno)
    box('Frame beam', [0.95, 7.3, 2.6], [0.1, 1.4, 0.1], legno)
    pend = box('Pendulum', [1.0, 8.0, 2.6], [0.1, 0.1, 2.0], rosso, off: [-0.05, -0.05, -2.0])
    data[pend] = { 'pivot' => 'origin',
                   'tracks' => [track('rot_y', 'loop', [{ 'v' => 0 }, fx(0, 2.0, '30 * sin(180 * t)')])] }

    # 4 — Wave: one formula, shifted by 45° from block to block
    label('4 · Wave: 0.3 + 0.3 * sin(180 * t - 45 * i)', 11)
    6.times do |i|
      b = box("Wave #{i + 1}", [i * 0.6, 11, 0], [0.4, 0.4, 0.4], i.even? ? blu : verde)
      data[b] = { 'tracks' => [track('move_z', 'loop', [{ 'v' => 0 }, fx(0, 2.0, "0.3 + 0.3 * sin(180 * t - #{45 * i})")])] }
    end

    data.each { |e, x| d.write_data(e, x) }
    cam = Sketchup::Camera.new(P(12, -9, 9), P(3.5, 5.5, 0.6), Z_AXIS)
    @model.active_view.camera = cam
    @model.active_view.zoom_extents
    @model.commit_operation if op
    data.size
  rescue => err
    @model.abort_operation if op
    raise err
  end
end
