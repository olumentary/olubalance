class CreateDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :documents do |t|
      t.references :attachable, polymorphic: true, null: false, index: true
      t.string :attachment_type
      t.integer :tax_year
      t.date :document_date
      t.timestamps
    end
    
    add_index :documents, :attachment_type
    add_index :documents, :tax_year
    add_index :documents, :document_date
  end
end 