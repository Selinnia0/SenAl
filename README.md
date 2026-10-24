# SenAl

[![CI](https://github.com/Selinnia0/SenAl/actions/workflows/ci.yml/badge.svg)](https://github.com/Selinnia0/SenAl/actions/workflows/ci.yml)

Üniversite BT birimleri ve araştırma laboratuvarları için nöbet, olay yönetimi ve durum sayfası. Alarm gelir, o an
nöbetçi olan kişi çağrılır; "Gördüm" denmezse sıradakine eskale edilir. Alarmdan olay ilan edilir, ekip zaman
çizelgesine yazar, öğrenciler durum sayfasından bilgilenir; postmortem ve takip görevleri bitince olay kapanır.

> **Sürümler:** `main` dalı v1'dir (on-call katmanı; canlıdaki sürüm). v2 (olay yönetimi, durum sayfası,
> post-incident, yeni tasarım) `v2-incident-response` dalında. Ayrıntı: [docs/specs.md](docs/specs.md) → "v2".

**Adaptasyon (kim, neden, nasıl):** Üniversite BT birimleri ve araştırma laboratuvarları, nöbetçi asistanlar sınav haftasında veya izindeyken her takvimi tek tek elle düzeltmek zorunda kalmasın diye; kişi iznini bir kez girer, akademik takvim (sınav haftası, bayram, dönem arası) bir kez tanımlanır ve rotasyon bu kişileri **tüm** takvimlerde otomatik atlar, kapanamayan boşluklar önceden yöneticiye bildirilir.

- Canlı URL: _(Render'daki adres, insan tarafından eklenecek; v1 `main` dalından deploy edildi)_
- Ayrıntılı tanım: [docs/specs.md](docs/specs.md) · Uygulama planı: [docs/plan.md](docs/plan.md) · Ajan kuralları: [AGENT.md](AGENT.md)

## İlham kaynakları: PagerDuty → incident.io

- **v1 · PagerDuty:** nöbet takvimi, alarmın doğru kişiye gitmesi ve cevap gelmezse eskalasyon.
- **v2 · incident.io:** alarmdan sonra gelen koordinasyon. Olay ilanı (önem + olay lideri), ekip zaman çizelgesi,
  halka açık durum sayfası, postmortem ve takip görevleri.
- **Neden geçtik:** v1'in akışı alarmın birine ulaşmasında bitiyordu. Şirketlerin asıl para ödediği değer sonrasında:
  kim liderlik ediyor, kullanıcılar ne zaman ne biliyor, aynı olay neden tekrar olmasın. v2 bu katmanı ekler;
  v1'in eskalasyonu ve 100+ adaptasyonu (izin, akademik takvim) korunur ve yeni akışa bağlanır (ör. olay lideri
  önerisi izindeki kişiyi önermez).

Ürün adları yalnızca burada "ilham kaynağı" olarak geçer; uygulamada orijinal ad, logo veya alev ikonu yoktur
(koruma testi: `test/controllers/design_system_test.rb`). Fontlar açık lisanslı (Newsreader, Inter, Geist Mono).

## Aort dilimi (v2)

```
Alarm gelir (API / deneme formu)
  → nöbetçi çağrılır, "Gördüm" gelmezse eskalasyon
  → alarmdan olay ilan edilir: önem + olay lideri (zorunlu; öneri = müsait nöbetçi)
  → ekip zaman çizelgesine güncelleme yazar, durum ilerler (triage → investigating → fixing → monitoring → resolved)
  → durum sayfası güncellenir; çözülünce otomatik "resolved"
  → post-incident: postmortem + takip görevleri tamamlanınca closed
```

## Zaman kuralları

Hepsi `travel_to` ile testli, sınırın iki yanı denenir. Kod ve test yerleri: [docs/G1.md](docs/G1.md).

| # | Kural | Katman |
|---|---|---|
| Z1 | Alarm 5 dk "Gördüm" alınmazsa sonraki seviyeye eskalasyon | Alarm |
| Z2 | Nöbet rotasyonu (`rotation_days`) | Nöbet |
| Z3 | Aktif critical olayda 30 dk, major'da 60 dk güncelleme yoksa "güncelleme gecikti" + hatırlatıcı | Olay |
| Z4 | critical/major olay çözüldükten 5 gün sonra postmortem yoksa "postmortem gecikti" + hatırlatıcı | Olay |
| Z5 | Çözülmüş halka açık olay durum sayfası geçmişinde 7 gün görünür | Durum sayfası |
| Z6 | İzinli / akademik kapanma dönemindeki kişi çağrılmaz ve olay lideri olarak önerilmez (adaptasyon) | Nöbet + Olay |
| Z7 | "Gördüm" denip 4 saat çözülmeyen alarm yeniden tetiklenir | Alarm |
| Z8 | Önümüzdeki 7 gündeki nöbet boşlukları her sabah 08:00'de yöneticiye bildirilir (adaptasyon) | Nöbet |

Her dakika çalışan iş (Solid Queue): Z1, Z7, Z3, Z4. Demo için beklemeden: **Zaman sıçraması** (aşağıda).


## Yerelde çalıştırma

```sh
bin/setup --skip-server  # bağımlılıklar + SQLite veritabanı (+ seed)
bin/rails db:seed        # demo verisi (tekrar çalıştırılabilir)
bin/dev                  # http://localhost:3000 — Solid Queue Puma'nın içinde çalışır
```

`bin/dev` canlıdakiyle aynı şekilde Solid Queue'yu da başlatır: eskalasyon taraması her dakika, boşluk raporu her gün 08:00
(`config/recurring.yml`). Geliştirme ve test SQLite, canlı PostgreSQL kullanır.

## Test

```sh
bin/rails test
bin/ci             # CI'daki tüm adımlar (rubocop, brakeman, audit, test)
```

## Demo kullanıcılar

`bin/rails db:seed` ile oluşur. **Demo şifresi (tümü): `senal-demo`** — yalnızca demo içindir.

| E-posta | Ad | Rol | Akademik rol |
|---|---|---|---|
| `yonetici@senal.test` | Selin Yönetici | Yönetici | Personel |
| `ayse@senal.test` | Ayşe Kaya | Nöbetçi | Asistan |
| `mehmet@senal.test` | Mehmet Arslan | Nöbetçi | Asistan |
| `burak@senal.test` | Burak Demir | Nöbetçi | Personel |
| `zeynep@senal.test` | Zeynep Şahin | Nöbetçi | Personel |

Seed ayrıca 2 takvim (BT Altyapı, Laboratuvar), 2 seviyeli eskalasyon politikası, "Öğrenci Bilgi Sistemi" servisi,
yarından başlayan bir vize haftası (yalnızca asistanlar) ve 2 gün sonrası için Laboratuvar'da kasıtlı bir nöbet boşluğu
(asistanlar vize haftasında, Zeynep izinli) farklı durumlarda 3 alarm ve (v2) farklı aşamalarda 4 olay oluşturur: halka açık kritik ve inceleniyor, alarmdan
ilan edilmiş ve düzeltiliyor, çözülmüş ve postmortem bekliyor, postmortem'iyle kapanmış.

### Demo akışı (v2)

1. `/` (landing) ve `/status` (durum sayfası) girişsiz açılır.
2. Yönetici ile gir → **Servisler → Öğrenci Bilgi Sistemi → Deneme alarmı gönder** → alarm detayında **Olay ilan et**
   (önerilen lider seçili gelir) → olay detayında güncelleme yaz, **İncelemeye al** → **Durum sayfası** kartından yayınla.
3. **Zaman sıçraması +30 dk** → olayda "Güncelleme gecikti" bandı ve lidere hatırlatıcı.
4. **Çözüldü** → durum sayfasında otomatik "Çözüldü"; **Postmortem yaz → Yayınla** → **Kapat**.

### Demo akışı (v1)

1. Yönetici ile gir → **Servisler → Öğrenci Bilgi Sistemi** → `curl` komutunu kopyala ve çalıştır
   (ya da aynı sayfadaki **Deneme alarmı gönder** formunu kullan; API ile aynı kurallar işler).
2. **Pano**'da olay görünür; nöbetçi (ör. Ayşe) **Bildirimlerim**'de görür → olay detayında **Gördüm** → **Çözüldü**.
3. "Gördüm" denmezse 5 dk sonra Laboratuvar nöbetçisine eskale edilir (Solid Queue, her dakika).
   Beklemek yerine **Zaman sıçraması** sayfasından ileri sarın (aşağıda).
4. Adaptasyon: **Akademik takvim**'de vize haftası → asistanlar **tüm** takvimlerden düşer; **Takvimler → Laboratuvar**'da boşluk günü kırmızı, Pano'da "nöbet boşlukları" uyarısı.

## Örnek alarm (`curl`)

`<INTEGRATION_KEY>` servisin entegrasyon anahtarıdır (Servisler sayfasında görünür). Yerelde `http://localhost:3000`.

```sh
# Olay aç (severity: critical | error → yüksek aciliyet, eskale edilir; warning | info | yok → düşük)
curl -X POST http://localhost:3000/api/v1/events \
  -H "Authorization: Token token=<INTEGRATION_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"event_action":"trigger","dedup_key":"disk-full-db1","summary":"db1 disk %95","severity":"critical"}'

# Üstlen / çöz
curl -X POST http://localhost:3000/api/v1/events \
  -H "Authorization: Token token=<INTEGRATION_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"event_action":"resolve","dedup_key":"disk-full-db1"}'
```

Yanıtlar: `202` `{"status":"triggered|deduplicated|acknowledged|resolved","alert_id":1,"dedup_key":"..."}` ·
`401` geçersiz anahtar · `404` açık olay yok · `409` izin verilmeyen geçiş · `422` bozuk gövde.

## Zaman sıçraması (demo / test aracı)

Yönetici menüsünde **Zaman sıçraması** (`/time_skip/new`): zaman kurallarını beklemeden görmek için 1 dakika ile
7 gün arası ileri sarar (+1 dk, +5 dk, +10 dk, +30 dk, +1 saat, +4 saat, +1 gün, +5 gün butonları).

- Sunucu saati **değişmez**. Açık alarmların ve olayların bütün zamanları (açılış, görülme, son güncelleme, çözülme,
  zaman çizelgeleri, durum sayfası güncellemeleri, bildirimler) girilen süre kadar geriye kaydırılır ve her kural
  anında gerçek metotlar çalışır: `Alert.escalate_due!` (Z1), `Alert.retrigger_stale!` (Z7),
  `Incident.remind_overdue_updates!` (Z3), `Incident.remind_overdue_postmortems!` (Z4). Z5 bir scope olduğu için
  kaydırma yeterli. Örn. +12 dk → 5. ve 10. dakikada iki eskalasyon; +30 dk → kritik olayda güncelleme hatırlatıcısı.
- Nöbet rotasyonu, izinler ve akademik takvim gerçek saate göre hesaplanır; çözülmüş alarmlara dokunulmaz.
- Geliştirme/testte açık; canlıda yalnızca `TIME_SKIP_ENABLED=1` ise açık (Render Blueprint'inde açık). Kapalıyken sayfa 404.

Örnek: Servisler'deki `curl` ile alarm gönder → Zaman sıçraması → **+5 dk** → olay Laboratuvar nöbetçisine eskale olur;
**+5 dk** daha → seviye 1'e, yeni tura döner; turlar bitince yöneticilere "Eskalasyon tükendi" bildirimi.

## Canlıya alma (Render, ücretsiz)

**Neden Render:** Uygulama sürekli çalışan bir sunucu ve her dakika çalışan arka plan işi (Solid Queue) gerektirir.
Vercel sunucusuz (serverless) olduğu için Rails'i ve kalıcı arka plan işlerini çalıştıramaz. Render'ın ücretsiz
planında Docker web servisi ve PostgreSQL var. Kalıcı disk olmadığı için canlıda SQLite yerine PostgreSQL kullanılır.

Altyapı repoda hazır: [`render.yaml`](render.yaml) (Blueprint), [`Dockerfile`](Dockerfile),
[`bin/docker-entrypoint`](bin/docker-entrypoint) (`db:prepare` + `SEED_ON_BOOT=1` ise `db:seed`).

### Adımlar

1. Kodu GitHub'a gönder (`main`) ve Actions'ta CI'ın yeşil olduğunu gör.
2. https://dashboard.render.com → GitHub ile giriş → **New → Blueprint**.
3. `Selinnia0/SenAl` reposunu seç. Render `render.yaml`'ı okur ve iki kaynak gösterir:
   `senal-db` (PostgreSQL 16, free, Frankfurt) ve `senal` (Docker web servisi, free, Frankfurt).
4. **Apply / Deploy Blueprint**. Ek ayar gerekmez: `DATABASE_URL` veritabanından bağlanır,
   `SECRET_KEY_BASE` Render tarafından üretilir. `RAILS_MASTER_KEY` gerekmez.
5. İlk derleme birkaç dakika sürer. Loglarda sırasıyla `db:prepare`, `Seed tamam: ...` ve
   `Started Scheduler ... recurring_schedule: ["escalation_sweep", "gap_report", ...]` görünür.
6. Servis sayfasındaki `https://senal-xxxx.onrender.com` adresini aç, `yonetici@senal.test` / `senal-demo` ile gir.
7. Canlı URL'yi bu README'nin başına ekle.

Sonraki her `main` push'unda CI geçerse Render otomatik deploy eder (`autoDeployTrigger: checksPass`).
CI kırmızıysa deploy olmaz; Render panelindeki **Manual Deploy** ile elle tetiklenebilir.

### Sorun giderme

- **`PG::UndefinedTable: relation "solid_queue_recurring_tasks" does not exist`**: veritabanı hazırlanmadan sunucu açılmış.
  Servisin **Settings → Docker Command** değeri `./bin/docker-entrypoint ./bin/rails server` olmalı (Blueprint senkronize
  olunca kendiliğinden gelir; gelmediyse elle yaz) → **Manual Deploy → Deploy latest commit**. Loglarda `Seed tamam`
  ve `Started Scheduler` görünmeli.

### Ortam değişkenleri (`render.yaml`)

| Değişken | Değer | Ne işe yarar |
|---|---|---|
| `DATABASE_URL` | veritabanından | PostgreSQL bağlantısı |
| `SECRET_KEY_BASE` | Render üretir | Oturum çerezleri |
| `PORT` | `10000` | Puma `0.0.0.0:$PORT` dinler |
| `SOLID_QUEUE_IN_PUMA` | `1` | Arka plan işleri Puma ile aynı süreçte (`async`); ayrı worker servisi gerekmez |
| `SEED_ON_BOOT` | `1` | Her açılışta `db:seed` (tekrar çalıştırılabilir; demo verisini tazeler) |
| `TIME_SKIP_ENABLED` | `1` | Zaman sıçraması sayfası açık |
| `RAILS_FORCE_SSL` | (yok → `1`) | HTTPS zorunlu; production'ı yerelde HTTP ile denemek için `0` |

### Ücretsiz planın sınırları (Render belgeleri, Ekim 2026)

- Servis **15 dakika** istek almazsa uyur; ilk istekte yaklaşık **1 dakikada** uyanır. Uyurken Solid Queue de durur;
  uyanınca kaçırılan dakikalar tek tek işlenmez, ilk taramada gecikmiş olaylar birer adım eskale olur.
  Demo için Zaman sıçraması kullanın.
- Ücretsiz PostgreSQL **oluşturulduktan 30 gün sonra sona erer** (14 gün ek süre, sonra silinir); 1 GB, yedek yok.
  Süre dolunca yeni bir ücretsiz veritabanı oluşturup `DATABASE_URL`'yi güncellemek ya da ücretli plana geçmek gerekir.
- Ayda 750 ücretsiz instance saati; tek instance.

## Yapamadıklarım / bilerek dışarıda bıraktıklarım

**Bilerek kapsam dışı (v2):** AI kök neden analizi, Slack/Teams entegrasyonu, çağrı transkripti, gerçek SMS/telefon
araması, çoklu organizasyon. (v1'den: mobil uygulama, SLO/analitik raporlar, otomatik çözme, olay birleştirme.)

**Yapamadıklarım / doğrulanmadı** (tam liste: [docs/yapamadiklarim.md](docs/yapamadiklarim.md)):
- v2 tarayıcıda görsel olarak doğrulanmadı ve henüz canlıya alınmadı (`v2-incident-response` dalı).
- Canlı güncellemenin iki tarayıcı arasında çalıştığı elle denenmedi; yayın testli, WebSocket el sıkışması denendi.
- Gecikme bantları (Z3/Z4) zaman geçince sayfayı kendiliğinden yenilemez; hatırlatıcı bildirimi gider.
- "5 gün" takvim günüdür (iş günü için gem gerekir).
- Takvim, müsaitlik, servis ve akademik takvim ekranları yeni temel stillerle çalışır ama bileşenlere taşınmadı.

## Adaptasyonun kaynakları

- PagerDuty topluluk forumu: izin/tatilde kişiyi her takvimden tek tek override ile çıkarma şikâyeti ve destek ekibinin bunun tek yol olduğunu doğrulaması — _(bağlantı insan tarafından eklenecek)_
- Capterra: takvim özelliğiyle ilgili yorumlar — _(bağlantı insan tarafından eklenecek)_
