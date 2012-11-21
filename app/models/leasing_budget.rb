class LeasingBudget < ActiveRecord::Base

  attr_accessor :current_selected_year

  belongs_to :real_estate_property
  serialize :lease_expirations, Hash
  serialize :existing_lease_renewals, Hash
  serialize :new_leases, Hash
  serialize :area_rsf, Hash
  serialize :area_percentage, Hash
  serialize :occupancy_beginning_of_period, Hash

  before_save :update_data_in_commercial_lease_occupancy_table

  YEAR = {
    Time.now.year => Time.now.year,
    Time.now.year+1 => Time.now.year+1,
    Time.now.year+2 => Time.now.year+2
  }

  PERIOD = {1 => "January", 2 => "February", 3 => "March", 4 => "April", 5 => "May" ,6 => "June", 7 => "July", 8 => "August", 9 => "September", 10 => "October", 11 => "November", 12 => "December", 13 => "End of Year"}


  def update_data_in_commercial_lease_occupancy_table
    if self.real_estate_property_id.present? && self.selected_year.present?
      total_sqft_of_property = Suite.where(:real_estate_property_id => self.real_estate_property_id).sum(:rentable_sqft)
      occupancy_beginning_of_period = self.occupancy_beginning_of_period["0"] if self.occupancy_beginning_of_period.present?
       (1..12).each do |month|
        current_year_sf_occupied_budget = (self.area_rsf["#{month}"]).gsub(",", "") rescue 0
        current_year_sf_vacant_budget = total_sqft_of_property - current_year_sf_occupied_budget.to_f
        commercial_lease_occupancy = CommercialLeaseOccupancy.find_by_real_estate_property_id_and_month_and_year(self.real_estate_property_id, month, self.selected_year)
        new_leases_budget = self.new_leases["#{month}"] rescue 0
        renewals_budget = self.existing_lease_renewals["#{month}"] rescue 0
        expirations_budget = self.lease_expirations["#{month}"] rescue 0
        if commercial_lease_occupancy.present?
          commercial_lease_occupancy.update_attributes(:total_building_rentable_s => total_sqft_of_property ,:last_year_sf_occupied_budget => occupancy_beginning_of_period, :current_year_sf_occupied_budget => current_year_sf_occupied_budget, :current_year_sf_vacant_budget => current_year_sf_vacant_budget, :new_leases_budget => new_leases_budget, :renewals_budget => renewals_budget, :expirations_budget => expirations_budget, :real_estate_property_id => self.real_estate_property_id, :month => month, :year => selected_year)
        else
          CommercialLeaseOccupancy.create(:total_building_rentable_s => total_sqft_of_property ,:last_year_sf_occupied_budget => occupancy_beginning_of_period, :current_year_sf_occupied_budget => current_year_sf_occupied_budget, :current_year_sf_vacant_budget => current_year_sf_vacant_budget, :new_leases_budget => new_leases_budget, :renewals_budget => renewals_budget, :expirations_budget => expirations_budget, :real_estate_property_id => self.real_estate_property_id, :month => month, :year => selected_year)
        end
      end
    end
  end

  def self.leasing_budget(note,selected_year=nil)
    if selected_year.present?
      leasing_budget = note.leasing_budgets.where(:selected_year => selected_year).first
      if leasing_budget.blank?
        leasing_budget =  LeasingBudget.new(:selected_year => selected_year)
      end
    else
      current_year = Time.now.year
      if note.leasing_budgets.present?
        leasing_budget = note.leasing_budgets.where(:selected_year => current_year).first
        leasing_budget = LeasingBudget.new() if leasing_budget.blank?
      else
        leasing_budget = LeasingBudget.new(:selected_year => current_year)
      end
    end
    leasing_budget
  end

  def self.leasing_budget_with_selected_year(selected_year)

  end
end
