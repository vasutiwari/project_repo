class TenantImprovement < ActiveRecord::Base

  # Associations
  belongs_to :cap_ex
  has_one :note, :as => :note, :dependent => :destroy

  # Callbacks
  after_save :calling_lease_rent_roll_from_delayed_job

  # Validations
  validates :amount_psf ,   :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |tenant_improvement|  tenant_improvement.amount_psf != nil }
  validates :total_amount , :numericality => { :greater_than_or_equal_to => 0 },   :if => Proc.new { |tenant_improvement|  tenant_improvement.total_amount != nil }

  accepts_nested_attributes_for :note
  def self.tenant_improvement_data_push(params,capexid)
    self.create(:name => params[:name],:amount_psf => params[:amt_psf],:total_amount => params[:tot_amt],:work_start_date => params[:work_start_date],:cap_ex_id => capexid) if params[:name].present? || params[:amt_psf].present? || params[:tot_amt].present? || params[:work_start_date].present?
    self.create(:name => params[:name_1],:amount_psf => params[:amt_psf_1],:total_amount => params[:tot_amt_1],:work_start_date => params[:work_start_date_1],:cap_ex_id => capexid) if params[:name_1].present? || params[:amt_psf_1].present? || params[:tot_amt_1].present? || params[:work_start_date_1].present?
    self.create(:name => params[:name_2],:amount_psf => params[:amt_psf_2],:total_amount => params[:tot_amt_2],:work_start_date => params[:work_start_date_2],:cap_ex_id => capexid) if params[:name_2].present? || params[:amt_psf_2].present? || params[:tot_amt_2].present? || params[:work_start_date_2].present?
    self.create(:name => params[:name_3],:amount_psf => params[:amt_psf_3],:total_amount => params[:tot_amt_3],:work_start_date => params[:work_start_date_3],:cap_ex_id => capexid) if params[:name_3].present? || params[:amt_psf_3].present? || params[:tot_amt_3].present? || params[:work_start_date_3].present?
    self.create(:name => params[:name_4],:amount_psf => params[:amt_psf_4],:total_amount => params[:tot_amt_4],:work_start_date => params[:work_start_date_4],:cap_ex_id => capexid) if params[:name_4].present? || params[:amt_psf_4].present? || params[:tot_amt_4].present? || params[:work_start_date_4].present?
  end

  def calling_lease_rent_roll_from_delayed_job
    total_amount_changed =  self.total_amount_changed?
    self.delay.update_lease_rent_roll(total_amount_changed)
  end

  def update_lease_rent_roll(total_amount_changed)
    if self.total_amount.present? && total_amount_changed
      lease = self.try(:cap_ex).try(:lease)
      if lease.try(:is_executed) && lease.try(:commencement) && lease.try(:expiration)
        property_lease_suite = lease.try(:property_lease_suite)
        if property_lease_suite.present? && property_lease_suite.suite_ids?
          number_of_months = RentSchedule.get_rent_schedule_period(lease.try(:commencement), Time.now)
          tis_amount = lease.cap_ex.tenant_improvements.sum(:total_amount) rescue nil
          0.upto(number_of_months) do |month|
            current_year = (lease.try(:commencement) + month.months).year rescue nil
            current_month = (lease.try(:commencement) + month.months).month rescue nil
            property_lease_suite.suite_ids.each do |suite_id|
              if current_year.present? && current_month.present?
                lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,current_month,current_year)
                lease_rent_roll.update_attributes(:tis_amount => tis_amount)  if lease_rent_roll.present?
              end
            end
          end
        end
      end
    end
  end
end