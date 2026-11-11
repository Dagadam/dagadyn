# Prova il motore di DagaDyn dentro una SketchUp finta (tools/fake_sketchup.rb)
# e il suo aggancio a DagaWASD (I:\WASD\lib\dyn_link.rb, se c'è):
# camminata, piattaforme che portano il giocatore, Aziona, catene, visibilità,
# colori, piani di sezione, video, salvataggio, ombre, voci di annullamento.
#
#   ruby tools/test_link.rb
ROOT = File.expand_path('..', __dir__)
require File.join(ROOT, 'tools', 'fake_sketchup')
$model = Sketchup::Model.new

%w[config i18n settings curves color tracks props player api paths observers panel].each do |f|
  require File.join(ROOT, 'dagadyn', 'lib', f)
end
D = DagaDyn::Dyn
module DagaDyn
  module Dyn
    @cfg  = DEFAULT.dup
    @lang = {}
    def self.log_error(w, e); raise e.class, "#{w}: #{e.message}", e.backtrace; end
    def self.save_cfg; end
  end
end

# DagaWASD: solo il file di collegamento, con quel poco che usa
WASD_LINK = 'I:/WASD/lib/dyn_link.rb'
module DagaWASD
  module FPSWalk
    def self.log_error(w, e); raise e.class, "#{w}: #{e.message}", e.backtrace; end
    def self.t(k); k; end
  end
end
HAVE_WASD = File.exist?(WASD_LINK)
require WASD_LINK if HAVE_WASD
W = DagaWASD::FPSWalk

$bad = 0
def eq(what, got, want, tol = 1e-4)
  ok = want.is_a?(Numeric) && got.is_a?(Numeric) ? (got - want).abs <= tol : got == want
  puts "#{ok ? 'ok ' : 'NO '} #{what}: #{got.is_a?(Float) ? got.round(5) : got.inspect} (atteso #{want.inspect})"
  $bad += 1 unless ok
end

LIN = [[0, 0], [1, 1]].freeze
def anim(e, tracks, start: nil, pivot: 'base', axes: 'object', faces: false)
  data = { 'pivot' => pivot, 'axes' => axes, 'faces' => faces, 'tracks' => tracks }
  data['start'] = start if start
  $model.start_operation('scrivi')
  D.write_data(e, data)
  $model.commit_operation
end
def tr(prop, a, b, dur = 1.0, delay: 0.0, loop: 'none')
  { 'prop' => prop, 'delay' => delay, 'loop' => loop,
    'keys' => [{ 'v' => a }, { 'v' => b, 'dur' => dur, 'preset' => 'linear', 'curve' => LIN }] }
end
def org(e); e.transformation.to_a[12, 3].map { |v| v / 1.m }; end

# ── Il modello ──
plat = $model.add_group([0, 0, 0], [2.m, 2.m, 0.2.m])                    # piattaforma 2×2 m
anim(plat, [tr('move_x', 0, 4.m, 2.0)])
door = $model.add_group([0, 0, 0], [1.m, 0.1.m, 2.m], Geom::Transformation.translation(Geom::Vector3d.new(10.m, 0, 0)))
anim(door, [tr('rot_z', 0, 90, 1.0)], start: { 'mode' => 'trigger', 'act' => 'toggle' }, pivot: 'min')
lamp = $model.add_group([0, 0, 0], [0.3.m, 0.3.m, 0.3.m])
anim(lamp, [tr('visible', 1, 0, 1.0), tr('color', '#ffffff', '#ff0000', 1.0)])
chain = $model.add_group([0, 0, 0], [1.m, 1.m, 1.m])
anim(chain, [tr('move_z', 0, 1.m, 1.0)], start: { 'mode' => 'after', 'after' => plat.persistent_id, 'wait' => 0.5 })
spin = $model.add_group([-1.m, -1.m, 0], [1.m, 1.m, 0.2.m])                # giostra centrata nell'origine
anim(spin, [tr('rot_z', 0, 90, 1.0, delay: 5.0)], axes: 'world', pivot: 'center')
$sections = [Sketchup::SectionPlane.new([0, 0, 1, -1.m])]                  # z = 1 m
sec = $sections[0]
anim(sec, [tr('move_z', 0, 1.m, 1.0)])
still = $model.add_group([0, 0, 0], [1, 1, 1], Geom::Transformation.translation(Geom::Vector3d.new(50.m, 0, 0)))
$model.ops.clear

eq('oggetti animati trovati (anche la sezione)', D.animated_instances($model).size, 6)
eq('durata della timeline: catena fino a 3.5 s, giostra 6 s', D.timeline_length(D.animated_instances($model)), 6.0)

if HAVE_WASD
  # ── Camminata: DagaWASD batte il tempo ──
  eq('camminata: DagaDyn ha qualcosa da animare', W.dyn_begin(:walk), true)
  W.instance_variable_set(:@on_ground, true)
  W.instance_variable_set(:@eye_x, 1.m); W.instance_variable_set(:@eye_y, 1.m)
  W.instance_variable_set(:@floor_z_in, 0.2.m); W.instance_variable_set(:@eye_z, 1.9.m)
  W.instance_variable_set(:@yaw, 0.0)
  W.instance_variable_set(:@floor_hit, [Geom::Point3d.new(1.m, 1.m, 0.2.m), [plat, Sketchup::Face.new]])
  W.dyn_tick(0.0); W.dyn_carry
  eq('fermo all\'inizio', W.instance_variable_get(:@eye_x) / 1.m, 1.0)
  W.dyn_tick(1.0); W.dyn_carry
  eq('piattaforma a 1 s: spostata di 2 m', org(plat)[0], 2.0)
  eq('…e il giocatore con lei', W.instance_variable_get(:@eye_x) / 1.m, 3.0)
  W.dyn_tick(1.5); W.dyn_carry
  eq('…a 1.5 s', W.instance_variable_get(:@eye_x) / 1.m, 4.0)
  eq('la piattaforma non si prende né si calcia', W.dyn_kinematic?([plat]), true)
  eq('un oggetto fermo sì', W.dyn_kinematic?([still]), false)
  eq('Play di DagaDyn rifiutato mentre DagaWASD guida', (D.cmd_play; $status), 't'.then { D.t('rt.busy') })

  # Lampada: a 1.5 s è già spenta e rossa
  eq('lampada nascosta dopo 1 s', lamp.hidden?, true)
  eq('lampada rossa (materiale temporaneo)', [lamp.material.color.red, lamp.material.color.green], [255, 0])
  # Catena: parte 0.5 s dopo la fine della piattaforma (2 s)
  W.dyn_tick(3.0)
  eq('catena a 3 s: mezzo metro su', org(chain)[2], 0.5)
  eq('sezione a 3 s: salita di 1 m (d = −2 m)', sec.get_plane[3] / 1.m, -2.0)

  # Giostra centrata: gira dal secondo 5, e porta il giocatore girandolo
  W.instance_variable_set(:@eye_x, 1.m); W.instance_variable_set(:@eye_y, 0.0)
  W.instance_variable_set(:@floor_z_in, 0.2.m)
  W.instance_variable_set(:@floor_hit, [Geom::Point3d.new(1.m, 0, 0.2.m), [spin, Sketchup::Face.new]])
  W.dyn_tick(5.0); W.dyn_carry
  W.dyn_tick(6.0); W.dyn_carry
  eq('giostra: il giocatore da (1,0) a (0,1)', [W.instance_variable_get(:@eye_x) / 1.m, W.instance_variable_get(:@eye_y) / 1.m].map { |v| v.round(4) }, [0.0, 1.0])
  eq('…e guarda girato di 90°', W.instance_variable_get(:@yaw) * 180 / Math::PI, 90.0)

  # Porta: si aziona col tasto, avanti e poi indietro
  eq('porta ferma prima di azionarla', org(door)[0], 10.0)
  eq('tasto Aziona sulla porta', W.dyn_use([door, Sketchup::Face.new]), true)
  W.dyn_tick(6.5)
  ang = ->(e) { a = e.transformation.to_a; Math.atan2(a[1], a[0]) * 180 / Math::PI }
  eq('porta a metà dopo 0.5 s', ang.call(door), 45.0)
  W.dyn_tick(8.0)
  eq('porta aperta', ang.call(door), 90.0)
  W.dyn_use([door])
  W.dyn_tick(8.25)
  eq('di nuovo: torna indietro', ang.call(door), 67.5)
  eq('tasto Aziona su un oggetto qualsiasi: niente', W.dyn_use([still]), false)

  named = $model.ops.reject { |_, transp| transp }
  eq('una sola voce di annullamento per tutta la camminata', named.map(&:first), ['op.anim'])

  # Salvataggio a metà: nel file lo stato di progetto
  $allow_free = true
  D.session_suspend
  eq('salvando: piattaforma a riposo', org(plat)[0], 0.0)
  eq('salvando: lampada visibile', lamp.hidden?, false)
  eq('salvando: sezione al suo posto', sec.get_plane[3] / 1.m, -1.0)
  D.session_resume
  $allow_free = false
  eq('dopo il salvataggio si riprende', org(plat)[0], 4.0)

  W.dyn_end(:walk)
  eq('fine della camminata: piattaforma a riposo', org(plat)[0], 0.0)
  eq('porta a riposo', ang.call(door).round(6), 0.0)
  eq('lampada di nuovo visibile, senza materiale', [lamp.hidden?, lamp.material], [false, nil])
  eq('niente materiali temporanei rimasti', $model.materials.count { |m| m.name.start_with?(D::TEMP_MAT) }, 0)
  eq('sezione al suo posto', sec.get_plane[3] / 1.m, -1.0)
  eq('nessuna sessione', D.session.nil?, true)

  # ── Video: il tempo è quello del video, non quello dell'orologio ──
  W.dyn_begin(:video)
  [0, 12, 24].each { |k| W.dyn_tick(k / 24.0) }
  eq('video: fotogramma 24 a 24 fps = 1 s', org(plat)[0], 2.0)
  W.dyn_end(:video)
  eq('fine del video: tutto a riposo', org(plat)[0], 0.0)

  # Con l'impostazione spenta DagaWASD non anima nulla
  D.instance_variable_get(:@cfg)['with_dagawasd'] = false
  eq('impostazione spenta: niente', W.dyn_begin(:walk), false)
  W.dyn_end(:walk)
  D.instance_variable_get(:@cfg)['with_dagawasd'] = true
else
  puts '-- DagaWASD non trovato: salto le prove di aggancio'
end

# ── Da solo: Play, ombre spente, pausa, Stop ──
D.instance_variable_get(:@cfg)['play_no_shadows'] = true
$model.ops.clear
D.cmd_play
eq('Play: ombre spente', $model.shadow_info['DisplayShadows'], false)
eq('Play: SketchUp guida l\'animazione', $model.active_view.animation.is_a?(D::Anim), true)
D.cmd_pause
eq('pausa: ombre di nuovo accese', $model.shadow_info['DisplayShadows'], true)
D.cmd_seek(1.0)
eq('timeline a 1 s', org(plat)[0], 2.0)
D.cmd_stop
eq('Stop: a riposo', org(plat)[0], 0.0)

# ── Anteprima di uno stato dal pannello ──
D.cmd_preview(door, 1.0)
ang2 = door.transformation.to_a
eq('anteprima: la porta (azionata) si mostra aperta', (Math.atan2(ang2[1], ang2[0]) * 180 / Math::PI).round(4), 90.0)
D.cmd_preview(chain, 1.0)
eq('anteprima della catena: timeline al suo stato finale (3.5 s)', D.session[:t], 3.5)
D.cmd_stop

# ── Traiettorie nella vista ──
pk = D.path_compute(plat, nil)
eq('traiettoria della piattaforma: da 1 m a 5 m (centro)', [pk[0].first.x / 1.m, pk[0].last.x / 1.m].map { |v| v.round(4) }, [1.0, 5.0])
eq('traiettoria: punti degli stati', pk[1].size, 2)
eq('niente traiettoria per chi non si sposta', D.path_compute(lamp, nil), nil)

# ── Più oggetti: le tracce portate su un altro ──
other = $model.add_group([0, 0, 0], [1.m, 1.m, 2.m], Geom::Transformation.translation(Geom::Vector3d.new(5.m, 0, 0)))
src = { 'pivot' => 'base', 'tracks' => [tr('pos_x', 0.5.m, 3.m), tr('size_z', 1.m, 2.m), tr('rot_z', 0, 45)] }
src = D.sanitize_data(src)
box = $model.add_group([0, 0, 0], [1.m, 1.m, 1.m])
m = D.map_data(src, D.rest_for(box, src), D.rest_for(other, src), false)
eq('posizione X riportata al riposo dell\'altro', m['tracks'][0]['keys'].map { |k| (k['v'] / 1.m).round(4) }, [5.5, 8.0])
eq('altezza in proporzione', m['tracks'][1]['keys'].map { |k| (k['v'] / 1.m).round(4) }, [2.0, 4.0])
eq('rotazione uguale', m['tracks'][2]['keys'].map { |k| k['v'] }, [0.0, 45.0])
eq('su una sezione: solo le proprietà che può avere', D.map_data(src, D.rest_for(box, src), D.rest_for(sec, src), true)['tracks'].size, 0)

# ── Facce con materiale proprio ──
painted = $model.add_group([0, 0, 0], [1.m, 1.m, 1.m])
brick = $model.materials.add('Mattone')
f1 = Sketchup::Face.new; f1.material = brick
painted.definition.entities << f1
anim(painted, [tr('opacity', 1.0, 0.0, 1.0)], faces: true)
D.cmd_seek(0.5)
eq('faccia dipinta: copia temporanea a metà opacità', [f1.material.name.start_with?(D::TEMP_MAT), f1.material.alpha], [true, 0.5])
D.cmd_stop
eq('faccia di nuovo col suo materiale', f1.material.equal?(brick), true)

puts $bad.zero? ? 'TUTTO OK' : "#{$bad} errori"
exit($bad.zero? ? 0 : 1)
