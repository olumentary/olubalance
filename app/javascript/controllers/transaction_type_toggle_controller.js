import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = {
    url: String,
    currentType: String,
    currentAmount: String,
  };

  toggleType() {
    // Toggle between credit and debit
    const newValue = this.currentTypeValue === 'credit' ? 'debit' : 'credit';

    const formData = new FormData();
    formData.append('transaction[trx_type]', newValue);

    // Also send the current amount so the server can convert it properly
    if (this.currentAmountValue) {
      formData.append('transaction[amount]', this.currentAmountValue);
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
          throw new Error('Update failed');
        }
      })
      .then(data => {
        if (data.success) {
          // Refresh the page to update balances and other dependent data
          window.location.reload();
        } else {
          throw new Error(data.error || 'Update failed');
        }
      })
      .catch(error => {
        console.error('Error updating transaction type:', error);
        alert('Failed to update transaction type. Please try again.');
      });
  }
}
