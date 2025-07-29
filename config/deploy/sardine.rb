# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

set :rvm_custom_path, '/usr/share/rvm'
set :rvm_type, :system
set :rvm_ruby_version, '3.3.8'
set :deploy_to, "/app/highway"
set :rails_env, "production"

server "sardine.sandelman.ca",
       user: "highway",
       roles: %w{app db web},
       deploy_to: '/app/highway',
       ssh_options: {
         user: ENV['USER']
       }

# Global options
# --------------
set :ssh_options, {
      forward_agent: true,
    }

