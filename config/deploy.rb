# config valid only for current version of Capistrano
lock "3.16.0"

set :application, "highway"
#set :repo_url, "git+ssh://code.credil.org/git/pandora/highway"
set :repo_url, "git@github.com:AnimaGUS-minerva/highway.git"

# ask for the branch to deploy, default to current.
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
#set :deploy_to, "/data/highway/highway"

set :rvm_type, :system
set :rvm_ruby_version, '2.6.6'
set :rvm_roles,    [:app]
set :bundle_roles, [:app]


# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

set :assets_roles, []

# Default value for :linked_files is []
append :linked_files, "config/database.yml", "config/secrets.yml", "config/environments/production.rb", "config/acme.yml"
append :linked_files, "config/environments/sentry.rb"

# Default value for linked_dirs is []
append :linked_dirs, "db/cert", "db/devices", "db/inventory", "log", "tmp", "turris_root"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

#require 'byebug'

set :bundle_flags,      '--quiet' # this unsets --deployment, see details in config_bundler task details
set :bundle_path,       nil
set :bundle_without,    nil

namespace :deploy do
  desc 'Config bundler'
  task :config_bundler do
    on roles(/.*/) do
      execute :bundle, :config, '--local deployment true'
      execute :bundle, :config, '--local without "development:test"'
      execute :bundle, :config, "--local path #{shared_path.join('bundle')}"
    end
  end
end

before 'bundler:install', 'deploy:config_bundler'
