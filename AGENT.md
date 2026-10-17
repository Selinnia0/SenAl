# AGENT.md — SenAl

## 1. Proje

**SenAl**, üniversite BT birimleri ve araştırma laboratuvarları için müsaitlik farkındalıklı bir nöbet ve olay müdahale (on-call & incident response) uygulamasıdır (Rails 8).
Ne yapılacağı: [docs/specs.md](docs/specs.md). Hangi sırayla: [docs/plan.md](docs/plan.md). Kod İngilizce, arayüz Türkçe.

## 2. Domain sözlüğü (TR ↔ EN)

| Türkçe (arayüz) | İngilizce (kod) | Anlamı |
|---|---|---|
| Olay | `Incident` | Bir alarmın ürettiği, müdahale gerektiren kayıt |
| Servis | `Service` | Alarmın geldiği sistem (ör. "Öğrenci Bilgi Sistemi") |
| Entegrasyon anahtarı | `integration_key` | Dış sistemin alarm göndermek için kullandığı gizli anahtar |
| Gördüm / Üstlen | `acknowledge` | Nöbetçinin olayı üstlenmesi |
| Çözüldü | `resolve` | Olayın kapanması |
| Eskalasyon | `escalation` | Cevap gelmeyince bir üst seviyeye geçiş |
| Eskalasyon politikası | `EscalationPolicy` | Hangi sırayla kimlerin aranacağı |
| Seviye | `EscalationLevel` | Politikadaki bir basamak |
| Nöbet takvimi | `Schedule` | Dönüşümlü nöbet listesi |
| Nöbet devri | `handoff` | Nöbetin bir kişiden diğerine geçtiği an |
| Elle değişiklik | `Override` | Belirli bir zaman aralığında nöbetin başkasına verilmesi |
| Müsait değilim | `Unavailability` | Kişisel izin kaydı |
| Akademik kapanma dönemi | `BlackoutPeriod` | Sınav haftası, bayram, dönem arası |
| Nöbet boşluğu | `gap` | Kimsenin müsait olmadığı zaman dilimi |
| Aciliyet | `urgency` | `high` (eskale edilir) / `low` (edilmez) |
| Tekilleştirme anahtarı | `dedup_key` | Aynı sorunun tekrar eden alarmlarını tek olayda toplar |

## 3. Yasak sihirler

| Yasak | Yerine |
|---|---|
| `default_scope` | Adlandırılmış `scope` |
| `method_missing` | Açıkça tanımlanmış metot |
| Global monkey patch (`class Integer ... end` vb.) | Modül veya servis nesnesi |
| İş mantığı içeren callback (`after_save :notify_oncall` gibi) | Açık domain metodu (`incident.escalate!`) veya servis. Callback **yalnızca** türetilmiş alanlar için (ör. e-posta küçük harfe çevirme, `integration_key` üretme). |
| Enum'un ürettiği bang metotlarının (`resolved!`, `acknowledged!`) domain kodunda doğrudan kullanımı | Domain geçiş metotları (`resolve!`, `acknowledge!`) |
| `Time.now`, `Date.today` | `Time.current`, `Date.current` |
| Uydurma API | Kullanılan her gem/metot konsolda doğrulanır; doğrulanamayan satır yazılmaz |

## 4. Test kuralı

- Her zaman kuralı (Z1–Z5) `travel_to` ile test edilir. Testler job'u değil sınıf metotlarını çağırır (`Incident.escalate_due!`, `GapReport.run!`); job'lar için tek smoke testi yeterli.
- Her yasak durum geçişi ayrı bir testle `Incident::InvalidTransition` beklenerek test edilir; enum'un ham bang metotları da ayrıca denenir.
- Sabit çapa zamanı: `travel_to Time.zone.parse("2026-10-19 10:00")` (Istanbul).
- Önce test yazılır, kırmızı görülür, sonra kod yazılır.
- Minitest + fixtures; RSpec yok.
- Fixture çapası: 2026-10-19 10:00'da BT Altyapı (`schedules(:primary)`) nöbetçisi Ayşe (`users(:alice)`, asistan), Laboratuvar (`schedules(:secondary)`) nöbetçisi Burak (`users(:bob)`, personel). `users(:manager)` tek yönetici. Olay fixture'ları: `incidents(:triggered)` (escalate_at 10:05), `(:acknowledged)` (09:02'de görüldü → 13:02'de bayat), `(:resolved)`.
- Bildirim sayısı kontrol edilirken olaya göre süz (`incident.notifications`): fixture olayları da aynı süpürmede eskale olur.
- Her geçişin `IncidentEvent` kaydı testte kontrol edilir; kullanıcıya görünen her sayfa için en az bir controller testi.

## 5. Konvansiyondan sapmalar

| Sapma | Sebep |
|---|---|
| Uygulama `sen_al/` alt klasöründe değil, repo kökünde. Modül adı `SenAl`. | Rails iskeleti repo köküne üretilmiş olarak geldi; ayrı klasör ek fayda sağlamıyor. |
| `OnCall`, `EventIngestor`, `GapReport` `app/models` altında PORO; `app/services` klasörü kullanılmıyor. | `specs.md` kod yerlerini böyle veriyor; Rails'in varsayılan autoload yolu, ek klasör konvansiyonu gerektirmiyor. |
| `tailwindcss-rails` kaldırıldı, Pico.css (sınıfsız) CDN'den yükleniyor. | `specs.md` §2: tek sınıfsız CSS, build adımı yok. |
| `rails-i18n` gem'i eklendi. | Varsayılan locale `:tr`; tarih ve doğrulama mesajlarının Türkçe çevirisi için. |
| `users.name` sütunu `default: ""` ile eklendi. | SQLite, mevcut tabloya `NOT NULL` sütun eklerken varsayılan ister. Boş olmama kuralı `validates :name, presence: true` ile modelde. |
| CI'dan `system-test` işi çıkarıldı. | Projede sistem testi yok; gereksiz Chrome kurulumu CI'ı yavaşlatır ve kırılganlaştırır. |
| API: açık olayda izin verilmeyen geçiş (ör. zaten üstlenilmiş olaya `acknowledge`) `409 Conflict` döner; bilinmeyen `severity` `422` döner. | `specs.md` §6 bu iki durumu tanımlamıyor; "sessizce geçmez" ilkesine uygun açık hata seçildi. |
| `incidents` üzerinde kısmi benzersiz indeks (`service_id, dedup_key WHERE status <> 2`). | "Açık olay en fazla 1" kuralı yarış durumunda da veritabanı düzeyinde korunsun diye. |
| `notified` olayında `user_id` boş; bildirilen kişi `details["user_id"]` içinde. | `IncidentEvent.user` "eylemi yapan kişi"dir; bildirimi sistem yapar. |
| `Incident has_many :incident_events, -> { order(:occurred_at, :id) }` (spec: yalnızca `occurred_at`). | Aynı anda yazılan kayıtlar (ör. `triggered` + `notified`) yazılış sırasıyla görünsün diye `id` ikincil sıralama anahtarı. |
| `stale_acknowledged` scope'u servisteki her farklı `ack_reset_minutes` değeri için ayrı koşul kurar (`or` ile birleşir). | SQL tarih aritmetiği SQLite ve PostgreSQL'de farklı; canlı veritabanı henüz belli değil. Farklı süre değeri sayısı küçük. |
| Boşluk atlamada (`gap_skipped`) `escalated` kaydı da yazılır; bütün seviyeler boşsa turlar beklemeden tükenir ve `escalation_exhausted` olur. `low` olaylarda da boşluk atlanır (bildirecek birini bulmak için), zaman aşımı eskalasyonu yapılmaz. | Spec "beklemeden sonraki seviyeye geçilir" diyor; aciliyet ayrımı yalnızca zaman aşımı için tanımlı. |
| `escalation_exhausted` sonrası olay `triggered` kalır, `escalate_at` nil olur. | Spec yeni bir durum tanımlamıyor; yöneticiler bildirilir, olay hâlâ "Gördüm" bekler. |
| `escalate!` `triggered` olmayan olayda `false` döner (istisna fırlatmaz). | Bir durum geçişi değil; süpürme işi yarış durumunda sessizce atlayabilsin diye. |
| `notifications.incident_id` boş olabilir, yeni `message` (text) alanı eklendi (yeni migration). | Z5 boşluk raporu "takvim adı + aralıklar" içeren, bir olaya bağlı olmayan bildirimdir; spec §3.12'deki alanlar bunu taşıyamıyor. Olaysız bildirimde `message` zorunlu. |
| `Schedule#gaps` aralıkları bitişi hariç (`a...b`) döner; son aralık `to`'da kesilir. | Spec bitişin dahil olup olmadığını belirtmiyor; `Unavailability`/`Override` ile aynı `[başlangıç, bitiş)` kuralı. |
| `GapReportJob` zamanlaması `every day at 8am Europe/Istanbul`. | Sunucunun saat dilimi ne olursa olsun 08:00 İstanbul saatinde çalışsın diye (Fugit ile doğrulandı). |
| Yetki: `ManagerOnly` concern'i manager olmayanı `root`'a yönlendirir (403 yerine). Override'ı herkes ekler, yalnızca manager siler. | Spec yalnızca servis ve akademik takvim için yetki tanımlıyor; override silme kuralı spec'te yok. |
| `Schedule#on_call_samples` eklendi; `gaps` ve takvim sayfasının günlük tablosu (`on_call_days`) aynı örneklemeyi kullanır. İlk örnek `from` anında, sonrakiler tam saat başında. | Tablo ile boşluk raporu hiçbir zaman çelişmesin; saat başı olmayan `from` boşluk sınırlarını kaydırmasın (testli). |
| Pano ayrıca önümüzdeki 7 günün boşluklarını gösterir. | Adaptasyonun canlı demoda görünmesi için (spec §9 "boşluk uyarısını göster"). |
| Kayıt sayfası (`/registration/new`) eklendi; spec'te yok. | İnsan isteği. Kayıt olan herkes `responder` olur (`role` izinli parametrelerde yok, testli); `manager` yalnızca seed/konsol ile atanır. |

## 6. Komutlar

```sh
bin/rails test              # tüm testler
bin/rails db:seed           # demo verisi (tekrar çalıştırılabilir; şifre README'de)
bin/dev                     # geliştirme sunucusu
bin/ci                      # CI adımlarının tamamı yerelde
bin/rails db:test:prepare   # test veritabanı kirlendiyse (ör. db:seed:replant sonrası)
bin/rubocop && bin/brakeman -q --no-pager
# Yasak kalıp taraması (boş dönmeli):
grep -rnE "default_scope|method_missing|Time\.now|Date\.today|\.(resolved|acknowledged|triggered)!" app lib config db/seeds.rb | grep -v "^config/environments"
```

## 7. Kod haritası

| Ne | Nerede |
|---|---|
| Durum makinesi, Z1, Z3, bildirim | `app/models/incident.rb` (`ALLOWED_TRANSITIONS`, `transition_to!`, `notify_current_level!`, `escalate!`) |
| Z2 rotasyon | `app/models/on_call.rb` (`OnCall.for`) |
| Z4 müsaitlik | `app/models/user.rb#available_at?`, `unavailability.rb`, `blackout_period.rb` |
| Z5 boşluk | `app/models/schedule.rb` (`on_call_samples`, `gaps`, `on_call_days`), `app/models/gap_report.rb` |
| API | `app/controllers/api/v1/events_controller.rb` (ince) → `app/models/event_ingestor.rb` |
| Arka plan işleri | `app/jobs/escalation_sweep_job.rb`, `gap_report_job.rb`, `config/recurring.yml` |
| Yetki | `app/controllers/concerns/manager_only.rb` |
| Türkçe etiketler | `config/locales/tr.yml` (`enums.*`), `app/helpers/application_helper.rb` |
| Kural → dosya:satır tablosu | `docs/G1.md` |

## 8. Tuzaklar (bu projede yaşandı)

- **Enum bang metotları her durumdan çalışır.** `resolved!` domain kodunda yasak; savunma `status_transition_allowed` doğrulamasında. Yeni bir durum eklenirse önce `ALLOWED_TRANSITIONS`, sonra testler.
- **Bildirim tek yerden.** Bildirim/atanan/`escalate_at` mantığını `notify_current_level!` dışına kopyalama; yeni bir tetik (ör. yeni geçiş) gerekiyorsa bu metodu çağır.
- **Zaman örneklemesi saat başına hizalı.** `Schedule#on_call_samples` dışında ayrı bir örnekleme döngüsü yazma; tablo ile rapor çelişir.
- **Ruby keyword argümanları:** `def m(payload, key:)` iken `m a: 1` çağrısı hash'i anahtar argüman sayar. Yardımcıda `def m(key:, **payload)` kullan.
- **`db:seed:replant` test veritabanını kirletir** (fixture'ı olmayan tablolar temizlenmez) → `bin/rails db:test:prepare`.
- **Solid Queue geliştirmede kurulu değil** (yalnızca production `queue` veritabanı). `recurring.yml` doğrulamak için `SolidQueue::Configuration.new.send(:recurring_tasks_config)` (veritabanına dokunmaz).
- **Canlıda Solid Queue çalışmazsa eskalasyon hiç olmaz.** `SOLID_QUEUE_IN_PUMA=1` veya ayrı `bin/jobs`.

## 9. Çalışma kuralları (`docs/plan.md`'den)

- Faz faz ilerle, her faz sonunda dur; `bin/rails test` çıktısının son satırlarını aynen göster.
- Test önce: kırmızıyı gör, sonra kodu yaz. Test sonucunu uydurma.
- Emin olunmayan API `bin/rails runner` ile denenir; doğrulanamayan satır yazılmaz.
- Çalışmış migration düzenlenmez; şema değişikliği yeni migration ile.
- Spec'teki alan/scope/metot adları değiştirilmez; sapma bu dosyanın 5. bölümüne yazılır.
- Küçük, Türkçe, açıklayıcı commit'ler. Yapılamayan her şey `docs/yapamadiklarim.md`'ye.
