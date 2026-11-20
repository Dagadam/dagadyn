# DagaDyn — Pannello (HtmlDialog): callback, oggetto selezionato, timeline, esporta/importa.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    def self.panel_open?; @dialog && @dialog.visible?; end

    def self.js(code)
      @dialog.execute_script(code) if panel_open?
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # Invia al pannello dizionario, elenco lingue, impostazioni e stato.
    # L'ordine conta: applyLang ricostruisce il DOM, quindi i valori
    # vanno ricaricati subito dopo.
    def self.push_panel_state
      return unless @dialog
      load_lang
      payload = {
        'strings'   => @lang,
        'languages' => lang_index,
        'current'   => (panel_cfg['language'] || 'auto'),
        'shared'    => ui_shared? ? SHARED_UI : [],     # lingua e aspetto vengono da DagaWASD
        'resolved'  => @lang_code,
        'rtl'       => @lang_rtl,
        'presets'   => PRESET_POINTS,
        'version'   => (defined?(DagaDyn::Loader::VERSION) ? DagaDyn::Loader::VERSION : '')
      }
      @dialog.execute_script("applyLang(#{js_json(payload)})")
      # I valori predefiniti esistono solo qui (DEFAULT): il pannello li
      # riceve per "Ripristina", per i segni di modifica e per la guida.
      @dialog.execute_script("setDefaults(#{js_json(DEFAULT)})")
      @dialog.execute_script("loadSettings(#{js_json(panel_cfg)})")
      @ui_sig = wasd_ui
      @dialog.execute_script("setLogCount(#{log_count})")
      panel_transport
      panel_selection
    rescue => dyn_err; log_error(__method__, dyn_err); nil; end

    # ── Timeline ────────────────────────────────────────────────────
    # La barra mostra il tempo della timeline. Mentre DagaWASD batte il tempo
    # (ext) vale l'ultimo istante applicato: l'orologio del Play è fermo, e
    # leggerlo dava un numero senza senso (la timeline sempre in fondo).
    def self.transport_state
      s = @session
      return { 'state' => 'stop', 't' => 0.0, 'total' => scene_total, 'loops' => false } unless s
      t = s[:t]
      if s[:state] == :playing && !s[:ext]
        c = clock(s, Time.now.to_f)
        len = play_len(s)
        c %= len if cf('play_repeat') && len > 0 && !s[:loops]
        t = warp(s, c)
      end
      { 'state' => s[:state] == :playing ? 'play' : 'pause', 't' => t, 'total' => s[:total], 'loops' => s[:loops] }
    end

    def self.scene_total
      m = Sketchup.active_model
      m ? timeline_length(animated_instances(m)) : 0.0
    end

    def self.panel_transport
      js("setTransport(#{js_json(transport_state)})")
    end

    # ── Oggetto selezionato ─────────────────────────────────────────
    def self.ent_name(e)
      n = e.respond_to?(:name) ? e.name.to_s : ''
      return n unless n.empty?
      return t('obj.section') if section?(e)
      e.is_a?(Sketchup::Group) ? t('obj.group') : e.definition.name
    end

    def self.selection_info(list = nil)
      model = Sketchup.active_model
      return { 'kind' => 'none' } unless model
      sel = model.selection.to_a
      return { 'kind' => 'none' } if sel.empty?
      anim = sel.select { |e| animatable?(e) }
      return { 'kind' => 'raw', 'n' => sel.size } if anim.empty?
      # Più oggetti: si modifica il primo, e (se si vuole) le modifiche
      # valgono per tutti (save_tracks, others)
      obj_info(anim.first, list).merge('multi' => anim.size - 1)
    end

    def self.obj_info(e, list = nil)
      data = read_data(e) || empty_data
      rest = rest_for(e, data, item_base(e))
      model = e.model
      type = section?(e) ? 'section' : (e.is_a?(Sketchup::Group) ? 'group' : 'component')
      shared = type == 'component' && e.definition.instances.size > 1
      { 'kind' => 'obj', 'pid' => e.persistent_id, 'name' => ent_name(e), 'type' => type,
        'shared' => shared, 'rest' => rest[:values], 'data' => data,
        'live' => !!(@session && @session[:items][e]),
        'tags' => model.layers.map { |l| l.name.to_s },
        'others' => (list || animated_instances(model)).reject { |x, _| x == e }
                                             .map { |x, _| { 'pid' => x.persistent_id, 'name' => ent_name(x) } },
        'overlay' => overlay_ok? }
    end

    # Gli oggetti animati, la durata della timeline e la velocità del tempo
    # (nil: tempo normale)
    def self.scene_info(list = nil)
      model = Sketchup.active_model
      return { 'objects' => [], 'total' => 0.0, 'time' => nil } unless model
      list ||= animated_instances(model)
      starts = chain_starts(list)
      { 'objects' => list.map do |e, data|
          on = data['tracks'].select { |t| t['on'] }
          { 'pid' => e.persistent_id, 'name' => ent_name(e), 'n' => on.size,
            'props' => on.map { |t| t['prop'] }.uniq,
            'len' => data_length(data), 'loops' => data_loops?(data),
            'mode' => data['start']['mode'], 'at' => starts[e.persistent_id] }
        end,
        'total' => timeline_length(list, starts), 'time' => read_time(model) }
    end

    def self.panel_selection
      return unless panel_open?
      m = Sketchup.active_model
      js("setUnit(#{js_json(m ? unit_info(m) : UNITS[4])})")
      list = m ? animated_instances(m) : []      # una volta sola per selezione e scena
      js("setSelection(#{js_json(selection_info(list))})")
      js("setScene(#{js_json(scene_info(list))})")
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # Molti eventi di fila (selezione con riquadro, fotogrammi): un invio solo.
    # Senza «segui la selezione» l'oggetto mostrato resta quello, ma la scena
    # (oggetti animati, velocità del tempo) si aggiorna lo stesso: dopo un
    # Ctrl+Z il tasto ⏱ restava com'era prima.
    def self.panel_selection_soon
      return unless panel_open?
      return if @sel_timer
      @sel_timer = UI.start_timer(0.08, false) do
        @sel_timer = nil
        if cf('follow_selection')
          panel_selection
        else
          js("setScene(#{js_json(scene_info)})")
        end
      end
    end

    def self.find_pid(pid)
      model = Sketchup.active_model or return nil
      pid = pid.to_i
      e = model.find_entity_by_persistent_id(pid) if model.respond_to?(:find_entity_by_persistent_id)
      unless e
        model.definitions.each do |d|
          e = d.instances.find { |i| i.persistent_id == pid }
          break if e
        end
      end
      e && animatable?(e) && e.valid? ? e : nil
    end

    # Dati di un oggetto dal pannello: una voce di annullamento per ogni
    # modifica (il pannello raggruppa le battute ravvicinate).
    def self.save_tracks(json)
      d = JSON.parse(json.to_s)
      e = find_pid(d['pid']) or return
      model = e.model
      data = sanitize_data(d['data'])
      # «Vale per tutti i selezionati»: gli altri ricevono le stesse tracce,
      # con posizioni e dimensioni riportate al loro riposo
      others = d['others'] ? model.selection.select { |x| animatable?(x) && x != e && x.valid? } : []
      written = []
      @own_op = true
      model.start_operation(t('op.edit'), true)
      begin
        src_rest = rest_for(e, data, item_base(e))
        written << [e, write_data(e, data)]
        others.each do |x|
          dst = map_data(data, src_rest, rest_for(x, data, item_base(x)), section?(x))
          written << [x, write_data(x, dst)]
        end
        model.commit_operation
      rescue => dyn_err
        model.abort_operation
        raise dyn_err
      ensure
        @own_op = false
      end
      op_break                       # voce dell'utente: la sessione non vi si accoda
      if @session
        written.each { |x, xd| session_update(x, xd, true) }
        session_updated
      end
      paths_dirty
      cmd_preview(e, d['preview'].to_f) if d['preview'].is_a?(Numeric) && cf('edit_preview')
      js("setScene(#{js_json(scene_info)})")
      panel_transport
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    def self.item_base(e)
      it = @session && @session[:items][e]
      it ? it[:base] : base_of(e)
    end

    # Velocità del tempo dal pannello: una voce di annullamento, come le tracce
    def self.save_time(json)
      d = JSON.parse(json.to_s)
      model = Sketchup.active_model or return
      @own_op = true
      model.start_operation(t('tw.title'), true)
      begin
        write_time(model, d)
        model.commit_operation
      rescue => dyn_err
        model.abort_operation
        raise dyn_err
      ensure
        @own_op = false
      end
      op_break                       # voce dell'utente: la sessione non vi si accoda
      session_updated if @session && @session[:model] == model
      js("setScene(#{js_json(scene_info)})")
      panel_transport
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # Tracce di un oggetto portate su un altro: le posizioni assolute si
    # spostano della differenza fra i due riposi, le dimensioni in
    # proporzione; il resto (rotazioni, spostamenti, scala, colori) uguale.
    def self.map_data(data, src, dst, to_section)
      out = JSON.parse(JSON.generate(data))
      out['tracks'].select! { |tr| SECTION_PROPS.include?(tr['prop']) } if to_section
      out['tracks'].each do |tr|
        p = tr['prop']
        a = src[:values][p]
        b = dst[:values][p]
        next unless a.is_a?(Numeric) && b.is_a?(Numeric)
        tr['keys'].each do |k|
          if p.start_with?('pos_')
            k['v'] = k['v'] + (b - a)
          elsif p.start_with?('size_') && a.abs > 1e-9
            k['v'] = k['v'] * b / a
          end
        end
      end
      out
    end

    # Anteprima chiesta dal pannello (senza salvare): l'oggetto al tempo locale t
    def self.preview_obj(json)
      d = JSON.parse(json.to_s)
      e = find_pid(d['pid']) or return
      cmd_preview(e, d['t'].to_f) if cf('edit_preview')
    end

    # La selezione non è un gruppo: ne fa uno, che diventa animabile.
    def self.make_group
      model = Sketchup.active_model or return
      sel = model.selection.to_a
      return if sel.empty?
      model.start_operation(t('op.group'), true)
      g = model.active_entities.add_group(sel)
      model.commit_operation
      model.selection.clear
      model.selection.add(g)
    rescue => dyn_err
      model.abort_operation rescue nil
      log_error(__method__, dyn_err)
      UI.messagebox("DagaDyn — #{dyn_err.message}")
    end

    def self.select_pid(pid)
      e = find_pid(pid) or return
      sel = e.model.selection
      sel.clear
      sel.add(e)
      panel_selection
    end

    # ── Esporta / importa ──────────────────────────────────────────
    # Il file contiene solo il comportamento: lingua e livello del pannello
    # restano quelli di chi importa.
    PANEL_ONLY = %w[language panel_level].freeze

    def self.export_settings
      path = UI.savepanel(t('bk.export'), '', 'DagaDyn.json')
      return unless path
      path += '.json' unless path =~ /\.json\z/i
      data = @cfg.reject { |k, _| PANEL_ONLY.include?(k) }
      File.write(path, JSON.pretty_generate('dagadyn_settings' => 1, 'settings' => data))
      js("flashStatus(#{js_json(t('bk.exported'))})")
    rescue => dyn_err
      log_error(__method__, dyn_err)
      UI.messagebox("DagaDyn — #{dyn_err.message}")
    end

    # Accetta solo chiavi note, del tipo giusto; gli intervalli li
    # ricontrolla il pannello, che dopo l'importazione risalva i valori
    # passati dal suo clamp.
    def self.import_values(src)
      src = src['settings'] if src.is_a?(Hash) && src['settings'].is_a?(Hash)
      return 0 unless src.is_a?(Hash)
      n = 0
      src.each do |k, v|
        next if PANEL_ONLY.include?(k) || !DEFAULT.key?(k)
        d = DEFAULT[k]
        ok = case d
             when true, false then v == true || v == false
             when Numeric     then v.is_a?(Numeric) && v.to_f.finite?
             when String      then v.is_a?(String)
             else false
             end
        next unless ok
        @cfg[k] = v
        n += 1
      end
      n
    end

    def self.import_settings
      path = UI.openpanel(t('bk.import'), '', 'JSON|*.json||')
      return unless path
      data = begin
        JSON.parse(File.read(path, encoding: 'UTF-8'))
      rescue JSON::ParserError, EncodingError
        nil
      end
      speed = cf('play_speed')
      if import_values(data).zero?
        UI.messagebox(t('bk.bad'))
        return
      end
      sanitize_cfg
      speed_kept(speed)
      warp_setup(@session) if @session        # «Ripeti» decide se la velocità del tempo si ripete
      save_cfg
      push_panel_state
      js("saveNow(); flashStatus(#{js_json(t('bk.imported'))})")
    rescue => dyn_err
      log_error(__method__, dyn_err)
      UI.messagebox("DagaDyn — #{dyn_err.message}")
    end

    # ── Finestra ───────────────────────────────────────────────────
    def self.show_panel
      load_cfg
      load_lang
      if panel_open?
        dialog_on_screen(@dialog)    # "aperto" ma fuori dallo schermo: il menu non farebbe nulla
        @dialog.bring_to_front
        return
      end
      @dialog = UI::HtmlDialog.new(
        dialog_title:    "DagaDyn — #{t('menu.panel').sub(/…\z/, '')}",
        preferences_key: 'DagaDynPanel',
        width:  640, height:  720,
        min_width: 520, min_height: 520,
        resizable: true
      )
      @dialog.set_file(PANEL_FILE)
      cb = ->(name, &blk) do
        @dialog.add_action_callback(name) do |_ctx, arg|
          begin
            blk.call(arg)
          rescue => dyn_err
            log_error("cb_#{name}", dyn_err)
          end
        end
      end
      cb.call('request_settings') { |_| push_panel_state }
      cb.call('save_settings') do |json|
        shared = ui_shared? ? SHARED_UI : []
        speed = cf('play_speed')
        @cfg.merge!(JSON.parse(json).select { |k, _| DEFAULT.key?(k) && !shared.include?(k) })
        sanitize_cfg
        speed_kept(speed)
        warp_setup(@session) if @session      # «Ripeti» decide se la velocità del tempo si ripete
        save_cfg
        overlay_refresh
      end
      cb.call('set_language') do |code|
        next push_panel_state if ui_shared?   # la lingua la decide DagaWASD
        code = code.to_s
        @cfg['language'] = (code == 'auto' || lang_codes.include?(code)) ? code : 'auto'
        save_cfg
        push_panel_state            # ricarica la lingua (load_lang); menu e barra al prossimo avvio
      end
      cb.call('export_settings') { |_| export_settings }
      cb.call('import_settings') { |_| import_settings }
      cb.call('read_log')  { |_| js("showLog(#{js_json(read_log)})") }
      cb.call('clear_log') { |_| clear_log; js("showLog(#{js_json(read_log)})") }
      # «Incolla» del menu del destro: la pagina non può leggere gli appunti
      cb.call('panel_paste') { |_| js("incolla(#{js_json(clipboard_text)})") }
      # Timeline
      cb.call('play')   { |_| cmd_play }
      cb.call('pause')  { |_| cmd_pause }
      cb.call('toggle') { |_| cmd_toggle }
      cb.call('stop')   { |_| cmd_stop }
      cb.call('bake')   { |_| cmd_bake }
      cb.call('seek')   { |v| cmd_seek(v.to_f) }
      cb.call('save_time') { |json| save_time(json) }
      # Oggetti
      cb.call('request_selection') { |_| panel_selection }
      cb.call('save_tracks') { |json| save_tracks(json) }
      cb.call('make_group')  { |_| make_group }
      cb.call('select_obj')  { |pid| select_pid(pid) }
      cb.call('preview')     { |json| preview_obj(json) }
      cb.call('use_tool')    { |_| start_use_tool }

      @dialog.set_on_closed { @dialog = nil; ui_watch_stop } if @dialog.respond_to?(:set_on_closed)
      @dialog.show
      dialog_on_screen(@dialog)
      ui_watch_start
    end

    # Lingua o aspetto cambiati nel pannello di DagaWASD mentre il nostro è
    # aperto: un'occhiata al secondo (legge solo valori già in memoria).
    def self.ui_watch_start
      return if @ui_watch
      @ui_watch = UI.start_timer(1.0, true) { ui_watch }
    end

    def self.ui_watch_stop
      UI.stop_timer(@ui_watch) if @ui_watch
      @ui_watch = nil
    end

    def self.ui_watch
      return ui_watch_stop unless panel_open?
      now = wasd_ui
      return if now == @ui_sig
      lang = (now || {})['language'] != (@ui_sig || {})['language'] || now.nil? != @ui_sig.nil?
      @ui_sig = now
      if lang
        push_panel_state                                   # ricostruisce il pannello nella nuova lingua
      else
        js("loadSettings(#{js_json(panel_cfg)})")          # solo l'aspetto
      end
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

  end
end
