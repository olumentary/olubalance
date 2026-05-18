# frozen_string_literal: true

# Content Security Policy. Starts in report-only mode so violations are surfaced
# in browser devtools without blocking legitimate scripts. Flip
# `content_security_policy_report_only` to `false` once you've confirmed there
# are no real violations.
#
# All scripts/styles are self-hosted (Bulma, Stimulus, Turbo, FontAwesome JS),
# so :self covers the main app. Adjust here if you add external CDNs or
# re-enable Google reCAPTCHA on a public-facing form.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :https
    policy.media_src   :self
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self, :unsafe_inline  # Bulma helpers + inline styles in views
    policy.connect_src :self
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self
  end

  # Run in report-only mode initially; flip to false to enforce.
  config.content_security_policy_report_only = true
end
