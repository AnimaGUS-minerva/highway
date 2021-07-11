class CmsVoucherRequest < VoucherRequest
  def self.from_pkcs7(token, json = nil)
    # look to see if this is a byte-for-byte identical requestion
    if vreq = where(voucher_request: token).take
      return vreq
    end

    cvr = Chariwt::VoucherRequest.from_pkcs7_withoutkey(token)
    # on MASA, voucher requests MUST always be signed
    unless cvr
      raise InvalidVoucherRequest
    end
    vreq = from_json(cvr.inner_attributes, token)
    vreq.extract_prior_signed_voucher_request(cvr)
    vreq.populate_explicit_fields

    # need to collect cvr.signing_cert into a field.
    if cvr.signing_cert
      vreq.signing_key = Base64.urlsafe_encode64(cvr.signing_cert.public_key.to_der)
    end

    vreq.lookup_owner
    vreq.validate_prior!
    vreq.save!
    vreq
  end

  def pledge_json
    @pledge_json ||= prior_voucher_request.inner_attributes
  end

  def lookup_owner
    proximity = pledge_json["proximity-registrar-cert"]
    if proximity
      cooked_key = Chariwt::Voucher.decode_pem(proximity)
      self.owner = Owner.find_by_encoded_public_key(cooked_key)
    end
    self.owner
  end

  def prior_voucher_request
    if pledge_request
      @prior_voucher_request ||= Chariwt::VoucherRequest.from_pkcs7_withoutkey(pledge_request)
    end
  end

  def extract_prior_signed_voucher_request(cvr)
    self.pledge_request    = cvr.priorSignedVoucherRequest

    if pledge_request
      # save the decoded results into JSON bag.
      self.details["prior-signed-voucher-request"] = pledge_json
    end
    if cvr.signing_cert and pledge_request
      self.prior_signing_key = Base64.urlsafe_encode64(prior_voucher_request.signing_cert.public_key.to_der)
    end

    lookup_owner
  end

  def generate_voucher(owner, device, effective_date, nonce, expires = nil)
    CmsVoucher.create_voucher(owner: owner, device: device,
                              domainOwnerCert: prior_voucher_request.proximityRegistrarCert,
                              effective_date: effective_date,
                              nonce: nonce, expires: expires, voucher_request: self)
  end
end
