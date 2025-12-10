import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = {
    bills: Array
  };

  connect() {
    this.popup = null;
    this.hideTimeout = null;
    this.handlePopupEnter = this.clearHideTimer.bind(this);
    this.handlePopupLeave = this.scheduleHide.bind(this);
  }

  disconnect() {
    this.removePopup();
  }

  show() {
    this.clearHideTimer();

    if (!this.hasBillsValue || this.billsValue.length === 0) return;

    this.ensurePopup();
    this.renderContent();
    this.positionPopup();
    this.popup.classList.add('is-active');
  }

  hide() {
    this.scheduleHide();
  }

  scheduleHide() {
    this.clearHideTimer();
    this.hideTimeout = window.setTimeout(() => {
      this.hideImmediately();
    }, 200);
  }

  clearHideTimer() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout);
      this.hideTimeout = null;
    }
  }

  hideImmediately() {
    this.clearHideTimer();
    if (this.popup) {
      this.popup.classList.remove('is-active');
      this.popup.style.display = 'none';
      this.popup.style.visibility = 'hidden';
    }
  }

  ensurePopup() {
    if (this.popup) return;

    this.popup = document.createElement('div');
    this.popup.className = 'ob-summary-popup box';
    this.popup.setAttribute('role', 'presentation');
    document.body.appendChild(this.popup);
    this.popup.addEventListener('pointerenter', this.handlePopupEnter);
    this.popup.addEventListener('pointerleave', this.handlePopupLeave);
  }

  removePopup() {
    if (this.popup) {
      this.popup.removeEventListener('pointerenter', this.handlePopupEnter);
      this.popup.removeEventListener('pointerleave', this.handlePopupLeave);
    }
    if (this.popup && this.popup.parentNode) {
      this.popup.parentNode.removeChild(this.popup);
    }
    this.popup = null;
  }

  renderContent() {
    const bills = this.billsValue || [];
    const listItems = bills.map((bill) => `
      <li class="ob-summary-popup-line">
        <strong>${this.escape(bill.description)}</strong> ${this.escape(bill.detail)}
      </li>
    `).join('');

    const total = bills.reduce((sum, bill) => {
      const value = parseFloat(bill.monthly_amount);
      return sum + (isNaN(value) ? 0 : value);
    }, 0);
    const totalLine = `
      <div class="ob-summary-popup-divider"></div>
      <div class="ob-summary-popup-total">
        <span class="has-text-weight-semibold">Total</span>
        <span class="has-text-weight-semibold">${this.formatCurrency(total)}</span>
      </div>
    `;

    this.popup.innerHTML = `
      <div class="ob-summary-popup-header">
        <p class="has-text-weight-semibold mb-1">Breakdown</p>
      </div>
      <ul class="ob-summary-popup-list">
        ${listItems}
      </ul>
      ${totalLine}
    `;
  }

  positionPopup() {
    if (!this.popup) return;

    this.popup.style.visibility = 'hidden';
    this.popup.style.display = 'block';

    const rect = this.element.getBoundingClientRect();
    const popupRect = this.popup.getBoundingClientRect();
    const top = window.scrollY + rect.bottom + 8;
    let left = window.scrollX + rect.left + (rect.width / 2) - (popupRect.width / 2);

    const maxLeft = window.scrollX + document.documentElement.clientWidth - popupRect.width - 8;
    const minLeft = window.scrollX + 8;
    left = Math.max(minLeft, Math.min(left, maxLeft));

    this.popup.style.top = `${top}px`;
    this.popup.style.left = `${left}px`;
    this.popup.style.visibility = 'visible';
  }

  escape(text) {
    const div = document.createElement('div');
    div.textContent = text || '';
    return div.innerHTML;
  }

  formatCurrency(value) {
    if (isNaN(value)) return '';
    return new Intl.NumberFormat(undefined, { style: 'currency', currency: 'USD' }).format(value);
  }
}

