class Option < ActiveRecord::Base
  has_one :note, :as => :note,    :dependent => :destroy
  belongs_to :tenant

  after_save :calling_lease_rent_roll_from_delayed_job
  before_save :restrict_default_value

  accepts_nested_attributes_for :note,:reject_if => :all_blank

  OPTION_TYPE = [

    [ "Renewal", "Renewal" ],
    [ "Contraction", "Contraction" ],
    [ "Termination", "Termination" ],
    [ "Right of First Refusal", "Right of First Refusal" ],
    [ "Expansion", "Expansion" ],
    [ "Right of First Offer", "Right of First Offer" ],
    [ "Exclusive Use", "Exclusive Use" ],
    [ "Assignment, Subletting", "Assignment, Subletting" ],
    [ "Early Possession", "Early Possession" ],
    [ "Right of First Purchase", "Right of First Purchase" ],
    [ "Relocation", "Relocation" ],
    [ "Other", "Other" ]
  ]

  def restrict_default_value
    self.encumbered_floors = nil if self.encumbered_floors.present? && self.encumbered_floors.eql?('enter comma separated.')
    self.encumbered_suites = nil if self.encumbered_suites.present? && self.encumbered_suites.eql?('enter comma separated.')
    self.l_para = nil if self.l_para.present? && self.l_para.eql?('enter comma separated.')
  end

  def self.store_option_items(*args)
    args = args.extract_options!
    self.create(:option_type => args[:option_type],:option_start => args[:option_start],:option_end => args[:option_end],:notice_start => args[:notice_start],:notice_end => args[:notice_end],:encumbered_floors  => args[:encumbered_floors],:encumbered_suites => args[:encumbered_suites],:tenant_id => args[:tenant_id])
  end

  # We Need this code Becuase I have changed the code for lease rent roll
  #  def update_lease_rent_roll
  #    if self.option_type.present? || self.option_start.present? || self.option_end.present?
  #      property_lease_suite = self.tenant.try(:property_lease_suite)
  #      if property_lease_suite.present? && property_lease_suite.suite_ids?
  #        property_lease_suite.suite_ids.each do |suite_id|
  #          lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month(suite_id,Time.now.month)
  #          existing_options = lease_rent_roll.try(:options)
  #          options = []
  #          options <<  self.option_type if self.option_type.present?
  #          options <<  self.option_start if self.option_start.present?
  #          options <<  self.option_end if self.option_end.present?
  #          options =  options.join(",") if options.present?
  #          options = existing_options + options if existing_options.present?
  #          lease_rent_roll.update_attributes(:options => options)  if lease_rent_roll.present?
  #        end
  #      end
  #    end
  #  end

  def calling_lease_rent_roll_from_delayed_job
    option_changes =  self.option_type_changed? ||  self.option_start_changed? ||  self.option_end_changed?
    self.delay.update_lease_rent_roll(option_changes)
  end

  def update_lease_rent_roll(option_changes)
    if option_changes
      property_lease_suite = self.tenant.try(:property_lease_suite)
      if property_lease_suite.present? && property_lease_suite.suite_ids?
        lease = property_lease_suite.lease
        if lease.present? && lease.tenant.present? && lease.try(:is_executed) && lease.try(:commencement)
          number_of_months = RentSchedule.get_rent_schedule_period(lease.try(:commencement), Time.now)
          options = lease.tenant.options
          final_options = Option.merge_options(options)
          0.upto(number_of_months) do |month|
            current_year = (lease.commencement + month.months).year rescue nil
            current_month = (lease.commencement + month.months).month rescue nil
            if current_year.present? && current_month.present?
              property_lease_suite.suite_ids.each do |suite_id|
                lease_rent_roll=LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id, current_month, current_year)
                lease_rent_roll.update_attributes(:options => final_options)  if lease_rent_roll.present?
              end
            end
          end
        end
      end
    end
  end

  def self.merge_options(options=[])
    final_options = []
    option_types = options.map(&:option_type).uniq.join(",")
    option_starts = options.map(&:option_start).uniq.join(",")
    option_ends = options.map(&:option_end).uniq.join(",")
    final_options << option_types if option_types.present?
    final_options << option_starts if option_starts.present?
    final_options << option_ends if option_ends.present?
    final_options = final_options.join(",")
    final_options
  end

end
