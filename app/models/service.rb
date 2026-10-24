class Service < ApplicationRecord
  belongs_to :escalation_policy
  has_many :alerts, dependent: :restrict_with_error
  has_many :incidents, dependent: :restrict_with_error

  # Türetilmiş alan: callback yalnızca anahtarı üretir, iş mantığı yok.
  before_validation :generate_integration_key, on: :create

  validates :name, presence: true, uniqueness: true
  validates :integration_key, presence: true, uniqueness: true
  validates :ack_reset_minutes, numericality: { only_integer: true, greater_than: 0 }

  private
    def generate_integration_key
      self.integration_key ||= SecureRandom.hex(16)
    end
end
