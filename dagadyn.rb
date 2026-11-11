require 'sketchup.rb'
require 'extensions.rb'

# ══════════════════════════════════════════════════════════════════
# DagaDyn — loader dell'estensione
# Va nella radice della cartella Plugins, accanto alla cartella
# "dagadyn" che contiene main.rb, panel.html, lib, lang e icons.
#
# VERSION è l'unico posto dove sta il numero di versione.
# ══════════════════════════════════════════════════════════════════
module DagaDyn
  module Loader

    VERSION = '0.2.0' unless defined?(VERSION)

    unless defined?(EXTENSION)

      # __FILE__ può arrivare con la codifica sbagliata se il percorso ha
      # lettere accentate (nome utente di Windows): si dichiara UTF-8.
      dir = File.dirname(__FILE__.dup.force_encoding('UTF-8'))
      EXTENSION = SketchupExtension.new('DagaDyn', File.join(dir, 'dagadyn', 'main'))
      EXTENSION.description =
        'Oggetti dinamici: per ogni proprietà di un gruppo, componente o ' \
        'piano di sezione (spostamento, posizione, rotazione, dimensioni, ' \
        'colore, opacità, visibilità, tag) uno stato iniziale, uno finale e ' \
        'una transizione con curva disegnabile. Partenza con la timeline, a ' \
        'catena o azionando l\'oggetto; con DagaWASD anche camminando e nei video.'
      EXTENSION.version   = VERSION
      EXTENSION.creator   = 'Dagadam'
      EXTENSION.copyright = '© 2026 Dagadam'

      Sketchup.register_extension(EXTENSION, true)

    end

  end
end
