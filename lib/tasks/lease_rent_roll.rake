namespace :lease_rent_roll do
  desc "Inserting the data into lease rent roll table"
  task :push_data_to_lease_rent_roll_table => :environment do
    date_array = []
    a = Date.today
    b = a.prev_year.beginning_of_year
    for i in 5..13
      date_array << b.months_since(i)
    end
    date_array.each do |date_arr|
      begin
        #        date_array.each do |date_arr|
        leases =  Lease.current_leases.join_property_lease_suites.where("leases.real_estate_property_id IN (35, 36, 38, 39, 43, 135, 136, 189, 323, 533, 534, 536, 537)")
        time = date_arr
        leases.each do |lease|
          suite_ids = lease.suite_ids
          if suite_ids.present?
            suite_ids = YAML::load(suite_ids)
            suite_ids = [suite_ids] unless suite_ids.is_a?(Array)
            suite_ids.each do |suite_id|
              suite=Suite.join_rent_schedule.join_recovery.join_percentage_sales_rent.where("suites.id=?",suite_id).first
              
              if suite.present?
                @cap_ex = CapEx.find_by_sql("SELECT A.*, sum(tt.total_amount) as tenant_improvements_tot_amt FROM (SELECT c.id, c.security_deposit_amount, sum(lc.total_amount) as leasing_commission_tot_amt FROM cap_exes c LEFT JOIN leasing_commissions lc ON c.id=lc.cap_ex_id where c.lease_id=#{lease.id}) A LEFT JOIN tenant_improvements tt ON A.id=tt.cap_ex_id ").try(:first) if lease.cap_ex_id.present? 
                options = Option.where(:tenant_id => lease.tenant_id )
                @escalations_period =  RentSchedule.get_rent_schedule_period(suite.percentage_sales_rents_from_date, suite.percentage_sales_rents_to_date)
                
                if @escalations_period.present? && @escalations_period != 0
                  @est_sales_percentage_esc_year = (suite.est_sales_percentage_esc_year.to_i/@escalations_period)*100
                end
                
                if @cap_ex.try(:leasing_commission_tot_amt)
                  leasing_commission_total_amount = @cap_ex.try(:leasing_commission_tot_amt)
                else
                  rent = lease.rent if lease.present?
                  leasing_commissions = lease.try(:cap_ex).try(:leasing_commissions)
                  if rent.present? && leasing_commissions.present?
                    rent_schedules  = rent.rent_schedules 
                    rent_schedules_leasing_commissions_total_amount = 0
                    rent_schedules.each do |rent_schedule|
                      rent_schedules_leasing_commissions_total_amount = rent_schedules_leasing_commissions_total_amount + rent_schedule.find_leasing_commission(lease,leasing_commissions).to_f rescue nil
                    end
                    leasing_commission_total_amount = rent_schedules_leasing_commissions_total_amount
                  end
                end
                
                option_data = []
                options.each do |option|
                  option_data << option.try(:option_type)
                  option_data << "#{option.try(:option_start)} to #{option.try(:option_end)}" if option.try(:option_start).present? && option.try(:option_end).present?
                  option_data << "#{option.try(:notice_start)} to #{option.try(:notice_end)}" if option.try(:notice_start).present? && option.try(:notice_end).present?
                end
                
                options_string = option_data.join(",")
                lease_rent_roll = LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,time.month, time.year)
                if lease_rent_roll.present?
                  lease_rent_roll.update_attributes(:tenant => lease.tenant_legal_name, :sqft => suite.rentable_sqft,:lease_start_date => lease.commencement, :lease_end_date => lease.expiration, :base_rent_monthly_amount => suite.amount_per_month, :base_rent_annual_psf => suite.amount_per_month_per_sqft, :escalations_period => @escalations_period,:escalations_monthly_amount => @est_sales_percentage_esc_year,:per_sales_floor => suite.floor_amt ,:per_sales_percentage => suite.sales_rent_percentage, :recoveries_charge => suite.value, :recoveries_info => suite.recovery_method,:tis_amount => @cap_ex.try(:tenant_improvements_tot_amt), :lcs_amount => leasing_commission_total_amount, :options => options_string,  :security_deposit_amount => @cap_ex.try(:security_deposit_amount),  :month => time.month, :year => time.year, :suite_id => suite_id, :real_estate_property_id =>lease.real_estate_property_id, :occupancy_type => lease.occupancy_type, :lease_id => lease.id, :effective_rate => lease.effective_rate)
                else
                  LeaseRentRoll.create(:tenant => lease.tenant_legal_name, :sqft => suite.rentable_sqft,:lease_start_date => lease.commencement, :lease_end_date => lease.expiration, :base_rent_monthly_amount => suite.amount_per_month, :base_rent_annual_psf => suite.amount_per_month_per_sqft, :escalations_period => @escalations_period,:escalations_monthly_amount => @est_sales_percentage_esc_year,:per_sales_floor => suite.floor_amt ,:per_sales_percentage => suite.sales_rent_percentage, :recoveries_charge => suite.value, :recoveries_info => suite.recovery_method,:tis_amount => @cap_ex.try(:tenant_improvements_tot_amt), :lcs_amount => leasing_commission_total_amount, :options => options_string,  :security_deposit_amount => @cap_ex.try(:security_deposit_amount),  :month => time.month, :year => time.year, :suite_id => suite_id, :real_estate_property_id =>lease.real_estate_property_id, :occupancy_type => lease.occupancy_type, :lease_id => lease.id, :effective_rate => lease.effective_rate)
                end
                
                @cap_ex = nil; @escalations_period = nil; @est_sales_percentage_esc_year=nil
              end
            end
          end
        end
        
        suites = Suite.where(:status => "Vacant")
        time = date_arr
        suites.each do |suite|
          lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite.id,time.month, time.year)
          
          if lease_rent_roll.present?
            lease_rent_roll.update_attributes(:suite_id => suite.id, :real_estate_property_id => suite.real_estate_property_id, :sqft => suite.rentable_sqft, :month => time.month, :year => time.year)
          else
            LeaseRentRoll.create(:suite_id => suite.id, :real_estate_property_id => suite.real_estate_property_id, :sqft => suite.rentable_sqft, :tenant => "Vacant", :month => time.month, :year => time.year)
          end
        end
        
      rescue => e
        puts "Exception had been raised with message: #{e.message}"
      end
    end
  end
end