# G5 — Ajan notları

> Ajanın düzeltildiği veya kendi hatasını yakaladığı yerler. İnsanın yakaladığı uydurmalar `G5.md`'de (insan doldurur).

## İnsan tarafından düzeltilen

Bu oturumda insan ajanın bir uydurmasını veya hatalı iddiasını düzeltmedi. İnsanın istekleri (kayıt sayfası, push/deploy'un ertelenmesi) kapsam kararlarıydı.

## Ajanın kendi yakaladığı hatalar

| Faz | Ne oldu | Nasıl yakalandı | Düzeltme |
|---|---|---|---|
| 3 | API test yardımcısı `post_event(payload, key:)` imzası yüzünden `post_event event_action: ...` çağrıları anahtar argüman sayıldı; 9 test `ArgumentError` verdi. | Test çıktısı | İmza `post_event(key:, **payload)` yapıldı. Hata koddaydı değil testteydi. |
| 4 | Bayatlama testine anlamsız bir satır (`@incident.travel_escalation_to_level_one = nil if false`) yazıldı. | Çalıştırmadan önce okuyarak | Satır silindi, yerine açıklayıcı yorum. |
| 4 | Faz 1 ve 3'te yazılan iki test, Faz 4'te spec'in getirdiği davranışla (retrigger bildirimi, boşluk atlama) çelişti. | Tam test koşusu | Testler spec'e göre güncellendi; commit mesajında belirtildi. |
| 6 | `Schedule#gaps` örneklemeyi `from`'un dakikasından başlattığı için boşluk "00:52 – 00:52" raporlandı (gerçekte 00:00 – 00:00). Faz 5 testleri çapa tam saat olduğu için bunu yakalamadı. | Seed ile yerelde çalıştırınca çıktıyı okuyarak | Önce kırmızı bir test yazıldı, sonra örnekler saat başına hizalandı. |
| 6 | Test veritabanında `db:seed:replant` çalıştırıldıktan sonra fixture'ı olmayan tablolarda seed kayıtları kaldı, fixture yüklemesi yabancı anahtar hatası verdi. | Test çıktısı | `bin/rails db:test:prepare`. Kod hatası değil; AGENT.md'ye not edildi. |
| 4 | `SolidQueue::Configuration#recurring_tasks` geliştirme ortamında veritabanı tablosu istediği için doğrulama komutu hata verdi. | Komut çıktısı | Veritabanına dokunmayan `recurring_tasks_config` kaynak koddan bulunup kullanıldı. |
