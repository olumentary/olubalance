require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Store uploaded files (see config/storage.yml for options).
  # Use STORAGE_SERVICE environment variable to switch between services.
  # Options: :local, :amazon, :linode. Defaults to :local so a self-hosted
  # instance with STORAGE_SERVICE unset writes to disk rather than failing
  # against S3 with cryptic AWS errors. Cloud deploys set STORAGE_SERVICE explicitly.
  config.active_storage.service = ENV.fetch('STORAGE_SERVICE', 'local').to_sym

  # SSL behavior is env-driven so the same image can run behind a TLS-terminating
  # reverse proxy (set both to "true") or be accessed directly over plain HTTP on a
  # LAN / self-hosted box (leave them unset/"false"). The Dokku deploy sets these to
  # "true" via its app config; self-host defaults to HTTP-friendly.
  ssl_enabled = ENV.fetch("FORCE_SSL", "false") == "true"

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = ENV.fetch("ASSUME_SSL", "false") == "true"

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ssl_enabled

  # Trust Dokku's nginx + Docker bridge as proxies so `request.remote_ip` reflects the real client.
  config.action_dispatch.trusted_proxies = [
    IPAddr.new("127.0.0.1"),
    IPAddr.new("::1"),
    IPAddr.new("10.0.0.0/8"),
    IPAddr.new("172.16.0.0/12"),
    IPAddr.new("192.168.0.0/16")
  ]

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
  
  # Session configuration for better mobile persistence
  config.session_store :cookie_store,
    key: '_olubalance_session',
    expire_after: 2.weeks,
    secure: ssl_enabled,
    same_site: :lax

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with Redis so Rack::Attack
  # throttle counters are shared across Puma workers and dynos.
  config.cache_store = :redis_cache_store, { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1") }

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates. Env-driven so
  # self-hosted instances generate correct links for their own hostname.
  config.action_mailer.default_url_options = {
    host: ENV.fetch("APP_HOST", "olubalance.com"),
    protocol: ssl_enabled ? "https" : "http"
  }

  config.action_mailer.delivery_method = :smtp
  config.action_mailer.default :charset => "utf-8"
  config.action_mailer.smtp_settings = {
    address: ENV['MAILER_ADDRESS'],
    port: ENV['MAILER_PORT'],
    user_name: ENV['MAILER_USER'],
    password: ENV['MAILER_PASSWORD'],
    authentication: 'plain',
    enable_starttls_auto: false
  }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
