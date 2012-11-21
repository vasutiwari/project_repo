module PerformanceReviewPropertyHelper
  # Hash formation in listing details in Performance review lease page
  def lease_details(month=nil, year=nil) # If you do any changes here, please do the same in dashboard_lease_details method
    ##removed code related to period for time line selector removal
    if is_multifamily(@note)
      @month,@explanation = month,true
      year = PropertyOccupancySummary.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
      year = year.compact.empty? ? nil : year[0].year
      os= PropertyOccupancySummary.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,year,get_month(year)],:order => "month desc",:limit =>1)
    elsif is_commercial(@note)
      @month,@explanation = month,true
      find_occupancy_values
      year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
      year = year.compact.empty? ? nil : year[0].year
      os= CommercialLeaseOccupancy.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,year,get_month(year)],:order => "month desc",:limit =>1)
    end
    @prop_occup_summary = os if !os.nil? and !os.empty?
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, @resource])
    @actual = @time_line_actual
    lease_details_calculation
  end

  #lease details for wres
  def wres_lease_details(month=nil,year=nil)
    @month,@year,@explanation = month,year,true
    if !month.nil?
      month,year = month.to_i,year.to_i
      if (params[:tl_period] == "7" || params[:period] == "7") && params[:cur_month]
        @prop_occup_summary=PropertyOccupancySummary.find(:all, :conditions=>['month <= ? and year = ? and real_estate_property_id = ?', month, year, @note.id]) if !@note.nil? && !month.nil? && !year.nil?
      else
        @prop_occup_summary=PropertyOccupancySummary.find(:all, :conditions=>['month = ? and year = ? and real_estate_property_id = ?', month, year, @note.id]) if !@note.nil? && !month.nil? && !year.nil?
      end
      @comments = LeasesExplanation.find(:all, :conditions =>["month = ? and year = ? and real_estate_property_id = ?",month, year, @note.id]).collect{|s| [s.occupancy_type,s.explanation]} if !@note.nil? && !month.nil? && !year.nil?
    else
      year = Date.today.year if year.nil?
      os= PropertyOccupancySummary.find(:all,:conditions => ["year=? and real_estate_property_id=? and month <= ?",year,@note.id,Date.today.prev_month.month],:order => "month desc",:limit =>1)
      @prop_occup_summary = os if !os.nil? and !os.empty?
    end
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, @resource])
    @actual = @time_line_actual
    wres_lease_details_calculation
  end
  # Hash formation in listing details in Performance review lease sub page
  def lease_sub_details(month, year, occupancy_type)
    term_cdn = ""
    sort = " "
    params[:sort].blank? ? (params[:sort] = "pl.lease_end_date") : ""
    if params[:sort]
      if params[:sort].match(/time_diff/)
        term_cdn = " if( pl.lease_end_date - CURDATE() < 0,0,pl.lease_end_date - CURDATE()) as time_diff, "
        sort = "ORDER BY "+params[:sort]+","+"pl.tenant asc"
      else
        sort = !params[:sort].nil? ? "ORDER BY "+params[:sort] : ""
      end
    end
    ##removed code related to period for time line selector removal
    @suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
    year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and  year <= ?',@suites,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
    year = year.compact.empty? ? nil : year[0].year
    month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ?',@suites,year,get_month(year)],:select=>"month").map(&:month).max if !@suites.blank?
    @month = month

    if  occupancy_type == 'expirations'
      expiration_qry = "pl.occupancy_type = 'expirations' AND pl.month = '#{Date.today.month}' AND pl.year = #{Date.today.year.to_i}  AND pl.lease_end_date between '#{Date.today.year}-01-01' and '#{Date.today.year}-#{Date.today.month}-31'  AND pl.month = '#{month}' AND pl.year = #{year.to_i} AND pl.real_estate_property_id = #{@note.id}"
    elsif occupancy_type == 'new'
      expiration_qry = "((pl.occupancy_type = 'new' or pl.occupancy_type ='current') AND pl.month = '#{Date.today.month}' AND pl.year = #{Date.today.year.to_i} AND pl.lease_start_date between '#{Date.today.year}-01-01' and '#{Date.today.year}-#{Date.today.month}-31'  AND pl.month = '#{month}' AND pl.year = #{year.to_i} AND pl.real_estate_property_id = #{@note.id})"
    else
      expiration_qry = "pl.occupancy_type = '#{occupancy_type}' AND pl.month = '#{month}' AND pl.year = #{year.to_i} AND pl.real_estate_property_id = #{@note.id}"
    end

    @sub_leases = LeaseRentRoll.find_by_sql("SELECT pl.id,pl.occupancy_type,pl.sqft as rented_area,ps.suite_no as suite_number,ps.space_type as space_type,pl.tenant,#{term_cdn} pl.base_rent_monthly_amount as base_rent, pl.effective_rate,pl.lease_end_date as end_date,pl.tis_amount as tenant_improvements, pl.lcs_amount as leasing_commissions,pl.security_deposit_amount FROM `lease_rent_rolls` pl INNER JOIN suites ps ON pl.suite_id = ps.id  WHERE (#{expiration_qry}) #{sort};") if !month.nil? && !year.nil? && !occupancy_type.nil?
    @year = year
    @sub_leases = @sub_leases.paginate :page => (params[:page]), :per_page => 30 if !@sub_leases.blank?
  end

  # Method to calculate the total area
  def get_total_area(lease_areas)
    total_area = 0
    lease_areas.each do |lease_area|
      total_area +=lease_area.to_i if lease_area
    end
    return total_area
  end

  # Method to get the remaining term details
  def get_term_remaining(end_date)
    team_remaining = ((end_date - Date.today)/30).round if !end_date.nil?
    return team_remaining.to_s+" Months" if !team_remaining.nil? && team_remaining != 1 && team_remaining > 0
    return (end_date - Date.today).to_i > 0 ? "1 Month" : "-" if (!team_remaining.nil?) && (team_remaining == 0 || team_remaining == 1)
    "-"
  end

  # Weighted average calculation for the lease sub page
  def get_weighted_data(data1,data2)
    total = 0
    if data1.length == data2.length
      for i in 0..data1.length
        total += data1[i].to_f * data2[i].to_f if !data1[i].nil? && !data2[i].nil?
      end
      return (total/get_total_area(data1)).to_f
    end
  end

  # Hash formation for the calculation in the occupancy
  def form_hash_of_data_for_occupancy(actuals,budget)
    val ={:actuals =>actuals,:budget =>budget}
    variant = val[:budget].to_f.abs-val[:actuals].to_f.abs
    percent = variant*100/val[:budget].to_f.abs rescue ZeroDivisionError
    percent = ( val[:actuals].to_f == 0 ? 0 : -100 ) if  val[:budget].to_f==0
    percent=0.0 if percent.to_f.nan?
    val[:percent],val[:variant],val[:status] = percent,variant,true
    return val
  end

  #This method is used to calculate debt service for a particular month
  def debt_service_for_month
    @explanation = true
    @debt_services = PropertyDebtSummary.find(:all,:conditions => ["real_estate_property_id =? and month =? and year =? and (LOWER(category) = ? or LOWER(category) =? or LOWER(category =?))",@note.id, @tl_month, @tl_year, 'maturity', 'loan amount', 'loan balance'], :select=>['category, description,id'],:group=>'category')
  end

  #This method is used to calculate debt service for Year To Date
  def debt_service_for_ytd
    @debt_services = []
    prev_month = PropertyDebtSummary.find(:first,:conditions =>["real_estate_property_id =? and year =?",@note.id,@tl_year], :order=> "month desc")
    if prev_month
      @debt_services << PropertyDebtSummary.find(:first,:conditions => ["real_estate_property_id =? and month =? and year =? and (LOWER(category) = ?)",@note.id, prev_month.month, @tl_year, 'maturity'], :select=>['category,description,id'])
      @debt_services << PropertyDebtSummary.find(:first,:conditions => ["real_estate_property_id =? and month =? and year =? and (LOWER(category) = ? )",@note.id, prev_month.month, @tl_year, 'loan amount'], :select=>['category,description,id'])
      @debt_services << PropertyDebtSummary.find(:first,:conditions => ["real_estate_property_id =? and month =? and year =? and (LOWER(category) = ? )",@note.id, prev_month.month, @tl_year,'loan balance'], :select=>['category,description,id'])
    end
  end

  #This method is used to calculate debt service for Last Year
  def debt_service_for_prev_year
    year_de = Date.today.prev_year.year
    prev_month = PropertyDebtSummary.find(:first,:conditions =>["real_estate_property_id =? and year =?",@note.id,year_de], :order=> "month desc")
    @debt_services = PropertyDebtSummary.find(:all,:conditions => ["real_estate_property_id =? and month =? and year =? and (LOWER(category) = ? or LOWER(category) =? or LOWER(category =?))",@note.id, prev_month.month, year_de, 'maturity', 'loan amount', 'loan balance'], :select=>['category, description,id'])  if prev_month
  end

  # Capital expenditure calculation for the month in performance review page
  def capital_expenditure_month(month=nil,year=nil)
    capital_expenditure_sub_method('month')
  end

  # Capital expenditure calculation for the year to date in performance review page
  def capital_expenditure_year
    capital_expenditure_sub_method('year')
  end

  # Capital expenditure calculation for the month to year in performance review page
  def capital_expenditure_month_year
    capital_expenditure_sub_method('month_year')
  end

  # Capital expenditure calculation for the last year in performance review page
  def capital_expenditure_prev_year
    capital_expenditure_sub_method('prev_year')
  end

  # Performance review financial sub page Link formation for the Text in the display
  def  summary_financial_review(heading,rec_id = nil)
    len = 22
    subpages_in_financial_review_sub_method('swig',heading,rec_id,len)
  end

  def subpages_in_financial_review(heading,rec_id = nil)
    subpages_in_financial_review_sub_method('swig',heading,rec_id)
  end

  def wres_subpages_in_financial_expenses(heading,rec_id = nil)
    subpages_in_financial_review_sub_method('wres',heading,rec_id = nil)
  end

  # Performance review financial sub page for month calculation
  def calculate_the_financial_sub_graph_for_month(month,year,from_properties_tab = nil)
    @month,@ytd = month, []
    @ytd << "IFNULL(f."+Date::MONTHNAMES[month.to_i].downcase+",0)"
    find_out_asset_details(params,year,from_properties_tab)
    bread_crumb = breadcrumb_in_financial(params[:financial_sub],params[:financial_subid])
  end

  # Performance review financial sub page for year-to-date calculation
  def calculate_the_financial_sub_graph(year=nil,from_properties_tab = nil)
    calc_for_financial_data_display
    year_to_date= @financial_month
    @ytd= []

    if(params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
      quarter_months =  [12,11,10,9,8,7,6,5,4,3,2,1,12,11,10]
      for quarter_month in quarter_months[params[:quarter_end_month].to_i]..quarter_months[params[:quarter_end_month].to_i] + 2
        m= quarter_months[quarter_month]
        @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
      end
    elsif (params[:period] == "11" || params[:tl_period] == "11")
        @ytd << "IFNULL(f."+Date::MONTHNAMES[@financial_month.to_i].downcase+",0)"
    else
      for m in 1..year_to_date
        @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
      end
    end
    find_out_asset_details(params,year,from_properties_tab)
  end
  # Performance review financial sub page for month_ytd calculation
  def calculate_the_financial_sub_graph_for_month_ytd(year=nil,month=nil,from_properties_tab = nil)
    year_to_date= month
    @ytd= []
    for m in 1..year_to_date
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
    end
    find_out_asset_details(params,year,from_properties_tab)
  end
  # Performance review financial sub page for year-to-date calculation
  def calculate_the_financial_sub_graph_month_year(month=nil,year=nil)
    year_to_date= month if month
    @ytd= []
    for m in 1..year_to_date
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
    end
    find_out_asset_details(params,year)
  end

  # Performance review financial sub page for last year calculation
  def calculate_the_financial_sub_graph_for_prev_year(year=nil,from_properties_tab = nil)
    @ytd= []
    for m in 1..12
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
    end
    params[:financial_sub] = params[:financial_sub].gsub("?","\'") if params[:financial_sub]
    if params[:financial_sub] and params[:financial_sub] == "Operating Expenses"
      if @note && (find_accounting_system_type(1,@note) || find_accounting_system_type(2,@note))
        actual_pcb_type,budget_pcb_type = find_pcb_type
        qry = "select  Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(child_id) as Record_id from (SELECT  a.title as Title, f.pcb_type, #{@ytd.join("+")}  as actuals, 0 as budget,a.id as child_id FROM `income_and_cash_flow_details` a  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.title IN ('recoverable expenses detail','non-recoverable expenses detail') AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION   SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")}  as budget,0 as child_id FROM `income_and_cash_flow_details` a  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.title IN ('recoverable expenses detail','non-recoverable expenses detail') AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'    ) xyz group by  Title"
        @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      elsif  @note && (find_accounting_system_type(3,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note) || remote_property(@note.accounting_system_type_id))
        if !params[:financial_subid].blank?
          actual_pcb_type,budget_pcb_type = find_pcb_type
          qry = "select  Title, sum(actuals) as Actuals, sum(budget) as Budget, sum(child_id) as Record_id from (SELECT  a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget, a.id as child_id FROM `income_and_cash_flow_details` a   inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.parent_id = #{params[:financial_subid]} AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' AND a.title NOT IN ('Operating Expenses','operating expenses','net operating income','net income before depreciation','operating income','Other Income And Expense','expenses')  UNION SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as child_id FROM `income_and_cash_flow_details` a    inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.parent_id  = #{params[:financial_subid]} AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' AND a.title NOT IN ('operating expenses','net operating income','net income before depreciation','operating income','Other Income And Expense','expenses','Operating Expenses') ) xyz group by Title"
          @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
        else
          @using_sub_id = false
          qry = get_query_for_financial_sub_page(params[:financial_sub],year,false,from_properties_tab)
          @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
        end
      end
    elsif !params[:financial_subid].blank?
      @using_sub_id = true
      qry = get_query_for_financial_sub_page(params[:financial_subid],year,false,from_properties_tab)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      if params[:action].include?("financial_subpage") || (params[:partial_page] == "financial_subpage") || params[:action].include?("balace_sheet_sub_page") || (params[:partial_page] == "balace_sheet_sub_page")
        total_qry = get_query_for_financial_sub_page(params[:financial_subid],year,true,from_properties_tab)
        @total = IncomeAndCashFlowDetail.find_by_sql(total_qry)
      end
    else
      @using_sub_id = false
      qry = get_query_for_financial_sub_page(params[:financial_sub],year,false,from_properties_tab)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    end
    @explanation = true
  end

  #Performance review financial subpage query for the calculation
  def get_query_for_financial_sub_page(parent,year,find_total,from_properties_tab = nil)
    if params[:partial_page] == 'cash_and_receivables'  &&  remote_property(@note.accounting_system_type_id) || remote_property(@note.accounting_system_type_id) && (params[:partial_page] == 'portfolio_partial' || (params[:controller] == "properties" && params[:action] == "show"))
      adjustments =  AccountTree.find(:all,:conditions=>["title in ('#{params[:financial_sub]}')"]).map(&:id).join(',')
      adjustment_sub_items_account_num =  AccountTree.find(:all,:conditions=>["parent_id in (#{adjustments})"]).map(&:account_num).join(',') if adjustments
      cash_items = IncomeAndCashFlowDetail.find_by_sql("select * from income_and_cash_flow_details where account_code in (#{adjustment_sub_items_account_num})").map(&:id).join(',')
      @cash_items_titles = IncomeAndCashFlowDetail.find_by_sql("select * from income_and_cash_flow_details where account_code in (#{adjustment_sub_items_account_num})").map(&:title).join(',')
      return"select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(child_id) as Record_id,inormal_balance as InormalBalance from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget , a.id as child_id,a.inormalbalance as inormal_balance FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.id IN (#{cash_items}) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget,0 as child_id,a.inormalbalance as inormal_balance FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.id IN (#{cash_items}) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"
    elsif @balance_sheet && @using_sub_id
      string =  find_total == true ? "a.id" : "a.parent_id"
      find_last_updated_items(from_properties_tab)
      return "select  Title, sum(actuals) as Actuals, sum(budget) as Budget, child_id as Record_id from (SELECT  a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget, a.id as child_id FROM `income_and_cash_flow_details` a   inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} = #{parent} AND (f.pcb_type = 'c' or f.pcb_type = 'p') AND a.year=#{@last_record_year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as child_id FROM `income_and_cash_flow_details` a    inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{parent} AND f.pcb_type IN ('b') AND a.year=#{@last_record_year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Title"
    elsif  @using_sub_id
      actual_pcb_type,budget_pcb_type = find_pcb_type
      string =  find_total == true ? "a.id" : "a.parent_id"
      return "select  Title, sum(actuals) as Actuals, sum(budget) as Budget, sum(child_id) as Record_id from (SELECT  a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget, a.id as child_id FROM `income_and_cash_flow_details` a   inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} = #{parent} AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as child_id FROM `income_and_cash_flow_details` a    inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{parent} AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Title"
    else
      actual_pcb_type,budget_pcb_type = find_pcb_type
      return "select  Title, sum(actuals) as Actuals, sum(budget) as Budget, sum(child_id) as Record_id from (SELECT  a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget, a.id as child_id FROM `income_and_cash_flow_details` a   inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.title =\"#{parent}\" AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as child_id FROM `income_and_cash_flow_details` a    inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.title =\"#{parent}\" AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Title"
    end
  end

  # Breadcrumb link display for the performance review financial subgraph
  def breadcrumb_in_financial(title,ids)
    arr = []
    a = {"income detail" => "Operating Revenue"}
    arr_heading = ["income details","net operating income","capital expenditures"]
    heading_display_restriction =     (@balance_sheet && params[:financial_sub] == 'transactions' && remote_property(@note.accounting_system_type_id)) ? 3 :  (@balance_sheet ? 2 : ((@note && (find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note) )) ? 1 : (remote_property(@note.accounting_system_type_id) ? 4 : 0)))
    bread_title = @balance_sheet  ? "Balance Sheet" : "Operating Statement"
    bread_partial = @balance_sheet  ? "balance_sheet" : "financial"
    bread_sub_partial =  @balance_sheet  ? "balance_sheet_sub_page" : "financial_subpage"
    if ids.nil? || ids.blank?
      base = "<div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span><a href=\"#\" onclick=\"performanceReviewCalls(\\'#{bread_partial}\\',{});return false;\">#{bread_title}</a><img width=\"10\" height=\"9\" src=\"/images/eventsicon2.png\">&nbsp;</div><div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Operating Expenses &nbsp;</div>"
    else
      income=IncomeAndCashFlowDetail.find_by_id(ids)
      while(income and  !income.parent_id.nil?)
        arr << [income.title,income.id]
        income = IncomeAndCashFlowDetail.find_by_id(income.parent_id)
      end
      if income
        arr << [income.title,income.id] if arr.empty?
      else
        arr = []
      end
      base = "<div class=\"executivesubheadcol\" style=\" padding:22px 0px 0px;\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span><a href=\"#\" onclick=\"performanceReviewCalls(\\'#{bread_partial}\\',{});return false;\">#{bread_title}</a><img width=\"10\" height=\"9\" src=\"/images/eventsicon2.png\">&nbsp;</div>"
      j=0
      if !arr.empty?
        for ar2 in arr.reverse
          if ar2[0] == "non-recoverable expenses detail" or  ar2[0] == "recoverable expenses detail"
            j +=1
          end
        end
        title_array = []
        arr << ["Deals",0] if params[:financial_sub] == 'transactions' && remote_property(@note.accounting_system_type_id)
        for ar1 in arr.reverse
          last_element = arr.first
          heading =   a[ar1[0]] ? a[ar1[0]] : ar1[0]
          title_array << heading.gsub("'","").gsub(/\sdetail/,'').titleize
          if heading !="non-recoverable expenses detail" && heading !="recoverable expenses detail" && heading.downcase !="recoverable (or) variable" && heading.downcase != 'non recoverable' && heading.downcase != "variable operating exp"
            if ar1[1] == last_element[1]
              item_disabled = params[:financial_sub] == 'transactions' && remote_property(@note.accounting_system_type_id) ? "#{heading.gsub("'","").gsub(/\sdetail/,'').titleize} - Deals" : "#{heading.gsub("'","").gsub(/\sdetail/,'').titleize}"
              base =  base +"<div class=\"executivesubheadcol\" style=\" padding:22px 0px 0px;\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>#{item_disabled}&nbsp;</div>"
            else
              if j > heading_display_restriction
                base =  base + "<div class=\"executivesubheadcol\" style=\" padding:22px 0px 0px;\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span><a href=\"#\" onclick=\"performanceReviewCalls(\\'#{bread_sub_partial}\\',{financial_sub:\\'#{ar1[0]}\\', financial_subid: #{ar1[1]} });return false;\">#{heading.gsub("'","").gsub(/\sdetail/,'').titleize}</a><img width=\"10\" height=\"9\" src=\"/images/eventsicon2.png\">&nbsp;</div>"
              end
            end
          end
          j +=1
        end
      end
    end
    @color_display =title_array && ((title_array.flatten.to_s.downcase.include?('revenue') ||  title_array.flatten.to_s.downcase.include?('income')) && !title_array.flatten.to_s.downcase.include?('other income and expense') && !title_array.flatten.to_s.downcase.include?('debt service'))  ? "income" : "expense"
    return base
  end

  # Heading link formation in the capital expenditure sub page
  def find_link_to(title, id)
    length =   (params[:partial_page] == 'cash_and_receivables'  &&  remote_property(@note.accounting_system_type_id)) ? 20 : 30
    nodes = IncomeAndCashFlowDetail.count(:all , :conditions=>["parent_id=#{id}"])
    if nodes == 0
      return "<span title='#{title.gsub(/\b\w/){$&.upcase}.gsub(':','')}'>&nbsp;#{title.gsub(/\b\w/){$&.upcase}.gsub(':','')}</span>"
    else
      return "&nbsp;<a  href=\"\" onclick=\"update_level_bread_crum2(#{id},' #{title.titleize}'#{@par});cashSubCalls(2,{cash_find_id:'#{id}',cash_item:'#{title}'}); return false;\" title='#{title.gsub(/\b\w/){$&.upcase}.gsub(':','')}'>#{title.gsub(/\b\w/){$&.upcase}.gsub(':','')}</a>"
    end
  end

  def total_cap_display(title, id)
    title = 'Total '+title
    return "<span title='#{title.gsub(/\b\w/){$&.upcase}.gsub(':','')}'>&nbsp;#{title.gsub(/\b\w/){$&.upcase}.gsub(':','')}</span>"
  end

  def wres_rent_roll_details(month=nil, year=nil)
    swig_rent_roll_details(month=nil, year=nil)
  end

  def swig_rent_roll_details(month=nil, year=nil)
    @note = RealEstateProperty.find_real_estate_property(params[:note_id]) if params[:note_id]
    if @note.leasing_type == 'Commercial'
      rent_roll_for_commercial(month, year)
    elsif @note.leasing_type == 'Multifamily'
      rent_roll_for_multifamily(month, year)
    end
  end

  def rent_roll_for_commercial(month=nil, year=nil, lease=nil)
    params[:page] = ((params[:from_pag]!='true' && !params[:sort].blank?) ? 1 : params[:page])
    sort = (params[:sort].blank? || params[:sort].nil?) ? "lr.lease_end_date" : params[:sort]
    sort = params[:sort] == "ps.suite_no DESC" ? "CAST(suite_no AS SIGNED) DESC"  : sort
    sort = params[:sort] == "ps.suite_no" ? "CAST(suite_no AS SIGNED) ASC"  : sort
    sort = params[:sort] == "top_tenants" ? "lr.sqft"  : sort
    sort = params[:sort] == "upcoming_expiration" ? "lr.lease_end_date"  : sort
    sort = params[:sort] == "expirations" ? "expirations"  : sort
    sort = params[:sort] == "renewals" ? "renewals"  : sort
    sort = params[:sort] == "new_leases" ? "new_leases"  : sort

    #~ sort = (params[:sort] == "pl.term_remaining") ? "lr.lease_end_date" :  (params[:sort] == "pl.term_remaining DESC" ? "pl.end_date DESC" : sort )
    if params[:rent_roll_filter] == 'vacant'
      rent_roll_vacant_filter(month,year,sort,params)
#    elsif params[:rent_roll_filter] == "2011_expiration" ||params[:rent_roll_filter] == "2012_expiration" || params[:rent_roll_filter] == "2013_expiration" || params[:rent_roll_filter] == "2014_expiration" || params[:rent_roll_filter] == "2015_expiration"
    elsif params[:rent_roll_filter].present? && (params[:rent_roll_filter].include?('_expiration') || params[:rent_roll_filter].include?('and above'))
      rent_roll_expiration_filter(params[:rent_roll_filter],sort,month,year)
    elsif params[:rent_roll_filter].eql?('expirations') || params[:rent_roll_filter].eql?('renewals') || params[:rent_roll_filter].eql?('new_leases')
      suites = Suite.find(:all, :conditions=>['real_estate_property_id IN (?)', @note.id]).map(&:id) if @note.present?
      year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year <= ? and real_estate_property_id IN (?)', suites ,Date.today.year,@note.id],:select=>"year",:order=>"year desc",:limit=>1) if suites.present?
      year  = !year.nil? && year[0] ? year[0].year.to_i : Date.today.year
      month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ? and real_estate_property_id IN (?)', suites ,year.to_i,get_month(year),@note.id],:select=>"month").map(&:month).max if suites.present?
      find_commercial_rent_roll(month,year,sort,nil)
      unless @pdf
        @rent_roll_swig = @rent_roll_swig.paginate(:page=> params[:page],:per_page=>30 ) unless (@rent_roll_swig.nil? || @rent_roll_swig.blank?)
      end
    elsif params[:rent_roll_filter].eql?('top_10_tenants') || params[:rent_roll_filter].eql?('top_10_expirations')
      #      filter = params[:top_tenants].eql?("true") ? params[:top_tenants] : params[:upcoming_expiration]
      rent_roll_top_tenants_and_expiration_filter(sort,month,year)
    else
      ##removed code related to period for time line selector removal
      @suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
      year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year <= ? and real_estate_property_id = ?', @suites ,Date.today.year,@note.id],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
      year  = !year.nil? && year[0] ? year[0].year.to_i : Date.today.year
      month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ? and real_estate_property_id = ?', @suites ,year.to_i,get_month(year),@note.id],:select=>"month").map(&:month).max if !@suites.blank?
      @month = month
      find_commercial_rent_roll(month,year,sort,lease)
      unless @pdf
        @rent_roll_swig = @rent_roll_swig.paginate(:page=> params[:page],:per_page=>30 ) unless (@rent_roll_swig.nil? || @rent_roll_swig.blank?)
      end
    end
  end

  #~ def find_commercial_rent_roll(month,year,sort,lease=nil)
  #~ vacant_res = lease.eql?('mgmt_lease') ? "and lr.tenant <> 'VACANT'" : ""
  #~ @rent_roll_swig = LeaseRentRoll.find_by_sql("SELECT ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id WHERE (lr.occupancy_type ='current' and ps.status = 'Occupied' and lr.real_estate_property_id = #{@note.id} and lr.month = #{month} and lr.year = #{year.to_i}) or (lr.occupancy_type IS  null and  ps.status ='Vacant' and lr.real_estate_property_id = #{@note.id} and lr.month = #{month} and lr.year = #{year.to_i}) order by #{sort};")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
  #~ return @rent_roll_swig
  #~ end

  #Commercial Rent Rolll display
  def find_commercial_rent_roll(month,year,sort,lease=nil)
    vacant_res = lease.eql?('mgmt_lease') ? "and lr.tenant <> 'VACANT'" : ""
    @rent_roll_swig,parent_ids,sub_ids = [],[],[]
    @suite_nos = []
    if params[:rent_roll_filter].present? && params[:rent_roll_filter] != 'all_units'
      if params[:rent_roll_filter].include?('and above')
        start_date = Date.new(params[:rent_roll_filter].gsub(" and above","").to_i).strftime("%Y-%m-%d")
        end_date = ''
      else
        start_date = Date.new(params[:rent_roll_filter].gsub(" Expiration","").to_i).strftime("%Y-%m-%d")
        end_date = start_date.to_date.end_of_year.strftime("%Y-%m-%d")
        end_date = "and lr.lease_end_date <= '#{end_date}' "
      end
    end
    if params[:rent_roll_filter].present? && params[:rent_roll_filter].eql?('expirations')
      start_date = '#{Date.today.year}-01-01'
      end_date = '#{Date.today.year}-#{Date.today.month}-31'
      end_date = "and lr.lease_end_date <= '#{end_date}' "
    end
    #included conditions for displaying expirations from files also#
    lese_end_date = Time.now.strftime("%Y-%m-%d")
    @expiration_qry = params[:rent_roll_filter] && !params[:rent_roll_filter].eql?("top_10_expirations") && params[:rent_roll_filter] != 'all_units' && !params[:rent_roll_filter].blank? && params[:rent_roll_filter] != "undefined" ? "and lr.occupancy_type != 'expirations' and lr.lease_end_date >= '#{start_date}' #{end_date} and ps.status != 'vacant'" : params[:rent_roll_filter].eql?("top_10_expirations") ? "and lr.occupancy_type != 'expirations' and lr.lease_end_date >= '#{lese_end_date}' and ps.status != 'vacant'" : "" if !params[:rent_roll_filter].eql?("top_10_tenants")
    @lease_end = params[:rent_roll_filter].present? && params[:rent_roll_filter].include?('and above') ? '' : " or lr.lease_end_date < '#{lese_end_date}'"
    sort_var = params[:rent_roll_filter].eql?("top_10_tenants") ? "CAST(lr.sqft AS SIGNED) DESC" : "lr.lease_end_date ASC"
    if params[:rent_roll_filter].eql?("top_10_tenants")
      tmp_rent_roll_swig1 = LeaseRentRoll.find_by_sql("SELECT ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id INNER JOIN leases l ON lr.lease_id = l.id WHERE (ps.status = 'Occupied' and lr.real_estate_property_id = #{@note.id} and lr.month = #{month} and lr.year = #{year.to_i} #{@expiration_qry}) or ((lr.occupancy_type IS null or lr.occupancy_type = 'expirations' #{@lease_end} or ps.status like '%Vacant%') and lr.real_estate_property_id = #{@note.id} and l.is_executed = #{1} and lr.month = #{month} and lr.year = #{year.to_i} #{@expiration_qry}) order by #{sort_var};")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
      tmp_rent_roll_swig =  LeaseRentRoll.find_by_sql("SELECT le.parent_id as parent_id,ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id INNER JOIN leases le on (lr.lease_id = le.id) and le.real_estate_property_id = #{@note.id} WHERE (ps.status = 'Occupied' and lr.real_estate_property_id = #{@note.id} and le.is_executed = #{1} and lr.month = #{month} and lr.year = #{year.to_i} #{@expiration_qry}) order by #{sort_var};")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
    elsif params[:rent_roll_filter].eql?('expirations')
      tmp_rent_roll_swig1 = LeaseRentRoll.find_by_sql("SELECT ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id INNER JOIN leases l ON lr.lease_id = l.id WHERE (lr.occupancy_type = 'expirations'  and lr.real_estate_property_id = #{@note.id} and lr.month = '#{month}' AND lr.year = #{year} AND lr.lease_end_date between '#{Date.today.year}-01-01' and '#{Date.today.year}-#{Date.today.month}-31')")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
      tmp_rent_roll_swig = []
    elsif params[:rent_roll_filter].eql?('renewals')
      tmp_rent_roll_swig1 = LeaseRentRoll.find_by_sql("SELECT ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id INNER JOIN leases l ON lr.lease_id = l.id WHERE (lr.occupancy_type = 'renewal'  and lr.real_estate_property_id = #{@note.id} and lr.month = '#{month}' AND lr.year = #{year})")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
      tmp_rent_roll_swig = []
    elsif params[:rent_roll_filter].eql?('new_leases')
      tmp_rent_roll_swig1 = LeaseRentRoll.find_by_sql("SELECT ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id INNER JOIN leases l ON lr.lease_id = l.id WHERE ((lr.occupancy_type = 'new' or lr.occupancy_type = 'current') and lr.lease_start_date between '#{Date.today.year}-01-01' and '#{Date.today.year}-#{Date.today.month}-31' and lr.real_estate_property_id = #{@note.id} and lr.month = '#{month}' AND lr.year = #{year})")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
      tmp_rent_roll_swig = []
    else
      tmp_rent_roll_swig1 = LeaseRentRoll.find_by_sql("SELECT ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id WHERE (ps.status = 'Occupied' and lr.real_estate_property_id = #{@note.id} and lr.month = #{month} and lr.year = #{year.to_i} #{@expiration_qry}) or ((lr.occupancy_type IS null or lr.occupancy_type = 'expirations' #{@lease_end} or ps.status like '%Vacant%') and lr.real_estate_property_id = #{@note.id} and lr.month = #{month} and lr.year = #{year.to_i} #{@expiration_qry}) order by CAST(ps.suite_no AS SIGNED) ASC;")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
      tmp_rent_roll_swig = LeaseRentRoll.find_by_sql("SELECT le.parent_id as parent_id,ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id INNER JOIN leases le on (lr.lease_id = le.id) and le.real_estate_property_id = #{@note.id} WHERE (ps.status = 'Occupied' and lr.real_estate_property_id = #{@note.id} and lr.month = #{month} and lr.year = #{year.to_i} #{@expiration_qry}) order by CAST(ps.suite_no AS SIGNED) ASC;")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
    end
    vacant_leases =  tmp_rent_roll_swig1 - tmp_rent_roll_swig if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
    vacant_leases.present? && vacant_leases.each do |vacant|
      vacant.tenant = raw("Vacant") if vacant.tenant.present?
      vacant.lease_start_date = raw("&nbsp;")
      vacant.lease_end_date = raw("&nbsp;")
      vacant.base_rent_monthly_amount = raw("")
      vacant.tis_amount = raw("")
      vacant.lcs_amount =raw("")
      @rent_roll_swig  << vacant #unless params[:top_tenants].present?
    end
    @rent_roll_parent_id_zero = []
    @rent_roll_parent_id = []
    tmp_rent_roll_swig.each do |i|
      i.parent_id.to_i == 0 ?  @rent_roll_parent_id_zero << i : @rent_roll_parent_id << i
    end  if tmp_rent_roll_swig.present?
    @rent_roll_collection = []
    @rent_roll_collection = @rent_roll_parent_id_zero + @rent_roll_parent_id
    group_master_and_sub_leases(month,year,sort)
  end

  #To loop the sub leases of a particular master lease
  def loop_sub_leases(i,month,year,sort,sub_leases_collection)
    sub_leases_collection.each do |i|
      i.tenant = raw('&nbsp;')
      @rent_roll_swig << i if @suite_nos.index(i.suite_no).nil?
      sub_leases_collection =sub_lease(i,month,year,sort) if @suite_nos.index(i.suite_no).nil?
      loop_sub_leases(i,month,year,sort,sub_leases_collection) if @suite_nos.index(i.suite_no).nil?
      @suite_nos << i.suite_no
    end if sub_leases_collection.present?
  end

  #To find sub lease of  particular lease
  def sub_lease(i,month,year,sort)
    sub_leases =  LeaseRentRoll.find_by_sql("SELECT le.parent_id as parent_id,ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id INNER JOIN leases le on lr.lease_id = le.id and le.real_estate_property_id = #{@note.id} and le.parent_id = #{i.lease_id} WHERE ((ps.status = 'Occupied' and lr.real_estate_property_id = #{@note.id} and lr.month = #{month} and lr.year = #{year.to_i} #{@expiration_qry}))  order by CAST(ps.suite_no AS SIGNED) ASC;")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
  end

  #TO Group master and sub leases
  def  group_master_and_sub_leases(month,year,sort)
    if @rent_roll_collection.present?
      @rent_roll_collection.each do |i|
        if i.lease_id
          sub_leases =  sub_lease(i,month,year,sort)
          @rent_roll_swig << i  if @suite_nos.index(i.suite_no).nil?
          @suite_nos << i.suite_no
          sub_leases.each do |i|
            i.tenant = raw('&nbsp;')
            @rent_roll_swig << i if @suite_nos.index(i.suite_no).nil?
            sub_leases_collection =sub_lease(i,month,year,sort)
            loop_sub_leases(i,month,year,sort,sub_leases_collection)
            @suite_nos << i.suite_no
          end if sub_leases.present?
        end
      end
    end

    if params[:rent_roll_filter].eql?("top_10_tenants")
      @rent_roll_swig = @rent_roll_swig.sort_by(&:sqft).reverse
      return @rent_roll_swig
    elsif params[:rent_roll_filter].eql?("top_10_expirations")
      @rent_roll_swig = @rent_roll_swig.sort_by(&:lease_end_date)
      return @rent_roll_swig
    else
      return @rent_roll_swig
    end
  end



  def rent_roll_for_multifamily(month=nil, year=nil) # If you change any functionality in this method, please do the same in dashboard multifamily
    params[:page] = ((params[:from_pag]!='true' && !params[:sort].blank?) ? 1 : params[:page])
    sort = (params[:sort].blank? || params[:sort].nil?) ? "pl.end_date" : params[:sort]
    sort = params[:sort] == "ps.suite_number DESC" ? "CAST(suite_number AS SIGNED) DESC"  : sort
    sort = params[:sort] == "ps.suite_number" ? "CAST(suite_number AS SIGNED) ASC"  : sort
    sort = (params[:sort] == "pl.term_remaining") ? "pl.end_date" :  (params[:sort] == "pl.term_remaining DESC" ? "pl.end_date DESC" : sort )
    ##removed code related to period for time line selector removal
    @suites = PropertySuite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
    #~ year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?)',@suites],:order=>"year desc",:limit=>1).map(&:year).max if !@suites.blank?
    year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year <= ?',@suites,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
    year= year && year[0] ? year[0].year.to_i : nil
    month = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year = ? and month <= ?',@suites,year.to_i,get_month(year)],:select=>"month").map(&:month).max if !@suites.blank?
    @month = month
    find_multifamily_rent_roll(month,year,sort)
    unless @pdf
      @rent_roll_wres = @rent_roll_wres.paginate(:page=> params[:page],:per_page=>30 ) if !(@rent_roll_wres.nil? || @rent_roll_wres.blank?)
    end
    @year = year
  end

  def find_multifamily_rent_roll(month,year,sort)
    @rent_roll_wres = PropertyLease.find_by_sql("SELECT ps.suite_number,ps.floor_plan,pl.tenant,ps.rented_area,pl.effective_rate,pl.actual_amt_per_sqft,pl.end_date,pl.other_deposits,pl.made_ready FROM `property_leases` pl INNER JOIN property_suites ps ON pl.property_suite_id = ps.id WHERE (ps.real_estate_property_id = #{@note.id} and pl.month = #{month} and pl.year = #{year.to_i}) order by #{sort};") if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
    return @rent_roll_wres
  end

  def rent_roll_vacant_filter(month,year,sort,params)
    ##removed code related to period for time line selector removal
    @suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
    #Commented as an issue occurred in Year#
    #~ year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and occupancy_type = ?',@suites,'current'],:order=>"year desc",:limit=>1).map(&:year).max if !@suites.blank?
    #~ year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and occupancy_type = ? and year <= ?',@suites,'current',Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
    #~ year = year.compact.empty? ? nil : year[0].year
    month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ?',@suites,year,get_month(year)],:select=>"month").map(&:month).max if !@suites.blank?
    vacant_units_filter(month,year)
    @month = month
    @rent_roll_swig = @rent_roll_swig.paginate(:page=> params[:page],:per_page=>30 ) unless (@rent_roll_swig.nil? || @rent_roll_swig.blank?)
    @year = year
  end

  def vacant_units_filter(month,year)
    #Changes done for displaying vacant units that are expired leases#
    @rent_roll_swig = []
    lese_end_date = Time.now.strftime("%Y-%m-%d")
    @lease_end = " or lr.lease_end_date < '#{lese_end_date}'"
    vacant_filter = LeaseRentRoll.find_by_sql("SELECT ps.id,ps.suite_no,lr.* FROM  suites ps inner join lease_rent_rolls lr on ps.id = lr.suite_id where ps.real_estate_property_id = #{@note.id} and (lr.occupancy_type IS null or lr.occupancy_type ='expirations' #{@lease_end} or ps.status like '%Vacant%') and lr.month = #{month} and lr.year = #{year.to_i} order by CAST(ps.suite_no AS SIGNED) ASC;")  #if (!month.nil? && (!year.nil? || !year.blank?)) &&  sort != ""
    vacant_filter.present? && vacant_filter.each do |vacant|
      vacant.tenant = raw("Vacant")
      vacant.lease_start_date = raw("&nbsp;")
      vacant.lease_end_date = raw("&nbsp;")
      vacant.base_rent_monthly_amount = raw("")
      vacant.tis_amount = raw("")
      vacant.lcs_amount =raw("")
      @rent_roll_swig << vacant
    end
    return @rent_roll_swig
  end

  def rent_roll_expiration_filter(filter,sort,month,year)
    start_date = Date.new(filter.gsub(" Expiration","").to_i).strftime("%Y-%m-%d")
    end_date = start_date.to_date.end_of_year.strftime("%Y-%m-%d")
    ##removed code related to period for time line selector removal
    @suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
    #Commented as an issue occurred in Year#
    #~ year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and occupancy_type = ? and year <= ?',@suites,'current',Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
    #~ year = year.compact.empty? ? nil : year[0].year
    month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ?',@suites,year,get_month(year)],:select=>"month").map(&:month).max if !@suites.blank?
    @month = month
    expiration_units_filter(month,year,sort,start_date,end_date)
    @rent_roll_swig = @rent_roll_swig.paginate(:page=> params[:page],:per_page=>30 ) unless (@rent_roll_swig.nil? || @rent_roll_swig.blank?)
    @year = year
  end


  def rent_roll_top_tenants_and_expiration_filter(sort,month,year)
    #~ start_date = Date.new(filter.gsub(" Expiration","").to_i).strftime("%Y-%m-%d")
    #~ end_date = start_date.to_date.end_of_year.strftime("%Y-%m-%d")
    ##removed code related to period for time line selector removal
    #~ @suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
    #Commented as an issue occurred in Year#
    #~ year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and occupancy_type = ? and year <= ?',@suites,'current',Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
    #~ year = year.compact.empty? ? nil : year[0].year
    #~ month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ?',@suites,year,get_month(year)],:select=>"month").map(&:month).max if !@suites.blank?
    #~ @month = month

    year = @note.try(:lease_rent_rolls).map(&:year).compact.max
    month = @note.try(:lease_rent_rolls).where(:year=> year).map(&:month).compact.max

    expiration_units_filter(month,year,sort,start_date=nil,end_date=nil)
    @rent_roll_swig = @rent_roll_swig.paginate(:page=> params[:page],:per_page=>30 ) unless (@rent_roll_swig.nil? || @rent_roll_swig.blank?)
    @year = year
  end


  def expiration_units_filter(month,year,sort,start_date,end_date)
    #@rent_roll_swig = PropertyLease.find_by_sql("SELECT ps.id,ps.suite_no,lr.* FROM `lease_rent_rolls` lr INNER JOIN suites ps ON lr.suite_id = ps.id WHERE (  lr.month = #{month}  AND lr.year = #{year.to_i} AND lr.real_estate_property_id = #{@note.id} and lr.occupancy_type = 'current' and lr.lease_end_date >= '#{start_date}' and lr.lease_end_date <= '#{end_date}') order by #{sort};")  if (!month.nil? && (!year.nil? || !year.blank?)) &&  sort != ""
    find_commercial_rent_roll(month,year,sort,nil)
    #return @rent_roll_swig
  end

  def wres_and_swig_path_for_items(id, path = '')
    item = IncomeAndCashFlowDetail.find_by_id(id) # => have to be changed if calling from assign new task
    property = RealEstateProperty.find_real_estate_property(item.resource_id)
    return nil if item.title == "other income" && current_user && current_user.client_type && current_user.client_type.downcase == "wres"
    if item.parent_id.nil?
      return nil if (item.title == "cash flow statement summary" && item.title != "net cash flow") || path.include?('Amortization')
      path = "#{item.title.gsub("'","")}" + path unless (item.title == "operating statement summary" || item.title == "cash flow statement summary") # => check the cash flow condition
      return '' if path.blank?
      path = path[3, path.length]
      path_itms = path.split(' > ')
      replace = {'operating income'=> 'Total Operating Revenues', 'operating expenses'=> 'Total Expenses', 'income detail'=> 'Operating Revenue', 'net operating income'=> 'Net Operating Income', 'capital expenditures'=> 'Capital Expenditures', 'net income before depreciation'=>'Net Income Before Depreciation'}
      if replace.keys.include?(path_itms[0].downcase)
        path_itms[0] = replace[path_itms[0].downcase]
      elsif path_itms[0] == "Recoverable Expenses Detail" || path_itms[0] == "Non Recoverable Expenses Detail"
        path_itms.unshift("Operating Expenses")
      else
        path_itms[0] = property.leasing_type == "Multifamily"  && !(find_accounting_system_type(0,@note) ||  find_accounting_system_type(4,@note)) ? 'Other Income & Expenses' :  !(find_accounting_system_type(0,@note) ||  find_accounting_system_type(4,@note)) ? 'Cash': 'Operating Statement'
      end
      path_itms = path_itms.join(' > ')
    else
      path = " > #{item.title.titleize.gsub("'","")}" + path
      wres_and_swig_path_for_items(item.parent_id, path)
    end
  end

  def wres_variances
    variances_find_month
  end

  def variances
    @portfolio = Portfolio.find(params[:portfolio_id]) if params[:portfolio_id]
    property_id = params[:note_id] ? params[:note_id] : params[:id]
    @note =  RealEstateProperty.find_real_estate_property(property_id)
    @notes = RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id)
    @period = params[:period]  ? params[:period]  : params[:tl_period]
    @partial = 'variances'
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    #@default_month_and_year= 45.days.ago
    #~ if (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
    #~ variances_display(params[:quarter_end_month].to_i,params[:tl_year].to_i)
    if !params[:tl_month].nil? and !params[:tl_month].blank? and  !params[:tl_year].nil? and !params[:tl_year].blank?
      @current_time_period=Date.new(params[:tl_year].to_i,params[:tl_month].to_i,1)
    elsif params[:period] == '5' || params[:tl_period] == '5'
      calc_for_financial_data_display
      @current_time_period=Date.new(@financial_year,@financial_month,1)
    else
      @current_time_period = Date.new(Date.today.year,Date.today.month,1)
    end
    @month_list = []
    if (params[:tl_period] == "7" || params[:period] == "7") && params[:cur_year]
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    #~ if @note && remote_property(@note.accounting_system_type_id)
    variances_for_remote_property
    #~ else
    #~ variances_find_month
    #~ end
  end

  def variances_find_month
    #~ @show_variance_thresholds =true
    #to find year and month start
    calc_for_financial_data_display
    if params[:start_date] && (params[:period] != "2" && params[:tl_period] != "2") &&  (params[:period] != "3" && params[:tl_period] != "3")
      @dates= params[:start_date].split("-")
      variances_display(@dates[1].to_i,@dates[0].to_i)
      #~ elsif (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
      #~ variances_display(params[:quarter_end_month].to_i,params[:tl_year].to_i)
    elsif !params[:tl_month].nil? and !params[:tl_month].blank? and  !params[:tl_year].nil? and !params[:tl_year].blank? and  (params[:period] != "3" && params[:tl_period] != "3")
      variances_display(params[:tl_month].to_i, params[:tl_year].to_i)
    elsif params[:period] == '4' || params[:tl_period] == '4'
      year_to_date= @financial_month
      for m in 1..year_to_date
        @month_list <<  Date.new(Time.now.year,m,1).strftime("%Y-%m-%d")
      end
      variances_display(@financial_month,@financial_year)
    elsif params[:period] == '7' || params[:tl_period] == '7'
      month_year = params[:cur_month] ? @end_date.to_date.month : @dates[1].to_i
      year_month = params[:cur_year] ? @start_date.to_date.year : @dates[0].to_i
      for m in 1..month_year
        @month_list <<  Date.new(year_month,m,1).strftime("%Y-%m-%d")
      end
      variances_display(month_year,year_month)
    elsif params[:period] == '5' || params[:tl_period] == '5'
      variances_display(@financial_month,@financial_year)
    elsif params[:period] == '6' || params[:tl_period] == '6'|| params[:tl_period] == '3' || params[:period] == '3'
      prev_year = Date.today.prev_year.year
      year = find_selected_year(prev_year)
      for m in 1..12
        @month_list <<  Date.new(prev_year,m,1).strftime("%Y-%m-%d")
      end
      variances_display(12,year)
    elsif params[:period] == '8' || params[:tl_period] == '8'
      variances_display(12,Date.today.year)
    end
    #to find year and month end
    #render page
    unless @pdf
      render :update do |page|
        if params[:from_performance_review] == "true"
          page << "jQuery('.subheaderwarpper').show();"
        end
        page << "if(!jQuery('.subheaderwarpper').is(':visible')){jQuery('.subheaderwarpper').show();}else{}"
        page << "jQuery('#time_line_selector').show();"
        if @note && @note.property_name.present?
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Variances</div>');"
        else
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Variances</div>');"
        end
        page.replace_html "time_line_selector", :partial => "/properties/time_line_selector", :locals => {:period => @period, :note_id => @note.id, :partial_page =>"/properties/variances", :start_date => 0, :timeline_start => @time_line_start_date, :timeline_end => @time_line_end_date } if params[:action] == "select_time_period" || params[:action] == "wres_select_time_period" ||   (((params[:tl_period] == "5" || params[:period] == "5") && Date.today.month == 1)  || (params[:tl_period] == "4"  ||  params[:period] == "4")) &&  ((params[:tl_month].nil? || params[:tl_month].blank?))
        page << "jQuery('#monthyear').show();"
        page << "jQuery('#quarterly').hide();"
        page.replace_html "portfolio_overview_property_graph", :partial => "/properties/variances",:locals => {:partial_page => "variances"}
        if @note && @note.property_name.present?
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Variances</div>');"
        else
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Variances</div>');"
        end
      end
    end
  end

  def variances_display(month_val=nil,year=nil)
    @month = month_val
    @year = year
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    if @note.class  == "RealEstateProperty"
      property_folder =   Folder.find_by_real_estate_property_id_and_is_master_and_parent_id(@note.id,0,0)
      @accounts_folder =  Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,property_folder.id,'Excel Uploads')
      @accounts_folder =  Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,property_folder.id,'Accounts') if @accounts_folder.nil?
      @year_folder =  Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,@accounts_folder.id,year.to_s) if @accounts_folder
      excel_file_name,excel_file_name2 = find_excel_name
      if @year_folder
        12.downto(1) do |month|
          m_f =  Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,@year_folder.id,months[month-1].to_s)
          @month_folder = Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,@year_folder.id,months[month-1].to_s) if m_f && !m_f.documents.empty?
          if @month_folder && !@month_folder.documents.empty?
            @month_folder.documents.each do |d|
              if d.user_id == current_user.id || !SharedDocument.find_by_user_id_and_document_id(current_user.id,d.id).nil?
                if (d.filename.downcase.include?(excel_file_name) || d.filename.downcase.include?(excel_file_name2))  && d.is_deleted == false
                  @excel_document = d
                end
              end
            end
            if @excel_document
              @month_folder.documents.each do |d|
                if (d.filename.downcase.include?(excel_file_name) || d.filename.downcase.include?(excel_file_name2)) && d.is_deleted == false
                  @variance_task_document = d
                  if d.filename.downcase.include?(excel_file_name) && d.is_deleted == false
                    @variance_task_document_month_budget = d
                  elsif d.filename.downcase.include?(excel_file_name2) && d.is_deleted == false
                    @variance_task_document_capital_improvement = d
                  end
                end
              end
              if  @variance_task_document.nil?
                @month_folder.documents.each do |d|
                  if (d.filename.downcase.include?(excel_file_name) || d.filename.downcase.include?(excel_file_name2)) && d.is_deleted == false
                    @without_variance_task_document = d
                    if d.filename.downcase.include?(excel_file_name) && d.is_deleted == false
                      @without_variance_task_document_month_budget = d
                    elsif d.filename.downcase.include?(excel_file_name2) && d.is_deleted == false
                      @without_variance_task_document_capital_improvement = d
                    end
                  end
                end
              end
            end
          end
          break if m_f && !m_f.documents.empty? && (@variance_task_document || @without_variance_task_document)
        end
      end
    end
    @month = months.index(@month_folder.name) + 1 if @month_folder && params[:period] != '5' && params[:period] != '10' && params[:tl_period] != '10' && params[:tl_period] != '5' && params[:tl_period] != '1' && params[:period] != '1'
  end
  #To map the excel file with accounting syatem type
  def find_excel_name
    if @note && find_accounting_system_type(2,@note)
      excel_file_name = "Month_Budget"
      excel_file_name2 = "CapExp"
    elsif @note && find_accounting_system_type(1,@note)
      excel_file_name = "month_budget"
      excel_file_name2 = "capital_improvement"
    elsif @note && (find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note))
      excel_file_name = "Financials"
      excel_file_name2 = "CapExp"
    elsif @note && find_accounting_system_type(3,@note)
      excel_file_name = "actual_budget_analysis"
      excel_file_name2 = "actual_budget_analysis"
    else
      excel_file_name,excel_file_name2="",""
    end
    return excel_file_name.downcase,excel_file_name2.downcase
  end

  def variances_display_for_exp(month_val=nil,year=nil)
    @month = month_val
    @year = year
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    if @note.class  == "RealEstateProperty"
      property_folder =   Folder.find_by_real_estate_property_id_and_is_master_and_parent_id(@note.id,0,0)
      @accounts_folder =  Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,property_folder.id,'Excel Uploads')
      @accounts_folder =  Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,property_folder.id,'Accounts') if @accounts_folder.nil?
      @year_folder =  Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,@accounts_folder.id,year.to_s) if @accounts_folder
      excel_file_name,excel_file_name2 = find_excel_name
      if @year_folder
        12.downto(1) do |month|
          m_f =  Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,@year_folder.id,months[month-1].to_s)
          @month_folder = Folder.find_by_real_estate_property_id_and_parent_id_and_name(@note.id,@year_folder.id,months[month-1].to_s) if m_f && !m_f.documents.empty?
          if @month_folder && !@month_folder.documents.empty?
            @month_folder.documents.each do |d|
              if (d.filename.downcase.include?(excel_file_name) || d.filename.downcase.include?(excel_file_name2))  && d.is_deleted == false
                @excel_document = d
              end
            end
            if @excel_document
              @month_folder.documents.each do |d|
                if d.filename.downcase.include?(excel_file_name) && d.is_deleted == false
                  @variance_task_document_month_budget = d
                elsif d.filename.downcase.include?(excel_file_name2) && d.is_deleted == false
                  @variance_task_document_capital_improvement = d
                end
              end
            end
          end
          break if m_f && !m_f.documents.empty? && (@variance_task_document || @without_variance_task_document)
        end
      end
    end
    @month = months.index(@month_folder.name) + 1 if @month_folder && params[:period] != '5' && params[:period] != '10' && params[:tl_period] != '10' && params[:tl_period] != '5'
  end
  ##Varainces calculation for remote property
  def variances_for_remote_property
    calc_for_financial_data_display
    if params[:start_date] && (params[:period] != "2" && params[:tl_period] != "2")
      @dates= params[:start_date].split("-")
      variances_display_for_remote(@dates[1].to_i,@dates[0].to_i)
    elsif !params[:tl_month].nil? and !params[:tl_month].blank? and  !params[:tl_year].nil? and !params[:tl_year].blank?
      variances_display_for_remote(params[:tl_month].to_i, params[:tl_year].to_i)
    elsif params[:period] == '4' || params[:tl_period] == '4'
      year_to_date= @financial_month
      for m in 1..year_to_date
        @month_list <<  Date.new(Time.now.year,m,1).strftime("%Y-%m-%d")
      end
      variances_display_for_remote(@financial_month,@financial_year)
    elsif params[:period] == '7' || params[:tl_period] == '7'
      month_year = params[:cur_month] ? @end_date.to_date.month : @dates[1].to_i
      year_month = params[:cur_year] ? @start_date.to_date.year : @dates[0].to_i
      for m in 1..month_year
        @month_list <<  Date.new(year_month,m,1).strftime("%Y-%m-%d")
      end
      variances_display_for_remote(month_year,year_month)
    elsif params[:period] == '5' || params[:tl_period] == '5'
      variances_display_for_remote(@financial_month,@financial_years)
    elsif params[:period] == '6' || params[:tl_period] == '6'|| params[:tl_period] == '3' || params[:period] == '3'
      prev_year = Date.today.prev_year.year
      year = find_selected_year(prev_year)
      for m in 1..12
        @month_list <<  Date.new(prev_year,m,1).strftime("%Y-%m-%d")
      end
      variances_display_for_remote(12,year)
    elsif params[:period] == '8' || params[:tl_period] == '8'
      variances_display_for_remote(12,Date.today.year)
    end
  end

  def variances_display_for_remote(month= nil ,year = nil)
    @month = month.to_i
    @year = year
    unless @pdf
      render :update do |page|
        if params[:from_performance_review] == "true"
          page << "jQuery('.subheaderwarpper').show();"
        end
        page << "if(!jQuery('.subheaderwarpper').is(':visible')){jQuery('.subheaderwarpper').show();}else{}"
        page << "jQuery('#time_line_selector').show();"
        if @note && @note.property_name.present?
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Variances</div>');"
        else
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Variances</div>');"
        end
        page.replace_html "time_line_selector", :partial => "/properties/time_line_selector", :locals => {:period => @period, :note_id => @note.id, :partial_page =>"/properties/variances", :start_date => 0, :timeline_start => @time_line_start_date, :timeline_end => @time_line_end_date } if((params[:tl_period] == "5" || params[:period] == "5") && Date.today.month == 1) || (params[:action] == "select_time_period" || params[:action] == "wres_select_time_period" ||   (params[:tl_period] == "4"  ||  params[:period] == "4") &&  ((params[:tl_month].nil? || params[:tl_month].blank?) ))
        page << "jQuery('#monthyear').show();"
        page << "jQuery('#quarterly').hide();"
        page.replace_html "portfolio_overview_property_graph", :partial => "/properties/variances",:locals => {:partial_page => "variances"}
        if @note && @note.property_name.present?
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Variances</div>');"
        else
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>Variances</div>');"
        end
      end
    end
  end

  def swig_path_for_cap_exp_items(id)
    item = PropertyCapitalImprovement.find_by_id(id)
    "Capital Expenditure > #{item.category.titlecase.gsub("'","")} > #{item.tenant_name.titlecase.gsub("'","")}"
  end

  #.......................................................functions related to commnets and files in portfolio summary page starts here................................................................................................................................
  def add_secondary_docs_in_summary
    folder = Folder.find_by_id(params[:folder_id])
    document_ids = (params[:recently_added_files_by_tree].split(',').collect { |id| id.to_i } ).uniq unless params[:recently_added_files_by_tree].blank?
    create_secondary_files_for_summary(folder,document_ids)
  end

  def add_secondary_files_in_summary
    folder = Folder.find_by_id(params[:folder_id])
    document_ids = (params[:already_upload].split(',').collect { |id| id.to_i } ).uniq unless params[:already_upload].blank?
    create_secondary_files_for_summary(folder,document_ids)
  end

  def create_secondary_files_for_summary(folder,document_ids)
    @secondary_files =[]
    if document_ids && !document_ids.empty?
      document_ids.each do |doc|
        @secondary_files << Document.find_by_id(doc)
      end
    end
    find_added_scondary_files
    if @secondary_files && !@secondary_files.empty?
      @secondary_files.each do |doc|
        #create copy of file starts here
        path ="#{Rails.root.to_s}/public"+doc.public_filename.to_s
        # ActionController::UploadedTempfile.open(doc.filename) do |temp|
        tempfile = Tempfile.new(doc.filename)
        begin
          tempfile.write(File.open(path).read)
          tempfile.flush
          upload_data = ActionDispatch::Http::UploadedFile.new({:filename=>doc.filename,:type=>doc.content_type, :tempfile=>tempfile})
          d= Document.new
          d.attributes = doc.attributes
          d.created_at = Time.now
          d.uploaded_data = upload_data
          d.folder_id = @monthly_report_folder.id
          d.real_estate_property_id = @monthly_report_folder.real_estate_property_id
          d.user_id = current_user.id
          d.save
        ensure
          tempfile.close
          tempfile.unlink
        end
        #create copy of file ends here
        folder = d.folder
        shared_folders_1 = SharedFolder.find(:all,:conditions=>['folder_id = ?',folder.id])
        @repeat_email = false
        unless shared_folders_1.empty?
          shared_folders_1.each do |subshared_folders_1|
            if d.filename != "Cash_Flow_Template.xls" && d.filename != "Rent_Roll_Template.xls"
              @repeat_email = (subshared_folders_1.user.email == folder.user.email) ? true : false if !@repeat_email
              SharedDocument.create(:folder_id=>folder.id,:user_id=>subshared_folders_1.user_id,:sharer_id=>current_user.id,:real_estate_property_id=>folder.real_estate_property_id,:document_id=>d.id)
              UserMailer.delay.send_collab_folder_updates("uploaded", current_user, subshared_folders_1.user, d.filename, folder.name,'document',d) if subshared_folders_1.user.email != current_user.email
            end
          end
          SharedDocument.create(:document_id=>d.id,:folder_id=>d.folder_id,:user_id=>folder.user_id,:sharer_id=>current_user.id,:real_estate_property_id=>folder.real_estate_property_id) if current_user.id != folder.user_id
          #          Event.create_new_event("upload",current_user.id,nil,[d],current_user.user_role(current_user.id),d.filename,nil)
          UserMailer.delay.send_collab_folder_updates("uploaded",current_user,folder.user, d.filename, folder.name,'document',d) if current_user.email != folder.user.email && !@repeat_email
        end
        Event.create_new_event("upload",current_user.id,nil,[d],current_user.user_role(current_user.id),d.filename,nil)
        # end
      end
    end
    update_portfolio_summary
  end

  def single_file_upload_in_executive_summary
    if params[:file]
      @task_file = Document.new
      @task_file.uploaded_data = params[:file]
      @task_file.user_id = current_user.id
      if params[:task_id]
        fn = ['delect_selected_file_for_folder',params[:task_id]]
      elsif params[:document_id]
        fn = ['delect_selected_file',params[:document_id]]
      end
      @task_file.save
    end
    total = (!params[:already_upload_file].nil? and  !params[:already_upload_file].blank? ) ?  params[:already_upload_file]+","+@task_file.id.to_s  : @task_file.id.to_s
    val_list = ''
    final_list = []
    for each_file in total.split(",")
      doc = Document.find_by_id(each_file)
      if !doc.nil?
        val_list =val_list + "<div class='coll3' id='#{doc.class.to_s+"_"+doc.id.to_s}'>  <div class='collabdelcol'><a href='#' onclick=\"if(confirm('Are you sure you want to remove this file ?')){jQuery(\'##{doc.class.to_s+"_"+doc.id.to_s}\').remove();#{fn[0]}(\'summary\',#{doc.id},#{doc.id},\'#{doc.filename}\');} return false\"><img border='0' width='7' height='7' src='/images/del_icon.png' title='Remove File'></a> #{doc.filename}</div></div>" if !doc.nil?
        final_list << doc.id
      end
    end
    val_list = val_list +"<div class='coll3'></div>"
    responds_to_parent do
      render :update do |page|
        if !(!params[:already_upload_file].nil? and  !params[:already_upload_file].blank? )
          page.show 'upload_file'
        end
        page.replace_html  'upload_files_list',"<input type='hidden' name='already_upload_file' id='already_upload_file' value='#{final_list.join(",")}'/>"
        page.replace_html  'single_file_upload_list',val_list
        page << "jQuery('#toDisable').remove();"
        page.call "flash_writter", "File added successfully"
      end
    end
  end

  def update_portfolio_summary
    if params[:add_doc_id]
      responds_to_parent do
        render :update do |page|
          page.call 'close_control_model'
          if params[:deal_room] == 'true'
            #            page.replace_html "show_assets_list",:partial=>'/collaboration_hub/my_files_assets_list'
            page.call "show_hide_asset_docs1_real_estate_for_deal_room", "#{params[:pid]}", "#{params[:folder_id]}", "hide_del"
          else
            page.replace_html "summary_secondary_files",:partial =>"/properties/summary_secondary_files_display"
          end
          page.call "load_completer"
        end
      end
    else
      render :update do |page|
        page.call 'close_control_model'
        if params[:deal_room] == 'true'
          #          page.call "show_hide_asset_docs1_real_estate_for_deal_room", "#{params[:portfolio_id]}", "#{params[:folder_id]}", "hide_del"
          #          show_hide_asset_docs1_real_estate_for_deal_room(88,4172,'hide_del')
          page.replace_html "show_assets_list",:partial=>'properties/assets_list.html.erb'
        else
          page.replace_html "summary_secondary_files",:partial =>"/properties/summary_secondary_files_display"
        end
        page.call "flash_writter", "#{@msg}"  if params[:action] == "show_asset_files" && @msg && params[:fn] == "true"
        page.call "load_completer" if !@msg
      end
    end
  end
  #.......................................................functions related to commnets and files in portfolio summary page ends here................................................................................................................................
  # copied from property_helper start
  def for_notes_year_to_date
    calc_for_financial_data_display
    id_val = params[:note_id] ? params[:note_id] : (params[:id] ? params[:id] : 0)
    if @note == nil || params[:id].nil?
      @note = RealEstateProperty.find_real_estate_property(id_val)
    end
    @notes = RealEstateProperty.find(:all, :conditions=>["portfolios.id=? and real_estate_properties.user_id = ? and real_estate_properties.client_id = #{current_user.client_id}", @portfolio.id,current_user.id ],:joins=>:portfolios, :order=> "real_estate_properties.created_at desc") if !@portfolio.nil?
    @shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{current_user.id } AND client_id = #{current_user.client_id})")
    @notes += RealEstateProperty.find(:all, :conditions=>['portfolios.id=? and real_estate_properties.id in (?)', @portfolio.id,@shared_folders.collect {|x| x.real_estate_property_id}],:joins=>:portfolios, :order=> "real_estate_properties.created_at desc") if !(@portfolio.nil? || @portfolio.blank? || @shared_folders.nil? || @shared_folders.blank?)
    @note = RealEstateProperty.find_real_estate_property(params[:id])  if !@portfolio.nil? && !params[:id].nil?
    @prop = RealEstatePropertyStateLog.find_by_state_id_and_real_estate_property_id(5,@note.id) if @note.nil?
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, @resource])
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    @actual = @time_line_actual
    year_to_date= params[:period] == '7' ? @end_date.to_date.month : @financial_month
    @ytd= []
    for m in 1..year_to_date
      @ytd << Date::MONTHNAMES[m].downcase
    end
    @ytd_cal_flag = "false"
    if Date.today.month == 1 && @period == "5"
      @ytd_cal_flag = "true"
      #store_income_and_cash_flow_statement_for_month(Date.today.prev_month.month.to_i,Date.today.prev_month.year.to_i)
      executive_overview_details(@financial_month,@financial_year)
    else
      executive_overview_details_for_year if  @period=="4" || @period == "7" || @period== "2"
      executive_overview_details(Date.today.month, Date.today.year) if @period == "1"
      executive_overview_details(@financial_month,@financial_year) if @period == "5"
      executive_overview_details_for_prev_year 	if @period=="6" || @period=="3"
      executive_overview_details_for_year_forecast  if @period=="8"
      property_weekly_display_calc  if @period=="9"
    end
  end

  def store_income_and_cash_flow_statement_for_prev_year
    if params[:start_date]  && (params[:period] == "3" || params[:tl_period] == "3")
      year = params[:start_date].split("-")[0].to_i
    elsif params[:tl_year] && !params[:tl_year].blank? && (params[:period] == "3" || params[:tl_period] == "3")
      year = params[:tl_year].to_i == Date.today.prev_year.year.to_i ? params[:tl_year].to_i : Date.today.prev_year.year.to_i
    elsif params[:tl_year] && !params[:tl_year].blank? && (params[:period] == "8" || params[:tl_period] == "8")
      year = params[:tl_year].to_i
    else
      year = Date.today.prev_year.year.to_i
    end
    if year.to_i >= Date.today.year.to_i
      store_income_and_cash_flow_statement_for_year_forecast
    else
      @operating_statement={}
      @cash_flow_statement={}
      year_to_date= Date.today.prev_month.month
      @ytd= []
      @month_list = []
      for m in 1..12
        @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
        @month_list <<  Date.new(year,m,1).strftime("%Y-%m-%d")
      end
      if @portfolio_summary == true
        qry = get_query_for_portfolio_summary(year)
      else
        qry = get_query_for_each_summary(year)
      end
      calculate_asset_details(year,qry)
    end
  end


  def store_income_and_cash_flow_statement # If you do any changes in this method, please do the same in dashboard_store_income_and_cash_flow_statement method
    @operating_statement={}
    @cash_flow_statement={}
    calc_for_financial_data_display
    year_to_date =(params[:period] == '7' || params[:tl_period] == "7") ? @end_date.to_date.month : @financial_month
    year = (params[:period] == '7' || params[:tl_period] == "7") ? @start_date.to_date.year : find_record_year
    @month_to_year = year_to_date
    @year = year
    @ytd= []
    @month_list = []
    @explanation = true
    if(params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
      find_quarterly_month_year
    elsif (params[:period] == "11" || params[:tl_period] == "11")
      @ytd << "IFNULL(f."+Date::MONTHNAMES[@financial_month.to_i].downcase+",0)"
    else
      for m in 1..year_to_date
        @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
        if params[:period] == "7" || params[:tl_period] == "7"
          @month_list <<  Date.new(@start_date.to_date.year,m,1).strftime("%Y-%m-%d")
        else
          @month_list <<  Date.new(Time.now.year,m,1).strftime("%Y-%m-%d")
        end
      end
    end
    year = Date.today.year if @from_dash_board == true
    if @portfolio_summary == true
      qry = get_query_for_portfolio_summary(year)
    else
      qry = get_query_for_each_summary(year)
    end
    calculate_asset_details(year,qry)
  end

  #To collect operating statement
  def calculate_asset_details(year,qry)
    find_dashboard_portfolio_display
    if qry != nil && ((@ytd && !@ytd.empty?) || (@ytd_actuals))
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      @operating_statement['operating expenses']={:budget =>0 ,:actuals =>0}
      @op_ex = IncomeAndCashFlowDetail.find(:first,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id,@resource,'operating expenses',year])
      @op_in  = IncomeAndCashFlowDetail.find(:first,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id,@resource,'operating income',year])
      for cash_row in asset_details
        if cash_row.Title.include?("discount losses")
          val ={}
          if cash_row.Parent == "cash flow statement summary" || cash_row.Parent == "CASH FLOW STATEMENT" || (params[:partial_page] == 'cash_and_receivables'  &&  remote_property(@note.accounting_system_type_id))
            @cash_flow_statement[cash_row.Title] = form_hash_of_data(cash_row)
            @operating_statement[cash_row.Title] =  form_hash_of_data(cash_row)
          else
            data = form_hash_of_data(cash_row)
            @operating_statement[cash_row.Title] = data
            @cash_flow_statement[cash_row.Title] = data if cash_row.Title == "depreciation & amortization detail" or cash_row.Title =="net income" or cash_row.Title == "CASH FLOW STATEMENT"
            if cash_row.Title=="recoverable expenses detail" or cash_row.Title=="non-recoverable expenses detail"
              @operating_statement['operating expenses'][:budget]=  @operating_statement['operating expenses'][:budget].to_f + cash_row.Budget.to_f
              @operating_statement['operating expenses'][:actuals]=  @operating_statement['operating expenses'][:actuals].to_f + cash_row.Actuals.to_f
              @operating_statement['operating expenses'][:record_id]=  cash_row.Record_id 
            end
          end
        else
          if (cash_row.Actuals.to_f !=0.0 || cash_row.Budget.to_f !=0.0)
            val ={}
            if cash_row.Parent == "cash flow statement summary" || cash_row.Parent == "CASH FLOW STATEMENT" || (params[:partial_page] == 'cash_and_receivables'  &&  remote_property(@note.accounting_system_type_id))
              @cash_flow_statement[cash_row.Title] = form_hash_of_data(cash_row)
              @operating_statement[cash_row.Title] =  form_hash_of_data(cash_row)
            else
              data = form_hash_of_data(cash_row)
              @operating_statement[cash_row.Title] = data
              @cash_flow_statement[cash_row.Title] = data if cash_row.Title == "depreciation & amortization detail" or cash_row.Title =="net income" or cash_row.Title == "CASH FLOW STATEMENT"
              if cash_row.Title=="recoverable expenses detail" or cash_row.Title=="non-recoverable expenses detail"
                @operating_statement['operating expenses'][:budget]=  @operating_statement['operating expenses'][:budget].to_f + cash_row.Budget.to_f
                @operating_statement['operating expenses'][:actuals]=  @operating_statement['operating expenses'][:actuals].to_f + cash_row.Actuals.to_f
                @operating_statement['operating expenses'][:record_id]=  cash_row.Record_id 
              end
            end
          end
        end
      end
      variant = @operating_statement['operating expenses'][:budget].to_f-@operating_statement['operating expenses'][:actuals].to_f
      percent = variant*100/@operating_statement['operating expenses'][:budget].to_f.abs rescue ZeroDivisionError
      if  @operating_statement['operating expenses'][:budget].to_f==0
        percent = ( @operating_statement['operating expenses'][:actuals].to_f == 0 ? 0 : -100 )
      end
      @operating_statement['operating expenses'][:percent] = percent
      @operating_statement['operating expenses'][:variant] = variant
      @operating_statement['operating expenses'][:status] = true
      net_income_operation_summary_report
    end
    @portfolio_summary = false
  end

  #to form the hash of line item
  def form_hash_of_data(cash_row)
    if @financial
      if !cash_row[:Record_id].nil?
        val ={:actuals => cash_row.Actuals.to_f,:budget => cash_row.Budget.to_f,:record_id=>cash_row.Record_id}
      else
        val ={:actuals => cash_row.Actuals.to_f,:budget => cash_row.Budget.to_f,:record_id=>0}
      end
    else
      if !cash_row[:Record_id].nil?
        val ={:actuals => cash_row.Actuals.to_f,:budget => cash_row.Budget.to_f,:record_id=>cash_row.Record_id}
      else
        val ={:actuals => cash_row.Actuals.to_f,:budget => cash_row.Budget.to_f,:record_id=>0}
      end
    end
    variant = val[:budget].to_f-val[:actuals].to_f
    percent = variant*100/val[:budget].to_f.abs rescue ZeroDivisionError
    if  val[:budget].to_f==0
      percent = ( val[:actuals].to_f == 0 ? 0 : -100 )
    end
    percent=0.0 if percent.to_f.nan?
    val[:percent] = percent
    val[:variant] =  variant
    val[:status] = true
    return val
  end

  def get_query_for_each_summary(year)
    find_dashboard_portfolio_display
    if params[:partial_page] == 'cash_and_receivables'  &&  remote_property(@note.accounting_system_type_id)
      adjustments =  AccountTree.find(:all,:conditions=>["title in ('CASH FLOW','ADJUSTMENTS','NET INCOME')"]).map(&:id).join(',')
      adjustment_sub_items_account_num =  AccountTree.find(:all,:conditions=>["parent_id in (#{adjustments})"]).map(&:account_num).join(',') if adjustments
      cash_items = IncomeAndCashFlowDetail.find_by_sql("select * from income_and_cash_flow_details where account_code in (#{adjustment_sub_items_account_num})").map(&:id).join(',')
      @cash_items_titles = IncomeAndCashFlowDetail.find_by_sql("select * from income_and_cash_flow_details where account_code in (#{adjustment_sub_items_account_num})").map(&:title).join(',')
      "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(child_id) as Record_id from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget , a.id as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.id IN (#{cash_items}) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.id IN (#{cash_items}) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"
    elsif @balance_sheet
      find_last_updated_items
      financial_title = find_financial_title
      "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,child_id as Record_id from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget , a.id as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title}) or (a.parent_id is null) AND k.title NOT IN ('Griffin')) AND (f.pcb_type =  'c' or f.pcb_type ='p') AND a.year=#{@last_record_year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title}) or (a.parent_id is null) AND k.title NOT IN ('Griffin')) AND f.pcb_type IN ('b') AND a.year=#{@last_record_year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"
    elsif @financial
      actual_pcb_type,budget_pcb_type = find_pcb_type
      financial_title = find_financial_title
      "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(child_id) as Record_id from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget , a.id as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title}) or (a.parent_id is null)) AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title}) or (a.parent_id is null)) AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"  if @note
    else
      actual_pcb_type,budget_pcb_type = find_pcb_type
      financial_title = find_non_financial_title
      "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(child_id) as Record_id from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget , a.id as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title}) or (a.parent_id is null)) AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget,0 as child_id  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title}) or (a.parent_id is null)) AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title" if @note
    end
  end

  # Income & cash flow details calculation for the month
  def store_income_and_cash_flow_statement_for_month(month_val=nil,year=nil)
    @operating_statement={}
    @cash_flow_statement={}
    calc_for_financial_data_display
    year_to_date= !month_val.nil? ? month_val : @financial_month
    year = Date.today.month ==1 ? Date.today.prev_year.year :  Date.today.year if year.nil?
    @current_time_period=Date.new(year,year_to_date,1)
    @ytd= []
    @ytd << "IFNULL(f."+Date::MONTHNAMES[year_to_date].downcase+",0)"
    @explanation = true
    if @portfolio_summary == true
      qry = get_query_for_portfolio_summary(year)
    else
      qry = get_query_for_each_summary(year)
    end
    calculate_asset_details(year,qry)
  end

  # Net operating income details display in exceutive summary
  def net_income_operation_summary_report(from_properties_tab = nil)
    @divide = 1
    noi_title = map_title('NOI',from_properties_tab)
    expense_title = find_expense_title(from_properties_tab)
    income_title = map_title('Op.Revenue',from_properties_tab)
    net_income_title = map_title('Net Income',from_properties_tab)
    if (@operating_statement.length > 1 and @operating_statement[noi_title])
      if @operating_statement[expense_title] && @operating_statement[income_title]
        @divide = (@operating_statement[expense_title][:actuals].abs > @operating_statement[income_title][:actuals].abs) ? @operating_statement[expense_title][:actuals].abs : @operating_statement[income_title][:actuals].abs
      else
        @divide = 1 #(@operating_statement[expense_title][:actuals].abs > @operating_statement[expense_title][:actuals].abs) ? @operating_statement[expense_title][:actuals].abs : @operating_statement[income_title][:actuals].abs
      end
      @net_income_de={}
      @net_income_de['diff'] = (@operating_statement[noi_title][:budget] - @operating_statement[noi_title][:actuals]).abs
      percent =  ((@net_income_de['diff']*100) / @operating_statement[noi_title][:budget]).abs rescue ZeroDivisionError
      if   @operating_statement[noi_title][:budget].to_f==0
        percent = ( @operating_statement[noi_title][:actuals].to_f == 0 ? 0 : -100 )
      end
      @net_income_de['diff_per'] = percent  #((@net_income_de['diff']*100) / @operating_statement['net operating income'][:budget]).abs
      @net_income_de['diff_word'] = (@operating_statement[noi_title][:budget] > @operating_statement[noi_title][:actuals]) ? 'below' : 'above'
      @net_income_de['diff_style'] =  (@net_income_de['diff_word'] == 'above') ? 'greenrow' : 'redrow'
      @net_income_detail={}
      if @operating_statement[net_income_title]
        @net_income_detail['diff'] = (@operating_statement[net_income_title][:budget] - @operating_statement[net_income_title][:actuals]).abs
        percent_net_income_detail =  ((@net_income_detail['diff']*100) / @operating_statement[net_income_title][:budget]).abs rescue ZeroDivisionError
        if   @operating_statement[net_income_title][:budget].to_f==0
          percent_net_income_detail = ( @operating_statement[net_income_title][:actuals].to_f == 0 ? 0 : -100 )
        end
        @net_income_detail['diff_per'] = percent_net_income_detail
        @net_income_detail['diff_word'] = (@operating_statement[net_income_title][:budget] > @operating_statement[net_income_title][:actuals]) ? 'below' : 'above'
        @net_income_detail['diff_style'] =  (@net_income_detail['diff_word'] == 'above') ? 'greenrow' : 'redrow'
      end
    end
  end

  # Executive summary for monthly details
  def executive_overview_details(month_val=nil,year=nil)
    store_income_and_cash_flow_statement_for_month(month_val,year)
    if @note && (find_accounting_system_type(1,@note) || find_accounting_system_type(2,@note)|| (find_accounting_system_type(0,@note) && is_commercial(@note)) || check_yardi_commercial(@note) || remote_property(@note.accounting_system_type_id) && is_commercial(@note))
      occupancy_percent_for_month(month_val,year)
      #capital_expenditure_for_month(month_val,year)
      wres_other_income_and_expense_details_for_month(month_val,year)
      lease_expirations_calculation(month_val,year)
    elsif @note && (find_accounting_system_type(3,@note) || ((find_accounting_system_type(0,@note) || check_yardi_multifamily(@note) || find_accounting_system_type(4,@note) || remote_property(@note.accounting_system_type_id))  && is_multifamily(@note)))
      wres_other_income_and_expense_details_for_month(month_val,year)
      @property_occupancy_summary =  PropertyOccupancySummary.find_by_real_estate_property_id(@note.id)
      wres_occupancy_data_calculation if !@property_occupancy_summary.nil?
      wres_rent_analysis_cal(month_val,year) # unless params[:partial_page] == 'leases' || params[:action] == 'change_date'
    end
  end


  def lease_expirations_calculation(month_val, year) # If you do any changes here, please do the same in dashboard_exp method
    ##removed code related to period for time line selector removal
    #~ year = find_selected_year(year)
    @base_rent = []
    @lease_expirations = []
    @colors = ["fd5805","4cc94f","2f48e1","974cc6","dced84"]
    @suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
    @year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?)  and year <= ? ',@suites,Date.today.year],:order=>"year desc",:limit=>1).map(&:year).max if !@suites.blank?
    @month_val = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and  month <= ? and year=?',@suites,get_month(@year),@year],:select=>"month").map(&:month).max if !@suites.blank? && @year.present?
    if @year.present? && @month_val.present?
      for i in (0 .. 3)
        start_date = Date.new(@year.to_i+i).strftime("%Y-%m-%d")
        end_date = start_date.to_date.end_of_year.strftime("%Y-%m-%d") if start_date
        end_date_string = ( i == 3 ? '' : "and lease_rent_rolls.lease_end_date <= '#{end_date}'")
        @base_rent = LeaseRentRoll.find_by_sql("select sum(lease_rent_rolls.base_rent_monthly_amount) as base_rent,sum(lease_rent_rolls.sqft) as rented_area from lease_rent_rolls,suites where lease_rent_rolls.real_estate_property_id = #{@note.id}  and lease_rent_rolls.suite_id = suites.id and lease_rent_rolls.lease_end_date >= '#{start_date}' #{end_date_string} and lease_rent_rolls.month = '#{@month_val}' and lease_rent_rolls.year = #{@year} and lease_rent_rolls.occupancy_type != 'new'")
        @vacant_suite = Suite.find_by_sql("select sum(suites.rentable_sqft) as current_vacant from suites where suites.status = 'Vacant' and suites.real_estate_property_id = #{@note.id} ")
        @suite_vacant = []
        @suite_vacant << ['ececec']
        @suite_vacant << @vacant_suite.first.current_vacant  if !@vacant_suite.empty?
        if @base_rent.all? do |base| !base.rented_area.nil?  end
          @lease_expiration_year =[]
          @lease_expiration_colors =[]
          @total_rent = []
          @total_rented_area = []
          @lease_expiration_year << ( i == 3 ? start_date.to_date.year.to_s+' & above' : start_date.to_date.year) if !@base_rent.empty?
          @lease_expiration_colors << @colors[i]  if !@base_rent.empty?
          @total_rent << @base_rent.first.base_rent if !@base_rent.empty?
          @total_rented_area << @base_rent.first.rented_area if !@base_rent.empty?
          @lease_expirations << @total_rent + @lease_expiration_year + @lease_expiration_colors + @total_rented_area
        end
      end
    end
  end

  # Executive summary for year-to-date funcationalcity
  def executive_overview_details_for_year
    @ytd_t=true
    year= find_selected_year(Date.today.year)
    calc_for_financial_data_display
    store_income_and_cash_flow_statement
    selected_month = ( params[:period] == "7" || params[:tl_period] == "7" ) ? @end_date.to_date.month : @financial_month
    selected_year = ( params[:period] == "7" || params[:tl_period] == "7" ) ? @start_date.to_date.year : year
    if @note && (find_accounting_system_type(1,@note) || find_accounting_system_type(2,@note) || (find_accounting_system_type(0,@note) && is_commercial(@note)) || check_yardi_commercial(@note) || (remote_property(@note.accounting_system_type_id) && is_commercial(@note)))
      occupancy_percent_for_month(selected_month,selected_year)  #if params[:partial] != 'capital_expenditure' && session[:wres_user] != true #Fix for other inc & exp last month error
      #capital_expenditure_for_month
      wres_other_income_and_expense_details
      lease_expirations_calculation(selected_month,Date.today.end_of_year.year)
    elsif @note && ((find_accounting_system_type(3,@note) || find_accounting_system_type(4,@note) ) || (find_accounting_system_type(0,@note)&& is_multifamily(@note)) || check_yardi_multifamily(@note) || (remote_property(@note.accounting_system_type_id) && is_multifamily(@note)))
      wres_other_income_and_expense_details#(selected_month,selected_year)
      @property_occupancy_summary = PropertyOccupancySummary.find(:first,:conditions => ["real_estate_property_id=?",@note.id],:order => "month desc")
      wres_occupancy_data_calculation if !@property_occupancy_summary.nil?
      wres_rent_analysis_cal_for_year
    end
  end

  def executive_overview_details_for_prev_year
    @ytd_t=true
    store_income_and_cash_flow_statement_for_prev_year
    if @note && (find_accounting_system_type(1,@note) || find_accounting_system_type(2,@note) || (find_accounting_system_type(0,@note) && is_commercial(@note)) || check_yardi_commercial(@note) || (remote_property(@note.accounting_system_type_id) && is_commercial(@note)))
      occupancy_percent_for_month(Date.today.prev_year.end_of_year.month,Date.today.prev_year.end_of_year.year)
      #capital_expenditure_for_month(Date.today.prev_year.end_of_year.month,Date.today.prev_year.end_of_year.year)
      wres_other_income_and_expense_details_for_prev_year
      lease_expirations_calculation(Date.today.prev_year.end_of_year.month,Date.today.prev_year.end_of_year.year)
    elsif @note && (find_accounting_system_type(3,@note) || check_yardi_multifamily(@note) || ((find_accounting_system_type(0,@note)  ||  find_accounting_system_type(4,@note) ) && is_multifamily(@note)) || (remote_property(@note.accounting_system_type_id) && is_multifamily(@note)))
      year = find_selected_year(year)
      wres_other_income_and_expense_details_for_prev_year
      @property_occupancy_summary = PropertyOccupancySummary.find(:first,:conditions => ["real_estate_property_id=?",@note.id],:order => "month desc")
      wres_occupancy_data_calculation if !@property_occupancy_summary.nil?
      wres_rent_analysis_cal(Date.today.prev_year.end_of_year.month,Date.today.prev_year.end_of_year.year)
    end
  end

  # Occupancy details diaplay for month
  def occupancy_percent_for_month(month_val=nil,year=nil)
    month= !month_val.nil? ? month_val : Date.today.prev_month.month
    if is_multifamily(@note)
      @current_time_period=Date.new(year,month,1)
      year = PropertyOccupancySummary.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
      year = year.compact.empty? ? nil : year[0].year
      os= PropertyOccupancySummary.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,year,get_month(year)],:order => "month desc",:limit =>1)
    elsif is_commercial(@note)
      find_occupancy_values
      year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
      year = year.compact.empty? ? nil : year[0].year
      os= CommercialLeaseOccupancy.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,year,get_month(year)],:order => "month desc",:limit =>1)
    end
    @occupancy_summary = os[0] if !os.nil? and !os.empty?
    @occupancy_graph ={}
    @leasing_activity ={}
    if @occupancy_summary
      #Occupancy
      act_total = @occupancy_summary.current_year_sf_vacant_actual.to_f + @occupancy_summary.current_year_sf_occupied_actual.to_f
      diff = @occupancy_summary.current_year_sf_occupied_actual.to_f - @occupancy_summary.current_year_sf_occupied_budget.to_f
      @occupancy_graph[:occupied] = {:value => @occupancy_summary.current_year_sf_occupied_actual.to_f.abs,:val_percent => (@occupancy_summary.current_year_sf_occupied_actual.to_f.abs*100)/act_total.to_f ,:diff => diff.abs,:diff_percent =>  (diff.abs*100)/@occupancy_summary.current_year_sf_occupied_budget.to_f.abs ,:style => (diff >= 0 ?  "greenrow" : "redrow3" ) ,:diff_word => (diff >= 0 ?  "above" : "below" ) }

      #Vacant
      act_total = @occupancy_summary.current_year_sf_vacant_actual.to_f + @occupancy_summary.current_year_sf_occupied_actual.to_f
      diff = @occupancy_summary.current_year_sf_vacant_actual.to_f - @occupancy_summary.current_year_sf_vacant_budget.to_f
      @occupancy_graph[:vacant] = {:value => @occupancy_summary.current_year_sf_vacant_actual.to_f.abs,:val_percent => (@occupancy_summary.current_year_sf_vacant_actual.to_f.abs*100)/act_total.to_f ,:diff => diff.abs,:diff_percent =>  (diff.abs*100)/@occupancy_summary.current_year_sf_vacant_budget.to_f.abs ,:style => (diff >= 0 ?  "greenrow" : "redrow2" )  ,:diff_word => (diff >= 0 ?  "above" : "below" )}

      #Method added for pipeline header vacanty display#
      find_vacant_for_pipeline if (params[:controller].eql?('dashboard') || params[:from_mgmt].present? || current_user.has_role?('Leasing Agent') || (params[:controller].eql?('lease') && params[:action_name].eql?("pipeline")) || params[:selected_value].present? || @pdf)
      @leasing_activity ={:new_leave => @occupancy_summary.new_leases_actual.to_f,:expire => @occupancy_summary.expirations_actual.to_f } if(!@occupancy_summary.new_leases_actual.nil? || !@occupancy_summary.expirations_actual.nil?)
      diff_a =  @occupancy_summary.new_leases_actual.to_f - @occupancy_summary.expirations_actual.to_f
      diff_b =  @occupancy_summary.new_leases_budget.to_f - @occupancy_summary.expirations_budget.to_f
      diff_d = diff_a - diff_b
      diff_percent = diff_b == 0 ? 100 : ((diff_d*100)/diff_b).abs
      @leasing_activity[:change_in_occu] = { :diff_act =>diff_a,:diff_both => diff_d,:diff_percent => diff_percent,:style =>  (diff_a >= diff_b) ? "greedrow" : "redrow"}
      diff_renewal = @occupancy_summary.renewals_actual.to_f - @occupancy_summary.renewals_budget.to_f
      #Code Modified to rectify the display issue
      @leasing_activity[:renewal] = {:actual => @occupancy_summary.renewals_actual.to_f,:diff_renew => diff_renewal.to_f ,:style => (@occupancy_summary.renewals_actual.to_f >= @occupancy_summary.renewals_budget.to_f ) ? "greenrow" : "redrow" ,:diff_word =>  (@occupancy_summary.renewals_actual.to_f >= @occupancy_summary.renewals_budget.to_f ) ? "above" : "below" }
      @leasing_activity[:renewal][:diff_percent] = (@leasing_activity[:renewal][:diff_renew].to_f * 100)/ @occupancy_summary.renewals_budget.to_f
      @percent_average = {}
      high_value = @occupancy_summary.new_leases_actual.to_f > @occupancy_summary.expirations_actual.to_f ? ( ( @occupancy_summary.new_leases_actual.to_f > @occupancy_summary.renewals_actual.to_f) ?  @occupancy_summary.new_leases_actual.to_f :  @occupancy_summary.renewals_actual.to_f )  :  ( ( @occupancy_summary.expirations_actual.to_f > @occupancy_summary.renewals_actual.to_f ) ?  @occupancy_summary.expirations_actual.to_f :  @occupancy_summary.renewals_actual.to_f )
      @percent_average = { :renewal => (@occupancy_summary.renewals_actual.to_f  * 100)/high_value ,:new_l_percent => (@occupancy_summary.new_leases_actual.to_f * 100)/high_value ,:expiration => (@occupancy_summary.expirations_actual.to_f * 100)/high_value,:change_percent => (@leasing_activity[:change_in_occu][:diff_act].to_f  * 100)/ high_value }
    end
    @mtyd = @ytd.nil? ? "0" : "1"
    @graph_month = month
    @gra_year = year
    if !(@occupancy_graph.nil? || @occupancy_graph.blank?)
      @partial_file = "/properties/sample_pie"
      @swf_file = "Pie2D.swf"
      @xml_partial_file = "/properties/sample_pie"
      @vaccant      =  @occupancy_graph[:vacant][:value].to_i
      @occupied   =   @occupancy_graph[:occupied][:value].to_i
      @vaccant_percent = (@vaccant  * 100 / (@occupancy_graph[:vacant][:value].to_f + @occupancy_graph[:occupied][:value].to_f)).abs rescue 0
      @occupied_percent = (@occupied  * 100 / (@occupancy_graph[:vacant][:value].to_f + @occupancy_graph[:occupied][:value].to_f)).abs rescue 0
      @vaccant_percent =  number_with_precision(@vaccant_percent, :precision=>2) rescue 0
      @occupied_percent =  number_with_precision(@occupied_percent, :precision=>2) rescue 0
      @start_angle = 0
      if !(@vaccant.nil? || @vaccant.blank? || @vaccant == 0 || @occupied.nil? || @occupied.blank? || @occupied == 0)
        if @vaccant <= @occupied
          @start_angle = (180 - (1.8 * ((@vaccant * 100)/(@vaccant+@occupied)  rescue ZeroDivisionError)))
        else
          @start_angle = (1.8 * ((@vaccant * 100)/(@vaccant+@occupied)  rescue ZeroDivisionError))
        end
      end
    end
    @month_lease = @occupancy_summary.month  if @occupancy_summary
  end

  # Captial Expenditure calculation for the month in executive summary
  def capital_expenditure_for_month(month_val=nil,year=nil)
    calc_for_financial_data_display
    find_dashboard_portfolio_display
    month= @financial_month
    year = Date.today.prev_month.year  if year.nil?
    year = find_selected_year(year)
    cur_month = @end_date ? @end_date : params[:start_date]
    #~ month=1
    pci = @note.try(:class).eql?(Portfolio) ? PropertyCapitalImprovement.find(:first,:conditions => ["year=? and portfolio_id = ? and month < ?",year,@note.id,Date.today.month],:select=>'month',:order => "month desc") : PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=? and month < ?",year,@note.id,Date.today.month],:select=>'month',:order => "month desc")

    if params[:tl_month].blank? && params[:period] != '5' && params[:tl_period] != '5'
      month = pci.month if !pci.nil?
    end
    query = get_query_for_capital_improvement_executive(month,year)
    asset_details = PropertyCapitalImprovement.find_by_sql(query)
    if !asset_details.empty?
      @capital_improvement = {}
      @capital_percent = {}
      tot_a = 0
      tot_b = 0
      for asset in asset_details
        if !asset.Cate.nil? and ["total tenant improvements","total leasing commissions","total building improvements","total lease costs", "total net lease costs","total loan costs"].include?(asset.Cate.downcase.strip)
          @capital_improvement[asset.Cate.downcase.strip] = asset.act.to_f
          #~ tot_a = tot_a + asset.act.to_f if !asset.act.nil?
          #~ tot_b = tot_b + asset.bud.to_f if !asset.bud.nil?
        elsif !asset.Cate.nil? and asset.Cate.downcase.strip=="total capital expenditures"
          tot_a=asset.act.to_f if !asset.act.nil?
          tot_b=asset.bud.to_f if !asset.bud.nil?
        end
      end
      for asset in asset_details
        if !asset.Cate.nil? and ["total tenant improvements","total leasing commissions","total building improvements","total lease costs", "total net lease costs","total loan costs"].include?(asset.Cate.downcase.strip)
          @capital_percent[asset.Cate.downcase.strip] =((@capital_improvement[asset.Cate.downcase.strip]*100)/tot_a)
        end
      end
      diff = tot_b - tot_a
      diff_per = tot_b !=  0.0 ? (diff * 100)/tot_b : 0
      if diff_per == 0
        diff_per = 0
      elsif diff_per.nan?
        diff_per = 0
      end
      @captial_diff={:diff => diff.abs,:tot_budget => tot_b,:diff_percent => diff_per,:style => (tot_b >= tot_a ) ?  "greenrow" : "redrow",:tot_actual => tot_a,:diff_word => (tot_b > tot_a ) ? "below" : "above",:tot_budget => tot_b}
    end
  end

  # Query for Captical improvement functionality
  def get_query_for_capital_improvement_executive(month,year)
    find_dashboard_portfolio_display
    #  insert_month = (@note.accounting_system_type_id == 3 || @note.accounting_system_type_id == 1) && @note.leasing_type=="Commercial" ? "" :  (params[:period] == "2" || params[:tl_period] == "2")   ? "AND ci.month in (#{find_month_list_for_quarterly.join(',')})" :  "AND ci.month = #{month}"
    if  (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note)
    elsif  (params[:period] == "2" || params[:tl_period] == "2")
      @cap_expenditure = 'true'
      find_quarterly_each_msg(params[:quarter_end_month].to_i,params[:tl_year].to_i)
      @cap_expenditure = 'false'
      q_months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
      insert_month =@quarter_ending_month && q_months.index(@quarter_ending_month) ? "AND ci.month = #{q_months.index(@quarter_ending_month)+1}" : "AND ci.month = #{params[:quarter_end_month].to_i}"
    else
      insert_month = "AND ci.month = #{month}"
    end
    qry_string =  @note.try(:class).eql?(Portfolio) ?   "ci.portfolio_id = #{@note.id} " : "ci.real_estate_property_id = #{@note.id} "
    if(params[:period] == "2" || params[:tl_period] == "2")  && @ytd.length == 3
      sum_string = "sum(#{@ytd[0]})+#{@ytd[1]}+#{@ytd[2]}"
    else
      sum_string = "sum(#{@ytd.join("+")})"
    end
    "select sum(actual) as act, sum(budget) as bud, Cate from ( SELECT  #{sum_string} as actual , 0 AS budget, ci.category as Cate , f.pcb_type  FROM   property_capital_improvements AS ci,property_financial_periods AS f  WHERE  #{qry_string} AND  ci.year = #{year} #{insert_month} AND  ci.category IN ('TOTAL TENANT IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASE COSTS','TOTAL CAPITAL EXPENDITURES','TOTAL NET LEASE COSTS','TOTAL LOAN COSTS') AND   f.source_id = ci.id AND   f.pcb_type ='c' AND   f.source_type = 'PropertyCapitalImprovement'  GROUP BY  ci.category UNION  SELECT  0 as actual, #{sum_string} AS budget,  ci.category as Cate,f.pcb_type   FROM property_capital_improvements AS ci,  property_financial_periods AS f WHERE #{qry_string} AND ci.year = #{year} #{insert_month} AND ci.category IN ('TOTAL TENANT IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASE COSTS','TOTAL CAPITAL EXPENDITURES','TOTAL NET LEASE COSTS','TOTAL LOAN COSTS') AND f.source_id = ci.id AND  f.pcb_type ='b' AND f.source_type = 'PropertyCapitalImprovement' GROUP BY  ci.category ) xyz group by Cate"
  end

  #to calculate pending amount
  def find_amount_pending(aging)
    aging_30_days = aging.over_30days.nil? ? 0 : aging.over_30days
    aging_60_days = aging.over_60days.nil? ? 0 : aging.over_60days
    aging_90_days = aging.over_90days.nil? ? 0 : aging.over_90days
    aging_120_days = aging.over_120days.nil? ? 0 : aging.over_120days
    amount = aging_30_days + aging_60_days + aging_90_days + aging_120_days
    return amount
  end

  #to calulate cash and receivables and displayed in performance review page
  def cash_and_receivables()
    property_suite_ids = PropertySuite.find(:all,:conditions=>["real_estate_property_id = ?",@note.id],:select=>'id') #.collect{|s| s.id} - Instead of all fields,only ids are selected
    month = (params[:tl_month].nil? || params[:tl_month].empty?) ? Date.today.prev_month.month.to_i  : params[:tl_month]
    year =  params[:tl_year].nil? ? Date.today.year.to_i : params[:tl_year]
    if Date.today.month == 1
      year = Date.today.prev_month.year
    end
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    #@default_month_and_year= 45.days.ago
    #@current_time_period=Date.new(@default_month_and_year.year,@default_month_and_year.month,1)
    @current_time_period = Date.new(Date.today.year,Date.today.month,1)
    @account_receivables_aging = true
    @financial = true
    @period = params[:period] if params[:period]
    @period = "5" if @period.nil?
    financial_function_calls
    if (@period == "4" || params[:tl_period] == "4") && (params[:tl_month].nil? || params[:tl_month] == "" )
      year_to_date= Date.today.prev_month.strftime("%m").to_i
      @months = []
      if @month_list && !@month_list.empty?
        @month_list.each do |m|
          @months << m.split("-")[1]
        end
      end
      #      @account_receivables_aging = PropertyAgedReceivable.paginate(:all,:conditions=>["property_suite_id in (?) and month in (?) and year = ? AND !(round(over_30days) = 0 AND   round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0)", property_suite_ids,@months,year],:page=>(params[:sort] ? 1 : params[:page]),:per_page=>30,:order=>params[:sort],:include=>["property_suite"]) if @months
      #      else
      #      @account_receivables_aging = PropertyAgedReceivable.paginate(:all,:conditions=>["property_suite_id in (?) and month = ? and year = ? AND !(round(over_30days) = 0 AND   round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0)", property_suite_ids,month,year],:page=>(params[:sort] ? 1 : params[:page]),:per_page=>30,:order=>params[:sort],:include=>["property_suite"])
    end
    property_name = @note.try(:class).eql?(Portfolio) ? @note.try(:name) : @note.try(:property_name)
    unless @pdf
      render :update do |page|
        if params[:from_performance_review] == "true"
          page << "jQuery('#time_line_selector').show();"
          page << "jQuery('.subheaderwarpper').show();"
        elsif params[:from_performance_review] != "true"
          page << "jQuery('#time_line_selector').show();"
          if @note && property_name.present?
            page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Cash</div>');"
          else
            page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Cash</div>');"
          end
          page << "jQuery('#id_for_variance_threshold').html('<ul class=inputcoll2 id=cssdropdown></ul>');"
        end
        if (params[:period] == "3"|| params[:tl_period] == "3" ) || ((params[:period] == "4"|| params[:tl_period] == "4" && params[:tl_month] ==''))
          page << "jQuery('#monthyear').hide();"
        else
          page << "jQuery('#monthyear').show();"
        end
        page << "jQuery('#tot_per_val').hide();"
        page.replace_html "time_line_selector", :partial => "/properties/time_line_selector", :locals => {:period => @period, :note_id => @note.id, :partial_page => "cash_and_receivables", :start_date => 0, :timeline_start => @time_line_start_date, :timeline_end => @time_line_end_date } if !params[:start_date] && params[:tl_month].blank?
        page.replace_html "portfolio_overview_property_graph", :partial => "/properties/cash_and_receivables/",:locals =>{:time_line_actual => @time_line_actual,
          :time_line_rent_roll => @time_line_rent_roll,:notes_collection => @notes,:cash_flow_statement => @cash_flow_statement,:operating_statement => @operating_statement,:account_receivables_aging => @account_receivables_aging,:start_date => @start_date,:note_collection => @note}
        set_quarterly_msg(page) if params[:period] =="2" || params[:tl_period] =="2"
      end
    end
  end

  def cash_and_receivables_for_receivables() # If you do any changes here, please do the same in dashboard_cash_and_receivables_for_receivables method
    find_dashboard_portfolio_display
    portfolio_prop = RealEstateProperty.find(:all,:conditions=>['portfolios.id = ?',@note.id],:joins=>:portfolios,:select=>'real_estate_properties.id') if @note.try(:class).eql?(Portfolio)
    property_suite_ids = @note.try(:class).eql?(Portfolio) ? PropertySuite.find(:all,:conditions=>["real_estate_property_id IN (?)",portfolio_prop],:select=>'id')  : PropertySuite.find(:all,:conditions=>["real_estate_property_id = ?",@note.id],:select=>'id')
    #~ property_suite_ids = PropertySuite.find(:all,:conditions=>["real_estate_property_id = ?",@note.id],:select=>'id') #.collect{|s| s.id} - Instead of all fields,only ids are selected
    month = (params[:tl_month].nil? || params[:tl_month].empty?) ? Date.today.prev_month.month.to_i  : params[:tl_month]
    year =  params[:tl_year].nil? ? Date.today.year.to_i : params[:tl_year]
    if Date.today.month == 1
      year = Date.today.prev_month.year
    end
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    @current_time_period = Date.new(Date.today.year,Date.today.month,1)
    @financial = true
    @period = params[:period] if params[:period]
    @period = "5" if @period.nil?
    financial_function_calls
    find_redmonth_start_for_recv(find_selected_year(Date.today.year))
    value_month = @month_red_start - 12
    ## removed code for time line selector removal
    find_year = PropertyAgedReceivable.find(:first, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>["year<= #{Date.today.year} AND !(round(amount) = 0 AND round(over_30days) = 0 AND  round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0) AND property_suite_id in (?)", property_suite_ids],:include=>["property_suite"],:order => 'year desc' )
    @year = find_year.try(:year)
    #@account_receivables_aging_for_receivables = PropertyAgedReceivable.find(:all, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>["property_suite_id in (?) and month = ? and year = ? AND !(round(amount) = 0 AND round(over_30days) = 0 AND   round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0)", property_suite_ids,value_month, @year.to_i],:order=>(!@pdf ? params[:sort] : "id asc") ,:include=>["property_suite"]) #if @months
    @account_receivables_aging_for_receivables =PropertyAgedReceivable.find(:all, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>["property_suite_id in (?) and month = ? and year = ? and (abs(IFNULL(amount,0)) + abs(over_30days) + abs(over_60days) + abs(over_90days) + abs(IFNULL(over_120days,0)) + abs(IFNULL(prepaid,0))) > 0", property_suite_ids,value_month, @year.to_i],:order=>(!@pdf ? params[:sort] : "id asc") ,:include=>["property_suite"]) if !property_suite_ids.empty?
    if @account_receivables_aging_for_receivables.present?
      @account_receivables_aging_for_receivables = @account_receivables_aging_for_receivables.paginate(:page=>(params[:sort] ? params[:page] : params[:page]),:per_page=>30) unless @pdf
    end
    find_redmonth_start_for_recv(find_selected_year(Date.today.year))
    timeline_msg = find_timeline_message
    @timeline_recv = timeline_msg
    property_name = @note.try(:class).eql?(Portfolio) ? @note.try(:name) : @note.try(:property_name)
    unless @pdf
      render :update do |page|
        if @note && property_name.present?
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Account Receivables Aging #{timeline_msg}</div>');"
        else
          page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Account Receivables Aging #{timeline_msg}</div>');"
        end
        page << "jQuery('#id_for_variance_threshold').html('<ul class=inputcoll2 id=cssdropdown></ul>');"
        page <<   "jQuery('#set_quarter_msg').html('');" if params[:period] == '2' || params[:tl_period] == '2'
        page << "jQuery('.sqft_for_breadcrumb').hide();"
        page.replace_html "portfolio_overview_property_graph", :partial => "/properties/cash_and_receivables_for_receivables/",:locals =>{:time_line_actual => @time_line_actual,
          :time_line_rent_roll => @time_line_rent_roll,:notes_collection => @notes,:cash_flow_statement => @cash_flow_statement,:operating_statement => @operating_statement,:account_receivables_aging_for_receivables => @account_receivables_aging_for_receivables,:start_date => @start_date,:note_collection => @note}
      end
      return @timeline_recv
    end
  end


  #To calculate NOI in portfolio overview page
  def property_performance_noi_calculation(property_id,period)
    @note = RealEstateProperty.find_real_estate_property(property_id)
    @period = period
    if @period == "4"
      store_income_and_cash_flow_statement
    elsif @period == "5"
      store_income_and_cash_flow_statement_for_month
    else
      store_income_and_cash_flow_statement
    end
  end

  #calculates noi of all properties in particular portfolio
  def find_net_operating_income_summary_portfolio(portfolio_id,period)
    property_ids = RealEstateProperty.find(:all,:conditions => ["portfolios.id = ? and real_estate_properties.user_id =? and real_estate_properties.client_id = #{current_user.client_id}",portfolio_id, current_user.id],:joins=>:portfolios)
    portfolio = Portfolio.find_by_id(portfolio_id)
    property_ids += portfolio.real_estate_properties.find_by_sql("SELECT * FROM real_estate_properties WHERE id in (SELECT real_estate_property_id FROM shared_folders WHERE is_property_folder = 1 AND user_id = #{current_user.id} and client_id = #{current_user.client_id})")
    @property_ids = property_ids.collect{|x|x.id}.split(',').join(',')
    @portfolio_summary = true
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id IN (?) and resource_type=? ",@property_ids, @resource])
    if period == "4"
      year = Date.today.year  if year.nil?
    else
      year = Date.today.prev_month.year  if year.nil?
    end
    ((period == "4") ? store_income_and_cash_flow_statement  : store_income_and_cash_flow_statement_for_month(nil,year)) #if (!@time_line_actual.empty?)
  end

  # query to find noi of all properties in portfolio overview
  def get_query_for_portfolio_summary(year)
    if !@property_ids.empty?
      financial_title = find_financial_title_summary
      qry = "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget from (SELECT k.title as Parent, a.title as Title, f.pcb_type,sum(#{@ytd.join("+")}) as actuals, 0 as budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id in (#{@property_ids}) AND a.resource_type = #{@resource} AND k.title IN (#{financial_title}) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' group by Title UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals,sum(#{@ytd.join("+")}) as budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id in (#{@property_ids}) AND a.resource_type = #{@resource} AND k.title IN (#{financial_title}) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' group by Title) xyz group by Parent, Title"
    end
  end

  # query to find noi of all properties in portfolio overview
  def wres_get_query_for_portfolio_summary(year)
    if !@property_ids.empty?
      qry = "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget , sum(variance) as Variance from (SELECT k.title as Parent, a.title as Title, f.pcb_type,sum(#{@ytd.join("+")}) as actuals, 0 as budget , 0 as variance FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id in (#{@property_ids}) AND a.resource_type = #{@resource} AND k.title IN ('operating statement summary') AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' group by Title UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals,sum(#{@ytd.join("+")}) as budget,0 as variance FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id in (#{@property_ids}) AND a.resource_type = #{@resource} AND k.title IN ('operating statement summary') AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' group by Title UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals,0 as budget, sum(#{@ytd.join("+")}) as variance  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id in (#{@property_ids}) AND a.resource_type = #{@resource} AND k.title IN ('operating statement summary') AND f.pcb_type IN ('var_amt') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' group by Title) xyz group by Parent, Title"
    end
  end

  # To check whether 12 month budget exists for a particular property
  def income_and_budget_exists(property_id)
    income_budget = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",property_id, @resource])
    !income_budget.empty? ? true : false
  end

  # To check whether lease exists for a particular property
  def lease_exists(property_id)
    lease = PropertySuite.find(:first,:conditions => ["real_estate_property_id=? ",property_id])
    occupancy = PropertyOccupancySummary.find(:first,:conditions => ["real_estate_property_id=? ",property_id])
    (!lease.nil? && !occupancy.nil?) ? true : false
  end

  #To find direction of arrow icon should be displayed
  def up_or_down(actual, budget)
    (actual >= budget) ? 'up' : 'down'
  end

  #To find color to display good or bad based on budget and actual values for expense
  def expense_color(actual, budget)
    (actual > budget) ? 'red' : 'green'
  end

  #To find color to display good or bad based on budget and actual values for income
  def income_color(actual, budget)
    (actual >= budget) ? 'green' : 'red'
  end

  #to display noi ,capexp,occupancy in performance review page
  def portfolio_overview_noi_capital_exp_occupancy(id,year=nil)
    calc_for_financial_data_display
    if  @period == "4"
      year_to_date= @financial_month
      year = @financial_year
      @ytd= []
      @month_list = []
      for m in 1..year_to_date
        @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
        @month_list <<  Date.new(Time.now.year,m,1).strftime("%Y-%m-%d")
      end
    elsif @period =="5"
      year_to_date= @financial_month
      year = @financial_year if year.nil?
      @current_time_period=Date.new(year,year_to_date,1)
      @ytd= []
      @ytd << "IFNULL(f."+Date::MONTHNAMES[year_to_date].downcase+",0)"
    end
    connection = ActiveRecord::Base.connection();
    connection.execute("DROP TABLE  IF EXISTS tmp_table")
    connection.execute("CREATE TABLE tmp_table (id INT,portfolio_id INT,property_name VARCHAR(100),city VARCHAR(100),province VARCHAR(100),noi_c double,bud double,var double,
         act_c double,bud_c double,var_c double,current_year_sf_occupied_actual  double,current_year_sf_occupied_budget  double,occupancy_percentage  double,act_m double,bud_m double,var_m double,current_year_units_occupied_actual  double,current_year_units_vacant_actual  double,accounting_system_type_id INT,leasing_type VARCHAR(100),revenue_act double,expense_act double,revenue_bud double,expense_bud double,noi_actulas double,noi_budget double,current_year_sf_vacant_actual  double,current_year_sf_vacant_budget  double,occupied_percentage double,vacant_percentage double)")
    sort = params[:sort] ?  params[:sort] : "id"
    real_estate_properties_id = find_real_estate_properties_for_navigation_bar
    real_estate_properties_id.each do |p|
      is_property_exists = connection.execute("select id from tmp_table where id = #{p.id}")
      if is_property_exists == []
        connection.execute("INSERT INTO tmp_table(id,portfolio_id,property_name,city,province,accounting_system_type_id,leasing_type)  VALUES(#{p.id},#{p.portfolio_id},'#{p.portfolio_name}','#{p.city}','#{p.province}',#{p.accounting_system_type_id},'#{p.leasing_type}')")
      end
      month_qr = find_accounting_system_type(1,p)  && p.leasing_type=="Commercial" ? "" : "HAVING max(ci.month)"
      max_month = PropertyCapitalImprovement.find_by_sql("SELECT max(ci.month) as month,id FROM property_capital_improvements ci WHERE ci.category IN ('TOTAL TENANT IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASE COSTS','TOTAL NET LEASE COSTS','TOTAL LOAN COSTS') AND ci.real_estate_property_id = #{p.id}  AND ci.year=#{Date.today.year} #{month_qr}")
      insert_noi_details(id,year,p,connection)
      insert_occupancy_details(p.id,connection,year,id)
      if p && (((find_accounting_system_type(2,p) || find_accounting_system_type(0,p) || check_yardi_commercial(p)) && p.leasing_type=="Commercial" && !max_month.empty?) || (find_accounting_system_type(1,p)  && p.leasing_type=="Commercial"))
        insert_capital_expenditure_details(p.id,connection,year,id,p) if p
      elsif  p && (((find_accounting_system_type(2,p) || find_accounting_system_type(0,p)) && p.leasing_type=="Commercial" && max_month.empty?) ||  ((find_accounting_system_type(3,p) || find_accounting_system_type(0,p) || find_accounting_system_type(2,p) || find_accounting_system_type(4,p) || check_yardi_multifamily(p) ) &&  p.leasing_type=="Multifamily") || remote_property(p.accounting_system_type_id))
        insert_maintenance_details(p.id,connection,year,id,p)
      end
    end
    real_properties = connection.execute("select * from tmp_table where portfolio_id = #{id} order by #{sort}");
    real_estate_properties = []
    real_properties.each do |r|
      real_estate_properties << r
    end
    @real_properties = real_estate_properties.paginate(:page =>params[:page],:per_page => 12)
    return @real_properties
  end

  def insert_noi_details(id,year,p,connection)
    @note = p
    @period == "4" ? store_income_and_cash_flow_statement : store_income_and_cash_flow_statement_for_month
    income_title = map_title('Op.Revenue')
    expense_title=@expense_title
    noi_title = map_title('NOI')
    noi_qry = "SELECT r.id, r.portfolio_id, r.property_name,sum(V.actual) noi_c, sum(V.budget) bud, sum(actual-budget) as var,accounting_system_type_id as account,leasing_type as lease FROM real_estate_properties r LEFT JOIN ( SELECT k.resource_id, IF(f.pcb_type='c',#{@ytd.join("+")},0) as actual, IF(f.pcb_type='b',#{@ytd.join("+")},0) as budget FROM property_financial_periods f , income_and_cash_flow_details k WHERE f.source_id IN ( SELECT i.id FROM income_and_cash_flow_details i WHERE i.resource_id IN (SELECT r.id FROM real_estate_properties r WHERE r.portfolio_id = #{id} ) AND i.title='#{noi_title}' AND i.year=#{year}) AND f.source_type = 'IncomeAndCashFlowDetail' AND f.pcb_type IN ('c','b') AND k.id=f.source_id ) V ON r.id = V.resource_id WHERE r.id = #{p.id} GROUP BY r.id, r.portfolio_id, r.property_name"
    noi_details = connection.execute(noi_qry)
    for cash_row in noi_details
      cty_prov = RealEstateProperty.find_by_sql("SELECT  a.city as cty,a.province as prov FROM real_estate_properties r, addresses a WHERE r.address_id = a.id and r.id = #{cash_row[0]}")
      city = cty_prov.empty? ? "" : cty_prov[0].cty
      province = cty_prov.empty? ? "" : cty_prov[0].prov
      cash_row[2] = CGI::escape(cash_row[2]) unless cash_row[2].nil? || cash_row[2] ==""
      cash_row[3] = CGI::escape(cash_row[3]) unless cash_row[3].nil? || cash_row[3] ==""
      cash_row[4] = CGI::escape(cash_row[4]) unless cash_row[4].nil? || cash_row[4] ==""
      cash_row[5] = CGI::escape(cash_row[5]) unless cash_row[5].nil? || cash_row[5] ==""
      city = CGI::escape(city) unless city ==""
      province = CGI::escape(province) unless province ==""
      cash_row[3] = cash_row[3].nil? ? 'NULL' : cash_row[3]
      cash_row[4] = cash_row[4].nil? ? 'NULL' : cash_row[4]
      cash_row[5] = cash_row[5].nil? ? 'NULL' : cash_row[5]
      cash_row[6] = cash_row[6].nil? ? 'NULL' : cash_row[6]
      cash_row[7] = cash_row[7].nil? ? 'NULL' : cash_row[7]
      if @operating_statement[income_title] && @operating_statement[expense_title] && @operating_statement[noi_title]
        insert_qry = connection.execute("INSERT INTO tmp_table(id,portfolio_id,property_name,city,province,noi_c,bud,var,accounting_system_type_id,leasing_type,revenue_act,expense_act,revenue_bud,expense_bud,noi_actulas,noi_budget)  VALUES(#{cash_row[0]},#{cash_row[1]},'#{cash_row[2]}','#{city}','#{province}',#{cash_row[3]},#{cash_row[4]},#{cash_row[5]},#{cash_row[6]},'#{cash_row[7]}',#{@operating_statement[income_title][:actuals]},#{@operating_statement[expense_title][:actuals]},#{@operating_statement[income_title][:budget]},#{@operating_statement[expense_title][:budget]},#{@operating_statement[noi_title][:actuals]},#{@operating_statement[noi_title][:budget]})")
      else
        insert_qry = connection.execute("INSERT INTO tmp_table(id,portfolio_id,property_name,city,province,noi_c,bud,var,accounting_system_type_id,leasing_type)  VALUES(#{cash_row[0]},#{cash_row[1]},'#{cash_row[2]}','#{city}','#{province}',#{cash_row[3]},#{cash_row[4]},#{cash_row[5]},#{cash_row[6]},'#{cash_row[7]}')")
      end
    end
  end

  #To calculate total noi
  def find_noi_total
    @net_income_de = {}
    if @operating_statement && @operating_statement.length > 1
      connection = ActiveRecord::Base.connection();
      income_expense_values = connection.execute("select sum(revenue_act) as r_actuals,sum(expense_act) as e_actuals,sum(revenue_bud) as r_budget,sum(expense_bud) as e_budget,sum(noi_actulas) as noi_actulas,sum(noi_budget) as noi_budget from tmp_table where portfolio_id = #{@portfolio.id}")
      income_expense_values.each do |income_expense_value|
        @operating_statement['income']={:budget =>0 ,:actuals =>0}
        @operating_statement['expense']={:budget =>0 ,:actuals =>0}
        @operating_statement['noi']={:budget =>0 ,:actuals =>0}
        @operating_statement['income'][:actuals] = income_expense_value[0].to_f
        @operating_statement['expense'][:actuals] = income_expense_value[1].to_f
        @operating_statement['income'][:budget] = income_expense_value[2].to_f
        @operating_statement['expense'][:budget] = income_expense_value[3].to_f
        @operating_statement['noi'][:actuals] = income_expense_value[4].to_f
        @operating_statement['noi'][:budget] = income_expense_value[5].to_f
        @net_income_de['diff'] = (@operating_statement['noi'][:budget] - @operating_statement['noi'][:actuals]).abs
        percent =  ((@net_income_de['diff']*100) / @operating_statement['noi'][:budget]).abs rescue ZeroDivisionError
        if   @operating_statement['noi'][:budget].to_f==0
          percent = ( @operating_statement['noi'][:actuals].to_f == 0 ? 0 : -100 )
        end
        @net_income_de['diff_per'] = percent  #((@net_income_de['diff']*100) / @operating_statement['net operating income'][:budget]).abs
        @net_income_de['diff_word'] = (@operating_statement['noi'][:budget] > @operating_statement['noi'][:actuals]) ? 'below' : 'above'
        @net_income_de['diff_style'] =  (@net_income_de['diff_word'] == 'above') ? 'greenrow' : 'redrow'
        if !@operating_statement['expense'].nil?
          @divide = (@operating_statement['expense'][:actuals].abs > @operating_statement['income'][:actuals].abs) ? @operating_statement['expense'][:actuals].abs : @operating_statement['income'][:actuals].abs
        elsif !@operating_statement['expense'].nil?
          @divide = (@operating_statement['expense'][:actuals].abs > @operating_statement['expense'][:actuals].abs) ? @operating_statement['expense'][:actuals].abs : @operating_statement['income'][:actuals].abs
        end
      end
    end
  end


  def find_occupied_and_vacant_actual_total
    connection = ActiveRecord::Base.connection();
    occupied_and_vacant_values = connection.execute("select sum(current_year_sf_occupied_actual) as 	current_year_sf_occupied_actual,sum(current_year_sf_vacant_actual) as current_year_sf_vacant_actual,sum(current_year_units_occupied_actual) as current_year_units_occupied_actual,sum(current_year_units_vacant_actual) as current_year_units_vacant_actual,avg(occupied_percentage) as occupied_percentage,avg(vacant_percentage) as vacant_percentage,sum(current_year_sf_occupied_budget) as current_year_sf_occupied_budget from tmp_table where portfolio_id = #{@portfolio.id}")
    occupied_and_vacant_values.each do |occupied_and_vacant_value|
      @occupied = @portfolio.leasing_type == "Multifamily" ? occupied_and_vacant_value[2] : occupied_and_vacant_value[0]
      @vaccant = @portfolio.leasing_type == "Multifamily" ? occupied_and_vacant_value[3] : occupied_and_vacant_value[1]
      @occupied = @occupied.to_f if !@occupied.nil?
      @vaccant = @vaccant.to_f if !@vaccant.nil?
      @occupied_percent = number_with_precision(occupied_and_vacant_value[4].to_f, :precision=>2) rescue 0
      @vaccant_percent =  number_with_precision(occupied_and_vacant_value[5].to_f, :precision=>2) rescue 0
      @occupied_budget = occupied_and_vacant_value[6].to_f
      if @occupied  && @occupied_budget
        @sqft_difference = @occupied_budget.nil? ? @occupied  :  @occupied_budget  - @occupied
        @sqft_percentage = ((@occupied_budget - @occupied)/@occupied_budget)*100
        @occu_change =(@occupied.round >= @occupied_budget.round) ? 'greenrow' : 'redrow'
        @color_icon = (@occupied.round >= @occupied_budget.round) ? 'greenarrowup' : 'downarrow_red'
        @occu_change_word = (@occupied.round >= @occupied_budget.round) ? 'above' : 'below'
      elsif @vaccant
        @occupied = @occupied.to_f
        @sqft_difference = @occupied_budget.nil? ? @occupied  :  @occupied_budget  - @occupied
        @sqft_percentage = (@occupied_budget == 0 &&  @occupied == 0)  ? 0 : ((@occupied_budget - @occupied)/@occupied_budget)*100
        @occu_change =(@occupied.round >= @occupied_budget.round) ? 'greenrow' : 'redrow'
        @color_icon = (@occupied.round >= @occupied_budget.round) ? 'greenarrowup' : 'downarrow_red'
        @occu_change_word = (@occupied.round >= @occupied_budget.round) ? 'above' : 'below'
      end
    end
  end


  def insert_maintenance_details(property_id,connection,year,id,p)
    calc_for_financial_data_display
    acc_sys_type=AccountingSystemType.find_by_id(p.accounting_system_type_id).try(:type_name)
    title=if acc_sys_type=="Real Page"
      'maintenance projects'
    elsif acc_sys_type=="AMP Excel"
      'Capital Expenditures'
    else
      'capital expenditures'
    end
    if p && remote_property(p.accounting_system_type_id)
      if @period == "4"
        maintenance_qry = "select r.id, r.portfolio_id, r.property_name, sum(act) as act_m, sum(bud) as bud_m, (sum(bud) - sum(act)) as var_m from real_estate_properties r LEFT JOIN (select pf1.#{Date::MONTHNAMES[@financial_month]} as act,pf2.#{Date::MONTHNAMES[@financial_month]} as bud,ic.resource_id as rid  from income_and_cash_flow_details ic  left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf1.pcb_type = 'c_ytd'  left    join property_financial_periods pf2 on pf2.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf2.pcb_type = 'b_ytd'  where ic.resource_id =  #{property_id} and ic.year =  #{year} and  title IN ('A/D-TENANT/LEASEHOLD IMPROVEMENTS ','REAL ESTATE UNDER DEVELOPMENT','TENANT IMPROVEMENTS','LEASEHOLD IMPROVEMENTS','LAND IMPROVEMENTS','TOTAL REAL ESTATE UNDER DEVELOPMENT','A/D-LAND IMPROVEMENTS') limit 1) v ON r.id = rid GROUP BY rid;"
      elsif @period == "5"
        maintenance_qry = "select r.id, r.portfolio_id, r.property_name, sum(act) as act_m, sum(bud) as bud_m, (sum(bud) - sum(act)) as var_m from real_estate_properties r LEFT JOIN (select pf1.#{Date::MONTHNAMES[@financial_month]} as act, pf2.#{Date::MONTHNAMES[@financial_month]} as bud, ic.resource_id as rid from income_and_cash_flow_details ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf1.pcb_type = 'c' left join property_financial_periods pf2 on pf2.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf2.pcb_type = 'b' where ic.resource_id = #{property_id} and ic.year = #{year} and title IN ('A/D-TENANT/LEASEHOLD IMPROVEMENTS ','REAL ESTATE UNDER DEVELOPMENT','TENANT IMPROVEMENTS','LEASEHOLD IMPROVEMENTS','LAND IMPROVEMENTS','TOTAL REAL ESTATE UNDER DEVELOPMENT','A/D-LAND IMPROVEMENTS') limit 1) v ON r.id = rid GROUP BY rid;"
      end
    else
      #maintenance_qry = "SELECT r.id, r.portfolio_id, r.property_name,sum(V.actual) noi_c, sum(V.budget) bud, sum(actual-budget) as var FROM real_estate_properties r LEFT JOIN ( SELECT k.resource_id, IF(f.pcb_type='c',#{@ytd.join('+')},0) as actual, IF(f.pcb_type='b',#{@ytd.join('+')},0) as budget FROM property_financial_periods f , income_and_cash_flow_details k WHERE f.source_id IN ( SELECT i.id FROM income_and_cash_flow_details i WHERE i.resource_id = #{property_id} AND i.title='#{title}' AND i.year=#{year}) AND f.source_type = 'IncomeAndCashFlowDetail' AND f.pcb_type IN ('c','b') AND k.id=f.source_id ) V ON r.id = V.resource_id WHERE  r.portfolio_id = #{id} GROUP BY r.id, r.portfolio_id, r.property_name;"
      if @period == "4"
        maintenance_qry = "select r.id, r.portfolio_id, r.property_name, pf1.#{Date::MONTHNAMES[@financial_month]} as act_m, pf2.#{Date::MONTHNAMES[@financial_month]} as bud_m, (pf2.#{Date::MONTHNAMES[@financial_month]} - pf1.#{Date::MONTHNAMES[@financial_month]}) as var_m from income_and_cash_flow_details ic     left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf1.pcb_type = 'c_ytd'   left join property_financial_periods pf2 on pf2.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf2.pcb_type = 'b_ytd'  left join real_estate_properties r on r.id = ic.resource_id     where ic.resource_id = #{property_id} and ic.year = #{year} and title= '#{title}' limit 1;"
      elsif @period == "5"
        maintenance_qry = "select r.id, r.portfolio_id, r.property_name, pf1.#{Date::MONTHNAMES[@financial_month]} as act_m, pf2.#{Date::MONTHNAMES[@financial_month]} as bud_m, (pf1.#{Date::MONTHNAMES[@financial_month]} - pf2.#{Date::MONTHNAMES[@financial_month]}) as var_m from income_and_cash_flow_details ic     left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf1.pcb_type = 'c' left join property_financial_periods pf2 on pf2.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf2.pcb_type = 'b'  left join real_estate_properties r on r.id = ic.resource_id     where ic.resource_id = #{property_id} and ic.year = #{year} and title= '#{title}' limit 1;"
      end
    end
    maintenance_details = connection.execute(maintenance_qry)
    for main_row in maintenance_details
      if !(main_row[3] == nil && main_row[4] == nil && main_row[5] == nil)
        connection.execute("update tmp_table set act_m=#{main_row[3].to_f},bud_m=#{main_row[4].to_f},var_m=#{main_row[5].to_f} where (id =#{main_row[0].to_i} and portfolio_id = #{main_row[1].to_i});")
      end
    end
  end

  def insert_occupancy_details(property_id,connection,year,id)
    if is_multifamily(@note)
      find_multifamily_occupancy(property_id,connection,year,id)
    elsif is_commercial(@note)
      find_commercial_occupancy(property_id,connection,year,id)
    end
    occupancy_details = connection.execute(@occupancy_qry) if !@occupancy_qry.nil? && @occupancy_qry != ""

    if is_multifamily(@note)
      if occupancy_details
        for occ_row in occupancy_details
          occ_row_2 = occ_row[2].nil? ? 'NULL' : "'#{occ_row[2]}'"
          occ_row_3 = occ_row[3].nil? ? 'NULL' : "'#{occ_row[3]}'"
          occ_row_4 = occ_row[4].nil? ? 'NULL' : "'#{occ_row[4]}'"
          occ_row_5 = occ_row[5].nil? ? 'NULL' : "'#{occ_row[5]}'"
          occ_row_6 = occ_row[6].nil? ? 'NULL' : "'#{occ_row[6]}'"
          occ_row_7 = occ_row[7].nil? ? 'NULL' : "'#{occ_row[7]}'"
          occ_row_8 = occ_row[8].nil? ? 'NULL' : "'#{occ_row[8]}'"
          year_occ = @max_year
          property_occupancy = find_property_occupancy_summary(property_id,year_occ)
          if  property_occupancy && property_occupancy.current_year_units_occupied_actual == 0 && property_occupancy.current_year_units_vacant_actual ==0
            @occupied_percent = 'NULL'
          else
            @occupied_percent = !(property_occupancy.nil? || property_occupancy.blank?) ?  ((property_occupancy.current_year_units_occupied_actual * 100) / (property_occupancy.current_year_units_occupied_actual + property_occupancy.current_year_units_vacant_actual.to_f)).round  : "0"
          end
          if property_occupancy
            #@vacant_pecent=!(property_occupancy.current_year_sf_vacant_actual.nil? || property_occupancy.current_year_sf_vacant_actual.blank? || property_occupancy.current_year_sf_occupied_actual.nil? || property_occupancy.current_year_sf_occupied_actual.blank? ) ? ((property_occupancy.current_year_sf_vacant_actual.to_f/(property_occupancy.current_year_sf_occupied_actual.to_f+property_occupancy.current_year_sf_vacant_actual).to_f)*100).round : "0"
            @vacant_pecent = @occupied_percent.nil? ? 0 : (100 - @occupied_percent.to_f)
            insert_qry = connection.execute("update tmp_table set current_year_sf_occupied_actual=#{occ_row_2},current_year_sf_occupied_budget=#{occ_row_3},occupancy_percentage=#{occ_row_4},current_year_units_occupied_actual=#{occ_row_5},current_year_units_vacant_actual=#{occ_row_6},current_year_sf_vacant_actual=#{occ_row_7},current_year_sf_vacant_budget=#{occ_row_8},occupied_percentage = #{@occupied_percent},vacant_percentage =#{@vacant_pecent} where id=#{occ_row[1]}")
          end
        end
      end
    end
    if @note.leasing_type != "Multifamily"
      if occupancy_details
        for occ_row in occupancy_details
          occ_row_2 = occ_row[2].nil? ? 'NULL' : "'#{occ_row[2]}'"
          occ_row_3 = occ_row[3].nil? ? 'NULL' : "'#{occ_row[3]}'"
          occ_row_4 = occ_row[4].nil? ? 'NULL' : "'#{occ_row[4]}'"
          occ_row_5 = occ_row[5].nil? ? 'NULL' : "'#{occ_row[5]}'"
          occ_row_6 = occ_row[6].nil? ? 'NULL' : "'#{occ_row[6]}'"
          year_occ = @max_year
          property_occupancy = find_commercial_lease_occupancy(property_id,year_occ)
          if  (property_occupancy && property_occupancy.current_year_sf_occupied_actual == 0 && property_occupancy.current_year_sf_vacant_actual ==0) || (property_occupancy && property_occupancy.current_year_sf_occupied_actual.nil? )
            @occupied_percent = 'NULL'
          else
            @occupied_percent = !(property_occupancy.nil? || property_occupancy.blank?) ?  ((property_occupancy.current_year_sf_occupied_actual * 100) / (property_occupancy.current_year_sf_occupied_actual + property_occupancy.current_year_sf_vacant_actual.to_f))  : "0"
          end
          if property_occupancy
            @occupied_percent =  number_with_precision(@occupied_percent, :precision=>2) rescue 0
            @vacant_pecent = @occupied_percent.nil? ? 0 : (100 - @occupied_percent.to_f)
            @vacant_pecent =  number_with_precision(@vacant_pecent, :precision=>2) rescue 0
            insert_qry = connection.execute("update tmp_table set current_year_sf_occupied_actual=#{occ_row_2},current_year_sf_occupied_budget=#{occ_row_3},occupancy_percentage=#{occ_row_4},current_year_sf_vacant_actual=#{occ_row_5},current_year_sf_vacant_budget=#{occ_row_6},occupied_percentage = #{@occupied_percent},vacant_percentage =#{@vacant_pecent} where id=#{occ_row[1]}")
          end
        end
      end
    end
  end

  def insert_capital_expenditure_details(property_id,connection,year,id,p)
    month_qr = find_accounting_system_type(1,p)  && p.leasing_type=="Commercial" ? "" : "HAVING max(ci.month)"
    max_month_qry = connection.execute("SELECT max(ci.month) FROM property_capital_improvements ci WHERE ci.category IN ('TOTAL TENANT IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL BUILDING IMPROVEMENTS', 'TOTAL LEASE COSTS','TOTAL NET LEASE COSTS','TOTAL LOAN COSTS') AND ci.real_estate_property_id = #{property_id}  AND ci.year=#{year} #{month_qr}")
    prev_month = []
    max_month_qry.each do |m|
      prev_month << m
    end
    calc_for_financial_data_display
    prev_month = [@financial_month]  if(@period == "5")
    if prev_month[0] != nil
      month_string = (find_accounting_system_type(2,p) || find_accounting_system_type(0,p) || find_accounting_system_type(1,p)) && is_commercial(p) ? "" : "AND ci.month = #{prev_month[0]}"
      cap_exp_qry = "SELECT r.id, r.portfolio_id, r.property_name,sum(V.actual) noi_c, sum(V.budget) bud, sum(actual-budget) as var FROM real_estate_properties r LEFT JOIN  (SELECT k.real_estate_property_id,f.source_type, f.pcb_type,IF(f.pcb_type='c',(#{@ytd.join("+")}),0) as actual,IF(f.pcb_type='b',(#{@ytd.join("+")}),0) as budget FROM property_financial_periods f, property_capital_improvements k WHERE f.source_id IN (SELECT ci.id FROM property_capital_improvements ci WHERE ci.category IN ('TOTAL CAPITAL EXPENDITURES') AND ci.real_estate_property_id = #{property_id} AND ci.year=#{year} #{month_string}) AND f.`source_type`='PropertyCapitalImprovement' AND k.id=f.source_id ) V ON r.id = V.real_estate_property_id WHERE r.portfolio_id = #{id} GROUP BY r.id, r.portfolio_id, r.property_name"
    end
    cap_exp_details = connection.execute(cap_exp_qry) if prev_month[0] != nil
    if prev_month[0] != nil
      for cap_row in cap_exp_details
        if !(cap_row[3] == nil && cap_row[4] == nil && cap_row[5] == nil)
          insert_qry = connection.execute("update tmp_table set act_c ='#{cap_row[3]}',bud_c ='#{cap_row[4]}',var_c ='#{cap_row[5]}' where (id =#{cap_row[0]} and portfolio_id = #{cap_row[1]}) ")
          insert_qry = connection.execute("update tmp_table set act_m ='#{cap_row[3]}',bud_m ='#{cap_row[4]}',var_m ='#{cap_row[5]}' where (id =#{cap_row[0]} and portfolio_id = #{cap_row[1]}) ")
        end
      end
    end
  end


  def get_address(property)
    if property.nil?
      return '-'
    else
      address = ''
      address = address + property.desc.to_s if  property.desc != ''
      if property.city != ''
        address == '' ? address = address+property.city.to_s  :  address = address + ', '+property.city.to_s
      end
      if property.province != ''
        address == '' ? address = address+property.province.to_s : address = address + ', '+property.province.to_s
      end
      if property.zip != ''
        address == '' ?  address  : address = address+', '+property.zip.to_i.to_s
      end
      address == '' ?  '-' :  address
    end
  end

  #to find period in overview
  def find_time_period
    params[:period] = Date.today.month == 1 ?  "5" : "4" if params[:period].nil? || params[:period].empty?
    @period = params[:period]
  end
  #copied from proprty helper end
  def set_object_value(portfolio_id,id,options={})
    portfolio,notes,note = options[:prop_folder].eql?(true) ? note_for_shared_folder(portfolio_id,id) : note_for_nomal(portfolio_id,id)
    prop = RealEstatePropertyStateLog.find_by_state_id_and_real_estate_property_id(5,note.id) if !note.nil? rescue
    return portfolio,note,notes,prop
  end

  def note_for_shared_folder(portfolio_id,id)
    portfolio = Portfolio.find(portfolio_id)
    shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{current_user.id } AND client_id = #{current_user.client_id})")
    prop_condition = "and r.id in (#{shared_folders.collect {|x| x.real_estate_property_id}.join(',')})"  if !(portfolio.nil? || portfolio.blank? || shared_folders.nil? || shared_folders.blank?)
    notes = RealEstateProperty.find_properties_by_portfolio_id_with_cond(portfolio_id,prop_condition,"order by r.created_at desc")   if !(portfolio.nil? || portfolio.blank? || shared_folders.nil? || shared_folders.blank?)
    note = RealEstateProperty.find_real_estate_property(id)
    return portfolio,notes,note
  end

  def note_for_nomal(portfolio_id,id)
    note = RealEstateProperty.find_real_estate_property(id)
    portfolio = portfolio_id.nil? ? note.portfolio : Portfolio.find(portfolio_id)
    notes = portfolio.real_estate_properties
    return portfolio,notes,note
  end

  def load_instance_var_note
    @portfolio,@note,@notes,@prop = set_object_value(params[:portfolio_id],params[:id],{:prop_folder => params[:prop_folder] ? true : false})
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, @resource])
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    @actual = @time_line_actual
    @operating_statement,@cash_flow_statement={},{}
    @partial_file = "/properties/sample_pie"
    @swf_file = "Pie2D.swf"
    @xml_partial_file = "/properties/sample_pie"
    if params[:cur_month] || ( params[:tl_period] == "7" || params[:period] == "7")
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    tl_month =  !params[:tl_month].nil? ? params[:tl_month].to_i : params[:tl_month]
    tl_year =  !params[:tl_year].nil? ? params[:tl_year].to_i : params[:tl_year]
    if params[:tl_period] == "7" || params[:period] == "7"
      tl_month = @end_date.to_date.month
      tl_year = @start_date.to_date.year
    end
    @ytd= []
    for m in 1..12
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
    end if params[:tl_period] == "3" || params[:period] == "3"
    return tl_month,tl_year
  end

  def lease_details_calculation
    unless @prop_occup_summary.blank?
      @prop_occup_summary = @prop_occup_summary.first
      if @note.leasing_type == 'Commercial'
        change_occupancy_actual=@prop_occup_summary.new_leases_actual.to_f - @prop_occup_summary.expirations_actual.to_f
        change_occupancy_budget=@prop_occup_summary.new_leases_budget.to_f - @prop_occup_summary.expirations_budget.to_f
        current_occup_pecent_actual=((@prop_occup_summary.current_year_sf_occupied_actual.to_f/(@prop_occup_summary.current_year_sf_occupied_actual.to_f+@prop_occup_summary.current_year_sf_vacant_actual.to_f))*100).round rescue 0
        if (@prop_occup_summary.current_year_sf_vacant_budget.to_f+@prop_occup_summary.current_year_sf_occupied_budget.to_f) != 0.0
          current_occup_pecent_budget=((@prop_occup_summary.current_year_sf_occupied_budget.to_f/(@prop_occup_summary.current_year_sf_vacant_budget.to_f+@prop_occup_summary.current_year_sf_occupied_budget.to_f))*100).round rescue 0
        else
          current_occup_pecent_budget=0
        end
        current_vacant_pecent_actual=((@prop_occup_summary.current_year_sf_vacant_actual.to_f/(@prop_occup_summary.current_year_sf_occupied_actual.to_f+@prop_occup_summary.current_year_sf_vacant_actual.to_f))*100).round rescue 0
        if (@prop_occup_summary.current_year_sf_vacant_budget.to_f+@prop_occup_summary.current_year_sf_occupied_budget.to_f) != 0.0
          current_vacant_pecent_budget=((@prop_occup_summary.current_year_sf_vacant_budget.to_f/(@prop_occup_summary.current_year_sf_vacant_budget.to_f+@prop_occup_summary.current_year_sf_occupied_budget.to_f))*100).round rescue 0
        else
          current_vacant_pecent_budget=0
        end
        @leases={:renewals=>{:actual=>@prop_occup_summary.renewals_actual.to_f,:budget=>@prop_occup_summary.renewals_budget.to_f},
          :new_leases=>{:actual=>@prop_occup_summary.new_leases_actual.to_f,:budget=>@prop_occup_summary.new_leases_budget.to_f},
          :expirations=>{:actual=>@prop_occup_summary.expirations_actual.to_f,:budget=>@prop_occup_summary.expirations_budget.to_f},
          :change_in_occupancy=>{:actual=>change_occupancy_actual.to_f,:budget=>change_occupancy_budget.to_f},
          :prev_year_occupancy=>{:actual=>@prop_occup_summary.last_year_sf_occupied_actual.to_f,:budget=>@prop_occup_summary.last_year_sf_occupied_budget.to_f},
          :current_occupancy_percent=>{:actual=>current_occup_pecent_actual.to_f,:budget=>current_occup_pecent_budget.to_f},
          :current_vacant_percent=>{:actual=>current_vacant_pecent_actual.to_f,:budget=>current_vacant_pecent_budget.to_f},
          :current_occupancy=>{:actual=>@prop_occup_summary.current_year_sf_occupied_actual.to_f, :budget=>@prop_occup_summary.current_year_sf_occupied_budget.to_f},
          :current_vacant=>{:actual=>@prop_occup_summary.current_year_sf_vacant_actual.to_f, :budget=>@prop_occup_summary.current_year_sf_vacant_budget.to_f},
          :total_rentable_space=>{:actual=>(@prop_occup_summary.current_year_sf_occupied_actual.to_f + @prop_occup_summary.current_year_sf_vacant_actual.to_f ), :budget=>(@prop_occup_summary.current_year_sf_occupied_budget.to_f + @prop_occup_summary.current_year_sf_vacant_budget.to_f)}}
      else
        @wres_leases = {
          :current_vacancy=>{:units=>@prop_occup_summary.currently_vacant_leases_number.abs,
            :sqft=>((@prop_occup_summary.total_building_rentable_s * @prop_occup_summary.currently_vacant_leases_percentage)/100).round,
            :percent=>@prop_occup_summary.currently_vacant_leases_percentage },
          :vacant_leased=>{:units=>@prop_occup_summary.vacant_leased_number.abs,
            :sqft=>((@prop_occup_summary.total_building_rentable_s * @prop_occup_summary.vacant_leased_percentage)/100).round,
            :percent=>@prop_occup_summary.vacant_leased_percentage },
          :occupied_on_notice=>{:units=>@prop_occup_summary.occupied_on_notice_number.abs,
            :sqft=>((@prop_occup_summary.total_building_rentable_s * @prop_occup_summary.occupied_on_notice_percentage)/100).round,
            :percent=>@prop_occup_summary.occupied_on_notice_percentage },
          :occupied_preleased=>{:units=>@prop_occup_summary.  occupied_preleased_number.abs,
            :sqft=>((@prop_occup_summary.total_building_rentable_s * @prop_occup_summary.occupied_preleased_percentage)/100).round,
            :percent=>@prop_occup_summary.occupied_preleased_percentage },
          :net_exposure_to_vacancy=>{:units=>@prop_occup_summary.net_exposure_to_vacancy_number.abs,
            :sqft=>((@prop_occup_summary.total_building_rentable_s * @prop_occup_summary.net_exposure_to_vacancy_percentage)/100).round,
            :percent=>@prop_occup_summary.net_exposure_to_vacancy_percentage },
          :total_rentable_space=>{:units=>@prop_occup_summary.current_year_units_total_actual.abs,:sqft=>@prop_occup_summary.total_building_rentable_s ,:percent=>""}
        }
        titles = [:current_vacancy, :vacant_leased, :occupied_on_notice, :occupied_preleased, :net_exposure_to_vacancy, :total_rentable_space]
        titles.each { |title| (@wres_leases[title][:percent] == 0.0 ) ? @wres_leases[title][:percent] = 0 : ''}
      end
    end
  end

  def wres_lease_details_calculation
    lease_details_calculation
  end

  def form_hash_of_data_for_capex(capex)
    @capex_variance = {}
    @capex_variance[:b_variant] = capex.building_imp_budget.to_f - capex.building_imp_actual.to_f
    @capex_variance[:t_variant] = capex.tenant_imp_budget.to_f - capex.tenant_imp_actual.to_f
    @capex_variance[:l_com_variant] = capex.leasing_comm_budget.to_f - capex.leasing_comm_actual.to_f
    @capex_variance[:l_cos_variant] = capex.lease_cost_budget.to_f - capex.lease_cost_actual.to_f
    @capex_variance[:net_lease_variant] = capex.net_lease_bud.to_f - capex.net_lease_act.to_f
    @capex_variance[:loan_cost_variant] = capex.loan_cost_bud.to_f - capex.loan_cost_act.to_f
    @capex_variance[:b_status] = @capex_variance[:b_variant] < 0 ? false : true
    @capex_variance[:t_status] = @capex_variance[:t_variant] < 0 ? false : true
    @capex_variance[:l_com_status] = @capex_variance[:l_com_variant] < 0 ? false : true
    @capex_variance[:l_cos_status] = @capex_variance[:l_cos_variant] < 0 ? false : true
    @capex_variance[:net_lease_status] = @capex_variance[:net_lease_variant] < 0 ? false : true
    @capex_variance[:loan_cost_status] = @capex_variance[:loan_cost_variant] < 0 ? false : true
    @capex_variance[:b_percent_bar] = (capex.building_imp_actual.to_f * 100/ capex.building_imp_budget.to_f.abs) rescue ZeroDivisionError
    @capex_variance[:t_percent_bar] = (capex.tenant_imp_actual.to_f * 100/ capex.tenant_imp_budget.to_f.abs) rescue ZeroDivisionError
    @capex_variance[:l_com_percent_bar] = (capex.leasing_comm_actual.to_f * 100/ capex.leasing_comm_budget.to_f.abs) rescue ZeroDivisionError
    @capex_variance[:net_lease_percent_bar] = (capex.net_lease_act.to_f * 100/ capex.net_lease_bud.to_f.abs) rescue ZeroDivisionError
    @capex_variance[:loan_cost_percent_bar] = (capex.loan_cost_act.to_f * 100/ capex.loan_cost_bud.to_f.abs) rescue ZeroDivisionError
    @capex_variance[:l_cos_percent_bar] = (capex.lease_cost_actual.to_f * 100/ capex.lease_cost_budget.to_f.abs) rescue ZeroDivisionError
    @capex_variance[:l_tot_percent_bar] = ((total_cap_ex_actual(@cap_exp) * 100 ) / total_cap_ex_budget(@cap_exp)) rescue ZeroDivisionError
    @capex_variance[:b_percent] = @capex_variance[:b_variant] * 100/ capex.building_imp_budget.to_f.abs rescue ZeroDivisionError
    if  capex.building_imp_budget.to_f==0
      @capex_variance[:b_percent] = ( capex.building_imp_actual.to_f == 0 ? 0 : -100 )
    end
    @capex_variance[:b_percent] = 0.0 if @capex_variance[:b_percent].to_f.nan?
    @capex_variance[:t_percent] = @capex_variance[:t_variant] * 100/ capex.tenant_imp_budget.to_f.abs rescue ZeroDivisionError
    if  capex.tenant_imp_budget.to_f==0
      @capex_variance[:t_percent] = ( capex.tenant_imp_actual.to_f == 0 ? 0 : -100 )
    end
    @capex_variance[:t_percent] = 0.0 if @capex_variance[:t_percent].to_f.nan?
    @capex_variance[:l_com_percent] = @capex_variance[:l_com_variant] * 100/ capex.leasing_comm_budget.to_f.abs rescue ZeroDivisionError
    if  capex.leasing_comm_budget.to_f==0
      @capex_variance[:l_com_percent] = ( capex.leasing_comm_actual.to_f == 0 ? 0 : -100 )
    end
    @capex_variance[:l_com_percent] = 0.0 if @capex_variance[:l_com_percent].to_f.nan?
    @capex_variance[:net_lease_percent] = @capex_variance[:net_lease_variant] * 100/ capex.net_lease_bud.to_f.abs rescue ZeroDivisionError
    if  capex.net_lease_bud.to_f==0
      @capex_variance[:net_lease_percent] = ( capex.net_lease_act.to_f == 0 ? 0 : -100 )
    end
    @capex_variance[:net_lease_percent] = 0.0 if @capex_variance[:net_lease_percent].to_f.nan?

    @capex_variance[:loan_cost_percent] = @capex_variance[:loan_cost_variant] * 100/ capex.loan_cost_bud.to_f.abs rescue ZeroDivisionError
    if  capex.loan_cost_bud.to_f==0
      @capex_variance[:loan_cost_percent] = ( capex.loan_cost_act.to_f == 0 ? 0 : -100 )
    end
    @capex_variance[:loan_cost_percent] = 0.0 if @capex_variance[:loan_cost_percent].to_f.nan?

    @capex_variance[:l_cos_percent] = @capex_variance[:l_cos_variant] * 100/ capex.lease_cost_budget.to_f.abs rescue ZeroDivisionError
    if  capex.lease_cost_budget.to_f==0
      @capex_variance[:l_cos_percent] = ( capex.lease_cost_actual.to_f == 0 ? 0 : -100 )
    end
    @capex_variance[:l_cos_percent] = 0.0 if @capex_variance[:l_cos_percent].to_f.nan?
    @capex_variance[:b_percent_bar]  = @capex_variance[:b_percent_bar] > 100 ? 100 : @capex_variance[:b_percent_bar]
    @capex_variance[:t_percent_bar]  = @capex_variance[:t_percent_bar] > 100 ? 100 : @capex_variance[:t_percent_bar]
    @capex_variance[:l_com_percent_bar]  = @capex_variance[:l_com_percent_bar] > 100 ? 100 : @capex_variance[:l_com_percent_bar]
    @capex_variance[:l_cos_percent_bar]  = @capex_variance[:l_cos_percent_bar] > 100 ? 100 : @capex_variance[:l_cos_percent_bar]
    @capex_variance[:net_lease_percent_bar]  = @capex_variance[:net_lease_percent_bar] > 100 ? 100 : @capex_variance[:net_lease_percent_bar]
    @capex_variance[:loan_cost_percent_bar]  = @capex_variance[:loan_cost_percent_bar] > 100 ? 100 : @capex_variance[:loan_cost_percent_bar]
    @capex_variance[:l_tot_percent_bar]  = @capex_variance[:l_tot_percent_bar] > 100 ? 100 : @capex_variance[:l_tot_percent_bar]
    @capex_variance[:cap_ex_total_variant] = @capex_variance[:b_variant] + @capex_variance[:t_variant] + @capex_variance[:l_com_variant] + @capex_variance[:l_cos_variant] + @capex_variance[:net_lease_variant] + @capex_variance[:loan_cost_variant]
    @capex_variance[:cap_ex_total_percent] =  (total_cap_ex_budget(@cap_exp) == 0.0) ? 0 : ( @capex_variance[:cap_ex_total_variant] * 100 ) / total_cap_ex_budget(@cap_exp)
    if capex && !capex.empty? && capex.total_cap_ex_bud && capex.total_cap_ex_act
      @capex_variance[:cap_ex_total_status] = (capex.total_cap_ex_bud.to_f >= capex.total_cap_ex_act.to_f)
    else
      @capex_variance[:cap_ex_total_status] = @capex_variance[:cap_ex_total_variant] <= 0 ? false : true
    end
    return @capex_variance
  end

  def capital_expenditure_sub_method(type)
    calc_for_financial_data_display
    find_dashboard_portfolio_display
    source = @note.try(:class).eql?(Portfolio)  ? "portfolio_id"  : "real_estate_property_id"

    id = !params[:id].nil? ? params[:id]  : @portfolio.id if type != 'month'
    if params["start_date"]#=>"2010-09-01"
      sd = params["start_date"].split('-')
      tl_month,tl_year = sd[1].to_i,sd[0].to_i
    else
      unless params[:period] == "7" || params[:tl_period] == "7"
        tl_month = params[:tl_month].nil? ? Date.today.month : params[:tl_month].to_i
      else
        tl_month = @end_date.to_date.month
      end
      tl_year =(params[:period] == "2" || params[:tl_period] == '2') ? params[:tl_year] :  (type == 'month' ? (params[:tl_year].nil? ? Date.today.year : params[:tl_year].to_i) : ( type == 'year' ? Date.today.year : ( type == "month_year" ? @start_date.to_date.year : Date.today.prev_year.year)))

      if params[:tl_period] == "3" || params[:period] =="3"
        tl_year = find_selected_year(Date.today.prev_year.year)
      end
      @explanation = true
    end
    if params[:period] == "2" || params[:tl_period] == "2"
      find_quarterly_month_year_for_cap_exp
    else
      month_qry= type == 'month' ? tl_month : (type == 'year' ? Date.today.prev_month.month : ( type == "month_year" ? tl_month :1))
    end
    month_details = ['', 'january','february','march','april','may','june','july','august','september','october','november','december','january','february','march','april','may','june','july','august','september','october','november','december','january','february','march','april','may','june','july','august','september','october','november','december']
    if type == 'prev_year'
      prev_month = Date.today.prev_month.month
      arr = []
      for m in 1..12
        arr << "IFNULL(pf.#{month_details[m]},0)"
      end
      val = arr.join("+")

      pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and #{source}=?",tl_year,id],:order => "month desc")

      month_qry = pci.month if !pci.nil?
      month_qry = find_month_using_capital_improvement('',tl_year)
      month_qry = month_qry == 0 ?  1 : month_qry
    end
    ######Yearforecast conditions######
    if type == 'year_forecast'
      year =  find_selected_year(Date.today.year)

      pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and #{source}=?",year,id],:order => "month desc")

      if  (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note)
        month_qry = month_qry
      else
        month_qry = pci.month if (!pci.nil? && type != 'month')
      end
      insert_month = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : "AND ic.month = #{month_qry}"
      qry_string = @note.try(:class).eql?(Portfolio)  ? "ic.portfolio_id = #{@note.id}"  : "ic.real_estate_property_id = #{@note.id}"
      val_qry="select pf1.january as january,pf1.february as february,pf1.march as march,pf1.april as april, pf1.may as may,pf1.june as june,pf1.july as july,pf1.august as august,pf1.september as september,pf1.october as october,pf1.november as november,pf1.december as december FROM  property_capital_improvements  ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.pcb_type = 'c' and pf1.source_type = 'PropertyCapitalImprovement' where ic.tenant_name in ('TOTAL CAPITAL EXPENDITURES') and #{qry_string} #{insert_month} and ic.year= #{year}"
      k=0
      value= PropertyCapitalImprovement.find_by_sql(val_qry)
      @result = value[k].attributes.keys.select {|i| i if value[k].send(:"#{i}") == "0" }  if !value.blank?
      common_method_for_yrforecast
      year =  find_selected_year(Date.today.year)
      #~ unless @result.nil?
      #~ @month = @result.flatten.to_s
      #~ year_to_date = @financial_month
      #~ @ytd_actuals= []
      #~ for m in 1..year_to_date
      #~ if @month.include?("#{Date::MONTHNAMES[m].downcase}")
      #~ @ytd_actuals << "IFNULL(pf2."+Date::MONTHNAMES[m].downcase+",0)"
      #~ else
      #~ @ytd_actuals << "IFNULL(pf1."+Date::MONTHNAMES[m].downcase+",0)"
      #~ end
      #~ end
      #~ end
      #~ year_to_date = @financial_month + 1
      #~ year =  find_selected_year(Date.today.year)
      #~ @ytd_budget= []
      #~ for m in year_to_date..12
      #~ @ytd_budget << "IFNULL(pf2."+Date::MONTHNAMES[m].downcase+",0)"
      #~ end
    end
    ##############
    if type=='month'
      tl_month = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? 1 : tl_month
      if find_accounting_system_type(1,@note)
        pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and #{source}=?",tl_year,params[:id]],:order => "month desc")
      else
        pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? and month=? and #{source}=?",tl_year,tl_month,params[:id]],:order => "month desc")
      end
    elsif type == "month_year"
      if params[:period] == "2" ||  params[:tl_period] == "2"
        insert_month = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : "AND month in (#{find_month_list_for_quarterly.join(',')})"
        pci = PropertyCapitalImprovement.find(:first,:conditions => ["year=? #{insert_month} and #{source}=?",tl_year,params[:id]],:order => "month desc")
      else
        pci =  PropertyCapitalImprovement.find(:first,:conditions => ["year=? and month <= ? and #{source}=?",tl_year,tl_month,id],:order => "month desc")
      end
    elsif type == "year_forecast"
      pci =   PropertyCapitalImprovement.find(:first,:conditions => ["year=? and #{source}=? and month < ?",year,id,Date.today.month],:order => "month desc")
    else
      pci =  PropertyCapitalImprovement.find(:first,:conditions => ["year=? and #{source}=? and month < ?",tl_year,id,Date.today.month],:order => "month desc")
    end
    if  (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note)
      month_qry = month_qry
    else
      month_qry = pci.month if (!pci.nil? && type != 'month')
    end
    #    month_qry = (pci.collect { |n| n.month }).uniq! if type == 'month_year'
    @record_list_de = pci
    qry_cp_arr = []
    total_array =  ['TOTAL TENANT IMPROVEMENTS', 'TOTAL BUILDING IMPROVEMENTS', 'TOTAL LEASING COMMISSIONS', 'TOTAL LEASE COSTS', 'TOTAL CAPITAL EXPENDITURES','TOTAL NET LEASE COSTS','TOTAL LOAN COSTS']
    #remove month for MRI commercial and AMP commercial
    insert_month = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : "AND ci.month = #{month_qry}"
    qry_string = @note.try(:class).eql?(Portfolio)  ? "ci.portfolio_id = #{@note.id}"  : "ci.real_estate_property_id = #{@note.id}"
    if(params[:period] == '3' || params[:tl_period] == '3') && tl_year && tl_year < Date.today.year
      month_qry = find_month_using_capital_improvement('',tl_year)
      month_qry = month_qry == 0 ? 1 : month_qry
    end
    qry_cp_arr = total_array.collect { |itr| PropertyCapitalImprovement.find_by_sql("select IFNULL(pf1.#{month_details[month_qry]},0) actual, IFNULL(pf2.#{month_details[month_qry]},0) budget, ci.id id from property_capital_improvements ci left join property_financial_periods pf1 on pf1.source_id = ci.id and pf1.source_type='PropertyCapitalImprovement' and pf1.pcb_type='c' left join property_financial_periods pf2 on pf2.source_id = ci.id and pf2.source_type='PropertyCapitalImprovement' and pf2.pcb_type='b' where #{qry_string} #{insert_month} AND  ci.year = #{tl_year} AND ci.tenant_name = '#{itr}';").first } if type == 'month'
    qry_cp_arr = total_array.collect { |itr| PropertyCapitalImprovement.find_by_sql("select IFNULL(pf1.#{month_details[@financial_month]},0) actual, IFNULL(pf2.#{month_details[@financial_month]},0) budget, ci.id id from property_capital_improvements ci left join property_financial_periods pf1 on pf1.source_id = ci.id and pf1.source_type='PropertyCapitalImprovement' and pf1.pcb_type='c_ytd' left join property_financial_periods pf2 on pf2.source_id = ci.id and pf2.source_type='PropertyCapitalImprovement' and pf2.pcb_type='b_ytd' where #{qry_string} #{insert_month} AND  ci.year = #{tl_year} AND ci.tenant_name = '#{itr}';").first } if type == 'year'
    if(params[:period] == "2" || params[:tl_period] == "2") && type == 'month_year'
      find_quarterly_each_msg(params[:quarter_end_month].to_i,params[:tl_year].to_i)
      q_months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
      insert_month = (find_accounting_system_type(2,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note)) && is_commercial(@note) ? "" : (@quarter_ending_month && q_months.index(@quarter_ending_month) ? "AND ci.month = #{q_months.index(@quarter_ending_month)+1}" : "AND ci.month = #{params[:quarter_end_month].to_i}")
      if(params[:period] == "2" || params[:tl_period] == "2")  && @ytd_act.length == 3
        sum_string_act = "sum(#{@ytd_act[0]})+#{@ytd_act[1]}+#{@ytd_act[2]}"
        sum_string_bud = "sum(#{@ytd_bud[0]})+#{@ytd_bud[1]}+#{@ytd_bud[2]}"
      else
        sum_string_act = "sum(#{@ytd_act.join("+")})"
        sum_string_bud = "sum(#{@ytd_bud.join("+")})"
      end
      qry_cp_arr = total_array.collect { |itr| PropertyCapitalImprovement.find_by_sql("select #{sum_string_act} as  actual,#{sum_string_bud} as  budget, ci.id id from property_capital_improvements ci left join property_financial_periods pf1 on pf1.source_id = ci.id and pf1.source_type='PropertyCapitalImprovement' and pf1.pcb_type='c' left join property_financial_periods pf2 on pf2.source_id = ci.id and pf2.source_type='PropertyCapitalImprovement' and pf2.pcb_type='b' where #{qry_string} #{insert_month} AND  ci.year = #{tl_year} AND ci.tenant_name = '#{itr}';").first } if type == 'month_year'
    else
      qry_cp_arr = total_array.collect { |itr| PropertyCapitalImprovement.find_by_sql("select (IFNULL(pf1.#{month_details[month_qry]},0)) actual,(IFNULL(pf2.#{month_details[month_qry]},0)) budget,  ci.id id from property_capital_improvements ci left join property_financial_periods pf1 on pf1.source_id = ci.id and pf1.source_type='PropertyCapitalImprovement' and pf1.pcb_type='c_ytd' left join property_financial_periods pf2 on pf2.source_id = ci.id and pf2.source_type='PropertyCapitalImprovement' and pf2.pcb_type='b_ytd' where #{qry_string} #{insert_month} AND  ci.year = #{tl_year} AND ci.tenant_name = '#{itr}';").first } if type == 'month_year'
    end
    qry_cp_arr = total_array.collect { |itr| PropertyCapitalImprovement.find_by_sql("select IFNULL(pf1.#{month_details[month_qry]}, 0) actual, IFNULL(pf2.december, 0) budget, ci.id id from property_capital_improvements ci left join property_financial_periods pf1 on pf1.source_id = ci.id and pf1.source_type='PropertyCapitalImprovement' and pf1.pcb_type='c_ytd' left join property_financial_periods pf2 on pf2.source_id = ci.id and pf2.source_type='PropertyCapitalImprovement' and pf2.pcb_type='b_ytd' where #{qry_string} #{insert_month} AND  ci.year = #{tl_year} AND ci.tenant_name = '#{itr}';").first } if type == 'prev_year'


    if !@ytd_actuals.nil?
      qry_cp_arr = total_array.collect { |itr| PropertyCapitalImprovement.find_by_sql("select (#{@ytd_actuals} + #{@ytd_budget}) actual,(IFNULL(pf2.january,0)+IFNULL(pf2.february,0)+IFNULL(pf2.march,0)+IFNULL(pf2.april,0)+IFNULL(pf2.may,0)+IFNULL(pf2.june,0)+IFNULL(pf2.july,0)+IFNULL(pf2.august,0)+IFNULL(pf2.september,0)+IFNULL(pf2.october,0)+IFNULL(pf2.november,0)+IFNULL(pf2.december,0)) budget, ci.id id from property_capital_improvements ci left join property_financial_periods pf1 on pf1.source_id = ci.id and pf1.source_type='PropertyCapitalImprovement' and pf1.pcb_type='c' left join property_financial_periods pf2 on pf2.source_id = ci.id and pf2.source_type='PropertyCapitalImprovement' and pf2.pcb_type='b' where #{qry_string} #{insert_month} AND  ci.year = #{year} AND ci.tenant_name = '#{itr}';").first } if type == 'year_forecast'
    end
    @cap_exp = OpenStruct.new
    @cap_exp.tenant_imp_actual = qry_cp_arr[0] ? qry_cp_arr[0].actual : 0
    @cap_exp.tenant_imp_budget = qry_cp_arr[0] ? qry_cp_arr[0].budget : 0
    @cap_exp.tenant_imp_id =qry_cp_arr[0] ? qry_cp_arr[0].id : 0
    @cap_exp.leasing_comm_actual = qry_cp_arr[2] ? qry_cp_arr[2].actual : 0
    @cap_exp.leasing_comm_budget = qry_cp_arr[2] ? qry_cp_arr[2].budget : 0
    @cap_exp.leasing_comm_id = qry_cp_arr[2] ? qry_cp_arr[2].id : 0
    @cap_exp.building_imp_actual = qry_cp_arr[1] ? qry_cp_arr[1].actual : 0
    @cap_exp.building_imp_budget = qry_cp_arr[1] ? qry_cp_arr[1].budget : 0
    @cap_exp.building_imp_id = qry_cp_arr[1] ? qry_cp_arr[1].id : 0
    @cap_exp.lease_cost_actual = qry_cp_arr[3] ? qry_cp_arr[3].actual : 0
    @cap_exp.lease_cost_budget = qry_cp_arr[3] ? qry_cp_arr[3].budget : 0
    @cap_exp.lease_cost_id =qry_cp_arr[3] ? qry_cp_arr[3].id : 0

    @cap_exp.total_cap_ex_act = qry_cp_arr[4] ? qry_cp_arr[4].actual : 0
    @cap_exp.total_cap_ex_bud = qry_cp_arr[4] ? qry_cp_arr[4].budget : 0
    @cap_exp.total_cap_ex_id =qry_cp_arr[4] ? qry_cp_arr[4].id : 0

    if @note.try(:class).eql?(Portfolio)
	if qry_cp_arr[5] || PropertyCapitalImprovement.exists?(:category=>"TOTAL NET LEASE COSTS", :real_estate_property_id=>@note.id)
      @cap_exp.net_lease_act = qry_cp_arr[5] ? qry_cp_arr[5].actual : 0
      @cap_exp.net_lease_bud = qry_cp_arr[5] ? qry_cp_arr[5].budget : 0
      @cap_exp.net_lease_id = qry_cp_arr[5] ? qry_cp_arr[5].id : 0
    end
    if qry_cp_arr[6] || PropertyCapitalImprovement.exists?(:category=>"TOTAL LOAN COSTS", :real_estate_property_id=>@note.id)
      @cap_exp.loan_cost_act = qry_cp_arr[6] ? qry_cp_arr[6].actual : 0
      @cap_exp.loan_cost_bud = qry_cp_arr[6] ? qry_cp_arr[6].budget : 0
      @cap_exp.loan_cost_id = qry_cp_arr[6] ? qry_cp_arr[6].id : 0
    end
  elsif @note.try(:class).eql?(RealEstateProperty)
    if qry_cp_arr[5] || PropertyCapitalImprovement.exists?(:category=>"TOTAL NET LEASE COSTS", :real_estate_property_id=>@note.id)
      @cap_exp.net_lease_act = qry_cp_arr[5] ? qry_cp_arr[5].actual : 0
      @cap_exp.net_lease_bud = qry_cp_arr[5] ? qry_cp_arr[5].budget : 0
      @cap_exp.net_lease_id = qry_cp_arr[5] ? qry_cp_arr[5].id : 0
    end
    if qry_cp_arr[6] || PropertyCapitalImprovement.exists?(:category=>"TOTAL LOAN COSTS", :real_estate_property_id=>@note.id)
      @cap_exp.loan_cost_act = qry_cp_arr[6] ? qry_cp_arr[6].actual : 0
      @cap_exp.loan_cost_bud = qry_cp_arr[6] ? qry_cp_arr[6].budget : 0
      @cap_exp.loan_cost_id = qry_cp_arr[6] ? qry_cp_arr[6].id : 0
    end
    end
    @cap_exp.month = tl_month if type == 'month'
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1) # time line test
    @time_line_end_date = Date.new(today_year,12,31)
    remove_if_actual_and_budget_zero
  end

  def subpages_in_financial_review_sub_method(type,heading,rec_id = nil,len=nil)
    record_year = find_record_year
    title = heading
    title = map_title(heading)
    title_display = map_title(heading)
    if rec_id.nil?
      record = IncomeAndCashFlowDetail.find(:first,:conditions => ["title=? and resource_id=? and year=?",title,@note.id,record_year])
    else
      record = IncomeAndCashFlowDetail.find_by_id(rec_id)
    end
    query = IncomeAndCashFlowDetail.find(:all,:conditions => ["parent_id =?",record.id],:select => "count(*) as childers") if record
    title = title.gsub("'","?")
    remove_detail_for = ["debt service detail", "depreciation & amortization detail"]
    #if remove_detail_for.include?(heading)
    heading = heading.gsub(/\sdetail/,'')
    #end
    financial_subid = (record.nil?) ? '' :  record.id
    partial_page_title = @balance_sheet ?  "balance_sheet_sub_page" : "financial_subpage"
    if !len.nil?
      return "<a class='loader_event' trend_value='#{financial_subid}' onclick=\"partial_page='#{partial_page_title}';performanceReviewCalls('#{partial_page_title}',{financial_sub:\'#{title}\', financial_subid: #{financial_subid} });return false;\" href=\"#\" title='#{title_display[heading].nil? ? heading.titleize : title_display[heading].titleize}'>#{display_truncated_chars(title_display[heading].nil? ? heading.titleize : heading.titleize,len,true)} </a>" if (query and query.first.childers and query.first.childers.to_i > 0)
      return "<a  class='loader_event' trend_value='#{financial_subid}' onclick=\"partial_page='#{partial_page_title}';performanceReviewCalls('#{partial_page_title}',{financial_sub:\'#{title}\'});return false;\" href=\"#\" title='#{title_display[heading].nil? ? heading.titleize : title_display[heading].titleize}'>#{display_truncated_chars(title_display[heading].nil? ? heading.titleize : heading,len,true)} </a>" if heading == "Operating Expenses" || title == "Operating Expenses"
      "<span title='#{title_display[heading].nil? ? heading.titleize : title_display[heading].titleize}'>#{display_truncated_chars(title_display[heading].nil? ? heading.titleize : heading.titleize,len,true)}</span>"
    else
      return "<a class='loader_event' trend_value='#{financial_subid}' onclick=\"partial_page='#{partial_page_title}';performanceReviewCalls('#{partial_page_title}',{financial_sub:\'#{title}\', financial_subid: #{financial_subid} });return false;\" href=\"#\" title='#{title_display[heading].nil? ? heading.titleize : title_display[heading].titleize}'>#{display_truncated_chars(title_display[heading].nil? ? heading.titleize : heading.titleize,35,true)} </a>" if (query and query.first.childers and query.first.childers.to_i > 0)
      return "<a class='loader_event' trend_value='#{financial_subid}' onclick=\"partial_page='#{partial_page_title}';performanceReviewCalls('#{partial_page_title}',{financial_sub:\'#{title}\'});return false;\" href=\"#\" title='#{title_display[heading].nil? ? heading.titleize : title_display[heading].titleize}'>#{display_truncated_chars(title_display[heading].nil? ? heading.titleize : heading,35,true)} </a>" if heading == "Operating Expenses" || title == "Operating Expenses"
      if remote_property(@note.accounting_system_type_id) && (query and query.first.childers and query.first.childers.to_i == 0)
        return "<a class='loader_event' trend_value='#{financial_subid}' onclick=\"partial_page='#{partial_page_title}';performanceReviewCalls('#{partial_page_title}',{financial_sub:\'Deals\', financial_subid: #{financial_subid} });return false;\" href=\"#\" title='#{title_display[heading].nil? ? heading.titleize : title_display[heading].titleize}'>#{display_truncated_chars(title_display[heading].nil? ? heading.titleize : heading.titleize,35,true)} </a>"
      else
        "<span id='title_id' trend_value='#{financial_subid}' title='#{title_display[heading].nil? ? heading.titleize : title_display[heading].titleize}'>#{display_truncated_chars(title_display[heading].nil? ? heading.titleize : heading.titleize,33,true)}</span>"
      end

    end
  end

  def find_out_asset_details(params,year,from_properties_tab = nil)
    if session[:property__id].present? && session[:portfolio__id].blank?
      @resource = "'RealEstateProperty'"
    elsif session[:portfolio__id].present? && session[:property__id].blank?
      @resource = "'Portfolio'"
    end
    unless params[:financial_sub] == 'transactions'
      params[:financial_sub] = params[:financial_sub].gsub("?","\'") if params[:financial_sub]

      if params[:financial_sub] and params[:financial_sub] == "Operating Expenses"
        if @note && (find_accounting_system_type(1,@note) || find_accounting_system_type(2,@note))
          actual_pcb_type,budget_pcb_type = find_pcb_type
          qry = "select  Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(child_id) as Record_id from (SELECT  a.title as Title, f.pcb_type, #{@ytd.join("+")}  as actuals, 0 as budget,a.id as child_id FROM `income_and_cash_flow_details` a  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.title IN ('recoverable expenses detail','non-recoverable expenses detail') AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION   SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")}  as budget,0 as child_id FROM `income_and_cash_flow_details` a  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.title IN ('recoverable expenses detail','non-recoverable expenses detail') AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'    ) xyz group by  Title"
           @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
        elsif @note && (find_accounting_system_type(3,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note) || remote_property(@note.accounting_system_type_id))
          actual_pcb_type,budget_pcb_type = find_pcb_type
          qry = "select  Title, sum(actuals) as Actuals, sum(budget) as Budget, sum(child_id) as Record_id from (SELECT  a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget, a.id as child_id FROM `income_and_cash_flow_details` a   inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.parent_id = #{params[:financial_subid]} AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' AND a.title NOT IN ('operating expenses','net operating income','net income before depreciation','operating income','Other Income And Expense')  UNION SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as child_id FROM `income_and_cash_flow_details` a    inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.parent_id  = #{params[:financial_subid]} AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' AND a.title NOT IN ('operating expenses','net operating income','net income before depreciation','operating income','Other Income And Expense') ) xyz group by Title"
           @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry) if params[:financial_subid].present?
        end
#        @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      elsif !params[:financial_subid].blank?
        @using_sub_id = true
        find_last_updated_items(from_properties_tab)        if @balance_sheet
        unless @ytd.empty?
          qry = get_query_for_financial_sub_page(params[:financial_subid],year,false,from_properties_tab)
          @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
          if params[:action].include?("financial_subpage") || (params[:partial_page] == "financial_subpage") || params[:financial_sub]=="maintenance projects" || params[:financial_sub]=="Capital Expenditures" || params[:action].include?("balance_sheet_sub_page") || (params[:partial_page] == "balance_sheet_sub_page")
            total_qry = get_query_for_financial_sub_page(params[:financial_subid],year,true,from_properties_tab)
            @total = IncomeAndCashFlowDetail.find_by_sql(total_qry)
          end
        else
          @asset_details  = []
        end
      else
        @using_sub_id = false
        qry = get_query_for_financial_sub_page(params[:financial_sub],year,false,from_properties_tab)
        @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      end
      @explanation = true
    end
  end

  def find_financial_sub_id(from_properties_tab = nil)
    if from_properties_tab.blank?
      find_dashboard_portfolio_display
    else
      @resource = "'RealEstateProperty'"
    end
    #    find_dashboard_portfolio_display
    params[:financial_sub] = params[:financial_sub].gsub("?","\'") if params[:financial_sub]
    record_year = find_record_year
    title =  params[:financial_sub]
    title = map_title(title)
    if @balance_sheet && (title == "OF ALL" || title == "ASSETS" || title == "CASH")
      record = IncomeAndCashFlowDetail.find(:last,:conditions => ["title=? and resource_id=? and year=?",title,@note.id,record_year])
    elsif @note && remote_property(@note.accounting_system_type_id) && params[:partial_page] == "capital_expenditure"
      record = IncomeAndCashFlowDetail.find(:last,:conditions => ["title=? and resource_id=? and year=?",title,@note.id,record_year])
    else
      record = IncomeAndCashFlowDetail.find(:first,:conditions => ["title=? and resource_id=? and resource_type = (#{@resource}) and year=?",title,@note.id,record_year])
    end

    params[:financial_subid] = record.id if record
    bread_crumb = breadcrumb_in_financial(params[:financial_sub],params[:financial_subid])
    if record
      return record.id
    else
      return ''
    end
  end

  def find_financial_sub_items(title,from_properties_tab=nil)
    params[:financial_sub] =title
    params[:financial_subid] = find_financial_sub_id(from_properties_tab) #unless find_financial_sub_id.blank?
    financial_sub_items(from_properties_tab)
  end

  def financial_sub_items(from_properties_tab = nil)
    @operating_statement = {}
    @cash_flow_statement = {}
    if from_properties_tab.blank?
      find_dashboard_portfolio_display
    else
      @resource = "'RealEstateProperty'"
    end
    #    find_dashboard_portfolio_display
    #~ @portfolio = Portfolio.find(params[:portfolio_id]) if !@portfolio
    #~ @note = RealEstateProperty.find_real_estate_property(params[:id]) if !@note
    call_for_financials_sub_graph(from_properties_tab)
    @asset_details = @asset_details.collect{|asset| asset if asset.Actuals.to_f.round !=0 || asset.Budget.to_f.round !=0}.compact if @asset_details && !@asset_details.empty?
  end

  def call_for_financials_sub_graph(from_properties_tab=nil)
    if from_properties_tab.blank?
      find_dashboard_portfolio_display
    else
      @resource = "'RealEstateProperty'"
    end
    #    find_dashboard_portfolio_display
    @record_year = find_record_year
    @time_line_actual =  IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? and year=?",@note.id, @resource,@record_year]) if !@note.nil?
    params[:financial_sub] = params[:financial_sub].gsub("?","\'") if params[:financial_sub]
    if params[:cur_month]
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
    end
    if !params[:financial_subid].nil?
      if @balance_sheet && (params[:financial_sub] == "OF ALL" || params[:financial_sub] == "ASSETS" || params[:financial_sub] == "CASH" )
        original_record = IncomeAndCashFlowDetail.find(:last,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id, @resource,params[:financial_sub],@record_year]) if !@note.nil?
      elsif @note && remote_property(@note.accounting_system_type_id) && params[:partial_page] == "capital_expenditure"
        original_record = IncomeAndCashFlowDetail.find(:last,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id, @resource,params[:financial_sub],@record_year]) if !@note.nil?
      else
        original_record = IncomeAndCashFlowDetail.find(:first,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id, @resource,params[:financial_sub],@record_year]) if !@note.nil?
      end
      params[:financial_subid] = original_record.id if !original_record.nil?
    end
    financial_sub_function_calls(from_properties_tab)
  end

  def financial_sub_function_calls(from_properties_tab = nil)
    @record_year = find_record_year(from_properties_tab) if @record_year.nil?
    if @balance_sheet
      calculate_the_financial_sub_graph(@record_year,from_properties_tab)
    else
      if !params[:tl_month].nil? and !params[:tl_month].blank? && params[:period] != "3" && params[:tl_period] != "3" &&  (params[:period] != '2' && params[:tl_period] != '2')
        @current_time_period=Date.new(params[:tl_year].to_i,params[:tl_month].to_i,1)
        calculate_the_financial_sub_graph_for_month(params[:tl_month], params[:tl_year],from_properties_tab)
      else
        calculate_the_financial_sub_graph(@record_year,from_properties_tab) if (!params[:tl_period].nil? and params[:tl_period] == "4") or (!params[:period].nil? and params[:period] == "4") or (params[:tl_period] == "2") or (params[:period] == "2") or (params[:tl_period] == "11") or (params[:period] == "11")
        if (!params[:tl_period].nil? and params[:tl_period] == "5") or (!params[:period].nil? and params[:period] == "5")
          calc_for_financial_data_display
          @current_time_period=Date.new(@financial_year,@financial_month,1)
          calculate_the_financial_sub_graph_for_month(@financial_month,@financial_year,from_properties_tab)
        end
        if(!params[:tl_period].nil? and params[:tl_period] == "6") or (!params[:period].nil? and params[:period] == "6") or params[:period] == "3" || params[:tl_period] == "3"
          if @record_year.to_i >= Date.today.year.to_i
            calculate_the_financial_sub_graph_for_year_forecast(@record_year)
          else
            calculate_the_financial_sub_graph_for_prev_year(@record_year,from_properties_tab)
          end
        end
        calculate_the_financial_sub_graph_for_month_ytd(@start_date.to_date.year,@end_date.to_date.month,from_properties_tab)  if(!params[:tl_period].nil? and params[:tl_period] == "7") or  (!params[:period].nil? and params[:period] == "7")
        calculate_the_financial_sub_graph_for_year_forecast(Date.today.year) if(!params[:tl_period].nil? and params[:tl_period] == "8") or  (!params[:period].nil? and params[:period] == "8")
        if @summary_page
          #@current_time_period = Date.new(@default_month_and_year.year,@default_month_and_year.month,1)
          @current_time_period = Date.new(Date.today.year,Date.today.month,1)
          calculate_the_financial_sub_graph(Date.today.year,from_properties_tab)
        end
      end
    end
    find_transaction_items if params[:financial_sub].downcase == "transactions"
  end

  def find_record_year(from_properties_tab = nil)
    if @balance_sheet
      find_last_updated_items(from_properties_tab)
      record_year =  @last_record_year
    else
      #added for redirection from graph
      record_year = ((params[:tl_period] == "10") ? params[:tl_year] : (params[:tl_period] == "2" || params[:period] == "2") ? params[:tl_year] : ((params[:tl_period] == "8" || params[:period] == "8") ?  Date.today.year : (params[:tl_period] == "3" ? params[:tl_year] : ((params[:tl_period] == "4" || params[:period] == "4") && (params[:tl_month].nil? || params[:tl_month].blank?))  ?  Date.today.year : (!params[:tl_month].blank? and !params[:tl_year].blank?) ?  params[:tl_year] : (params[:cur_year] ? params[:cur_year] : (params[:start_date] ? params[:start_date].split("-")[0].to_i  : ((params[:tl_period] == "5" || params[:period] == "5") ? Date.today.prev_month.year : (params[:period] == "11" || params[:tl_period] == "11") ? Date.today.year : Date.today.prev_year.year))))))
    end
    return record_year
  end

  def map_title(title,from_properties_tab = nil)
    if from_properties_tab.blank?
      find_dashboard_portfolio_display
    else
      @resource = "'RealEstateProperty'"
    end
    #    find_dashboard_portfolio_display
    if @note && (find_accounting_system_type(1,@note) || find_accounting_system_type(2,@note))
      a = {"Operating Revenue"  => "income detail" , "Op.Revenue" => "income detail","Op.Expenses"=>"Operating Expenses","capital expenditures" => "","expenses"=>"expenses",'Net Income'=>'net income','NOI'=>"net operating income"}
    elsif @note && find_accounting_system_type(3,@note)
      a = {"Operating Revenue"  => "operating income","Operating Expenses"=>"operating expenses","capital expenditures"=>"maintenance projects",'Net Income'=>'net income before depreciation',"Op.Revenue"  => "operating income","Op.Expenses"=>"operating expenses","NOI"=>'net operating income'}
    elsif @note && (find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note))
      a = {"Operating Revenue"  => "Operating Revenues" ,"Operating Expenses"=>"Operating Expense","Maintenance Projects" => "Capital Expenditures",'Net Income'=>'Net Income','Non Operating Revenues'=>'Non Operating Revenues','Net Non Operating Income'=>'Non Operating Summary','Non Operating Expense'=>'Non Operating Expense','Net Income'=>'INCOME STATEMENT', 'net operating income'=>'Operating Summary',"Op.Revenue"  => "Operating Revenues" ,"Op.Expenses"=>"Operating Expenses", 'NOI'=>'Operating Summary'}
    elsif @note && remote_property(@note.accounting_system_type_id)
      a = {"Operating Revenue"  => "INCOME" ,"Operating Expenses"=>"OPERATING EXPENSES","Maintenance Projects" => "DEPRECIATION & AMORT",'Net Income'=>'NET INCOME','Non Operating Expense'=>'DEPRECIATION & AMORT', 'net operating income'=>'NET OPERATING INCOME',"Op.Revenue"  => "INCOME" ,"Op.Expenses"=>"OPERATING EXPENSES", 'NOI'=>'NET OPERATING INCOME'}
    end
    title = a[title] if a && !a[title].nil?
    return title
  end

  def performance_financials(page)

    find_dashboard_portfolio_display
    property_name = @note.try(:class).eql?(Portfolio) ? @note.try(:name) : @note.try(:property_name)

    if @note && ((find_accounting_system_type(0,@note) || find_accounting_system_type(1,@note) || find_accounting_system_type(2,@note) ||  find_accounting_system_type(4,@note) || check_yardi_commercial(@note) ))
      @financial =true
      @show_variance_thresholds = true
      today= Date.today
      @tl_month = params[:period] == "7" ? @end_date.to_date.month : today.prev_month.month
      @tl_year = params[:period] == "7" ? @start_date.to_date.year : today.prev_month.year
      financial_function_calls
      page.replace_html "time_line_selector", :partial => "/properties/time_line_selector", :locals => {:period => @period, :note_id => @note.id, :partial_page => "financial", :start_date => 0, :timeline_start => @time_line_start_date, :timeline_end => @time_line_end_date }
      @lease = true
      page.replace_html "portfolio_overview_property_graph" , :partial => "/properties/property_financial_performance",:locals =>{:operating_statement => @operating_statement,:explanation => @explanation,:cash_flow_statement => @cash_flow_statement,:debt_services => @debt_services,:portfolio_collection => @portfolio,
        :notes_collection => @notes,:time_line_actual => @time_line_actual,:time_line_rent_roll => @time_line_rent_roll,:note_collection => @note,:start_date => @start_date,:actual=>@actual,:current_time_period =>@current_time_period,:doc_collection=>@doc}
      page << "jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img width=\"14\" height=\"16\" src=\"/images/executivehead_icon.png\"></span>Operating Statement </div>');"
      page << "jQuery('#id_for_modify_threshold').hide();"
      #~ page << "jQuery('#id_for_variance_threshold').html('<ul class=inputcoll2 id=cssdropdown><li class=headlink3 id=id_for_modify_threshold><div class=morebutton_label><a id=modify_threshold_#{@note.id} href=#{new_threshold_explanation_path(@note.id)}>Variance Thresholds</a></div><span></span></li></ul>');"
      #~ page << "new Control.Modal($('modify_threshold_#{@note.id}'), {beforeOpen: function(){load_writter();},afterOpen: function(){load_completer();},className:'modal_container', method:'post'});"
    elsif @note &&(find_accounting_system_type(3,@note) || check_yardi_multifamily(@note))
      for_notes_year_to_date
      today= Date.today
      @tl_month=today.prev_month.month
      @tl_year=today.prev_month.year
      financial_function_calls
      common_update_page(page,["time_line_selector","portfolio_overview_property_graph"],["/properties/time_line_selector","/properties/property_financial_performance"],{"time_line_selector"=>{:period => @period, :note_id => @note.id, :partial_page => "financial", :start_date => 0, :timeline_start => @time_line_start_date, :timeline_end => @time_line_end_date},"portfolio_overview_property_graph"=>{:operating_statement=>@operating_statement,:explanation=>@explanation,:notes_collection=>@notes,:note_collection=>@note,:start_date=>@start_date,:time_line_actual=>@time_line_actual,:actual=>@actual,:navigation_start_position=>@navigation_start_position,:time_line_rent_roll => @time_line_rent_roll,:portfolio_collection =>@portfolio}})
      common_insert_js_to_page(page,["jQuery('.executiveheadcol_for_title').html('<div class=\"executivecol_subrow\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span> Operating Statement </div>');"])
    end
  end


  def find_total_non_operating_expense(operating_statement)
    find_dashboard_portfolio_display
    if @operating_statement && !@operating_statement.empty? && @operating_statement.length > 1 && @note && ( find_accounting_system_type(2,@note) || ( find_accounting_system_type(1,@note) && @note.accounting_type == "Accrual"))
      @operating_statement["Non Operating Expense"] = Hash.new
      @operating_statement["Net Non Operating Income"] = Hash.new
      @operating_statement['Non Operating Revenues'] = Hash.new

      if @operating_statement['depreciation & amortization detail'] && @operating_statement['debt service detail']
        @operating_statement["Non Operating Expense"][:actuals] = @operating_statement['depreciation & amortization detail'][:actuals] + @operating_statement['debt service detail'][:actuals]
        @operating_statement["Non Operating Expense"][:budget] = @operating_statement['depreciation & amortization detail'][:budget] + @operating_statement['debt service detail'][:budget]
      elsif @operating_statement['depreciation & amortization detail'] && !@operating_statement['debt service detail']
        @operating_statement["Non Operating Expense"][:actuals] = @operating_statement['depreciation & amortization detail'][:actuals]
        @operating_statement["Non Operating Expense"][:budget] = @operating_statement['depreciation & amortization detail'][:budget]
      elsif !@operating_statement['depreciation & amortization detail'] && @operating_statement['debt service detail']
        @operating_statement["Non Operating Expense"][:actuals] = @operating_statement['debt service detail'][:actuals]
        @operating_statement["Non Operating Expense"][:budget] = @operating_statement['debt service detail'][:budget]
      end
      @operating_statement["Non Operating Expense"][:variant] = @operating_statement["Non Operating Expense"][:budget].to_f -  @operating_statement["Non Operating Expense"][:actuals].to_f
      percent =@operating_statement["Non Operating Expense"][:variant] *100/@operating_statement["Non Operating Expense"][:budget] .to_f.abs rescue ZeroDivisionError
      if  @operating_statement['Non Operating Expense'][:budget].to_f==0
        percent = (@operating_statement["Non Operating Expense"][:actuals].to_f == 0 ? 0 : -100 )
      end
      @operating_statement["Non Operating Expense"][:percent] = percent
      #@operating_statement["Net Non Operating Income"]  = @operating_statement['Non Operating Expense']
      @operating_statement["Net Non Operating Income"][:actuals] = - @operating_statement['Non Operating Expense'][:actuals]
      @operating_statement["Net Non Operating Income"][:budget] = - @operating_statement['Non Operating Expense'][:budget]
      @operating_statement["Net Non Operating Income"][:variant] = @operating_statement["Net Non Operating Income"][:budget].to_f -  @operating_statement["Net Non Operating Income"][:actuals].to_f
      percent =@operating_statement["Net Non Operating Income"][:variant] *100/@operating_statement["Net Non Operating Income"][:budget] .to_f.abs rescue ZeroDivisionError
      if  @operating_statement['Net Non Operating Income'][:budget].to_f==0
        percent = (@operating_statement["Net Non Operating Income"][:actuals].to_f == 0 ? 0 : -100 )
      end
      @operating_statement["Net Non Operating Income"][:percent] = percent
    elsif @operating_statement && !@operating_statement.empty? && @operating_statement.length > 1 && @note &&  find_accounting_system_type(3,@note) && @note.accounting_type == "Cash"
      @operating_statement["Non Operating Expense"] = Hash.new
      @operating_statement["Net Non Operating Income"] = Hash.new
      @operating_statement['Non Operating Revenues'] = Hash.new
      if @operating_statement['maintenance projects'] || @operating_statement['other']
        @operating_statement["Non Operating Expense"] [:actuals] = @operating_statement['maintenance projects'][:actuals] + @operating_statement['other'][:actuals]
        @operating_statement["Non Operating Expense"] [:budget] = @operating_statement['maintenance projects'][:budget] + @operating_statement['other'][:budget]
        @operating_statement["Non Operating Expense"][:variant] = @operating_statement["Non Operating Expense"][:budget].to_f -  @operating_statement["Non Operating Expense"][:actuals].to_f
        percent =@operating_statement["Non Operating Expense"][:variant] *100/@operating_statement["Non Operating Expense"][:budget] .to_f.abs rescue ZeroDivisionError
        if  @operating_statement['Non Operating Expense'][:budget].to_f==0
          percent = (@operating_statement["Non Operating Expense"][:actuals].to_f == 0 ? 0 : -100 )
        end
        @operating_statement["Non Operating Expense"][:percent] = percent
        @operating_statement["Net Non Operating Income"][:actuals] = - @operating_statement['Non Operating Expense'][:actuals]
        @operating_statement["Net Non Operating Income"][:budget] = - @operating_statement['Non Operating Expense'][:budget]
        @operating_statement["Net Non Operating Income"][:variant] = @operating_statement["Net Non Operating Income"][:budget].to_f -  @operating_statement["Net Non Operating Income"][:actuals].to_f
        percent =@operating_statement["Net Non Operating Income"][:variant] *100/@operating_statement["Net Non Operating Income"][:budget] .to_f.abs rescue ZeroDivisionError
        if  @operating_statement['Net Non Operating Income'][:budget].to_f==0
          percent = (@operating_statement["Net Non Operating Income"][:actuals].to_f == 0 ? 0 : -100 )
        end
        @operating_statement["Net Non Operating Income"][:percent] = percent
      end
    end
    return @operating_statement
  end

  def find_expense_title(from_properties_tab = nil)
    if @operating_statement && !@operating_statement.empty? && @operating_statement.length > 1
      if @operating_statement["OPERATING EXPENSES"]
        @expense_title =  map_title("OPERATING EXPENSES",from_properties_tab)
      elsif @operating_statement["Operating Expense"]
        @expense_title =  map_title("Operating Expense",from_properties_tab)
      elsif @operating_statement["operating expenses"]
        @expense_title = map_title("operating expenses",from_properties_tab)
      elsif  @operating_statement["Operating Expenses"]
        @expense_title = map_title("Operating Expenses",from_properties_tab)
      elsif  @operating_statement["expenses"]
        @expense_title =  map_title("expenses",from_properties_tab)
      end
      return @expense_title
    end
  end

  def financial_function_calls
    if @balance_sheet
      store_income_and_cash_flow_statement
    elsif (params[:period] != '3' && params[:tl_period] != '3') and ((!params[:tl_month].nil? and !params[:tl_month].blank?) or (!params[:start_date].nil?)) and  (params[:period] != '2' && params[:tl_period] != '2')
      store_income_and_cash_flow_statement_for_month(@tl_month, @tl_year) if @tl_month &&  @tl_year
      store_income_and_cash_flow_statement_for_month(params[:tl_month].to_i,params[:tl_year].to_i) if params[:tl_month] && params[:tl_year]
    else
      if params[:tl_period] == '4' || params[:period] == '4' || params[:tl_period] == '2' || params[:period] == '2' || params[:tl_period] == '11' || params[:period] == '11'
        @period = "4"  if params[:tl_period] == '4' || params[:period] == '4'
        @period = "2"  if params[:tl_period] == '2' || params[:period] == '2'
        @period = "11" if params[:tl_period] == '11' || params[:period] == '11'
        store_income_and_cash_flow_statement
      elsif params[:tl_period] == '7' || params[:period] == '7'
        @period = "7"
        store_income_and_cash_flow_statement
      elsif  params[:tl_period] == '5' || params[:period] == '5'
        @period = "5"
        calc_for_financial_data_display
        store_income_and_cash_flow_statement_for_month(@financial_month, @financial_year)
      elsif  params[:tl_period] == '6'|| params[:tl_period] == '3'  || params[:period] == '6' || params[:period] == '3'
        @period = "6"
        @period = "3" if (params[:period] == '3' || params[:tl_period] == '3')
        store_income_and_cash_flow_statement_for_prev_year
      elsif params[:tl_period] == '8'|| params[:period] == '8'
        @period = "8"
        store_income_and_cash_flow_statement_for_year_forecast
      end
    end
  end

  ########Year Forecast ###########
  def executive_overview_details_for_year_forecast
    @ytd_t=true
    store_income_and_cash_flow_statement_for_year_forecast
    if @note && ( find_accounting_system_type(1,@note) ||  find_accounting_system_type(2,@note) || ( find_accounting_system_type(0,@note) && is_commercial(@note)) || check_yardi_commercial(@note))
      occupancy_percent_for_month(Date.today.prev_month.month,Date.today.prev_month.year)
      if @note && (( find_accounting_system_type(0,@note) || remote_property(@note.accounting_system_type_id)) && is_commercial(@note))
        wres_other_income_and_expense_details_for_year_forecast
      else
        capital_expenditure_for_yr_forecast
      end
      lease_expirations_calculation(Date.today.prev_month.month,Date.today.end_of_year.year)
    elsif @note && ( find_accounting_system_type(3,@note) ||  check_yardi_multifamily(@note) || (( find_accounting_system_type(0,@note) ||  find_accounting_system_type(4,@note) || remote_property(@note.accounting_system_type_id) ) && is_multifamily(@note)))
      year = find_selected_year(year)
      wres_other_income_and_expense_details_for_year_forecast
      @property_occupancy_summary = PropertyOccupancySummary.find(:first,:conditions => ["real_estate_property_id=? and year=? and month < ?",@note.id,Date.today.year,Date.today.month],:order => "month desc")
      wres_occupancy_data_calculation if !@property_occupancy_summary.nil?
      wres_rent_analysis_cal_for_year
    end
  end

  def capital_expenditure_for_year_forecast
    if !(remote_property(@note.accounting_system_type_id)) || (find_accounting_system_type(3,@note)) &&  !(( find_accounting_system_type(0,@note) ||  find_accounting_system_type(4,@note)) && is_multifamily(@note))
      capital_expenditure_sub_method('year_forecast')
    end
  end

  #### cap_exp_summary for yearforecast #########
  def  cap_exp_yrforecast_condition(month_val=nil,year=nil)
    calc_for_financial_data_display
    month= @financial_month
    year =  find_selected_year(Date.today.year)
    find_dashboard_portfolio_display
    pci =@note.try(:class).eql?(Portfolio) ? PropertyCapitalImprovement.find(:first,:conditions => ["year=? and portfolio_id =?",year,@note.id],:select=>'month',:order => "month desc") : PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=?",year,@note.id],:select=>'month',:order => "month desc")
    month = pci.month if !pci.nil?
    insert_month = ( find_accounting_system_type(2,@note) ||  find_accounting_system_type(0,@note)) && is_commercial(@note) ? "" : "AND ic.month = #{month}"
    qry_string = @note.try(:class).eql?(Portfolio) ? "ic.portfolio_id = #{@note.id}"  : "ic.real_estate_property_id = #{@note.id}"
    val_qry="select pf1.january as january,pf1.february as february,pf1.march as march,pf1.april as april, pf1.may as may,pf1.june as june,pf1.july as july,pf1.august as august,pf1.september as september,pf1.october as october,pf1.november as november,pf1.december as december,ic.category as Cate FROM  property_capital_improvements  ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.pcb_type = 'c' and pf1.source_type = 'PropertyCapitalImprovement' where ic.category in ('TOTAL CAPITAL EXPENDITURES') and #{qry_string} #{insert_month} and ic.year= #{year}"
    value= PropertyCapitalImprovement.find_by_sql(val_qry)
    k=0
    @result = value[k].attributes.keys.select {|i| i if value[k].send(:"#{i}") == "0" }  if !(value.blank? || value.empty?)
  end

  def capital_expenditure_for_yr_forecast(month_val=nil,year=nil)
    cap_exp_yrforecast_condition
    common_method_for_yrforecast
    find_dashboard_portfolio_display
    year =  find_selected_year(Date.today.year)
    month= @financial_month
    cur_month = @end_date ? @end_date : params[:start_date]
    pci = @note.try(:class).eql?(Portfolio) ? PropertyCapitalImprovement.find(:first,:conditions => ["year=? and portfolio_id =?",year,@note.id],:select=>'month',:order => "month desc") : PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=?",year,@note.id],:select=>'month',:order => "month desc")
    month = pci.month if !pci.nil?
    query = get_query_for_cap_imp_exec_for_yr_forecast(month,year) if !@ytd_actuals.nil?
    asset_details = !@ytd_actuals.nil? ?  PropertyCapitalImprovement.find_by_sql(query) : []
    if !asset_details.empty?
      @capital_improvement = {}
      @capital_percent = {}
      tot_a = 0
      tot_b = 0
      for asset in asset_details
        if !asset.Cate.nil? and ["total tenant improvements","total leasing commissions","total building improvements","total lease costs","total net lease costs","total loan costs"].include?(asset.Cate.downcase.strip)
          @capital_improvement[asset.Cate.downcase.strip] = asset.act.to_f
        elsif !asset.Cate.nil? and asset.Cate.downcase.strip=="total capital expenditures"
          tot_a=asset.act.to_f if !asset.act.nil?
          tot_b=asset.bud.to_f if !asset.bud.nil?
        end
      end
      for asset in asset_details
        if !asset.Cate.nil? and ["total tenant improvements","total leasing commissions","total building improvements","total lease costs","total net lease costs","total loan costs"].include?(asset.Cate.downcase.strip)
          @capital_percent[asset.Cate.downcase.strip] =((@capital_improvement[asset.Cate.downcase.strip]*100)/tot_a)
        end
      end
      diff = tot_b - tot_a
      diff_per = tot_b !=  0.0 ? (diff * 100)/tot_b : 0
      if diff_per == 0
        diff_per = 0
      elsif diff_per.nan?
        diff_per = 0
      end
      @captial_diff={:diff => diff.abs,:diff_percent => diff_per,:style => (tot_b >= tot_a ) ?  "greenrow" : "redrow",:tot_actual => tot_a,:diff_word => (tot_b > tot_a ) ? "below" : "above",:tot_budget => tot_b}
    end
  end


  # Query for Captical improvement functionality
  def get_query_for_cap_imp_exec_for_yr_forecast(month,year)
    insert_month = ( find_accounting_system_type(2,@note) ||  find_accounting_system_type(0,@note)) && is_commercial(@note) ? "" : "AND ci.month = #{month}"
    qry_string = @note.try(:class).eql?(Portfolio) ? " ci.portfolio_id = #{@note.id}" :   "ci.real_estate_property_id = #{@note.id}"
    "SELECT (#{@ytd_actuals} + #{@ytd_budget}) as act,pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december as bud, ci.category as Cate FROM   property_capital_improvements AS ci  LEFT JOIN   property_financial_periods AS pf1  on  pf1.source_id = ci.id AND  pf1.pcb_type ='c' AND   pf1.source_type = 'PropertyCapitalImprovement'   LEFT JOIN   property_financial_periods AS pf2 on pf2.source_id = ci.id AND  pf2.pcb_type ='b' AND pf2.source_type = 'PropertyCapitalImprovement' WHERE  #{qry_string} #{insert_month} AND  ci.year = #{year} AND  ci.category IN ('TOTAL TENANT IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASE COSTS','TOTAL CAPITAL EXPENDITURES','TOTAL NET LEASE COSTS','TOTAL LOAN COSTS')"
  end

  ########Year Forecast for financial ###########
  def year_forecast_condition
    year =  find_selected_year(Date.today.year)
    k=0
    if @note && (find_accounting_system_type(1,@note) || find_accounting_system_type(2,@note))
      val_qry="select sum(pf1.january) as january,sum(pf1.february) as february,sum(pf1.march) as march,sum(pf1.april) as april, sum(pf1.may) as may,sum(pf1.june) as june,sum(pf1.july) as july,sum(pf1.august) as august,sum(pf1.september) as september,sum(pf1.october) as october,sum(pf1.november) as november,sum(pf1.december) as december from income_and_cash_flow_details ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.pcb_type = 'c' and pf1.source_type = 'IncomeAndCashFlowDetail' where ic.title in ('non-recoverable expenses detail','recoverable expenses detail') and ic.resource_id = #{@note.id} and ic.year= #{year} union select pf1.january as january,pf1.february as february,pf1.march as march,pf1.april as april,pf1.may as may,pf1.june as june, pf1.july as july,pf1.august as august,pf1.september as september, pf1.october as october,pf1.november as november,pf1.december as december from income_and_cash_flow_details ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.pcb_type = 'c' and pf1.source_type = 'IncomeAndCashFlowDetail' where ic.title ='income detail' and ic.resource_id = #{@note.id} and ic.year= #{year}"
      value= IncomeAndCashFlowDetail.find_by_sql(val_qry)
      @result = value[k].attributes.keys.select {|i| i if value[k].send(:"#{i}") == "0" and value[k+1] and value[k+1].send(:"#{i}") == "0" }  if !(value.blank? || value.empty?)
    elsif @note && (find_accounting_system_type(3,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note) || remote_property(@note.accounting_system_type_id))
      val_qry="select pf1.january as january,pf1.february as february,pf1.march as march,pf1.april as april, pf1.may as may,pf1.june as june,pf1.july as july,pf1.august as august,pf1.september as september,pf1.october as october,pf1.november as november,pf1.december as december from income_and_cash_flow_details ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.pcb_type = 'c' and pf1.source_type = 'IncomeAndCashFlowDetail' where ic.title in ('operating expenses','Operating Expense') and ic.resource_id = #{@note.id} and ic.year= #{year} union select pf1.january as january,pf1.february as february,pf1.march as march,pf1.april as april,pf1.may as may,pf1.june as june, pf1.july as july,pf1.august as august,pf1.september as september, pf1.october as october,pf1.november as november,pf1.december as december from income_and_cash_flow_details ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.pcb_type = 'c' and pf1.source_type = 'IncomeAndCashFlowDetail' where ic.title in ('operating income','Operating Revenues') and ic.resource_id = #{@note.id} and ic.year= #{year}"
      value= IncomeAndCashFlowDetail.find_by_sql(val_qry)
      @result = value[k].attributes.keys.select {|i| i if value[k].send(:"#{i}") == "0"}  if !(value.blank? || value.empty?)
    end
  end

  def store_income_and_cash_flow_statement_for_year_forecast
    year_forecast_condition
    @operating_statement={}
    @cash_flow_statement={}
    @explanation = true
    common_method_for_yrforecast
    year =  find_selected_year(Date.today.year)
    if @portfolio_summary == true
      qry = get_query_for_portfolio_summary(year)
    else
      qry = get_query_for_year_forecast(year) if !@ytd_actuals.nil?
    end
    calculate_asset_details(year,qry)
  end


  def get_query_for_year_forecast(year)
    if @financial
      financial_title = find_financial_title
      "select ic2.title as Parent, ic.title as Title,(#{@ytd_actuals} + #{@ytd_budget}) as Actuals,pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december as Budget,ic.id as Record_id from `income_and_cash_flow_details` ic LEFT JOIN  property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' left join income_and_cash_flow_details ic2 on ic2.id=ic.parent_id  WHERE ic.id IN (SELECT ic2.id FROM income_and_cash_flow_details ic2 WHERE (ic2.title IN (#{financial_title}) or (ic2.parent_id is null)) AND ic2.resource_id = #{@note.id} AND ic2.year= #{year} UNION SELECT ic3.id FROM income_and_cash_flow_details ic3 WHERE ic3.parent_id IN (SELECT ic1.id FROM income_and_cash_flow_details ic1 WHERE (ic1.title IN (#{financial_title}) or (ic1.parent_id is null)) AND ic1.resource_id = #{@note.id} AND ic1.year= #{year}))"
    else
      financial_title = find_non_financial_title
      "select ic2.title as Parent, ic.title as Title,(#{@ytd_actuals} + #{@ytd_budget}) as Actuals,pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december as Budget,ic.id as Record_id from `income_and_cash_flow_details` ic LEFT JOIN  property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' left join income_and_cash_flow_details ic2 on ic2.id=ic.parent_id  WHERE ic.id IN (SELECT ic2.id FROM income_and_cash_flow_details ic2 WHERE (ic2.title IN (#{financial_title}) or (ic2.parent_id is null)) AND ic2.resource_id = #{@note.id} AND ic2.year= #{year}   UNION SELECT ic3.id FROM income_and_cash_flow_details ic3 WHERE ic3.parent_id IN (SELECT ic1.id FROM income_and_cash_flow_details ic1 WHERE (ic1.title IN (#{financial_title}) or (ic1.parent_id is null)) AND ic1.resource_id = #{@note.id} AND ic1.year= #{year}))"
    end
  end

  def calculate_the_financial_sub_graph_for_year_forecast(year=nil)
    year_forecast_condition
    common_method_for_yrforecast
    year =  find_selected_year(Date.today.year)
    params[:financial_sub] = params[:financial_sub].gsub("?","\'") if params[:financial_sub]
    if params[:financial_sub] and params[:financial_sub] == "Operating Expenses"
      if @note && (find_accounting_system_type(1,@note) || find_accounting_system_type(2,@note))
        qry = "select ic.title as Title,(#{@ytd_actuals} + #{@ytd_budget}) as Actuals,pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december as Budget,ic.id as Record_id from `income_and_cash_flow_details` ic LEFT JOIN  property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' WHERE  ic.resource_id= #{@note.id} AND ic.resource_type = #{@resource} AND ic.year =#{year} AND ic.title IN('recoverable expenses detail','non-recoverable expenses detail')"
      elsif  @note && (find_accounting_system_type(3,@note) || find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note) || remote_property(@note.accounting_system_type_id)) && params[:financial_subid].present?
        qry = "select ic.title as Title,(#{@ytd_actuals} + #{@ytd_budget}) as Actuals,pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december as Budget,ic.id as Record_id from `income_and_cash_flow_details` ic LEFT JOIN  property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' WHERE  ic.resource_id= #{@note.id} AND ic.resource_type = #{@resource} AND ic.year =#{year} AND ic.parent_id = #{params[:financial_subid]} AND ic.title NOT IN ('operating expenses','net operating income','net income before depreciation','operating income','Other Income And Expense')"
      end
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry) if qry.present?
    elsif !params[:financial_subid].blank?
      @using_sub_id = true
      qry = get_query_for_financial_sub_page_for_year_forecast(params[:financial_subid],year,false) if !@ytd_actuals.nil?
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry) if !@ytd_actuals.nil?
      if params[:action].include?("financial_subpage") || (params[:partial_page] == "financial_subpage") || params[:financial_sub]=="maintenance projects" || params[:financial_sub]=="Capital Expenditures" || params[:action].include?("balance_sheet_sub_page") || (params[:partial_page] == "balance_sheet_sub_page")
        total_qry = get_query_for_financial_sub_page_for_year_forecast(params[:financial_subid],year,true) if !@ytd_actuals.nil?
        @total = IncomeAndCashFlowDetail.find_by_sql(total_qry) if !@ytd_actuals.nil?
      end
    else
      @using_sub_id = false
      qry = get_query_for_financial_sub_page_for_year_forecast(params[:financial_sub],year,false) if !@ytd_actuals.nil?
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry) if !@ytd_actuals.nil?
    end
    @explanation = true
  end

  def get_query_for_financial_sub_page_for_year_forecast(parent,year,find_total)
    if params[:partial_page] == 'cash_and_receivables'  &&  remote_property(@note.accounting_system_type_id) || params[:partial_page] == 'portfolio_partial' && remote_property(@note.accounting_system_type_id)
      adjustments =  AccountTree.find(:all,:conditions=>["title in ('#{params[:financial_sub]}')"]).map(&:id).join(',')
      adjustment_sub_items_account_num =  AccountTree.find(:all,:conditions=>["parent_id in (#{adjustments})"]).map(&:account_num).join(',') if adjustments
      cash_items = IncomeAndCashFlowDetail.find_by_sql("select * from income_and_cash_flow_details where account_code in (#{adjustment_sub_items_account_num})").map(&:id).join(',')
      return"select ic.inormalbalance as InormalBalance,Title,(#{@ytd_actuals} + #{@ytd_budget}) as Actuals,(pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december) as Budget,ic.id as Record_id from `income_and_cash_flow_details` ic LEFT JOIN  property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' WHERE  ic.resource_id= #{@note.id} AND ic.resource_type = #{@resource} AND ic.year =#{year} AND ic.id in (#{cash_items})"
      @cash_items_titles = IncomeAndCashFlowDetail.find_by_sql("select * from income_and_cash_flow_details where account_code in (#{adjustment_sub_items_account_num})").map(&:title).join(',')
    elsif  @using_sub_id
      string =  find_total == true ? "ic.id" : "ic.parent_id"
      return"select Title,(#{@ytd_actuals} + #{@ytd_budget}) as Actuals,(pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december) as Budget,ic.id as Record_id from `income_and_cash_flow_details` ic LEFT JOIN  property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' WHERE  ic.resource_id= #{@note.id} AND ic.resource_type = #{@resource} AND ic.year =#{year} AND #{string} =#{parent}"
    else
      return "select Title,(#{@ytd_actuals} + #{@ytd_budget}) as Actuals,(pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december) as Budget,ic.id as Record_id from `income_and_cash_flow_details` ic LEFT JOIN  property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' WHERE  ic.resource_id= #{@note.id} AND ic.resource_type = #{@resource} AND ic.year =#{year} AND ic.title =\"#{parent}\""
    end
  end

  def  find_selected_year(year)
    if(params[:period] == "2" || params[:tl_period] == "2") && params[:tl_year]
      year = params[:tl_year].to_i
    elsif params[:cur_year] && !params[:cur_year].blank?
      year = params[:cur_year].to_i
    elsif params[:start_date]  && (params[:period] == "3" || params[:tl_period] == "3")
      year = params[:start_date].split("-")[0].to_i
    elsif params[:tl_year] && !params[:tl_year].blank? && ((params[:period] == "3" || params[:tl_period] == "3") || (params[:period] == "10" || params[:tl_period] == "10") || (params[:period] == "5" || params[:tl_period] == "5"))
      year = params[:tl_year].to_i
    elsif  params[:tl_year] && !params[:tl_year].blank? && (params[:period] == "8" || params[:tl_period] == "8")
      year = params[:tl_year].to_i
    end
    return year
  end

  def find_time_line_selector_year_class(date_element,i,time,navigation_start_position)
    if params[:tl_year] && (params[:period] == "3" || params[:tl_period] == "3")
      if  (date_element[i]).scan(/(.*)\s-/).flatten.to_s.include?(params[:tl_year].to_s)
        navigation_start_position = ((i)/12)*12
        class_name = 'active'
      else
        class_name = 'deactive'
      end
    else
      if (date_element[i]).scan(/(.*)\s-/).flatten.to_s == time.prev_year.beginning_of_year.strftime("%Y-%m-%d")
        navigation_start_position = ((i)/12)*12
        class_name = 'active'
      else
        class_name = 'deactive'
      end
    end
    return class_name,navigation_start_position
  end

  def weekly_class(i,date_array)
    prev =  "#{@prev_sunday.day}#{(@prev_sunday.to_date).strftime("%b")}"
    if date_array == prev
      navigation_start_position = ((i)/12)*12
      class_name = 'active'
    else
      class_name = 'deactive'
    end
    return class_name,navigation_start_position
  end

  #to show default value in gross rentable area popup box
  def get_gross_rentable_area(property)
    if property.gross_rentable_area
      property.gross_rentable_area
    else
      occupancy_summay = PropertyOccupancySummary.find(:first, :conditions=>['year = ? and real_estate_property_id = ?',Date.today.year,property.id], :order=>'month desc')
      rentable_area = occupancy_summay ? (occupancy_summay.current_year_sf_occupied_actual ? occupancy_summay.current_year_sf_occupied_actual : 0) + (occupancy_summay.current_year_sf_vacant_actual ?  occupancy_summay.current_year_sf_vacant_actual : 0 ) : 0
    end
  end

  #to show default value in number of units popup box
  def get_no_of_units(property)
    if property.no_of_units
      property.no_of_units
    else
      occupancy_summay = PropertyOccupancySummary.find(:first, :conditions=>['year = ? and real_estate_property_id = ?',Date.today.year,property.id], :order=>'month desc')
      no_of_units =  occupancy_summay ? occupancy_summay.current_year_units_total_actual ? occupancy_summay.current_year_units_total_actual : 0 : 0
    end
  end

  #to change color in timeline selector
  def find_time_line_item_color
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    #month color for financials and summary
    if params[:partial_page] == "portfolio_partial" || params[:partial_page] == 'financials' || params[:partial_page] == 'financial_subpage'  || params[:partial_page] == 'balance_sheet' || params[:partial_page] == 'balance_sheet_sub_page' || params[:partial_page] =="cash_and_receivables" || params[:cash_call_id] || params[:partial_page] == 'financial' || params[:partial_page] == 'variances'|| (controller.controller_name =="properties" && controller.action_name =="show") || params[:main_head_call] == 'true'
      find_redmonth_start_for_summary(Date.today.year)
      #month color for leases
    elsif params[:partial_page] == 'leases' ||  params[:partial_page] == 'lease_sub_tab'
      find_redmonth_start_for_leases(find_selected_year(Date.today.year))
      #month_color_for_rent_roll
    elsif params[:partial_page] == 'rent_roll' || params[:partial_page] == 'rent_roll_highlight' || params[:action] == "rent_roll"
      find_redmonth_start_for_rent_roll(find_selected_year(Date.today.year))
      #month_color_for_recv
    elsif params[:partial_page] == 'cash_and_receivables_for_receivables'
      find_redmonth_start_for_recv(find_selected_year(Date.today.year))
    elsif params[:partial_page] == 'capital_expenditure'  || params[:cap_call_id] || params[:action] == "capital_expenditure"
      find_redmonth_start_for_capexp(Date.today.year)
      #num_add = (params[:tl_year] && params[:tl_year].to_i == Date.today.year) ? 24 : 12
      #@month_red_start =  Date.today.month.to_i + num_add if remote_property(@note.accounting_system_type_id)
    end
  end

  def find_redmonth_start_for_leases(year_value)
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    month_val =((params[:period] == "7"  || params[:tl_period] == "7") && !params[:cur_month].nil?) ? months.index(params[:cur_month]) + 1 : Date.today.prev_month.month
    if(params[:period] == "3"  || params[:tl_period] == "3") || (params[:period] == "6"  || params[:tl_period] == "6" || params[:tl_period] == "2" || params[:period] == "2")
      month_val = 12
    end

    if is_multifamily(@note)
      #~ insert_month_string =  ((@month_quarter) && (params[:tl_period] == "2" || params[:period] == "2")) ?  "month in (#{@month_quarter.join(',')})" : "month <= #{month_val}"
      @year = PropertyOccupancySummary.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
      @year = @year.compact.empty? ? nil : @year[0].year
      occupancy= PropertyOccupancySummary.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,@year,get_month(@year)],:order => "month desc",:limit =>1)
    elsif is_commercial(@note)
      @year = LeaseRentRoll.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
      @year = @year.compact.empty? ? nil : @year[0].year
      occupancy= LeaseRentRoll.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,@year,get_month(@year)],:order => "month desc",:limit =>1)
    end
    @month_red_start  = occupancy.empty? ? 0 : occupancy[0].month.to_i + 12
  end

  def find_redmonth_start_for_summary(year_num)
    noi_title = map_title('NOI')
    @actuals  = PropertyFinancialPeriod.find_by_sql("SELECT pcb_type,january, february, march, april, may, june, july, august, september, october, november, december
        FROM property_financial_periods f INNER JOIN income_and_cash_flow_details i ON i.id = f.source_id AND i.resource_id =#{@note.id} AND f.pcb_type IN ('c') AND f.source_type = 'IncomeAndCashFlowDetail' AND i.year = '#{year_num}'AND   i.title  IN ('#{noi_title}') ORDER BY 'created_at' DESC LIMIT 1")
    if @actuals.empty?
      @month_red_start  = 0
    else
      financial_period =[@actuals[0].january,@actuals[0].february,@actuals[0].march,@actuals[0].april,@actuals[0].may,@actuals[0].june,@actuals[0].july,@actuals[0].august,@actuals[0].september,@actuals[0].october,@actuals[0].november,@actuals[0].december]
      num_add = Date.today.year ==  year_num ? 24 : 12
      @month_red_start = (financial_period.index(0.0)).to_i + num_add if financial_period.index(0.0)
      if @month_red_start && (params[:partial_page] =="cash_and_receivables" || params[:cash_call_id]) && @note.accounting_type != "Accrual"
        @month_red_start = 0
      end
    end
  end

  def find_redmonth_start_for_rent_roll(year_value)
    month = redmonth_month_calc(year_value)
    @month_red_start  = month.nil? ? 0 : month.to_i + 12
    return @year
  end

  def redmonth_month_calc(year_value)
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    calc_for_financial_data_display
    month_val  =((params[:period] == "7"  || params[:tl_period] == "7") && !params[:cur_month].nil?) ? months.index(params[:cur_month]) + 1 : @financial_month
    if (params[:period] == "3"  || params[:tl_period] == "3") || (params[:period] == "6"  || params[:tl_period] == "6" || params[:tl_period] == "2" || params[:period] == "2")
      month_val = 12
    end

    if is_commercial(@note)
      occupancy_query_part = " and occupancy_type = 'current'"
    elsif is_multifamily(@note)
      occupancy_query_part = ""
    end
    if @note.class.eql?(Portfolio)
      if @note.leasing_type.eql?("Multifamily")
       property_collection = RealEstateProperty.joins(:portfolios).where("portfolios.id" => @note.id)		
			prop_ids = property_collection.collect { |prop| prop.id}
        suites = PropertySuite.find(:all, :conditions=>['real_estate_property_id IN (?)', prop_ids]).map(&:id) if !@note.nil?
      insert_month_string =  ((@month_quarter) && (params[:tl_period] == "2" || params[:period] == "2")) ?  "month in (#{@month_quarter.join(',')})" : "month <= #{month_val}"
      @year = PropertyLease.find(:all, :conditions=>["property_suite_id IN (?) and year <= ? #{occupancy_query_part}",suites,Date.today.year],:select=>"year",:order=>"year desc") if !suites.blank?
      @year = @year && @year[0] ? @year[0].year.to_i : nil
      return PropertyLease.find(:all, :conditions=>["property_suite_id IN (?) and year = ? and month <= ? #{occupancy_query_part}",suites,@year.to_i,get_month(@year)],:select=>"month").map(&:month).max if !suites.blank?
        end
      else
    if is_commercial(@note)
      suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
      @year  = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year <= ? and occupancy_type = ?', @suites ,Date.today.year,'current'],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
      @year   =@year && @year [0] ? @year [0].year.to_i : nil
      return LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ? and occupancy_type = ?', @suites ,@year.to_i,get_month(@year),'current'],:select=>"month").map(&:month).max if !@suites.blank?
    else
      suites = PropertySuite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
      insert_month_string =  ((@month_quarter) && (params[:tl_period] == "2" || params[:period] == "2")) ?  "month in (#{@month_quarter.join(',')})" : "month <= #{month_val}"
      @year = PropertyLease.find(:all, :conditions=>["property_suite_id IN (?) and year <= ? #{occupancy_query_part}",suites,Date.today.year],:select=>"year",:order=>"year desc") if !suites.blank?
      @year = @year && @year[0] ? @year[0].year.to_i : nil
      return PropertyLease.find(:all, :conditions=>["property_suite_id IN (?) and year = ? and month <= ? #{occupancy_query_part}",suites,@year.to_i,get_month(@year)],:select=>"month").map(&:month).max if !suites.blank?
    end
    end
    
    #~ return PropertyLease.find(:all, :conditions=>["property_suite_id IN (?) and year = ? {occupancy_query_part}",suites,@year],:select=>"month").map(&:month).max if !suites.blank?
  end

  def find_redmonth_start_for_multifamily_occupancy(year_value)
    month = redmonth_month_calc(year_value)
    @month_red_start_occupancy  = month.nil? ? 0 : month.to_i + 12
  end

  def get_last_12_weeks
    @dates = []
    y = (Time.now.to_date-Time.now.wday)
    x = y - 12.weeks
    (x..y).each do |date|
      next unless date.strftime("%A") == 'Sunday'
      @dates << date
    end
    @dates
  end

  def get_last_12_weeks_dates_and_months
    @dates = []
    @date_month = []
    @date_array = []
    y = (Time.now.to_date-Time.now.wday)
    x = y - 12.weeks
    (x..y).each do |date|
      next unless date.strftime("%A") == 'Sunday'
      @date_array << date.day
      @date_month << date.strftime("%b")
      @dates << date
    end
    @dates
  end


  def get_last_12_months_rent_and_vacant_units_graph
    get_last_12_weeks
    @week_array = []
    @week_dates = []
    @dates.each do |date|
      @week_array << date.to_date.strftime("%b %e")
    end

    @dates.each do |date|
      @week_dates << date.strftime("%Y-%m-%d")
    end
    weekly_dates = @week_dates
    @week_dates = @week_dates.map { |i| "'" + i.to_s + "'" }.join(",")

    #connection = ActiveRecord::Base.connection();
    query_values = "sum(vacant_total) as sum_vacant_total, sum(prelsd) as sum_prelsd, sum(ntv_status_total) as sum_ntv_status_total, sum(prelsd2) as sum_prelsd2, MIN(NULLIF(min_rent,0)) as sum_min_rent, MAX(max_rent) as sum_max_rent, sum(pi_total) as sum_pi_total, sum(wi_total) as sum_wi_total, sum(dep_total) as sum_dep_total, sum(dep_rej) as sum_dep_rej, sum(dep_canc) as sum_dep_canc, time_period"
    if @real_estate_property_ids.present?
      real_estate_property_ids = @real_estate_property_ids.map { |i| "'" + i.to_s + "'" }.join(",")
      if @selected_floor_plan.present? && !@selected_floor_plan.eql?("All")
        vacant_query =  "select #{query_values}  from property_weekly_osrs where real_estate_property_id IN (#{real_estate_property_ids}) and floor_plan = '#{@selected_floor_plan}' and time_period IN (#{@week_dates}) group by time_period"
      else
        logger.info "I am in portfolio all action +++++++"
        vacant_query =  "select #{query_values}  from property_weekly_osrs where real_estate_property_id IN (#{real_estate_property_ids}) and time_period IN (#{@week_dates}) group by time_period"
      end
    else
      if @selected_floor_plan.present? && !@selected_floor_plan.eql?("All")
        vacant_query =  "select #{query_values}  from property_weekly_osrs where real_estate_property_id = #{@note.id} and floor_plan = '#{@selected_floor_plan}' and time_period IN (#{@week_dates}) group by time_period"
      else
        vacant_query =  "select #{query_values}  from property_weekly_osrs where real_estate_property_id = #{@note.id} and time_period IN (#{@week_dates}) group by time_period"
      end
    end

    @vacant_display = PropertyWeeklyOsr.find_by_sql(vacant_query)

    @property_week_vacant_total,@property_week_prelsd,@property_weekly_ntv,@property_week_prelsd2,@min_rent,@max_rent, @notice_net, @vacant_net, @pi_total, @wi_total, @dep_total, @dep_rej, @dep_canc, @net_deposits, @total_inquiries =[],[],[],[],[],[], [], [], [],[],[],[],[], [], []
   # i=0
    j=0
    floor_plan_count = @weekly_floor_plan.present? && @weekly_floor_plan.count > 0 ? (@weekly_floor_plan.count - 1) : 1
    weekly_dates.each_with_index do |weekly_time_period, i|
      weekly_time_period = DateTime.parse(weekly_time_period) rescue nil
      property_weekly_osr = @vacant_display[j]
      sql_time_period = property_weekly_osr.try(:time_period)  #rescue nil
      sql_time_period  = DateTime.parse(sql_time_period.to_s) rescue nil
      if weekly_time_period.eql?(sql_time_period)
        @property_week_vacant_total << make_nil_if_value_is_zero(property_weekly_osr.sum_vacant_total)
        @property_week_prelsd << make_nil_if_value_is_zero(property_weekly_osr.sum_prelsd)

        @vacant_net  << make_nil_if_value_is_zero(property_weekly_display(i,'vacant_net'))
        @property_weekly_ntv << make_nil_if_value_is_zero(property_weekly_osr.sum_ntv_status_total)
        @property_week_prelsd2 << make_nil_if_value_is_zero(property_weekly_osr.sum_prelsd2)
        @notice_net << make_nil_if_value_is_zero(property_weekly_display(i,'notice_net'))

        if @selected_floor_plan.present? && @selected_floor_plan.eql?("All")
          min_rent = (@weekly_floor_plan.present?  && property_weekly_osr.sum_min_rent.present? && !property_weekly_osr.sum_min_rent.to_f.eql?(0)) ? property_weekly_osr.sum_min_rent.to_f : nil #rescue nil
          @min_rent << make_nil_if_value_is_zero(min_rent)
        else
          @min_rent << make_nil_if_value_is_zero(property_weekly_osr.sum_min_rent)
        end
        if @selected_floor_plan.present? && @selected_floor_plan.eql?("All")
          max_rent = (@weekly_floor_plan.present?  && property_weekly_osr.sum_max_rent.present? && !property_weekly_osr.sum_max_rent.to_f.eql?(0)) ? property_weekly_osr.sum_max_rent.to_f : nil #rescue nil
          @max_rent << make_nil_if_value_is_zero(max_rent)
        else
          @max_rent <<  make_nil_if_value_is_zero(property_weekly_osr.sum_max_rent)
        end
        @pi_total << make_nil_if_value_is_zero(property_weekly_osr.sum_pi_total)

        @wi_total << make_nil_if_value_is_zero(property_weekly_osr.sum_wi_total)
        @dep_total << make_nil_if_value_is_zero(property_weekly_osr.sum_dep_total)
        @dep_rej << make_nil_if_value_is_zero(property_weekly_osr.sum_dep_rej)
        @dep_canc << make_nil_if_value_is_zero(property_weekly_osr.sum_dep_canc)

        @net_deposits <<  make_nil_if_value_is_zero(property_weekly_osr.sum_dep_total.to_f - (property_weekly_osr.sum_dep_rej.to_f + property_weekly_osr.sum_dep_canc.to_f))

        @total_inquiries << make_nil_if_value_is_zero(property_weekly_osr.sum_pi_total.to_f + property_weekly_osr.sum_wi_total.to_f)
        j = j+1
      else
        store_nil_values
      end
     # i = i + 1
    end
    @minimum_rent = @min_rent.compact.sort.first rescue nil
    return @vacant_net,@notice_net,@min_rent,@max_rent,@net_deposits,@minimum_rent,@week_array,@selected_floor_plan,@wi_total,@pi_total,@total_inquiries
  end

  def check_empty_values(value = [])
    value = value.uniq || []
    if value.present? && !value.eql?([0]) && !value.eql?([nil]) &&  !value.eql?([0.0])
      value = true
    else
      value = false
    end
    value
  end


  def store_nil_values()
    @property_week_vacant_total << nil
    @property_week_prelsd << nil
    @vacant_net  << nil
    @property_weekly_ntv << nil
    @property_week_prelsd2 << nil
    @notice_net << nil
    @min_rent << nil
    @max_rent <<  nil
    @pi_total << nil
    @wi_total << nil
    @dep_total << nil
    @dep_rej << nil
    @dep_canc << nil
    @net_deposits <<  nil
    @total_inquiries << nil
  end

  def make_nil_if_value_is_zero(value)
    if value.blank? || value.eql?(0) ||  value.eql?(0.0) || value.eql?("0") ||  value.eql?("0.0")
      value = nil
    else
      value
    end
    value
  end


  def get_last_12_months_array
    @dates_array, @dispaly_months=[],[]
    start_date = DateTime.now - 11.month
    for i in 0..11
      month_and_year = []
      date = start_date + i.month
      @dispaly_months << date.to_date.strftime("%b%y")
      month_and_year << date.month
      month_and_year << date.year
      @dates_array << month_and_year
    end
  end


  def get_market_and_lease_rent_graph
    get_last_12_months_array
    if @real_estate_property_ids.present?
      if @selected_floor_plan.present? &&  !@selected_floor_plan.eql?("All")
        property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids, :floor_plan => @selected_floor_plan).map(&:id)
      else
        property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids).map(&:id)
      end
    else
      if @selected_floor_plan.present? &&  !@selected_floor_plan.eql?("All")
        property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id, :floor_plan => @selected_floor_plan).map(&:id)
      else
        property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id).map(&:id)
      end
    end

    @base_rent, @effective_rate = [],[]
    @dates_array.each do |month_and_year|
      property_lease = PropertyLease.where(:property_suite_id => property_suite_ids, :month => month_and_year[0], :year => month_and_year[1]).select("sum(base_rent)/count(id) as base_rent, sum(effective_rate)/count(id)  as effective_rate ").first
      @base_rent << make_nil_if_value_is_zero(property_lease.base_rent)
      @effective_rate << make_nil_if_value_is_zero(property_lease.effective_rate)
    end
  end

  def get_vacant_units_for_waterfront_and_regular_units_graph
    get_last_12_months_array
    if @real_estate_property_ids.present?
      #      if @selected_floor_plan.present? &&  !@selected_floor_plan.eql?("All")
      #        vacant_regular_property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids, :is_waterfront => false, :floor_plan => @selected_floor_plan).map(&:id)
      #        vacant_waterfront_property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids, :is_waterfront => true, :floor_plan => @selected_floor_plan).map(&:id)
      #      else
      vacant_regular_property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids, :is_waterfront => false).map(&:id)
      vacant_waterfront_property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids, :is_waterfront => true).map(&:id)
      #      end
    else
      #      if @selected_floor_plan.present? &&  !@selected_floor_plan.eql?("All")
      #        vacant_regular_property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id, :is_waterfront => false, :floor_plan => @selected_floor_plan).map(&:id)
      #        vacant_waterfront_property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id, :is_waterfront => true, :floor_plan => @selected_floor_plan).map(&:id)
      #      else
      vacant_regular_property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id, :is_waterfront => false).map(&:id)
      vacant_waterfront_property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id, :is_waterfront => true).map(&:id)
      # end
    end

    @vacant_regualr_units, @vacant_waterfront_units = [], []
    @dates_array.each do |month_and_year|
      vacant_regualr_units = PropertyLease.where(:property_suite_id => vacant_regular_property_suite_ids, :month => month_and_year[0], :year => month_and_year[1]).where("tenant like 'Vacant%'").count
      vacant_waterfront_units = PropertyLease.where(:property_suite_id => vacant_waterfront_property_suite_ids, :month => month_and_year[0], :year => month_and_year[1]).where("tenant not like 'Vacant%'").count
      #total_regular_units = PropertyLease.where(:property_suite_id => vacant_regular_property_suite_ids, :month => month_and_year[0], :year => month_and_year[1]).count
      #total_waterfall_units = PropertyLease.where(:property_suite_id => vacant_waterfront_property_suite_ids, :month => month_and_year[0], :year => month_and_year[1]).count
      #vacant_regualr_units = total_regular_units.to_f.eql?(0.0) ? '0.0' : (vacant_regualr_units/total_regular_units.to_f)*100  rescue 0
      #vacant_waterfront_units = total_waterfall_units.to_f.eql?(0.0) ? '0.0' : (vacant_waterfront_units/total_waterfall_units.to_f)*100 rescue 0
      vacant_regualr_units = nil if vacant_regualr_units.eql?(0)
      vacant_waterfront_units = nil if vacant_waterfront_units.eql?(0)
      @vacant_regualr_units << vacant_regualr_units
      @vacant_waterfront_units << vacant_waterfront_units
    end
    return @vacant_regualr_units,@vacant_waterfront_units
  end

  def get_rent_units_for_waterfront_and_regular_units_graph
    get_last_12_months_array

    if @real_estate_property_ids.present?
      #      if @selected_floor_plan.present? &&  !@selected_floor_plan.eql?("All")
      #        rent_regular_property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids, :is_waterfront => false, :floor_plan => @selected_floor_plan).map(&:id)
      #        rent_waterfront_property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids, :is_waterfront => true, :floor_plan => @selected_floor_plan).map(&:id)
      #      else
      rent_regular_property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids, :is_waterfront => false).map(&:id)
      rent_waterfront_property_suite_ids = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids, :is_waterfront => true).map(&:id)
      #      end
    else
      #      if @selected_floor_plan.present? &&  !@selected_floor_plan.eql?("All")
      #        rent_regular_property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id, :is_waterfront => false, :floor_plan => @selected_floor_plan).map(&:id)
      #        rent_waterfront_property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id, :is_waterfront => true, :floor_plan => @selected_floor_plan).map(&:id)
      #      else
      rent_regular_property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id, :is_waterfront => false).map(&:id)
      rent_waterfront_property_suite_ids = PropertySuite.where(:real_estate_property_id => @note.id, :is_waterfront => true).map(&:id)
      #      end

    end
    @rent_regualr_averages, @rent_waterfront_averages = [], []


    @dates_array.each do |month_and_year|
      rent_regualr_units = PropertyLease.where(:property_suite_id => rent_regular_property_suite_ids, :month => month_and_year[0], :year => month_and_year[1]).sum(:base_rent)
      rent_waterfront_units = PropertyLease.where(:property_suite_id => rent_waterfront_property_suite_ids, :month => month_and_year[0], :year => month_and_year[1]).sum(:base_rent)
      total_regular_units = PropertyLease.where(:property_suite_id => rent_regular_property_suite_ids, :month => month_and_year[0], :year => month_and_year[1]).count
      total_waterfront_units = PropertyLease.where(:property_suite_id => rent_waterfront_property_suite_ids, :month => month_and_year[0], :year => month_and_year[1]).count
      rent_regualr_average = total_regular_units.to_f.eql?(0.0) ? '0.0' : rent_regualr_units/total_regular_units.to_f  rescue 0
      rent_waterfront_average = total_waterfront_units.to_f.eql?(0.0) ? '0.0' : rent_waterfront_units/total_waterfront_units.to_f rescue 0
      @rent_regualr_averages << make_nil_if_value_is_zero(rent_regualr_average)
      @rent_waterfront_averages << make_nil_if_value_is_zero(rent_waterfront_average)
    end
    return @rent_regualr_averages,@rent_waterfront_averages
  end



  def find_redmonth_start_for_recv(year_value)
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    year_value =find_selected_year(Date.today.year)
    month_val  =((params[:period] == "7"  || params[:tl_period] == "7") && !params[:cur_month].nil?) ? months.index(params[:cur_month]) + 1 : Date.today.prev_month.month
    if (params[:period] == "3"  || params[:tl_period] == "3") || (params[:period] == "6"  || params[:tl_period] == "6" || params[:tl_period] == "2")
      month_val = 12
    end
    portfolio_prop = RealEstateProperty.find(:all,:conditions=>['portfolios.id = ?',@note.id],:joins=>:portfolios,:select=>'real_estate_properties.id') if @note.try(:class).eql?(Portfolio)
    property_suite_ids = @note.try(:class).eql?(Portfolio) ? PropertySuite.find(:all,:conditions=>["real_estate_property_id IN (?)",portfolio_prop],:select=>'id')  : PropertySuite.find(:all,:conditions=>["real_estate_property_id = ?",@note.id],:select=>'id')
    #~ property_suite_ids = PropertySuite.find(:all,:conditions=>["real_estate_property_id = ?",@note.id],:select=>'id')
    insert_month_string =  ((@month_quarter) && (params[:tl_period] == "2" || params[:period] == "2")) ?  "month in (#{@month_quarter.join(',')})" : "month <= #{month_val}"
    #find_year = PropertyAgedReceivable.find(:first, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>["property_suite_id in (?) AND !(round(amount) = 0 AND round(over_30days) = 0 AND   round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0)", property_suite_ids],:include=>["property_suite"],:order => 'year desc' )
    find_year = PropertyAgedReceivable.find(:first, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>["year<= #{Date.today.year} AND !(round(amount) = 0 AND round(over_30days) = 0 AND  round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0) AND property_suite_id in (?)", property_suite_ids],:include=>["property_suite"],:order => 'year desc, month desc' )
    @year = find_year.try(:year)

    ## removed year condition as year is found in @year
    find_month = PropertyAgedReceivable.find(:first, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>[" month <= #{get_month(@year)} AND !(round(amount) = 0 AND round(over_30days) = 0 AND  round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0) AND property_suite_id in (?)", property_suite_ids],:include=>["property_suite"],:order => 'month desc' )


    month = find_year.try(:month)
    #account_receivables_aging_for_receivables = PropertyAgedReceivable.find(:first, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>["property_suite_id in (?) and year = ? AND !(round(amount) = 0 AND round(over_30days) = 0 AND   round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0)", property_suite_ids,@year.to_i],:include=>["property_suite"],:order => 'month desc' )
    @month_red_start  = month.blank? ? 0 : month.to_i + 12
  end

  def find_month_using_income_and_cash(year_value)
    acc_sys_type=AccountingSystemType.find_by_id(@note.accounting_system_type_id).try(:type_name)
    title_val=if acc_sys_type=="Real Page"
      "'maintenance projects'"
    elsif (acc_sys_type=="AMP Excel" || acc_sys_type=="YARDI V1")
      "'Capital Expenditures'"
    elsif remote_property(@note.accounting_system_type_id)
      "'REAL ESTATE UNDER DEVELOPMENT','TENANT IMPROVEMENTS','A/D-TENANT/LEASEHOLD IMPROVEMENTS','LEASEHOLD IMPROVEMENTS','LAND IMPROVEMENTS','A/D-LAND IMPROVEMENTS', 'TOTAL REAL ESTATE UNDER DEVELOPMENT'"
    else
      "'capital expenditures'"
    end
    @actuals  = PropertyFinancialPeriod.find_by_sql("SELECT pcb_type,january, february, march, april, may, june, july, august, september, october, november, december
        FROM property_financial_periods f INNER JOIN income_and_cash_flow_details i ON i.id = f.source_id AND i.resource_id =#{@note.id} AND f.pcb_type IN ('c') AND f.source_type = 'IncomeAndCashFlowDetail' AND i.year = '#{year_value}'AND   i.title  IN (#{title_val}) ORDER BY 'created_at' DESC LIMIT 1")
    if @actuals.empty?
      if remote_property(@note.accounting_system_type_id) && (params[:partial_page] == 'capital_expenditure'  || params[:cap_call_id] || params[:action] == "capital_expenditure")
        @month_red_start  = Date.today.year ==  year_value ? 24 : 0
      else
        @month_red_start  = 0
      end
    else
      financial_period =[@actuals[0].january,@actuals[0].february,@actuals[0].march,@actuals[0].april,@actuals[0].may,@actuals[0].june,@actuals[0].july,@actuals[0].august,@actuals[0].september,@actuals[0].october,@actuals[0].november,@actuals[0].december]
      num_add = Date.today.year ==  year_value ? 24 : 12
      @month_red_start =  financial_period.index(0.0) ? (financial_period.index(0.0)).to_i + num_add : num_add
      @month_red_start = financial_period.index(0.0) ? (financial_period.index(0.0) ? (financial_period.index(0.0)).to_i + num_add : num_add ) : ( financial_period.index(nil) ? (financial_period.index(nil)).to_i + num_add : num_add ) if remote_property(@note.accounting_system_type_id) && (params[:partial_page] == 'capital_expenditure'  || params[:cap_call_id] || params[:action] == "capital_expenditure")
      if @month_red_start && (params[:partial_page] =="cash_and_receivables" || params[:cash_call_id]) && @note.accounting_type != "Accrual"
        @month_red_start = 0
      end
    end
  end

  def  find_month_using_capital_improvement(max_month,year_value)
    source = @note.try(:class).eql?(Portfolio)  ? "portfolio_id"  : "real_estate_property_id"
    @actuals  = PropertyFinancialPeriod.find_by_sql("SELECT f.id,pcb_type,january, february, march, april, may, june, july, august, september, october, november, december
        FROM property_financial_periods f INNER JOIN property_capital_improvements i ON (i.id = f.source_id AND i.#{source} =#{@note.id} AND f.pcb_type IN ('c')  AND i.year = '#{year_value}'AND   i.category  IN ('Total Capital Expenditures') AND f.source_type = 'PropertyCapitalImprovement') ORDER BY i.month DESC LIMIT 1")
    if @actuals.empty?
      @month_red_start  = 0
    else
      financial_period =[@actuals[0].january,@actuals[0].february,@actuals[0].march,@actuals[0].april,@actuals[0].may,@actuals[0].june,@actuals[0].july,@actuals[0].august,@actuals[0].september,@actuals[0].october,@actuals[0].november,@actuals[0].december]
      num_add = Date.today.year ==  year_value ? 24 : 12
      @month_red_start = financial_period.index(0.0) ? (financial_period.index(0.0) ? (financial_period.index(0.0)).to_i + num_add : num_add ) : ( financial_period.index(nil) ? (financial_period.index(nil)).to_i + num_add : num_add ) if (params[:partial_page] == 'capital_expenditure'  || params[:cap_call_id] || params[:action] == "capital_expenditure")
    end
    return @month_red_start
  end

  def  find_timeline_selector_title(year_number,month_name)
    if @deactive_red
      return  "Data unavailable,click for more info"
    else
      return  "#{year_number}"
    end
  end

  def replace_time_line_selector(page)
    find_timeline_values
    if params[:partial_page]!="portfolio_partial"
      @summary_page=false
    end
    year_to_date= Date.today.prev_month.strftime("%m").to_i
    @months = []
    @month_list =[]
    for m in 1..12
      @month_list <<  Date.new(params[:tl_year].to_i,m,1).strftime("%Y-%m-%d")
    end
    if @month_list && !@month_list.empty?
      @month_list.each do |m|
        @months << m.split("-")[1]
      end
    end
    page.replace_html "time_line_selector", :partial => "/properties/time_line_selector", :locals => {:period => @period, :note_id => @note.id, :partial_page => "rent_roll", :start_date => 0, :timeline_start => @time_line_start_date, :timeline_end => @time_line_end_date }
  end

  def find_quarter_end_month(i)
    if(i == 0 || i == 4 || i == 8)
      month= 3
      year = i==8 ? Date.today.year : (i==0 ?  Date.today.prev_year.year - 1 : Date.today.prev_year.year)
    elsif(i == 1 || i == 5 || i == -1 || i ==9)
      month= 6
      year = i==9 ? Date.today.year : ((i==1 || i == -1) ?  Date.today.prev_year.year - 1 : Date.today.prev_year.year)
    elsif(i == 2 || i == 6 || i ==  -2 || i == 10)
      month= 9
      year = i==10 ? Date.today.year : ((i==2 || i == -2) ?  Date.today.prev_year.year - 1 : Date.today.prev_year.year)
    elsif(i == 3 || i == 7 || i == -3 || i == 11)
      month= 12
      year = i==11 ? Date.today.year : ((i==3 || i == -3) ?  Date.today.prev_year.year - 1 : Date.today.prev_year.year)
    end
    return month,year
  end

  def find_quarterly_month_year
    @ytd= []
    @month_list = []
    quarter_months =  [12,11,10,9,8,7,6,5,4,3,2,1,12,11,10]
    for quarter_month in quarter_months[params[:quarter_end_month].to_i]..quarter_months[params[:quarter_end_month].to_i] + 2
      m= quarter_months[quarter_month]
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
      @month_list <<  Date.new(Time.now.year,m,1).strftime("%Y-%m-%d")
    end
    return @ytd
  end

  def  find_quarterly_month_year_for_cap_exp
    @ytd_act= []
    @ytd_bud= []
    quarter_months =  [12,11,10,9,8,7,6,5,4,3,2,1,12,11,10]
    for quarter_month in quarter_months[params[:quarter_end_month].to_i]..quarter_months[params[:quarter_end_month].to_i] + 2
      m= quarter_months[quarter_month]
      @ytd_act << "IFNULL(pf1."+Date::MONTHNAMES[m].downcase+",0)"
      @ytd_bud << "IFNULL(pf2."+Date::MONTHNAMES[m].downcase+",0)"
    end
  end


  def find_month_list_for_quarterly
    find_quarterly_month_year
    month_val = @month_list
    @month_quarter=[]
    if month_val && !month_val.empty?
      month_val.each do|val|
        @month_quarter << val.split("-")[1].to_i
      end
    end
    return @month_quarter
  end

  #To dipaly quarterly message
  def set_quarterly_msg(page)
    if !@balance_sheet && params[:partial_page] != "cash_and_receivables_for_receivables" && params[:partial_page] != "rent_roll_highlight" && params[:partial_page] != "rent_roll" && params[:partial_page] !="leases" && params[:partial_page] !="lease_sub_tab"
      quarterly_timeline_msg = find_quarterly_each_msg(params[:quarter_end_month].to_i,params[:tl_year])
      page <<   "jQuery('#set_quarter_msg').html('#{quarterly_timeline_msg}');"
    elsif params[:partial_page] == "cash_and_receivables_for_receivables" || params[:partial_page] == "rent_roll_highlight" || params[:partial_page] == "rent_roll" || params[:partial_page] =="leases" || params[:partial_page] =="lease_sub_tab"
      page <<   "jQuery('#set_quarter_msg').html('');"
    end
  end

  def calculate_property_weekly_display_data(*date)
    connection = ActiveRecord::Base.connection();
    sel_date = date.empty? ? params[:start_date] : date.first

    if @real_estate_property_ids.present?
      real_estate_property_ids = @real_estate_property_ids.map { |i| "'" + i.to_s + "'" }.join(",")
      #if @selected_floor_plan.present? && !@selected_floor_plan.eql?("All")
      #vacant_query = "select vacant_total,prelsd,units,ntv_status_total,prelsd2,floor_plan,current,wk1,wk4,rtr,min_rent,max_rent,pi_total,wi_total,dep_total,dep_rej,dep_canc from property_weekly_osrs where real_estate_property_id IN (#{real_estate_property_ids}) and time_period = '#{sel_date}' and floor_plan='#{@selected_floor_plan}'"
      #else
      vacant_query = "select sum(vacant_total), sum(prelsd), sum(units), sum(ntv_status_total), sum(prelsd2),floor_plan, sum(current), sum(wk1), sum(wk4), sum(rtr), sum(min_rent), sum(max_rent), sum(pi_total) ,sum(wi_total) ,sum(dep_total), sum(dep_rej), sum(dep_canc) from property_weekly_osrs where real_estate_property_id IN (#{real_estate_property_ids}) and time_period = '#{sel_date}' group by floor_plan"
      #end
    else
      #if @selected_floor_plan.present? && !@selected_floor_plan.eql?("All")
      #vacant_query = "select vacant_total,prelsd,units,ntv_status_total,prelsd2,floor_plan,current,wk1,wk4,rtr,min_rent,max_rent,pi_total,wi_total,dep_total,dep_rej,dep_canc from property_weekly_osrs where real_estate_property_id = #{@note.id} and time_period = '#{sel_date}' and floor_plan='#{@selected_floor_plan}'"
      #else
      vacant_query = "select vacant_total,prelsd,units,ntv_status_total,prelsd2,floor_plan,current,wk1,wk4,rtr,min_rent,max_rent,pi_total,wi_total,dep_total,dep_rej,dep_canc from property_weekly_osrs where real_estate_property_id = #{@note.id} and time_period = '#{sel_date}'"
      #end
    end
    @vacant_display = connection.execute(vacant_query)
    @property_week_vacant_total,@property_week_prelsd,@property_week_units,@property_weekly_ntv,@property_week_prelsd2,@property_week_floor,@current,@wk1,@wk4,@rtr,@min_rent,@max_rent,@pi_total,@wi_total,@dep_total,@dep_rej,@dep_canc = [],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]
    @vacant_display.each do |row|
      @property_week_vacant_total << row[0]
      @property_week_prelsd << row[1]
      @property_week_units << row[2]
      @property_weekly_ntv << row[3]
      @property_week_prelsd2 << row[4]
      @property_week_floor << row[5]
      @current << row[6]
      @wk1 << row[7]
      @wk4 << row[8]
      @rtr << row[9]
      @min_rent << row[10]
      @max_rent << row[11]
      @pi_total << row[12]
      @wi_total << row[13]
      @dep_total << row[14]
      @dep_rej << row[15]
      @dep_canc << row[16]
    end
    return @property_week_vacant_total,@property_week_floor,@property_week_units,@property_week_prelsd
  end

  def property_weekly_display(i,val)
    case val
    when 'vacant_net' then @property_week_vacant_total[i].to_f-@property_week_prelsd[i].to_f
    when 'vacant_gross_per' then is_nan_checking_gross(@property_week_vacant_total[i].to_f,@property_week_units[i].to_f)
    when 'vacant_net_per' then is_nan_checking_net(@property_week_vacant_total[i].to_f,@property_week_prelsd[i].to_f,@property_week_units[i].to_f)
    when 'notice_net' then @property_weekly_ntv[i].to_i-@property_week_prelsd2[i].to_i
    when 'notice_gross_per' then is_nan_checking_gross(@property_weekly_ntv[i].to_f,@property_week_units[i].to_f)
    when 'notice_net_per' then is_nan_checking_net(@property_weekly_ntv[i].to_f,@property_week_prelsd2[i].to_f,@property_week_units[i].to_f)
    end
  end

  def property_weekly_display_net_units(i,val)
    case val
    when 'crnt' then is_nan_checking_gross(@current[i].to_f,@property_week_units[i].to_f)
    when 'wk1' then is_nan_checking_gross(@wk1[i].to_f,@property_week_units[i].to_f)
    when 'wk4' then is_nan_checking_gross(@wk4[i].to_f,@property_week_units[i].to_f)
    end
  end

  def net_per_calc(i,net)
    val = net == 'vacant_net_per' ? ((property_weekly_display(i,'vacant_net_per').gsub('%','').to_f)/20*100) : ((property_weekly_display(i,'notice_net_per').gsub('%','').to_f)/20*100)
    val = val >=100.0 ? 100.0 : val
    "#{val}%"
  end

  def crnt_per_calc(i)
    val = (property_weekly_display_net_units(i,'crnt').gsub('%','').to_f)/20*100
    val = val >=100.0 ? 100.0 : val
    "#{val}%"
  end

  def total_crnt_per_calc()
    val = (@netunits_avail_crnt_per.gsub('%','').to_f)/20*100
    val = val >=100.0 ? 100.0 : val
    "#{val}%"
  end

  def property_weekly_display_total(count)
    @vacant_units_total,@vacant_gross_total,@vacant_rented_total,@vacant_net_total,@vacant_gross_per,@vacant_net_p,@vacant_net,@notice_gross_total,@notice_rented_total,@notice_net_total,@netunits_avail_crnt_total,@netunits_avail_wk1_total,@netunits_avail_wk4_total,@total_rtr,@total_min_rent,@total_max_rent,@trafic_pi_total,@trafic_wi_total,@trafic_dep_total,@trafic_rej_total,@trafic_canc_total=0,0,0,0,0.0,0.0,0.0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    for i in 0...count
      @vacant_units_total+=@property_week_units[i].to_i
      @vacant_gross_total+=@property_week_vacant_total[i].to_i
      @vacant_rented_total+=@property_week_prelsd[i].to_i
      @vacant_net_total+=(@property_week_vacant_total[i].to_i-@property_week_prelsd[i].to_i)
      @vacant_net+=(@property_week_vacant_total[i].to_f-@property_week_prelsd[i].to_f)
      @notice_gross_total+=@property_weekly_ntv[i].to_i
      @notice_rented_total+=@property_week_prelsd2[i].to_i
      @notice_net_total+=property_weekly_display(i,'notice_net')
      @netunits_avail_crnt_total+=@current[i].to_i
      @netunits_avail_wk1_total+=@wk1[i].to_i
      @netunits_avail_wk4_total+=@wk4[i].to_i
      @total_rtr+=@rtr[i].to_i
      @total_min_rent+=@min_rent[i].to_i
      @total_max_rent+=@max_rent[i].to_i
      @trafic_pi_total+=@pi_total[i].to_i
      @trafic_wi_total+=@wi_total[i].to_i
      @trafic_dep_total+=@dep_total[i].to_i
      @trafic_rej_total+=@dep_rej[i].to_i
      @trafic_canc_total+=@dep_canc[i].to_i
    end
    @vacant_gross_per = "#{number_with_precision((@vacant_gross_total.to_f/@vacant_units_total.to_f)*100, :precision => 1)}%"
    @vacant_net_per = "#{number_with_precision(((@vacant_gross_total.to_f-@vacant_rented_total.to_f)/@vacant_units_total)*100, :precision => 1)}%"
    @notice_gross_per = "#{number_with_precision((@notice_gross_total.to_f/@vacant_units_total.to_f)*100, :precision => 1)}%"
    @notice_net_per = "#{number_with_precision(((@notice_gross_total.to_f-@notice_rented_total.to_f)/@vacant_units_total)*100, :precision => 1)}%"
    @netunits_avail_crnt_per = "#{number_with_precision((@netunits_avail_crnt_total.to_f/@vacant_units_total.to_f)*100, :precision => 1)}%"
    @netunits_avail_wk1_per = "#{number_with_precision((@netunits_avail_wk1_total.to_f/@vacant_units_total.to_f)*100, :precision => 1)}%"
    @netunits_avail_wk4_per = "#{number_with_precision((@netunits_avail_wk4_total.to_f/@vacant_units_total.to_f)*100, :precision => 1)}%"
    return @vacant_units_total,@vacant_gross_total,@vacant_rented_total,@vacant_net_total,@vacant_gross_per,@vacant_net_per
  end

  def bar_percentage_calc(i,type,value=nil)
    case type
    when 'summary_occupancy_per' then val = value.to_f
    when 'property_yardi_netunits_avail_per' then val = (value.gsub('%','').to_f)/20*100
    when 'property_yardi_netunits_avail_total_per' then val = (value.gsub('%','').to_f)/20*100
    when 'vacant_net_per' then val = (value.gsub('%','').to_f)/20*100
    when 'notice_net_per' then val = (value.gsub('%','').to_f)/20*100
    when 'vacant_total_net_per' then val = (@vacant_net_per.gsub('%','').to_f)/20*100
    when 'notice_total_net_per' then val = (@notice_net_per.gsub('%','').to_f)/20*100
    when 'property_week_net_units' then val = (value.gsub('%','').to_f)/20*100
    when 'property_week_total_net_units' then val = (@netunits_avail_crnt_per.gsub('%','').to_f)/20*100
    end
    val = val >= 100.0 ? 100.0 : val
    "#{val}%"
  end


  def total_net_per_calc
    val = (@vacant_net_per.gsub('%','').to_f)/20*100
    val = val >= 100.0 ? 100.0 : val
    "#{val}%"
  end

  def total_notice_net_per_calc
    val = (@notice_net_per.gsub('%','').to_f)/20*100
    val = val >=100.0 ? 100.0 : val
    "#{val}%"
  end

  def property_weekly_display_calc
  end

  def calculate_portfolio_weekly_report(prop_id,prev_date)
    connection = ActiveRecord::Base.connection();
    vacant_query = "select vacant_total,prelsd,units,ntv_status_total,prelsd2,floor_plan,current,wk1,wk4,rtr,min_rent,max_rent,pi_total,wi_total,dep_total,dep_rej,dep_canc from property_weekly_osrs where real_estate_property_id = #{prop_id} and time_period = '#{prev_date}'"
    @vacant_display = connection.execute(vacant_query)
    @property_week_vacant_total,@property_week_prelsd,@property_week_units,@property_weekly_ntv,@property_week_prelsd2,@property_week_floor,@current,@wk1,@wk4,@rtr,@min_rent,@max_rent,@pi_total,@wi_total,@dep_total,@dep_rej,@dep_canc = [],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]
    @vacant_display.each do |row|
      @property_week_vacant_total << row[0]
      @property_week_prelsd << row[1]
      @property_week_units << row[2]
      @property_weekly_ntv << row[3]
      @property_week_prelsd2 << row[4]
      @property_week_floor << row[5]
      @current << row[6]
      @wk1 << row[7]
      @wk4 << row[8]
      @rtr << row[9]
      @min_rent << row[10]
      @max_rent << row[11]
      @pi_total << row[12]
      @wi_total << row[13]
      @dep_total << row[14]
      @dep_rej << row[15]
      @dep_canc << row[16]
    end
  end
  def find_property(prop_id)
    RealEstateProperty.find_real_estate_property(prop_id).property_name if RealEstateProperty.find_real_estate_property(prop_id)
  end
  def find_property_address(prop_id)
    property = RealEstateProperty.find_real_estate_property(prop_id)
    province = property.address.province
    city = property.address.city
    if city.empty?
      return province
    else
      return "#{city}, #{province}"
    end
  end
  def prev_or_next_date
    if params[:prev_date] && !params[:prev_date].blank?
      index = @date_array.index{|x| x== params[:prev_date]}
    elsif params[:next_date] && !params[:next_date].blank?
      index = @date_array.index{|x| x== params[:next_date]}
    elsif params[:cur_date] && !params[:cur_date].blank?
      index = @date_array.index{|x| x== params[:cur_date]}
    else
      index = @date_array.index{|x| x== @prev_sunday.strftime("%B %d,%Y")}
    end
    return @date_array[index-1],@date_array[index],@date_array[index+1],index
  end

  def date_calc(real_properties)
    @date_array,@date_element,@prop_id_coll=[],[],[]
    #RealEstateProperty.find_owned_and_shared_properties(@portfolio,current_user.id).select {|i| @prop_id_coll<<i.id}
    real_properties.select {|i| @prop_id_coll<<i.id}
    @prev_sunday = (Time.now.to_date-Time.now.wday)
    @start_date = (@prev_sunday-(7*7)).strftime("%B %d,%Y")
    @end_date = (@prev_sunday+(1*7)).strftime("%B %d,%Y")
    for i in 0...10
      @date_array << "#{(@start_date.to_date+(i*7)).strftime("%B %d,%Y")}"
      @date_element << "#{(@start_date.to_date+(i*7)).strftime("%Y-%m-%d")}"
    end
  end
  def portfolio_class_name(j)
    j.even? ? "portfolioweek_tablerow" : "portfolio_tablegraycontentrow3"
  end

  def account_system_type_name(id)
    AccountingSystemType.find_by_id(id).nil? ? "" : AccountingSystemType.find_by_id(id).type_name
  end

 	def is_nan_checking_gross(a,b)
    value = number_with_precision((a/b)*100, :precision => 1)
    is_nan =  a/b
    value = is_nan.nan? ? 0.0  : value
    "#{value}%"
  end

 	def is_nan_checking_net(a,b,c)
    value = number_with_precision(((a-b)/c)*100, :precision => 1)
    is_nan =  (a-b)/c
    value = is_nan.nan? ? 0.0  : value
    "#{value}%"
  end

  #balance sheet main page
  def balance_sheet
    @balance_sheet = true
    common_financial_wres_swig(params,"balance_sheet")
  end

  #balance sheet sub page
  def balance_sheet_sub_page
    @balance_sheet = true
    financial_sub_items
    render :action => 'balance_sheet_sub_page.rjs'
  end

  # Called from financial & change date methods
  def financial_month(tl_month=nil, tl_year=nil)
    find_dashboard_portfolio_display
    @notes = RealEstateProperty.find_properties_by_portfolio_id(params[:portfolio_id]) if params[:portfolio_id].present?
    @record_year = find_record_year
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? and year=?",@note.id, @resource,@record_year])
    today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(today_year,12,31)
    @actual = @time_line_actual
    @debt_services=[]
    @financial=true
    if Date.today.month == 1 && !params[:start_date]
      @tl_month = Date.today.months_ago(1).month
      @tl_year = Date.today.years_ago(1).year
      @explanation=true
    end
    if !params[:start_date].nil?
      @tl_month = params[:start_date].split("-")[1].to_i
      @tl_year =  params[:start_date].split("-")[0].to_i
    elsif params[:start_date].nil?
      @tl_month = (params[:tl_month].nil?) ? (tl_month.nil? ? Date.today.month : tl_month) : params[:tl_month].to_i
      @tl_year = params[:tl_year].nil? ? (tl_year.nil? ? Date.today.year : tl_year) : params[:tl_year].to_i
    end
    if params[:cur_month] && params[:tl_period] == "7"
      @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
      @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
      @tl_month = @end_date.to_date.month
      @tl_year = @start_date.to_date.year
    end
    financial_function_calls
  end

  #To collect title for summary financial data display
  def find_financial_title_summary
    if @note && remote_property(@note.accounting_system_type_id)
      financial_title = "'NET INCOME BEFORE DEPR & AMORT','net operating income'"
    else
      financial_title = "'Operating Summary','Non Operating Revenues','Non Operating Expense','Non Operating Summary','INCOME STATEMENT','cash flow statement summary','operating statement summary','net operating income','cash flow from operating activities','other income and expense'"
    end
  end


  def find_occupancy_max_year(property_id)
    max_year  =  PropertyOccupancySummary.find_by_sql("SELECT max(`year`) as year FROM property_occupancy_summaries o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id} and r.id = #{property_id}")
    return max_year[0].year if max_year && max_year[0]
  end

  def bar_percentage_dashboard(val,flag=nil)
    val = val.to_f/20*100 if flag
    val = val >=100.0 ? 100.0 : val
    "#{val.round}%"
  end

  def bar_percentage_dashboard_without_round(val,flag=nil)
    val = val.to_f/20*100 if flag
    val = val >=100.0 ? 100.0 : val
    "#{val}%"
  end


  def find_occupancy_values
    suite = Suite.find_by_sql("select sum(suites.rentable_sqft) as total_rentable_space from suites where suites.real_estate_property_id = #{@note.id}")
    suite.each do |val|
      @suite_val =  val.total_rentable_space
    end
    vacant_suite = Suite.find_by_sql("select sum(suites.rentable_sqft) as current_vacant from suites where suites.status = 'Vacant' and suites.real_estate_property_id = #{@note.id} ")
    vacant_suite.each do |vac|
      @vacant_suite = vac.current_vacant
    end
    occ_suite = Suite.find_by_sql("select sum(suites.rentable_sqft) as occupied from suites where suites.status ='Occupied' and suites.real_estate_property_id = #{@note.id} ")
    occ_suite.each do |occ|
      @occ_suite = occ.occupied
    end
    time = Time.now

    @suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
    year_value = (params[:tl_period].present? && params[:tl_period] == "3") ?  Date.today.prev_year.year : Date.today.year
    year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and  year <= ?',@suites,year_value],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
    if year
      year = year.compact.empty? ? nil : year[0].year
      month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ?',@suites,year,get_month(year)],:select=>"month").map(&:month).max if !@suites.blank?
    end
    lease_records = LeaseRentRoll.find(:all,:conditions=>["((occupancy_type = 'new' or occupancy_type = 'current') and lease_start_date between '#{Date.today.year}-01-01' and '#{Date.today.year}-#{Date.today.month}-31' and real_estate_property_id = #{@note.id} and month = '#{month}' AND year = #{year})"]) if month.present? && year.present?
    lease_records_exp = LeaseRentRoll.find(:all,:conditions=>["occupancy_type = ? and real_estate_property_id = ? and month = '#{month}' AND year = #{year} AND lease_end_date between '#{Date.today.year}-01-01' and '#{Date.today.year}-#{Date.today.month}-31'",'expirations',@note.id ]) if month.present? && year.present?
    suite_ids = lease_records.collect{|record| record.suite_id}       if lease_records && !lease_records.empty?
    suite_ids_exp = lease_records_exp.collect{|record| record.suite_id}       if lease_records_exp && !lease_records_exp.empty?
    new_lease_rentable_sqft = Suite.find_by_sql("select sum(suites.rentable_sqft) as occupied from suites where suites.real_estate_property_id = #{@note.id} and suites.id IN (#{suite_ids.join(',')})") if suite_ids &&  !suite_ids.empty?
    expiration_rentable_sqft = Suite.find_by_sql("select sum(suites.rentable_sqft) as occupied from suites where suites.real_estate_property_id = #{@note.id} and suites.id IN (#{suite_ids_exp.join(',')})") if suite_ids_exp &&  !suite_ids_exp.empty?

    #Renewal option update start - Need to change this based on lease_id#
    lease_records_renewal = LeaseRentRoll.find(:all,:conditions=>["occupancy_type = 'renewal' and real_estate_property_id = #{@note.id} and month = '#{month}' AND year = #{year}"]) if month.present? && year.present?
    suite_ids_for_renewal = lease_records_renewal.collect{|record| record.suite_id}  if lease_records_renewal && !lease_records_renewal.empty?
    renewal_rentable_sqft = Suite.find_by_sql("select sum(suites.rentable_sqft) as occupied from suites where suites.real_estate_property_id = #{@note.id} and suites.id IN (#{ suite_ids_for_renewal.join(',')})") if suite_ids_for_renewal.present? &&  !suite_ids_for_renewal.empty?
    #Renewal option update end#

    if @suite_val.present?
      lease_occ = CommercialLeaseOccupancy.find_or_create_by_real_estate_property_id(@note.id)
      lease_occ.current_year_sf_occupied_actual = @occ_suite
      lease_occ.current_year_sf_vacant_actual = @vacant_suite
      lease_occ.year = time.year
      lease_occ.month = time.month
      lease_occ.new_leases_actual = new_lease_rentable_sqft.present? ? new_lease_rentable_sqft[0].occupied : ""
      lease_occ.expirations_actual = expiration_rentable_sqft.present? ? expiration_rentable_sqft[0].occupied : ""
      lease_occ.renewals_actual =   renewal_rentable_sqft.present? ? renewal_rentable_sqft[0].occupied : ""
      lease_occ.save
    end
    return @vacant_suite,@occ_suite,@suite_val
  end

  #Method for Print Pdf  Cover page Timline option display#
  def find_selected_year_and_option
    year = find_selected_year(Date.today.year)
    months = ["","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    if (params[:period] == '1' || params[:tl_period] == '1' || params[:period] == '10' || params[:tl_period] == '10' || params[:period] == '5' || params[:tl_period] == '5')
      @option = months[params[:tl_month].to_i] +' - ' + "#{year}"
    elsif (params[:period] == '2' || params[:tl_period] == '2')
      @option = "Quarterly - #{year}"
    elsif (params[:period] == '3' || params[:tl_period] == '3' || params[:period] == '6' || params[:tl_period] == '6')
      @option ="Year - #{year}"
    elsif (params[:period] == '4' || params[:tl_period] == '4'|| params[:period] == "9" || params[:tl_period] == "9")
      @option = "YTD - #{year}"
    elsif (params[:period] == '7' || params[:tl_period] == '7')
      @option = "#{params[:cur_month]} YTD - #{params[:cur_year]}"  rescue "Month YTD"
    elsif (params[:period] == '8' || params[:tl_period] == '8')
      @option = "YearForecast - #{year}"
    end
    return @option
  end

  #find vacancy budget for pipeline header#
  def find_vacant_for_pipeline
    act_total = @occupancy_summary.current_year_sf_vacant_actual.to_f + @occupancy_summary.current_year_sf_occupied_actual.to_f
    diff = @occupancy_summary.current_year_sf_vacant_actual.to_f - @occupancy_summary.current_year_sf_vacant_budget.to_f
    @occupancy_graph[:vacant] = {:value => @occupancy_summary.current_year_sf_vacant_actual.to_f.abs,:val_percent => (@occupancy_summary.current_year_sf_vacant_actual.to_f.abs*100)/act_total.to_f ,:diff => diff.abs,:diff_percent =>  (diff.abs*100)/@occupancy_summary.current_year_sf_vacant_budget.to_f.abs ,:style => (diff >= 0 ?  "redrow2" : "greenrow" )  ,:diff_word => (diff >= 0 ?  "above" : "below" )}
  end
end
