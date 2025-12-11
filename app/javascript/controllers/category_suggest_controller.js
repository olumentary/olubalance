import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "select"];
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
    url.searchParams.set("description", description);

    fetch(url.toString(), {
      headers: { Accept: "application/json" },
      credentials: "same-origin",
    })
      .then((response) => {
        if (!response.ok) throw new Error("no suggestion");
        return response.json();
      })
      .then((data) => {
        if (data.category_id && this.selectTarget) {
          this.selectTarget.value = data.category_id;
        }
      })
      .catch(() => {
        /* ignore */
      });
  }
}

