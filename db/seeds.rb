# specs.md §8: canlı demoyu tek komutla hazırlar (`bin/rails db:seed`).
# Tekrar çalıştırılabilir; tarihler çalıştırıldığı güne göre hesaplanır.
# DEMO şifreleri README'de "demo" etiketiyle listelenir.

DEMO_PASSWORD = "senal-demo"

def demo_user(email, name:, role: :responder, academic_role: :staff)
  User.find_or_initialize_by(email_address: email).tap do |user|
    user.update!(name: name, role: role, academic_role: academic_role, password: DEMO_PASSWORD)
  end
end

ActiveRecord::Base.transaction do
  # --- Kullanıcılar: 1 manager, 4 responder (2'si asistan) ---
  manager = demo_user("yonetici@senal.test", name: "Selin Yönetici", role: :manager)
  ayse    = demo_user("ayse@senal.test", name: "Ayşe Kaya", academic_role: :assistant)
  mehmet  = demo_user("mehmet@senal.test", name: "Mehmet Arslan", academic_role: :assistant)
  burak   = demo_user("burak@senal.test", name: "Burak Demir")
  zeynep  = demo_user("zeynep@senal.test", name: "Zeynep Şahin")

  # --- Takvimler: 7 günlük rotasyon, ilk devir bu haftanın pazartesisi 09:00 ---
  rotation_start = Date.current.beginning_of_week.in_time_zone.change(hour: 9)
  rotation_start -= 7.days if rotation_start > Time.current

  schedules = {
    "BT Altyapı" => [ ayse, burak, mehmet ],
    "Laboratuvar" => [ mehmet, zeynep, ayse ]
  }.to_h do |name, members|
    schedule = Schedule.find_or_initialize_by(name: name)
    schedule.update!(starts_at: rotation_start, rotation_days: 7)
    schedule.schedule_memberships.destroy_all
    members.each_with_index { |user, position| schedule.schedule_memberships.create!(user: user, position: position) }
    [ name, schedule ]
  end

  # --- Eskalasyon politikası: 2 seviye, 5'er dk ---
  policy = EscalationPolicy.find_or_initialize_by(name: "Standart politika")
  policy.update!(repeat_count: 1)
  policy.escalation_levels.destroy_all
  policy.escalation_levels.create!(position: 0, schedule: schedules["BT Altyapı"], timeout_minutes: 5)
  policy.escalation_levels.create!(position: 1, schedule: schedules["Laboratuvar"], timeout_minutes: 5)

  # --- Servis ---
  service = Service.find_or_initialize_by(name: "Öğrenci Bilgi Sistemi")
  service.update!(escalation_policy: policy, ack_reset_minutes: 240)

  # --- Akademik takvim: yaklaşan vize haftası (yalnızca asistanlar) ---
  exam_week = BlackoutPeriod.find_or_initialize_by(name: "Güz Vize Haftası (demo)")
  exam_week.update!(kind: :exam_week, applies_to: :assistants,
                    starts_on: Date.current + 1, ends_on: Date.current + 5)

  # --- Kasıtlı boşluk: vize haftasında Laboratuvar'ın tek personeli Zeynep izinli ---
  # Mehmet ve Ayşe asistan (vize haftası), Zeynep izinli → o gün Laboratuvar'da nöbetçi yok.
  gap_day = (Date.current + 2).in_time_zone
  zeynep.unavailabilities.where(reason: "Konferans (demo)").destroy_all
  zeynep.unavailabilities.create!(starts_at: gap_day, ends_at: gap_day + 1.day, reason: "Konferans (demo)")

  # --- Farklı durumlarda 3 olay (yalnızca ilk çalıştırmada açılır) ---
  unless service.incidents.exists?
    Incident.trigger!(service: service, title: "Kayıt sayfası yanıt vermiyor",
                      dedup_key: "kayit-timeout", urgency: :high)

    Incident.trigger!(service: service, title: "Veritabanı diski %90 dolu",
                      dedup_key: "db-disk-90", urgency: :low)
            .acknowledge!(by: ayse)

    Incident.trigger!(service: service, title: "SSL sertifikası yakında doluyor",
                      dedup_key: "ssl-expiry", urgency: :low)
            .tap { |incident| incident.acknowledge!(by: burak) }
            .resolve!(by: burak)
  end

  puts "Seed tamam: #{User.count} kullanıcı, #{Schedule.count} takvim, #{Incident.count} olay. " \
       "Demo şifresi README'de. Yönetici: #{manager.email_address}"
end
