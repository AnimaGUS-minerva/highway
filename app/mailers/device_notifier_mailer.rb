class DeviceNotifierMailer < ApplicationMailer

  def voucher_issued_email(voucher, voucher_request)
    @owner = voucher.owner
    @device= voucher.device
    @hostname = SystemVariable.string(:hostname)
    @resold = @device.owners.count > 1
    @originating_ip = voucher_request.try(:originating_ip) || "unknown"
    type = voucher.voucher_type
    mail(to: ENV['USER'], subject: "New #{type} voucher issued for #{@device.name}")
  end

  def voucher_notissued_email(voucher_req, reason)
    @voucher_req = voucher_req
    @hostname = SystemVariable.string(:hostname)
    @reason   = reason
    @originating_ip = voucher_req.try(:originating_ip) || "unknown"
    mail(to: ENV['USER'], subject: "Did not issue voucher")
  end

  def invalid_voucher_request(request, voucher_req)
    @originating_ip = request.env["REMOTE_ADDR"]
    @hostname = SystemVariable.string(:hostname)
    @voucher_req = voucher_req
    mail(to: ENV['USER'], subject: "Invalid voucher request")
  end

  def failed_to_notify_email(trace)
    if Rails.env.test?
      STDERR.puts "Failed to send notify"
      STDERR.puts trace.try(:to_s)
    else
      @trace = trace.try(:to_s)
      mail(to: 'webmaster', subject: "Failed to send notify email")
    end
  end

end
