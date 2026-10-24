# specs.md §6: dış sistemden gelen olay gövdesini ayrıştırır ve uygular. PORO.
class EventIngestor
  Result = Data.define(:http_status, :body)

  HIGH_SEVERITIES = %w[critical error].freeze
  LOW_SEVERITIES = [ "warning", "info", nil ].freeze

  def initialize(service)
    @service = service
  end

  def call(payload)
    case payload
    in { event_action: "trigger", dedup_key: String => key, summary: String => summary, **rest } if key.present? && summary.present?
      urgency = urgency_for(rest[:severity])
      return error(:unprocessable_entity, "Bilinmeyen severity: #{rest[:severity].inspect}") unless urgency

      trigger(key, summary, urgency)
    in { event_action: "acknowledge" | "resolve" => action, dedup_key: String => key } if key.present?
      transition(action, key)
    else
      error(:unprocessable_entity, "Geçersiz olay gövdesi: event_action (trigger/acknowledge/resolve) ve dedup_key zorunlu; trigger için summary zorunlu")
    end
  end

  private
    def urgency_for(severity)
      if HIGH_SEVERITIES.include?(severity) then :high
      elsif LOW_SEVERITIES.include?(severity) then :low
      end
    end

    def trigger(key, summary, urgency)
      Alert.transaction do
        if (existing = open_alert(key))
          existing.record_event!("deduplicated", details: { summary: summary })
          accepted("deduplicated", existing)
        else
          accepted("triggered", Alert.trigger!(service: @service, title: summary, dedup_key: key, urgency: urgency))
        end
      end
    end

    def transition(action, key)
      alert = open_alert(key)
      return error(:not_found, "Bu dedup_key için açık olay yok: #{key}") unless alert

      action == "acknowledge" ? alert.acknowledge!(by: nil) : alert.resolve!(by: nil)
      accepted(alert.status, alert)
    rescue Alert::InvalidTransition => e
      error(:conflict, e.message)
    end

    def open_alert(key)
      @service.alerts.not_resolved.find_by(dedup_key: key)
    end

    def accepted(status, alert)
      Result.new(http_status: :accepted, body: { status: status, alert_id: alert.id, dedup_key: alert.dedup_key })
    end

    def error(http_status, message)
      Result.new(http_status: http_status, body: { error: message })
    end
end
