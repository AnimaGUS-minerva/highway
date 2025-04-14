class HighwayKeys
  attr_accessor :devdir, :certdir, :domain_curve, :client_curve, :algo

  def rootkey
    @rootkey ||= load_root_pub_key
  end
  def cacert
    rootkey
  end

  def rootprivkey
    @rootprivkey ||= load_root_priv_key
  end
  def ca_signing_key
    rootprivkey
  end

  def algo
    @algo         ||= SystemVariable.findwithdefault('domain_algo','ecdsa')
  end

  def domain_curve
    @domain_curve ||= SystemVariable.findwithdefault('domain_curve','secp384r1')
  end

  def serial
    SystemVariable.randomseq(:serialnumber)
  end

  def digest
    OpenSSL::Digest::SHA384.new
  end

  def client_algo
    @client_algo  ||= SystemVariable.findwithdefault('client_algo','ecdsa')
  end

  def client_curve
    @client_curve ||= SystemVariable.findwithdefault('client_curve','prime256v1')
  end

  def serial
    SystemVariable.nextval(:serialnumber)
  end

  def devicedir
    @devdir  ||= case
                 when ENV['DEVICEDIR']
                   Pathname.new(ENV['DEVICEDIR'])

                 when (Rails.env.development? or Rails.env.test?)
                   HighwayKeys.ca.certdir = Rails.root.join('spec','files','cert')

                 else
                   Rails.root.join('db').join('devices')
                 end
  end

  def certdir
    @certdir ||= case
                 when ENV['CERTDIR']
                   Pathname.new(ENV['CERTDIR'])

                 when (Rails.env.development? or Rails.env.test?)
                   HighwayKeys.ca.certdir = Rails.root.join('spec','files','cert')

                 else
                   Rails.root.join('db').join('cert')
                 end
  end

  def vendor_pubkey
    certdir.join("vendor_#{domain_curve}.crt")
  end

  def self.ca
    @ca ||= self.new
  end

  def root_priv_key_file
    @vendorprivkey ||= File.join(certdir, "vendor_#{domain_curve}.key")
  end

  def gen_client_pkey
    case client_algo
    when 'ecdsa'
      key = OpenSSL::PKey::EC.new(client_curve)
      key.generate_key
      key
    when 'rsa'
      key = OpenSSL::PKey::RSA.new(client_curve.to_i)  # really, strength in bits
      key
    end
  end

  def gen_domain_pkey
    case algo
    when 'ecdsa'
      key = OpenSSL::PKey::EC.new(domain_curve)
      key.generate_key
      key
    when 'rsa'
      # really, strength in bits
      key = OpenSSL::PKey::RSA.new(domain_curve.to_i)
      key
    end
  end

  def sign_end_certificate(certname, privkeyfile, pubkeyfile, dnstr)
    dnobj = OpenSSL::X509::Name.parse dnstr

    sign_certificate(certname, nil, privkeyfile,
                     pubkeyfile, dnobj, 2*365*24*60*60) { |cert,ef|
      cert.add_extension(ef.create_extension("basicConstraints","CA:FALSE",true))
      cert.add_extension(ef.create_extension("authorityKeyIdentifier","issuer",false))
    }
  end

  def sign_pubkey(issuer, dnobj, pubkey, duration=(2*365*24*60*60), efblock = nil)
    # note, root CA's are "self-signed", so pass dnobj.
    issuer ||= cacert.subject

    ncert  = OpenSSL::X509::Certificate.new
    # cf. RFC 5280 - to make it a "v3" certificate
    ncert.version = 2
    ncert.serial  = SystemVariable.randomseq(:serialnumber)
    ncert.subject = dnobj

    ncert.issuer = issuer
    ncert.public_key = pubkey
    ncert.not_before = Time.now

    # 2 years validity
    ncert.not_after = ncert.not_before + duration

    # Extension Factory
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = ncert
    ef.issuer_certificate  = ncert

    if efblock
      efblock.call(ncert, ef)
    end
    ncert.sign(ca_signing_key, OpenSSL::Digest::SHA256.new)
  end

  def generate_domain_privkey_if_needed(privkeyfile, curve, certname)
    if File.exist?(privkeyfile)
      puts "#{certname} using existing key at: #{privkeyfile}"
      OpenSSL::PKey.read(File.open(privkeyfile))
    else
      # the CA's public/private key - 3*1024 + 8
      key = gen_domain_pkey
      File.open(privkeyfile, "w", 0600) do |f| f.write key.to_pem end
      key
    end
  end

  def generate_privkey_if_needed(privkeyfile, curve = nil, certname)
    if File.exist?(privkeyfile)
      puts "#{certname} using existing key at: #{privkeyfile}"
      OpenSSL::PKey.read(File.open(privkeyfile))
    else
      # the CA's public/private key - 3*1024 + 8
      key = gen_client_pkey
      File.open(privkeyfile, "w", 0600) do |f| f.write key.to_pem end
      key
    end
  end

  def sign_certificate(certname, issuer, privkeyfile, pubkeyfile, dnobj, duration=(2*365*24*60*60), &efblock)
    FileUtils.mkpath(certdir)

    key = generate_privkey_if_needed(privkeyfile, client_curve, certname)
    ncert = sign_pubkey(issuer, dnobj, key, duration, efblock)

    File.open(pubkeyfile,'w') do |f|
      f.write ncert.to_pem
    end
    ncert
  end

  protected
  def load_root_priv_key
    File.open(root_priv_key_file) do |f|
      OpenSSL::PKey.read(f)
    end
  end

  def load_root_pub_key
    File.open(vendor_pubkey,'r') do |f|
      OpenSSL::X509::Certificate.new(f)
    end
  end


end
