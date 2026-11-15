# DagaDyn — Collegamento con altre estensioni (DagaWASD): chi batte il tempo, piattaforme, azionare.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
#
# DagaWASD chiama solo i metodi di DagaDyn (modulo, qui in fondo), e solo
# se DagaDyn c'è: nessuna delle due estensioni ha bisogno dell'altra.
#
#   DagaDyn.ext_begin(:walk)          parte la camminata (o :explore, :path, :video)
#   DagaDyn.ext_tick(secondi)         a ogni passo: secondi dall'inizio, nel suo orologio
#                                     (il video passa il tempo del video, k / fps)
#   DagaDyn.ext_end(:walk)            fine: tutto torna a riposo
#   DagaDyn.carry(percorso)           trasformazione mondo con cui si è mossa in questo
#                                     passo la cosa sotto i piedi (percorso di raytest), o nil
#   DagaDyn.kinematic?(percorso)      è animato: la fisica non lo spinge e non lo prende
#   DagaDyn.use(percorso)             azionare (tasto Aziona): nome dell'oggetto, o nil
module DagaDyn
  module Dyn

    def self.ext_begin(owner)
      return false unless cf('with_dagawasd')
      model = Sketchup.active_model or return false
      s = @session
      return true if s && s[:ext] == owner   # già suo (es. l'esploratore che riprende)
      if s && s[:ext] && s[:ext] != owner
        s[:ext] = owner                    # passa la mano (es. dalla camminata al video)
      else
        s = session_start(model) or return false
        if s[:items].empty?
          session_end
          return false
        end
      end
      driver_stop
      clear_pins(s)
      shadows_back(s)                      # le ombre le decide chi registra o cammina
      s[:ext]    = owner
      s[:state]  = :playing
      s[:hold]   = true
      s[:ext_t0] = s[:t]
      s[:ext_el] = 0.0
      panel_transport
      true
    rescue => dyn_err
      log_error(__method__, dyn_err)
      false
    end

    def self.ext_tick(elapsed)
      s = @session
      return false unless s && s[:ext] && s[:model].valid?
      s[:ext_el] = elapsed.to_f              # per speed_kept (lib/player.rb)
      t = s[:ext_t0] + s[:ext_el] * cf('play_speed')
      if !s[:loops] && cf('play_repeat') && s[:total] > 0 && t >= s[:total] && !busy_at?(s, t)
        n = (t / s[:total]).floor
        shift_time(s, n * s[:total])
        t -= n * s[:total]
      end
      apply(t)
      panel_tick(s, Time.now.to_f)
      true
    rescue => dyn_err
      log_error(__method__, dyn_err)
      false
    end

    def self.ext_end(owner)
      s = @session
      return unless s && s[:ext] == owner
      s[:ext] = nil
      s[:hold] = false
      session_end(false)
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    # Le istanze del percorso (dal più esterno), senza la faccia o lo spigolo finale
    def self.path_insts(path)
      (path || []).select { |x| x.respond_to?(:transformation) && !section?(x) }
    end

    # Spostamento nel mondo, in quest'ultimo passo, di ciò che sta in fondo al
    # percorso: W_nuova · W_vecchia⁻¹, dove W è il prodotto delle
    # trasformazioni del percorso e per gli oggetti mossi in questo passo
    # la vecchia è quella del passo prima. nil se niente si è mosso.
    def self.carry(path)
      s = @session or return nil
      insts = path_insts(path)
      moved = false
      w_new = Geom::Transformation.new
      w_old = Geom::Transformation.new
      insts.each do |e|
        return nil unless e.valid?
        cur = e.transformation
        it = s[:items][e]
        old = cur
        if it && it[:moved] == s[:tick] && it[:prev_tr]
          old = it[:prev_tr]
          moved = true
        end
        w_new *= cur
        w_old *= old
      end
      moved ? w_new * w_old.inverse : nil
    rescue => dyn_err
      log_error(__method__, dyn_err)
      nil
    end

    def self.kinematic?(path)
      s = @session or return false
      path_insts(path).any? { |e| s[:items].key?(e) }
    rescue
      false
    end

    # Gli oggetti del percorso che si azionano, dal più interno; nessun effetto
    # (lo strumento Aziona li usa anche solo per evidenziare sotto il mouse).
    def self.use_targets(path)
      cand = path_insts(path).reverse
      cand += (path || []).select { |x| section?(x) }
      cand.select do |e|
        data = read_data(e)
        data && data['start']['mode'] == 'trigger' && data['tracks'].any? { |t| t['on'] }
      end
    end

    # Il più interno del percorso che si aziona; parte la sessione se serve.
    def self.use_path(path, hold = true)
      model = Sketchup.active_model or return nil
      use_targets(path).each do |e|
        s = @session
        unless s && s[:model] == model
          return nil if foreign_busy?
          s = session_start(model) or return nil
        end
        it = s[:items][e] or next
        unless s[:state] == :playing
          return nil if foreign_busy? && !s[:ext]
          s[:hold] = true if hold
          cmd_play
          s = @session or return nil
        end
        t = s[:ext] ? s[:t] : clock(s, Time.now.to_f)
        trigger_item(s, it, t)
        panel_transport
        return ent_name(e)
      end
      nil
    rescue => dyn_err
      log_error(__method__, dyn_err)
      nil
    end

  end

  # ── Metodi pubblici per le altre estensioni ────────────────────────
  def self.ext_begin(owner);   Dyn.ext_begin(owner); end
  def self.ext_tick(elapsed);  Dyn.ext_tick(elapsed); end
  def self.ext_end(owner);     Dyn.ext_end(owner); end
  def self.carry(path);        Dyn.carry(path); end
  def self.kinematic?(path);   Dyn.kinematic?(path); end
  def self.use(path);          Dyn.cf('with_dagawasd') ? Dyn.use_path(path, false) : nil; end
  def self.own_op?;            !!Dyn.own_op?; end
  def self.api_version;        1; end
end
