class Recovery < ActiveRecord::Base

  # Associations
  belongs_to :rent
  has_one :note, :as => :note,    :dependent => :destroy

  # Callbacks
  before_save :revovery_all_suites_set
  after_save :calling_lease_rent_roll_from_delayed_job

  # Validations
  validates :value ,          :numericality => { :greater_than  => 0 }, :if => Proc.new { |recovery|  recovery.value != nil }
  validates :billable_sqft ,  :numericality => { :greater_than  => 0 }, :if => Proc.new { |recovery|  recovery.billable_sqft != nil }
  validates :fixed_prorata ,  :numericality => { :greater_than  => 0 }, :if => Proc.new { |recovery|  recovery.fixed_prorata != nil }
  validates :gross_up ,       :numericality => { :greater_than  => 0 }, :if => Proc.new { |recovery|  recovery.gross_up != nil }
  validates :expense_cap ,    :numericality => { :greater_than  => 0 }, :if => Proc.new { |recovery|  recovery.expense_cap != nil }

  # Constants
  RECOVERY_TYPE = [
    ["",nil],
    [ "CAM", "CAM" ],
    [ "CAM (Mall)", "CAM (Mall)" ],
    [ "All Expenses", "All Expenses" ],
    [ "Utilities", "Utilities" ],
    [ "Management Fee", "Management Fee" ]
  ]
  RECOVERY_BILLING = [
    [ "Monthly", "Monthly" ],
    [ "Quarterly", "Quarterly" ],
    [ "Yearly", "Yearly" ]
  ]
  RECOVERY_METHOD = [
    ["",nil],
    [ "Base Year", "Base Year" ],
    [ "Expense Stop Base Amt", "Expense Stop Base Amt" ],
    [ "Expense Stop Annual %", "Expense Stop Annual %" ]
  ]
  RANK_COMPARISON_FINANCIAL_ACCESS = [
    ["YTD - NOI Variances","YTD - NOI Variances"],
    ["Vacancy","Vacancy"],
    ["Tenant A/R","Tenant A/R"],
    ["Expirations","Expirations"]
  ]
  RANK_COMPARISON_WITHOUT_FINANCIAL_ACCESS = [
    ["Vacancy","Vacancy"],
    ["Tenant A/R","Tenant A/R"],
    ["Expirations","Expirations"]
  ]

  # Old Code May be needed in Future thats why i kept it like this
  #  def update_lease_rent_roll
  #    lease = self.rent.try(:lease)
  #    if lease.try(:is_executed) && lease.try(:commencement)
  #      number_of_months = RentSchedule.get_rent_schedule_period(lease.try(:commencement), Time.now)
  #      if self.suite_id.present? && !self.suite_id.eql?(0)
  #        lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(self.suite_id,Time.now.month,Time.now.year)
  #        lease_rent_roll.update_attributes(:recoveries_charge => self.recv_charge_type, :recoveries_info => self.recovery_method)  if lease_rent_roll.present?
  #      elsif self.is_all_suites_selected.present?
  #        suite_ids = lease.try(:property_lease_suite).try(:suite_ids)
  #        suite_ids.each do |suite_id|
  #          lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,Time.now.month,Time.now.year)
  #          lease_rent_roll.update_attributes(:recoveries_charge => self.recv_charge_type, :recoveries_info => self.recovery_method)  if lease_rent_roll.present?
  #        end
  #      end
  #    end
  #  end

  def calling_lease_rent_roll_from_delayed_job
    recovery_changes =  self.recv_charge_type_changed? ||  self.recovery_method_changed?
    self.delay.update_lease_rent_roll(recovery_changes)
  end

  def update_lease_rent_roll(recovery_changes)
    if recovery_changes
      lease = self.rent.try(:lease)
      if lease.try(:is_executed) && lease.try(:commencement)
        property_lease_suite = lease.property_lease_suite
        if property_lease_suite.present? && property_lease_suite.suite_ids?
          number_of_months = RentSchedule.get_rent_schedule_period(lease.try(:commencement), Time.now)
          recv_charge_types = self.rent.recoveries.map(&:recv_charge_type).uniq.join(",") rescue nil
          recovery_methods = self.rent.recoveries.map(&:recovery_method).uniq.join(",") rescue nil
          0.upto(number_of_months) do |month|
            current_year = (lease.commencement + month.months).year rescue nil
            current_month = (lease.commencement + month.months).month rescue nil
            suite_ids = lease.try(:property_lease_suite).try(:suite_ids)
            if current_year.present? && current_month.present?
              suite_ids.each do |suite_id|
                lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,current_month,current_year)
                lease_rent_roll.update_attributes(:recoveries_charge => recv_charge_types, :recoveries_info => recovery_methods)  if lease_rent_roll.present?
              end
            end
          end
        end
      end
    end
  end

  private

  def revovery_all_suites_set
    if self.suite_id.eql?(0)
    self.is_all_suites_selected = 1
    else
      self.is_all_suites_selected = nil
    end
  end

end
