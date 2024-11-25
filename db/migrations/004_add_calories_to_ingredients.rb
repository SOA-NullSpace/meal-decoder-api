# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:ingredients) do
      add_column :calories_per_100g, Float, default: 0.0
    end
  end
end
