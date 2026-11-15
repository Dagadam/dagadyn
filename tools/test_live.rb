# Prova DagaDyn nel SketchUp vero, attraverso il ponte di DagaWASD
# (Sistema › Ponte Claude acceso). Trova quello che la SketchUp finta di
# test_link non può vedere: tempi veri dell'animazione, salvataggio, Ctrl+Z,
# File › Nuovo (su Windows lo stesso oggetto Model, osservatori staccati).
#
#   ruby tools/test_live.rb
#
# Parte solo con un modello VUOTO e mai modificato aperto in SketchUp (File ›
# Nuovo): non può toccare il lavoro di nessuno. Ci costruisce gli oggetti di
# prova, li anima, salva in %TEMP%, annulla, fa File › Nuovo due volte e
# lascia un modello vuoto, come l'ha trovato. Il file di prova si cancella.
#
# Il ponte esegue ogni richiesta dentro un'operazione: i comandi che vanno
# dati come li darebbe l'utente (Play, Aziona, Salva, Annulla, Nuovo) partono
# da un timer appena dopo, fuori da quell'operazione.
require 'json'
require 'net/http'

INFO_PATH = File.join(ENV['APPDATA'] || Dir.home, 'DagaWASD', 'bridge.json')
abort "#{INFO_PATH} non esiste: accendi il ponte in DagaWASD (Sistema › Ponte Claude)" unless File.exist?(INFO_PATH)
INFO = JSON.parse(File.read(INFO_PATH, encoding: 'UTF-8'))
SKP  = File.join(ENV['TEMP'] || Dir.tmpdir, 'dagadyn_prova_live.skp').tr('\\', '/')

def http(req)
  req['X-Token'] = INFO['token']
  res = Net::HTTP.start('127.0.0.1', INFO['port'], open_timeout: 3, read_timeout: 120) { |h| h.request(req) }
  JSON.parse(res.body.force_encoding('UTF-8'))
rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Net::OpenTimeout
  abort "SketchUp non risponde sulla porta #{INFO['port']}: è aperto, col ponte acceso?"
end

# Codice in SketchUp; quello che stampa con `out` torna qui come JSON.
def su(code)
  req = Net::HTTP::Post.new('/eval?op=DagaDyn%20prova')
  req.body = "D = DagaDyn::Dyn unless defined?(D)\nout = ->(x) { puts JSON.generate(x) }\n" + code
  r = http(req)
  raise "in SketchUp: #{r['error']}\n#{(r['backtrace'] || []).join("\n")}" unless r['ok']
  line = r['output'].to_s.lines.last
  line ? JSON.parse(line) : nil
end

# Come un comando dell'utente: fuori dall'operazione del ponte.
def later(code)
  su(<<~RB)
    UI.start_timer(0, false) do
      begin
        #{code}
      rescue => e
        (($dd_live ||= {})[:errs] ||= []) <<"\#{e.class}: \#{e.message}"
      end
    end
    nil
  RB
end

$bad = 0
def eq(what, got, want)
  ok = want.is_a?(Proc) ? want.call(got) : got == want
  puts "#{ok ? 'ok ' : 'NO '} #{what}: #{got.inspect}#{want.is_a?(Proc) ? '' : " (atteso #{want.inspect})"}"
  $bad += 1 unless ok
end
def near(want, tol = 0.5) = ->(x) { x.is_a?(Numeric) && (x - want).abs <= tol }

# Campioni ogni ~0,1 s per `secs` secondi: [[leva, ponte], …] in gradi
def samples(secs)
  out = []
  t_end = Time.now + secs
  while Time.now < t_end
    out << su('out.([$dd_live[:ang].($dd_live[:e]["Leva"]), $dd_live[:ang].($dd_live[:e]["Ponte"])])')
    sleep 0.1
  end
  out
end

# ── Si parte solo da un modello vuoto, con niente in corso ──
ping = http(Net::HTTP::Get.new('/ping'))
abort 'DagaWASD è in modalità FPS: esci (ESC) e rilancia' if ping['fps_active']
pre = su(<<~RB)
  m = Sketchup.active_model
  out.({ 'vuoto' => m.entities.size.zero? && m.definitions.size.zero?, 'modificato' => m.modified?,
         'dagadyn' => defined?(DagaDyn::Dyn) ? true : false,
         'sessione' => defined?(DagaDyn::Dyn) && !DagaDyn::Dyn.session.nil?,
         'occupato' => defined?(DagaDyn::Dyn) && DagaDyn::Dyn.foreign_busy? })
RB
abort 'DagaDyn non è caricata in SketchUp' unless pre['dagadyn']
unless pre['vuoto'] && !pre['modificato']
  abort 'Serve un modello vuoto e mai modificato: in SketchUp File › Nuovo (salvando quello aperto, ' \
        'se ti serve), poi rilancia. La prova non tocca un modello che contiene qualcosa.'
end
abort 'DagaDyn sta animando: Stop, poi rilancia' if pre['sessione']
abort 'DagaWASD sta registrando, riproducendo un percorso o esplorando: aspetta che finisca' if pre['occupato']
puts "SketchUp #{ping['sketchup']}: modello vuoto, si comincia"

begin
  # ── Gli oggetti di prova ──
  su(<<~'RB')
    m = Sketchup.active_model
    $dd_live = { e: {}, rest: {}, errs: [] }
    $dd_live[:ang] = ->(e) { y = e.transformation.yaxis; (Math.atan2(y.z, y.y) * 180 / Math::PI).round(2) }
    $dd_live[:z]   = ->(e) { e.transformation.origin.z.to_m.round(4) }
    lin = [[0, 0], [1, 1]]
    tr = ->(prop, a, b, dur) { { 'prop' => prop, 'keys' => [{ 'v' => a }, { 'v' => b, 'dur' => dur, 'preset' => 'linear', 'curve' => lin }] } }
    box = lambda do |name, x, w, d, h|
      g = m.entities.add_group
      pts = [[0, 0, 0], [w.m, 0, 0], [w.m, d.m, 0], [0, d.m, 0]]
      f = g.entities.add_face(pts)
      f.reverse! if f.normal.z < 0
      f.pushpull(h.m)
      g.transform!(Geom::Transformation.translation([x.m, 0, 0]))
      g.name = "Prova·#{name}"
      $dd_live[:e][name] = g
      g
    end
    scat  = box.('Scatola', 0, 1, 1, 1)
    leva  = box.('Leva', 3, 0.1, 0.1, 0.5)
    ponte = box.('Ponte', 5, 2, 0.2, 1)
    col   = box.('Colore', 8, 1, 1, 1)
    box.('Fermo', 11, 1, 1, 1)
    D.write_data(scat, { 'tracks' => [tr.('move_z', 0, 1.m.to_f, 2.0)] })
    D.write_data(leva, { 'pivot' => 'min', 'tracks' => [tr.('rot_x', 0, 60, 0.6)],
                         'start' => { 'mode' => 'trigger', 'act' => 'toggle' } })
    D.write_data(ponte, { 'pivot' => 'min', 'tracks' => [tr.('rot_x', 0, -80, 1.0)],
                          'start' => { 'mode' => 'after', 'after' => leva.persistent_id, 'wait' => 0.2 } })
    D.write_data(col, { 'tracks' => [tr.('color', '#ff0000', '#0000ff', 2.0)] })
    $dd_live[:e].each { |n, e| $dd_live[:rest][n] = e.transformation.to_a }
    out.(D.animated_instances(m).size)
  RB
  puts 'costruiti: Scatola (timeline), Leva (azionata), Ponte (dietro la leva), Colore, Fermo'

  # ── Play: la timeline va ──
  later('D.cmd_play')
  sleep 1.0
  r = su(<<~'RB')
    e = $dd_live[:e]
    out.({ 'stato' => D.transport_state['state'], 'z' => $dd_live[:z].(e['Scatola']),
           'mat' => e['Colore'].material && e['Colore'].material.name.start_with?(D::TEMP_MAT) })
  RB
  eq('Play: la timeline è partita', r['stato'], 'play')
  eq('…la scatola sale (fra 0,2 e 0,9 m dopo ~1 s)', r['z'], ->(z) { z.between?(0.2, 0.9) })
  eq('…il colore passa da un materiale temporaneo', r['mat'], true)

  # ── Aziona: la leva, poi il ponte quando la leva ha finito ──
  later('D.use_path([$dd_live[:e]["Leva"]])')
  fw = samples(2.4)
  eq('Aziona: la leva arriva a 60°', fw.last[0], near(60))
  eq('…il ponte arriva a -80°', fw.last[1], near(-80))
  eq('…il ponte resta fermo finché la leva si muove', fw.select { |l, _| l < 59 }.map { |_, p| p.abs < 0.5 }.uniq, [true])
  eq('…e si muove davvero (campioni a metà corsa)', fw.count { |_, p| p.between?(-75, -5) }, ->(n) { n >= 2 })

  # ── Aziona di nuovo: si torna, e il ponte aspetta di nuovo la leva ──
  later('D.use_path([$dd_live[:e]["Leva"]])')
  bw = samples(2.4)
  eq('Indietro: la leva torna a 0°', bw.last[0], near(0))
  eq('…il ponte torna a 0°', bw.last[1], near(0))
  eq('…mentre la leva torna il ponte resta giù', bw.select { |l, _| l > 1 }.map { |_, p| (p + 80).abs < 0.5 }.uniq, [true])
  eq('…poi risale (campioni a metà corsa)', bw.count { |_, p| p.between?(-75, -5) }, ->(n) { n >= 2 })

  # ── Salvare durante il Play: nel file lo stato di progetto ──
  later("Sketchup.active_model.save(#{SKP.inspect})")
  sleep 1.0
  r = su(<<~RB)
    m = Sketchup.active_model
    d = m.definitions.load(#{SKP.inspect})
    g = d.entities.grep(Sketchup::Group).to_h { |x| [x.name, x] }
    res = { 'stato' => D.transport_state['state'],
            'scatola_z' => g['Prova·Scatola'].transformation.origin.z.to_m.round(4),
            'colore_mat' => g['Prova·Colore'].material && g['Prova·Colore'].material.name,
            'temp_nel_file' => d.entities.grep(Sketchup::Group).count { |x| x.material && x.material.name.start_with?(D::TEMP_MAT) } }
    m.definitions.remove(d)
    out.(res)
  RB
  eq('Salva durante il Play: l\'animazione continua', r['stato'], 'play')
  eq('…nel file la scatola è a riposo (z = 0)', r['scatola_z'], near(0, 0.001))
  eq('…e niente materiali temporanei nel file', [r['colore_mat'], r['temp_nel_file']], [nil, 0])

  # ── Un'operazione dell'utente durante il Play, Stop, poi Ctrl+Z ──
  later(<<~'RB')
    m = Sketchup.active_model
    m.start_operation('Prova: sposta', true)
    $dd_live[:e]['Fermo'].transform!(Geom::Transformation.translation([0, 2.m, 0]))
    m.commit_operation
  RB
  sleep 0.3
  later('D.cmd_stop')
  sleep 0.3
  later('Sketchup.undo')
  sleep 0.5
  r = su(<<~'RB')
    m = Sketchup.active_model
    e = $dd_live[:e]
    rest = e.keys.reject { |n| n == 'Fermo' }.all? do |n|
      e[n].transformation.to_a.zip($dd_live[:rest][n]).all? { |a, b| (a - b).abs < 1e-6 }
    end
    out.({ 'stato' => D.transport_state['state'], 'riposo' => rest,
           'fermo_y' => e['Fermo'].transformation.origin.y.to_m.round(4),
           'temp' => m.materials.count { |x| x.name.start_with?(D::TEMP_MAT) },
           'temp_addosso' => e.values.count { |x| x.material && x.material.name.start_with?(D::TEMP_MAT) } })
  RB
  eq('Stop: fermo', r['stato'], 'stop')
  eq('…tutti gli animati a riposo', r['riposo'], true)
  eq('Ctrl+Z dopo lo Stop: la mossa dell\'utente si annulla', r['fermo_y'], near(0, 0.001))
  eq('…senza riportare materiali temporanei', [r['temp'], r['temp_addosso']], [0, 0])

  # ── File › Nuovo: osservatori e Overlay riagganciati (due volte) ──
  2.times do |k|
    later("Sketchup.active_model.save(#{SKP.inspect})")      # niente domanda «salvare?»
    sleep 0.6
    later('Sketchup.file_new')
    sleep 1.5
    su(<<~'RB')
      m = Sketchup.active_model
      g = m.entities.add_group
      g.entities.add_face([0, 0, 0], [1.m, 0, 0], [1.m, 1.m, 0])
      D.write_data(g, { 'tracks' => [{ 'prop' => 'move_z', 'keys' => [{ 'v' => 0 }, { 'v' => 1.m.to_f, 'dur' => 0.5 }] }] })
      $dd_live[:probe] = g
      D.animated_instances(m)                       # elenco in memoria…
      D.instance_variable_set(:@path_cache, { probe: true })
      nil
    RB
    su('Sketchup.active_model.entities.add_cpoint([0, 0, 0]); nil')   # …un'operazione lo deve buttare
    su('Sketchup.active_model.selection.add($dd_live[:probe]); nil')
    su('Sketchup.active_model.selection.clear; nil')
    r = su(<<~'RB')
      m = Sketchup.active_model
      ovs = m.respond_to?(:overlays) ? m.overlays.select { |o| o.overlay_id.to_s.start_with?('dagadyn') } : nil
      out.({ 'documento' => m.entities.size == 2,
             'modello' => D.instance_variable_get(:@anim_cache).nil?,
             'selezione' => D.instance_variable_get(:@path_cache) == {},
             'overlay' => ovs && [ovs.size, ovs.all?(&:valid?)] })
    RB
    n = k.zero? ? 'File › Nuovo' : 'Di nuovo Nuovo'
    eq("#{n}: documento nuovo, solo la prova", r['documento'], true)
    eq('…l\'osservatore del modello risponde', r['modello'], true)
    eq('…quello della selezione anche', r['selezione'], true)
    eq('…i due Overlay ci sono e sono validi', r['overlay'], ->(o) { o.nil? || o == [2, true] })
    later('Sketchup.undo; Sketchup.undo')
    sleep 0.5
  end
ensure
  # Si lascia un modello vuoto e senza modifiche, come all'inizio
  begin
    later("D.cmd_stop if D.session; Sketchup.active_model.save(#{SKP.inspect}); UI.start_timer(0.3, false) { Sketchup.file_new }")
    sleep 1.5
    errs = su('out.($dd_live ? $dd_live[:errs] : [])')
    eq('nessun errore nei comandi', errs, [])
    fin = su('m = Sketchup.active_model; out.([m.entities.size, m.path])')
    eq('alla fine: modello vuoto e senza titolo', fin, [0, ''])
  rescue => e
    warn "pulizia: #{e.message}"
    $bad += 1
  end
  Dir[SKP.sub(/\.skp\z/, '*')].each { |f| File.delete(f) rescue nil }
end

puts $bad.zero? ? 'TUTTO OK' : "#{$bad} errori"
exit($bad.zero? ? 0 : 1)
