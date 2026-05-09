// Copies the source target's value to the clipboard and toggles success/default state.
// Usage:
//   <div data-controller="clipboard">
//     <input data-clipboard-target="source" value="..." readonly>
//     <button data-action="clipboard#copy">
//       <span data-clipboard-target="defaultState">Copy</span>
//       <span data-clipboard-target="successState" class="hidden">Copied</span>
//     </button>
//   </div>
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "defaultState", "successState"]
  static values = { resetAfter: { type: Number, default: 2000 } }

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value)

    this.defaultStateTargets.forEach((el) => el.classList.add("hidden"))
    this.successStateTargets.forEach((el) => el.classList.remove("hidden"))

    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => this.reset(), this.resetAfterValue)
  }

  reset() {
    this.defaultStateTargets.forEach((el) => el.classList.remove("hidden"))
    this.successStateTargets.forEach((el) => el.classList.add("hidden"))
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }
}
