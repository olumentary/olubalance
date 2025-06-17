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
    console.log('Inline date controller connected', {
      element: this.element,
      url: this.urlValue,
      date: this.dateValue,
      formattedDate: formattedDate,
      hasDisplayTarget: this.hasDisplayTarget,
      hasInputTarget: this.hasInputTarget,
    });
  }

  showInput(event) {
    console.log('showInput called', {
      event: event,
      element: this.element,
      isPending: this.element.closest('tr').classList.contains('is-pending'),
    });

    // Only show input for pending transactions
    if (!this.element.closest('tr').classList.contains('is-pending')) {
      console.log('Not a pending transaction, ignoring click');
      return;
    }

    console.log('Showing input for date edit');
    this.displayTarget.classList.add('is-hidden');
    this.inputTarget.classList.remove('is-hidden');
    this.inputTarget.focus();
  }

  hideInput() {
    console.log('Hiding input');
    this.displayTarget.classList.remove('is-hidden');
    this.inputTarget.classList.add('is-hidden');
  }

  async updateDate(event) {
    const newDate = event.target.value;
    const currentDate = new Date(this.dateValue).toISOString().split('T')[0];

    console.log('updateDate called', {
      newDate: newDate,
      currentDate: currentDate,
      dateValue: this.dateValue,
    });

    if (newDate === currentDate) {
      console.log('Date unchanged, hiding input');
      this.hideInput();
      return;
    }

    try {
      const url = `${this.urlValue}/update_date`;
      console.log('Sending update request', {
        url: url,
        date: newDate,
      });

      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        },
        body: JSON.stringify({ date: newDate }),
      });

      console.log('Response received', {
        status: response.status,
        ok: response.ok,
        headers: Object.fromEntries(response.headers.entries()),
      });

      const data = await response.json();
      console.log('Response data:', data);

      if (data.success) {
        console.log('Update successful', { data });
        this.dateValue = data.trx_date;
        const displayDate = new Date(data.trx_date);
        this.displayTarget.textContent = displayDate.toLocaleDateString();
        this.hideInput();

        // Refresh the page to update the transaction list
        window.location.reload();
      } else {
        console.error('Error updating date:', data.errors || 'Unknown error');
        this.inputTarget.value = currentDate;
        this.hideInput();
      }
    } catch (error) {
      console.error('Error updating date:', error);
      this.inputTarget.value = currentDate;
      this.hideInput();
    }
  }

  // Handle keyboard events
  handleKeydown(event) {
    console.log('Keydown event', { key: event.key });
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
