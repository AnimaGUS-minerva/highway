Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # there are no significant assets here, but a few images and redirects
  # do exist.
  config.public_file_server.enabled = true

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = false

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Debug mode disables concatenation and preprocessing of assets.
  # This option may cause significant delays in view rendering with a large
  # number of complex assets.
  config.assets.debug = true

  # Asset digests allow you to set far-future HTTP expiration dates on all assets,
  # yet still be able to expire them through the digest params.
  config.assets.digest = true

  # Adds additional error checking when serving assets at runtime.
  # Checks for improperly declared sprockets dependencies.
  # Raises helpful error messages.
  config.assets.raise_runtime_errors = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  config.action_mailer.smtp_settings = {
    :address => 'localhost',
    :port => '25',
    :enable_starttls_auto => false,
    :openssl_verify_mode => 'none'
  }

  config.action_mailer.perform_deliveries = false
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_options = {from: 'mcr+minerva@sandelman.ca'}

end

$TGZ_FILE_LOCATION = Pathname.new("/var/tmp/tgz")
$TURRIS_ROOT_LOCATION = Rails.root.join("turris_root")
$ACME_SERVER = "https://acme-v02.api.letsencrypt.org/directory"
$FCM_KEYS    = JSON.parse(Rails.root.join('config', 'fcm.json').read
Raven.configure do |config|
  config.dsn = 'https://184818fffd53434eb0c7e555016558de:adfecbb2123b40c88df38f2bb9bd76fb@sentry.io/1488540'
end


