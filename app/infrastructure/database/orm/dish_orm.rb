# frozen_string_literal: true

module MealDecoder
  module Database
    # Object-Relational Mapper for Dishes
    class DishOrm < Sequel::Model(:dishes)
      plugin :timestamps, update_on_create: true
      plugin :validation_helpers

      def validate
        super
        validates_presence :name
        validates_unique :name
        validates_max_length 100, :name
        # Allow letters, numbers, and spaces in dish names
        validates_format(/\A[[:print:]]+\z/u, :name, message: 'name must be printable characters')
      end

      many_to_many :ingredients,
                   class: :'MealDecoder::Database::IngredientOrm',
                   join_table: :dishes_ingredients,
                   left_key: :dish_id, right_key: :ingredient_id

      def self.find_or_create(dish_info)
        first(name: dish_info[:name]) || create(dish_info)
      end

      def before_create
        super
        self.status ||= 'processing'
      end
    end
  end
end
