require 'digest/sha1'

class User < ActiveRecord::Base
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken
  include Authorization::AasmRoles

  #Attr accessor
  attr_accessor :is_shared_user,:designation_check
  attr_accessor :is_new_user,:is_asset_manager
  attr_accessor :is_set_password, :is_asset_edit, :is_set_company,:ignore_password

  #Scope to find the user based on client admin ids
  scope :by_client_ids, (lambda do |client_id,email|
    {:include=>[:roles],:conditions => ['client_id = ? AND email <> ? AND roles.name NOT in (?)', client_id,email,["Admin","Server Admin", "Client Admin"]]}
    end)

  #Relationship
  has_and_belongs_to_many :roles
  has_many :comments, :dependent=>:destroy
  has_many :folders, :dependent=>:destroy
  has_many :document_names, :dependent=>:destroy
  has_many :documents, :dependent=>:destroy
  has_many :shared_documents,:dependent=>:destroy
  has_many :shared_folders,:dependent=>:destroy
  has_one :user_profile_detail, :dependent=>:destroy
  has_many :income_and_cash_flow_details, :dependent=>:destroy
  has_many :real_estate_properties, :dependent=>:destroy
  has_many :portfolios , :dependent=>:destroy
  has_one :portfolio_image, :as=> :attachable , :dependent=>:destroy, :conditions=> "filename != 'login_logo'"
  has_one :logo_image, :as=> :attachable, :dependent=>:destroy, :conditions=> "filename = 'login_logo'", :class_name=> 'PortfolioImage'
  #~ has_one :client_logo_image, :class_name => 'PortfolioImage', :conditions => "attachable_type = 'ClientSetting'  or attachable_type = 'ClientExtension'"
  has_one :client_logo_image, :class_name => 'PortfolioImage', :conditions => "attachable_type = 'Client'"
  has_many :variance_thresholds, :dependent=>:destroy
  has_one :client_setting, :dependent=>:destroy
  has_one :db_settings, :dependent=>:destroy
  has_one :amp_users_phone_call, :dependent=>:destroy
  has_many :suites
  belongs_to :client
  accepts_nested_attributes_for :portfolio_image, :allow_destroy => true

  #Validations
  #~ validates_presence_of :login,:if => Proc.new { |user| !user.is_shared_user && !user.is_set_password},:message=>"User name can't be blank"
  #~ validates_length_of :login,:if => Proc.new { |user| !user.is_shared_user && !user.is_set_password  },:within => 3..40,:message=>"User name must be between 3 to 40 characters"
  #~ validates_uniqueness_of :login,:if => Proc.new { |user| !user.is_shared_user && !user.is_set_password},:message=>"User name already taken"
  #~ validates_format_of :login,:if => Proc.new { |user| !user.is_shared_user && !user.is_set_password},:with => Authentication.login_regex, :message => "only letters, numbers, dots ,hyphen & underscore is allowed"
  validates_presence_of :name,:if => Proc.new { |user| !user.is_shared_user || user.is_set_password },:message=>"Name can't be blank"
  validates_length_of :name,:if => Proc.new { |user| !user.is_shared_user || user.is_set_password },:within=> 3..100,:too_long=>"Name should not contain more than 100 characters", :too_short=>"Must have at least 3 characters"
  validates_format_of :name,:if => Proc.new { |user| !user.is_shared_user || user.is_set_password } ,:with => /^[\w\s]([\w]*[\s]*[\w]*)*[\w\s]$/ , :message => "Name only contain alphabets, digits, space & underscore"
  validates_presence_of :phone_number,:if => Proc.new { |user| user.is_new_user || user.is_asset_manager || user.is_set_password },:message=>"Phone number can't be blank"
  validates_format_of :phone_number, :if => Proc.new {|user| !user.is_shared_user || user.is_asset_manager || user.is_set_password }, :with => /^(\d{10}){1}?(\d)*$/, :unless =>  Proc.new { |user| user.roles.map(&:name).include?("Client Admin") || user.roles.map(&:name).include?("Server Admin") }, :message =>"Provide a valid Phone Number"#, :allow_nil=>true, :allow_blank=>true
  validates_presence_of :email,:message=>"Email can't be blank"
  validates_length_of :email,    :within => 6..100 ,:message=>"Email Id must be between 6 to 100 characters"
  validates_uniqueness_of :email,:message=>"This Email Id already taken"
  validates_format_of :email,    :with => Authentication.email_regex, :message => Authentication.bad_email_message
  validates_length_of :designation,:if => Proc.new { |user| (!user.is_shared_user && !user.is_new_user && !user.designation_check)  || (user.is_asset_manager || user.is_set_password)}, :unless =>  Proc.new { |user| user.roles.map(&:name).include?("Client Admin") || user.roles.map(&:name).include?("Server Admin") } , :within => 0..40,:message=>"Title should be in less than 40 characters"#, :allow_nil=>true, :allow_blank=>true
  validates_presence_of :designation,:if => Proc.new { |user| user.is_asset_manager || user.is_set_password }, :unless =>  Proc.new { |user| user.roles.map(&:name).include?("Client Admin") || user.roles.map(&:name).include?("Server Admin") }, :message=>"Job Title can't be blank"
  validates_presence_of :company_name,:if => Proc.new { |user| !user.is_shared_user && !user.is_set_password },:message=>"Company name can't be blank"
  validates_uniqueness_of :company_name, :if=> Proc.new {|user| user.is_set_company},:message=>"Company name already taken"
  validates_presence_of     :password, :if => :password_required?
  validates_presence_of     :password_confirmation, :if => :password_required?
  validates_confirmation_of :password, :if => :password_required?
  validates_length_of       :password, :within => 6..40, :if => :password_required?
  validates_length_of       :password_confirmation, :within => 6..40, :if => :password_required?
  validates_presence_of :address,:if => Proc.new { |user| user.is_new_user },:message=>"Address can't be blank"

  validate :check_user_company, :if=> Proc.new {|user| user.is_set_company}
  # HACK HACK HACK -- how to do attr_accessible from here?
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :email, :name, :password, :password_confirmation,:company_name,:designation,:comment,:department,:phone_number,:address,:approval_status,:client_type,:company_address
  # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
  # uff.  this is really an authorization, not authentication routine.
  # We really need a Dispatch Chain here or something.
  # This will also let us return a human error message.
  after_create :after_save_the_property,:create_basic_portfolios_for_client_admin
  def self.authenticate(email, password)
    return nil if email.blank? || password.blank?
    user = find :first, :conditions => (['(email = ? or login = ?)',email.downcase,email.downcase]) # need to get the salt
    user #&& user.authenticated?(password) ? user : nil
  end

  def login=(value)
    write_attribute :login, (value ? value.downcase : nil)
  end

  def email=(value)
    write_attribute :email, (value ? value.downcase : nil)
  end

  # has_role? simply needs to return true or false whether a user has a role or not.
  # It may be a good idea to have "admin" roles return true always
  def has_role?(role_in_question)
    @_list ||= self.roles.collect(&:name)
    return true if @_list.include?("admin")
    (@_list.include?(role_in_question.to_s) )
  end

  def generate_password
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    p = ""
    chars_small =  ("a".."z").to_a
    chars_caps = ("A".."Z").to_a
    chars_numbers =   ("0".."9").to_a
    small  = chars_small[rand(chars_small.size-1)]
    caps = chars_caps[rand(chars_caps.size-1)]
    number = chars_numbers[rand(chars_numbers.size-1)]
    p << small << caps << number
    1.upto(7) { |i| p << chars[rand(chars.size-1)] }
    return p
  end

  def self.encrypt_password(pwd)
    Base64.encode64(pwd).chop
  end

  def self.email_authenticate(email, password)
    return nil if email.blank? || password.blank?
    u = find :first, :conditions => {:email => email} # need to get the salt
    u && u.authenticated?(password) ? u : nil
  end

  def user_role(id)
    user=User.find_by_id_and_client_id(id,User.current.try(:client_id))
    userrole=user.roles[0].name
    return userrole
  end

  def self.random_passwordcode(size = 30)
    chars = (('a'..'z').to_a + ('0'..'9').to_a) - %w(i o 0 1 l 0)
    (1..size).collect{|a| chars[rand(chars.size)] }.join
  end

  def user_name
    unless (self.name.nil? || self.name.empty?)
    self.name #.capitalize
    else
      self.email.split('@').first.capitalize
    end
  end

  def after_save_the_property
    if self.login != "admin"
      portfolio = Portfolio.find_or_create_by_user_id_and_name_and_portfolio_type_id_and_client_id(self.id,'portfolio_created_by_system',2,self.client_id)
      property = RealEstateProperty.find_or_create_by_user_id_and_property_name_and_portfolio_id_and_client_id(self.id,'property_created_by_system',portfolio.id,self.client_id)
      property.no_validation_needed = 'true'
      property.save
      Folder.find_or_create_by_portfolio_id_and_real_estate_property_id_and_user_id_and_name_and_client_id(portfolio.id,property.id,self.id,'my_files',self.client_id)
      portfolio_for_deal_room = Portfolio.find_or_create_by_user_id_and_name_and_portfolio_type_id_and_client_id(self.id,'portfolio_created_by_system_for_deal_room',2,self.client_id)
      property_for_deal_room = RealEstateProperty.find_or_create_by_user_id_and_property_name_and_portfolio_id_and_client_id(self.id,'property_created_by_system_for_deal_room',portfolio_for_deal_room.id,self.client_id)
      property_for_deal_room.no_validation_needed = 'true'
      property_for_deal_room.save
      Folder.find_or_create_by_portfolio_id_and_real_estate_property_id_and_user_id_and_name_and_client_id(portfolio_for_deal_room.id,property_for_deal_room.id,self.id,'my_deal_room',self.client_id)
      # Weekly bulk upload items to be set in the database.
      portfolio_for_bulk_upload = Portfolio.find_or_create_by_user_id_and_name_and_portfolio_type_id_and_client_id(self.id,'portfolio_created_by_system_for_bulk_upload',2,self.client_id)
      property_for_bulk_upload = RealEstateProperty.find_or_create_by_user_id_and_property_name_and_portfolio_id_and_client_id(self.id,'property_created_by_system_for_bulk_upload',portfolio_for_bulk_upload.id,self.client_id)
      property_for_bulk_upload.no_validation_needed = 'true'
      property_for_bulk_upload.save
      folder_bulk = Folder.find_or_create_by_name_and_user_id_and_parent_id_and_is_master_and_portfolio_id_and_real_estate_property_id_and_client_id(:name =>"Bulk Uploads", :user_id => property.user_id, :parent_id =>-2, :is_master =>1, :portfolio_id => portfolio_for_bulk_upload.id, :real_estate_property_id => property_for_bulk_upload.id,:client_id=>self.client_id)
      folder_year_bulk = Folder.find_or_create_by_name_and_user_id_and_parent_id_and_is_master_and_portfolio_id_and_real_estate_property_id_and_client_id(:name =>"#{Date.today.year}", :user_id => property.user_id, :parent_id =>folder_bulk.id, :is_master =>1,  :portfolio_id => portfolio_for_bulk_upload.id, :real_estate_property_id => property_for_bulk_upload.id,:client_id=>self.client_id)
      12.downto(1).each do |mo|
        Folder.find_or_create_by_name_and_user_id_and_parent_id_and_is_master_and_portfolio_id_and_real_estate_property_id_and_client_id(:name =>"#{Date::MONTHNAMES[mo].slice(0,3)}", :user_id => property.user_id, :parent_id =>folder_year_bulk.id,:is_master =>1, :portfolio_id => portfolio_for_bulk_upload.id, :real_estate_property_id => property_for_bulk_upload.id, :created_at => "#{1.second.since(Folder.last.created_at)}",:client_id=>self.client_id)
      end
    end
  end

  # Overwrite password_required
  def password_required?
    if !is_asset_edit && !ignore_password
      ((!password.blank? and !password.nil?) || (!password_confirmation.blank? and !password_confirmation.nil?)) || true
    else
    false
    end
  end

  def self.find_collaborators(i)
    User.find(:first, :conditions => ["id IN (?)",i.task_collaborators.collect{|u| u.user_id}], :select => "email").email
  end

  def self.user_updates(user,params,asset_manager)
    user.login = params[:user][:email]
    user.email = params[:user][:email]
    user.name = params[:user][:name]
    user.address = params[:user][:address]
    user.phone_number = params[:user][:phone_number]
    user.company_name = params[:user][:company_name]
    user.department = params[:user][:department]
    user.designation = params[:user][:designation]
    user.comment = params[:user][:comment]
    user.is_asset_edit = true
    user.is_asset_manager = true if asset_manager
    user.client_id = Client.current_client_id
    user
  end

  def self.current
    Thread.current[:user]
  end

  def self.current=(user)
    Thread.current[:user] = user
  end

  def self.create_new_user(e,params,sharer_id)
    next if e.strip.scan(/^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i).empty?
    su = User.find_by_email(e.strip)
    su_already = (!su.nil? ? true : false)
    if su_already
      if su.roles.collect {|x| x.name}.include?("Shared User")  && params[:is_lease_agent] == 'true'
        role = Role.find_by_name('Leasing Agent')
      elsif su.roles.collect {|x| x.name}.include?("Asset Manager") && !params[:is_property_folder]
        role = Role.find_by_name('Shared User')
      elsif su.roles.collect {|x| x.name}.include?("Shared User") && params[:is_property_folder] && params[:is_lease_agent] != 'true'
        role = Role.find_by_name('Asset Manager')
        su.update_attribute("selected_role","Asset Manager")
      end
      su.roles << role if !role.nil?

      already_collaborators = Collaborator.find(:all,:conditions=>["(user_1_id = #{sharer_id} and user_2_id = #{su.id}) or (user_1_id = #{su.id} and user_2_id = #{sharer_id})"])
      Collaborator.create(:user_1_id =>sharer_id,:user_2_id=>su.id) if already_collaborators.empty?
    end
    if su.nil?
      su = User.new(:email=>e.strip)
      p = su.generate_password
      su.password = p
      su.password_confirmation =p
      su.is_shared_user = true
      su.password_code = User.random_passwordcode
      su.client_id = User.current.client_id
      su.save
      #To create contacts
      already_collaborators = Collaborator.find(:all,:conditions=>["(user_1_id = #{sharer_id} and user_2_id = #{su.id}) or (user_1_id = #{su.id} and user_2_id = #{sharer_id})"])
      Collaborator.create(:user_1_id =>sharer_id,:user_2_id=>su.id) if already_collaborators.empty?
      if params[:is_lease_agent] == 'true'
        role = Role.find_by_name('Leasing Agent')
        role2 = Role.find_by_name('Shared User')
      elsif (params[:is_lease_agent] == 'true' ? false : ((params[:note_add_edit] == 'true' || params[:is_property_folder] == 'true' || params[:edit_inside_asset] == "true" || params[:from_debt_summary] == "true" || params[:from_property_details] == "true" || params[:call_from_prop_files] == 'true') ? true : false))
        role = Role.find_by_name('Asset Manager')
      else
        role = Role.find_by_name('Shared User')
      end
    su.roles << role
    su.roles << role2 if role2
    end
    return su,su_already
  end

  def self.save_user_values(params)
    user = User.new(params[:user])
    user.is_asset_manager = true
    password = user.generate_password
    user.password , user.password_confirmation , user.login = password , password , params[:user][:email]
    user.client_id = Client.current_client_id
    user.roles << Role.find_by_name('Asset Manager')
    valid_or_not = user.valid?
    if valid_or_not
      user.password_code =  User.random_passwordcode
    user.save
    end
    return [user , valid_or_not]
  end

  def self.save_client_admin_values(params)
    user = User.new(params[:user])
    user.is_set_company = true
    user.designation_check = true
    password = user.generate_password
    user.password , user.password_confirmation , user.login = password , password , params[:user][:email]
    user.client_id = Client.current_client_id
    user.roles << Role.find_by_name('Client Admin')
    user.roles << Role.find_by_name('Asset Manager')
    valid_or_not = user.valid?
    if valid_or_not
      user.password_code =  User.random_passwordcode
    end
    return [user , valid_or_not]
  end

  def self.save_client_admin_user(params,client_id,sharer_id)
    user = User.new(params[:user].reject {|key,value| key == "roles" })
    user.designation_check = true
    password = user.generate_password
    user.password , user.password_confirmation , user.login = password , password , params[:user][:email]
    user_roles=user.roles
    if !(user_roles.map(&:role_id).include?(params[:user][:roles]))
      user_roles<< Role.find(params[:user][:roles])
    end
    valid_or_not = user.valid?
    if valid_or_not
      user.password_code =  User.random_passwordcode
      user.client_id=client_id
      user.selected_role=params[:selected_user]
      user.save
      already_collaborators = Collaborator.find(:all,:conditions=>["(user_1_id = #{sharer_id} and user_2_id = #{user.id}) or (user_1_id = #{user.id} and user_2_id = #{sharer_id})"])
      Collaborator.create(:user_1_id =>sharer_id,:user_2_id=>user.id) if already_collaborators.empty?
    end

    return [user , valid_or_not]
  end

  def self.save_server_admin_values(params)
    user = User.new(params[:user])
    user.is_set_company = true
    password = user.generate_password
    user.password , user.password_confirmation , user.login = password , password , params[:user][:email]
    user.roles << Role.find_by_name('Server Admin')
    user.client_id = Client.current_client_id
    valid_or_not = user.valid?
    if valid_or_not
      user.password_code =  User.random_passwordcode
    end
    return [user , valid_or_not]
  end

  def self.client_admin_update(user,params)
    c_user = User.find_or_create_by_id(user.id)
    if c_user.email != params[:user][:email] && c_user.password_code == nil
      user.login = params[:user][:email]
      user.email = params[:user][:email]
      user.name = params[:user][:name]
      user.company_name = params[:user][:company_name]
      password = user.generate_password
      user.password , user.password_confirmation , user.login = password , password , params[:user][:email]
      if user.valid?
        user.password_code =  User.random_passwordcode
      end
    else
      user.login = params[:user][:email]
      user.email = params[:user][:email]
      user.name = params[:user][:name]
      user.company_name = params[:user][:company_name]
    end
    user.is_asset_edit = true
    user
  end

  def self.new_user(user_data,data,profile_detail,interests)
    user = User.new(user_data)
    user.is_new_user=true
    p=user.generate_password
    user.password ,user.password_confirmation,user.login,user.password_code,user.approval_status= p,p,data,User.random_passwordcode,false
    user.user_profile_detail=UserProfileDetail.new(profile_detail)
    user.user_profile_detail.is_new_user= true
    user.user_profile_detail.interest=interests
    user_valid=user.valid?
    user_profile_valid=user.user_profile_detail.valid?
    if user_valid && user_profile_valid
      role = Role.find_by_name('Asset Manager')
      user.roles << role
      user.client_id = Client.current_client_id
    user.save
    end
    return user
  end

  def check_user_company
    errors.add(:company_name, "Company name already taken") if User.joins(:roles).where(:roles => {:id => 4}).map(&:company_name).include?(self.company_name)
  end

  def create_basic_portfolios_for_client_admin
    roles = self.roles.map(&:name) || []
    if (roles.include?("Client Admin") || roles.include?("Asset Manager"))&& self.client.present? && self.client.chart_of_accounts
      chart_of_accounts = self.client.chart_of_accounts || []

      #chart_of_accounts_count = chart_of_accounts.count
      #        if chart_of_accounts_count.eql?(1)
      #          multifamily_portfolio = Portfolio.create(:name => "All Multifamily", :user_id => self.id, :leasing_type => "Multifamily", :client_id => self.client_id , :is_basic_portfolio => true)
      #          Folder.create(:name => multifamily_portfolio.try(:name), :portfolio_id => multifamily_portfolio.try(:id), :user_id => self.id, :is_master => true, :client_id => self.client_id) if multifamily_portfolio.present?
      #          commercial_portfolio = Portfolio.create(:name => "All Commercial", :user_id => self.id, :leasing_type => "Commercial", :client_id => self.client_id, :is_basic_portfolio => true)
      #          Folder.create(:name => commercial_portfolio.try(:name), :portfolio_id => commercial_portfolio.try(:id), :user_id => self.id, :is_master => true, :client_id => self.client_id) if commercial_portfolio.present?
      #        else
      chart_of_accounts.each_with_index do |chart_of_account, number|
        number += 1
        multifamily_portfolio = Portfolio.create(:name => "All Multifamily #{number}", :user_id => self.id, :leasing_type => "Multifamily", :client_id => self.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
        Folder.create(:name => multifamily_portfolio.try(:name), :portfolio_id => multifamily_portfolio.try(:id), :user_id => self.id,:client_id => self.client_id, :parent_id => -1) if multifamily_portfolio.present?
        commercial_portfolio = Portfolio.create(:name => "All Commercial #{number}", :user_id => self.id, :leasing_type => "Commercial", :client_id => self.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
        Folder.create(:name => commercial_portfolio.try(:name), :portfolio_id => commercial_portfolio.try(:id), :user_id => self.id, :client_id => self.client_id,  :parent_id => -1) if commercial_portfolio.present?
      #end
      end
    end
  end

  def self.save_super_admin_values(params,client_id)
    user = User.new
    user.is_set_company = true
    password = user.generate_password
    user.password , user.password_confirmation , user.login = password , password , params[:user][:email]
    user.client_id = Client.current_client_id
    user.roles << Role.find_by_name('Client Admin')
    user.roles << Role.find_by_name('Asset Manager')
    valid_or_not = user.valid?
    if valid_or_not
      user.password_code =  User.random_passwordcode
    end
    return [user , valid_or_not]
  end

  def self.create_property_and_portfolio(params,user,client_id,client_user_id)
    property_and_portfolio_access={}
    if params[:property].present?
      property_ids=params[:property].values
      property_and_portfolio_access[:property] = property_ids
      property_ids.each do |property_id|
        folder=Folder.find_by_real_estate_property_id_and_client_id(property_id,client_id)
        portfolio,property_check_value,real_estate_property = User.property_check(property_id,client_id,user)
        unless property_check_value
        portfolio.real_estate_properties << real_estate_property
        portfolio.save
        end
        #Shared folder creation starts here
        Portfolio.shared_folder_creation(real_estate_property,property_id,user,client_user_id,client_id)
        #Shared folder creation ends here
        #Code for delayed job for portfolio update starts here#
        Portfolio.update_financial_info(user)
      #Code for delayed job for portfolio update ends here#
      end
    end

    if params[:portfolio].present?
      portfolios_ids=params[:portfolio].values
      property_and_portfolio_access[:portfolio] = portfolios_ids
      portfolios_ids.each do |portfolio_id|
        folder=Folder.find_by_portfolio_id_and_real_estate_property_id(portfolio_id,nil)
        SharedFolder.create(:user_id=>user.id,:folder_id=>folder.id,:sharer_id=>client_user_id,:portfolio_id=>portfolio_id,:is_portfolio_folder=>true,:client_id=>client_id)
        portfolio = Portfolio.find(portfolio_id)
        Portfolio.save_shared_folder(portfolio,user,client_user_id,client_id)
      end
    end

    if params[:user_profile_detail] && params[:user_profile_detail][:title]
      user.create_user_profile_detail(params[:user_profile_detail])
    end
    #send a mail with property and portfolios links
    #~ if (property_and_portfolio_access && (property_and_portfolio_access[:property].present? || property_and_portfolio_access[:portfolio].present?))
    
  #  UserMailer.property_and_portfolio_access_client(user,property_and_portfolio_access,"create").deliver
  
  #~ else
  #~ UserMailer.set_your_password(user,"users").deliver
  #~ end
  end

  def self.property_check(property_id,client_id,user)
    real_estate_property = RealEstateProperty.find_by_id(property_id)
    portfolio=Portfolio.where(["user_id = ? AND leasing_type = ? AND client_id = ? AND chart_of_account_id = ? and is_basic_portfolio = ?",user.id,real_estate_property.leasing_type,client_id,real_estate_property.chart_of_account_id,true]).first
    property_check_boolean = ""
    if portfolio && portfolio.real_estate_properties
      property_check_boolean = portfolio.real_estate_properties.map(&:id).include?(property_id)
    end
    return portfolio,property_check_boolean,real_estate_property
  end

  def self.update_property_and_portfolio(params,user,client_user_id,client_id)
    property_and_portfolio_access={}
    existing_portfolios=SharedFolder.find(:all,:conditions=>["user_id=? AND is_portfolio_folder=? and client_id = ? and real_estate_property_id is NULL",user.id,true,client_id])
    existing_properties=SharedFolder.find(:all,:conditions=>["user_id=? AND is_property_folder=? AND client_id = ?",user.id,true,client_id])
    existing_properties=existing_properties.present? ? existing_properties.map(&:real_estate_property_id) : [ ]
    existing_properties = existing_properties.uniq
    if params[:property].present?
      property_ids=params[:property].values.collect{|id| id.to_i}
      new_properties=property_ids-existing_properties
      delete_properties=existing_properties-property_ids
      delete_properties && delete_properties.each do |delete_property|
        property = RealEstateProperty.find(delete_property)
        property_and_portfolio_access[:property] = new_properties if new_properties.present?
        Portfolio.delete_basic_property_records(user,property.portfolio,client_id,property) if (property.present? && user.shared_folders.where(:portfolio_id =>property.portfolios.map(&:id).uniq,:is_portfolio_folder => true).blank?)
      end
      new_properties && new_properties.each do |property_id|
        folder=Folder.find_by_real_estate_property_id_and_client_id(property_id,client_id)
        portfolio,property_check_value,real_estate_property=User.property_check(property_id,client_id,user)
        unless property_check_value
        portfolio.real_estate_properties << real_estate_property
        portfolio.save
        end
        #Shared folder creation starts here
        Portfolio.shared_folder_creation(real_estate_property,property_id,user,client_user_id,client_id)
        #Shared folder creation ends here
        #Code for delayed job for portfolio update starts here#
        Portfolio.update_financial_info(user)
      #Code for delayed job for portfolio update ends here#
      end
    else
      basic_portfolios=user.portfolios(:all,:conditions=>["is_basic_portfolio = ?",true])
      basic_portfolios.each do |basic_portfolio|
      #~ basic_portfolio.real_estate_property_ids=[]
        basic_portfolio.real_estate_properties.each do |property|
          Portfolio.delete_basic_property_records(user,basic_portfolio,client_id,property) if (property.present? && user.shared_folders.where(:portfolio_id =>property.portfolios.map(&:id).uniq,:is_portfolio_folder => true).blank?)
        end
      #~ basic_portfolio.save
      end
      #Code for delayed job for portfolio update starts here#
      Portfolio.update_financial_info(user)
    #Code for delayed job for portfolio update ends here#
    end

    if params[:portfolio].present?
      portfolios_ids=params[:portfolio].values.collect{|id| id.to_i}
      existing_portfolios=existing_portfolios.present? ? existing_portfolios.map(&:portfolio_id) : [ ]
      new_portfolios=(params[:portfolio].values.collect{|id| id.to_i}) - existing_portfolios
      delete_portfolios=existing_portfolios-portfolios_ids
      delete_portfolios.each do |delete_portfolio|
      #~ folder_delete=SharedFolder.find_by_user_id_and_portfolio_id_and_cliend_id(user.id,delete_portfolio,client_id)
        folder_delete = SharedFolder.find_by_client_id_and_user_id_and_portfolio_id(client_id,user.id,delete_portfolio)
        if folder_delete.present?
          folder_delete.destroy
          delete_portfolio = Portfolio.find(delete_portfolio)
          delete_portfolio_properties = delete_portfolio.real_estate_properties
          delete_portfolio_properties && delete_portfolio_properties.each do |delete_portfolio_property|
            property=RealEstateProperty.find(delete_portfolio_property)
            Portfolio.delete_basic_property_records(user,property.portfolio,client_id,property)
          end
        end
      end
      property_and_portfolio_access[:portfolio] = new_portfolios if new_portfolios.present?
      new_portfolios.each do |portfolio_id|
        folder=Folder.find_by_portfolio_id(portfolio_id)
        is_portfolio_available = SharedFolder.find_by_user_id_and_folder_id_and_sharer_id_and_portfolio_id_and_is_portfolio_folder_and_client_id(user.id,folder.id,client_user_id,portfolio_id,true,client_id)
        SharedFolder.create(:user_id=>user.id,:folder_id=>folder.id,:sharer_id=>client_user_id,:portfolio_id=>portfolio_id,:is_portfolio_folder=>true,:client_id=>client_id) unless is_portfolio_available
        #~ #code to save properties of portfolios
        portfolio = Portfolio.find(portfolio_id)
        portfolio_properties = portfolio.real_estate_properties
        portfolio_properties.each do |portfolio_property|
          portfolio_property_id = portfolio_property.id
          folder_property=Folder.find_by_real_estate_property_id_and_client_id(portfolio_property_id,client_id)
          is_available = SharedFolder.find_by_user_id_and_folder_id_and_sharer_id_and_real_estate_property_id_and_is_property_folder_and_client_id(user.id,folder_property.id,client_user_id,portfolio_property_id,true,client_id)
          portfolio_value,property_check_value,real_estate_property = property_check(portfolio_property,client_id,user)
          unless property_check_value
          portfolio_value.real_estate_properties << real_estate_property
          portfolio_value.save
          end
          unless is_available.present?
            Portfolio.shared_folder_creation(real_estate_property,portfolio_property_id,user,client_user_id,client_id)
          end
        end
      end
    else
      shared_portfolios = SharedFolder.where("user_id=? AND is_portfolio_folder=? and client_id = ? and real_estate_property_id is NULL",user.id,true,client_id)
      existing_properties && existing_properties.each do |property|
        property=RealEstateProperty.find(property)
        Portfolio.delete_basic_property_records(user,property.portfolio,client_id,property)
      end
    shared_portfolios.destroy_all
    end

    if params[:user_profile_detail] && params[:user_profile_detail][:title]
      if user.user_profile_detail.present?
        else
        user.create_user_profile_detail(params[:user_profile_detail])
      end
    end
    #send a mail with property and portfolios links
    if (property_and_portfolio_access && (property_and_portfolio_access[:property].present? || property_and_portfolio_access[:portfolio].present?))
      UserMailer.property_and_portfolio_access_client(user,property_and_portfolio_access,"update").deliver
    end
  end

  def self.client_admin_roles
    asset_manager=Role.find_by_name("Asset Manager").id
    shared_user=Role.find_by_name("Shared User").id
    leasing_agent=Role.find_by_name("Leasing Agent").id
    #~ client_roles={"Asset Manager" => asset_manager,"Property Manager" =>asset_manager, "Portfolio Manager" => asset_manager,"Leasing Agent" => leasing_agent,"Investor" => shared_user,"Accounting Team" => shared_user, "Storage and Chat only" => shared_user, "Other" => shared_user}
    client_roles=[["Asset Manager",asset_manager],["Property Manager",asset_manager],["Portfolio Manager",asset_manager],["Leasing Agent", leasing_agent],["Investor",shared_user],["Accounting Team", shared_user], ["Storage and Chat only", shared_user], ["Other" , shared_user]]
  end

  def self.find_users_of_a_property(property)
    shared_folders = SharedFolder.find_all_by_real_estate_property_id(property.try(:id))
    folders = Folder.find_all_by_real_estate_property_id(property.try(:id))
    user_ids = shared_folders.map(&:user_id).uniq + folders.map(&:user_id).uniq
    users = self.where(:id=>user_ids.uniq)
  end

  def self.shared_folder_creation_basic_portfolio(portfolio,portfolio_property,user_id,sharer_id,client_id)
    #for folder and shared folder creation for basic portfolios start
    folder_for_basic_portfolio = Folder.find_or_create_by_name_and_portfolio_id_and_real_estate_property_id_and_user_id_and_client_id(portfolio_property.property_name,portfolio.id,portfolio_property.id,user_id,portfolio.client_id) if portfolio
    amp_folder_for_basic = Folder.find_by_name_and_portfolio_id_and_real_estate_property_id_and_user_id_and_parent_id_and_is_master("AMP Files",folder_for_basic_portfolio.portfolio_id,portfolio_property.id,user_id,folder_for_basic_portfolio.id,true) if folder_for_basic_portfolio
    Portfolio.amp_create_subfolders_files_for_property_with_portfolio(folder_for_basic_portfolio,portfolio_property) if amp_folder_for_basic.nil?
    #for folder and shared folder creation for basic portfolios end
    shared_folder_for_property = SharedFolder.find_or_create_by_user_id_and_folder_id_and_sharer_id_and_real_estate_property_id_and_is_property_folder_and_client_id_and_portfolio_id(user_id,folder_for_basic_portfolio.id,sharer_id,portfolio_property.id,true,client_id,portfolio.id)

    sub_folders =  Folder.find(:all,:conditions => ["real_estate_property_id = ? and user_id = ? and portfolio_id=? and is_master = ?",folder_for_basic_portfolio.real_estate_property_id,folder_for_basic_portfolio.user_id,folder_for_basic_portfolio.portfolio_id,true])
    sub_folder_shared = sub_folders.uniq
    Portfolio.share_sub_folders_while_sharing_folder(sub_folder_shared,shared_folder_for_property) if sub_folder_shared
    document_collection = Document.where(:real_estate_property_id => folder_for_basic_portfolio.real_estate_property_id,:is_deleted => false)
    documents = document_collection.uniq
    Portfolio.share_sub_docs_while_sharing_folder(documents,shared_folder_for_property) if documents

  end

end
