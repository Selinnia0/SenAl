import { Controller } from "@hotwired/stimulus"

// Seçim değişince formu kendiliğinden gönderir (ör. Roller kartındaki kişi listesi).
// Boş seçenek ("Atanmadı") gönderilmez: rol kaldırılamaz, yalnızca başka birine verilir.
export default class extends Controller {
  submit(event) {
    if (event.target.value === "") return

    this.element.requestSubmit()
  }
}
