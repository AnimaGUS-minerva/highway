class StatusController < ActionController::Base
  include Response

  def index
    @stats = [['Devices', Device.count],
              ['Inventory',  Device.unowned.count],
              ['Owners',  Owner.count],
              ['Vouchers',Voucher.count],
              ['Requests',VoucherRequest.count],
             ]
    respond_to do |format|
      format.html {
        render layout: 'reload'
      }
      format.json {
        data = Hash.new
        @stats.each { |n| data[n[0]]=n[1] }
        json_response(data, :ok, 'application/json')
      }
    end
  end
end
