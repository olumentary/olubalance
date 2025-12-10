import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = [
    'frequency',
    'biweeklySection',
    'biweeklyTwoDays',
    'biweeklyEveryOtherWeek',
    'secondDay',
    'anchorDate',
    'anchorWeekday',
    'nextMonth'
  ];

  connect() {
    this.toggleSections();
  }

  changeFrequency() {
    this.toggleSections();
  }

  changeBiweeklyMode() {
    this.toggleBiweeklyMode();
  }

  toggleSections() {
    const frequency = this.frequencyTarget.value;
    const isBiweekly = frequency === 'bi_weekly';
    const isQuarterlyOrAnnual = frequency === 'quarterly' || frequency === 'annual';

    this.toggleTarget(this.biweeklySectionTarget, isBiweekly);
    this.toggleTarget(this.nextMonthTarget, isQuarterlyOrAnnual);
    this.setRequired(this.nextMonthTarget.querySelector('select'), isQuarterlyOrAnnual);

    if (isBiweekly) {
      this.toggleBiweeklyMode();
    } else {
      this.clearBiweeklyRequired();
    }
  }

  toggleBiweeklyMode() {
    const mode = this.currentBiweeklyMode();
    const isTwoDays = mode === 'two_days';
    const isEveryOtherWeek = mode === 'every_other_week';

    this.toggleTarget(this.biweeklyTwoDaysTarget, isTwoDays);
    this.toggleTarget(this.biweeklyEveryOtherWeekTarget, isEveryOtherWeek);

    this.setRequired(this.secondDayTarget, isTwoDays);
    this.setRequired(this.anchorDateTarget, isEveryOtherWeek);
    this.setRequired(this.anchorWeekdayTarget, isEveryOtherWeek);
  }

  currentBiweeklyMode() {
    const checked = this.element.querySelector('input[name="bill[biweekly_mode]"]:checked');
    return checked ? checked.value : null;
  }

  toggleTarget(target, shouldShow) {
    target.classList.toggle('is-hidden', !shouldShow);
  }

  setRequired(element, required) {
    if (!element) return;
    element.required = required;
  }

  clearBiweeklyRequired() {
    this.setRequired(this.secondDayTarget, false);
    this.setRequired(this.anchorDateTarget, false);
    this.setRequired(this.anchorWeekdayTarget, false);
  }
}

