# DagaDyn — Proprietà: valori di riposo, trasformazione, materiali temporanei.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    # ══════════════════════════════════════════════════════════════
    # Riposo = lo stato dell'oggetto nel modello, quando nulla si anima
    # (base_of: trasformazione, materiale, nascosto, tag, piano di sezione).
    # La trasformazione animata non si accumula mai: a ogni fotogramma si
    # ricalcola da quella di riposo R0,
    #
    #   T = Trasla(P − P0 + spostamento) · Rz · Ry · Rx · R0 · Scala(pivot locale)
    #
    # 1. Scala: dimensioni (e scala uniforme) lungo gli assi propri
    #    dell'oggetto, attorno al punto di riferimento (pivot) nelle
    #    coordinate della definizione: quel punto resta fermo, così
    #    un'altezza che cresce col pivot "base" cresce verso l'alto.
    # 2. R0: la posizione dell'oggetto nel modello.
    # 3. Rotazioni passanti per il pivot (P0 = R0 · pivot), attorno agli assi
    #    di riposo dell'oggetto o a quelli del contenitore ("axes": "world").
    #    Prima X, poi Y, poi Z.
    # 4. Traslazione: il pivot va nella posizione animata P, più lo
    #    spostamento relativo (move_x/y/z).
    #
    # Posizioni e assi sono nel sistema del contenitore dell'oggetto (il
    # modello, o il gruppo in cui sta).
    # ══════════════════════════════════════════════════════════════

    def self.unit_info(model)
      u = (model.options['UnitsOptions']['LengthUnit'] rescue 4).to_i
      label, factor = UNITS[u] || UNITS[4]
      { 'label' => label, 'factor' => factor }
    end

    # Trasformazione come matrice con w = 1 (SketchUp può tenere una scala
    # uniforme nel termine omogeneo): assi (con la loro scala) e origine.
    def self.affine(tr)
      a = tr.to_a
      w = a[15].to_f
      w = 1.0 if w.abs < 1e-12
      a = a.map { |v| v / w }
      { x: Geom::Vector3d.new(a[0], a[1], a[2]), y: Geom::Vector3d.new(a[4], a[5], a[6]),
        z: Geom::Vector3d.new(a[8], a[9], a[10]), o: Geom::Point3d.new(a[12], a[13], a[14]) }
    end

    def self.local_pivot(bb, pivot)
      return ORIGIN.clone if bb.empty? || pivot == 'origin'
      case pivot
      when 'center' then bb.center
      when 'min'    then bb.min
      else Geom::Point3d.new(bb.center.x, bb.center.y, bb.min.z)
      end
    end

    def self.face_front_color(model)
      c = model.rendering_options['FaceFrontColor'] rescue nil
      c ? rgb_hex([c.red, c.green, c.blue]) : '#ffffff'
    end

    def self.layer_name(e)
      e.layer ? e.layer.name.to_s : ''
    end

    # Lo stato di progetto di un oggetto: va fotografato prima di animarlo.
    def self.base_of(e)
      if section?(e)
        { section: true, plane: e.get_plane, hidden: e.hidden?, layer: e.layer, material: nil, tr: nil }
      else
        { tr: e.transformation, material: e.material, hidden: e.hidden?, layer: e.layer }
      end
    end

    # Tutto ciò che serve per animare l'oggetto a partire dal suo riposo.
    # Durante una sessione l'oggetto è animato: va passato il riposo
    # fotografato all'inizio (base).
    def self.rest_for(e, data, base = base_of(e))
      return section_rest(base) if base[:section]
      rest_info(e, data['pivot'], base[:tr], base[:material], data['axes'] == 'world', base)
    end

    def self.section_rest(base)
      vals = { 'move_x' => 0.0, 'move_y' => 0.0, 'move_z' => 0.0, 'visible' => base[:hidden] ? 0.0 : 1.0 }
      { section: true, plane: base[:plane], values: vals, material: nil, base: base }
    end

    def self.rest_info(e, pivot, tr = e.transformation, mat = e.material, world = false, base = nil)
      bb  = e.definition.bounds
      af  = affine(tr)
      s0  = [af[:x].length.to_f, af[:y].length.to_f, af[:z].length.to_f]
      axes = [af[:x], af[:y], af[:z]].each_with_index.map do |v, i|
        s0[i] > 1e-12 ? Geom::Vector3d.new(v.x / s0[i], v.y / s0[i], v.z / s0[i]) : [X_AXIS, Y_AXIS, Z_AXIS][i]
      end
      pl  = local_pivot(bb, pivot)
      p0  = pl.transform(tr)
      dims = bb.empty? ? [0.0, 0.0, 0.0] : [bb.width.to_f, bb.height.to_f, bb.depth.to_f]
      size0 = dims.each_with_index.map { |d, i| d * s0[i] }
      hidden = base ? base[:hidden] : e.hidden?
      layer  = base ? base[:layer] : e.layer
      vals = {
        'pos_x' => p0.x.to_f, 'pos_y' => p0.y.to_f, 'pos_z' => p0.z.to_f,
        'move_x' => 0.0, 'move_y' => 0.0, 'move_z' => 0.0,
        'rot_x' => 0.0, 'rot_y' => 0.0, 'rot_z' => 0.0,
        'size_x' => size0[0], 'size_y' => size0[1], 'size_z' => size0[2],
        'scale' => 1.0,
        'color' => mat ? rgb_hex([mat.color.red, mat.color.green, mat.color.blue]) : face_front_color(e.model),
        'opacity' => mat ? mat.alpha.to_f : 1.0,
        'visible' => hidden ? 0.0 : 1.0,
        'tag' => layer ? layer.name.to_s : ''
      }
      { tr: tr, pl: pl, p0: p0, axes: axes, world: world, size0: size0, center: bb.empty? ? pl : bb.center,
        values: vals, material: mat, base: base }
    end

    # Trasformazione per i valori animati v (le proprietà che mancano
    # restano a riposo).
    def self.compose(rest, v)
      rv = rest[:values]
      g  = ->(k) { v.key?(k) ? v[k] : rv[k] }
      sc = g.call('scale')
      f  = (0..2).map do |i|
        k  = %w[size_x size_y size_z][i]
        s0 = rest[:size0][i]
        (s0 > 1e-9 ? g.call(k) / s0 : 1.0) * sc
      end
      f = f.map { |x| x.abs < 1e-6 ? (x.negative? ? -1e-6 : 1e-6) : x }
      t = rest[:tr]
      t = t * Geom::Transformation.scaling(rest[:pl], f[0], f[1], f[2]) unless f.all? { |x| (x - 1.0).abs < 1e-12 }
      p0 = rest[:p0]
      axes = rest[:world] ? [X_AXIS, Y_AXIS, Z_AXIS] : rest[:axes]
      %w[rot_x rot_y rot_z].each_with_index do |k, i|
        a = g.call(k)
        next if a.abs < 1e-9
        t = Geom::Transformation.rotation(p0, axes[i], a.degrees) * t
      end
      d = Geom::Vector3d.new(g.call('pos_x') - p0.x + g.call('move_x'),
                             g.call('pos_y') - p0.y + g.call('move_y'),
                             g.call('pos_z') - p0.z + g.call('move_z'))
      t = Geom::Transformation.translation(d) * t if d.length > 1e-9
      t
    end

    # Piano di sezione [a, b, c, d] (a·x + b·y + c·z + d = 0) spostato del
    # vettore m: d' = d − n·m.
    def self.compose_plane(rest, v)
      a, b, c, d = rest[:plane]
      mx = v['move_x'] || 0.0
      my = v['move_y'] || 0.0
      mz = v['move_z'] || 0.0
      [a, b, c, d - (a * mx + b * my + c * mz)]
    end

    # Spostamento senza voce di annullamento (move!): è fatto apposta per
    # le animazioni. Lo stato di riposo si ripristina allo stesso modo.
    def self.place(e, tr)
      e.respond_to?(:move!) ? e.move!(tr) : e.transformation = tr
    end

    def self.layer_by_name(model, name)
      return nil if name.nil?
      model.layers[name] || (name.empty? ? model.layers[0] : nil)
    rescue
      nil
    end

    # ── Materiali temporanei ─────────────────────────────────────────
    # Colore e opacità si animano su una copia del materiale dell'oggetto,
    # che sostituisce l'originale per la durata della sessione: cambiare
    # l'originale cambierebbe tutti gli oggetti che lo usano. Va chiamata
    # dentro un'operazione.
    def self.clone_material(model, orig, name)
      m = model.materials.add(name)
      return m unless orig
      m.color = orig.color
      m.alpha = orig.alpha
      if orig.texture && m.respond_to?(:texture=)
        begin
          m.texture = orig.texture.image_rep
          m.texture.size = [orig.texture.width, orig.texture.height]
        rescue => dyn_err
          log_error(__method__, dyn_err)
        end
      end
      m
    end

    def self.temp_material(e, rest)
      orig = rest[:material]
      m = clone_material(e.model, orig, "#{TEMP_MAT}#{e.persistent_id}")
      m.color = Sketchup::Color.new(*hex_rgb(rest[:values]['color'])) unless orig
      e.material = m
      m
    end

    # «Anche le facce con materiale proprio»: ogni materiale delle facce
    # dirette della definizione ha la sua copia temporanea. Cambia tutte le
    # copie di un componente (la definizione è comune). Dentro un'operazione.
    def self.faces_paint(e)
      model = e.model
      mats = {}
      list = []
      e.definition.entities.grep(Sketchup::Face).each do |f|
        fm = f.material
        bm = f.back_material
        next unless fm || bm
        [fm, bm].compact.each do |m|
          mats[m] ||= clone_material(model, m, "#{TEMP_MAT}#{e.persistent_id}·#{mats.size + 1}")
        end
        list << [f, fm, bm]
        f.material = mats[fm] if fm
        f.back_material = mats[bm] if bm
      end
      { mats: mats, list: list }
    end

    def self.faces_restore(model, faces)
      return unless faces
      faces[:list].each do |f, fm, bm|
        next unless f.valid?
        f.material = fm if fm && (fm.valid? rescue false)
        f.back_material = bm if bm && (bm.valid? rescue false)
      end
      faces[:mats].each_value { |m| model.materials.remove(m) if m.valid? }
    end

    def self.set_material_values(m, rest, v)
      return unless m && m.valid?
      if v.key?('color')
        c = hex_rgb(v['color']) || hex_rgb(rest[:values]['color'])
        m.color = Sketchup::Color.new(*c.map { |x| x.round.clamp(0, 255) })
      end
      m.alpha = v['opacity'].clamp(0.0, 1.0) if v.key?('opacity')
    end

    # Rimuove i materiali temporanei rimasti (SketchUp chiuso durante una
    # sessione e modello salvato da un'altra estensione): un oggetto o una
    # faccia che ne usa ancora uno torna senza materiale.
    def self.purge_temp_materials(model)
      left = model.materials.select { |m| m.name.start_with?(TEMP_MAT) }
      return if left.empty?
      set = left.to_h { |m| [m, true] }
      @own_op = true                  # non è una voce dell'utente (op_break)
      model.start_operation('DagaDyn', true, false, true)
      model.definitions.each do |d|
        d.instances.each { |e| e.material = nil if e.material && set[e.material] }
        d.entities.grep(Sketchup::Face).each do |f|
          f.material = nil if f.material && set[f.material]
          f.back_material = nil if f.back_material && set[f.back_material]
        end
      end
      model.entities.grep(Sketchup::Face).each do |f|
        f.material = nil if f.material && set[f.material]
        f.back_material = nil if f.back_material && set[f.back_material]
      end
      left.each { |m| model.materials.remove(m) rescue nil }
      model.commit_operation
    rescue => dyn_err
      model.abort_operation rescue nil
      log_error(__method__, dyn_err)
    ensure
      @own_op = false
    end

  end
end
