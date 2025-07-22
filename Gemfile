source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', "~> 8.0.0"
gem 'cow_proxy', :git => 'https://github.com/mcr/cow_proxy.git'
gem 'zeitwerk'

gem 'psych', '~> 3.3'

# Use postgresql as the database for Active Record
gem 'sqlite3', "~> 1.4.0"
gem 'pg'

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

# while we need the CMS code, and the not DTLS code,
# so it would be nice to not complicate life with need for openssl 1.1.1 w/patches
# maintaining multiple branches is also a pain.
#gem 'openssl', :git => 'https://github.com:mcr/ruby-openssl.git', :branch => 'ruby-3-openssl-3-cms'
gem 'openssl', :path => '../minerva/ruby3-openssl3'

# for static files
gem 'rails-static-router'

# for github warning
gem 'warden', '~> 1.2.3'
gem "devise", ">= 4.7.1"
gem "rake", ">= 12.3.3"
gem "netaddr", ">= 2.0.4"
gem "actionview", ">= 5.2.7.1"
gem "yard", ">= 0.9.20"
gem "websocket-extensions", ">= 0.1.5"
gem "rack", ">= 2.2.6.4"
gem "loofah", ">= 2.19.1"
gem "actionpack", ">= 5.2.6.2"
gem "activerecord", ">= 5.2.8.1"
gem "json", ">= 2.3.0"
gem "rexml", ">= 3.2.5"
gem "addressable", ">= 2.8.0"
gem "nokogiri", ">= 1.18.9"
gem "rails-html-sanitizer", ">= 1.4.4"
gem "tzinfo", ">= 1.2.10"
gem "globalid", ">= 1.0.1"
gem 'concurrent-ruby', '>= 1.3.4'

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

#gem 'chariwt', :path => '../chariwt'
# need version 0.11.0 to get correct date and nonce types
gem 'chariwt', :git => 'https://github.com/AnimaGUS-minerva/ChariWTs.git', :branch => 'v0.11.0'
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


