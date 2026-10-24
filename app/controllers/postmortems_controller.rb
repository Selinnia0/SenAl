class PostmortemsController < ApplicationController
  include IncidentScoped

  before_action :set_incident
  before_action :set_postmortem

  def edit
  end

  def update
    if @postmortem.update(params.expect(postmortem: [ :body ]))
      broadcast_incident_change
      redirect_to edit_incident_postmortem_path(@incident), notice: "Postmortem kaydedildi."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def publish
    # Yayınlanan postmortem'de metin zorunlu (Postmortem doğrulaması); boşsa RecordInvalid → uyarı mesajı.
    run_incident_action("Postmortem yayınlandı.") { @postmortem.publish! }
  end

  private
    def set_postmortem
      @postmortem = @incident.postmortem || @incident.build_postmortem
    end
end
