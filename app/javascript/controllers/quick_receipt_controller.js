import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['attachment', 'submit', 'error'];

  connect() {
    this.validateForm();
  }

  attachmentSelected() {
    this.validateForm();
  }

  validateForm() {
    const hasAttachment = this.attachmentTarget.files.length > 0;
    const submitButton = this.submitTarget;

    if (!hasAttachment) {
      submitButton.disabled = true;
      submitButton.classList.add('is-loading');
      submitButton.classList.remove('is-primary');
      submitButton.classList.add('is-danger');
      submitButton.value = 'Receipt Required';

      // Show error message
      this.showError('Please select a receipt file before uploading.');
    } else {
      submitButton.disabled = false;
      submitButton.classList.remove('is-loading', 'is-danger');
      submitButton.classList.add('is-primary');
      submitButton.value = 'Upload Receipt';

      // Hide error message
      this.hideError();
    }
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message;
      this.errorTarget.classList.remove('is-hidden');
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add('is-hidden');
    }
  }
}
