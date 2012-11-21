class MasterFilename < ActiveRecord::Base
	belongs_to :portfolio_type
	belongs_to :master_folder
end
