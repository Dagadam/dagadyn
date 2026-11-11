# DagaDyn — Curve di transizione: punti ("pallini"), interpolazione, preset.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    # ══════════════════════════════════════════════════════════════
    # Una curva dice quanta parte della transizione è compiuta (y) a ogni
    # istante (x), entrambi in 0–1: valore = da + (a − da) × y.
    # È una lista di punti [x, y] oppure [x, y, 1] (1 = punto ad angolo:
    # la curva vi arriva e ne riparte con due pendenze diverse, come un
    # rimbalzo). Il primo punto è sempre (0, 0) e l'ultimo (1, 1); quelli in
    # mezzo possono uscire da 0–1 (oltre la meta e ritorno: elastico).
    #
    # Fra i punti: cubica di Hermite monotona a tratti (PCHIP, Fritsch–
    # Carlson con media armonica). Passa per ogni punto, non inventa
    # oscillazioni fra due punti e si appiattisce sui massimi e minimi.
    #
    # LO STESSO ALGORITMO sta in panel.html (curveTangents / curveEval): la
    # curva che si disegna è quella che il motore applica. Se si cambia qui
    # va cambiato anche là (tools/test_curves.rb confronta le due).
    # ══════════════════════════════════════════════════════════════

    CURVE_MAX_PTS = 32
    CURVE_MIN_DX  = 0.005
    CURVE_Y_RANGE = [-1.0, 2.0].freeze

    PRESET_POINTS = {
      'linear'      => [[0, 0], [1, 1]],
      'ease_in'     => [[0, 0], [0.5, 0.125], [0.75, 0.42], [1, 1]],
      'ease_out'    => [[0, 0], [0.25, 0.58], [0.5, 0.875], [1, 1]],
      'ease_in_out' => [[0, 0], [0.25, 0.0625], [0.5, 0.5], [0.75, 0.9375], [1, 1]],
      'back'        => [[0, 0], [0.5, 0.85], [0.72, 1.1], [1, 1]],
      'elastic'     => [[0, 0], [0.25, 1.3], [0.45, 0.85], [0.62, 1.08], [0.78, 0.97], [0.9, 1.01], [1, 1]],
      'bounce'      => [[0, 0], [0.2, 0.3], [0.36, 1, 1], [0.54, 0.75], [0.73, 1, 1], [0.83, 0.94],
                        [0.91, 1, 1], [0.955, 0.985], [1, 1]],
      'steps'       => [[0, 0], [0.32, 0, 1], [0.34, 0.333, 1], [0.65, 0.333, 1], [0.67, 0.667, 1],
                        [0.98, 0.667, 1], [1, 1]],
    }.freeze

    def self.preset_points(id)
      (PRESET_POINTS[id.to_s] || PRESET_POINTS['linear']).map { |p| p.map(&:to_f) }
    end

    # Punti validi: numeri finiti, ordinati per x, estremi fissi, niente
    # punti troppo vicini, non più di CURVE_MAX_PTS.
    def self.sanitize_points(pts)
      pts = [] unless pts.is_a?(Array)
      inner = pts.filter_map do |p|
        next unless p.is_a?(Array) && p.size >= 2
        x = p[0]; y = p[1]
        next unless x.is_a?(Numeric) && y.is_a?(Numeric) && x.to_f.finite? && y.to_f.finite?
        x = x.to_f; y = y.to_f.clamp(*CURVE_Y_RANGE)
        next if x <= CURVE_MIN_DX || x >= 1.0 - CURVE_MIN_DX
        p[2] == 1 ? [x, y, 1] : [x, y]
      end
      # ordinamento stabile (come Array.sort del pannello): a parità di x vince il primo
      inner = inner.each_with_index.sort_by { |p, i| [p[0], i] }.map(&:first)
      out = [[0.0, 0.0]]
      inner.each { |p| out << p if p[0] - out.last[0] >= CURVE_MIN_DX }
      out.pop while out.size > 1 && 1.0 - out.last[0] < CURVE_MIN_DX
      out << [1.0, 1.0]
      out = out.first(CURVE_MAX_PTS - 1) + [out.last] if out.size > CURVE_MAX_PTS
      out
    end

    # Pendenze di entrata (mi) e uscita (mo) in ogni punto.
    def self.curve_tangents(pts)
      n  = pts.size
      xs = pts.map { |p| p[0] }
      ys = pts.map { |p| p[1] }
      h  = (0...n - 1).map { |k| xs[k + 1] - xs[k] }
      d  = (0...n - 1).map { |k| (ys[k + 1] - ys[k]) / h[k] }
      m  = Array.new(n, 0.0)
      if n == 2
        m[0] = m[1] = d[0]
      else
        (1...n - 1).each do |k|
          a = d[k - 1]; b = d[k]
          if a * b <= 0
            m[k] = 0.0
          else
            w1 = 2 * h[k] + h[k - 1]
            w2 = h[k] + 2 * h[k - 1]
            m[k] = (w1 + w2) / (w1 / a + w2 / b)
          end
        end
        m[0]     = pchip_end(h[0], h[1], d[0], d[1])
        m[n - 1] = pchip_end(h[n - 2], h[n - 3], d[n - 2], d[n - 3])
      end
      mi = m.dup
      mo = m.dup
      # punti ad angolo: ogni lato prende la pendenza del suo tratto
      (1...n - 1).each do |k|
        next unless pts[k][2] == 1
        mi[k] = d[k - 1]
        mo[k] = d[k]
      end
      [mi, mo]
    end

    # Pendenza a un estremo (come pchip di MATLAB): formula a tre punti,
    # poi ricondotta perché la curva resti monotona vicino all'estremo.
    def self.pchip_end(h0, h1, d0, d1)
      m = ((2 * h0 + h1) * d0 - h0 * d1) / (h0 + h1)
      if (m <=> 0) != (d0 <=> 0)
        0.0
      elsif (d0 <=> 0) != (d1 <=> 0) && m.abs > (3 * d0).abs
        3 * d0
      else
        m
      end
    end

    # Curva pronta per la valutazione: punti e pendenze.
    def self.curve_prepare(pts)
      pts = sanitize_points(pts)
      mi, mo = curve_tangents(pts)
      { pts: pts, mi: mi, mo: mo }
    end

    def self.curve_eval(c, u)
      pts = c[:pts]
      u = u.to_f
      return pts[0][1] if u <= 0.0
      return pts[-1][1] if u >= 1.0
      k = 0
      k += 1 while k < pts.size - 2 && u > pts[k + 1][0]
      x0, y0 = pts[k]
      x1, y1 = pts[k + 1]
      hh = x1 - x0
      t  = (u - x0) / hh
      t2 = t * t; t3 = t2 * t
      (2 * t3 - 3 * t2 + 1) * y0 + (t3 - 2 * t2 + t) * hh * c[:mo][k] +
        (-2 * t3 + 3 * t2) * y1 + (t3 - t2) * hh * c[:mi][k + 1]
    end

  end
end
