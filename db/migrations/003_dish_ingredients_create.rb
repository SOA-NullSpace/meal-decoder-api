# frozen_string_literal: true

Sequel.migration do
  up do
    create_table(:dishes_ingredients) do
      foreign_key :dish_id, :dishes, null: false
      foreign_key :ingredient_id, :ingredients, null: false

      primary_key %i[dish_id ingredient_id]
      index %i[dish_id ingredient_id]
    end
  end

  down do
    drop_table(:dishes_ingredients)
  end
end
