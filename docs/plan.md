# plan.md — SenAl uygulama planı

> Bu dosya coding agent içindir. **Ne** yapılacağı `specs.md`'de; burada **hangi sırayla** ve **hangi kurallarla** yapılacağı yazıyor.
> Önce `specs.md`'yi baştan sona oku. Sonra bu planı faz faz uygula.

---

## Ajan için çalışma kuralları

1. **Faz faz ilerle.** Her fazın sonunda **DUR**: ne yaptığını, hangi testlerin eklendiğini, `bin/rails test` çıktısının **son satırlarını aynen** göster. İnsan onay vermeden sonraki faza geçme.
2. **Test önce gelir.** Her zaman kuralı ve her durum geçişi için önce testi yaz, kırmızı olduğunu gör, sonra kodu yaz.
3. **Test sonucunu uydurma.** Testleri çalıştıramadıysan "çalıştıramadım" de. "Testler geçti" cümlesini yalnızca gerçek komut çıktısıyla birlikte yaz.
4. **Emin olmadığın API'yi kullanma.** Bir gem metodunun var olduğundan emin değilsen `bin/rails runner` ile dene. Doğrulayamadığın her şeyi sor.
5. **Çalışmış migration'ı düzenleme.** Şema değişikliği her zaman yeni migration ile yapılır. Sıra: önce migration, sonra model.
6. **Yasaklar** (`specs.md` §2): `default_scope`, `method_missing`, monkey patch, iş mantığı içeren callback, enum bang metotlarının domain kodunda kullanımı, `Time.now`.
7. **`specs.md`'deki alan, scope ve metot adlarını değiştirme.** Değiştirmen gerekirse sebebini `AGENT.md` → "Konvansiyondan sapmalar" bölümüne yaz.
8. **Küçük commit'ler.** Her faz en az bir commit. Mesajlar Türkçe ve açıklayıcı: `Faz 2: Z1 eskalasyon kuralı ve testleri`.
9. Bir şeyi yapamıyorsan **dur ve söyle.** Yapamadıkları `docs/yapamadiklarim.md`'ye yaz. Uydurulan rapor notu sıfırlar, dürüst eksik not düşürmez.

---

## Faz 0 — İskelet, CI ve canlı "merhaba" (önce risk)

Amaç: Canlı URL ve CI en riskli iki madde. En başta hallolsun.

- [ ] `rails new sen_al` (Rails 8, varsayılanlar: SQLite, Solid Queue, Minitest, Propshaft, Importmap)
- [ ] `config.time_zone = "Istanbul"`, `config.i18n.default_locale = :tr`
- [ ] `bin/rails g authentication` + `User`'a `name`, `role`, `academic_role` alanları (yeni migration)
- [ ] Sınıfsız CSS'i layout'a ekle (CDN), ana sayfada "SenAl" başlığı
- [ ] `.github/workflows/ci.yml` çalışıyor; README'ye CI rozeti
- [ ] **İnsan kararı:** deploy platformu. Platform kalıcı disk sunmuyorsa production'da PostgreSQL'e geç (yalnızca `production` ortamı).
- [ ] Boş uygulamayı canlıya al, giriş sayfası canlıda açılıyor
- [ ] `AGENT.md` **v1**'i oluştur (bkz. aşağıdaki bölüm) ve **ayrı bir commit** olarak at: `AGENT.md v1`
- [ ] `docs/` klasöründe G1–G5 ve `yapamadiklarim.md` için boş şablonlar

**DUR — insan kontrolü:** Canlı URL açılıyor mu? CI rozeti yeşil mi?

---

## Faz 1 — Çekirdek domain: Service, Incident, durum makinesi

- [ ] Migration + model: `EscalationPolicy`, `Schedule`, `EscalationLevel`, `Service`, `Incident`, `IncidentEvent`, `Notification` (alanlar `specs.md` §3)
- [ ] `Incident` enum'ları: `status` (`triggered`, `acknowledged`, `resolved`), `urgency` (`high`, `low`)
- [ ] `Incident::InvalidTransition`
- [ ] Domain metotları: `acknowledge!(by:)`, `resolve!(by:)`, `retrigger!` — her biri transaction içinde zaman damgası + `IncidentEvent`
- [ ] `validate :status_transition_allowed, on: :update` savunma katmanı
- [ ] Fixtures: her durumda birer olay, en az 2 kullanıcı, 1 servis, 1 politika

**Testler (`test/models/incident_test.rb`):**
- [ ] Bölüm 4 tablosundaki her izinli geçiş
- [ ] Her yasak geçiş `InvalidTransition` fırlatır
- [ ] `resolved` olayda `update(status: :triggered)` ve enum'un ham `triggered!` metodu doğrulama hatasıyla başarısız olur
- [ ] Her geçiş doğru `IncidentEvent` kaydını yazar

**DUR — insan kontrolü:** Durum makinesi testleri yeşil mi? `Incident.instance_methods.grep(/resolv/)` çıktısını göster.

---

## Faz 2 — Nöbet takvimi ve Z2 (rotasyon)

- [ ] Migration + model: `ScheduleMembership`, `Override`
- [ ] `app/models/on_call.rb` → `OnCall.for(schedule, at:)` (saf, yan etkisiz)
- [ ] `User#available_at?(time)` şimdilik her zaman `true` (Faz 5'te dolacak)

**Testler (`test/models/on_call_test.rb`):** `specs.md` Z2'deki 4 test.

**DUR — insan kontrolü.**

---

## Faz 3 — Olay alımı (API) ve bildirim

- [ ] `Api::V1::EventsController` + `EventIngestor` (pattern matching, `specs.md` §6)
- [ ] Tetiklemede: seviye 0'ın takviminden `OnCall.for` ile nöbetçi bul → `Notification` oluştur, `assignee` ata, `notified` event'i yaz, `high` ise `escalate_at` ayarla
- [ ] Bildirim mantığı tek bir yerde: `Incident#notify_current_level!` (callback değil, açık çağrı)
- [ ] Tekilleştirme (`dedup_key`)

**Testler (`test/integration/events_api_test.rb`):** `specs.md` §6'daki 5 test.

**DUR — insan kontrolü:** README'deki örnek `curl` ile yerelde bir olay açılıyor mu?

---

## Faz 4 — Z1 eskalasyon ve Z3 bayatlama (arka plan işleri)

- [ ] `Incident.escalation_due`, `Incident.stale_acknowledged` scope'ları
- [ ] `Incident#escalate!` (seviye atlama, tur tekrarı, boşlukta atlama, `escalation_exhausted`)
- [ ] `Incident.escalate_due!`, `Incident.retrigger_stale!` sınıf metotları
- [ ] `EscalationSweepJob` (her dakika) → yalnızca bu iki metodu çağırır
- [ ] `config/recurring.yml` girdisi

**Testler:** `specs.md` Z1'deki 5 test + Z3'teki 2 test. Testler job'u değil **sınıf metotlarını** çağırır (job ince olduğu için ayrıca tek bir smoke test yeterli).

**DUR — insan kontrolü:** Bu noktada 85 puanlık backend tamam. Tüm testler yeşil mi?

> **Kesme çizgisi:** Zaman kalmazsa Faz 5 atlanabilir; Faz 6 (UI) ve Faz 7 (canlı + belgeler) **atlanamaz**. Sıra: Faz 4 → Faz 6'nın aort dilimi sayfaları → Faz 7 → kalan zamanda Faz 5.

---

## Faz 5 — Adaptasyon: Z4 müsaitlik ve Z5 boşluk tespiti (100+)

- [ ] Migration + model: `Unavailability`, `BlackoutPeriod`
- [ ] `User#available_at?(time)` gerçek kural (`specs.md` Z4)
- [ ] `Schedule#gaps(from:, to:)`
- [ ] `GapReport.run!(horizon:)` + `GapReportJob` (her gün 08:00)

**Testler:** `specs.md` Z4'teki 5 test + Z5'teki 3 test.

**DUR — insan kontrolü.**

---

## Faz 6 — Arayüz (minimal)

Sıra önemli; önce aort dilimi:
1. [ ] Pano (`/`): şu an nöbetçiler + açık olaylar
2. [ ] Olay listesi ve detay; **Gördüm / Çözüldü** butonları yalnızca izinli geçişte görünür; zaman çizelgesi
3. [ ] Servisler (manager): `integration_key` ve kopyalanabilir `curl` örneği
4. [ ] Takvim detayı: 14 günlük nöbet tablosu, boşluklar kırmızı, override formu
5. [ ] Müsaitliğim ve Akademik takvim sayfaları
6. [ ] Bildirimlerim
7. [ ] (Opsiyonel) Panoda Turbo Stream ile canlı olay listesi

- [ ] Yetki: `manager` olmayan kullanıcı servis ve akademik takvim sayfalarına erişemez (controller testi)
- [ ] `db/seeds.rb` (`specs.md` §8)

**DUR — insan kontrolü:** Yerelde seed ile aort dilimi baştan sona tıklanarak tamamlanabiliyor mu?

---

## Faz 7 — Canlıya alma ve teslim belgeleri

- [ ] Son sürümü canlıya al, canlıda `db:seed`
- [ ] Canlıda Solid Queue çalışıyor: bir olay aç, 5 dk bekle, eskalasyonun gerçekleştiğini gör
- [ ] README: proje adı, canlı URL, CI rozeti, demo kullanıcılar, örnek `curl`, **ilham kaynağı: PagerDuty** (yalnızca burada), adaptasyonun tek cümlelik açıklaması ve forum kaynakları
- [ ] `AGENT.md` **son sürüm**ü güncelle ve commit'le. Diff'i üret:
  `git diff <AGENT.md v1 commit> HEAD -- AGENT.md > docs/agent-md-diff.txt`
- [ ] `docs/G1.md`: her zaman kuralı ve durum geçişi için **dosya:satır** tablosu (sunumdaki "kod yeri sorusu" için)
- [ ] `docs/yapamadiklarim.md`: dürüst liste
- [ ] G2–G4: **insan dolduracak** (tanımları hocadan teyit ediliyor)
- [ ] G5 (yakalanan uydurmalar): **insan dolduracak**; ajan yalnızca kendisinin düzeltildiği yerleri `docs/G5-ajan-notlari.md`'ye not eder

**DUR — son insan kontrolü.**

---

## AGENT.md v1 içeriği (Faz 0'da oluşturulur)

Başlıklar ve ilk içerik:

1. **Proje:** SenAl, tek cümle tanım, `specs.md`'ye referans
2. **Domain sözlüğü TR ↔ EN:** `specs.md` §1 tablosu
3. **Yasak sihirler:** `specs.md` §2 tablosu
4. **Test kuralı:** her zaman kuralı `travel_to` testli; her yasak geçiş testli; sabit çapa zamanı `2026-10-19 10:00 Istanbul`
5. **Konvansiyondan sapmalar:** (başlangıçta boş; ör. `OnCall` ve `EventIngestor` `app/models` altında PORO, `app/services` kullanılmıyor — sebebiyle yazılır)
6. **Komutlar:** `bin/rails test`, `bin/rails db:seed`, `bin/dev`

Son sürümde bu bölümler ajanla birlikte büyür; diff teslim edilir.

---

## docs/G1.md şablonu

| Kural / Geçiş | Dosya | Satır | Test dosyası |
|---|---|---|---|
| Z1 Eskalasyon | `app/models/incident.rb` | | `test/models/incident_escalation_test.rb` |
| Z2 Rotasyon | `app/models/on_call.rb` | | `test/models/on_call_test.rb` |
| Z3 Bayatlama | `app/models/incident.rb` | | |
| Z4 Müsaitlik | `app/models/user.rb` | | |
| Z5 Boşluk | `app/models/schedule.rb`, `app/models/gap_report.rb` | | |
| triggered → acknowledged | `app/models/incident.rb` | | |
| resolved → * yasak | `app/models/incident.rb` | | |

### Ölçüm tablosu (insan doldurur, her fazdan sonra)

| Faz | Çıktı token (ajan arayüzünden) | Düzeltme turu | Yeşil test sayısı | Yakalanan uydurma | Okuyup onaylama süresi (dk) |
|---|---|---|---|---|---|
| 0 | | | | | |
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |
| 6 | | | | | |
| 7 | | | | | |
