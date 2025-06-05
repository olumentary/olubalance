import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = {
    url: String,
  };

  connect() {}

  async markReviewed() {
    try {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          Accept: 'text/html',
        },
        credentials: 'same-origin',
      });

      if (!response.ok) {
        throw new Error('Network response was not ok');
      }

      window.location.reload();
    } catch (error) {
      console.error('Error:', error);
    }
  }

  async markPending() {
    try {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          Accept: 'text/html',
        },
        credentials: 'same-origin',
      });

      if (!response.ok) {
        throw new Error('Network response was not ok');
      }

      window.location.reload();
    } catch (error) {
      console.error('Error:', error);
    }
  }
}
