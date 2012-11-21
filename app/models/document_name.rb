class DocumentName < ActiveRecord::Base
	belongs_to :folder
	belongs_to :document
	belongs_to :user
	has_many :event_resources, :as=>:resource,:dependent=>:destroy
  belongs_to :real_estate_property
  belongs_to :property
	end