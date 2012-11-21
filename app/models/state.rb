class State < ActiveRecord::Base
	#Relationships
	has_many :properties, :dependent=>:destroy
	has_many :real_estate_properties, :dependent=>:destroy
end