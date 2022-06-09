# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# server "example.com", user: "deploy", roles: %w{app db web}, my_property: :my_value
# server "example.com", user: "deploy", roles: %w{app web}, other_property: :other_value
# server "db.example.com", user: "deploy", roles: %w{db}

# connect the hook directly
after :'deploy:log_revision', :'passenger:restart'

  set :deploy_to, '/honeydukes/app/highway'

  server "masa.honeydukes.sandelman.ca",
       user: "honeydukes",
       roles: %w{app db web},
       deploy_to: '/honeydukes/app/highway',
       git_wrapper_path: '/honeydukes/app/tmp'

set :stage, :production

# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult the Net::SSH documentation.
# http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start
#
# Global options
# --------------
set :ssh_options, {
      forward_agent: true,
    }

