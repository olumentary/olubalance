import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['display', 'input'];
  static values = {
    url: String,
    date: String,
  };

  connect() {
    // Initialize with the current date value
    const date = new Date(this.dateValue);
    const formattedDate = date.toISOString().split('T')[0];
    this.inputTarget.value = formattedDate;
  }

  showInput(event) {
    const element = event.target.closest('td');
    const row = element.closest('tr');
    const isPending = row.classList.contains('is-pending');

    if (!isPending) {
      return;
    }

    this.inputTarget.value = this.dateValue;
    this.inputTarget.classList.remove('is-hidden');
    this.displayTarget.classList.add('is-hidden');
    this.inputTarget.focus();
  }

  hideInput() {
    this.inputTarget.classList.add('is-hidden');
    this.displayTarget.classList.remove('is-hidden');
  }

  async updateDate(event) {
    const newDate = event.target.value;
    const currentDate = new Date(this.dateValue).toISOString().split('T')[0];

    if (newDate === currentDate) {
      this.hideInput();
      return;
    }

    try {
      const url = `${this.urlValue}/update_date`;
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ date: newDate }),
      });

      const data = await response.json();

      if (data.success) {
        this.dateValue = data.trx_date;
        const displayDate = new Date(data.trx_date);
        this.displayTarget.textContent = displayDate.toLocaleDateString();
        this.hideInput();

        // Refresh the page to update the transaction list
        window.location.reload();
      } else {
        this.inputTarget.value = currentDate;
        this.hideInput();
      }
    } catch (error) {
      this.inputTarget.value = currentDate;
      this.hideInput();
    }
  }

  // Handle keyboard events
  handleKeydown(event) {
    if (event.key === 'Enter') {
      event.preventDefault();
      this.updateDate(event);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      this.inputTarget.value = new Date(this.dateValue).toISOString().split('T')[0];
      this.hideInput();
    }
  }
}
