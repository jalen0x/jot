// Dynamic transaction form behavior:
// - transaction_kind selection via pill tab buttons (hidden input carries the value)
// - toggles destination account / destination amount visibility for transfers
// - swaps the source amount label between "Amount" and "Source amount"
// - colors the amount inputs/labels by kind
// - shows the selected account's currency code as a prefix next to each amount
// - evaluates an arithmetic expression typed into an amount input on Enter
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "kindInput",
    "kindTab",
    "sectionTab",
    "section",
    "destinationAccountField",
    "sourceAmountField",
    "sourceAmountLabel",
    "sourceAmountInput",
    "destinationAmountField",
    "destinationAmountInput",
    "sourceAccount",
    "destinationAccount",
    "sourceCurrencyPrefix",
    "destinationCurrencyPrefix"
  ]
  static values = {
    amountLabel: String,
    sourceAmountLabel: String,
    destinationAmountLabel: String,
    amountColors: Object
  }

  connect() {
    this.refresh()
  }

  selectKind(event) {
    const kind = event.currentTarget.dataset.kind
    if (!kind || kind === this.kindInputTarget.value) return
    this.kindInputTarget.value = kind
    this.refresh()
  }

  selectSection(event) {
    const key = event.currentTarget.dataset.section
    if (!key) return
    this.sectionTabTargets.forEach((tab) => {
      const active = tab.dataset.section === key
      tab.setAttribute("aria-selected", active)
      tab.classList.toggle("text-fg-brand", active)
      tab.classList.toggle("text-body", !active)
      tab.classList.toggle("hover:text-heading", !active)
    })
    this.sectionTargets.forEach((section) => {
      section.hidden = section.dataset.section !== key
    })
  }

  sourceAccountChanged() {
    this.updateSourceCurrency()
  }

  destinationAccountChanged() {
    this.updateDestinationCurrency()
  }

  refresh() {
    const kind = this.kindInputTarget.value
    const isTransfer = kind === "transfer"

    this.kindTabTargets.forEach((tab) => {
      const active = tab.dataset.kind === kind
      tab.setAttribute("aria-pressed", active)
      tab.classList.toggle("bg-brand", active)
      tab.classList.toggle("text-white", active)
      tab.classList.toggle("shadow-xs", active)
      tab.classList.toggle("text-body", !active)
      tab.classList.toggle("hover:text-heading", !active)
    })

    this.destinationAccountFieldTarget.hidden = !isTransfer
    this.destinationAmountFieldTarget.hidden = !isTransfer

    if (this.hasSourceAmountLabelTarget) {
      this.sourceAmountLabelTarget.textContent = isTransfer ? this.sourceAmountLabelValue : this.amountLabelValue
    }

    this.#applyAmountColor(kind)
    this.updateSourceCurrency()
    this.updateDestinationCurrency()
  }

  updateSourceCurrency() {
    if (!this.hasSourceCurrencyPrefixTarget) return
    this.sourceCurrencyPrefixTarget.textContent = this.#currencyOf(this.sourceAccountTarget)
  }

  updateDestinationCurrency() {
    if (!this.hasDestinationCurrencyPrefixTarget) return
    this.destinationCurrencyPrefixTarget.textContent = this.#currencyOf(this.destinationAccountTarget)
  }

  // Evaluate an arithmetic expression typed into an amount field.
  // Whitelist guards against arbitrary JS via the Function constructor.
  evaluateAmount(event) {
    const input = event.target
    const expr = input.value
    if (!/[+\-*/()]/.test(expr)) return
    if (!/^[\d+\-*/()\s.]+$/.test(expr)) return

    event.preventDefault()
    try {
      const result = Function(`"use strict"; return (${expr})`)()
      if (Number.isFinite(result)) {
        input.value = (Math.round(result * 100) / 100).toString()
      }
    } catch (_e) {
      // leave the expression in place so the user can correct it
    }
  }

  #applyAmountColor(kind) {
    const colors = this.amountColorsValue || {}
    const next = colors[kind]
    if (!next) return

    const targets = [
      this.hasSourceAmountLabelTarget ? this.sourceAmountLabelTarget : null,
      this.hasSourceAmountInputTarget ? this.sourceAmountInputTarget : null,
      this.hasSourceCurrencyPrefixTarget ? this.sourceCurrencyPrefixTarget : null,
      this.hasDestinationAmountInputTarget ? this.destinationAmountInputTarget : null,
      this.hasDestinationCurrencyPrefixTarget ? this.destinationCurrencyPrefixTarget : null
    ].filter(Boolean)

    const allColors = Object.values(colors).flatMap((c) => c.split(/\s+/))
    targets.forEach((el) => {
      allColors.forEach((cls) => cls && el.classList.remove(cls))
      next.split(/\s+/).forEach((cls) => cls && el.classList.add(cls))
    })
  }

  #currencyOf(node) {
    if (!node) return ""
    if (node.selectedOptions) {
      const option = node.selectedOptions[0]
      return option ? (option.dataset.currency || "") : ""
    }
    return node.dataset?.currency || ""
  }
}
