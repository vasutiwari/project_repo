class CapEx < ActiveRecord::Base

  # Associations
  has_many   :tenant_improvements, :dependent => :destroy
  has_many   :other_exps, :dependent => :destroy
  has_many   :leasing_commissions, :dependent => :destroy
  has_one    :note, :as => :note, :dependent => :destroy
  belongs_to :lease

  #Callbacks
  after_save :calling_lease_rent_roll_from_delayed_job

  # Validations
  validates :security_deposit_amount ,        :numericality => { :greater_than_or_equal_to  => 0 },                        :if => Proc.new { |cap_ex|  cap_ex.security_deposit_amount != nil }
  validates :security_deposit_interest_rate , :numericality => { :greater_than_or_equal_to => 0 },                         :if => Proc.new { |cap_ex|  cap_ex.security_deposit_interest_rate != nil }
  validates :rent_prepaid_amount ,            :numericality => { :greater_than_or_equal_to => 0 },                         :if => Proc.new { |cap_ex|  cap_ex.rent_prepaid_amount != nil }
  validates :key_deposit_amount ,             :numericality => { :greater_than_or_equal_to => 0 },                         :if => Proc.new { |cap_ex|  cap_ex.key_deposit_amount != nil }
  validates :letter_of_credit_amount ,        :numericality => { :greater_than_or_equal_to => 0 },                         :if => Proc.new { |cap_ex|  cap_ex.letter_of_credit_amount != nil }
  validates :tax_id_tax_rate ,                :numericality => { :greater_than_or_equal_to => 0 },                         :if => Proc.new { |cap_ex|  cap_ex.tax_id_tax_rate != nil }
  #validates :tax_id_tax_authority_number  ,   :numericality => { :greater_than_or_equal_to => 0, :only_integer => true },  :if => Proc.new { |cap_ex|  cap_ex.tax_id_tax_authority_number != nil }

  accepts_nested_attributes_for :note,:allow_destroy => true,:reject_if => proc { |attrs| attrs.all? { |k, v| v.blank? } }
  accepts_nested_attributes_for :tenant_improvements,:allow_destroy => true,:reject_if => lambda { |a| (a['name'].blank? && a['amount_psf'].blank? && a['total_amount'].blank? && (a['work_start_date'].blank? || a['work_start_date'] == 'mm/dd/yyyy'))}
  accepts_nested_attributes_for :other_exps,:allow_destroy => true,:reject_if => lambda { |a| (a['name'].blank? && a['amt_psf'].blank? && a['tot_amt'].blank?)}
  #~ accepts_nested_attributes_for :leasing_commissions,:allow_destroy => true,:reject_if => lambda { |a| (a['broker_or_agent'].blank? && a['percentage_for_first_year'].blank? && a['percentage_for_second_year'].blank? && a['percentage_for_third_year'].blank? && a['percentage_for_fourth_year'].blank? && a['percentage_for_fifth_year'].blank? && a['percentage_for_sixth_year'].blank? && a['percentage_for_seventh_year'].blank? && a['percentage_for_eighth_year'].blank? && a['percentage_for_ninth_year'].blank? && a['percentage_for_tenth_year'].blank? && a['total_amount'].blank? && a['dollar_per_sf'].blank?)}
  accepts_nested_attributes_for :leasing_commissions,:allow_destroy => true,:reject_if => proc { |attrs| attrs.all? { |k, v| v.blank? } }
  def self.lease_cap_ex(params)
    self.create(:lease_id => $new_lease.try(:id),:security_deposit_amount => params[:security_deposit_amount],:security_deposit_interest_rate => params[:security_deposit_interest_rate],:security_deposit_lpara => params[:security_deposit_lpara],:rent_prepaid_amount => params[:rent_prepaid_amount],:rent_prepaid_for_months => params[:rent_prepaid_for_months],:rent_prepaid_lpara => params[:rent_prepaid_lpara],:late_charges_grace_and_penalities => params[:late_charges_grace_and_penalities],:guarantor_name => params[:guarantor_name],:guarantor_address => params[:guarantor_address],:key_deposit_amount => params[:key_deposit_amount],:key_deposit_lpara => params[:key_deposit_lpara],:letter_of_credit_amount => params[:letter_of_credit_amount],:letter_of_credit_expiration_date => params[:letter_of_credit_expiration_date],:letter_of_credit_expiration_lpara => params[:letter_of_credit_expiration_lpara],:tax_id_tax_authority_number => params[:tax_id_tax_authority_number],:tax_id_tax_rate => params[:tax_id_tax_rate],:tax_id_phone => params[:tax_id_phone])
  end

  # Here I am doing calcuations required to display in income projections
  def self.get_cap_ex_details(cap_ex)
    if cap_ex.present?
      tenant_improvements = cap_ex.tenant_improvements

      # Here we are doing calcuations to display tenant improvements
      if tenant_improvements.present?
        no_of_tenant_improvements = tenant_improvements.count
        tenant_improvements_total_amount = tenant_improvements.sum(:total_amount)
        tenant_improvements_total_amount_psf = tenant_improvements.sum(:amount_psf)
      tenant_improvements_average_of_total_amount = tenant_improvements_total_amount / no_of_tenant_improvements if no_of_tenant_improvements.present? && no_of_tenant_improvements > 0
      tenant_improvements_average_of_total_amount_psf = tenant_improvements_total_amount_psf / no_of_tenant_improvements if no_of_tenant_improvements.present? && no_of_tenant_improvements > 0
      end

      leasing_commissions = cap_ex.leasing_commissions

      # Here we are doing calcuations to display leasing commissions
      if  leasing_commissions.present?
        check_leasing_commissions_first_year_percentages = leasing_commissions.map(&:percentage_for_first_year).compact.present? rescue nil
        procurement_and_listing_leasing_commissions = cap_ex.leasing_commissions.where(:leasing_commission_type => ["Listing", "Procurement"])
        bonus_leasing_commissions = cap_ex.leasing_commissions.where(:leasing_commission_type => "Bonus")
      #display_leasing_commissions_total_amount = leasing_commissions.sum(:total_amount)

      lease = cap_ex.lease
      #        rent = lease.rent if lease.present?
      #        if rent.present?
      #          rent_schedules  = rent.rent_schedules
      #          rent_schedules_leasing_commissions_total_amount = 0
      #          rent_schedules.each do |rent_schedule|
      #            rent_schedules_leasing_commissions_total_amount = rent_schedules_leasing_commissions_total_amount + rent_schedule.find_leasing_commission(lease,leasing_commissions).to_f rescue nil
      #          end
      #        end

      #        if display_leasing_commissions_total_amount==0
      #          leasing_commissions_total_amount = rent_schedules_leasing_commissions_total_amount
      #        else
      #          leasing_commissions_total_amount = display_leasing_commissions_total_amount
      #        end

      # leasing_commissions_amount_psf = leasing_commissions.sum(:dollar_per_sf)
      end

      other_exps = cap_ex.other_exps

      other_exps_total_amount = other_exps.sum(:tot_amt) if other_exps.present?

    #   total_lease_capital_costs = tenant_improvements_total_amount.to_f + leasing_commissions_total_amount.to_f + other_exps_total_amount.to_f
    end

    # I am sending results back to controller
    [cap_ex, tenant_improvements, tenant_improvements_total_amount, tenant_improvements_average_of_total_amount, tenant_improvements_total_amount_psf, tenant_improvements_average_of_total_amount_psf, leasing_commissions,
      procurement_and_listing_leasing_commissions, bonus_leasing_commissions,
      check_leasing_commissions_first_year_percentages, other_exps, other_exps_total_amount]

  end

  def update_lease_rent_roll(security_deposit_amount_changed)
    if security_deposit_amount_changed
      if self.security_deposit_amount.present? && self.try(:lease).try(:is_executed) && self.try(:lease).try(:commencement) && self.try(:lease).try(:expiration)
        property_lease_suite = self.lease.try(:property_lease_suite)
        if property_lease_suite.present? && property_lease_suite.suite_ids?
          number_of_months = RentSchedule.get_rent_schedule_period(lease.try(:commencement), Time.now)
          0.upto(number_of_months) do |month|
            current_year = (self.lease.commencement + month.months).year rescue nil
            current_month = (lease.try(:commencement) + month.months).month rescue nil
            property_lease_suite.suite_ids.each do |suite_id|
              lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,current_month,current_year)
              lease_rent_roll.update_attributes(:security_deposit_amount => self.security_deposit_amount)  if lease_rent_roll.present?
            end
          end
        end
      end
    end
  end

  def calling_lease_rent_roll_from_delayed_job
    security_deposit_amount_changed =  self.security_deposit_amount_changed?
    self.delay.update_lease_rent_roll(security_deposit_amount_changed)
  end

end