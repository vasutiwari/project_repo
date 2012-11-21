class OtherRevenue < ActiveRecord::Base

  # Associations
  belongs_to :rent
  before_save :other_revenue_all_suites_set

  # Validations
  validates :billable_sqft ,             :numericality => { :greater_than  => 0 }, :if => Proc.new { |other_revenue|  other_revenue.billable_sqft != nil }
  validates :amount_per_month ,          :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |other_revenue|  other_revenue.amount_per_month != nil }
  validates :amount_per_month_per_sqft , :numericality => { :greater_than_or_equal_to => 0 },   :if => Proc.new { |other_revenue|  other_revenue.amount_per_month_per_sqft != nil }

  # Constants
  BILLING_FREQ = [
  [ "Monthly", "Monthly" ],
  [ "Quarterly", "Quarterly" ],
  [ "Yearly", "Yearly" ]
  ]

  def self.total_other_revenue(other_revenues)
    @total_amount = 0

    other_revenues.each do |other_revenue|

      if other_revenue.from_date? && other_revenue.to_date? && other_revenue.amount_per_month?

        other_revenue_from_date = other_revenue.from_date.to_s
        other_revenue_to_date =   other_revenue.to_date.to_s

        escalations_period = RentSchedule.get_rent_schedule_period(other_revenue_from_date, other_revenue_to_date)

      amount = escalations_period.to_f * other_revenue.amount_per_month.to_f

      @total_amount = @total_amount + amount
      end
    end
    @total_amount
  end

  def total_other_revenue_per_month(from_date=nil,to_date=nil,amount_per_month=nil)
    if from_date.present? && to_date.present? && amount_per_month.present?
      other_revenue_from_date = from_date.to_s
      other_revenue_to_date =   to_date.to_s
      escalations_period = RentSchedule.get_rent_schedule_period(other_revenue_from_date, other_revenue_to_date)
    @amount = escalations_period.to_f * amount_per_month.to_f
    end
    @amount
  end

  def other_revenue_all_suites_set
    if self.suite_id.eql?(0)
    self.is_all_suites_selected = 1
    else
      self.is_all_suites_selected = nil
    end
  end
end
