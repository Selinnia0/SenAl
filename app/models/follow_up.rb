# Olaydan çıkan takip görevi. Hepsi tamamlanmadan olay kapanamaz.
class FollowUp < ApplicationRecord
  belongs_to :incident
  belongs_to :owner, class_name: "User"

  scope :open, -> { where(completed_at: nil) }

  validates :title, presence: true

  def completed?
    completed_at.present?
  end

  def complete!
    update!(completed_at: Time.current)
  end
end
