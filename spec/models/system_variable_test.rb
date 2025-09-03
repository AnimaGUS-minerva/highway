require 'rails_helper'
require 'byebug'

RSpec.describe SystemVariable, type: :model do
  fixtures :all

  it "should have a fixture bar with value 34" do
    l = system_variables(:one)
    expect(l).to_not be_nil
    expect(l.variable).to eq("bar")
    expect(l.value).to    eq(34.to_s)
  end

  it "should look up name by symbol" do
    l = SystemVariable.lookup(:bar)
    expect(l).to_not be_nil
    expect(l.value).to    eq(34.to_s)
  end

  it "should make a variable if it does not already exist" do
    l = SystemVariable.findormake(:niceone)
    expect(l).to_not be_nil
    expect(l.value).to    be nil
  end

  it "should support nextvalue counters" do
    l = SystemVariable.nextval(:counter)
    expect(l).to eq(1)

    l = SystemVariable.nextval(:counter)
    expect(l).to eq(2)

    g = SystemVariable.findormake(:counter)
    expect(g.number).to eq(3)
  end

  it "should generate a sequence of random numbers" do
    l = SystemVariable.nextval(:counter)
    expect(l).to eq(1)

    l = SystemVariable.randomseq(:counter)
    expect(l).to_not eq 0
    #puts "l: #{l}"
    l = SystemVariable.randomseq(:counter)
    expect(l).to_not eq 0
    #puts "l: #{l}"
    l = SystemVariable.randomseq(:counter)
    expect(l).to_not eq 0
    #puts "l: #{l}"
  end

  describe "with TPP" do
    pending "TPM disabled" unless File.exist?("/bin/swtpm")

    def tmpdir
      @tmpdir ||= Rails.root.join("tmp")
    end

    def tpmstatedir
      tpmstatedir ||= tmpdir.join("tpm")
    end

    def socket0
      socket0 ||= tmpdir.join("swtpm")
    end
    def socket1
      socket1 ||= tmpdir.join("swtpm.ctrl")
    end
    def ca_handle
      "0x81010003"
    end

    def start_tpm
      logfile=tmpdir.join("tpm2.log")
      if !File.exist?(socket0)
        FileUtils.rm_rf(tpmstatedir)
        FileUtils.mkdir_p(tpmstatedir)
        cmd="swtpm_setup --tpm-state #{tpmstatedir} --tpm2 --createek"
        #print "PREP: #{cmd}\n"
        system(cmd)
        cmd="swtpm socket --daemon --server type=unixio,path=#{socket0} --ctrl type=unixio,path=#{socket1} --tpmstate dir=#{tpmstatedir} --tpm2 --log file=#{logfile} --flags startup-clear"

        #print "RUNNING: #{cmd}\n"
        system(cmd)
        system("(cd tmp && tpm2_createak --tcti=swtpm:path=#{socket0} -C 0x81010001 -G rsa -g sha256 -s rsapss --ak-context=ak_rsa.ctxi --public=ak_rsa.pub -n ak_rsa.name)")
        system("(cd tmp && tpm2_evictcontrol --tcti=swtpm:path=#{socket0} -C o -c ak_rsa.ctxi #{ca_handle})")
      end

      ENV['TPM2OPENSSL_TCTI']="swtpm:path=#{socket0}"
      prov01=OpenSSL::Provider.load("tpm2")
      print "Loaded #{OpenSSL::VERSION}\n"
      prov01
    end

    def end_tpm
      cmd="swtpm_ioctl --unix #{socket1} --stop "
      #print "STOPCMD: #{cmd}\n"
      system(cmd)
      cmd="swtpm_ioctl --unix #{socket1} -s "
      #print "ENDCMD: #{cmd}\n"
      system(cmd)
    end

    it "should configure a blank TPM, creating and using keys" do
      start_tpm
      SystemVariable.setvalue(:domain_handle, "handle:#{ca_handle}")
      caprivkeyfile = HighwayKeys.ca.root_priv_key_file
      outfile       = Rails.root.join("tmp").join("testca.crt")
      curve         = "2048"  # bits for RSA
      dnobj = OpenSSL::X509::Name.parse("/DC=ca/DC=sandelman/DC=testtpmca")

      file = HighwayKeys.ca.sign_ca_key(caprivkeyfile, outfile, curve, dnobj)
      expect(File.exist?(file)).to be true
      #FileUtils.rm(file)
      end_tpm
    end
  end

end
