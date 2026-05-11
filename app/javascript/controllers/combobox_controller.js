// Searchable combobox: a hidden input carries the chosen value, a button
// renders the current selection, and a panel lists options that can be
// filtered by a search box.
//
// Markup contract:
//   <div data-controller="combobox" data-combobox-placeholder-value="Choose…">
//     <input type="hidden" name="..." value="..." data-combobox-target="input">
//     <button type="button" data-action="click->combobox#toggle"
//             data-combobox-target="button">
//       <span data-combobox-target="display"></span>
//     </button>
//     <div data-combobox-target="panel" hidden>
//       <input type="search" data-combobox-target="search"
//              data-action="input->combobox#filter">
//       <ul data-combobox-target="list">
//         <li data-combobox-target="option" data-value="1"
//             data-display="Cash" data-search="cash usd"
//             data-action="click->combobox#select">…</li>
//       </ul>
//     </div>
//   </div>
//
// On select, the wrapper element dispatches a `change` event so outer
// Stimulus controllers can react.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "display", "panel", "search", "list", "option"]
  static values = { placeholder: String }

  connect() {
    this.outsideClick = this.#handleOutsideClick.bind(this)
    this.#syncDisplay()
    this.#syncSelectedAttrs()
  }

  #syncSelectedAttrs() {
    const value = this.inputTarget.value
    const match = this.optionTargets.find((o) => o.dataset.value === value)
    if (match) this.#propagateAttrs(match)
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
    this.#propagateAttrs(option)
    this.#renderDisplay(option)
    this.close()
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  #propagateAttrs(option) {
    // Mirror option's data-* attributes (except the combobox-internal ones)
    // onto the wrapper so outer controllers can read them like dataset.currency.
    const skip = new Set(["value", "display", "search", "comboboxTarget", "action"])
    Object.keys(option.dataset).forEach((key) => {
      if (skip.has(key)) return
      this.element.dataset[key] = option.dataset[key]
    })
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

  #syncDisplay() {
    const value = this.inputTarget.value
    const match = this.optionTargets.find((o) => o.dataset.value === value)
    if (match) {
      this.#renderDisplay(match)
    } else {
      this.displayTarget.textContent = this.placeholderValue || ""
      this.displayTarget.classList.add("text-body-subtle")
    }
  }

  #renderDisplay(option) {
    this.displayTarget.textContent = option.dataset.display || option.textContent.trim()
    this.displayTarget.classList.remove("text-body-subtle")
  }
}
