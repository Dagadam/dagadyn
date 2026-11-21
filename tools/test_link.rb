# Prova il motore di DagaDyn dentro una SketchUp finta (tools/fake_sketchup.rb)
# e il suo aggancio a DagaWASD (lib/dyn_link.rb dei sorgenti di DagaWASD, se
# ci sono: la cartella WASD accanto a questa, o quella in DAGAWASD_DIR):
# camminata, piattaforme che portano il giocatore, Aziona, catene, visibilità,
# colori, piani di sezione, video, salvataggio, ombre, voci di annullamento.
#
#   ruby tools/test_link.rb
ROOT = File.expand_path('..', __dir__)
require File.join(ROOT, 'tools', 'fake_sketchup')
$model = Sketchup::Model.new

%w[config i18n settings curves formula color tracks props player api paths observers panel].each do |f|
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
WASD_LINK = File.join(ENV['DAGAWASD_DIR'] || File.expand_path('../../WASD', __dir__), 'lib', 'dyn_link.rb')
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

# Due copie dello stesso componente, tutte e due con «anche le facce»: la
# definizione è comune, quindi la seconda copia le facce già dipinte dalla
# prima. Cambiando i dati di una durante la sessione (lei esce e rientra:
# l'ordine si inverte), allo Stop le facce tornano lo stesso al materiale vero.
[0, 1].each do |chi|
  wood = $model.materials.add("Legno #{chi}")
  ca = $model.add_group([0, 0, 0], [1.m, 1.m, 1.m], Geom::Transformation.new, Sketchup::ComponentInstance)
  cb = Sketchup::ComponentInstance.new(ca.definition, Geom::Transformation.translation(Geom::Vector3d.new(3.m, 0, 0)))
  f2 = Sketchup::Face.new; f2.material = wood
  ca.definition.entities << f2
  anim(ca, [tr('opacity', 1.0, 0.0, 1.0)], faces: true)
  anim(cb, [tr('opacity', 1.0, 0.5, 1.0)], faces: true)
  D.cmd_seek(0.5)
  eq("copie con le facce (#{chi}): faccia con un materiale temporaneo", f2.material.name.start_with?(D::TEMP_MAT), true)
  mod = [ca, cb][chi]
  $model.start_operation('modifica')
  d = D.read_data(mod)
  d['tracks'][0]['keys'][1]['v'] = 0.25
  D.write_data(mod, d)
  $model.commit_operation
  D.session_update(mod, D.read_data(mod))
  eq("…modificata la copia #{chi + 1}: le facce restano animate", f2.material.name.start_with?(D::TEMP_MAT), true)
  D.cmd_stop
  eq("…allo Stop la faccia torna al suo materiale", f2.material.equal?(wood), true)
  eq("…e nessun materiale temporaneo resta nel modello", $model.materials.count { |m| m.name.start_with?(D::TEMP_MAT) }, 0)
  [ca, cb].each { |x| $model.start_operation('via'); D.write_data(x, D.empty_data); $model.commit_operation }
end

# ── Lingua e aspetto da DagaWASD ──
eq('senza cf di DagaWASD: niente in comune', D.ui_shared?, false)
own = D.cf('ui_theme')
wcfg = { 'language' => 'de', 'ui_theme' => 'midnight', 'ui_accent' => '#123abc', 'ui_font_size' => 17.0,
         'ui_font' => 'nonesiste', 'ui_logo' => 'bolt', 'play_speed' => 3.0 }
W.define_singleton_method(:cf) { |k| wcfg[k] }
pc = D.panel_cfg
eq('con DagaWASD: lingua e tema i suoi', [pc['language'], pc['ui_theme'], pc['ui_accent'], pc['ui_font_size']], ['de', 'midnight', '#123abc', 17.0])
eq('un suo valore non valido: resta il nostro', pc['ui_font'], D.cf('ui_font'))
eq('il logo resta di DagaDyn', pc['ui_logo'], D.cf('ui_logo'))
eq('le impostazioni non grafiche restano nostre', pc['play_speed'], D.cf('play_speed'))
eq('le nostre non vengono toccate', D.cf('ui_theme'), own)
eq('lingua dei testi: quella di DagaWASD', (D.load_lang; D.instance_variable_get(:@lang_code)), 'de')
W.singleton_class.send(:remove_method, :cf)
eq('DagaWASD tolta: di nuovo le nostre', [D.ui_shared?, D.panel_cfg['ui_theme']], [false, own])
D.load_lang
D.cmd_stop

# ── Segnaposto {nome} nei testi: sostituiti in tutte le lingue ──
# (prima lo strumento Aziona scriveva alla lettera «azionato "{name}"»)
langs = Dir[File.join(ROOT, 'dagadyn', 'lang', '*.json')].map { |f| File.basename(f, '.json') } - ['index']
holes = langs.reject do |code|
  D.instance_variable_set(:@lang, JSON.parse(File.read(File.join(ROOT, 'dagadyn', 'lang', "#{code}.json"), encoding: 'UTF-8')))
  s = D.tf('rt.used', name: 'Porta \\1 & co')
  s.include?('Porta \\1 & co') && !s.include?('{')
end
eq('«azionato» col nome dell\'oggetto, in ogni lingua', holes, [])
D.load_lang
eq('un segnaposto sconosciuto resta com\'è', D.tf('rt.used', altro: 1).include?('{name}'), true)

# ── Voce di annullamento: dopo un'operazione dell'utente la sessione non vi si accoda ──
obs = D::ModelObs.new
D.cmd_seek(0.5)                                     # lampada: colore → operazione della sessione
$model.start_operation('Sposta'); $model.commit_operation
obs.onTransactionCommit($model)                     # SketchUp avvisa: operazione non nostra
$model.ops.clear
D.cmd_seek(0.7)
eq('dopo l\'operazione dell\'utente: una voce nuova, non trasparente', $model.ops.first, [D.t('op.anim'), false])
$model.ops.clear
D.save_tracks(JSON.generate('pid' => lamp.persistent_id, 'data' => D.read_data(lamp)))
eq('dopo una modifica dal pannello: lo stesso', $model.ops.first(2), [[D.t('op.edit'), false], [D.t('op.anim'), false]])
$model.ops.clear
D.cmd_seek(0.8)
eq('…e poi di nuovo accodate', $model.ops.map(&:last).uniq, [true])
D.cmd_stop

# ── Velocità cambiata durante il Play: la timeline non salta ──
D.cmd_play
s = D.session
s[:wall0] = Time.now.to_f - 2.0                      # 2 s di Play a 1×
D.instance_variable_get(:@cfg)['play_speed'] = 2.0
D.speed_kept(1.0)
eq('da 1× a 2× dopo 2 s: si resta a 2 s', D.clock(s, Time.now.to_f), 2.0, 0.05)
eq('…e da lì si va al doppio', D.clock(s, Time.now.to_f + 1.0), 4.0, 0.05)
D.instance_variable_get(:@cfg)['play_speed'] = 1.0
D.cmd_stop
D.ext_begin(:walk)
D.ext_tick(1.0)
D.instance_variable_get(:@cfg)['play_speed'] = 2.0
D.speed_kept(1.0)
D.ext_tick(1.0)
eq('con DagaWASD: stesso istante subito dopo il cambio', D.session[:t], 1.0)
D.ext_tick(1.5)
eq('…poi al doppio', D.session[:t], 2.0)
D.instance_variable_get(:@cfg)['play_speed'] = 1.0
D.ext_end(:walk)

# ── Materiale originale eliminato durante la sessione: lo Stop ripristina lo stesso ──
legno = $model.materials.add('Legno')
crate = $model.add_group([0, 0, 0], [1.m, 1.m, 1.m])
$model.start_operation('dipingi'); crate.material = legno; $model.commit_operation
anim(crate, [tr('color', '#ffffff', '#00ff00', 1.0)])
D.cmd_seek(0.5)
eq('cassa: materiale temporaneo', crate.material.name.start_with?(D::TEMP_MAT), true)
$model.materials.remove(legno)                       # Elimina inutilizzati
D.cmd_stop
eq('Stop: niente materiale (l\'originale non c\'è più)', crate.material, nil)
eq('…e niente materiali temporanei rimasti', $model.materials.count { |m| m.name.start_with?(D::TEMP_MAT) }, 0)

# ── Salvataggio: niente materiali temporanei nel file, nascosti a mano restano tali ──
D.cmd_seek(1.0)                                      # piattaforma a 2 m, lampada rossa
$model.start_operation('Sposta')
plat.transformation = Geom::Transformation.translation(Geom::Vector3d.new(1.m, 0, 0)) * plat.transformation
chain.hidden = true
$model.commit_operation
$allow_free = true
D.session_suspend
eq('salvando: nessun materiale temporaneo nel modello', $model.materials.count { |m| m.name.start_with?(D::TEMP_MAT) }, 0)
eq('salvando: la lampada senza materiale', lamp.material, nil)
eq('salvando: nascosto a mano resta nascosto', chain.hidden?, true)
eq('salvando: spostato a mano in pausa = nuovo riposo', org(plat)[0], 1.0)
D.session_resume
$allow_free = false
eq('dopo il salvataggio: di nuovo il materiale temporaneo', lamp.material && lamp.material.name.start_with?(D::TEMP_MAT), true)
eq('…e la piattaforma dove l\'utente l\'aveva portata', org(plat)[0], 3.0)
D.cmd_stop
$model.start_operation('mostra'); chain.hidden = false
plat.transformation = Geom::Transformation.new; $model.commit_operation

# ── Anteprima di uno stato in catena dietro un azionato ──
hinge = $model.add_group([0, 0, 0], [1.m, 1.m, 1.m])
anim(hinge, [tr('move_x', 0, 2.m, 1.0)], start: { 'mode' => 'after', 'after' => door.persistent_id })
D.cmd_preview(hinge, 1.0)
eq('anteprima dietro l\'azionato fermo: si vede lo stato', org(hinge)[0], 2.0)
D.cmd_seek(0.0)
eq('la timeline riparte: torna ad aspettare l\'azionato', org(hinge)[0], 0.0)
D.cmd_stop

# ── Piani di sezione copiati ──
copy = Sketchup::SectionPlane.new(sec.get_plane)
copy.set_attribute(D::DICT, D::DATA_KEY, sec.get_attribute(D::DICT, D::DATA_KEY))
$sections << copy
$model.selection.replace([copy])
eq('copia non ancora nell\'elenco', D.animated_instances($model).map(&:first).include?(copy), false)
$model.ops.clear
D.section_adopt($model)
eq('copia selezionata: entra nell\'elenco', D.animated_instances($model).map(&:first).include?(copy), true)
eq('…con un\'operazione trasparente (si annulla con la copia)', $model.ops, [[D.t('op.anim'), true]])
copy.erase!
anim(sec, [tr('move_z', 0, 2.m, 1.0)])
eq('copia eliminata: il suo id esce dall\'elenco', D.section_pids($model).include?(copy.persistent_id), false)
$model.selection.clear

# ── File › Nuovo su Windows: stesso oggetto Model, osservatori e Overlay staccati ──
D.observe_model($model)
ids = ->() { $model.overlays.map(&:overlay_id).sort }
eq('agganciato: osservatori e due Overlay', [$model.observers.size, $model.selection.observers.size, ids.()],
   [1, 1, %w[dagadyn.extents dagadyn.paths]])
D.cmd_seek(0.5)
$model.new_document!
eq('dopo Nuovo: Overlay non più validi', D.instance_variable_get(:@overlays)[$model].map(&:valid?), [false, false])
D::AppObs.new.onNewModel($model)
eq('riagganciati: un osservatore per tipo', [$model.observers.size, $model.selection.observers.size], [1, 1])
eq('…e i due Overlay, validi', [ids.(), $model.overlays.all?(&:valid?)], [%w[dagadyn.extents dagadyn.paths], true])
eq('la sessione del documento di prima è finita', D.session.nil?, true)
D.overlay_refresh                                    # il caso del registro: impostazione salvata dal pannello
eq('cambiare un\'impostazione non dà più «invalid overlay»', $model.overlays.all?(&:enabled?), true)
D::AppObs.new.onActivateModel($model)
eq('attivare lo stesso modello non aggiunge doppioni', [$model.observers.size, $model.overlays.count], [1, 2])

# ── Strumento Aziona: sotto il mouse riquadro, nome e cursore; niente parte prima del clic ──
use_m = Sketchup::Model.new
$model = use_m
D.cmd_stop if D.session
box   = use_m.add_group([0, 0, 0], [1.m, 1.m, 1.m])                        # contenitore
lever = use_m.add_group([0, 0, 0], [0.1.m, 0.1.m, 0.5.m], Geom::Transformation.translation(Geom::Vector3d.new(1.m, 0, 0)))
still = use_m.add_group([0, 0, 0], [1.m, 1.m, 1.m])                        # animato, ma con la timeline
anim(lever, [tr('rot_x', 0, 45, 1.0)], start: { 'mode' => 'trigger', 'act' => 'toggle' })
anim(still, [tr('move_x', 0, 1.m, 1.0)])
box.name = 'Scatola'; lever.name = 'Leva'
$picks = { [10, 10] => [[box, lever]], [20, 20] => [[still]], [30, 30] => [] }
tool = D::UseTool.new
view = use_m.active_view
cur_png = ->() { c = $cursors[$cursor - 77]; [File.basename(c[0]), c[1, 2], File.exist?(c[0])] }
tool.activate
eq('lo strumento guarda sotto il mouse anche da fermo (timer)', tool.instance_variable_get(:@timer).nil?, false)
tool.onMouseMove(0, 20, 20, view)
tool.onSetCursor
eq('sopra un oggetto che non si aziona: niente nome, freccia semplice', [view.tooltip, cur_png.()],
   ['', ['arrow_cursor.png', [1, 1], true]])
tool.onMouseMove(0, 10, 10, view)
eq('sopra la leva (dentro un gruppo): il suo nome', view.tooltip, 'Leva')
tool.onSetCursor
eq('…il triangolo di Play, che clicca dal centro', cur_png.(), ['use_cursor.png', [14, 16], true])
eq('…e niente parte finché non si clicca', D.session.nil?, true)
# La leva si sposta col mouse fermo: al giro dopo del timer non è più lì sotto
$picks[[10, 10]] = []
tool.refresh(view)
view.drawn&.clear
tool.draw(view)
eq('oggetto uscito da sotto il mouse: niente nome, riquadro, freccia semplice',
   [view.tooltip, (view.drawn || []).size, cur_png.()[0]], ['', 0, 'arrow_cursor.png'])
$picks[[10, 10]] = [[box, lever]]                                    # e ci torna
tool.refresh(view)
eq('…ci torna sotto: di nuovo evidenziato', [view.tooltip, cur_png.()[0]], ['Leva', 'use_cursor.png'])
tool.draw(view)
mode, pts = view.drawn.last
xs = pts.map { |p| (p.x / 1.m).round(3) }.uniq.sort
eq('riquadro: 12 spigoli, nel mondo (x della leva da 1 a 1.1 m)', [mode, pts.size, xs], [GL_LINES, 24, [1.0, 1.1]])
eq('…e SketchUp lo sa (getExtents)', (tool.getExtents.max.z / 1.m).round(3), 0.5)
# Strumento lasciato e ripreso sopra lo stesso oggetto: SketchUp ha tolto il nome, va rimesso
tool.deactivate(view)
view.tooltip = ''
tool.activate
tool.onMouseMove(0, 10, 10, view)
eq('strumento ripreso sopra la stessa leva: il nome torna', view.tooltip, 'Leva')
lever.erase!
view.drawn.clear
tool.draw(view)
tool.onSetCursor
eq('leva cancellata sotto il mouse: niente riquadro, freccia semplice', [view.drawn.size, cur_png.()[0]], [0, 'arrow_cursor.png'])
tool.onMouseMove(0, 30, 30, view)
eq('nel vuoto: niente nome', view.tooltip, '')
tool.deactivate(view)
eq('chiuso lo strumento, il timer si ferma', tool.instance_variable_get(:@timer), nil)

# ── Modelli grandi: l'elenco degli animati non si ricerca a ogni selezione ──
big = Sketchup::Model.new
$model = big
D.model_changed(big, true)
scans = 0
big.define_singleton_method(:definitions) { scans += 1; super() }
movers = Array.new(30) { |i| big.add_group([0, 0, 0], [1.m, 1.m, 1.m], Geom::Transformation.translation(Geom::Vector3d.new(i * 2.m, 0, 0))) }
200.times { big.add_group([0, 0, 0], [1.m, 1.m, 1.m]) }               # arredo fermo
movers.each { |g| anim(g, [tr('move_z', 0, 1.m, 1.0)]) }
scans = 0
big.selection.replace([movers[3]])
sel = D.selection_info(D.animated_instances(big))
3.times { D.scene_info }
eq('selezione e scena: il modello si scorre una volta sola', scans, 1)
eq('…e i dati sono quelli giusti', [sel['others'].size, D.scene_info['objects'].size], [29, 30])
D::ModelObs.new.onTransactionCommit(big)                            # una copia, un'eliminazione…
D.scene_info
eq('dopo un\'operazione si riscorre', scans, 2)
movers[0].erase!
eq('oggetto eliminato: esce subito dall\'elenco', D.scene_info['objects'].size, 29)
anim(movers[1], [])
eq('tracce tolte (write_data): esce dall\'elenco', D.scene_info['objects'].size, 28)
anim(movers[1], [tr('move_z', 0, 1.m, 1.0)])
# Un oggetto animato dentro un componente che non è più nel modello (tutte le
# copie eliminate: resta fra i componenti «Nel modello»): non si vede, non conta
cont = big.add_group([0, 0, 0], [3.m, 3.m, 3.m])
movers[2].parent = cont.definition
D::ModelObs.new.onTransactionCommit(big)
eq('dentro un contenitore che sta nel modello: conta', D.scene_info['objects'].size, 29)
cont.erase!
D::ModelObs.new.onTransactionCommit(big)
eq('contenitore eliminato dal modello: l\'oggetto dentro non conta più', D.scene_info['objects'].size, 28)
movers[2].parent = big
D::ModelObs.new.onTransactionCommit(big)
eq('…rimesso nel modello: conta di nuovo', D.scene_info['objects'].size, 29)

# Ctrl+Z durante il Play: durata, traiettorie e pose una volta sola, non una per oggetto
D.cmd_play
applies = 0
D.singleton_class.send(:alias_method, :apply_before_test, :apply)
D.define_singleton_method(:apply) { |*a| applies += 1; apply_before_test(*a) }
$run_timers = true
D::ModelObs.new.onTransactionUndo(big)
$run_timers = false
D.singleton_class.send(:alias_method, :apply, :apply_before_test)
eq('annulla con 29 oggetti in moto: pose rifatte una volta', applies, 1)
eq('…e la sessione li ha ancora tutti', D.session[:items].size, 29)
D.cmd_stop

# ── Fine della timeline con un azionato finito dopo: non si torna indietro ──
# (trovato da tools/test_live.rb: il ponte si fermava a -6° invece di -80°)
endm = Sketchup::Model.new
$model = endm
D.model_changed(endm, true)
clock_box = endm.add_group([0, 0, 0], [1.m, 1.m, 1.m])
lev = endm.add_group([0, 0, 0], [0.1.m, 0.1.m, 0.5.m])
brg = endm.add_group([0, 0, 0], [2.m, 0.2.m, 1.m])
anim(clock_box, [tr('move_z', 0, 1.m, 2.0)])                             # timeline lunga 2 s
anim(lev, [tr('rot_x', 0, 60, 0.6)], start: { 'mode' => 'trigger', 'act' => 'toggle' }, pivot: 'min')
anim(brg, [tr('rot_x', 0, -80, 1.0)], start: { 'mode' => 'after', 'after' => lev.persistent_id, 'wait' => 0.2 }, pivot: 'min')
ang = ->(e) { a = e.transformation.to_a; (Math.atan2(a[6], a[5]) * 180 / Math::PI).round(2) }
D.cmd_play
s = D.session
w0 = s[:wall0]
D.advance(w0 + 1.1)
D.trigger_item(s, s[:items][lev], 1.1)                                   # leva a 1.1 s: ponte da 1.9 a 2.9 s
eq('a 2.5 s la timeline è finita ma il ponte scende: si va avanti', D.advance(w0 + 2.5), true)
eq('a 3.5 s tutto fermo: ci si ferma', D.advance(w0 + 3.5), false)
eq('…con il ponte giù, non tornato a com\'era a 2 s', [ang.(lev), ang.(brg)], [60.0, -80.0])
eq('…e il tempo dove si è arrivati', D.session[:t], 3.5)
D.cmd_stop

# ── Ctrl+Z dopo lo Stop, con un'operazione dell'utente durante l'animazione ──
# (trovato da tools/test_live.rb: annullare rimetteva il materiale temporaneo)
um = Sketchup::Model.new
$model = um
D.model_changed(um, true)
red = um.materials.add('Rosso')
paint = um.add_group([0, 0, 0], [1.m, 1.m, 1.m])
$allow_free = true
paint.material = red
$allow_free = false
mover = um.add_group([0, 0, 0], [1.m, 1.m, 1.m])
anim(paint, [tr('color', '#ff0000', '#0000ff', 2.0)])
anim(mover, [tr('move_x', 0, 2.m, 2.0)])
rest_mover = mover.transformation.to_a
D.cmd_play
s = D.session
D.advance(s[:wall0] + 0.5)
temp_name = paint.material.name
um.start_operation('Sposta', true); um.commit_operation          # l'utente fa qualcosa
D::ModelObs.new.onTransactionCommit(um)
D.advance(s[:wall0] + 1.0)                                       # la sessione apre una voce sua
D.cmd_stop
eq('Stop: materiale originale, nessun temporaneo', [paint.material.name, um.materials.count { |m| m.name.start_with?(D::TEMP_MAT) }], ['Rosso', 0])
eq('voci nate durante la sessione: animazione, utente, animazione', D.instance_variable_get(:@ended)[:depth], 3)
# Ctrl+Z della voce dell'animazione: SketchUp rimette com'era a metà
$allow_free = true
back = um.materials.add(temp_name)
paint.material = back
mover.transformation = Geom::Transformation.translation(Geom::Vector3d.new(1.m, 0, 0))
$allow_free = false
$run_timers = true
D::ModelObs.new.onTransactionUndo(um)
$run_timers = false
eq('dopo Ctrl+Z: di nuovo il materiale originale', paint.material.name, 'Rosso')
eq('…il temporaneo tolto dal modello', um.materials.count { |m| m.name.start_with?(D::TEMP_MAT) }, 0)
eq('…e l\'oggetto a riposo', mover.transformation.to_a, rest_mover)
# Due Ctrl+Z ancora: prima dell'inizio della sessione ciò che c'è è dell'utente
$run_timers = true
D::ModelObs.new.onTransactionUndo(um)
D::ModelObs.new.onTransactionUndo(um)
$allow_free = true
mover.transformation = Geom::Transformation.translation(Geom::Vector3d.new(5.m, 0, 0))   # uno stato di prima
$allow_free = false
D::ModelObs.new.onTransactionUndo(um)
$run_timers = false
eq('annullando oltre l\'inizio della sessione non si tocca niente', org(mover)[0], 5.0)

# ── Velocità del tempo: una curva per tutto il modello (time-lapse, rallentatore) ──
tm = Sketchup::Model.new
$model = tm
D.model_changed(tm, true)
bar = tm.add_group([0, 0, 0], [1.m, 1.m, 1.m])
anim(bar, [tr('move_x', 0, 10.m, 10.0)])                                 # timeline di 10 s: 1 m al secondo
eq('senza curva: tempo normale', D.read_time(tm), nil)
eq('dati sporchi: lineare, senza durata', D.sanitize_time('preset' => 'boh', 'curve' => 'x', 'dur' => -2),
   { 'v' => 1, 'preset' => 'linear', 'curve' => [[0.0, 0.0], [1.0, 1.0]] })
eq('durata oltre il limite', D.sanitize_time('dur' => 1e9)['dur'], 3600.0)
tm.ops.clear
D.save_time(JSON.generate('preset' => 'linear', 'curve' => LIN, 'dur' => 2.0))   # 10 s in 2: ×5
eq('dal pannello: una voce di annullamento', tm.ops, [[D.t('tw.title'), false]])
eq('la scena la vede', D.scene_info['time'], { 'v' => 1, 'preset' => 'linear', 'curve' => [[0.0, 0.0], [1.0, 1.0]], 'dur' => 2.0 })
D.cmd_play
s = D.session
w0 = s[:wall0]
D.advance(w0 + 1.0)
eq('time-lapse ×5: dopo 1 s la timeline è a 5 s', s[:t], 5.0)
eq('…e l\'oggetto a 5 m', org(bar)[0], 5.0)
eq('riproduzione finita dopo 2 s: ci si ferma', D.advance(w0 + 2.5), false)
eq('…con tutto alla fine', org(bar)[0], 10.0)
D.cmd_play
eq('Play di nuovo: da capo', [s[:c], s[:t]], [0.0, 0.0])
D.cmd_pause
D.cmd_seek(5.0)
eq('barra a 5 s: la riproduzione a 1 s', s[:c], 1.0)
D.save_time(JSON.generate('preset' => 'ease_in'))                      # il tempo parte piano e accelera
eq('curva cambiata in pausa: la timeline resta a 5 s', D.warp(s, s[:c]), 5.0)
eq('accelera: a metà riproduzione la timeline a 1.25 s', D.warp(s, 5.0), 1.25)
D.cmd_seek(2.0)
D.cmd_play
s[:wall0] -= 1.0                                                         # un secondo di Play
t_before = D.warp(s, D.clock(s, Time.now.to_f))
D.save_time(JSON.generate('preset' => 'linear', 'curve' => LIN, 'dur' => 5.0))   # ×2
t_after = D.warp(s, D.clock(s, Time.now.to_f))
eq('curva cambiata durante il Play: la timeline non salta', t_after, t_before, 0.02)
eq('…e da lì corre al doppio', D.warp(s, D.clock(s, Time.now.to_f + 1.0)) - t_after, 2.0, 0.02)
D.cmd_pause
D.instance_variable_get(:@cfg)['play_repeat'] = true
D.warp_setup(s)                                                          # come salvando le impostazioni
D.cmd_seek(0.0)
D.cmd_play
D.advance(s[:wall0] + 6.0)                                               # 5 s a giro: 1 s nel secondo giro
eq('«Ripeti»: la curva ricomincia a ogni giro', s[:t], 2.0)
D.instance_variable_get(:@cfg)['play_repeat'] = false
D.cmd_stop
D.ext_begin(:video)
D.ext_tick(1.0)
eq('video di DagaWASD: la curva anche lì', D.session[:t], 2.0)
eq('…e la barra mostra quell\'istante (non l\'orologio fermo del Play)', D.transport_state['t'], 2.0)
D.ext_end(:video)
D.save_time(JSON.generate('preset' => 'custom', 'curve' => [[0, 0], [0.4, 0.8], [0.7, 0.4], [1, 1]]))  # avanti, indietro, avanti
D.cmd_seek(6.0)
s = D.session
eq('curva che torna indietro: la barra a 6 s dal primo passaggio', s[:c].between?(0.0, 4.0), true)
s[:c] = 5.5
D.cmd_seek(6.0)
eq('…dal punto della riproduzione vicino al ritorno: il ritorno', s[:c].between?(4.0, 7.0), true)
s[:c] = 9.0
D.cmd_seek(6.0)
eq('…vicino alla fine: l\'ultimo passaggio', s[:c].between?(7.0, 10.0), true)
eq('…sempre la timeline a 6 s', D.warp(s, s[:c]), 6.0)
tm.set_attribute(D::DICT, D::TIME_KEY, '')                             # Ctrl+Z: il modello senza la curva
$run_timers = true
D::ModelObs.new.onTransactionUndo(tm)
$run_timers = false
eq('Ctrl+Z della curva: di nuovo il tempo normale', [s[:warp], D.warp(s, 3.0), s[:t]], [nil, 3.0, 6.0])
D.save_time(JSON.generate('preset' => 'linear', 'curve' => LIN))
eq('lineare e lunga quanto la timeline: la chiave si svuota', tm.get_attribute(D::DICT, D::TIME_KEY), '')
D.cmd_stop
anim(bar, [tr('move_x', 0, 10.m, 10.0)], start: { 'mode' => 'trigger', 'act' => 'play' })
D.save_time(JSON.generate('preset' => 'ease_in', 'dur' => 3.0))
s = D.session_start(tm)
eq('timeline vuota (solo azionati): la curva non conta', [s[:warp], D.play_len(s), D.warp(s, 1.5)], [nil, 0.0, 1.5])
D.cmd_stop

# ── Oggetto animato dentro un altro: l'ingombro dei contenitori segue ──
# (lo scooter del video: move! lasciava ai contenitori l'ingombro di riposo,
# e SketchUp non disegnava lo scooter quando quel vecchio ingombro usciva
# dalla vista)
nest = Sketchup::Model.new
$model = nest
D.model_changed(nest, true)
outer = nest.add_group([0, 0, 0], [4.m, 4.m, 1.m])                      # contenitore nel modello
mid = nest.add_group([0, 0, 0], [2.m, 2.m, 1.m])                        # contenitore dentro outer
mid.parent = outer.definition
rider = nest.add_group([0, 0, 0], [0.2.m, 0.2.m, 0.2.m])                # l'animato, dentro mid
rider.parent = mid.definition
solo = nest.add_group([0, 0, 0], [1.m, 1.m, 1.m])                       # animato nel modello
anim(rider, [tr('move_x', 0, 1.m, 1.0)])
anim(solo, [tr('move_y', 0, 1.m, 1.0)])
D::ModelObs.new.onTransactionCommit(nest)
D.cmd_seek(0.5)
eq('spostato dentro due contenitori: tutti e due rifanno l\'ingombro', [mid.definition.stale > 0, outer.definition.stale > 0], [true, true])
eq('…e lui è a metà strada', org(rider)[0], 0.5)
st = [mid.definition.stale, outer.definition.stale]
D.cmd_seek(0.8)
eq('a ogni passo', [mid.definition.stale > st[0], outer.definition.stale > st[1]], [true, true])
eq('l\'animato nel modello non tocca i contenitori degli altri', solo.definition.stale, 0)
st = [mid.definition.stale, outer.definition.stale]
D.cmd_stop
eq('Stop: a riposo, e l\'ingombro si rifà anche lì', [org(rider)[0], mid.definition.stale > st[0], outer.definition.stale > st[1]], [0.0, true, true])

# ── Transizioni a formula: un oggetto segue l'altro ──
# Il cubo cresce da 1 a 2 m in 2 s; la lastra è larga 0.5 + K/2 con K =
# altezza del cubo; la sfera si sposta di K × 2 m, K = avanzamento della
# transizione del cubo (0–1).
fxm = Sketchup::Model.new
$model = fxm
D.model_changed(fxm, true)
def xlen(e); a = e.transformation.to_a; Math.sqrt(a[0]**2 + a[1]**2 + a[2]**2) * e.definition.bounds.width / 1.m; end
def fxtr(prop, v0, dur, expr, params)
  { 'prop' => prop, 'keys' => [{ 'v' => v0 }, { 'v' => v0, 'dur' => dur, 'preset' => 'linear', 'curve' => LIN,
                                                 'fx' => { 'on' => true, 'expr' => expr, 'params' => params } }] }
end
cubo = fxm.add_group([0, 0, 0], [1.m, 1.m, 1.m])
lastra = fxm.add_group([0, 0, 0], [1.m, 1.m, 0.1.m], Geom::Transformation.translation(Geom::Vector3d.new(3.m, 0, 0)))
sfera = fxm.add_group([0, 0, 0], [0.5.m, 0.5.m, 0.5.m], Geom::Transformation.translation(Geom::Vector3d.new(6.m, 0, 0)))
anim(cubo, [tr('size_z', 1.m, 2.m, 2.0)])
anim(lastra, [fxtr('size_x', 1.m, 2.0, '0.5 + K/2', [{ 'n' => 'K', 'pid' => cubo.persistent_id, 'prop' => 'size_z', 'at' => 0 }])])
anim(sfera, [fxtr('move_x', 0, 2.0, 'K * 2', [{ 'n' => 'K', 'pid' => cubo.persistent_id, 'prop' => 'size_z', 'at' => 1 }])])
D::ModelObs.new.onTransactionCommit(fxm)
eq('formula: le scritte nella scena non cambiano la timeline', D.timeline_length(D.animated_instances(fxm)), 2.0)
pts = D.path_compute(sfera, nil)
eq('traiettoria fuori dal Play: la sfera legge il cubo (2 m in fondo)', pts && (pts[0].last.x - pts[0].first.x) / 1.m, 2.0)
D.cmd_seek(1.0)
eq('a 1 s la lastra è larga 0.5 + 1.5/2 m', xlen(lastra), 1.25)
eq('…e la sfera a metà della transizione del cubo: 1 m', org(sfera)[0] - 6.0, 1.0)
D.cmd_seek(2.0)
eq('a 2 s: 1.5 m e 2 m', [xlen(lastra), org(sfera)[0] - 6.0].map { |v| v.round(6) }, [1.5, 2.0])
D.cmd_stop
eq('Stop: tutto a riposo', [xlen(lastra), org(sfera)[0]].map { |v| v.round(6) }, [1.0, 6.0])
info = D.obj_info(lastra)
eq('pannello: gli altri oggetti con le tracce che una formula può leggere', info['others'].find { |o| o['pid'] == cubo.persistent_id }['tracks'],
   [{ 'prop' => 'size_z', 'n' => 1 }])
chk = ->(e, data) { D.fx_check(JSON.generate('pid' => e.persistent_id, 'data' => data, 'seq' => 7)) }
eq('controllo: tutto a posto', chk.call(lastra, D.read_data(lastra)).values_at('seq', 'errs'), [7, {}])
giro = D.read_data(cubo)
giro['tracks'][0]['keys'][1]['fx'] = { 'on' => true, 'expr' => 'K', 'params' => [{ 'n' => 'K', 'pid' => lastra.persistent_id, 'prop' => 'size_x', 'at' => 0 }] }
eq('controllo: il cubo che legge la lastra che legge il cubo', chk.call(cubo, giro)['errs'], { '0_1' => ['fx.e_cycle', ''] })
eq('…l\'avanzamento invece non fa giro (dipende dal tempo)', chk.call(sfera, D.read_data(sfera))['errs'], {})
anim(cubo, giro['tracks'])
D.cmd_seek(1.0)
eq('giro chiuso salvato lo stesso: niente blocco, valori finiti', [xlen(lastra), xlen(cubo)].all?(&:finite?), true)
D.cmd_stop

# ── Sessione che parte dentro un'operazione aperta di uno script ──
# Lo script ha appena cancellato un contenitore: gli animati dentro sono
# ancora validi ma fuori dal modello, e l'elenco in memoria li ha ancora (si
# rifà al commit). In SketchUp la prima operazione nostra chiude quella dello
# script e loro spariscono a metà elenco: «reference to deleted Group» e una
# sessione lasciata a metà (registro del 18/11).
gm = Sketchup::Model.new
$model = gm
D.model_changed(gm, true)
box = gm.add_group([0, 0, 0], [4.m, 4.m, 1.m])
dentro = gm.add_group([0, 0, 0], [1.m, 1.m, 1.m])
dentro.parent = box.definition
fuori = gm.add_group([0, 0, 0], [1.m, 1.m, 1.m])
anim(dentro, [tr('move_x', 0, 1.m, 1.0)])
anim(fuori, [tr('move_y', 0, 1.m, 1.0)])
D::ModelObs.new.onTransactionCommit(gm)
eq('prima: tutti e due animati', D.animated_instances(gm).map(&:first), [dentro, fuori])
box.erase!                                                               # operazione dello script ancora aperta
s = D.session_start(gm)
eq('la sessione prende solo chi è ancora nel modello', s && s[:items].keys, [fuori])
D.session_end
D::ModelObs.new.onTransactionCommit(gm)
def fuori.transformation; raise TypeError, 'reference to deleted Group'; end
logged = []
D.singleton_class.alias_method(:log_error_prove, :log_error)
D.define_singleton_method(:log_error) { |w, e| logged << "#{w}: #{e.class}" }
begin
  eq('un oggetto che sparisce a metà: niente sessione a metà', [D.session_start(gm), D.session], [nil, nil])
ensure
  D.singleton_class.alias_method(:log_error, :log_error_prove)
end
eq('…e l\'errore va nel registro', logged, ['session_start: TypeError'])

# ── Copie di oggetti collegati ──
# Il cubo cresce; la lastra legge il cubo e la propria posizione; la sfera
# parte dopo il cubo. Copiati insieme, i collegamenti passano alle copie.
cm = Sketchup::Model.new
$model = cm
D.model_changed(cm, true)
at = ->(x) { Geom::Transformation.translation(Geom::Vector3d.new(x, 0, 0)) }
copia = lambda do |e, dx, stamp: true|
  c = cm.add_group([0, 0, 0], [1.m, 1.m, 1.m], at.(e.transformation.to_a[12] + dx))
  c.set_attribute(D::DICT, D::DATA_KEY, e.get_attribute(D::DICT, D::DATA_KEY))
  c.set_attribute(D::DICT, D::SELF_KEY, e.get_attribute(D::DICT, D::SELF_KEY)) if stamp
  c
end
par = ->(e, prop) { { 'n' => 'K', 'pid' => e.persistent_id, 'prop' => prop, 'at' => 0 } }
cub = cm.add_group([0, 0, 0], [1.m, 1.m, 1.m], at.(0))
las = cm.add_group([0, 0, 0], [1.m, 1.m, 1.m], at.(2.m))
sfe = cm.add_group([0, 0, 0], [1.m, 1.m, 1.m], at.(4.m))
anim(cub, [tr('size_z', 1.m, 2.m, 2.0)])
anim(las, [tr('move_y', 0, 1.m, 2.0), fxtr('size_x', 1.m, 2.0, 'K + J', [par.(cub, 'size_z'), par.(las, 'move_y').merge('n' => 'J')])])
anim(sfe, [tr('move_z', 0, 1.m, 1.0)], start: { 'mode' => 'after', 'after' => cub.persistent_id, 'wait' => 0.0, 'act' => 'play' })
D::ModelObs.new.onTransactionCommit(cm)
D.copies_known(cm)
legge = ->(e) { D.read_data(e)['tracks'][1]['keys'][1]['fx']['params'].map { |q| q['pid'] } }
dopo = ->(e) { D.read_data(e)['start']['after'] }
adotta = -> { D::ModelObs.new.onTransactionCommit(cm); D.copies_adopt(cm) }

cub2 = copia.(cub, 10.m); las2 = copia.(las, 10.m)
adotta.()
eq('copiati insieme: la lastra copiata legge il cubo copiato e sé stessa', legge.(las2), [cub2.persistent_id, las2.persistent_id])
eq('…l\'originale non cambia', legge.(las), [cub.persistent_id, las.persistent_id])
eq('…e la copia ha il suo segno', las2.get_attribute(D::DICT, D::SELF_KEY), las2.persistent_id.to_s)
eq('…in un\'operazione accodata alla copia', cm.ops.last, [D.t('op.anim'), true])

las3 = copia.(las, 20.m)
adotta.()
eq('copiata da sola: legge ancora il cubo di prima, e sé stessa', legge.(las3), [cub.persistent_id, las3.persistent_id])

# una serie in una sola operazione: ogni lastra con il cubo spostato come lei
cub4 = copia.(cub, 30.m); las5 = copia.(las, 40.m); las4 = copia.(las, 30.m); cub5 = copia.(cub, 40.m)
adotta.()
eq('serie: ognuna con il cubo della sua copia', [legge.(las4)[0], legge.(las5)[0]], [cub4.persistent_id, cub5.persistent_id])

cub6 = copia.(cub, 50.m); sfe6 = copia.(sfe, 50.m)
adotta.()
eq('catena copiata insieme: la sfera copiata parte dopo il cubo copiato', dopo.(sfe6), cub6.persistent_id)
eq('…e la sfera di prima dopo il cubo di prima', dopo.(sfe), cub.persistent_id)

# dati scritti prima del segno: si riconosce l'originale dai dati identici
[cub, las].each { |e| e.attribute_dictionary(D::DICT).delete(D::SELF_KEY) }
D.copies_known(cm)
cub7 = copia.(cub, 60.m, stamp: false); las7 = copia.(las, 60.m, stamp: false)
adotta.()
eq('dati senza segno: la copia legge comunque la copia', legge.(las7), [cub7.persistent_id, las7.persistent_id])

# ── Grafico della formula e «Converti in curva» ──
bm = Sketchup::Model.new
$model = bm
D.model_changed(bm, true)
pen = bm.add_group([0, 0, 0], [1.m, 1.m, 1.m])
anim(pen, [fxtr('rot_y', 0, 2.0, '30 * sin(180 * t)', [])])
D::ModelObs.new.onTransactionCommit(bm)
pdata = D.read_data(pen)
cuoci = ->(data, i = 0, j = 1) { D.fx_bake(JSON.generate('pid' => pen.persistent_id, 'data' => data, 'i' => i, 'j' => j)) }
r = cuoci.(pdata)
eq('pendolo: tre stati, uno a ogni inversione', r['keys'].map { |k| [k['v'].round(3), k['dur'].round(3)] }, [[30.0, 0.5], [-30.0, 1.0], [0.0, 0.5]])
baked = JSON.parse(JSON.generate(pdata))
baked['tracks'][0]['keys'][1, 1] = r['keys']
ft = D.prepare_tracks(pdata).first
bt = D.prepare_tracks(D.sanitize_data(baked)).first
err = (0..200).map { |s| (D.track_value(ft, s * 0.01) - D.track_value(bt, s * 0.01)).abs }.max
eq('…e le curve rifanno la formula (scarto massimo sotto 0.2°)', err < 0.2, true)
puts "    scarto massimo: #{err.round(4)}°"
chk = D.fx_check(JSON.generate('pid' => pen.persistent_id, 'data' => pdata, 'seq' => 3))
eq('grafico per il pannello: 49 valori, da 0 a 0 passando per 30', [chk['plots']['0_1'].size, chk['plots']['0_1'][0], chk['plots']['0_1'][12].round(3)], [49, 0.0, 30.0])
salto = JSON.parse(JSON.generate(pdata))
salto['tracks'][0]['keys'][1]['fx']['expr'] = '10 + 5 * u'
r = cuoci.(salto)
eq('formula che non parte dal valore di prima: un salto di durata 0, poi la rampa', r['keys'].map { |k| [k['v'].round(3), k['dur'].round(3), k['preset']] },
   [[10.0, 0.0, 'linear'], [15.0, 2.0, 'linear']])
mossa = JSON.parse(JSON.generate(pdata))
mossa['tracks'][0]['keys'][1]['fx']['expr'] = '10 * sin(3600 * t)'
eq('troppo mossa per gli stati che ci stanno', cuoci.(mossa)['err'], ['fx.e_bake_many', D::MAX_KEYS.to_s])
rotta = JSON.parse(JSON.generate(pdata))
rotta['tracks'][0]['keys'][1]['fx']['expr'] = '30 * '
eq('formula sbagliata: niente conversione', cuoci.(rotta)['err'], ['fx.e_bake', ''])

$model = cm
D.model_changed(cm)
cm.selection.replace([las2])
eq('linee: la lastra copiata selezionata, dal cubo copiato (il parametro su sé stessa non conta)',
   D.links_pairs(cm).map { |a, b, ns| [a, b, ns] }, [[cub2, las2, ['K']]])
cm.selection.replace([cub])
eq('…selezionato il cubo: tutte le lastre che lo leggono', D.links_pairs(cm).map { |a, b, _| [a, b] }.sort_by { |_, b| b.persistent_id },
   [[cub, las], [cub, las3]])
cm.selection.clear
n_ops = cm.ops.size
D.copies_known(cm)
adotta.()
eq('niente di nuovo: nessuna operazione', cm.ops.size, n_ops)

puts $bad.zero? ? 'TUTTO OK' : "#{$bad} errori"
exit($bad.zero? ? 0 : 1)
