class AddTlsClientcertificateToVoucherRequests < ActiveRecord::Migration[5.2]
  def change
    add_column :voucher_requests, :tls_clientcert, :text
  end
end
