class Role < ActiveRecord::Base
	#Relationship
  has_and_belongs_to_many :users
	#To reject admin and client admin roles
	scope :not_admin_and_client_admin, :conditions=>["name NOT in (?)",["Admin","Client Admin"]]
end

                        