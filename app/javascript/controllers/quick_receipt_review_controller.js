import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['form', 'saveButton', 'receiptImage', 'submitButton', 'loadingIndicator'];
  static values = {
    url: String,
  };

  connect() {
    // Initialize the form when the modal opens
    this.initializeForm();

    // Add event listener for Escape key
    document.addEventListener('keydown', this.handleKeydown.bind(this));

    // Observe changes to the modal's classes to detect when it's opened
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
          const currentClassList = this.element.classList;
          if (currentClassList.contains('is-active')) {
            this.clearFormFields();
          }
        }
      });
    });

    this.observer.observe(this.element, { attributes: true });
  }

  disconnect() {
    // Remove event listener when controller disconnects
    document.removeEventListener('keydown', this.handleKeydown.bind(this));

    // Disconnect the observer
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

  initializeForm() {
    // Set default transaction type to debit for quick receipts
    const debitButton = this.formTarget.querySelector('#debitType-' + this.getTransactionId());
    if (debitButton) {
      debitButton.classList.remove('is-outlined');
      debitButton.classList.add('is-danger');
    }

    const creditButton = this.formTarget.querySelector('#creditType-' + this.getTransactionId());
    if (creditButton) {
      creditButton.classList.add('is-outlined');
      creditButton.classList.remove('is-success');
    }

    // Set the hidden field value
    const hiddenField = this.formTarget.querySelector('input[name="transaction[trx_type]"]');
    if (hiddenField) {
      hiddenField.value = 'debit';
    }
  }

  getTransactionId() {
    // Extract transaction ID from the modal ID
    const modalId = this.element.id;
    return modalId.replace('quick-receipt-review-modal-', '');
  }

  clearFormFields() {
    // Clear description, amount, and memo fields
    const descriptionField = this.formTarget.querySelector('input[name="transaction[description]"]');
    const amountField = this.formTarget.querySelector('input[name="transaction[amount]"]');
    const memoField = this.formTarget.querySelector('input[name="transaction[memo]"]');
    const categoryField = this.formTarget.querySelector('select[name="transaction[category_id]"]');

    if (descriptionField) descriptionField.value = '';
    if (amountField) amountField.value = '';
    if (memoField) memoField.value = '';
    if (categoryField) categoryField.value = '';
  }

  saveTransaction() {
    // Disable the save button to prevent double submission
    this.saveButtonTarget.disabled = true;
    this.saveButtonTarget.classList.add('is-loading');
    this.saveButtonTarget.textContent = 'Saving...';

    // Get form data
    const formData = new FormData(this.formTarget);

    fetch(this.urlValue, {
      method: 'PATCH',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        Accept: 'application/json',
      },
      body: formData,
    })
      .then(response => {
        if (response.ok) {
          return response.json();
        } else {
          return response.json().then(errorData => {
            throw new Error(errorData.errors ? errorData.errors.join(', ') : 'Save failed');
          });
        }
      })
      .then(data => {
        if (data.success) {
          // Show success message
          this.showSuccess('Transaction saved and reviewed successfully!');

          // Close the modal after a short delay
          setTimeout(() => {
            this.closeModal();
            // Reload the page to update the transaction list
            window.location.reload();
          }, 1500);
        } else {
          throw new Error(data.error || 'Save failed');
        }
      })
      .catch(error => {
        console.error('Error saving transaction:', error);
        this.showError(error.message || 'Failed to save transaction. Please try again.');

        // Re-enable the save button
        this.saveButtonTarget.disabled = false;
        this.saveButtonTarget.classList.remove('is-loading');
        this.saveButtonTarget.textContent = 'Save & Review';
      });
  }

  showSuccess(message) {
    // Find existing flash container or create one
    let flashContainer = document.getElementById('flash_messages');
    if (!flashContainer) {
      flashContainer = document.createElement('div');
      flashContainer.id = 'flash_messages';
      // Insert at the top of the page content, after the navbar if it exists
      const navbar = document.querySelector('nav');
      const content = document.querySelector('.container') || document.body;
      if (navbar && navbar.nextSibling) {
        content.insertBefore(flashContainer, navbar.nextSibling);
      } else {
        content.insertBefore(flashContainer, content.firstChild);
      }
    }

    // Clear any existing messages
    flashContainer.innerHTML = '';

    // Create success message
    const successHtml = `
      <div class="notification is-success is-light mb-4">
        <button class="delete" onclick="this.parentElement.remove()"></button>
        <span class="icon">
          <i class="fas fa-check-circle"></i>
        </span>
        <span>${message}</span>
      </div>
    `;

    flashContainer.innerHTML = successHtml;

    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (flashContainer && flashContainer.innerHTML.trim() !== '') {
        flashContainer.innerHTML = '';
      }
    }, 5000);
  }

  showError(message) {
    // Find existing flash container or create one
    let flashContainer = document.getElementById('flash_messages');
    if (!flashContainer) {
      flashContainer = document.createElement('div');
      flashContainer.id = 'flash_messages';
      // Insert at the top of the page content, after the navbar if it exists
      const navbar = document.querySelector('nav');
      const content = document.querySelector('.container') || document.body;
      if (navbar && navbar.nextSibling) {
        content.insertBefore(flashContainer, navbar.nextSibling);
      } else {
        content.insertBefore(flashContainer, content.firstChild);
      }
    }

    // Clear any existing messages
    flashContainer.innerHTML = '';

    // Create error message
    const errorHtml = `
      <div class="notification is-danger is-light mb-4">
        <button class="delete" onclick="this.parentElement.remove()"></button>
        <span class="icon">
          <i class="fas fa-exclamation-triangle"></i>
        </span>
        <span>${message}</span>
      </div>
    `;

    flashContainer.innerHTML = errorHtml;

    // Auto-remove after 5 seconds
    setTimeout(() => {
      if (flashContainer && flashContainer.innerHTML.trim() !== '') {
        flashContainer.innerHTML = '';
      }
    }, 5000);
  }

  imageLoaded() {
    // Hide loading indicator and show the image
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('is-hidden');
    }
    if (this.hasReceiptImageTarget) {
      this.receiptImageTarget.classList.remove('is-hidden');
    }
  }

  closeModal() {
    // Close the modal by toggling the is-active class
    this.element.classList.remove('is-active');
  }
}
