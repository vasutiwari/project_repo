class UserProfileDetail < ActiveRecord::Base
	attr_accessor :is_new_user
	belongs_to :user
	validates_presence_of :city,:if => Proc.new { |user| user.is_new_user },:message=>"City can't be blank"
	validates_presence_of :state,:if => Proc.new { |user| user.is_new_user },:message=>"State can't be blank"
	validates_presence_of :zipcode,:if => Proc.new { |user| user.is_new_user },:message=>"Zipcode can't be blank"
	validates_format_of :zipcode, :if => Proc.new {|user| user.is_new_user}, :with => /\b[0-9]{1,6}\b/, :message =>"Provide a valid Zipcode",:allow_nil=>true, :allow_blank=>true
	validates_presence_of :interest,:if => Proc.new { |user| user.is_new_user },:message=>"Select your interest(s)"
	validates_format_of :city,  :with => /[A-Z\/a-z]/, :message => "Provide a valid City name",:allow_nil=>true, :allow_blank=>true
	validates_format_of :state,  :with => /[A-Z\/a-z]/, :message => "Provide a valid State name",:allow_nil=>true, :allow_blank=>true
	validates_length_of :title,:if => Proc.new { |user| user.is_new_user },:within => 0..40,:message=>"Title should be in less than 40 characters", :allow_nil=>true, :allow_blank=>true
  validates_presence_of :title,:if => Proc.new { |user| user.is_new_user},:message=>"Job Title can't be blank"
	attr_accessible :business_name, :city, :state, :zipcode, :title, :website, :interest, :user_id
end