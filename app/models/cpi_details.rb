class CpiDetails < ActiveRecord::Base
  # Associations
  belongs_to :rent
  has_one :note, :as => :note,    :dependent => :destroy
  before_save :cpi_all_suites_set

  # Validations
  validates :annual_cpi_inc_estimate ,  :numericality => { :greater_than  => 0 },  :if => Proc.new { |cpi_details|  cpi_details.annual_cpi_inc_estimate != nil }
  validates :yearly_min ,               :numericality => { :greater_than  => 0 },   :if => Proc.new { |cpi_details|  cpi_details.yearly_min != nil }
  validates :yearly_max ,               :numericality => { :greater_than  => 0 },   :if => Proc.new { |cpi_details|  cpi_details.yearly_max != nil }
  validates :lease_max ,                :numericality => { :greater_than  => 0 },   :if => Proc.new { |cpi_details|  cpi_details.lease_max != nil }
  validates :adjustment_start_month ,  :presence => true, :if => Proc.new{|cpi_details| cpi_details.check }

  RENT_CPI_TYPE = [
    [ "12", "12" ],
    [ "24", "24" ]
  ]

  MONTH_NAMES = [
    [:Jan , 1],
    [:Feb , 2],
    [:Mar , 3],
    [:Apr , 4],
    [:May , 5],
    [:Jun , 6],
    [:Jul , 7],
    [:Aug , 8],
    [:Sep , 9],
    [:Oct , 10],
    [:Nov , 11],
    [:Dec , 12]
  ]

  def check
    self.rent.try(:is_cpi_escalation)
  end

  private

  def cpi_all_suites_set
    if self.suite_id.eql?(0)
    self.is_all_suites_selected = 1
    else
      self.is_all_suites_selected = nil
    end
  end

end
