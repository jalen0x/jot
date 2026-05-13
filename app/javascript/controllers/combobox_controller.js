import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "display", "panel", "search", "list", "option"]
  static values = { placeholder: String }

  connect() {
    this.outsideClick = this.#handleOutsideClick.bind(this)
    this.#syncFromSelected()
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick)
  }

  toggle(event) {
    event?.preventDefault()
    this.panelTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.panelTarget.hidden = false
    document.addEventListener("click", this.outsideClick)
    if (this.hasSearchTarget) {
      this.searchTarget.value = ""
      this.#applyFilter("")
      requestAnimationFrame(() => this.searchTarget.focus())
    }
  }

  close() {
    this.panelTarget.hidden = true
    document.removeEventListener("click", this.outsideClick)
  }

  filter() {
    this.#applyFilter(this.searchTarget.value)
  }

  select(event) {
    const option = event.currentTarget
    this.inputTarget.value = option.dataset.value || ""
    this.element.dataset.currency = option.dataset.currency || ""
    this.#renderDisplay(option)
    this.close()
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  #syncFromSelected() {
    const value = this.inputTarget.value
    const match = this.optionTargets.find((o) => o.dataset.value === value)
    if (match) {
      this.element.dataset.currency = match.dataset.currency || ""
      this.#renderDisplay(match)
    } else {
      this.displayTarget.textContent = this.placeholderValue || ""
      this.displayTarget.classList.add("text-body-subtle")
    }
  }

  #handleOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  #applyFilter(query) {
    const q = query.trim().toLowerCase()
    this.optionTargets.forEach((option) => {
      const haystack = (option.dataset.search || option.textContent).toLowerCase()
      option.hidden = q && !haystack.includes(q)
    })
  }

  #renderDisplay(option) {
    this.displayTarget.textContent = option.dataset.display || option.textContent.trim()
    this.displayTarget.classList.remove("text-body-subtle")
  }
}
