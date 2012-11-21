class Client < ActiveRecord::Base
  has_many :users, :dependent=>:destroy
  has_many :chart_of_accounts, :dependent=>:destroy

  # validations start here
  #~ validates :name,  :presence => {:message => "Name can't be blank" }, :uniqueness => {:message => "Email has already taken"}

  #~ validates_presence_of :email,:message=>"Email can't be blank"
  #~ validates_length_of :email,    :within => 6..100 ,:message=>"Email Id must be between 6 to 100 characters"
  #~ validates_uniqueness_of :email,:message=>"This Email Id already taken"
  #~ validates_format_of :email,    :with => Authentication.email_regex, :message => Authentication.bad_email_message

  accepts_nested_attributes_for :users, :allow_destroy => true
  accepts_nested_attributes_for :chart_of_accounts,:reject_if => lambda { |attrs| attrs['name'].blank?  }, :allow_destroy => true
  serialize :accounting_system_type_ids

  def self.current_client
    Thread.current[:client]
  end

  def self.current=(client)
    Thread.current[:client] = client
  end

  def self.current_client_id
    Thread.current[:client_id]
  end

  def self.current_id=(client_id)
    Thread.current[:client_id] = client_id
  end

  def update_client_fields(params)
    if params.present?
      self.name = params[:name]
      self.email = params[:email]
      self.host = params[:host]
      self.contact_person = params[:contact_person]
      self.chart_of_accounts = params[:chart_of_accounts]
    end
    self
  end
end
