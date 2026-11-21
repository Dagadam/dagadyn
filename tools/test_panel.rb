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

# Transizioni a formula: la casella «Formula» toglie pallini e valore di
# arrivo e mette campo e parametri; i parametri leggono questo oggetto (non
# la stessa traccia) e gli altri; gli errori arrivano da Ruby (fxChecked).
script4 = <<~JS
  const errEls = [];
  const bakeErr = {textContent:''};
  const document = {querySelectorAll: s => s === '.fxerr' ? errEls : [], querySelector: s => s === '.fxerr[data-k="0_1"]' ? bakeErr : null};
  function T(k){ return k; }
  function curveThumb(){ return '<svg/>'; }
  function presetName(id){ return 'cv.' + id; }
  function openCurve(){}
  let closed = 0;
  function closeCurve(){ closed++; CV = null; }
  const changes = [];
  function tracksChanged(redraw, preview){ changes.push([redraw, preview === undefined ? null : preview]); }
  let timers = 0;
  function setTimeout(f){ timers++; return 0; }
  function clearTimeout(){}
  const sent = [];
  const sketchup = {fx_check: j => sent.push(JSON.parse(j)), fx_bake: j => sent.push(['bake', JSON.parse(j)])};
  #{html[/^const PROPS = \{.*?\};\n/m]}
  #{html[/^const LEN_DEC.*$/]}
  #{html[/^let UNIT = .*$/]}
  #{html[/^const FX_KINDS.*$/]}
  #{html[/^let FX_ERR = .*$/]}
  #{html[/^let FX_PLOT = .*$/]}
  #{%w[esc escA kindOf fmtSec fxKey fxParamDel fxParamProp fxParamAt].map { |n| js_line(html, n) }.join("\n")}
  #{%w[toDisp unitOf decOf fmtVal keyTime valInput trackHTML fxSources fxHTML fxParamHTML fxOn fxExpr fxParamAdd
       fxParamName fxParamObj fxErrText fxCheckSoon fxCheck fxChecked fxPlotOf fxPlotSvg fxEndText fxBake fxBaked].map { |n| js_fn(html, n) }.join}
  let CV = {i:0, j:1};
  const M = 39.37007874;
  let SEL = {kind:'obj', pid:5, name:'Solido', data:{tracks:[
      {id:'a', prop:'size_x', on:true, delay:0, loop:'none', keys:[{v:M}, {v:2*M, dur:1, preset:'linear', curve:[[0,0],[1,1]]}]},
      {id:'b', prop:'size_y', on:true, delay:0, loop:'none', keys:[{v:M}, {v:M, dur:1, preset:'linear', curve:[[0,0],[1,1]]}]},
      {id:'c', prop:'color', on:true, delay:0, loop:'none', keys:[{v:'#ff0000'}, {v:'#00ff00', dur:1, preset:'linear', curve:[[0,0],[1,1]]}]}]},
    others:[{pid:1, name:'Cubo', tracks:[{prop:'size_z', n:2}, {prop:'rot_z', n:1}]}]};
  const out = {};
  const h0 = trackHTML(SEL.data.tracks[0], 0);
  out.before = [h0.includes('cthumb'), h0.includes('fxexpr'), h0.includes('fxOn(0,1,this.checked)'), h0.includes('class="vbox" type="text"')];
  out.color = trackHTML(SEL.data.tracks[2], 2).includes('fxOn(');
  fxOn(0, 1, true);
  const k = SEL.data.tracks[0].keys[1];
  out.on = [k.fx.on, k.fx.expr, closed, changes[changes.length - 1]];
  const h1 = trackHTML(SEL.data.tracks[0], 0);
  out.after = [h1.includes('openCurve('), h1.includes('fxexpr'), h1.includes('fxend'), (h1.match(/class="vbox" type="text"/g) || []).length,
               h1.includes('fxplot'), h1.includes('fxBake(0,1)')];
  fxParamAdd(0, 1); fxParamAdd(0, 1);
  out.names = k.fx.params.map(q => q.n);
  const srcs = fxSources(SEL.data.tracks[0]);
  out.sources = srcs.map(o => [o.pid, o.name, o.tracks.map(t => t.prop)]);
  fxParamObj(0, 1, 0, 1);
  out.picked = Object.assign({}, k.fx.params[0]);
  fxParamAt(0, 1, 0, 2);
  const h2 = trackHTML(SEL.data.tracks[0], 0);
  out.paramHtml = [h2.includes('tr.fx_prog'), h2.includes('>0–1<'), h2.includes('value="2" selected')];
  fxParamObj(0, 1, 1, 999);
  out.unknown = [k.fx.params[1].pid, k.fx.params[1].prop];
  const el = {value:'K!2'};
  fxParamName(0, 1, 0, el);
  out.rename = [el.value, k.fx.params[0].n];
  fxParamDel(0, 1, 1);
  out.left = k.fx.params.length;
  fxCheck();
  out.sent = [sent.length, sent[0].pid, sent[0].seq, sent[0].data.tracks[0].keys[1].fx.expr];
  const e1 = {dataset:{k:'0_1'}, textContent:''}; errEls.push(e1);
  fxChecked({seq: 0, errs:{'0_1':['fx.e_name','Q']}});
  out.stale = e1.textContent;
  fxChecked({seq: FX_SEQ, errs:{'0_1':['fx.e_name','Q']}});
  out.err = e1.textContent;
  SEL = Object.assign({}, SEL, {pid: 6});
out.otherObj = fxErrText('0_1');
SEL = Object.assign({}, SEL, {pid: 5});
fxChecked({seq: FX_SEQ, errs:{}, plots:{'0_1':[M, 1.5*M, 2*M]}});
const h3 = trackHTML(SEL.data.tracks[0], 0);
out.plot = [h3.includes('<path d="M0.0 30.0 L38.0 17.0 L76.0 4.0"/>'), fxEndText(0, 1)];
SEL = Object.assign({}, SEL, {pid: 6});
out.plotOther = [fxPlotOf('0_1'), fxEndText(0, 1)];
SEL = Object.assign({}, SEL, {pid: 5});
sent.length = 0; changes.length = 0;
fxBake(0, 1);
out.bake = [sent[0][0], sent[0][1].pid, sent[0][1].i, sent[0][1].j, sent[0][1].data.tracks[0].keys.length];
fxBaked({pid:6, i:0, j:1, keys:[{v:1}, {v:2}]});
out.bakeOther = [SEL.data.tracks[0].keys.length, changes.length];
fxBaked({pid:5, i:0, j:1, err:['fx.e_bake_many', '32']});
out.bakeErr = [bakeErr.textContent, SEL.data.tracks[0].keys.length];
fxBaked({pid:5, i:0, j:1, keys:[{v:1.5*M, dur:0.5, preset:'custom', curve:[[0,0],[0.5,0.7],[1,1]]}, {v:2*M, dur:0.5, preset:'linear', curve:[[0,0],[1,1]]}]});
const ks = SEL.data.tracks[0].keys;
out.baked = [ks.length, ks.map(k => !!k.fx), ks[1].v / M, changes[changes.length - 1]];
  process.stdout.write(JSON.stringify(out));
JS
File.write(path, script4)
r4 = JSON.parse(`node "#{path}"`)
eq('formula spenta: curva, casella «Formula», valori da scrivere', r4['before'], [true, false, true, true])
eq('colore: niente formula', r4['color'], false)
eq('spuntata: una formula lineare fino al valore di prima, editor chiuso, anteprima', r4['on'],
   [true, 'v0 + (2.000 - v0) * u', 1, [true, 1]])
eq('…niente pallini, il campo della formula, «dove la porta la formula» al posto del valore', r4['after'], [false, true, true, 1, true, true])
eq('parametri nuovi: K, K2', r4['names'], %w[K K2])
eq('si leggono: le altre tracce di questo oggetto (numeriche) e gli altri oggetti', r4['sources'],
   [[5, 'tr.fx_self', ['size_y']], [1, 'Cubo', %w[size_z rot_z]]])
eq('scelto il Cubo: la sua prima traccia, il valore', r4['picked'], { 'n' => 'K', 'pid' => 1, 'prop' => 'size_z', 'at' => 0 })
eq('avanzamento della transizione 2: scelto, in 0–1', r4['paramHtml'], [true, true, true])
eq('oggetto che non c\'è: niente', r4['unknown'], [0, ''])
eq('nome del parametro: solo lettere, cifre e _', r4['rename'], %w[K2 K2])
eq('parametro tolto', r4['left'], 1)
eq('controllo chiesto a Ruby con i dati non ancora salvati', r4['sent'], [1, 5, 1, 'v0 + (2.000 - v0) * u'])
eq('risposta vecchia: ignorata', r4['stale'], '')
eq('errore mostrato', r4['err'], 'fx.e_name')
eq('errori di un altro oggetto: non si mostrano', r4['otherObj'], '')
eq('il grafico della formula al posto della miniatura, e dove arriva', r4['plot'], [true, "ƒ tr.fx_end  ≈ 2.000 m"])
eq('…ma non quello di un altro oggetto', r4['plotOther'], [nil, 'ƒ tr.fx_end'])
eq('«Converti in curva»: chiesto a Ruby con i dati di adesso', r4['bake'], ['bake', 5, 0, 1, 2])
eq('…risposta per un altro oggetto: ignorata', r4['bakeOther'], [2, 0])
eq('…troppo mossa: lo dice sotto la formula', r4['bakeErr'], ['fx.e_bake_many', 2])
eq('…convertita: due stati al posto della formula, salvati', r4['baked'], [3, [false, false, false], 1.5, [true, nil]])

puts $bad.zero? ? 'TUTTO OK' : "#{$bad} errori"
exit($bad.zero? ? 0 : 1)
