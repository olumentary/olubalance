import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['form', 'fileInput', 'fileName', 'uploadButton', 'error', 'errorMessage', 'success', 'successMessage'];
  static values = { url: String };

  connect() {
    this.validateForm();
  }

  fileSelected() {
    const files = this.fileInputTarget.files;
    if (files.length > 0) {
      if (files.length === 1) {
        this.fileNameTarget.textContent = files[0].name;
      } else {
        this.fileNameTarget.textContent = `${files.length} files selected`;
      }
    } else {
      this.fileNameTarget.textContent = 'No files selected';
    }
    this.validateForm();
  }

  validateForm() {
    const hasFile = this.fileInputTarget.files.length > 0;
    this.uploadButtonTarget.disabled = !hasFile;
  }

  async uploadFile() {
    if (!this.fileInputTarget.files.length) {
      this.showError('Please select files first.');
      return;
    }

    const formData = new FormData();
    const files = Array.from(this.fileInputTarget.files);
    files.forEach(file => {
      formData.append('transaction[attachments][]', file);
    });

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
        if (data.filenames.length === 1) {
          this.showSuccess(`Attachment "${data.filenames[0]}" uploaded successfully!`);
        } else {
          this.showSuccess(`${data.filenames.length} attachments uploaded successfully!`);
        }

        // Update the paperclip icon in the transaction row
        this.updateTransactionRow(data.has_attachments);

        // Refresh the page after a short delay to show updated state
        setTimeout(() => {
          window.location.reload();
        }, 1500);
      } else {
        this.showError(data.errors.join(', '));
      }
    } catch (error) {
      console.error('Error:', error);
      this.showError('An error occurred while uploading the files.');
    } finally {
      this.uploadButtonTarget.classList.remove('is-loading');
      this.validateForm();
    }
  }

  updateTransactionRow(hasAttachments) {
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

        // Add paperclip icon if attachments exist
        if (hasAttachments) {
          const iconHtml = '<span class="icon has-text-grey-light has-tooltip" data-tooltip="Transaction has attachments"><i class="fas fa-sm fa-paperclip"></i></span>';
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

  // Delete an attachment from the transaction
  async deleteAttachment(event) {
    const button = event.currentTarget;
    const attachmentId = button.dataset.attachmentId;
    const transactionId = button.dataset.transactionId;
    const accountId = button.dataset.accountId;

    if (!confirm('Are you sure you want to delete this attachment?')) {
      return;
    }

    try {
      const response = await fetch(`/accounts/${accountId}/transactions/${transactionId}/delete_attachment`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ attachment_id: attachmentId }),
      });

      const data = await response.json();

      if (data.success) {
        // Remove the attachment tag from the DOM (both in modal and form)
        const modalAttachmentTag = document.getElementById(`modal-attachment-${attachmentId}`);
        const formAttachmentTag = document.getElementById(`attachment-${attachmentId}`);

        if (modalAttachmentTag) {
          modalAttachmentTag.remove();
        }
        if (formAttachmentTag) {
          formAttachmentTag.remove();
        }

        // Show success message
        this.showSuccess(data.message);
      } else {
        this.showError(data.errors.join(', '));
      }
    } catch (error) {
      console.error('Error:', error);
      this.showError('An error occurred while deleting the attachment.');
    }
  }
}
