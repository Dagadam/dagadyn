# DagaDyn — Tracce: lettura, scrittura e controllo dei dati sugli oggetti.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    # ══════════════════════════════════════════════════════════════
    # I dati stanno sull'istanza (gruppo o componente) o sul piano di
    # sezione, nel dizionario DICT, chiave DATA_KEY, come JSON: viaggiano
    # dentro il file .skp e con le copie dell'oggetto.
    #
    #   { "v": 1,
    #     "pivot": "base",                      punto di riferimento (PIVOTS)
    #     "axes": "object",                     rotazioni sugli assi dell'oggetto o del contenitore (AXES)
    #     "faces": false,                       colore e opacità anche sulle facce con materiale proprio
    #     "start": { "mode": "time",            quando parte (START_MODES):
    #                "after": 1234,             …dopo l'oggetto con questo persistent_id
    #                "wait": 0.0,               …più un'attesa (s)
    #                "act": "play" },           azionato: riparte (play) o avanti/indietro (toggle)
    #     "tracks": [
    #       { "id": "k3f9",                     identificativo stabile (pannello)
    #         "prop": "size_z",                 proprietà (PROPS)
    #         "on": true,                       traccia attiva
    #         "delay": 0.0,                     s prima della prima transizione
    #         "loop": "none",                   none | loop | pingpong
    #         "keys": [                         stati, in ordine di tempo
    #           { "v": 118.11 },                stato iniziale
    #           { "v": 157.48,                  stato successivo…
    #             "dur": 1.0,                   …raggiunto in dur secondi
    #             "preset": "ease_in_out",      curva scelta (o "custom")
    #             "curve": [[0,0],…,[1,1]],     punti della curva (lib/curves.rb)
    #             "fx": { "on": true, … } }     oppure una formula (lib/formula.rb)
    #         ] } ] }
    #
    # Valori nelle unità interne: lunghezze in pollici (come SketchUp),
    # angoli in gradi, scala in ×, opacità 0–1, visibile 0/1, colori
    # '#rrggbb', tag per nome. Il pannello converte le lunghezze
    # nell'unità del modello.
    # ══════════════════════════════════════════════════════════════

    MAX_TRACKS = 64
    MAX_KEYS   = 32
    MAX_DUR    = 3600.0

    def self.animatable?(e)
      e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) || section?(e)
    end

    def self.section?(e)
      defined?(Sketchup::SectionPlane) ? e.is_a?(Sketchup::SectionPlane) : false
    end

    def self.read_data(e)
      return nil unless animatable?(e) && e.valid?
      raw = e.get_attribute(DICT, DATA_KEY)
      return nil unless raw.is_a?(String) && !raw.empty?
      sanitize_data(JSON.parse(raw))
    rescue JSON::ParserError
      nil
    rescue => dyn_err
      log_error(__method__, dyn_err)
      nil
    end

    # Va chiamata dentro un'operazione. Nessuna traccia: il dizionario sparisce.
    def self.write_data(e, data)
      anim_dirty
      data = sanitize_data(data)
      if data['tracks'].empty?
        e.attribute_dictionaries.delete(DICT) if e.attribute_dictionaries && e.attribute_dictionary(DICT)
      else
        e.set_attribute(DICT, DATA_KEY, JSON.generate(data))
        e.set_attribute(DICT, SELF_KEY, e.persistent_id.to_s)   # per riconoscerne le copie (copies_adopt)
      end
      section_register(e, !data['tracks'].empty?) if section?(e)
      data
    end

    # I piani di sezione animati si ricordano nel modello per persistent_id:
    # trovarli scorrendo tutte le entità costerebbe troppo nei modelli grandi.
    def self.section_register(e, on)
      model = e.model
      list = section_pids(model)
      list = on ? (list | [e.persistent_id]) : (list - [e.persistent_id])
      model.set_attribute(DICT, SECTIONS_KEY, section_prune(model, list).join(','))
    end

    def self.section_pids(model)
      model.get_attribute(DICT, SECTIONS_KEY, '').to_s.split(',').map(&:to_i).reject(&:zero?)
    end

    # Via gli id dei piani che non esistono più (eliminati)
    def self.section_prune(model, list)
      return list unless model.respond_to?(:find_entity_by_persistent_id)
      list.select do |pid|
        x = (model.find_entity_by_persistent_id(pid) rescue nil)
        x && x.valid? && section?(x)
      end
    end

    # Un piano animato copiato (Copia/Incolla, Sposta con Ctrl) porta con sé
    # i dati, ma non è nell'elenco del modello: non si animerebbe. Dopo ogni
    # operazione si guardano i piani selezionati (la copia lo è) e quelli
    # nuovi entrano nell'elenco, in un'operazione trasparente che si accoda
    # alla copia: annullando la copia sparisce anche questo. Nello stesso
    # giro le copie degli oggetti collegati (copies_adopt).
    def self.section_adopt_soon
      return if @adopt_timer
      @adopt_timer = UI.start_timer(0, false) do
        @adopt_timer = nil
        section_adopt(Sketchup.active_model)
        copies_adopt(Sketchup.active_model)
      end
    end

    def self.section_adopt(model)
      return unless model && model.valid?
      have  = section_pids(model)
      fresh = model.selection.select do |e|
        section?(e) && e.valid? && e.attribute_dictionary(DICT) && !have.include?(e.persistent_id)
      end
      fresh = fresh.map { |e| [e, read_data(e)] }.select { |_e, d| d && !d['tracks'].empty? }
      return if fresh.empty?
      list = section_prune(model, have + fresh.map { |e, _| e.persistent_id })
      own_op(model, true) { model.set_attribute(DICT, SECTIONS_KEY, list.join(',')) }
      if @session && @session[:model] == model
        fresh.each { |e, d| session_update(e, d, true) }
        session_updated
      end
      paths_dirty
      panel_selection_soon
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # ══════════════════════════════════════════════════════════════
    # Copie di oggetti collegati. La partenza «dopo un altro oggetto» e i
    # parametri delle formule ricordano l'altro oggetto per persistent_id,
    # e una copia si porta dietro i dati com'erano. Copiati insieme
    # (Copia/Incolla, Sposta con Ctrl, una serie, un gruppo che li
    # contiene), i collegamenti fra loro passano alle copie: la lastra
    # copiata legge il cubo copiato, e un parametro «questo oggetto» legge
    # la copia stessa. Verso un oggetto non copiato restano com'erano.
    #
    # Di chi è copia: ogni oggetto porta il proprio persistent_id
    # (SELF_KEY, scritto da write_data); in una copia non è più il suo.
    # Dati scritti prima, senza: un oggetto nuovo con gli stessi identici
    # dati di uno solo di quelli che c'erano. Più copie dello stesso
    # oggetto nella stessa operazione (una serie): un collegamento va alla
    # copia spostata allo stesso modo (stessa trasformazione dall'originale
    # alla copia, nel mondo).
    #
    # Si confronta con gli oggetti animati che c'erano dopo l'operazione di
    # prima (copies_known: all'apertura, dopo ogni operazione e annulla);
    # le modifiche vanno in un'operazione trasparente accodata alla copia.
    # ══════════════════════════════════════════════════════════════
    SELF_KEY = 'pid'

    def self.copies_known(model)
      @copies_seen = model && model.valid? ? [model, anim_candidates(model).to_h { |e| [e.persistent_id, e] }] : nil
    rescue => dyn_err
      log_error(__method__, dyn_err)
      @copies_seen = nil
    end

    def self.copies_adopt(model)
      return unless model && model.valid?
      seen = @copies_seen
      copies_known(model)
      return unless seen && seen[0].equal?(model)
      known = seen[1]
      fresh = anim_candidates(model).reject { |e| known.key?(e.persistent_id) }
      return if fresh.empty?
      origin = {}
      twins = {}
      fresh.each do |e|
        st = e.get_attribute(DICT, SELF_KEY).to_s
        if st.empty?
          tw = copy_twins(e, known)
          next twins[e] = tw if tw.size > 1
          o = tw[0]
        else
          o = st.to_i
        end
        origin[e] = o if o && o != e.persistent_id
      end
      # più oggetti di prima con gli stessi dati: quello da cui la copia è
      # spostata come le altre copie di questa operazione
      unless twins.empty?
        moves = origin.filter_map { |e, o| copy_delta(model, e, o) }
        twins.each do |e, tw|
          hit = tw.select { |x| (dd = copy_delta(model, e, x)) && moves.any? { |mv| copy_same?(dd, mv) } }
          origin[e] = hit[0] if hit.size == 1
        end
      end
      by_orig = {}
      origin.each { |e, o| (by_orig[o] ||= []) << e }
      jobs = fresh.filter_map do |e|
        data = read_data(e) or next
        o = origin[e]
        relinked = o ? copy_relink(model, e, o, data, by_orig) : data
        changed = relinked != data
        next unless changed || e.get_attribute(DICT, SELF_KEY).to_s != e.persistent_id.to_s
        [e, relinked, changed]
      end
      return if jobs.empty?
      own_op(model, true) do
        jobs.each { |e, d, changed| changed ? write_data(e, d) : e.set_attribute(DICT, SELF_KEY, e.persistent_id.to_s) }
      end
      copies_known(model)
      moved = jobs.select { |_e, _d, changed| changed }
      return if moved.empty?
      if @session && @session[:model] == model
        moved.each { |e, d, _| session_update(e, d, true) }
        session_updated
      end
      paths_dirty
      panel_selection_soon
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # Dati senza SELF_KEY: gli oggetti di prima con gli stessi dati
    def self.copy_twins(e, known)
      raw = e.get_attribute(DICT, DATA_KEY)
      known.values.select { |x| x.valid? && x.get_attribute(DICT, DATA_KEY) == raw }.map(&:persistent_id)
    end

    # I dati della copia e con i collegamenti verso gli oggetti copiati
    # insieme a lei (o è l'originale di e)
    def self.copy_relink(model, e, o, data, by_orig)
      mine = nil
      pick = lambda do |p|
        list = by_orig[p] or return p
        return list[0].persistent_id if list.size == 1
        mine ||= copy_delta(model, e, o) or return p
        hit = list.find { |c| (dd = copy_delta(model, c, p)) && copy_same?(dd, mine) }
        hit ? hit.persistent_id : p
      end
      d = JSON.parse(JSON.generate(data))
      st = d['start']
      st['after'] = pick.call(st['after']) if st['after'] != 0
      d['tracks'].each do |t|
        t['keys'].each do |k|
          f = k['fx'] or next
          f['params'].each { |q| q['pid'] = pick.call(q['pid']) if q['pid'] != 0 }
        end
      end
      d
    end

    # Da dove sta l'originale (persistent_id o) a dove sta la copia c, nel mondo
    def self.copy_delta(model, c, o)
      x = model.find_entity_by_persistent_id(o) rescue nil
      return nil unless x && x.valid? && animatable?(x) && !section?(x) && !section?(c)
      (world_of(c) * c.transformation) * (world_of(x) * x.transformation).inverse
    end

    def self.copy_same?(a, b)
      a.to_a.zip(b.to_a).all? { |p, q| (p - q).abs < 1e-3 }
    end

    # ══════════════════════════════════════════════════════════════
    # Velocità del tempo: una curva per tutto il modello, negli attributi
    # del modello (dizionario DICT, chiave TIME_KEY), come JSON:
    #
    #   { "v": 1,
    #     "preset": "ease_in",                curva scelta (o "custom")
    #     "curve": [[0,0],…,[1,1]],           in x la riproduzione, in y la timeline (0–1)
    #     "dur": 10.0 }                       quanto dura la riproduzione della timeline (s);
    #                                         senza: quanto la timeline
    #
    # Come la usa il motore: lib/player.rb (warp). Lineare e senza durata è
    # il tempo normale: la chiave resta vuota.
    # ══════════════════════════════════════════════════════════════
    TIME_DUR_MIN = 0.1

    def self.read_time(model)
      raw = model.get_attribute(DICT, TIME_KEY, '')
      return nil unless raw.is_a?(String) && !raw.empty?
      d = sanitize_time(JSON.parse(raw))
      time_plain?(d) ? nil : d
    rescue JSON::ParserError
      nil
    rescue => dyn_err
      log_error(__method__, dyn_err)
      nil
    end

    # Va chiamata dentro un'operazione. Ritorna i dati scritti (nil: tempo normale).
    def self.write_time(model, d)
      d = sanitize_time(d)
      plain = time_plain?(d)
      model.set_attribute(DICT, TIME_KEY, plain ? '' : JSON.generate(d))
      plain ? nil : d
    end

    def self.sanitize_time(d)
      d = {} unless d.is_a?(Hash)
      preset = d['preset'].to_s
      preset = 'linear' unless PRESET_POINTS.key?(preset) || preset == 'custom'
      out = { 'v' => DATA_VER, 'preset' => preset,
              'curve' => sanitize_points(d['curve'].is_a?(Array) ? d['curve'] : preset_points(preset)) }
      dur = d['dur']
      out['dur'] = dur.to_f.clamp(TIME_DUR_MIN, MAX_DUR) if dur.is_a?(Numeric) && dur.to_f.finite? && dur.to_f > 0
      out
    end

    def self.time_plain?(d)
      d['dur'].nil? && d['curve'] == [[0.0, 0.0], [1.0, 1.0]]
    end

    def self.empty_data
      { 'v' => DATA_VER, 'pivot' => cf('new_pivot'), 'axes' => 'object', 'faces' => false,
        'start' => default_start, 'tracks' => [] }
    end

    def self.default_start
      { 'mode' => 'time', 'after' => 0, 'wait' => 0.0, 'act' => 'play' }
    end

    def self.sanitize_data(d)
      d = {} unless d.is_a?(Hash)
      pivot  = PIVOTS.include?(d['pivot']) ? d['pivot'] : 'base'
      tracks = (d['tracks'].is_a?(Array) ? d['tracks'] : []).filter_map { |t| sanitize_track(t) }
      st = d['start'].is_a?(Hash) ? d['start'] : {}
      start = {
        'mode'  => START_MODES.include?(st['mode']) ? st['mode'] : 'time',
        'after' => st['after'].is_a?(Numeric) ? st['after'].to_i : 0,
        'wait'  => num(st['wait']).clamp(0.0, MAX_DUR),
        'act'   => TRIGGER_ACTS.include?(st['act']) ? st['act'] : 'play'
      }
      { 'v' => DATA_VER, 'pivot' => pivot, 'axes' => AXES.include?(d['axes']) ? d['axes'] : 'object',
        'faces' => d['faces'] == true, 'start' => start, 'tracks' => tracks.first(MAX_TRACKS) }
    end

    def self.num(v, dflt = 0.0)
      v.is_a?(Numeric) && v.to_f.finite? ? v.to_f : dflt
    end

    def self.sanitize_value(prop, v)
      spec = PROPS[prop]
      case spec[:kind]
      when :color
        c = hex_rgb(v)
        c ? rgb_hex(c) : '#ffffff'
      when :tag
        v.is_a?(String) ? v[0, 128] : ''
      when :bool
        v == true || (v.is_a?(Numeric) && v.to_f >= 0.5) ? 1.0 : 0.0
      else
        x = num(v, spec[:rel] || 0.0)
        x = [x, spec[:min]].max if spec[:min]
        x = [x, spec[:max]].min if spec[:max]
        x
      end
    end

    def self.sanitize_track(t)
      return nil unless t.is_a?(Hash) && PROPS.key?(t['prop'])
      prop = t['prop']
      keys = (t['keys'].is_a?(Array) ? t['keys'] : []).select { |k| k.is_a?(Hash) }.first(MAX_KEYS)
      return nil if keys.empty?
      keys = keys.each_with_index.map do |k, i|
        out = { 'v' => sanitize_value(prop, k['v']) }
        if i > 0
          out['dur']    = num(k['dur'], 1.0).clamp(0.0, MAX_DUR)
          preset        = k['preset'].to_s
          out['preset'] = PRESET_POINTS.key?(preset) || preset == 'custom' ? preset : 'linear'
          out['curve']  = sanitize_points(k['curve'].is_a?(Array) ? k['curve'] : preset_points(out['preset']))
          fx = sanitize_fx(prop, k['fx'])
          out['fx'] = fx if fx
        end
        out
      end
      id = t['id'].to_s
      id = new_id if id.empty? || id.size > 24 || id !~ /\A[\w-]+\z/
      { 'id' => id, 'prop' => prop, 'on' => t['on'] != false,
        'delay' => num(t['delay']).clamp(0.0, MAX_DUR),
        'loop' => LOOPS.include?(t['loop']) ? t['loop'] : 'none',
        'keys' => keys }
    end

    def self.new_id
      @id_seq = (@id_seq || 0) + 1
      (Time.now.to_f * 1000).to_i.to_s(36)[-5..] + @id_seq.to_s(36)
    end

    # Durata di un ciclo (somma delle transizioni) e della traccia intera
    # fino a che smette di cambiare (una volta, o un'andata e ritorno).
    def self.track_cycle(t)
      t['keys'].drop(1).sum { |k| k['dur'] }
    end

    def self.track_length(t)
      t['delay'] + track_cycle(t) * (t['loop'] == 'pingpong' ? 2 : 1)
    end

    # Durata dell'animazione di un oggetto (le tracce in ciclo contano un giro)
    def self.data_length(data)
      data['tracks'].select { |t| t['on'] }.map { |t| track_length(t) }.max || 0.0
    end

    def self.data_loops?(data)
      data['tracks'].any? { |t| t['on'] && t['loop'] != 'none' && track_cycle(t) > 0 }
    end

    # Tutte le istanze animate del modello (anche dentro altri gruppi) e i
    # piani di sezione animati: [[entità, dati], …]. Le istanze dentro una
    # definizione vista più volte compaiono una volta sola: animarle muove
    # tutte le copie del contenitore.
    # Le istanze con il dizionario di DagaDyn. Trovarle vuol dire scorrere
    # tutte le istanze del modello (decine di migliaia nei modelli grandi),
    # e il pannello lo chiederebbe a ogni cambio di selezione: l'elenco si
    # tiene finché il modello non cambia (anim_dirty: ogni operazione,
    # annulla/ripeti, write_data, documento nuovo). I dati si rileggono
    # sempre, l'elenco serve solo a non cercare.
    def self.anim_dirty
      @anim_cache = nil
    end

    def self.anim_candidates(model)
      c = @anim_cache
      return c[1] if c && c[0].equal?(model) && c[1].all?(&:valid?)
      list = []
      model.definitions.each do |d|
        next if d.image?
        d.instances.each { |e| list << e if e.attribute_dictionary(DICT) && in_model?(e) }
      end
      @anim_cache = [model, list]
      list
    end

    # Un'istanza dentro un componente che nel modello non è più usato (tutte
    # le copie eliminate: resta fra i componenti «Nel modello») non si vede e
    # non si anima. Senza questo controllo compariva nella Scena e la sua
    # durata allungava la timeline. Rimesso nel modello il componente,
    # l'oggetto torna animato (è un'operazione: l'elenco si rifà).
    def self.in_model?(e)
      p = e.parent
      !p.is_a?(Sketchup::ComponentDefinition) || p.count_used_instances > 0
    end

    def self.animated_instances(model)
      out = []
      anim_candidates(model).each do |e|
        data = read_data(e)
        out << [e, data] if data && data['tracks'].any? { |t| t['on'] }
      end
      section_pids(model).each do |pid|
        e = model.find_entity_by_persistent_id(pid) rescue nil
        next unless e && section?(e) && e.valid?
        data = read_data(e)
        out << [e, data] if data && data['tracks'].any? { |t| t['on'] }
      end
      out
    rescue => dyn_err
      log_error(__method__, dyn_err)
      []
    end

    # ── Partenze ────────────────────────────────────────────────────
    # Istante della timeline in cui parte ogni oggetto: 0 con la timeline;
    # dopo un altro oggetto, quando quello finisce, più l'attesa (se quello
    # non è animato: dopo l'attesa); azionato, o in catena dietro un
    # azionato: nil, non è sulla timeline. Catene circolari: nil.
    #   list: [[entità, dati], …] → { persistent_id => secondi | nil }
    # Senza ricorsione né limite di lunghezza: si risale la catena fino a un
    # oggetto con la partenza già nota (o a un giro chiuso), poi si ridiscende
    # sommando durate e attese. Il risultato non dipende dall'ordine di list.
    def self.chain_starts(list)
      by = {}
      list.each { |e, d| by[e.persistent_id] = d }
      memo = {}
      by.each_key do |first|
        next if memo.key?(first)
        path = []
        on_path = {}
        pid = first
        val = nil
        loop do
          if memo.key?(pid) then val = memo[pid]; break end
          if on_path[pid] then val = nil; break end            # catena circolare
          st = by[pid]['start'] || default_start
          pred = st['after']
          linked = st['mode'] == 'after' && pred != pid && by.key?(pred)
          unless linked
            val = case st['mode']
                  when 'trigger' then nil
                  when 'after'   then st['wait']                # dopo un oggetto non animato
                  else 0.0
                  end
            memo[pid] = val
            break
          end
          on_path[pid] = true
          path << pid
          pid = pred
        end
        path.reverse_each do |p|
          val = val && val + data_length(by[pid]) + (by[p]['start'] || default_start)['wait']
          memo[p] = val
          pid = p
        end
      end
      memo
    end

    def self.timeline_length(list, starts = chain_starts(list))
      list.filter_map { |e, data| (s = starts[e.persistent_id]) && s + data_length(data) }.max || 0.0
    end

    def self.loops?(list, starts = chain_starts(list))
      list.any? { |e, data| starts[e.persistent_id] && data_loops?(data) }
    end

  end
end
