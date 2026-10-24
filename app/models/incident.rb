# v2 response katmanı: ilan edilen olay. Durum makinesi, iş kuralları ve zaman çizelgesi burada.
# Bütün geçişler transition_to! üzerinden geçer; enum bang metotları (closed! gibi) domain kodunda
# kullanılmaz ve status_transition_allowed doğrulamasıyla engellenir.
class Incident < ApplicationRecord
  class InvalidTransition < StandardError; end
  # Geçiş grafikte var ama bir iş kuralı engelliyor (ör. postmortem yayınlanmadı).
  class TransitionBlocked < InvalidTransition; end
  class NotPermitted < StandardError; end

  # Durum → gidilebilecek durumlar (izin listesi). Listede olmayan her geçiş yasak.
  ALLOWED_TRANSITIONS = {
    "triage" => %w[investigating declined],
    "investigating" => %w[fixing monitoring resolved],
    "fixing" => %w[monitoring resolved],
    "monitoring" => %w[resolved investigating],
    "resolved" => %w[closed investigating],
    "closed" => [],
    "declined" => []
  }.freeze

  # Geri dönüşler zaman çizelgesine "reopened" olarak düşer.
  REOPENINGS = [ %w[monitoring investigating], %w[resolved investigating] ].freeze
  ACTIVE_STATUSES = %w[triage investigating fixing monitoring].freeze
  FINAL_STATUSES = %w[closed declined].freeze

  belongs_to :service
  belongs_to :alert, optional: true
  has_many :role_assignments, class_name: "IncidentRoleAssignment", dependent: :destroy
  has_one :lead_assignment, -> { where(role: :lead) }, class_name: "IncidentRoleAssignment", inverse_of: :incident
  has_many :timeline_events, -> { order(:occurred_at, :id) }, dependent: :destroy, inverse_of: :incident
  has_many :status_page_updates, -> { order(:published_at, :id) }, dependent: :destroy, inverse_of: :incident
  has_one :postmortem, dependent: :destroy
  has_many :follow_ups, dependent: :destroy
  has_many :notifications, dependent: :destroy

  enum :severity, { critical: 0, major: 1, minor: 2 }, validate: true
  enum :status, { triage: 0, investigating: 1, fixing: 2, monitoring: 3, resolved: 4, closed: 5, declined: 6 },
       validate: true

  scope :active, -> { where(status: ACTIVE_STATUSES) }

  validates :title, :declared_at, :last_update_at, presence: true
  validates :lead_assignment, presence: true
  validate :status_transition_allowed, on: :update

  # Olay ilan eder. Lead zorunlu. Alert'ten ilan edilirse alert ilan eden adına "Gördüm" olur.
  def self.declare!(service:, title:, severity:, lead:, by:, summary: nil, public_impact: false,
                    communications: nil, alert: nil)
    transaction do
      incident = new(service: service, alert: alert, title: title, summary: summary, severity: severity,
                     public_impact: public_impact, status: :triage,
                     declared_at: Time.current, last_update_at: Time.current)
      incident.build_lead_assignment(user: lead) if lead
      incident.save!
      incident.role_assignments.create!(role: :communications, user: communications) if communications
      incident.record!(:status_change, user: by, body: "Olay ilan edildi", details: { from: nil, to: "triage" })
      alert.acknowledge!(by: by) if alert&.can_acknowledge?
      incident
    end
  end

  def lead
    lead_assignment&.user
  end

  def communications_lead
    role_assignments.find_by(role: :communications)&.user
  end

  def active?
    ACTIVE_STATUSES.include?(status)
  end

  def final?
    FINAL_STATUSES.include?(status)
  end

  def postmortem_required?
    !minor?
  end

  def can_transition_to?(new_status)
    ALLOWED_TRANSITIONS.fetch(status).include?(new_status.to_s)
  end

  def available_transitions
    ALLOWED_TRANSITIONS.fetch(status)
  end

  # Tek geçiş noktası: izin listesi → iş kuralları → durum + zaman damgası + zaman çizelgesi (tek transaction).
  def transition_to!(new_status, by:)
    new_status = new_status.to_s
    from = status
    unless can_transition_to?(new_status)
      raise InvalidTransition, "#{status_label(from)} → #{status_label(new_status)} geçişine izin verilmiyor (olay ##{id})"
    end
    check_preconditions!(new_status, by)

    transaction do
      self.status = new_status
      self.last_update_at = Time.current
      self.update_reminder_sent_at = nil
      self.resolved_at = Time.current if new_status == "resolved"
      self.resolved_at = nil if from == "resolved" && new_status == "investigating"
      self.closed_at = Time.current if new_status == "closed"
      save!

      kind = REOPENINGS.include?([ from, new_status ]) ? :reopened : :status_change
      record!(kind, user: by, details: { from: from, to: new_status })
      finish_resolution!(by) if new_status == "resolved"
    end
  end

  def post_update!(body:, by:)
    ensure_open_for_updates!

    transaction do
      record!(:update, user: by, body: body)
      update!(last_update_at: Time.current, update_reminder_sent_at: nil)
    end
  end

  def publish_status_update!(public_status:, message:, by:)
    ensure_open_for_updates!

    transaction do
      status_page_update = status_page_updates.create!(public_status: public_status, message: message,
                                                       published_at: Time.current)
      record!(:update, user: by, body: "Durum sayfası: #{message}", details: { status_page: public_status.to_s })
      update!(last_update_at: Time.current, update_reminder_sent_at: nil)
      status_page_update
    end
  end

  # Aynı severity için kayıt yazmaz ve false döner.
  def change_severity!(new_severity, by:)
    return false if severity == new_severity.to_s

    transaction do
      from = severity
      update!(severity: new_severity)
      record!(:severity_change, user: by, details: { from: from, to: severity })
    end
    true
  end

  # Rolü atar ya da değiştirir. Lead kaldırılamaz (user nil → RecordInvalid).
  def assign_role!(role, user:, by:)
    assignment = role_assignments.find_or_initialize_by(role: role)
    previous = assignment.user

    transaction do
      assignment.update!(user: user)
      record!(:role_change, user: by, details: { role: role.to_s, from_user_id: previous&.id,
                                                 to_user_id: user.id, to_user_name: user.name })
    end
    association(:lead_assignment).reset
    assignment
  end

  def record!(kind, user: nil, body: nil, details: {})
    timeline_events.create!(kind: kind, user: user, body: body, details: details, occurred_at: Time.current)
  end

  private
    def check_preconditions!(new_status, by)
      case new_status
      when "resolved"
        if public_impact? && status_page_updates.none?
          raise TransitionBlocked, "Halka açık etkisi olan olay, durum sayfası güncellemesi yayınlanmadan çözülemez"
        end
      when "closed"
        raise NotPermitted, "Olayı yalnızca olay lideri veya yönetici kapatabilir" unless by&.manager? || by == lead
        if postmortem_required? && !postmortem&.published?
          raise TransitionBlocked, "Postmortem yayınlanmadan #{severity} olay kapatılamaz"
        end
        raise TransitionBlocked, "Tamamlanmamış takip görevleri var" if follow_ups.open.exists?
      end
    end

    # Çözülünce: halka açık olayda durum sayfasına otomatik "resolved", bağlı açık alert de çözülür.
    def finish_resolution!(by)
      if public_impact?
        status_page_updates.create!(public_status: :resolved, published_at: Time.current,
                                    message: "Sorun giderildi. Sistemler normal çalışıyor.")
      end
      alert.resolve!(by: by) if alert&.can_resolve?
    end

    def ensure_open_for_updates!
      raise InvalidTransition, "#{status_label(status)} olaya güncelleme yazılamaz (olay ##{id})" if final?
    end

    def status_label(value)
      I18n.t("enums.incident.status.#{value}", default: value.to_s)
    end

    def status_transition_allowed
      return unless will_save_change_to_status?

      from, to = status_change_to_be_saved
      return if ALLOWED_TRANSITIONS.fetch(from).include?(to)

      errors.add(:status, :invalid_transition, message: "#{from} → #{to} geçişine izin verilmiyor")
    end
end
