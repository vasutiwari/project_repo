module WresPerformanceReviewHelper

  def wres_for_notes_year_to_date
    id_val = params[:note_id] ? params[:note_id] : (params[:id] ? params[:id] : 0)
    @note = RealEstateProperty.find_real_estate_property(id_val) if @note.nil?
    @notes = RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id)
    if @portfolio.user_id != current_user.id || params[:prop_folder]
      @shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{current_user.id })")
      prop_condition = "and r.id in (#{@shared_folders.collect {|x| x.real_estate_property_id}.join(',')})"  if !(@portfolio.nil? || @portfolio.blank? || @shared_folders.nil? || @shared_folders.blank?)
      @notes = RealEstateProperty.find_properties_by_portfolio_id_with_cond(@portfolio.id,prop_condition,"order by r.created_at desc")   if !(@portfolio.nil? || @portfolio.blank? || @shared_folders.nil? || @shared_folders.blank?)
      @note =  RealEstateProperty.find_properties_by_portfolio_id(@portfolio.id) if !@portfolio.nil?
    end
    @prop = RealEstatePropertyStateLog.find_by_state_id_and_real_estate_property_id(5,@note.id) if @note.nil
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, 'RealEstateProperty'])
    @time_line_start_date,@time_line_end_date,@ytd = Date.new(2010,1,1),Date.today.end_of_month,[]
    year_to_date= params[:period] == '7' || params[:tl_period] == '7' ? @end_date.to_date.month : Date.today.prev_month.month
    for m in 1..year_to_date
      @ytd << Date::MONTHNAMES[m].downcase
    end
    @ytd_cal_flag,@actual = "false",@time_line_actual
#    if @initial_val
      if Date.today.month == 1
        @ytd_cal_flag = "true"
        #store_income_and_cash_flow_statement_for_month(Date.today.prev_month.month.to_i,Date.today.prev_month.year.to_i)
        wres_executive_overview_details(Date.today.prev_month.month,Date.today.prev_month.year)
      else
        wres_executive_overview_details_for_year
      end
#    end
  end

  def wres_executive_overview_details(month_val=nil,year=nil)
    wres_store_income_and_cash_flow_statement_for_month(month_val,year)
    wres_other_income_and_expense_details_for_month(month_val,year)
    @property_occupancy_summary =  PropertyOccupancySummary.find_by_real_estate_property_id_and_month_and_year(@note.id,month_val,year)
    wres_occupancy_data_calculation if !@property_occupancy_summary.nil?
  end

  # Executive summary for year-to-date funcationalcity
  def wres_executive_overview_details_for_year
    @ytd_t=true
    wres_store_income_and_cash_flow_statement
    wres_other_income_and_expense_details
    @property_occupancy_summary = PropertyOccupancySummary.find(:first,:conditions => ["real_estate_property_id=? and year=? and month < ?",@note.id,Date.today.year,get_month],:order => "month desc")
    wres_occupancy_data_calculation if !@property_occupancy_summary.nil?
  end

  def wres_executive_overview_details_for_prev_year
    @ytd_t=true
    wres_store_income_and_cash_flow_statement_for_prev_year
    wres_other_income_and_expense_details_for_prev_year
    @property_occupancy_summary = PropertyOccupancySummary.find(:first,:conditions => ["real_estate_property_id=? and year=? ",@note.id,Date.today.prev_year.year],:order => "month desc")
    wres_occupancy_data_calculation if !@property_occupancy_summary.nil?
  end

  # Income & cash flow details calculation for the month
  def wres_store_income_and_cash_flow_statement_for_month(month_val=nil,year=nil)
   year_to_date= !month_val.nil? ? month_val : Date.today.prev_month.month
    @operating_statement,@cash_flow_statement,@ytd,@current_time_period,@explanation={},{},[],Date.new(year,year_to_date,1),true
    year = Date.today.year  if year.nil?
    @ytd << "IFNULL(f."+Date::MONTHNAMES[year_to_date].downcase+",0)"
    if @portfolio_summary == true
      qry = wres_get_query_for_portfolio_summary(year)
    else
      qry = wres_get_query_for_each_summary(year)
    end
    @op_ex = IncomeAndCashFlowDetail.find(:first,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id,'RealEstateProperty','operating expenses',year])
    @op_in  = IncomeAndCashFlowDetail.find(:first,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id,'RealEstateProperty','operating income',year])
    if qry != nil
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      for cash_row in asset_details
        if cash_row.Parent == "cash flow statement summary"
          @cash_flow_statement[cash_row.Title] = wres_form_hash_of_data(cash_row)
        else
          data = wres_form_hash_of_data(cash_row)
          @operating_statement[cash_row.Title] = data
          @cash_flow_statement[cash_row.Title] = data if cash_row.Title == "depreciation & amortization detail" or cash_row.Title =="net income"
        end
      end
      wres_net_income_operation_summary_report
    end
    @portfolio_summary = false
  end

  # Net operating income details display in executive summary
  def wres_net_income_operation_summary_report
    @divide = 1
    if @operating_statement.length > 1 and @operating_statement['net operating income']
      @divide = 1
      if !@operating_statement['operating expenses'].nil?
        @divide = (@operating_statement['operating expenses'][:actuals].abs > @operating_statement['operating income'][:actuals].abs) ? @operating_statement['operating expenses'][:actuals].abs : @operating_statement['operating income'][:actuals].abs
      end
      @net_income_de={}
      @net_income_de['diff'] = (@operating_statement['net operating income'][:budget] - @operating_statement['net operating income'][:actuals]).abs
      percent =  ((@net_income_de['diff']*100) / @operating_statement['net operating income'][:budget]).abs rescue ZeroDivisionError
      if @operating_statement['net operating income'][:budget].to_f==0
        percent = ( @operating_statement['net operating income'][:actuals].to_f == 0 ? 0 : -100 )
      end
      @net_income_de['diff_per'] = percent  #((@net_income_de['diff']*100) / @operating_statement['net operating income'][:budget]).abs
      @net_income_de['diff_word'] = (@operating_statement['net operating income'][:budget] > @operating_statement['net operating income'][:actuals]) ? 'below' : 'above'
      @net_income_de['diff_style'] =  (@net_income_de['diff_word'] == 'above') ? 'greenrow' : 'redrow'
    end
  end

  def wres_get_query_for_each_summary(year)
    if @financial
           financial_title = @note && (find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note) ) ? "'Operating Summary','Non-Op Revenue','Non Operating Expense','Non Operating Summary','INCOME STATEMENT'" : "'cash flow statement summary', 'operating statement summary','net operating income','cash flow from operating activities','NET INCOME BEFORE DEPR & AMORT'"
      "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(child_id) as Record_id from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget , a.id as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN (#{financial_title}) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN (#{financial_title}) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"
    else
          financial_title = @note && (find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note) ) ? "'Operating Summary','Non-Op Revenue','Non Operating Expense','Non Operating Summary','INCOME STATEMENT'" : "'operating statement summary','current rent','other income and expense','NET INCOME BEFORE DEPR & AMORT'"
      "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(variance) as Variance,sum(child_id) as Record_id from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget ,0 as variance, a.id as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN (#{financial_title}) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as variance,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN (#{financial_title}) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, 0 as budget ,#{@ytd.join("+")} as variance,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN (#{financial_title}) AND f.pcb_type IN ('var_amt') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"
    end
  end

  def wres_store_income_and_cash_flow_statement
    @operating_statement,@cash_flow_statement,@ytd,@month_list={},{},[],[]
    year_to_date= (params[:period] == "7" || params[:tl_period] == "7") ? @end_date.to_date.month : Date.today.prev_month.month
    year = (params[:period] == "7" || params[:tl_period] == "7") ? @start_date.to_date.year : Date.today.year
    for m in 1..year_to_date
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
      if params[:period] == '7' || params[:tl_period] == "7"
      @month_list <<  Date.new(@start_date.to_date.year,m,1).strftime("%Y-%m-%d")
      else
      @month_list <<  Date.new(Time.now.year,m,1).strftime("%Y-%m-%d")
      end
    end
    if @portfolio_summary == true
      qry = wres_get_query_for_portfolio_summary(year)
    else
      qry = wres_get_query_for_each_summary(year)
    end
    @op_ex = IncomeAndCashFlowDetail.find(:first,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id,'RealEstateProperty','operating expenses',year])
    @op_in  = IncomeAndCashFlowDetail.find(:first,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id,'RealEstateProperty','operating income',year])
    if qry != nil
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      for cash_row in asset_details
        val ={}
        if cash_row.Parent == "cash flow statement summary"
          @cash_flow_statement[cash_row.Title] = wres_form_hash_of_data(cash_row)
        else
          data = wres_form_hash_of_data(cash_row)
          @operating_statement[cash_row.Title] = data
          @cash_flow_statement[cash_row.Title] = data if cash_row.Title == "depreciation & amortization detail" or cash_row.Title =="net income"
        end
      end
      wres_net_income_operation_summary_report
    end
    @portfolio_summary = false
  end

  def wres_store_income_and_cash_flow_statement_for_prev_year
    @operating_statement,@cash_flow_statement,year,@ytd,@month_list={},{},Date.today.prev_year.year,[],[]
    for m in 1..12
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
      @month_list <<  Date.new(year,m,1).strftime("%Y-%m-%d")
    end
    if @portfolio_summary == true
      qry = wres_get_query_for_portfolio_summary(year)
    else
      qry = wres_get_query_for_each_summary(year)
    end
    @op_ex = IncomeAndCashFlowDetail.find(:first,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id,'RealEstateProperty','operating expenses',year])
    @op_in  = IncomeAndCashFlowDetail.find(:first,:conditions => ["resource_id =? and resource_type=? and title=? and year=?",@note.id,'RealEstateProperty','operating income',year])
    if qry != nil
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      for cash_row in asset_details
        if cash_row.Parent == "cash flow statement summary"
          @cash_flow_statement[cash_row.Title] = wres_form_hash_of_data(cash_row)
        else
          data = wres_form_hash_of_data(cash_row)
          @operating_statement[cash_row.Title] = data
          @cash_flow_statement[cash_row.Title] = data if cash_row.Title == "depreciation & amortization detail" or cash_row.Title =="net income"
        end
      end
      wres_net_income_operation_summary_report
    end
    @portfolio_summary = false
    @explanation = false
  end

  def wres_form_hash_of_data(cash_row)
    if !cash_row[:Record_id].nil?
      val ={:actuals => cash_row.Actuals.to_f,:budget => cash_row.Budget.to_f,:variant => cash_row.Variance.to_f,:record_id=>cash_row.Record_id}
    else
      val ={:actuals => cash_row.Actuals.to_f,:budget => cash_row.Budget.to_f,:variant => cash_row.Variance.to_f,:record_id=>0}
    end
    variant = val[:variant] #.to_f-val[:actuals].to_f
    percent = variant*100/val[:budget].to_f.abs rescue ZeroDivisionError
    if  val[:budget].to_f==0
      percent = ( val[:actuals].to_f == 0 ? 0 : -100 )
    end
    percent=0.0 if percent.to_f.nan?
    val[:percent],val[:status] = percent,true
    return val
  end

  def wres_other_income_and_expense_query(year)
    if @note && remote_property(@note.accounting_system_type_id)
      cap_exp_title = "'ASSETS','FURNITURE, FIXTURES & EQUIPMENT'"
    else
      cap_exp_title = "'maintenance projects','Capital Expenditures'"
    end
    "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(variance) as Variance,sum(child_id) as Record_id from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget ,0 as variance, a.id as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = (#{@resource}) AND k.title IN (#{cap_exp_title}) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' group by title UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as variance,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = (#{@resource}) AND k.title IN (#{cap_exp_title}) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' group by title  UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, 0 as budget ,#{@ytd.join("+")} as variance,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = (#{@resource}) AND k.title IN (#{cap_exp_title}) AND f.pcb_type IN ('var_amt') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' group by title) xyz group by Parent, Title"
  end

  def wres_other_income_and_expense_details_for_month(month_val=nil,year=nil)
    year_to_date= !month_val.nil? ? month_val : Date.today.prev_month.month
    year = Date.today.year  if year.nil?
    @current_time_period=Date.new(year,year_to_date,1)
    @ytd= []
    @ytd << "IFNULL(f."+Date::MONTHNAMES[year_to_date].downcase+",0)"
    wres_other_details_display_calculation(year)
  end

  def wres_other_income_and_expense_details
    @ytd,@month_list= [],[]
    calc_for_financial_data_display
    year_to_date = params[:period] == '7' || params[:tl_period] == '7' ? @end_date.to_date.month : @financial_month
    year = params[:period] == '7' || params[:tl_period] == '7' ? @start_date.to_date.year : find_selected_year(Date.today.year)
   if (params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
     find_quarterly_month_year
   else
    for m in 1..year_to_date
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
      if params[:period] == "7" || params[:tl_period] == "7"
      @month_list <<  Date.new(year,m,1).strftime("%Y-%m-%d")
      else
      @month_list <<  Date.new(Time.now.year,m,1).strftime("%Y-%m-%d")
      end
    end
   end
    wres_other_details_display_calculation(year)
  end

  def wres_other_income_and_expense_details_for_prev_year
    year_to_date,year,@ytd,@month_list= Date.today.prev_month.month,Date.today.prev_year.year,[],[]
    year = find_selected_year(year)
    for m in 1..12
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
      @month_list <<  Date.new(year,m,1).strftime("%Y-%m-%d")
    end
    wres_other_details_display_calculation(year)
  end

  def wres_other_details_display_calculation(year)
    find_dashboard_portfolio_display
    acc_sys_type=AccountingSystemType.find_by_id(@note.accounting_system_type_id).try(:type_name)
    if is_commercial(@note) && !remote_property(@note.accounting_system_type_id)
      capital_expenditure_for_yr_forecast if (params[:tl_period]=="8" || params[:period]=="8") || ((params[:tl_period]=="3" || params[:period]=="3") && year >= Date.today.year)
      capital_expenditure_for_month(params[:tl_month],params[:tl_year]) if !(params[:tl_period]=="8" || params[:period]=="8")
    end
    if ((acc_sys_type!="MRI, SWIG" && (!@capital_percent || @capital_percent.empty?)) || is_multifamily(@note))
    title_val=if (acc_sys_type=="Real Page")
      'maintenance projects'
    elsif (find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note))
      'Capital Expenditures'
    else
      'capital expenditures'
    end
    @other_income_and_expenses = {}
    qry = if params[:tl_period]=="8" || params[:period]=="8"
      wres_other_income_and_expense_for_year_forecast(year)
    else
      wres_other_income_and_expense_query(year)
    end
    @other_bar={}
    @count=0
    @sum_bud = 0
    @sum_act = 0
    if qry != nil
      other_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      other_details && other_details.each_with_index do |cash_row,ind|
        if cash_row.Title != "maintenance projects"
        if ind < 4 || remote_property(@note.accounting_system_type_id)
          if remote_property(@note.accounting_system_type_id)
            if cash_row.Title == 'REAL ESTATE UNDER DEVELOPMENT' || cash_row.Title == 'TENANT IMPROVEMENTS' || cash_row.Title == 'A/D-TENANT/LEASEHOLD IMPROVEMENTS' || cash_row.Title == 'LEASEHOLD IMPROVEMENTS' || cash_row.Title == 'LAND IMPROVEMENTS' || cash_row.Title == 'A/D-LAND IMPROVEMENTS' || cash_row.Title == 'TOTAL REAL ESTATE UNDER DEVELOPMENT'
             @other_income_and_expenses[cash_row.Title ] = wres_form_hash_of_data(cash_row)
              @other_bar[cash_row.Title ] = @other_income_and_expenses[cash_row.Title ][:actuals]  *100 / @other_income_and_expenses[cash_row.Title ][:actuals]  if @other_income_and_expenses[cash_row.Title ] and @other_income_and_expenses[cash_row.Title ][:actuals]
               @sum_bud =  @sum_bud + @other_income_and_expenses[cash_row.Title][:budget]
               @sum_act =  @sum_act + @other_income_and_expenses[cash_row.Title][:actuals]
              end
            else
               @other_income_and_expenses[cash_row.Title] = wres_form_hash_of_data(cash_row)
          @other_bar[cash_row.Title] = @other_income_and_expenses[cash_row.Title][:actuals]  *100 / @operating_statement[title_val][:actuals]  if @other_income_and_expenses[cash_row.Title] and @other_income_and_expenses[cash_row.Title][:actuals] && @operating_statement[title_val] and @operating_statement[title_val][:actuals]
        end
        else
          @other_income_and_expenses["more"]={} unless @other_income_and_expenses.member?("more")
          @other_income_and_expenses["more"][:actuals] = @other_income_and_expenses["more"][:actuals].to_f+wres_form_hash_of_data(cash_row)[:actuals].to_f
          @count+=1
          end
        end
      end
    end
    @other_bar['more'] = @other_income_and_expenses['more'][:actuals]  *100 / @operating_statement[title_val][:actuals]  if (@operating_statement and @operating_statement[title_val] and @operating_statement[title_val][:actuals] and @other_income_and_expenses['more'] and @other_income_and_expenses['more'][:actuals])
    if @operating_statement and  @operating_statement[title_val]
      tot_b =  @operating_statement[title_val][:budget]
      tot_a =  @operating_statement[title_val][:actuals]
      @captial_diff={:diff => @operating_statement[title_val][:variant].abs ,:diff_percent => @operating_statement[title_val][:percent],:style => (tot_b >= tot_a ) ?  "greenrow" : "redrow",:tot_actual => tot_a,:diff_word => (tot_b > tot_a ) ? "below" : "above",:tot_budget => tot_b}
      elsif   remote_property(@note.accounting_system_type_id)
        @total_actual = @sum_act
        @total_budget = @sum_bud
        variant = @sum_bud - @sum_act
        variant_percent = ((variant * 100) /@sum_bud).abs rescue ZeroDivisionError
        if @sum_bud == 0
             variant_percent = @sum_act == 0 ? 0 : -100
        end
        @captial_diff={:diff => variant.abs ,:diff_percent => variant_percent,:style => (@sum_bud >= @sum_act ) ?  "greenrow" : "redrow",:tot_actual => @sum_act,:diff_word => (@sum_bud > @sum_act ) ? "below" : "above",:tot_budget => @sum_bud}
        end
    @title=title_val
  end
 end

  def wres_other_income_and_expense_year
    @month_list,@ytd,@operating_statement,@cash_flow_statement,year_to_date,year=[],[],{},{},Date.today.prev_month.month,Date.today.year
    if params[:tl_period] == "7" || params[:period] == "7"
      year_to_date = @end_date.to_date.month
      year = @start_date.to_date.year
    end
    for m in 1..year_to_date
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
      if params[:tl_period] == "7" || params[:period] == "7"
      @month_list <<  Date.new(@start_date.to_date.year,m,1).strftime("%Y-%m-%d")
      else
      @month_list <<  Date.new(Time.now.year,m,1).strftime("%Y-%m-%d")
      end
    end
    qry = get_query_for_other_income_and_expense(year)
    if qry != nil
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      @operating_statement['expenses']={:budget =>0 ,:actuals =>0}
      for cash_row in asset_details
        val ={}
        if cash_row.Parent == "cash flow statement summary"
          @cash_flow_statement[cash_row.Title] = form_hash_of_data(cash_row)
        else
          data = form_hash_of_data(cash_row)
          @operating_statement[cash_row.Title] = data
          @cash_flow_statement[cash_row.Title] = data if cash_row.Title == "depreciation & amortization detail" or cash_row.Title =="net income"
          if cash_row.Title=="recoverable expenses detail" or cash_row.Title=="non-recoverable expenses detail"
            @operating_statement['expenses'][:budget]=  @operating_statement['expenses'][:budget].to_f + cash_row.Budget.to_f
            @operating_statement['expenses'][:actuals]=  @operating_statement['expenses'][:actuals].to_f + cash_row.Actuals.to_f
          end
        end
        @operating_statement['expenses'][:record_id]=  cash_row.Record_id if @financial
      end
      variant = @operating_statement['expenses'][:budget].to_f-@operating_statement['expenses'][:actuals].to_f
      percent = variant*100/@operating_statement['expenses'][:budget].to_f.abs rescue ZeroDivisionError
      if  @operating_statement['expenses'][:budget].to_f==0
        percent = ( @operating_statement['expenses'][:actuals].to_f == 0 ? 0 : -100 )
      end
      @operating_statement['expenses'][:percent] = percent
      @operating_statement['expenses'][:variant] = variant
      @operating_statement['expenses'][:status] = true
    end
  end

  def wres_other_income_and_expense_prev_year
    @operating_statement,@cash_flow_statement={},{}
    year_to_date,year,@ytd,@month_list= Date.today.prev_month.month,Date.today.prev_year.year,[],[]
    for m in 1..12
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
      @month_list <<  Date.new(year,m,1).strftime("%Y-%m-%d")
    end
    qry = get_query_for_other_income_and_expense(year)
    if qry != nil
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      for cash_row in asset_details
        val ={}
        if cash_row.Parent == "cash flow statement summary"
          @cash_flow_statement[cash_row.Title] = wres_form_hash_of_data(cash_row)
        else
          data = wres_form_hash_of_data(cash_row)
          @operating_statement[cash_row.Title] = data
          @cash_flow_statement[cash_row.Title] = data if cash_row.Title == "depreciation & amortization detail" or cash_row.Title =="net income"
        end
      end
    end
    @portfolio_summary,@explanation = false,false
  end

  def get_query_for_other_income_and_expense(year)
    "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(variance) as Variance,sum(child_id) as Record_id from (SELECT k.title as Parent, a.title as Title, f.pcb_type,#{@ytd.join("+")} as actuals, 0 as budget ,0 as variance,a.id as child_id  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN ('other income and expense','other','maintenance projects','operating statement summary') AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals,#{@ytd.join("+")} as budget, 0 as variance,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN ('other income and expense','other','maintenance projects','operating statement summary') AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, 0 as budget,#{@ytd.join("+")} as variance,0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN ('other income and expense','other','maintenance projects','operating statement summary') AND f.pcb_type IN ('var_amt') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"
  end

  def find_other_income_and_expense_percentage(act,bud)
    @per = bud != 0 ?  (act * 100) / bud  : '100'
    @col = bud > act ? 'red' : 'green'
    @per = (@per.to_i > 100) ? '100' : @per
    return @per,@col
  end

  def wres_other_income_and_expense_month(month_val=nil,year=nil)
    @operating_statement,@cash_flow_statement,@financial,@ytd,@explanation={},{},true,[],true
    year_to_date= !month_val.nil? ? month_val : Date.today.prev_month.month
    year = Date.today.year  if year.nil?
    @current_time_period=Date.new(year,year_to_date,1)
    @ytd << "IFNULL(f."+Date::MONTHNAMES[year_to_date].downcase+",0)"
    qry = get_query_for_other_income_and_expense(year)
    if qry != nil
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      @operating_statement['expenses']={:budget =>0.0 ,:actuals =>0.0}
      for cash_row in asset_details
        val ={}
        if cash_row.Parent == "cash flow statement summary"
          @cash_flow_statement[cash_row.Title] = form_hash_of_data(cash_row)
        else
          data = form_hash_of_data(cash_row)
          @operating_statement[cash_row.Title] = data
          @cash_flow_statement[cash_row.Title] = data if cash_row.Title == "depreciation & amortization detail" or cash_row.Title =="net income"
          if cash_row.Title=="recoverable expenses detail" or cash_row.Title=="non-recoverable expenses detail"
            @operating_statement['expenses'][:budget]=  @operating_statement['expenses'][:budget].to_f + cash_row.Budget.to_f
            @operating_statement['expenses'][:actuals]=  @operating_statement['expenses'][:actuals].to_f + cash_row.Actuals.to_f
            @operating_statement['expenses'][:record_id]=  cash_row.Record_id if @financial
          end
        end
      end
      variant = @operating_statement['expenses'][:budget].to_f-@operating_statement['expenses'][:actuals].to_f
      percent = variant*100/@operating_statement['expenses'][:budget].to_f.abs rescue ZeroDivisionError
      if  @operating_statement['expenses'][:budget].to_f==0
        percent = ( @operating_statement['expenses'][:actuals].to_f == 0 ? 0 : -100 )
      end
      @operating_statement['expenses'][:percent] = percent
      @operating_statement['expenses'][:variant] = variant
      @operating_statement['expenses'][:status] = true
    end
    @portfolio_summary = false
  end

  def wres_occupancy_data_calculation
    year = PropertyOccupancySummary.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
    year = year.compact.empty? ? nil : year[0].year
    if year
      os= PropertyOccupancySummary.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,year,get_month(year)],:order => "month desc",:limit =>1)
      @property_occupancy_summary = os[0] if !os.nil? and !os.empty?
    else
      @property_occupancy_summary = nil
    end

    if !@property_occupancy_summary.nil?
      @exposure_vacancy = {}
      @exposure_vacancy['net_exposure_to_vacancy'] ={}
      @exposure_vacancy['net_exposure_to_vacancy'][:sqft] = ((@property_occupancy_summary.total_building_rentable_s.nil? ? 0 : @property_occupancy_summary.total_building_rentable_s) * @property_occupancy_summary.net_exposure_to_vacancy_percentage) / 100
      @exposure_vacancy['net_exposure_to_vacancy'][:percent] = @property_occupancy_summary.net_exposure_to_vacancy_percentage
      @exposure_vacancy['net_exposure_to_vacancy'][:bar] =  (@exposure_vacancy['net_exposure_to_vacancy'][:sqft] and @exposure_vacancy['net_exposure_to_vacancy'][:sqft] > 0) ? 100 : 0
      @exposure_vacancy['net_exposure_to_vacancy'][:unit]  = @property_occupancy_summary.net_exposure_to_vacancy_number
      wres_form_hash_for_occupancy_exposure_vacancy('occupied_preleased',@property_occupancy_summary.occupied_preleased_percentage,@property_occupancy_summary.occupied_preleased_number )
      wres_form_hash_for_occupancy_exposure_vacancy('occupied_on_notice',@property_occupancy_summary.occupied_on_notice_percentage,@property_occupancy_summary.occupied_on_notice_number )
      wres_form_hash_for_occupancy_exposure_vacancy('vacant_leased',@property_occupancy_summary.vacant_leased_percentage,@property_occupancy_summary.vacant_leased_number )
      wres_form_hash_for_occupancy_exposure_vacancy('currently_vacant_leases',@property_occupancy_summary.currently_vacant_leases_percentage,@property_occupancy_summary.currently_vacant_leases_number)
      @partial_file = "/properties/sample_pie"
      @swf_file = "Pie2D.swf"
      @xml_partial_file = "/properties/sample_pie"
      @vaccant      =  @property_occupancy_summary.current_year_units_vacant_actual
      @occupied   =   @property_occupancy_summary.current_year_units_occupied_actual
      @vaccant_percent = (@vaccant  * 100 / @property_occupancy_summary.current_year_units_total_actual.to_f)
      @vaccant_percent = @vaccant_percent.nan? ? 0 : @vaccant_percent.abs.round
      @occupied_percent = (@occupied  * 100 / @property_occupancy_summary.current_year_units_total_actual.to_f)
      @occupied_percent =  @occupied_percent.nan? ? 0 : @occupied_percent.abs.round
      @start_angle = 0
      if !(@vaccant.nil? || @vaccant.blank? || @vaccant == 0 || @occupied.nil? || @occupied.blank? || @occupied == 0)
        if @vaccant <= @occupied
          @start_angle = (180 - (1.8 * ((@vaccant * 100)/(@vaccant+@occupied)  rescue ZeroDivisionError)))
        else
          @start_angle = (1.8 * ((@vaccant * 100)/(@vaccant+@occupied)  rescue ZeroDivisionError))
        end
      end
    end
    @month_lease = @property_occupancy_summary.month if @property_occupancy_summary
  end

  def wres_form_hash_for_occupancy_exposure_vacancy(title,percent_value,unit)
    @exposure_vacancy[title] ={}
    @exposure_vacancy[title][:sqft] = ((@property_occupancy_summary.total_building_rentable_s.nil? ? 0 : @property_occupancy_summary.total_building_rentable_s) * percent_value) / 100
    @exposure_vacancy[title][:percent] = percent_value
    @exposure_vacancy[title][:bar] = @exposure_vacancy[title][:sqft]   *100 / @exposure_vacancy['net_exposure_to_vacancy'][:sqft]
    @exposure_vacancy[title][:unit] = unit
  end

  # Performance review financial sub page for month calculation
  def wres_calculate_the_financial_sub_graph_for_month(month,year)
    @month,@ytd,@explanation = month,[],true
    @ytd << "IFNULL(f."+Date::MONTHNAMES[month.to_i].downcase+",0)"
    params[:financial_sub] = params[:financial_sub].gsub("?","\'") if params[:financial_sub]
    #if params[:financial_sub] and params[:financial_sub] == "Operating Expenses"
      #qry = build_query(@note,@ytd,year)
      #@asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    if !params[:financial_subid].blank?
      e = IncomeAndCashFlowDetail.find_by_id(params[:financial_subid])
      if e && (e.title == "operating expenses" || e.title == "operating revenue")
        @using_sub_id = true
        a= []
        a << params[:financial_subid]
        a << e.parent_id
        qry = wres_get_query_for_financial_sub_page(a.join(","),year)
        @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      else
        @using_sub_id = true
        qry = wres_get_query_for_financial_sub_page(params[:financial_subid],year)
        @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
        if params[:financial_sub] == "operating income"
          wres_total_operating_revenue_sub_page(year)
        end
      end
    else
      qry = wres_get_query_for_financial_sub_page(params[:financial_sub],year)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    end
  end

  def build_query(note,ytd,year)
    "select  Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(child_id) as Record_id from (SELECT  a.title as Title, f.pcb_type, #{ytd.join("+")}  as actuals, 0 as budget,a.id as child_id FROM `income_and_cash_flow_details` a  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{note.id} AND a.resource_type = 'RealEstateProperty' AND a.title IN ('recoverable expenses detail','non-recoverable expenses detail','operating statement summary') AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION   SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{ytd.join("+")}  as budget,0 as child_id FROM `income_and_cash_flow_details` a  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{note.id} AND a.resource_type = 'RealEstateProperty' AND a.title IN ('recoverable expenses detail','non-recoverable expenses detail','operating statement summary') AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'    ) xyz group by  Title"
  end

  def wres_total_operating_revenue_sub_page(year)
    @totals,@b,@totals,@year= [],[],[],year
    @asset_details.each do |a|
      @totals << a
      @b <<  "string to separate #{a.Title}"
      q1 = wres_get_query_for_financial_sub_page(a.Record_id,year)
      q2 = IncomeAndCashFlowDetail.find_by_sql(q1)
      @b << q2 << "added string"
    end
    @asset_details = []
    @b.each do |m|
      m.each do |n|
        @asset_details << n
      end
    end
    @v = @asset_details.split("added string")
    i =0
    @v.each do |t|
      t << @totals[i]
      i = i +1
    end
    @revenue_percentage,@revenue_var,@revenue_act,@revenue_bud = 0,0,0,0
    @totals.each do |t|
      @revenue_act = @revenue_act + t.Actuals.to_f
      @revenue_bud = @revenue_bud + t.Budget.to_f
    end
    @revenue_percentage  = @revenue_bud != 0 ?  ( (@revenue_bud - @revenue_act)/@revenue_bud) * 100  : 0
    @revenue_var = @revenue_bud - @revenue_act
  end

  def wres_get_query_for_financial_sub_page(parent,year)
    if  @using_sub_id
      "select  Title, sum(actuals) as Actuals, sum(budget) as Budget, sum(child_id) as Record_id from (SELECT  a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget, a.id as child_id FROM `income_and_cash_flow_details` a   inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND a.parent_id IN (#{parent}) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' AND a.title NOT IN ('operating expenses','net operating income','net income before depreciation','operating income','Other Income And Expense')  UNION SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as child_id FROM `income_and_cash_flow_details` a    inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND a.parent_id IN (#{parent}) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' AND a.title NOT IN ('operating expenses','net operating income','net income before depreciation','operating income','Other Income And Expense') ) xyz group by Title"
    else
      "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget, sum(child_id) as Record_id from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget, a.id as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN (\"#{parent}\") AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as child_id FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = 'RealEstateProperty' AND k.title IN (\"#{parent}\") AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"
    end
  end

  # Performance review financial sub page for year-to-date calculation
  def wres_calculate_the_financial_sub_graph(year=nil)
    year_to_date,@explanation= Date.today.prev_month.month,true
    @ytd= []
    for m in 1..year_to_date
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
    end
    params[:financial_sub] = params[:financial_sub].gsub("?","\'") if params[:financial_sub]
 #   if params[:financial_sub] and params[:financial_sub] == "Operating Expenses"
    #  qry = build_query(@note,@ytd,year)
      #@asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    #els
    if !params[:financial_subid].blank?
      @using_sub_id = true
      qry = get_query_for_financial_sub_page(params[:financial_subid],year,false)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      if params[:financial_sub] == "operating income"
        wres_total_operating_revenue_sub_page(year)
      end
    else
      qry = get_query_for_financial_sub_page(params[:financial_sub],year,false)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    end
  end
  # Performance review financial sub page for month_ytd calculation
  def wres_calculate_the_financial_sub_graph_for_month_ytd(year=nil,month=nil)
    year_to_date,@explanation= month,true
    @ytd= []
    for m in 1..year_to_date
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
    end
    params[:financial_sub] = params[:financial_sub].gsub("?","\'") if params[:financial_sub]
    if params[:financial_sub] and params[:financial_sub] == "Operating Expenses"
      qry = build_query(@note,@ytd,year)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    elsif params[:financial_subid]
      @using_sub_id = true
      qry = get_query_for_financial_sub_page(params[:financial_subid],year,false)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      if params[:financial_sub] == "operating income"
        wres_total_operating_revenue_sub_page(year)
      end
    else
      qry = get_query_for_financial_sub_page(params[:financial_sub],year,false)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    end
  end

  # Performance review financial sub page for last year calculation
  def wres_calculate_the_financial_sub_graph_for_prev_year(year=nil)
    @ytd= []
    for m in 1..12
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
    end
    params[:financial_sub] = params[:financial_sub].gsub("?","\'") if params[:financial_sub]
   #if params[:financial_sub] and params[:financial_sub] == "Operating Expenses"
      #qry = build_query(@note,@ytd,year)
      #@asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    #els
    if !params[:financial_subid].blank?
      @using_sub_id = true
      qry = get_query_for_financial_sub_page(params[:financial_subid],year,false)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
      if params[:financial_sub] == "operating income"
        wres_total_operating_revenue_sub_page(year)
      end
    else
      qry = get_query_for_financial_sub_page(params[:financial_sub],year,false)
      @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    end
    @explanation = true
  end


  def wres_rent_analysis_cal_for_year
    year_to_date=(params[:period] == '7' || params[:tl_period] == "7") ? @end_date.to_date.month : Date.today.prev_month.month
    year = (params[:period] == '7' || params[:tl_period] == "7") ? @start_date.to_date.year : Date.today.year
    year = find_selected_year(year)
    wres_rent_analysis_cal(year_to_date,year)
  end

  def wres_rent_analysis_cal(month_for_year,year_value)
    year_value = find_selected_year(year_value)
    @suites = PropertySuite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
    year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year <= ?',@suites,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
    if year
     year = year.compact.empty? ? nil : year[0].year
    month = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year = ? and month <= ?',@suites,year,get_month(year)],:select=>"month",:order => "month desc",:limit =>1).map(&:month) if !@suites.blank?
    end
    sql = ActiveRecord::Base.connection();
    tenant_string =  "pl.tenant like '%vacant%'"
    ##find the count of vacant suites
    if month.present? && year.present?
      @suite_plan = sql.execute("SELECT  count(*) FROM `property_suites` ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id = #{@note.id}	and #{tenant_string} and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan" )
      record = Document.record_to_hash(@suite_plan)
      @suite_plan  = record.map{|x| x["count(*)"].to_i}
    end
    @total_suite =  @suite_plan.sum if !@suite_plan.blank?
    ##find the floor_plan of vacant suites
      @plan_floor =PropertySuite.find_by_sql("select ps.floor_plan from property_suites ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id = #{@note.id} and #{tenant_string} and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan" )if month.present? && year.present?
      @occ_plan_floor = PropertySuite.find_by_sql("select ps.floor_plan from property_suites ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id = #{@note.id} and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan" ) if month.present? && year.present?
      @occ_floor = []
      @floor= []
    unless @plan_floor.nil?
      @plan_floor && @plan_floor.each do |f|
      @floor<< f.floor_plan
    end
    end
  unless @occ_plan_floor.nil?
   @occ_plan_floor && @occ_plan_floor.each do |f|
   @occ_floor<<f.floor_plan
 end
    end
    ##find the total count of floor plan that are vacant
  if month.present? && year.present?
    if !@floor.empty? || !@floor.blank?
    @floor_plan = sql.execute("SELECT count(*) FROM `property_suites` ps left join property_leases pl on pl.property_suite_id = ps.id where ps.real_estate_property_id = #{@note.id} and ps.floor_plan in (#{@floor.collect { |i| "'" + i.to_s + "'" }.join(",")}) and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan")
    record = Document.record_to_hash(@floor_plan)
    @floor_plan = record.map{|x| x["count(*)"].to_i}
    end
  end
    @total_floor = @floor_plan.sum if !@floor_plan.blank?
    if month.present? && year.present?
        if !@occ_floor.empty? || !@occ_floor.blank?
          @occ_floor_plan = sql.execute("SELECT count(*) FROM `property_suites` ps left join property_leases pl on pl.property_suite_id = ps.id where ps.real_estate_property_id = #{@note.id} and ps.floor_plan in (#{@occ_floor.collect { |i| "'" + i.to_s + "'" }.join(",")}) and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan")
        record = Document.record_to_hash(@occ_floor_plan)
        @occ_floor_plan = record.map{|x| x["count(*)"].to_i}
        end
    end
    @occ_total_floor = @occ_floor_plan.sum if !@occ_floor_plan.blank?
      ##find the lease rent and market rent
      @rent_rate =PropertySuite.find_by_sql("SELECT ps.floor_plan as floor_plan,sum(pl.base_rent) as base_rent, sum(pl.effective_rate) as effective_rate from property_suites ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id = #{@note.id} and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan")    if month.present? && year.present?
    @market_rent = []
    @lease_rent=[]
    unless @rent_rate.nil?
      @rent_rate && @rent_rate.each do |x|
        if @floor.include?(x.floor_plan)
        @market_rent << x.base_rent
        @lease_rent << x.effective_rate
        end
      end
    end
    sum = 0
    @market_rent.each do |r|
      sum = sum + r.to_i
    end
  @market_sum = sum
    rent = 0
    @lease_rent.each do |r|
      rent = rent + r.to_i
    end
  @lease_sum = rent
  end

  def other_income_exp_yrforecast_condition
    if @note && remote_property(@note.accounting_system_type_id)
      cap_exp_title = "'A/D-TENANT/LEASEHOLD IMPROVEMENTS ','REAL ESTATE UNDER DEVELOPMENT','TENANT IMPROVEMENTS','LEASEHOLD IMPROVEMENTS','LAND IMPROVEMENTS','TOTAL REAL ESTATE UNDER DEVELOPMENT','A/D-LAND IMPROVEMENTS'"
    else
      cap_exp_title = "'maintenance projects','Capital Expenditures'"
    end
      year =  find_selected_year(Date.today.year)
      val_qry="select pf1.january as january,pf1.february as february,pf1.march as march,pf1.april as april, pf1.may as may,pf1.june as june,pf1.july as july,pf1.august as august,pf1.september as september,pf1.october as october,pf1.november as november,pf1.december as december from  income_and_cash_flow_details  ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.pcb_type = 'c' and pf1.source_type = 'IncomeAndCashFlowDetail' where ic.title in (#{cap_exp_title}) and ic.resource_id  = #{@note.id} and ic.year= #{year}"
      k=0
      value= PropertyCapitalImprovement.find_by_sql(val_qry)
      @result = value[k].attributes.keys.select {|i| i if value[k].send(:"#{i}") == "0" } if !(value.blank? || value.empty?)
  end

  def wres_other_income_and_expense_details_for_year_forecast
    other_income_exp_yrforecast_condition
    common_method_for_yrforecast
    year =  find_selected_year(Date.today.year)
    year_todate= @financial_month
    @ytd= []
    for m in 1..year_todate
      @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
    end
    wres_other_details_display_calculation(year)
  end

  def wres_other_income_and_expense_for_year_forecast(year)
    if !@ytd_actuals.nil?
    if @note && remote_property(@note.accounting_system_type_id)
      cap_exp_title = "'A/D-TENANT/LEASEHOLD IMPROVEMENTS ','REAL ESTATE UNDER DEVELOPMENT','TENANT IMPROVEMENTS','LEASEHOLD IMPROVEMENTS','LAND IMPROVEMENTS','TOTAL REAL ESTATE UNDER DEVELOPMENT','A/D-LAND IMPROVEMENTS'"
    else
      cap_exp_title = "'maintenance projects','Capital Expenditures'"
    end
     "select ic2.title as Parent, ic.title as Title,(#{@ytd_actuals} + #{@ytd_budget}) as Actuals,pf2.january+pf2.february+pf2.march+pf2.april+pf2.may+pf2.june+ pf2.july+pf2.august+pf2.september+pf2.october+pf2.november+pf2.december as Budget,(#{@ytd.join("+")}) as Variance,ic.id as Record_id from `income_and_cash_flow_details` ic  LEFT JOIN  property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type='IncomeAndCashFlowDetail' AND pf1.pcb_type ='c' LEFT JOIN  property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type='IncomeAndCashFlowDetail' AND pf2.pcb_type ='b' LEFT JOIN  property_financial_periods f on f.source_id = ic.id AND f.source_type='IncomeAndCashFlowDetail' AND f.pcb_type ='var_amt' left join income_and_cash_flow_details ic2 on ic2.id=ic.parent_id WHERE ic.id IN (SELECT ic2.id FROM income_and_cash_flow_details ic2 WHERE ic2.title IN (#{cap_exp_title})  AND ic2.resource_id = #{@note.id} AND ic2.year= #{year} AND ic2.resource_type = (#{@resource}) UNION SELECT ic3.id FROM income_and_cash_flow_details ic3 WHERE ic3.parent_id IN (SELECT ic1.id FROM income_and_cash_flow_details ic1 WHERE ic1.title IN (#{cap_exp_title}) AND ic1.resource_id = #{@note.id} AND ic1.year= #{year} AND ic1.resource_type = (#{@resource})))"
     end
   end
   
   def portfolio_multifamily_occupancy(prop_ids)
    year_value = find_selected_year(Date.today.year)
    @suites = PropertySuite.find(:all, :conditions=>['real_estate_property_id IN (?)', prop_ids]).map(&:id) if prop_ids.present?
    year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year <= ?',@suites,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if !@suites.blank?
    if year
     year = year.compact.empty? ? nil : year[0].year
    month = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year = ? and month <= ?',@suites,year,get_month(year)],:select=>"month",:order => "month desc",:limit =>1).map(&:month) if !@suites.blank?
    end
    sql = ActiveRecord::Base.connection();
    tenant_string =  "pl.tenant like '%vacant%'"
    ##find the count of vacant suites
    if month.present? && year.present?
      @suite_plan = sql.execute("SELECT  count(*) FROM `property_suites` ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id IN (#{prop_ids.join(',')})	and #{tenant_string} and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan" )
      record = Document.record_to_hash(@suite_plan)
      @suite_plan  = record.map{|x| x["count(*)"].to_i}
    end
    @total_suite =  @suite_plan.sum if !@suite_plan.blank?
    ##find the floor_plan of vacant suites
      @plan_floor =PropertySuite.find_by_sql("select ps.floor_plan from property_suites ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id IN (#{prop_ids.join(',')}) and #{tenant_string} and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan" )if month.present? && year.present?
      @occ_plan_floor = PropertySuite.find_by_sql("select ps.floor_plan from property_suites ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id IN (#{prop_ids.join(',')}) and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan" ) if month.present? && year.present?
      @occ_floor = []
      @floor= []
    unless @plan_floor.nil?
      @plan_floor && @plan_floor.each do |f|
      @floor<< f.floor_plan
    end
    end
  unless @occ_plan_floor.nil?
   @occ_plan_floor && @occ_plan_floor.each do |f|
   @occ_floor<<f.floor_plan
 end
    end
    ##find the total count of floor plan that are vacant
  if month.present? && year.present?
    if !@floor.empty? || !@floor.blank?
    @floor_plan = sql.execute("SELECT count(*) FROM `property_suites` ps left join property_leases pl on pl.property_suite_id = ps.id where ps.real_estate_property_id IN (#{prop_ids.join(',')})and ps.floor_plan in (#{@floor.collect { |i| "'" + i.to_s + "'" }.join(",")}) and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan")
    record = Document.record_to_hash(@floor_plan)
    @floor_plan = record.map{|x| x["count(*)"].to_i}
    end
  end
    @total_floor = @floor_plan.sum if !@floor_plan.blank?
    if month.present? && year.present?
        if !@occ_floor.empty? || !@occ_floor.blank?
          @occ_floor_plan = sql.execute("SELECT count(*) FROM `property_suites` ps left join property_leases pl on pl.property_suite_id = ps.id where ps.real_estate_property_id IN (#{prop_ids.join(',')}) and ps.floor_plan in (#{@occ_floor.collect { |i| "'" + i.to_s + "'" }.join(",")}) and pl.month = #{month} and pl.year = #{year.to_i} group by ps.floor_plan")
        record = Document.record_to_hash(@occ_floor_plan)
        @occ_floor_plan = record.map{|x| x["count(*)"].to_i}
        end
    end
    @occ_total_floor = @occ_floor_plan.sum if !@occ_floor_plan.blank?
   end   
end
