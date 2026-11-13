# DagaDyn — settings.json e registro errori.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
# Stesso comportamento di DagaWASD (lib/settings.rb).
require 'fileutils'

module DagaDyn
  module Dyn

    # ══════════════════════════════════════════════════════════════
    # Impostazioni
    # ══════════════════════════════════════════════════════════════
    # I test possono usare un altro file (@settings_file) invece di quello vero.
    def self.settings_path; @settings_file || SETTINGS_FILE; end

    # Un settings.json illeggibile non deve impedire l'avvio (senza, il menu
    # e la barra degli strumenti non comparirebbero): si parte dai default e
    # il file rovinato viene messo da parte come settings.bad.json.
    def self.load_cfg
      data = {}
      if File.exist?(settings_path)
        begin
          data = JSON.parse(File.read(settings_path, encoding: 'UTF-8'))
          raise JSON::ParserError, "settings.json: #{data.class} invece di un oggetto" unless data.is_a?(Hash)
        rescue => dyn_err
          log_error(__method__, dyn_err)
          data = {}
          begin; File.rename(settings_path, settings_path.sub(/\.json\z/, '.bad.json')); rescue SystemCallError; end
        end
      end
      @cfg = DEFAULT.merge(data.select { |k, _| DEFAULT.key?(k) })
      sanitize_cfg
      @cfg
    end

    def self.cf(k)
      load_cfg unless @cfg
      @cfg[k]
    end

    # Tipo sbagliato → predefinito; colori non validi o scelte sconosciute
    # tornano al predefinito (il pannello li trasforma in CSS). Gli
    # intervalli numerici li controlla il pannello; qui solo quelli che il
    # motore usa direttamente.
    def self.sanitize_cfg
      DEFAULT.each do |k, d|
        v = @cfg[k]
        case d
        when true, false
          @cfg[k] = d unless v == true || v == false
        when Numeric
          @cfg[k] = d unless v.is_a?(Numeric) && v.to_f.finite?
        when String
          choices = LOOK_CHOICES[k]
          if choices
            @cfg[k] = d unless choices.include?(v)
          elsif d.start_with?('#')
            @cfg[k] = v.is_a?(String) && v.match?(/\A#\h{6}\z/) ? v.downcase : d
          else
            @cfg[k] = d unless v.is_a?(String)
          end
        end
      end
      @cfg['play_speed'] = @cfg['play_speed'].to_f.clamp(0.05, 10.0)
      @cfg['panel_fps']  = @cfg['panel_fps'].to_i.clamp(1, 60)
    end

    # ── Lingua e aspetto di DagaWASD ────────────────────────────────
    # Con DagaWASD caricata, lingua e aspetto del pannello sono i suoi (stesse
    # chiavi, stessi valori): il pannello di DagaDyn non li mostra e non li
    # salva, e quelli propri restano in settings.json per quando DagaDyn è da
    # sola. Il logo no: ognuna ha i suoi (LOOK_CHOICES diversi).
    SHARED_UI = (['language'] + DEFAULT.keys.grep(/\Aui_/) - ['ui_logo']).freeze

    # Valori condivisi validi (quelli che non lo sono restano i nostri), o
    # nil se DagaWASD non c'è. boot: all'avvio DagaWASD si carica dopo di noi
    # (ordine alfabetico), quindi per menu e barra si legge il suo file, se il
    # suo caricatore è nella cartella Plugins.
    def self.wasd_ui(boot = false)
      src =
        if defined?(::DagaWASD::FPSWalk) && ::DagaWASD::FPSWalk.respond_to?(:cf)
          w = ::DagaWASD::FPSWalk
          SHARED_UI.to_h { |k| [k, w.cf(k)] }
        elsif boot
          plugins = Sketchup.find_support_file('Plugins').to_s
          file = File.join(ENV['APPDATA'] || Dir.home, 'DagaWASD', 'settings.json')
          return nil unless File.exist?(File.join(plugins, 'dagawasd.rb')) && File.exist?(file)
          JSON.parse(File.read(file, encoding: 'UTF-8'))
        end
      return nil unless src.is_a?(Hash)
      src.select { |k, v| SHARED_UI.include?(k) && ui_value_ok?(k, v) }
    rescue
      nil
    end

    def self.ui_value_ok?(k, v)
      d = DEFAULT[k]
      case d
      when true, false then v == true || v == false
      when Numeric     then v.is_a?(Numeric) && v.to_f.finite?
      when String
        if LOOK_CHOICES[k]        then LOOK_CHOICES[k].include?(v)
        elsif d.start_with?('#')  then v.is_a?(String) && v.match?(/\A#\h{6}\z/)
        else v.is_a?(String)
        end
      else false
      end
    end

    def self.ui_shared?; !wasd_ui.nil?; end

    # Le impostazioni come le vede il pannello: le nostre, con lingua e
    # aspetto di DagaWASD quando c'è.
    def self.panel_cfg(boot = false)
      load_cfg unless @cfg
      w = wasd_ui(boot)
      w ? @cfg.merge(w) : @cfg
    end

    # Prima su un file temporaneo, poi lo scambio: se SketchUp si chiude a
    # metà scrittura, settings.json resta quello di prima invece che troncato.
    def self.save_cfg
      load_cfg unless @cfg
      tmp = "#{settings_path}.tmp"
      FileUtils.mkdir_p(File.dirname(settings_path))
      File.write(tmp, JSON.pretty_generate(@cfg), encoding: 'UTF-8')
      File.rename(tmp, settings_path)
    rescue => e
      log_error(__method__, e)
      Sketchup.status_text = "DagaDyn: save error — #{e.message}"
    end

    # ── Registro errori ─────────────────────────────────────────────
    # Gli errori interni non devono interrompere l'animazione, ma nemmeno
    # sparire: ognuno viene scritto una volta per sessione in dagadyn.log
    # (con le prime righe dello stack) e segnalato nella barra di stato.
    # Il registro non supera LOG_MAX: oltre riparte da zero. Questo metodo
    # non deve mai sollevare a sua volta.
    def self.log_error(where, err)
      @logged ||= {}
      sig = "#{where}|#{err.class}|#{err.message}"
      return if @logged[sig]
      @logged[sig] = true
      trace = (err.backtrace || []).first(4).map { |l| "    #{l}" }.join("\n")
      line  = "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')} [#{where}] #{err.class}: #{err.message}\n#{trace}\n"
      path  = log_path
      mode  = File.exist?(path) && File.size(path) > LOG_MAX ? 'w' : 'a'
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, mode) { |f| f.write(line) }
      puts "DagaDyn [#{where}] #{err.class}: #{err.message}" unless @log_quiet
      Sketchup.status_text = "DagaDyn — #{t('rt.err_logged')}"
      # pannello aperto: aggiorna subito il contatore ⚠ nella barra in alto
      @dialog.execute_script("setLogCount(#{log_count})") if @dialog && @dialog.visible?
    rescue Exception
      nil
    end

    def self.log_path; @log_file || LOG_FILE; end

    # Contenuto del registro per il pannello (UTF-8 valido anche se il file
    # contiene byte strani: un messaggio di errore può riportare di tutto).
    def self.read_log
      path = log_path
      txt  = File.exist?(path) ? File.binread(path).force_encoding('UTF-8').scrub('?') : ''
      { 'path' => path, 'text' => txt }
    rescue => dyn_err
      { 'path' => log_path, 'text' => "#{dyn_err.class}: #{dyn_err.message}" }
    end

    # Voci del registro: ogni voce comincia con data e ora.
    def self.log_count
      read_log['text'].scan(/^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d \[/).size
    end

    # Svuota il registro; gli errori già visti potranno essere riscritti.
    def self.clear_log
      File.delete(log_path) if File.exist?(log_path)
      @logged = {}
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

  end
end
