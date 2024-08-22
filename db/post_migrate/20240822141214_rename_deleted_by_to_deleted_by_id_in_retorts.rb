# frozen_string_literal: true
class RenameDeletedByToDeletedByIdInRetorts < ActiveRecord::Migration[7.0]
  def change
    rename_column :retorts, :deleted_by, :deleted_by_id
  end
end
