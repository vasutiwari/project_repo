class AccountingSystemType < ActiveRecord::Base

  validates_presence_of :type_name , :message => "Accounting System Type name can't be empty."
  validates_length_of :type_name , :within => 3..100
  validates_format_of :type_name ,:with => /^[A-Za-z\d_]+/ , :message => "Please enter a valid Accounting System Type name."
  validates_uniqueness_of :type_name ,:message => "Accounting System Type name already exists."
  has_many :chart_of_accounts,:dependent=>:destroy
end
