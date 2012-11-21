class Address < ActiveRecord::Base
	has_one :real_estate_property
  attr_accessor  :add_property_validity
	validates_presence_of :province ,:message => "Can't be blank"  ,:if => Proc.new { |address| (address.add_property_validity != "no") }
	before_save :update_client_id_for_address
	
def self.store_address_details(txt,city,zip,province)
  address = Address.new
	address.txt =  txt
	address.city =  city
	address.zip =  zip
	address.province =  province
	address.add_property_validity = "yes"
	address.save
	return address
end

#client id added
def update_client_id_for_address
    client_id  = Client.current_client_id
    self.client_id = client_id  if client_id.present?
end
	
end
