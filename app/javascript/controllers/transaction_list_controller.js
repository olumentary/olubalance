import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['list'];

  connect() {
    document.addEventListener('transaction:updated', this.handleUpdate.bind(this));
  }

  disconnect() {
    document.removeEventListener('transaction:updated', this.handleUpdate.bind(this));
  }

  async handleUpdate(event) {
    const transactionId = event.detail.transactionId;
    const response = await fetch(`/accounts/${this.element.dataset.accountId}/transactions/${transactionId}`);
    const html = await response.text();
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    const updatedTransaction = doc.querySelector(`[data-transaction-id="${transactionId}"]`);

    if (updatedTransaction) {
      const currentTransaction = this.element.querySelector(`[data-transaction-id="${transactionId}"]`);
      if (currentTransaction) {
        currentTransaction.replaceWith(updatedTransaction);
      }
    }
  }
}
