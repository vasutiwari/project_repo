class MasterFolder < ActiveRecord::Base
	has_many :master_files, :dependent=>:destroy
	belongs_to :portfolio_type

	def self.find_and_update_attributes(drop,drag)
		case drag[0]
			when "folder"
				folder = MasterFolder.find_by_id(drag[1])
				already_folder = MasterFolder.find_by_name_and_parent_id(folder.name,drop[1])
				folder.update_attributes(:parent_id => drop[1]) if already_folder.nil?			
			when "filename"
				document = MasterFilename.find_by_id(drag[1])
				already_file = MasterFilename.find_by_name_and_master_folder_id(document.name,drop[1])
				document.update_attributes(:master_folder_id => drop[1]) if already_file.nil?			
			when "file"
				file = MasterFile.find_by_id(drag[1])
				already_file = MasterFile.find_by_filename_and_master_folder_id(file.filename,drop[1])
				file.update_attributes(:master_folder_id => drop[1]) if already_file.nil?			
		end		
		return already_folder , already_file	
	end
	
end
