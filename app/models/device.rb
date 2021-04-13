require 'googleauth'
require 'google/apis/fcm_v1'

class Device < ActiveRecord::Base
  include FixtureSave
  has_many :vouchers
  belongs_to :owner
  # will add device_type for multi-product vendors
  #belongs_to :device_type

  has_many :owners, -> { order("vouchers.created_at DESC") }, through: :vouchers

  attr_accessor :idevid, :dev_key

  class CSRNotverified < Exception; end
  class CSRSerialNumberDuplicated < Exception; end
  class CSRFailed < Exception; end

  before_save :fill_in_pub_key
  before_save :serial_number_from_eui64

  scope :active,  -> { where.not(obsolete: true) }
  scope :obsolete,-> { where(obsolete: true) }
  scope :owned,   -> { where.not(owner: nil) }
  scope :unowned, -> { where(owner: nil) }

  def canonicalize_eui64(str)
    self.class.canonicalize_eui64(str)
  end

  def self.canonicalize_eui64(str)
    return '' unless str
    nocolondash = str.downcase.gsub(/[\-\:]/,'')
    result=''
    filler=''
    toggle=false
    nocolondash.split('').each { |letter|
      result = result + filler + letter
      filler = '-' if toggle
      filler = ''  unless toggle
      toggle = !toggle
    }
    result
  end

  def self.list_dev(output = $stdout)
    output.puts sprintf("%22s  %26s %s",
                 "PRODUCTID", "EUI64", "status")

    count = 0
    self.all.each { |dev|
      if dev.owner
        ownerstr = "owned by #{dev.owner.name}"
      elsif dev.obsolete?
        ownerstr = "obsolete"
      else
        ownerstr = "unowned"
      end
      output.puts sprintf("%22s: %26s %s",
                   dev.serial_number,
                   dev.eui64,
                   ownerstr)
      count += 1
    }
    count
  end

  def self.find_by_number(number)
    active.where(fqdn: number.downcase).take || active.where(serial_number: number).take || active.where(eui64: canonicalize_eui64(number)).take
  end
  def self.create_by_number(number)
    find_by_number(number) || create(eui64: canonicalize_eui64(number))
  end
  def self.find_by_second_eui64(number)
    where(second_eui64: number).take
  end
  def self.find_obsolete_by_eui64(number)
    where(serial_number: number).take ||
      where(eui64: canonicalize_eui64(number)).take ||
      where(second_eui64: canonicalize_eui64(number)).take
  end

  def self.find_obsolete_or_create_by_eui64(number)
    find_obsolete_by_eui64(number) || create(eui64: canonicalize_eui64(number))
  end

  def self.create_from_csr_io(csrio)
    create_from_csr(OpenSSL::X509::Request.new(csrio))
  end

  # call-seq:
  #   Device.create_by_csr(csr) => device
  #
  # creates a new device identity using the public key found in the CSR.
  # the public key will be used to lookup a device object by public key, creating one
  # if necessary.
  #
  # Any serialNumber attribute found in the CSR will be used, provided it is already
  # unique (or matches the existing device), otherwise, the creation fails.
  # The rest of the proposed DN will be ignored, and any subjectAltName proposed will
  # also be ignored.
  def self.create_from_csr(csr)
    unless csr.verify(csr.public_key)
      raise CSRNotVerified;
    end

    dev = self.find_by_PKey(csr.public_key)

    # if no existing device, then look for one with the same serial number, and
    # reject if it exists.
    unless dev
      attributes = Hash.new
      items = csr.subject.to_a
      items.each { |attr|
        case attr[2]
        when 12       # UTF8STRING
          attributes[attr[0]] = attr[1]
        when 19       # PRINTABLESTRING
          attributes[attr[0]] = attr[1]
        else
          # not sure what to do with other types now.
        end
      }

      if attributes["serialNumber"]
        odev = active.find_by_serial_number(attributes["serialNumber"])
        if odev
          raise CSRSerialNumberDuplicated.new("#{attributes["serialNumber"]} duplicated by #{odev.id}");
        end
      end

      # so, not found, create a device with the same serial number.
      dev = create(:serial_number => attributes["serialNumber"])
      dev.eui64 = dev.serial_number
      dev.set_public_key(csr.public_key)
    end

    # found a suitable dev, now write a certificate for it, and store it.
    # will allocate an EUI-64 for it along the way.
    # The caller can set the model if desired.
    dev.sign_eui64
    dev.save!

    dev
  end

  def self.find_by_PKey(pkey)
    return nil if pkey.blank?
    b64 = Base64::strict_encode64(pkey.to_der)
    find_by_pub_key(b64)
  end

  def self.get_router_by_identity(certpem)
    # canonicalize into certificate, to get public key, and look it up
    find_by_PKey(OpenSSL::X509::Certificate.new(certpem).try(:public_key))
  end

  # make sure extra_attrs is initialized as a hash.
  def extra_attrs
    self[:extra_attrs] ||= Hash.new
  end

  def sign_from_base64_csr(csr64)
    csrio = Base64.decode64(csr64)
    csr = OpenSSL::X509::Request.new(csrio)
    sign_from_csr(csr)
  end

  def certificate_already_satisfies_csr(csr)
    return false unless self.public_key        # skip if no public key yet
    return false unless csr.public_key.to_der  == self.public_key.to_der
    return false unless csr.subject.to_s.downcase.include?(shg_basename.downcase)
    return false unless self.certificate
    return false if self.certificate.not_after  < Time.now.utc
    return false if self.certificate.not_before > Time.now.utc
    return true
  end

  def sign_from_csr(csr)
    unless csr.verify(csr.public_key)
      raise CSRNotVerified;
    end

    # skip everything if existing certificate is good
    return true if certificate_already_satisfies_csr(csr)

    set_public_key(csr.public_key)
    case
    when $INTERNAL_CA_SHG_DEVICE
      logger.info "Signing CSR with internal CA"
      sign_from_csr_internal(csr)
    when $LETSENCRYPT_CA_SHG_DEVICE
      logger.info "Processing CSR with LetsEncrypt"
      result = sign_from_csr_letsencrypt(csr)
      logger.info "device #{id} CSR created"
      insert_ula_quad_ah
      logger.info "device #{id} CSR processed"
    else
      logger.info "No certificate authority enabled"
    end
  end

  def split_up_bag_of_certificates(txt)
    return [] if txt.blank?
    txt.split(/-----END CERTIFICATE-----/).collect {|certtxt|
      if(certtxt =~ /BEGIN CERTIFICATE/)
        OpenSSL::X509::Certificate.new(certtxt + "-----END CERTIFICATE-----\n")
      end
    }
  end

  def sign_from_csr_letsencrypt(csr)
    # a pem format certificate is returned, possibly with extra certificates
    # tagged on as well, as a "bag"
    begin
      cert_bag = AcmeKeys.acme.cert_for(shg_basename, shg_zone, csr, logger, 120)
    rescue Faraday::ConnectionFailed => e
      raise CSRFailed.new("LetsEncrypt/ACME failed to connect #{e.message}")
    end

    logger.info "device #{id} received certificate, populating to #{shg_basezone}"

    raise CSRFailed.new("cert bag broken") unless cert_bag

    certs = split_up_bag_of_certificates(cert_bag)
    first = certs.shift

    self.certificate = first
    logger.info "device #{id} gets certificate #{first.subject.to_s}"

    self.othercerts = ""
    certs.each { |cert|
      if cert
        self.othercerts << cert.to_pem
      end
    }
    save!
  end

  def insert_quad_ah(hostname, addr, remove = true)

    if remove
      AcmeKeys.acme.acme_dns_updater.remove { |m|
        m.type = :aaaa
        m.zone = shg_basezone
        m.hostname = hostname
      }
    end
    worked = AcmeKeys.acme.acme_dns_updater.update { |m|
      m.type = :aaaa
      m.zone = shg_basezone
      m.hostname = hostname
      m.address  = addr
      logger.info "device #{id} ULA updating to #{hostname} to #{addr}"
    }
    unless worked
      logger.error "Failed to do DNS update #{hostname} -> #{addr}"
      return false
    end
    unless rfc1918.blank?
      worked = AcmeKeys.acme.acme_dns_updater.update { |m|
        m.type = :record
        m.zone = shg_zone
        m.hostname = hostname
        m.address  = rfc1918
        logger.info "device #{id} A updating to #{hostname} to #{m.address}"
      }
    end
    return true
  end

  def router_name_ip
    hostname   = shg_basename
    addr       = ulanet.host_address(1).to_s
    return hostname, addr
  end

  def mud_router_name_ip
    hostname = "mud." + shg_basename
    addr     = ulanet.host_address(2).to_s
    return hostname, addr
  end

  def mudmac_router_name_ip
    hostname = "mud." + shg_basename

    # also add the ULA + ::2c66:d8ff:fe00:9329 which is the SLAAC address for now.
    # because the ::2 address is not reliably added.
    slaac = ACPAddress.new("::2c66:d8ff:fe00:9329")
    addr  = ulanet.host_address(slaac.to_u128).to_s
    return hostname, addr
  end

  def insert_ula_quad_ah
    hostname = nil
    addr     = nil
    return nil unless AcmeKeys.acme.acme_dns_updater

    (hostname,addr) = router_name_ip
    return false unless insert_quad_ah(hostname, addr)

    (hostname,addr) = mudmac_router_name_ip
    return false unless insert_quad_ah(hostname, addr)

    # do not put AAAA in for MUD IP
    #(hostname,addr) = mud_router_name_ip
    #return false unless insert_quad_ah(hostname, addr, false)
    return true
  end

  # this routine is used to sign SHG device CSR for bootstrap use.
  # The MASA URL is still included, but the sanitized_eui64 is not included,
  # and the DN includes the requested CN value as well as the serial number.
  def sign_from_csr_internal(csr)
    sign_setup_certificate

    # make sure that fqdn has been setup.
    # the CSR value is actually pretty much ignored... how can we trust any of it?
    # 12 - is the code for UTF8 string, I think.
    subject_list = [["CN", fqdn, 12],
                    ["serialNumber", serial_number,12],
                    ["CN", "mud." + fqdn, 12]]

    @idevid.subject = OpenSSL::X509::Name.new(subject_list)

    # this depends upon a patch to ruby-openssl, at:
    #  https://github.com/mcr/openssl/commit/a59c5e049b8b4b7313c6532692fa67ba84d1707c
    @idevid.add_extension(masa_extension)
    @idevid.sign(HighwayKeys.ca.rootprivkey, OpenSSL::Digest::SHA256.new)

    self.certificate     = @idevid
    save!
  end

  def tgz_name
    @tgz ||= $TGZ_FILE_LOCATION.join('shg', "dev_#{self.id}")
  end
  def tgz_filename
    "#{tgz_name.to_s}.tgz"
  end

  # this creates a tgz file for installation in a SecureHomeGateway.ca
  # the file name is returned.
  def generate_tgz_for_shg
    unless File.exist?(tgz_name)
      FileUtils.mkdir_p(tgz_name)
    end

    if $TURRIS_ROOT_LOCATION
      # Copy the root filesystem for Turris in the tgz location
      FileUtils.copy_entry($TURRIS_ROOT_LOCATION, tgz_name, true, true, true)
    end

    # write out the certificate
    certdir = tgz_name.join("etc", "shg")
    FileUtils.mkdir_p(certdir)
    unless certificate
      logger.info "tgz file not created due to lack of certificate"
      return nil
    end
    # put the key that will be validating the vouchers in
    FileUtils.copy_entry MasaKeys.masa.masa_pubkey, certdir.join("masa.crt")

    masa_certdir=tgz_name.join("srv", "lxc", "mud-supervisor", "rootfs", "app", "certificates")
    FileUtils.mkdir_p(masa_certdir)
    FileUtils.copy_entry MasaKeys.masa.masa_pubkey, masa_certdir.join("masa.crt")

    File.open(certdir.join("idevid_cert.pem"), "w") { |f|
      f.write certificate.to_pem
    }
    File.open(certdir.join("intermediate_certs.pem"), "w") { |f|
      f.write othercerts
    }

    # extend /etc/hosts with addresses so that dnsmasq will answer them if no Internet.
    etcdir = tgz_name.join("etc", "shg", "extra", "etc")
    FileUtils.mkdir_p(etcdir)
    etchosts=etcdir.join("hosts")
    File.open(etchosts, "w") { |f|
      (host, addr) = router_name_ip
      f.puts sprintf("%s %s router", addr, host)

      # no way to force the ::2 to work, so avoid for now.
      #(host, addr) = mud_router_name_ip
      #f.puts sprintf("%s %s mud", addr, host)

      (host, addr) = mudmac_router_name_ip
      f.puts sprintf("%s %s mud", addr, host)
    }

    # create /etc/lighttpd/conf.d/50-https.conf
    # XXX this should be done with a templated .conf.erb file
    httpsdir = tgz_name.join("etc", "lighttpd", "conf.d")
    FileUtils.mkdir_p(httpsdir)
    httpsconf= httpsdir.join("50-https.conf")
    File.open(httpsconf, "w") { |f|
      f.puts "$SERVER[\"socket\"] == \"[::]:443\" {"
      f.puts "    ssl.engine  = \"enable\""
      f.puts "    ssl.pemfile = \"/etc/shg/lighttpd.pem\""
      f.puts "    ssl.ca-file = \"/etc/shg/intermediate_certs.pem\""
      f.puts "} else $SERVER[\"socket\"] == \"0.0.0.0:443\" {"
      f.puts "    ssl.engine  = \"enable\""
      f.puts "    ssl.pemfile = \"/etc/shg/lighttpd.pem\""
      f.puts "    ssl.ca-file = \"/etc/shg/intermediate_certs.pem\""
      f.puts "} else $HTTP[\"scheme\"] == \"http\" {"
      f.puts "    $HTTP[\"host\"] =~ \".*\" {"
      f.puts "        url.redirect = (\".*\" => \"https://#{shg_basename}$0\")"
      f.puts "  }"
      f.puts "}"
    }

    # invoke tar to collect it all, but avoid invoking a shell.
    #puts ["tar", "-C", tgz_name.to_s, "-c", "-z", "-f", tgz_filename, "."].join(' ')
    system("tar", "-C", tgz_name.to_s, "-c", "-z", "-f", tgz_filename, ".")
    FileUtils.remove_entry_secure(tgz_name, true)
    FileUtils.rmdir(tgz_name) if File.exist?(tgz_name)
    tgz_filename
  end

  def set_public_key(key)
    # stupid issue with API into EC::Point
    if key.kind_of?(OpenSSL::PKey::EC::Point)
      pub = OpenSSL::PKey::EC.new(key.group)
      pub.public_key = key
      key = pub
    end
    self.pub_key = Base64::strict_encode64(key.to_der)
  end

  def public_key
    @public_key ||= (OpenSSL::PKey.read(Base64::decode64(pub_key)) unless pub_key.blank?)
  end

  def activated!
    self.obsolete = false
    save!
  end
  def obsoleted!
    self.obsolete = true
    save!
  end

  def fill_in_pub_key
    if idevid_cert and !pub_key
      self.pub_key = Base64::strict_encode64(certificate.public_key.to_der)
    end
    true
  end

  def serial_number_from_eui64
    serial_number ||= eui64
    true
  end
  def serial_number
    self[:serial_number] ||= eui64
  end

  # take key type from settings in IDevIDKey.
  def gen_priv_key
    @dev_key = IDevIDKeys.ca.gen_client_pkey
  end

  def sanitized_eui64
    @sanitized_eui64 ||= eui64.upcase.gsub(/[^0-9A-F-]/,"")
  end

  # no dash or :
  def compact_eui64
    @compact_eui64 ||= eui64.upcase.gsub(/[^0-9A-F]/,"")
  end

  def linklocal_eui64
    @linklocal_eui64 ||= ACPAddress.iid_from_eui(compact_eui64)
  end

  def ulanet
    unless ula.blank?
      @ulanet ||= ACPAddress.new(ula)
    end
  end

  def short_ula
    if ulanet
      ulanet.ula_random_part_base[0..5]
    else
      ""
    end
  end

  def shg_suffix
    @shg_suffix ||= SystemVariable.string(:shg_suffix)
  end
  def shg_zone
    @shg_zone   ||= SystemVariable.string(:shg_zone)
  end

  def update_from_smarkaklink_provision(params)
    self.eui64        = canonicalize_eui64(params['switch-mac'])
    self.second_eui64 = canonicalize_eui64(params['wan-mac'])
    self.ula          = params['ula']

    # set to null, and reset.
    self.essid = self.fqdn = nil
    extrapolate_from_ula
  end

  # return a textual form of the ULA address
  def ula_str
    ula        # stored as string in DB for now.
  end
  def shg_basename
    raise CSRFailed.new("ula not set") unless ula_str
    @shg_basename ||= ['n' + short_ula,
                       shg_suffix, shg_zone].join('.')
  end
  def shg_basezone
    [shg_suffix, shg_zone].join('.')
  end

  def fqdn
    self[:fqdn] ||= shg_basename.downcase
  end

  def essid
    self[:essid] ||= ("SHG"+short_ula)
  end

  def extrapolate_from_ula
    self.fqdn  ||= fqdn.downcase
    self.essid ||= essid
    save!
  end

  def device_dir(dir = HighwayKeys.ca.devicedir)
    @devdir ||= dir.join(sanitized_eui64)
  end

  def zipfilename
    sprintf("product_%s.zip", sanitized_eui64)
  end

  def vendorprivkey(dir = HighwayKeys.ca.devicedir)
    @vendorprivkey ||= device_dir(dir).join("key.pem")
  end

  def store_priv_key(dir = HighwayKeys.ca.devicedir)
    FileUtils.mkpath(device_dir(dir))

    File.open(vendorprivkey(dir), "w", 0600) do |f| f.write @dev_key.to_pem end
    File.chmod(0400, vendorprivkey(dir))
  end

  def gen_or_load_priv_key(dir, curve = 'prime256v1', verbose=true)
    if File.exists?(vendorprivkey(dir))
      puts "Reused private key from #{vendorprivkey(dir)}" if verbose
      @dev_key = OpenSSL::PKey.read(IO::read(vendorprivkey(dir)))
    else
      gen_priv_key       # sets @dev_key
      store_priv_key(dir)
    end

    if pub_key.blank?
      set_public_key(@dev_key.public_key)
      save!
    end
    @dev_key
  end

  def certificate_filename(dir = HighwayKeys.ca.devicedir)
    devdir = device_dir(dir)
    FileUtils.mkpath(devdir)
    pubkeyfile = devdir.join("device.crt")
  end

  def store_certificate(dir = HighwayKeys.ca.devicedir)
    File.open(certificate_filename(dir), "w") do |f| f.write self.idevid_cert end
  end

  def calc_certificate
    OpenSSL::X509::Certificate.new(self.idevid_cert) unless idevid_cert.blank?
  end

  def certificate
    @idevid ||= calc_certificate
  end
  def certificate=(x)
    @idevid = x
    if x
      self.idevid_cert = x.to_pem
    end
  end

  def pubkey
    self[:pub_key]
  end

  # compare a given key to the key that has been given to this device.
  def signing_key?(othercert)
    case
    when othercert.is_a?(OpenSSL::X509::Certificate)
      (certificate.to_der == othercert.to_der)
    when (othercert.is_a?(OpenSSL::PKey) or othercert.is_a?(OpenSSL::PKey::EC))
      (certificate.public_key.to_der == othercert.to_der)
    else
      false
    end
  end

  def gen_and_store_key(dir = HighwayKeys.ca.devicedir)
    gen_or_load_priv_key(dir)
    sign_eui64
    store_certificate(dir)
  end

  def masa_url
    SystemVariable.string(:masa_iauthority) || "unset-masa-iauthority"
  end

  def masa_extension
    @mext ||= extension_factory.create_extension(
      "1.3.6.1.5.5.7.1.32",
      sprintf("ASN1:IA5STRING:%s", masa_url),
      false)
  end

  def extension_factory
    @ef ||= OpenSSL::X509::ExtensionFactory.new
  end

  def sign_setup_certificate(not_after = Time.gm(2999,12,31))
    @idevid  = OpenSSL::X509::Certificate.new
    @idevid.version = 2
    @idevid.serial = SystemVariable.randomseq(:serialnumber)
    @idevid.issuer = HighwayKeys.ca.rootkey.issuer
    @idevid.public_key = self.public_key
    @idevid.not_before = Time.now
    @idevid.not_after  = not_after

    self.serial_number ||= sanitized_eui64
  end

  def end_certificate_extensions
    extension_factory.subject_certificate = @idevid
    extension_factory.issuer_certificate  = HighwayKeys.ca.rootkey
    @idevid.add_extension(extension_factory.create_extension("subjectKeyIdentifier","hash",false))
    @idevid.add_extension(extension_factory.create_extension("basicConstraints","CA:FALSE",false))
  end

  def sign_eui64(not_after = Time.gm(2999,12,31))
    sign_setup_certificate(not_after)
    end_certificate_extensions
    @idevid.subject = OpenSSL::X509::Name.new([["serialNumber", serial_number,12]])

    # keyUsage and extendedKeyUsage (EKU) were tried, but shoud be avoided according to brski-20
    # @idevid.add_extension(extension_factory.create_extension("keyUsage","digitalSignature",false))
    # @idevid.add_extension(extension_factory.create_extension("extendedKeyUsage","clientAuth",false))

    if SystemVariable.boolvalue?(:eui64embed)
      # the OID: 1.3.6.1.4.1.46930.1 is a Private Enterprise Number OID:
      #    iso.org.dod.internet.private.enterprise . SANDELMAN=46930 . 1
      # subjectAltName=otherName:1.2.3.4;UTF8:some other identifier
      @idevid.add_extension(extension_factory.create_extension(
                              "subjectAltName",
                              sprintf("otherName:1.3.6.1.4.1.46930.1;UTF8:%s",
                                      self.sanitized_eui64),
                              false))
    end

    # depends upon a patch to ruby-openssl, at:
    #  https://github.com/mcr/openssl/commit/a59c5e049b8b4b7313c6532692fa67ba84d1707c
    @idevid.add_extension(masa_extension)

    # include the official HardwareModule OID:  1.3.6.1.5.5.7.8.4
    @idevid.sign(HighwayKeys.ca.rootprivkey, OpenSSL::Digest::SHA256.new)

    self.certificate     = @idevid
    save!
  end

  def audit_events
    vouchers.creation_order.collect {|vr|
      { 'date' => vr.created_at,
        'registrarID' => vr.owner.registrarID_base64,
        'nonce'       => vr.nonce
      }
    }
  end

  def audit_log
    al = Hash.new
    al['version'] = '1'
    al['events']  = audit_events
    al
  end

  # returns true if this device has ever been own owned by the given
  # owner, which is done by looking at the audit log.
  def device_owned_by?(owner)
    owners.include?(owner)
  end

  # for building fixtures, etc.
  def simplename
    "device_#{self.id}"
  end

  # for human consumption
  def name
    "Device #{sanitized_eui64}"
  end

  def savefixturefw(fw)
    return if save_self_tofixture(fw)
    vouchers.each { |voucher| voucher.savefixturefw(fw)}
  end

  # for SmartPledge QR code creation
  def dpphash_calc
    dc = Hash.new
    dc["S"] = SystemVariable.masa_iauthority
    dc["M"] = compact_eui64
    dc["K"] = Base64.strict_encode64(public_key.to_der)
    dc["L"] = linklocal_eui64.to_hex[-16..-1].upcase  # last 16 digits
    dc["E"] = essid
    dc
  end

  def dpphash
    @dpphash ||= dpphash_calc
  end

  def dpp_component(a)
    if dpphash[a]
      a + ":" + dpphash[a] + ";"
    else
      ""
    end
  end

  def dppstring
    "DPP:" +
      dpp_component("M") +
      dpp_component("I") +
      dpp_component("K") +
      dpp_component("L") +
      dpp_component("S") +
      dpp_component("E")
  end

  def self.fcm_client
    # The location of the google-service.json file is set by ENV['GOOGLE_APPLICATION_CREDENTIALS']
    ENV['GOOGLE_APPLICATION_CREDENTIALS'] ||= $FCM_SERVICE_CREDENTIALS.to_s

    # Get the environment configured authorization
    scopes =  [     'https://www.googleapis.com/auth/cloud-platform',
                    'https://www.googleapis.com/auth/firebase' ]
    @fcm           ||= Google::Apis::FcmV1::FirebaseCloudMessagingService.new
    @fcm.authorization = Google::Auth.get_application_default(scopes)
    @fcm
  end

  def fcm_client
    self.class.fcm_client
  end

  # now handle notifications outgoing from this device via firebase
  def notify_new_device_message(tokens, device)

    msg = { 'messageType'     => 'new_device',
            'hardwareAddress' => device }
    parent = "projects/#{fcm_client.authorization.project_id}"

    token1 = tokens.first
    #logger.info "Posting to token #{token1}"
    stufftosend = {
        data: msg,
        token: token1
    }

    message = ::Google::Apis::FcmV1::SendMessageRequest.new
    message.message = stufftosend
    #logger.info "Sending #{stufftosend.to_json}"
    response = fcm_client.send_message(parent, message)
    #logger.info "Response: #{response}"
    return response
  end

end
