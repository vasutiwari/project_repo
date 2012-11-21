class PercentageSalesRent < ActiveRecord::Base

  #Associatons
  belongs_to :rent
  has_one :note, :as => :note,    :dependent => :destroy

  # Callbacks
  before_save :percentage_sales_all_suites_set
  after_save  :calling_lease_rent_roll_from_delayed_job

  # Validations
  validates :sales_rent_percentage ,                :numericality => { :greater_than  => 0 }, :if => Proc.new { |percentage_sales_rent|  percentage_sales_rent.sales_rent_percentage != nil }
  validates :floor_amt ,                            :numericality => { :greater_than  => 0 }, :if => Proc.new { |percentage_sales_rent|  percentage_sales_rent.floor_amt != nil }
  validates :ceiling_amt ,                          :numericality => { :greater_than  => 0 }, :if => Proc.new { |percentage_sales_rent|  percentage_sales_rent.ceiling_amt != nil }
  validates :estimation_for_projection_sales_est ,  :numericality => { :greater_than  => 0 }, :if => Proc.new { |percentage_sales_rent|  percentage_sales_rent.estimation_for_projection_sales_est != nil }
  validates :est_sales_percentage_esc_year ,        :numericality => { :greater_than  => 0 }, :if => Proc.new { |percentage_sales_rent|  percentage_sales_rent.est_sales_percentage_esc_year != nil }

  # Constants
  BILLING_PER = [
    [ "Monthly", "Monthly" ],
    [ "Quarterly", "Quarterly" ],
    [ "Yearly", "Yearly" ]
  ]

  def self.create_sales_rent(*args)
    args = args.extract_options!
    self.create(:floor_amt => args[:floor_amt], :rent_id => args[:rent_id])
  end

  def calling_lease_rent_roll_from_delayed_job
    percentage_sales_rent_changes = self.from_date_changed? || self.to_date_changed? || self.floor_amt_changed? || self.sales_rent_percentage_changed? || self.is_all_suites_selected_changed?
    self.delay.update_lease_rent_roll(percentage_sales_rent_changes)
  end

  def update_lease_rent_roll(percentage_sales_rent_changes)
    if percentage_sales_rent_changes
      lease = self.try(:rent).try(:lease)
      if lease.try(:is_executed) && self.from_date.present? && self.to_date.present?
        percentage_sales_rents_from_date = self.from_date.to_s
        percentage_sales_rents_to_date =   self.to_date.to_s
        if percentage_sales_rents_from_date.present? && percentage_sales_rents_to_date.present?
          @escalations_period = RentSchedule.get_rent_schedule_period(percentage_sales_rents_from_date, percentage_sales_rents_to_date)
        end
        if @escalations_period.present? && @escalations_period != 0
        @est_sales_percentage_esc_year = (self.est_sales_percentage_esc_year.to_i/@escalations_period)*100
        end
        if self.suite_id.present? && self.suite_id!=0
          0.upto(@escalations_period) do |month|
            current_year = (self.from_date + month.months).year rescue nil
            current_month = (self.from_date + month.months).month rescue nil
            if current_year.present? && current_month.present?
              lease_rent_roll= LeaseRentRoll.find_by_suite_id_and_month_and_year(self.suite_id,current_month,current_year)
              lease_rent_roll.update_attributes(:escalations_period => @escalations_period,:escalations_monthly_amount => @est_sales_percentage_esc_year,:per_sales_floor => self.floor_amt ,:per_sales_percentage => self.sales_rent_percentage)  if lease_rent_roll.present?
            end
          end
        elsif self.is_all_suites_selected.present?
          suite_ids = lease.try(:property_lease_suite).try(:suite_ids)
          if suite_ids.present?
            suite_ids.each do |suite_id|
              0.upto(@escalations_period) do |month|
                current_year = (self.from_date + month.months).year rescue nil
                current_month = (self.from_date + month.months).month rescue nil
                if current_year.present? && current_month.present?
                  lease_rent_roll= LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,current_month,current_year)
                  lease_rent_roll.update_attributes(:escalations_period => @escalations_period,:escalations_monthly_amount => @est_sales_percentage_esc_year,:per_sales_floor => self.floor_amt ,:per_sales_percentage => self.sales_rent_percentage)  if lease_rent_roll.present?
                end
              end
            end
          end
        end
      end
    end
  end

  def find_estimation_sales(estimation_for_projection_sales_est,est_sales_percentage_esc_year)
    if estimation_for_projection_sales_est.present? && est_sales_percentage_esc_year.present?
    @estimation_sales = (estimation_for_projection_sales_est*est_sales_percentage_esc_year)/100
    end
    @estimation_sales
  end

  private

  def percentage_sales_all_suites_set
    if self.suite_id.eql?(0)
    self.is_all_suites_selected = 1
    else
      self.is_all_suites_selected = nil
    end
  end

  def self.collection(percentage_sales_rents)
    @final_collection = []
    @final_est_sales = 0
    @final_est_sales_above_floor_amt = 0
    @final_sales_percentage = 0
    @final_sales_rent_rev = 0

    percentage_sales_rents.each_with_index do |psr,i|
      if psr.from_date.present? && psr.to_date.present?
        @escalations_period = RentSchedule.get_rent_schedule_period(psr.from_date, psr.to_date)
        number_of_years = (@escalations_period/12).ceil rescue 0 if @escalations_period.present?

        for year in 1..number_of_years
          if year == 1 && i==0
            collection = {}
            @est_sales =   psr.estimation_for_projection_sales_est.to_f
            @est_sales_above_floor_amt = @est_sales.to_f - psr.floor_amt.to_f
            @sales_percentage = psr.sales_rent_percentage
            @sales_rent_rev =  (@est_sales_above_floor_amt.to_f * @sales_percentage.to_f)/100
            collection[:est_sales] = @est_sales
            collection[:est_sales_above_floor_amt] = @est_sales_above_floor_amt
            collection[:sales_percentage] = @sales_percentage
            collection[:sales_rent_rev] = check_sales_rent_revenue(@sales_rent_rev)
            @final_est_sales = @final_est_sales + @est_sales.to_f
            @final_est_sales_above_floor_amt = @final_est_sales_above_floor_amt  + @est_sales_above_floor_amt.to_f
            @final_sales_percentage = @sales_percentage.to_f
            @final_sales_rent_rev = @final_sales_rent_rev + collection[:sales_rent_rev].to_f
          @final_collection << collection
          else
            collection = {}
            latest_hash = @final_collection.last
            @est_sales = latest_hash[:est_sales]
            @est_sales = (@est_sales.to_f * (1+(psr.est_sales_percentage_esc_year.to_f/100)))
            @est_sales_above_floor_amt = @est_sales.to_f - psr.floor_amt.to_f
            @sales_percentage = psr.sales_rent_percentage
            @sales_rent_rev =  (@est_sales_above_floor_amt.to_f * @sales_percentage.to_f)/100
            collection[:est_sales] = @est_sales
            collection[:est_sales_above_floor_amt] = @est_sales_above_floor_amt
            collection[:sales_percentage] = @sales_percentage
            collection[:sales_rent_rev] = check_sales_rent_revenue(@sales_rent_rev)
            @final_est_sales = @final_est_sales + @est_sales.to_f
            @final_est_sales_above_floor_amt = @final_est_sales_above_floor_amt  + @est_sales_above_floor_amt.to_f
            @final_sales_percentage = @sales_percentage.to_f
            @final_sales_rent_rev = @final_sales_rent_rev + collection[:sales_rent_rev].to_f
          @final_collection << collection
          end
        end
      end
    end
    total_collection = {}
    total_collection[:est_sales] = @final_est_sales
    total_collection[:est_sales_above_floor_amt] = @final_est_sales_above_floor_amt
    total_collection[:sales_percentage] = @final_sales_percentage
    total_collection[:sales_rent_rev] = @final_sales_rent_rev
    [@final_collection, total_collection]
  end

  def self.check_sales_rent_revenue(sales_rent_rev)
    sales_rent_revenue = 0
    if sales_rent_rev < 0
    sales_rent_revenue =  0
    else
    sales_rent_revenue = sales_rent_rev
    end
    sales_rent_revenue
  end

end