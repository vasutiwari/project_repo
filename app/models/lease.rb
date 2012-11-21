class Lease < ActiveRecord::Base
  #validates_date_time :commencement, :expiration, :execution, :activity_date #, :with => /\d{2}\/\d{2}\/\d{4}/, :message => "^Date must be in the following format: mm/dd/yyyy"


  # Associations
  has_one  :property_lease_suite,  :dependent => :destroy
  has_one  :comm_property_lease_suite,  :dependent => :destroy
  has_one  :clause,                :dependent => :destroy
  has_one  :cap_ex,                :dependent => :destroy
  has_one  :insurance,             :dependent => :destroy
  has_one  :rent,                  :dependent => :destroy
  has_one  :income_projection,     :dependent => :destroy
  has_one  :note, :as => :note,    :dependent => :destroy
  has_many :documents
  has_one  :tenant,             :through => :property_lease_suite
  has_many :tenant_improvments, :through => :cap_ex
  has_many :options, :dependent => :destroy
  has_one :info, :dependent => :destroy

  belongs_to :real_estate_property

  # Callbacks
  #before_save :update_lease_occupancy_type

  after_update :check_status_change

  after_save :calling_lease_rent_roll_from_delayed_job

  after_save :change_lease_status

  after_destroy :update_suites_info

  before_save :update_client_id_for_lease

  accepts_nested_attributes_for :property_lease_suite, :rent,:clause,:cap_ex,:insurance,:documents
  accepts_nested_attributes_for :note,:reject_if => :all_blank

  scope :current_leases,     group("leases.id").where("leases.commencement <= ? and (leases.expiration >= ? or leases.mtm=?) and leases.is_executed= ? and tenant_legal_name is not NULL", Time.now.strftime("%Y-%m-%d"), Time.now.strftime("%Y-%m-%d"), true, true)

  scope :join_property_lease_suites, :joins => "inner join property_lease_suites on property_lease_suites.lease_id = leases.id
   left outer join tenants on tenants.id =  property_lease_suites.tenant_id   left outer join cap_exes on cap_exes.lease_id=leases.id ",
                :select => "leases.id, leases.real_estate_property_id, leases.commencement, leases.expiration, leases.occupancy_type, leases.effective_rate, property_lease_suites.suite_ids, tenants.id as tenant_id , tenants.tenant_legal_name, cap_exes.id as cap_ex_id"

  scope :port_six_month_expiration_leases , lambda { |args| {:conditions=>["leases.is_executed=true and leases.is_archived=false and leases.commencement <='#{Date.today}' and leases.expiration >='#{Date.today}' and leases.expiration <='#{(Date.today+182)}' and leases.status IS NOT NULL and leases.real_estate_property_id IN (#{args.join(',')})"],:order=>"leases.expiration ASC",:select=>"id"} }

  # Validations
  validates :effective_rate,      :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |lease|  lease.effective_rate != nil }
  validates :basic_rentable_sqft, :numericality => { :greater_than  => 0 },             :if => Proc.new { |lease|  lease.basic_rentable_sqft != nil }
  def self.create_new_lease(*args)
    args = args.extract_options!
    self.create(:real_estate_property_id => args[:real_estate_property_id],:commencement => args[:commencement], :execution => args[:execution],:expiration => args[:expiration],:is_executed => 1)
  end


  # adding current_client_id before saving to db
  def update_client_id_for_lease
    self.client_id = Client.current_client_id
  end

  def self.executed_leases_method(id,search_txt)
    search_txt = search_txt.strip unless search_txt.nil?
    property_lease_suites = []
    executed_leases_coll = RealEstateProperty.find(:all,:include => [:suites],:conditions=>["id = ?",id]).first.executed_leases # executed leases collection
    executed_leases_coll.includes(:property_lease_suite=>[:tenant=>[:options]]).each do |executed_lease|
      selected_suite_numbers = []
      selected_option_types = []
      property_lease = executed_lease.property_lease_suite
      if property_lease.present?
        if search_txt && !search_txt.nil?
          #search for tenant name
          property_lease_suites << property_lease if property_lease && property_lease.tenant && property_lease.tenant.tenant_legal_name.downcase.strip.include?( search_txt.downcase)
          #search for option type
          option_types = property_lease.tenant.options.collect{|option| option.option_type.to_s.downcase.strip} if property_lease && property_lease.tenant
          if option_types && !option_types.empty?
            selected_option_types << option_types.map{|option_type| option_type if option_type.include?(search_txt.downcase.to_s)}
            if option_types.index(search_txt.downcase.to_s) || !selected_option_types.flatten.compact.empty?
            property_lease_suites << property_lease
            end
          end
          #search for suite number
          suite_numbers= Suite.suites(property_lease).collect{|suite| suite.suite_no.to_s.downcase.strip}
          if suite_numbers && !suite_numbers.empty?
            selected_suite_numbers << suite_numbers.map{|suite_number| suite_number if suite_number.include?(search_txt.to_s.downcase)}
            if suite_numbers.index(search_txt.to_s.downcase) || !selected_suite_numbers.flatten.compact.empty?
            property_lease_suites << property_lease
            end
          end
        else
        property_lease_suites << property_lease
        end
      end
    end
    return property_lease_suites.flatten.compact.uniq.sort_by(&:updated_at).reverse!
  end

  def self.executed_leases_archeived_method(id)
    property_lease_suites = []
    executed_leases_coll = RealEstateProperty.find_real_estate_property(id).executed_leases_archeived # executed leases collection
    executed_leases_coll.each do |executed_lease_archeived|
      property_lease_suites << executed_lease_archeived.property_lease_suite # property lease suites collection
    end
    return property_lease_suites.flatten.compact.sort_by(&:updated_at).reverse!
  end

  def self.find_option_type(tenant)
    string = ""
    if tenant.present?
      options_collection = tenant.options
      options_collection.each do |option|
        option_start = option.option_start ? ": #{option.option_start.strftime('%m/%y')}" : ''
        option_end =  option.option_end ? "to #{option.option_end.strftime('%m/%y')}" : ''
        string << "#{option.try(:option_type)} #{option_start} #{option_end} #{ (option != options_collection.last) ? ',' : '' }"
      end
    end
    return string
  end

  def self.negotiated_leases_method(id)
    property_lease_suites_six, property_lease_suites_othr, property_lease_suites = [],[],[]
    negotiated_leases_coll_six_mnth = RealEstateProperty.find_real_estate_property(id).negotiation_leases_six_mnth_exp # negotiated leases collection
    negotiated_leases_coll_othr = RealEstateProperty.find_real_estate_property(id).negotiation_leases_other # negotiated leases collection

    negotiated_leases_coll_six_mnth.each do |negotiated_leases_six_mnth|
      property_lease_suites_six << negotiated_leases_six_mnth.property_lease_suite # property lease suites collection
    end
    negotiated_leases_coll_othr.each do |negotiated_leases_othr|
      property_lease_suites_othr << negotiated_leases_othr.property_lease_suite # property lease suites collection
    end
    property_lease_suites = property_lease_suites_othr.flatten
    return property_lease_suites.compact.sort_by(&:updated_at).reverse!, property_lease_suites_six.flatten.compact.sort_by(&:updated_at).reverse!
  end

  def self.interested_prospects_leases_method(id)
    property_lease_suites_intrstd,property_lease_suites_six_mnth,property_lease_suites = [],[],[]
    interested_prospects_leases_coll =RealEstateProperty.find_real_estate_property(id).interested_prospects_leases # interested prospects leases collection
    interested_prospects_leases_six_month_exp_coll = RealEstateProperty.find_real_estate_property(id).interested_prospects_leases_six_month_exp # interested prospects leases collection

    interested_prospects_leases_coll.each do |interested_prospects_lease|
      property_lease_suites_intrstd << interested_prospects_lease.property_lease_suite # property lease suites collection
    end
    interested_prospects_leases_six_month_exp_coll.each do |interested_prospects_leases_six_month_exp|
      property_lease_suites_six_mnth << interested_prospects_leases_six_month_exp.property_lease_suite # property lease suites collection
    end
    property_lease_suites = property_lease_suites_intrstd.flatten #+ property_lease_suites_six_mnth.flatten
    return property_lease_suites.compact.sort_by(&:updated_at).reverse!, property_lease_suites_six_mnth.flatten.compact.sort_by(&:updated_at).reverse!
  end

  def self.six_mnth_expirations_leases(id)
    property_lease_suites_six_mnth = []
    six_month_expiration_leases_coll = RealEstateProperty.find_real_estate_property(id).six_month_expiration_leases
    six_month_expiration_leases_coll.each do |six_month_expiration_lease|
      property_lease_suites_six_mnth << six_month_expiration_lease.property_lease_suite
    end
    property_lease_suites = property_lease_suites_six_mnth.flatten
  end

  def self.portfolio_six_mnth_expirations_leases(id)
    property_lease_suites_six_mnth,six_month_expiration_leases_coll = [],[]
    real_props = RealEstateProperty.find_real_estate_property(id,true)
    real_props.each do |i|
      six_month_expiration_leases_coll << i.six_month_expiration_leases
    end if real_props.present?
    six_month_expiration_leases_coll.flatten!.each do |six_month_expiration_lease|
      property_lease_suites_six_mnth << six_month_expiration_lease.property_lease_suite
    end
    property_lease_suites = property_lease_suites_six_mnth.flatten
  end

  def self.interested_prospects_leases_archieve_method(id)
    property_lease_suites_intrstd_archiev =[]
    interested_prospects_leases_coll_archiev = RealEstateProperty.find_real_estate_property(id).interested_prospects_leases_archeived # interested prospects leases collection
    interested_prospects_leases_coll_archiev.each do |interested_prospects_lease|
      property_lease_suites_intrstd_archiev << interested_prospects_lease.property_lease_suite # property lease suites collection
    end
    property_lease_suites = property_lease_suites_intrstd_archiev.flatten
    return property_lease_suites.compact.sort_by(&:updated_at).reverse!
  end

  def self.procedure_lease(*args)
    args = args.extract_options!
    args.each{ |key, val| args[key] = 'NULL' if val.nil? }
    mtm = args[:mtm].present? ? args[:mtm] : 0 if args.present?
    ret =ActiveRecord::Base.connection.execute("call LeaseFindOrCreate(\"#{args[:startDate]}\", \"#{args[:endDate]}\", \"#{args[:occType]}\",\"#{args[:sStatus]}\",#{args[:realIn]},#{args[:isExecuted]},#{args[:userId]},#{args[:effRate]} ,#{mtm})")
    ret = Document.record_to_hash(ret).first rescue nil
    ActiveRecord::Base.connection.reconnect!;ret
  end

  def self.update_lease_occupancy_type(lease)
    if (lease.expiration? && lease.commencement? ) && (lease.commencement.to_date.strftime("%Y-%m-%d") <= Time.now.strftime("%Y-%m-%d") && lease.expiration.to_date.strftime("%Y-%m-%d") >= Time.now.strftime("%Y-%m-%d")) || lease.expiration? && (lease.expiration.to_date.strftime("%Y-%m-%d") < Time.now.strftime("%Y-%m-%d") && (lease.mtm == true))
      lease.occupancy_type = "current"
    elsif lease.expiration? && (lease.expiration.to_date.strftime("%Y-%m-%d") < Time.now.strftime("%Y-%m-%d") && (lease.mtm != true))
      lease.occupancy_type = "expirations"
    elsif (lease.expiration? && lease.commencement? ) && (lease.commencement.to_date.strftime("%Y-%m-%d") > Time.now.strftime("%Y-%m-%d") && lease.expiration.to_date.strftime("%Y-%m-%d") > Time.now.strftime("%Y-%m-%d"))
      lease.occupancy_type = "new"
    end

    #Renewal option update start - Need to change this based on lease_id#
    property_lease_suites = []
    property_lease_suites << PropertyLeaseSuite.find_by_lease_id(lease)
     if property_lease_suites.present?
       property_lease_suites.each do |prop_lease_suite|
          info_collect = Info.find_by_tenant_id_and_renewal(prop_lease_suite.try(:tenant_id),'Renewal')  if prop_lease_suite.present?
          suites_collect = PropertyLeaseSuite.find(:all ,:conditions=>['tenant_id = ?', info_collect.tenant_id]) if info_collect.present?
          lease.occupancy_type = "renewal" if suites_collect.present? && !suites_collect.empty?
       end
     end
    #Renewal option update end#
    lease.save
  end

  #Method added for updating a lease status when a lease is created and updated based on suite#
  def self.update_lease_status(lease)
    property_lease_suite = lease.property_lease_suite if lease
    if property_lease_suite && property_lease_suite.suite_ids?
      if (lease.expiration? && lease.commencement? ) && (lease.commencement.to_date.strftime("%Y-%m-%d") <= Time.now.strftime("%Y-%m-%d") && lease.expiration.to_date.strftime("%Y-%m-%d") >= Time.now.strftime("%Y-%m-%d"))
        lease.status = "Active"
      elsif lease.expiration? && (lease.expiration.to_date.strftime("%Y-%m-%d") < Time.now.strftime("%Y-%m-%d") && (lease.mtm != true))
        lease.status = "Inactive"
      elsif (lease.expiration? && lease.commencement? ) && (lease.commencement.to_date.strftime("%Y-%m-%d") > Time.now.strftime("%Y-%m-%d") && lease.expiration.to_date.strftime("%Y-%m-%d") > Time.now.strftime("%Y-%m-%d"))
        lease.status = "Active"
      elsif  lease.expiration? && (lease.expiration.to_date.strftime("%Y-%m-%d") < Time.now.strftime("%Y-%m-%d") && (lease.mtm == true))
        lease.status = "Active"
        lease.occupancy_type = "current"
      end
    elsif (lease.present? && !property_lease_suite.present? && (lease.expiration? && lease.commencement? ) && (lease.commencement.to_date.strftime("%Y-%m-%d") > Time.now.strftime("%Y-%m-%d") && lease.expiration.to_date.strftime("%Y-%m-%d") > Time.now.strftime("%Y-%m-%d")) || (lease.expiration? && (lease.expiration.to_date.strftime("%Y-%m-%d") < Time.now.strftime("%Y-%m-%d")) && (lease.mtm != true)))
      lease.status = "Inactive"
    end
    lease.save
  end

  #Method to change the suite status based on the lease status#
  def change_lease_status
    if !self.is_executed
      property_lease_suite = self.property_lease_suite
      suite = Suite.find(:all,:conditions=>['id IN (?)',property_lease_suite.suite_ids]) if property_lease_suite
      suite.present? && suite.each do |suite_up|
        suite_up.update_attributes(:status=>suite_up.status)
      end
    else
      if (self.commencement.present? && self.expiration.present?) && (self.commencement.to_date.strftime("%Y-%m-%d") <= Time.now.strftime("%Y-%m-%d") && self.expiration.to_date.strftime("%Y-%m-%d")  >= Time.now.strftime("%Y-%m-%d"))
        if self.status == "Active"
          property_lease_suite = self.property_lease_suite
          suite = Suite.find(:all,:conditions=>['id IN (?)',property_lease_suite.suite_ids]) if property_lease_suite
          suite.present? && suite.each do |suite_up|
            suite_up.update_attributes(:status=>"Occupied")
          end
        elsif self.status == "Inactive"
          property_lease_suite = self.property_lease_suite
          suite = Suite.find(:all,:conditions=>['id IN (?)',property_lease_suite.suite_ids]) if property_lease_suite
          suite.present? && suite.each do |suite_up|
            suite_up.update_attributes(:status=>"Vacant")
          end
        elsif self.status != "Inactive" || self.status != "%Vacant%" || self.status != nil
          property_lease_suite = self.property_lease_suite
          suite = Suite.find(:all,:conditions=>['id IN (?)',property_lease_suite.suite_ids]) if property_lease_suite
          suite.present? && suite.each do |suite_up|
            suite_up.update_attributes(:status=>"Occupied")
          end
        end
      elsif (self.expiration.present?) && (self.expiration.to_date.strftime("%Y-%m-%d") < Time.now.strftime("%Y-%m-%d") && (self.mtm != true))
        property_lease_suite = self.property_lease_suite
        suite = Suite.find(:all,:conditions=>['id IN (?)',property_lease_suite.suite_ids]) if property_lease_suite
        suite.present? && suite.each do |suite_up|
          suite_up.update_attributes(:status=>"Vacant")
        end
      elsif (self.expiration.present?) && (self.expiration.to_date.strftime("%Y-%m-%d") < Time.now.strftime("%Y-%m-%d") && (self.mtm == true))
        property_lease_suite = self.property_lease_suite
        suite = Suite.find(:all,:conditions=>['id IN (?)',property_lease_suite.suite_ids]) if property_lease_suite
        suite.present? && suite.each do |suite_up|
          suite_up.update_attributes(:status=>"Occupied")
        end
      elsif (self.commencement.present?) &&  (self.commencement.to_date.strftime("%Y-%m-%d") > Time.now.strftime("%Y-%m-%d"))
        property_lease_suite = self.property_lease_suite
        suite = Suite.find(:all,:conditions=>['id IN (?)',property_lease_suite.suite_ids]) if property_lease_suite
        suite.present? && suite.each do |suite_up|
          leases = find_leases_of_a_suite(suite_up)
          if leases.present? && leases.size > 1
            leases.each do |lease|
              suite_up.update_attributes(:status=>(lease.try(:commencement).to_date.strftime("%Y-%m-%d") > Time.now.strftime("%Y-%m-%d") rescue nil ) ? "Vacant" : suite_up.status)
            end
          else
            suite_up.update_attributes(:status=>"Vacant")
          end
        end
      end
    end
  end

  # Main Purpose of this method is updating Lease Rent Roll table basing on changes of lease status.
  def check_status_change
    if self.status_changed?
      if (self.status=="Vacant")
        property_lease_suite = self.property_lease_suite
        if property_lease_suite.present? && property_lease_suite.suite_ids?
          property_lease_suite.suite_ids.each do |suite_id|
            lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,Time.now.month, Time.now.year)
            lease_rent_roll.update_attributes( :tenant => "Vacant", :lease_start_date => nil,  :lease_end_date => nil, :base_rent_monthly_amount => nil, :base_rent_annual_psf => nil, :escalations_period => nil, :escalations_monthly_amount => nil,  :per_sales_floor => nil, :per_sales_percentage => nil,  :recoveries_charge => nil,  :recoveries_info  => nil,  :tis_amount => nil,  :lcs_amount => nil, :options => nil, :security_deposit_amount => nil, :effective_rate => nil, :occupancy_type => nil) if lease_rent_roll.present?
          end
        end
      elsif ((self.status=="Inactive") && (self.occupancy_type=="current"))
        property_lease_suite = self.property_lease_suite
        if property_lease_suite.present? && property_lease_suite.suite_ids?
          property_lease_suite.suite_ids.each do |suite_id|
            lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,Time.now.month, Time.now.year)
            lease_rent_roll.update_attributes(:occupancy_type => nil) if lease_rent_roll.present?
          end
        end
      else
        property_lease_suite = self.property_lease_suite
        if property_lease_suite.present?
          property_lease_suite.save
          tenant = property_lease_suite.tenant
          tenant.save if tenant.present?
        end

        rent = self.rent
        if rent.present?
          rent_schedules = rent.rent_schedules
          rent_schedules.each { |rent_schedule| rent_schedule.save } if rent_schedules.present?
          percentage_sales_rents = rent.percentage_sales_rents
          percentage_sales_rents.each { |percentage_sales_rent| percentage_sales_rent.save }  if percentage_sales_rents.present?
          recoveries = rent.recoveries
          recoveries.each { |recovery| recovery.save } if recoveries.present?
        end

        cap_ex = self.cap_ex
        if cap_ex.present?
          cap_ex.save
          tenant_improvements = cap_ex.tenant_improvements
          tenant_improvements.each { |tenant_improvement| tenant_improvement.save } if tenant_improvements.present?
          leasing_commissions = cap_ex.leasing_commissions
          leasing_commissions.each { |leasing_commission| leasing_commission.save } if leasing_commissions.present?
        end

      end
    end
  end


  def calling_lease_rent_roll_from_delayed_job
    lease_changes = self.commencement_changed? || self.expiration_changed? || self.occupancy_type_changed?
    self.delay.update_lease_rent_roll(lease_changes)
  end

  def update_lease_rent_roll(lease_changes)
    if lease_changes
      if (self.commencement.present? || self.expiration.present?) && self.is_executed
        property_lease_suite = self.property_lease_suite
        if property_lease_suite.present? && property_lease_suite.suite_ids?
          lease_duration = RentSchedule.get_rent_schedule_period(self.commencement, Time.now)
          tenant = Tenant.find_by_id(property_lease_suite.try(:tenant_id)).try(:tenant_legal_name)
          if self.occupancy_type.eql?("current") && self.status.eql?("Inactive")
            occupancy_type = nil
          else
            occupancy_type = self.occupancy_type
          end
          0.upto(lease_duration) do |month|
            current_year = (self.commencement + month.months).year rescue nil
            current_month = (self.commencement + month.months).month rescue nil
            if current_year.present? && current_month.present?
              property_lease_suite.suite_ids.each do |suite_id|
                lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,current_month, current_year)
                lease_rent_roll.update_attributes(:lease_start_date => self.commencement, :lease_end_date =>self.expiration, :occupancy_type => occupancy_type, :tenant => tenant, :lease_id => self.id)  if lease_rent_roll.present?
              end
            end
          end
        end
      end
    end
  end

  def update_suites_info
    if (self.is_executed && self.is_archived == false && self.status != 'Inactive' )
      property_lease_suite = self.property_lease_suite
      if property_lease_suite.present? && property_lease_suite.suite_ids?
        property_lease_suite.suite_ids.each do |suite_id|
          suite = Suite.find_by_id(suite_id)
          suite.update_attributes(:status=>"Vacant") if suite.present?
          lease_rent_roll = LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,Time.now.month, Time.now.year)
          lease_rent_roll.update_attributes( :tenant => "Vacant", :lease_start_date => nil,  :lease_end_date => nil, :base_rent_monthly_amount => nil, :base_rent_annual_psf => nil, :escalations_period => nil, :escalations_monthly_amount => nil,  :per_sales_floor => nil, :per_sales_percentage => nil,  :recoveries_charge => nil,  :recoveries_info  => nil,  :tis_amount => nil,  :lcs_amount => nil, :options => nil, :security_deposit_amount => nil, :effective_rate => nil, :occupancy_type => nil, :lease_id => nil) if lease_rent_roll.present?
        end
      end
    end
  end


  def find_leases_of_a_suite(suite)
    property_lease_suites = PropertyLeaseSuite.includes(:lease).where("leases.real_estate_property_id = ? AND leases.is_executed = ?",  suite.real_estate_property_id, true)
    leases = []
    suite_ids = property_lease_suites.map(&:suite_ids).flatten.compact.uniq
    if suite_ids && suite_ids.include?(suite.id)
      property_lease_suites.each do |pls|
        leases << pls.lease if pls && pls.suite_ids && pls.try(:suite_ids).include?(suite.id)
      end
    end
    return leases
  end

end
