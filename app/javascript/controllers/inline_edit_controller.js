import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['display', 'input'];
  static values = {
    url: String,
    field: String,
    value: String,
  };

  connect() {
    this.hideInput();
  }

  showInput() {
    this.displayTarget.classList.add('is-hidden');
    this.inputTarget.classList.remove('is-hidden');

    // Focus the first radio button for trx_type
    if (this.fieldValue === 'trx_type') {
      const firstRadio = this.inputTarget.querySelector('input[type="radio"]');
      if (firstRadio) firstRadio.focus();
    } else {
      this.inputTarget.focus();
    }

    // Select all text for easy replacement
    if (this.fieldValue === 'description') {
      this.inputTarget.select();
    }
  }

  hideInput() {
    this.displayTarget.classList.remove('is-hidden');
    this.inputTarget.classList.add('is-hidden');
  }

  toggleType() {
    // Toggle between credit and debit
    const newValue = this.valueValue === 'credit' ? 'debit' : 'credit';
    this.sendUpdate(newValue);
  }

  updateValue() {
    let newValue;

    if (this.fieldValue === 'trx_type') {
      // Get selected radio button value
      const selectedRadio = this.inputTarget.querySelector('input[type="radio"]:checked');
      if (!selectedRadio) {
        this.showError('Please select Credit or Debit');
        return;
      }
      newValue = selectedRadio.value;
    } else {
      newValue = this.inputTarget.value.trim();
    }

    // Don't update if value hasn't changed
    if (newValue === this.valueValue) {
      this.hideInput();
      return;
    }

    // Validate amount field
    if (this.fieldValue === 'amount') {
      if (newValue === '') {
        this.showError('Amount cannot be empty');
        this.inputTarget.value = this.valueValue;
        this.hideInput();
        return;
      }

      const amount = parseFloat(newValue);
      if (isNaN(amount)) {
        this.showError('Amount must be a valid number');
        this.inputTarget.value = this.valueValue;
        this.hideInput();
        return;
      }

      if (amount < 0) {
        this.showError('Amount must be a positive number');
        this.inputTarget.value = this.valueValue;
        this.hideInput();
        return;
      }

      // Additional validation: ensure it's a reasonable number (not too large)
      if (amount > 999999999.99) {
        this.showError('Amount is too large. Please enter a smaller value.');
        this.inputTarget.value = this.valueValue;
        this.hideInput();
        return;
      }
    }

    // Validate description field
    if (this.fieldValue === 'description' && newValue === '') {
      this.showError('Description cannot be empty');
      this.inputTarget.value = this.valueValue;
      this.hideInput();
      return;
    }

    // Validate date field
    if (this.fieldValue === 'trx_date' && newValue === '') {
      this.showError('Date cannot be empty');
      this.inputTarget.value = this.valueValue;
      this.hideInput();
      return;
    }

    this.sendUpdate(newValue);
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

    // Create error message using the same pattern as Rails
    const errorHtml = `
      <div class="notification is-danger is-light mb-4">
        <button class="delete" onclick="this.parentElement.remove()"></button>
        <ul>
          <li>${message}</li>
        </ul>
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

  sendUpdate(newValue) {
    const formData = new FormData();

    if (this.fieldValue === 'trx_date') {
      // For date updates, use the date parameter format
      formData.append('date', newValue);
    } else if (this.fieldValue === 'amount') {
      // For amount updates, we need to determine if it should be positive or negative
      // We'll send the absolute value and let the server handle the sign based on transaction type
      formData.append(`transaction[${this.fieldValue}]`, newValue);
    } else {
      formData.append(`transaction[${this.fieldValue}]`, newValue);
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
        if (response.ok) {
          return response.json();
        } else {
          // Try to parse error response for better error messages
          return response
            .json()
            .then(errorData => {
              throw new Error(errorData.errors ? errorData.errors.join(', ') : 'Update failed');
            })
            .catch(() => {
              throw new Error('Update failed');
            });
        }
      })
      .then(data => {
        if (data.success) {
          // Update the display value
          this.valueValue = newValue;
          this.updateDisplay(newValue);
          this.hideInput();

          // Refresh the page to update balances and other dependent data
          window.location.reload();
        } else {
          throw new Error(data.error || 'Update failed');
        }
      })
      .catch(error => {
        console.error('Error updating field:', error);
        this.showError(error.message || 'Failed to update. Please try again.');
        if (this.fieldValue !== 'trx_type') {
          this.inputTarget.value = this.valueValue;
        }
        this.hideInput();
      });
  }

  updateDisplay(newValue) {
    if (this.fieldValue === 'amount') {
      // Format amount as currency with at least 2 decimal places
      const amount = parseFloat(newValue);
      this.displayTarget.textContent = new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD',
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      }).format(amount);
    } else if (this.fieldValue === 'trx_date') {
      // Format date
      const date = new Date(newValue);
      this.displayTarget.textContent = date.toLocaleDateString('en-US', {
        weekday: 'short',
        month: 'short',
        day: 'numeric',
      });
    } else if (this.fieldValue === 'trx_type') {
      // Update the tag display
      const tag = this.displayTarget.querySelector('.tag');
      if (tag) {
        tag.textContent = newValue === 'debit' ? 'D' : 'C';
        tag.className = `tag is-small ${newValue === 'debit' ? 'is-danger' : 'is-success'}`;
      }
    } else {
      this.displayTarget.textContent = newValue;
    }
  }

  handleKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      this.updateValue();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      if (this.fieldValue !== 'trx_type') {
        this.inputTarget.value = this.valueValue;
      }
      this.hideInput();
    }
  }
}
