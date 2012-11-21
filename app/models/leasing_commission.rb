class LeasingCommission < ActiveRecord::Base

  # Associations
  has_one    :note, :as => :note
  belongs_to :cap_ex

  #Callbacks
  after_save :calling_lease_rent_roll_from_delayed_job

  # Validations
  validates :total_amount ,                :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.total_amount  != nil }
  validates :dollar_per_sf ,               :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.dollar_per_sf != nil }
  validates :percentage_for_first_year ,   :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_first_year != nil }
  validates :percentage_for_second_year ,  :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_second_year != nil }
  validates :percentage_for_third_year ,   :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_third_year != nil }
  validates :percentage_for_fourth_year ,  :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_fourth_year != nil }
  validates :percentage_for_fifth_year ,   :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_fifth_year != nil }
  validates :percentage_for_sixth_year ,   :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_sixth_year != nil }
  validates :percentage_for_seventh_year , :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_seventh_year != nil }
  validates :percentage_for_eighth_year ,  :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_eighth_year != nil }
  validates :percentage_for_ninth_year ,   :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_ninth_year != nil }
  validates :percentage_for_tenth_year ,   :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |leasing_commission|  leasing_commission.percentage_for_tenth_year != nil }

  accepts_nested_attributes_for :note
  def self.leasing_commission_data_push(params,capexid)
    self.create(:leasing_commission_type => "Listing",:broker_or_agent=> params[:listing_broker_or_agent],:total_amount => params[:listing_tot_amt],:dollar_per_sf => params[:listing_dollar_per_sf],:cap_ex_id => capexid) if params[:listing_broker_or_agent].present? || params[:listing_tot_amt].present? || params[:listing_dollar_per_sf].present?
    self.create(:leasing_commission_type => "Procurement",:broker_or_agent=> params[:procurement_broker_or_agent],:total_amount => params[:procurement_tot_amt],:dollar_per_sf => params[:procurement_dollar_per_sf],:cap_ex_id => capexid) if params[:procurement_broker_or_agent].present? || params[:procurement_tot_amt].present? || params[:procurement_dollar_per_sf].present?
    self.create(:leasing_commission_type => "Bonus",:broker_or_agent=> params[:bonus_broker_or_agent],:cap_ex_id => capexid) if params[:bonus_broker_or_agent].present?
  end

  def self.find_dollar_per_sqft_of_leasing_commissions(lease_rentable_sqft, procurement_leasing_commission_total_amount, listing_leasing_commission_total_amount, bonus_leasing_commission_total_amount)

    if lease_rentable_sqft.present?
    procurement_leasing_commission_dollar_per_sqft = procurement_leasing_commission_total_amount.to_f / lease_rentable_sqft
    listing_leasing_commission_dollar_per_sqft = listing_leasing_commission_total_amount.to_f / lease_rentable_sqft
    bonus_leasing_commission_dollar_per_sqft = bonus_leasing_commission_total_amount.to_f / lease_rentable_sqft
    leasing_commission_total_dollar_per_sqft = procurement_leasing_commission_dollar_per_sqft.to_f+listing_leasing_commission_dollar_per_sqft.to_f+bonus_leasing_commission_dollar_per_sqft.to_f
    end

    [procurement_leasing_commission_dollar_per_sqft || 0, listing_leasing_commission_dollar_per_sqft || 0, bonus_leasing_commission_dollar_per_sqft || 0, leasing_commission_total_dollar_per_sqft || 0]

  end

  def self.find_lease_capital_cost(tenant_improvements_total_amount , leasing_commissions_total_amount , other_exps_total_amount)
    tenant_improvements_total_amount.to_f + leasing_commissions_total_amount.to_f + other_exps_total_amount.to_f
  end

  def calling_lease_rent_roll_from_delayed_job
    total_amount_changed =  self.total_amount_changed?
    self.delay.update_lease_rent_roll(total_amount_changed)
  end

  def update_lease_rent_roll(total_amount_changed)
    if self.total_amount.present? && total_amount_changed
      lease = self.try(:cap_ex).try(:lease)
      if lease.try(:is_executed)  && lease.try(:commencement) && lease.try(:expiration)
        property_lease_suite = lease.try(:property_lease_suite)
        if property_lease_suite.present? && property_lease_suite.suite_ids?
          number_of_months = RentSchedule.get_rent_schedule_period(lease.try(:commencement), Time.now)
          total_amount = lease.cap_ex.leasing_commissions.sum(:total_amount) rescue nil
          0.upto(number_of_months) do |month|
            current_year = (lease.try(:commencement) + month.months).year rescue nil
            current_month = (lease.try(:commencement) + month.months).month rescue nil
            if current_year.present? && current_month.present?
              property_lease_suite.suite_ids.each do |suite_id|
                lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,current_month,current_year)
                lease_rent_roll.update_attributes( :lcs_amount => total_amount)  if lease_rent_roll.present?
              end
            end
          end
        end
      end
    end
  end

end