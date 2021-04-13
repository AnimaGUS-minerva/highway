# spec/requests/todos_spec.rb
require 'rails_helper'
require 'support/pem_data.rb'

RSpec.describe 'SmarKaKlink MASA API', type: :request do
  fixtures :all

  before(:each) do
    FileUtils::mkdir_p("tmp")
    HighwayKeys.ca.certdir = Rails.root.join('spec','files','cert')
    MasaKeys.masa.certdir = Rails.root.join('spec','files','cert')
    IDevIDKeys.ca.certdir = Rails.root.join('spec','files','cert')
    SystemVariable.setnumber(:dns_update_attempt, 0)
    SystemVariable.setnumber(:dns_update_success, 0)
  end

  describe "smarkaklink IDevID enrollment" do
    it "POST a smartpledge voucher request, using correct content_type" do
      token = IO::read("spec/files/enroll1.json")

      post "/.well-known/brski/smarkaklink", params: token, headers: {
             'CONTENT_TYPE' => 'application/json',
             'ACCEPT'       => 'application/pkcs7',
           }

      expect(response).to have_http_status(200)
      owner=assigns(:owner)
      expect(owner).to_not be_nil

      cert = OpenSSL::X509::Certificate.new(response.body)
      expect(cert.issuer.to_s).to eq("/DC=ca/DC=sandelman/CN=highway-test.example.com IDevID CA")
      expect(cert.subject.to_s).to include(owner.simplename)
    end

    it "GET the details on a device, by public key of provisioned device" do

      n3c = devices(:shgmudhighway31)

      get "/devices", params: { :pub_key => n3c.pub_key }, headers: {
             'ACCEPT'          => 'application/json',
             'SSL_CLIENT_CERT' => smarkaklink_client_1502,
           }

      # this is currently restricted to administrators, which this request does
      # not do, unclear what the purpose was.
      expect(response).to have_http_status(401)

      if false
      expect(response).to have_http_status(200)
      device=assigns(:device)
      expect(device).to_not be_nil

      result = JSON::Parse(response.body)
      expect(result["hostname"]).to_not be_nil
      end
    end

    it "POST a smarkaklink voucher request, with an invalid content_type" do
      token = IO::read("spec/files/enroll1.json")

      post "/.well-known/brski/smarkaklink", params: token, headers: {
             'CONTENT_TYPE' => 'application/pkcs10',
             'ACCEPT'       => 'application/pkcs7',
           }

      expect(response).to have_http_status(406)
      expect(assigns(:owner)).to be_nil
    end
  end

  describe "provision of a new device" do
    it "should provision a new device when mac address already loaded" do
      $INTERNAL_CA_SHG_DEVICE=true
      $LETSENCRYPT_CA_SHG_DEVICE=false
      provision1 = IO::read("spec/files/hera.provision.json")

      post "/shg-provision", params: provision1, headers: {
             'CONTENT_TYPE' => 'application/json',
             'ACCEPT'       => 'application/tgz',
           }
      expect(response).to have_http_status(200)
      device = assigns(:device)
      expect(device).to eq(devices(:heranew))
    end

    it "should provision via LetsEncrypt, a new device when mac address already loaded" do

      if ENV['ACME_TESTING'] and AcmeKeys.acme.server
        pending "dns_update_options is not configured" unless AcmeKeys.acme.dns_update_options
        SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
        $INTERNAL_CA_SHG_DEVICE=false
        $LETSENCRYPT_CA_SHG_DEVICE=true
        provision1 = IO::read("spec/files/hera.provision.json")

        post "/shg-provision", params: provision1, headers: {
               'CONTENT_TYPE' => 'application/json',
               'ACCEPT'       => 'application/tgz',
             }
        expect(response).to have_http_status(200)
        device = assigns(:device)
        expect(device).to eq(devices(:heranew))
      end
    end

    it "should re-provision via LetsEncrypt, when ULA is different" do

      if ENV['ACME_TESTING'] and AcmeKeys.acme.server
        pending "dns_update_options is not configured" unless AcmeKeys.acme.dns_update_options
        # do the first time.
        SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
        $INTERNAL_CA_SHG_DEVICE=false
        $LETSENCRYPT_CA_SHG_DEVICE=true
        provision1 = IO::read("spec/files/hera.provision.json")

        post "/shg-provision", params: provision1, headers: {
               'CONTENT_TYPE' => 'application/json',
               'ACCEPT'       => 'application/tgz',
             }
        expect(response).to have_http_status(200)
        File.open("tmp/provision.tgz", "wb") { |f| f.write response.body }
        cert=OpenSSL::X509::Certificate.new(IO::popen("tar -x -z -O -f tmp/provision.tgz ./etc/shg/idevid_cert.pem"))
        expect(cert.subject.to_a[0][1]).to eq("n2e82a1.r.dasblinkenled.org")

        puts "waiting 30s for DNS and LetsEncrypt to settle"
        sleep(10)

        # now change the ULA (n9e7354) and see if we can get another certificate
        provision1 = IO::read("spec/files/hera.provision-new.json")
        post "/shg-provision", params: provision1, headers: {
               'CONTENT_TYPE' => 'application/json',
               'ACCEPT'       => 'application/tgz',
             }
        expect(response).to have_http_status(200)
        File.open("tmp/provision.tgz", "wb") { |f| f.write response.body }
        cert=OpenSSL::X509::Certificate.new(IO::popen("tar -x -z -O -f tmp/provision.tgz ./etc/shg/idevid_cert.pem"))
        expect(cert.subject.to_a[0][1]).to eq("n9e7354.r.dasblinkenled.org")
      end
    end

    it "should get a previously acquired certificate, if it is not too old" do

      if ENV['ACME_TESTING'] and AcmeKeys.acme.server
        pending "dns_update_options is not configured" unless AcmeKeys.acme.dns_update_options
        # do the first time.
        SystemVariable.setvalue(:shg_zone, "dasblinkenled.org")
        $INTERNAL_CA_SHG_DEVICE=false
        $LETSENCRYPT_CA_SHG_DEVICE=true
        provision1 = IO::read("spec/files/hera.provision.json")

        expect {
          post "/shg-provision", params: provision1, headers: {
                 'CONTENT_TYPE' => 'application/json',
                 'ACCEPT'       => 'application/tgz',
               }
          expect(response).to have_http_status(200)
          File.open("tmp/provision.tgz", "wb") { |f| f.write response.body }
          cert=OpenSSL::X509::Certificate.new(IO::popen("tar -x -z -O -f tmp/provision.tgz ./etc/shg/idevid_cert.pem"))
          expect(cert.subject.to_a[0][1]).to eq("n2e82a1.r.dasblinkenled.org")
        }.to change{AcmeKeys.attempt_count}.by(1).and change{AcmeKeys.success_count}.by(1)

        expect {
          post "/shg-provision", params: provision1, headers: {
                 'CONTENT_TYPE' => 'application/json',
                 'ACCEPT'       => 'application/tgz',
               }
          expect(response).to have_http_status(200)
          File.open("tmp/provision.tgz", "wb") { |f| f.write response.body }
          cert=OpenSSL::X509::Certificate.new(IO::popen("tar -x -z -O -f tmp/provision.tgz ./etc/shg/idevid_cert.pem"))
          expect(cert.subject.to_a[0][1]).to eq("n2e82a1.r.dasblinkenled.org")
        }.to change{AcmeKeys.attempt_count}.by(0).and change{AcmeKeys.success_count}.by(0)
      end

    end

    it "should refuse a device when no mac address can be found" do
      $INTERNAL_CA_SHG_DEVICE=true
      $LETSENCRYPT_CA_SHG_DEVICE=false
      $TOFU_DEVICE_REGISTER=false
      token = '{ "wan-mac" : "11-22-ba-dd-ba-dd" }'
      post "/shg-provision", params: token, headers: {
             'CONTENT_TYPE' => 'application/json',
             'ACCEPT'       => 'application/tgz',
           }
      expect(response).to have_http_status(404)
      device = assigns(:device)
      expect(device).to be_nil
    end

    it "should refuse a device, but remember it when in TOFU mode" do
      $INTERNAL_CA_SHG_DEVICE=true
      $LETSENCRYPT_CA_SHG_DEVICE=false
      $TOFU_DEVICE_REGISTER=true
      token = '{ "wan-mac" : "11-22-ba-dd-ba-dd" }'
      post "/shg-provision", params: token, headers: {
             'CONTENT_TYPE' => 'application/json',
             'ACCEPT'       => 'application/tgz',
           }
      expect(response).to have_http_status(404)
      device = assigns(:device)
      expect(device).to_not be_nil
      expect(device.second_eui64).to eq('11-22-ba-dd-ba-dd')
    end
  end

  describe "enrollment status" do
    it "should accept enrollment status about active voucher" do
      token = { "version" => 1,
                "status"  => true,
                "reason"  => "ok",
                "voucher" => Base64.urlsafe_encode64(vouchers(:voucher43).as_issued)
              }

      post "/.well-known/brski/enrollstatus", params: token.to_json, headers: {
             'CONTENT_TYPE' => 'application/json',
           }
      expect(response).to have_http_status(200)
      device = assigns(:device)
      expect(device).to_not be_nil
      expect(device.eui64).to eq('00-d0-e5-f2-00-02')
      expect(device.extra_attrs['last_status']).to eq(true)
      expect(device.extra_attrs['last_reason']).to eq("ok")
    end

    it "should reject enrollment status if no voucher included" do
      token = {"version"=>1, "status"=>true, "reason"=>"ok"}

      post "/.well-known/brski/enrollstatus", params: token.to_json, headers: {
             'CONTENT_TYPE' => 'application/json',
           }
      expect(response).to have_http_status(406)
    end
  end

end
