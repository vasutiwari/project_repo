class RealEstateProperty < ActiveRecord::Base
  attr_accessor :check_property_size,:check_gross_land_area,:check_gross_rentable_area,:check_no_of_units,:check_year_built,:check_property_name,:check_city,:check_state,:check_zip,:check_property_description,:check_address,:check_purchase_price,:check_validation, :is_field_exists,:no_validation_needed, :add_property_validity, :check_prop_name_validation,:remote_property_validation

  #Relationships
  has_many :folders, :dependent=>:destroy
  has_many :documents, :dependent=>:destroy
  has_many :property_occupancy_summaries
  has_many :property_suites
  has_many :leases
  has_many :lease_rent_rolls, :dependent=>:destroy
  has_many :property_debt_summaries
  has_many :property_capital_improvements
  belongs_to :state
  belongs_to :user
  #belongs_to :portfolio
  has_and_belongs_to_many :portfolios
  belongs_to :property_type
  has_one :portfolio_image, :as=> :attachable
  belongs_to :address
  has_one :variance_threshold
  has_one :accounting_system_type
  has_many :executed_leases, :class_name => "Lease", :conditions => "leases.is_executed=true and leases.is_archived=false and (leases.status!='Inactive' or leases.status IS NULL)"
  has_many :executed_leases_archeived, :class_name => "Lease", :conditions => "leases.is_executed=true and (leases.is_archived=true or leases.status = 'Inactive')"
  has_many :non_executed_leases, :class_name => "Lease", :conditions => "leases.is_executed=false and leases.status!='Inactive'"
  has_many :negotiation_leases_six_mnth_exp, :class_name => "Lease", :conditions => "leases.is_approval_requested=true and leases.is_archived=false and leases.commencement <='#{Date.today}' and leases.expiration >='#{Date.today}' and leases.expiration <='#{(Date.today+182)}' and leases.status IS NOT NULL"
  has_many :negotiation_leases_other, :class_name => "Lease", :conditions => "leases.is_executed=false and leases.is_approval_requested=true and leases.is_archived=false and leases.status IS NOT NULL"
  has_many :interested_prospects_leases, :class_name => "Lease", :conditions => "leases.is_executed=false and leases.is_approval_requested=false and leases.is_archived=false and leases.status IS NOT NULL"
  has_many :interested_prospects_leases_archeived, :class_name => "Lease", :conditions => "leases.is_executed=false and leases.is_approval_requested=false and (leases.is_archived=true or leases.status = 'Inactive')"
  has_many :interested_prospects_leases_six_month_exp, :class_name => "Lease", :conditions => "leases.is_executed=true and leases.is_archived=false and leases.is_approval_requested=false and leases.commencement <='#{Date.today}' and leases.expiration >='#{Date.today}' and leases.expiration <='#{(Date.today+182)}' and leases.status IS NOT NULL"

  has_many :six_month_expiration_leases, :class_name => "Lease", :conditions => "leases.is_executed=true and leases.is_archived=false and leases.commencement <='#{Date.today}' and leases.expiration >='#{Date.today}' and leases.expiration <='#{(Date.today+182)}' and leases.status IS NOT NULL",:order=>"leases.expiration ASC"

  has_many :suites
  has_many :vacant_suites, :class_name => "Suite", :conditions => "suites.status='vacant'"
  has_many :commercial_lease_occupancies
  has_many :leasing_budgets
  has_many    :assets, :as => :assetable, :class_name => "Ckeditor::Asset"
  accepts_nested_attributes_for :address

  before_destroy { portfolios.clear }
  #Scope to find the portflios based on client admin ids

 scope :by_client_ids, (lambda do |client_id,type,chart,user_id|
    {:conditions => ['client_id = ? and leasing_type = ? and chart_of_account_id=? and property_name NOT in (?) and user_id = ?', client_id,type,chart,["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"],user_id]} #added current user id to dispaly the properties created by the current client admin.in future single client can have multiple client admin.#
  end)

  scope :property_client_ids, (lambda do |client_id,user_id,leasing_type|
    {:conditions => ['client_id = ? and user_id = ? and property_name NOT in (?) and leasing_type = ?', client_id,user_id,["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"],leasing_type]}
  end)

  #To find other properties
    scope :find_other_properties, (lambda do |users_properties|
    {:select=>[:id,:property_name],:conditions => ["id in (?) and property_name NOT in (?)",users_properties,["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"]]}
  end)




  before_save :modify_permalink
  after_create :create_permalink
  scope :properties_of_portfolio_ids , lambda { |args| {:conditions=>["portfolios.id in (#{args.join(',')}) and real_estate_properties.user_id = #{User.current.id}"], :select=>"real_estate_properties.id",:joins=>:portfolios} }
  validates_presence_of :property_name ,:message => "Can't be blank"  ,:if => Proc.new { |property| (property.check_prop_name_validation != false && property.no_validation_needed != 'true') }
  validates_uniqueness_of :property_name, :scope => [:user_id] ,:message => "Note Id already exists" ,:if => Proc.new { |property| (property.check_prop_name_validation != false && property.no_validation_needed != 'true') }
  validates_presence_of :occupancy ,:message => "Can't be blank" ,:if => Proc.new { |property| (property.check_validation == "no" && property.add_property_validity != "no"  && property.no_validation_needed != 'true' ) }
  validates_presence_of :annualized_noi ,:message => "Can't be blank" ,:if => Proc.new { |property| (property.check_validation == "no" && property.add_property_validity != "no"  && property.no_validation_needed != 'true') }
  validates_presence_of :property_size ,:message => "Can't be blank" ,:if => Proc.new { |property| (property.add_property_validity != "no"  && property.no_validation_needed != 'true') }
  validates_presence_of :gross_land_area ,:message => "Can't be blank",:if => Proc.new { |property| (property.check_validation != "no" && property.add_property_validity != "no"  && property.no_validation_needed != 'true') }
  validates_presence_of :gross_rentable_area ,:message => "Can't be blank" ,:if => Proc.new { |property| (property.check_validation != "no" && property.add_property_validity != "no"  && property.no_validation_needed != 'true') }
  validates_presence_of :no_of_units ,:message => "Can't be blank"  ,:if => Proc.new { |property| (property.check_validation != "no" && property.add_property_validity != "no"  && property.no_validation_needed != 'true' ) }
  validates_presence_of :year_built ,:message => "Can't be blank"  ,:if => Proc.new { |property| (property.check_validation != "no" && property.add_property_validity != "no"  && property.no_validation_needed != 'true') }
  validates_presence_of :property_description ,:message => "Can't be blank" ,:if => Proc.new { |property| (property.check_validation != "no" && property.add_property_validity != "no"  && property.no_validation_needed != 'true') }
  validates_presence_of :purchase_price    ,:message => "Can't be blank" ,:if => Proc.new { |property| (property.check_validation != "no" && property.add_property_validity != "no"  && property.no_validation_needed != 'true') }
  validates_presence_of :property_code    ,:message => "Can't be blank" ,:if => Proc.new { |property| (property.remote_property_validation) }
  validates_presence_of :remote_property_name,:message => "Can't be blank" ,:if => Proc.new { |property| (property.remote_property_validation) }
  #validates_uniqueness_of :property_code, :message => "Property code has already taken", :allow_nil => true, :allow_blank=>true

MONTH = [
  [ "January", "1" ],
  [ "February", "2" ],
  [ "March", "3" ],
  [ "April", "4" ],
  [ "May", "5" ],
  [ "June", "6" ],
  [ "July", "7" ],
  [ "August", "8" ],
  [ "September", "9" ],
  [ "October", "10" ],
  [ "November", "11" ],
  [ "December", "12" ]
  ]

YEAR = [
  [ "2010", "2010" ],
  [ "2011", "2011" ],
  [ "2012", "2012" ]
  ]

def self.one_time_script_for_making_portfolio_id_as_nil
        RealEstateProperty.all.each do |real_estate_property|
          portfolio_id = real_estate_property.portfolio_id
          if portfolio_id.present?
            portfolio = Portfolio.find_by_id(portfolio_id)
            if portfolio.present?
              real_estate_property.portfolios << portfolio
              if real_estate_property.save(false)
                real_estate_property.update_attribute(:portfolio_id, nil)
              end
            end
          end
        end
        nil
end

  def create_permalink
    save_permalink
    self.save
  end

  def modify_permalink
    save_permalink
  end

  def save_permalink
    companyname= (self.user.nil? or self.user.company_name.nil?) ?  "-" :  self.user.company_name.gsub(/[^a-z0-9]+/i, '-')
    assetname= (self.property_name.nil?) ? "-" : self.property_name.gsub(/[^a-z0-9]+/i, '-')
    prop_id=self.nil? ? "-" : self.id
    self.permalink="/listing/#{companyname}/#{assetname}/#{prop_id}"
  end

  #added to get real estate property's address from address table
  def city
    (self.is_field_exists) ? self[:city] : (self.address.nil? ? '' : self.address.city.nil? ? '' : self.address.city)
  end

  def province
    (self.is_field_exists) ? self[:province] : (self.address.nil?  ? '' : self.address.province.nil? ? '' : self.address.province)
  end

  def zip
    (self.is_field_exists) ? self[:zip] : (self.address.nil? ? '' : self.address.zip.nil? ? '' : self.address.zip)
  end

  def desc
    self.address.nil? ? '' : self.address.txt.nil? ? '' : self.address.txt
  end

  def self.note_find(id)
    RealEstateProperty.find_real_estate_property(id)
  end

  #save_and_send_exp_mail_to_collabrators start
  def save_and_send_exp_mail_to_collabrators(params,property)
    if params[:selected_users] && !params[:selected_users].empty?
      property.no_validation_needed ='true'
      property.update_attributes(:var_exp_users=>params[:selected_users].keys.join(',').to_s)
    else
      property.no_validation_needed ='true'
      property.update_attributes(:var_exp_users=>'')
    end
    property.save
  end
  #save_and_send_exp_mail_to_collabrators end

  #stores basic tab details
  def create_real_estate_property(name,pid,property_type_id,user_id,remote_name,property_code)
    self.property_name =  name
    #self.portfolio_id = pid
    self.property_type_id = property_type_id
    self.user_id = user_id
    self.add_property_validity = "no"
    self.check_validation == "no"
    self.remote_property_name =  remote_name
    self.property_code =  property_code
    self.client_id = Client.current_client_id
  end

  #stores property tab details
  def create_property_details(params)
    self.check_prop_name_validation = false
    self.property_size = params[:real_estate_property][:property_size]
    self.purchase_price = params[:real_estate_property][:purchase_price]
    self.gross_land_area = params[:real_estate_property][:gross_land_area]
    self.no_of_units = params[:real_estate_property][:no_of_units]
    self.property_description = params[:real_estate_property][:property_description]
    self.gross_rentable_area = params[:real_estate_property][:gross_rentable_area]
    self.year_built = params[:real_estate_property][:year_built]
    self.save
  end

  #find real_estate_property
  def self.find_real_estate_property(id,from_portfolio = nil)
    if id && User.current.present?
      property =  RealEstateProperty.find_by_sql("select r.* from real_estate_properties r left join shared_folders s on s.real_estate_property_id = r.id where ((s.is_property_folder = 1 and s.user_id = #{User.current.id} and s.client_id = #{User.current.client_id} ) or (r.user_id = #{User.current.id} and r.client_id = #{User.current.client_id})) and r.id IN (#{id.class.eql?(Array) ? id.join(',') : id})")
      return property if property && from_portfolio.present?
    elsif id  &&  User.current.blank?
      real_estate_property = RealEstateProperty.find_by_id(id)
      user = real_estate_property.user
      property =  RealEstateProperty.find_by_sql("select r.* from real_estate_properties r left join shared_folders s on s.real_estate_property_id = r.id where ((s.is_property_folder = 1 and s.user_id = #{user.id} and s.client_id = #{user.client_id} ) or (r.user_id = #{user.id} and r.client_id = #{user.client_id})) and r.id IN (#{id.class.eql?(Array) ? id.join(',') : id})")
    end
    return property if property && from_portfolio.present?
    return property[0] if property
  end

  def self.find_user_properties(id,user_id)
    user = User.find_by_id(user_id)
    portfolio = Portfolio.find_by_id(id)
    portfolio.real_estate_properties.where(:user_id=>user_id, :client_id=>user.client_id).order("created_at DESC")
  end

  def self.find_properties_of_portfolio(id)
    portfolio = Portfolio.find_by_id(id)
    #~ portfolio.real_estate_properties.find_by_sql("select r.* from real_estate_properties r left join shared_folders s on s.real_estate_property_id = r.id where ((s.is_property_folder = 1 and s.user_id = #{User.current.id} and s.client_id = #{User.current.client_id} ) or (r.user_id = #{User.current.id} and r.client_id = #{User.current.client_id})) and r.property_name not in ('property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload')") if id
    self.joins("left outer join shared_folders on shared_folders.real_estate_property_id=real_estate_properties.id", :portfolios).where("(shared_folders.is_property_folder = 1 and shared_folders.user_id = #{User.current.id} and shared_folders.client_id = #{User.current.client_id} ) or (real_estate_properties.user_id = #{User.current.id} and real_estate_properties.client_id = #{User.current.client_id} and real_estate_properties.property_name not in ('property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload'))").where("portfolios_real_estate_properties.portfolio_id=#{id}") if portfolio
  end

  def self.find_owned_and_shared_properties(portfolio,user_id,prop_folder=nil)
    notes =[]
    user_client_id = User.find(user_id).client_id
    if @portfolio_index
      notes =  RealEstateProperty.find(:all, :conditions=>["portfolios.id=? and real_estate_properties.user_id = ? and property_name not in (?) AND real_estate_properties.client_id = #{user_client_id}",portfolio.id,user_id,["property_created_by_system","property_created_by_system_for_deal_room"]],:joins=>:portfolios, :order=> "real_estate_properties.created_at desc")
    else
      notes = RealEstateProperty.find_user_properties(portfolio.id,user_id) if !portfolio.id.nil?
    end
    # note = RealEstateProperty.find_by_id_and_portfolio_id(property_id,portfolio.id) if !portfolio.id.nil?
    if portfolio.user_id != user_id ||  prop_folder == "true" || prop_folder == true
      @shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{user_id } AND client_id = #{user_client_id})")
      notes += RealEstateProperty.find(:all, :conditions=>['portfolios.id=? and real_estate_properties.id in (?)', portfolio.id,@shared_folders.collect {|x| x.real_estate_property_id}],:joins=>:portfolios, :order=> "real_estate_properties.created_at desc") if !(portfolio.id.nil? || portfolio.id.blank? || @shared_folders.nil? || @shared_folders.blank?)
    end
    return notes
  end

  #To find lease agents
  def self.find_lease_agents(property_id,current_user_id)
    @folder = Folder.find_by_real_estate_property_id_and_is_master_and_parent_id(property_id,0,0)
    @lease_agents = SharedFolder.find(:all,:conditions=>["folder_id = ?",@folder.id]).collect{|sf| sf.user if sf.user.has_role?("Leasing Agent") && sf.user.id != current_user_id}.compact
    return @folder,@lease_agents
  end

  def self.find_note(portfolio,current_user)
    @notes = RealEstateProperty.find_owned_and_shared_properties(portfolio,current_user.id,true)
    @note = @notes.first if @notes && !@notes.empty?
  end

  def self.change_is_closed(property_id)
    a = RealEstateProperty.find_real_estate_property(property_id)
    a.is_getting_started_closed=1
    a.save(false)
  end

  def get_property_address(address)
    @address = []
    if address.present?
      @address << address.try(:txt) if address.try(:txt).present?
      @address << address.try(:city) if address.try(:city).present?
      @address << address.try(:province) if address.try(:province).present?
      @address << address.try(:zip) if address.try(:zip).present?
      @address = @address.join(",") if @address.present?
    end
    @address
  end

  #to find properties by portfolio id
  def self.find_properties_by_portfolio_id(id)
    portfolio = Portfolio.find_by_id(id)

    #~ portfolio.real_estate_properties.find_by_sql("select r.* from real_estate_properties r left join shared_folders s on s.real_estate_property_id = r.id where ((s.is_property_folder = 1 and s.user_id = #{User.current.id} and s.client_id = #{User.current.client_id} ) or (r.user_id = #{User.current.id} and r.client_id = #{User.current.client_id}))") if id

    #~ self.joins("left outer join shared_folders on shared_folders.real_estate_property_id=real_estate_properties.id", :portfolios).where("portfolios_real_estate_properties.portfolio_id=#{id} and real_estate_properties.user_id = #{User.current.id} and real_estate_properties.client_id = #{User.current.client_id}") if portfolio

    self.joins("left outer join shared_folders on shared_folders.real_estate_property_id=real_estate_properties.id", :portfolios).where("portfolios_real_estate_properties.portfolio_id=#{id} and (real_estate_properties.user_id = #{User.current.id} or shared_folders.user_id = #{User.current.id} ) and real_estate_properties.client_id = #{User.current.client_id}") if portfolio

  end

     #to find properties by portfolio id with some conditions
  def self.find_properties_by_portfolio_id_with_cond(id,condition,order)
    portfolio = Portfolio.find_by_id(id)
    created_at = order.include?("created_at desc")
    limit = order.include?("limit 1")
    if id && created_at && limit
       real_estate_properties = self.joins("left outer join shared_folders on shared_folders.real_estate_property_id=real_estate_properties.id", :portfolios).where("portfolios_real_estate_properties.portfolio_id=#{id} and (real_estate_properties.user_id = #{User.current.id} or shared_folders.user_id = #{User.current.id} ) and real_estate_properties.client_id = #{User.current.client_id}  and real_estate_properties.property_name  not in ('property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload')  ").order("created_at desc").limit(1) if portfolio
    elsif id && created_at
       real_estate_properties = self.joins("left outer join shared_folders on shared_folders.real_estate_property_id=real_estate_properties.id", :portfolios).where("portfolios_real_estate_properties.portfolio_id=#{id} and (real_estate_properties.user_id = #{User.current.id} or shared_folders.user_id = #{User.current.id} ) and real_estate_properties.client_id = #{User.current.client_id}  and real_estate_properties.property_name  not in ('property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload')  ").order("created_at desc").uniq if portfolio
    else
      real_estate_properties = self.joins("left outer join shared_folders on shared_folders.real_estate_property_id=real_estate_properties.id", :portfolios).where("portfolios_real_estate_properties.portfolio_id=#{id} and (real_estate_properties.user_id = #{User.current.id} or shared_folders.user_id = #{User.current.id} ) and real_estate_properties.client_id = #{User.current.client_id}  and real_estate_properties.property_name  not in ('property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload')  ").uniq if portfolio
    end
    real_estate_properties
   end

  #to find the shared clients of properties in a portfolio
  def self.find_shared_clients(property_id,portfolio_id)
    if property_id.nil?
      property_client_ids = Portfolio.find_by_id(portfolio_id).real_estate_properties.map(&:client_id) #TO add owner's client_id
      client_ids = SharedFolder.includes(:folder).where("folders.portfolio_id=#{portfolio_id} and shared_folders.user_id = #{User.current.id}").map(&:client_id)
      client_ids = property_client_ids + client_ids
    else
      property = RealEstateProperty.find_by_id_and_client_id(property_id,User.current.client_id)
      client_ids = SharedFolder.includes(:folder).where("folders.real_estate_property_id=#{property_id} and shared_folders.user_id = #{User.current.id}").map(&:client_id).uniq
      client_ids << property.client_id if property#TO add owner's client_id
    end
    client_ids.flatten.compact.uniq.present? ?  "and client_id in (#{client_ids.flatten.compact.uniq.join(',')})" : ""
  end


  def self.find_owned_and_shared_properties_of_a_user(user_id,prop_folder=true)
    notes =[]
    user_client_id = User.find(user_id).client_id

    notes =  RealEstateProperty.where("user_id = ? and property_name not in (?) AND client_id = #{user_client_id}", user_id,["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"]).sort_by(&:created_at).reverse

    # note = RealEstateProperty.find_by_id_and_portfolio_id(property_id,portfolio.id) if !portfolio.id.nil?

    if prop_folder.eql?(true)
      @shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{user_id } AND client_id = #{user_client_id})")
      notes += RealEstateProperty.where('id in (?)', @shared_folders.collect {|x| x.real_estate_property_id}).sort_by(&:created_at).reverse if !(@shared_folders.nil? || @shared_folders.blank?)
    end
    return notes
  end

def self.find_shared_properties_of_a_user(user_id)
    user_client_id = User.find(user_id).client_id
    @shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{user_id } AND client_id = #{user_client_id})")
    notes = RealEstateProperty.where('id in (?)', @shared_folders.collect {|x| x.real_estate_property_id}).sort_by(&:created_at).reverse if !(@shared_folders.nil? || @shared_folders.blank?)
    return notes
end

def self.update_shared_properties_of_client_admin
  IncomeAndCashFlowDetail.transaction do
    users = User.find(:all, :conditions=>['email in (?)', ['swigamp@gmail.com','wresamp@gmail.com','kwilliams.amp@gmail.com']])
    users.each do |user|
      if user.present?
        portfolio_collect = user.try(:portfolios).where("portfolios.user_id = #{user.id} and portfolios.name NOT LIKE '%portfolio_created_by_system%' and is_basic_portfolio = true")
        portfolio_collect.each do |portfolio|
          for year in 2010..Date.today.year
            if portfolio.leasing_type.eql?("Commercial")
              Portfolio.delay.portfolio_ic(portfolio.id, year)
              Portfolio.delay.portfolio_pci(portfolio.id,0,year)
            elsif portfolio.leasing_type.eql?("Multifamily")
              Portfolio.delay.portfolio_ic(portfolio.id, year)
            end
          end
        end
      end
    end
  end
end


  # included all table sto find top tenants#
  #~ def self.top_ten_tenants(property)
  #~ top_tenants={}
  #~ tenants,suites_sqft = [],[]
  #~ executed_leases = property.try(:executed_leases)
  #~ executed_leases.includes(:property_lease_suite).each do |executed_lease|
  #~ prop_lease_suite = executed_lease.try(:property_lease_suite)
  #~ suite_ids = prop_lease_suite.try(:suite_ids).try(:compact)
  #~ suites = Suite.where(:id=>suite_ids)

  #~ rentable_sqft = suites.sum(:rentable_sqft)
  #~ tenant = prop_lease_suite.try(:tenant).try(:tenant_legal_name)
  #~ new_hash =  Hash[rentable_sqft, tenant]

  #~ top_tenants.merge!(new_hash)

  #~ end
  #~ final_array  =  top_tenants.sort.reverse.first(10)
  #~ return final_array

  #~ end

  # fetched the top ten tenants from lease rent roll table#
  def self.top_tenants_from_lease_rent_roll(property)
    year = property.try(:lease_rent_rolls).map(&:year).compact.max
    month = property.try(:lease_rent_rolls).where(:year=> year).map(&:month).compact.max
    #~ top_tenants = property.lease_rent_rolls.includes(:lease).where("leases.is_executed = ? and lease_rent_rolls.month = ? and lease_rent_rolls.year = ?", true,month,year).uniq.sort_by(&:sqft).reverse

   # top_tenants = LeaseRentRoll.includes(:lease).select("lease_rent_rolls.tenant,lease_rent_rolls.lease_end_date,lease_rent_rolls.lease_id,sum(lease_rent_rolls.sqft) as lease_rent_roll_sqft ,sum(lease_rent_rolls.base_rent_annual_psf) as lease_rent_roll_base_rent_annual_psf").where("leases.is_executed = ? and lease_rent_rolls.month = ? and lease_rent_rolls.year = ?", true,month,year).group_by(&:lease_id)

    top_tenants = LeaseRentRoll.joins(:lease).select("leases.is_executed, lease_rent_rolls.lease_end_date, lease_rent_rolls.real_estate_property_id as real_estate_property_id, lease_rent_rolls.tenant,lease_rent_rolls.lease_id,sum(lease_rent_rolls.sqft) as lease_rent_roll_sqft ,sum(lease_rent_rolls.base_rent_annual_psf) as lease_rent_roll_base_rent_annual_psf, count(lease_rent_rolls.lease_end_date) as count,sum((lease_rent_rolls.sqft * lease_rent_rolls. base_rent_annual_psf)) as psfsql").where("leases.is_executed = ? and lease_rent_rolls.occupancy_type = 'current' and lease_rent_rolls.month = ? and lease_rent_rolls.year = ? and lease_rent_rolls.real_estate_property_id = ?", true,month,year, property.id).group(:lease_id).order("lease_rent_roll_sqft desc")

    top_ten_tenants =  top_tenants.first(10)

    return top_tenants, top_ten_tenants
  end
  #For find_Upcoming_ten_Expirations for property info
  def self.find_Upcoming_ten_Expirations(property)
    year = property.try(:lease_rent_rolls).map(&:year).compact.max
    month = property.try(:lease_rent_rolls).where(:year=> year).map(&:month).compact.max

    #~ upcoming_expiration_leases = property.lease_rent_rolls.includes(:lease,:suite).where("leases.is_executed = ? and suites.status !='vacant' and lease_rent_rolls.occupancy_type != 'expirations' and leases.expiration>= ? and lease_rent_rolls.month = ? and lease_rent_rolls.year = ?",true,Time.now.strftime('%Y-%m-%d'),month,year).uniq.sort_by(&:lease_end_date).first(10) # .order("CAST(leases.expiration AS SIGNED)ASC").limit(10)


     upcoming_expiration_leases = LeaseRentRoll.joins(:lease,:suite).select("leases.is_executed, lease_rent_rolls.lease_end_date as lease_end_date, lease_rent_rolls.real_estate_property_id as real_estate_property_id, lease_rent_rolls.tenant,lease_rent_rolls.lease_id,sum(lease_rent_rolls.sqft) as lease_rent_roll_sqft ,sum(lease_rent_rolls.base_rent_annual_psf) as lease_rent_roll_base_rent_annual_psf, count(lease_rent_rolls.lease_end_date) as count,sum((lease_rent_rolls.sqft * lease_rent_rolls. base_rent_annual_psf)) as psfsql").where("leases.is_executed = ? and suites.status !='vacant' and lease_rent_rolls.occupancy_type != 'expirations' and leases.expiration>= ? and lease_rent_rolls.month = ? and lease_rent_rolls.year = ? and lease_rent_rolls.real_estate_property_id = ?", true,Time.now.strftime('%Y-%m-%d'),month,year, property.id).group(:lease_id).order("lease_end_date asc").first(10)

    return upcoming_expiration_leases
  end

  def self.get_last_week_dates
    @dates, @date_array, @date_month  = [], [], []
    y = (Time.now.to_date-Time.now.wday)
    x = y - 13.weeks
    # x = Date.new(Time.now.year,01,01).sunday()
    (x..y).each do |date|
      next unless date.strftime("%A") == 'Sunday'
      @dates << date
      @date_array << date.day
      @date_month << date.strftime("%b")
    end
    [@dates, @date_array, @date_month]
  end

 def portfolio
    selected_portfolio = portfolios.where(:user_id=>User.current.id, :client_id=>User.current.client_id).first   if User.current
    selected_portfolio = portfolios.where(:client_id=>User.current.client_id).first if  User.current && selected_portfolio.blank?
    selected_portfolio = portfolios.first  if selected_portfolio.blank?
  selected_portfolio
 end

 def portfolio_id
   portfolio.try(:id)
 end

  def self.find_or_create_by_user_id_and_property_name_and_portfolio_id_and_client_id(user_id,property_created_by_system, portfolio_id,client_id)
		portfolio = Portfolio.find_by_id(portfolio_id)
    property = self.find_by_user_id_and_property_name_and_client_id(user_id,property_created_by_system,client_id)
    property = property.present? ? property : RealEstateProperty.new(:user_id=>user_id, :property_name=>property_created_by_system, :client_id=>client_id)
    if property.new_record?
      property.save
			property.portfolios << portfolio if portfolio
		  property.save
  	else
	  	portfolio_property = property.portfolios.map(&:id).include?(portfolio_id)
      if portfolio_property.blank?
		  property.portfolios << portfolio if portfolio
		  property.save
		end
  end
  return property
end

 def self.add_properties_to_basic_portfolio_for_wresamp
        user = User.find_by_email("wresamp@gmail.com")
        client_id = user.client_id
        properties = user.real_estate_properties.where("property_name NOT in (?)",["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"])
        chart_of_accounts = user.client.chart_of_accounts || []
        chart_of_accounts.each_with_index do |chart_of_account, number|
          number += 1
          multifamily_portfolio = Portfolio.create(:name => "All Multifamily #{number}", :user_id => user.id, :leasing_type => "Multifamily", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
          Folder.create(:name => multifamily_portfolio.try(:name), :portfolio_id => multifamily_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if multifamily_portfolio.present?
          commercial_portfolio = Portfolio.create(:name => "All Commercial #{number}", :user_id => user.id, :leasing_type => "Commercial", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
          Folder.create(:name => commercial_portfolio.try(:name), :portfolio_id => commercial_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if commercial_portfolio.present?
        end
        user_id=user.id
        sql = ActiveRecord::Base.connection();
        properties.each do |property|
          chart_of_account_id = property.chart_of_account_id
          portfolio = Portfolio.where(:chart_of_account_id => chart_of_account_id,:leasing_type =>property.leasing_type,:user_id => user_id,:is_basic_portfolio => true)
          portfolio_id =  portfolio.present? ? portfolio.first.id : ''
          sql.execute("INSERT INTO portfolios_real_estate_properties (portfolio_id,real_estate_property_id) VALUES('#{portfolio_id}','#{property.id}')") if portfolio_id.present?
        end
      end

  def self.add_properties_to_basic_portfolio_for_swigamp
        user = User.find_by_email("swigamp@gmail.com")
        client_id = user.client_id
        properties = user.real_estate_properties.where("property_name NOT in (?)",["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"])
        user_id=user.id
        sql = ActiveRecord::Base.connection();
        properties.each do |property|
          chart_of_account_id = property.chart_of_account_id
          portfolio = Portfolio.where(:chart_of_account_id => chart_of_account_id,:leasing_type =>property.leasing_type,:user_id => user_id,:is_basic_portfolio => true)
          portfolio_id =  portfolio.present? ? portfolio.first.id : ''
          sql.execute("INSERT INTO portfolios_real_estate_properties (portfolio_id,real_estate_property_id) VALUES('#{portfolio_id}','#{property.id}')") if portfolio_id.present?
        end
      end

  def self.add_properties_to_basic_portfolio_for_kwilliams
    Portfolio.transaction do
      user = User.find_by_email("kwilliams.amp@gmail.com")
      client_id = user.client_id
      properties = user.real_estate_properties.where("property_name NOT in (?)",["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"])
      chart_of_accounts = user.client.chart_of_accounts || []
      chart_of_accounts.each_with_index do |chart_of_account, number|
        number += 1
        multifamily_portfolio = Portfolio.create(:name => "All Multifamily #{number}", :user_id => user.id, :leasing_type => "Multifamily", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
        Folder.create(:name => multifamily_portfolio.try(:name), :portfolio_id => multifamily_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if multifamily_portfolio.present?
        commercial_portfolio = Portfolio.create(:name => "All Commercial #{number}", :user_id => user.id, :leasing_type => "Commercial", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
        Folder.create(:name => commercial_portfolio.try(:name), :portfolio_id => commercial_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if commercial_portfolio.present?
      end
      sql = ActiveRecord::Base.connection();
      properties.each do |property|
        chart_of_account_id = property.chart_of_account_id
        portfolio = Portfolio.where(:chart_of_account_id => chart_of_account_id,:leasing_type =>property.leasing_type,:user_id => user.id,:is_basic_portfolio => true)
        portfolio_id =  portfolio.present? ? portfolio.first.id : ''
        sql.execute("INSERT INTO portfolios_real_estate_properties (portfolio_id,real_estate_property_id) VALUES('#{portfolio_id}','#{property.id}')") if portfolio_id.present?
      end
    end
  end

  def self.update_chart_of_accounts_for_real_estate_properties_basing_on_accounting_system_id_and_chart_of_account_id_client_5
    ChartOfAccount.transaction do
      RealEstateProperty.transaction do
        client = Client.find 5
        accounting_system_type_ids,acc_sys_type_name=[],nil
        client.users.each do |user|
          accounting_system_type_ids << user.real_estate_properties.where("property_name NOT like ?", "property_created_by%").map(&:accounting_system_type_id)
        end
        accounting_system_type_ids = accounting_system_type_ids.flatten.uniq.compact
        client.accounting_system_type_ids = accounting_system_type_ids
        client.save(:validate => false)
            accounting_system_type_ids.each do |acc_sys_id|
              acc_sys_type_name = AccountingSystemType.find_by_id(acc_sys_id).try(:type_name)
              if acc_sys_type_name.eql?('MRI, SWIG')
                ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'Mri_swig_kwilliams_chart_of_account', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
              elsif acc_sys_type_name.eql?('Real Page')
                ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'Yardi_kwilliams_chart_of_account', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
              elsif acc_sys_type_name.eql?('AMP Excel')
                ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'amp_kwilliams_chart_of_account', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
              end
            end if accounting_system_type_ids.present?
        users = client.users
        users.each do |user|
          properties = user.real_estate_properties.where("accounting_system_type_id IS NOT NULL and property_name NOT like ?", "property_created_by%")
          properties.each do |property|
            chart_of_account =  ChartOfAccount.find_by_client_id_and_accounting_system_type_id(user.client_id,property.accounting_system_type_id)
            property.chart_of_account_id = chart_of_account.id
            property.save(:validate => false)
          end
        end
      end
    end
  end

  def self.update_chart_of_accounts_for_real_estate_properties_basing_on_accounting_system_id_and_chart_of_account_id
    ChartOfAccount.transaction do
      RealEstateProperty.transaction do
        client = Client.first
        accounting_system_type_ids,acc_sys_type_name=[],nil
        client.users.each do |user|
          accounting_system_type_ids << user.real_estate_properties.where("property_name NOT like ?", "property_created_by%").map(&:accounting_system_type_id)
        end
        accounting_system_type_ids = accounting_system_type_ids.flatten.uniq.compact
        client.accounting_system_type_ids = accounting_system_type_ids
        client.save(:validate => false)
            accounting_system_type_ids.each do |acc_sys_id|
              acc_sys_type_name = AccountingSystemType.find_by_id(acc_sys_id).try(:type_name)
              if acc_sys_type_name.eql?('MRI, SWIG')
                ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'Amp Technology Commercial', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
              elsif acc_sys_type_name.eql?('Real Page')
                ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'Amp Technology Multifamily', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
              elsif acc_sys_type_name.eql?('AMP Excel')
                ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'Amp Technology AMP Excel', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
              elsif acc_sys_type_name.eql?('MRI')
                ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'Amp Technology MRI Commercial', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
              elsif acc_sys_type_name.eql?('YARDI V1')
                ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'Amp Technology YARDI V1', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
              end
            end if accounting_system_type_ids.present?
        users = client.users
        users.each do |user|
          properties = user.real_estate_properties.where("accounting_system_type_id IS NOT NULL and property_name NOT like ?", "property_created_by%")
          properties.each do |property|
            chart_of_account =  ChartOfAccount.find_by_client_id_and_accounting_system_type_id(user.client_id,property.accounting_system_type_id)
            property.chart_of_account_id = chart_of_account.id
            property.save(:validate => false)
          end
        end
      end
    end
  end

  def self.create_chart_of_accounts_for_metro
    ChartOfAccount.transaction do
      RealEstateProperty.transaction do
        client = Client.find 6
        accounting_system_type_ids,acc_sys_type_name=[],nil
        client.users.each do |user|
          accounting_system_type_ids << user.real_estate_properties.where("property_name NOT like ?", "property_created_by%").map(&:accounting_system_type_id)
        end
        accounting_system_type_ids = accounting_system_type_ids.flatten.uniq.compact
        client.accounting_system_type_ids = accounting_system_type_ids
        client.save(:validate => false)
        accounting_system_type_ids.each do |acc_sys_id|
          acc_sys_type_name = AccountingSystemType.find_by_id(acc_sys_id).try(:type_name)
          if acc_sys_type_name.eql?('MRI, SWIG')
            ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'Metro Commercial', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
          end
        end if accounting_system_type_ids.present?
        users = client.users
        users.each do |user|
          properties = user.real_estate_properties.where("accounting_system_type_id IS NOT NULL and property_name NOT like ?", "property_created_by%")
          properties.each do |property|
            chart_of_account =  ChartOfAccount.find_by_client_id_and_accounting_system_type_id(user.client_id,property.accounting_system_type_id)
            property.chart_of_account_id = chart_of_account.id
            property.save(:validate => false)
          end
        end
      end
    end
  end

  def self.create_chart_of_accounts_for_external
    ChartOfAccount.transaction do
      RealEstateProperty.transaction do
        client = Client.find 8
        accounting_system_type_ids,acc_sys_type_name=[],nil
        client.users.each do |user|
          accounting_system_type_ids << user.real_estate_properties.where("property_name NOT like ?", "property_created_by%").map(&:accounting_system_type_id)
        end
        accounting_system_type_ids = accounting_system_type_ids.flatten.uniq.compact
        client.accounting_system_type_ids = accounting_system_type_ids
        client.save(:validate => false)
        accounting_system_type_ids.each do |acc_sys_id|
          acc_sys_type_name = AccountingSystemType.find_by_id(acc_sys_id).try(:type_name)
          if acc_sys_type_name.eql?('Real Page')
            ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'External Real Page', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
          elsif acc_sys_type_name.eql?('AMP Excel')
            ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'External AMP Excel', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
          end
        end if accounting_system_type_ids.present?
        users = client.users
        users.each do |user|
          properties = user.real_estate_properties.where("accounting_system_type_id IS NOT NULL and property_name NOT like ?", "property_created_by%")
          properties.each do |property|
            chart_of_account =  ChartOfAccount.find_by_client_id_and_accounting_system_type_id(user.client_id,property.accounting_system_type_id)
            property.chart_of_account_id = chart_of_account.id
            property.save(:validate => false)
          end
        end
      end
    end
  end

  def self.create_chart_of_accounts_for_nas
    ChartOfAccount.transaction do
      RealEstateProperty.transaction do
        client = Client.find 13
        accounting_system_type_ids,acc_sys_type_name=[],nil
        client.users.each do |user|
          accounting_system_type_ids << user.real_estate_properties.where("property_name NOT like ?", "property_created_by%").map(&:accounting_system_type_id)
        end
        accounting_system_type_ids = accounting_system_type_ids.flatten.uniq.compact
        client.accounting_system_type_ids = accounting_system_type_ids
        client.save(:validate => false)
        accounting_system_type_ids.each do |acc_sys_id|
          acc_sys_type_name = AccountingSystemType.find_by_id(acc_sys_id).try(:type_name)
          if acc_sys_type_name.eql?('AMP Excel')
            ChartOfAccount.find_or_create_by_name_and_accounting_system_type_id_and_client_id(:name => 'Nas AMP Excel', :accounting_system_type_id => acc_sys_id, :client_id => client.id)
          end
        end if accounting_system_type_ids.present?
        users = client.users
        users.each do |user|
          properties = user.real_estate_properties.where("accounting_system_type_id IS NOT NULL and property_name NOT like ?", "property_created_by%")
          properties.each do |property|
            chart_of_account =  ChartOfAccount.find_by_client_id_and_accounting_system_type_id(user.client_id,property.accounting_system_type_id)
            property.chart_of_account_id = chart_of_account.id
            property.save(:validate => false)
          end
        end
      end
    end
  end

  def self.update_kwilliams_users
    Portfolio.transaction do
      Folder.transaction do
        RealEstateProperty.transaction do
          client = Client.find_by_name("AMP Technologies")
#          client = Client.find_by_name("ABC")
          users = client.users
          users.each do |user|
            role_ids =   user.role_ids.uniq
            if role_ids.present? && role_ids.include?(2) && !role_ids.include?(4)
              basic_portfolios_count = user.portfolios.where(:is_basic_portfolio => true).count
              if basic_portfolios_count == 0
                chart_of_accounts = user.client.chart_of_accounts || []

                chart_of_accounts.each_with_index do |chart_of_account, number|
                  number += 1
                  multifamily_portfolio = Portfolio.create(:name => "All Multifamily #{number}", :user_id => user.id, :leasing_type => "Multifamily", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
                  Folder.create(:name => multifamily_portfolio.try(:name), :portfolio_id => multifamily_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if multifamily_portfolio.present?
                  commercial_portfolio = Portfolio.create(:name => "All Commercial #{number}", :user_id => user.id, :leasing_type => "Commercial", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
                  Folder.create(:name => commercial_portfolio.try(:name), :portfolio_id => commercial_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if commercial_portfolio.present?
                  #end
                end
              end

              real_properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(user.id,true)

              #~ real_properties = RealEstateProperty.where('user_id = ? and client_id = ? and accounting_system_type_id is NOT NULL',user.id,client.id)
              real_properties.each do |real_props|
                if real_props.accounting_system_type_id.present?
                  chart_of_account =  ChartOfAccount.find_by_client_id_and_accounting_system_type_id(user.client_id,real_props.accounting_system_type_id)
                  if real_props.try(:chart_of_account_id).blank?
                    real_props.chart_of_account_id = chart_of_account.id
                    real_props.save(:validate => false)
                  end
                  Portfolio.insert_property_in_basic_portfolio(real_props,user)
                else
                  puts "No accounting_system_type_ids"
                  puts real_props.id
                end
              end
              portfolios = Portfolio.find_shared_and_owned_portfolios(user.id)
              #~ portfolios = Portfolio.where('user_id = ? and client_id = ? and name NOT IN (?) and is_basic_portfolio = ?',user.id,client.id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"],true)
              portfolios.each do |portfolio|
                if portfolio.real_estate_properties.present?
                  chart_of_account_id = portfolio.real_estate_properties.first.chart_of_account_id
                  portfolio.update_attributes(:chart_of_account_id => chart_of_account_id) if portfolio.chart_of_account_id.blank?
                else
                  puts "No real estate properties"
                  puts portfolio.id
                end
              end
            end
            Portfolio.update_financial_info(user)
          end
        end
      end
    end

  end

  def self.update_swig_users
    Portfolio.transaction do
      Folder.transaction do
        RealEstateProperty.transaction do
          #          client = Client.find_by_name("AMP Technologies")
          client = Client.find_by_name("SWIG")
          users = client.users
          users.each do |user|
            role_ids =   user.role_ids.uniq
            if role_ids.present? && role_ids.include?(2) && !role_ids.include?(4)
              basic_portfolios_count = user.portfolios.where(:is_basic_portfolio => true).count
              if basic_portfolios_count == 0
                chart_of_accounts = user.client.chart_of_accounts || []

                chart_of_accounts.each_with_index do |chart_of_account, number|
                  number += 1
                  multifamily_portfolio = Portfolio.create(:name => "All Multifamily #{number}", :user_id => user.id, :leasing_type => "Multifamily", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
                  Folder.create(:name => multifamily_portfolio.try(:name), :portfolio_id => multifamily_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if multifamily_portfolio.present?
                  commercial_portfolio = Portfolio.create(:name => "All Commercial #{number}", :user_id => user.id, :leasing_type => "Commercial", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
                  Folder.create(:name => commercial_portfolio.try(:name), :portfolio_id => commercial_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if commercial_portfolio.present?
                  #end
                end
              end

              real_properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(user.id,true)

              #~ real_properties = RealEstateProperty.where('user_id = ? and client_id = ? and accounting_system_type_id is NOT NULL',user.id,client.id)
              real_properties.each do |real_props|
                if real_props.accounting_system_type_id.present?
                  chart_of_account =  ChartOfAccount.find_by_client_id_and_accounting_system_type_id(user.client_id,real_props.accounting_system_type_id)
                  if real_props.try(:chart_of_account_id).blank?
                    real_props.chart_of_account_id = chart_of_account.id
                    real_props.save(:validate => false)
                  end
                  Portfolio.insert_property_in_basic_portfolio(real_props,user)
                else
                  puts "No accounting_system_type_ids"
                  puts real_props.id
                end
              end
              portfolios = Portfolio.find_shared_and_owned_portfolios(user.id)
              #~ portfolios = Portfolio.where('user_id = ? and client_id = ? and name NOT IN (?) and is_basic_portfolio = ?',user.id,client.id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"],true)
              portfolios.each do |portfolio|
                if portfolio.real_estate_properties.present?
                  chart_of_account_id = portfolio.real_estate_properties.first.chart_of_account_id
                  portfolio.update_attributes(:chart_of_account_id => chart_of_account_id) if portfolio.chart_of_account_id.blank?
                else
                  puts "No real estate properties"
                  puts portfolio.id
                end
              end
            end
            Portfolio.update_financial_info(user)
          end
        end
      end
    end

  end

  # Moved to rake

#  def self.creating_chart_of_accounts_for_all_clients
#    RealEstateProperty.update_chart_of_accounts_for_real_estate_properties_basing_on_accounting_system_id_and_chart_of_account_id
#    RealEstateProperty.update_chart_of_accounts_for_real_estate_properties_basing_on_accounting_system_id_and_chart_of_account_id_client_5
#    RealEstateProperty.create_chart_of_accounts_for_metro
#    RealEstateProperty.create_chart_of_accounts_for_external
#    RealEstateProperty.create_chart_of_accounts_for_nas
#    Portfolio.update_wres_users
#    RealEstateProperty.update_shared_properties_of_client_admin
#  end

  def self.update_chart_of_account_id_as_nil_for_system_created_properties_and_portfolios
    RealEstateProperty.where("property_name like ?", "property_created_by%").update_all(:chart_of_account_id => nil)
    Portfolio.where("name like ?", "portfolio_created_by%").update_all(:chart_of_account_id => nil)
  end

end
