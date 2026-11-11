# DagaDyn — Win32: appunti per il menu del pannello, finestre fuori dallo schermo.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
# Le stesse funzioni di DagaWASD (lib/input.rb, lib/keyedit.rb), ridotte a
# ciò che serve al pannello. Facoltative: senza Windows il pannello funziona
# lo stesso, senza «Incolla» dal menu del destro.
module DagaDyn
  module Dyn

    def self.ensure_win32
      return true  if @w32
      return false if @w32_error
      unless Sketchup.platform == :platform_win
        @w32_error = 'not windows'
        return false
      end
      begin
        require 'fiddle'
        require 'fiddle/import'
        m = Module.new
        m.extend(Fiddle::Importer)
        m.dlload('user32', 'kernel32')
        m.module_eval do
          extern 'void* MonitorFromRect(void*, int)'
          extern 'int   IsClipboardFormatAvailable(int)'
          extern 'int   OpenClipboard(void*)'
          extern 'int   CloseClipboard()'
          extern 'void* GetClipboardData(int)'
          extern 'void* GlobalLock(void*)'
          extern 'int   GlobalUnlock(void*)'
          extern 'void* GlobalSize(void*)'
        end
        @w32 = m
        true
      rescue => e
        @w32_error = e.message
        false
      end
    end

    # Una finestra che ricorda la sua posizione (preferences_key) si riapre
    # dov'era, anche se lì ora non c'è più un monitor: sembra che non si
    # apra. Se la barra del titolo non cade su nessun monitor la si rimette
    # al centro.
    def self.dialog_on_screen(d)
      return unless d.respond_to?(:get_position) && ensure_win32   # get_position: SketchUp 2021+
      x, y = d.get_position
      w, = d.get_size
      s = UI.respond_to?(:scale_factor) ? UI.scale_factor : 1.0
      rect = [x + 40, y, x + w - 40, y + 24].map { |v| (v * s).round }.pack('l<4')
      d.center if @w32.MonitorFromRect(rect, 0).to_i == 0          # 0: MONITOR_DEFAULTTONULL
    rescue => dyn_err; log_error(__method__, dyn_err); end

    # Testo negli appunti di Windows, per «Incolla» del menu del pannello: la
    # pagina non può leggerli da sola. '' se non c'è testo.
    CF_UNICODETEXT = 13
    def self.clipboard_text
      return '' unless ensure_win32 && @w32.IsClipboardFormatAvailable(CF_UNICODETEXT) != 0
      return '' if @w32.OpenClipboard(nil).zero?
      begin
        h = @w32.GetClipboardData(CF_UNICODETEXT)
        return '' if h.to_i.zero?
        p = @w32.GlobalLock(h)
        return '' if p.to_i.zero?
        begin
          n = [@w32.GlobalSize(h).to_i, 1 << 16].min & ~1              # al più 32 000 caratteri
          raw = Fiddle::Pointer.new(p.to_i)[0, n]
          raw = raw[0, raw.unpack('v*').index(0).to_i * 2] if raw.unpack('v*').include?(0)
          raw.force_encoding('UTF-16LE').encode('UTF-8', invalid: :replace, undef: :replace)
        ensure
          @w32.GlobalUnlock(h)
        end
      ensure
        @w32.CloseClipboard
      end
    rescue => dyn_err
      log_error(__method__, dyn_err)
      ''
    end

  end
end
