# Confronta le curve di Ruby (dagadyn/lib/curves.rb) con quelle del pannello
# (dagadyn/panel.html, fra CURVE-BEGIN e CURVE-END): devono dare gli stessi
# valori, altrimenti ciò che si disegna non è ciò che si vede nella scena.
#
#   ruby tools/test_curves.rb        (serve node nel PATH)
require 'json'
require 'tmpdir'

ROOT = File.expand_path('..', __dir__)
require File.join(ROOT, 'dagadyn', 'lib', 'curves.rb')
D = DagaDyn::Dyn

html = File.read(File.join(ROOT, 'dagadyn', 'panel.html'), encoding: 'UTF-8')
js = html[%r{/\* CURVE-BEGIN \*/(.*?)/\* CURVE-END \*/}m, 1] or abort 'marcatori CURVE-BEGIN/END non trovati'

srand(12_345)
cases = D::PRESET_POINTS.map { |id, pts| [id, pts] }
60.times do |n|
  k = rand(0..8)
  pts = (1..k).map { [rand(0.0..1.0).round(3), rand(-0.8..1.8).round(3)].tap { |p| p << 1 if rand < 0.3 } }
  cases << ["random#{n}", pts]
end
# punti fuori regola: devono essere ripuliti allo stesso modo
cases << ['dirty', [[0.5, 0.5], [0.5, 0.7], [-1, 3], [2, 0], [0.001, 9], ['x', 1], [0.3]]]
us = (0..200).map { |i| i / 200.0 } + [-0.5, 1.5, 0.12345, 0.98765]

ruby_out = cases.map do |id, pts|
  c = D.curve_prepare(pts)
  [id, c[:pts], us.map { |u| D.curve_eval(c, u) }]
end

script = <<~JS
  #{js}
  const cases = #{JSON.generate(cases)}, us = #{JSON.generate(us)};
  const out = cases.map(([id, pts]) => { const c = curvePrepare(pts); return [id, c.pts, us.map(u => curveEval(c, u))]; });
  process.stdout.write(JSON.stringify(out));
JS
path = File.join(Dir.tmpdir, 'dagadyn_test_curves.js')
File.write(path, script)
js_out = JSON.parse(`node "#{path}"`)

bad = 0
ruby_out.zip(js_out).each do |(id, rp, rv), (_, jp, jv)|
  if rp.map { |p| p.map(&:to_f) } != jp.map { |p| p.map(&:to_f) }
    puts "#{id}: punti diversi\n  ruby #{rp.inspect}\n  js   #{jp.inspect}"
    bad += 1
    next
  end
  err = rv.zip(jv).map { |a, b| (a - b).abs }.max
  if err > 1e-9
    puts "#{id}: differenza massima #{err}"
    bad += 1
  end
end
# Gli estremi della curva sono sempre 0 e 1, e le preset passano per i loro punti
D::PRESET_POINTS.each do |id, pts|
  c = D.curve_prepare(pts)
  pts.each do |x, y|
    v = D.curve_eval(c, x)
    if (v - y).abs > 1e-9
      puts "#{id}: in x=#{x} vale #{v}, atteso #{y}"
      bad += 1
    end
  end
end
puts bad.zero? ? "OK: #{cases.size} curve, #{us.size} istanti ciascuna, Ruby e pannello coincidono" : "#{bad} problemi"
exit(bad.zero? ? 0 : 1)
