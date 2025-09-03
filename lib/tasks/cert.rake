# -*- ruby -*-

namespace :highway do

  def privkeyhandle
    vendorprivkeyfile = HighwayKeys.ca.certdir.join("vendor_#{curve}.key")
  end

  desc "Create initial self-signed CA certificate, or resign existing one"
  task :h1_bootstrap_ca => :environment do

    curve = HighwayKeys.ca.domain_curve
    vendorprivkeyfile = Highway.ca.root_priv_key_file
    outfile       = HighwayKeys.ca.certdir.join("vendor_#{curve}.crt")
    dnprefix = SystemVariable.string(:dnprefix) || "/DC=ca/DC=sandelman"
    dn = sprintf("%s/CN=%s CA", dnprefix, SystemVariable.string(:hostname))
    puts "issuer is now: #{dn}"
    dnobj = OpenSSL::X509::Name.parse dn

    if !File.exist?(outfile) or ENV['RESIGN']

      duration = ENV['DURATION'].try(:to_i) || (2*365*24*60*60)

      puts "Signing with duration of #{duration} seconds"

      outfile = HighwayKeys.ca.sign_ca_key(vendorprivkeyfile, curve, dnobj, duration)
      puts "CA Certificate writtten to: #{outfile}"
    end
  end

  desc "Create a certificate for the MASA to sign vouchers with"
  task :h2_bootstrap_masa => :environment do

    curve = MasaKeys.ca.curve
    certdir = MasaKeys.ca.certdir
    masaprivkeyfile= certdir.join("masa_#{curve}.key")
    outfile        = certdir.join("masa_#{curve}.crt")
    dnprefix = SystemVariable.string(:dnprefix) || "/DC=ca/DC=sandelman"
    dn = sprintf("%s/CN=%s MASA", dnprefix, SystemVariable.string(:hostname))

    if !File.exist?(outfile) or ENV['RESIGN']
      HighwayKeys.ca.sign_end_certificate("MASA",
                                          masaprivkeyfile,
                                          outfile, dn)
      puts "MASA voucher signing certificate writtten to: #{outfile}"
    end
  end

  desc "Create a certificate for the MASA to sign MUD objects"
  task :h3_bootstrap_mud => :environment do

    curve   = MudKeys.ca.curve
    certdir = HighwayKeys.ca.certdir
    mudprivkeyfile = certdir.join("mud_#{curve}.key")
    outfile=certdir.join("mud_#{curve}.crt")
    dnprefix = SystemVariable.string(:dnprefix) || "/DC=ca/DC=sandelman"
    dn = sprintf("%s/CN=%s MUD", dnprefix, SystemVariable.string(:hostname))

    if !File.exist?(outfile) or ENV['RESIGN']
      HighwayKeys.ca.sign_end_certificate("MUD",
                                          mudprivkeyfile,
                                          outfile, dn)
      puts "MUD file signing certificate writtten to: #{outfile}"
    end
  end

  desc "Create a certificate for the MASA web interface (EST) to answer requests"
  task :h4_masa_server_cert => :environment do

    curve   = HighwayKeys.ca.client_curve
    certdir = HighwayKeys.ca.certdir
    serverprivkeyfile = certdir.join("server_#{curve}.key")
    outfile=certdir.join("server_#{curve}.crt")
    dnprefix = SystemVariable.string(:dnprefix) || "/DC=ca/DC=sandelman"
    dn = sprintf("%s/CN=%s", dnprefix, SystemVariable.string(:hostname))
    dnobj = OpenSSL::X509::Name.parse dn

    if !File.exist?(outfile) or ENV['RESIGN']
      mud_cert = HighwayKeys.ca.sign_certificate("SERVER", nil,
                                                 serverprivkeyfile,
                                                 outfile, dnobj) { |cert,ef|
        cert.add_extension(ef.create_extension("basicConstraints","CA:FALSE",true))
      }
      puts "MASA SERVER certificate writtten to: #{outfile}"
    end
  end

  desc "Create a certificate signing request for the MASA web interface (EST) to answer requests"
  task :h4_masa_server_csr => :environment do

    curve   = HighwayKeys.ca.client_curve
    certdir = HighwayKeys.ca.certdir
    serverprivkeyfile = certdir.join("server_#{curve}.key")
    csrfile=certdir.join("server_#{curve}.crt")

    dnprefix = SystemVariable.string(:dnprefix) || "/DC=ca/DC=sandelman"
    dn = sprintf("%s/CN=%s", dnprefix, SystemVariable.string(:hostname))
    dnobj = OpenSSL::X509::Name.parse dn

    if !File.exist?(outfile) or ENV['RESIGN']
      mud_cert = HighwayKeys.ca.sign_certificate("SERVER", nil,
                                                 serverprivkeyfile,
                                                 outfile, dnobj) { |cert,ef|
        cert.add_extension(ef.create_extension("basicConstraints","CA:FALSE",true))
      }
      puts "MASA SERVER certificate writtten to: #{outfile}"
    end
  end

  desc "Create a suborbinate CA for signing SmartPledge IDevID devices"
  task :h5_idevid_ca => :environment do

    curve             = IDevIDKeys.ca.client_curve
    dnprefix          = SystemVariable.string(:dnprefix) || "/DC=ca/DC=sandelman"
    dn = sprintf("%s/CN=%s IDevID CA", dnprefix, SystemVariable.string(:hostname))
    puts "issuer is now: #{dn}"
    dnobj = OpenSSL::X509::Name.parse dn
    outfile=IDevIDKeys.ca.idevid_pub_keyfile

    if !File.exist?(outfile) or ENV['RESIGN']
      HighwayKeys.ca.sign_certificate("IDevID", nil,
                                      IDevIDKeys.ca.idevid_priv_keyfile,
                                      IDevIDKeys.ca.idevid_pub_keyfile,
                                      dnobj) { |cert, ef|
        cert.add_extension(ef.create_extension("basicConstraints","CA:TRUE",true))
        cert.add_extension(ef.create_extension("keyUsage","keyCertSign, cRLSign", true))
        cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
        cert.add_extension(ef.create_extension("authorityKeyIdentifier","keyid:always",false))
      }
      puts "IDevID Certificate writtten to: #{outfile}"
    end
  end

  desc "Sign a IDevID certificate for a new device, EUI64=xx"
  task :signmic => :environment do

    eui64 = ENV['EUI64']

    unless eui64
      puts "must set EUI64= to a valid MAC address"
      exit
    end

    dev = Device.create_by_number(eui64)
    dev.gen_and_store_key
  end

  desc "Create an IDevID certificate based upon a Certificate Signing Request (CSR=). Output to CERT="
  task :signcsr => :environment do

    input = ENV['CSR']
    output= ENV['CERT']

    dev = Device.create_from_csr_io(File.read(input))
    File.open(output, "w") do |f| f.write dev.certificate.to_pem; end
  end

  desc "Sign voucher for device EUI64= to OWNER_ID=xx, with optional NONCE=xx, EXPIRES=yy"
  task :signvoucher => :environment do
    eui64 = ENV['EUI64']
    ownerid = ENV['OWNER_ID']
    nonce = ENV['NONCE']
    expires=ENV['EXPIRES'].try(:to_date)

    unless eui64
      puts "must set EUI64= to a valid MAC address"
      exit
    end

    device = Device.find_by_number(eui64)
    unless device
      puts "no device found with EUI64=#{eui64}"
      exit
    end

    unless ownerid
      puts "must set OWNER_ID= to a valid database ID"
      exit
    end
    owner = Owner.find(ownerid)

    voucher = Voucher.create_voucher(owner, device, Time.now, nonce, expires)

    puts "Voucher created and saved, #{voucher.id}, and fixture written to tmp"
    fw = FixtureWriter.new('tmp')
    voucher.savefixturefw(fw)
    fw.closefiles
  end

  desc "Create self-signed EE certificate"
  task :h0_self_signed_ee => :environment do

    curve = HighwayKeys.ca.domain_curve
    selfsignedprivkeyfile = HighwayKeys.ca.certdir.join("selfsigned_#{curve}.key")
    outfile       = HighwayKeys.ca.certdir.join("selfsigned_#{curve}.crt")
    dnprefix = SystemVariable.string(:dnprefix) || "/DC=ca/DC=sandelman"
    dn = "/CN=selfsigned"
    if ENV['NAME']
      dn = sprintf("/CN=%s CA", ENV['NAME'])
    end
    dnobj = OpenSSL::X509::Name.parse dn

    if !File.exist?(outfile) or ENV['RESIGN']

      duration = ENV['DURATION'].try(:to_i) || (2*365*24*60*60)

      puts "Signing with duration of #{duration} seconds"

      # generate the privkey directly, since we want the domain privkey
      HighwayKeys.ca.generate_domain_privkey_if_needed(selfsignedprivkeyfile, curve, dnobj)

      HighwayKeys.ca.sign_certificate("EE", dnobj,
                                      selfsignedprivkeyfile,
                                      outfile, dnobj, duration) { |cert, ef|
        cert.add_extension(ef.create_extension("basicConstraints","CA:FALSE",true))
        cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
        cert.add_extension(ef.create_extension("authorityKeyIdentifier","keyid:always",false))
      }
      puts "self-signed EE Certificate writtten to: #{outfile}"
    end
  end

  desc "Create Certificate Signing Request with appropriate MASA OID URL"
  task :h6_device_csr => :environment do

    serialnumber = ENV['SN']
    if serialnumber.blank?
      serialnumber = Device.build_inventory_serialnumber
    end

    inv_dir = SystemVariable.setup_sane_inventory
    tdir = HighwayKeys.ca.devicedir

    device = Device.find_obsolete_by_eui64(serialnumber)
    unless device
      device = Device.create_by_number(serialnumber)
    end
    device.serial_number = serialnumber
    device.gen_or_load_priv_key(tdir)
    device.activated!
    device.save!
    file = device.write_csr(tdir)
    puts "Writing CSR for #{serialnumber} to #{file}"
  end


end
