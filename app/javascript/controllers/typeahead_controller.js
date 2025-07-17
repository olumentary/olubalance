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

    // Add click outside listener to hide suggestions
    document.addEventListener('click', this.handleClickOutside.bind(this));

    // Add keyboard navigation
    this.inputTarget.addEventListener('keydown', this.handleKeydown.bind(this));

    this.selectedIndex = -1;
    this.searchTimeout = null;
    this.minChars = 3;
  }

  disconnect() {
    // Clean up the event listeners when the controller is disconnected
    document.removeEventListener('click', this.handleClickOutside.bind(this));
    this.inputTarget.removeEventListener('keydown', this.handleKeydown.bind(this));
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout);
    }
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions();
    }
  }

  handleKeydown(event) {
    const items = this.suggestionsTarget.querySelectorAll('.dropdown-item');

    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1);
        this.updateSelection(items);
        break;
      case 'ArrowUp':
        event.preventDefault();
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1);
        this.updateSelection(items);
        break;
      case 'Enter':
        event.preventDefault();
        if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
          this.selectItem(items[this.selectedIndex]);
        }
        break;
      case 'Escape':
        event.preventDefault();
        this.hideSuggestions();
        break;
    }
  }

  updateSelection(items) {
    items.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add('is-active');
        item.scrollIntoView({ block: 'nearest' });
      } else {
        item.classList.remove('is-active');
      }
    });
  }

  search() {
    const query = this.inputTarget.value.trim();

    if (query.length < this.minChars) {
      this.hideSuggestions();
      return;
    }

    // Clear any existing timeout
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout);
    }

    // Set a new timeout
    this.searchTimeout = setTimeout(() => {
      this.performSearch(query);
    }, 300); // 300ms debounce delay
  }

  async performSearch(query) {
    try {
      const response = await fetch(`${this.urlValue}?query=${encodeURIComponent(query)}`);
      const suggestions = await response.json();

      if (suggestions.length > 0) {
        const dropdownContent = this.suggestionsTarget.querySelector('.dropdown-content');
        dropdownContent.innerHTML = '';

        suggestions.forEach(suggestion => {
          const item = document.createElement('div');
          item.className = 'dropdown-item';
          item.textContent = suggestion;
          item.addEventListener('mousedown', e => {
            e.preventDefault();
            this.selectItem(item);
          });
          dropdownContent.appendChild(item);
        });

        this.suggestionsTarget.classList.remove('is-hidden');
        this.selectedIndex = -1;
      } else {
        this.hideSuggestions();
      }
    } catch (error) {
      console.error('Error fetching suggestions:', error);
    }
  }

  selectItem(element) {
    const selectedText = element.textContent.trim();
    this.inputTarget.value = selectedText;
    this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }));
    this.hideSuggestions();
  }

  hideSuggestions() {
    this.suggestionsTarget.classList.add('is-hidden');
    this.selectedIndex = -1;
  }
}
