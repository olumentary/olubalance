import { Controller } from '@hotwired/stimulus';

// Generic clipboard controller. Usage:
//
//   <div data-controller="clipboard"
//        data-clipboard-text-value="text to copy"
//        data-clipboard-copied-label-value="Copied!">
//     <button data-action="click->clipboard#copy">Copy</button>
//   </div>
export default class extends Controller {
  static values = {
    text: String,
    copiedLabel: { type: String, default: 'Copied to clipboard' },
  };

  copy(event) {
    event.preventDefault();
    const button = event.currentTarget;
    if (!this.textValue) return;

    navigator.clipboard.writeText(this.textValue).then(
      () => this._flash(button, this.copiedLabelValue),
      () => this._flash(button, 'Copy failed — select manually'),
    );
  }

  _flash(button, message) {
    const original = button.innerHTML;
    button.innerHTML = `<span>${message}</span>`;
    button.disabled = true;
    setTimeout(() => {
      button.innerHTML = original;
      button.disabled = false;
    }, 1500);
  }
}
