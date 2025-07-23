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
    this.lastSelectedValue = null; // Track the last selected value
    this.isValueSelected = false; // Track if a value was selected from autocomplete
    this.isSelecting = false; // Flag to prevent search during selection
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
    // Don't search if we're in the middle of selecting an item
    if (this.isSelecting) {
      return;
    }

    const query = this.inputTarget.value.trim();

    if (query.length < this.minChars) {
      this.hideSuggestions();
      return;
    }

    // Check if we should show suggestions based on selection state
    if (this.isValueSelected && this.lastSelectedValue) {
      // If the current query exactly matches the selected value, don't show suggestions
      if (query.toLowerCase() === this.lastSelectedValue.toLowerCase()) {
        this.hideSuggestions();
        return;
      }

      // If the query is a prefix of the selected value, don't show suggestions
      if (this.lastSelectedValue.toLowerCase().startsWith(query.toLowerCase())) {
        this.hideSuggestions();
        return;
      }

      // If the query is completely different from the selected value, reset the selection state
      if (!this.lastSelectedValue.toLowerCase().includes(query.toLowerCase()) && !query.toLowerCase().includes(this.lastSelectedValue.toLowerCase())) {
        this.isValueSelected = false;
        this.lastSelectedValue = null;
      }
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

    // Set flag to prevent search during selection
    this.isSelecting = true;

    this.inputTarget.value = selectedText;
    this.inputTarget.dispatchEvent(new Event('input', { bubbles: true }));

    // Mark that a value was selected and store it
    this.isValueSelected = true;
    this.lastSelectedValue = selectedText;

    this.hideSuggestions();

    // Reset the flag after a short delay to allow future searches
    setTimeout(() => {
      this.isSelecting = false;
    }, 100);
  }

  hideSuggestions() {
    this.suggestionsTarget.classList.add('is-hidden');
    this.selectedIndex = -1;
  }
}
