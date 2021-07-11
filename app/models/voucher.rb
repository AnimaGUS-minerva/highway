require 'chariwt'

class Voucher < ActiveRecord::Base
  include FixtureSave
  belongs_to :device
  belongs_to :owner
  has_many   :voucher_requests

  class InvalidVoucher < Exception; end

  scope :creation_order, -> { order('created_at DESC') }

  def serial_number
    device.serial_number
  end

  def device_identifier
    device.serial_number
  end

  def notify_voucher!(vr = nil)
    begin
      DeviceNotifierMailer.voucher_issued_email(self, vr).deliver
    rescue Exception => e
      DeviceNotifierMailer.failed_to_notify-email(e).deliver
    end
  end

  def signing_cert
    MasaKeys.masa.masakey
  end

  def sign!
    raise Exception
  end

  # sign! is implemented in subclass.
  def self.create_voucher(owner:, device:, effective_date:,
                          nonce: nil, expires: nil, domainOwnerCert: nil,
                          domainOwnerRPK: nil,
                          voucher_request: nil)
    voucher = create(owner: owner,
                     device: device,
                     nonce: nonce)

    # assign the ownership.
    device.owner = owner
    device.save!

    domainOwnerCert ||= owner.certder
    domainOwnerRPK  ||= owner.pubkey_object

    unless expires
      expires = effective_date + 14.days
    end
    unless nonce
      voucher.expires_on = expires
    end

    voucher.sign!(today: effective_date, voucher_request: voucher_request,
                  owner_cert: domainOwnerCert, owner_rpk: domainOwnerRPK)
    voucher
  end

  def self.from_json(json)
    raise Voucher::InvalidVoucher unless json["ietf-voucher:voucher"]

    vdetails = json["ietf-voucher:voucher"]
    self.nonce = vdetails["nonce"]
  end

  def voucher_type
    "generic"
  end

  def name
    "#{voucher_type}_#{self.id}"
  end

  def savefixturefw(fw)
    return if save_self_tofixture(fw)
    device.savefixturefw(fw) if device
    owner.savefixturefw(fw)  if owner
  end

  # recode it in correct base64, and look up a voucher entry with that.
  def self.find_by_issued_voucher(binary_voucher)
    urlsafe64 = Base64.urlsafe_encode64(binary_voucher)
    Voucher.where(as_issued: urlsafe64).take
  end

  # CMS and CBOR vouchers are always stored Base64 urlsafe encoded in the database
  # avoiding a binary database
  def as_issued=(x)
    self[:as_issued]=Base64.urlsafe_encode64(x)
  end
  def as_issued
    Base64.urlsafe_decode64(self[:as_issued])
  end

end
