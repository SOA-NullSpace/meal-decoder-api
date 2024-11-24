# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../spec_helper'

# Application domain entity and value objects for the MealDecoder service
# Handles form validation and processing for image uploads
module MealDecoder
  describe 'Test Requests - Image File Upload' do
    before do
      @temp_file = Tempfile.new(['test_img', '.jpg'])
      File.write(@temp_file, 'fake image content')
    end

    after do
      @temp_file.close
      @temp_file.unlink
    end

    it 'HAPPY: should validate proper image files' do
      good_file = {
        image_file: {
          tempfile: @temp_file,
          type: 'image/jpeg',
          filename: 'test.jpg'
        }
      }

      validation = Request::Image.new.call(good_file)
      _(validation.success?).must_equal true
      _(validation.errors.messages).must_be_empty
    end

    it 'SAD: should reject non-image files' do
      bad_file = {
        image_file: {
          tempfile: @temp_file,
          type: 'application/pdf',
          filename: 'test.pdf'
        }
      }

      validation = Request::Image.new.call(bad_file)
      _(validation.success?).must_equal false
      _(validation.errors[:image_file]).must_include 'must be a JPG, JPEG, or PNG image'
    end

    it 'SAD: should reject files with wrong extension' do
      bad_extension = {
        image_file: {
          tempfile: @temp_file,
          type: 'image/jpeg',
          filename: 'test.txt'
        }
      }

      validation = Request::Image.new.call(bad_extension)
      _(validation.success?).must_equal false
      _(validation.errors[:image_file]).must_include 'must have a valid image extension'
    end

    it 'SAD: should reject when image file is missing' do
      validation = Request::Image.new.call({})
      _(validation.success?).must_equal false
      _(validation.errors[:image_file]).must_include 'is missing'
    end
  end
end
