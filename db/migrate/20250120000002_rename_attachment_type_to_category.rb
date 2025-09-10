class RenameAttachmentTypeToCategory < ActiveRecord::Migration[7.0]
  def change
    rename_column :documents, :attachment_type, :category
  end
end 