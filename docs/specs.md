# specs.md — SenAl

> PagerDuty'den ilham alan, Ruby on Rails 8 ile yazılmış bir nöbet ve olay müdahale (on-call & incident response) uygulaması.
> Bu dosya **ne** yapılacağını tanımlar. **Nasıl ve hangi sırayla** yapılacağı `plan.md`'de.

---

## 0. Ürün özeti

| | |
|---|---|
| **Ürün adı** | SenAl (kod içinde: `SenAl`, klasör adı `sen_al`) — "ben yapamıyorum, sen al" esprisi: nöbeti devretmenin adı |
| **İlham** | PagerDuty. Bu ad **yalnızca README'de** "ilham kaynağı" olarak geçer. Uygulamanın arayüzünde, logosunda, sayfa başlıklarında, e-postalarında PagerDuty adı veya markası **kullanılmaz**. |
| **Aort dilimi** | Alarm gelir → nöbetçiye bildirilir → nöbetçi "gördüm" der (acknowledge) → sorun çözülür (resolve). "Gördüm" denmezse bir üst seviyeye eskale edilir. |
| **Adaptasyon (100+)** | Müsaitlik farkındalıklı nöbet: kişisel izinler ve **akademik takvim** (sınav haftası, bayram, dönem arası) nöbet rotasyonunda otomatik atlanır; kapanamayan boşluklar önceden tespit edilip yöneticiye bildirilir. |
| **Hedef kullanıcı (tek cümle)** | Üniversite BT birimleri ve araştırma laboratuvarları, nöbetçi asistanlar sınav haftasında veya izindeyken sistemi her takvimde tek tek elle düzeltmek zorunda kalmadan nöbet yönetmek için kullanır. |

### Adaptasyonun gerekçesi (kanıt)
PagerDuty'nin kendi topluluk forumunda kullanıcılar, izin/tatil durumunda kişiyi her nöbet takviminden tek tek elle "override" ile çıkarmak zorunda kaldıklarından şikayet ediyor; destek ekibi bunun tek yol olduğunu doğruluyor. Capterra'da takvim özelliğiyle ilgili yorumların çoğunluğu olumsuz. Linkler README'de verilecek.

---

## 1. Sözlük (TR ↔ EN)

Kod İngilizce, arayüz Türkçe yazılır. Bu tablo `AGENT.md`'ye de kopyalanır.

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

---

## 2. Teknoloji ve kısıtlar

- **Ruby 3.3+**, **Rails 8.x**
- Kimlik doğrulama: `bin/rails g authentication` (ek gem yok)
- Arka plan işleri: **Solid Queue** + `config/recurring.yml`
- Veritabanı: geliştirmede SQLite. Canlıda: deploy platformu kalıcı disk sunmuyorsa PostgreSQL (karar `plan.md` Faz 0'da verilir).
- Arayüz: Rails view'ları + Hotwire (Turbo). Tasarım **minimal**: tek bir sınıfsız CSS (ör. Pico.css veya Simple.css, CDN'den) yeterli. JS build adımı yok.
- Test: **Minitest + fixtures** (Rails varsayılanı). RSpec kullanılmaz.
- CI: GitHub Actions (Rails 8'in ürettiği `.github/workflows/ci.yml` temel alınır), README'de CI rozeti.
- Saat dilimi: `config.time_zone = "Istanbul"`. Tüm zaman hesapları `Time.current` ile yapılır, **asla** `Time.now` kullanılmaz.
- E-posta: Action Mailer. Geliştirmede `letter_opener_web` veya log; canlıda gönderim zorunlu değil, uygulama içi bildirim yeterli.
- Tek kurum (single-tenant). Çok kiracılık kapsam dışı.

### Yasaklar (hocanın kuralları)
| Yasak | Yerine |
|---|---|
| `default_scope` | Adlandırılmış `scope` |
| `method_missing` | Açıkça tanımlanmış metot |
| Global monkey patch (`class Integer ... end` vb.) | Modül veya servis nesnesi |
| İş mantığı içeren callback (`after_save :notify_oncall` gibi) | Açık domain metodu (`incident.escalate!`) veya servis. Callback **yalnızca** türetilmiş alanlar için (ör. e-posta küçük harfe çevirme, `integration_key` üretme). |
| Enum'un ürettiği bang metotlarının (`resolved!`, `acknowledged!`) domain kodunda doğrudan kullanımı | Domain geçiş metotları (`resolve!`, `acknowledge!`) |
| `Time.now`, `Date.today` | `Time.current`, `Date.current` |
| Uydurma API | Kullanılan her gem/metot konsolda doğrulanır; doğrulanamayan satır yazılmaz |

---

## 3. Veri modeli

Alan adları kesindir; ajan bunları değiştirmez. Değiştirmesi gerekirse `AGENT.md` "Sapmalar" bölümüne yazar.

### 3.1 `User`
| Alan | Tip | Not |
|---|---|---|
| `email_address` | string, unique, not null | `bin/rails g authentication` üretir |
| `password_digest` | string | üretir |
| `name` | string, not null | |
| `role` | integer enum | `responder: 0`, `manager: 1` |
| `academic_role` | integer enum | `staff: 0`, `assistant: 1` — akademik kapanma dönemleri hangi kişilere uygulanır, onu belirler |

İlişkiler: `has_many :schedule_memberships`, `has_many :schedules, through:`, `has_many :unavailabilities`, `has_many :notifications`.

### 3.2 `Service`
| Alan | Tip | Not |
|---|---|---|
| `name` | string, not null, unique | |
| `integration_key` | string, not null, unique, index | Oluşturulurken `SecureRandom.hex(16)` ile üretilir (türetilmiş alan, callback serbest) |
| `escalation_policy_id` | references, not null | |
| `ack_reset_minutes` | integer, default 240 | Bayatlama kuralı için (Bkz. Z3) |

### 3.3 `EscalationPolicy`
| Alan | Tip | Not |
|---|---|---|
| `name` | string, not null | |
| `repeat_count` | integer, default 1 | Son seviyeden sonra baştan kaç tur daha dönülür |

`has_many :escalation_levels, -> { order(:position) }, dependent: :destroy`

### 3.4 `EscalationLevel`
| Alan | Tip | Not |
|---|---|---|
| `escalation_policy_id` | references, not null | |
| `position` | integer, not null | 0'dan başlar; politika içinde tekil |
| `schedule_id` | references, not null | Bu seviyede o anki nöbetçi aranır |
| `timeout_minutes` | integer, not null, default 5, > 0 | Bu süre içinde "gördüm" denmezse sonraki seviye |

### 3.5 `Schedule`
| Alan | Tip | Not |
|---|---|---|
| `name` | string, not null | |
| `starts_at` | datetime, not null | Rotasyonun çapası; ilk nöbet devri anı |
| `rotation_days` | integer, not null, default 7, > 0 | Her kişinin kesintisiz nöbet uzunluğu (gün) |

`has_many :schedule_memberships, -> { order(:position) }`, `has_many :members, through: :schedule_memberships, source: :user`, `has_many :overrides`

### 3.6 `ScheduleMembership`
| Alan | Tip | Not |
|---|---|---|
| `schedule_id`, `user_id` | references | (schedule, user) tekil |
| `position` | integer, not null | Rotasyon sırası; (schedule, position) tekil |

### 3.7 `Override`
| Alan | Tip | Not |
|---|---|---|
| `schedule_id`, `user_id` | references | |
| `starts_at`, `ends_at` | datetime, not null | `ends_at > starts_at` |

### 3.8 `Unavailability` (adaptasyon)
| Alan | Tip | Not |
|---|---|---|
| `user_id` | references | |
| `starts_at`, `ends_at` | datetime, not null | `ends_at > starts_at` |
| `reason` | string | ör. "Yıllık izin" |

### 3.9 `BlackoutPeriod` (adaptasyon — akademik takvim)
| Alan | Tip | Not |
|---|---|---|
| `name` | string, not null | ör. "2026 Güz Vize Haftası" |
| `kind` | integer enum | `exam_week: 0`, `holiday: 1`, `semester_break: 2` |
| `applies_to` | integer enum | `assistants: 0`, `everyone: 1` |
| `starts_on`, `ends_on` | date, not null | `ends_on >= starts_on`; **iki uç dahil**, gün sınırları `Istanbul` saatine göre |

### 3.10 `Incident`
| Alan | Tip | Not |
|---|---|---|
| `service_id` | references, not null | |
| `title` | string, not null | Alarmdaki `summary` |
| `dedup_key` | string, not null, index | (service, dedup_key) için açık olay en fazla 1 tane |
| `urgency` | integer enum | `high: 0`, `low: 1` |
| `status` | integer enum | `triggered: 0`, `acknowledged: 1`, `resolved: 2` — **`new` adı kullanılmaz** (Rails `Incident.new` ile çakışır) |
| `assignee_id` | references → users, null | En son bildirim yapılan kişi |
| `current_level` | integer, default 0 | Eskalasyon politikasındaki şu anki seviye |
| `escalation_round` | integer, default 0 | Kaçıncı tur |
| `escalate_at` | datetime, null, index | Bir sonraki eskalasyonun yapılacağı an. `triggered` değilse veya `low` ise `nil` |
| `triggered_at` | datetime, not null | |
| `acknowledged_at` | datetime | |
| `resolved_at` | datetime | |

`has_many :incident_events, -> { order(:occurred_at) }`

### 3.11 `IncidentEvent` (zaman çizelgesi)
| Alan | Tip | Not |
|---|---|---|
| `incident_id` | references | |
| `kind` | string, not null | Bkz. aşağıdaki liste |
| `user_id` | references, null | Eylemi yapan kişi (sistem ise `nil`) |
| `details` | json, default {} | |
| `occurred_at` | datetime, not null | |

Geçerli `kind` değerleri: `triggered`, `notified`, `acknowledged`, `resolved`, `escalated`, `retriggered`, `deduplicated`, `gap_skipped`, `escalation_exhausted`.

### 3.12 `Notification`
| Alan | Tip | Not |
|---|---|---|
| `user_id`, `incident_id` | references | |
| `read_at` | datetime | |

---

## 4. Durum makinesi: `Incident`

```
             acknowledge!            resolve!
 triggered ───────────────▶ acknowledged ─────────▶ resolved
     │  ▲                        │                     ▲
     │  └──── retrigger! ────────┘ (yalnızca sistem)   │
     └─────────────────── resolve! ────────────────────┘
```

| Geçiş | Metot | İzinli mi? | Kim |
|---|---|---|---|
| triggered → acknowledged | `acknowledge!(by:)` | ✅ | Herhangi bir giriş yapmış kullanıcı |
| triggered → resolved | `resolve!(by:)` | ✅ | Kullanıcı veya API (`by: nil`) |
| acknowledged → resolved | `resolve!(by:)` | ✅ | Kullanıcı veya API |
| acknowledged → triggered | `retrigger!` | ✅ | Yalnızca sistem (Z3) |
| acknowledged → acknowledged | `acknowledge!` | ❌ `InvalidTransition` | |
| resolved → (herhangi) | tümü | ❌ `InvalidTransition` | |

Kurallar:
- `Incident::InvalidTransition < StandardError` tanımlanır.
- Her geçiş: durumu, ilgili zaman damgasını (`acknowledged_at` vb.), `escalate_at`'i günceller ve bir `IncidentEvent` yazar. Hepsi tek `transaction` içinde.
- **Savunma katmanı:** `validate :status_transition_allowed, on: :update` doğrulaması eklenir. Böylece biri `update(status: :triggered)` veya enum'un `triggered!` metodunu çağırsa bile `resolved` olaydan çıkış engellenir. (Bu bir doğrulama, iş mantığı callback'i değil.)
- **Tuzak notu:** Enum'un ürettiği `resolved!` her durumdan çalışır. Testler domain metotlarını **ve** bu ham yolu ayrı ayrı denemelidir.

---

## 5. Zaman kuralları

Her kural: tanım, sorumlu kod yeri ve **zorunlu** `travel_to` testleri. Testler sabit bir çapa zaman kullanır: `travel_to Time.zone.parse("2026-10-19 10:00")`.

### Z1 — "Gördüm" zaman aşımı → eskalasyon
- `high` aciliyetli olay `triggered` olduğunda, o seviyenin nöbetçisi bildirilir ve `escalate_at = Time.current + level.timeout_minutes.minutes` olur.
- `escalate_at` geçtiyse ve olay hâlâ `triggered` ise `escalate!` çalışır:
  - Sonraki seviye varsa → `current_level += 1`, o seviyenin nöbetçisi bildirilir.
  - Son seviyedeyse ve `escalation_round < policy.repeat_count` ise → seviye 0'a dön, `escalation_round += 1`.
  - Turlar bittiyse → `escalate_at = nil`, `escalation_exhausted` olayı yazılır, tüm `manager`'lara bildirim gider.
- Bir seviyede nöbetçi yoksa (boşluk) → `gap_skipped` yazılır, **beklemeden** sonraki seviyeye geçilir.
- `low` aciliyetli olaylar bildirilir ama **eskale edilmez** (`escalate_at = nil`). Bu, alarm yorgunluğunu azaltır.
- Kod yeri: `Incident#escalate!`, `Incident.escalation_due` scope'u, `Incident.escalate_due!` sınıf metodu, `EscalationSweepJob` (her dakika, `config/recurring.yml`). Job yalnızca `Incident.escalate_due!` çağırır; içinde mantık yok.
- Scope: `scope :escalation_due, -> { triggered.where(escalate_at: ..Time.current) }`

**Zorunlu testler:**
1. 4 dakika sonra eskale **olmaz**; 5 dakika sonra seviye 1'e geçer ve seviye 1 nöbetçisine bildirim gider.
2. Son seviyede zaman aşımı → `repeat_count` kadar baştan döner; sonra `escalation_exhausted`.
3. `acknowledged` olay zaman aşımında eskale **olmaz**.
4. `low` aciliyetli olay hiç eskale olmaz.
5. Seviye 0'da boşluk varsa olay tetiklenir tetiklenmez seviye 1 nöbetçisine gider.

### Z2 — Nöbet devri (rotasyon)
- `OnCall.for(schedule, at: time)` saf (yan etkisiz) bir nesne/metottur, o andaki nöbetçiyi (`User` veya `nil`) döner.
- Hesap sırası:
  1. `at` anını kapsayan bir `Override` varsa → onun kişisi (müsaitlik kontrolü yapılmaz; override bilinçli bir karardır).
  2. Yoksa: `slot = ((at - starts_at) / rotation_days.days).floor`, `base_index = slot % üye_sayısı`.
  3. `base_index`'ten başlayarak sırayla dön; `at` anında **müsait olan ilk** üyeyi döndür (Z4).
  4. Kimse müsait değilse veya `at < starts_at` ise veya üye yoksa → `nil`.
- Kod yeri: `app/models/on_call.rb` (PORO), `User#available_at?(time)`.

**Zorunlu testler:**
1. 3 kişi, 7 günlük rotasyon: 0., 7. ve 14. gün sırasıyla 1., 2., 3. kişi; 21. gün tekrar 1. kişi.
2. Devir anından 1 saniye önce eski kişi, devir anında yeni kişi.
3. Override aralığında override kişisi, aralık bitince rotasyon kişisi.
4. `starts_at` öncesi → `nil`.

### Z3 — Bayatlamış "gördüm" → yeniden tetikleme
- `acknowledged` durumdaki olay `service.ack_reset_minutes` (varsayılan 240) boyunca çözülmezse `retrigger!` çalışır: durum `triggered`, `current_level = 0`, `escalation_round = 0`, seviye 0 nöbetçisi yeniden bildirilir.
- Scope: `scope :stale_acknowledged, -> { acknowledged.joins(:service).where("incidents.acknowledged_at <= ?", ...)}` — servis bazlı süre gerektiği için uygulama ajanın kararı; ama scope adı `stale_acknowledged` olur ve `Incident.retrigger_stale!` aynı `EscalationSweepJob` içinden çağrılır.

**Zorunlu testler:**
1. 3 saat 59 dakikada durum `acknowledged` kalır; 4 saatte `triggered` olur ve seviye 0'a bildirim gider.
2. `resolved` olay hiçbir zaman yeniden tetiklenmez.

### Z4 — Müsaitlik farkındalıklı rotasyon (ADAPTASYON)
- `User#available_at?(time)` şu durumlarda `false`:
  - `time`'ı kapsayan bir `Unavailability` var (`starts_at <= time < ends_at`), **veya**
  - `time`'ın tarihi (`time.in_time_zone.to_date`) bir `BlackoutPeriod`'un `starts_on..ends_on` aralığında **ve** dönem `everyone`'a uygulanıyor ya da dönem `assistants`'a uygulanıyor ve kullanıcı `assistant`.
- Z2'deki "müsait olan ilk üye" kuralı bunu kullanır. Bu sayede kişi **bir kez** izin girer, **tüm** takvimlerden otomatik düşer.

**Zorunlu testler:**
1. Nöbetçi A izindeyken nöbet sıradaki B'ye geçer; izin bitince A'ya döner.
2. A beş farklı takvimde olsun; tek bir `Unavailability` kaydı beşinde de A'yı atlatır.
3. Vize haftası `assistants` için tanımlıyken asistan atlanır, `staff` atlanmaz.
4. Bayram `everyone` için tanımlıyken herkes atlanır → `OnCall.for` `nil` döner.
5. `BlackoutPeriod` uçları dahildir: `ends_on` günü 23:59'da atlanır, ertesi gün 00:00'da atlanmaz.

### Z5 — Boşluk tespiti ve önceden uyarı (ADAPTASYON)
- `Schedule#gaps(from:, to:)` belirtilen aralıkta nöbetçinin `nil` olduğu zaman aralıklarını `[Range<Time>]` olarak döner. Örnekleme adımı 1 saat; ardışık boş saatler tek aralıkta birleştirilir.
- `GapReport.run!(horizon: 7.days)` tüm takvimleri tarar; boşluk varsa her `manager`'a tek bir bildirim gönderir (takvim adı + aralıklar).
- `GapReportJob` her gün 08:00'de (`config/recurring.yml`) çalışır, yalnızca `GapReport.run!` çağırır.
- Arayüzde takvim sayfası önümüzdeki 14 günü gösterir; boşluk olan günler kırmızı işaretlenir.

**Zorunlu testler:**
1. Tüm üyeler aynı gün izinliyse o gün `gaps` içinde tek bir aralık olarak çıkar.
2. Boşluk yoksa yöneticiye bildirim **gitmez**.
3. 8 gün sonraki bir boşluk 7 günlük ufukta raporlanmaz; 1 gün sonra (`travel_to`) raporlanır.

---

## 6. Olay alımı (API)

`POST /api/v1/events`

- Kimlik: `Authorization: Token token=<integration_key>` başlığı. Geçersizse `401`.
- CSRF bu uç için kapalı; `ActionController::API` veya ayrı bir base controller.
- Gövde (JSON):

```json
{ "event_action": "trigger", "dedup_key": "disk-full-db1", "summary": "db1 disk %95", "severity": "critical" }
{ "event_action": "acknowledge", "dedup_key": "disk-full-db1" }
{ "event_action": "resolve", "dedup_key": "disk-full-db1" }
```

- Ayrıştırma **pattern matching** ile yapılır (derste Slayt 9'daki kalıp):

```ruby
case payload
in { event_action: "trigger", dedup_key: String => key, summary: String => summary, **rest }
  # severity: "critical" | "error" → high, "warning" | "info" | yok → low
in { event_action: "acknowledge" | "resolve", dedup_key: String => key }
  # ...
else
  # 422 + hata mesajı (sessizce geçmez)
end
```

- **Tekilleştirme:** Aynı servis ve `dedup_key` ile açık (`resolved` olmayan) olay varsa yeni olay açılmaz; mevcut olaya `deduplicated` event'i yazılır.
- `acknowledge` / `resolve` için açık olay yoksa `404`.
- Yanıt: `202 Accepted`, `{ "status": "...", "incident_id": 42, "dedup_key": "..." }`
- Kod yeri: `Api::V1::EventsController` (ince), `EventIngestor` servisi (`app/models/event_ingestor.rb`, PORO).

**Zorunlu testler (integration test):** geçersiz anahtar 401; trigger yeni olay açar; aynı `dedup_key` ikinci trigger olay açmaz; resolve olayı kapatır; bozuk gövde 422.

---

## 7. Arayüz (minimal)

Tasarım hedefi: çalışır ve okunur. Sınıfsız CSS, tablo ve form yeterli.

| Sayfa | Yol | İçerik |
|---|---|---|
| Giriş | `/session/new` | Rails 8 authentication |
| Pano | `/` | Her takvim için "şu an nöbetçi", açık olaylar listesi (Turbo ile canlı güncelleme opsiyonel) |
| Olaylar | `/incidents` | Duruma göre filtre (`triggered` / `acknowledged` / `resolved`) |
| Olay detayı | `/incidents/:id` | Bilgiler, **Gördüm** ve **Çözüldü** butonları (yalnızca izinli geçişlerde görünür), zaman çizelgesi (`IncidentEvent`) |
| Takvimler | `/schedules`, `/schedules/:id` | Üyeler ve sıraları, önümüzdeki 14 günün nöbet tablosu (boşluklar kırmızı), override ekleme |
| Müsaitliğim | `/unavailabilities` | Kişinin kendi izinlerini ekleme/silme |
| Akademik takvim | `/blackout_periods` | Yalnızca `manager`: sınav haftası, bayram, dönem arası CRUD |
| Servisler | `/services` | Yalnızca `manager`: servis CRUD, `integration_key` ve kopyalanabilir örnek `curl` komutu |
| Bildirimlerim | `/notifications` | Okunmamış bildirimler |

Route örneği:
```ruby
resources :incidents, only: %i[index show] do
  member do
    post :acknowledge
    post :resolve
  end
end
```

---

## 8. Seed verisi

`bin/rails db:seed` canlı demoyu tek komutla hazırlar:
- 1 manager, 4 responder (2'si `assistant`). Demo şifreleri yalnızca README'de, açıkça "demo" etiketiyle.
- 2 takvim ("BT Altyapı", "Laboratuvar"), 1 eskalasyon politikası (2 seviye, 5'er dk).
- 1 servis ("Öğrenci Bilgi Sistemi").
- 1 `BlackoutPeriod`: önümüzdeki haftaya denk gelen bir vize haftası (`assistants`).
- Önümüzdeki 7 gün içinde kasıtlı bir boşluk (demo için).
- Farklı durumlarda 3 olay.

---

## 9. Kabul kriterleri (rubrik eşlemesi)

### 85 puan için hepsi zorunlu
- [ ] Canlı URL'de: alarm gönder (curl) → panoda görün → bildirim → "Gördüm" → "Çözüldü" akışı uçtan uca çalışıyor
- [ ] CI yeşil, README'de rozet
- [ ] En az 3 zaman kuralı `travel_to` ile testli (Z1, Z2, Z3)
- [ ] Durum makinesi + yasak geçiş testleri (bölüm 4)
- [ ] `docs/` altında G1–G5 + "Yapamadıklarım"
- [ ] `AGENT.md` ilk ve son sürümü arasında diff mevcut
- [ ] Arayüzde orijinal marka yok

### 100+ için
- [ ] Z4 ve Z5 testli ve canlıda gösterilebilir: bir asistanı vize haftasına sok → tüm takvimlerden düştüğünü göster → boşluk uyarısını göster
- [ ] README'de adaptasyonun tek cümlelik "kim, neden, nasıl" açıklaması ve forum kaynakları

---

## 10. Kapsam dışı (bilinçli olarak yapılmayacaklar)

SMS/telefon araması, mobil uygulama, çok kiracılık, Slack entegrasyonu, SLO/analitik raporlar, otomatik çözme, olay birleştirme (merge), postmortem. Bunlar istenirse `docs/yapamadiklarim.md` içinde "kapsam dışı bırakıldı" olarak listelenir.
