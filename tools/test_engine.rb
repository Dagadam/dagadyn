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
%w[config curves formula color tracks player].each { |f| require File.join(ROOT, 'dagadyn', 'lib', f) }
D = DagaDyn::Dyn

$bad = 0
def eq(what, got, want, tol = 1e-6)
  ok = want.is_a?(Numeric) && got.is_a?(Numeric) ? (got - want).abs <= tol : got == want
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
S = { items: {}, by_pid: {}, total: 0.0, c0: 0.0, ext_c0: 0.0 }
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

# ── Catene lunghe: nessun limite di lunghezza, nessuna dipendenza dall'ordine
# (prima: dal 18° oggetto in poi non partiva più, e in ordine inverso la
# catena intera risultava fuori dalla timeline)
long = (1..40).map { |i| i == 1 ? obj(1001, dur: 1.0) : obj(1000 + i, 'after', after: 999 + i, dur: 1.0) }
eq('catena di 40: il 40° parte a 39 s', D.chain_starts(long)[1040], 39.0)
eq('…anche con gli oggetti in ordine inverso', D.chain_starts(long.reverse)[1040], 39.0)
eq('…e mescolati', D.chain_starts(long.shuffle(random: Random.new(7)))[1020], 19.0)
SL = { items: {}, by_pid: {} }
long.each { |pr| it = item(pr); SL[:items][pr[0]] = it; SL[:by_pid][pr[0].persistent_id] = it }
eq('in sessione (senza partenze calcolate): il 18° parte', D.item_start(SL, SL[:by_pid][1018]), 17.0)
eq('…il 40° pure', D.item_start(SL, SL[:by_pid][1040]), 39.0)
eq('…e ha il suo tempo locale', D.item_local(SL, SL[:by_pid][1040], 39.5), 0.5)
SL[:items].each { |e, it| it[:static] = D.chain_starts(long)[e.persistent_id] }
eq('con le partenze calcolate: lo stesso', D.item_start(SL, SL[:by_pid][1040]), 39.0)

# Catena di 25 dietro un azionato: parte quando l'azionato finisce
behind = [obj(2001, 'trigger', dur: 2.0)] + (2..25).map { |i| obj(2000 + i, 'after', after: 1999 + i, dur: 2.0) }
SB = { items: {}, by_pid: {} }
behind.each { |pr| it = item(pr); it[:static] = nil; SB[:items][pr[0]] = it; SB[:by_pid][pr[0].persistent_id] = it }
eq('dietro l\'azionato fermo: non parte', D.item_start(SB, SB[:by_pid][2025]).nil? ? 1 : 0, 1)
D.trigger_item(SB, SB[:by_pid][2001], 10.0)
eq('azionato a 10 s: il 25° parte a 10 + 2 + 23 × 2', D.item_start(SB, SB[:by_pid][2025]), 58.0)
cyc = [obj(3001, 'after', after: 3003), obj(3002, 'after', after: 3001), obj(3003, 'after', after: 3002)]
SC = { items: {}, by_pid: {} }
cyc.each { |pr| it = item(pr); SC[:items][pr[0]] = it; SC[:by_pid][pr[0].persistent_id] = it }
eq('giro chiuso in sessione: non parte (e non si blocca)', D.item_start(SC, SC[:by_pid][3002]).nil? ? 1 : 0, 1)

# Anteprima ferma (cmd_preview su chi non ha un istante sulla timeline)
i25 = SB[:by_pid][2024]
i25[:pin] = 1.5
eq('anteprima ferma: tempo locale fissato', D.item_local(SB, i25, 999.0), 1.5)
D.clear_pins(SB)
eq('…finché la timeline non riparte', D.item_local(SB, i25, 58.0), 2.0)

# ── Leva e ponte levatoio: in catena dietro un avanti/indietro si segue la direzione
lev = obj(4001, 'trigger', act: 'toggle', dur: 0.5)
brg = obj(4002, 'after', after: 4001, wait: 0.5, dur: 4.0)
gat = obj(4003, 'after', after: 4002, dur: 1.0)            # un terzo in catena dietro il ponte
SP = { items: {}, by_pid: {}, c0: 0.0, ext_c0: 0.0 }
[lev, brg, gat].each { |pr| it = item(pr); it[:static] = nil; SP[:items][pr[0]] = it; SP[:by_pid][pr[0].persistent_id] = it }
il = SP[:by_pid][4001]; ib2 = SP[:by_pid][4002]; ig = SP[:by_pid][4003]
eq('ponte fermo prima della leva', D.item_local(SP, ib2, 3.0) <= 0 ? 1 : 0, 1)
D.trigger_item(SP, il, 10.0)                        # leva giù: 0.5 s, poi 0.5 s di attesa, poi il ponte
eq('ponte: aspetta la leva e l\'attesa', D.item_local(SP, ib2, 10.9) <= 0 ? 1 : 0, 1)
eq('ponte a metà discesa', D.item_local(SP, ib2, 13.0), 2.0)
eq('…si sta muovendo', D.busy_at?(SP, 13.0) ? 1 : 0, 1)
eq('il terzo parte quando il ponte è giù', D.item_local(SP, ig, 15.5), 0.5)
# Ritorno a corsa finita (prima il ponte risaliva insieme alla leva)
D.trigger_item(SP, il, 20.0)                        # leva su col ponte giù
eq('leva su: il ponte resta giù mentre la leva torna', D.item_local(SP, ib2, 20.4), 4.0)
eq('…e durante l\'attesa', D.item_local(SP, ib2, 20.9), 4.0)
eq('…poi risale', D.item_local(SP, ib2, 23.0), 2.0)
eq('…si sta muovendo', D.busy_at?(SP, 23.0) ? 1 : 0, 1)
eq('il terzo aspetta che il ponte sia su', D.item_local(SP, ig, 24.9), 1.0)
eq('…poi torna indietro anche lui', D.item_local(SP, ig, 25.5), 0.5)
eq('ponte in cima', D.item_local(SP, ib2, 30.0), 0.0)
eq('…tutto fermo', D.busy_at?(SP, 30.0) ? 1 : 0, 0)
# Ripensamenti a metà corsa
D.trigger_item(SP, il, 30.0)                        # giù di nuovo: ponte dal 31 al 35
eq('ponte a metà discesa (di nuovo)', D.item_local(SP, ib2, 33.0), 2.0)
D.trigger_item(SP, il, 33.0)                        # leva su a metà discesa
eq('leva su a metà discesa: il ponte si ferma dov\'è', D.item_local(SP, ib2, 33.9), 2.0)
eq('…risale quando la leva ha finito, dopo l\'attesa', D.item_local(SP, ib2, 35.0), 1.0)
D.trigger_item(SP, il, 35.0)                        # di nuovo giù a metà salita
eq('di nuovo giù a metà salita: fermo lì', D.item_local(SP, ib2, 35.9), 1.0)
eq('…poi riprende la discesa da lì', D.item_local(SP, ib2, 37.0), 2.0)
eq('…e si ferma in fondo', D.item_local(SP, ib2, 50.0), 4.0)
D.shift_time(SP, 10.0)
eq('ripetizione della timeline: il ponte non salta', D.item_local(SP, ib2, 40.0), 4.0)

dd2 = D.sanitize_data('axes' => 'world', 'faces' => true, 'start' => { 'mode' => 'boh', 'wait' => -3 })
eq('assi del mondo', dd2['axes'], 'world')
eq('partenza sconosciuta → timeline', dd2['start']['mode'], 'time')
eq('attesa negativa → 0', dd2['start']['wait'], 0.0)

# ── Transizioni a formula (lib/formula.rb)
def fx_val(src, vars = {}, names = vars.keys)
  D.fx_run(D.fx_compile(src, names), vars)
end
def fx_err(src, names = [])
  D.fx_compile(src, names)
  'nessun errore'
rescue D::FxError => err
  "#{err.code} #{err.arg}".strip
end
eq('formula: precedenze', fx_val('1 + 2*3 - 4/2'), 5)
eq('formula: meno davanti alla potenza', fx_val('-2^2'), -4)
eq('formula: potenze da destra', fx_val('2^3^2'), 512)
eq('formula: esponente negativo', fx_val('2^-1'), 0.5)
eq('formula: seno in gradi', fx_val('sin(90)'), 1)
eq('formula: max con tre argomenti', fx_val('max(1, 5, 3)'), 5)
eq('formula: punto e virgola fra gli argomenti', fx_val('clamp(5; 0; 2)'), 2)
eq('formula: × e − scritti a mano', fx_val('2 × 3 − 1'), 5)
eq('formula: variabili', fx_val('v0 + (2 - v0) * u', { 'v0' => 1.0, 'u' => 0.25 }), 1.25)
eq('formula: pi', fx_val('cos(180) * pi'), -Math::PI)
eq('formula: decimali e notazione 1e3', fx_val('.5 + 1.5e1'), 15.5)
eq('formula: divisione per zero → nil', fx_val('1/0').nil? ? 1 : 0, 1)
eq('formula: radice di un negativo → nil', fx_val('sqrt(-1)').nil? ? 1 : 0, 1)
eq('formula: potenza con risultato complesso → nil', fx_val('(-8)^(1/3)').nil? ? 1 : 0, 1)
eq('errore: vuota', fx_err('  '), 'empty')
eq('errore: finisce a metà', fx_err('2 +'), 'end')
eq('errore: parentesi non chiusa', fx_err('(1 + 2'), 'end')
eq('errore: 2u senza segno', fx_err('2u', ['u']), 'syntax u')
eq('errore: carattere sconosciuto', fx_err('2 $ 3'), 'syntax $')
eq('errore: funzione sconosciuta', fx_err('foo(1)'), 'name foo')
eq('errore: nome sconosciuto', fx_err('K * 2'), 'name K')
eq('errore: argomenti sbagliati', fx_err('sqrt(1, 2)'), 'args sqrt')
eq('niente eval: codice Ruby è un errore', fx_err('`calc`'), 'syntax `')
eq('niente eval: system(…) è una funzione sconosciuta', fx_err('system(1)'), 'name system')

def fxk(v, dur, expr, params = [])
  { 'v' => v, 'dur' => dur, 'preset' => 'linear', 'fx' => { 'on' => true, 'expr' => expr, 'params' => params } }
end
# Altezza da 1 m: la formula la porta a 3 m in 2 s (il valore di arrivo scritto, 9 m, non conta)
f1 = track('size_z', [{ 'v' => 1 * M }, fxk(9 * M, 2.0, 'v0 + (3 - v0) * u')])
eq('formula a metà (m)', D.track_value(f1, 1.0) / M, 2)
eq('formula finita: resta dove l\'ha portata (m)', D.track_value(f1, 5.0) / M, 3)
eq('formula con t e d', D.track_value(track('rot_z', [{ 'v' => 0 }, fxk(0, 4.0, '90 * t / d')]), 1.0), 22.5)
# La transizione dopo riparte da dove l'ha lasciata la formula
f2 = track('size_z', [{ 'v' => 1 * M }, fxk(9 * M, 2.0, 'v0 + (3 - v0) * u'), { 'v' => 0.5 * M, 'dur' => 1.0 }.merge(lin)])
eq('dopo la formula: parte da 3 m', D.track_value(f2, 2.5) / M, 1.75)
eq('…e arriva al suo stato', D.track_value(f2, 4.0) / M, 0.5)
f3 = track('pos_x', [{ 'v' => 0 }, fxk(0, 1.0, '2 * u'), fxk(0, 1.0, 'v0 + u')])
eq('due formule di fila: la seconda parte dalla prima', D.track_value(f3, 1.5) / M, 2.5)
eq('in ciclo: ogni giro riparte dallo stato iniziale', D.track_value(track('pos_x', [{ 'v' => 0 }, fxk(0, 1.0, '2 * u')], loop: 'loop'), 1.25) / M, 0.5)
eq('opacità in %: 50 → 0.5', D.track_value(track('opacity', [{ 'v' => 1 }, fxk(1, 1.0, '50')]), 0.5), 0.5)
eq('formula non valida: resta al valore di partenza', D.track_value(track('size_z', [{ 'v' => 1 * M }, fxk(1, 1.0, '2 +')]), 0.5) / M, 1)
eq('opacità mai oltre il 100%', D.track_value(track('opacity', [{ 'v' => 1 }, fxk(1, 1.0, '300')]), 0.5), 1.0)
dfx = D.sanitize_data('tracks' => [{ 'prop' => 'color', 'keys' => [{ 'v' => '#ff0000' }, { 'v' => '#00ff00', 'fx' => { 'on' => true, 'expr' => '1' } }] },
                                   { 'prop' => 'move_x', 'keys' => [{ 'v' => 0 }, { 'v' => 1, 'fx' => { 'on' => false, 'expr' => 'x' * 900,
                                     'params' => [{ 'n' => 'K!', 'pid' => 5, 'prop' => 'color', 'at' => 99 }] } }] }])
eq('colore: niente formula', dfx['tracks'][0]['keys'][1].key?('fx') ? 1 : 0, 0)
eq('formula spenta: resta scritta (per riaccenderla)', dfx['tracks'][1]['keys'][1]['fx']['on'] ? 1 : 0, 0)
eq('formula troppo lunga: tagliata', dfx['tracks'][1]['keys'][1]['fx']['expr'].size, D::FX_MAX_LEN)
eq('parametro: nome ripulito', dfx['tracks'][1]['keys'][1]['fx']['params'][0]['n'], 'K')
eq('parametro: traccia non numerica tolta', dfx['tracks'][1]['keys'][1]['fx']['params'][0]['prop'], '')
eq('parametro: transizione oltre il massimo', dfx['tracks'][1]['keys'][1]['fx']['params'][0]['at'], D::MAX_KEYS)

# Parametri: il Cubo (pid 1) cresce da 1 a 2 m in 2 s; la larghezza del
# Solido (pid 2) è 0.5 + K/2 con K = altezza del Cubo, per 1 s
def fxp(n, pid, prop, at = 0); { 'n' => n, 'pid' => pid, 'prop' => prop, 'at' => at }; end
def fxobj(pid, tracks, mode: 'time', after: 0)
  [Ent.new(pid), D.sanitize_data('start' => { 'mode' => mode, 'after' => after }, 'tracks' => tracks)]
end
cubo  = fxobj(1, [{ 'prop' => 'size_z', 'keys' => [{ 'v' => 1 * M }, { 'v' => 2 * M, 'dur' => 2.0 }.merge(lin)] }])
solido = fxobj(2, [{ 'prop' => 'size_x', 'keys' => [{ 'v' => 1 * M }, fxk(0, 1.0, '0.5 + K/2', [fxp('K', 1, 'size_z')])] }])
dopo  = fxobj(3, [{ 'prop' => 'size_y', 'keys' => [{ 'v' => 1 * M }, fxk(0, 3.0, 'K * 10', [fxp('K', 1, 'size_z', 1)])] }],
              mode: 'after', after: 1)
SF = { items: {}, by_pid: {}, c0: 0.0, ext_c0: 0.0, ufac: M }
[cubo, solido, dopo].each { |pr| it = item(pr); SF[:items][pr[0]] = it; SF[:by_pid][pr[0].persistent_id] = it }
SF[:items].each { |e, it| it[:static] = D.chain_starts([cubo, solido, dopo])[e.persistent_id] }
def fx_at(s, pid, t)
  it = s[:by_pid][pid]
  w = D.fx_world_session(s)
  local = D.item_local(s, it, t)
  D.track_value(it[:tracks][0], local, { w: w, off: t - local, f: w[:f] }) / M
end
eq('Solido a 0 s: 0.5 + 1/2', fx_at(SF, 2, 0.0), 1.0)
eq('Solido a 0.5 s: segue il Cubo (1.25 m)', fx_at(SF, 2, 0.5), 1.125)
eq('Solido a 1 s', fx_at(SF, 2, 1.0), 1.25)
eq('Solido dopo la sua transizione: fermo dov\'era a 1 s', fx_at(SF, 2, 1.8), 1.25)
eq('in catena dopo il Cubo (parte a 2 s): K = avanzamento della sua transizione, finita', fx_at(SF, 3, 2.5), 10)
eq('avanzamento a metà della transizione del Cubo', D.track_progress(SF[:by_pid][1][:tracks][0], 1.0, 1), 0.5)
eq('avanzamento prima del ritardo', D.track_progress(track('pos_x', [{ 'v' => 0 }, { 'v' => 1, 'dur' => 2.0 }], delay: 1.0), 0.5, 1), 0.0)
eq('avanzamento della seconda transizione', D.track_progress(s3, 2.0, 2), 0.5)
eq('avanzamento di una transizione che non c\'è: nil', D.track_progress(s3, 2.0, 3).nil? ? 1 : 0, 1)
# Collegamento circolare: niente giro infinito, si resta al valore di partenza
ca = fxobj(11, [{ 'prop' => 'size_z', 'keys' => [{ 'v' => 1 * M }, fxk(0, 1.0, 'K + 1', [fxp('K', 12, 'size_x')])] }])
cb = fxobj(12, [{ 'prop' => 'size_x', 'keys' => [{ 'v' => 2 * M }, fxk(0, 1.0, 'K + 1', [fxp('K', 11, 'size_z')])] }])
SCY = { items: {}, by_pid: {}, c0: 0.0, ext_c0: 0.0, ufac: M }
[ca, cb].each { |pr| it = item(pr); it[:static] = 0.0; SCY[:items][pr[0]] = it; SCY[:by_pid][pr[0].persistent_id] = it }
eq('giro chiuso: si calcola lo stesso, senza bloccarsi', fx_at(SCY, 11, 0.5).finite? ? 1 : 0, 1)
gr = { 11 => ca[1], 12 => cb[1] }
eq('pannello: giro chiuso segnalato', D.fx_problems(11, ca[1], gr), { '0_1' => ['fx.e_cycle', ''] })
gr2 = { 1 => cubo[1], 2 => solido[1] }
eq('pannello: tutto a posto', D.fx_problems(2, solido[1], gr2), {})
bad = ->(expr, params) { D.fx_problems(2, D.sanitize_data('tracks' => [{ 'prop' => 'size_x', 'keys' => [{ 'v' => 1 }, fxk(0, 1.0, expr, params)] }]), gr2)['0_1'] }
eq('pannello: errore di scrittura', bad.call('K +', [fxp('K', 1, 'size_z')]), ['fx.e_end', ''])
eq('pannello: nome sconosciuto', bad.call('Q', [fxp('K', 1, 'size_z')]), ['fx.e_name', 'Q'])
eq('pannello: parametro senza oggetto', bad.call('K', [fxp('K', 0, '')]), ['fx.e_src', 'K'])
eq('pannello: traccia che non c\'è più', bad.call('K', [fxp('K', 1, 'size_y')]), ['fx.e_gone', 'K'])
eq('pannello: transizione che non c\'è più', bad.call('K', [fxp('K', 1, 'size_z', 2)]), ['fx.e_gone', 'K'])
eq('pannello: nome riservato', bad.call('u', [fxp('u', 1, 'size_z')]), ['fx.e_pname', 'u'])
eq('pannello: nome ripetuto', bad.call('K', [fxp('K', 1, 'size_z'), fxp('K', 1, 'size_z', 1)]), ['fx.e_pname', 'K'])

puts $bad.zero? ? 'TUTTO OK' : "#{$bad} errori"
exit($bad.zero? ? 0 : 1)
