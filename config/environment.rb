# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

$MASAUrl = 'https://highway.sandelman.ca/'
$ADMINTERFACE = false

# SHG-provisioning controls... replace with appropriate yaml file?
$TOFU_DEVICE_REGISTER = true

# set these in environments/
#$INTERNAL_CA_SHG_DEVICE=false
#$LETENCRYPT_CA_SHG_DEVICE=true

$TGZ_FILE_LOCATION = Rails.root.join("tmp")
$TURRIS_ROOT_LOCATION = Rails.root.join("turris_root")

$VERSION = "0.9.14"

# gets overridden by config/initializers/revision.rb by capistrano
$REVISION ||= "devel"

Mime::Type.register "application/voucher-cose+cbor", :vcc
Mime::Type.register "application/pkcs7-mime", :cms
Mime::Type.register "application/cms",        :cms

acme_settings_file = Rails.root.join("config", "acme.yml")
unless File.exist?(acme_settings_file)
  acme_settings_file = Rails.root.join("config", "acme.yaml")
end
if File.exist?(acme_settings_file)
  options = HashWithIndifferentAccess.new(YAML.load(IO::read(acme_settings_file)))
  if options
    AcmeKeys.acme.dns_update_options = options["dns_update_options"]
    if AcmeKeys.acme.dns_update_options[:acme_server]
      AcmeKeys.acme.server = AcmeKeys.acme.dns_update_options[:acme_server]
      $INTERNAL_CA_SHG_DEVICE = false
      $LETSENCRYPT_CA_SHG_DEVICE=true
    end
  end
end
