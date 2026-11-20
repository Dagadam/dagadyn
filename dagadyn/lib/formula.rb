# DagaDyn — Transizioni a formula: interprete, parametri, collegamenti fra tracce.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    # ══════════════════════════════════════════════════════════════
    # Una transizione può seguire una formula invece della curva a pallini
    # (lib/curves.rb). Sta nello stato di arrivo, accanto alla curva, che
    # resta lì: togliendo la spunta si torna ai pallini di prima.
    #
    #   { "v": 157.48, "dur": 1.0, "preset": "linear", "curve": [...],
    #     "fx": { "on": true,
    #             "expr": "0.5 + K/2",
    #             "params": [ { "n": "K",            nome nella formula
    #                           "pid": 1234,         oggetto (persistent_id)
    #                           "prop": "size_z",    sua traccia
    #                           "at": 0 } ] } }      0: il valore della traccia;
    #                                                j: l'avanzamento (0–1) della
    #                                                sua transizione j (1 = la prima)
    #
    # La formula dà il valore della proprietà, nelle unità del pannello
    # (lunghezze nell'unità del modello, angoli in gradi, scala ×, opacità
    # in %). Conosce:
    #   u   avanzamento della transizione, da 0 a 1 (il tempo, senza curva)
    #   t   secondi dall'inizio della transizione
    #   d   durata della transizione (s)
    #   v0  il valore di partenza (dove ha lasciato la transizione prima)
    #   pi  e i parametri, letti nello stesso istante della timeline.
    # Operatori + - * / ^ (potenza) e parentesi; funzioni FX_FUNCS (seni e
    # coseni in gradi, come gli angoli di DagaDyn).
    #
    # Il valore di arrivo non si scrive: è dove la formula porta l'oggetto
    # alla fine della transizione, con i parametri di quell'istante, e la
    # transizione dopo riparte da lì. Finita l'ultima, resta lì.
    #
    # Niente eval di Ruby: le formule viaggiano dentro i file .skp, e un
    # file scaricato non deve poter eseguire codice. L'interprete qui sotto
    # conosce solo numeri, nomi, operatori e le funzioni dell'elenco.
    # Una formula che non si può calcolare (errore di scrittura, parametro
    # che non c'è più, collegamento circolare, divisione per zero) lascia
    # l'oggetto al valore di partenza; il pannello dice perché (fx_check).
    # ══════════════════════════════════════════════════════════════

    FX_KINDS      = %i[length angle factor ratio].freeze   # solo proprietà numeriche continue
    FX_MAX_LEN    = 400
    FX_MAX_PARAMS = 8
    FX_VARS       = %w[u t d v0].freeze
    FX_CONSTS     = { 'pi' => Math::PI }.freeze
    RAD = Math::PI / 180.0
    # nome → [argomenti minimi, massimi (nil: quanti si vuole), calcolo]
    FX_FUNCS = {
      'sin'   => [1, 1, ->(a) { Math.sin(a[0] * RAD) }],
      'cos'   => [1, 1, ->(a) { Math.cos(a[0] * RAD) }],
      'tan'   => [1, 1, ->(a) { Math.tan(a[0] * RAD) }],
      'asin'  => [1, 1, ->(a) { Math.asin(a[0]) / RAD }],
      'acos'  => [1, 1, ->(a) { Math.acos(a[0]) / RAD }],
      'atan'  => [1, 1, ->(a) { Math.atan(a[0]) / RAD }],
      'atan2' => [2, 2, ->(a) { Math.atan2(a[0], a[1]) / RAD }],
      'sqrt'  => [1, 1, ->(a) { Math.sqrt(a[0]) }],
      'abs'   => [1, 1, ->(a) { a[0].abs }],
      'sign'  => [1, 1, ->(a) { (a[0] <=> 0).to_f }],
      'floor' => [1, 1, ->(a) { a[0].floor.to_f }],
      'ceil'  => [1, 1, ->(a) { a[0].ceil.to_f }],
      'round' => [1, 1, ->(a) { a[0].round.to_f }],
      'exp'   => [1, 1, ->(a) { Math.exp(a[0]) }],
      'ln'    => [1, 1, ->(a) { Math.log(a[0]) }],
      'log'   => [1, 1, ->(a) { Math.log10(a[0]) }],
      'min'   => [1, nil, ->(a) { a.min }],
      'max'   => [1, nil, ->(a) { a.max }],
      'clamp' => [3, 3, ->(a) { a[0] < a[1] ? a[1] : (a[0] > a[2] ? a[2] : a[0]) }],
    }.freeze
    FX_NAME = /\A[A-Za-z_][A-Za-z0-9_]{0,15}\z/

    class FxError < StandardError
      attr_reader :code, :arg
      def initialize(code, arg = '')
        @code = code
        @arg  = arg.to_s
        super("#{code} #{arg}")
      end
    end

    def self.fx_kind?(prop)
      spec = PROPS[prop]
      spec && FX_KINDS.include?(spec[:kind]) ? true : false
    end

    # Un nome che il parametro non può avere: variabili, costanti, funzioni
    def self.fx_reserved?(n)
      FX_VARS.include?(n) || FX_CONSTS.key?(n) || FX_FUNCS.key?(n)
    end

    # ── Dati ────────────────────────────────────────────────────────
    # nil: niente formula (né accesa, né scritta da conservare)
    def self.sanitize_fx(prop, f)
      return nil unless f.is_a?(Hash) && fx_kind?(prop)
      expr = f['expr'].is_a?(String) ? f['expr'][0, FX_MAX_LEN] : ''
      params = (f['params'].is_a?(Array) ? f['params'] : []).select { |p| p.is_a?(Hash) }.first(FX_MAX_PARAMS).map do |p|
        n = p['n'].is_a?(String) ? p['n'].gsub(/[^A-Za-z0-9_]/, '')[0, 16] : ''
        src = p['prop'].to_s
        { 'n' => n, 'pid' => p['pid'].is_a?(Numeric) ? p['pid'].to_i : 0,
          'prop' => fx_kind?(src) ? src : '',
          'at' => p['at'].is_a?(Numeric) ? p['at'].to_i.clamp(0, MAX_KEYS) : 0 }
      end
      on = f['on'] == true
      return nil if !on && expr.strip.empty? && params.empty?
      { 'on' => on, 'expr' => expr, 'params' => params }
    end

    # ── Interprete ──────────────────────────────────────────────────
    # La formula diventa un albero di array:
    #   [:n, 2.0]  [:v, 'u']  [:neg, x]  [:op, '+', a, b]  [:f, 'sin', [x]]
    # Solleva FxError: :empty, :syntax (vicino a…), :end (finisce a metà),
    # :name (nome sconosciuto), :args (argomenti sbagliati).
    FX_SIGNS = { '×' => '*', '·' => '*', '÷' => '/', '−' => '-', '–' => '-', ';' => ',' }.freeze
    FX_TOKEN = /\s*(?:(\d+(?:\.\d*)?(?:[eE][-+]?\d+)?|\.\d+(?:[eE][-+]?\d+)?)|([A-Za-z_][A-Za-z0-9_]*)|(\S))/m

    def self.fx_tokens(src)
      s = src.to_s.gsub(/[×·÷−–;]/, FX_SIGNS)
      out = []
      pos = 0
      while pos < s.size
        m = FX_TOKEN.match(s, pos)
        break unless m && m.begin(0) == pos
        pos = m.end(0)
        if m[1] then out << [:n, m[1].to_f]
        elsif m[2] then out << [:id, m[2]]
        elsif m[3]
          raise FxError.new(:syntax, m[3]) unless '+-*/^(),'.include?(m[3])
          out << [:op, m[3]]
        end
      end
      out
    end

    def self.fx_compile(src, names = [])
      toks = fx_tokens(src)
      raise FxError.new(:empty) if toks.empty?
      st = { toks: toks, i: 0, names: names }
      ast = fx_add(st)
      raise FxError.new(:syntax, fx_tok_text(toks[st[:i]])) if st[:i] < toks.size
      ast
    end

    def self.fx_tok_text(t)
      return '' unless t
      t[0] == :n ? (t[1] % 1 == 0 ? t[1].to_i.to_s : t[1].to_s) : t[1].to_s
    end

    def self.fx_peek(st); st[:toks][st[:i]]; end

    def self.fx_take(st, op)
      t = fx_peek(st)
      return false unless t && t[0] == :op && t[1] == op
      st[:i] += 1
      true
    end

    def self.fx_add(st)
      a = fx_mul(st)
      loop do
        if fx_take(st, '+') then a = [:op, '+', a, fx_mul(st)]
        elsif fx_take(st, '-') then a = [:op, '-', a, fx_mul(st)]
        else return a
        end
      end
    end

    def self.fx_mul(st)
      a = fx_unary(st)
      loop do
        if fx_take(st, '*') then a = [:op, '*', a, fx_unary(st)]
        elsif fx_take(st, '/') then a = [:op, '/', a, fx_unary(st)]
        else return a
        end
      end
    end

    # -2^2 = -4, 2^-1 = 0.5, 2^3^2 = 2^9 (come si scrive a mano)
    def self.fx_unary(st)
      return [:neg, fx_unary(st)] if fx_take(st, '-')
      return fx_unary(st) if fx_take(st, '+')
      a = fx_atom(st)
      fx_take(st, '^') ? [:op, '^', a, fx_unary(st)] : a
    end

    def self.fx_atom(st)
      t = fx_peek(st) or raise FxError.new(:end)
      st[:i] += 1
      case t[0]
      when :n then [:n, t[1]]
      when :id
        n = t[1]
        if fx_take(st, '(')
          f = FX_FUNCS[n] or raise FxError.new(:name, n)
          args = [fx_add(st)]
          args << fx_add(st) while fx_take(st, ',')
          raise(fx_peek(st) ? FxError.new(:syntax, fx_tok_text(fx_peek(st))) : FxError.new(:end)) unless fx_take(st, ')')
          raise FxError.new(:args, n) if args.size < f[0] || (f[1] && args.size > f[1])
          [:f, n, args]
        elsif FX_CONSTS.key?(n) then [:n, FX_CONSTS[n]]
        elsif FX_VARS.include?(n) || st[:names].include?(n) then [:v, n]
        else raise FxError.new(:name, n)
        end
      else
        if t[1] == '('
          a = fx_add(st)
          raise(fx_peek(st) ? FxError.new(:syntax, fx_tok_text(fx_peek(st))) : FxError.new(:end)) unless fx_take(st, ')')
          a
        else
          raise FxError.new(:syntax, t[1])
        end
      end
    end

    # Valore dell'albero con le variabili vars (nome → numero). Non finito
    # (divisione per zero, radice di un negativo): nil.
    def self.fx_run(ast, vars)
      x = fx_node(ast, vars)
      x.is_a?(Float) && x.finite? ? x : nil
    rescue ZeroDivisionError, Math::DomainError, FloatDomainError, TypeError, NoMethodError
      nil
    end

    def self.fx_node(a, vars)
      case a[0]
      when :n then a[1]
      when :v then vars.fetch(a[1]).to_f
      when :neg then -fx_node(a[1], vars)
      when :op
        x = fx_node(a[2], vars)
        y = fx_node(a[3], vars)
        case a[1]
        when '+' then x + y
        when '-' then x - y
        when '*' then x * y
        when '/' then x / y
        else
          r = x**y
          r.is_a?(Complex) ? Float::NAN : r.to_f
        end
      else
        FX_FUNCS[a[1]][2].call(a[2].map { |b| fx_node(b, vars) }).to_f
      end
    end

    # Formule già tradotte (la stessa formula serve a ogni fotogramma)
    def self.fx_cached(expr, names)
      @fx_cache ||= {}
      key = [expr, names]
      return @fx_cache[key] if @fx_cache.key?(key)
      @fx_cache.clear if @fx_cache.size > 500
      @fx_cache[key] = begin
        { ast: fx_compile(expr, names) }
      rescue FxError => err
        { err: err }
      end
    end

    # Pronta per il motore (prepare_tracks): nil se la transizione usa la curva
    def self.fx_prepare(k)
      f = k['fx']
      return nil unless f && f['on']
      params = f['params'].select { |p| p['n'] =~ FX_NAME && !fx_reserved?(p['n']) }
      names = params.map { |p| p['n'] }
      ok = names.uniq.size == names.size && params.all? { |p| p['pid'] != 0 && !p['prop'].empty? }
      c = fx_cached(f['expr'], names)
      { ast: ok ? c[:ast] : nil, params: params }
    end

    # ── Unità ───────────────────────────────────────────────────────
    # Le formule lavorano con i numeri che si vedono nel pannello
    def self.fx_disp(prop, v, factor)
      case PROPS[prop][:kind]
      when :length then v / factor
      when :ratio  then v * 100.0
      else v
      end
    end

    def self.fx_internal(prop, x, factor)
      case PROPS[prop][:kind]
      when :length then x * factor
      when :ratio  then x / 100.0
      else x
      end
    end

    # Pollici per unità del modello attivo (senza SketchUp: metri)
    def self.fx_factor
      m = defined?(Sketchup) && Sketchup.respond_to?(:active_model) ? Sketchup.active_model : nil
      m ? unit_info(m)['factor'] : 1.0 / 0.0254
    rescue
      1.0 / 0.0254
    end

    # ── Calcolo dentro il motore ────────────────────────────────────
    # ctx: { w: mondo, off: tempo della timeline − tempo locale, f: fattore }
    # Il mondo (fx_world_*) trova le tracce degli altri oggetti e il loro
    # tempo locale in un istante qualsiasi della timeline; ricorda i valori
    # già calcolati in questo fotogramma (memo) e riconosce i giri chiusi
    # (busy: A chiede B che chiede A nello stesso istante → nil).
    #
    # Valore della transizione g (indice gi) a u, t secondi dal suo inizio,
    # all'istante gt della timeline, partendo da v0: nil se non si calcola.
    def self.fx_eval(tr, g, u, tsec, v0, gt, ctx)
      fx = g[:fx]
      return nil unless fx[:ast]
      f = ctx[:f]
      vars = { 'u' => u, 't' => tsec, 'd' => g[:dur], 'v0' => fx_disp(tr[:prop], v0, f) }
      fx[:params].each do |p|
        x = fx_param(ctx[:w], p, gt) or return nil
        vars[p['n']] = x
      end
      x = fx_run(fx[:ast], vars) or return nil
      fx_internal(tr[:prop], x, f)
    end

    def self.fx_param(w, p, gt)
      return nil unless w
      if p['at'] > 0
        fx_src_progress(w, p['pid'], p['prop'], p['at'], gt)
      else
        v = fx_src_value(w, p['pid'], p['prop'], gt)
        v && fx_disp(p['prop'], v, w[:f])
      end
    end

    def self.fx_src_track(w, pid, prop)
      src = w[:src].call(pid) or return nil
      tr = src[:tracks].find { |x| x[:prop] == prop } or return nil
      [src, tr]
    end

    def self.fx_src_value(w, pid, prop, gt)
      key = [pid, prop, gt.round(6)]
      return w[:memo][key] if w[:memo].key?(key)
      return nil if w[:busy][key]               # collegamento circolare
      w[:busy][key] = true
      v = nil
      if (st = fx_src_track(w, pid, prop))
        src, tr = st
        local = src[:local].call(gt)
        v = track_value(tr, local, { w: w, off: gt - local, f: w[:f] })
        v = nil unless v.is_a?(Numeric)
      end
      w[:busy].delete(key)
      w[:memo][key] = v
    end

    def self.fx_src_progress(w, pid, prop, j, gt)
      st = fx_src_track(w, pid, prop) or return nil
      src, tr = st
      track_progress(tr, src[:local].call(gt), j)
    end

    # Avanzamento (0–1, nel tempo, senza curva) della transizione j (1 = la
    # prima) di una traccia al tempo locale t; nil se non c'è.
    def self.track_progress(tr, t, j)
      g = tr[:segs][j - 1] or return nil
      tau = t - tr[:delay]
      return 0.0 if tau <= 0
      c = tr[:cycle]
      return 1.0 if c <= 0
      case tr[:loop]
      when 'loop'
        tau %= c
      when 'pingpong'
        tau %= 2 * c
        tau = 2 * c - tau if tau > c
      else
        tau = c if tau > c
      end
      start = tr[:ends][j - 1] - g[:dur]
      return(tau >= start ? 1.0 : 0.0) if g[:dur] <= 0
      ((tau - start) / g[:dur]).clamp(0.0, 1.0)
    end

    # Il mondo durante la sessione: gli oggetti animati e il loro tempo
    def self.fx_world_session(s)
      { f: s[:ufac] || fx_factor, memo: {}, busy: {},
        src: lambda do |pid|
          it = s[:by_pid][pid]
          it && { tracks: it[:tracks], local: ->(gt) { item_local(s, it, gt) } }
        end }
    end

    # Fuori dalla sessione (traiettorie): ogni oggetto parte quando lo
    # porterebbe la timeline; gli azionati restano allo stato iniziale.
    def self.fx_world_model(model, list = animated_instances(model))
      starts = chain_starts(list)
      by = {}
      list.each { |x, d| by[x.persistent_id] = d }
      made = {}
      { f: unit_info(model)['factor'], memo: {}, busy: {}, starts: starts,
        src: lambda do |pid|
          next made[pid] if made.key?(pid)
          d = by[pid]
          st = starts[pid]
          made[pid] = d && { tracks: prepare_tracks(d), local: ->(gt) { st ? gt - st : -1.0 } }
        end }
    end

    # ── Controllo per il pannello ───────────────────────────────────
    # Le formule dell'oggetto pid con i dati data (anche non ancora
    # salvati): { "seq" => numero della richiesta, "errs" => { "i_j" =>
    # [chiave del messaggio, argomento] } } per ogni transizione a formula
    # che non si può calcolare.
    def self.fx_check(json)
      d = JSON.parse(json.to_s)
      out = { 'seq' => d['seq'], 'errs' => {} }
      model = Sketchup.active_model or return out
      pid = d['pid'].to_i
      data = sanitize_data(d['data'])
      graph = {}
      animated_instances(model).each { |x, xd| graph[x.persistent_id] = xd unless x.persistent_id == pid }
      graph[pid] = data
      out['errs'] = fx_problems(pid, data, graph)
      out
    rescue => dyn_err
      log_error(__method__, dyn_err)
      { 'seq' => nil, 'errs' => {} }
    end

    # graph: { pid => dati } di tutti gli oggetti animati (con questo)
    def self.fx_problems(pid, data, graph)
      out = {}
      data['tracks'].each_with_index do |tr, i|
        tr['keys'].each_with_index do |k, j|
          f = k['fx']
          next unless j > 0 && f && f['on']
          err = fx_problem(pid, tr, f, graph)
          out["#{i}_#{j}"] = err if err
        end
      end
      out
    end

    def self.fx_problem(pid, tr, f, graph)
      names = []
      f['params'].each do |p|
        n = p['n']
        return ['fx.e_pname', n] if n !~ FX_NAME || fx_reserved?(n) || names.include?(n)
        names << n
      end
      begin
        fx_compile(f['expr'], names)
      rescue FxError => err
        return ["fx.e_#{err.code}", err.arg]
      end
      f['params'].each do |p|
        return ['fx.e_src', p['n']] if p['pid'] == 0 || p['prop'].empty?
        src = graph[p['pid']]
        st = src && src['tracks'].find { |x| x['prop'] == p['prop'] && x['on'] }
        return ['fx.e_gone', p['n']] unless st && p['at'] < st['keys'].size
      end
      return ['fx.e_cycle', ''] if tr['on'] && fx_cycle?(graph, [pid, tr['prop']])
      nil
    end

    # La traccia node dipende da sé stessa, attraverso i parametri?
    def self.fx_cycle?(graph, node)
      seen = {}
      stack = fx_deps(graph, node)
      until stack.empty?
        n = stack.pop
        return true if n == node
        next if seen[n]
        seen[n] = true
        stack.concat(fx_deps(graph, n))
      end
      false
    end

    # Le tracce lette dalle formule della traccia node (solo i valori:
    # l'avanzamento di una transizione dipende dal tempo, non dai valori)
    def self.fx_deps(graph, node)
      d = graph[node[0]] or return []
      tr = d['tracks'].find { |x| x['prop'] == node[1] && x['on'] } or return []
      tr['keys'].drop(1).flat_map do |k|
        f = k['fx']
        f && f['on'] ? f['params'].select { |p| p['at'] == 0 }.map { |p| [p['pid'], p['prop']] } : []
      end
    end

  end
end
