import { Controller } from '@hotwired/stimulus';

// Connects to data-controller="sortable-header"
// Manages sort state and resubmits the search form via Turbo Frame
export default class extends Controller {
  static targets = ['form', 'sortBy', 'sortDir'];

  sort(event) {
    event.preventDefault();

    const column = event.currentTarget.dataset.sortColumn;
    const currentSort = this.sortByTarget.value;
    const currentDir = this.sortDirTarget.value;

    // Toggle direction if clicking same column, otherwise default to desc (asc for description)
    if (currentSort === column) {
      this.sortDirTarget.value = currentDir === 'asc' ? 'desc' : 'asc';
    } else {
      this.sortByTarget.value = column;
      this.sortDirTarget.value = column === 'description' ? 'asc' : 'desc';
    }

    this.formTarget.requestSubmit();
  }
}
