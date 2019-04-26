# There are a multiciplicity of subclasses, each to deal with different cases
#
# 1) CMS signed JSON, containing (prior=CMS signed JSON)
#    This is CmsVoucherRequest subclass.
#
# 2) CMS signed CBOR, containing (prior=CMS signed CBOR)
#    This is not implemented as yet.
#
# 3) COSE signed CBOR, containing (prior=COSE signed CBOR)
#    This is CoseVoucherRequest
#
# 4) CMS signed JSON, containing unsigned JSON.
#    This is UnsignedVoucherRequest
#
# 5) CMS signed JSON, containing unsigned CBOR.
#    This is not implemented as yet.
#
# 6) CMS signed CBOR, containing unsigned CBOR.
#    This is not implemented as yet.
#

class VoucherRequest < ApplicationRecord
  belongs_to :voucher
  belongs_to :owner
  belongs_to :device
  include FixtureSave

  attr_accessor :tls_clientcert, :prior_voucher_request

  class InvalidVoucherRequest < Exception; end
  class MissingPublicKey < Exception; end
  class InvalidDeviceSignature < Exception; end

  def self.from_json(json, artifact)
    vr = create(details: json, voucher_request: artifact)
    vr.populate_explicit_fields
    vr
  end

  def self.from_json_jose(token, json = nil)
    jsonresult = Chariwt::VoucherRequest.from_jose_json(token)
    unless jsonresult
      raise InvalidVoucherRequest
    end
    return from_json(jsonresult.inner_attributes, token)
  end

  def name
    "voucherreq_#{self.id}"
  end

  def proximity?
    "proximity" == details["assertion"]
  end

  def savefixturefw(fw)
    voucher.savefixturefw(fw) if voucher
    owner.savefixturefw(fw)   if owner
    save_self_tofixture(fw)
  end

  def signing_public_key
    unless signing_key.blank?
      @signing_public_key ||= OpenSSL::PKey.read(Base64.urlsafe_decode64(signing_key))
    end
  end

  def populate_explicit_fields(hash = details)
    self.device_identifier = hash["serial-number"]
    if self.device_identifier
      self.device            = Device.find_by_number(device_identifier)
    end
    self.nonce             = hash["nonce"]
  end

  def validated!
    self.validated = true
  end

  def validate_prior!
    if device.try(:certificate)
      if prior_voucher_request.verify_with_key(device.certificate)
        self.signing_key = device.pubkey
        self.validated!
      else
        raise VoucherRequest::InvalidDeviceSignature
      end
    else
      raise VoucherRequest::MissingPublicKey
    end
  end

  def issue_voucher(effective_date = Time.now)

    # at a minimum, this must be before a device that belongs to us!
    unless device
      DeviceNotifierMailer.voucher_notissued_email(self, :notmydevice).deliver
      return nil,:notmydevice
    end

    # must have an owner!
    return nil,:ownerunknown unless owner

    # validate that the signature on the prior-signed-voucher-request
    # is from the key which was assigned to the device.
    return nil,:rawvoucherinvalid unless validated?

    # XXX if there is another valid voucher for this device, it must be for
    # the same owner.

    ## XXX what other kinds of validation belongs here?

    voucher = generate_voucher(owner, device, effective_date, nonce)
    self.voucher = voucher
    save!
    return voucher,:ok
  end

end
