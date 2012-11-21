class DbSettings < ActiveRecord::Base
		belongs_to :user		
		validates_presence_of :server_url
		validates_uniqueness_of :server_url	,	:message=>"URL already exists"
		validates_format_of :server_url , :with =>/^(http|https):\/\/[a-z0-9]+([-.]{1}[a-z0-9]+)*.[a-z]{2,5}(([0-9]{1,5})?\.*)?$/ix	,	:message=> "URL is not in valid format(Must include http:// or https://)"
		validates_format_of :add_property, :with=> /^[a-zA-Z0-9]*[\s]*/	
end