# DagaDyn — Traiettorie nella vista (Overlay) e strumento Aziona.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    # ══════════════════════════════════════════════════════════════
    # Traiettorie: il percorso del centro di ogni oggetto animato durante
    # la sua animazione (un giro, se si ripete), con un punto per ogni
    # stato. Si disegnano in un Overlay (SketchUp 2023 e successivi), che
    # non tocca il modello e non serve uno strumento attivo. Si vedono
    # quelle degli oggetti selezionati, o di tutti (paths_all); mai mentre
    # DagaWASD cammina o registra.
    # ══════════════════════════════════════════════════════════════
    PATH_SAMPLES = 96
    PATH_RGB  = [0, 201, 167].freeze
    PATH_KEY  = [255, 209, 102].freeze

    def self.overlay_ok?
      defined?(Sketchup::Overlay) ? true : false
    end

    # Cache: entità → [firma, punti, punti degli stati]
    def self.paths_dirty
      @path_cache = {}
      @link_cache = {}
      @path_list = nil
      view = Sketchup.active_model && Sketchup.active_model.active_view
      view.invalidate if view && cf('show_paths') && !playing?
    rescue
      nil
    end

    def self.paths_targets(model)
      if cf('paths_all')
        @path_list ||= animated_instances(model).map(&:first)
      else
        model.selection.select { |e| animatable?(e) && !section?(e) && e.attribute_dictionary(DICT) }
      end
    end

    # Trasformazione del contenitore nel mondo (la prima copia, se il
    # contenitore è un componente usato più volte).
    def self.world_of(e)
      t = Geom::Transformation.new
      p = e.parent
      16.times do
        break unless p.is_a?(Sketchup::ComponentDefinition)
        inst = p.instances.first or break
        t = inst.transformation * t
        p = inst.parent
      end
      t
    end

    def self.path_of(e)
      raw = e.get_attribute(DICT, DATA_KEY).to_s
      it  = @session && @session[:items][e]
      sig = [raw, it ? it[:base][:tr].to_a : e.transformation.to_a]
      @path_cache ||= {}
      c = @path_cache[e]
      return c[1] if c && c[0] == sig
      @path_cache[e] = [sig, path_compute(e, it)]
      @path_cache[e][1]
    end

    # [punti, punti degli stati] nel mondo, o nil se non si muove
    def self.path_compute(e, it)
      data = it ? it[:data] : read_data(e)
      return nil unless data
      tracks = prepare_tracks(data).select { |tr| TRANSFORM_PROPS.include?(tr[:prop]) }
      return nil if tracks.empty?
      rest = it ? it[:rest] : rest_for(e, data)
      len  = tracks.map { |tr| tr[:delay] + tr[:cycle] * (tr[:loop] == 'pingpong' ? 2 : 1) }.max
      return nil unless len && len > 0
      w = world_of(e)
      center = rest[:center]
      # Transizioni a formula che leggono altri oggetti: il tempo locale tau
      # è l'istante st0 + tau della timeline (fuori dalla timeline: da 0)
      fw = nil
      if tracks.any? { |tr| tr[:fx] }
        s = @session
        if s && it
          fw = fx_world_session(s)
          st0 = item_start(s, it) || 0.0
        else
          fw = fx_world_model(e.model)
          st0 = fw[:starts][e.persistent_id] || 0.0
        end
      end
      at = lambda do |tau|
        ctx = fw && { w: fw, off: st0, f: fw[:f] }
        v = {}
        tracks.each { |tr| v[tr[:prop]] = track_value(tr, tau, ctx) }
        center.transform(compose(rest, v)).transform(w)
      end
      pts = (0..PATH_SAMPLES).map { |i| at.call(len * i / PATH_SAMPLES) }
      keys = []
      tracks.each do |tr|
        acc = tr[:delay]
        keys << acc
        tr[:segs].each { |g| keys << (acc += g[:dur]) }
      end
      kpts = keys.uniq.select { |x| x <= len + 1e-9 }.map { |x| at.call(x) }
      spread = pts.map { |p| p.distance(pts[0]) }.max
      return nil if spread < 1e-3
      [pts, kpts]
    rescue => dyn_err
      log_error(__method__, dyn_err)
      nil
    end

    def self.paths_draw(view)
      return unless cf('show_paths') && !external?
      model = view.model
      paths_targets(model).each do |e|
        next unless e.valid?
        pk = path_of(e) or next
        pts, kpts = pk
        view.line_width = 2
        view.line_stipple = ''
        view.drawing_color = Sketchup::Color.new(*PATH_RGB)
        view.draw(GL_LINE_STRIP, pts)
        view.draw_points(kpts, 8, 2, Sketchup::Color.new(*PATH_KEY)) unless kpts.empty?
        view.draw_points([pts[0]], 9, 1, Sketchup::Color.new(*PATH_RGB))
      end
      links_draw(view, model)
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # ── Collegamenti delle formule ──────────────────────────────────
    # Con le traiettorie, una linea tratteggiata da ogni oggetto letto da
    # una formula a chi lo legge, con il nome del parametro a metà: dei
    # selezionati (quelli che leggono e quelli da cui sono letti) o di tutti.
    # Segue gli oggetti mentre si muovono.
    LINK_RGB = [255, 140, 90].freeze

    # [[persistent_id letto, nomi dei parametri]] delle formule accese di e
    def self.links_of(e)
      raw = e.get_attribute(DICT, DATA_KEY).to_s
      @link_cache ||= {}
      c = @link_cache[e]
      return c[1] if c && c[0] == raw
      by = {}
      data = read_data(e)
      (data ? data['tracks'] : []).each do |t|
        next unless t['on']
        t['keys'].each do |k|
          f = k['fx']
          next unless f && f['on']
          f['params'].each { |q| (by[q['pid']] ||= []) << q['n'] if q['pid'] != 0 && q['pid'] != e.persistent_id }
        end
      end
      @link_cache[e] = [raw, by.map { |pid, ns| [pid, ns.uniq] }]
      @link_cache[e][1]
    end

    # Coppie [letto, chi legge, nomi] da disegnare
    def self.links_pairs(model)
      all = anim_candidates(model)
      readers = cf('paths_all') ? all : all.select { |e| !links_of(e).empty? }
      sel = cf('paths_all') ? nil : model.selection.to_a
      out = []
      readers.each do |e|
        next unless e.valid?
        links_of(e).each do |pid, ns|
          src = find_pid(pid) or next
          next unless src.valid? && animatable?(src) && !section?(src)
          out << [src, e, ns] if sel.nil? || sel.include?(e) || sel.include?(src)
        end
      end
      out
    end

    def self.links_draw(view, model)
      pairs = links_pairs(model)
      return if pairs.empty?
      col = Sketchup::Color.new(*LINK_RGB)
      pairs.each do |src, e, ns|
        a = src.bounds.center.transform(world_of(src))
        b = e.bounds.center.transform(world_of(e))
        next if a.distance(b) < 1e-3
        view.line_width = 2
        view.line_stipple = '-'
        view.drawing_color = col
        view.draw(GL_LINES, [a, b])
        view.draw_points([b], 7, 1, col)
        mid = Geom::Point3d.new((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
        view.draw_text(view.screen_coords(mid), ns.join(', '), color: col, size: 11, bold: true)
      end
      view.line_stipple = ''
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    if defined?(Sketchup::Overlay)
      class PathsOverlay < Sketchup::Overlay
        def initialize
          super('dagadyn.paths', 'DagaDyn', description: 'DagaDyn')
        end

        def draw(view)
          Dyn.paths_draw(view)
        end
      end

      # ════════════════════════════════════════════════════════════
      # Ingombro durante l'animazione. move! non aggiorna l'ingombro che
      # SketchUp usa per i piani di taglio: resta quello di riposo, mentre
      # model.bounds è già quello nuovo. Un oggetto che esce dal riposo
      # (più alto, spostato) veniva tagliato dal piano lontano, e con lui
      # il cielo di DagaWASD, che si mette appena oltre model.bounds: le
      # nuvole sparivano a ogni ciclo. Questo Overlay non disegna niente e,
      # solo durante una sessione, dice a SketchUp l'ingombro attuale.
      # ════════════════════════════════════════════════════════════
      class ExtentsOverlay < Sketchup::Overlay
        def initialize
          super('dagadyn.extents', Dyn.t('op.anim'), description: 'DagaDyn')
        end

        def getExtents
          Dyn.session_extents
        end
      end
    end

    def self.session_extents
      s = @session
      m = Sketchup.active_model
      return Geom::BoundingBox.new unless s && m && s[:model] == m && !s[:items].empty?
      Geom::BoundingBox.new.add(m.bounds)
    rescue => dyn_err
      log_error(__method__, dyn_err)
      Geom::BoundingBox.new
    end

    def self.overlay_attach(model)
      return unless overlay_ok? && model.respond_to?(:overlays)
      @overlays ||= {}
      @overlays.delete_if { |m, _| !m.valid? }
      ov, ex = @overlays[model]
      # non validi: tolti con il documento di prima (Windows riusa l'oggetto Model)
      unless ov && ex && ov.valid? && ex.valid?
        # quelli già nel modello (estensione ricaricata) si riusano: lo stesso id non si aggiunge due volte
        have = model.overlays.to_a
        ov = have.find { |o| o.overlay_id == 'dagadyn.paths' } || PathsOverlay.new.tap { |o| model.overlays.add(o) }
        ex = have.find { |o| o.overlay_id == 'dagadyn.extents' } || ExtentsOverlay.new.tap { |o| model.overlays.add(o) }
        @overlays[model] = [ov, ex]
      end
      ov.enabled = cf('show_paths') if ov.respond_to?(:enabled=)
      ex.enabled = true if ex.respond_to?(:enabled=)
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # Impostazione cambiata dal pannello
    def self.overlay_refresh
      m = Sketchup.active_model or return
      overlay_attach(m)
      paths_dirty
    end

    # ══════════════════════════════════════════════════════════════
    # Strumento Aziona: un clic su un oggetto che parte «quando lo si
    # aziona» lo fa partire (o tornare indietro). Mentre lo strumento è
    # attivo la timeline va avanti da sola (hold): si gioca col modello.
    # Sotto il mouse, l'oggetto che si aziona ha il riquadro colorato, il
    # nome accanto e il cursore con il simbolo di Aziona: si vede prima di
    # cliccare che cosa partirà.
    # ══════════════════════════════════════════════════════════════
    class UseTool
      def activate
        @hover = nil
        @at = nil
        @tip = nil                # cambiando strumento SketchUp toglie il nome: va rimesso
        Dyn.use_tool(true)
        # Gli oggetti si muovono anche col mouse fermo: durante l'animazione
        # si riguarda cosa c'è sotto, o il riquadro resterebbe su un oggetto
        # che se n'è andato (e mancherebbe su uno che arriva).
        @timer = UI.start_timer(0.1, true) do
          view = Sketchup.active_model && Sketchup.active_model.active_view
          refresh(view) if view && (Dyn.playing? || Dyn.external?)
        end
      end

      def deactivate(view)
        UI.stop_timer(@timer) if @timer
        @timer = nil
        Dyn.use_tool(false)
        @hover = nil
        view.invalidate
      end

      def onMouseMove(_flags, x, y, view)
        @at = [x, y]
        refresh(view)
      end

      # Cosa si aziona sotto il mouse: riquadro, nome, cursore
      def refresh(view)
        return unless @at
        h = Dyn.use_hover(view, *@at)
        tip = h ? Dyn.ent_name(h[0]) : ''
        view.tooltip = @tip = tip if tip != @tip
        return if h == @hover
        @hover = h
        cur = Dyn.use_cursor(!h.nil?)
        UI.set_cursor(cur) if cur
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        best = nil
        ph.count.times do |i|
          path = ph.path_at(i)
          next unless path
          name = Dyn.use_path(path)
          if name
            best = name
            break
          end
        end
        Sketchup.status_text = best ? Dyn.tf('rt.used', name: best) : Dyn.t('rt.use_none')
      end

      def onSetCursor
        cur = Dyn.use_cursor(!@hover.nil?) or return false
        UI.set_cursor(cur)
        true
      end

      def onCancel(_reason, _view)
        Sketchup.active_model.select_tool(nil)
      end

      def draw(view)
        @hover = nil if @hover && !@hover[0].valid?     # cancellato mentre era sotto il mouse
        pts = @hover && Dyn.use_box(*@hover) or return
        view.line_width = 2
        view.line_stipple = ''
        view.drawing_color = Sketchup::Color.new(*PATH_RGB)
        view.draw(GL_LINES, pts)
      end

      def getExtents
        bb = Geom::BoundingBox.new
        pts = @hover && @hover[0].valid? && Dyn.use_box(*@hover)
        bb.add(pts) if pts
        bb
      end
    end

    # [oggetto, contenitori sopra di lui] che si aziona sotto il mouse, o nil
    def self.use_hover(view, x, y)
      ph = view.pick_helper
      ph.do_pick(x, y)
      ph.count.times do |i|
        path = ph.path_at(i) or next
        e = use_targets(path).first or next
        return [e, path.take_while { |p| !p.equal?(e) }]
      end
      nil
    rescue => dyn_err
      log_error(__method__, dyn_err)
      nil
    end

    # Spigoli (a coppie, GL_LINES) del riquadro dell'oggetto nella posa
    # attuale, nel mondo; nil per i piani di sezione.
    BOX_EDGES = [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7],
                 [0, 4], [1, 5], [2, 6], [3, 7]].freeze
    def self.use_box(e, parents)
      return nil if !e.valid? || section?(e)
      tr = parents.select { |p| p.respond_to?(:transformation) && p.valid? }
                  .map(&:transformation).inject(Geom::Transformation.new, :*) * e.transformation
      bb = e.definition.bounds
      return nil if bb.empty?
      c = (0..7).map { |k| bb.corner(k).transform(tr) }
      BOX_EDGES.flat_map { |a, b| [c[a], c[b]] }
    rescue => dyn_err
      log_error(__method__, dyn_err)
      nil
    end

    # Sopra un oggetto che si aziona il triangolo di Play, che clicca dal suo
    # centro (14, 16); altrove la freccia, che clicca dalla punta (1, 1).
    def self.use_cursor(on)
      @use_cursors ||= {}
      return @use_cursors[on] if @use_cursors.key?(on)
      png = File.join(PLUGIN_DIR, 'icons', on ? 'use_cursor.png' : 'arrow_cursor.png')
      hx, hy = on ? [14, 16] : [1, 1]
      @use_cursors[on] = File.exist?(png) ? UI.create_cursor(png, hx, hy) : nil
    rescue
      @use_cursors[on] = nil
    end

    def self.use_tool(on)
      @use_on = on
      s = @session
      if on
        Sketchup.status_text = t('rt.use_hint')
        if s && !s[:ext]
          s[:hold] = true
        end
      elsif s && !s[:ext]
        s[:hold] = false
      end
    end

    def self.use_tool_on?; !!@use_on; end

    def self.start_use_tool
      model = Sketchup.active_model or return
      model.select_tool(UseTool.new)
    end

    # Pulsante della barra e voce del menu: di nuovo, con lo strumento già
    # attivo, se ne esce come con Esc.
    def self.toggle_use_tool
      model = Sketchup.active_model or return
      use_tool_on? ? model.select_tool(nil) : start_use_tool
    end

  end
end
