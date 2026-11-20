# Prova pezzi del pannello (dagadyn/panel.html) in Node, senza browser:
# le funzioni si estraggono dalla pagina e girano con un DOM finto.
#
#   ruby tools/test_panel.rb        (serve node nel PATH)
#
# - setSelection con l'editor delle curve aperto: se arriva un altro oggetto
#   (o le tracce cambiano sotto, Ctrl+Z) l'editor si chiude invece di
#   lavorare sulla traccia sbagliata; con lo stesso oggetto resta aperto.
require 'json'
require 'tmpdir'

ROOT = File.expand_path('..', __dir__)
html = File.read(File.join(ROOT, 'dagadyn', 'panel.html'), encoding: 'UTF-8')

# Una funzione di primo livello: dalla sua riga «function nome(» alla prima
# riga che è solo «}».
def js_fn(html, name)
  html[/^function #{name}\(.*?^\}\n/m] or abort "funzione #{name} non trovata in panel.html"
end
# Una funzione scritta tutta su una riga
def js_line(html, name)
  html[/^function #{name}\(.*$/] or abort "funzione #{name} non trovata in panel.html"
end

script = <<~JS
  let SEL = {kind:'none'}, DIRTY = false, CV = null, saved = 0, rendered = 0;
  const modal = {classList: {open: true, remove(c){ if(c === 'open') this.open = false; }}};
  const document = {getElementById: id => id === 'curvem' ? modal : null};
  function saveTracks(){ saved++; DIRTY = false; }
  function renderObj(){ rendered++; }
  function markSceneCur(){}
  #{js_fn(html, 'setSelection')}
  const obj = (pid, nTracks) => ({kind:'obj', pid, multi:0, others:[], data:{tracks:
    Array.from({length:nTracks}, () => ({keys:[{v:0},{v:1,dur:1},{v:2,dur:1}]}))}});
  const out = {};
  const open = (i, j) => { CV = {i, j}; modal.classList.open = true; };

  setSelection(obj(1, 3)); open(2, 2);
  setSelection(obj(1, 3));                     // stesso oggetto, stessi dati
  out.same = [CV !== null, modal.classList.open];

  const changed = obj(1, 3); changed.data.tracks[2].keys[2].v = 9;
  setSelection(changed);                       // stesso oggetto, dati nuovi (Ctrl+Z di un valore)
  out.sameNewData = [CV !== null, modal.classList.open];

  setSelection(obj(1, 1));                     // Ctrl+Z ha tolto la traccia aperta
  out.trackGone = [CV === null, modal.classList.open];

  setSelection(obj(1, 3)); open(1, 1); DIRTY = true;
  setSelection(obj(2, 3));                     // un altro oggetto, con modifiche in attesa
  out.other = [CV === null, modal.classList.open, saved];

  open(0, 1);
  setSelection({kind:'none'});                 // selezione vuota
  out.none = [CV === null, modal.classList.open];
  process.stdout.write(JSON.stringify(out));
JS
path = File.join(Dir.tmpdir, 'dagadyn_test_panel.js')
File.write(path, script)
res = JSON.parse(`node "#{path}"`)

$bad = 0
def eq(what, got, want)
  ok = got == want
  puts "#{ok ? 'ok ' : 'NO '} #{what}: #{got.inspect} (atteso #{want.inspect})"
  $bad += 1 unless ok
end
eq('curve aperte, stesso oggetto: restano aperte', res['same'], [true, true])
eq('stesso oggetto con dati nuovi: restano aperte', res['sameNewData'], [true, true])
eq('traccia tolta da un Ctrl+Z: si chiudono', res['trackGone'], [true, false])
eq('altro oggetto: si chiudono, dopo aver salvato le modifiche', res['other'], [true, false, 1])
eq('selezione vuota: si chiudono', res['none'], [true, false])

# setTransport: timeline vuota (solo oggetti azionati) → niente barra né
# timer, una riga che lo dice; etichetta di stato in alto senza il tasto ▶.
script2 = <<~JS
  const els = {};
  const document = {getElementById: id => els[id] || (els[id] = {id, hidden:false, disabled:false, textContent:'', innerHTML:'', title:'', className:''})};
  function T(k){ return k; }
  #{js_fn(html, 'fmtSec')}
  #{js_fn(html, 'setRunning')}
  let TP = {state:'stop', t:0, total:0, loops:false}, SCRUB = false;
  let SCENE = {objects:[], total:0, time:null}, CV = null, TW_DIRTY = false;
  #{js_fn(html, 'warpBtn')}
  #{js_fn(html, 'setTransport')}
  const look = () => [els.tpSlider.hidden, els.tpTime.hidden, els.tpEmpty.hidden, els.tpEmpty.textContent, els.dot.textContent];
  const warp = () => [els.tpWarp.hidden, els.tpWarp.className, els.tpWarp.title];
  const out = {};
  setTransport({state:'pause', t:13.05, total:0}); out.empty = look(); out.warpEmpty = warp();
  setTransport({state:'play', t:1.5, total:4}); out.full = look().concat([els.tpTime.innerHTML]); out.warpFull = warp();
  SCENE.time = {preset:'ease_in', curve:[[0,0],[1,1]]};
  setTransport({}); out.warpOn = warp();
  setTransport({state:'stop', t:0, total:0}); out.stop = look();
  out.noBtn = !('btnT' in els);
  // tasto principale: ☝ (strumento Aziona) con la timeline vuota e niente in moto
  let DIRTY = false; const calls = [];
  function saveTracks(){}
  function saveTime(){ TW_DIRTY = false; calls.push('save_time'); }
  const sketchup = new Proxy({}, {get: (_o, n) => () => calls.push(n)});
  #{js_fn(html, 'tpCmd')}
  #{js_fn(html, 'tpMain')}
  const btn = () => [els.tpPlay.textContent, els.tpPlay.title];
  setTransport({state:'pause', t:0, total:0}); out.useBtn = btn(); tpMain();
  setTransport({state:'play', t:3, total:0});  out.moving = btn(); tpMain();
  setTransport({state:'pause', t:1, total:4}); out.playBtn = btn(); TW_DIRTY = true; tpMain();
  out.calls = calls;
  process.stdout.write(JSON.stringify(out));
JS
File.write(path, script2)
r2 = JSON.parse(`node "#{path}"`)
eq('timeline vuota: barra e timer nascosti, la riga che lo spiega', r2['empty'], [true, true, false, 'tp.empty', '● ui.paused'])
eq('timeline con oggetti: barra e timer, niente riga', r2['full'][0, 3] + [r2['full'][5]], [false, false, true, '<b>1.50</b> / 4.00 s'])
eq('in riproduzione: l\'etichetta lo dice', r2['full'][4], '● ui.playing')
eq('fermo', r2['stop'][4], '● ui.idle')
eq('nessun tasto ▶ in alto', r2['noBtn'], true)
eq('timeline vuota e fermo: il tasto è lo strumento Aziona', r2['useBtn'], ['☝', 'tip.use'])
eq('timeline vuota ma qualcosa si muove: ⏸ per fermarlo', r2['moving'], ['⏸', 'tp.pause'])
eq('timeline con oggetti: Play', r2['playBtn'], ['▶', 'tp.play'])
eq('i comandi mandati a SketchUp (prima la velocità del tempo in attesa)', r2['calls'], %w[use_tool toggle save_time toggle])
eq('timeline vuota: niente tasto della velocità del tempo', r2['warpEmpty'][0], true)
eq('con la barra della timeline: il tasto ⏱', r2['warpFull'], [false, 'tbtn warp', 'tp.warp'])
eq('…acceso quando il modello ha una curva del tempo', r2['warpOn'][1], 'tbtn warp on')

# L'editor delle curve per la velocità del tempo (openTime): stessa finestra,
# curva del modello, riga della durata; salva con save_time.
curve_js = html[%r{/\* CURVE-BEGIN \*/(.*?)/\* CURVE-END \*/}m, 1]
script3 = <<~JS
  const els = {};
  const document = {activeElement: null, querySelectorAll: () => [],
    getElementById: id => els[id] || (els[id] = {id, hidden:false, textContent:'', innerHTML:'', title:'', className:'', value:'',
      dataset:{}, style:{}, setAttribute(){}, focus(){ document.activeElement = this; },
      classList: {s: new Set(), add(c){ this.s.add(c); }, remove(c){ this.s.delete(c); }, contains(c){ return this.s.has(c); }}})};
  function T(k){ return k; }
  function lookVal(k){ return {curve_grid: 10, curve_snap: true}[k]; }
  function requestAnimationFrame(){}
  function renderScene(){}
  function renderObj(){}
  function markSceneCur(){}
  function saveTracks(){ DIRTY = false; }
  const sent = [];
  const sketchup = {save_time: j => sent.push(JSON.parse(j))};
  let TP = {state:'pause', t:0, total:10, loops:false}, SCENE = {objects:[], total:10, time:null};
  let SEL = {kind:'none'}, DIRTY = false;
  let PRESETS = {linear:[[0,0],[1,1]], ease_in:[[0,0],[0.5,0.125],[0.75,0.42],[1,1]]};
  const CURVE_IDS = ['linear', 'ease_in'];
  #{curve_js}
  #{%w[esc escA presetName fmtSec curNum].map { |n| js_line(html, n) }.join("\n")}
  #{%w[num curvePath curveBounds].map { |n| js_fn(html, n) }.join}
  #{html[/^const CV_W.*$/]}
  #{html[/^let TW = .*$/]}
  let CV = null;
  #{%w[cvKey cvDur].map { |n| js_line(html, n) }.join("\n")}
  #{%w[cvX cvY].map { |n| js_line(html, n) }.join("\n")}
  #{%w[cvRange openTime renderTimeDur timeTotalChanged timeDur timeSame timeNormal timeChanged saveTime timeData
       timeTotal timeLen fmtX warpBtn closeCurve setScene setSelection renderCurve renderPresets curveSet curvePreset
       cvShowPos cvTick].map { |n| n.start_with?('time') && %w[timeTotal timeLen].include?(n) ? js_line(html, n) : js_fn(html, n) }.join}
  const out = {};
  const row = () => [els.cvDur.hidden, els.twDur.value, els.twAvg.innerHTML, els.twSame.hidden];
  openTime();
  out.open = [CV && CV.time, els.curvem.classList.contains('open'), els.cvTitle.textContent, els.cvAll.hidden, els.cvNormal.hidden];
  out.row = row();
  cvTick(performance.now());
  out.prev = [els.cvGhost.hidden, els.cvLa.textContent, els.cvLb.textContent];
  els.twDur.value = '2'; timeDur(els.twDur);
  out.dur = [TW.dur, TW_DIRTY].concat(row());
  cvShowPos(0.5, 0);
  out.pos = els.cvPos.innerHTML;
  setSelection({kind:'obj', pid:7, multi:0, others:[], data:{tracks:[]}});
  out.selKeeps = CV !== null && CV.time === true;
  closeCurve();
  out.closed = [CV, els.curvem.classList.contains('open'), document.activeElement === els.tpWarp, TW_DIRTY];
  out.sent1 = sent.slice();
  SCENE = {objects:[], total:10, time:{preset:'ease_in', curve:[[0,0],[0.5,0.125],[0.75,0.42],[1,1]], dur:4}};
  openTime();
  out.reopen = [TW.preset, TW.dur, els.twDur.value];
  curvePreset('linear');
  out.preset = [TW.preset, TW_DIRTY];
  setScene({objects:[], total:10, time:{preset:'ease_in', curve:[[0,0],[1,1]], dur:3}});
  out.sceneWhileDirty = TW.dur;
  saveTime();
  setScene({objects:[], total:10, time:{preset:'linear', curve:[[0,0],[1,1]], dur:4}});
  out.sceneAfterSave = [TW.preset, TW.dur, els.twDur.value];
  timeNormal(); saveTime();
  out.normal = sent[sent.length - 1];
  TP.total = 0; timeTotalChanged();
  out.gone = [CV, els.curvem.classList.contains('open')];
  out.fmt = [fmtX(6), fmtX(0.5), fmtX(-1.25), fmtX(120), fmtX(Infinity)];
  process.stdout.write(JSON.stringify(out));
JS
File.write(path, script3)
r3 = JSON.parse(`node "#{path}"`)
eq('⏱: si apre l\'editor delle curve, in modalità tempo', r3['open'], [true, true, 'tw.title', true, false])
eq('…con la riga della durata: quanto la timeline, ×1', r3['row'], [false, '10.00', 'tw.avg <b>×1.0</b>', true])
eq('anteprima: la timeline da 0 alla fine, e la pallina grigia del tempo normale', r3['prev'], [false, '0 s', '10.00 s'])
eq('durata 2 s: ×5, e «lunga quanto la timeline» per tornare', r3['dur'], [2, true, false, '2.00', 'tw.avg <b>×5.0</b>', false])
eq('sotto il mouse: riproduzione, timeline, velocità', r3['pos'], 'tw.play <b>1.00 s</b> · tw.time <b>5.00 s</b> · tw.speed <b>×5.0</b>')
eq('un altro oggetto selezionato: la velocità del tempo resta aperta', r3['selKeeps'], true)
eq('chiusa: salvata subito, e il fuoco torna al tasto', r3['closed'], [nil, false, true, false])
eq('…il modello riceve curva e durata', r3['sent1'], [{ 'preset' => 'linear', 'curve' => [[0, 0], [1, 1]], 'dur' => 2 }])
eq('riaperta: la curva del modello', r3['reopen'], ['ease_in', 4, '4.00'])
eq('una curva pronta: in attesa di salvare', r3['preset'], ['linear', true])
eq('la scena arriva mentre si modifica: non si perde la modifica', r3['sceneWhileDirty'], 4)
eq('…dopo il salvataggio sì', r3['sceneAfterSave'], ['linear', 4, '4.00'])
eq('«Tempo normale»: lineare, senza durata', r3['normal'], { 'preset' => 'linear', 'curve' => [[0, 0], [1, 1]], 'dur' => nil })
eq('timeline svuotata con l\'editor aperto: si chiude', r3['gone'], [nil, false])
eq('velocità scritte come ×', r3['fmt'], ['6.0', '0.50', '−1.3', '120', '—'])

puts $bad.zero? ? 'TUTTO OK' : "#{$bad} errori"
exit($bad.zero? ? 0 : 1)
