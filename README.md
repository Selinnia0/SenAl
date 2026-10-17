# SenAl

[![CI](https://github.com/Selinnia0/SenAl/actions/workflows/ci.yml/badge.svg)](https://github.com/Selinnia0/SenAl/actions/workflows/ci.yml)

Nöbet ve olay müdahale (on-call & incident response) uygulaması. Alarm gelir → nöbetçiye bildirilir → nöbetçi "Gördüm" der → sorun "Çözüldü" olur. "Gördüm" denmezse bir üst seviyeye eskale edilir.

**Adaptasyon (kim, neden, nasıl):** Üniversite BT birimleri ve araştırma laboratuvarları, nöbetçi asistanlar sınav haftasında veya izindeyken her takvimi tek tek elle düzeltmek zorunda kalmasın diye; kişi iznini bir kez girer, akademik takvim (sınav haftası, bayram, dönem arası) bir kez tanımlanır ve rotasyon bu kişileri **tüm** takvimlerde otomatik atlar, kapanamayan boşluklar önceden yöneticiye bildirilir.

**İlham kaynağı:** PagerDuty.

- Canlı URL: _(henüz yok — deploy platformu kararı bekleniyor; bkz. [docs/yapamadiklarim.md](docs/yapamadiklarim.md))_
- Ayrıntılı tanım: [docs/specs.md](docs/specs.md) · Uygulama planı: [docs/plan.md](docs/plan.md) · Ajan kuralları: [AGENT.md](AGENT.md)

## Kurulum

```sh
bin/setup          # bağımlılıklar + veritabanı
bin/rails db:seed  # demo verisi
bin/dev            # http://localhost:3000
```

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

## Canlıya alma gereksinimleri

- `RAILS_MASTER_KEY` ortam değişkeni (`config/master.key`, repoda yok).
- **Solid Queue mutlaka çalışmalı**, yoksa eskalasyon (her dakika) ve boşluk raporu (her gün 08:00) hiç tetiklenmez:
  tek süreçte `SOLID_QUEUE_IN_PUMA=1` ile Puma içinde, ya da ayrı bir `bin/jobs` süreci.
- Veritabanı: kalıcı disk varsa SQLite (`storage/`); yoksa yalnızca `production` için PostgreSQL'e geçilmeli.
- İlk kurulumdan sonra `bin/rails db:seed`.

## Adaptasyonun kaynakları

- PagerDuty topluluk forumu: izin/tatilde kişiyi her takvimden tek tek override ile çıkarma şikâyeti ve destek ekibinin bunun tek yol olduğunu doğrulaması — _(bağlantı insan tarafından eklenecek)_
- Capterra: takvim özelliğiyle ilgili yorumlar — _(bağlantı insan tarafından eklenecek)_
