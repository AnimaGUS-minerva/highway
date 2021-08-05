# RAVEN specific configuration (.dsn) has been moved to environment/production.rb
# on the target machines themselves. With .dsn, raven will not be enabled.

Sentry.init do |config|
  #config.dsn = 'https://something.ingest.sentry.io/else'
  config.enabled_environments = ['production']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Set tracesSampleRate to 1.0 to capture 100%
  # of transactions for performance monitoring.
  # We recommend adjusting this value in production
  config.traces_sample_rate = 0.5
  # or
  #config.traces_sampler = lambda do |context|
  # true
  #end
end

