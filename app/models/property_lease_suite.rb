class PropertyLeaseSuite < ActiveRecord::Base

  serialize :suite_ids

  # Associations
  belongs_to :lease

  belongs_to :tenant

  # Callbacks
  after_save :calling_lease_rent_roll_from_delayed_job

  before_destroy :destroy_tenant

  scope :port_property_leases , lambda { |args| {:conditions=>["lease_id IN (#{args.join(',')})"]}}

  accepts_nested_attributes_for :tenant
  def calling_lease_rent_roll_from_delayed_job
    self.delay.update_lease_rent_roll
  end

  def update_lease_rent_roll
    if self.suite_ids.present? && self.lease_id.present?
      lease = Lease.find_by_id(self.lease_id)
      if lease.present? && (lease.commencement? || lease.expiration?) && lease.is_executed
        tenant = Tenant.find_by_id(self.tenant_id)
        options = tenant.try(:options)
        final_options = Option.merge_options(options)
        number_of_months = RentSchedule.get_rent_schedule_period(lease.try(:commencement), Time.now)
        0.upto(number_of_months) do |month|
          current_year = (lease.commencement + month.months).year rescue nil
          current_month = (lease.commencement + month.months).month rescue nil
          if current_year.present? && current_month.present?
            self.suite_ids.each do |suite_id|
              lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id, current_month, current_year)
              if lease_rent_roll.present?
                lease_rent_roll.update_attributes(:lease_start_date => lease.try(:commencement), :lease_end_date =>lease.try(:expiration), :tenant => tenant.try(:tenant_legal_name), :options => final_options,:occupancy_type=>lease.try(:occupancy_type),:effective_rate=>lease.try(:effective_rate), :lease_id => lease.try(:id))
              else
                suite = Suite.find_by_id(suite_id)
                LeaseRentRoll.create(:suite_id => suite.id, :real_estate_property_id => suite.real_estate_property_id, :sqft => suite.rentable_sqft, :month => current_month, :year => current_year,:lease_start_date => lease.try(:commencement), :lease_end_date =>lease.try(:expiration), :tenant => tenant.try(:tenant_legal_name), :options => final_options,:occupancy_type=>lease.try(:occupancy_type),:effective_rate=>lease.try(:effective_rate), :lease_id => lease.try(:id))  if suite.present?
              end
            end
          end
        end
      end
    end
  end

  def destroy_tenant
    tenant = self.tenant
    tenant.destroy if tenant.present?
  end

end