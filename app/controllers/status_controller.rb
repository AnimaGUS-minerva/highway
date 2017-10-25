class StatusController < ApiController
  def index
    @stats = [['Devices', Device.count],
              ['Owners',  Owner.count],
              ['Vouchers',Voucher.count],
              ['Requests',VoucherRequest.count],
             ]
    render :layout => 'reload'
  end
end
