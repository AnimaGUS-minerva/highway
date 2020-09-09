# -*- ruby -*-

namespace :shg do

  desc "Create the contents for an SQRL code for a given PRODUCTID="
  task :sqrl_pledge => :environment do
    productid = ENV['PRODUCTID']
    unless productid
      STDERR.puts "Must set PRODUCTID= to generate for"
      exit
    end

    device = Device.find_by_number(productid.downcase)
    if device
      STDERR.puts "Found product #{device.id}"
      puts device.sqrl_string
    else
      STDERR.puts "No product found with ID=#{productid}"
    end
  end

  desc "Create a new SHG device using SN=1234 MAC1=4567 MAC2=6789"
  task :device => :environment do
    serialnumber = ENV['SN']
    mac1         = ENV['MAC1']
    mac2         = ENV['MAC2']

    # it is okay if mac2 is missing
    if serialnumber.blank? or mac1.blank?
      puts "Please provide SN=#{serialnumber} MAC1=#{mac1} MAC2=#{mac2}. One was missing."
      exit 1
    end
    device = Device.find_obsolete_by_eui64(serialnumber) ||
             Device.find_obsolete_by_eui64(mac1)
    unless device
      device = Device.create_by_number(mac1)
    end
    device.serial_number = serialnumber
    device.second_eui64  = mac2
    device.activated!
    device.save!
    puts "Created #{device.id} #{device.notes}, and activated it"
  end

  desc "Mark a device PRODUCTID= as being valid for provisioning"
  task :valid => :environment do

    productid = ENV['PRODUCTID']
    device = Device.find_obsolete_by_eui64(productid)
    if device
      device.activated!
      puts "Marked #{device.id} #{device.notes} as active"
      if device.extra_attrs
        puts "Activated from #{device.extra_attrs['register_ip'] || "unknown"}"
      end
    else
      STDERR.puts "Device not found"
    end
  end

end
