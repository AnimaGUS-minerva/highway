require 'rails_helper'

RSpec.describe HighwayKeys do

  def mk_empty_dir
    newdir = Rails.root.join("tmp").join("cert")
    FileUtils.remove_entry_secure(newdir) if Dir.exists?(newdir)
    FileUtils.mkdir_p(newdir)
    newdir
  end

  it "should generate and sign private end-certificate from Highway CA" do
    curve   = HighwayKeys.ca.domain_curve

    # set up to use test signing keys
    HighwayKeys.ca.certdir = Rails.root.join('spec','files','cert')
    tmpdir = mk_empty_dir

    ee_privkeyfile = tmpdir.join("cert1_#{curve}.key")
    outfile        = tmpdir.join("cert1_#{curve}.crt")

    dn = "/C=CA/CN=testingcert1"

    cert = HighwayKeys.ca.sign_end_certificate("cert1",
                                               ee_privkeyfile,
                                               outfile, dn)

    expect(cert.subject.to_s).to eq("/C=CA/CN=testingcert1")
  end

  it "should generate and sign private end-certificate from IDevID CA" do
    curve   = IDevIDKeys.ca.client_curve

    # set up to use test signing keys
    IDevIDKeys.ca.certdir = Rails.root.join('spec','files','cert')
    tmpdir = mk_empty_dir

    ee_privkeyfile = tmpdir.join("cert2_#{curve}.key")
    outfile        = tmpdir.join("cert2_#{curve}.crt")

    dn = "/C=CA/CN=testingidevid1"

    cert = IDevIDKeys.ca.sign_end_certificate("cert1",
                                               ee_privkeyfile,
                                               outfile, dn)

    expect(cert.subject.to_s).to eq("/C=CA/CN=testingidevid1")
  end



end
