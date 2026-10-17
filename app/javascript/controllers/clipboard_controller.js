import { Controller } from "@hotwired/stimulus"

// <div data-controller="clipboard"><pre data-clipboard-target="source">…</pre>
// <button data-action="clipboard#copy">Kopyala</button></div>
export default class extends Controller {
  static targets = ["source"]

  copy(event) {
    navigator.clipboard.writeText(this.sourceTarget.textContent.trim())
    event.currentTarget.textContent = "Kopyalandı"
  }
}
