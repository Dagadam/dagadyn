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
    # Tempo: l'orologio della riproduzione c = c0 + (adesso − partenza) ×
    # velocità; il tempo della timeline t = c, oppure, con la velocità del
    # tempo del modello, t = warp(c) (qui sotto). Un PC lento salta
    # fotogrammi, ma un secondo dura un secondo. Ogni oggetto ha il suo tempo
    # locale (item_local): parte con la timeline, dopo un altro oggetto, o
    # quando lo si aziona.
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
      @ended = nil                     # l'annulla dopo lo Stop vale per l'ultima sessione
      @session = { model: model, items: {}, by_pid: {}, state: :paused, t: 0.0, c: 0.0, c0: 0.0, wall0: 0.0,
                   first_op: true, panel_at: 0.0, tick: 0, ext: nil, ext_c0: 0.0, hold: false,
                   shadows: false, total: 0.0, loops: false, warp: nil }
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
          @ended = nil
          bake_items(s)
        else
          ended_keep(s)
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

    # ── Annulla dopo lo Stop ───────────────────────────────────────
    # I materiali temporanei nascono all'inizio della sessione. Se in mezzo
    # c'è un'operazione dell'utente, ogni stato a cui si torna con Ctrl+Z da
    # lì in giù li contiene: lo Stop li ha tolti, ma annullare la voce
    # dell'animazione (o la mossa dell'utente) li rimette, e con loro
    # visibilità, tag e pose di quel momento. Dopo un annulla o un ripeti
    # senza sessione si rimette a posto:
    # - i materiali temporanei, sempre (non sono mai legittimi fuori da una
    #   sessione): al loro posto l'originale, se si sa qual era;
    # - riposo, visibilità, tag e piani di sezione degli oggetti dell'ultima
    #   sessione, solo finché l'annulla resta fra le voci nate durante quella
    #   sessione (depth > 0): più in giù ci sono stati di prima, dell'utente.
    def self.ended_keep(s)
      mats = {}
      s[:items].each_value do |it|
        mats[it[:temp].name] = it[:base][:material] if it[:temp] && it[:temp].valid?
        (it[:faces] ? it[:faces][:mats] : {}).each { |orig, cl| mats[cl.name] = orig if cl.valid? }
      end
      @ended = { model: s[:model], items: s[:items].to_a, mats: mats, depth: s[:depth].to_i }
    end

    # dir: -1 annulla, +1 ripeti, 0 una voce nuova sopra (operazione dell'utente)
    def self.ended_step(dir)
      r = @ended or return
      return @ended = nil unless r[:model].valid?
      r[:depth] += dir.zero? ? 1 : dir
      UI.start_timer(0, false) { ended_repair(r) } unless dir.zero?
    end

    def self.ended_repair(r)
      model = r[:model]
      return unless model.valid? && !@session && @ended.equal?(r)
      temp = model.materials.select { |m| m.name.start_with?(TEMP_MAT) }
      fix  = r[:depth] > 0 ? r[:items].select { |e, it| e.valid? && rest_off?(e, it) } : []
      return if temp.empty? && fix.empty?
      own_op(model, true) do
        swap = ->(m) { m && m.valid? && m.name.start_with?(TEMP_MAT) ? live_mat(r[:mats][m.name]) : m }
        unless temp.empty?
          r[:items].each do |e, _it|
            next unless e.valid?
            e.material = swap.(e.material) if e.respond_to?(:material) && e.material
            next unless e.respond_to?(:definition)
            e.definition.entities.grep(Sketchup::Face).each do |f|
              f.material = swap.(f.material) if f.material
              f.back_material = swap.(f.back_material) if f.back_material
            end
          end
        end
        fix.each { |e, it| rest_put(e, it) }
      end
      purge_temp_materials(model)              # quelli rimasti senza originale
      model.active_view.invalidate
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    def self.rest_props(it)
      it[:tracks].map { |tr| tr[:prop] }
    end

    def self.rest_off?(e, it)
      b = it[:base]
      p = rest_props(it)
      return true if p.include?('visible') && e.hidden? != b[:hidden]
      return true if p.include?('tag') && b[:layer] && b[:layer].valid? && e.layer != b[:layer]
      return e.get_plane.zip(b[:plane]).any? { |x, y| (x - y).abs > 1e-9 } if it[:section]
      !same_tr?(e.transformation, b[:tr])
    end

    def self.rest_put(e, it)
      b = it[:base]
      p = rest_props(it)
      e.hidden = b[:hidden] if p.include?('visible') && e.hidden? != b[:hidden]
      e.layer = b[:layer] if p.include?('tag') && b[:layer] && b[:layer].valid? && e.layer != b[:layer]
      if it[:section]
        e.set_plane(b[:plane])
      elsif !same_tr?(e.transformation, b[:tr])
        e.transformation = b[:tr]
      end
    end

    # Le operazioni della sessione: la prima è una voce vera, le altre vi si
    # accodano (trasparenti).
    def self.op_in(s, model, &blk)
      first = s[:first_op]
      s[:first_op] = false
      s[:depth] = s[:depth].to_i + 1 if first
      own_op(model, !first, &blk)
    end

    # Un'operazione non della sessione (dell'utente, di un'altra estensione,
    # una modifica delle tracce dal pannello): una trasparente si accoderebbe
    # a lei, e il suo Ctrl+Z annullerebbe anche fotogrammi e ripristino
    # (materiali temporanei di nuovo nel modello dopo lo Stop). La prossima
    # operazione della sessione apre una voce sua.
    def self.op_break
      if @session
        @session[:first_op] = true
        @session[:depth] = @session[:depth].to_i + 1     # una voce dell'utente in mezzo
      else
        ended_step(0)
      end
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
    # many: tanti oggetti di fila (dopo un annulla): durata, traiettorie e
    # pose si rifanno una volta sola alla fine (session_updated), non per
    # ciascuno; con n oggetti erano n giri su tutti gli n.
    def self.session_update(e, data, many = false)
      s = @session or return
      it = s[:items][e]
      on = data && data['tracks'].any? { |t| t['on'] }
      if it
        base = it[:base]
        trig = it[:trig]
        follow = it[:follow]
        item_remove(s, e, it)
        if on
          nit = item_add(e, data, base)
          nit[:trig] = trig if data['start']['mode'] == 'trigger'
          nit[:follow] = follow if follow && data['start']['mode'] == 'after'
        end
      elsif on
        item_add(e, data)
      end
      session_updated unless many
    end

    def self.session_updated
      s = @session or return
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
        e.material = live_mat(base[:material]) if e.material == it[:temp]
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

    # Il materiale di riposo, se esiste ancora: può essere stato eliminato
    # durante la sessione (Elimina inutilizzati), e rimetterlo solleverebbe.
    def self.live_mat(m)
      m && m.valid? ? m : nil
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
          bm = live_mat(it[:base][:material])
          base = bm ? bm.display_name : 'DagaDyn'
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
      starts = chain_starts(list)
      s[:total] = timeline_length(list, starts)
      s[:loops] = loops?(list, starts)
      s[:items].each { |e, it| it[:static] = starts[e.persistent_id] }
      s[:fx] = s[:items].each_value.any? { |it| it[:tracks].any? { |tr| tr[:fx] } }
      s[:ufac] = (unit_info(s[:model])['factor'] rescue nil) if s[:fx]
      warp_setup(s)
    end

    # ── Velocità del tempo ──────────────────────────────────────────
    # La curva del modello (read_time, lib/tracks.rb) lega l'orologio della
    # riproduzione c al tempo della timeline t, come una curva di
    # transizione: in x la riproduzione, da 0 a P secondi; in y la timeline,
    # da 0 a T (la sua durata). Dove sale ripida il tempo corre (time-lapse),
    # dove è piatta rallenta, dove scende torna indietro.
    #
    #   t = T × curva(c / P)        P: la durata scelta nel pannello, o T
    #
    # Dopo la fine (c > P) la curva ricomincia se ricomincia la timeline
    # (oggetti in ciclo, o «Ripeti»): a ogni giro lo stesso andamento.
    # Altrimenti il tempo torna normale: lì si muovono solo gli azionati e
    # chi li segue. Vale per tutto: Play, barra, azionati, DagaWASD (che
    # batte c: il video al tempo del video, la curva dentro).
    # Senza curva, o con la timeline vuota, t = c.
    def self.warp_setup(s)
      tm = read_time(s[:model])
      tt = s[:total]
      w = nil
      if tm && tt > 0
        w = { p: tm['dur'] || tt, t: tt, pts: tm['curve'], curve: curve_prepare(tm['curve']),
              round: s[:loops] || cf('play_repeat') ? true : false }
      end
      old = s[:warp]
      return if old.nil? && w.nil?
      return if old && w && old[:p] == w[:p] && old[:t] == w[:t] && old[:pts] == w[:pts] && old[:round] == w[:round]
      # dove sono adesso riproduzione e timeline, con la curva di prima
      now = Time.now.to_f
      live = s[:state] == :playing && !s[:ext]
      c = live ? clock(s, now) : s[:c]
      t = live ? warp(s, c) : s[:t]
      s[:warp] = w
      warp_keep(s, old, c, t, now)
    end

    # Durata della riproduzione della timeline (P)
    def self.play_len(s)
      s[:warp] ? s[:warp][:p] : s[:total]
    end

    def self.warp(s, c)
      w = s[:warp] or return c
      p = w[:p]
      tt = w[:t]
      return c * tt / p if c <= 0.0
      n = (c / p).floor
      return tt + (c - p) if n >= 1 && !w[:round]
      n * tt + tt * curve_eval(w[:curve], c / p - n)
    end

    # L'istante della riproduzione che dà il tempo t della timeline. Una
    # curva che torna indietro ci passa più volte: si prende la volta più
    # vicina a near (secondi della riproduzione), o la prima.
    def self.unwarp(s, t, near = nil)
      w = s[:warp] or return t
      p = w[:p]
      tt = w[:t]
      return t * p / tt if t <= 0.0
      return p + (t - tt) if t >= tt && !w[:round]
      n = w[:round] ? (t / tt).floor : 0
      u = curve_inverse(w[:curve], t / tt - n, near && near / p - n)
      (n + u) * p
    end

    # Dove la curva vale y: la curva va da 0 a 1, quindi per y fra 0 e 1
    # c'è sempre almeno un punto. Si cerca a passi, poi per bisezione.
    INV_STEPS = 256
    def self.curve_inverse(c, y, near = nil)
      return 0.0 if y <= 0.0
      return 1.0 if y >= 1.0
      best = nil
      u0 = 0.0
      f0 = 0.0
      (1..INV_STEPS).each do |i|
        u1 = i.to_f / INV_STEPS
        f1 = curve_eval(c, u1)
        if (f0 - y) * (f1 - y) <= 0.0
          x = f0 == y ? u0 : inverse_in(c, y, u0, f0, u1)
          return x unless near
          best = x if best.nil? || (x - near).abs < (best - near).abs
        end
        u0 = u1
        f0 = f1
      end
      best || 1.0
    end

    def self.inverse_in(c, y, lo, flo, hi)
      40.times do
        mid = (lo + hi) / 2
        fm = curve_eval(c, mid)
        if (flo - y) * (fm - y) <= 0.0
          hi = mid
        else
          lo = mid
          flo = fm
        end
      end
      (lo + hi) / 2
    end

    # La curva (o la durata della timeline, o la ripetizione) è cambiata:
    # la timeline resta all'istante in cui era, cambia solo da lì in avanti.
    # L'orologio della riproduzione riparte dal punto della curva nuova che
    # dà quell'istante, il più vicino a dove era su quella di prima.
    def self.warp_keep(s, old, c, t, now)
      w = s[:warp]
      near = w ? c * w[:p] / (old ? old[:p] : w[:t]) : nil   # senza curva prima: c era t
      c = unwarp(s, t, near)
      s[:c] = c
      if s[:ext]
        s[:ext_c0] = c - s[:ext_el].to_f * cf('play_speed')
      elsif s[:state] == :playing
        s[:c0] = c
        s[:wall0] = now
      end
    end

    # ── Tracce pronte per il calcolo ────────────────────────────────
    def self.prepare_tracks(data, section = false)
      data['tracks'].select { |t| t['on'] && (!section || SECTION_PROPS.include?(t['prop'])) }.map do |t|
        kind  = PROPS[t['prop']][:kind]
        color = kind == :color
        vals  = t['keys'].map { |k| color ? hex_rgb(k['v']) : k['v'] }
        segs  = t['keys'].drop(1).map { |k| { dur: k['dur'], curve: curve_prepare(k['curve']), fx: fx_prepare(k) } }
        acc   = 0.0
        { prop: t['prop'], delay: t['delay'], loop: t['loop'], vals: vals, segs: segs,
          ends: segs.map { |g| acc += g[:dur] }, fx: segs.any? { |g| g[:fx] },
          cycle: segs.sum { |g| g[:dur] }, color: color, discrete: DISCRETE.include?(kind) }
      end
    end

    # Valore di una traccia all'istante t (tempo locale dell'oggetto).
    # ctx serve alle transizioni a formula (lib/formula.rb): da dove
    # leggere gli altri oggetti e a che istante della timeline corrisponde t.
    def self.track_value(tr, t, ctx = nil)
      vals = tr[:vals]
      tau  = t - tr[:delay]
      c    = tr[:cycle]
      return finish(tr, vals[0]) if tau <= 0 || vals.size == 1
      ctx ||= { w: nil, off: 0.0, f: fx_factor } if tr[:fx]
      base = tr[:delay]                       # tempo locale in cui è cominciato questo giro
      return finish(tr, seg_from(tr, tr[:segs].size, base, ctx)) if c <= 0
      case tr[:loop]
      when 'loop'
        n = (tau / c).floor
        tau -= n * c
        base += n * c
      when 'pingpong'
        n = (tau / (2 * c)).floor
        tau -= n * 2 * c
        base += n * 2 * c
        tau = 2 * c - tau if tau > c
      else
        return finish(tr, seg_from(tr, tr[:segs].size, base, ctx)) if tau >= c
      end
      start = 0.0
      tr[:segs].each_with_index do |g, i|
        d = g[:dur]
        if tau <= start + d && d > 0
          x = (tau - start) / d
          if g[:fx]
            v0 = seg_from(tr, i, base, ctx)
            v = fx_eval(tr, g, x, tau - start, v0, t + ctx[:off], ctx)
            return finish(tr, v || v0)
          end
          e = curve_eval(g[:curve], x)
          a = tr[:fx] ? seg_from(tr, i, base, ctx) : vals[i]
          b = vals[i + 1]
          # a scatti: si passa allo stato quando la sua transizione finisce
          return finish(tr, e >= 1.0 - 1e-9 ? b : a) if tr[:discrete]
          return finish(tr, tr[:color] ? mix_color(a, b, e) : a + (b - a) * e)
        end
        start += d
      end
      finish(tr, seg_from(tr, tr[:segs].size, base, ctx))
    end

    # Il valore da cui parte la transizione i (= dove è arrivata quella
    # prima): lo stato scritto, oppure, dopo una transizione a formula,
    # dove la formula ha portato l'oggetto alla sua fine, con i parametri
    # di quell'istante (base: tempo locale d'inizio del giro). i = numero
    # delle transizioni: lo stato finale.
    def self.seg_from(tr, i, base, ctx)
      g = i > 0 ? tr[:segs][i - 1] : nil
      return tr[:vals][i] unless g && g[:fx]
      v0 = seg_from(tr, i - 1, base, ctx)
      v = fx_eval(tr, g, 1.0, g[:dur], v0, base + tr[:ends][i - 1] + ctx[:off], ctx)
      v.nil? ? v0 : finish(tr, v)
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
    # Chi sta sulla timeline ha la partenza già calcolata (it[:static], da
    # chain_starts in recalc_total). Per le catene dietro un azionato si
    # risale fino all'azionato senza ricorsione: nessun limite di lunghezza,
    # e un giro chiuso dà nil.
    def self.item_start(s, it)
      acc  = 0.0
      seen = {}
      cur  = it
      loop do
        return nil if seen[cur.object_id]
        seen[cur.object_id] = true
        return acc + cur[:static] if cur[:static]
        st = cur[:data]['start']
        return nil if st['mode'] == 'trigger'
        return acc if st['mode'] != 'after'
        pred = s[:by_pid][st['after']]
        return acc + st['wait'] unless pred && !pred.equal?(cur)
        acc += st['wait']
        if pred[:data]['start']['mode'] == 'trigger'
          pe = trig_end(pred)
          return pe && acc + pe
        end
        acc += pred[:len]
        cur = pred
      end
    end

    def self.item_end(s, it)
      if it[:data]['start']['mode'] == 'trigger'
        trig_end(it)
      else
        st = item_start(s, it)
        st && st + it[:len]
      end
    end

    # Fine del primo giro di un azionato (nil: fermo, o torna indietro)
    def self.trig_end(it)
      g = it[:trig] or return nil
      return g[:at] + it[:len] if g[:act] == 'play'
      g[:dir] > 0 ? g[:at] + (it[:len] - g[:from]) : nil
    end

    # Tempo locale: prima della partenza è negativo (stato iniziale).
    def self.item_local(s, it, t)
      return it[:pin] if it[:pin]            # anteprima di uno stato (cmd_preview)
      if it[:data]['start']['mode'] == 'trigger'
        g = it[:trig] or return 0.0
        return t - g[:at] if g[:act] == 'play'
        return g[:from] if g[:dir].zero?
        x = g[:from] + g[:dir] * (t - g[:at])
        x = [x, it[:len]].min unless it[:loops] && g[:dir] > 0
        [x, 0.0].max
      else
        f = it[:follow]
        if f                                  # dietro un avanti/indietro (trigger_item)
          run = [t - f[:start], 0.0].max      # fermo dov'era finché non tocca a lui
          return [f[:from] - run, 0.0].max if f[:dir] < 0
          x = f[:from] + run
          return it[:loops] ? x : [x, it[:len]].min
        end
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
          if (f = it[:follow])
            x = item_local(s, it, t)
            f[:dir] > 0 ? (it[:loops] || x < it[:len]) : x > 0
          else
            stt = item_start(s, it)
            stt && (it[:loops] || t < stt + it[:len])
          end
        else
          false
        end
      end
    end

    # Azionare un oggetto all'istante t della sessione.
    #   play: riparte da capo; toggle: va avanti, alla volta dopo torna
    #   indietro (anche a metà corsa: inverte da dov'è).
    #   Chi è in catena dietro un avanti/indietro ne segue la direzione
    #   (leva → ponte levatoio), in tutte e due le direzioni con la regola
    #   di «dopo un altro oggetto»: resta fermo dov'è finché quello prima
    #   di lui nella catena non ha finito, aspetta la sua attesa, poi va
    #   avanti o torna indietro da dove era arrivato.
    #   follow = { dir, from: dove era, start: quando riparte, end: quando arriva }
    def self.trigger_item(s, it, t)
      clear_pins(s)
      toggle = it[:data]['start']['act'] == 'toggle'
      # chi è in catena dietro questo azionato, e dove si trova adesso
      # (prima di cambiare l'azionato, da cui dipende)
      chained = s[:items].each_value.filter_map do |x|
        next if x.equal?(it)
        link = chain_link(s, x)
        [x, link[1], item_local(s, x, t)] if link && link[0].equal?(it)
      end
      if toggle
        cur = item_local(s, it, t)
        dir = it[:trig] && it[:trig][:dir] > 0 ? -1 : 1
        it[:trig] = { act: 'toggle', at: t, from: cur.clamp(0.0, [it[:len], 0.0].max), dir: dir }
      else
        it[:trig] = { act: 'play', at: t, from: 0.0, dir: 1 }
      end
      unless toggle
        chained.each { |x, _d, _l| x.delete(:follow) }
        return
      end
      g = it[:trig]
      root_end = t + (g[:dir] > 0 ? it[:len] - g[:from] : g[:from])   # quando l'azionato arriva
      # dal più vicino all'azionato al più lontano: ognuno parte quando arriva chi lo precede
      chained.sort_by { |_x, d, _l| d }.each do |x, _d, loc|
        st    = x[:data]['start']
        pred  = s[:by_pid][st['after']]
        pend  = pred.equal?(it) ? root_end : pred[:follow][:end]
        from  = loc.clamp(0.0, [x[:len], 0.0].max)
        start = pend + st['wait']
        x[:follow] = { dir: g[:dir], from: from, start: start,
                       end: start + (g[:dir] > 0 ? x[:len] - from : from) }
      end
    end

    # L'azionato da cui dipende un oggetto in catena e quanti anelli li
    # separano: [azionato, anelli], o nil (nessuno, o giro chiuso).
    def self.chain_link(s, it)
      seen  = {}
      cur   = it
      depth = 0
      loop do
        return nil if seen[cur.object_id]
        seen[cur.object_id] = true
        st = cur[:data]['start']
        return (cur.equal?(it) ? nil : [cur, depth]) if st['mode'] == 'trigger'
        return nil unless st['mode'] == 'after'
        pred = s[:by_pid][st['after']]
        return nil unless pred && !pred.equal?(cur)
        cur = pred
        depth += 1
      end
    end

    # Le anteprime ferme (cmd_preview) finiscono quando la timeline riparte
    def self.clear_pins(s)
      s[:items].each_value { |it| it.delete(:pin) }
    end

    # La timeline torna indietro di delta (ripetizione), l'orologio della
    # riproduzione di dc (con la velocità del tempo, giri interi: n × P per
    # n × T): azionati e catene restano dove sono.
    def self.shift_time(s, delta, dc = delta)
      s[:c0]     -= dc
      s[:ext_c0] -= dc
      s[:items].each_value do |it|
        it[:trig][:at] -= delta if it[:trig]
        next unless it[:follow]
        it[:follow][:start] -= delta
        it[:follow][:end]   -= delta
      end
    end

    # ── Applicazione ────────────────────────────────────────────────
    def self.apply(t, force = false)
      s = @session or return
      s[:t] = t
      s[:tick] += 1
      jobs = []
      moved = []
      w = s[:fx] ? fx_world_session(s) : nil   # transizioni a formula: chi legge chi
      s[:items].each do |e, it|
        next unless e.valid?
        local = item_local(s, it, t)
        ctx = w && { w: w, off: t - local, f: w[:f] }
        v = {}
        it[:tracks].each { |tr| v[tr[:prop]] = track_value(tr, local, ctx) }
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
      if !s[:loops] && s[:total] > 0 && s[:c] >= play_len(s) - 1e-6 && !busy_at?(s, s[:t])
        shift_time(s, s[:t], s[:c])
        s[:t] = 0.0
        s[:c] = 0.0
      end
      clear_pins(s)
      s[:state] = :playing
      s[:c0]    = s[:c]
      s[:wall0] = Time.now.to_f
      shadows_off(s)
      driver_start(s[:model])
      panel_transport
    end

    def self.cmd_pause
      s = @session or return
      return if s[:ext]
      if s[:state] == :playing
        s[:c] = clock(s, Time.now.to_f)
        s[:t] = warp(s, s[:c])
      end
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
    # La barra è il tempo della timeline: con la velocità del tempo
    # l'orologio della riproduzione va al punto della curva che lo dà.
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
      clear_pins(s)
      s[:c] = unwarp(s, t, s[:c])
      s[:t] = t
      if s[:state] == :playing
        s[:c0] = s[:c]
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
      clear_pins(s)
      st = item_start(s, it)
      local = local.to_f.clamp(0.0, [it[:len], 0.0].max)
      if it[:data]['start']['mode'] == 'trigger'
        it[:trig] = { act: 'toggle', at: s[:t], from: local, dir: 0 }
      elsif st
        s[:t] = [st + local, 0.0].max
        s[:c] = unwarp(s, s[:t], s[:c])
      else
        # in catena dietro un azionato non ancora partito (o in un giro
        # chiuso): non ha un istante sulla timeline, resta fermo lì
        # finché non si riparte (clear_pins)
        it[:pin] = local
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

    # L'orologio della riproduzione (c): il tempo della timeline è warp(s, c)
    def self.clock(s, now)
      s[:c0] + (now - s[:wall0]) * cf('play_speed')
    end

    # Velocità cambiata (pannello, importazione): il tempo fin qui resta
    # quello corso alla velocità di prima, cambia solo da adesso in poi.
    # Senza, c = c0 + trascorso × velocità salterebbe avanti o indietro.
    def self.speed_kept(old)
      s = @session or return
      now_speed = cf('play_speed')
      return if old.nil? || now_speed == old
      if s[:ext]
        s[:ext_c0] += s[:ext_el].to_f * (old - now_speed)
      elsif s[:state] == :playing
        now = Time.now.to_f
        s[:c0] += (now - s[:wall0]) * old
        s[:wall0] = now
      end
    end

    # Fine della timeline: ricomincia (ripetizione) o si ferma. Con un
    # azionato in moto o con lo strumento Aziona (hold) si va avanti.
    # Si decide sull'orologio della riproduzione c: con la velocità del
    # tempo la timeline può superare la sua fine prima (una curva che va
    # oltre la meta e torna). Ritorna il c da applicare, o nil per fermarsi.
    def self.timeline_end(s, c)
      len = play_len(s)
      return c if s[:loops] || c < len || busy_at?(s, warp(s, c))
      if cf('play_repeat') && len > 0
        n = (c / len).floor
        shift_time(s, n * s[:total], n * len)
        return c - n * len
      end
      return c if s[:hold] || s[:ext]
      nil
    end

    # Un passo: tempo, fine o ripetizione, applicazione. true = continua.
    def self.advance(now = Time.now.to_f)
      s = @session
      return false unless s && s[:state] == :playing && s[:model].valid?
      c_now = clock(s, now)
      c = timeline_end(s, c_now)
      unless c
        # Fermi all'istante raggiunto, non alla fine della timeline: un
        # azionato (e chi gli va dietro) può essere finito dopo, e tornare
        # a s[:total] lo faceva scattare indietro (il ponte a metà corsa).
        s[:c] = c_now
        apply([warp(s, c_now), s[:total]].max)
        s[:state] = :paused
        shadows_back(s)
        panel_transport
        return false
      end
      s[:c] = c
      apply(warp(s, c))
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
    # Qui SketchUp sta già salvando: niente operazioni, solo i valori. I
    # materiali temporanei si tolgono del tutto (nel file non devono finire
    # nemmeno nell'elenco dei materiali) e si rifanno dopo. Visibilità e tag
    # si rimettono solo se una traccia li anima: un oggetto nascosto a mano
    # durante la sessione resta nascosto.
    def self.session_suspend
      s = @session or return
      s[:suspended] = true
      model = s[:model]
      s[:items].each do |e, it|
        next unless e.valid?
        base = it[:base]
        props = it[:tracks].map { |tr| tr[:prop] }
        if it[:last_tr] && !it[:section]
          item_rebase(e, it)                 # spostato a mano in pausa: è il nuovo riposo
          place(e, it[:base][:tr])
          base = it[:base]
        end
        if it[:temp]
          e.material = live_mat(base[:material]) if e.material == it[:temp]
          model.materials.remove(it[:temp]) if it[:temp].valid?
          it[:temp] = nil
        end
        if it[:faces]
          faces_restore(model, it[:faces])
          it[:faces] = nil
        end
        e.hidden = base[:hidden] if props.include?('visible') && e.hidden? != base[:hidden]
        e.layer = base[:layer] if props.include?('tag') && base[:layer] && base[:layer].valid? && e.layer != base[:layer]
        e.set_plane(base[:plane]) if it[:section] && it[:plane_moved]
      end
      model.shadow_info['DisplayShadows'] = true if s[:shadows]
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    def self.session_resume
      s = @session or return
      return unless s.delete(:suspended)
      s[:items].each do |e, it|
        next unless e.valid?
        item_material(s, e, it)              # materiali temporanei di nuovo
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
