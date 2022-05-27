source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', "~> 5.2.7.1"
gem 'cow_proxy', :git => 'https://github.com/mcr/cow_proxy.git'

gem 'psych', '~> 3.3'

# Use postgresql as the database for Active Record
gem 'pg', '~> 0.15'
gem 'sqlite3'

# Use jquery as the JavaScript library
gem 'jquery-rails'

gem 'log4r'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem 'turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 2.0'

# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', group: :doc

# raven for sentry.io
gem "sentry-ruby"
gem "sentry-rails"

# minimization is turned off.
#gem 'uglifier'
#gem 'therubyracer'

# need CMS code, but not DTLS code, so do not complicate life with
# need for openssl 1.1.1 w/patches.
#gem 'openssl', :git => 'https://github.com/CIRALabs/ruby-openssl.git', :branch => 'cms-added'
gem 'openssl', :path => '../minerva/ruby-openssl'

# for static files
gem 'rails-static-router'

# for github warning
gem 'warden', '~> 1.2.3'
gem "devise", ">= 4.7.1"
gem "loofah", ">= 2.3.1"
gem "rake", ">= 12.3.3"
gem "rack", ">= 2.2.3.1"
gem "nokogiri", ">= 1.13.5"
gem "netaddr", ">= 2.0.4"
gem "websocket-extensions", ">= 0.1.5"
gem "json", ">= 2.3.0"
gem "activerecord", ">= 5.2.4.5"
gem "rexml", ">= 3.2.5"
gem "actionpack", ">= 5.2.6.2"
gem "addressable", ">= 2.8.0"
gem "actionview", ">= 5.2.7.1"

# for LetsEncrypt
gem 'acme-client'
#gem 'dns-update', :path => '../minerva/dns-update'
gem 'dns-update', :git => 'https://github.com/CIRALabs/dns-update.git', :branch => 'aaaa_rr'

# used by IP address management in ANIMA ACP
gem 'ipaddress'

#gem 'active_scaffold', :git => 'https://github.com/activescaffold/active_scaffold.git'
gem 'sassc'
gem 'sass-rails'

# use this to get full decoding of HTTP Accept: headers, to be able to
# split off smime-type=voucher in pkcs7-mime, and other parameters
gem 'http-accept'

# used to generate multipart bodies
gem 'multipart_body', :git => 'https://github.com/AnimaGUS-minerva/multipart_body.git', :branch => 'binary_http_multipart'
#gem 'multipart_body', :path => '../minerva/multipart_body'

gem 'ecdsa',   :git => 'https://github.com/AnimaGUS-minerva/ruby_ecdsa.git', :branch => 'ecdsa_interface_openssl'
#gem 'ecdsa',   :path => '../minerva/ruby_ecdsa'

gem 'chariwt', :path => '../chariwt'
#gem 'chariwt', :git => 'https://github.com/AnimaGUS-minerva/ChariWTs.git', :branch => 'v0.9.0'
gem 'jwt'

gem 'thin'

# This is used for notifying clients, based upon provisioned devices
gem 'googleauth'
gem 'google-apis-fcm_v1'

# just in case we need it.
# Call 'byebug' anywhere in the code to stop execution and get a debugger console
gem 'byebug'

group :development, :test do
  gem "rspec-rails"
  gem "shoulda"
  gem 'shoulda-matchers'
  gem 'rails-controller-testing'
  gem 'vcr'
end

group :development do
  # Deploy with Capistrano
  gem 'capistrano'
  gem 'capistrano-bundler'
  gem 'capistrano-rails'
  gem 'capistrano-passenger'
  gem 'capistrano-rvm'

  # Spring speeds up development by keeping your application running
  #  in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'webmock'

  # sometimes does not get installed by default
  gem 'rb-readline'

end


