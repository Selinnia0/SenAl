# Z2: Belirli bir anda takvimin nöbetçisi. Saf hesap, hiçbir kayıt yazmaz.
class OnCall
  def self.for(schedule, at:)
    new(schedule).user_at(at)
  end

  def initialize(schedule)
    @schedule = schedule
  end

  def user_at(time)
    # 1. Override bilinçli bir karardır: müsaitlik kontrolü yapılmaz.
    override = @schedule.overrides.covering(time).order(created_at: :desc).first
    return override.user if override

    return nil if time < @schedule.starts_at

    members = @schedule.schedule_memberships.includes(:user).map(&:user)
    return nil if members.empty?

    # 2. Rotasyon sırası; 3. o anda müsait olan ilk üye (Z6).
    base_index = slot_at(time) % members.size
    members.rotate(base_index).find { |member| member.available_at?(time) }
  end

  private
    def slot_at(time)
      ((time - @schedule.starts_at) / @schedule.rotation_days.days.to_i).floor
    end
end
