# -*- ruby -*-

require 'log4r'
include Log4r

namespace :highway do

  def prompt_variable(prompt, variable, previous)
    print prompt
    previous = previous.to_s.chomp
    print "(default #{previous}): "
    value = STDIN.gets.chomp

    if value.blank?
      value = previous
    end

    value
  end

  def prompt_variable_number(prompt, variable)
    SystemVariable.setnumber(variable,
                             prompt_variable(prompt,
                                             variable,
                                             SystemVariable.number(variable)))
  end

  def prompt_variable_value(prompt, variable)
    SystemVariable.setvalue(variable,
                            prompt_variable(prompt,
                                            variable,
                                            SystemVariable.string(variable)))
  end

  def set_iauthority
    port = SystemVariable.number(:portnum)
    portinfo = sprintf(":%u", port)
    portinfo = "" if port == 443
    SystemVariable.setvalue(:masa_iauthority, sprintf("%s%s",
                                                      SystemVariable.string(:hostname),
                                                      portinfo))

  end

  desc "Do initial setup of system variables, non-interactively, HOSTNAME=foo"
  task :h0_set_hostname => :environment do
    SystemVariable.setvalue(:hostname, ENV['HOSTNAME'])
    SystemVariable.setnumber(:portnum, ENV['PORT'] || "9443")
    set_iauthority
    puts "MASA URL is #{SystemVariable.string(:masa_iauthority)}"
  end

  desc "Do initial setup of shg_zone and prefix: SHG_ZONE=example.org SHG_PREFIX=r"
  task :h0_shg_zone => :environment do
    SystemVariable.setvalue(:shg_zone,   ENV['SHG_ZONE'])
    SystemVariable.setvalue(:shg_prefix, ENV['SHG_PREFIX'])
    puts "SHG dynamic update zone is #{SystemVariable.string(:shg_prefix)}.#{SystemVariable.string(:shg_zone)}"
  end

  desc "Do initial setup of sytem variables"
  task :h0_setup_masa => :environment do

    SystemVariable.dump_vars

    prompt_variable_value("Hostname for this instance",
                          :hostname)

    prompt_variable_number("Port number this instance",
                          :portnum)

    prompt_variable_value("DN prefix for certificates",
                          :dnprefix)

    prompt_variable_value("Inventory directory for this instance",
                          :inventory_dir)

    prompt_variable_value("Setup inventory base mac address",
                          :base_mac)

    set_iauthority
    SystemVariable.dump_vars
  end

  def rfc822NameChoice
    1
  end
  def rfc822NameAttr(rfc822name)
    v = OpenSSL::ASN1::UTF8String.new(rfc822name, rfc822NameChoice, :EXPLICIT, :CONTEXT_SPECIFIC)
    OpenSSL::X509::Attribute.new("subjectAltName",
                                 OpenSSL::ASN1::Set.new([OpenSSL::ASN1::Sequence.new([v])]))
  end

  # while this asks LetsEncrypt for a host like "foobar.example.com", it assumes that there is
  # a CNAME at _acme-challenge.foobar.example.com, pointing to _acme-challenge.example.com.example.net,
  # where example.net is the zone that has DNS updates enabled.
  desc "Ask LetsEncrypt for server certificate"
  task :h4_masa_letsencrypt => :environment do

    hostname = SystemVariable.hostname

    curve   = HighwayKeys.ca.client_curve
    certdir = HighwayKeys.ca.certdir
    serverprivkeyfile = certdir.join("server_#{curve}.key")
    outfile=certdir.join("server_#{curve}.crt")
    dn = sprintf("CN=%s", hostname)
    dnobj = OpenSSL::X509::Name.parse dn

    extraextra = "."
    unless ENV['EXTRA'].blank?
      extraextra = ENV['EXTRA']
    end

    if !File.exist?(outfile) or ENV['RESIGN']
      FileUtils.mkpath(HighwayKeys.ca.certdir)

      AcmeKeys.acme.acme_maybe_make_keys

      if SystemVariable.string(:shg_zone).blank?
        puts "Can not use LetsEncrypt unless :shg_zone SystemVariable is set"
        return
      end

      privkey = HighwayKeys.ca.generate_privkey_if_needed(serverprivkeyfile, curve, "SERVER")

      csr = OpenSSL::X509::Request.new
      csr.version = 0
      csr.subject = dnobj
      csr.public_key = privkey   # EC::Point can function as public key appropriately.
      csr.add_attribute rfc822NameAttr(hostname)
      csr.sign privkey, OpenSSL::Digest::SHA256.new

      mylog = Log4r::Logger.new 'mylog'
      mylog.outputters = Log4r::Outputter.stdout

      shg_suffix ||= SystemVariable.string(:shg_suffix)
      shg_zone   ||= SystemVariable.string(:shg_zone)

      shg_basezone = [shg_suffix, shg_zone].join('.')
      server_cert = AcmeKeys.acme.cert_for_names(qnames: [hostname],
                                                 zone: shg_basezone,
                                                 logger: mylog,
                                                 csr: csr,
                                                 sleeptime: 120,
                                                 extrazone: extraextra + SystemVariable.string(:shg_zone))

      if server_cert
        puts "MASA SERVER certificate writtten to: #{outfile}"
        File.open(outfile, "w") { |f|
          f.write server_cert
        }
      else
        puts "certificate failed"
      end
    end



  end


end
