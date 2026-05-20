class DropMotorAdminTables < ActiveRecord::Migration[8.1]
  def up
    %i[
      motor_alert_locks
      motor_alerts
      motor_api_configs
      motor_audits
      motor_configs
      motor_dashboards
      motor_forms
      motor_notes
      motor_note_tags
      motor_note_tag_tags
      motor_notifications
      motor_queries
      motor_reminders
      motor_resources
      motor_taggable_tags
      motor_tags
    ].each { |t| drop_table t, if_exists: true, force: :cascade }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
