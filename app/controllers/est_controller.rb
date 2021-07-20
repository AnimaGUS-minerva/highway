require 'multipart_body'

# use of ActionController::Metal means that JSON parameters are
# not automatically parsed, which reduces cases of processing bad
# JSON when no JSON is acceptable anyway.
class EstController < ApiController

  def requestvoucher

    @clientcert = nil
    @replytype  = request.content_type
    if @replytype.blank?
	   @replytype = "application/voucher-cms+json"
    end

    begin
      cert_pem = capture_client_certificate
      if cert_pem.blank?
        capture_bad_request(code: 406,
                            msg: "client certificate seems blank")
        return
      end

      if cert_pem
        @clientcert = OpenSSL::X509::Certificate.new(cert_pem)
        log_client_certificate(@clientcert)
      end

    # catch case where certificate is crap.
    rescue OpenSSL::X509, OpenSSL::X509::CertificateError
      capture_bad_request(code: 406,
                          msg: "client certificate was not well formatted")

    rescue
      capture_bad_request(code: 406,
                          msg: "client certificate processing had error #{$!}")
    end

    logger.info "Processing Voucher-Request of type: '#{@replytype}'"
    @media_types = HTTP::Accept::MediaTypes.parse(@replytype)

    if @media_types == nil or @media_types.length < 1
      capture_bad_request(msg: "unknown voucher-request content-type: #{@replytype}")
      return
    end
    @media_type = @media_types.first

    begin
      case
      when (@media_type.mime_type == 'application/voucher-cms+json')

        binary_pkcs = request.body.read
        begin
          @voucherreq = CmsVoucherRequest.from_pkcs7(binary_pkcs)
        rescue VoucherRequest::MissingPublicKey
          vr = capture_bad_request(code: 404,
                              msg: "voucher request was for invalid device, or was missing public key")
          DeviceNotifierMailer.invalid_voucher_request(request, vr).deliver
          return

        rescue Chariwt::Voucher::RequestFailedValidation
          vr = capture_bad_request(code: 406,
                              msg: "voucher request corrupt or failed to validate")
          DeviceNotifierMailer.invalid_voucher_request(request, vr).deliver
          return
        end

      when (@media_type.mime_type == 'application/voucher-cose+cbor')
        begin
          @voucherreq = CoseVoucherRequest.from_cbor_cose_io(request.body, @clientcert)
        rescue VoucherRequest::InvalidVoucherRequest
          vr = capture_bad_request(code: 406,
                              msg: "CBOR voucher request was not signed with a known public key")
          DeviceNotifierMailer.invalid_voucher_request(request, vr).deliver
          return
        rescue VoucherRequest::MissingPublicKey
          vr = capture_bad_request(code: 406,
                              msg: "CBOR voucher request prior-signed-voucher-request was not signed with a known public key")
          DeviceNotifierMailer.invalid_voucher_request(request, vr).deliver
          return
        end
      else
        vr = capture_bad_request(code: 406,
                                 msg: "unknown voucher-request content-type: #{request.content_type}")
        DeviceNotifierMailer.invalid_voucher_request(request, vr).deliver
        return
      end
    end

    unless @voucherreq
      capture_bad_request(code: 404, msg: 'missing voucher request')
      return
    end

    # capture extra info, if we didn't get it already
    capture_client_certificate

    @voucherreq.save!
    @voucher,@reason = @voucherreq.issue_voucher

    @answered = false
    if @reason == :ok and @voucher

      accept_types = HTTP::Accept::MediaTypes.parse(request.env['HTTP_ACCEPT'])
      accept_types.each { |type|

        case
        when type.mime_type == 'multipart/mixed'
          part1 = Part.new(:body => @voucher.as_issued,           :content_type => 'application/voucher-cose+cbor')
          part2 = Part.new(:body => @voucher.signing_cert.to_pem, :content_type => 'application/pkcs7-mime; smime-type=certs-only')
          @multipart = MultipartBody.new([part1, part2])
          raw_response(@multipart.to_s, :ok, "multipart/mixed; boundary=#{@multipart.boundary}")
          @answered = true

        when ((type.mime_type == 'application/pkcs7-mime' and
               type.parameters == { 'smime-type' => 'voucher'}) or
              (type.mime_type == 'application/pkcs7-mime' and
               type.parameters == { } )                         or
              (type.mime_type == 'application/voucher-cms+json'))

          raw_response(@voucher.as_issued, :ok, "application/voucher-cms+json")
          @answered = true

        when (type.mime_type == 'application/voucher-cose+cbor')
          raw_response(@voucher.as_issued, :ok, @replytype)
          @answered = true

        when (type.mime_type == '*/*')
          # just ignore this entry, it does not help
          true

        else
          logger.debug "accept type: #{type} not recognized"
          # nothing, inside loop
        end

        break if @answered
      }

      unless @answered
        logger.error "No acceptable HTTP_ACCEPT type found #{accept_types}"
        capture_bad_request(code: 406, msg: "no acceptable HTTP_ACCEPT type found")
      end

    else
      logger.error "no voucher issued for #{request.ip}, reason: #{@reason.to_s}"
      capture_bad_request(code: 404, msg: @reason.to_s)
    end
  end

  def requestauditlog
    binary_pkcs = request.body.read
    @voucherreq = CmsVoucherRequest.from_pkcs7(binary_pkcs)
    @device = @voucherreq.device
    @owner  = @voucherreq.owner

    if @device.device_owned_by?(@owner)
      api_response(@device.audit_log, :ok,
                    'application/json')
    else
      head 404, text: 'invalid device'
    end
  end

  private

  def capture_client_certificate
    clientcert_pem = request.env["SSL_CLIENT_CERT"]
    clientcert_pem ||= request.env["rack.peer_cert"]
    if @voucherreq
      @voucherreq.raw_request = request.env.to_s
      if clientcert_pem
        @voucherreq.tls_clientcert = clientcert_pem
      end
      @voucherreq.originating_ip = request.ip
    end
    clientcert_pem
  end

  def capture_bad_request(msg:, code: 406)
    request.body.rewind
    token = request.body.read
    @voucherreq ||= VoucherRequest.create(:voucher_request => token,
                                          :originating_ip => request.env["REMOTE_ADDR"])

    capture_client_certificate
    # put @media_type into some useful place?
    @voucherreq.details["returned_message"] = msg
    @voucherreq.save!
    logger.info "Voucher request failed, details in #{@voucherreq.id}, #{$!}"
    head code, text: msg

    @voucherreq
  end

end
