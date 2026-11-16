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
tool.activate
tool.onMouseMove(0, 20, 20, view)
eq('sopra un oggetto che non si aziona: niente nome, cursore normale', [view.tooltip, tool.onSetCursor], ['', false])
tool.onMouseMove(0, 10, 10, view)
eq('sopra la leva (dentro un gruppo): il suo nome', view.tooltip, 'Leva')
eq('…cursore di Aziona, punta in alto a sinistra', [tool.onSetCursor, $cursor, $cursors.last[1, 2],
   File.basename($cursors.last[0]), File.exist?($cursors.last[0])], [true, 77, [1, 1], 'use_cursor.png', true])
eq('…e niente parte finché non si clicca', D.session.nil?, true)
tool.draw(view)
mode, pts = view.drawn.last
xs = pts.map { |p| (p.x / 1.m).round(3) }.uniq.sort
eq('riquadro: 12 spigoli, nel mondo (x della leva da 1 a 1.1 m)', [mode, pts.size, xs], [GL_LINES, 24, [1.0, 1.1]])
eq('…e SketchUp lo sa (getExtents)', (tool.getExtents.max.z / 1.m).round(3), 0.5)
lever.erase!
view.drawn.clear
tool.draw(view)
eq('leva cancellata sotto il mouse: niente riquadro, cursore normale', [view.drawn.size, tool.onSetCursor], [0, false])
tool.onMouseMove(0, 30, 30, view)
eq('nel vuoto: niente nome', view.tooltip, '')
tool.deactivate(view)

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

puts $bad.zero? ? 'TUTTO OK' : "#{$bad} errori"
exit($bad.zero? ? 0 : 1)
