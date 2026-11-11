# DagaDyn — Osservatori: modello aperto, salvataggio, annulla, selezione.
# Parte di DagaDyn::Dyn, caricata da main.rb (che elenca tutti i file e il loro ordine).
module DagaDyn
  module Dyn

    class AppObs < Sketchup::AppObserver
      def onNewModel(model);      Dyn.model_changed(model); end
      def onOpenModel(model);     Dyn.model_changed(model); end
      def onActivateModel(model); Dyn.model_changed(model); end   # Mac: più documenti aperti
    end

    class ModelObs < Sketchup::ModelObserver
      def onPreSaveModel(_m);  Dyn.session_suspend; end
      def onPostSaveModel(_m); Dyn.session_resume; end
      def onTransactionUndo(_m); Dyn.after_undo; end
      def onTransactionRedo(_m); Dyn.after_undo; end
      def onTransactionCommit(_m)
        return if Dyn.own_op?
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
    def self.model_changed(model)
      if @session && @session[:model] != model
        driver_stop
        @session = nil
      end
      observe_model(model)
      UI.start_timer(0, false) { purge_temp_materials(model) if model && model.valid? && !@session }
      panel_transport
      panel_selection
    rescue => dyn_err
      log_error(__method__, dyn_err)
    end

    def self.observe_model(model)
      return unless model
      @observed.delete_if { |m, _| !m.valid? }
      return if @observed[model]
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
    def self.after_undo
      paths_dirty
      panel_selection_soon
      return unless @session
      UI.start_timer(0, false) do
        begin
          s = @session
          if s && s[:model].valid?
            s[:first_op] = true
            s[:items].delete_if { |e, _| !e.valid? }
            s[:by_pid].delete_if { |_k, it| !s[:items].value?(it) }
            now = animated_instances(s[:model]).to_h
            (s[:items].keys | now.keys).each { |e| session_update(e, now[e]) }
            s[:model].active_view.invalidate
          end
        rescue => dyn_err
          log_error(:after_undo, dyn_err)
        end
      end
    end

  end
end
