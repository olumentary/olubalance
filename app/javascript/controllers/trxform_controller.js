import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['submit', 'attachment', 'newreceipt', 'filename'];

  create() {
    this.submitTarget.classList.add('is-loading');
    if (this.attachmentTarget.value != '') {
      this.attachmentTarget.parentNode.classList.add('is-hidden');
      this.submitTarget.parentNode.insertAdjacentHTML(
        'afterend',
        `
        <div class="control" style="display: flex; align-items: center">
          Uploading attachment ...
        </div>
      `
      );
    }
  }

  // When an attachment file is selected, set the file-name field
  attachmentSelected() {
    var filename = this.attachmentTarget.value;
    var lastIndex = filename.lastIndexOf('\\');
    if (lastIndex >= 0) {
      filename = filename.substring(lastIndex + 1);
      filename = filename;
    }
    this.newreceiptTarget.innerHTML = 'Adding receipt: ';
    this.filenameTarget.innerHTML = filename;
  }

  // When the account is changed, update the form action URL
  accountChanged(event) {
    const accountId = event.target.value;
    const form = this.element.querySelector('form');
    const currentPath = form.action;
    const newPath = currentPath.replace(/\/accounts\/\d+\/transactions/, `/accounts/${accountId}/transactions`);
    form.action = newPath;
  }
}
