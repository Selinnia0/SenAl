# SenAl

[![CI](https://github.com/Selinnia0/SenAl/actions/workflows/ci.yml/badge.svg)](https://github.com/Selinnia0/SenAl/actions/workflows/ci.yml)

Nöbet ve olay müdahale (on-call & incident response) uygulaması. Alarm gelir → nöbetçiye bildirilir → nöbetçi "Gördüm" der → sorun "Çözüldü" olur. "Gördüm" denmezse bir üst seviyeye eskale edilir.

**Adaptasyon:** Üniversite BT birimleri ve araştırma laboratuvarları için müsaitlik farkındalıklı nöbet — kişisel izinler ve akademik takvim (sınav haftası, bayram, dönem arası) nöbet rotasyonunda otomatik atlanır, kapanamayan boşluklar önceden yöneticiye bildirilir.

**İlham kaynağı:** PagerDuty.

- Canlı URL: _(Faz 0 deploy kararından sonra eklenecek)_
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

_(Faz 6'da seed ile eklenecek.)_

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

## Adaptasyonun kaynakları

_(Forum ve Capterra bağlantıları insan tarafından eklenecek.)_
