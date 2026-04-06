import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = [
    'form',
    'saveButton',
    'approveButton',
    'receiptImage',
    'submitButton',
    'loadingIndicator',
    'ocrOverlay',
    'ocrError',
    'ocrErrorText',
    'ocrSuccess',
  ];
  static values = {
    url: String,
    processUrl: String,
  };

  connect() {
    this.initializeForm();
    document.addEventListener('keydown', this.handleKeydown.bind(this));

    // Trigger OCR when the modal becomes active
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
          if (this.element.classList.contains('is-active')) {
            this.clearFormFields();
            this.processReceipt();
            this.checkImagesAlreadyLoaded();
          }
        }
      });
    });

    this.observer.observe(this.element, { attributes: true });
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeydown.bind(this));
    if (this.observer) {
      this.observer.disconnect();
    }
  }

  handleKeydown(event) {
    if (event.key === 'Escape') {
      event.preventDefault();
      this.closeModal();
    }
  }

  // ── OCR ────────────────────────────────────────────────────────────────────

  processReceipt() {
    if (!this.hasProcessUrlValue || !this.processUrlValue) return;

    this.showOcrOverlay();
    this.hideOcrStatus();

    fetch(this.processUrlValue, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        Accept: 'application/json',
      },
    })
      .then(response => response.json())
      .then(data => {
        this.hideOcrOverlay();
        if (data.success) {
          this.populateFormFields(data);
          this.showOcrSuccessBadge();
        } else {
          this.showOcrError(data.error || 'Could not read receipt automatically.');
        }
      })
      .catch(() => {
        this.hideOcrOverlay();
        this.showOcrError('Could not connect to the AI service. Please fill in the details manually.');
      });
  }

  retryOcr() {
    this.processReceipt();
  }

  populateFormFields(data) {
    const form = this.formTarget;

    if (data.description) {
      const descField = form.querySelector('input[name="transaction[description]"]');
      if (descField) descField.value = data.description;
    }

    if (data.date) {
      const dateField = form.querySelector('input[name="transaction[trx_date]"]');
      if (dateField) dateField.value = data.date;
    }

    if (data.amount) {
      const amountField = form.querySelector('input[name="transaction[amount]"]');
      if (amountField) amountField.value = data.amount;
    }

    if (data.trx_type) {
      const hiddenField = form.querySelector('input[name="transaction[trx_type]"]');
      if (hiddenField) hiddenField.value = data.trx_type;

      // Sync the visual radio buttons
      const txId = this.getTransactionId();
      const debitBtn  = form.querySelector(`#debitType-${txId}`);
      const creditBtn = form.querySelector(`#creditType-${txId}`);
      if (debitBtn && creditBtn) {
        if (data.trx_type === 'credit') {
          creditBtn.classList.remove('is-outlined');
          creditBtn.classList.add('is-success');
          debitBtn.classList.add('is-outlined');
          debitBtn.classList.remove('is-danger');
        } else {
          debitBtn.classList.remove('is-outlined');
          debitBtn.classList.add('is-danger');
          creditBtn.classList.add('is-outlined');
          creditBtn.classList.remove('is-success');
        }
      }
    }

    if (data.category_id) {
      const categorySelect = form.querySelector('select[name="transaction[category_id]"]');
      if (categorySelect) categorySelect.value = data.category_id;
    }
  }

  // ── OCR UI helpers ──────────────────────────────────────────────────────────

  showOcrOverlay() {
    if (this.hasOcrOverlayTarget) {
      this.ocrOverlayTarget.style.display = 'block';
    }
  }

  hideOcrOverlay() {
    if (this.hasOcrOverlayTarget) {
      this.ocrOverlayTarget.style.display = 'none';
    }
  }

  hideOcrStatus() {
    if (this.hasOcrErrorTarget)   this.ocrErrorTarget.classList.add('is-hidden');
    if (this.hasOcrSuccessTarget) this.ocrSuccessTarget.classList.add('is-hidden');
  }

  showOcrSuccessBadge() {
    if (this.hasOcrSuccessTarget) this.ocrSuccessTarget.classList.remove('is-hidden');
  }

  showOcrError(message) {
    if (this.hasOcrErrorTarget) {
      this.ocrErrorTarget.classList.remove('is-hidden');
    }
    if (this.hasOcrErrorTextTarget) {
      this.ocrErrorTextTarget.textContent = message;
    }
  }

  // ── Form ────────────────────────────────────────────────────────────────────

  initializeForm() {
    const txId = this.getTransactionId();
    const debitButton  = this.formTarget.querySelector(`#debitType-${txId}`);
    const creditButton = this.formTarget.querySelector(`#creditType-${txId}`);

    if (debitButton) {
      debitButton.classList.remove('is-outlined');
      debitButton.classList.add('is-danger');
    }
    if (creditButton) {
      creditButton.classList.add('is-outlined');
      creditButton.classList.remove('is-success');
    }

    const hiddenField = this.formTarget.querySelector('input[name="transaction[trx_type]"]');
    if (hiddenField) hiddenField.value = 'debit';
  }

  getTransactionId() {
    return this.element.id.replace('quick-receipt-review-modal-', '');
  }

  clearFormFields() {
    const form = this.formTarget;
    const descriptionField = form.querySelector('input[name="transaction[description]"]');
    const amountField      = form.querySelector('input[name="transaction[amount]"]');
    const memoField        = form.querySelector('input[name="transaction[memo]"]');
    const categoryField    = form.querySelector('select[name="transaction[category_id]"]');

    if (descriptionField) descriptionField.value = '';
    if (amountField)      amountField.value = '';
    if (memoField)        memoField.value = '';
    if (categoryField)    categoryField.value = '';
  }

  // ── Save / Approve ─────────────────────────────────────────────────────────

  saveTransaction() {
    this._submitForm({ approve: false });
  }

  approveTransaction() {
    this._submitForm({ approve: true });
  }

  _submitForm({ approve }) {
    const saveBtn    = this.hasSaveButtonTarget    ? this.saveButtonTarget    : null;
    const approveBtn = this.hasApproveButtonTarget ? this.approveButtonTarget : null;

    // Lock both buttons during submission
    [saveBtn, approveBtn].forEach(btn => {
      if (btn) {
        btn.disabled = true;
        btn.classList.add('is-loading');
      }
    });

    const formData = new FormData(this.formTarget);
    if (approve) {
      formData.append('approve_quick_receipt', 'true');
    }

    fetch(this.urlValue, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        Accept: 'application/json',
      },
      body: formData,
    })
      .then(response => {
        if (response.ok) return response.json();
        return response.json().then(err => {
          throw new Error(err.errors ? err.errors.join(', ') : 'Save failed');
        });
      })
      .then(data => {
        if (data.success) {
          const message = approve
            ? 'Transaction approved! It has been moved to pending for review.'
            : 'Transaction saved successfully!';
          this.showSuccess(message);
          setTimeout(() => {
            this.closeModal();
            window.location.reload();
          }, 1500);
        } else {
          throw new Error(data.error || 'Save failed');
        }
      })
      .catch(error => {
        console.error('Error saving transaction:', error);
        this.showError(error.message || 'Failed to save transaction. Please try again.');

        [saveBtn, approveBtn].forEach(btn => {
          if (btn) {
            btn.disabled = false;
            btn.classList.remove('is-loading');
          }
        });
      });
  }

  // ── Image loading ───────────────────────────────────────────────────────────

  imageLoaded() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('is-hidden');
    }
    if (this.hasReceiptImageTarget) {
      this.receiptImageTarget.classList.remove('is-hidden');
    }
  }

  // When the modal opens, the browser may have already loaded the image (e.g.
  // from cache or because the page had time to fetch it while an earlier
  // receipt was being reviewed).  In that case the `load` event already fired
  // and `imageLoaded` was never called, leaving the spinner stuck.  Check each
  // image's `.complete` flag and reveal it immediately if loading is done.
  checkImagesAlreadyLoaded() {
    this.receiptImageTargets.forEach((img, i) => {
      if (img.complete && img.naturalWidth > 0) {
        img.classList.remove('is-hidden');
        const indicator = this.loadingIndicatorTargets[i];
        if (indicator) indicator.classList.add('is-hidden');
      }
    });
  }

  // ── Modal ───────────────────────────────────────────────────────────────────

  closeModal() {
    this.element.classList.remove('is-active');
  }

  // ── Flash messages ─────────────────────────────────────────────────────────

  showSuccess(message) {
    this._showFlash(message, 'is-success', 'fa-check-circle');
  }

  showError(message) {
    this._showFlash(message, 'is-danger', 'fa-exclamation-triangle');
  }

  _showFlash(message, colorClass, icon) {
    let flashContainer = document.getElementById('flash_messages');
    if (!flashContainer) {
      flashContainer = document.createElement('div');
      flashContainer.id = 'flash_messages';
      const navbar  = document.querySelector('nav');
      const content = document.querySelector('.container') || document.body;
      if (navbar && navbar.nextSibling) {
        content.insertBefore(flashContainer, navbar.nextSibling);
      } else {
        content.insertBefore(flashContainer, content.firstChild);
      }
    }

    flashContainer.innerHTML = `
      <div class="notification ${colorClass} is-light mb-4">
        <button class="delete" onclick="this.parentElement.remove()"></button>
        <span class="icon"><i class="fas ${icon}"></i></span>
        <span>${message}</span>
      </div>
    `;

    setTimeout(() => {
      if (flashContainer && flashContainer.innerHTML.trim() !== '') {
        flashContainer.innerHTML = '';
      }
    }, 5000);
  }
}
