module PerformanceReviewCalculationsHelper

  def initial_variance_calculations(record,variance_task_doc)
    calc_for_financial_data_display
    if params[:start_date] && (params[:period] != "3"  && params[:tl_period] != "3")
      exp_month_ytd = params[:start_date].split("-")[1].to_i
      exp_ytd_check = false
      date_for_var_doc = params[:start_date].split("-")
      variances_display_for_exp(date_for_var_doc[1].to_i,date_for_var_doc[0].to_i)
    elsif !params[:tl_month].nil? and !params[:tl_month].blank? && (params[:period] != "3"  && params[:tl_period] != "3")
      exp_month_ytd = params[:tl_month].to_i
      exp_ytd_check = false
      variances_display_for_exp(params[:tl_month].to_i, params[:tl_year].to_i)
    else
      if (params[:period] && params[:period] == "4") ||  (params[:tl_period] && params[:tl_period] == "4")
        exp_month_ytd = @financial_month
        exp_ytd_check = true
        variances_display_for_exp(@financial_month,@financial_year)
      elsif (params[:period] && params[:period] == "5") ||  (params[:tl_period] && params[:tl_period] == "5")
        exp_month_ytd = @financial_month
        exp_ytd_check = false
        variances_display_for_exp(@financial_month,@financial_year)
      elsif (params[:period] && params[:period] == "6") ||  (params[:tl_period] && params[:tl_period] == "6") ||  (params[:tl_period] == "3" || params[:period] == "3")
        exp_month_ytd = 12
        exp_ytd_check = true
        year = find_selected_year(Date.today.prev_year.year)
        variances_display_for_exp(12,year)
      elsif (params[:period] && params[:period] == "7") ||  (params[:tl_period] && params[:tl_period] == "7")
        @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
        @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
        exp_month_ytd = @end_date.to_date.month
        exp_ytd_check = true
        variances_display_for_exp(@end_date.to_date.month,@start_date.to_date.year)
      elsif (params[:period] && params[:period] == "8") ||  (params[:tl_period] && params[:tl_period] == "8")
        exp_month_ytd = 12
        exp_ytd_check = true
        year = Date.today.year
        variances_display_for_exp(12,year)
      elsif (params[:period] && params[:period] == "11") ||  (params[:tl_period] && params[:tl_period] == "11")
        exp_month_ytd = "t12"
        exp_ytd_check = true
      end
    end
     if variance_task_doc == "financials"
      variance_task_document_id = @variance_task_document_month_budget.nil? ? 0 : @variance_task_document_month_budget.id
      elsif variance_task_doc == "cap_exp"
      variance_task_document_id = @variance_task_document_capital_improvement.nil? ? 0 : @variance_task_document_capital_improvement.id
      end
    return exp_month_ytd,exp_ytd_check,variance_task_document_id
  end

  def find_color_direction_and_icon(actual,budget)
    icon_direction = up_or_down(actual,budget)
    use_color = expense_color(actual, budget)
    color_flag = (use_color == 'green') ? '' : 'red'
    color_icon = (use_color == 'green') ? "greenarrow#{icon_direction}" : "#{icon_direction}arrowred"
    return icon_direction,use_color,color_flag,color_icon
  end

  def find_variance_threshold(variance_type,id,exp_month_ytd,exp_ytd_check)
    variance_thres = VarianceThreshold.find_thresholds_value(@note.id)
    explanation_doc_id = cap_exp_explanation_doc(id,exp_month_ytd,exp_ytd_check)
    @doc = find_document_id(explanation_doc_id)
    and_or = variance_thres.and_or
    if exp_ytd_check == false
      val = (variance_type < -(variance_thres.cap_exp_variance.to_i) or variance_type > variance_thres.cap_exp_variance.to_i)
    else
      val = (variance_type < -(variance_thres.cap_exp_variance_ytd.to_i) or variance_type > variance_thres.cap_exp_variance_ytd.to_i)
    end
    return variance_thres,exp_ytd_check,explanation_doc_id,and_or,val
  end

  def find_folder_and_month_details
    folder_det = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    month_details = ['january','february','march','april','may','june','july','august','september','october','november','december']
    return folder_det,month_details
  end

  def calculate_capital_exp_variance_and_percentage
    capex_variance = {}
    capex_variance[:b_variant] = cap_exp.annual_budget.to_f - cap_exp.actual.to_f
    capex_variance[:b_status] = capex_variance[:b_variant] < 0 ? false : true
    capex_variance[:b_percent_bar] = (cap_exp.actual.to_f * 100/ cap_exp.annual_budget.to_f.abs)/2 rescue ZeroDivisionError
    capex_variance[:b_percent] = capex_variance[:b_variant] * 100/ cap_exp.annual_budget.to_f.abs rescue ZeroDivisionError
    if cap_exp.annual_budget.to_f==0
      capex_variance[:b_percent] = ( cap_exp.actual.to_f == 0 ? 0 : -100 )
    end
    capex_variance[:b_percent] = 0.0 if capex_variance[:b_percent].to_f.nan?
    return capex_variance
  end

  def find_color_direction_and_icon_income(actuals,budget)
    icon_direction = up_or_down(actuals,budget)
    use_color = income_color(actuals,budget)
    color_flag = (use_color == 'green') ? '' : 'red'
    color_icon = (use_color == 'green') ? "greenarrow#{icon_direction}" : "#{icon_direction}arrowred"
    return icon_direction,use_color,color_flag,color_icon
  end

  def dashboard_icon_color(actuals,budget)
    icon_direction = up_or_down(actuals,budget)
    use_color = income_color(actuals,budget)
    color_flag = (use_color == 'green') ? '' : 'red'
    color_icon = (use_color == 'green') ? "multgreenarrow" : "#{icon_direction}arrow_red2"
    return icon_direction,use_color,color_flag,color_icon
  end


  def find_aging_details(aging)
    aging_30_days = aging.over_30days.nil? ? 0 : aging.over_30days
    aging_60_days = aging.over_60days.nil? ? 0 : aging.over_60days
    aging_90_days = aging.over_90days.nil? ? 0 : aging.over_90days
    aging_120_days = aging.over_120days.nil? ? 0 : aging.over_120days
    prepaid = aging.prepaid.nil? ? 0 : aging.prepaid
    pending_amount = aging.paid_amount.nil? ? 0 : aging.paid_amount
    return aging_30_days,aging_60_days,aging_90_days,aging_120_days,prepaid,pending_amount
  end

  def find_controller_and_action_in_cash
    if params[:action] == "change_date" && (params[:period] == "5" || params[:tl_period] == "5")
      controller_name =  "performance_review_property"
      action_name = "change_date"
    elsif (params[:action] == "select_time_period" && (params[:period] == "4" || params[:tl_period] == "4" )) || (params[:tl_period] == "4" && params[:action] == "cash_n_receivables" ) || (params[:tl_period] == "5" && params[:action] == "cash_n_receivables" ) || (params[:action] == "select_time_period" && (params[:period] == "5" || params[:tl_period] == "5" ))
      controller_name =  "properties"
      action_name = "select_time_period"
    elsif params[:start_date] != "nil" && !params[:start_date] != ""
      controller_name =  "performance_review_property"
      action_name = "change_date"
    else
      controller_name = (params[:period] == "4" || params[:tl_period] == "4" || params[:period] == "5" || params[:tl_period] == "5") ? "properties" : "performance_review_property"
      action_name = (params[:period] == "4" || params[:tl_period] == "4" || params[:period] == "5" || params[:tl_period] == "5" ) ? "select_time_period" : "change_date"
    end
    return controller_name,action_name
  end


  def calculate_capital_exp_sub_variance_and_percentage(cap_exp)
    capex_variance = {}
    capex_variance[:b_variant] = cap_exp.annual_budget.to_f - cap_exp.actual.to_f
    capex_variance[:b_status] = capex_variance[:b_variant] < 0 ? false : true
    capex_variance[:b_percent_bar] = (cap_exp.actual.to_f * 100/ cap_exp.annual_budget.to_f.abs) rescue ZeroDivisionError
    capex_variance[:b_percent_bar] = capex_variance[:b_percent_bar] > 100 ? 100 : capex_variance[:b_percent_bar]
    capex_variance[:b_percent] = capex_variance[:b_variant] * 100/ cap_exp.annual_budget.to_f.abs rescue ZeroDivisionError
    if cap_exp.annual_budget.to_f==0
      capex_variance[:b_percent] = ( cap_exp.actual.to_f == 0 ? 0 : -100 )
    end
    capex_variance[:b_percent] = 0.0 if capex_variance[:b_percent].to_f.nan?
    return capex_variance
  end

  def find_variance_threshold_financial_performance(exp_month_ytd,exp_ytd_check,record_id,percent,variant)
    variance_thres = VarianceThreshold.find_thresholds_value(@note.id)
    explanation_doc_id = financial_explanation_doc(record_id,exp_month_ytd,exp_ytd_check)
    @doc = find_document_id(explanation_doc_id)
    and_or = variance_thres.and_or

    if exp_ytd_check == false
      val = "(display_currency_real_estate_overview_for_percent_variance(#{percent}).to_f < -(variance_thres.variance_percentage.to_f) or display_currency_real_estate_overview_for_percent_variance(#{percent}).to_f >  variance_thres.variance_percentage.to_f) #{variance_thres.and_or}(#{variant} < -(variance_thres.variance_amount.to_f) or #{variant} > variance_thres.variance_amount.to_f)"
    else
      val = "(display_currency_real_estate_overview_for_percent_variance(#{percent}).to_f < -(variance_thres.variance_percentage_ytd.to_f) or display_currency_real_estate_overview_for_percent_variance(#{percent}).to_f >  variance_thres.variance_percentage_ytd.to_f) #{variance_thres.and_or} (#{variant} < -(variance_thres.variance_amount_ytd.to_f) or #{variant} > variance_thres.variance_amount_ytd.to_f)"
    end
    return variance_thres,exp_ytd_check,explanation_doc_id,and_or,val
  end

  def set_local_variables_value(params , month , options)
    calc_for_financial_data_display
    exp_month_ytd , exp_ytd_check = nil , nil
    if(params[:period] == "2" || params[:tl_period] == "2") && (params[:quarter_end_month] && !params[:quarter_end_month].blank?)
      exp_month_ytd = month.to_i
      exp_ytd_check = true
      variances_display(month.to_i,params[:tl_year].to_i)
    elsif params[:start_date] && (params[:period] != "3"  && params[:tl_period] != "3")
      date_for_var_doc = params[:start_date].split("-")
      exp_month_ytd = date_for_var_doc[1].to_i
      exp_ytd_check = false
      date_for_var_doc = params[:start_date].split("-") if options[:option].eql?("income_expence")
      variances_display(date_for_var_doc[1].to_i,date_for_var_doc[0].to_i) if options[:option].eql?("income_expence")
    elsif !params[:tl_month].nil? and !params[:tl_month].blank? && (params[:period] != "3"  && params[:tl_period] != "3")
      exp_month_ytd = params[:tl_month].to_i
      exp_ytd_check = false
      variances_display(params[:tl_month].to_i, params[:tl_year].to_i) if options[:option].eql?("income_expence")
    else
      if (params[:period] && params[:period] == "4") ||  (params[:tl_period] && params[:tl_period] == "4")
        exp_month_ytd = @financial_month
        exp_ytd_check = true
        variances_display(@financial_month,@financial_year) if options[:option].eql?("income_expence")
      elsif (params[:period] && params[:period] == "5") ||  (params[:tl_period] && params[:tl_period] == "5")
        exp_month_ytd = @financial_month
        exp_ytd_check = false
        variances_display(@financial_month,@financial_year) if options[:option].eql?("income_expence")
      elsif (params[:period] && params[:period] == "6") ||  (params[:tl_period] && params[:tl_period] == "6")  ||  (params[:tl_period] == "3" || params[:period] == "3")
        exp_month_ytd = 12
        exp_ytd_check = true
        year = find_selected_year(Date.today.prev_year.year)
        variances_display(12,year) if options[:option].eql?("income_expence")
      elsif (params[:period] && params[:period] == "8") ||  (params[:tl_period] && params[:tl_period] == "8")
        exp_month_ytd = 12
        exp_ytd_check = true
        year = Date.today.year
        variances_display(12,year) if options[:option].eql?("income_expence")
      elsif (params[:period] && params[:period] == "7") || (params[:tl_period] && params[:tl_period] == "7")
        @start_date = Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d").to_date.beginning_of_year.strftime("%Y-%m-%d")
        @end_date =  Time.local("#{params[:cur_year]}","#{params[:cur_month]}").strftime("%Y-%m-%d")
        exp_month_ytd = @end_date.to_date.month
        exp_ytd_check = true
        variances_display(@end_date.to_date.month,@start_date.to_date.year)
        elsif (params[:period] && params[:period] == "11") ||  (params[:tl_period] && params[:tl_period] == "11")
        exp_month_ytd = "t12"
        exp_ytd_check = true
      end
    end
    return exp_month_ytd , exp_ytd_check
  end
  def color_code_creation(actual,budget,use_color)
    icon_direction = up_or_down(actual,budget)
    vari = form_hash_of_data_for_occupancy(actual,budget)
    color_flag = (use_color == 'green') ? '' : 'red'
    color_icon = (use_color == 'green') ? "greenarrow#{icon_direction}" : "#{icon_direction}arrowred"
    return icon_direction,vari,color_flag,color_icon
  end

  def calculate_vaccant_and_occupancy(portfolio,hash_portfolio_occupancy)
    property_types =  RealEstateProperty.count(:all, :conditions=>['portfolios.id=?',portfolio.id],:joins=>:portfolios )
    total_sqft = 0
    for i in hash_portfolio_occupancy
      total_sqft = i.occupied.to_i + i.vaccant.to_i
      @vaccant = i.vaccant.to_f
      @occupied = i.occupied.to_f
      if portfolio.leasing_type == "Multifamily"
        total_sqft = i.occupied_units.to_i + i.vaccant_units.to_i
        @vaccant = i.vaccant_units.to_f
        @occupied = i.occupied_units.to_f
        @occupied_percent = ((@occupied * 100) / (@occupied + @vaccant)).round rescue ZeroDivisionError
        if !(@occupied.nil? || @occupied.blank? || @occupied == 0)
          @vaccant_percent = 100 - @occupied_percent
        end
      end
    end
    @occupied_percent = ((@occupied * 100) / (@occupied + @vaccant)).round rescue ZeroDivisionError
    if !(@occupied.nil? || @occupied.blank? || @occupied == 0)
      @vaccant_percent = 100 - @occupied_percent
    else
      @vaccant_percent = 0
    end
    return total_sqft
  end

  def initialize_variance_threshold_values(note,operating_statement,exp_month_ytd,exp_ytd_check)
    variance_thres = VarianceThreshold.find_thresholds_value(note.id)
    explanation_doc_id = financial_explanation_doc(operating_statement,exp_month_ytd,exp_ytd_check)
    doc = find_document_id(explanation_doc_id)
    and_or = variance_thres.and_or
    return variance_thres,explanation_doc_id,doc,and_or
  end

  def find_quarterly_msg
    find_month_list_for_quarterly
    q_months = @month_quarter.reverse
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    @quarter_message = "Calculating actuals from #{months[q_months[0] - 1]} - #{months[q_months[2] - 1]} #{params[:tl_year]}"
    return @quarter_message
  end

  def  find_quarterly_each_msg(end_month,quarter_year)
    if params[:period] == '2' || params[:tl_period] == '2'
    if !@quarter_default_message
      q_months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec","Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
      @month_quarter = []
      @month_quarter[0] = end_month
      @month_quarter[1] = end_month - 1
      @month_quarter[2] = end_month - 2
      find_redmonth_start_for_summary(quarter_year)     if (params[:partial_page] == "portfolio_partial" ||  params[:partial_page] == "financial" || params[:partial_page] == "financials" || params[:partial_page] == "financial_subpage" || params[:partial_page] == "cash_and_receivables" || params[:action] == "cash_n_receivables_sub_view" || params[:partial_page] == " balance_sheet_sub_page")
      if  params[:partial_page] =="leases"
        find_redmonth_start_for_leases(quarter_year)
      end
      find_redmonth_start_for_recv(quarter_year) if params[:partial_page] =="cash_and_receivables_for_receivables"
      find_redmonth_start_for_rent_roll(quarter_year) if params[:partial_page] =="rent_roll_highlight" || params[:partial_page] =="rent_roll"
      find_redmonth_start_for_capexp(quarter_year) if  params[:partial_page] =="capital_expenditure" || params[:cap_call_id] || @cap_expenditure == "true"
      if Date.today.month == 1 && @month_red_start == nil
          @quarter_starting_month  = q_months[end_month - 3]
          @quarter_ending_month = q_months[end_month - 1]
          @quarter_default_message =  "Calculating Actuals from #{@quarter_starting_month} - #{@quarter_ending_month}"
      elsif(@month_red_start == 0 || @month_red_start.nil?)
        if(@month_quarter[0] > Date.today.month && @month_quarter[1] > Date.today.month && @month_quarter[2] > Date.today.month) || (@month_red_start == 0)
          @quarter_default_message = ""
        elsif @month_quarter[0] > Date.today.month - 1 || @month_quarter[1] > Date.today.month - 1  || @month_quarter[2] > Date.today.month - 1
          @quarter_default_message = "Calculating Actuals for  #{q_months[Date.today.month - 2]}"
        else
          @quarter_starting_month  = q_months[end_month - 3]
          @quarter_ending_month = q_months[end_month - 1]
          @quarter_default_message =  "Calculating Actuals from #{@quarter_starting_month} - #{@quarter_ending_month}"
        end
      elsif @month_red_start && (!@month_quarter.index(@month_red_start - 12).nil? ||  (@month_red_start - 12 > @month_quarter[0] && @month_red_start - 12 > @month_quarter[1] && @month_red_start - 12 > @month_quarter[2] ) )
        @quarter_starting_month  = q_months[end_month - 3] if @month_red_start
        @quarter_ending_month = q_months[@month_red_start - 1]  if !@month_quarter.index(@month_red_start - 12).nil?
        @quarter_ending_month = q_months[end_month - 1]  if (@month_quarter.index(@month_red_start - 12).nil? &&  (@month_red_start - 12 > @month_quarter[0] && @month_red_start - 12 > @month_quarter[1] && @month_red_start - 12 > @month_quarter[2] ) )
        if @quarter_starting_month == @quarter_ending_month
          @quarter_default_message = "Calculating Actuals for #{@quarter_starting_month}"
        else
          @quarter_default_message = "Calculating Actuals from #{@quarter_starting_month} - #{@quarter_ending_month} "
        end
      elsif(@month_red_start && ((@month_red_start - 12) > end_month))
        @quarter_starting_month  = q_months[end_month - 3]
        @quarter_ending_month = q_months[end_month - 1]
      else
        @quarter_default_message = ""
      end
      end
  		return @quarter_default_message
      end
  end


def find_cash_account_code
     cash =  AccountTree.find_by_title('CASH FLOW')
     @cash_sub_items_account_code =  AccountTree.find(:all,:conditions=>["parent_id = #{cash.id}"]).map(&:account_num) if cash
end

def find_income_and_cash_flow_item(account_code)
    cash_item = IncomeAndCashFlowDetail.find_by_account_code(account_code)
end


def find_financial_title
 find_dashboard_portfolio_display
  if @balance_sheet
      financial_title = "'balance sheet'"
  elsif @note && remote_property(@note.accounting_system_type_id)
     financial_title = "'NET INCOME BEFORE DEPR & AMORT','#{@expense_title}','net operating income','NET INCOME','Griffin'"
  else
        financial_title = @note && (find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note))? "'Operating Summary','Non Operating Revenues','Non Operating Expense','Non Operating Summary','INCOME STATEMENT','CASH FLOW STATEMENT','#{@expense_title}'" : "'cash flow statement summary','operating statement summary','net operating income','cash flow from operating activities','other income and expense','current rent','#{@expense_title}'"
      end
return financial_title
end

#for cash items
def find_non_financial_title(from_properties_tab = nil)
  if from_properties_tab.blank?
    find_dashboard_portfolio_display
  else
    @resource = "'RealEstateProperty'"
  end
  if @note && remote_property(@note.accounting_system_type_id)
    financial_title = "'NET INCOME BEFORE DEPR & AMORT','#{@expense_title}','net operating income','NET INCOME','Griffin'"
  else
    financial_title = @note && (find_accounting_system_type(0,@note) || find_accounting_system_type(4,@note)) ? "'Operating Summary','Non Operating Revenues','Non Operating Expense','Non Operating Summary','INCOME STATEMENT','CASH FLOW STATEMENT','#{@expense_title}'" : "'operating statement summary','current rent','other income and expense','net operating income','current rent','cash flow statement summary','Non-Op Expense','#{@expense_title}'"
  end
  return financial_title
end

#titles for financial items
def find_financial_title_summary
 find_dashboard_portfolio_display
  if @note && remote_property(@note.accounting_system_type_id)
    financial_title = "'NET INCOME BEFORE DEPR & AMORT','net operating income','NET INCOME','Griffin'"
  else
    financial_title = "'Operating Summary','Non Operating Revenues','Non Operating Expense','Non Operating Summary','INCOME STATEMENT','cash flow statement summary','operating statement summary','net operating income','cash flow from operating activities','other income and expense'"
  end
return financial_title
end

#find total of line item in balance sheet and cash
def find_total_of_line_item(title,record_id)
find_dashboard_portfolio_display
  op_statement = {}
  if @balance_sheet
    find_last_updated_items
    year = @last_record_year
  else
    year = find_selected_year(Date.today.year)
  end
 asset_detail = IncomeAndCashFlowDetail.find_by_sql("select  Title, sum(actuals) as Actuals, sum(budget) as Budget, child_id as Record_id from (SELECT  a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget, a.id as child_id FROM `income_and_cash_flow_details` a   inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.id = #{record_id} AND (f.pcb_type = 'c' or f.pcb_type = 'p') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT  a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget, 0 as child_id FROM `income_and_cash_flow_details` a    inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.id = #{record_id} AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Title")[0]
  op_statement[asset_detail.Title] = {:actuals=>0,:budget=>0,:record_id=>0}
  op_statement[asset_detail.Title][:actuals] = asset_detail.Actuals.to_f
  op_statement[asset_detail.Title][:budget] = asset_detail.Budget.to_f
  op_statement[asset_detail.Title][:record_id] = asset_detail.Record_id.to_f
  return asset_detail,op_statement
end

#to get max month and year
def find_last_updated_items(from_properties_tab = nil)
  if from_properties_tab.blank?
    find_dashboard_portfolio_display
  else
    @resource = "'RealEstateProperty'"
  end
  #find_dashboard_portfolio_display
  @ytd  = []
  actuals  = PropertyFinancialPeriod.find_by_sql("SELECT i.year,pcb_type,january, february, march, april, may, june, july, august, september, october, november, december
        FROM property_financial_periods f INNER JOIN income_and_cash_flow_details i ON i.id = f.source_id AND i.resource_id =#{@note.id} AND f.pcb_type IN ('c') AND f.source_type = 'IncomeAndCashFlowDetail' where i.title = 'balance sheet' ORDER BY i.year DESC LIMIT 1")
  if actuals.empty?
    last_record_month  = 0
  else
    financial_period =[actuals[0].january,actuals[0].february,actuals[0].march,actuals[0].april,actuals[0].may,actuals[0].june,actuals[0].july,actuals[0].august,actuals[0].september,actuals[0].october,actuals[0].november,actuals[0].december]
    last_record_month = (financial_period.index(0.0)).to_i
    last_record_month = (financial_period.index(nil)).to_i  if last_record_month == 0
    last_record_month = (financial_period.index(actuals[0].december)).to_i  if last_record_month == 0
    @last_record_year = actuals[0].year
    @ytd << "IFNULL(f."+Date::MONTHNAMES[last_record_month.to_i].downcase+",0)" if !Date::MONTHNAMES[last_record_month.to_i].nil?

  end
end

#To display breadcrumb in cash tab
 def breadcrumb_in_cash(title,ids)
    arr = []
    arr_heading = ["income details","net operating income","capital expenditures"]
    heading_display_restriction = remote_property(@note.accounting_system_type_id) ? false :  true
    bread_title = "Cash"
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
      base = "<div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span><a href=\"#\" onclick=\"performanceReviewCalls(\\'cash_n_receivables\\',{});return false;\">#{bread_title}</a><img width=\"10\" height=\"9\" src=\"/images/eventsicon2.png\">&nbsp;</div>"
      j=0
      if !arr.empty?
        title_array = []
        for ar1 in arr.reverse
          last_element = arr.first
          heading =  ar1[0]
          title_array << heading.gsub("'","").gsub(/\sdetail/,'').titleize
            if ar1[1] == last_element[1]
              base =  base +"<div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span>#{heading.gsub("'","").gsub(/\sdetail/,'').titleize}&nbsp;</div>"
            else
              if( j > 0) ||( heading_display_restriction == true)
                base =  base + "<div class=\"executivesubheadcol\"><span class=\"executiveiconcol\"><img src=\"/images/executivehead_icon.png\" width=\"14\" height=\"16\" /></span><a href=\"#\" onclick=\"cashSubCalls(1,{cash_find_id:\\'#{ar1[1]}\\',cash_item:\\'#{heading}\\'}); return false;\">#{heading.gsub("'","").gsub(/\sdetail/,'').titleize}</a><img width=\"10\" height=\"9\" src=\"/images/eventsicon2.png\">&nbsp;</div>"
              end
            end
          j +=1
        end
      end
    return base
  end

def remove_if_actual_and_budget_zero
    if ( @cap_exp.building_imp_budget == "0" && @cap_exp.building_imp_actual == "0" ) || ( @cap_exp.building_imp_budget == 0 && @cap_exp.building_imp_actual == 0 )
    @cap_exp.delete_field('building_imp_budget')
    @cap_exp.delete_field('building_imp_actual')
    @cap_exp.delete_field('building_imp_id')
    end
    if ( @cap_exp.tenant_imp_actual == "0" && @cap_exp.tenant_imp_budget == "0" ) || ( @cap_exp.tenant_imp_actual == 0 && @cap_exp.tenant_imp_budget == 0 )
    @cap_exp.delete_field('tenant_imp_actual')
    @cap_exp.delete_field('tenant_imp_budget')
    @cap_exp.delete_field('tenant_imp_id')
    end
    if ( @cap_exp.leasing_comm_actual == "0" && @cap_exp.leasing_comm_budget == "0" ) || ( @cap_exp.leasing_comm_actual == 0 && @cap_exp.leasing_comm_budget == 0 )
    @cap_exp.delete_field('leasing_comm_actual')
    @cap_exp.delete_field('leasing_comm_budget')
    @cap_exp.delete_field('leasing_comm_id')
    end
    if ( @cap_exp.lease_cost_actual == "0" && @cap_exp.lease_cost_budget == "0" ) || ( @cap_exp.lease_cost_actual == 0 && @cap_exp.lease_cost_budget == 0 )
    @cap_exp.delete_field('lease_cost_actual')
    @cap_exp.delete_field('lease_cost_budget')
    @cap_exp.delete_field('lease_cost_id')
    end
    if ( @cap_exp.net_lease_act == "0" && @cap_exp.net_lease_bud == "0" ) || ( @cap_exp.net_lease_act == 0 && @cap_exp.net_lease_bud == 0 )
    @cap_exp.delete_field('net_lease_act')
    @cap_exp.delete_field('net_lease_bud')
    @cap_exp.delete_field('net_lease_id')
    end
    if ( @cap_exp.loan_cost_act == "0" && @cap_exp.loan_cost_bud == "0" ) || ( @cap_exp.loan_cost_act == 0 && @cap_exp.loan_cost_bud == 0 )
    @cap_exp.delete_field('loan_cost_act')
    @cap_exp.delete_field('loan_cost_bud')
    @cap_exp.delete_field('loan_cost_id')
    end
end

def find_transaction_items
 month_in_abr_format = ['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec']
 @transaction_year = find_selected_year(Date.today.year)
 @income_cash_flow_item = IncomeAndCashFlowDetail.find_by_id(params[:financial_subid])
 incom_acc = @income_cash_flow_item.account_code
 calc_for_financial_data_display
 if @balance_sheet
  @transaction_details = RealEstateProperty.find_by_sql("select * from transactions where real_estate_property_id = #{@note.id} and year = #{@last_record_year} and month <= #{@ytd.length} and acc_code = #{incom_acc}")
  @beginning_month = 0
  else
 if params[:tl_period] == "4" || params[:period] == '4'
  @transaction_details = RealEstateProperty.find_by_sql("select * from transactions where real_estate_property_id = #{@note.id} and year = #{@transaction_year} and month <= #{@ytd.length} and acc_code = #{incom_acc}")
  @beginning_month = 0
  elsif params[:tl_period] == "10" || params[:period] == '10' || params[:tl_period] == "5" || params[:period] == "5"
      m = (params[:tl_period] == "10" || params[:period] == '10') ? params[:tl_month].to_i : (params[:tl_month] != "" ?  params[:tl_month].to_i : @financial_month)
     @transaction_details = RealEstateProperty.find_by_sql("select * from transactions where real_estate_property_id = #{@note.id} and year = #{@transaction_year} and month = #{m} and acc_code = #{incom_acc}")
     @beginning_month = m
  elsif params[:tl_period] == "2" || params[:period] == '2'
     qua_months = find_month_list_for_quarterly.join(',')
     @transaction_details = RealEstateProperty.find_by_sql("select * from transactions where real_estate_property_id = #{@note.id} and year = #{@transaction_year} and month in (#{qua_months}) and acc_code = #{incom_acc}")
     @beginning_month =  qua_months.last.to_i
  elsif params[:tl_period] == '6'|| params[:tl_period] == '3'  || params[:period] == '6' || params[:period] == '3'|| params[:period] == '8' || params[:tl_period] == '8'
         @transaction_details = RealEstateProperty.find_by_sql("select * from transactions where real_estate_property_id = #{@note.id} and year = #{@transaction_year} and acc_code = #{incom_acc}")
         @beginning_month = 0
   elsif params[:tl_period] == '7' || params[:period] == '7'
         @transaction_details = RealEstateProperty.find_by_sql("select * from transactions where real_estate_property_id = #{@note.id} and year = #{@transaction_year} and month <= #{month_in_abr_format.index(params[:cur_month].downcase) + 1} and acc_code = #{incom_acc}")
         @beginning_month = 0
       end
    end
end

def find_beginning_balance
  beg_cash  = PropertyFinancialPeriod.find_by_sql("SELECT * from property_financial_periods p where p.source_id = #{params[:financial_subid]} and p.pcb_type = 'p'")[0]
  financial_details =[]
  if beg_cash
      financial_details << beg_cash.january << beg_cash.february << beg_cash.march  << beg_cash.april  <<  beg_cash.may  << beg_cash.june  << beg_cash.july  << beg_cash.august  << beg_cash.september  <<  beg_cash.october  << beg_cash.november  << beg_cash.december
    end
  @beginning_cash = beg_cash && financial_details[@beginning_month - 1] ? financial_details[@beginning_month] : 0
end

def find_transaction_balance(transaction)
  if !@beginning_cash.nil?
   @balance_amt = @beginning_cash +  transaction.daamount.to_f
  else
   @balance_amt = 0 +  transaction.daamount.to_f
  end
   @beginning_cash = @balance_amt
   return @balance_amt.to_f
end

def occupancy_total(p,year=nil)
  year_to_date= Date.today.prev_month.month
  year = Date.today.year
  @ytd= []
  @month_list = []
  for m in 1..year_to_date
    @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
    @month_list <<  Date.new(Time.now.year,m,1).strftime("%Y-%m-%d")
  end
  real_estate_properties = p
  month_qr = find_accounting_system_type(1,p)  && p.leasing_type=="Commercial" ? "" : "HAVING max(ci.month)"
  max_month = PropertyCapitalImprovement.find_by_sql("SELECT max(ci.month) as month,id FROM property_capital_improvements ci WHERE ci.category IN ('TOTAL TENANT IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASE COSTS','TOTAL NET LEASE COSTS','TOTAL LOAN COSTS') AND ci.real_estate_property_id = #{p.id}  AND ci.year=#{Date.today.year} #{month_qr}")
  max_year  = find_occupancy_max_year(p.id)
  connection = ActiveRecord::Base.connection();
  if max_year
    occupancy_max_month = PropertyOccupancySummary.find_by_sql("SELECT max(`month`) as month FROM property_occupancy_summaries o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id} and r.id = #{p.id} and o.year = #{max_year}")
  end
  max_month =  occupancy_max_month[0].month if occupancy_max_month
  if occupancy_max_month && occupancy_max_month[0] && occupancy_max_month[0].month.nil?
    occupancy_qry = ""
  elsif max_month && max_year
    occupancy_qry = "SELECT a.*, b.current_year_sf_occupied_actual, b.current_year_sf_occupied_budget, b.id,b.current_year_units_occupied_actual, b.current_year_units_vacant_actual,b.current_year_sf_vacant_actual,b.current_year_sf_vacant_budget FROM property_occupancy_summaries b RIGHT JOIN ( SELECT #{max_month} as month, real_estate_property_id FROM property_occupancy_summaries WHERE real_estate_property_id = #{p.id} AND year = #{max_year} group by real_estate_property_id having #{max_month}) a ON a.month=b.month and b.year = #{max_year} AND a.real_estate_property_id=b.real_estate_property_id"
  end
  occupancy_details = connection.execute(occupancy_qry) if !occupancy_qry.nil? && occupancy_qry != ""
  if occupancy_details
    for occ_row in occupancy_details
      occ_row_2 = occ_row[2].nil? ? 'NULL' : "#{occ_row[2]}"
    end
  end
  occ_row_2.eql?('NULL') || occ_row_2.eql?(nil) ? 0 : occ_row_2.to_i
end

def dashboard_exp()
  sf_value = 0
  start_date = Date.today.strftime("%Y-%m-%d")
  end_date = params[:exp].present? ? start_date.to_date.advance(:months=>params[:exp].to_i).strftime("%Y-%m-%d") : start_date.to_date.advance(:months=>6).strftime("%Y-%m-%d")
  end_date_qry = "and lease_rent_rolls.lease_end_date <= '#{end_date}'"
  suites_value = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
  year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and occupancy_type = ? and year <= ? ',suites_value,'current',Date.today.year],:order=>"year desc",:limit=>1).map(&:year).max if !suites_value.blank?
  month_val = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and occupancy_type = ? and month <= ? and year=?',suites_value,'current',get_month(year),year],:select=>"month").map(&:month).max if !suites_value.blank? && year.present?
#  month_val = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and occupancy_type = ? and year = ?',suites_value,'current',year.to_i],:select=>"month").map(&:month).max if !suites_value.blank?
  sqft = LeaseRentRoll.find_by_sql("select sum(suites.rentable_sqft) as sqft from suites,lease_rent_rolls where lease_rent_rolls.real_estate_property_id = #{@note.id} and lease_rent_rolls.suite_id = suites.id and lease_rent_rolls.lease_end_date >= '#{start_date}' #{end_date_qry} and lease_rent_rolls.occupancy_type = 'current' and lease_rent_rolls.month = '#{month_val}' and lease_rent_rolls.year = #{year.to_i}")
  if sqft
    for sf in sqft
      sf_value = sf.sqft.nil? ? 0 : sf.sqft
    end
  end
  sf_value.to_i
end

def dashboard_lease_details(month=nil, year=nil,note = nil,from_nav=nil)
  ##removed code related to period for time line selector removal
  @note = note.present? ? note : @note
  month,explanation = month,true
  year_val = from_nav.present? ? Date.today.prev_year.year : Date.today.year
  if is_commercial(@note)
  find_occupancy_values
  year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,year_val],:select=>"year",:order=>"year desc",:limit=>1)
  year = year.compact.empty? ? nil : year[0].year
  os= CommercialLeaseOccupancy.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,year,get_month(year)],:order => "month desc",:limit =>1)
  elsif is_multifamily(@note)
  year = PropertyOccupancySummary.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@note.id,year_val],:select=>"year",:order=>"year desc",:limit=>1)
  year = year.compact.empty? ? nil : year[0].year
  os= PropertyOccupancySummary.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@note.id,year,get_month(year)],:order => "month desc",:limit =>1)
  end
   prop_occup_summary = os if !os.nil? and !os.empty?
  leases,wres_leases = 0,0
  unless prop_occup_summary.blank?
    prop_occup_summary = prop_occup_summary.first
    if @note.leasing_type == 'Commercial'
      current_vacant_pecent_actual = ((prop_occup_summary.current_year_sf_vacant_actual.to_f/(prop_occup_summary.current_year_sf_occupied_actual.to_f+prop_occup_summary.current_year_sf_vacant_actual.to_f))*100).round rescue 0
      leases={
        :current_vacant_percent=>{:actual=>current_vacant_pecent_actual.to_f,:budget=>0.0},
        :current_vacant=>{:actual=>prop_occup_summary.current_year_sf_vacant_actual.to_f, :budget=>0.0},
        :total_rentable_space=>{:actual=>(prop_occup_summary.current_year_sf_occupied_actual.to_f + prop_occup_summary.current_year_sf_vacant_actual.to_f ), :budget=>0.0}
      }
      leases = leases.nil? || leases[:current_vacant_percent].nil? || leases[:current_vacant].nil? ? 0 : leases
    else
      wres_leases={
        :total_rentable_space=>{:units=>prop_occup_summary.current_year_units_total_actual.abs , :budget=>0.0}
      }
      wres_leases = wres_leases.nil? || wres_leases[:total_rentable_space].nil? ||  wres_leases[:total_rentable_space][:units].nil? ? 0 : wres_leases[:total_rentable_space][:units]
    end
  end
   return @note.leasing_type == 'Commercial' ? leases : wres_leases
end

def dashboard_cash_and_receivables_for_receivables(from_nav=nil)
  acc_rev_aging = []
  late_by_30_days,late_by_60_days,late_by_90_days,late_by_120_days,total_tenant,amount_pending = 0,0,0,0,0,0
  property_suite_ids = PropertySuite.find(:all,:conditions=>["real_estate_property_id = ?",@note.id],:select=>'id')
  year = (Date.today.month == 1 || from_nav.present?) ?  Date.today.prev_year.year  :  Date.today.year.to_i
  month_val  =Date.today.prev_month.month
  find_year = PropertyAgedReceivable.find(:first, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>["year<= #{Date.today.year} AND !(round(amount) = 0 AND round(over_30days) = 0 AND  round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0) AND property_suite_id in (?)", property_suite_ids],:include=>["property_suite"],:order => 'year desc' )
  if find_year.present?
    find_month = PropertyAgedReceivable.find(:first, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>["year = #{find_year.year} AND month <= #{get_month(find_year.year)} AND !(round(amount) = 0 AND round(over_30days) = 0 AND  round(over_60days) = 0 AND round(over_90days) = 0 AND round(over_120days) = 0) AND property_suite_id in (?)", property_suite_ids],:include=>["property_suite"],:order => 'month desc' )
    #month = find_year.try(:month)
    month_red_start  = (find_month.nil? ||  find_month.month.blank?) ? 0 : find_month.month.to_i + 12
    value_month = month_red_start - 12
    year = find_year.try(:year)
    acc_rec_aging = PropertyAgedReceivable.find(:all, :select=>['*, over_90days+over_120days as over_120days'], :conditions=>["property_suite_id in (?) and month = ? and year = ?  and (abs(IFNULL(amount,0)) + abs(IFNULL(over_30days,0)) + abs(IFNULL(over_60days,0)) + abs(IFNULL(over_90days,0)) + abs(IFNULL(over_120days,0)) + abs(IFNULL(prepaid,0))) > 0", property_suite_ids,value_month, year.to_i],:order=>(!@pdf ? params[:sort] : "id asc") ,:include=>["property_suite"]) if !property_suite_ids.empty?
   if acc_rec_aging.present?
      acc_rec_aging.each do |aging|
        aging_30_days,aging_60_days,aging_90_days,aging_120_days,prepaid,pending_amount = find_aging_details(aging)
        amount_pending = amount_pending + pending_amount
        late_by_30_days = late_by_30_days + aging_30_days
        late_by_60_days = late_by_60_days + aging_60_days
        late_by_90_days = late_by_90_days + aging_90_days
        late_by_120_days = late_by_120_days + aging_120_days
      end
    end
  end
   total_tenant = (late_by_30_days + late_by_60_days + late_by_120_days + amount_pending).round
end

def dashboard_rent_roll()
  rent_roll_swig = []
  base_rent_suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
  year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and occupancy_type = ?',base_rent_suites,'current'],:order=>"year desc",:limit=>1).map(&:year).max if !base_rent_suites.blank?
  month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and occupancy_type = ? and year = ?',base_rent_suites,'current',year.to_i],:select=>"month").map(&:month).max if !base_rent_suites.blank?
  sort = "pl.lease_end_date"
  rent_roll_swig = LeaseRentRoll.find_by_sql("SELECT ps.id,ps.suite_no,pl.* FROM `lease_rent_rolls` pl INNER JOIN suites ps ON pl.suite_id = ps.id WHERE (ps.real_estate_property_id = #{@note.id} and pl.occupancy_type = 'current' and pl.month = #{month} and pl.year = #{year.to_i}) order by #{sort};")  if (!month.nil? && (!year.nil? || !year.blank?)) && sort != ""
  rent_value = rent_roll_swig.blank? ? 0 : base_rent_total(0,rent_roll_swig)
end

def dashboard_currency_display(value,absolute=nil)
  return "0" if value.nil? || value.blank? || value == 0
#  return "-#{number_with_delimiter(value.round.abs)}" if value < 0
  return "#{number_with_delimiter(value.round)}" if absolute.present?
  "#{number_with_delimiter(value.round.abs)}"
end

#New method for tenant number for commercial comparison
def dashboard_number_display(value,absolute=nil)
  return "0" if value.nil? || value.blank? || value == 0
#  return "-#{number_with_delimiter(value.round.abs)}" if value < 0
  #~ return "#{number_with_delimiter(value.round)}" if absolute.present?
  return "#{(value.round)}" if absolute.present?
  "#{(value.round.abs)}"
end

def dashboard_store_income_and_cash_flow_statement(from_properties_tab = nil,from_nav=nil)
  @operating_statement={}
  @cash_flow_statement={}
  calc_for_financial_data_display
  year_to_date = @financial_month
  year =  (Date.today.month.eql?(1) || from_nav.present?) ? Date.today.prev_year.year : Date.today.year
  @month_to_year = year_to_date
  @year = year
  @ytd= []
  @month_list = []
  @explanation = true
  for n in 1..year_to_date
    @ytd << "IFNULL(f."+Date::MONTHNAMES[n].downcase+",0)"
    @month_list <<  Date.new(Time.now.year,n,1).strftime("%Y-%m-%d")
  end
  financial_title = find_non_financial_title(from_properties_tab)
  qry =  "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title}) or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title}) or (a.parent_id is null)) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"
  if qry != nil && ((@ytd && !@ytd.empty?) || (@ytd_actuals))
    asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
    @operating_statement['operating expenses']={:budget =>0 ,:actuals =>0}
    for cash_row in asset_details
      if (cash_row.Actuals.to_f !=0.0 || cash_row.Budget.to_f !=0.0)
        val ={}
        if cash_row.Parent == "cash flow statement summary" || cash_row.Parent == "CASH FLOW STATEMENT" || (params[:partial_page] == 'cash_and_receivables'  &&  remote_property(@note.accounting_system_type_id))
          @cash_flow_statement[cash_row.Title] = form_hash_of_data(cash_row)
          @operating_statement[cash_row.Title] =  form_hash_of_data(cash_row)
        else
          data = form_hash_of_data(cash_row)
          @operating_statement[cash_row.Title] = data
          @cash_flow_statement[cash_row.Title] = data if cash_row.Title == "depreciation & amortization detail" or cash_row.Title =="net income" or cash_row.Title == "CASH FLOW STATEMENT"
        end
      end
    end
    net_income_operation_summary_report(from_properties_tab)
  end
  return @net_income_de,@operating_statement,@cash_flow_statement
end

def dashboard_remote_cash_flow_statement(operating_statement,from_properties_tab = nil)
  find_cash_account_code
  total_cash_actuals,total_cash_budget,total_cash_variance,total_cash_percent,item_total_actuals,item_total_budget = 0,0,0,0,0,0
  title_net = map_title("NET OPERATING INCOME",from_properties_tab)
  #Included if !empty condition to fix nil error#
  if @cash_sub_items_account_code && !@cash_sub_items_account_code.empty?
  @cash_sub_items_account_code.each do |account_code|
    if account_code == 0
      cash_item = find_income_and_cash_flow_item(account_code)
      find_financial_sub_items("ADJUSTMENTS",from_properties_tab)
      dashboard_calculate_the_financial_sub_graph(Date.today.year)
      @asset_details = @asset_details.collect{|asset| asset if asset.Actuals.to_f.round !=0 || asset.Budget.to_f.round !=0}.compact if @asset_details && !@asset_details.empty?
      if @asset_details && !@asset_details.empty?
        @asset_details = @asset_details.compact.sort_by(&:Record_id) if @asset_details
        for asset_detail in @asset_details
          if (cash_item.nil? || cash_item.account_code == 0) && asset_detail.InormalBalance == '0'
            asset_actuals = ((asset_detail.Actuals.to_f) * (-1)).to_f
            asset_budget = ((asset_detail.Budget.to_f) * (-1)).to_f
          else
            asset_actuals = (asset_detail.Actuals.to_f).to_f
            asset_budget = (asset_detail.Budget.to_f).to_f
          end
          item_total_actuals = item_total_actuals + asset_actuals
          item_total_budget += asset_budget
        end
      end
      total_cash_actuals = (operating_statement[title_net][:actuals])+ item_total_actuals  if operating_statement[title_net]
      total_cash_budget = (operating_statement[title_net][:budget])+ item_total_budget  if operating_statement[title_net]
    end
  end
  end
  total_cash_variance = total_cash_budget - total_cash_actuals
  total_cash_percent = total_cash_budget.eql?(0) ? 0 : (total_cash_variance/total_cash_budget)*100
  return total_cash_actuals,total_cash_budget,total_cash_variance,total_cash_percent
end

def dashboard_calculate_the_financial_sub_graph(year=nil)
  calc_for_financial_data_display
  year_to_date= @financial_month
  @ytd= []
  for m in 1..year_to_date
    @ytd << "IFNULL(f."+Date::MONTHNAMES[m].downcase+",0)"
  end
  dashboard_find_out_asset_details(year)
end

def dashboard_find_out_asset_details(year)
  adjustments =  AccountTree.find(:all,:conditions=>["title in ('ADJUSTMENTS')"]).map(&:id).join(',')
  adjustment_sub_items_account_num =  AccountTree.find(:all,:conditions=>["parent_id in (#{adjustments})"]).map(&:account_num).join(',') if adjustments
  cash_items = IncomeAndCashFlowDetail.find_by_sql("select * from income_and_cash_flow_details where account_code in (#{adjustment_sub_items_account_num})").map(&:id).join(',')
  cash_items_titles = IncomeAndCashFlowDetail.find_by_sql("select * from income_and_cash_flow_details where account_code in (#{adjustment_sub_items_account_num})").map(&:title).join(',')
  qry = "select Parent, Title, sum(actuals) as Actuals, sum(budget) as Budget,sum(child_id) as Record_id,inormal_balance as InormalBalance from (SELECT k.title as Parent, a.title as Title, f.pcb_type, #{@ytd.join("+")} as actuals, 0 as budget , a.id as child_id,a.inormalbalance as inormal_balance FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.id IN (#{cash_items}) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as actuals, #{@ytd.join("+")} as budget,0 as child_id,a.inormalbalance as inormal_balance FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND a.id IN (#{cash_items}) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz group by Parent, Title"
  @asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
end

def net_cash_calc(cash_flow_statement,cash_type)
  if cash_type == 'net_cash_flow'
    net_cash_flow_actual = cash_flow_statement['net cash flow'].nil? ? 0 : cash_flow_statement['net cash flow'][:actuals]
    net_cash_flow_budget = cash_flow_statement['net cash flow'].nil? ? 0 : cash_flow_statement['net cash flow'][:budget]
    net_cash_flow_variant = cash_flow_statement['net cash flow'].nil? ? 0 : cash_flow_statement['net cash flow'][:variant]
    net_cash_flow_percent = cash_flow_statement['net cash flow'].nil? ? 0 : cash_flow_statement['net cash flow'][:percent]
  else
    net_cash_flow_actual = cash_flow_statement['CASH FLOW STATEMENT'].nil? ? 0 : cash_flow_statement['CASH FLOW STATEMENT'][:actuals]
    net_cash_flow_budget = cash_flow_statement['CASH FLOW STATEMENT'].nil? ? 0 : cash_flow_statement['CASH FLOW STATEMENT'][:budget]
    net_cash_flow_variant = cash_flow_statement['CASH FLOW STATEMENT'].nil? ? 0 : cash_flow_statement['CASH FLOW STATEMENT'][:variant]
    net_cash_flow_percent = cash_flow_statement['CASH FLOW STATEMENT'].nil? ? 0 : cash_flow_statement['CASH FLOW STATEMENT'][:percent]
  end
  return net_cash_flow_actual,net_cash_flow_budget,net_cash_flow_variant,net_cash_flow_percent
end

def revenue_calc(revenue)
  revenue_act = revenue.nil? ? 0 : revenue[:actuals]
  revenue_bud = revenue.nil? ? 0 : revenue[:budget]
  revenue_per = revenue.nil? ? 0 : revenue[:percent]
  revenue_var = revenue.nil? ? 0 : revenue[:variant]
  return revenue_act,revenue_bud,revenue_per,revenue_var
end

def find_net_cash(operating_statement)
  if operating_statement['CASH FLOW STATEMENT'].present?
    return operating_statement['CASH FLOW STATEMENT'],'cash_flow_statement'
  else
    return operating_statement['net cash flow'],'net_cash_flow'
  end
end


  def find_net_income(operating_statement)
    if operating_statement['net income before depreciation'].present?
    return operating_statement['net income before depreciation']
  else
    return operating_statement['net income']
    end
  end

  def find_ytd_noi(operating_statement)
    if operating_statement['net operating income'].present?
      return operating_statement['net operating income']
      end
  end

def dashboard_update_display

  portfolio = Portfolio.find_by_name_and_user_id("portfolio_created_by_system",current_user.id)
  folder = Folder.find_by_name_and_parent_id_and_user_id('my_files',0,current_user.id)
  folders = Folder.find_all_by_parent_id_and_is_deleted(folder.id,false)
  documents = Document.find_all_by_folder_id_and_is_deleted(folder.id,false)
  conditions =  "and is_deleted = false"
  portfolios = []
  real_estate_properties = []
  real_estate_properties = RealEstateProperty.find(:all, :conditions => ["real_estate_properties.user_id = ? and real_estate_properties.client_id = #{current_user.client_id}",current_user.id],:joins=>:portfolios, :select => "portfolios.id as portfolio_id,real_estate_properties.id,property_name", :order => "real_estate_properties.created_at desc, real_estate_properties.last_updated desc")
  real_estate_properties = real_estate_properties.select{|i| i.portfolio.try(:name) != 'portfolio_created_by_system_for_deal_room'}
  portfolios = Portfolio.find(:all, :conditions => ["user_id = ? and portfolio_type_id = 2",current_user.id])
  shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{current_user.id } AND client_id = #{current_user.client_id})")
  portfolios += Portfolio.find(:all, :conditions => ["id in (?)",shared_folders.collect {|x| x.portfolio_id}]) if !(shared_folders.nil? || shared_folders.blank?)
  real_estate_properties += RealEstateProperty.find(:all, :conditions => ["real_estate_properties.id in (?)",shared_folders.collect {|x| x.real_estate_property_id}],:joins=>:portfolios, :select => "portfolios.id as portfolio_id,real_estate_properties.id,property_name").select{|i| i.portfolio.name != 'portfolio_created_by_system_for_deal_room' if i.portfolio.present?} if !(shared_folders.nil? || shared_folders.blank?)
  sahred_folders_collection,shared_docs_collection,shared_properties_collection  = [],[],[]
  tmp = SharedFolder.find(:all,:conditions=>["user_id = ? and client_id = ? ",current_user.id,current_user.client_id]).select{|sf| sf.folder.try(:portfolio).try(:name) != 'portfolio_created_by_system_for_deal_room'}
  s = tmp.collect{|sf| sf.folder_id}
  fs = Folder.find(:all,:conditions=>["id in (?) and parent_id not in (?) #{conditions} and (real_estate_property_id is NOT NULL or parent_id = -1 )",s,s]).collect{|f| f.id}
  shared_folders_real_estate = SharedFolder.find(:all,:conditions=>["user_id = ? and folder_id in (?) and (is_property_folder != 1 || is_property_folder is null) and client_id = ?",current_user.id,fs,current_user.client_id])
  if s.empty?
    tmp_doc = SharedDocument.find(:all,:conditions=>["user_id = ? ",current_user.id]).select{|sf| sf.folder.portfolio.name != 'portfolio_created_by_system_for_deal_room'}
    shared_docs_ids = tmp_doc.collect{|sd| sd.document_id}
  else
    tmp_doc = SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?)",current_user.id,s]).select{|sf| sf.folder.portfolio.name != 'portfolio_created_by_system_for_deal_room'}
    shared_docs_ids = tmp_doc.collect{|sd| sd.document_id}
  end
  shared_folders_real_estate = shared_folders_real_estate.collect{|sf| sf.folder if sf.folder.try(:real_estate_property).try(:user_id) != current_user.id && sf.folder.try(:portfolio).try(:user_id) != current_user.id}.compact
  documents_ids = Document.find(:all,:conditions=>["id in (?) #{conditions} and real_estate_property_id is NOT NULL ",shared_docs_ids]).collect{|d| d.id}
  shared_docs = shared_docs_ids.empty? ? SharedDocument.find(:all,:conditions=>["user_id = ? and document_id in (?)",current_user.id,documents_ids]) :  s.empty? ? SharedDocument.find(:all,:conditions=>["user_id = ? and document_id in (?)",current_user.id,documents_ids]) : SharedDocument.find(:all,:conditions=>["user_id = ? and folder_id not in (?) and document_id in (?)",current_user.id,s,documents_ids])
  shared_docs_real_estate = shared_docs.collect{|sd| sd.document if sd.folder && sd.folder.real_estate_property.user_id != current_user.id && sd.folder.portfolio.user_id != current_user.id}.compact
  folders = folders + shared_folders_real_estate
  documents = documents + shared_docs_real_estate
  sahred_folders_collection = shared_folders_real_estate.collect{|x| x.id}.join(",")
  shared_docs_collection = shared_docs_real_estate.collect{|x| x.id}.join(",")
  shared_and_owned_properties_collection = real_estate_properties.collect{|x| x.id}.join(",")

  return sahred_folders_collection, shared_docs_collection, shared_and_owned_properties_collection, folder

end

def capital_percent_nan_chk(capital_percent)
  val = capital_percent.values
  val.delete_if { |i| i.nan?}
end

  def show_err_msg_if_no_access
    if @note.nil?
      if @notes.collect{|x| x.id}.include?(params[:id].to_i)
        @note = RealEstateProperty.find_real_estate_property(params[:id])
      else
        @note = @notes.first
        flash[:notice]=FLASH_MESSAGES['properties']['408']
      end
    end
    if @note && (@note.user_id != current_user.id && find_property_shared(@note).nil?)
      flash[:notice]=FLASH_MESSAGES['properties']['408']
      @note = @notes.first
    end
  end

  def find_commercial_lease_occupancy(property_id,year_occ)
   return CommercialLeaseOccupancy.find(:first, :conditions => ["real_estate_property_id = ? and year = ?",property_id,year_occ], :order => "month desc")
 end

def find_multifamily_occupancy(property_id,connection,year,id)
    @max_year  = find_occupancy_max_year(property_id)
    if @max_year
      occupancy_max_month = PropertyOccupancySummary.find_by_sql("SELECT max(`month`) as month FROM property_occupancy_summaries o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id} and r.id = #{property_id} and o.year = #{@max_year}")
    end
    #max_month =  (@period == "5") ? "#{Date.today.prev_month.month}" : occupancy_max_month[0].month
    max_month =  occupancy_max_month[0].month if occupancy_max_month
    if occupancy_max_month && occupancy_max_month[0] && occupancy_max_month[0].month.nil?
      @occupancy_qry = ""
    elsif max_month && @max_year
      @occupancy_qry = "SELECT a.*, b.current_year_sf_occupied_actual, b.current_year_sf_occupied_budget, b.id,b.current_year_units_occupied_actual, b.current_year_units_vacant_actual,b.current_year_sf_vacant_actual,b.current_year_sf_vacant_budget FROM property_occupancy_summaries b RIGHT JOIN ( SELECT #{max_month} as month, real_estate_property_id FROM property_occupancy_summaries WHERE real_estate_property_id = #{property_id} AND year = #{@max_year} group by real_estate_property_id having #{max_month}) a ON a.month=b.month and b.year = #{@max_year} AND a.real_estate_property_id=b.real_estate_property_id"
    end
      return @occupancy_qry,@max_year
  end

  def find_commercial_occupancy(property_id,connection,year,id)
    find_occupancy_values
    @max_year  =find_commercial_max_year(property_id)
    if @max_year
        occupancy_max_month = CommercialLeaseOccupancy.find_by_sql("SELECT max(`month`) as month FROM commercial_lease_occupancies o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id} and r.id = #{property_id} and o.year = #{@max_year}")
    end
    #max_month =  (@period == "5") ? "#{Date.today.prev_month.month}" : occupancy_max_month[0].month
    max_month =  occupancy_max_month[0].month if occupancy_max_month
    if occupancy_max_month && occupancy_max_month[0] && occupancy_max_month[0].month.nil?
        @occupancy_qry = ""
    elsif max_month && @max_year
      @occupancy_qry = "SELECT a.*, b.current_year_sf_occupied_actual, b.current_year_sf_occupied_budget, b.id,b.current_year_sf_vacant_actual,b.current_year_sf_vacant_budget FROM commercial_lease_occupancies b RIGHT JOIN ( SELECT #{max_month} as month, real_estate_property_id FROM commercial_lease_occupancies WHERE real_estate_property_id = #{property_id} AND year = #{@max_year} group by real_estate_property_id having #{max_month}) a ON a.month=b.month and b.year = #{@max_year} AND a.real_estate_property_id=b.real_estate_property_id"
    end
      return @occupancy_qry,@max_year
    end

    def find_commercial_max_year(property_id)
    @max_year  =  CommercialLeaseOccupancy.find_by_sql("SELECT max(`year`) as year FROM commercial_lease_occupancies o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id} and r.id = #{property_id}")
   return  @max_year[0].year if @max_year && @max_year[0]
 end

  def check_accounting_sys_type_MRI
      acc_sys_type=AccountingSystemType.find_by_id(@note.accounting_system_type_id)
      acc_sys_type.type_name && (acc_sys_type.type_name=="MRI" || acc_sys_type.type_name == "MRI, SWIG") ? true : false
  end

  #added to find the trailing 12 months actuals and budget#
  def find_pcb_type
      actual_pcb_type = (params[:tl_period] == "11" || params[:period] == "11") ? "'c_ytd12'" : "'c'"
      budget_pcb_type = (params[:tl_period] == "11" || params[:period] == "11") ? "'b_ytd12'" : "'b'"
      return actual_pcb_type,budget_pcb_type
  end
end
