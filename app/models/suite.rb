class Suite < ActiveRecord::Base

  # Associations
  belongs_to :rent
  belongs_to :real_estate_property
  belongs_to :user
  has_one :document
  has_one :note, :as => :note,    :dependent => :destroy
  has_many :lease_rent_rolls

  after_save :update_lease_rent_roll
  before_save :set_client_id_in_suite

  has_one :rent_schedule, :conditions => 'rent_schedules.from_date <= "#{Time.now.strftime("%Y-%m-%d")}" and rent_schedules.to_date >= "#{Time.now.strftime("%Y-%m-%d")}"'

  has_one :recovery, :conditions => 'recoveries.from_date <= "#{Time.now.strftime("%Y-%m-%d")}" and recoveries.to_date >= "#{Time.now.strftime("%Y-%m-%d")}"'

  has_one :percentage_sales_rent, :conditions => 'percentage_sales_rents.from_date <= "#{Time.now.strftime("%Y-%m-%d")}" and percentage_sales_rents.to_date >= "#{Time.now.strftime("%Y-%m-%d")}"'

  scope :join_rent_schedule, :joins => "left outer join  rent_schedules on rent_schedules.suite_id = suites.id and rent_schedules.from_date <= '#{Time.now.strftime("%Y-%m-%d")}' and rent_schedules.to_date >= '#{Time.now.strftime("%Y-%m-%d")}'", :select => "suites.id, suites.rentable_sqft, rent_schedules.amount_per_month, rent_schedules.amount_per_month_per_sqft"

  scope :join_recovery, :joins => "left outer join  recoveries on recoveries.suite_id = suites.id and recoveries.from_date <= '#{Time.now.strftime("%Y-%m-%d")}' and recoveries.to_date >= '#{Time.now.strftime("%Y-%m-%d")}'", :select => "recoveries.value, recoveries.recovery_method"

  scope :join_percentage_sales_rent, :joins => "left outer join  percentage_sales_rents on percentage_sales_rents.suite_id = suites.id and percentage_sales_rents.from_date <= '#{Time.now.strftime("%Y-%m-%d")}' and percentage_sales_rents.to_date >= #{Time.now.strftime("%Y-%m-%d")} ", :select => "percentage_sales_rents.from_date as percentage_sales_rents_from_date, percentage_sales_rents.to_date as percentage_sales_rents_to_date, percentage_sales_rents.floor_amt, percentage_sales_rents.sales_rent_percentage, percentage_sales_rents.est_sales_percentage_esc_year"

  after_save :update_rent_schedule

  # Validations
  validates :rentable_sqft ,          :numericality => {:greater_than => 0 }, :presence => true

  validates :usable_sqft ,            :numericality => {:greater_than => 0 },       :if => Proc.new { |suite|  suite.usable_sqft!=nil }

  validates_uniqueness_of :suite_no, :scope =>[:real_estate_property_id]

  #Constants
  SUITE_FLOOR = [
  ["",nil],
  [ "1", "1" ],
  [ "2", "2" ],
  [ "3", "3" ],
  [ "4", "4" ]
  ]


  #lease suites start
  def self.create_lease_suite_data_push(s,params,propid,user_id)
    self.create(:suite_no => s,:floor => params[:floor],:rentable_sqft  => params[:rentable_sqft],:usable_sqft => params[:usable_sqft], :status => params[:status],:real_estate_property_id => propid,:user_id => user_id,:days_vaccant=> params[:days_vaccant])
  end

  def update_lease_suite_data(params,propid,user_id)
    self.update_attributes(:suite_no => params[:suite_no1],:floor => params[:floor1],:rentable_sqft  => params[:rentable_sqft1],:usable_sqft => params[:usable_sqft1], :status => params[:status1],:real_estate_property_id => propid,:user_id => user_id,:days_vaccant=> params[:days_vaccant1])
  end

  def update_lease_suite_data_add(s,params,propid,user_id)
    self.update_attributes(:suite_no => s,:floor => params[:floor],:rentable_sqft  => params[:rentable_sqft],:usable_sqft => params[:usable_sqft], :status => params[:status],:real_estate_property_id => propid,:user_id => user_id,:days_vaccant=> params[:days_vaccant])
  end
  #lease suites end

  def self.create_or_update_suites(*args)
    args = args.extract_options!
    self.find_or_create_by_suite_no(:rentable_sqft => args[:rent_sqft], :floor => args[:floor], :move_in=> args[:move_in], :move_out => args[:move_out], :usable_sqft => args[:usable_sqft], :rent_id => args[:rent_id], :suite_no => args[:suite_no],:real_estate_property_id => args[:real_estate_property_id],:days_vaccant=> args[:days_vaccant])
  end

  def create_or_update_suite_details(params,suite_no)
    self.floor = params[:floor]
    self.suite_no = suite_no
    self.rentable_sqft = params[:suite][:rentable_sqft]
    self.usable_sqft = params[:suite][:usable_sqft]
    self.status = params[:suite][:status]
    self.days_vaccant = params[:days_vaccant]
    #self.real_estate_property_id = params[:real_estate_property][:no_of_units]
    self.save
  end

  def self.suites(property_lease_suite)
    where(:id => property_lease_suite.suite_ids) #getting suites_collection for executed leases
  end

  #To find suites in a floor
  def self.suites_with_floor(property_lease_suite,floor)
    floor_condition = (floor.nil? || floor.blank?) ? "(floor is null or floor = '')" : "floor = '#{floor}'"
    self.find(:all,:conditions=>["id in (?) and rentable_sqft is not null and #{floor_condition} and status!='vacant'",property_lease_suite.suite_ids])
  end

  def update_lease_rent_roll
    time = Time.now
    lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(self.id,time.month, time.year)
    if lease_rent_roll.present?
      l= lease_rent_roll.update_attributes(:suite_id => self.id, :real_estate_property_id => self.real_estate_property_id, :sqft => self.rentable_sqft, :month => time.month, :year => time.year)
    else
      l = LeaseRentRoll.create(:suite_id => self.id, :real_estate_property_id => self.real_estate_property_id, :sqft => self.rentable_sqft, :tenant => "Vacant", :month => time.month, :year => time.year)
    end
  end

  # Here we are getting  building sqft using real estate property id
  def self.get_building_sqft(real_estate_property_id)
    Suite.where(:real_estate_property_id => real_estate_property_id).sum(:rentable_sqft) if real_estate_property_id.present?
  end

  def self.get_suite_details(suite_ids)
    suites = Suite.where(:id => suite_ids)
    suite_nos = suites.map(&:suite_no) if suites.present?
    lease_rentable_sqft =  suites.sum(:rentable_sqft) if suites.present?
    [suites, suite_nos , lease_rentable_sqft]
  end

  #To set client_id in suite
  def set_client_id_in_suite
    self.client_id = self.try(:user).try(:client).try(:id)
  end


  #To update commercial_lease_occupancy while deleting suite
  def self.update_commercial_lease_occupancy(id)
    suite = Suite.find_by_id(id)
    rentable_sqft_vacant =  suite.rentable_sqft if suite.status.downcase == 'vacant'
    rentable_sqft_occupied = suite.rentable_sqft if suite.status.downcase == 'occupied'
    lease_occ = CommercialLeaseOccupancy.find_or_create_by_real_estate_property_id(suite.real_estate_property_id)
    lease_records = LeaseRentRoll.find(:all,:conditions=>["((occupancy_type = 'new' or occupancy_type = 'current') and lease_start_date between '#{Date.today.year}-01-01' and '#{Date.today.year}-#{Date.today.month}-31' and real_estate_property_id = #{suite.real_estate_property_id})" ])
    lease_records_exp = LeaseRentRoll.find(:all,:conditions=>["occupancy_type = ? and real_estate_property_id = ? AND lease_end_date between '#{Date.today.year}-01-01' and '#{Date.today.year}-#{Date.today.month}-31'",'expirations',suite.real_estate_property_id])
    suite_ids = lease_records.collect{|record| record.suite_id}       if lease_records && !lease_records.empty?
    suite_ids_exp = lease_records_exp.collect{|record| record.suite_id}       if lease_records_exp && !lease_records_exp.empty?
    new_lease_rentable_sqft = Suite.find_by_sql("select sum(suites.rentable_sqft) as occupied from suites where suites.status ='Occupied' and suites.real_estate_property_id = #{suite.real_estate_property_id} and suites.id = #{id}") if suite_ids &&  !suite_ids.empty?
    expiration_rentable_sqft = Suite.find_by_sql("select sum(suites.rentable_sqft) as occupied from suites where suites.status ='Occupied' and suites.real_estate_property_id = #{suite.real_estate_property_id} and suites.id = #{id}") if suite_ids_exp &&  !suite_ids_exp.empty?
    new_lease_actual = new_lease_rentable_sqft[0].occupied if new_lease_rentable_sqft.present?
    expiration_actual = expiration_rentable_sqft[0].occupied if expiration_rentable_sqft.present?

    #Renewal option update start#
    property_lease_suites = []
    leases = Lease.find_all_by_real_estate_property_id_and_is_executed(@note.id,true)
    if leases.present?
      leases.each do |lease|
        property_lease_suites << PropertyLeaseSuite.find_by_lease_id(lease)
      end
    end
    if property_lease_suites.present?
      property_lease_suites.each do |prop_lease_suite|
        @info_collect = Info.find(:all,:conditions=>['tenant_id = ? and renewal = ?',prop_lease_suite.tenant_id,'Renewal'])
      end
    end
    if @info_collect.present?
      @info_collect.each do |find_suite|
        @suites_collect = PropertyLeaseSuite.find(:all ,:conditions=>['tenant_id = ?', find_suite.tenant_id])
      end
    end
    suite_ids_for_renewal = @suites_collect.collect{|record| record.suite_ids}       if @suites_collect && !@suites_collect.empty?
    renewal_rentable_sqft = Suite.find_by_sql("select sum(suites.rentable_sqft) as occupied from suites where suites.real_estate_property_id = #{@note.id} and suites.id IN (#{ suite_ids_for_renewal.to_s.to_a.join(',')})") if suite_ids_for_renewal &&  !suite_ids_for_renewal.empty?
    renewal_actual = renewal_rentable_sqft[0].occupied if renewal_rentable_sqft.present?
    #Renewal option update end#

    if lease_occ
      lease_occ.current_year_sf_occupied_actual = (lease_occ.current_year_sf_occupied_actual - rentable_sqft_occupied).abs if rentable_sqft_occupied && lease_occ.current_year_sf_occupied_actual
      lease_occ.current_year_sf_vacant_actual = (lease_occ.current_year_sf_vacant_actual - rentable_sqft_vacant).abs if rentable_sqft_vacant &&  lease_occ.current_year_sf_vacant_actual
      lease_occ.new_leases_actual 	 =  (lease_occ.new_leases_actual 	 - new_lease_actual).abs if new_lease_actual && lease_occ.new_leases_actual
      lease_occ.expirations_actual = (lease_occ.expirations_actual - expiration_actual).abs if expiration_actual &&  lease_occ.expirations_actual
      lease_occ.renewals_actual = (lease_occ.renewals_actual - renewal_actual).abs if renewal_actual &&  lease_occ.renewals_actual
      lease_occ.save
    end
    if(lease_occ.current_year_sf_occupied_actual == 0 && lease_occ.current_year_sf_vacant_actual.nil?)
      lease_occ.current_year_sf_occupied_actual = nil
      lease_occ.save
    end
    if(lease_occ.current_year_sf_occupied_actual.nil? && lease_occ.current_year_sf_vacant_actual == 0)
      lease_occ.current_year_sf_vacant_actual = nil
      lease_occ.save
    end
  end

  def self.find_suite_num(suite_id)
    Suite.find_by_id(suite_id).try(:suite_no)
  end

  #to update rent-schedule amount based on rentable sqft update in suites#
  def update_rent_schedule
    property_lease_suites= []
    lease_find = Lease.find_all_by_real_estate_property_id_and_is_executed(self.real_estate_property_id,true)
    lease_find.each do |lease|
      property_lease_suites << PropertyLeaseSuite.find_by_lease_id(lease)
    end
    property_lease_suites.present? && property_lease_suites.each do |prop_lease_suite|
      if prop_lease_suite.present? && prop_lease_suite.suite_ids.present? && prop_lease_suite.suite_ids.include?(self.id)
        rent = Rent.find_by_lease_id(prop_lease_suite.try(:lease_id))
        rent_schedule = RentSchedule.find_all_by_rent_id(rent.id) if rent.present?
        rent_schedule.present? && rent_schedule.compact.each do |rent_val|
          if rent_val.is_all_suites_selected == true
            rent_sqft = Suite.find_all_by_id_and_real_estate_property_id(prop_lease_suite.suite_ids,self.real_estate_property_id).map(&:rentable_sqft).sum rescue nil
            rent_val.update_attributes(:amount_per_month => (rent_sqft.to_f  * rent_val.amount_per_month_per_sqft.to_f))
          elsif rent_val.present? && rent_val.suite_id.present? && rent_val.suite_id.eql?(self.id)
            rent_val.update_attributes(:amount_per_month => (self.rentable_sqft.to_f  * rent_val.amount_per_month_per_sqft.to_f))
          end
        end
      end
    end
  end
end
