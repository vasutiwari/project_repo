class RentSchedule < ActiveRecord::Base

  attr_accessor :rent_schedule_ids, :rent_schedule_amount_per_sqft
  # Associations
  belongs_to :rent
  has_one :note, :as => :note,    :dependent => :destroy

  # Callbacks
  before_save :rent_sch_all_suites_set#, :automatic_saving_of_dates_in_rent_scheudule_table
  after_save :calling_lease_rent_roll_from_delayed_job

  # Validations
  validates :amount_per_month ,          :numericality => { :greater_than_or_equal_to  => 0 },  :if => Proc.new { |rent_schedule|  rent_schedule.amount_per_month != nil }
  validates :amount_per_month_per_sqft , :numericality => { :greater_than_or_equal_to => 0 },   :if => Proc.new { |rent_schedule|  rent_schedule.amount_per_month_per_sqft != nil }
  validates :no_of_months ,          :numericality => { :greater_than_or_equal_to  => 0 },  :if => Proc.new { |rent_schedule|  rent_schedule.no_of_months != nil }

  # Constants

  RENT_BILLING = [
  [ "Monthly", "Monthly" ],
  [ "Quarterly", "Quarterly" ],
  [ "Yearly", "Yearly" ]
  ]

  RENT_SCH_TYPE = [
  ["",nil],
  [ "Free", "Free" ],
  [ "Base", "Base" ]
  ]

  SUITES_SELECTION = { 'Enter same rent for all suites'=>true, 'Enter different rent for each suite'=>false }

  # Caluculating total rent revenue by adding all rent schedules amount.

  def self.total_rent_revenue(rent_schedules)
    @total_amount = 0
    rent_schedules.each do |rent_schedule|
      if rent_schedule.from_date? && rent_schedule.to_date? && rent_schedule.amount_per_month?
        rent_schedules_from_date = rent_schedule.from_date.to_s
        rent_schedules_to_date =   rent_schedule.to_date.to_s
        escalations_period = RentSchedule.get_rent_schedule_period(rent_schedules_from_date, rent_schedules_to_date)
        amount = escalations_period.to_f * rent_schedule.amount_per_month.to_f
        @total_amount = @total_amount + amount
      end
    end
    @total_amount
  end

  # Caluculating rent reveunue for one rent schedule.
  def self.get_rent_revenue_per_month(from_date=nil,to_date=nil, amount_per_month=nil)
    @amount = 0
    if from_date.present? && to_date.present? && amount_per_month.present?
      rent_schedules_from_date = from_date.to_s
      rent_schedules_to_date =   to_date.to_s
      escalations_period = RentSchedule.get_rent_schedule_period(rent_schedules_from_date, rent_schedules_to_date)
      @amount = escalations_period.to_f * amount_per_month.to_f # Multiplying amount_per_month(from database) with the escalations_period coming from subtracting dates.
    end
    @amount
  end

  # Caluculating leasing commission for displaying in income projection under rent schedule.
  def self.leasing_commission(from_date, to_date, amount_per_month ,lease,leasing_commissions, leasing_commission_start_date)
    # For calculate leasing commissions below fields in if condition are mandatory.
    if from_date.present? && to_date.present? && amount_per_month.present? && lease.try(:expiration).present? && lease.try(:commencement).present? && leasing_commissions.present? && leasing_commission_start_date.present?
      @leasing_commissions_sum = 0
      rent_schedules_from_date = from_date.to_s
      rent_schedules_to_date =   to_date.to_s
      #      lease_end_date = lease.expiration.to_s
      #      lease_start_date =   lease.commencement.to_s
      lease_escalations_period =  RentSchedule.get_rent_schedule_period(leasing_commission_start_date,rent_schedules_from_date)
      lease_escalations_period = (lease_escalations_period/12).floor rescue nil if lease_escalations_period.present?
      escalations_period = RentSchedule.get_rent_schedule_period(rent_schedules_from_date, rent_schedules_to_date)
      @amount = escalations_period * amount_per_month.to_f
      number_of_years =  RentSchedule.find_exact_number_of_years(escalations_period) || 0
      # Summing the leasing commissions percentages basing on ther years.
      for rent_schedule_year in 0..number_of_years
        final_lease_escalations_period = lease_escalations_period + rent_schedule_year
        @leasing_commissions_sum =  @leasing_commissions_sum.to_f + RentSchedule.find_leasing_commission_sum(final_lease_escalations_period, leasing_commissions)
      end
      final_leasing_commission_sum = (@leasing_commissions_sum.to_f * @amount.to_f)/100
    end
    @leasing_commissions_sum = 0
    final_leasing_commission_sum || 0
  end



  # Caluculating exact number of months between from_date and to_date.
  def self.get_rent_schedule_period(from_date, to_date)
    if from_date.present? && to_date.present?
      rent_schedules_from_date = from_date.to_date
      rent_schedules_to_date =   to_date.to_date
      escalations_period = (rent_schedules_to_date.year*12+rent_schedules_to_date.month) - (rent_schedules_from_date.year*12+rent_schedules_from_date.month)
      end_date = from_date.to_date + escalations_period.months
      number_of_days =  rent_schedules_to_date.day-end_date.day
      # If the number of days in month is more than 15 then we will assume it as one month and we add it below.
      escalations_period = escalations_period + 1  if number_of_days >=15
    end
    escalations_period  || 0
  end

  # Caluculation for displaying rent schedule in income projection.
  def self.get_rent_schedules_with_cpi_details(rent_schedules, annual_cpi_estimation=nil, adjustment_frequency=12.0, display_years=1,is_cpi_escalation=false,check_leasing_commissions_first_year_percentages=nil, leasing_commissions=[],lease=nil, lease_rentable_sqft=0, cpi_details=nil, procurement_leasing_commission=nil, listing_leasing_commission=nil)
    total_rent_revenue = 0
    rent_schedules_leasing_commissions_total_amount = 0
    procurement_leasing_commission_total_amount = 0
    listing_leasing_commission_total_amount = 0
    total_rent_schedules = []
    rent_schedules.each do |rent_schedule|
      if rent_schedule.is_all_suites_selected && lease.try(:commencement)
        leasing_commission_start_date = lease.try(:commencement).to_s
      else
        leasing_commission_start_date = rent_schedules.where(:suite_id => rent_schedule.suite_id).where("from_date is not null").map(&:from_date).min rescue nil
      end

      if rent_schedule.rent_schedule_type.eql?("Free") && rent_schedule.try(:no_of_months).present?
        fresh_rent_schedule = {}
        fresh_rent_schedule[:from_date] = rent_schedule.from_date
        fresh_rent_schedule[:to_date] =  rent_schedule.to_date
        fresh_rent_schedule[:no_of_months] =  get_rent_schedule_period(fresh_rent_schedule[:from_date], fresh_rent_schedule[:to_date])
        fresh_rent_schedule[:rent_schedule_type] =  rent_schedule.rent_schedule_type
        fresh_rent_schedule[:suite_id] =  rent_schedule.suite_id
        fresh_rent_schedule[:amount_per_month] =  rent_schedule.amount_per_month
        fresh_rent_schedule[:amount_per_month_per_sqft] =  rent_schedule.amount_per_month_per_sqft
        fresh_rent_schedule[:is_all_suites_selected] =  rent_schedule.is_all_suites_selected
        fresh_rent_schedule[:rent_revenue] =  RentSchedule.get_rent_revenue_per_month(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month])

        if check_leasing_commissions_first_year_percentages
          fresh_rent_schedule[:leasing_commission] =  RentSchedule.leasing_commission(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,leasing_commissions, leasing_commission_start_date)
          rent_schedules_leasing_commissions_total_amount += fresh_rent_schedule[:leasing_commission]
        end
        total_rent_revenue +=  fresh_rent_schedule[:rent_revenue]
        total_rent_schedules << fresh_rent_schedule

      elsif rent_schedule.try(:no_of_months).present?

        previous_rent_schedule = total_rent_schedules.last
        free_months_left = 0

        if previous_rent_schedule.present? && previous_rent_schedule[:rent_schedule_type]=="Free"
          free_period_years = RentSchedule.find_exact_number_of_years(previous_rent_schedule[:no_of_months])
          free_months_left = previous_rent_schedule[:no_of_months].to_i - free_period_years.to_i*12
        end

        escalations_period = self.get_rent_schedule_period(rent_schedule.from_date, rent_schedule.to_date)
        number_of_years =  rent_schedule.get_exact_number_of_years(escalations_period, adjustment_frequency.to_i) || 0

        period = escalations_period/adjustment_frequency rescue nil
        fresh_rent_schedule = {}
        fresh_rent_schedule[:from_date] = rent_schedule.from_date
        fresh_rent_schedule[:to_date] =  check_rent_schedule_date(rent_schedule.from_date,rent_schedule.to_date,period, cpi_details.try(:adjustment_start_month), is_cpi_escalation,free_months_left, rent_schedule.try(:rent))
        fresh_rent_schedule[:no_of_months] =  get_rent_schedule_period(fresh_rent_schedule[:from_date], fresh_rent_schedule[:to_date])
        fresh_rent_schedule[:rent_schedule_type] =  rent_schedule.rent_schedule_type
        fresh_rent_schedule[:suite_id] =  rent_schedule.suite_id
        fresh_rent_schedule[:amount_per_month] =  rent_schedule.amount_per_month
        fresh_rent_schedule[:amount_per_month_per_sqft] =  rent_schedule.amount_per_month_per_sqft
        fresh_rent_schedule[:is_all_suites_selected] =  rent_schedule.is_all_suites_selected
        fresh_rent_schedule[:rent_revenue] =  RentSchedule.get_rent_revenue_per_month(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month])

        if leasing_commissions.present?
          fresh_rent_schedule[:leasing_commission] =  RentSchedule.leasing_commission(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,leasing_commissions, leasing_commission_start_date)
          rent_schedules_leasing_commissions_total_amount += fresh_rent_schedule[:leasing_commission]
        end

        if procurement_leasing_commission.present?
          fresh_rent_schedule[:procurement_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,procurement_leasing_commission, leasing_commission_start_date)
          procurement_leasing_commission_total_amount += fresh_rent_schedule[:procurement_leasing_commission]
        end

        if listing_leasing_commission.present?
          fresh_rent_schedule[:listing_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,listing_leasing_commission, leasing_commission_start_date)
          listing_leasing_commission_total_amount += fresh_rent_schedule[:listing_leasing_commission]
        end

        total_rent_revenue +=  fresh_rent_schedule[:rent_revenue]
        total_rent_schedules << fresh_rent_schedule


        escalations_period = self.get_rent_schedule_period(fresh_rent_schedule[:to_date],rent_schedule.to_date )
        number_of_years =  rent_schedule.get_exact_number_of_years(escalations_period, adjustment_frequency.to_i) || 0
        period = escalations_period/adjustment_frequency rescue nil


        fresh_rent_schedule = {}

        previous_rent_schedule = total_rent_schedules.last

        if period > 1
          fresh_rent_schedule[:rent_schedule_type] =  rent_schedule.rent_schedule_type
          fresh_rent_schedule[:from_date] = previous_rent_schedule[:to_date]
          fresh_rent_schedule[:to_date] =  previous_rent_schedule[:to_date] + display_years.year
          fresh_rent_schedule[:no_of_months] = get_rent_schedule_period(fresh_rent_schedule[:from_date], fresh_rent_schedule[:to_date])
          fresh_rent_schedule[:suite_id] =  rent_schedule.suite_id
          fresh_rent_schedule[:amount_per_month_per_sqft] =  rent_schedule.get_cpi_amount_per_month_per_sqft(is_cpi_escalation, previous_rent_schedule[:amount_per_month_per_sqft], annual_cpi_estimation, adjustment_frequency)
          fresh_rent_schedule[:amount_per_month] =  rent_schedule.get_cpi_amount_per_month(is_cpi_escalation, fresh_rent_schedule[:amount_per_month_per_sqft],  rent_schedule.is_all_suites_selected, rent_schedule.suite_id, lease_rentable_sqft)
          fresh_rent_schedule[:is_all_suites_selected] =  rent_schedule.is_all_suites_selected
          fresh_rent_schedule[:rent_revenue] =  RentSchedule.get_rent_revenue_per_month(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month])

          if leasing_commissions.present?
            fresh_rent_schedule[:leasing_commission] =  RentSchedule.leasing_commission(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,leasing_commissions, leasing_commission_start_date)
            rent_schedules_leasing_commissions_total_amount += fresh_rent_schedule[:leasing_commission]
          end

          if procurement_leasing_commission.present?
            fresh_rent_schedule[:procurement_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,procurement_leasing_commission, leasing_commission_start_date)
            procurement_leasing_commission_total_amount += fresh_rent_schedule[:procurement_leasing_commission]
          end


          if listing_leasing_commission.present?
            fresh_rent_schedule[:listing_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,listing_leasing_commission, leasing_commission_start_date)
            listing_leasing_commission_total_amount += fresh_rent_schedule[:listing_leasing_commission]
          end



          total_rent_revenue +=  fresh_rent_schedule[:rent_revenue]
          total_rent_schedules << fresh_rent_schedule
        elsif period > 0
          fresh_rent_schedule[:rent_schedule_type] =  rent_schedule.rent_schedule_type
          fresh_rent_schedule[:from_date] = previous_rent_schedule[:to_date]
          fresh_rent_schedule[:to_date] =  rent_schedule[:to_date]
          fresh_rent_schedule[:no_of_months] = get_rent_schedule_period(fresh_rent_schedule[:from_date], fresh_rent_schedule[:to_date])
          fresh_rent_schedule[:suite_id] =  rent_schedule.suite_id
          fresh_rent_schedule[:amount_per_month_per_sqft] =  rent_schedule.get_cpi_amount_per_month_per_sqft(is_cpi_escalation, previous_rent_schedule[:amount_per_month_per_sqft], annual_cpi_estimation, adjustment_frequency)
          fresh_rent_schedule[:amount_per_month] =  rent_schedule.get_cpi_amount_per_month(is_cpi_escalation, fresh_rent_schedule[:amount_per_month_per_sqft],  rent_schedule.is_all_suites_selected, rent_schedule.suite_id, lease_rentable_sqft)
          fresh_rent_schedule[:is_all_suites_selected] =  rent_schedule.is_all_suites_selected
          fresh_rent_schedule[:rent_revenue] =  RentSchedule.get_rent_revenue_per_month(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month])

          if leasing_commissions.present?
            fresh_rent_schedule[:leasing_commission] =  RentSchedule.leasing_commission(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,leasing_commissions, leasing_commission_start_date)
            rent_schedules_leasing_commissions_total_amount += fresh_rent_schedule[:leasing_commission]
          end

          if procurement_leasing_commission.present?
            fresh_rent_schedule[:procurement_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,procurement_leasing_commission, leasing_commission_start_date)
            procurement_leasing_commission_total_amount += fresh_rent_schedule[:procurement_leasing_commission]
          end



          if listing_leasing_commission.present?
            fresh_rent_schedule[:listing_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,listing_leasing_commission, leasing_commission_start_date)
            listing_leasing_commission_total_amount += fresh_rent_schedule[:listing_leasing_commission]
          end



          total_rent_revenue +=  fresh_rent_schedule[:rent_revenue]
          total_rent_schedules << fresh_rent_schedule
        end




        for rent_schedule_year in 1..number_of_years
          fresh_rent_schedule = {}
          previous_rent_schedule = total_rent_schedules.last

          if rent_schedule_year==number_of_years
            fresh_rent_schedule[:no_of_months] =  rent_schedule.no_of_months
            fresh_rent_schedule[:rent_schedule_type] =  rent_schedule.rent_schedule_type
            fresh_rent_schedule[:from_date] = previous_rent_schedule[:to_date]
            fresh_rent_schedule[:to_date] =  rent_schedule.to_date
            fresh_rent_schedule[:no_of_months] = get_rent_schedule_period(fresh_rent_schedule[:from_date], fresh_rent_schedule[:to_date])
            fresh_rent_schedule[:suite_id] =  rent_schedule.suite_id
            fresh_rent_schedule[:amount_per_month_per_sqft] =  rent_schedule.get_cpi_amount_per_month_per_sqft(is_cpi_escalation, previous_rent_schedule[:amount_per_month_per_sqft], annual_cpi_estimation, adjustment_frequency)
            fresh_rent_schedule[:amount_per_month] = rent_schedule.get_cpi_amount_per_month(is_cpi_escalation, fresh_rent_schedule[:amount_per_month_per_sqft],  rent_schedule.is_all_suites_selected, rent_schedule.suite_id, lease_rentable_sqft)
            fresh_rent_schedule[:is_all_suites_selected] =  rent_schedule.is_all_suites_selected
            fresh_rent_schedule[:rent_revenue] =  RentSchedule.get_rent_revenue_per_month(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month])


            if leasing_commissions.present?
              fresh_rent_schedule[:leasing_commission] =  RentSchedule.leasing_commission(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month], lease,leasing_commissions, leasing_commission_start_date)
              rent_schedules_leasing_commissions_total_amount += fresh_rent_schedule[:leasing_commission]
            end

            if procurement_leasing_commission.present?
              fresh_rent_schedule[:procurement_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,procurement_leasing_commission, leasing_commission_start_date)
              procurement_leasing_commission_total_amount += fresh_rent_schedule[:procurement_leasing_commission]
            end

            if listing_leasing_commission.present?
              fresh_rent_schedule[:listing_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,listing_leasing_commission, leasing_commission_start_date)
              listing_leasing_commission_total_amount += fresh_rent_schedule[:listing_leasing_commission]
            end

            total_rent_revenue +=  fresh_rent_schedule[:rent_revenue]
            total_rent_schedules << fresh_rent_schedule
          else
            fresh_rent_schedule[:rent_schedule_type] =  rent_schedule.rent_schedule_type
            fresh_rent_schedule[:from_date]  = previous_rent_schedule[:to_date]
            fresh_rent_schedule[:to_date] =  previous_rent_schedule[:to_date] +  display_years.year
            fresh_rent_schedule[:no_of_months] = get_rent_schedule_period(fresh_rent_schedule[:from_date], fresh_rent_schedule[:to_date])
            fresh_rent_schedule[:suite_id] =  rent_schedule.suite_id
            fresh_rent_schedule[:amount_per_month_per_sqft] =  rent_schedule.get_cpi_amount_per_month_per_sqft(is_cpi_escalation, previous_rent_schedule[:amount_per_month_per_sqft], annual_cpi_estimation, adjustment_frequency)
            fresh_rent_schedule[:amount_per_month] =  rent_schedule.get_cpi_amount_per_month(is_cpi_escalation, fresh_rent_schedule[:amount_per_month_per_sqft],rent_schedule.is_all_suites_selected, rent_schedule.suite_id, lease_rentable_sqft)
            fresh_rent_schedule[:is_all_suites_selected] =  rent_schedule.is_all_suites_selected
            fresh_rent_schedule[:rent_revenue] =  RentSchedule.get_rent_revenue_per_month(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month])


            if leasing_commissions.present?
              fresh_rent_schedule[:leasing_commission] =  RentSchedule.leasing_commission(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,leasing_commissions, leasing_commission_start_date)
              rent_schedules_leasing_commissions_total_amount += fresh_rent_schedule[:leasing_commission]
            end


            if procurement_leasing_commission.present?
              fresh_rent_schedule[:procurement_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,procurement_leasing_commission, leasing_commission_start_date)
              procurement_leasing_commission_total_amount += fresh_rent_schedule[:procurement_leasing_commission]
            end



            if listing_leasing_commission.present?
              fresh_rent_schedule[:listing_leasing_commission] =  RentSchedule.find_single_leasing_commission_percentages_sum(fresh_rent_schedule[:from_date],fresh_rent_schedule[:to_date], fresh_rent_schedule[:amount_per_month],lease,listing_leasing_commission, leasing_commission_start_date)
              listing_leasing_commission_total_amount += fresh_rent_schedule[:listing_leasing_commission]
            end



            total_rent_revenue +=  fresh_rent_schedule[:rent_revenue]
            total_rent_schedules << fresh_rent_schedule
          end
        end
      end

    end

    [total_rent_schedules, total_rent_revenue, procurement_leasing_commission_total_amount || 0, listing_leasing_commission_total_amount || 0, rent_schedules_leasing_commissions_total_amount]
  end



  def self.check_rent_schedule_date(from_date, to_date, period, adjustment_start_month, is_cpi_escalation,free_months_left=0, rent=nil)
    if is_cpi_escalation.present?

      if adjustment_start_month.present? && adjustment_start_month.to_i <= 12 && adjustment_start_month.to_i > 0
        adjustment_start_month = adjustment_start_month.to_i
      elsif rent.present?
        cpi_detail = rent.cpi_details.first
        if cpi_detail.present?
          cpi_detail.adjustment_start_month = "1"
          cpi_detail.save
        end
        adjustment_start_month = 1
      else
        adjustment_start_month = 1
      end


      if from_date.present?
        from_date = from_date.to_date
        to_date = to_date.to_date rescue nil
        month = adjustment_start_month
        if month.to_i <= from_date.month && period >= 1
          day = from_date.day
          year = from_date.year+1
          date = "#{day}-#{month}-#{year}".to_date rescue nil
        elsif  month.to_i >= from_date.month  && period >= 1
          day = from_date.day
          year = from_date.year
          date = "#{day}-#{month}-#{year}".to_date rescue nil
        elsif month.to_i >= from_date.month && period < 1
          day = from_date.day
          year = from_date.year
          date = "#{day}-#{month}-#{year}".to_date  rescue nil
          if to_date.present? && date > to_date
            date = to_date
          elsif to_date.present? && date < to_date
            date = date
          else
            date = date
          end
        elsif month.to_i <= from_date.month && period < 1
          day = from_date.day
          year = from_date.year
          date = "#{day}-#{month}-#{year}".to_date rescue nil
          if to_date.present? && date > to_date
            date = to_date
          elsif to_date.present? && date < to_date && date > from_date
            date = date
          elsif date < from_date && to_date.present?
            day = from_date.day
            year = to_date.year
            date = "#{day}-#{month}-#{year}".to_date rescue nil
            if date < to_date && date > from_date
              date = date
            elsif to_date.present? && date > to_date
              date = to_date
            elsif date < from_date && period < 1
              date = to_date
            end
          end
        end
        date
      end
    elsif from_date.present? && to_date.present?
      date = from_date + 1.year-free_months_left.months
      to_date = to_date.to_date rescue nil
      if date < to_date
        date=date
      else
        date = to_date
      end
    end
    date
  end

  def get_exact_number_of_years(period, months=12)
    if period.present?
      number_of_years = period/months rescue 0
      number_of_years = number_of_years - 1 if number_of_years*months==period rescue 0
    end
    number_of_years if number_of_years.present? && number_of_years >= 0
  end

  def get_cpi_amount_per_month_per_sqft(is_cpi_escalation,previous_rent_psf, annual_cpi_estimation, adjustment_frequency=12.0)
    if is_cpi_escalation && adjustment_frequency.to_i.eql?(12)
      amount_per_month_per_sqft =  (previous_rent_psf.to_f)* (1+ annual_cpi_estimation.to_f/100)
    elsif  is_cpi_escalation && adjustment_frequency.to_i.eql?(24)
      amount_per_month_per_sqft =  (previous_rent_psf.to_f)* (1+ annual_cpi_estimation.to_f/100)*(1+ annual_cpi_estimation.to_f/100)
    else
      amount_per_month_per_sqft =  previous_rent_psf.to_f
    end
    amount_per_month_per_sqft
  end


  def get_cpi_amount_per_month(is_cpi_escalation, previous_rent_psf, is_all_suites_selected, suite_id, lease_rentable_sqft)
    if is_all_suites_selected
      rentable_sqft = lease_rentable_sqft.to_f
    else
      rentable_sqft = Suite.find_by_id(suite_id).try(:rentable_sqft).to_f
    end
    cpi_amount_per_month =  (previous_rent_psf.to_f)*rentable_sqft
    cpi_amount_per_month
  end



  # Caluculating leasing commission for displaying in income projection under rent schedule.
  def self.find_single_leasing_commission_percentages_sum(from_date, to_date, amount_per_month ,lease,leasing_commission, leasing_commission_start_date)
    # For calculate leasing commissions below fields in if condition are mandatory.
    if from_date.present? && to_date.present? && amount_per_month.present? && lease.try(:expiration).present? && lease.try(:commencement).present? && leasing_commission.present? && leasing_commission_start_date.present?
      @leasing_commissions_sum = 0
      rent_schedules_from_date = from_date.to_s
      rent_schedules_to_date =   to_date.to_s
      #      lease_end_date = lease.expiration.to_s
      #      lease_start_date =   lease.commencement.to_s
      lease_escalations_period =  RentSchedule.get_rent_schedule_period(leasing_commission_start_date,rent_schedules_from_date)
      lease_escalations_period = (lease_escalations_period/12).floor rescue nil if lease_escalations_period.present?
      escalations_period = RentSchedule.get_rent_schedule_period(rent_schedules_from_date, rent_schedules_to_date)
      @amount = escalations_period * amount_per_month.to_f
      number_of_years =  RentSchedule.find_exact_number_of_years(escalations_period) || 0
      # Summing the leasing commissions percentages basing on ther years.
      for rent_schedule_year in 0..number_of_years
        final_lease_escalations_period = lease_escalations_period + rent_schedule_year
        @leasing_commissions_sum =  @leasing_commissions_sum.to_f + RentSchedule.find_single_leasing_commission(final_lease_escalations_period, leasing_commission)
      end
      final_leasing_commission_sum = (@leasing_commissions_sum.to_f * @amount.to_f)/100
    end
    final_leasing_commission_sum || 0
  end

  def self.get_total_amount_per_month_basing_on_individual_suites(rent_schedules=[])
    rent_schedules_total_amount_per_month_basing_on_suites = []
    if rent_schedules.present?
      rent_schedules_total_amount_per_month = 0
      rent_schedules_total_amount_per_month_basing_on_suites = rent_schedules.group_by {|row|  row[:suite_id] }.map do |id, group|
        total_rent_revenue_for_suite = 0
        total_no_of_months_for_suite = 0
        total_rent_revenue_for_suite = group.map { |h| h[:rent_revenue] }.inject(:+)
        total_no_of_months_for_suite = group.map { |h| h[:no_of_months] }.inject(:+)
        total_amount_per_month_for_suite = total_rent_revenue_for_suite.to_f/total_no_of_months_for_suite.to_f rescue 0
        rent_schedules_total_amount_per_month = rent_schedules_total_amount_per_month + total_amount_per_month_for_suite
        rent_schedules_total_amount_per_month
      end
    end
    rent_schedules_total_amount_per_month_basing_on_suites.last
  end

  def update_lease_rent_roll(rent_schedule_changes)
    if rent_schedule_changes
      lease = self.try(:rent).try(:lease)
      rent = self.try(:rent)
      if lease.try(:is_executed) && rent.present? && (lease.try(:commencement) || lease.try(:expiration)) && self.from_date.present? && self.to_date.present?
        number_of_months = RentSchedule.get_rent_schedule_period(self.from_date, self.to_date)
        if self.suite_id.present?  && !self.suite_id.eql?(0)
          rent_schedules = rent.rent_schedules.where(:suite_id => self.suite_id).where("from_date<=? and to_date >=?",Time.now,Time.now)
          base_rent_monthly_amount,base_rent_annual_psf = find_base_rent_monthly_amount_and_base_rent_annual_psf(rent_schedules)
          0.upto(number_of_months) do |month|
            current_year = (self.from_date + month.months).year rescue nil
            current_month = (self.from_date + month.months).month rescue nil
            if current_year.present? && current_month.present?
              lease_rent_roll= LeaseRentRoll.find_by_suite_id_and_month_and_year(self.suite_id,current_month,current_year)
              lease_rent_roll.update_attributes(:base_rent_monthly_amount => base_rent_monthly_amount, :base_rent_annual_psf => base_rent_annual_psf)   if lease_rent_roll.present?
            end
          end
        elsif self.is_all_suites_selected.present?
          suite_ids = lease.try(:property_lease_suite).try(:suite_ids) || []
          rent_schedules = rent.rent_schedules.where("from_date<=? and to_date >=?",Time.now,Time.now) || []
          base_rent_monthly_amount,base_rent_annual_psf = find_base_rent_monthly_amount_and_base_rent_annual_psf(rent_schedules)
          suite_ids.each do |suite_id|
            0.upto(number_of_months) do |month|
              current_year = (self.from_date + month.months).year rescue nil
              current_month = (self.from_date + month.months).month rescue nil
              if current_year.present? && current_month.present?
                lease_rent_roll= LeaseRentRoll.find_by_suite_id_and_month_and_year(suite_id,current_month,current_year)
                lease_rent_roll.update_attributes(:base_rent_monthly_amount => base_rent_monthly_amount, :base_rent_annual_psf => base_rent_annual_psf)   if lease_rent_roll.present?
              end
            end
          end
        end
      end
    end
  end


  private
  def rent_sch_all_suites_set
    if (self.suite_id.eql?(0) || self.suite_id.nil?)
      self.is_all_suites_selected = 1
    else
      self.is_all_suites_selected = 0
    end
  end


  def self.find_leasing_commission_sum(final_lease_escalations_period, leasing_commissions)
    final_lease_escalations_period = 9  if final_lease_escalations_period.present? && final_lease_escalations_period > 9
    @result = case final_lease_escalations_period
      when 0
      leasing_commissions.sum(:percentage_for_first_year)
      when 1
      leasing_commissions.sum(:percentage_for_second_year)
      when 2
      leasing_commissions.sum(:percentage_for_third_year)
      when 3
      leasing_commissions.sum(:percentage_for_fourth_year)
      when 4
      leasing_commissions.sum(:percentage_for_fifth_year)
      when 5
      leasing_commissions.sum(:percentage_for_sixth_year)
      when 6
      leasing_commissions.sum(:percentage_for_seventh_year)
      when 7
      leasing_commissions.sum(:percentage_for_eighth_year)
      when 8
      leasing_commissions.sum(:percentage_for_ninth_year)
      when 9
      leasing_commissions.sum(:percentage_for_tenth_year)
    end
    @result.to_f
  end

  def self.find_single_leasing_commission(final_lease_escalations_period, leasing_commission)
    final_lease_escalations_period = 9  if final_lease_escalations_period.present? && final_lease_escalations_period > 9
    @result = case final_lease_escalations_period
      when 0
      leasing_commission.try(:percentage_for_first_year)
      when 1
      leasing_commission.try(:percentage_for_second_year)
      when 2
      leasing_commission.try(:percentage_for_third_year)
      when 3
      leasing_commission.try(:percentage_for_fourth_year)
      when 4
      leasing_commission.try(:percentage_for_fifth_year)
      when 5
      leasing_commission.try(:percentage_for_sixth_year)
      when 6
      leasing_commission.try(:percentage_for_seventh_year)
      when 7
      leasing_commission.try(:percentage_for_eighth_year)
      when 8
      leasing_commission.try(:percentage_for_ninth_year)
      when 9
      leasing_commission.try(:percentage_for_tenth_year)
    end
    @result.to_f
  end



  def self.find_exact_number_of_years(period, months=12)
    if period.present?
      number_of_years = period/months rescue 0
      number_of_years = number_of_years - 1 if number_of_years*months==period rescue 0
    end
    number_of_years if number_of_years.present? && number_of_years >= 0
  end

  def self.find_total_number_of_months(rent_schedules)
    number_of_months = 0
    rent_schedules.each do |rent_schedule|
      period = RentSchedule.get_rent_schedule_period(rent_schedule.from_date,rent_schedule.to_date)
      number_of_months +=  period || 0
    end
    number_of_months
  end

  def self.find_base_rent_revenue(rent_schedules)
    number_of_months = 0
    i = 0
    rent_schedules.each do |rent_schedule|
      unless rent_schedule.rent_schedule_type.eql?("Free")
        period = RentSchedule.get_rent_schedule_period(rent_schedule.from_date,rent_schedule.to_date)
        @base_amount = rent_schedule.amount_per_month if i==0
        number_of_months +=  period||0
        i+=1
      end
    end
    number_of_months * @base_amount.to_f
  end

  #Storing  from_date and to_dates in rent schedule table basing on number of months.
  def automatic_saving_of_dates_in_rent_scheudule_table
    no_of_months = self.no_of_months
    lease_start_date = self.rent.lease.commencement
    lease_end_date = self.rent.lease.expiration
    if lease_start_date.present? && lease_end_date.present? && no_of_months.present?
      total_number_of_months_for_rent_schedules = self.rent.rent_schedules.sum(:no_of_months) || 0
      start_date = lease_start_date + total_number_of_months_for_rent_schedules.months
      self.from_date = start_date
      self.to_date = start_date + (no_of_months.to_i).months - 1.day rescue nil
    end
  end

  def calling_lease_rent_roll_from_delayed_job
    rent_schedule_changes =   self.from_date_changed? ||  self.to_date_changed? || self.amount_per_month_changed? || self.amount_per_month_per_sqft_changed?
    self.delay.update_lease_rent_roll(rent_schedule_changes)
  end

  def find_base_rent_monthly_amount_and_base_rent_annual_psf(rent_schedules=[])
    base_rent_monthly_amount = nil
    base_rent_annual_psf = nil
    base_rent_monthly_amount = self.amount_per_month
    base_rent_annual_psf = self.amount_per_month_per_sqft.to_f*12
    if base_rent_monthly_amount.blank?
      rent_schedule = rent_schedules.last
      if rent_schedule.present?
        base_rent_monthly_amount = rent_schedule.amount_per_month
        base_rent_annual_psf = rent_schedule.amount_per_month_per_sqft.to_f*12
      end
    end
    [base_rent_monthly_amount,base_rent_annual_psf]
  end

end
