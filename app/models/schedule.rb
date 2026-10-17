class Schedule < ApplicationRecord
  has_many :schedule_memberships, -> { order(:position) }, dependent: :destroy, inverse_of: :schedule
  has_many :members, through: :schedule_memberships, source: :user
  has_many :overrides, dependent: :destroy
  has_many :escalation_levels, dependent: :restrict_with_error

  validates :name, :starts_at, presence: true
  validates :rotation_days, numericality: { only_integer: true, greater_than: 0 }

  GAP_SAMPLE_STEP = 1.hour

  # Z5: [from, to) aralığında nöbetçinin nil olduğu dilimler. 1 saatlik örnekleme;
  # ardışık boş saatler tek aralıkta birleşir. Dönüş: [Range<Time>] (bitiş hariç).
  def gaps(from:, to:)
    on_call = OnCall.new(self)
    gaps = []
    gap_start = nil
    time = from

    while time < to
      if on_call.user_at(time).nil?
        gap_start ||= time
      elsif gap_start
        gaps << (gap_start...time)
        gap_start = nil
      end
      time += GAP_SAMPLE_STEP
    end

    gaps << (gap_start...to) if gap_start
    gaps
  end
end
