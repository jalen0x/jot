import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  connect() {
    this.handleKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.handleKeydown, true)
  }

  disconnect() {
    document.removeEventListener("keydown", this.handleKeydown, true)
  }

  handleKeydown(event) {
    if (event.key.toLowerCase() !== "l") return
    if (!event.metaKey && !event.ctrlKey) return
    if (event.altKey || event.shiftKey || this.submitted) return

    event.preventDefault()
    this.submitted = true
    this.formTarget.requestSubmit()
  }
}
