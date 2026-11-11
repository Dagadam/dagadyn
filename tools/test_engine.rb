# Prova il calcolo dei valori delle tracce nel tempo (dagadyn/lib/player.rb)
# fuori da SketchUp: ritardi, curve, più stati, ripetizioni, colori, limiti.
#
#   ruby tools/test_engine.rb
require 'json'

ROOT = File.expand_path('..', __dir__)
module DagaDyn
  module Dyn
    CFG = { 'color_mix' => 'oklab', 'new_pivot' => 'base' }
    def self.cf(k); CFG[k]; end
    def self.log_error(w, e); raise e; end
    def self.t(k); k; end
  end
end
%w[config curves color tracks player].each { |f| require File.join(ROOT, 'dagadyn', 'lib', f) }
D = DagaDyn::Dyn

$bad = 0
def eq(what, got, want, tol = 1e-6)
  ok = want.is_a?(String) ? got == want : (got - want).abs <= tol
  puts "#{ok ? 'ok ' : 'NO '} #{what}: #{got.is_a?(Float) ? got.round(6) : got} (atteso #{want})"
  $bad += 1 unless ok
end

M = 39.37007874   # pollici in un metro
def track(prop, keys, delay: 0, loop: 'none')
  t = D.sanitize_track('prop' => prop, 'delay' => delay, 'loop' => loop, 'keys' => keys)
  D.prepare_tracks('tracks' => [t]).first
end
def lin; { 'preset' => 'linear' }; end

# L'esempio: altezza da 3 a 4 m in 1 secondo
h = track('size_z', [{ 'v' => 3 * M }, { 'v' => 4 * M, 'dur' => 1.0 }.merge(lin)])
[0.0, 0.1, 0.2, 0.5, 1.0, 2.0].each { |s| eq("altezza lineare a #{s} s (m)", D.track_value(h, s) / M, [3 + s, 4].min) }

# Accelera e decelera: a metà tempo metà strada, a un quarto ancora poco
e = track('size_z', [{ 'v' => 3 * M }, { 'v' => 4 * M, 'dur' => 1.0, 'preset' => 'ease_in_out' }])
eq('ease_in_out a 0.5 s', D.track_value(e, 0.5) / M, 3.5)
eq('ease_in_out a 0.25 s', D.track_value(e, 0.25) / M, 3.0625)

# Ritardo: fermo allo stato iniziale finché non parte
d = track('pos_x', [{ 'v' => 0 }, { 'v' => 100, 'dur' => 2.0 }.merge(lin)], delay: 1.0)
eq('ritardo: a 0.5 s', D.track_value(d, 0.5), 0)
eq('ritardo: a 2 s', D.track_value(d, 2.0), 50)

# Tre stati: 0 → 10 in 1 s, poi → 0 in 2 s
s3 = track('rot_z', [{ 'v' => 0 }, { 'v' => 10, 'dur' => 1.0 }.merge(lin), { 'v' => 0, 'dur' => 2.0 }.merge(lin)])
eq('tre stati a 0.5 s', D.track_value(s3, 0.5), 5)
eq('tre stati a 2 s', D.track_value(s3, 2.0), 5)
eq('tre stati a 5 s', D.track_value(s3, 5.0), 0)

# Ripetizioni
l = track('pos_y', [{ 'v' => 0 }, { 'v' => 10, 'dur' => 1.0 }.merge(lin)], loop: 'loop')
eq('ciclo a 1.25 s', D.track_value(l, 1.25), 2.5)
p = track('pos_y', [{ 'v' => 0 }, { 'v' => 10, 'dur' => 1.0 }.merge(lin)], loop: 'pingpong')
eq('avanti e indietro a 1.25 s', D.track_value(p, 1.25), 7.5)
eq('avanti e indietro a 2.5 s', D.track_value(p, 2.5), 5)

# Durata zero: salto immediato
z = track('pos_x', [{ 'v' => 0 }, { 'v' => 7, 'dur' => 0 }])
eq('durata zero', D.track_value(z, 0.001), 7)

# Elastico: supera la meta (la curva può uscire da 0–1)
el = track('pos_x', [{ 'v' => 0 }, { 'v' => 100, 'dur' => 1.0, 'preset' => 'elastic' }])
over = (0..100).map { |i| D.track_value(el, i / 100.0) }.max
eq('elastico supera la meta', over > 100 ? 1 : 0, 1)

# Dimensioni mai nulle e opacità dentro 0–1, anche con la curva oltre
sz = track('size_x', [{ 'v' => 1 }, { 'v' => 0.0001, 'dur' => 1.0, 'preset' => 'back' }])
eq('dimensione minima', (0..100).map { |i| D.track_value(sz, i / 100.0) }.min >= 0.001 ? 1 : 0, 1)
op = track('opacity', [{ 'v' => 0 }, { 'v' => 1, 'dur' => 1.0, 'preset' => 'elastic' }])
eq('opacità al massimo 1', (0..100).map { |i| D.track_value(op, i / 100.0) }.max, 1.0)

# Colori: estremi esatti, a metà una tinta intermedia
c = track('color', [{ 'v' => '#ff0000' }, { 'v' => '#0000ff', 'dur' => 1.0 }.merge(lin)])
eq('colore all\'inizio', D.track_value(c, 0), '#ff0000')
eq('colore alla fine', D.track_value(c, 1), '#0000ff')
mid = D.hex_rgb(D.track_value(c, 0.5))
eq('colore a metà: né rosso né blu puri', mid[0].between?(60, 230) && mid[2].between?(60, 230) ? 1 : 0, 1)
D::CFG['color_mix'] = 'rgb'
eq('colore a metà in RGB', D.track_value(c, 0.5), '#800080')

# Dati sporchi: proprietà ignote, valori non numerici, ripetizione sconosciuta
dd = D.sanitize_data('pivot' => 'boh', 'tracks' => [{ 'prop' => 'nope' }, { 'prop' => 'scale', 'loop' => 'x',
                       'keys' => [{ 'v' => 'a' }, { 'v' => -5, 'dur' => -1, 'curve' => 'x' }] }])
eq('pivot sconosciuto → base', dd['pivot'], 'base')
eq('traccia ignota scartata', dd['tracks'].size, 1)
eq('scala non numerica → 1', dd['tracks'][0]['keys'][0]['v'], 1.0)
eq('scala negativa → minimo', dd['tracks'][0]['keys'][1]['v'], 0.001)
eq('durata negativa → 0', dd['tracks'][0]['keys'][1]['dur'], 0.0)
eq('ripetizione sconosciuta → none', dd['tracks'][0]['loop'], 'none')
eq('lunghezza della traccia', D.track_length(D.sanitize_track('prop' => 'pos_x', 'delay' => 1, 'loop' => 'pingpong',
                      'keys' => [{ 'v' => 0 }, { 'v' => 1, 'dur' => 2 }])), 5.0)

# ── Proprietà a scatti: visibile e tag cambiano quando la transizione finisce
vis = track('visible', [{ 'v' => 1 }, { 'v' => 0, 'dur' => 1.0 }.merge(lin)])
eq('visibile a 0.99 s', D.track_value(vis, 0.99), 1.0)
eq('nascosto a 1 s', D.track_value(vis, 1.0), 0.0)
tg = track('tag', [{ 'v' => 'Muri' }, { 'v' => 'Porte', 'dur' => 2.0 }.merge(lin)])
eq('tag a 1 s', D.track_value(tg, 1.0), 'Muri')
eq('tag a 3 s', D.track_value(tg, 3.0), 'Porte')
eq('visibile da un vero', D.sanitize_value('visible', true), 1.0)

# ── Partenze: dopo un altro oggetto, azionati, catene circolari
Ent = Struct.new(:persistent_id)
def obj(pid, mode = 'time', after: 0, wait: 0, dur: 2.0, loop: 'none', act: 'play')
  d = D.sanitize_data('start' => { 'mode' => mode, 'after' => after, 'wait' => wait, 'act' => act },
                      'tracks' => [{ 'prop' => 'move_z', 'loop' => loop,
                                     'keys' => [{ 'v' => 0 }, { 'v' => 10, 'dur' => dur, 'preset' => 'linear' }] }])
  [Ent.new(pid), d]
end
a = obj(1); b = obj(2, 'after', after: 1, wait: 0.5); c = obj(3, 'after', after: 2, dur: 1.0)
tr_ = obj(4, 'trigger'); ch = obj(5, 'after', after: 4)
x1 = obj(6, 'after', after: 7); x2 = obj(7, 'after', after: 6)
st = D.chain_starts([a, b, c, tr_, ch, x1, x2])
eq('B parte dopo A + attesa', st[2], 2.5)
eq('C parte dopo B', st[3], 4.5)
eq('azionato: fuori dalla timeline', st[4].nil? ? 1 : 0, 1)
eq('in catena dietro un azionato: fuori', st[5].nil? ? 1 : 0, 1)
eq('catena circolare: fuori', st[6].nil? && st[7].nil? ? 1 : 0, 1)
eq('timeline lunga fino alla fine di C', D.timeline_length([a, b, c, tr_, ch]), 5.5)
eq('dopo un oggetto non animato: solo l\'attesa', D.chain_starts([obj(8, 'after', after: 99, wait: 1.5)])[8], 1.5)

# Sessione finta (senza SketchUp): tempo locale e azionati
def item(pair)
  e, d = pair
  { data: d, tracks: D.prepare_tracks(d), len: D.data_length(d), loops: D.data_loops?(d), trig: nil }
end
S = { items: {}, by_pid: {}, total: 0.0, t0: 0.0, ext_t0: 0.0 }
[a, b, tr_, ch].each { |pr| it = item(pr); S[:items][pr[0]] = it; S[:by_pid][pr[0].persistent_id] = it }
S[:total] = 4.5
S[:items].each { |e, it| it[:static] = D.chain_starts([a, b, tr_, ch])[e.persistent_id] }
ib = S[:by_pid][2]; it4 = S[:by_pid][4]; i5 = S[:by_pid][5]
eq('B a t=3: tempo locale 0.5', D.item_local(S, ib, 3.0), 0.5)
eq('B prima di partire: stato iniziale', D.track_value(ib[:tracks][0], D.item_local(S, ib, 1.0)), 0)
eq('azionato fermo prima del clic', D.item_local(S, it4, 10.0), 0.0)
D.trigger_item(S, it4, 10.0)
eq('azionato a 1 s dal clic', D.track_value(it4[:tracks][0], D.item_local(S, it4, 11.0)), 5)
eq('in catena dietro l\'azionato: parte quando finisce', D.item_local(S, i5, 12.5), 0.5)
eq('azionato in moto: la sessione va avanti', D.busy_at?(S, 11.0) ? 1 : 0, 1)
eq('tutto finito: si può fermare', D.busy_at?(S, 20.0) ? 1 : 0, 0)
tg2 = item(obj(9, 'trigger', act: 'toggle'))
S[:items][Ent.new(9)] = tg2
D.trigger_item(S, tg2, 0.0)
eq('avanti/indietro: avanti a 1.5 s', D.item_local(S, tg2, 1.5), 1.5)
D.trigger_item(S, tg2, 1.5)
eq('…secondo clic a metà: torna indietro da lì', D.item_local(S, tg2, 2.0), 1.0)
eq('…fino all\'inizio', D.item_local(S, tg2, 9.0), 0.0)
D.trigger_item(S, tg2, 9.0)
eq('…terzo clic: di nuovo avanti', D.item_local(S, tg2, 10.0), 1.0)
D.shift_time(S, 5.0)
eq('ripetizione della timeline: l\'azionato non salta', D.item_local(S, tg2, 5.0), 1.0)

dd2 = D.sanitize_data('axes' => 'world', 'faces' => true, 'start' => { 'mode' => 'boh', 'wait' => -3 })
eq('assi del mondo', dd2['axes'], 'world')
eq('partenza sconosciuta → timeline', dd2['start']['mode'], 'time')
eq('attesa negativa → 0', dd2['start']['wait'], 0.0)

puts $bad.zero? ? 'TUTTO OK' : "#{$bad} errori"
exit($bad.zero? ? 0 : 1)
