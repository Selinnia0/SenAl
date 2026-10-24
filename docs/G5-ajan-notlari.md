# G5 — Ajan notları

> Ajanın düzeltildiği veya kendi hatasını yakaladığı yerler. İnsanın yakaladığı uydurmalar `G5.md`'de (insan doldurur).

## İnsan tarafından düzeltilen

| Ne oldu | Ajanın iddiası | Gerçek | Düzeltme |
|---|---|---|---|
| İlk Render deploy'u `PG::UndefinedTable: relation "solid_queue_recurring_tasks" does not exist` ile düştü; hatayı insan bildirdi. | "Prod ready"; production yerelde PostgreSQL ile doğrulandı. | Yerel doğrulama `bin/docker-entrypoint ./bin/rails server` ile yapılmıştı; Render ise `dockerCommand: ./bin/rails server` ile entrypoint'i atladı (ya da komutu kabukla verdi), `db:prepare` hiç çalışmadı. Ajan yerel testte Render'ın komutu nasıl çağırdığını değil, kendi varsaydığı çağrıyı denedi; CI'daki `production` işi de `db:prepare`'i elle çalıştırdığı için açığı göremedi. | Hata yerelde birebir üretildi; entrypoint sağlamlaştırıldı, `dockerCommand` entrypoint'i açıkça çağırıyor, 5 çağrı biçimi boş veritabanında denendi; CI `docker` işi imajı Render gibi çalıştırıyor. |

Bundan önce insan ajanın bir uydurmasını düzeltmedi; istekleri (kayıt sayfası, push/deploy zamanlaması, zaman sıçraması) kapsam kararlarıydı.

## Ajanın kendi yakaladığı hatalar

| Faz | Ne oldu | Nasıl yakalandı | Düzeltme |
|---|---|---|---|
| 3 | API test yardımcısı `post_event(payload, key:)` imzası yüzünden `post_event event_action: ...` çağrıları anahtar argüman sayıldı; 9 test `ArgumentError` verdi. | Test çıktısı | İmza `post_event(key:, **payload)` yapıldı. Hata koddaydı değil testteydi. |
| 4 | Bayatlama testine anlamsız bir satır (`@incident.travel_escalation_to_level_one = nil if false`) yazıldı. | Çalıştırmadan önce okuyarak | Satır silindi, yerine açıklayıcı yorum. |
| 4 | Faz 1 ve 3'te yazılan iki test, Faz 4'te spec'in getirdiği davranışla (retrigger bildirimi, boşluk atlama) çelişti. | Tam test koşusu | Testler spec'e göre güncellendi; commit mesajında belirtildi. |
| 6 | `Schedule#gaps` örneklemeyi `from`'un dakikasından başlattığı için boşluk "00:52 – 00:52" raporlandı (gerçekte 00:00 – 00:00). Faz 5 testleri çapa tam saat olduğu için bunu yakalamadı. | Seed ile yerelde çalıştırınca çıktıyı okuyarak | Önce kırmızı bir test yazıldı, sonra örnekler saat başına hizalandı. |
| 6 | Test veritabanında `db:seed:replant` çalıştırıldıktan sonra fixture'ı olmayan tablolarda seed kayıtları kaldı, fixture yüklemesi yabancı anahtar hatası verdi. | Test çıktısı | `bin/rails db:test:prepare`. Kod hatası değil; AGENT.md'ye not edildi. |
| 4 | `SolidQueue::Configuration#recurring_tasks` geliştirme ortamında veritabanı tablosu istediği için doğrulama komutu hata verdi. | Komut çıktısı | Veritabanına dokunmayan `recurring_tasks_config` kaynak koddan bulunup kullanıldı. |

## v2 (olay yönetimi) — ajanın kendi yakaladığı hatalar ve yanlış söyledikleri

| Faz | Ne oldu | Nasıl yakalandı | Düzeltme |
|---|---|---|---|
| B | PostgreSQL'de `AddIncidentIdToNotifications` `PG::DuplicateObject` ile düştü: `rename_column` FK kısıt adını korumuştu, yeni FK aynı adı üretti. SQLite'ta ve bütün testlerde görünmedi. | `main` şeması + seed ile dolu PostgreSQL'de yükseltme denemesi (worktree + taşınabilir PostgreSQL 16) | Yeni migration `RenameNotificationsAlertForeignKey`; yükseltme ve sıfırdan kurulum yeniden denendi |
| B | Yeni migration'ı `CreateIncidents` adıyla üretmeye çalıştı; v1'de aynı sınıf vardı. Sonra zaman damgası FK'lerin önüne düştü. | Generator uyarısı / dosya sırası | `CreateResponseIncidents`, zaman damgası öne alındı (henüz çalışmamıştı) |
| B | `TimelineEvent` enum'unda `update` değeri `update!` ile çakışıyordu. | Konsolda önceden denendi | `prefix: true` |
| C | Testte `assert_no_difference`'a dizi döndüren lambda verdi; bir test yeni 7 günlük sınırı aşan süre denedi. | Test çıktısı | `assert_no_changes`; iki adımlı sıçrama |
| D | **Kullanıcıya yanlış sayı söyledi:** "10 testin 7'si ilk çalıştırmada geçti" dedi; doğrusu 6'ydı (helper testi de kırmızıydı). | Sonraki test çıktısı | Kullanıcıya düzeltildiği söylendi |
| D | "Önce test" kuralına tam uymadı: CSS, partial ve kabuğu testlerden önce yazdı. | Kendi değerlendirmesi | Faz D özetinde açıkça belirtildi |
| D | `--sa-accent-strong`'a `--sa-accent-hover` ile aynı hex'i iki kez yazdı (spec: değer tekrar yazılmaz). | Yazdıktan sonra okuyarak | `var(--sa-accent-hover)` |
| E | **CSS yorumlarına hesaplamadan kontrast oranı yazdı** (11.7 / 12.9 / 11.3); gerçeği 10.9 / 12.1 / 11.1. | Hemen ardından hesaplayarak | Yorumlar düzeltildi, sonra değerler token'a taşındı |
| E | `PostmortemsController#publish` içine gereksiz ve okunmaz bir satır yazdı. | Kendi okuması | Domain doğrulamasına bırakıldı (tek satır) |
| F | AGENT.md'ye "tokens.css dışında hex yok" yazdı; kodda 8 sabit renk vardı. | Kuralı grep ile doğrularken | Renkler token'a taşındı, koruma testi eklendi |
| B | Doğrulama komutunda var olmayan bir metot (`migration_context`) kullandı. | Komut çıktısı | Sonuç başka çıktıdan okundu; uygulamayla ilgisi yok |

