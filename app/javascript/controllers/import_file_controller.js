import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['input', 'name', 'trigger'];

  selected() {
    const file = this.inputTarget.files[0];
    if (file) {
      this.nameTarget.textContent = file.name;
      this.triggerTarget.disabled = false;
    } else {
      this.nameTarget.textContent = 'No file selected';
      this.triggerTarget.disabled = true;
    }
  }
}
