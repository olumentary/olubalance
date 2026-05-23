# frozen_string_literal: true

module SecurityEventsHelper
  EVENT_CLASSES = {
    "success"      => "is-success",
    "otp_success"  => "is-success",
    "failure"      => "is-warning",
    "otp_failure"  => "is-warning",
    "throttle"     => "is-warning is-light",
    "block"        => "is-danger",
    "lockout"      => "is-danger",
    "unlock"       => "is-info"
  }.freeze

  def event_type_class(event_type)
    EVENT_CLASSES.fetch(event_type, "is-light")
  end
end
