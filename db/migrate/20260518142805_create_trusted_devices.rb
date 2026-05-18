class CreateTrustedDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :trusted_devices do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.string     :token_digest, null: false
      t.string     :user_agent
      t.inet       :ip
      t.datetime   :last_seen_at
      t.datetime   :expires_at, null: false
      t.datetime   :revoked_at

      t.timestamps
    end

    add_index :trusted_devices, :token_digest, unique: true
    add_index :trusted_devices, :expires_at
  end
end
