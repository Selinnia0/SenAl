# Halka açık durum sayfasına yayınlanan güncelleme.
class StatusPageUpdate < ApplicationRecord
  belongs_to :incident

  enum :public_status, { investigating: 0, identified: 1, monitoring: 2, resolved: 3 }, prefix: :public, validate: true

  validates :message, :published_at, presence: true
end
