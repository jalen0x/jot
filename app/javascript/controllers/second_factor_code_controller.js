import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden"]
  static values = { allowBackupCode: Boolean, autoSubmit: Boolean }

  connect() {
    this.syncHiddenField()
    setTimeout(() => this.inputTargets[0]?.focus(), 100)
  }

  handleInput(event) {
    const input = event.target
    const index = this.inputTargets.indexOf(input)
    input.value = input.value.replace(/\D/g, "").slice(-1)

    this.syncHiddenField()

    if (input.value && index < this.inputTargets.length - 1) {
      this.inputTargets[index + 1].focus()
    }

    this.submitIfComplete()
  }

  handleKeydown(event) {
    const input = event.target
    const index = this.inputTargets.indexOf(input)

    if (event.key === "Backspace" && !input.value && index > 0) {
      event.preventDefault()
      this.inputTargets[index - 1].focus()
      this.inputTargets[index - 1].value = ""
      this.syncHiddenField()
    } else if (event.key === "ArrowLeft" && index > 0) {
      event.preventDefault()
      this.inputTargets[index - 1].focus()
    } else if (event.key === "ArrowRight" && index < this.inputTargets.length - 1) {
      event.preventDefault()
      this.inputTargets[index + 1].focus()
    }
  }

  handlePaste(event) {
    event.preventDefault()

    const pastedValue = event.clipboardData?.getData("text/plain") || ""
    const compactValue = pastedValue.replace(/[\s-]/g, "")
    if (!compactValue) return

    if (this.allowBackupCodeValue && (/[A-Za-z]/.test(compactValue) || compactValue.length > 6)) {
      this.inputTargets.forEach((input) => { input.value = "" })
      this.hiddenTarget.value = compactValue.slice(0, 64)
      return
    }

    compactValue.replace(/\D/g, "").slice(0, 6).split("").forEach((digit, index) => {
      this.inputTargets[index].value = digit
    })

    this.syncHiddenField()
    this.inputTargets[Math.min(this.hiddenTarget.value.length, this.inputTargets.length - 1)]?.focus()
    this.submitIfComplete()
  }

  syncHiddenField() {
    this.hiddenTarget.value = this.inputTargets.map((input) => input.value).join("")
  }

  submitIfComplete() {
    const value = this.hiddenTarget.value
    if (!this.autoSubmitValue || this.submitted || !/^\d{6}$/.test(value)) return

    this.submitted = true
    this.element.closest("form")?.requestSubmit()
  }
}
