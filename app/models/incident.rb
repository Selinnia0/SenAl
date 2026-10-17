class Incident < ApplicationRecord
  class InvalidTransition < StandardError; end

  # specs.md §4: durum → gidilebilecek durumlar.
  ALLOWED_TRANSITIONS = {
    "triggered" => %w[acknowledged resolved],
    "acknowledged" => %w[resolved triggered],
    "resolved" => []
  }.freeze

  belongs_to :service
  belongs_to :assignee, class_name: "User", optional: true
  has_many :incident_events, -> { order(:occurred_at) }, dependent: :destroy, inverse_of: :incident
  has_many :notifications, dependent: :destroy

  enum :status, { triggered: 0, acknowledged: 1, resolved: 2 }, validate: true
  enum :urgency, { high: 0, low: 1 }, validate: true

  validates :title, :dedup_key, :triggered_at, presence: true
  validates :dedup_key, uniqueness: { scope: :service_id, conditions: -> { not_resolved } }, unless: :resolved?
  # Savunma katmanı: ham update(status:) veya enum bang metotları da geçiş kuralına tabi.
  validate :status_transition_allowed, on: :update

  # Yeni olay açar ve seviye 0'ı bildirir. Tekilleştirme EventIngestor'da.
  def self.trigger!(service:, title:, dedup_key:, urgency:)
    transaction do
      incident = create!(service: service, title: title, dedup_key: dedup_key, urgency: urgency,
                         status: :triggered, triggered_at: Time.current)
      incident.record_event!("triggered")
      incident.notify_current_level!
      incident
    end
  end

  # Bildirim mantığının tek yeri: şu anki seviyenin nöbetçisini bulur, bildirir, assignee atar,
  # high ise bir sonraki eskalasyon anını ayarlar. Callback değil, açıkça çağrılır.
  def notify_current_level!
    level = current_escalation_level
    on_call = level && OnCall.for(level.schedule, at: Time.current)

    transaction do
      if on_call
        notifications.create!(user: on_call)
        self.assignee = on_call
        record_event!("notified", details: { user_id: on_call.id, user_name: on_call.name,
                                             level: current_level, round: escalation_round })
      end
      self.escalate_at = high? && level ? Time.current + level.timeout_minutes.minutes : nil
      save!
    end
  end

  def current_escalation_level
    service.escalation_policy.escalation_levels.find_by(position: current_level)
  end

  def record_event!(kind, user: nil, details: {})
    incident_events.create!(kind: kind, user: user, details: details, occurred_at: Time.current)
  end

  def acknowledge!(by:)
    transition_to!(:acknowledged, user: by) do
      self.acknowledged_at = Time.current
      self.escalate_at = nil
    end
  end

  def resolve!(by:)
    transition_to!(:resolved, user: by) do
      self.resolved_at = Time.current
      self.escalate_at = nil
    end
  end

  # Yalnızca sistem çağırır (Z3).
  def retrigger!
    transition_to!(:triggered, kind: "retriggered") do
      self.acknowledged_at = nil
      self.current_level = 0
      self.escalation_round = 0
    end
  end

  def can_transition_to?(new_status)
    ALLOWED_TRANSITIONS.fetch(status).include?(new_status.to_s)
  end

  def can_acknowledge?
    can_transition_to?(:acknowledged)
  end

  def can_resolve?
    can_transition_to?(:resolved)
  end

  private
    def transition_to!(new_status, kind: new_status.to_s, user: nil)
      unless can_transition_to?(new_status)
        raise InvalidTransition, "#{status} → #{new_status} geçişine izin verilmiyor (olay ##{id})"
      end

      transaction do
        self.status = new_status
        yield
        save!
        record_event!(kind, user: user)
      end
    end

    def status_transition_allowed
      return unless will_save_change_to_status?

      from, to = status_change_to_be_saved
      return if ALLOWED_TRANSITIONS.fetch(from).include?(to)

      errors.add(:status, :invalid_transition, message: "#{from} → #{to} geçişine izin verilmiyor")
    end
end
