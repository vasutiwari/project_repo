class MasterFile < ActiveRecord::Base
	
	has_attachment :storage => :file_system, :size => 1.kilobytes..60.megabytes, :content_type => ['application/vnd.ms-excel'], :path_prefix => 'public/master_files'		
  belongs_to :master_folder
	
end
