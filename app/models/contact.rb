class Contact < ActiveRecord::Base
	 #validates_presence_of :name, :message=>"Name can't be blank"
	 validates_presence_of :email, :message=>"Email ID can't be blank"
  # apply_simple_captcha :message => " image and text were different", :add_to_base => true
	validates_format_of :email,    :with => Authentication.email_regex, :message =>"Invalid Email Address"
	validates_format_of :name,  :with => /[A-Z\/a-z]/, :message => "Provide a valid name",:allow_nil=>true, :allow_blank=>true		
	validates_format_of :phone_number, :with => /[0-9]/, :message => "Provide a valid Phone Number",:allow_nil=>true, :allow_blank=>true		
	 #validates_format_of :phone_number, :with => /^(\d{10}){1}?(\d)*$/, :message =>"Provide a valid Phone No", :allow_nil=>true, :allow_blank=>true
end
