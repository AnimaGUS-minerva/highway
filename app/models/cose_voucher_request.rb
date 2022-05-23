class CoseVoucherRequest < VoucherRequest

  def self.from_cbor_cose(token, pubkey = nil)
    from_cbor_cose(StringIO.new(token), pubkey)
  end

  def self.from_cbor_cose_io(iotoken, pubkey = nil)
    iotoken = StringIO.new(iotoken.read)
    token   = iotoken.read
    iotoken.pos = 0  # rewind.
    begin
      vr = Chariwt::VoucherRequest.from_cbor_cose_io(iotoken, pubkey)
    rescue Chariwt::Voucher::MissingPublicKey
      raise InvalidVoucherRequest
    end

    unless vr
      raise InvalidVoucherRequest
    end
    vreq = create(voucher_request: token)
    vreq.details = vr.inner_attributes
    vreq.validated=false
    vreq.parse!(vr)
    vreq
  end

  def parse!(vr = nil)
    # base64 encode it for safe keeping.
    self.raw_request = Base64.urlsafe_encode64(voucher_request)
    if vr
      extract_prior_signed_voucher_request(vr)
    end
    if prior_voucher_request
      populate_explicit_fields(prior_voucher_request.attributes)
    end
    lookup_owner
    validate_prior!
    voucher
  end

  def pledge_cbor
    @pledge_cbor ||= prior_voucher_request.try(:attributes) || Hash.new
  end

  def lookup_owner
    proximity = pledge_cbor["proximity-registrar-cert"]
    if proximity
      # it is already binary, no pem/base64 decoding needed.
      self.owner = Owner.find_by_encoded_public_key(proximity)
    end
    self.owner
  end

  def prior_voucher_request
    case pledge_request
    when String
      @prior_voucher_request ||= Chariwt::VoucherRequest.from_cose_withoutkey(pledge_request)
    when Hash
      @prior_voucher_request ||= Chariwt::VoucherRequest.object_from_unsigned_json(pledge_request)
    end
  end

  def extract_prior_signed_voucher_request(cvr)
    self.pledge_request = cvr.priorSignedVoucherRequest
  end

  def generate_voucher(owner, device, effective_date, nonce, expires = nil)
    CoseVoucher.create_voucher(owner: owner, device: device,
                               domainOwnerRPK: prior_voucher_request.proximityRegistrarPublicKey,
                               effective_date: effective_date, nonce: nonce, expires: expires,
                               voucher_request: self)
  end


end
