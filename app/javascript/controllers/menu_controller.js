import { Controller } from "@hotwired/stimulus"

// Mobilde sidebar üst menüye dönüşür; buton açıp kapatır (data-open). Masaüstünde CSS hep gösterir.
export default class extends Controller {
  static targets = ["button"]

  toggle() {
    const open = this.element.dataset.open !== "true"
    this.element.dataset.open = open
    this.buttonTarget.setAttribute("aria-expanded", open)
  }
}
