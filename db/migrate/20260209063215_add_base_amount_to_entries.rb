class AddBaseAmountToEntries < ActiveRecord::Migration[8.0]
  def change
    add_column :entries, :base_amount, :decimal, precision: 15, scale: 4
  end
end
