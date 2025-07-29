# RAVEN specific configuration (.dsn) has been moved to environment/production.rb
# on the target machines themselves. With .dsn, raven will not be enabled.

Sentry.init do |config|
  dsn = Rails.application.credentials[:sentrydsn]
  if dsn
    config.dsn = dsn
  end
  # get breadcrumbs from logs
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Add data like request headers and IP for users, if applicable;
  # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
  config.send_default_pii = true

  # Set tracesSampleRate to 1.0 to capture 100%
  # of transactions for performance monitoring.
  # We recommend adjusting this value in production
  config.traces_sample_rate = 0.5
  # or
  #config.traces_sampler = lambda do |context|
  # true
  #end
end

