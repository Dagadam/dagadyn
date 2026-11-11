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
      load_lang
      sub = UI.menu('Plugins').add_submenu('DagaDyn')
      sub.add_item(t('menu.panel')) { show_panel }
      sub.add_separator
      sub.add_item(t('menu.play'))  { cmd_toggle }
      sub.add_item(t('menu.stop'))  { cmd_stop }
      sub.add_item(t('menu.use'))   { start_use_tool }

      tb = UI::Toolbar.new('DagaDyn')
      cmd_panel = UI::Command.new('DagaDyn') { show_panel }
      cmd_panel.tooltip = t('tip.panel')
      cmd_panel.status_bar_text = t('tip.panel')
      icon(cmd_panel, 'dyn')
      tb.add_item(cmd_panel)

      cmd_play = UI::Command.new('DagaDyn Play') { cmd_toggle }
      cmd_play.tooltip = t('tip.play')
      cmd_play.status_bar_text = t('tip.play')
      icon(cmd_play, 'play')
      cmd_play.set_validation_proc { playing? ? MF_CHECKED : MF_UNCHECKED } if cmd_play.respond_to?(:set_validation_proc)
      tb.add_item(cmd_play)

      cmd_stop = UI::Command.new('DagaDyn Stop') { cmd_stop }
      cmd_stop.tooltip = t('tip.stop')
      cmd_stop.status_bar_text = t('tip.stop')
      icon(cmd_stop, 'stop')
      cmd_stop.set_validation_proc { @session ? MF_ENABLED : MF_GRAYED } if cmd_stop.respond_to?(:set_validation_proc)
      tb.add_item(cmd_stop)

      cmd_use = UI::Command.new('DagaDyn Aziona') { start_use_tool }
      cmd_use.tooltip = t('tip.use')
      cmd_use.status_bar_text = t('tip.use')
      icon(cmd_use, 'use')
      cmd_use.set_validation_proc { use_tool_on? ? MF_CHECKED : MF_UNCHECKED } if cmd_use.respond_to?(:set_validation_proc)
      tb.add_item(cmd_use)
      tb.restore
    end

  end
end
