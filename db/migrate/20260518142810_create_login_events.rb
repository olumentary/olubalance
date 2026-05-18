class CreateLoginEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :login_events do |t|
      t.references :user, null: true, foreign_key: true, index: true
      t.string     :email_attempted
      t.inet       :ip
      t.string     :user_agent
      t.string     :event_type, null: false
      t.string     :reason
      t.jsonb      :metadata, default: {}, null: false
      t.datetime   :created_at, null: false
    end

    add_index :login_events, :created_at, order: { created_at: :desc }
    add_index :login_events, [ :ip, :created_at ]
    add_index :login_events, [ :email_attempted, :created_at ]
    add_index :login_events, [ :event_type, :created_at ]
  end
end
