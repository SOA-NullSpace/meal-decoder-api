# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:ingredients) do
      primary_key :id
      String      :name, unique: true, null: false
      DateTime    :created_at
      DateTime    :updated_at
    end
  end
end
