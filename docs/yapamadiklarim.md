# Yapamadıklarım

> Dürüst liste. Yapılamayan, eksik kalan veya doğrulanamayan her şey burada.

## Yapılamayanlar / eksikler

| Faz | Madde | Durum / sebep |
|---|---|---|
| 0, 7 | **Canlı URL** | Henüz yok. Platform Render seçildi, altyapı hazır (`render.yaml`, Dockerfile, entrypoint); deploy'u insan yapacak (README "Canlıya alma"). |
| 7 | Docker imajı | Yerelde derlenemedi (makinede Docker yok). CI'daki `docker` işi derliyor; sonucu insan GitHub'da görecek. |
| 7 | Render'da gerçek çalışma | İlk deploy `solid_queue_recurring_tasks` yok hatasıyla düştü (insan bildirdi; sebep `dockerCommand` ile atlanan `db:prepare`, düzeltildi). Düzeltmenin Render'da çalıştığı ajan tarafından doğrulanmadı. Yerine: production modu yerelde taşınabilir PostgreSQL 16 ile, `master.key` olmadan, Render'daki komutla (`bin/docker-entrypoint ./bin/rails server`, `SOLID_QUEUE_IN_PUMA=1`) çalıştırıldı: seed, 15 sayfa, API, zaman sıçraması, gerçek Solid Queue her dakikalık iş, ~127 MB bellek. |
| 0 | **CI rozetinin yeşil olduğu** | Ajan doğrulamadı; push edildi, sonucu insan kontrol edecek. Yerelde `bin/ci` yeşil; yeni `production` işinin adımları yerel PostgreSQL'de birebir çalıştırıldı. `.ruby-version` 4.0.7; `ruby/setup-ruby`'nin bu sürümü kurabildiği ve `docker` işi doğrulanmadı. |
| 7 | Canlıda `db:seed` | Entrypoint'te (`SEED_ON_BOOT=1`); yerelde production+PostgreSQL ile iki kez çalıştırıldı. Canlıda çalıştığı doğrulanmadı. |
| 7 | Canlıda "5 dk bekle, eskalasyonu gör" | İnsan Zaman sıçraması sayfasından deneyecek. Yerelde gerçek Solid Queue'nun her dakikalık işi hem SQLite (geliştirme) hem PostgreSQL (production) üzerinde çalıştı. |
| 7 | Render ücretsiz plan sınırları | Servis 15 dk boşta kalınca uyur (Solid Queue da durur); ücretsiz PostgreSQL 30 günde sona erer. Belgelerden doğrulandı, README'de. |
| 7 | README'de forum ve Capterra bağlantıları | Eklenmedi. Ajan bağlantıları doğrulayamadığı için uydurmadı; insan ekleyecek. |
| 7 | G2–G4, G5 | İnsan dolduracak (plan gereği). |
| 6 | Panoda Turbo Stream ile canlı olay listesi | Yapılmadı (planda opsiyonel). Pano sayfa yenilenince güncellenir. |
| 6 | Takvim üyeliklerini ve eskalasyon politikalarını arayüzden düzenleme | Yapılmadı; spec §7'de istenmiyor. Seed veya konsolla yönetilir. Takvim sayfası üyeleri ve sırasını yalnızca gösterir. |
| 6 | Kopyala butonu (`navigator.clipboard`) | Tarayıcıda elle denenmedi; yalnızca butonun ve komutun sayfada olduğu test edildi. Clipboard API yalnızca HTTPS veya localhost'ta çalışır. |
| 6 | Tarayıcıda görsel kontrol | Sayfalar gerçek sunucuda `curl` ile gezildi (15 sayfa 200, akış uçtan uca çalıştı), ama hiçbir sayfa bir tarayıcıda açılıp görsel olarak incelenmedi. |
| — | E-posta bildirimi | Yalnızca uygulama içi bildirim var (spec §2'ye göre yeterli). Şifre sıfırlama e-postası dışında e-posta gönderilmiyor; canlıda SMTP ayarı yok. |

## Kapsam dışı bırakılanlar (`specs.md` §10)

SMS/telefon araması, mobil uygulama, çok kiracılık, Slack entegrasyonu, SLO/analitik raporlar, otomatik çözme, olay birleştirme (merge), postmortem.
