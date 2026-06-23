import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['input', 'submit', 'hidden'];
  static values = { expected: String };

  connect() {
    this.submitTarget.disabled = true;
  }

  validate() {
    const typed = this.inputTarget.value.trim().toLowerCase();
    const matches = typed === this.expectedValue.toLowerCase();

    this.submitTarget.disabled = !matches;

    if (matches) {
      this.submitTarget.classList.remove('is-light');
      this.submitTarget.classList.add('is-danger');
      if (this.hasHiddenTarget) {
        this.hiddenTarget.value = this.inputTarget.value.trim();
      }
    } else {
      this.submitTarget.classList.remove('is-danger');
      this.submitTarget.classList.add('is-light');
      if (this.hasHiddenTarget) {
        this.hiddenTarget.value = '';
      }
    }
  }
}
