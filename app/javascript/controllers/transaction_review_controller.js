import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = {
    url: String,
  };

  connect() {}

  async markReviewed() {
    // Client-side validation first
    const validationErrors = this.validateTransactionForReview();
    if (validationErrors.length > 0) {
      this.showErrors(validationErrors);
      return;
    }

    try {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          Accept: 'text/vnd.turbo-stream.html',
        },
        credentials: 'same-origin',
      });

      if (response.ok) {
        // Turbo Stream response will automatically update the page
        const html = await response.text();
        Turbo.renderStreamMessage(html);
      } else {
        // Handle error response - check content type
        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
          const data = await response.json();
          this.showErrors(data.errors);
        } else {
          // Handle Turbo Stream error response
          const html = await response.text();
          Turbo.renderStreamMessage(html);
        }
      }
    } catch (error) {
      console.error('Error:', error);
      this.showErrors(['An error occurred while updating the transaction.']);
    }
  }

  async markPending() {
    try {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          Accept: 'text/vnd.turbo-stream.html',
        },
        credentials: 'same-origin',
      });

      if (response.ok) {
        // Turbo Stream response will automatically update the page
        const html = await response.text();
        Turbo.renderStreamMessage(html);
      } else {
        // Handle error response - check content type
        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
          const data = await response.json();
          this.showErrors(data.errors);
        } else {
          // Handle Turbo Stream error response
          const html = await response.text();
          Turbo.renderStreamMessage(html);
        }
      }
    } catch (error) {
      console.error('Error:', error);
      this.showErrors(['An error occurred while updating the transaction.']);
    }
  }

  validateTransactionForReview() {
    const errors = [];
    const row = this.element.closest('tr');

    // Check for required fields
    const dateCell = row.querySelector('td:first-child');
    const descriptionCell = row.querySelector('td:nth-child(2)');
    const amountCell = row.querySelector('td:nth-child(3)');

    // Check if date is present (not "Pending Receipt")
    const dateText = dateCell.textContent.trim();
    if (!dateText || dateText === 'Pending Receipt') {
      errors.push('Transaction date is required');
    }

    // Check if description is present (not "Pending Receipt")
    const descriptionText = descriptionCell.textContent.trim();
    if (!descriptionText || descriptionText === 'Pending Receipt') {
      errors.push('Description is required');
    }

    // Check if amount is present (not "Pending")
    const amountText = amountCell.textContent.trim();
    if (!amountText || amountText === 'Pending') {
      errors.push('Amount is required');
    }

    // Check for attachment (look for paperclip icon)
    // Temporarily disabled - will be re-enabled later
    // const attachmentIcon = descriptionCell.querySelector('.fa-paperclip');
    // if (!attachmentIcon) {
    //   errors.push('Attachment is required');
    // }

    return errors;
  }

  showErrors(errors) {
    // Remove any existing error messages
    this.removeErrors();

    // Create error notification
    const notification = document.createElement('div');
    notification.className = 'notification is-danger is-light';
    notification.style.cssText = 'position: fixed; top: 20px; left: 50%; transform: translateX(-50%); z-index: 1000; width: 500px; max-width: 90vw;';

    const content = document.createElement('div');
    content.className = 'content';

    // Create header container with flexbox for title and close button
    const header = document.createElement('div');
    header.style.cssText = 'display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;';

    const title = document.createElement('h6');
    title.className = 'title is-6';
    title.style.margin = '0';
    title.textContent = 'Cannot mark as reviewed:';

    const closeButton = document.createElement('button');
    closeButton.className = 'delete';
    closeButton.style.margin = '0';
    closeButton.addEventListener('click', () => this.removeErrors());

    header.appendChild(title);
    header.appendChild(closeButton);

    const list = document.createElement('ul');
    list.style.cssText = 'margin: 0; padding-left: 20px;';
    errors.forEach(error => {
      const item = document.createElement('li');
      item.textContent = error;
      list.appendChild(item);
    });

    content.appendChild(header);
    content.appendChild(list);
    notification.appendChild(content);

    document.body.appendChild(notification);

    // Auto-remove after 5 seconds
    setTimeout(() => this.removeErrors(), 5000);
  }

  removeErrors() {
    const existingNotifications = document.querySelectorAll('.notification.is-danger.is-light');
    existingNotifications.forEach(notification => notification.remove());
  }
}
