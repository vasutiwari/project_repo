class LeaseRentRoll < ActiveRecord::Base
  belongs_to :lease
  belongs_to :suite

  before_save :update_data_in_commercial_lease_occupancy_table
  def update_data_in_commercial_lease_occupancy_table
    if self.real_estate_property_id? && self.month? && self.year?
      total_sqft_of_property = Suite.where(:real_estate_property_id => self.real_estate_property_id).sum(:rentable_sqft)
      total_vacant_sqft_of_property = Suite.where(:status => 'Vacant', :real_estate_property_id => self.real_estate_property_id).sum(:rentable_sqft)
      total_occupied_sqft_of_property = Suite.where(:status => 'Occupied', :real_estate_property_id => self.real_estate_property_id).sum(:rentable_sqft)
      new_and_current_status_suite_ids = LeaseRentRoll.where(:occupancy_type => ["new", "current"], :lease_start_date => "#{Date.today.year}-01-01".."#{Date.today.year}-#{Date.today.month}-31", :real_estate_property_id => self.real_estate_property_id, :month => self.month, :year => self.year).map(&:suite_id)
      expiration_status_suite_ids = LeaseRentRoll.where(:occupancy_type => 'expirations', :real_estate_property_id => self.real_estate_property_id, :month => self.month, :year => self.year, :lease_end_date => "#{Date.today.year}-01-01".."#{Date.today.year}-#{Date.today.month}-31").map(&:suite_id)
      new_lease_rentable_sqft = Suite.where(:id => new_and_current_status_suite_ids, :real_estate_property_id => self.real_estate_property_id).sum(:rentable_sqft)
      expiration_rentable_sqft = Suite.where(:id => expiration_status_suite_ids, :real_estate_property_id => self.real_estate_property_id).sum(:rentable_sqft)
      #Renewal option update start - Need to change this based on lease_id#
      renewal_status_suite_ids = LeaseRentRoll.where(:occupancy_type => 'renewal', :real_estate_property_id => self.real_estate_property_id, :month => self.month, :year => self.year).map(&:suite_id)
      renewal_rentable_sqft = Suite.where(:id => renewal_status_suite_ids, :real_estate_property_id => self.real_estate_property_id).sum(:rentable_sqft)
      commercial_lease_occupancy = CommercialLeaseOccupancy.find_by_real_estate_property_id_and_month_and_year(self.real_estate_property_id, self.month, self.year)
      if commercial_lease_occupancy.present?
        commercial_lease_occupancy.update_attributes(:total_building_rentable_s => total_sqft_of_property, :current_year_sf_occupied_actual =>total_occupied_sqft_of_property, :current_year_sf_vacant_actual =>  total_vacant_sqft_of_property, :new_leases_actual => new_lease_rentable_sqft, :expirations_actual => expiration_rentable_sqft, :renewals_actual => renewal_rentable_sqft, :real_estate_property_id => self.real_estate_property_id, :month => self.month, :year => self.year)
      else
        CommercialLeaseOccupancy.create(:total_building_rentable_s => total_sqft_of_property, :current_year_sf_occupied_actual =>total_occupied_sqft_of_property, :current_year_sf_vacant_actual =>  total_vacant_sqft_of_property, :new_leases_actual => new_lease_rentable_sqft, :expirations_actual => expiration_rentable_sqft, :renewals_actual => renewal_rentable_sqft, :real_estate_property_id => self.real_estate_property_id, :month => self.month, :year => self.year)
      end
    end
  end

  def self.update_old_lease_rent_roll_records
    #leases = Lease.current_leases.join_property_lease_suites
    leases = Lease.current_leases.join_property_lease_suites.each do |lease|
      property_lease_suite = lease.property_lease_suite
      if property_lease_suite.present?
        property_lease_suite.update_lease_rent_roll
        tenant = lease.tenant
        if tenant.present?
        tenant.update_lease_rent_roll(true)
        option = tenant.options.first
        option.update_lease_rent_roll(true) if option.present?
        end
        rent = lease.rent
        if rent.present?
          first_recovery = rent.recoveries.first
          first_recovery.update_lease_rent_roll(true) if first_recovery.present?
          rent_schedules = rent.rent_schedules
          if rent_schedules.present?
            rent_schedules.each do |rent_schedule|
              rent_schedule.update_lease_rent_roll(true)
            end
          end
          percentage_sales_rents = rent.percentage_sales_rents
          if percentage_sales_rents.present?
            percentage_sales_rents.each do |percentage_sales_rent|
              percentage_sales_rent.update_lease_rent_roll(true) if percentage_sales_rent.present?
            end
          end
        end
        cap_ex = lease.cap_ex
        if cap_ex.present?
        cap_ex.update_lease_rent_roll(true)
        first_tenant_improvement = cap_ex.tenant_improvements.first
        first_tenant_improvement.update_lease_rent_roll(true) if first_tenant_improvement.present?
        first_leasing_commission = cap_ex.leasing_commissions.first
        first_leasing_commission.update_lease_rent_roll(true) if first_leasing_commission.present?
        end
      end
    end
  end

end
