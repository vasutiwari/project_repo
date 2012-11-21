class SharedDocument < ActiveRecord::Base
	belongs_to :user
        belongs_to :document
	belongs_to :folder
end