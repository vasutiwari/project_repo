class ExcelTemplate < ActiveRecord::Base
	has_attachment :storage => :file_system, :size => 1.kilobytes..60.megabytes, :content_type => ['application/vnd.ms-excel'], :path_prefix => 'public/portfolio_images'	
  belongs_to :portfolio
end