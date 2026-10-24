class Schedule < ApplicationRecord
  has_many :schedule_memberships, -> { order(:position) }, dependent: :destroy, inverse_of: :schedule
  has_many :members, through: :schedule_memberships, source: :user
  has_many :overrides, dependent: :destroy
  has_many :escalation_levels, dependent: :restrict_with_error

  validates :name, :starts_at, presence: true
  validates :rotation_days, numericality: { only_integer: true, greater_than: 0 }

  GAP_SAMPLE_STEP = 1.hour

  # Takvim sayfasındaki bir gün: o gün nöbet tutan kişiler ve boşluk olup olmadığı.
  Day = Data.define(:date, :users, :gap)

  # [from, to) aralığında saatlik örnekler: [[Time, User | nil], ...]. İlk örnek from anında,
  # sonrakiler tam saat başlarında; böylece boşluk sınırları from'un dakikasına göre kaymaz.
  def on_call_samples(from:, to:)
    on_call = OnCall.new(self)
    samples = []
    time = from
    while time < to
      samples << [ time, on_call.user_at(time) ]
      time = time.beginning_of_hour + GAP_SAMPLE_STEP
    end
    samples
  end

  # Z8: [from, to) aralığında nöbetçinin nil olduğu dilimler. 1 saatlik örnekleme;
  # ardışık boş saatler tek aralıkta birleşir. Dönüş: [Range<Time>] (bitiş hariç).
  def gaps(from:, to:)
    gaps = []
    gap_start = nil

    on_call_samples(from: from, to: to).each do |time, user|
      if user.nil?
        gap_start ||= time
      elsif gap_start
        gaps << (gap_start...time)
        gap_start = nil
      end
    end

    gaps << (gap_start...to) if gap_start
    gaps
  end

  # Istanbul gün sınırlarıyla günlük özet (takvim sayfasının 14 günlük tablosu).
  def on_call_days(from_date:, days:)
    from = from_date.in_time_zone
    on_call_samples(from: from, to: from + days.days)
      .group_by { |time, _user| time.to_date }
      .map do |date, samples|
        users = samples.map(&:last)
        Day.new(date: date, users: users.compact.uniq, gap: users.include?(nil))
      end
  end
end
