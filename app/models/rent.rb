class Rent < ActiveRecord::Base

  # Associations
  has_many   :rent_schedules,         :dependent => :destroy
  has_many   :other_revenues,         :dependent => :destroy
  has_many   :percentage_sales_rents, :dependent => :destroy
  has_many   :recoveries,             :dependent => :destroy
  has_many   :parkings,               :dependent => :destroy
  has_many   :cpi_details,            :class_name => "CpiDetails", :dependent => :destroy
  belongs_to :lease

  accepts_nested_attributes_for :cpi_details,:reject_if => proc { |attrs| attrs.all? { |k, v| v.blank? } }, :allow_destroy => true
  accepts_nested_attributes_for :parkings,:reject_if => lambda { |attrs| attrs['reserved_number'].blank? && attrs['reserver_amount_per_space_per_month'].blank? && attrs['unreserved_number'].blank? && attrs['unreserved_amount_per_space_per_month'].blank? }, :allow_destroy => true
  accepts_nested_attributes_for :other_revenues,:reject_if => lambda { |attrs| attrs['other_revenue_type'].blank? && attrs['billable_sqft'].blank? && attrs['amount_per_month'].blank? && attrs['amount_per_month_per_sqft'].blank? && attrs['billing_freq'].blank? && attrs['from_date'].eql?('mm/dd/yyyy') && attrs['to_date'].eql?('mm/dd/yyyy')}, :allow_destroy => true
  accepts_nested_attributes_for :rent_schedules,:reject_if => lambda { |attrs| attrs['rent_schedule_type'].blank? && attrs['amount_per_month_per_sqft'].blank? && attrs['amount_per_month'].blank? && attrs['billing_freq'].blank? && attrs['base_year'].blank? &&  ( attrs['to_date'].eql?('mm/dd/yyyy') || attrs['to_date'].blank? ) }, :allow_destroy => true # Here I am doing calcuations required to display in income projections
  accepts_nested_attributes_for :percentage_sales_rents,:reject_if => lambda { |attrs| attrs['sales_category'].blank? && attrs['sales_rent_percentage'].blank? && attrs['floor_amt'].blank? && attrs['ceiling_amt'].blank? && attrs['billing_freq'].blank? && attrs['sales_rent_due_date'].eql?('mm/dd/yyyy') && attrs['from_date'].eql?('mm/dd/yyyy') && attrs['to_date'].eql?('mm/dd/yyyy')  && attrs['bill_type'].blank?  && attrs['estimation_for_projection_sales_est'].blank?  && attrs['est_sales_percentage_esc_year'].blank?}, :allow_destroy => true
  accepts_nested_attributes_for :recoveries,:reject_if => lambda { |attrs| attrs['recv_charge_type'].blank? && attrs['from_date'].eql?('mm/dd/yyyy') && attrs['billable_sqft'].blank? && attrs['billed_freq'].blank? && attrs['to_date'].eql?('mm/dd/yyyy') && attrs['recovery_method'].blank? && attrs['value'].blank? && attrs['fixed_prorata'].blank? && attrs['gross_up'].blank? && attrs['expense_cap'].blank? }, :allow_destroy => true
  def self.rent_details(rent,lease, check_leasing_commissions_first_year_percentages, leasing_commissions, lease_rentable_sqft)
    rent = rent
    if rent.present?
      rent_schedules =  rent.rent_schedules.order(:suite_id,:from_date)
      # Here we are doing calcuations to display rent schedules
      if leasing_commissions.present?
        listing_leasing_commission = leasing_commissions.where(:leasing_commission_type => "Listing").try(:first)
        procurement_leasing_commission = leasing_commissions.where(:leasing_commission_type => "Procurement").try(:first)
        bonus_leasing_commission_total_amount = leasing_commissions.where(:leasing_commission_type => "Bonus").first.try(:total_amount) || 0
      end

      if rent_schedules.present?

        #calculating budget psf for rent#
        budget_psf_value = rent.budget_psf.to_f

        total_base_rent_revenue = 0 # RentSchedule.find_base_rent_revenue(rent_schedules)
        is_cpi_escalation = rent.is_cpi_escalation

        cpi_details = lease.rent.cpi_details.first

        if rent.is_cpi_escalation &&  cpi_details.present? && cpi_details.adjustment_frequency=="12"
          display_rent_schedules, rent_schedules_total_rent_revenue,procurement_leasing_commission_total_amount, listing_leasing_commission_total_amount, rent_schedules_leasing_commissions_total_amount = RentSchedule.get_rent_schedules_with_cpi_details(rent_schedules, cpi_details.annual_cpi_inc_estimate,12.0,1,is_cpi_escalation,check_leasing_commissions_first_year_percentages, leasing_commissions,lease, lease_rentable_sqft, cpi_details, procurement_leasing_commission, listing_leasing_commission)
        elsif rent.is_cpi_escalation && cpi_details.present? && cpi_details.adjustment_frequency=="24"
          display_rent_schedules,rent_schedules_total_rent_revenue,procurement_leasing_commission_total_amount, listing_leasing_commission_total_amount,rent_schedules_leasing_commissions_total_amount = RentSchedule.get_rent_schedules_with_cpi_details(rent_schedules, cpi_details.annual_cpi_inc_estimate, 24.0,2,is_cpi_escalation, check_leasing_commissions_first_year_percentages, leasing_commissions,lease, lease_rentable_sqft, cpi_details,procurement_leasing_commission, listing_leasing_commission)
        else
          display_rent_schedules,rent_schedules_total_rent_revenue,procurement_leasing_commission_total_amount, listing_leasing_commission_total_amount,rent_schedules_leasing_commissions_total_amount = RentSchedule.get_rent_schedules_with_cpi_details(rent_schedules, nil, 12.0,1,is_cpi_escalation,check_leasing_commissions_first_year_percentages, leasing_commissions,lease, lease_rentable_sqft, cpi_details,procurement_leasing_commission, listing_leasing_commission)
        end

        if rent.is_all_suites_selected
          total_number_of_months = RentSchedule.find_total_number_of_months(rent_schedules)
          rent_schedules_total_amount_per_month = rent_schedules_total_rent_revenue.to_f/total_number_of_months unless total_number_of_months.eql?(0)
        else
          rent_schedules_total_amount_per_month = RentSchedule.get_total_amount_per_month_basing_on_individual_suites(display_rent_schedules) || 0
        end

        total_escalation_revenue  = 0 #  rent_schedules_total_rent_revenue.to_f - total_base_rent_revenue.to_f

        # rent_schedules_total_amount_per_month_per_sqft = rent_schedules.sum(:amount_per_month_per_sqft)
        # rent_schedules_total_amount_per_month = rent_schedules.sum(:amount_per_month)
      end

      if listing_leasing_commission_total_amount.blank? || listing_leasing_commission_total_amount.eql?(0.0) || listing_leasing_commission_total_amount.eql?(0)
        listing_leasing_commission_total_amount = listing_leasing_commission.try(:total_amount)
      end

      if procurement_leasing_commission_total_amount.blank? || procurement_leasing_commission_total_amount.eql?(0.0) || procurement_leasing_commission_total_amount.eql?(0)
        procurement_leasing_commission_total_amount = procurement_leasing_commission.try(:total_amount)
      end

      display_leasing_commissions_total_amount = procurement_leasing_commission_total_amount.to_f +  listing_leasing_commission_total_amount.to_f + bonus_leasing_commission_total_amount.to_f

      other_revenues = rent.other_revenues
      parkings = rent.parkings

      # Here we are doing calcuations to display percentage sales rents
      percentage_sales_rents = rent.percentage_sales_rents
      displayed_percentage_sales_rents, final_percentage_sales_rent =  PercentageSalesRent.collection(percentage_sales_rents)
      estimation_sales_total = 0
      sales_percentage_total = 0
      percentage_sales_rents.each do |percentage_sales_rent|
        if percentage_sales_rent.present?
          sales_percentage_total = sales_percentage_total + percentage_sales_rent.sales_rent_percentage.to_f
          estimation_sales_total = estimation_sales_total + percentage_sales_rent.find_estimation_sales(percentage_sales_rent.estimation_for_projection_sales_est, percentage_sales_rent.est_sales_percentage_esc_year).to_f
        end
      end
      # total_rent_revenue = RentSchedule.total_rent_revenue(rent_schedules)
      total_other_revenue = OtherRevenue.total_other_revenue(other_revenues)
      total_parking_revenue = parkings.first.total_parking_revenue(lease.try(:expiration), lease.try(:commencement), parkings.sum(:total_monthly)) if parkings.present?
      sales_revenue = final_percentage_sales_rent[:sales_rent_rev]    rescue nil  if final_percentage_sales_rent.present?
      total_lease_revenue = rent_schedules_total_rent_revenue.to_f + total_other_revenue.to_f + total_parking_revenue.to_f +  sales_revenue.to_f
    end

    # I am sending results back to controller
    [rent, display_rent_schedules, rent_schedules_total_amount_per_month,rent_schedules_total_rent_revenue, procurement_leasing_commission_total_amount, listing_leasing_commission_total_amount,rent_schedules_leasing_commissions_total_amount,display_leasing_commissions_total_amount, other_revenues, parkings, percentage_sales_rents, displayed_percentage_sales_rents, final_percentage_sales_rent, sales_percentage_total, estimation_sales_total, rent_schedules_total_rent_revenue, total_other_revenue, total_parking_revenue, sales_revenue, total_lease_revenue, total_base_rent_revenue || 0, total_escalation_revenue || 0,budget_psf_value ]

  end

end
