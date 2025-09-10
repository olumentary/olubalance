import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['button', 'input'];

  connect() {
    // Default to 'debit' if input is blank (new transaction)
    if (!this.inputTarget.value) {
      this.inputTarget.value = 'debit';
    }
    this.selectButtonMatchingValue();
  }

  selectButtonMatchingValue() {
    const currentValue = this.inputTarget.value;
    this.buttonTargets.forEach(button => {
      const isSelected = button.dataset.value === currentValue;
      if (isSelected) {
        button.classList.remove('is-outlined');
        if (button.dataset.value === 'credit') {
          button.classList.add('is-success');
        } else {
          button.classList.add('is-danger');
        }
      } else {
        button.classList.add('is-outlined');
        button.classList.remove('is-success', 'is-danger');
      }
    });
  }

  buttonTargetConnected(button) {
    button.addEventListener('click', () => {
      this.inputTarget.value = button.dataset.value;
      this.selectButtonMatchingValue();
    });
  }
}
