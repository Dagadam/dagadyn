require 'sketchup'
require 'json'

# ══════════════════════════════════════════════════════════════════
# DagaDyn — caricatore
# Il codice sta in lib/, un file per argomento; tutti riaprono lo stesso
# modulo DagaDyn::Dyn. L'ordine conta solo per config (costanti usate al
# caricamento dagli altri file); i metodi si risolvono quando vengono
# chiamati, quindi un file può usare metodi definiti in uno successivo.
#
#   config     costanti, DEFAULT, proprietà   i18n       lingue
#   settings   settings.json, registro        win32      appunti, monitor
#   curves     curve di transizione, preset   formula    transizioni a formula
#   color      colori, OKLab
#   tracks     tracce negli attributi         props      valori di riposo, applicazione
#   player     motore: sessione, tempo        observers  selezione, salvataggio
#   api        collegamento con DagaWASD      paths      traiettorie, strumento Aziona
#   panel      pannello (HtmlDialog)          ui         menu e barra
#
# Il motore non dipende da chi batte il tempo: da solo lo guida
# view.animation (Dyn.advance, lib/player.rb); con DagaWASD lo guida il suo
# ciclo (DagaDyn.ext_tick, lib/api.rb): camminata, esploratore, percorsi e video.
# ══════════════════════════════════════════════════════════════════

# Già caricato (es. `load` ripetuto dalla console): non registrare di
# nuovo menu, barra e osservatori.
unless defined?(DagaDyn::Dyn::PLUGIN_DIR)
  %w[
    config i18n settings win32 curves formula color tracks props player api paths observers panel ui
  ].each do |f|
    path = File.join(__dir__.dup.force_encoding('UTF-8'), 'lib', f)   # percorsi con lettere accentate
    # Sketchup.require e non require: con la firma i file possono diventare .rbe cifrati
    Sketchup.require(path)
  end

  begin
    DagaDyn::Dyn.register_ui
    DagaDyn::Dyn.observe_app
  rescue => e
    DagaDyn::Dyn.log_error(:register_ui, e)
    Sketchup.status_text = "DagaDyn — register_ui error: #{e.message}"
  end
end
