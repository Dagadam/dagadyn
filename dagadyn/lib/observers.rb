# DagaDyn — Osservatori: modello aperto, salvataggio, annulla, selezione.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    # Nuovo e Apri: documento nuovo, anche quando (Windows) l'oggetto Model
    # di Ruby è lo stesso di prima. Activate (Mac, più documenti aperti):
    # uno già agganciato.
    class AppObs < Sketchup::AppObserver
      def onNewModel(model);      Dyn.model_changed(model, true); end
      def onOpenModel(model);     Dyn.model_changed(model, true); end
      def onActivateModel(model); Dyn.model_changed(model); end
    end

    class ModelObs < Sketchup::ModelObserver
      def onPreSaveModel(_m);  Dyn.session_suspend; end
      def onPostSaveModel(_m); Dyn.session_resume; end
      def onTransactionUndo(m); Dyn.anim_dirty; Dyn.copies_known(m); Dyn.after_undo(-1); end
      def onTransactionRedo(m); Dyn.anim_dirty; Dyn.copies_known(m); Dyn.after_undo(1); end
      def onTransactionAbort(_m); Dyn.anim_dirty; end
      def onTransactionCommit(_m)
        Dyn.anim_dirty                      # copie, eliminazioni, importazioni
        return if Dyn.own_op?
        Dyn.op_break
        Dyn.section_adopt_soon
        Dyn.panel_selection_soon
        Dyn.paths_dirty unless Dyn.external?
      end
    end

    class SelObs < Sketchup::SelectionObserver
      def onSelectionBulkChange(_s); Dyn.panel_selection_soon; Dyn.paths_dirty; end
      def onSelectionCleared(_s);    Dyn.panel_selection_soon; Dyn.paths_dirty; end
      def onSelectionAdded(_s, _e);  Dyn.panel_selection_soon; end
      def onSelectionRemoved(_s, _e); Dyn.panel_selection_soon; end
    end

    def self.observe_app
      return if @app_obs
      @app_obs = AppObs.new
      Sketchup.add_observer(@app_obs)
      model_changed(Sketchup.active_model)
    end

    # Un altro modello: la sessione del precedente non vale più (il modello
    # è chiuso o non è quello attivo). Materiali temporanei rimasti in un
    # file salvato a metà sessione da un'altra estensione: via.
    # fresh: documento nuovo o appena aperto. Su Windows l'oggetto Model può
    # essere lo stesso del documento di prima, ma osservatori e Overlay
    # agganciati là sono stati staccati: si riagganciano, e la sessione di
    # quel documento finisce.
    def self.model_changed(model, fresh = false)
      anim_dirty
      if @session && (fresh || @session[:model] != model)
        driver_stop
        @session = nil
      end
      observe_model(model, fresh)
      UI.start_timer(0, false) do
        purge_temp_materials(model) if model && model.valid? && !@session
        copies_known(model)              # gli oggetti di partenza: le copie si riconoscono da qui
      end
      panel_transport
      panel_selection
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    def self.observe_model(model, fresh = false)
      return unless model
      @observed.delete_if { |m, _| !m.valid? }
      if (old = @observed[model])
        return overlay_attach(model) unless fresh
        mo, so = old                          # quelli del documento di prima: via
        (model.remove_observer(mo) rescue nil)
        (model.selection.remove_observer(so) rescue nil)
      end
      mo = ModelObs.new
      so = SelObs.new
      model.add_observer(mo)
      model.selection.add_observer(so)
      @observed[model] = [mo, so]
      overlay_attach(model)
    end

    # Annulla / ripeti durante una sessione: può aver cambiato le tracce
    # (una modifica dal pannello annullata), tolto un materiale temporaneo o
    # rimesso una trasformazione. Si rileggono i dati e ogni oggetto riparte
    # dal suo riposo. La voce della sessione può essere sparita: la prossima
    # operazione ne apre una nuova invece di accodarsi a quella dell'utente.
    def self.after_undo(dir = -1)
      paths_dirty
      panel_selection_soon
      return ended_step(dir) unless @session
      @session[:depth] = @session[:depth].to_i + dir
      UI.start_timer(0, false) do
        begin
          s = @session
          if s && s[:model].valid?
            s[:first_op] = true
            s[:items].delete_if { |e, _| !e.valid? }
            s[:by_pid].delete_if { |_k, it| !s[:items].value?(it) }
            now = animated_instances(s[:model]).to_h
            (s[:items].keys | now.keys).each { |e| session_update(e, now[e], true) }
            session_updated
            s[:model].active_view.invalidate
          end
        rescue => dyn_err
          log_error(:after_undo, dyn_err)
        end
      end
    end

  end
end
