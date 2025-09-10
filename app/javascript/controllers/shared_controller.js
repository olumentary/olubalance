import { Controller } from '@hotwired/stimulus';
import * as bulmaToast from 'bulma-toast';

export default class extends Controller {
  static targets = ['modal'];

  connect() {
    //Invoke bulma toast notifications, if any
    var message = this.data.get('message');
    var messageType = this.data.get('message-type');
    var toastClass = messageType == 'notice' ? 'link' : 'danger';
    if (message && messageType) {
      bulmaToast.toast({
        message: message,
        position: 'top-center',
        type: 'is-' + toastClass,
        duration: 1500,
      });
    }
    
    // Auto-enable remember me for mobile devices on login form
    this.autoRememberMeForMobile();
  }

  /**
   * toggleModal
   * @param {*} e - Event
   * Toggle the is-active class to hide and show a modal for the given passed in data-id
   */
  toggleModal(e) {
    // console.log(e.currentTarget.dataset.id)
    let modalId = e.currentTarget.dataset.id;
    document.getElementById(modalId).classList.toggle('is-active');
    console.log('Modal toggled');
  }
  
  /**
   * autoRememberMeForMobile
   * Automatically check the remember me checkbox for mobile devices
   * This ensures iOS app shortcuts maintain login state
   */
  autoRememberMeForMobile() {
    // Check if we're on a mobile device
    const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
    
    if (isMobile) {
      // Find the remember me checkbox on login form
      const rememberMeCheckbox = document.querySelector('input[name="user[remember_me]"]');
      if (rememberMeCheckbox) {
        rememberMeCheckbox.checked = true;
        console.log('Auto-enabled remember me for mobile device');
      }
    }
  }
}
