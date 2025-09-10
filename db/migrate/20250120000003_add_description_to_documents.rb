class AddDescriptionToDocuments < ActiveRecord::Migration[7.0]
  def change
    add_column :documents, :description, :text
  end
end 