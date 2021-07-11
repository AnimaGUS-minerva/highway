class UnsignedVoucherRequest < CmsVoucherRequest
  def generate_voucher(owner, device, effective_date, nonce, expires = nil)
    CmsVoucher.create_voucher(owner: owner, device: device, effective_date: effective_date,
                              nonce: nonce, expires: expires, voucher_request: self)
  end
end
