class PropertyType < ActiveRecord::Base
	has_many :property_collateral_details, :dependent=>:destroy
	has_many :real_estate_properties

 # has_many :templates
  belongs_to :template
end