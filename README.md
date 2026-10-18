# SenAl

[![CI](https://github.com/Selinnia0/SenAl/actions/workflows/ci.yml/badge.svg)](https://github.com/Selinnia0/SenAl/actions/workflows/ci.yml)

Nöbet ve olay müdahale (on-call & incident response) uygulaması. Alarm gelir → nöbetçiye bildirilir → nöbetçi "Gördüm" der → sorun "Çözüldü" olur. "Gördüm" denmezse bir üst seviyeye eskale edilir.

**Adaptasyon (kim, neden, nasıl):** Üniversite BT birimleri ve araştırma laboratuvarları, nöbetçi asistanlar sınav haftasında veya izindeyken her takvimi tek tek elle düzeltmek zorunda kalmasın diye; kişi iznini bir kez girer, akademik takvim (sınav haftası, bayram, dönem arası) bir kez tanımlanır ve rotasyon bu kişileri **tüm** takvimlerde otomatik atlar, kapanamayan boşluklar önceden yöneticiye bildirilir.

**İlham kaynağı:** PagerDuty.

- Canlı URL: _(henüz yok — deploy platformu kararı bekleniyor; bkz. [docs/yapamadiklarim.md](docs/yapamadiklarim.md))_
- Ayrıntılı tanım: [docs/specs.md](docs/specs.md) · Uygulama planı: [docs/plan.md](docs/plan.md) · Ajan kuralları: [AGENT.md](AGENT.md)

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
(asistanlar vize haftasında, Zeynep izinli) ve farklı durumlarda 3 olay oluşturur.

### Demo akışı

1. Yönetici ile gir → **Servisler → Öğrenci Bilgi Sistemi** → `curl` komutunu kopyala ve çalıştır.
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

Yanıtlar: `202` `{"status":"triggered|deduplicated|acknowledged|resolved","incident_id":1,"dedup_key":"..."}` ·
`401` geçersiz anahtar · `404` açık olay yok · `409` izin verilmeyen geçiş · `422` bozuk gövde.

## Zaman sıçraması (demo / test aracı)

Yönetici menüsünde **Zaman sıçraması** (`/time_skip/new`): eskalasyonu (5 dk) veya bayatlamış "Gördüm"ü (4 saat)
beklemeden görmek için açık olayları 1–1440 dakika ileri sarar (+1 dk, +5 dk, +10 dk, +30 dk, +1 saat, +4 saat butonları).

- Sunucu saati **değişmez**. Açık olayların bütün zamanları (açılış, görülme, sonraki eskalasyon, zaman çizelgesi,
  bildirimler) girilen süre kadar geriye kaydırılır ve her eskalasyon/bayatlama anında gerçek kurallar
  (`Incident.escalate_due!`, `Incident.retrigger_stale!`) çalışır. Örn. +12 dk → 5. ve 10. dakikada iki eskalasyon.
- Nöbet rotasyonu, izinler ve akademik takvim gerçek saate göre hesaplanır; çözülmüş olaylara dokunulmaz.
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

## Adaptasyonun kaynakları

- PagerDuty topluluk forumu: izin/tatilde kişiyi her takvimden tek tek override ile çıkarma şikâyeti ve destek ekibinin bunun tek yol olduğunu doğrulaması — _(bağlantı insan tarafından eklenecek)_
- Capterra: takvim özelliğiyle ilgili yorumlar — _(bağlantı insan tarafından eklenecek)_
