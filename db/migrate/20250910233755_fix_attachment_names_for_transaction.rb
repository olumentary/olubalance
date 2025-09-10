class FixAttachmentNamesForTransaction < ActiveRecord::Migration[8.0]
  def up
    ActiveStorage::Attachment.where(
      record_type: 'Transaction',
      name: 'attachment'
    ).update_all(name: 'attachments')
  end

  def down
    # Rollback migration
    ActiveStorage::Attachment.where(
      record_type: 'Transaction', 
      name: 'attachments'
    ).update_all(name: 'attachment')
  end
end
