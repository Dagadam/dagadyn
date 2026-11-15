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
  #{js_fn(html, 'setTransport')}
  const look = () => [els.tpSlider.hidden, els.tpTime.hidden, els.tpEmpty.hidden, els.tpEmpty.textContent, els.dot.textContent];
  const out = {};
  setTransport({state:'pause', t:13.05, total:0}); out.empty = look();
  setTransport({state:'play', t:1.5, total:4}); out.full = look().concat([els.tpTime.innerHTML]);
  setTransport({state:'stop', t:0, total:0}); out.stop = look();
  out.noBtn = !('btnT' in els);
  // tasto principale: ☝ (strumento Aziona) con la timeline vuota e niente in moto
  let DIRTY = false; const calls = [];
  function saveTracks(){}
  const sketchup = new Proxy({}, {get: (_o, n) => () => calls.push(n)});
  #{js_fn(html, 'tpCmd')}
  #{js_fn(html, 'tpMain')}
  const btn = () => [els.tpPlay.textContent, els.tpPlay.title];
  setTransport({state:'pause', t:0, total:0}); out.useBtn = btn(); tpMain();
  setTransport({state:'play', t:3, total:0});  out.moving = btn(); tpMain();
  setTransport({state:'pause', t:1, total:4}); out.playBtn = btn(); tpMain();
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
eq('i comandi mandati a SketchUp', r2['calls'], %w[use_tool toggle toggle])

puts $bad.zero? ? 'TUTTO OK' : "#{$bad} errori"
exit($bad.zero? ? 0 : 1)
