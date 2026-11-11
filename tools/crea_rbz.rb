# DagaDyn — Crea il pacchetto .rbz da installare con Estensioni › Gestione
# estensioni › Installa estensione (lo stesso metodo di DagaWASD).
#
#   ruby tools/crea_rbz.rb [cartella]        → dist/dagadyn-<versione>.rbz
#
# Dentro: dagadyn.rb, e in dagadyn/: main.rb, panel.html, LICENSE, lib/,
# lang/, icons/. Niente test, strumenti o note di sviluppo.
#
# Prima di scrivere controlla: versione in dagadyn.rb e sua sezione in
# CHANGELOG.md, file elencati in main.rb tutti presenti (e nessuno in più),
# sintassi di ogni .rb, JSON validi. Al primo errore si ferma.
require 'json'
require 'zlib'
require 'fileutils'

module CreaRbz
  ROOT = File.expand_path('..', __dir__)
  module_function

  def errore(msg)
    warn "  [X] #{msg}"
    exit 1
  end

  def versione
    v = File.read(File.join(ROOT, 'dagadyn.rb'), encoding: 'UTF-8')[/^\s*VERSION = '(\d+\.\d+\.\d+)'/, 1]
    v or errore("dagadyn.rb: non trovo VERSION = 'x.y.z'")
  end

  def controlla_changelog(v)
    log = File.read(File.join(ROOT, 'CHANGELOG.md'), encoding: 'UTF-8')
    log.include?("## [#{v}]") or errore("CHANGELOG.md non ha la sezione «## [#{v}]»: scrivi cosa cambia in questa versione")
  end

  # [percorso nello zip, file sul disco]
  def contenuto
    ext = ->(rel) { ["dagadyn/#{rel}", File.join(ROOT, 'dagadyn', rel)] }
    lista = [['dagadyn.rb', File.join(ROOT, 'dagadyn.rb')], ext.('main.rb'), ext.('panel.html'), ext.('LICENSE')]
    %w[lib/*.rb lang/*.json icons/*.png].each do |g|
      Dir.glob(g, base: File.join(ROOT, 'dagadyn')).sort.each { |rel| lista << ext.(rel) }
    end
    lista
  end

  # main.rb carica lib/ da un elenco scritto a mano: un file elencato che
  # manca romperebbe l'avvio, uno non elencato non verrebbe mai caricato.
  def controlla_elenco
    main = File.read(File.join(ROOT, 'dagadyn', 'main.rb'), encoding: 'UTF-8')
    elencati = main[/%w\[(.*?)\]/m, 1].to_s.split
    presenti = Dir.glob('lib/*.rb', base: File.join(ROOT, 'dagadyn')).map { |f| File.basename(f, '.rb') }
    mancano = elencati - presenti
    errore("main.rb carica file che non ci sono: #{mancano.join(', ')}") unless mancano.empty?
    di_piu = presenti - elencati
    errore("lib/ ha file che main.rb non carica: #{di_piu.join(', ')}") unless di_piu.empty?
  end

  def controlla_file(lista)
    lista.each do |nome, file|
      testo = File.binread(file)
      case File.extname(file)
      when '.rb'
        begin
          RubyVM::InstructionSequence.compile(testo.dup.force_encoding('UTF-8'), nome)
        rescue SyntaxError => e
          errore("#{nome}: errore di sintassi\n#{e.message}")
        end
      when '.json'
        begin
          JSON.parse(testo.dup.force_encoding('UTF-8'))
        rescue JSON::ParserError => e
          errore("#{nome}: JSON non valido — #{e.message[0, 200]}")
        end
      end
    end
  end

  # ── Zip ─────────────────────────────────────────────────────────────
  # Una voce per cartella e una per file; nomi con /, deflate grezzo,
  # date dei file sul disco (ora locale, come vuole il formato).
  def dos_tempo(t)
    [(t.hour << 11) | (t.min << 5) | (t.sec / 2),
     ((t.year - 1980) << 9) | (t.month << 5) | t.day]
  end

  def scrivi_zip(dest, lista)
    voci = []
    cartelle = lista.flat_map { |nome, _| d = File.dirname(nome).split('/'); (1..d.size).map { |i| d[0, i].join('/') } }
                    .reject { |d| d == '.' }.uniq.sort
    cartelle.each { |d| voci << ["#{d}/", nil, Time.now] }
    lista.each { |nome, file| voci << [nome, File.binread(file), File.mtime(file)] }

    tmp = "#{dest}.tmp"
    centrale = ''.b
    File.open(tmp, 'wb') do |io|
      voci.each do |nome, dati, mtime|
        nome = nome.b
        tempo, data = dos_tempo(mtime)
        if dati
          crc = Zlib.crc32(dati)
          z = Zlib::Deflate.new(Zlib::BEST_COMPRESSION, -Zlib::MAX_WBITS)
          compressi = z.deflate(dati, Zlib::FINISH)
          z.close
          metodo, attr = 8, 0x20                     # deflate, file
        else
          dati = compressi = ''.b
          crc = 0
          metodo, attr = 0, 0x10                     # nessuna compressione, cartella
        end
        pos = io.pos
        comune = [20, 0x0800, metodo, tempo, data, crc, compressi.bytesize, dati.bytesize, nome.bytesize, 0]
        io.write([0x04034b50, *comune].pack('VvvvvvVVVvv'), nome, compressi)
        centrale << [0x02014b50, 20, *comune, 0, 0, 0, attr, pos].pack('VvvvvvvVVVvvvvvVV') << nome
      end
      inizio = io.pos
      io.write(centrale)
      io.write([0x06054b50, 0, 0, voci.size, voci.size, centrale.bytesize, inizio, 0].pack('VvvvvVVv'))
    end
    File.rename(tmp, dest)
    voci.size
  end

  def esegui(cartella = nil)
    v = versione
    controlla_changelog(v)
    controlla_elenco
    lista = contenuto
    controlla_file(lista)
    cartella ||= File.join(ROOT, 'dist')
    FileUtils.mkdir_p(cartella)
    nome = "dagadyn-#{v}.rbz"
    dest = File.join(cartella, nome)
    n = scrivi_zip(dest, lista)
    puts "  #{nome}: #{lista.size} file (#{n} voci), #{(File.size(dest) / 1024.0).round} KB"
    puts "  #{dest}"
    dest
  end
end

if $PROGRAM_NAME == __FILE__
  CreaRbz.esegui(ARGV[0])
end
