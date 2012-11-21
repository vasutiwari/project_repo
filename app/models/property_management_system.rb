class PropertyManagementSystem < ActiveRecord::Base
	#Relationships
	has_one :real_estate_property
	#Validations
	validates_presence_of :name, :message=>"Name can't be blank"
	validates_uniqueness_of :name, :message=>"Name already taken"
	validates_presence_of :short_code, :message=>"Short Code can't be blank"
	validates_uniqueness_of :short_code, :message=>"Short Code already taken"
end