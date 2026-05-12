import { Controller } from "@hotwired/stimulus"

// Multi-select combobox: renders selected options as chips inside the trigger
// and keeps a parallel set of hidden inputs so the form posts the array.
//
// Wire-compatible with `f.collection_select :foo_ids, ..., multiple: true`
// (the Rails idiom of submitting a leading empty value is preserved).
export default class extends Controller {
  static targets = ["hiddenContainer", "button", "chips", "panel", "search", "group", "option"]
  static values = { placeholder: String, name: String, removeLabel: String }

  connect() {
    this.outsideClick = this.#handleOutsideClick.bind(this)
    this.selectedIds = new Set(this.#initialSelectedIds())
    this.#render()
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

  toggleOption(event) {
    event.preventDefault()
    const option = event.currentTarget
    const id = option.dataset.value
    if (!id) return
    if (this.selectedIds.has(id)) {
      this.selectedIds.delete(id)
    } else {
      this.selectedIds.add(id)
    }
    this.#render()
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  removeChip(event) {
    event.preventDefault()
    event.stopPropagation()
    const id = event.currentTarget.dataset.value
    if (!id) return
    this.selectedIds.delete(id)
    this.#render()
    this.element.dispatchEvent(new Event("change", { bubbles: true }))
  }

  #initialSelectedIds() {
    return Array.from(this.hiddenContainerTarget.querySelectorAll("input[type=hidden]"))
      .map((input) => input.value)
      .filter((value) => value !== "")
  }

  #render() {
    this.#renderHiddenInputs()
    this.#renderChips()
    this.#syncOptionHighlight()
  }

  #renderHiddenInputs() {
    this.hiddenContainerTarget.replaceChildren(this.#hiddenInput(""))
    this.selectedIds.forEach((id) => {
      this.hiddenContainerTarget.appendChild(this.#hiddenInput(id))
    })
  }

  #hiddenInput(value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = this.nameValue
    input.value = value
    return input
  }

  #renderChips() {
    this.chipsTarget.replaceChildren()
    if (this.selectedIds.size === 0) {
      const placeholder = document.createElement("span")
      placeholder.className = "text-body-subtle"
      placeholder.textContent = this.placeholderValue || ""
      this.chipsTarget.appendChild(placeholder)
      return
    }
    this.selectedIds.forEach((id) => {
      const option = this.optionTargets.find((o) => o.dataset.value === id)
      if (!option) return
      this.chipsTarget.appendChild(this.#buildChip(id, option.dataset.display || id))
    })
  }

  #buildChip(id, label) {
    const chip = document.createElement("span")
    chip.className = "inline-flex items-center gap-1 px-2 py-0.5 text-xs font-medium text-heading bg-neutral-secondary-medium border border-default-medium rounded-full"

    const hash = document.createElement("span")
    hash.className = "text-body-subtle"
    hash.textContent = "#"
    chip.appendChild(hash)

    const name = document.createElement("span")
    name.textContent = label
    chip.appendChild(name)

    const remove = document.createElement("button")
    remove.type = "button"
    remove.dataset.action = "click->multi-combobox#removeChip"
    remove.dataset.value = id
    remove.setAttribute("aria-label", this.removeLabelValue || "Remove")
    remove.className = "inline-flex items-center justify-center text-body-subtle hover:text-heading"
    remove.innerHTML = '<svg class="h-3 w-3" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><path stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18 18 6M6 6l12 12"/></svg>'
    chip.appendChild(remove)

    return chip
  }

  #syncOptionHighlight() {
    const selectedClasses = ["bg-brand-soft", "text-fg-brand"]
    this.optionTargets.forEach((option) => {
      const selected = this.selectedIds.has(option.dataset.value)
      option.classList.toggle(selectedClasses[0], selected)
      option.classList.toggle(selectedClasses[1], selected)
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
    if (this.hasGroupTarget) {
      this.groupTargets.forEach((group) => {
        const anyVisible = Array.from(group.querySelectorAll("[data-multi-combobox-target='option']"))
          .some((option) => !option.hidden)
        group.hidden = !anyVisible
      })
    }
  }
}
