class AddHashOfPublicKeyToDevice < ActiveRecord::Migration[5.2]
  def down
    remove_index  :devices, :idevid_hash
    remove_column :devices, :idevid_hash, :text
  end

  def up
    add_column :devices, :idevid_hash, :text
    add_index  :devices, :idevid_hash

    Device.all.each { |d|
      d.validate_hash_of_keys
      d.save!
    }
  end
end
