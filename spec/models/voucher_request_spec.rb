require 'rails_helper'

RSpec.describe VoucherRequest, type: :model do
  fixtures :all

  before(:each) do
    HighwayKeys.ca.certdir = Rails.root.join('spec','files','cert')
    MasaKeys.masa.certdir  = Rails.root.join('spec','files','cert')
  end

  describe "relations" do
    it { should belong_to(:voucher) }
    it { should belong_to(:owner) }
    it { should belong_to(:device) }
  end

  describe "details" do
    it "should save detail objects" do
      vr1 = CmsVoucherRequest.new
      vr1.details['hello'] = "there"
      vr1.save!
      id = vr1.id

      vr2=CmsVoucherRequest.find(id)
      expect(vr2.details['hello']).to eq("there")
    end
  end

  describe "voucher input request" do
    it "should read a voucher request from disk" do
      token = Base64.decode64(IO::read("spec/files/parboiled_vr-00-D0-E5-F2-00-02.b64"))
      vr2 = CmsVoucherRequest.from_pkcs7(token)
      expect(vr2.device_identifier).to eq("00-D0-E5-F2-00-02")
      expect(vr2.nonce).to eq("Dss99sBr3pNMOACe-LYY7w")
      expect(vr2.owner).to_not be_nil

      voucher,reason = vr2.issue_voucher('2017-09-15'.to_date)
      expect(voucher).to_not be_nil
      expect(voucher.nonce).to eq(vr2.nonce)
      expect(voucher.device_identifier).to eq(vr2.device_identifier)
      expect(voucher.as_issued).to_not be_nil

      # save it for examination elsewhere (and use by Registrar tests)
      expect(Chariwt.cmp_pkcs_file(voucher.as_issued, "voucher_#{voucher.device_identifier}")).to be true
    end

    it "should not duplicate a byte4byte identical request" do
      token = Base64.decode64(IO::read("spec/files/parboiled_vr-00-D0-E5-F2-00-02.b64"))
      vr2 = CmsVoucherRequest.from_pkcs7(token)
      expect(vr2.id).to_not be_nil

      tok2 = Base64.decode64(IO::read("spec/files/parboiled_vr-00-D0-E5-F2-00-02.b64"))
      vr3 = CmsVoucherRequest.from_pkcs7(token)
      expect(vr3.id).to eq(vr2.id)
      expect(vr3.device).to eq(devices(:vizsla))
    end

    it "should process a voucher request into a voucher for a valid device" do
      req13 = voucher_requests(:voucher13)
      voucher,reason = req13.issue_voucher
      expect(reason).to eq(:ok)
      expect(voucher).to_not be_nil
      expect(voucher.nonce).to   eq(req13.nonce)
      expect(voucher.device).to  eq(req13.device)
      expect(voucher.owner).to   eq(req13.owner)
    end

    it "should process a repeated voucher request into a new voucher with a different certificate" do
      vr67 = voucher_requests(:vr67)
      voucher,reason = vr67.issue_voucher
      expect(reason).to eq(:ok)
      expect(voucher).to_not be_nil
      expect(voucher.nonce).to   eq(vr67.nonce)
      expect(voucher.device).to  eq(vr67.device)
      expect(voucher.owner).to   eq(vr67.owner)

      cv = Chariwt::Voucher.from_pkcs7(voucher.as_issued, MasaKeys.masa.masakey)
      expect(cv.pinnedDomainCert).to eq(vr67.prior_voucher_request.proximityRegistrarCert)
    end

    it "should process a parboiled voucher request from a file, raising error, because certificate is missing" do
      token = Base64.decode64(IO::read("spec/files/parboiled_vr-00-D0-E5-F2-00-01.pkcs"))
      expect {
        vr1 = CmsVoucherRequest.from_pkcs7(token)
      }.to raise_exception(VoucherRequest::MissingPublicKey)
    end

    it "should validate a voucher request" do
      req14 = voucher_requests(:voucher14)
      expect(req14.prior_voucher_request).to_not be_nil
      expect(req14.prior_voucher_request.proximityRegistrarCert).to_not be_nil
      owner = req14.lookup_owner
      expect(owner).to eq(owners(:owner4))
      expect(owner.pubkey).to eq(req14.signing_key)
    end

    # validate that the parsing routines
    it "should process a CMS voucher request content with unsigned pledge" do

      token = File.read("spec/files/parboiled_00-D0-E5-F2-00-03.txt")
      json0 = JSON.parse(token)
      json1 = json0['ietf-voucher-request:voucher']
      cvr = Chariwt::VoucherRequest.object_from_verified_json(json1, nil)

      uvr = CmsVoucherRequest.from_json(cvr.inner_attributes, nil)
      v = uvr.issue_voucher
      expect(v).to_not be_nil
    end

    it "should validate a voucher request, with unsigned prior" do
      req15 = voucher_requests(:voucher15)
      pending "lack of prior-signed-voucher request not yet working"
      expect(req15.prior_voucher_request).to_not be_nil
      expect(req15.prior_voucher_request.proximityRegistrarCert).to_not be_nil
      owner = req15.lookup_owner
      expect(owner).to eq(owners(:owner9))
      expect(owner.pubkey).to eq(req15.signing_key)
    end

    it "should load a constrained voucher request into database" do
      token  = open("spec/files/parboiled_vr_00-D0-E5-F2-00-02.vrq")
      regfile= File.join("spec","files", "jrc_prime256v1.crt")
      pubkey = OpenSSL::X509::Certificate.new(IO::read(regfile))

      vch = CoseVoucherRequest.from_cbor_cose_io(token, pubkey)
      expect(vch).to                       be_proximity
      expect(vch.owner).to                 be_present
      expect(vch.device_identifier).to_not be_nil
      expect(vch.device).to                be_present

      # now see if the looked up owner has a public key to validate the prior
      # signed voucher key.
      expect(vch.validate_prior!).to be_truthy

      voucher,reason = vch.issue_voucher
      expect(reason).to be :ok
      expect(voucher).to_not be_nil
    end

    it "should read a voucher request captured from Siemens JRC" do
      # will need to populate with Device from Florean
      token = IO::read("spec/files/product/00-D0-E5-03-00-03/vr92-from-siemens-jrc.pkcs")
      vr92 = CmsVoucherRequest.from_pkcs7(token)
      expect(vr92).to_not be_nil
    end

  end

end
