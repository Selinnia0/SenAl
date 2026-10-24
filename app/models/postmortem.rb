class Postmortem < ApplicationRecord
  belongs_to :incident

  scope :published, -> { where.not(published_at: nil) }

  validates :incident_id, uniqueness: true
  validates :body, presence: true, if: :published?

  def published?
    published_at.present?
  end

  def publish!
    update!(published_at: Time.current)
  end
end
