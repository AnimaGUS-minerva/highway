class FixJsonDetails < ActiveRecord::Migration[5.2]
  def change
    remove_column :voucher_requests, :details
  end
end
