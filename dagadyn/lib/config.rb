# DagaDyn — Costanti, impostazioni predefinite, proprietà animabili, stato.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    PLUGIN_DIR    = File.expand_path('..', __dir__.dup.force_encoding('UTF-8')).freeze
    USER_DIR      = File.join(ENV['APPDATA'] || Dir.home, 'DagaDyn').freeze
    SETTINGS_FILE = File.join(USER_DIR, 'settings.json').freeze
    PANEL_FILE    = File.join(PLUGIN_DIR, 'panel.html').freeze
    LANG_DIR      = File.join(PLUGIN_DIR, 'lang').freeze
    LOG_FILE      = File.join(USER_DIR, 'dagadyn.log').freeze   # mai scrivere nella cartella dell'estensione
    LOG_MAX       = 256 * 1024

    # Dizionario degli attributi sugli oggetti animati. 'data' è un JSON:
    # {"v":1, "pivot":"base", "tracks":[…]} (formato in lib/tracks.rb).
    DICT      = 'DagaDyn'.freeze
    DATA_KEY  = 'data'.freeze
    DATA_VER  = 1
    # Nome dei materiali temporanei creati per animare colore e opacità
    TEMP_MAT  = 'DagaDyn·'.freeze

    # ══════════════════════════════════════════════════════════════
    # Proprietà animabili
    # kind: length (pollici, unità interna di SketchUp; il pannello mostra
    # l'unità del modello), angle (gradi), factor (×), ratio (0–1), color
    # ('#rrggbb'). rel: il valore di riposo è fisso (rotazione 0, scala 1):
    # la proprietà è relativa allo stato del modello. min: limite inferiore
    # applicato anche ai valori che una curva porta oltre (dimensioni mai
    # nulle: una trasformazione con scala 0 non è invertibile).
    # ══════════════════════════════════════════════════════════════
    PROPS = {
      'pos_x'   => { kind: :length },
      'pos_y'   => { kind: :length },
      'pos_z'   => { kind: :length },
      'move_x'  => { kind: :length, rel: 0.0 },   # spostamento rispetto al riposo
      'move_y'  => { kind: :length, rel: 0.0 },
      'move_z'  => { kind: :length, rel: 0.0 },
      'rot_x'   => { kind: :angle,  rel: 0.0 },
      'rot_y'   => { kind: :angle,  rel: 0.0 },
      'rot_z'   => { kind: :angle,  rel: 0.0 },
      'size_x'  => { kind: :length, min: 0.001 },
      'size_y'  => { kind: :length, min: 0.001 },
      'size_z'  => { kind: :length, min: 0.001 },
      'scale'   => { kind: :factor, rel: 1.0, min: 0.001 },
      'color'   => { kind: :color },
      'opacity' => { kind: :ratio, min: 0.0, max: 1.0 },
      'visible' => { kind: :bool, min: 0.0, max: 1.0 },  # 1 visibile, 0 nascosto
      'tag'     => { kind: :tag },                        # nome del tag (layer)
    }.freeze
    # Proprietà a scatti: non c'è un valore intermedio, si passa allo stato
    # successivo quando la sua transizione finisce.
    DISCRETE = %i[bool tag].freeze
    # Proprietà che cambiano il modello (non con move!): vanno in un'operazione
    MODEL_PROPS = %w[color opacity visible tag].freeze
    # Un piano di sezione si sposta e si accende/spegne
    SECTION_PROPS = %w[move_x move_y move_z visible].freeze
    TRANSFORM_PROPS = %w[pos_x pos_y pos_z move_x move_y move_z rot_x rot_y rot_z size_x size_y size_z scale].freeze
    MATERIAL_PROPS  = %w[color opacity].freeze

    # Assi delle rotazioni: quelli dell'oggetto o quelli del contenitore (mondo)
    AXES = %w[object world].freeze

    # Quando parte l'animazione di un oggetto: con la timeline, dopo che è
    # finita quella di un altro oggetto (più un'attesa), o quando lo si
    # aziona (clic con lo strumento Interagisci, tasto Aziona di DagaWASD).
    # Azionato: riparte da capo, oppure va avanti e alla volta dopo torna
    # indietro (porte, cassetti).
    START_MODES   = %w[time after trigger].freeze
    TRIGGER_ACTS  = %w[play toggle].freeze

    # Punto di riferimento dell'oggetto: centro della base, centro, angolo
    # minimo del riquadro, origine del componente. Le dimensioni crescono
    # attorno a questo punto, le rotazioni girano attorno a lui e la
    # posizione è la sua.
    PIVOTS = %w[base center min origin].freeze

    # Ripetizione di una traccia
    LOOPS = %w[none loop pingpong].freeze

    # Unità di lunghezza del modello (UnitsOptions › LengthUnit) → pollici per unità
    UNITS = [
      ['in', 1.0], ['ft', 12.0], ['mm', 1.0 / 25.4], ['cm', 1.0 / 2.54], ['m', 1.0 / 0.0254], ['yd', 36.0]
    ].freeze

    # ══════════════════════════════════════════════════════════════
    # Impostazioni (settings.json in %APPDATA%\DagaDyn)
    # ══════════════════════════════════════════════════════════════
    DEFAULT = {
      'language'            => 'auto',
      'panel_level'         => 1,

      # ── Riproduzione ──
      'play_speed'          => 1.0,    # × tempo reale
      'play_repeat'         => false,  # la timeline riparte da capo al termine
      'stop_restore'        => true,   # allo stop gli oggetti tornano allo stato di progetto
      'panel_fps'           => 12,     # aggiornamenti al secondo della timeline nel pannello
      'play_no_shadows'     => false,  # ombre spente durante il Play (modelli pesanti)
      'with_dagawasd'       => true,   # animazioni anche camminando, esplorando e nei video di DagaWASD

      # ── Modifica ──
      'edit_preview'        => true,   # scrivendo il valore di uno stato l'oggetto lo mostra
      'show_paths'          => true,   # traiettorie nella vista
      'paths_all'           => false,  # traiettorie di tutti gli oggetti animati, non solo dei selezionati

      # ── Nuove tracce ──
      'new_duration'        => 1.0,    # s
      'new_curve'           => 'ease_in_out',
      'new_pivot'           => 'base',
      'follow_selection'    => true,   # il pannello mostra l'oggetto selezionato

      # ── Editor delle curve ──
      'curve_snap'          => true,
      'curve_grid'          => 10,     # divisioni della griglia
      'color_mix'           => 'oklab',

      # ── Aspetto del pannello ──
      # Colori '#rrggbb'; le scelte possibili sono in LOOK_CHOICES.
      'ui_theme'            => 'dark',
      'ui_accent'           => '#00c9a7',
      'ui_highlight'        => '#ffd166',
      'ui_danger'           => '#c04747',
      'ui_custom_colors'    => false,  # sfondo e testo propri al posto di quelli del tema
      'ui_bg'               => '#151515',
      'ui_text'             => '#dcdcdc',
      'ui_font'             => 'segoe',
      'ui_font_size'        => 15.0,   # px
      'ui_line_height'      => 1.55,
      'ui_radius'           => 6,      # px
      'ui_spacing'          => 1.0,    # × spaziature di righe e gruppi
      'ui_label_width'      => 230,    # px
      'ui_hints'            => true,   # descrizione breve sotto il nome
      'ui_animations'       => true,
      'ui_scrollbar'        => 9,      # px
      'ui_tab_icons'        => 'text',
      'ui_logo'             => 'wave',
    }.freeze

    CURVE_PRESETS = %w[linear ease_in ease_out ease_in_out back elastic bounce steps].freeze

    LOOK_CHOICES = {
      'ui_theme'        => %w[auto dark light midnight warm contrast],
      'ui_font'         => %w[segoe tahoma verdana trebuchet georgia calibri consolas comic system],
      'ui_tab_icons'    => %w[text both icons],
      'ui_logo'         => %w[wave film bolt cube spark none],
      'new_curve'       => CURVE_PRESETS,
      'new_pivot'       => PIVOTS,
      'color_mix'       => %w[oklab rgb],
    }.freeze

    # Chiave degli attributi del modello con i piani di sezione animati
    # (trovarli scorrendo tutte le entità costerebbe troppo nei modelli grandi)
    SECTIONS_KEY = 'sections'.freeze

    # ══════════════════════════════════════════════════════════════
    # Stato
    # ══════════════════════════════════════════════════════════════
    @cfg       = nil
    @lang      = nil
    @dialog    = nil
    @session   = nil     # sessione di riproduzione (lib/player.rb)
    @observed  = {}      # modello → osservatori agganciati (lib/observers.rb)

  end
end
