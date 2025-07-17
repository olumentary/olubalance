import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "input"]

  connect() {
    // Default to 'debit' if input is blank (new transaction)
    if (!this.inputTarget.value) {
      this.inputTarget.value = "debit"
    }
    this.selectButtonMatchingValue()
  }

  selectButtonMatchingValue() {
    const currentValue = this.inputTarget.value
    this.buttonTargets.forEach(button => {
      const isSelected = button.dataset.value === currentValue
      button.classList.toggle("is-selected", isSelected)
      button.classList.toggle("is-outlined", !isSelected)
    })
  }

  buttonTargetConnected(button) {
    button.addEventListener("click", () => {
      this.inputTarget.value = button.dataset.value
      this.selectButtonMatchingValue()
    })
  }
}
