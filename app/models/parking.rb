class Parking < ActiveRecord::Base

  # Associations
  belongs_to :rent
  has_one :note, :as => :note,    :dependent => :destroy

  # Validations
  validates :reserved_number ,                       :numericality => { :greater_than  => 0 , :only_integer => true }, :if => Proc.new { |parking|  parking.reserved_number != nil }
  validates :reserver_amount_per_space_per_month ,   :numericality => { :greater_than  => 0 },                         :if => Proc.new { |parking|  parking.reserver_amount_per_space_per_month != nil }
  validates :reserved_total_amount ,                 :numericality => { :greater_than  => 0 },                         :if => Proc.new { |parking|  parking.reserved_total_amount != nil }
  validates :unreserved_number ,                     :numericality => { :greater_than  => 0 , :only_integer => true }, :if => Proc.new { |parking|  parking.unreserved_number != nil }
  validates :unreserved_amount_per_space_per_month , :numericality => { :greater_than  => 0 },                         :if => Proc.new { |parking|  parking.unreserved_amount_per_space_per_month != nil }
  validates :unreserver_total_amount ,               :numericality => { :greater_than  => 0 },                         :if => Proc.new { |parking|  parking.unreserver_total_amount != nil }
  validates :total_monthly ,                         :numericality => { :greater_than  => 0 },                         :if => Proc.new { |parking|  parking.total_monthly != nil }
  def total_parking_revenue(lease_end_date, lease_start_date, parking_amount_per_month)

    if lease_end_date.present? && lease_start_date.present? && parking_amount_per_month.present?
      lease_end_date = lease_end_date.to_s
      lease_start_date =   lease_start_date.to_s
      escalations_period = RentSchedule.get_rent_schedule_period(lease_start_date, lease_end_date)
    @total_parking_revenue = escalations_period.to_f * parking_amount_per_month.to_f
    end
    @total_parking_revenue
  end
end
