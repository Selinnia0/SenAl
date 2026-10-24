# Z8: Önümüzdeki ufukta tüm takvimleri tarar; boşluk varsa her yöneticiye tek bildirim gönderir.
class GapReport
  TIME_FORMAT = "%d.%m.%Y %H:%M".freeze

  def self.run!(horizon: 7.days)
    new(from: Time.current, to: Time.current + horizon).run!
  end

  def initialize(from:, to:)
    @from = from
    @to = to
  end

  # Boşluklu takvimleri { Schedule => [Range<Time>] } olarak döner.
  def findings
    @findings ||= Schedule.order(:name).each_with_object({}) do |schedule, result|
      gaps = schedule.gaps(from: @from, to: @to)
      result[schedule] = gaps if gaps.any?
    end
  end

  def run!
    return [] if findings.empty?

    User.manager.map { |manager| manager.notifications.create!(message: message) }
  end

  def message
    lines = findings.map do |schedule, gaps|
      ranges = gaps.map { |gap| "#{format_time(gap.begin)} – #{format_time(gap.end)}" }
      "#{schedule.name}: #{ranges.join(', ')}"
    end
    "Nöbet boşluğu (önümüzdeki #{format_time(@from)} – #{format_time(@to)}):\n#{lines.join("\n")}"
  end

  private
    def format_time(time)
      time.in_time_zone.strftime(TIME_FORMAT)
    end
end
