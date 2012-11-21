class Tenant < ActiveRecord::Base

  # Associations
  has_one :property_lease_suite
  has_one :comm_property_lease_suite
  has_many :options, :dependent => :destroy
  has_one :info, :dependent => :destroy
  has_one :lease_contact, :as => :contact, :dependent => :destroy
  belongs_to :lease
  has_one  :note, :as => :note,    :dependent => :destroy

  # Callbacks
  after_save :calling_lease_rent_roll_from_delayed_job

  before_save :update_client_id_for_tenant

  # Validations
  #validates :tax_id, :numericality => { :greater_than_or_equal_to  => 0, :only_integer => true }, :if => Proc.new { |tenant|  tenant.tax_id != nil }


  accepts_nested_attributes_for :info,:lease_contact,:reject_if => proc { |attrs| attrs.all? { |k, v| v.blank? } }, :allow_destroy => true
  accepts_nested_attributes_for :note,:reject_if => :all_blank

  accepts_nested_attributes_for :options, :allow_destroy => true

  #~ accepts_nested_attributes_for :options,:reject_if => lambda { |attrs|  attrs['option_start'].eql?('mm/dd/yyyy') && attrs['option_end'].eql?('mm/dd/yyyy') && ( attrs['l_para'].blank? || attrs['l_para'].eql?('enter comma separated.')) && attrs['notice_start'].eql?('mm/dd/yyyy') && attrs['notice_end'].eql?('mm/dd/yyyy') && ( attrs['encumbered_floors'].blank? || attrs['encumbered_floors'].eql?('enter comma separated.')) && ( attrs['encumbered_suites'].blank? || attrs['encumbered_suites'].eql?('enter comma separated.') ) && ( attrs['content'].blank? || attrs['content'].eql?('Edit this text to see the text area expand and contract.') )}, :allow_destroy => true

  def self.store_teant_items(*args)
    args = args.extract_options!
    self.create(:tenant_legal_name => args[:tenant_legal_name], :dba_name => args[:dba_name], :tax_id => args[:tax_id], :naics_code => args[:naics_code])
  end

  # adding current_client_id before saving to db
  def update_client_id_for_tenant
    self.client_id = Client.current_client_id
  end

  def self.procedure_tenant(*args)
    args = args.extract_options!
    ret = ActiveRecord::Base.connection.execute("call TenantCreate(\"#{args[:nameIn]}\")")
    ret = Document.record_to_hash(ret).first
    ActiveRecord::Base.connection.reconnect!;ret
  end

  def calling_lease_rent_roll_from_delayed_job
    tenant_legal_name_changed =  self.tenant_legal_name_changed?
    self.delay.update_lease_rent_roll(tenant_legal_name_changed)
  end


  def update_lease_rent_roll(tenant_legal_name_changed)
    if self.tenant_legal_name.present?  && tenant_legal_name_changed
      property_lease_suite = self.property_lease_suite
      lease = property_lease_suite.try(:lease)
      if lease.try(:commencement)  &&  lease.try(:status)!="Inactive" && lease.try(:is_executed) && property_lease_suite.present? && property_lease_suite.suite_ids? #included is_executed conditions
        number_of_months = RentSchedule.get_rent_schedule_period(lease.try(:commencement), Time.now)
        property_lease_suite.suite_ids.each do |suite_id|
          0.upto(number_of_months) do |month|
            current_year = (lease.try(:commencement) + month.months).year rescue nil
            current_month = (lease.try(:commencement) + month.months).month rescue nil
            if current_year.present? && current_month.present?
              lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,current_month,current_year)
              lease_rent_roll.update_attributes(:tenant => self.tenant_legal_name)  if lease_rent_roll.present?
            end
          end
        end
      end
    end
  end

  # Here I am doing calcuations required to display in income projections
  def self.get_tenant_details(tenant)
    tenant = tenant
    if tenant.present?
      info = tenant.info
      options = tenant.options
      options = options.map(&:option_type).delete_if{|option| option.blank?}  rescue nil
      option_types = options.join(",") rescue nil
    end
    # Here we are doing calcuations to display percentage sales rents
    [tenant, info, options, option_types]
  end

end
