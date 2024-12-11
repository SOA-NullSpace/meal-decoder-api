# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:dishes) do
      add_column :status, String, null: false, default: 'processing'
      add_column :message_id, String
    end
  end
end
