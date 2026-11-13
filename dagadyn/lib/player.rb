# DagaDyn — Motore: sessione, tempo, partenze, applicazione dei valori, pilota dei fotogrammi.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    # ══════════════════════════════════════════════════════════════
    # Sessione
    # Comincia al primo Play, al primo spostamento della timeline, alla
    # prima anteprima di uno stato o quando DagaWASD parte (lib/api.rb), e
    # finisce con Stop. All'inizio fotografa ogni oggetto animato
    # (base_of: trasformazione, materiale, nascosto, tag, piano di sezione
    # = il suo riposo); alla fine lo rimette com'era. Nel frattempo:
    #
    # - le trasformazioni si cambiano con move!, che non lascia voci di
    #   annullamento (è fatto per le animazioni): Ctrl+Z resta pulito. Ma
    #   move! non rifà le ombre né l'ingombro dei piani di taglio: con le
    #   ombre accese la stessa trasformazione si rimette anche dentro
    #   l'operazione (shadow_sync), e ExtentsOverlay (lib/paths.rb) dà a
    #   SketchUp l'ingombro di adesso;
    # - colore, opacità, visibilità, tag e piani di sezione cambiano il
    #   modello: si cambiano in operazioni trasparenti accodate alla prima,
    #   e il ripristino pure: resta una sola voce "Animazione DagaDyn",
    #   neutra. Colore e opacità passano da materiali temporanei (lib/props.rb);
    # - se qualcuno sposta un oggetto animato (strumento Sposta durante la
    #   pausa, un'altra estensione), lo spostamento diventa il suo nuovo
    #   riposo invece di essere perso (item_rebase);
    # - al salvataggio il modello torna a riposo e subito dopo riprende
    #   (lib/observers.rb): nel file finisce sempre lo stato di progetto.
    #
    # Tempo: t della timeline = t0 + (adesso − partenza) × velocità. Un PC
    # lento salta fotogrammi, ma un secondo dura un secondo. Ogni oggetto ha
    # il suo tempo locale (item_local): parte con la timeline, dopo un altro
    # oggetto, o quando lo si aziona.
    #
    # Chi batte il tempo: view.animation (Anim, qui sotto), un timer di
    # riserva, oppure DagaWASD (camminata, esploratore, percorsi e video)
    # attraverso ext_tick: allora s[:ext] è il suo nome.
    # ══════════════════════════════════════════════════════════════

    def self.session; @session; end
    def self.playing?; !!(@session && @session[:state] == :playing); end
    def self.external?; !!(@session && @session[:ext]); end

    # Operazione nostra: gli osservatori (anche quello di DagaWASD) la riconoscono.
    def self.own_op(model, transparent)
      @own_op = true
      model.start_operation(t('op.anim'), true, false, transparent)
      yield
      model.commit_operation
    rescue => dyn_err
      model.abort_operation rescue nil
      log_error(__method__, dyn_err)
    ensure
      @own_op = false
    end
    def self.own_op?; @own_op; end

    # ── Inizio e fine ───────────────────────────────────────────────
    def self.session_start(model = Sketchup.active_model)
      return @session if @session && @session[:model] == model
      session_end if @session
      return nil unless model
      @session = { model: model, items: {}, by_pid: {}, state: :paused, t: 0.0, t0: 0.0, wall0: 0.0,
                   first_op: true, panel_at: 0.0, tick: 0, ext: nil, ext_t0: 0.0, hold: false,
                   shadows: false, total: 0.0, loops: false }
      animated_instances(model).each { |e, data| item_add(e, data) }
      recalc_total
      @session
    end

    # Fine della sessione: gli oggetti tornano a riposo (o, con keep,
    # restano dove sono e lo stato attuale diventa il nuovo progetto).
    def self.session_end(keep = false)
      s = @session or return
      @session = nil
      driver_stop
      model = s[:model]
      if model && model.valid?
        if keep
          bake_items(s)
        else
          back = s[:items].select { |e, it| it[:last_tr] && e.valid? && !it[:section] }.keys
          s[:items].each { |e, it| item_restore(e, it) }
          if s[:shadows] || s[:items].any? { |_e, it| model_touch?(it) } || !back.empty?
            op_in(s, model) do
              s[:items].each { |e, it| item_unpaint(s, e, it) }
              shadows_restore(s)
              shadow_sync(back) if shadows_follow?(s)
            end
          end
        end
        model.active_view.invalidate
      end
      paths_dirty
      panel_transport
      panel_selection
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # Le operazioni della sessione: la prima è una voce vera, le altre vi si
    # accodano (trasparenti).
    def self.op_in(s, model, &blk)
      first = s[:first_op]
      s[:first_op] = false
      own_op(model, !first, &blk)
    end

    # ── Oggetti della sessione ──────────────────────────────────────
    def self.item_add(e, data, base = nil)
      s = @session
      base ||= base_of(e)
      it = { data: data, base: base, rest: rest_for(e, data, base), section: !!base[:section],
             tracks: prepare_tracks(data, base[:section]), temp: nil, faces: nil,
             last_tr: nil, last_v: nil, trig: nil, len: data_length(data), loops: data_loops?(data) }
      s[:items][e] = it
      s[:by_pid][e.persistent_id] = it
      item_material(s, e, it)
      it
    end

    def self.item_remove(s, e, it)
      back = it[:last_tr] && !it[:section]
      item_restore(e, it)
      sync = back && shadows_follow?(s)
      if model_touch?(it) || sync
        op_in(s, s[:model]) do
          item_unpaint(s, e, it)
          shadow_sync([e]) if sync
        end
      end
      s[:items].delete(e)
      s[:by_pid].delete_if { |_k, v| v.equal?(it) }
    end

    # Dati cambiati dal pannello durante la sessione: il riposo resta quello
    # fotografato all'inizio (anche se cambia il pivot); un oggetto azionato
    # resta dov'era arrivato.
    def self.session_update(e, data)
      s = @session or return
      it = s[:items][e]
      on = data && data['tracks'].any? { |t| t['on'] }
      if it
        base = it[:base]
        trig = it[:trig]
        item_remove(s, e, it)
        if on
          nit = item_add(e, data, base)
          nit[:trig] = trig if data['start']['mode'] == 'trigger'
        end
      elsif on
        item_add(e, data)
      end
      recalc_total
      paths_dirty
      apply(s[:t], true)
    end

    # Serve un materiale temporaneo solo se c'è una traccia di colore o
    # opacità; con "faces" anche le copie dei materiali delle facce.
    def self.item_material(s, e, it)
      return if it[:section]
      need = it[:tracks].any? { |tr| MATERIAL_PROPS.include?(tr[:prop]) }
      return unless need && !(it[:temp] && it[:temp].valid?)
      op_in(s, s[:model]) do
        it[:temp]  = temp_material(e, it[:rest])
        it[:faces] = faces_paint(e) if it[:data]['faces']
      end
    end

    # Cambia il modello oltre alla trasformazione? (serve un'operazione)
    def self.model_touch?(it)
      it[:temp] || it[:faces] || it[:section] || it[:tracks].any? { |tr| MODEL_PROPS.include?(tr[:prop]) }
    end

    def self.item_restore(e, it)
      return unless e.valid? && !it[:section]
      item_rebase(e, it)
      place(e, it[:base][:tr]) if it[:last_tr]
      it[:last_tr] = nil
    end

    # Colore, facce, visibilità, tag, piano di sezione come a riposo. Dentro un'operazione.
    def self.item_unpaint(s, e, it)
      return unless e.valid?
      base = it[:base]
      if it[:temp]
        e.material = base[:material] if e.material == it[:temp]
        s[:model].materials.remove(it[:temp]) if it[:temp].valid?
        it[:temp] = nil
      end
      if it[:faces]
        faces_restore(s[:model], it[:faces])
        it[:faces] = nil
      end
      props = it[:tracks].map { |tr| tr[:prop] }
      e.hidden = base[:hidden] if props.include?('visible') && e.hidden? != base[:hidden]
      e.layer = base[:layer] if props.include?('tag') && base[:layer] && base[:layer].valid? && e.layer != base[:layer]
      e.set_plane(base[:plane]) if it[:section] && it[:plane_moved]
      it[:plane_moved] = false
      it[:last_v] = nil
    end

    # Spostato da qualcun altro dall'ultimo fotogramma (strumento Sposta
    # durante la pausa, un'altra estensione): quello spostamento
    # D = attuale · ultima⁻¹ si porta anche sul riposo, invece di perderlo.
    def self.item_rebase(e, it)
      return unless it[:last_tr] && !same_tr?(e.transformation, it[:last_tr])
      d = e.transformation * it[:last_tr].inverse
      it[:base] = it[:base].merge(tr: d * it[:base][:tr])
      it[:rest] = rest_for(e, it[:data], it[:base])
      it[:last_tr] = e.transformation
      paths_dirty
    end

    # «Tieni questo stato»: le trasformazioni attuali diventano quelle del
    # modello (con una voce di annullamento), i materiali temporanei
    # diventano materiali veri. Visibilità, tag e piani restano come sono.
    def self.bake_items(s)
      model = s[:model]
      now = s[:items].map { |e, it| [e, it, e.valid? && !it[:section] ? e.transformation : nil] }
      now.each { |e, it, _| item_restore(e, it) }
      own_op(model, false) do
        now.each do |e, it, tr|
          next unless e.valid?
          e.transformation = tr if tr && tr.to_a != it[:base][:tr].to_a
          base = it[:base][:material] ? it[:base][:material].display_name : 'DagaDyn'
          mats = []
          mats << it[:temp] if it[:temp]
          mats.concat(it[:faces][:mats].values) if it[:faces]
          mats.each do |m|
            m.name = model.materials.unique_name("#{base} (DagaDyn)") if m.valid?
          rescue => dyn_err
            log_error(__method__, dyn_err)
          end
        end
        shadows_restore(s)
      end
    end

    def self.recalc_total
      s = @session or return
      list = s[:items].map { |e, it| [e, it[:data]] }
      s[:total] = timeline_length(list)
      s[:loops] = loops?(list)
      starts = chain_starts(list)
      s[:items].each { |e, it| it[:static] = starts[e.persistent_id] }

    end

    # ── Tracce pronte per il calcolo ────────────────────────────────
    def self.prepare_tracks(data, section = false)
      data['tracks'].select { |t| t['on'] && (!section || SECTION_PROPS.include?(t['prop'])) }.map do |t|
        kind  = PROPS[t['prop']][:kind]
        color = kind == :color
        vals  = t['keys'].map { |k| color ? hex_rgb(k['v']) : k['v'] }
        segs  = t['keys'].drop(1).map { |k| { dur: k['dur'], curve: curve_prepare(k['curve']) } }
        { prop: t['prop'], delay: t['delay'], loop: t['loop'], vals: vals, segs: segs,
          cycle: segs.sum { |g| g[:dur] }, color: color, discrete: DISCRETE.include?(kind) }
      end
    end

    # Valore di una traccia all'istante t (tempo locale dell'oggetto).
    def self.track_value(tr, t)
      vals = tr[:vals]
      tau  = t - tr[:delay]
      c    = tr[:cycle]
      return finish(tr, vals[0]) if tau <= 0 || vals.size == 1
      return finish(tr, vals[-1]) if c <= 0
      case tr[:loop]
      when 'loop'
        tau %= c
      when 'pingpong'
        tau %= 2 * c
        tau = 2 * c - tau if tau > c
      else
        return finish(tr, vals[-1]) if tau >= c
      end
      start = 0.0
      tr[:segs].each_with_index do |g, i|
        d = g[:dur]
        if tau <= start + d && d > 0
          e = curve_eval(g[:curve], (tau - start) / d)
          a = vals[i]; b = vals[i + 1]
          # a scatti: si passa allo stato quando la sua transizione finisce
          return finish(tr, e >= 1.0 - 1e-9 ? b : a) if tr[:discrete]
          return finish(tr, tr[:color] ? mix_color(a, b, e) : a + (b - a) * e)
        end
        start += d
      end
      finish(tr, vals[-1])
    end

    def self.finish(tr, v)
      return rgb_hex(v) if tr[:color]
      return v unless v.is_a?(Numeric)
      spec = PROPS[tr[:prop]]
      v = [v, spec[:min]].max if spec[:min]
      v = [v, spec[:max]].min if spec[:max]
      v
    end

    # ── Partenze e tempo locale ─────────────────────────────────────
    # Istante della timeline in cui l'oggetto parte (nil: non ancora) e in
    # cui finisce il suo primo giro (nil: non si sa ancora, o non finisce).
    def self.item_start(s, it, depth = 0)
      return nil if depth > 32
      st = it[:data]['start']
      case st['mode']
      when 'trigger' then nil
      when 'after'
        pred = s[:by_pid][st['after']]
        return st['wait'] unless pred && !pred.equal?(it)
        pe = item_end(s, pred, depth + 1)
        pe && pe + st['wait']
      else 0.0
      end
    end

    def self.item_end(s, it, depth = 0)
      return nil if depth > 32
      if it[:data]['start']['mode'] == 'trigger'
        g = it[:trig] or return nil
        return g[:at] + it[:len] if g[:act] == 'play'
        g[:dir] > 0 ? g[:at] + (it[:len] - g[:from]) : nil
      else
        st = item_start(s, it, depth + 1)
        st && st + it[:len]
      end
    end

    # Tempo locale: prima della partenza è negativo (stato iniziale).
    def self.item_local(s, it, t)
      if it[:data]['start']['mode'] == 'trigger'
        g = it[:trig] or return 0.0
        return t - g[:at] if g[:act] == 'play'
        return g[:from] if g[:dir].zero?
        x = g[:from] + g[:dir] * (t - g[:at])
        x = [x, it[:len]].min unless it[:loops] && g[:dir] > 0
        [x, 0.0].max
      else
        st = item_start(s, it)
        st ? t - st : -1.0
      end
    end

    # Qualcosa fuori dalla timeline (azionato, o in catena dietro un
    # azionato) si sta ancora muovendo all'istante t?
    def self.busy_at?(s, t)
      s[:items].each_value.any? do |it|
        st = it[:data]['start']
        if st['mode'] == 'trigger'
          g = it[:trig]
          next false unless g
          next true if it[:loops] && (g[:act] == 'play' || g[:dir] > 0)
          next t - g[:at] < it[:len] if g[:act] == 'play'
          x = item_local(s, it, t)
          g[:dir] > 0 ? x < it[:len] : (g[:dir] < 0 && x > 0)
        elsif st['mode'] == 'after' && it[:static].nil?
          stt = item_start(s, it)
          stt && (it[:loops] || t < stt + it[:len])
        else
          false
        end
      end
    end

    # Azionare un oggetto all'istante t della sessione.
    #   play: riparte da capo; toggle: va avanti, alla volta dopo torna
    #   indietro (anche a metà corsa: inverte da dov'è).
    def self.trigger_item(s, it, t)
      if it[:data]['start']['act'] == 'toggle'
        cur = item_local(s, it, t)
        dir = it[:trig] && it[:trig][:dir] > 0 ? -1 : 1
        it[:trig] = { act: 'toggle', at: t, from: cur.clamp(0.0, [it[:len], 0.0].max), dir: dir }
      else
        it[:trig] = { act: 'play', at: t, from: 0.0, dir: 1 }
      end
    end

    # La timeline torna indietro di delta (ripetizione): azionati e catene
    # restano dove sono.
    def self.shift_time(s, delta)
      s[:t0]     -= delta
      s[:ext_t0] -= delta
      s[:items].each_value { |it| it[:trig][:at] -= delta if it[:trig] }
    end

    # ── Applicazione ────────────────────────────────────────────────
    def self.apply(t, force = false)
      s = @session or return
      s[:t] = t
      s[:tick] += 1
      jobs = []
      moved = []
      s[:items].each do |e, it|
        next unless e.valid?
        local = item_local(s, it, t)
        v = {}
        it[:tracks].each { |tr| v[tr[:prop]] = track_value(tr, local) }
        prev = it[:last_v]
        next if !force && v == prev
        it[:last_v] = v
        moved << e if apply_item(s, e, it, v)
        touched = it[:section] || v.any? { |k, x| MODEL_PROPS.include?(k) && (force || prev.nil? || prev[k] != x) }
        jobs << [e, it, v] if touched
      end
      dead = s[:items].keys.reject(&:valid?)
      dead.each { |e| s[:by_pid].delete_if { |_k, it| it.equal?(s[:items][e]) }; s[:items].delete(e) }
      moved = [] unless shadows_follow?(s)
      unless jobs.empty? && moved.empty?
        op_in(s, s[:model]) do
          jobs.each { |e, it, v| paint_item(s, e, it, v) }
          shadow_sync(moved)
        end
      end
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    def self.apply_item(s, e, it, v)
      return if it[:section]
      return unless it[:tracks].any? { |tr| TRANSFORM_PROPS.include?(tr[:prop]) }
      item_rebase(e, it)
      tr = compose(it[:rest], v)
      it[:prev_tr] = it[:last_tr] || it[:base][:tr]
      place(e, tr)
      it[:last_tr] = tr
      it[:moved] = s[:tick]
      true
    end

    # ── Ombre che seguono gli oggetti ───────────────────────────────
    # move! non rifà le ombre nella vista: restano quelle della posa di
    # riposo (un oggetto abbassato lascia a terra l'ombra lunga e fa ombra
    # su quelli vicini). Rimettere la stessa trasformazione dentro la nostra
    # operazione le fa ricalcolare. Solo con le ombre accese e non nel video
    # di DagaWASD: write_image le ricalcola da sé.
    def self.shadows_follow?(s)
      s[:ext] != :video && s[:model].shadow_info['DisplayShadows'] ? true : false
    rescue
      false
    end

    # Dentro un'operazione
    def self.shadow_sync(list)
      list.each { |e| e.transformation = e.transformation if e.valid? }
    end

    # Le proprietà che cambiano il modello. Dentro un'operazione.
    def self.paint_item(s, e, it, v)
      if it[:section]
        if %w[move_x move_y move_z].any? { |k| v.key?(k) }
          e.set_plane(compose_plane(it[:rest], v))
          it[:plane_moved] = true
        end
      else
        set_material_values(it[:temp], it[:rest], v) if it[:temp]
        it[:faces][:mats].each_value { |m| set_material_values(m, it[:rest], v) } if it[:faces]
        if v.key?('tag')
          l = layer_by_name(s[:model], v['tag'])
          e.layer = l if l && e.layer != l
        end
      end
      if v.key?('visible')
        h = v['visible'] < 0.5
        e.hidden = h if e.hidden? != h
      end
    end

    def self.same_tr?(a, b)
      a.to_a.zip(b.to_a).all? { |x, y| (x - y).abs < 1e-6 * [1.0, x.abs, y.abs].max }
    end

    # ── Ombre spente durante il Play ────────────────────────────────
    # Nei modelli pesanti il ridisegno con le ombre costa più di tutto il
    # resto (lo Stromboli: 280 ms a fotogramma). Si spengono al Play e si
    # riaccendono alla pausa, allo stop e prima di salvare.
    def self.shadows_off(s)
      return if s[:shadows] || s[:ext] || !cf('play_no_shadows')
      si = s[:model].shadow_info
      return unless si['DisplayShadows']
      op_in(s, s[:model]) { si['DisplayShadows'] = false }
      s[:shadows] = true
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # Dentro un'operazione
    def self.shadows_restore(s)
      return unless s[:shadows]
      s[:shadows] = false
      s[:model].shadow_info['DisplayShadows'] = true
    end

    def self.shadows_back(s)
      return unless s[:shadows]
      op_in(s, s[:model]) do
        shadows_restore(s)
        # spente durante il Play: tornano con la posa di adesso, non quella di riposo
        shadow_sync(s[:items].select { |_e, it| it[:last_tr] }.keys) if shadows_follow?(s)
      end
    end

    # ── Comandi della timeline ──────────────────────────────────────
    # SketchUp tiene una sola view.animation: prenderla mentre DagaWASD
    # registra un video (o riproduce un percorso, o esplora) ferma il suo
    # lavoro a metà. Quando invece DagaWASD batte il tempo per noi (ext) la
    # timeline è sua: Play, pausa e spostamenti aspettano che finisca.
    def self.foreign_busy?
      return true if external?
      return false unless defined?(DagaWASD::FPSWalk)
      w = DagaWASD::FPSWalk
      (w.respond_to?(:path_busy?) && w.path_busy?) || (w.respond_to?(:explore_on?) && w.explore_on?)
    rescue
      false
    end

    def self.refuse_busy
      return false unless foreign_busy?
      Sketchup.status_text = t('rt.busy')
      js("flashStatus(#{js_json(t('rt.busy'))})")
      true
    end

    def self.cmd_play
      return if refuse_busy
      s = session_start or return
      if s[:items].empty?
        Sketchup.status_text = t('rt.nothing')
        session_end
        return
      end
      if !s[:loops] && s[:total] > 0 && s[:t] >= s[:total] - 1e-6 && !busy_at?(s, s[:t])
        shift_time(s, s[:t])
        s[:t] = 0.0
      end
      s[:state] = :playing
      s[:t0]    = s[:t]
      s[:wall0] = Time.now.to_f
      shadows_off(s)
      driver_start(s[:model])
      panel_transport
    end

    def self.cmd_pause
      s = @session or return
      return if s[:ext]
      s[:t] = clock(s, Time.now.to_f) if s[:state] == :playing
      s[:state] = :paused
      driver_stop
      apply(s[:t])
      shadows_back(s)
      s[:model].active_view.invalidate
      panel_transport
    end

    def self.cmd_toggle
      playing? ? cmd_pause : cmd_play
    end

    def self.cmd_stop
      return if @session && @session[:ext] && refuse_busy
      session_end(!cf('stop_restore'))
    end

    # Timeline spostata a mano (scrub): durante la riproduzione si riparte da lì.
    def self.cmd_seek(t)
      if refuse_busy
        panel_transport
        return
      end
      s = session_start or return
      if s[:items].empty?
        session_end
        return
      end
      t = t.to_f.clamp(0.0, [s[:total], 0.0].max)
      s[:t] = t
      if s[:state] == :playing
        s[:t0] = t
        s[:wall0] = Time.now.to_f
      end
      apply(t)
      s[:model].active_view.invalidate
      panel_transport
    end

    # Anteprima di uno stato dal pannello: l'oggetto si mostra com'è al suo
    # tempo locale `local` (la timeline va lì; un azionato si ferma lì).
    def self.cmd_preview(e, local)
      return if foreign_busy?
      s = session_start or return
      it = s[:items][e] or return
      cmd_pause if s[:state] == :playing
      st = item_start(s, it)
      if st && it[:data]['start']['mode'] != 'trigger'
        s[:t] = [st + local.to_f, 0.0].max
      else
        it[:trig] = { act: 'toggle', at: s[:t], from: local.to_f.clamp(0.0, [it[:len], 0.0].max), dir: 0 }
      end
      apply(s[:t], true)
      s[:model].active_view.invalidate
      panel_transport
    end

    # «Tieni questo stato»
    def self.cmd_bake
      return if @session && @session[:ext] && refuse_busy
      session_end(true)
    end

    def self.clock(s, now)
      s[:t0] + (now - s[:wall0]) * cf('play_speed')
    end

    # Fine della timeline: ricomincia (ripetizione) o si ferma. Con un
    # azionato in moto o con lo strumento Aziona (hold) si va avanti.
    # Ritorna il tempo da applicare, o nil per fermarsi.
    def self.timeline_end(s, t)
      return t if s[:loops] || t < s[:total] || busy_at?(s, t)
      if cf('play_repeat') && s[:total] > 0
        n = (t / s[:total]).floor
        shift_time(s, n * s[:total])
        return t - n * s[:total]
      end
      return t if s[:hold] || s[:ext]
      nil
    end

    # Un passo: tempo, fine o ripetizione, applicazione. true = continua.
    def self.advance(now = Time.now.to_f)
      s = @session
      return false unless s && s[:state] == :playing && s[:model].valid?
      t = timeline_end(s, clock(s, now))
      unless t
        apply(s[:total])
        s[:state] = :paused
        shadows_back(s)
        panel_transport
        return false
      end
      apply(t)
      panel_tick(s, now)
      true
    rescue => dyn_err
      log_error(__method__, dyn_err)
      false
    end

    def self.panel_tick(s, now)
      return unless now - s[:panel_at] >= 1.0 / [cf('panel_fps').to_f, 1.0].max
      s[:panel_at] = now
      panel_transport
    end

    # ══════════════════════════════════════════════════════════════
    # Pilota dei fotogrammi
    # view.animation: SketchUp chiama nextFrame a ogni ridisegno, il più
    # fluido possibile. Se SketchUp la interrompe (navigazione con il
    # mouse, un'altra animazione) mentre stiamo suonando, si passa a un
    # timer che ridisegna la vista.
    # ══════════════════════════════════════════════════════════════
    class Anim
      def nextFrame(view)
        return false unless Dyn.anim_live?(self)
        go = Dyn.advance
        view.show_frame
        go
      end

      def stop
        Dyn.anim_stopped(self)
      end
    end

    def self.anim_live?(a); @anim.equal?(a); end

    def self.driver_start(model)
      driver_stop
      @anim = Anim.new
      model.active_view.animation = @anim
    rescue => dyn_err
      log_error(__method__, dyn_err)
      timer_start
    end

    def self.anim_stopped(a)
      return unless @anim.equal?(a)
      @anim = nil
      timer_start if playing? && !external?
    end

    def self.timer_start
      return if @timer
      @timer = UI.start_timer(1.0 / 60, true) do
        if advance
          (@session[:model].active_view.invalidate rescue nil)
        else
          timer_stop
        end
      end
    end

    def self.timer_stop
      UI.stop_timer(@timer) if @timer
      @timer = nil
    end

    def self.driver_stop
      # @anim c'è solo finché la nostra animazione è quella della vista (se
      # un'altra la sostituisce, SketchUp chiama Anim#stop e @anim si azzera):
      # View non ha un modo per leggere l'animazione attiva.
      if @anim
        @anim = nil
        view = Sketchup.active_model && Sketchup.active_model.active_view
        view.animation = nil if view
      end
      timer_stop
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # ── Salvataggio ────────────────────────────────────────────────
    # Prima di salvare: tutto a riposo; dopo: si riprende da dove si era.
    # Qui SketchUp sta già salvando: niente operazioni, solo i valori.
    def self.session_suspend
      s = @session or return
      s[:suspended] = true
      s[:items].each do |e, it|
        next unless e.valid?
        base = it[:base]
        place(e, base[:tr]) if it[:last_tr] && !it[:section]
        e.material = base[:material] if it[:temp]
        it[:faces][:list].each { |f, fm, bm| (f.material = fm if fm; f.back_material = bm if bm) if f.valid? } if it[:faces]
        e.hidden = base[:hidden] if e.hidden? != base[:hidden]
        e.layer = base[:layer] if base[:layer] && base[:layer].valid? && e.layer != base[:layer]
        e.set_plane(base[:plane]) if it[:section] && it[:plane_moved]
      end
      s[:model].shadow_info['DisplayShadows'] = true if s[:shadows]
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    def self.session_resume
      s = @session or return
      return unless s.delete(:suspended)
      s[:items].each do |e, it|
        next unless e.valid?
        e.material = it[:temp] if it[:temp] && it[:temp].valid?
        if it[:faces]
          mats = it[:faces][:mats]
          it[:faces][:list].each do |f, fm, bm|
            next unless f.valid?
            f.material = mats[fm] if fm && mats[fm]
            f.back_material = mats[bm] if bm && mats[bm]
          end
        end
        it[:last_tr] = nil
        it[:last_v]  = nil
      end
      s[:model].shadow_info['DisplayShadows'] = false if s[:shadows]
      apply(s[:t], true)
      s[:model].active_view.invalidate
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

  end
end
