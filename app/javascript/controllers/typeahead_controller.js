import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['input', 'suggestions'];
  static values = {
    url: String,
  };

  connect() {
    this.inputTarget.setAttribute('autocomplete', 'off');
    this.inputTarget.setAttribute('autocorrect', 'off');
    this.inputTarget.setAttribute('autocapitalize', 'off');
    this.inputTarget.setAttribute('spellcheck', 'false');
  }

  async search() {
    const query = this.inputTarget.value.trim();

    if (query.length < 2) {
      this.suggestionsTarget.classList.add('is-hidden');
      return;
    }

    try {
      const response = await fetch(`${this.urlValue}?query=${encodeURIComponent(query)}`);
      const suggestions = await response.json();

      if (suggestions.length > 0) {
        const suggestionsHtml = suggestions.map(suggestion => `<div class="dropdown-item" data-action="click->typeahead#select">${suggestion}</div>`).join('');

        this.suggestionsTarget.querySelector('.dropdown-content').innerHTML = suggestionsHtml;
        this.suggestionsTarget.classList.remove('is-hidden');
      } else {
        this.suggestionsTarget.classList.add('is-hidden');
      }
    } catch (error) {
      console.error('Error fetching suggestions:', error);
    }
  }

  select(event) {
    this.inputTarget.value = event.target.textContent;
    this.suggestionsTarget.classList.add('is-hidden');
  }

  hideSuggestions() {
    this.suggestionsTarget.classList.add('is-hidden');
  }
}
