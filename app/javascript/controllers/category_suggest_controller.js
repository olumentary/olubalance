import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['input', 'select', 'status', 'spinner'];
  static values = {
    url: String,
  };

  connect() {
    this.timeout = null;
  }

  suggest(event) {
    // debounce to avoid spamming
    clearTimeout(this.timeout);
    this.timeout = setTimeout(() => this.fetchSuggestion(), 200);
  }

  fetchSuggestion() {
    const description = this.inputTarget.value.trim();
    if (!description || !this.urlValue) return;

    const url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set('description', description);

    this.showSpinner();

    fetch(url.toString(), {
      headers: { Accept: 'application/json' },
      credentials: 'same-origin',
    })
      .then(response => {
        if (!response.ok) throw new Error('no suggestion');
        return response.json();
      })
      .then(data => {
        if (data.category_id && this.selectTarget) {
          this.selectTarget.value = data.category_id;
        }
        if (data.error === 'ai_rate_limited') {
          this.setStatus('AI suggestions unavailable (rate limit or billing issue).');
        } else {
          this.clearStatus();
        }
      })
      .catch(() => {
        this.clearStatus();
      })
      .finally(() => {
        this.hideSpinner();
      });
  }

  setStatus(message) {
    if (!this.hasStatusTarget) return;
    this.statusTarget.textContent = message;
  }

  clearStatus() {
    if (!this.hasStatusTarget) return;
    this.statusTarget.textContent = '';
  }

  showSpinner() {
    if (!this.hasSpinnerTarget) return;
    this.spinnerTarget.classList.remove('is-hidden');
  }

  hideSpinner() {
    if (!this.hasSpinnerTarget) return;
    this.spinnerTarget.classList.add('is-hidden');
  }
}
