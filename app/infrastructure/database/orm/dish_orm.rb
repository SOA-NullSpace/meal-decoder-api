# frozen_string_literal: true

module MealDecoder
  module Database
    # Object-Relational Mapper for Dishes
    class DishOrm < Sequel::Model(:dishes)
      unrestrict_primary_key
      plugin :timestamps, update_on_create: true
      plugin :validation_helpers
      plugin :whitelist_security

      set_allowed_columns :name, :status, :message_id

      many_to_many :ingredients,
                   class: :'MealDecoder::Database::IngredientOrm',
                   join_table: :dishes_ingredients,
                   left_key: :dish_id,
                   right_key: :ingredient_id

      def validate
        super
        validates_presence :name
        validates_unique :name
        validates_max_length 100, :name
        validates_format(/\A[\p{L}\p{N}\s]+\z/u, :name, message: 'name must contain only letters, numbers and spaces')
      end

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
