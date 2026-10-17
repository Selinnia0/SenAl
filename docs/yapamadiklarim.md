# Yapamadıklarım

> Dürüst liste. Yapılamayan, eksik kalan veya doğrulanamayan her şey burada.

## Yapılamayanlar / eksikler

| Faz | Madde | Durum / sebep |
|---|---|---|
| 0, 7 | **Canlı URL, canlıya alma** | Yapılmadı. Deploy platformu kararı insana bırakıldı ve ertelendi. README'de canlı URL yok. Canlıya alma gereksinimleri README'de "Canlıya alma gereksinimleri" bölümünde. |
| 0 | Production veritabanı kararı (SQLite / PostgreSQL) | Verilmedi; platforma bağlı. Kod veritabanından bağımsız yazıldı (ör. `stale_acknowledged` SQL tarih aritmetiği kullanmıyor), ama PostgreSQL ile hiç çalıştırılmadı. |
| 0 | **CI rozetinin yeşil olduğu** | Doğrulanmadı. GitHub'a push ertelendi; GitHub Actions hiç çalışmadı. CI'daki adımlar (rubocop, brakeman, bundler-audit, importmap audit, `bin/rails db:test:prepare test`) yalnızca yerelde geçti. `.ruby-version` 4.0.7; `ruby/setup-ruby`'nin bu sürümü kurabildiği doğrulanmadı. |
| 7 | Canlıda `db:seed` | Yapılmadı (canlı ortam yok). Seed yerelde geliştirme ve test ortamında çalıştırıldı, tekrar çalıştırılabilir olduğu denendi. |
| 7 | Canlıda Solid Queue ile "5 dk bekle, eskalasyonu gör" | Yapılmadı (canlı ortam yok). Eskalasyon mantığı `travel_to` testleriyle doğrulandı; `config/recurring.yml`'nin Solid Queue tarafından okunduğu ve zamanlamaların (`* * * * *`, `0 8 * * * Europe/Istanbul`) Fugit ile ayrıştırıldığı konsolda doğrulandı. Gerçek bir Solid Queue süreci hiç çalıştırılmadı. |
| 7 | README'de forum ve Capterra bağlantıları | Eklenmedi. Ajan bağlantıları doğrulayamadığı için uydurmadı; insan ekleyecek. |
| 7 | G2–G4, G5 | İnsan dolduracak (plan gereği). |
| 6 | Panoda Turbo Stream ile canlı olay listesi | Yapılmadı (planda opsiyonel). Pano sayfa yenilenince güncellenir. |
| 6 | Takvim üyeliklerini ve eskalasyon politikalarını arayüzden düzenleme | Yapılmadı; spec §7'de istenmiyor. Seed veya konsolla yönetilir. Takvim sayfası üyeleri ve sırasını yalnızca gösterir. |
| 6 | Kopyala butonu (`navigator.clipboard`) | Tarayıcıda elle denenmedi; yalnızca butonun ve komutun sayfada olduğu test edildi. Clipboard API yalnızca HTTPS veya localhost'ta çalışır. |
| 6 | Tarayıcıda görsel kontrol | Sayfalar gerçek sunucuda `curl` ile gezildi (15 sayfa 200, akış uçtan uca çalıştı), ama hiçbir sayfa bir tarayıcıda açılıp görsel olarak incelenmedi. |
| — | E-posta bildirimi | Yalnızca uygulama içi bildirim var (spec §2'ye göre yeterli). Şifre sıfırlama e-postası dışında e-posta gönderilmiyor; canlıda SMTP ayarı yok. |

## Kapsam dışı bırakılanlar (`specs.md` §10)

SMS/telefon araması, mobil uygulama, çok kiracılık, Slack entegrasyonu, SLO/analitik raporlar, otomatik çözme, olay birleştirme (merge), postmortem.
