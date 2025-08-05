import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['levelSelect', 'accountSelection', 'accountSelect', 'categorySelect', 'taxYearField', 'taxYearInput', 'fileInput', 'fileName'];

  connect() {
    this.initializeForm();
    this.setupEventListeners();
  }

  initializeForm() {
    // Initialize account selection visibility
    if (this.levelSelectTarget.value === 'Account') {
      this.showAccountSelection();
    } else {
      this.hideAccountSelection();
    }

    // Initialize tax year field visibility
    if (this.categorySelectTarget.value === 'Taxes') {
      this.showTaxYearField();
    } else {
      this.hideTaxYearField();
    }
  }

  setupEventListeners() {
    // Handle level selection changes
    this.levelSelectTarget.addEventListener('change', e => {
      if (e.target.value === 'Account') {
        this.showAccountSelection();
      } else {
        this.hideAccountSelection();
      }
    });

    // Handle category selection changes
    this.categorySelectTarget.addEventListener('change', e => {
      if (e.target.value === 'Taxes') {
        this.showTaxYearField();
      } else {
        this.hideTaxYearField();
      }
    });

    // Handle file name display
    this.fileInputTarget.addEventListener('change', e => {
      if (e.target.files.length > 0) {
        this.fileNameTarget.textContent = e.target.files[0].name;
      } else {
        this.fileNameTarget.textContent = 'No file chosen';
      }
    });

    // Form validation
    this.element.addEventListener('submit', e => {
      if (!this.validateForm()) {
        e.preventDefault();
      }
    });
  }

  showAccountSelection() {
    this.accountSelectionTarget.style.display = 'block';
    this.accountSelectTarget.required = true;
  }

  hideAccountSelection() {
    this.accountSelectionTarget.style.display = 'none';
    this.accountSelectTarget.required = false;
    this.accountSelectTarget.value = '';
  }

  showTaxYearField() {
    this.taxYearFieldTarget.style.display = 'block';
    this.taxYearInputTarget.required = true;
  }

  hideTaxYearField() {
    this.taxYearFieldTarget.style.display = 'none';
    this.taxYearInputTarget.required = false;
    this.taxYearInputTarget.value = '';
  }

  validateForm() {
    let isValid = true;

    // Check account selection for Account-level documents
    if (this.levelSelectTarget.value === 'Account' && !this.accountSelectTarget.value) {
      alert('Please select an account for Account-level documents.');
      this.accountSelectTarget.focus();
      isValid = false;
    }

    // Check tax year for Tax documents
    if (this.categorySelectTarget.value === 'Taxes' && !this.taxYearInputTarget.value) {
      alert('Please enter a tax year for Tax documents.');
      this.taxYearInputTarget.focus();
      isValid = false;
    }

    return isValid;
  }
}
