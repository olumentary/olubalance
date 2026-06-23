import { Controller } from '@hotwired/stimulus';

// Polls a long-running job's status by reloading the enclosing <turbo-frame>.
//
// The controller lives INSIDE the frame's content (re-rendered on every poll),
// so each reload reconnects a fresh instance with the latest status value. When
// the job reaches a terminal state ('complete' / 'failed'), the new instance
// simply doesn't schedule another tick — polling stops on its own.
export default class extends Controller {
  static values = {
    status: String,
    interval: { type: Number, default: 2000 },
  };

  connect() {
    if (this.inProgress) {
      this.timer = setTimeout(() => this.reloadFrame(), this.intervalValue);
    }
  }

  disconnect() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }

  get inProgress() {
    return ['pending', 'processing'].includes(this.statusValue);
  }

  reloadFrame() {
    const frame = this.element.closest('turbo-frame');
    if (frame && typeof frame.reload === 'function') {
      frame.reload();
    }
  }
}
