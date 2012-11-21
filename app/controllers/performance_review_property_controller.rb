class PerformanceReviewPropertyController < ApplicationController

  before_filter :login_required
  before_filter :property_id,:except=>['rent_roll']
  before_filter :find_real_estate_note,:only=>['change_date','leases_and_occupancy','sort_lease_sub_details','wres_lease','wres_cash_n_receivables_sub_view','financial']
  before_filter :portfolio_assign,:only=>['change_date','leases_and_occupancy']
  before_filter :common_financial_method,:only=>['financial_subpage','wres_financial_subpage']
  before_filter :common_for_cash_and_recv,:only=>['cash_n_receivables','cash_n_receivables_for_receivables','pdf']
  before_filter :find_rep_for_gross_units,:only=>['gross_rental_area_popup','no_of_units_popup']
  before_filter :change_session_value, :only=>[:capital_expenditure,:financial, :cash_n_receivables,:cash_n_receivables_for_receivables,:variances,:variances_display_for_remote_prop,:rent_roll,:select_time_period,:change_date]
  before_filter :check_property_access, :only=> [:rent_roll]
  before_filter :find_prop_id, :only => ['exp_comment_display','notification_to_prop_users']
  layout 'user',:only=>['lease','rent_roll']

  @@time = Time.now
  # It is used to display the  performance review for the current note.
  def for_notes
    tl_month,tl_year =  load_instance_var_note
    common_for_wres_swig(tl_month,tl_year,"for_notes")
  end

  # Listing details in cash & receivable performance review page.
  def cash_n_receivables
    cash_and_receivables
  end

  def cash_n_receivables_for_receivables
    cash_and_receivables_for_receivables
  end

  def common_for_cash_and_recv
    return true if params[:action] == 'pdf' and params[:partial_page] != 'cash_and_receivables' and params[:partial_page] != 'cash_and_receivables_for_receivables'
    @show_variance_thresholds = false
    @portfolio,@note,@notes,@prop = set_object_value(params[:portfolio_id],params[:id],{:prop_folder => false})
      if session[:property__id].present? && session[:portfolio__id].blank?
      @resource = "'RealEstateProperty'"
     elsif session[:portfolio__id].present? && session[:property__id].blank?
      @resource = "'Portfolio'"
    end
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, 'RealEstateProperty'])
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    @actual = @time_line_actual
    @operating_statement={}
    @cash_flow_statement={}
    if params[:tl_period] == "7" || params[:period] == "7"
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
  end


  # Listing details for wres Rent Roll performance review page.
  def wres_rent_roll
    rent_roll
  end

  # Listing details in Rent Roll performance review page.
  def rent_roll
    month = params[:tl_month]
    year = params[:tl_year]
    if params[:cur_month] && (params[:tl_period] == "7" || params[:period] == "7")
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    #~ time_line_display = @balance_sheet ? "jQuery('#time_line_selector').hide()" : "jQuery('#time_line_selector').show()"
    @show_variance_thresholds = false
    @portfolio = Portfolio.find(params[:portfolio_id])
    @note =  RealEstateProperty.find_real_estate_property(params[:id])
    @notes = RealEstateProperty.find(:all, :conditions =>["portfolios.id = ?",@portfolio.id],:joins=>:portfolios)
    @prop = RealEstatePropertyStateLog.find_by_state_id_and_real_estate_property_id(5,@note.id) if @note.nil?
    @rent_roll_highlight = true
    if !(!params[:tl_month].nil? && !params[:tl_month].blank?)  and (!params[:tl_period].nil?  and params[:tl_period] =="5")
      month= Date.today.prev_month.month
      year = Date.today.prev_month.year
      params[:tl_month] = month
    end
    if (!params[:tl_month].nil? && !params[:tl_month].blank?) && (params[:period] != "2" && params[:tl_period] != "2") && (params[:period] != "3" && params[:tl_period] != "3")
      swig_rent_roll_details(month, year)
    else
      if (!params[:tl_period].nil?  and params[:tl_period] =="4")
        year_value = Date.today.year
      elsif (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
        year_value = find_selected_year(Date.today.year)
      elsif (!params[:tl_period].nil?  and params[:tl_period] =="7") && ((params[:start_date].nil? || params[:start_date].blank?) && ( params[:tl_month].nil? ||  params[:tl_month].blank?))
        year_value = @start_date.to_date.year
        month_for_year = @end_date.to_date.month
      elsif(!params[:tl_period].nil?  and params[:tl_period] =="6") || (params[:period] =="3" || params[:tl_period] =="3")
        year_value = find_selected_year(Date.today.prev_year.year)
        month_for_year = Date.today.end_of_year.month
      elsif(!params[:tl_period].nil?  and params[:tl_period] =="8")
        year_value = find_selected_year(Date.today.year)
      else
      end
      if is_commercial(@note)
        @suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
      elsif is_multifamily(@note)
        @suites = PropertySuite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
      end
      swig_rent_roll_details(month_for_year,year_value)
    end
    find_redmonth_start_for_rent_roll(find_selected_year(Date.today.year))
    timeline_msg = find_timeline_message
    @timeline_rent = timeline_msg
    unless @pdf
    if !params[:from_lease].present? || params[:per_page].present?
      render :update do |page|
        if @note && @note.property_name.present?
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Rent Roll #{timeline_msg}: </div>');"
        else
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Rent Roll #{timeline_msg}</div>');"
        end
        page <<   "jQuery('#set_quarter_msg').html('');" if params[:period] == '2' || params[:tl_period] == '2'
        if @note.leasing_type == 'Commercial'
          page << "jQuery('#id_for_variance_threshold').html('<ul class=inputcoll2 id=cssdropdown></ul>');"
          #~ page.replace_html "portfolio_overview_property_graph" , :partial => "/properties/rent_roll"
          page << "jQuery('#per_tot_rent_roll option[value=#{params[:rent_roll_filter]}]').attr('selected', 'selected');"
        else
          page.replace_html "portfolio_overview_property_graph", :partial => "/properties/wres/rent_roll",:locals=>{:rent_roll_wres => @rent_roll_wres,:portfolio_collection => @portfolio,:note_collection => @note,:navigation_start_position => @navigation_start_position,:start_date => @start_date}
        end
      end

    end

    end
  end



  # Finanical data variance & Hash formation , when click on the different month
  def change_date
    @portfolio,@note,@notes,@prop = set_object_value(nil,params[:id])
    @notes = RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id)
    id = params[:note_id] ? params[:note_id] : params[:id]
    @note = RealEstateProperty.find_real_estate_property(id)
    find_financial_sub_id if  params[:partial_page] =="financial_subpage" || params[:partial_page] == "balance_sheet_sub_page"
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, 'RealEstateProperty'])
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    @partial_file = "/properties/sample_pie"
    @swf_file = "Pie2D.swf"
    @xml_partial_file = "/properties/sample_pie"
    @balance_sheet = true     if params[:partial_page] == "balance_sheet" || params[:partial_page] == "balance_sheet_sub_page"
    if params[:start_date]
      @dates= params[:start_date].split("-")
      params[:tl_month] = @dates[1]
      params[:tl_year] =@dates[0]
    else
      @dates = []
      @dates[1] = params[:tl_month]
      @dates[0] = params[:tl_year]
    end
    @start_date = params[:start_date]
    @actual = @time_line_actual
    @operating_statement={}
    @cash_flow_statement={}
    @financial = true if params[:partial_page] == "financial"
    if !params[:tl_month].nil? and !params[:tl_month].blank?
      @current_time_period=Date.new(params[:tl_year].to_i,params[:tl_month].to_i,1)
    end
    if params[:cur_month] && (params[:tl_period] == "7" || params[:period] == "7")
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    elsif !params[:cur_month] && (params[:tl_period] == "7" || params[:period] == "7") && params[:start_date]
      mon = params[:start_date].to_date.month
      yr = params[:start_date].to_date.year
      @start_date = Time.local("#{yr}","#{mon}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{yr}","#{mon}").strftime("%Y-%m-%d")
    end
    if params[:partial_page] == 'portfolio_partial'
      if (@dates[0].to_i  >= Date.today.year.to_i) && (params[:period] == "3" || params[:tl_period] == "3")
        executive_overview_details_for_year_forecast
      else
       (params[:period] == "2" || params[:tl_period] == "2")  ? executive_overview_details_for_year :  (params[:period] == "3" || params[:tl_period] == "3") ? executive_overview_details_for_prev_year : executive_overview_details(@dates[1].to_i,@dates[0].to_i)
      end
    end
    financial_month(@dates[1].to_i,@dates[0].to_i)  if params[:partial_page] == "financial" || params[:partial_page] == "balance_sheet"
    if params[:partial_page] == "capital_expenditure"
      if (@dates[0].to_i  >= Date.today.year.to_i) && (params[:period] == "3" || params[:tl_period] == "3")
        capital_expenditure_for_year_forecast
      elsif params[:partial_page] == "capital_expenditure"
       (params[:tl_period]=="3" || params[:period]=="3") && @dates[0].to_i < Date.today.year ? capital_expenditure_prev_year :  ((params[:period] == "2" || params[:tl_period] == "2") ?  capital_expenditure_month_year :  capital_expenditure_month(@dates[1].to_i,@dates[0].to_i))
      end
    end
    if params[:partial_page] == "variances"
      variances
    else
      render :action => 'change_date_without_wres.rjs'
    end
  end


  def wres_change_date
    change_date
  end

  def leases_and_occupancy
    @notes = RealEstateProperty.find_properties_by_portfolio_id(@note.portfolio_id)
    if !params[:buyer_id].nil?
      @user_id_graph = @prop.action_done_by
    else
      @user_id_graph = current_user.id
    end
    @rent_roll = RentRoll.find(:all,:conditions=>["user_id = ? and resource_id =? and resource_type = ? and start_date <= ? and end_date >= ?",@user_id_graph,@note.id, 'RealEstateProperty',@@time.beginning_of_month.strftime("%Y-%m-%d"),@@time.end_of_month.strftime("%Y-%m-%d")])
    @start_date = @@time.beginning_of_month.strftime("%Y-%m-%d")
    @end_date = @@time.end_of_month.strftime("%Y-%m-%d")
    now = Time.now.strftime('%Y%m%d')
    if !@rent_roll.nil?
      @rent_sum = 0
      @rent_area = 0
      @aged_recievables = 0
      @rent_details_count = 0
      @rent_roll.each do |i|
        @rent_details  = i.rent_details
        @rent_details_count = @rent_details.count + @rent_details_count
        @rent_details.each do |j|
          @rent_sum = j.monthly_rent + @rent_sum
          @rent_area = j.rented_area + @rent_area
          @aged_recievables = j.aged_receivables + @aged_recievables
        end
      end
      @rent_area = @rent_area/@rent_roll.count rescue ZeroDivisionError
      @rent_sum = @rent_sum/@rent_roll.count rescue ZeroDivisionError
      @aged_recievables = @aged_recievables/@rent_roll.count rescue ZeroDivisionError
    end
    @time_line_actual = Actual.find(:all,:conditions=>["resource_id =? and resource_type=?",@note.id, 'RealEstateProperty'], :order => "month_and_year")
    @time_line_rent_roll = RentRoll.find(:all,:conditions=>["resource_id =? and resource_type=?",@note, 'RealEstateProperty'], :order => "start_date")
    if !(@time_line_actual.nil? || @time_line_actual.blank?)
      @time_line_start_date = @time_line_actual.first.month_and_year
      @time_line_end_date = @time_line_actual.last.month_and_year
    elsif !(@time_line_rent_roll.nil? || @time_line_rent_roll.blank?)
      @time_line_start_date = @time_line_rent_roll.first.start_date
      @time_line_end_date = @time_line_rent_roll.last.end_date
    end
  end

  def change_chart_leases
    if params[:end_date].nil?
      params[:end_date] = (params[:start_date].to_date.end_of_month).strftime("%Y-%m-%d")
    end
    month_diff = ActiveRecord::Base.connection.select_one("SELECT TIMESTAMPDIFF(MONTH,'#{params[:start_date].to_date}','#{params[:end_date].to_date}')  as no_of_months")
    days_diff = []
    @note = RealEstateProperty.find_real_estate_property(params[:id])
    @portfolio = @note.portfolio
    @period = params[:period]
    @notes = RealEstateProperty.find(:all, :conditions =>["portfolios.id = ?",@note.portfolio_id],:joins=>:portfolios)
    @time_line_actual = Actual.find(:all,:conditions=>["resource_id =? and resource_type=?",@note.id, 'RealEstateProperty'], :order => "month_and_year")
    @time_line_rent_roll = RentRoll.find(:all,:conditions=>["resource_id =? and resource_type=?",@note, 'RealEstateProperty'], :order => "start_date")
    if !(@time_line_actual.nil? || @time_line_actual.blank?)
      @time_line_start_date = @time_line_actual.first.month_and_year
      @time_line_end_date = @time_line_actual.last.month_and_year
    elsif !(@time_line_rent_roll.nil? || @time_line_rent_roll.blank?)
      @time_line_start_date = @time_line_rent_roll.first.start_date
      @time_line_end_date = @time_line_rent_roll.last.end_date
    end
    @start_date = params[:start_date]
    if request.env['HTTP_REFERER'] &&  request.env['HTTP_REFERER'].include?('property_acquisitions')
      @user_id_graph = @prop.action_done_by
    else
      @user_id_graph = current_user.id
    end
    if month_diff["no_of_months"].to_i == 0
      params[:end_date] = (params[:start_date].to_date.end_of_month).strftime("%Y-%m-%d")
      @rent_roll = RentRoll.find(:all,:conditions=>["user_id = ? and resource_id =? and resource_type = ? and start_date <= ? and end_date >= ? ",@user_id_graph,@note.id, 'RealEstateProperty',params[:start_date].to_date,params[:end_date].to_date])
    elsif month_diff["no_of_months"].to_i >= 1 && month_diff["no_of_months"].to_i <= 3
      @rent_roll = RentRoll.find(:all,:conditions=>["(user_id = ? and resource_id =? and resource_type = ? and ((start_date <= '#{params[:start_date].to_date}' and end_date >= '#{params[:end_date].to_date}' and TIMESTAMPDIFF(MONTH,start_date,end_date) > 3) or (start_date >= '#{params[:start_date].to_date}' and end_date <= '#{params[:end_date].to_date}' and TIMESTAMPDIFF(MONTH,start_date,end_date) < 3)) )",@user_id_graph,@note.id, 'RealEstateProperty'])
    elsif month_diff["no_of_months"].to_i >= 4
      changed_start_date = params[:start_date].to_date.strftime("%Y")
      changed_end_date = params[:end_date].to_date.strftime("%Y")
      @rent_roll = RentRoll.find(:all,:conditions=>["user_id = ? and resource_id =? and resource_type = ? and DATE_FORMAT(start_date,'%Y') <= ? and DATE_FORMAT(end_date,'%Y') >= ? ",@user_id_graph,@note.id, 'RealEstateProperty',changed_start_date,changed_end_date])
    end
    now = Time.now.strftime('%Y%m%d')
    if !(@rent_roll.nil? || @rent_roll.blank?)
      @rent_sum = 0
      @rent_area = 0
      @aged_recievables = 0
      @rent_details_count = 0
      @rent_roll.each do |i|
        @rent_details  = i.rent_details
        @rent_details_count = @rent_details.count + @rent_details_count
        @rent_details.each do |j|
          @rent_sum = j.monthly_rent + @rent_sum
          @rent_area = j.rented_area + @rent_area
          @aged_recievables = j.aged_receivables + @aged_recievables
        end
      end
      @rent_area = @rent_area/@rent_roll.count rescue ZeroDivisionError
      @rent_sum = @rent_sum/@rent_roll.count rescue ZeroDivisionError
      @aged_recievables = @aged_recievables/@rent_roll.count rescue ZeroDivisionError
    end
  end

  #Used when Financial tab is clicked from Performance Review
  def financial
    #~ @show_variance_thresholds = true
    #~ @note = RealEstateProperty.find(params[:id])
    common_financial_wres_swig(params,"swig")
  end

  # Listing details in lease performance review page.
  def lease
    if params[:cur_month]
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    @show_variance_thresholds = false
    @portfolio = Portfolio.find(params[:portfolio_id]) if !@portfolio
    @note = RealEstateProperty.find_real_estate_property(params[:id]) if !@note
    @notes = RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id) unless  @portfolio.nil?
    @time_line_start_date,@time_line_end_date,@lease=Date.new(2011,1,1),Date.today.end_of_month,true
    if params[:tl_month] and params[:tl_year]
      month,year =  !params[:tl_month].nil? ? params[:tl_month].to_i : params[:tl_month] , !params[:tl_year].nil? ? params[:tl_year].to_i : params[:tl_year]
    end
    if !params[:tl_month].nil? and !params[:tl_month].blank?
      lease_details(month, year)
    else
      if !params[:tl_period].nil? and params[:tl_period] =="4" || params[:period] == "4" || (params[:tl_period] =="8" || params[:period] =="8")
        lease_details(nil, Date.today.year)
      elsif (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
        year = find_selected_year(Date.today.year)
        lease_details(nil,year)
      elsif !params[:tl_period].nil?  and params[:tl_period] =="5"
        dt = Date.today.months_ago(1)
        lease_details(dt.month, dt.year)
      elsif (!params[:tl_period].nil?  and params[:tl_period] =="6") || (params[:tl_period] =="3" || params[:period] =="3")
        year = find_selected_year(Date.today.prev_year.year)
        lease_details(nil,year)
      elsif !params[:tl_period].nil? and params[:tl_period] =="7"
        lease_details(@end_date.to_date.month,@start_date.to_date.year)
      elsif !params[:tl_period].nil? and params[:tl_period] =="8"
        year = find_selected_year(Date.today.year)
        lease_details(nil,year)
      end
    end
    find_redmonth_start_for_leases(find_selected_year(Date.today.year))
    timeline_msg= find_timeline_msg_for_leases
    @timeline_lease =  timeline_msg
    unless @pdf
      @time_display =  IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, 'RealEstateProperty']) if !@note.nil?
      if request.xhr?
      render :update do |page|
        if @note && @note.property_name.present?
          common_insert_js_to_page(page,["jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Leasing #{timeline_msg}: </div>');","jQuery('#id_for_variance_threshold').html('<ul class=inputcoll2 id=cssdropdown></ul>');"])
        else
          common_insert_js_to_page(page,["jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Leasing #{timeline_msg}</div>');","jQuery('#id_for_variance_threshold').html('<ul class=inputcoll2 id=cssdropdown></ul>');"])
        end
        if @note.leasing_type == 'Commercial'
          page.replace_html "portfolio_overview_property_graph", :partial => "/properties/property_lease_performance",:locals => {:leases_collection => @leases,
            :note_collection => @note,:month_collection => @month,:start_date => @start_date }
        else
          page.replace_html "portfolio_overview_property_graph", :partial => "/properties/wres/lease_performance",:locals =>{:wres_leases=>@wres_leases,:note_collection=>@note,
            :month_collection=>@month,:year_collection=>@year,:explanation=>@explanation,:start_date=>@start_date,:navigation_start_position=>@navigation_start_position}
        end
        set_quarterly_msg(page) if params[:period] =="2" || params[:tl_period] =="2"
         end
      end
    end
  end

  # Listing details in lease sub performance review page.
  def lease_sub_tab
    @time_line_start_date,@time_line_end_date,@lease,occupancy_type=Date.new(2010,1,1),Date.today.end_of_month,true,params[:occupancy_type]
    @note = RealEstateProperty.find_real_estate_property(params[:id])
    @portfolio = Portfolio.find(@note.portfolio_id) unless @note.nil?
    @notes = RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id) unless @portfolio.nil?
    @show_variance_thresholds = false
    @time_line_actual =  IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, 'RealEstateProperty']) if !@note.nil?
    month,year = params[:tl_month].to_i,params[:tl_year].to_i if params[:tl_month] && params[:tl_year]
    sub_tab = {"renewal" => "Renewals", "new" => "New Leases", "expirations" => "Expirations"}
    if params[:cur_month]
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    if !params[:tl_month].nil? and !params[:tl_month].blank?
      lease_sub_details(month, year, params[:occupancy_type])
    else
      if !params[:tl_period].nil? and params[:tl_period] =="4"
        lease_sub_details(nil, Date.today.year,  params[:occupancy_type])
      elsif (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
        year = find_selected_year(Date.today.year)
        lease_sub_details(nil,year,params[:occupancy_type])
      elsif !params[:tl_period].nil? and params[:tl_period] =="7"
        lease_sub_details(@end_date.to_date.month, @start_date.to_date.year,  params[:occupancy_type])
      elsif !params[:tl_period].nil?  and params[:tl_period] =="5"
        dt = Date.today.months_ago(1)
        lease_sub_details(dt.month, dt.year,  params[:occupancy_type])
      elsif !params[:tl_period].nil?  and params[:tl_period] =="6" || (params[:tl_period] =="3" || params[:period] =="3")
        year = find_selected_year(Date.today.prev_year.year)
        lease_sub_details(nil,year,params[:occupancy_type])
      elsif !params[:tl_period].nil?  and params[:tl_period] =="8"
        year = find_selected_year(Date.today.year)
        lease_sub_details(nil,year,params[:occupancy_type])
      end
    end
    find_redmonth_start_for_leases(find_selected_year(Date.today.year))
    timeline_msg= find_timeline_msg_for_leases
    render :update do |page|
      page.assign "active_sub_call", "lease_sub_tab"
      page.call "enable_disable_tab", "lease", "lease"
      val_str = "jQuery(\'.executiveheadcol_for_title\').html(\'<div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span><a href=\"#\" onclick=\"performanceReviewCalls(\\'lease\\',{});return false;\">Leasing</a><img width=\"10\" height=\"9\" src=\"/images/eventsicon2.png\">&nbsp;</div><div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>#{sub_tab[params[:occupancy_type]]} #{timeline_msg}</div>\');"
      if !@sub_leases.blank?
        page << val_str
      else
        page << val_str
        page << "jQuery('#id_for_variance_threshold').html('<ul class=inputcoll2 id=cssdropdown></ul>');"
      end
      page.replace_html 'portfolio_overview_property_graph', :partial=>"/properties/property_lease_sub_performance",:locals => {:sub_leases => @sub_leases,
        :start_date => @start_date,:note_collection => @note, :month_collection => @month, :year_collection => @year}
    end
  end

  # Sorting functionality in the lease sub page
  def  sort_lease_sub_details
    @suites = PropertySuite.find(:all, :conditions=>['real_estate_property_id = ?', params[:id]]).map(&:id) unless @note.nil?
    @sub_leases = PropertyLease.find(:all , :conditions=>['month = ? and year = ? and occupancy_type = ? and property_suite_id IN(?)', params[:tl_month], params[:tl_year], params[:occupancy_type], @suites],:order=>"#{params[:field]} #{params[:key]}") unless @suites.nil?
    @sub_leases = @sub_leases.paginate :page => params[:page], :per_page => 10
    render :update do |page|
      page.replace_html 'portfolio_overview_property_graph', :partial=>"/properties/property_lease_sub_performance",:locals => {:sub_leases => @sub_leases,
        :start_date => @start_date,:note_collection => @note}
    end
  end

  def wres_lease
    lease
  end

  # Listing details in capital expenditure performance review page.
  def capital_expenditure
    find_dashboard_portfolio_display
    #~ @show_variance_thresholds = true
    if params[:tl_period] == "7" || params[:period] == "7"
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    @cap_ex = true
    #~ @portfolio = Portfolio.find(params[:portfolio_id])
    #~ @note = RealEstateProperty.find_real_estate_property(params[:id])
    @notes = RealEstateProperty.find_properties_by_portfolio_id(params[:portfolio_id]) if params[:portfolio_id].present?
    if !params[:tl_month].nil? and !params[:tl_month].blank?
      capital_expenditure_month
    else
      if(!params[:tl_period].nil? and params[:tl_period] =="4")
        capital_expenditure_year
      elsif(!params[:tl_period].nil? and params[:tl_period] =="7") || ((params[:period] == "2" || params[:tl_period] == "2"))
        capital_expenditure_month_year
      elsif !params[:tl_period].nil? and params[:tl_period] =="5"
        dt = Date.today.months_ago(1)
        params[:tl_month] = dt.month
        params[:tl_year] = dt.year
        capital_expenditure_month
      elsif !params[:tl_period].nil? and params[:tl_period] =="6" || (params[:tl_period] =="3" || params[:period] =="3")
        year = find_selected_year(Date.today.prev_year)
        year >= Date.today.year ? capital_expenditure_for_year_forecast : capital_expenditure_prev_year
      elsif !params[:tl_period].nil? and params[:tl_period] =="8"
        year = find_selected_year(Date.today.year)
        capital_expenditure_for_year_forecast
      end
    end
    @time_display =  IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, @resource]) if !@note.nil?
    render :action => 'capital_expenditure.rjs' unless @pdf
  end

  # Listing details in capital expenditure sub performance review page.
  def capital_expenditures_sub_view    #~ @show_variance_thresholds = true

    @note = RealEstateProperty.note_find(params[:id]) if !@note
    calc_for_financial_data_display
    @month_list= []
    month_details = ['', 'january','february','march','april','may','june','july','august','september','october','november','december']
    #month = !(params[:tl_month].nil? || params[:tl_month].empty?) ? "ci.month = #{params[:tl_month]}" : "ci.month > 1 and ci.month < #{Date.today.month - 1 } "
    @order_list = {'order by suite_number desc' => 'suite_number asc', 'order by suite_number asc'=>'suite_number desc','order by tenant_name desc' => 'tenant_name asc', 'order by tenant_name asc'=>'tenant_name desc'}
    @arr_list = {'desc'=>'/images/bulletarrowup.png', 'asc'=>'/images/bulletarrowdown.png'}
    category = ['','BUILDING IMPROVEMENTS','TENANT IMPROVEMENTS','LEASING COMMISSIONS','LEASE COSTS','NET LEASE COSTS','LOAN COSTS']
    @order =  (params[:order].nil? || params[:order].empty?) ? "" : "order by #{params[:order]}"
    @tenant_order =  (params[:tenant_order].nil? || params[:tenant_order].empty?) ? "" : "order by #{params[:tenant_order]}"
    @odr =  (params[:order].nil? || params[:order].empty?) ? "" : "order by #{params[:order]}" #sasie YTD
    if params[:order] == "suite_number asc"
      @odr = "order by CAST(suite_number AS SIGNED) asc"
    elsif  params[:order] == "suite_number desc"
      @odr = "order by CAST(suite_number AS SIGNED) desc"
    end
    @tnt_odr =  (params[:tenant_order].nil? || params[:tenant_order].empty?) ? "" : "order by #{params[:tenant_order]}"#sasie YTD
    if params[:tl_period] == "7" || params[:period] == "7"
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    if !params[:tl_month].nil? and !params[:tl_month].blank?
      shft_type = ''
      upt_yr_cnd = "#{month_details[params[:tl_month].to_i]}"
      mnt_cond = "AND ci.month= #{params[:tl_month]}"
      year_condition = "IFNULL(f.#{month_details[params[:tl_month].to_i]},0) as actual"
      month_condition = "AND month= #{params[:tl_month]}"
      @timeline=Date.new(params[:tl_year].to_i,params[:tl_month].to_i,1)
      @period ="1"
      @cap_expen_mon = true
    else
      if !params[:tl_period].nil? and params[:tl_period] =="4"
        shft_type = '_ytd'#sasie YTD
        year_condition = "(IFNULL(f.january,0)+IFNULL(f.february,0)+IFNULL(f.march,0)+IFNULL(f.april,0)+IFNULL(f.may,0)+IFNULL(f.june,0)+IFNULL(f.july,0)+IFNULL(f.august,0)+IFNULL(f.september,0)+IFNULL(f.october,0)+IFNULL(f.november,0)+IFNULL(f.december,0) ) as actual"
        for m in 1..12
          @month_list <<  Date.new(Date.today.year,m,1).strftime("%Y-%m-%d")
        end
        pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=?",Date.today.year.to_s,params[:id]],:order => "month desc")
        month_qry= @financial_month
        if  (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note)
          month_qry = month_qry
        else
          month_qry = pci.month if (!pci.nil?)
        end
        upt_yr_cnd = "#{month_details[month_qry]}"#sasie YTD
        mnt_cond = "AND ci.month= #{month_qry}"#sasie YTD
        month_condition = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : "AND month = #{month_qry}"
        params[:tl_year] = Date.today.year.to_s
        @period = "4"
      elsif(!params[:tl_period].nil? and params[:tl_period] =="7") || (params[:period] == "2" || params[:tl_period] == "2")
        shft_type = '_ytd'#sasie YTD
        if params[:period] == "2" || params[:tl_period] == "2"
          @period = "2"
          year_condition = "(#{find_quarterly_month_year.join("+")}) as actual"
          @end_date =  Time.local("#{params[:tl_year]}","#{params[:quarter_end_month]}").strftime("%Y-%m-%d")
          if find_accounting_system_type(1,@note)
            pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=? ",find_selected_year(Date.today.year),params[:id]],:order => "month desc")
          else
            pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=? and month in (#{find_month_list_for_quarterly.join(",")}) ",find_selected_year(Date.today.year),params[:id]],:order => "month desc")
          end
          month_qry = pci.month if (!pci.nil?)
        else
          @period = "7"
          year_condition = "(IFNULL(f.january,0)+IFNULL(f.february,0)+IFNULL(f.march,0)+IFNULL(f.april,0)+IFNULL(f.may,0)+IFNULL(f.june,0)+IFNULL(f.july,0)+IFNULL(f.august,0)+IFNULL(f.september,0)+IFNULL(f.october,0)+IFNULL(f.november,0)+IFNULL(f.december,0) ) as actual"
          for m in 1..12
            @month_list <<  Date.new(params[:tl_year].to_i,m,1).strftime("%Y-%m-%d")
          end
          #pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=? and month",@end_date.to_date.year.to_s,params[:id]],:order => "month desc")
          months_ytd = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
          month_ytd = months_ytd.index(params[:cur_month])
          month_qry = month_ytd + 1
          #~ if  (@note.accounting_system_type_id == 3 || @note.accounting_system_type_id == 1) && @note.leasing_type=="Commercial"
          #~ month_qry = month_qry
          #~ else
          #~ month_qry = pci.month if (!pci.nil?)
          #~ end
          month_qry = month_qry if  find_accounting_system_type(1,@note) && is_commercial(@note)
          max_month = PropertyCapitalImprovement.find_by_sql("SELECT max(ci.month) as month,id FROM property_capital_improvements ci WHERE ci.category IN ('TOTAL TENANT IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASE COSTS','TOTAL NET LEASE COSTS','TOTAL LOAN COSTS') AND ci.real_estate_property_id = #{@note.id}  AND ci.year=#{params[:tl_year]} and ci.month <= #{month_qry} HAVING max(ci.month)")
          #          unless find_accounting_system_type(1,@note)
          month_qry = max_month[0].month unless find_accounting_system_type(1,@note) && is_commercial(@note)
          upt_yr_cnd = "#{month_details[month_qry]}"#sasie YTD
          mnt_cond = "AND ci.month= #{month_qry}"#sasie YTD
          #          end
          month_condition = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : "AND month = #{month_qry}"
        end
      elsif !params[:tl_period].nil? and params[:tl_period] =="5"
        shft_type = ''#sasie YTD
        upt_yr_cnd = "#{month_details[@financial_month]}"#sasie YTD
        mnt_cond = "AND ci.month= #{@financial_month}"#sasie YTD
        year_condition = "IFNULL(f.#{month_details[@financial_month]},0) as actual"
        month_condition = "AND month= #{@financial_month}"
        @current_time_period=Date.new(@financial_year,@financial_month,1)
        @period = "5"
        month_qry = @financial_month
      elsif !params[:tl_period].nil? and params[:tl_period] =="6" || (params[:tl_period] =="3" || params[:period] =="3")
        shft_type = '_ytd'#sasie YTD
        upt_yr_cnd = "december"#sasie YTD
        mnt_cond = ''#sasie YTD
        year_condition = "(IFNULL(f.january,0)+IFNULL(f.february,0)+IFNULL(f.march,0)+IFNULL(f.april,0)+IFNULL(f.may,0)+IFNULL(f.june,0)+IFNULL(f.july,0)+IFNULL(f.august,0)+IFNULL(f.september,0)+IFNULL(f.october,0)+IFNULL(f.november,0)+IFNULL(f.december,0) ) as actual"
        month_condition = ""
        year = find_selected_year(Date.today.prev_year.year)
        params[:tl_year] = year
        for m1 in 1..12
          @month_list <<  Date.new(params[:tl_year].to_i,m1,1).strftime("%Y-%m-%d")
        end
        @period = "6"  if (params[:tl_period] =="6" || params[:period] =="6")
        @period = "3" if (params[:tl_period] =="3" || params[:period] =="3")
        month_qry = 12
      end
    end
    ######Yearforecast conditions######
    if (params[:tl_period] =="8" || params[:period] =="8" || ((params[:period] =="3" || params[:tl_period] =="3") && params[:tl_year].to_i >= Date.today.year ) )
      year =  find_selected_year(Date.today.year)
      pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=?",Date.today.year.to_s,params[:id]],:order => "month desc")
      month_qry = 12
      if  (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note)
        month_qry = month_qry
      else
        month_qry = pci.month if (!pci.nil?)
      end
      month_condition = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : "AND month = #{month_qry}"
      val_qry="select pf1.january as january,pf1.february as february,pf1.march as march,pf1.april as april, pf1.may as may,pf1.june as june,pf1.july as july,pf1.august as august,pf1.september as september,pf1.october as october,pf1.november as november,pf1.december as december,ic.category as Cate FROM  property_capital_improvements  ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.pcb_type = 'c' and pf1.source_type = 'PropertyCapitalImprovement' where ic.category ='TOTAL CAPITAL EXPENDITURES' and ic.real_estate_property_id = #{params[:id]} and ic.year= #{year} #{month_condition}"
      k=0
      value= PropertyCapitalImprovement.find_by_sql(val_qry)
      @result = value[k].attributes.keys.select {|i| i if value[k].send(:"#{i}") == "0" }  if !(value.blank? || value.empty?)
      unless @result.nil?
        @month = @result.flatten.to_s
        year_to_date = @financial_month
        @ytd_actuals= []
        for m in 1..year_to_date
          if @month.include?("#{Date::MONTHNAMES[m].downcase}")
            @ytd_actuals << "IFNULL(pf2."+Date::MONTHNAMES[m].downcase+",0)"
          else
            @ytd_actuals << "IFNULL(pf1."+Date::MONTHNAMES[m].downcase+",0)"
          end
        end
      end
      year_to_date = @financial_month + 1
      year = find_selected_year(Date.today.year)
      params[:tl_year] = year
      @ytd_budget= []
      for m in year_to_date..12
        @ytd_budget << "IFNULL(pf2."+Date::MONTHNAMES[m].downcase+",0)"
      end
       (params[:tl_period] == "8" && params[:tl_year] >= Date.today.year) ? @period = "8" : @period = "3"
    end
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    if params[:tl_period] != '7' && params[:period] != "7" && !month_condition
      pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=?",Date.today.year.to_s,params[:id]],:order => "month desc")
      if  (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note)
        month_qry = month_qry
      else
        month_qry = pci.month if (!pci.nil?)
      end
      month_condition = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : "AND month = #{month_qry}"
    end
    mnt_cond=(find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : month_condition
    if (params[:tl_period] =="8" || params[:period] =="8" || ((params[:period] =="3" || params[:tl_period] =="3") && params[:tl_year].to_i >= Date.today.year ) )
      if !@ytd_actuals.nil?
        qry = "SELECT pc.tenant_name,pc.category,(#{@ytd_actuals.join("+")} + #{@ytd_budget.join("+")}) as actual,pc.annual_budget,pc.project_status,s.suite_number FROM
property_capital_improvements pc LEFT JOIN property_financial_periods pf1 on pf1.source_id = pc.id  and pf1.pcb_type='c'and pf1.source_type = 'PropertyCapitalImprovement'LEFT JOIN property_financial_periods pf2 on pf2.source_id = pc.id  and pf2.pcb_type='b'and pf2.source_type = 'PropertyCapitalImprovement'  LEFT JOIN property_suites s ON s.id = pc.property_suite_id WHERE pc.category = '#{category[params[:cap_call_id].to_i]}' AND pc.real_estate_property_id = #{params[:id]} AND pc.year = #{params[:tl_year]} #{month_condition}"
      end
      @cap_exp_result = !@ytd_actuals.nil? ? PropertyCapitalImprovement.find_by_sql(qry) : []
    else
      mnt_cond = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : mnt_cond
      if params[:period] == "2" || params[:tl_period] == "2"
        find_quarterly_month_year_for_cap_exp
        find_quarterly_each_msg(params[:quarter_end_month].to_i,params[:tl_year].to_i)
        q_months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        month_condition = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : (@quarter_ending_month && q_months.index(@quarter_ending_month) ? "AND ci.month = #{q_months.index(@quarter_ending_month)+1}" : "AND ci.month = #{params[:quarter_end_month].to_i}")
        mnt_cond=(find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : month_condition
        if(params[:period] == "2" || params[:tl_period] == "2")  && @ytd.length == 3
          sum_string_act = "(#{@ytd_act[0]})+#{@ytd_act[1]}+#{@ytd_act[2]}"
          sum_string_bud = "(#{@ytd_bud[0]})+#{@ytd_bud[1]}+#{@ytd_bud[2]}"
        else
          sum_string_act = "(#{@ytd_act.join("+")})"
          sum_string_bud = "(#{@ytd_bud.join("+")})"
        end
        qry = "select pf1.source_id, #{sum_string_act} as actual,#{sum_string_bud} as annual_budget, ci.tenant_name, ci.category, ci.project_status, ps.suite_number
from property_capital_improvements ci
left join property_financial_periods pf1 on pf1.source_id = ci.id and pf1.source_type='PropertyCapitalImprovement' and pf1.pcb_type='c'
left join property_financial_periods pf2 on pf2.source_id = ci.id and pf2.source_type='PropertyCapitalImprovement' and pf2.pcb_type='b'
left join property_suites ps on ps.id = ci.property_suite_id
where
ci.category = '#{category[params[:cap_call_id].to_i]}'  AND ci.real_estate_property_id = #{params[:id]} AND  ci.year = #{params[:tl_year]} #{mnt_cond} AND ci.tenant_name <> ci.category #{@odr}#{@tnt_odr}"
        @cap_exp_result = PropertyCapitalImprovement.find_by_sql(qry)
      else
        qry = "select pf1.source_id, IFNULL(pf1.#{upt_yr_cnd},0) as actual, IFNULL(pf2.#{upt_yr_cnd},0) as annual_budget, ci.tenant_name, ci.category, ci.project_status, ps.suite_number
from property_capital_improvements ci
left join property_financial_periods pf1 on pf1.source_id = ci.id and pf1.source_type='PropertyCapitalImprovement' and pf1.pcb_type='c#{shft_type}'
left join property_financial_periods pf2 on pf2.source_id = ci.id and pf2.source_type='PropertyCapitalImprovement' and pf2.pcb_type='b#{shft_type}'
left join property_suites ps on ps.id = ci.property_suite_id
where
ci.category = '#{category[params[:cap_call_id].to_i]}'  AND ci.real_estate_property_id = #{params[:id]} AND  ci.year = #{params[:tl_year]} #{mnt_cond} AND ci.tenant_name <> ci.category #{@odr}#{@tnt_odr}"
        @cap_exp_result = PropertyCapitalImprovement.find_by_sql(qry)
      end
    end
    @cap_exp_result = @cap_exp_result.collect{|cap_exp| cap_exp if cap_exp.actual.to_f != 0 || cap_exp.annual_budget.to_f != 0}.compact if (!@cap_exp_result.nil? || !@cap_exp_result.blank?)
    @cap_exp_result = @cap_exp_result.paginate :per_page => 13 ,:page=> params[:page] if (!@cap_exp_result.nil? || !@cap_exp_result.blank?)
    render :update do |page|

      if @note && @note.property_name.present?
        str = "<div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span><a href=\"#\" onclick=\"performanceReviewCalls(\\'capital_expenditure\\',{}); return false;\">Capital Expenditures</a><img width=\"10\" height=\"9\" src=\"/images/eventsicon2.png\"/></div><div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span> #{category[params[:cap_call_id].to_i].titleize}"
      else
        str = "<div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span><a href=\"#\" onclick=\"performanceReviewCalls(\\'capital_expenditure\\',{}); return false;\">Capital Expenditures</a><img width=\"10\" height=\"9\" src=\"/images/eventsicon2.png\"/></div><div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span> #{category[params[:cap_call_id].to_i].titleize}"
      end
      page.replace_html 'portfolio_overview_property_graph', :partial => '/properties/capital_expenditures_sub_graph',:locals => {:cap_exp_result => @cap_exp_result,
        :note_collection => @note,:start_date => @start_date,:order_list => @order_list,:order_collection => @order,:tenant_order => @tenant_order,:arr_list => @arr_list}
      if @period!="1"
        page.replace_html "time_line_selector", :partial => "/properties/time_line_selector", :locals => {:period => @period, :note_id => params[:id], :partial_page =>"portfolio_partial", :start_date => 0, :timeline_start => @time_line_start_date, :timeline_end => @time_line_end_date }
      end
      page << "jQuery('.executiveheadcol_for_title').html('#{str}');"
      page << "jQuery('#id_for_modify_threshold').hide();"
      set_quarterly_msg(page) if params[:period] =="2" || params[:tl_period] =="2"
    end
  end

  # Financial subpage for the call for performance review page
  def financial_subpage
  end

  def wres_financial_subpage
  end

  def common_financial_method
    financial_sub_items
    render :action => 'financial_subpage.rjs'
  end

  # Listing details in cash & receivable sub performance review page.
  def cash_n_receivables_sub_view
    @show_variance_thresholds = false
    @note = RealEstateProperty.note_find(params[:id]) if !@note
    calc_for_financial_data_display
    @par = ",cal_exp:'true'" if params[:cal_exp]
    @month_list = []
    view_budget = []
    month_details = ['', 'january','february','march','april','may','june','july','august','september','october','november','december']
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    bread_text = breadcrumb_in_cash(params[:cash_item_title],params[:cash_find_id])
    if params[:tl_period] == "7" || params[:period] == "7"
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    if !params[:tl_month].nil? and !params[:tl_month].blank?
      view =  "IFNULL(f.#{month_details[params[:tl_month].to_i]},0)"
      @timeline=Date.new(params[:tl_year].to_i,params[:tl_month].to_i,1)
      @period ="1"
      @current_time_period=Date.new(params[:tl_year].to_i,params[:tl_month].to_i,1)
    else
      if(params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
        find_quarterly_month_year
        view_budget = @ytd
        view = "(#{view_budget.join("+")})"  if !view_budget.nil?
        @period = "2"
      elsif !params[:tl_period].nil? and params[:tl_period] =="4"
        for m in 1..@financial_month
          @month_list <<  Date.new(Date.today.year,m,1).strftime("%Y-%m-%d")
          view_budget << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
        end
        view = "(#{view_budget.join("+")})"  if !view_budget.nil?
        @period = "4"
      elsif !params[:tl_period].nil? and params[:tl_period] =="7"
        for m in 1..@end_date.to_date.month
          @month_list <<  Date.new(params[:tl_year].to_i,m,1).strftime("%Y-%m-%d")
          view_budget << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
        end
        view = "(#{view_budget.join("+")})"  if !view_budget.nil?
        @period = "7"
      elsif !params[:tl_period].nil? and params[:tl_period] =="5"
        view = "IFNULL(f.#{month_details[@financial_month]},0)"
        @current_time_period=Date.new(@financial_year,@financial_month,1)
        @period = "5"
      elsif !params[:tl_period].nil? and params[:tl_period] =="6" || ((params[:tl_period] =="3" || params[:period] =="3") && params[:tl_year].to_i < Date.today.year )
        view = "(IFNULL(f.january,0)+IFNULL(f.february,0)+IFNULL(f.march,0)+IFNULL(f.april,0)+IFNULL(f.may,0)+IFNULL(f.june,0)+IFNULL(f.july,0)+IFNULL(f.august,0)+IFNULL(f.september,0)+IFNULL(f.october,0)+IFNULL(f.november,0)+IFNULL(f.december,0) )"
        params[:tl_year] =  find_selected_year(Date.today.prev_year.year)
        for m in 1..12
          @month_list <<  Date.new(params[:tl_year],m,1).strftime("%Y-%m-%d")
        end
        @period = "6" if(params[:tl_period] =="6" || params[:tl_period] =="6")
        @period = "3" if(params[:tl_period] =="3" || params[:tl_period] =="3")
      end
    end
    ######Yearforecast conditions######
    if (params[:tl_period] =="8" || params[:period] =="8" || ((params[:period] =="3" || params[:tl_period] =="3") && params[:tl_year].to_i >= Date.today.year ) )
      year_forecast_condition
      unless @result.nil?
        @month = @result.flatten.to_s
        year_to_date = @financial_month
        @ytd_actuals= []
        for m in 1..year_to_date
          if @month.include?("#{Date::MONTHNAMES[m].downcase}")
            @ytd_actuals << "IFNULL(pf2."+Date::MONTHNAMES[m].downcase+",0)"
          else
            @ytd_actuals << "IFNULL(pf1."+Date::MONTHNAMES[m].downcase+",0)"
          end
        end
      end
      @ytd_actuals = Date.today.month == 1 ? 0 : @ytd_actuals.join("+")
      year_to_date = (Date.today.month == 1 && @financial_month == 12) ? 1 : (Date.today.month == 2 && @financial_month == 12) ? 2 :  @financial_month + 1
      year = find_selected_year(Date.today.year)
      params[:tl_year] = year
      @ytd_budget= []
      for m in year_to_date..12
        @ytd_budget << "IFNULL(pf2."+Date::MONTHNAMES[m].downcase+",0)"
      end
      @ytd_budget = @ytd_budget.join("+")
      view =   "#{@ytd_actuals} + #{@ytd_budget}"  if !@ytd_actuals.nil?
      if view.nil?
        @ytd_actuals= []
        for m in 1..year_to_date
          @ytd_actuals << "IFNULL(pf1."+Date::MONTHNAMES[m].downcase+",0)"
        end
        view = "#{@ytd_actuals.join("+")} + #{@ytd_budget}"
      end
       (params[:tl_period] == "8" && params[:tl_year] >= Date.today.year) ? @period = "8" : @period = "3"
    end
    titles = ['','cash flow from operating activities','capital expenditures','cash flow from financing activities','Cash Flow From Op Activities','Non Cash Items in Net Income','Changes in assets and liabilities:','Capital Expenditures','Cash Flow From Financing Activities','CASH FLOW STATEMENT']
    bread_lvl = ['','Net Cash from Operating Activities','Total Capital Expenditures','Net Cash from Financing Activities','Cash Flow From Op Activities','Non Cash Items in Net Income','Changes in assets and liabilities:','Capital Expenditures','Cash Flow From Financing Activities']
    if (Date.today.month == 1)
      @explanation = true
      year = Date.today.prev_month.year
    else
      year = params[:tl_year]
    end
    if params[:cash_find_id] && !params[:cash_find_id].blank?
      cash_record = IncomeAndCashFlowDetail.find_by_id(params[:cash_find_id])
      cash_title =cash_record.title if cash_record
      new_cash_record = IncomeAndCashFlowDetail.find_by_sql("select id from income_and_cash_flow_details where title = '#{cash_title}' and resource_id= #{params[:id]} and resource_type='RealEstateProperty' and year = #{year}")
      params[:cash_find_id] =  new_cash_record && !new_cash_record.empty? ? new_cash_record[0].id : ""
    end
    if params[:cash_call_id] == '7'
      init_condition =  "select id from income_and_cash_flow_details where title = '#{titles[params[:cash_call_id].to_i]}' and resource_id= #{params[:id]} and resource_type='RealEstateProperty' and year = #{year} and parent_id IN (select id from income_and_cash_flow_details where title = 'CASH FLOW STATEMENT')"
    else
      init_condition = (params[:cash_find_id].nil? || params[:cash_find_id].blank?) ? "select id from income_and_cash_flow_details where title = '#{titles[params[:cash_call_id].to_i]}' and resource_id= #{params[:id]} and resource_type='RealEstateProperty' and year = #{year} and parent_id IN (select id from income_and_cash_flow_details where (title = 'CASH FLOW STATEMENT' or title = 'cash flow statement summary' ) )" : "#{params[:cash_find_id]}"
    end
    init_qry = "select id, title from income_and_cash_flow_details where parent_id = (#{init_condition} ) and resource_type='RealEstateProperty' and year = #{year};"
    init_qry_for_total = "select id, title from income_and_cash_flow_details where id = (#{init_condition} ) and resource_type='RealEstateProperty' and year = #{year};"

    nodes = IncomeAndCashFlowDetail.find_by_sql(init_qry)
    nodes_for_total = IncomeAndCashFlowDetail.find_by_sql(init_qry_for_total)
    if (params[:tl_period] =="8" || params[:period] =="8" || ((params[:period] =="3" || params[:tl_period] =="3") && params[:tl_year].to_i >= Date.today.year ) )
      value_qry = "select i.id, i.title,#{view} as actuals,(pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december) budget,pf1.pcb_type,pf2.pcb_type from income_and_cash_flow_details i LEFT JOIN  property_financial_periods pf1 on pf1.source_id = i.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = i.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' left join income_and_cash_flow_details ic2 on ic2.id=i.parent_id WHERE  i.resource_id= #{@note.id} AND i.resource_type = 'RealEstateProperty' AND i.year =#{params[:tl_year]}"
      value_qry_for_total = "select i.id, i.title,#{view} as actuals,(pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december) budget,pf1.pcb_type,pf2.pcb_type from income_and_cash_flow_details i LEFT JOIN  property_financial_periods pf1 on pf1.source_id = i.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = i.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' left join income_and_cash_flow_details ic2 on ic2.id=i.id WHERE  i.resource_id= #{@note.id} AND i.resource_type = 'RealEstateProperty' AND i.year =#{params[:tl_year]}"
      vals = IncomeAndCashFlowDetail.find_by_sql value_qry
      vals_for_total = IncomeAndCashFlowDetail.find_by_sql value_qry_for_total
      @asset_details = Array.new
      nodes = IncomeAndCashFlowDetail.find_by_sql(init_qry)
      nodes.each do |node|
        bud =  vals.detect{ |i| i.id == node.id }
        act =  vals.detect{ |i| i.id == node.id }
        os  = OpenStruct.new({:title => node.title})
        os.budget  =  bud.nil? ? 0 : bud.budget
        os.actual  =  act.nil? ? 0 : act.actuals
        os.node = node.id
        @asset_details << os
      end
      @asset_details_for_total = Array.new
      nodes_for_total = IncomeAndCashFlowDetail.find_by_sql(init_qry_for_total)
      nodes_for_total.each do |node|
        bud =  vals_for_total.detect{ |i| i.id == node.id }
        act =  vals_for_total.detect{ |i| i.id == node.id }
        os  = OpenStruct.new({:title => node.title})
        os.budget  =  bud.nil? ? 0 : bud.budget
        os.actual  =  act.nil? ? 0 : act.actuals
        os.node = node.id
        @asset_details_for_total << os
      end
    else
      value_qry = "SELECT i.id,i.title, #{view} as value, f.pcb_type FROM property_financial_periods f, income_and_cash_flow_details i WHERE f.source_id = i.id AND f.pcb_type IN ('c','b') AND i.parent_id IN (#{init_condition})  AND f.source_type = 'IncomeAndCashFlowDetail';"
      value_qry_for_total = "SELECT i.id,i.title, #{view} as value, f.pcb_type FROM property_financial_periods f, income_and_cash_flow_details i WHERE f.source_id = i.id AND f.pcb_type IN ('c','b') AND i.id IN (#{init_condition})  AND f.source_type = 'IncomeAndCashFlowDetail';"
      vals = IncomeAndCashFlowDetail.find_by_sql value_qry
      vals_for_total = IncomeAndCashFlowDetail.find_by_sql value_qry_for_total
      @asset_details = Array.new
      nodes = IncomeAndCashFlowDetail.find_by_sql(init_qry)
      nodes.each do |node|
        bud =  vals.detect{ |i| i.id == node.id && i.pcb_type == 'b'}
        act =  vals.detect{ |i| i.id == node.id && i.pcb_type == 'c'}
        os  = OpenStruct.new({:title => node.title})
        os.budget  =  bud.nil? ? 0 : bud.value
        os.actual  =  act.nil? ? 0 : act.value
        os.node = node.id
        @asset_details << os
      end
      @asset_details_for_total = Array.new
      nodes_for_total = IncomeAndCashFlowDetail.find_by_sql(init_qry_for_total)
      nodes_for_total.each do |node|
        bud =  vals_for_total.detect{ |i| i.id == node.id && i.pcb_type == 'b'}
        act =  vals_for_total.detect{ |i| i.id == node.id && i.pcb_type == 'c'}
        os  = OpenStruct.new({:title => node.title})
        os.budget  =  bud.nil? ? 0 : bud.value
        os.actual  =  act.nil? ? 0 : act.value
        os.node = node.id
        @asset_details_for_total << os
      end
    end
    bread_arr = (params[:cash_find_id].nil? || params[:cash_find_id].blank?) ? (view_context.bread_crum_cash(IncomeAndCashFlowDetail.find_by_sql(init_condition).first.id) if !(IncomeAndCashFlowDetail.find_by_sql(init_condition).nil? || IncomeAndCashFlowDetail.find_by_sql(init_condition).blank?)) : view_context.bread_crum_cash(params[:cash_find_id])
    if (bread_arr.nil? || bread_arr.blank?)
      bread_arr = ""
    end
    bread_txt = "<div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" height=\"16\" width=\"14\"></span><a id=\"a1\" href=\"#\" onclick=\"performanceReviewCalls(\\'cash_n_receivables\\',{}); return false;\">Cash</a>"
     (bread_arr.length-2).downto(0) do |itr|
      b_txt = titles.include?(bread_arr[itr].split('----')[1].strip) ? bread_lvl[titles.index(bread_arr[itr].split('----')[1].strip.to_s)] : bread_arr[itr].split('----')[1].gsub(/\b\w/){$&.upcase}.gsub(':','').to_s
      if !((find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note) ) && b_txt.downcase == "cash flow from op activities")
        if !(remote_property(@note.accounting_system_type_id) && b_txt == "NET INCOME")
          bread_txt << "<img src=\"/images/eventsicon2.png\" height=\"9\" width=\"10\"></div><div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span><a"
          if itr != 1
            bread_txt << " style=\"color:black\""
          else
            bread_txt << " href=\"\" onclick=\"cashSubCalls(1,{cash_find_id:\\'#{bread_arr[itr].split('----')[0]}\\'}); return false;\""
          end
          bread_txt << "title=\"#{b_txt.to_s}\"> #{view_context.display_truncated_chars(b_txt,30,true)}</a>"
        end
      end
    end
    @asset_details = @asset_details.collect{|asset| asset if asset.actual.to_f.round !=0 || asset.budget.to_f.round !=0}.compact if @asset_details && !@asset_details.empty?
    render :update do |page|
      page.replace_html "portfolio_overview_property_graph", :partial=> "/properties/cash_and_receivable_sub_view",:locals => {:asset_details_collection => @asset_details,:asset_details_for_total_collection => @asset_details_for_total,:current_time_period => @current_time_period,:explanation => @explanation,:note_collection => @note,:portfolio_collection => @portfolio,:start_date => @start_date,
        :month_collection =>@month}
      if @period!="1"
        page.call "breadData_for_cash_n_receivables","true"
        page.replace_html "time_line_selector", :partial => "/properties/time_line_selector", :locals => {:period => @period, :note_id => params[:id], :partial_page =>"portfolio_partial", :start_date => 0, :timeline_start => @time_line_start_date, :timeline_end => @time_line_end_date }
      end
      unless bread_text.blank?
        page << "jQuery('.executiveheadcol_for_title').html('#{bread_text}');"
      else
        page.call "breadData_for_cash_n_receivables","false"
      end
      page << "jQuery('#id_for_variance_threshold').html('<ul class=inputcoll2 id=cssdropdown></ul>');"
      set_quarterly_msg(page) if params[:period] =="2" || params[:tl_period] =="2"
    end
  end

  def wres_capital_expenditure
    @portfolio = Portfolio.find(params[:portfolio_id])
    @note = RealEstateProperty.find_real_estate_property(params[:id])
    @notes = RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id)
    @explanation = true
    if params[:tl_period] == "7" || params[:period] == "7"
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    if !params[:tl_month].nil? and !params[:tl_month].blank?
      wres_other_income_and_expense_month(params[:tl_month].to_i, params[:tl_year].to_i)
    else
      if !params[:tl_period].nil? and params[:tl_period] =="4"
        wres_other_income_and_expense_year
      elsif !params[:tl_period].nil? and params[:tl_period] =="7"
        wres_other_income_and_expense_year
      elsif !params[:tl_period].nil? and params[:tl_period] =="5"
        dt = Date.today.months_ago(1)
        params[:tl_month] = dt.month
        params[:tl_year] = dt.year
        wres_other_income_and_expense_month
      elsif !params[:tl_period].nil? and params[:tl_period] =="6"
        wres_other_income_and_expense_prev_year
      end
    end
    @time_display =  IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, 'RealEstateProperty']) if !@note.nil?
  end

  #This method is used when options in select period is clicked
  def select_time_period
    if params[:start_date]
      @timeline = params[:start_date]
      @start_date = params[:start_date]
    end
    if params[:end_date]
      @end_date = params[:end_date]
    end
    id = params[:note_id] ? params[:note_id] : params[:id]
    find_dashboard_portfolio_display
    #~ @note = RealEstateProperty.find_real_estate_property(id)
    find_financial_sub_id if params[:partial_page] =="financial_subpage" || params[:partial_page] == "balance_sheet_sub_page"
    #~ @notes = RealEstateProperty.find(:all, :conditions =>["portfolio_id = ?",@note.portfolio_id], :order =>"created_at desc")
    @user_id_graph = current_user.id
    @period =  params[:period] ?  params[:period] : params[:tl_period]
    @time = @@time
    @partial_file = "/properties/sample_pie"
    @swf_file = "Pie2D.swf"
    @xml_partial_file = "/properties/sample_pie"
    @portfolio = @note.class.eql?(Portfolio) ? @note : @note.portfolio
    if @period == "1"   or @period == "5" or @period == "11"
      @start_date = @@time.beginning_of_month.strftime("%Y-%m-%d")
      @end_date = @@time.end_of_month.strftime("%Y-%m-%d")
    elsif @period == "2"
      @start_date = @@time.beginning_of_quarter.strftime("%Y-%m-%d")
      @end_date = @@time.end_of_quarter.strftime("%Y-%m-%d")
    elsif @period ==  "3"
      @start_date = @@time.prev_year.beginning_of_year.strftime("%Y-%m-%d")
      @end_date = @@time.prev_year.end_of_year.strftime("%Y-%m-%d")
    elsif @period == "4"
      @start_date = @@time.beginning_of_quarter.strftime("%Y-%m-%d")
      @end_date = @@time.end_of_quarter.strftime("%Y-%m-%d")
    elsif @period == "6"
      @start_date = @@time.prev_year.beginning_of_year.strftime("%Y-%m-%d")
      @end_date = @@time.prev_year.end_of_year.strftime("%Y-%m-%d")
    elsif @period == "7"
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    elsif @period ==  "8"
      @start_date = @@time.prev_year.beginning_of_year.strftime("%Y-%m-%d")
      @end_date = @@time.prev_year.end_of_year.strftime("%Y-%m-%d")
    elsif @period ==  "9"
      @prev_sunday = (@@time.to_date-@@time.wday)
      @start_date = (@prev_sunday-(7*7)).strftime("%Y-%m-%d")
      @end_date = (@prev_sunday+(1*7)).strftime("%Y-%m-%d")
    else
      @date = "Select Period"
    end

    if params[:partial_page] == "variances"
      variances
    else
      render :action => 'select_time_period.rjs'
    end
  end

  def find_real_estate_note
    @note = RealEstateProperty.find(params[:id])
  end
  def portfolio_assign
    @portfolio = @note.portfolio
  end
  def gross_rental_area_popup
    if params[:gross_rentable_area] && !params[:gross_rentable_area].blank?
      @rep.gross_rentable_area=params[:gross_rentable_area]
      @rep.save(false)
      gross_rentable_area= (!@rep.gross_rentable_area || @rep.gross_rentable_area ==0) ? 0 : @rep.gross_rentable_area
      no_of_units= (!@rep.no_of_units || @rep.no_of_units ==0) ? 0 : @rep.no_of_units
      if @rep.leasing_type == 'Commercial'
        cap_exp_head = 'Cap Exp'
      elsif @rep.leasing_type=="Multifamily" && find_accounting_system_type(3,@rep)
        cap_exp_head = 'Maint Exp'
      end
      responds_to_parent do
        render :update do |page|
          page << "Control.Modal.close();"
          page.assign 'grossRent',true
          page << "change_navigation_gross_rent('#{remote_property(@rep.accounting_system_type_id)}','#{cap_exp_head}','#{@rep.id}','#{(!@rep.gross_rentable_area || @rep.gross_rentable_area ==0) ? 0 : @rep.gross_rentable_area}','#{ (!@rep.no_of_units || @rep.no_of_units ==0) ? 0 : @rep.no_of_units}',#{@rep.portfolio_id},'#{@rep.id}');"
          page.call "performanceReviewCalls", params[:from],{"financial_sub"=> params[:financial_sub], "financial_subid"=>params[:financial_subid]},'undefined','per_sqft'
          page.call "flash_writter", "Gross Rental Area successfully updated"
        end
      end
    end
  end
  def no_of_units_popup
    if params[:no_of_units] && !params[:no_of_units].blank?
      @rep.no_of_units=params[:no_of_units]
      @rep.save(false)
      gross_rentable_area= (!@rep.gross_rentable_area || @rep.gross_rentable_area ==0) ? 0 : @rep.gross_rentable_area
      no_of_units= (!@rep.no_of_units || @rep.no_of_units ==0) ? 0 : @rep.no_of_units
      if @rep.leasing_type == 'Commercial'
        cap_exp_head = 'Cap Exp'
      elsif @rep.leasing_type=="Multifamily" && find_accounting_system_type(3,@rep)
        cap_exp_head = 'Maint Exp'
      end
      responds_to_parent do
        render :update do |page|
          page << "Control.Modal.close();"
          page.assign 'noOfUnits',true
          page << "change_navigation_gross_rent('#{remote_property(@rep.accounting_system_type_id)}','#{cap_exp_head}','#{@rep.id}','#{(!@rep.gross_rentable_area || @rep.gross_rentable_area ==0) ? 0 : @rep.gross_rentable_area}','#{ (!@rep.no_of_units || @rep.no_of_units ==0) ? 0 : @rep.no_of_units}',#{@rep.portfolio_id},'#{@rep.id}');"
          page.call "performanceReviewCalls", params[:from],{"financial_sub"=> params[:financial_sub], "financial_subid"=>params[:financial_subid]},'undefined','unit_calc'
          page.call "flash_writter", "Number of Units successfully updated"
        end
      end
    end
  end

  def find_rep_for_gross_units
     if session[:portfolio__id].present? && session[:property__id].blank?
      @rep = Portfolio.find_by_id(session[:portfolio__id])
      elsif session[:property__id].present? && session[:portfolio__id].blank?
    @rep=RealEstateProperty.find_real_estate_property(params[:id])
    end
  end

 def pdf
    months = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    @content_to_render = ""
    calc_for_financial_data_display
    if session[:portfolio__id].present? && session[:property__id].blank?
    @note = Portfolio.find_by_id(session[:portfolio__id])
    @note_name = @note.name if @note
    elsif session[:property__id].present? && session[:portfolio__id].blank?
    @note = RealEstateProperty.find_real_estate_property(params[:id])
    @note_name = @note.property_name if @note
    @property_address = @note.get_property_address(@note.address)
    @property_image = @note.try(:portfolio_image)
    end
    @pdf_convn_path = Rails.root.to_s+'/public'
    id = params[:id]
    @pdf = true # Strongly need becoz the all older render options(render :update for js...) turned off for rendering pdf
    partial_details = ["", "portfolio_partial", "physical details", "financial", "leases", "rent_roll_highlight", "capital_expenditure", "cash_and_receivables", "cash_and_receivables_for_receivables","variances","balance_sheet"]
   get_partial_titles(params[:partial_pages],@note_name)
   @content_to_render <<  "<div class=\"pdf_break_page\" style=\"float:left;width:100%;\"><div style=\"z-index:18900;margin-bottom: 0px;padding-bottom: 10px;border-bottom: none;\"><span style=\"font-size: 13px ! important; font-weight: bold; color: rgb(0, 0, 0) ! important;\"></span><div class=\"lebredcomsright\" ><div style=\"font-size: 13px ! important; font-weight: bold; color: rgb(0, 0, 0) ! important; line-height: 20px;padding-bottom: 10px;\"></div></div>"
    @content_to_render << render_to_string(:template=>"/lease/pdf_header.html.erb").gsub('href','vhref').gsub('onclick','vonclick')
    @content_to_render << "</div></div>"
    if !params[:tl_month].nil? and !params[:tl_month].blank? and params[:tl_period] != "9"
      @sel_option = months[params[:tl_month].to_i] + "-" + params[:tl_year]
    else
      if(!params[:tl_period].nil? and (params[:tl_period] =="4" || params[:tl_period] =="9" ))
        @sel_option = "YTD - #{Date.today.year}"
      elsif(!params[:tl_period].nil? and params[:tl_period] =="7")
        @sel_option = "#{params[:cur_month]} YTD - #{params[:cur_year]}" rescue "Month YTD"
      elsif params[:period] == "2" || params[:tl_period] == "2"
        @sel_option = find_quarterly_msg.gsub("Calculating actuals from", "").strip
      elsif !params[:tl_period].nil? and params[:tl_period] =="5"
        @sel_option = months[params[:tl_month].to_i] + "-" + params[:tl_year]
      elsif !params[:tl_period].nil? and params[:tl_period] =="6" || (params[:tl_period] =="3" || params[:period] =="3") || (!params[:tl_period].nil? and params[:tl_period] =="8")
        #year = find_selected_year(Date.today.prev_year)
        year = params[:tl_year]
        @sel_option = "#{year}"
      end
    end
    #Condition added and excluded variances details for year forecast as it is not required. The condition is a temporary fix.
    # 8 for Yearforecast and 9 for Variances tab
    params[:partial_pages] = ((params[:tl_period] == "8" || params[:period] == "8") && params[:partial_pages].split(',').include?("9")) ? params[:partial_pages].split(',') - ["9"] : params[:partial_pages].split(',')
    params[:partial_pages].each do |par|
      params[:partial_page] = partial_details[par.to_i]
      params[:id] = id
      if params[:partial_page] == 'leases'
        params[:start_date] = params[:tl_period] == "9" ? nil : params[:start_date]
        params[:tl_month] =  params[:tl_period] == "9" ? "" : params[:tl_month]
        params[:tl_period] = params[:tl_period] == "9" ? "4" :  params[:tl_period]
        lease
        lease_val = @timeline_lease.blank? ?  " " : " - #{@timeline_lease}"
        pdf_content_to_render("Leasing #{lease_val}","/properties/property_lease_performancePdf.html.erb")
      elsif params[:partial_page] == 'rent_roll_highlight'
        params[:start_date] = params[:tl_period] == "9" ? nil : params[:start_date]
        params[:tl_month] =  params[:tl_period] == "9" ? "" : params[:tl_month]
        params[:tl_period] = params[:tl_period] == "9" || params[:tl_period]  == "11" ? "4" :  params[:tl_period]
        rent_roll
        rent_val = @timeline_rent.blank? ?  " " : " - #{@timeline_rent}"
         pdf_content_to_render("Rent Roll #{rent_val}","/properties/rent_rollPdf.html.erb")
      elsif params[:partial_page] == 'capital_expenditure'
        params[:tl_period] = params[:tl_period]  == "11" ? "4" :  params[:tl_period]
        select_option_calc
        capital_expenditure
        @cap_exp_name = !find_accounting_system_type(3,@note) ? "Capital Expenditures" : "Maintenance Projects"
        pdf_content_to_render("#{@cap_exp_name} - #{@sel_option}","/performance_review_property/capital_expenditurePdf.html.erb")
      elsif params[:partial_page] == 'cash_and_receivables'
      if session[:portfolio__id].present? && session[:property__id].blank?
        @notes = RealEstateProperty.find_properties_by_portfolio_id(session[:portfolio__id])
        elsif session[:property__id].present? && session[:portfolio__id].blank?
        @portfolio = Portfolio.find_by_id(@note.portfolio_id)
        @notes = RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id)
      end
        select_option_calc
        cash_and_receivables
        pdf_content_to_render("Cash - #{@sel_option}","/performance_review_property/cash_and_receivablesPdf.html.erb")
      elsif params[:partial_page] == 'cash_and_receivables_for_receivables'
        params[:start_date] = params[:tl_period] == "9" ? nil : params[:start_date]
        params[:tl_month] =  params[:tl_period] == "9" ? "" : params[:tl_month]
        params[:tl_period] = params[:tl_period] == "9"||  params[:tl_period]  == "11"? "4" :  params[:tl_period]
        cash_and_receivables_for_receivables
        recv_val = @timeline_recv.blank? ?  " " : " - #{@timeline_recv}"
        pdf_content_to_render("Receivables #{recv_val}","/performance_review_property/cash_and_receivables_for_receivPdf.html.erb")
     elsif params[:partial_page] == 'portfolio_partial'
        if (find_accounting_system_type(3,@note ) || find_accounting_system_type(4,@note)) && params[:period] == "9" || params[:tl_period] == "9"
          sel_option_weekly = params[:start_date] ? params[:start_date].to_date.strftime("%d %b %Y") : (Time.now.to_date-Time.now.wday).strftime("%d %b %Y")
          prev_sunday = (Time.now.to_date-Time.now.wday).strftime("%Y-%m-%d")
          @prev_sunday = Time.now.to_date-Time.now.wday
          params[:port_to_prop]='true'
          calculate_property_weekly_display_data(prev_sunday) unless params[:start_date]
          calculate_property_weekly_display_data if params[:start_date]
          pdf_content_to_render("Weekly Display - #{sel_option_weekly}","/performance_review_property/weeklyPdf.html.erb")
        else
          tl_month,tl_year =  load_instance_var_note
          common_for_wres_swig(tl_month,tl_year,"for_notes")
          pdf_content_to_render("Summary - #{@sel_option}","/performance_review_property/summaryPdf.html.erb")
        end
      elsif params[:partial_page] == 'physical details'
        id = params[:id]
        @note = RealEstateProperty.find_real_estate_property(id)
        @portfolio = Portfolio.find_by_id(@note.portfolio_id)
        @notes = RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id)
        @property = RealEstateProperty.find_real_estate_property(id)
        @address = @note.get_property_address(@note.address)
        #  "#{@property.address.txt.gsub(".",",").strip.to_s},#{@property.city},#{@property.province}" if @property.present? && @property.address.present?
        @folder = Folder.find_by_portfolio_id_and_real_estate_property_id_and_parent_id_and_is_master(@portfolio.id,@property.id,0,0) if @property && @portfolio
        pdf_content_to_render("Physical Details",'/physical_details/property_view.html.erb')
      elsif params[:partial_page] == 'variances'
        params[:start_date] = params[:tl_period] == "9" ? nil : params[:start_date]
        params[:tl_month] =  params[:tl_period] == "9" ? "" : params[:tl_month]
        params[:tl_period] = params[:tl_period] == "9"  ||  params[:tl_period] == "2" || params[:tl_period]  == "11" ? "4" :  params[:tl_period]
        variances
        sel_option = (((params[:tl_period] == "4" || params[:period] == "4") && (params[:tl_month].nil? || params[:tl_month].blank?)) || params[:tl_period] == "2" || params[:period] == "2") ? "YTD - #{Date.today.year}" : @sel_option
        #~ if remote_property(@note.accounting_system_type_id)
          if (params[:tl_period] == "7" || params[:period] == "7")
            params[:month] = months.index(params[:cur_month])
          elsif (params[:tl_period] == "4" || params[:period] == "4")
            params[:month] = (params[:tl_month].nil? || params[:tl_month].blank?) ? @financial_month : params[:tl_month]
          else
            params[:month] = params[:tl_month]
          end
          variances_display_for_remote_prop
        #~ else
          #~ if @variance_task_document  ||  @without_variance_task_document
            #~ params[:document_id] = @variance_task_document ? @variance_task_document.id : @without_variance_task_document.id
            #~ params[:note_id] = params[:id]
            #~ if (params[:tl_period] == "7" || params[:period] == "7")
              #~ params[:month] = months.index(params[:cur_month])
            #~ elsif (params[:tl_period] == "4" || params[:period] == "4")
              #~ params[:month] = (params[:tl_month].nil? || params[:tl_month].blank?) ? @financial_month : params[:tl_month]
            #~ elsif params[:tl_period] == "3" ||  params[:period] == "3" || params[:tl_period] == "6" || params[:period] == "3" || params[:tl_period] == "8" || params[:period] == "8"
              #~ params[:month] = 12
            #~ else
              #~ params[:month] = params[:tl_month]
            #~ end
            #~ exp_comment_display
          #~ end
        #~ end
         pdf_content_to_render("Variances -  #{sel_option}",'/properties/variancesPdf.html.erb')
     elsif  params[:partial_page] == 'financial'
        params[:start_date] = params[:tl_period] == "9" || params[:tl_period] == "2"   ? nil : params[:start_date]
        params[:tl_month] =  params[:tl_period] == "9" ? "" : params[:tl_month]
        params[:tl_period] = params[:tl_period] == "9" ? "4" :  params[:tl_period]
        common_financial_wres_swig(params,"swig")
        pdf_content_to_render("Operating Statement - #{@sel_option}",'/properties/sendFinancialPdf.html.erb')
      elsif params[:partial_page] == 'balance_sheet'
        balance_sheet
        pdf_content_to_render("Balance Sheet",'/properties/balancesheetPdf.html.erb')
      end
    end
    headers["Content-Type"] = "application/octet-stream"
    headers["Content-Disposition"] = "attachment; filename=\"#{@note_name}\""
    render :pdf => "#{@note_name}",:layout => '/layouts/_user_pdf.html.erb', :template=>'/performance_review_property/all_tabs_Pdf.html.erb', :footer => {:left=>'[page]', :right =>"Powered by AMP", :font_size => 7},:margin=>{:top=>5, :bottom=>10, :left=>10, :right=>10},:page_size=>'A4'
  end

  def pdf_content_to_render(time_line_msg,partial)
       logo_img,company_name =  find_logo_and_company_name
     @content_to_render <<  "<div class=\"pdf_break_page\" style=\"float:left;margin-top:7px;\"><div style=\"z-index:18900;margin-bottom: 0px;padding-bottom: 10px;border-bottom: none;\"><div id=\"page\" style=\"margin-left: 50px;\"> <img src=\"#{ Rails.root}/public/images/header-inner-bg.png\" style=\"position:absolute; top:0px; height:94px; width:100%; \"/> <div id=\"header-inner\"><div align=\"center\" style=\"font-family: Arial,Helvetica,sans-serif; padding: 46px 0pt 0pt;\"><div style=\"font-size: 14px; padding-bottom: 5px; font-weight: bold;\">#{@note_name}</div><div>#{time_line_msg}</div><div style=\"float: right; padding-right: 15px; font-size: 11px; margin-top: -14px;\">#{APP_CONFIG[:main_url]}</div></div><div class=\"logoDiv-inner\"><img align=\"left\" src=\"#{@pdf_convn_path}#{logo_img}\"  width=\"73\" height=\"68\" /><div class=\"company-name\">#{company_name}</div></div></div></div>"
        @content_to_render << "<div style=\"margin-left:50px;margin-top:17px;\">"
        if params[:partial_page] == 'physical details'
        @content_to_render << render_to_string(:partial => "/physical_details/property_view").gsub('href','vhref').gsub('onclick','vonclick')
        else
        @content_to_render << render_to_string(:template=>"#{partial}").gsub('href','vhref').gsub('onclick','vonclick')
        end
        @content_to_render << "</div></div></div>"
end



  def export_pdf
    if session[:portfolio__id].present? && session[:property__id].blank?
      @note = Portfolio.find_by_id(params[:id])
    elsif session[:property__id].present? && session[:portfolio__id].blank?
        @note = RealEstateProperty.find_real_estate_property(params[:id]) if !@note
    end
  end

  def exp_comment_display
    session[:comments],session[:cashflow_explanation_comments],session[:capital_explanation_comments] = {},{},{}
    self.collection_exp_comments[current_user.id] = Hash.new
    @item= @document = Document.find_by_id(params[:document_id])
    month_details = ['','january','february','march','april','may','june','july','august','september','october','november','december']
    @month_option = month_details[params[:month].to_i]
    parent_fol_name = view_context.find_name_of_the_parents_parent(@document.folder.parent_id)
    @expln_req_props_cash= view_context.explanation_required_property(@document.real_estate_property, @month_option, parent_fol_name)
    @expln_req_props_ytd_cash = view_context.explanation_required_property_ytd(@document.real_estate_property, @month_option, parent_fol_name)
    @expln_req_props_cap_exp = view_context.explanation_required_expenditures(@document.real_estate_property, params[:month].to_i, parent_fol_name)
    @expln_req_props_ytd_cap_exp= view_context.explanation_required_expenditures_ytd(@document.real_estate_property, params[:month].to_i, parent_fol_name)
    unless @pdf
      render :update do |page|
        page << "detect_comment_call=true;" # this setup is used for showing task_comments and documents_comments else only doc is shown.
        if params[:from_performance_review] == "true"
          page << "jQuery('.subheaderwarpper').show();"
        end
        page << "if(!jQuery('.subheaderwarpper').is(':visible')){jQuery('.subheaderwarpper').show();}else{}"
        page << "jQuery('#time_line_selector').show();"
        page << "jQuery('#yearforecast').hide();"
        page << "jQuery('#quarterly').hide();"
        page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Variances</div>');"
        page.replace_html "portfolio_overview_property_graph", :partial=>'/performance_review_property/exp_comment_display',:locals => {:document_collection =>@document,:task_collection =>@task,:item_collection =>@item,:expln_req_props_ytd_collection => @expln_req_props_ytd_cash,:expln_req_props_collection => @expln_req_props_cash,:expln_req_props_cap_collection=> @expln_req_props_cap_exp,:expln_req_props_cap_ytd=>@expln_req_props_ytd_cap_exp,:item_collection => @item,:month_option => @month_option,
          :note_collection=> @note}
        page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Variances</div>');"
        page.call "highlight_explanation", "#{params[:highlight_id]}","#{params[:highlight_period]}" if !params[:highlight_id].nil?
      end
    end
  end

 def notification_to_prop_users
   # if remote_property(@note.accounting_system_type_id)
      note_id = params[:id]
      find_user_for_remote(note_id)
    #~ else
    #~ doc_id = params[:id]
    #~ find_prop_user(doc_id)
    #~ end
    render :partial =>"/performance_review_property/notify_property_user",:locals=>{:note_collection=>@note}
  end

  def send_mail_to_prop_users
    @note = RealEstateProperty.find_real_estate_property(params[:id])
    property_id = @note.id
    portfolio_id = @note.portfolio_id
    responds_to_parent do
      render :update  do |page|
        if params[:selected_users] && !params[:selected_users].empty?
          params[:selected_users].keys.each do |users|
            property_users =User.find_by_id(users)
            user_mails= property_users.email
            prop_user = property_users.name
            if params[:textarea] && !params[:textarea].empty?
              @message = params[:textarea]
            end
            UserMailer.variances_display_mail(user_mails,@message,current_user,prop_user,portfolio_id,property_id).deliver
          end
          page.call "flash_writter","Notification has been sent to the selected Property User(s)"
          page << "Control.Modal.close();"
        else
          page.call "flash_writter", "Please select Property User(s)"
        end
      end
    end
  end

  def select_option_calc
    params[:start_date] = params[:tl_period] == "9" ? nil : params[:start_date]
    params[:tl_month] =  params[:tl_period] == "9" ? "" : params[:tl_month]
    params[:tl_period] = params[:tl_period] == "9" ? "4" :  params[:tl_period]
  end


  def variances_display_for_remote_prop
    session[:comments],session[:cashflow_explanation_comments],session[:capital_explanation_comments] = {},{},{}
    self.collection_exp_comments[current_user.id] = Hash.new
    month_details = ['','january','february','march','april','may','june','july','august','september','october','november','december']
    ## fixed for remote property crash in print pdf for year
    if params[:period] == '6' || params[:tl_period] == '6'|| params[:tl_period] == '3' || params[:period] == '3'
      @month_option = month_details[12]
      params[:month] = 12
    else
      @month_option = month_details[params[:month].to_i]
    end
    params[:tl_month] = params[:month].to_i  if params[:period] != '4' && params[:tl_period] != '4'&& params[:tl_period] != '7' && params[:period] != '7'
    @year =   params[:tl_year]
    @note = RealEstateProperty.find_real_estate_property(params[:id])
    @expln_req_props_cash= view_context.explanation_required_property(@note, @month_option, @year)
    @expln_req_props_ytd_cash = view_context.explanation_required_property_ytd(@note, @month_option,@year)
    @expln_req_props_cap_exp = view_context.explanation_required_expenditures(@note, params[:month].to_i, @year)
    @expln_req_props_ytd_cap_exp= view_context.explanation_required_expenditures_ytd(@note, params[:month].to_i, @year)
      unless @pdf
      render :update do |page|
        if params[:from_performance_review] == "true"
          page << "jQuery('.subheaderwarpper').show();"
        end
        page << "if(!jQuery('.subheaderwarpper').is(':visible')){jQuery('.subheaderwarpper').show();}else{}"
        page << "jQuery('#time_line_selector').show();"
        page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Variances</div>');"
        #page << "jQuery('#monthyear').show();"
        page << "jQuery('#quarterly').hide();"
        if @note && remote_property(@note.accounting_system_type_id)
        page.replace_html "portfolio_overview_property_graph", :partial=>'/properties/variance_for_remote_property',:locals => {:expln_req_props_ytd_cash =>  @expln_req_props_ytd_cash,:expln_req_props_cash => @expln_req_props_cash,:note_collection=> @note,:month_options=>@month_option}
        else
          page.replace_html "portfolio_overview_property_graph", :partial=>'/performance_review_property/exp_comment_display',:locals => {:expln_req_props_ytd_collection => @expln_req_props_ytd_cash,:expln_req_props_collection => @expln_req_props_cash,:expln_req_props_cap_collection=> @expln_req_props_cap_exp,:expln_req_props_cap_ytd=>@expln_req_props_ytd_cap_exp,:month_option => @month_option,
          :note_collection=> @note}
          end
        page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Variances</div>');"
          if params[:from_assign_task] == "cap_exp"
            page.call "highlight_comment", "#{params[:highlight_id]}","#{params[:highlight_period]}" if !params[:highlight_id].nil?
        else
           page.call "highlight_explanation", "#{params[:highlight_id]}","#{params[:highlight_period]}" if !params[:highlight_id].nil?
          end
      end
      end
  end

  private

  def get_partial_titles(partials,property_name)
    @partial_pages = []
    find_selected_year_and_option
    option = @option
    if partials.present?
      partials = partials.split(",")
      partials.each do |partial|
        result = case partial
          when "1"
          if (params[:period] == "9" || params[:tl_period] == "9")
             sel_option = params[:start_date] ? params[:start_date].to_date.strftime("%d %b %Y") : (Time.now.to_date-Time.now.wday).strftime("%d %b %Y")
            "Weekly Display for #{property_name} - #{sel_option}"
          else
            "Summary for #{property_name} - #{option}"
          end
          when "2"
        "Physical Details for #{property_name}"
          when "3"
        "Operating Statement for #{property_name} - #{option}"
          when "4"
        "Leasing for #{property_name} - Jan - #{Date.today.strftime("%b")} #{Date.today.strftime("%Y")}"
          when "9"
        "Variances for #{property_name} - #{option}"
          when "5"
        "Rent Roll for #{property_name} - As of #{Date.today.strftime("%b")} #{Date.today.strftime("%Y")}"
          when "6"
        "Capital Expenditures for #{property_name} - #{option}"
          when "8"
          find_redmonth_start_for_recv(find_selected_year(Date.today.year))
          month = @month_red_start
          if month == 0
            "Receivables for #{property_name} "
          else
              months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
              timeline_msg =  (month && month==0) ? "" :"#{months[month - 13]} #{@year}"
            "Receivables for #{property_name} - As of #{timeline_msg}"
          end
          when "7"
        "Cash for #{property_name} - #{option}"
          when "10"
          "Balance Sheet for #{property_name} - Jan - #{Date.today.strftime("%b")} #{Date.today.strftime("%Y")}"
        end
        @partial_pages << result
      end
    end
    @partial_pages
  end

  def change_session_value
  if session[:property__id].present? && session[:portfolio__id].blank?
     session[:portfolio__id] = ""
     session[:property__id] = params[:property_id] || params[:id] || params[:nid]  || session[:property__id]
    elsif session[:portfolio__id].present? && session[:property__id].blank?
      session[:portfolio__id] = params[:portfolio_id] || session[:portfolio__id]
      session[:property__id] = ""
    end
  end

  def property_id
    if request.xhr? && params[:id].present?
      params[:id] = params[:id]
    else
      params[:id] = (session[:property__id].present?) ? session[:property__id] : params[:id]
    end
  end

def check_property_access

    id = params[:property_id].present? ? params[:property_id] : params[:nid].present? ? params[:nid] : @property.present? ? @property.try(:id) : @note.present? ? @note.id : ""

    if id.present?
      properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(current_user.id,prop_folder=true)
      @property_ids = properties.present? ? properties.map(&:id) : []
      unless @property_ids.include?(id.to_i)
        last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
        if last_portfolio.present? && first_property.present?
          redirect_to financial_info_path(last_portfolio.try(:id), first_property.try(:id),:access=>'true')
        elsif properties.present?
          redirect_to financial_info_path(properties.last.try(:portfolio_id), properties.last.try(:id),:access=>'true')
        else
          redirect_to notify_admin_path(:from_session=> true)
        end
      end
    end
  end

  def find_prop_id
       @note = RealEstateProperty.find_real_estate_property(params[:note_id])
  end

end
