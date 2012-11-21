class IncomeProjection < ActiveRecord::Base

  # Associations
  has_one :note, :as => :note,    :dependent => :destroy
  belongs_to :lease

  # Validations
  validates :annual_discount_rate,   :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |income_projection|  income_projection.annual_discount_rate != nil }
  validates :npv_actual,             :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |income_projection|  income_projection.npv_actual != nil }
  validates :npv_budget_or_proforma, :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |income_projection|  income_projection.npv_budget_or_proforma != nil }
  # validates :npv_differential,       :numericality => { :greater_than  => 0 }, :if => Proc.new { |income_projection|  income_projection.npv_differential != nil }

  accepts_nested_attributes_for :note
  # Here I am calculationg percentage of building using below formula
  def self.get_percentage_of_building(lease_rentable_sqft, building_sqft)
    (lease_rentable_sqft.to_f/building_sqft.to_f)*100  if building_sqft.to_i!=0
  end

  # Here I am calculationg net_lease_cash_flow_psf using below formula
  def self.net_lease_cash_flow_psf(net_lease_cash_flow, lease_rentable_sqft)
    net_lease_cash_flow.to_f/lease_rentable_sqft.to_f if  lease_rentable_sqft.to_i!=0
  end

  # Here I am calculationg npv differencial to display in income projection
  def self.npv_differential(npv_actual, npv_budget)
    npv_actual.to_f - npv_budget.to_f
  end

end
