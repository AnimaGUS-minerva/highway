require 'rails_helper'

RSpec.describe Device, type: :model do
  fixtures :all

  before(:each) do
    HighwayKeys.ca.certdir = Rails.root.join('spec','files','cert')
    MasaKeys.masa.certdir  = Rails.root.join('spec','files','cert')
    SystemVariable.setnumber(:dns_update_attempt, 0)
    SystemVariable.setnumber(:dns_update_success, 0)
  end

  describe "canonical eui" do
    it "should turn colons into dashes" do
      expect(Device.canonicalize_eui64("aa:bb:cc:dd:ee:ff")).to eq("aa-bb-cc-dd-ee-ff")
    end

    it "should handle 6 byte eui" do
      expect(Device.canonicalize_eui64("aa-bb-cc-dd-ee-ff")).to eq("aa-bb-cc-dd-ee-ff")
    end

    it "should handle 7 byte eui" do
      expect(Device.canonicalize_eui64("00-11-aa-bb-cc-dd-ee-ff")).to eq("00-11-aa-bb-cc-dd-ee-ff")
    end

    it "should downcase hex digits" do
      expect(Device.canonicalize_eui64("AA-Bb-cc-dD-eE-ff")).to eq("aa-bb-cc-dd-ee-ff")
    end

    it "should insert dashes if missing" do
      expect(Device.canonicalize_eui64("aabbccddeeff")).to eq("aa-bb-cc-dd-ee-ff")
    end

  end

  describe "relations" do
    it "should have many vouchers" do
      almec = devices(:almec)
      expect(almec.vouchers.count).to be >= 0
    end
    it "should belong to an owner" do
      expect(devices(:device11).owner).to_not be_nil
    end
  end

  describe "key generation" do
    it "should generate a new public/private key pair, and sign it" do
      almec = devices(:almec)

      tmp_device_dir {
        almec.gen_and_store_key
        expect(almec.idevid_cert).to_not be_nil

        file = File.join(HighwayKeys.ca.devicedir, "#{almec.sanitized_eui64}/device.crt")
        expect(File.exists?(file)).to be true

        cert = OpenSSL::X509::Certificate.new(IO::read(file))
        expect(cert.subject.to_s).to include("/serialNumber=JADA_f2-00-01")
      }
      # expect almec public key to verify with root key
    end

    it "should generate a new private key, and store it" do
      almec = devices(:almec)

      tmp_device_dir {
        almec.gen_or_load_priv_key(HighwayKeys.ca.devicedir, 'prime256v1', false)
      }

      expect(almec.dev_key).to_not be_nil

      # weirdly, PKey::EC is not actually subclass of PKey.
      # expect(almec.public_key).to be_kind_of(OpenSSL::PKey)
      expect(almec.public_key).to be_kind_of(OpenSSL::PKey::EC)
    end

    it "should preserve public key in pub_key field" do
      almec = devices(:almec)
      tmp_device_dir(true) {
        almec.gen_or_load_priv_key(HighwayKeys.ca.devicedir, 'prime256v1', false)
      }
      expect(almec.dev_key).to_not be_nil

      gen_pubkey = almec.public_key

      # get fresh copy
      almec = Device.find(almec.id)
      # use to_pem to get deep comparison of contents
      expect(almec.public_key.to_pem).to eq(gen_pubkey.to_pem)
    end

    it "should recognize a voucher request containing the same public key" do
      vr11 = voucher_requests(:voucherreq54)
      d11 = vr11.device
      expect(d11).to eq(devices(:device11))
      expect(d11.signing_key?(vr11.signing_public_key)).to be_truthy
    end

    it "should recognize a voucher request containing the wrong public key" do
      vr11 = voucher_requests(:voucher14)
      d11 = vr11.device
      expect(d11).to eq(devices(:device11))
      expect(d11.signing_key?(vr11.signing_public_key)).to be_falsey
    end
  end

  describe "certificate signing request" do
    it "should accept a CSR in a file, generating an IDevID" do
      input = Rails.root.join("spec", "files", "csr", "sample1.csr")
      csr = OpenSSL::X509::Request.new(File.read(input))

      expect(csr.subject.to_s).to eq("/CN=www.iotrus.com/O=IOT-R-US, Inc./C=US/ST=NC/L=RTP/serialNumber=IOTRUS-0123456789")

      dev = Device.create_from_csr(csr)
      expect(dev).to be_present
      expect(dev.serial_number).to     eq("IOTRUS-0123456789")
      expect(dev.idevid_cert).to_not   be_nil
      expect(dev.certificate.subject.to_s).to eq("/serialNumber=IOTRUS-0123456789")
    end

    it "should accept CSR for an existing device" do
      $INTERNAL_CA_SHG_DEVICE=true
      $LETSENCRYPT_CA_SHG_DEVICE=false
      dev = devices(:heranew)
      expect(dev.certificate).to be_nil

      # grab the CSR from the hera machine, and extract the CSR and use it.
      provision1 = IO::read("spec/files/hera.provision.json")
      atts = JSON::parse(provision1)

      dev.sign_from_base64_csr(atts['csr'])
      expect(dev.certificate).to_not be_nil
    end

    it "should accept a CSR for an existing device, sign it with LetsEncrypt staging" do
      SystemVariable.setbool!(:dns_update_debug, true)
      SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
      dev = devices(:heranew)
      expect(dev.certificate).to be_nil

      # grab the CSR from the hera machine, but extract the CSR, use it.
      provision1 = IO::read("spec/files/hera.provision.json")
      atts = JSON::parse(provision1)
      if ENV['ACME_TESTING'] and AcmeKeys.acme.server
        $INTERNAL_CA_SHG_DEVICE=false
        $LETSENCRYPT_CA_SHG_DEVICE=true
        dev.update_from_smarkaklink_provision(atts)
        dev.sign_from_base64_csr(atts['csr'])

        expect(dev.certificate).to_not be_nil
      end
    end

    def devAB1D_setup
      dev = Device.new
      mac = dev.eui64 = "3c-97-1e-9b-ab-1d"
      dev.serial_number = "3c-97-1e-9b-ab-1d"
      smac = dev.second_eui64  = "3c-97-1e-9b-ab-1e"
      expect(dev.certificate).to be_nil

      # grab the CSR that was generated, and then run it first time to generate
      # some data
      csrio = IO::read("spec/files/product/3C-97-1E-9B-AB-1D/request.csr")
      csr = OpenSSL::X509::Request.new(csrio)
      atts = Hash.new
      atts["csr"] = Base64.encode64(csrio)
      atts["wan-mac"]= mac
      atts["switch-mac"] = smac
      atts["ula"]    = "fd9e:7354:b359::/48"
      dev.update_from_smarkaklink_provision(atts)

      return atts, dev, csr
    end

    it "should examine a device with the CSR, noting that certificate is good" do
      SystemVariable.setbool!(:dns_update_debug, true)
      SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
      $INTERNAL_CA_SHG_DEVICE=true
      $LETSENCRYPT_CA_SHG_DEVICE=false

      atts,dev,csr = devAB1D_setup

      # sign it once
      dev.sign_from_base64_csr(atts['csr'])
      expect(dev.certificate_already_satisfies_csr(csr)).to be_truthy
    end

    it "should examine a device with the CSR, needs new certificate if public key differs" do
      SystemVariable.setbool!(:dns_update_debug, true)
      SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
      $INTERNAL_CA_SHG_DEVICE=true
      $LETSENCRYPT_CA_SHG_DEVICE=false

      atts,dev,csr0 = devAB1D_setup

      # sign it once
      dev.sign_from_base64_csr(atts['csr'])

      csrbin = IO::read("spec/files/hera.csr")
      csr    = OpenSSL::X509::Request.new(csrbin)

      # but keep the DN the same
      csr.subject = csr0.subject

      expect(dev.certificate_already_satisfies_csr(csr)).to be_falsey
    end

    it "should examine a device with the CSR, needs new certificate if subject differs" do
      SystemVariable.setbool!(:dns_update_debug, true)
      SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
      $INTERNAL_CA_SHG_DEVICE=true
      $LETSENCRYPT_CA_SHG_DEVICE=false

      atts,dev,csr0 = devAB1D_setup

      # sign it once
      dev.sign_from_base64_csr(atts['csr'])
      csrbin = IO::read("spec/files/hera.csr")
      csr    = OpenSSL::X509::Request.new(csrbin)

      # but keep the public_key the same, change the subject
      csr0.subject = csr.subject

      expect(dev.certificate_already_satisfies_csr(csr0)).to be_falsey
    end

    it "should examine a device with the CSR, needs new certificate if old one is expired" do
      SystemVariable.setbool!(:dns_update_debug, true)
      SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
      $INTERNAL_CA_SHG_DEVICE=true
      $LETSENCRYPT_CA_SHG_DEVICE=false

      f46 = devices(:device_F46_expired)

      # grab the CSR that was generated, and then run it first time to generate
      # some data
      csrio = IO::read("spec/files/product/3C-97-1E-9B-AB-46/request.csr")
      csr = OpenSSL::X509::Request.new(csrio)

      # it is already signed
      # it should not satisfy the result because the certificate is expired
      expect(f46.certificate_already_satisfies_csr(csr)).to be_falsey
    end

    # this fixture is used for smarkaklink testing, and represents an owned key pair
    # items are in spec/files/product/3C-97-1E-9B-AB-1D
    # a created certificate request in spec/files/product/3C-97-1E-9B-AB-1D/device.csr
    # was created with: spec/files/product/3C-97-1E-9B-AB-1D/generate.sh
    it "should accept a CSR for an existing device, that has an old certificate, and still sign it with LetsEncrypt staging" do
      SystemVariable.setbool!(:dns_update_debug, true)
      SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")

      atts,dev = devAB1D_setup

      if ENV['ACME_TESTING'] and AcmeKeys.acme.server
        $INTERNAL_CA_SHG_DEVICE=false
        $LETSENCRYPT_CA_SHG_DEVICE=true

        expect {
          dev.sign_from_base64_csr(atts['csr'])
          expect(dev.certificate).to_not be_nil
        }.to change{AcmeKeys.attempt_count}.by(1).and change{AcmeKeys.success_count}.by(1)
        cert1 = dev.certificate

        expect {
          dev.sign_from_base64_csr(atts['csr'])
          expect(dev.certificate).to_not be_nil
        }.to change{AcmeKeys.attempt_count}.by(0).and change{AcmeKeys.success_count}.by(0)

        # expect that the certificate will not change since nothing else did
        expect(dev.certificate).to eq(cert1)

      end
    end
  end

  describe "provisioning" do
    it "should generate a directory from the device id" do
      expect(devices(:zeb).tgz_filename).to eq(Rails.root.join('tmp','shg','dev_16.tgz').to_s)
    end

    it "should generate a tgz file with new certificate" do
      zeb = devices(:zeb)
      filename = zeb.generate_tgz_for_shg
      expect(File.exist?(filename)).to be true
      files = IO::popen("tar tzf #{filename}").readlines
      expect(files).to include("./etc/shg/idevid_cert.pem\n")
    end
  end

  describe "certificate creation" do
    it "should create a certificate with a new issue " do
      almec = devices(:almec)

      dd = mk_empty_dir
      almec.gen_or_load_priv_key(dd)
      almec.sign_eui64
      expect(almec.idevid.serial).to be > 1
      almec.save!
      expect(almec.pub_key).to_not be_nil

      vizsla = devices(:vizsla)

      vizsla.gen_or_load_priv_key(dd)
      vizsla.sign_eui64
      expect(vizsla.idevid.serial).to_not eq(almec.idevid.serial)

      keyUsage = false
      eku      = false
      vizsla.idevid.extensions.each { |ext|
        case ext.oid
        when "basicConstraints"
          expect(ext.value).to eq("CA:FALSE")
        when "keyUsage"
          keyUsage=(ext.value == "Digital Signature")

        when "extendedKeyUsage"
          eku=(ext.value == "TLS Web Client Authentication")
        end
      }
      expect(vizsla.store_certificate).to be_truthy
      expect(eku).to      be false
      expect(keyUsage).to be false
    end

    it "should create a certificate with an interesting MASA url" do
      SystemVariable.setvalue(:masa_iauthority, "masa.example.com:1234")

      ndev = Device.new
      ndev.eui64 = '00-16-3e-ff-fe-d0-55-aa'
      tmp_device_dir {
        ndev.gen_and_store_key
        expect(system("openssl x509 -noout -text -in #{ndev.certificate_filename} | grep masa.example.com:1234 >/dev/null")).to be true
      }
    end
  end

  describe "eui64 strings" do
    it "should sanitize non-hex out of eui64" do
      t1 = Device.new(eui64: '../;bobby/11-22-44-55-22-55-88-22/')
      expect(t1.sanitized_eui64).to eq("BBB11-22-44-55-22-55-88-22")
    end
  end

  describe "audit log" do
    it "should have three vouchers" do
      d14 = devices(:device14)
      expect(d14.vouchers.count).to eq(3)
    end

    it "should have three owners via three vouchers" do
      d14 = devices(:device14)
      expect(d14.owners.count).to eq(3)
      expect(d14.owners[0]).to eq owners(:owner4)
      expect(d14.owners[1]).to eq owners(:owner2)
      expect(d14.owners[2]).to eq owners(:owner1)
    end

    it "should produce a hash representing the audit log for a device" do
      d14 = devices(:device14)

      log = d14.audit_log
      expect(log['version']).to eq('1')
      expect(log['events'].count).to eq(3)
      expect(log['events'][0]['registrarID']).to eq(owners(:owner4).registrarID_base64)
      expect(log['events'][1]['registrarID']).to eq(owners(:owner2).registrarID_base64)

    end
  end

  describe "searching" do
    it "should find a device by eui64 or serialnumber" do
      b1 = Device.find_by_number('00-D0-E5-F2-00-02')
      expect(b1).to_not be_nil
    end

    it "should find a device by colon-eui64" do
      b1 = Device.find_by_number('00:D0:E5:F2:00:02')
      expect(b1).to_not be_nil
    end

    it "should find a device by lower-case colon-eui64" do
      b1 = Device.find_by_number('00:d0:e5:f2:00:02')
      expect(b1).to_not be_nil
    end

    it "should ignore obsolete devices when looking for unowned" do
      expect(Device.active.unowned.count).to be >= 3
      expect(Device.active.owned.count).to   be >= 3
      expect(Device.obsolete.count).to eq(1)
    end

    it "should list devices" do
      expect(Device.list_dev(open("/dev/null","w"))).to_not be_nil
    end


  end

  describe "signed voucher requests" do
    it "should load a constrained prior-signed (pledge) voucher request, and validate it" do
      token  = open("spec/files/vr_00-D0-E5-F2-00-02.vrq")

      pvch = Chariwt::VoucherRequest.from_cose_withoutkey_io(token)

      # validate that the registry was nearby
      ownercert = pvch.attributes["proximity-registrar-cert"]
      expect(ownercert).to_not be_nil
      owner = Owner.find_by_encoded_public_key(ownercert)
      expect(owner).to                 be_present

      # validate that the voucher was signed by a device
      serialnumber = pvch.attributes["serial-number"]
      expect(serialnumber).to_not be_nil

      device = Device.find_by_number(serialnumber)
      expect(device).to                be_present

      expect(pvch.verify_with_key(device.certificate)).to be_truthy
    end
  end

  describe "processing bags of certificates" do
    it "should permit multiple certificates" do
      zeb = devices(:zeb)
      cert_bag = IO::read("spec/files/bag_of_LE_certificates.pem")

      certs = zeb.split_up_bag_of_certificates(cert_bag)
      expect(certs[0]).to be_kind_of OpenSSL::X509::Certificate
      expect(certs[1]).to be_kind_of OpenSSL::X509::Certificate
    end
  end

  describe "secure home gateway encoding" do
    it "should default essid and fqdn from ULA" do
      zeb = devices(:zeb)

      zeb.extrapolate_from_ula

      zeb.reload
      expect(zeb.essid).to eq("SHG3CE618")
      expect(zeb.fqdn).to  eq("n3ce618.r.securehomegateway.ca")
    end

    it "should create a new host" do
      zeb = devices(:zeb)
      expect(zeb.ulanet.host_address(1).to_s).to eq("fd3c:e618:51e2::1")
    end

    # this will only work if AcmeKeys is setup.
    it "should update a ULA ::1" do
      pending "needs AcmeKeys setup" unless ENV['ACME_TESTING']
      SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
      zeb = devices(:zeb)
      expect(zeb.insert_ula_quad_ah).to_not be_nil
    end

    # this will only work if AcmeKeys is setup.
    it "should update device with a ULA ::1 and an IPv4" do
      pending "needs AcmeKeys setup" unless ENV['ACME_TESTING']
      SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
      zeb = devices(:zeb)
      zeb.rfc1918 = '192.168.1.1'
      expect(zeb.insert_ula_quad_ah).to_not be_nil
      resolver = Resolv::DNS.new
      (hostname,addr) = zeb.router_name_ip
      zebnames = resolver.getaddresses(hostname)
      zebnames.each {|name|
        case name
        when Resolv::IPv4
          expect(name.to_s.downcase).to eq("192.168.1.1")
        when Resolv::IPv6
          expect(name.to_s.downcase).to eq(addr.downcase)
        end
      }
    end

    it "should enroll a device from a base64 CSR" do
      SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
      b64="MIICLzCCAdYCAQAwJjEkMCIGA1UEAwwbbjQ5NDMzOS5yLmRhc2JsaW5rZW5sZWQub3JnMIIBSzCCAQMGByqGSM49AgEwgfcCAQEwLAYHKoZIzj0BAQIhAP////8AAAABAAAAAAAAAAAAAAAA////////////////MFsEIP////8AAAABAAAAAAAAAAAAAAAA///////////////8BCBaxjXYqjqT57PrvVV2mIa8ZR0GsMxTsPY7zjw+J9JgSwMVAMSdNgiG5wSTamZ44ROdJreBn36QBEEEaxfR8uEsQkf4vOblY6RA8ncDfYEt6zOg9KE5RdiYwpZP40Li/hp/m47n60p8D54WK84zV2sxXs7LtkBoN79R9QIhAP////8AAAAA//////////+85vqtpxeehPO5ysL8YyVRAgEBA0IABJSG0GnnubH/K65/07zNDCmau+ijV44TMktmJRPRzTTJUC7b6Jl/lVhzpnk/yG70Sqm9q2bT+TMAxzz/nQdkCRugWjBYBgkqhkiG9w0BCQ4xSzBJMEcGA1UdEQRAMD6CG240OTQzMzkuci5kYXNibGlua2VubGVkLm9yZ4IfbXVkLm40OTQzMzkuci5kYXNibGlua2VubGVkLm9yZzAKBggqhkjOPQQDAgNHADBEAiA8RNx349S003zUYo0IgfWLr0ZioTD8Z46X3VMepf6TDgIgXEOSyNHcNcGtMmCZz6N0rGKk70e6j2NarQ7TgvrwHzU="
      zeb=devices(:zeb)
      zeb.sign_from_base64_csr(b64)
    end
  end

  describe "generate SQRL code from particulars" do
    it "should generate an SQRL string" do
      zeb = devices(:zeb)

      expect(zeb.sqrl_string.unpack("H*").first).to eq("5b293e1e30361d31324e42303030686967687761792d746573742e6578616d706c652e636f6d1f4230303150726f647563741f423030324d6f64656c1f5530383768747470733a2f2f686967687761792d746573742e6578616d706c652e636f6d2f6d75642f50726f647563742f4d6f64656c2f6d75642e6a736f6e1f1e04")
    end

    it "should have a default Company Name" do
      expect(devices(:zeb).product_name).to eq("Product")
    end
    it "should have a default Model Name" do
      expect(devices(:zeb).model_name).to eq("Model")
    end
  end


end
