// Dynamic transaction form behavior: toggles destination account / destination
// amount visibility based on transaction_kind, and swaps the amount label between
// "Amount" (for income/expense) and "Source amount" (for transfer).
//
// Usage:
//   <form data-controller="transaction-form"
//         data-transaction-form-amount-label-value="Amount"
//         data-transaction-form-source-amount-label-value="Source amount"
//         data-transaction-form-destination-amount-label-value="Destination amount">
//     <select data-transaction-form-target="kindSelect"
//             data-action="change->transaction-form#kindChanged">...</select>
//     <div data-transaction-form-target="destinationAccountField">...</div>
//     <div data-transaction-form-target="sourceAmountField">...</div>
//     <div data-transaction-form-target="destinationAmountField">...</div>
//   </form>
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "kindSelect",
    "destinationAccountField",
    "sourceAmountField",
    "destinationAmountField",
    "sourceAccount",
    "destinationAccount",
    "sourceCurrencyPrefix",
    "destinationCurrencyPrefix"
  ]
  static values = {
    amountLabel: String,
    sourceAmountLabel: String,
    destinationAmountLabel: String
  }

  connect() {
    this.refresh()
  }

  kindChanged() {
    this.refresh()
  }

  sourceAccountChanged() {
    this.updateSourceCurrency()
  }

  destinationAccountChanged() {
    this.updateDestinationCurrency()
  }

  refresh() {
    const isTransfer = this.kindSelectTarget.value === "transfer"
    this.destinationAccountFieldTarget.hidden = !isTransfer
    this.destinationAmountFieldTarget.hidden = !isTransfer

    const sourceLabel = this.sourceAmountFieldTarget.querySelector("label")
    if (sourceLabel) {
      sourceLabel.textContent = isTransfer ? this.sourceAmountLabelValue : this.amountLabelValue
    }

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

  #currencyOf(select) {
    const option = select.selectedOptions[0]
    return option ? (option.dataset.currency || "") : ""
  }

  // Evaluate an arithmetic expression typed into an amount field.
  // Triggered on Enter; preventDefault keeps the form from submitting.
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
}
