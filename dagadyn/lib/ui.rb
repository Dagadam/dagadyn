# DagaDyn — Menu Plugins e barra degli strumenti.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    def self.icon(cmd, name)
      idir = File.join(PLUGIN_DIR, 'icons')
      si = File.join(idir, "#{name}_24.png"); li = File.join(idir, "#{name}_32.png")
      cmd.small_icon = si if File.exist?(si)
      cmd.large_icon = li if File.exist?(li)
    end

    def self.register_ui
      load_cfg
      load_lang(true)      # con DagaWASD, menu e barra nella sua lingua
      sub = UI.menu('Plugins').add_submenu('DagaDyn')
      sub.add_item(t('menu.panel')) { show_panel }
      sub.add_separator
      sub.add_item(t('menu.play'))  { cmd_toggle }
      sub.add_item(t('menu.stop'))  { cmd_stop }
      sub.add_item(t('menu.use'))   { start_use_tool }

      tb = UI::Toolbar.new('DagaDyn')
      btn_panel = UI::Command.new('DagaDyn') { show_panel }
      btn_panel.tooltip = t('tip.panel')
      btn_panel.status_bar_text = t('tip.panel')
      icon(btn_panel, 'dyn')
      tb.add_item(btn_panel)

      btn_play = UI::Command.new('DagaDyn Play') { cmd_toggle }
      btn_play.tooltip = t('tip.play')
      btn_play.status_bar_text = t('tip.play')
      icon(btn_play, 'play')
      btn_play.set_validation_proc { playing? ? MF_CHECKED : MF_UNCHECKED } if btn_play.respond_to?(:set_validation_proc)
      tb.add_item(btn_play)

      btn_stop = UI::Command.new('DagaDyn Stop') { cmd_stop }
      btn_stop.tooltip = t('tip.stop')
      btn_stop.status_bar_text = t('tip.stop')
      icon(btn_stop, 'stop')
      btn_stop.set_validation_proc { @session ? MF_ENABLED : MF_GRAYED } if btn_stop.respond_to?(:set_validation_proc)
      tb.add_item(btn_stop)

      btn_use = UI::Command.new('DagaDyn Aziona') { start_use_tool }
      btn_use.tooltip = t('tip.use')
      btn_use.status_bar_text = t('tip.use')
      icon(btn_use, 'use')
      btn_use.set_validation_proc { use_tool_on? ? MF_CHECKED : MF_UNCHECKED } if btn_use.respond_to?(:set_validation_proc)
      tb.add_item(btn_use)
      tb.restore
    end

  end
end
