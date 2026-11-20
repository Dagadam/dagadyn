# DagaDyn — Rifà un esempio di examples/ nel SketchUp vero, attraverso il
# ponte di DagaWASD (Sistema › Ponte Claude acceso):
#
#   ruby tools/crea_esempio.rb              la cameretta: examples/bedroom.skp (tools/esempio_cameretta.rb)
#   ruby tools/crea_esempio.rb formulas     le formule:   examples/formulas.skp (tools/esempio_formule.rb)
#
# Parte solo con un modello NUOVO aperto (File › Nuovo, mai salvato, al più
# con la figura del modello di partenza). Ci costruisce l'esempio e lo salva
# in examples/ nel formato di SketchUp 2021: il modello aperto diventa quel
# file. Toglie dal modello
# ciò che non serve a nessuno (città e paese della posizione, dizionari di
# altre estensioni).
require 'json'
require 'net/http'

ROOT = File.expand_path('..', __dir__)
ESEMPI = {
  'bedroom'  => ['esempio_cameretta.rb', 'DagaDynEsempio'],
  'formulas' => ['esempio_formule.rb', 'DagaDynFormule'],
}.freeze
NOME = ARGV[0] || 'bedroom'
abort "esempi: #{ESEMPI.keys.join(', ')}" unless ESEMPI.key?(NOME)
COSTRUTTORE, MODULO = ESEMPI[NOME]
SKP  = File.join(ROOT, 'examples', "#{NOME}.skp").tr('\\', '/')
INFO_PATH = File.join(ENV['APPDATA'] || Dir.home, 'DagaWASD', 'bridge.json')
abort "#{INFO_PATH} non esiste: accendi il ponte in DagaWASD (Sistema › Ponte Claude)" unless File.exist?(INFO_PATH)
INFO = JSON.parse(File.read(INFO_PATH, encoding: 'UTF-8'))

def http(req)
  req['X-Token'] = INFO['token']
  res = Net::HTTP.start('127.0.0.1', INFO['port'], open_timeout: 3, read_timeout: 300) { |h| h.request(req) }
  JSON.parse(res.body.force_encoding('UTF-8'))
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Net::OpenTimeout
  abort "SketchUp non risponde sulla porta #{INFO['port']}: è aperto, col ponte acceso?"
end

def su(code)
  req = Net::HTTP::Post.new('/eval?op=DagaDyn%20esempio')
  req.body = "out = ->(x) { puts JSON.generate(x) }\n" + code
  r = http(req)
  raise "in SketchUp: #{r['error']}\n#{(r['backtrace'] || []).join("\n")}" unless r['ok']
  line = r['output'].to_s.lines.last
  line ? JSON.parse(line) : nil
end

ping = http(Net::HTTP::Get.new('/ping'))
abort 'DagaWASD è in modalità FPS: esci (ESC) e rilancia' if ping['fps_active']
pre = su(<<~RB)
  m = Sketchup.active_model
  d = defined?(DagaDyn::Dyn) ? DagaDyn::Dyn : nil
  out.({ 'dagadyn' => !d.nil?, 'nuovo' => m.path.empty? && m.entities.size <= 1 &&
           m.entities.all? { |e| e.is_a?(Sketchup::ComponentInstance) && !e.attribute_dictionary('DagaDyn') },
         'occupato' => d ? (!d.session.nil? || d.foreign_busy?) : false })
RB
abort 'DagaDyn non è caricata in SketchUp' unless pre['dagadyn']
abort 'Serve un modello nuovo: in SketchUp File › Nuovo, poi rilancia' unless pre['nuovo']
abort 'DagaDyn o DagaWASD stanno animando o registrando: fermali, poi rilancia' if pre['occupato']

r = su(<<~RB)
  load #{File.join(ROOT, 'tools', COSTRUTTORE).tr('\\', '/').inspect}
  n = #{MODULO}.costruisci(op: false)
  m = Sketchup.active_model
  m.definitions.purge_unused
  m.materials.purge_unused
  m.shadow_info['City'] = ''
  m.shadow_info['Country'] = ''
  (m.attribute_dictionaries || []).map(&:name).each do |nome|
    next if %w[DagaDyn GeoReference].include?(nome)
    begin
      m.attribute_dictionaries.delete(nome)
    rescue ArgumentError
      nil                      # quelli interni di SketchUp (GSU_ContributorsInfo) non si tolgono
    end
  end
  out.({ 'animati' => n })
RB
puts "costruita: #{r['animati']} oggetti animati"

# Il salvataggio come un comando dell'utente: fuori dall'operazione del ponte
su(<<~RB)
  $dd_esempio = nil
  UI.start_timer(0, false) do
    begin
      $dd_esempio = Sketchup.active_model.save(#{SKP.inspect}, Sketchup::Model::VERSION_2021) ? 'ok' : 'non salvato'
    rescue Exception => e
      $dd_esempio = "\#{e.class}: \#{e.message}"
    end
  end
  out.(nil)
RB
esito = nil
20.times do
  sleep 0.5
  esito = su('out.($dd_esempio)')
  break if esito
end
abort "salvataggio: #{esito || 'nessuna risposta'}" unless esito == 'ok'
skb = SKP.sub(/\.skp\z/, '.skb')
File.delete(skb) if File.exist?(skb)
puts "salvata: #{SKP} (#{File.size(SKP) / 1024} KB)"

# Cosa resta nel modello oltre agli oggetti: va guardato prima di pubblicarlo.
# Dopo il salvataggio SketchUp può scrivere chi ha modificato il file.
resto = su(<<~RB)
  m = Sketchup.active_model
  out.({ 'dizionari' => (m.attribute_dictionaries || []).map { |d| [d.name, d.to_a.map { |k, v| [k, v.to_s[0, 60]] }] },
         'luogo' => [m.shadow_info['City'], m.shadow_info['Country']] })
RB
resto['dizionari'].each { |nome, voci| puts "  dizionario #{nome}: #{voci.map { |k, v| "#{k}=#{v}" }.join(', ')}" }
chi = resto['dizionari'].to_h['GSU_ContributorsInfo'].to_a.to_h['LastModifiedByKey'].to_s
puts "  [!] il file dice chi l'ha modificato (#{chi}): controlla prima di pubblicare" unless chi.empty?
puts "  [!] posizione con città o paese: #{resto['luogo'].inspect}" unless resto['luogo'].all? { |x| x.to_s.empty? }
