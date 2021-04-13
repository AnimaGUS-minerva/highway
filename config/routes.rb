Rails.application.routes.draw do

  resources :iot_devices
  root to: static("index.html")
  get '/favicon.ico', to: static("favicon.ico")
  get '/robots.txt',  to: static("robots.txt")
  get '/sitemap.xml',  to: static("empty.xml")
  get '/.well-known/security.txt',  to: static("security.txt")

  if $ADMININTERFACE or Rails.env == 'test'
  devise_for :admins
  resources :voucher_requests
  resources :owners
  resources :vouchers
  resources :devices
  end

  # OLD EST processing at well known URLs (pre-RFC internet-draft)
  post '/.well-known/est/requestvoucher',  to: 'est#requestvoucher'
  post '/.well-known/est/requestauditlog', to: 'est#requestauditlog'

  # NEW EST processing at well known URLs
  post '/.well-known/brski/requestvoucher',  to: 'est#requestvoucher'
  post '/.well-known/brski/requestauditlog', to: 'est#requestauditlog'
  post '/.well-known/brski/enrollstatus', to: 'smarkaklink#enrollstatus'

  # EST processing of smarkaklink URLs
  post '/.well-known/brski/smarkaklink',  to: 'smarkaklink#enroll'
  post '/smarkaklink/enroll',           to: 'smarkaklink#enroll'
  post '/shg-provision',                to: 'smarkaklink#provision'

  # COMET processing of notification systems
  post '/send_new_device_notification',     to: 'iot_devices#new'
  post '/send_done_analyzing_notification', to: 'iot_devices#analysis_complete'

  resources :status,  :only => [:index ]
  resources :version, :only => [:index ]

end
