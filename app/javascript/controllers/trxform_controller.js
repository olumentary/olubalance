import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['submit', 'attachment', 'newreceipt', 'filename', 'confirmTransferButton'];

  connect() {
    // Expose methods globally for modal buttons
    window.confirmAccountTransfer = () => {
      if (window.currentTrxformController) {
        window.currentTrxformController.confirmAccountTransfer();
      }
    };
    window.cancelAccountTransfer = () => {
      if (window.currentTrxformController) {
        window.currentTrxformController.cancelAccountTransfer();
      }
    };
  }

  create() {
    this.submitTarget.classList.add('is-loading');
    if (this.attachmentTarget.value != '') {
      this.attachmentTarget.parentNode.classList.add('is-hidden');
      this.submitTarget.parentNode.insertAdjacentHTML(
        'afterend',
        `
        <div class="control" style="display: flex; align-items: center">
          Uploading attachment ...
        </div>
      `
      );
    }
  }

  // When attachment files are selected, set the file-name field
  attachmentSelected() {
    const files = this.attachmentTarget.files;
    if (files.length > 0) {
      if (files.length === 1) {
        const filename = files[0].name;
        this.newreceiptTarget.innerHTML = 'Adding receipt: ';
        this.filenameTarget.innerHTML = filename;
      } else {
        this.newreceiptTarget.innerHTML = 'Adding receipts: ';
        this.filenameTarget.innerHTML = `${files.length} files selected`;
      }
    } else {
      this.newreceiptTarget.innerHTML = '';
      this.filenameTarget.innerHTML = '';
    }
  }

  // When the account is changed, show confirmation modal but keep form action to current account
  accountChanged(event) {
    const accountId = event.target.value;
    const form = this.element.querySelector('form');
    const currentPath = form.action;

    // Extract the current account ID from the URL
    const currentAccountMatch = currentPath.match(/\/accounts\/(\d+)\/transactions/);
    const currentAccountId = currentAccountMatch ? currentAccountMatch[1] : null;

    // If the account is actually changing, show the confirmation modal
    if (currentAccountId && currentAccountId !== accountId) {
      const accountName = event.target.options[event.target.selectedIndex].text;

      // Store the selected account info for the modal
      this.selectedAccountId = accountId;
      this.selectedAccountName = accountName;
      this.accountSelectElement = event.target;
      this.originalAccountId = currentAccountId;

      // Update the modal content
      const transferAccountName = document.getElementById('transfer-account-name');
      if (transferAccountName) {
        transferAccountName.textContent = accountName;
      }

      // Update transaction details in the modal
      this.updateModalTransactionDetails();

      // Show the modal
      const modalId = `account-transfer-modal-${this.getTransactionId()}`;
      const modal = document.getElementById(modalId);
      if (modal) {
        modal.classList.add('is-active');
      }

      // Store the current controller instance for the global functions
      window.currentTrxformController = this;

      // Prevent the form from submitting immediately
      return;
    }

    // Don't change the form action URL - keep it pointing to the current account
    // where the transaction currently exists. The controller will handle the redirect.
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
        // Remove the attachment tag from the DOM
        const attachmentTag = document.getElementById(`attachment-${attachmentId}`);
        if (attachmentTag) {
          attachmentTag.remove();
        }

        // Update the filename display if no attachments remain
        if (data.attachment_count === 0) {
          this.filenameTarget.innerHTML = '- No receipts -';
        }

        // Show success message
        this.showNotification(data.message, 'success');
      } else {
        this.showNotification(data.errors.join(', '), 'error');
      }
    } catch (error) {
      console.error('Error:', error);
      this.showNotification('An error occurred while deleting the attachment.', 'error');
    }
  }

  // Show notification message
  showNotification(message, type) {
    // Create notification element
    const notification = document.createElement('div');
    notification.className = `notification is-${type === 'success' ? 'success' : 'danger'} is-light`;
    notification.style.position = 'fixed';
    notification.style.top = '20px';
    notification.style.right = '20px';
    notification.style.zIndex = '9999';
    notification.style.maxWidth = '300px';

    notification.innerHTML = `
      <button class="delete" onclick="this.parentElement.remove()"></button>
      ${message}
    `;

    document.body.appendChild(notification);

    // Auto-remove after 3 seconds
    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove();
      }
    }, 3000);
  }

  // Get transaction ID from the current page
  getTransactionId() {
    const pathMatch = window.location.pathname.match(/\/transactions\/(\d+)/);
    return pathMatch ? pathMatch[1] : null;
  }

  // Update transaction details in the modal
  updateModalTransactionDetails() {
    // Get form elements
    const dateField = document.querySelector('input[name="transaction[trx_date]"]');
    const descriptionField = document.querySelector('input[name="transaction[description]"]');
    const amountField = document.querySelector('input[name="transaction[amount]"]');

    // Update modal content
    const dateSpan = document.getElementById('transfer-transaction-date');
    const descriptionSpan = document.getElementById('transfer-transaction-description');
    const amountSpan = document.getElementById('transfer-transaction-amount');

    if (dateSpan && dateField) {
      const date = new Date(dateField.value);
      dateSpan.textContent = date.toLocaleDateString();
    }

    if (descriptionSpan && descriptionField) {
      descriptionSpan.textContent = descriptionField.value || 'No description';
    }

    if (amountSpan && amountField) {
      const amount = parseFloat(amountField.value);
      if (!isNaN(amount)) {
        const formattedAmount = new Intl.NumberFormat('en-US', {
          style: 'currency',
          currency: 'USD',
        }).format(Math.abs(amount));
        amountSpan.textContent = formattedAmount;
      } else {
        amountSpan.textContent = 'No amount';
      }
    }
  }

  // Confirm account transfer from modal
  confirmAccountTransfer() {
    console.log('confirmAccountTransfer called');

    // Close the modal
    const modalId = `account-transfer-modal-${this.getTransactionId()}`;
    const modal = document.getElementById(modalId);
    if (modal) {
      modal.classList.remove('is-active');
    }

    // Submit the form with the new account_id
    // Try multiple ways to find the form
    let form = this.element.querySelector('form');
    if (!form) {
      // If not found in current element, look in the document
      form = document.querySelector('form[action*="/transactions"]');
    }
    if (!form) {
      // Last resort - look for any form
      form = document.querySelector('form');
    }

    console.log('Found form:', form);

    if (form) {
      console.log('Submitting form for account transfer');
      // Use a small delay to ensure modal is closed before submitting
      setTimeout(() => {
        form.submit();
      }, 100);
    } else {
      console.error('Could not find form to submit');
      // Fallback: trigger the submit button click
      const submitButton = document.querySelector('button[type="submit"]');
      if (submitButton) {
        console.log('Using submit button fallback');
        submitButton.click();
      }
    }
  }

  // Cancel account transfer from modal
  cancelAccountTransfer() {
    // Reset the account select to the original value
    if (this.accountSelectElement && this.originalAccountId) {
      this.accountSelectElement.value = this.originalAccountId;
    }

    // Close the modal
    const modalId = `account-transfer-modal-${this.getTransactionId()}`;
    const modal = document.getElementById(modalId);
    if (modal) {
      modal.classList.remove('is-active');
    }
  }
}
