# Yapamadıklarım

> Dürüst liste. Yapılamayan, eksik kalan veya doğrulanamayan her şey burada.

## Yapılamayanlar / eksikler

| Faz | Madde | Durum / sebep |
|---|---|---|
| 0 | Canlı URL, deploy | Yapılmadı. Deploy platformu kararı insana bırakıldı ve ertelendi. |
| 0 | CI rozetinin yeşil olduğu | Doğrulanmadı. Push ertelendi; GitHub Actions hiç çalışmadı. CI adımları (rubocop, brakeman, bundler-audit, importmap audit, test) yalnızca yerelde geçti. |
| 6 | Panoda Turbo Stream ile canlı olay listesi | Yapılmadı (planda opsiyonel). Pano sayfa yenilenince güncellenir. |
| 6 | Takvim üyeliklerini ve eskalasyon politikalarını arayüzden düzenleme | Yapılmadı; spec §7'de istenmiyor. Seed veya konsolla yönetilir. Takvim sayfası üyeleri ve sırasını yalnızca gösterir. |
| 6 | Kopyala butonu (`navigator.clipboard`) | Tarayıcıda elle denenmedi; yalnızca butonun ve komutun sayfada olduğu test edildi. Clipboard API yalnızca HTTPS veya localhost'ta çalışır. |

## Kapsam dışı bırakılanlar (`specs.md` §10)

SMS/telefon araması, mobil uygulama, çok kiracılık, Slack entegrasyonu, SLO/analitik raporlar, otomatik çözme, olay birleştirme (merge), postmortem.
