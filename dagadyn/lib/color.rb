# DagaDyn — Colori: '#rrggbb', miscela in OKLab.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    # ══════════════════════════════════════════════════════════════
    # Fra due colori la transizione passa per OKLab (Björn Ottosson, 2020):
    # le tinte intermedie hanno una luminosità che cambia in modo regolare,
    # senza il grigio sporco a metà che dà la miscela diretta dei valori
    # RGB (rosso → verde passa per un giallo-bruno, non per un marrone
    # spento). Con color_mix = 'rgb' si usa la miscela diretta.
    # ══════════════════════════════════════════════════════════════

    def self.hex_rgb(h)
      h = h.to_s.strip.downcase
      h = "##{h[1] * 2}#{h[2] * 2}#{h[3] * 2}" if h.match?(/\A#\h{3}\z/)
      return nil unless h.match?(/\A#\h{6}\z/)
      [h[1, 2].hex, h[3, 2].hex, h[5, 2].hex]
    end

    def self.rgb_hex(c)
      '#' + c.map { |v| v.round.clamp(0, 255).to_s(16).rjust(2, '0') }.join
    end

    def self.srgb_to_lin(v)
      v /= 255.0
      v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4
    end

    def self.lin_to_srgb(v)
      v = v.clamp(0.0, 1.0)
      255.0 * (v <= 0.0031308 ? 12.92 * v : 1.055 * v**(1 / 2.4) - 0.055)
    end

    def self.rgb_oklab(c)
      r, g, b = c.map { |v| srgb_to_lin(v) }
      l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
      m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
      s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
      [0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
       1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
       0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s]
    end

    def self.oklab_rgb(lab)
      ll, a, b = lab
      l = (ll + 0.3963377774 * a + 0.2158037573 * b)**3
      m = (ll - 0.1055613458 * a - 0.0638541728 * b)**3
      s = (ll - 0.0894841775 * a - 1.2914855480 * b)**3
      [ 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
       -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
       -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s].map { |v| lin_to_srgb(v) }
    end

    # Colore a una frazione e (anche fuori da 0–1 con le curve elastiche:
    # il risultato viene ricondotto ai colori possibili) fra a e b, [r,g,b].
    def self.mix_color(a, b, e)
      if cf('color_mix') == 'rgb'
        a.zip(b).map { |x, y| (x + (y - x) * e).clamp(0.0, 255.0) }
      else
        la = rgb_oklab(a); lb = rgb_oklab(b)
        oklab_rgb(la.zip(lb).map { |x, y| x + (y - x) * e })
      end
    end

  end
end
