Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Do not eager load code on boot. This avoids loading your whole application
  # just for the purpose of running a single test. If you are using a tool that
  # preloads Rails for running tests, you may have to set it to true.
  config.eager_load = false

  # Configure static file server for tests with Cache-Control for performance.
  config.public_file_server.enabled = true
  config.public_file_server.haders={ 'Cache-Control' => 'public, max-age=3600'}

  # Show full error reports and disable caching.
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates.
  config.action_dispatch.show_exceptions = false

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Randomize the order test cases are executed.
  config.active_support.test_order = :random

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true

  config.action_mailer.smtp_settings = {
    :address => 'localhost',
    :port => '25',
    :enable_starttls_auto => false,
    :openssl_verify_mode => 'none'
  }

  config.action_mailer.perform_deliveries    = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_options = {from: 'mcr+minerva@sandelman.ca'}

  config.after_initialize do
    # in development mode, use the canned certificates from spec/files/cert,
    # which are also used for test.
    unless ENV['CERTDIR']
      HighwayKeys.ca.certdir = Rails.root.join('spec','files','cert')
      MasaKeys.ca.certdir = Rails.root.join('spec','files','cert')
      AcmeKeys.acme.certdir=Rails.root.join('spec','files','cert')
    end

    AcmeKeys.acme.server="https://acme-staging-v02.api.letsencrypt.org/directory"
    $FCM_SERVICE_CREDENTIALS = Rails.root.join("spec", "files", "development-service-info.json")
    $INTERNAL_CA_SHG_DEVICE=false
    $LETENCRYPT_CA_SHG_DEVICE=true
    # fake keys
    ENV['GOOGLE_APPLICATION_CREDENTIALS'] = Rails.root.join("spec", "files", "development-service-info.json").to_s

  end

end

