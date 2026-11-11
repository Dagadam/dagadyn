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
      at = lambda do |tau|
        v = {}
        tracks.each { |tr| v[tr[:prop]] = track_value(tr, tau) }
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
    end

    def self.overlay_attach(model)
      return unless overlay_ok? && model.respond_to?(:overlays)
      @overlays ||= {}
      @overlays.delete_if { |m, _| !m.valid? }
      ov = @overlays[model]
      unless ov
        ov = PathsOverlay.new
        model.overlays.add(ov)
        @overlays[model] = ov
      end
      ov.enabled = cf('show_paths') if ov.respond_to?(:enabled=)
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
    # ══════════════════════════════════════════════════════════════
    class UseTool
      def activate
        Dyn.use_tool(true)
      end

      def deactivate(view)
        Dyn.use_tool(false)
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
        Sketchup.status_text = best ? format(Dyn.t('rt.used'), name: best) : Dyn.t('rt.use_none')
      end

      def onCancel(_reason, _view)
        Sketchup.active_model.select_tool(nil)
      end

      def getExtents
        Geom::BoundingBox.new
      end
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

  end
end
