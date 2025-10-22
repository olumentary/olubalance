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

    // Add ARIA attributes for accessibility
    this.inputTarget.setAttribute('role', 'combobox');
    this.inputTarget.setAttribute('aria-expanded', 'false');
    this.inputTarget.setAttribute('aria-autocomplete', 'list');
    this.inputTarget.setAttribute('aria-haspopup', 'listbox');

    // Add click outside listener to hide suggestions
    document.addEventListener('click', this.handleClickOutside.bind(this));

    // Add keyboard navigation
    this.inputTarget.addEventListener('keydown', this.handleKeydown.bind(this), true); // Use capture phase
    this.inputTarget.addEventListener('blur', this.handleBlur.bind(this));

    this.selectedIndex = -1;
    this.searchTimeout = null;
    this.minChars = 3;
    this.lastSelectedValue = null; // Track the last selected value
    this.isValueSelected = false; // Track if a value was selected from autocomplete
    this.isSelecting = false; // Flag to prevent search during selection
    this.isDropdownVisible = false; // Track dropdown visibility state
    this.isDropdownFocused = false; // Track if dropdown has focus for navigation
    this.focusedItemIndex = -1; // Track which item has focus for tab navigation
  }

  disconnect() {
    // Clean up the event listeners when the controller is disconnected
    document.removeEventListener('click', this.handleClickOutside.bind(this));
    this.inputTarget.removeEventListener('keydown', this.handleKeydown.bind(this), true);
    this.inputTarget.removeEventListener('blur', this.handleBlur.bind(this));
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout);
    }
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideSuggestions();
    }
  }

  handleBlur(event) {
    // Use setTimeout to allow for potential mouse clicks on dropdown items
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) {
        this.hideSuggestions();
      }
    }, 150);
  }

  handleKeydown(event) {
    const items = this.suggestionsTarget.querySelectorAll('.dropdown-item');

    // Handle dropdown keydown if dropdown is focused
    if (this.isDropdownFocused) {
      this.handleDropdownKeydown(event, items);
      return;
    }

    // Handle input field keydown
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        if (!this.isDropdownVisible) {
          // If dropdown is not visible, show it first
          this.search();
          return;
        }
        this.selectedIndex = Math.min(this.selectedIndex + 1, items.length - 1);
        this.updateSelection(items);
        break;
      case 'ArrowUp':
        event.preventDefault();
        if (!this.isDropdownVisible) {
          // If dropdown is not visible, show it first
          this.search();
          return;
        }
        this.selectedIndex = Math.max(this.selectedIndex - 1, -1);
        this.updateSelection(items);
        break;
      case 'Enter':
        event.preventDefault();
        if (this.selectedIndex >= 0 && items[this.selectedIndex]) {
          this.selectItem(items[this.selectedIndex]);
        }
        break;
      case 'Tab':
        // If dropdown is visible and has items, move focus to dropdown
        if (this.isDropdownVisible && items.length > 0 && !this.isDropdownFocused) {
          event.preventDefault();
          event.stopPropagation();
          this.focusDropdown();
        } else {
          // Allow normal tab behavior but hide dropdown
          this.hideSuggestions();
          this.blurDropdown();
        }
        break;
      case 'Escape':
        event.preventDefault();
        this.hideSuggestions();
        this.inputTarget.blur(); // Remove focus from input
        break;
      case 'Home':
        if (this.isDropdownVisible && items.length > 0) {
          event.preventDefault();
          this.selectedIndex = 0;
          this.updateSelection(items);
        }
        break;
      case 'End':
        if (this.isDropdownVisible && items.length > 0) {
          event.preventDefault();
          this.selectedIndex = items.length - 1;
          this.updateSelection(items);
        }
        break;
    }
  }

  handleDropdownKeydown(event, items) {
    switch (event.key) {
      case 'ArrowDown':
        event.preventDefault();
        this.focusedItemIndex = Math.min(this.focusedItemIndex + 1, items.length - 1);
        this.updateDropdownFocus(items);
        break;
      case 'ArrowUp':
        event.preventDefault();
        this.focusedItemIndex = Math.max(this.focusedItemIndex - 1, 0);
        this.updateDropdownFocus(items);
        break;
      case 'Enter':
        event.preventDefault();
        if (this.focusedItemIndex >= 0 && items[this.focusedItemIndex]) {
          this.selectItem(items[this.focusedItemIndex]);
          this.blurDropdown();
        }
        break;
      case 'Tab':
        event.preventDefault();
        if (this.focusedItemIndex >= 0 && items[this.focusedItemIndex]) {
          // Select the focused item and move to next field
          this.selectItem(items[this.focusedItemIndex]);
        }
        this.blurDropdown();
        this.hideSuggestions();
        // Move focus to next focusable element
        this.moveToNextField();
        break;
      case 'Escape':
        event.preventDefault();
        this.blurDropdown();
        this.inputTarget.focus();
        break;
      case 'Home':
        event.preventDefault();
        this.focusedItemIndex = 0;
        this.updateDropdownFocus(items);
        break;
      case 'End':
        event.preventDefault();
        this.focusedItemIndex = items.length - 1;
        this.updateDropdownFocus(items);
        break;
    }
  }

  updateSelection(items) {
    items.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add('is-active');
        item.setAttribute('aria-selected', 'true');
        item.scrollIntoView({ block: 'nearest' });
      } else {
        item.classList.remove('is-active');
        item.setAttribute('aria-selected', 'false');
      }
    });

    // Update ARIA attributes
    this.inputTarget.setAttribute('aria-activedescendant', this.selectedIndex >= 0 ? `suggestion-${this.selectedIndex}` : '');
  }

  updateDropdownFocus(items) {
    items.forEach((item, index) => {
      if (index === this.focusedItemIndex) {
        item.classList.add('is-focused');
        item.setAttribute('aria-selected', 'true');
        item.scrollIntoView({ block: 'nearest' });
      } else {
        item.classList.remove('is-focused');
        item.setAttribute('aria-selected', 'false');
      }
    });

    // Update the input's aria-activedescendant to point to the focused item
    if (this.focusedItemIndex >= 0 && items[this.focusedItemIndex]) {
      this.inputTarget.setAttribute('aria-activedescendant', `suggestion-${this.focusedItemIndex}`);
    } else {
      this.inputTarget.removeAttribute('aria-activedescendant');
    }
  }

  focusDropdown() {
    if (!this.isDropdownVisible) return;

    this.isDropdownFocused = true;
    this.focusedItemIndex = 0; // Start with first item
    const items = this.suggestionsTarget.querySelectorAll('.dropdown-item');

    if (items.length > 0) {
      this.updateDropdownFocus(items);
    }
  }

  blurDropdown() {
    this.isDropdownFocused = false;
    this.focusedItemIndex = -1;

    // Remove focus from all items
    const items = this.suggestionsTarget.querySelectorAll('.dropdown-item');
    items.forEach(item => {
      item.classList.remove('is-focused');
      item.setAttribute('aria-selected', 'false');
    });

    // Clear aria-activedescendant
    this.inputTarget.removeAttribute('aria-activedescendant');
  }

  moveToNextField() {
    // Find the next focusable element after the input
    const focusableElements = document.querySelectorAll(
      'input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), [tabindex]:not([tabindex="-1"])'
    );

    const currentIndex = Array.from(focusableElements).indexOf(this.inputTarget);
    if (currentIndex !== -1 && currentIndex < focusableElements.length - 1) {
      const nextElement = focusableElements[currentIndex + 1];
      // Use setTimeout to ensure focus happens after current event processing
      setTimeout(() => {
        nextElement.focus();
      }, 0);
    }
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

        // Set ARIA attributes for the dropdown
        this.suggestionsTarget.setAttribute('role', 'listbox');
        this.suggestionsTarget.setAttribute('aria-label', 'Suggestions');

        suggestions.forEach((suggestion, index) => {
          const item = document.createElement('div');
          item.className = 'dropdown-item';
          item.textContent = suggestion;
          item.setAttribute('role', 'option');
          item.setAttribute('id', `suggestion-${index}`);
          item.setAttribute('aria-selected', 'false');
          item.setAttribute('tabindex', '-1'); // Initially not focusable

          item.addEventListener('mousedown', e => {
            e.preventDefault();
            this.selectItem(item);
          });

          // Add keydown listener for individual items
          item.addEventListener('keydown', e => {
            this.handleDropdownKeydown(e, this.suggestionsTarget.querySelectorAll('.dropdown-item'));
          });

          dropdownContent.appendChild(item);
        });

        this.suggestionsTarget.classList.remove('is-hidden');
        this.isDropdownVisible = true;
        this.inputTarget.setAttribute('aria-expanded', 'true');
        this.selectedIndex = -1;
      } else {
        this.hideSuggestions();
      }
    } catch (error) {
      console.error('Error fetching suggestions:', error);
      this.hideSuggestions();
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
    this.isDropdownVisible = false;
    this.inputTarget.setAttribute('aria-expanded', 'false');
    this.inputTarget.removeAttribute('aria-activedescendant');
    this.selectedIndex = -1;
    this.blurDropdown();

    // Ensure focus returns to input if no other element is focused
    setTimeout(() => {
      if (!document.activeElement || document.activeElement === document.body) {
        this.inputTarget.focus();
      }
    }, 0);
  }
}
