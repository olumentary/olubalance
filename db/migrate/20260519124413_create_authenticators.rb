class CreateAuthenticators < ActiveRecord::Migration[8.1]
  def change
    create_table :authenticators do |t|
      t.references :user,              null: false, foreign_key: true, index: true
      t.string     :nickname,          null: false
      t.string     :otp_secret,        null: false
      t.integer    :consumed_timestep
      t.datetime   :last_used_at
      t.datetime   :confirmed_at,      null: false

      t.timestamps
    end

    add_index :authenticators, [ :user_id, :nickname ], unique: true
  end
end
