import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ 'accounttype', 'interestrate', 'creditlimit', 'statementday' ]

  connect() {
    this.toggleFields()
  }

  toggleFields() {
    if (this.accounttypeTarget.value == 'credit') {
      this.interestrateTarget.classList.remove('is-hidden')
      this.creditlimitTarget.classList.remove('is-hidden')
      this.statementdayTarget.classList.remove('is-hidden')
    }
    else if (this.accounttypeTarget.value == 'savings') {
      this.interestrateTarget.classList.remove('is-hidden')
      this.creditlimitTarget.classList.add('is-hidden')
      this.statementdayTarget.classList.add('is-hidden')
    }
    else {
      this.interestrateTarget.classList.add('is-hidden')
      this.creditlimitTarget.classList.add('is-hidden')
      this.statementdayTarget.classList.add('is-hidden')
    }
  }
}