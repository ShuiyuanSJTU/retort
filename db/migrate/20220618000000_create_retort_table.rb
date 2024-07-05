# frozen_string_literal: true
class CreateRetortTable < ActiveRecord::Migration[7.0]
  def change
    create_table :retorts do |t|
      t.string :emoji, index: true
      t.integer :post_id, index: true
      t.integer :user_id, index: true

      t.timestamps
    end

    add_index :retorts, %i[post_id user_id emoji], unique: true
  end
end
