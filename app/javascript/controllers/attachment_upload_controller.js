import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['form', 'fileInput', 'fileName', 'uploadButton', 'error', 'errorMessage', 'success', 'successMessage'];
  static values = { url: String };

  connect() {
    this.validateForm();
  }

  fileSelected() {
    const file = this.fileInputTarget.files[0];
    if (file) {
      this.fileNameTarget.textContent = file.name;
    } else {
      this.fileNameTarget.textContent = 'No file selected';
    }
    this.validateForm();
  }

  validateForm() {
    const hasFile = this.fileInputTarget.files.length > 0;
    this.uploadButtonTarget.disabled = !hasFile;
  }

  async uploadFile() {
    if (!this.fileInputTarget.files.length) {
      this.showError('Please select a file first.');
      return;
    }

    const formData = new FormData();
    formData.append('transaction[attachment]', this.fileInputTarget.files[0]);

    this.uploadButtonTarget.classList.add('is-loading');
    this.uploadButtonTarget.disabled = true;
    this.hideError();
    this.hideSuccess();

    try {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        },
        body: formData,
      });

      const data = await response.json();

      if (data.success) {
        this.showSuccess(`Attachment "${data.filename}" uploaded successfully!`);

        // Update the paperclip icon in the transaction row
        this.updateTransactionRow(data.has_attachment);

        // Refresh the page after a short delay to show updated state
        setTimeout(() => {
          window.location.reload();
        }, 1500);
      } else {
        this.showError(data.errors.join(', '));
      }
    } catch (error) {
      console.error('Error:', error);
      this.showError('An error occurred while uploading the file.');
    } finally {
      this.uploadButtonTarget.classList.remove('is-loading');
      this.validateForm();
    }
  }

  updateTransactionRow(hasAttachment) {
    // Find the transaction row and update the paperclip icon
    const transactionId = this.urlValue.match(/\/transactions\/(\d+)/)[1];
    const row = document.querySelector(`tr[id="transaction_${transactionId}"]`);

    if (row) {
      const descriptionCell = row.querySelector('td:nth-child(2)');
      const displaySpan = descriptionCell.querySelector('[data-inline-edit-target="display"]');

      if (displaySpan) {
        // Remove existing paperclip icon
        const existingIcon = displaySpan.querySelector('.fa-paperclip');
        if (existingIcon) {
          existingIcon.closest('.icon').remove();
        }

        // Add paperclip icon if attachment exists
        if (hasAttachment) {
          const iconHtml = '<span class="icon has-text-grey-light has-tooltip" data-tooltip="Transaction has attachment"><i class="fas fa-sm fa-paperclip"></i></span>';
          displaySpan.insertAdjacentHTML('beforeend', iconHtml);
        }
      }
    }
  }

  closeModal() {
    const modalId = this.element.id;
    document.getElementById(modalId).classList.remove('is-active');
  }

  showError(message) {
    this.errorMessageTarget.textContent = message;
    this.errorTarget.classList.remove('is-hidden');
  }

  hideError() {
    this.errorTarget.classList.add('is-hidden');
  }

  showSuccess(message) {
    this.successMessageTarget.textContent = message;
    this.successTarget.classList.remove('is-hidden');
  }

  hideSuccess() {
    this.successTarget.classList.add('is-hidden');
  }
}
