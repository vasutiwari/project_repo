class DashboardController < ApplicationController
  before_filter :user_required
  before_filter :change_session_value, :only=>[:financial_info,:property_commercial_leasing_info, :property_multifamily_leasing_info,:property_info,:portfolio_commercial_leasing_info,:portfolio_multifamily_leasing_info, :portfolio_multifamily_leasing_info_for_timeline_selection, :display_graphs_for_property_basing_on_selected_floor_plan, :display_graphs_for_portfolio_basing_on_selected_floor_plan, :update_floor_plan_drop_down_data_for_property, :update_floor_plan_drop_down_data_for_portpolio,:trends]

  before_filter :check_property_access, :only=> [:financial_info,:property_commercial_leasing_info, :property_multifamily_leasing_info,:property_info,:portfolio_commercial_leasing_info,:portfolio_multifamily_leasing_info, :portfolio_multifamily_leasing_info_for_timeline_selection, :display_graphs_for_property_basing_on_selected_floor_plan, :display_graphs_for_portfolio_basing_on_selected_floor_plan, :update_floor_plan_drop_down_data_for_property, :update_floor_plan_drop_down_data_for_portpolio,:property_info,:trends]

  before_filter :check_portfolio_access, :only=> [:financial_info,:property_commercial_leasing_info, :property_multifamily_leasing_info,:property_info,:portfolio_commercial_leasing_info,:portfolio_multifamily_leasing_info, :portfolio_multifamily_leasing_info_for_timeline_selection, :display_graphs_for_property_basing_on_selected_floor_plan, :display_graphs_for_portfolio_basing_on_selected_floor_plan, :update_floor_plan_drop_down_data_for_property, :update_floor_plan_drop_down_data_for_portpolio,:property_info,:trends]

  layout 'user'


  def financial_info
    if request.xhr? && (params[:from_exec_summary] || params[:form_comments] || params[:form_edit] || params[:from_delete_comment])
      comments_for_exec_summary_ajax # this function calls the method for performing comments of executive summary
   else
    financial_access = current_user.try(:client).try(:is_financials_required)
    if session[:portfolio__id].present?  && !session[:property__id].present?
        @note = Portfolio.find_by_id(session[:portfolio__id])
        @resource = "'Portfolio'"
        
        exec_summary_create_or_update  # this function calls the method for creating and updation executive summary for portfolio
        
      if financial_access
        find_financial_info_for_portfolio_property
      else
        redirect_to portfolio_leasing_info_url(@note.try(:id))
      end

    elsif session[:property__id].present?
        session[:property__id] = session[:property__id].to_s.include?("review")  ? session[:property__id].split("?")[0] : session[:property__id]
        @real_estate_property = RealEstateProperty.find_real_estate_property(session[:property__id]) if session[:property__id].present?
        @real_property  =  RealEstateProperty.find_by_id(session[:property__id]) if session[:property__id].present?
        @note = @real_estate_property || @real_property
        @resource = "'RealEstateProperty'"
        exec_summary_create_or_update  # this function calls the method for creating and updation executive summary for property
      if financial_access
        find_financial_info_for_portfolio_property
      else
        redirect_to property_leasing_info_url(@note.try(:portfolio_id),@note.try(:id))
      end
    end
  end #it is exec_summary's ajax call end
end

  def portfolio_multifamily_leasing_info
    @portfolio = Portfolio.find_by_id(session[:portfolio__id])
    @real_estate_property_ids = @portfolio.real_estate_properties.map(&:id) || []
    @weekly_floor_plan = PropertyWeeklyOsr.where(:real_estate_property_id => @real_estate_property_ids ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
    @rent_analysis_floor_plan = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
    @selected_floor_plan = 'All'
    @last_12_weeks_dates, @date_array, @date_month =  RealEstateProperty.get_last_week_dates
    @selected_time_line = @date_array.count-1
    @currently_selected_sunday = @last_12_weeks_dates[@selected_time_line] rescue nil
    @start_date_position=@date_array.count-7
    exec_summary_for_leasing_info
  end

  def property_commercial_leasing_info
    exec_summary_for_leasing_info
  end
  
  def portfolio_commercial_leasing_info
    exec_summary_for_leasing_info
  end  

  def trends
    if params[:trend_value]
     income_cash = IncomeAndCashFlowDetail.find_by_id(params[:trend_value].to_i).try(:title)
     params[:selected_link] = income_cash.strip
    end
    calc_for_financial_data_display
    params[:trend_graph] = true
    #~ params[:tl_year]  = params[:tl_year]  if params[:tl_year] .present?
    params[:tl_period] = params[:tl_period].present? && (  params[:tl_period].eql?("7") && params[:tl_year].to_i.eql?(@financial_year) || params[:tl_period].eql?("2") && params[:tl_year].to_i.eql?(@financial_year) || (params[:tl_period].eql?("10") && params[:tl_year].to_i.eql?(@financial_year))  || params[:tl_period].eql?("5") || params[:tl_period].eql?("8"))? "4" :   (params[:tl_period].eql?("10") && params[:tl_year].to_i.eql?(Date.today.prev_year.year) || params[:tl_period].eql?("2") && params[:tl_year].to_i.eql?(Date.today.prev_year.year)  || params[:tl_period].eql?("7") && params[:tl_year].to_i.eql?(Date.today.prev_year.year) ? "3" : params[:tl_period].present? ? params[:tl_period] : "4")
    params[:tl_year] = @financial_year
    @portfolio = Portfolio.find_by_id(params[:portfolio_id])
    @property_id = (params[:property_id].present? && params[:property_id].include?('review')) ? params[:property_id].split('?')[0]  :  params[:property_id].present? ? params[:property_id] : @portfolio.try(:real_estate_properties).try(:first).try(:id)
    @graph_property_id = @property_id
    @graph_portfolio_id = params[:portfolio_id]
    @first_two_digit_year=Time.now.year.to_s.first(2)
    @op_rev_sub,@op_ex_sub,@non_op_ex_sub = [],[],[]
    tmp_period = params[:tl_period]
    params[:tl_period] = "4"
    find_financial_sub_items("Operating Revenue")
    params[:parent_title] = 'income' if params[:parent_title].blank?
    @parent_title = params[:parent_title].include?('review') ? params[:parent_title].split('?')[0] : params[:parent_title]
    params[:selected_link] = map_title("Operating Revenue") if params[:selected_link].blank?
    @asset_details.each do |asset_detail|
#      @op_rev_sub << asset_detail.Title.titleize
      @op_rev_sub << asset_detail.Title
    end
    find_financial_sub_items("Operating Expenses")
    @asset_details.each do |asset_detail|
#      @op_ex_sub << asset_detail.Title.titleize
      @op_ex_sub << asset_detail.Title
    end
    find_financial_sub_items("Non Operating Expense")
    if @asset_details.present?
      @asset_details.each do |asset_detail|
        @non_op_ex_sub << asset_detail.Title
      end
    else
      is_commercial(@note) ? find_financial_sub_items("net operating income") : find_financial_sub_items("other income and expense")
      @asset_details.each do |asset_detail|
        @non_op_ex_sub << asset_detail.Title
      end
    end
    params[:tl_period] = tmp_period
    if params[:selected_link].present?
      tmp_period = params[:tl_period]
      tmp_year = params[:tl_year]
      params[:tl_period] = "3"
      #      previous year details start
      params[:tl_year] = Date.today.prev_year.year
      find_financial_sub_items(map_title(params[:selected_link].strip))
      @last_year_financial_sub_id = params[:financial_subid]
      @last_year_financial_sub = params[:financial_sub]
      #      prev_year details ends
      #      prev_year's prev_year  details starts
      params[:tl_year] = Date.today.prev_year.prev_year.year
      find_financial_sub_items(map_title(params[:selected_link].strip))
      @second_last_year_financial_sub_id = params[:financial_subid]
      @second_last_year_financial_sub = params[:financial_sub]
      #      prev_year's prev_year  details ends
      params[:tl_period] = tmp_period
      params[:tl_year] = tmp_year
      find_financial_sub_items(map_title(params[:selected_link].strip))
      @financial_sub_id = params[:financial_subid]
      @financial_sub = params[:financial_sub]
      bread_crumb_property_id = (params[:property_id] && params[:property_id].present?) ? params[:property_id] : "false"
      @bread_crumb = breadcrumb_in_trend(params[:financial_sub],params[:financial_subid],@portfolio.try(:id),bread_crumb_property_id)
    end
    trend_operating_trend_graph
    find_data_for_noi_variances
    financial_ytd_occupancy_display
    calc_for_financial_data_display
    if (params[:tl_period] == "4" || params[:tl_period] == "11")
      #      store_income_and_cash_flow_statement
      @current_op_st = @operating_statement
    elsif params[:tl_period].eql?("3")
      params[:tl_year] = Date.today.prev_year.year
      #      store_income_and_cash_flow_statement_for_prev_year
    end
    if request.xhr?
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "trend_content", :partial => "/dashboard/trends", :locals => {:trend_graph => true,:operating_statement => @current_op_st,:graph_property_id=>@graph_property_id,:graph_portfolio_id=>@graph_portfolio_id,:first_two_digit_year=>@first_two_digit_year,:property_id=>@property_id}
            #            find_financial_sub_items("#{params[:selected_link].strip}")
            #            bread_crumb = breadcrumb_in_trend(params[:financial_sub],params[:financial_subid])
            page.replace_html 'trend_breadcrum', @bread_crumb
          end
        }
      end
    end
  end

  def property_multifamily_leasing_info
    @note = RealEstateProperty.find_by_id(params[:property_id]) if @note.blank? && params[:property_id].present?
    @weekly_floor_plan = PropertyWeeklyOsr.where(:real_estate_property_id => @note.id ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
    @rent_analysis_floor_plan = PropertySuite.where(:real_estate_property_id => @note.id ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
    @selected_floor_plan = 'All'
    @last_12_weeks_dates, @date_array, @date_month =  RealEstateProperty.get_last_week_dates
    @selected_time_line = @date_array.count-1
    @currently_selected_sunday = @last_12_weeks_dates[@selected_time_line] rescue nil
    @start_date_position=@date_array.count-7
    exec_summary_for_leasing_info
  end


  def property_multifamily_leasing_info_for_timeline_selection
    @selected_time_line =  params[:selected_timeline].to_i rescue 11
    @note = RealEstateProperty.find_by_id(params[:property_id]) if @note.blank? && params[:property_id].present?
    @last_12_weeks_dates, @date_array, @date_month =  RealEstateProperty.get_last_week_dates
    @currently_selected_sunday = @last_12_weeks_dates[@selected_time_line] rescue nil
    @currently_selected_sunday =  @currently_selected_sunday || Time.now.to_date-Time.now.wday
    @start_date_position=find_time_line_start(@last_12_weeks_dates,params[:selected_timeline].to_i, params[:next_button_status_disabled])
    #@start_date_position=@date_array.count-7
    if @currently_selected_sunday.present?
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "show_time_based_tables", :partial => "/dashboard/multifamily_property_timeline_tables", :locals => {:property_id => @note.try(:id), :portfolio_id => params[:portfolio_id]}
          end
        }
      end
    end
  end

  def display_graphs_for_property_basing_on_selected_floor_plan
    @note = RealEstateProperty.find_by_id(params[:property_id]) if @note.blank? && params[:property_id].present?
    @selected_floor_plan = params[:floor_plan]
    if params["selected_tab"].present? && params["selected_tab"].eql?("rent_analysis")
      @rent_analysis_floor_plan = PropertySuite.where(:real_estate_property_id => @note.id ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "show_rent_analysis_graph", :partial => "/dashboard/rent_analysis_graph", :locals => {:portfolio_id => params[:portfolio_id], :property_id =>  params[:property_id]}
          end
        }
      end
    else
      @weekly_floor_plan = PropertyWeeklyOsr.where(:real_estate_property_id => @note.id ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "show_weekly_graphs", :partial => "/dashboard/weekly_graphs", :locals => {:portfolio_id => params[:portfolio_id], :property_id =>  params[:property_id]}
          end
        }
      end
    end
  end

  def display_graphs_for_portfolio_basing_on_selected_floor_plan
    @portfolio = Portfolio.find_by_id(session[:portfolio__id])
    @real_estate_property_ids = @portfolio.real_estate_properties.map(&:id) || []
    @selected_floor_plan = params[:floor_plan]
    if params["selected_tab"].present? && params["selected_tab"].eql?("rent_analysis")
      @rent_analysis_floor_plan = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "show_portfolio_rent_analysis_graph", :partial => "/dashboard/rent_analysis_graph", :locals => {:portfolio_id => params[:portfolio_id], :property_id =>  params[:property_id]}
          end
        }
      end
    else
      @weekly_floor_plan = PropertyWeeklyOsr.where(:real_estate_property_id => @real_estate_property_ids ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "show_portfolio_weekly_graphs", :partial => "/dashboard/weekly_graphs", :locals => {:portfolio_id => params[:portfolio_id], :property_id =>  params[:property_id]}
          end
        }
      end
    end

  end

  def portfolio_multifamily_leasing_info_for_timeline_selection
    @selected_time_line =  params[:selected_timeline].to_i rescue 11
    @portfolio = Portfolio.find_by_id(session[:portfolio__id])
    @real_estate_property_ids = @portfolio.real_estate_properties.map(&:id) || []
    # @note = RealEstateProperty.find_by_id(params[:property_id]) if @note.blank? && params[:property_id].present?
    @last_12_weeks_dates, @date_array, @date_month =  RealEstateProperty.get_last_week_dates
    @currently_selected_sunday = @last_12_weeks_dates[@selected_time_line] rescue nil
    @currently_selected_sunday =  @currently_selected_sunday || Time.now.to_date-Time.now.wday
    @start_date_position=find_time_line_start(@last_12_weeks_dates,params[:selected_timeline].to_i, params[:next_button_status_disabled])
    if @currently_selected_sunday.present?
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "show_time_based_tables_for_portfolio", :partial => "/dashboard/multifamily_portfolio_timeline_tables", :locals => {:portfolio_id => params[:portfolio_id]}
          end
        }
      end
    end

  end


  def leasing_info
  end

  def property_info
    if params[:property_id].present?
      @real_estate_property = RealEstateProperty.find_real_estate_property(params[:property_id]) if params[:property_id].present?
      @note = @real_estate_property
    end
    property_view
  end

  def update_floor_plan_drop_down_data_for_property
    @note = RealEstateProperty.find_by_id(params[:property_id]) if params[:property_id].present?
    @selected_floor_plan = 'All'
    if params["selected_tab"].present? && params["selected_tab"].eql?("rent_analysis")
      @rent_analysis_floor_plan = PropertySuite.where(:real_estate_property_id => @note.id ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "update_floor_plan_data", :partial => "/dashboard/display_property_floor_plan_drop_down", :locals => {:property_id => @note.try(:id),:portfolio_id => params[:portfolio_id]}
            page.replace_html  "show_rent_analysis_graph", :partial => "/dashboard/rent_analysis_graph", :locals => {:portfolio_id => params[:portfolio_id], :property_id =>  params[:property_id]}
          end
        }
      end
    else
      @weekly_floor_plan = PropertyWeeklyOsr.where(:real_estate_property_id => @note.id ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "update_floor_plan_data", :partial => "/dashboard/display_property_floor_plan_drop_down", :locals => {:property_id => @note.try(:id), :portfolio_id => params[:portfolio_id]}
            page.replace_html  "show_weekly_graphs", :partial => "/dashboard/weekly_graphs", :locals => {:portfolio_id => params[:portfolio_id], :property_id =>  params[:property_id]}
          end
        }
      end
    end
  end



  def update_floor_plan_drop_down_data_for_portpolio
    @portfolio = Portfolio.find_by_id(session[:portfolio__id])
    @real_estate_property_ids = @portfolio.real_estate_properties.map(&:id) || []
    @selected_floor_plan = 'All'
    if params["selected_tab"].present? && params["selected_tab"].eql?("rent_analysis")
      @rent_analysis_floor_plan = PropertySuite.where(:real_estate_property_id => @real_estate_property_ids ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "update_portfolio_floor_plan_data", :partial => "/dashboard/display_portfolio_floor_plan_drop_down", :locals => {:portfolio_id => params[:portfolio_id]}
            page.replace_html  "show_portfolio_rent_analysis_graph", :partial => "/dashboard/rent_analysis_graph", :locals => {:portfolio_id => params[:portfolio_id]}
          end
        }
      end
    else
      @weekly_floor_plan = PropertyWeeklyOsr.where(:real_estate_property_id => @real_estate_property_ids ).select("distinct(floor_plan)").map(&:floor_plan).unshift("All") || [] rescue []
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "update_portfolio_floor_plan_data", :partial => "/dashboard/display_portfolio_floor_plan_drop_down", :locals => {:property_id => @note.try(:id), :portfolio_id => params[:portfolio_id]}
            page.replace_html  "show_portfolio_weekly_graphs", :partial => "/dashboard/weekly_graphs", :locals => {:portfolio_id => params[:portfolio_id]}
          end
        }
      end
    end

  end


  def change_session_value
    if (params[:portfolio_id].present? && params[:property_id].blank?)
      session[:portfolio__id] = params[:portfolio_id]
      session[:property__id] = ""
    else
      session[:portfolio__id] = ""
      session[:property__id] = params[:property_id]
    end
  end

  def find_financial_info_for_portfolio_property
    @actual = false
    @actual1= false
    calc_for_financial_data_display
    if params[:option].present? || params[:option_part].present? || params[:month].present? || params[:year].present?
      if params[:option] == "4" || params[:option_part] == "4"
        params[:tl_period] = "4"
        store_income_and_cash_flow_statement
      elsif (params[:option] == "5" || params[:option_part] == "5" )
      if params[:month].to_i == @financial_month && params[:year].to_i == @financial_year
          params[:tl_period] = "5"
          params[:tl_year] = params[:year].to_i if  params[:year].present?
          store_income_and_cash_flow_statement_for_month(month_val=nil,year=nil)
        else
          params[:tl_period] = "10"
          params[:tl_month] = params[:month].to_i if params[:month].present?
          params[:tl_year] = params[:year].to_i if  params[:year].present?
          store_income_and_cash_flow_statement_for_month(params[:tl_month],params[:tl_year])
        end
      elsif params[:option] == "3" || params[:option_part] == "3"
        params[:tl_year] =   params[:year].present? ? params[:year].to_i  : Date.today.year.to_i
        params[:tl_period] =  params[:tl_year].to_i < Date.today.year ? "3" : "8"
        store_income_and_cash_flow_statement_for_prev_year
      elsif params[:option] == "2" || params[:option_part] == "2"
        params[:tl_period] = "2"
        params[:tl_year] = params[:year].to_i
        params[:quarter_end_month] = params[:quarter] == "1" ? "3" : params[:quarter] == "2" ?  "6" : params[:quarter] == "3" ? "9" : params[:quarter] == "4" ? "12" :  (Time.now.beginning_of_quarter - 1).strftime("%m")
        store_income_and_cash_flow_statement
      elsif params[:option] == "11" || params[:option_part] == "11"
        params[:tl_period] = "11"
        params[:tl_year] = params[:year].to_i
        store_income_and_cash_flow_statement
      end
    else
      @actual = true
      @actual1 =true
    end

    if request.xhr?
      render :update do |page|
        find_month_options_values
        params[:portfolio_id] = params[:portfolio_id] && params[:portfolio_id].include?('review') ? params[:portfolio_id].split('?') [0] : params[:portfolio_id]
        if params[:portfolio_id].present?  && !params[:property_id].present?
          @note = Portfolio.find_by_id(params[:portfolio_id])
          @resource = "'Portfolio'"
        end
        portfolio = Portfolio.find_by_id(params[:portfolio_id])
	      property_id = params[:property_id].present? && params[:property_id].include?('review') ? params[:property_id].split('?') [0] : params[:property_id].present? ? params[:property_id] : portfolio.try(:real_estate_properties).try(:first).try(:id)   
#added for explanation#        
      if params[:property_id].present? && params[:property_id].include?("from_performance_review")  || (params[:from_performance_review].present? && (params[:from_performance_review].eql?('true') || params[:from_performance_review].include?("from_performance_review"))) || (params[:portfolio_id].present? && params[:portfolio_id].include?("from_performance_review"))
      params[:option] = params[:option].present? ? params[:option] : "4"
        if params[:option] == "4" 
            params[:tl_period] = "4"
            store_income_and_cash_flow_statement
        end
      end      
        if params[:option].present? || (params[:option].present? && params[:tl_month].present?)
          page.replace_html "actual_budget_item",  :partial=> "/dashboard/actual_budget_comparison",:locals=>{:note_collection=>@note,:operating_statement => @operating_statement,:expense_title=>@expense_title,:portfolio_obj=>params[:portfolio_id],:property_obj=>property_id,:month_string=>@month_string,:year_string=>@year_string,:quarter_string=>@quarter_string,:financial_month=>@financial_month,:financial_year=>@financial_year}
        elsif params[:option_part].present? || (params[:option_part].present? && params[:tl_month].present?)
          page.replace_html "actual_budget_item_part",  :partial=> "/dashboard/actual_budget_comparison_part",:locals=>{:note_collection=>@note,:operating_statement => @operating_statement,:expense_title=>@expense_title,:portfolio_obj=>params[:portfolio_id],:property_obj=>property_id,:month_string=>@month_string,:year_string=>@year_string,:quarter_string=>@quarter_string,:financial_month=>@financial_month,:financial_year=>@financial_year}
        end
      end
    end
  end

  def check_property_access
    #~ params.delete_if{|key,value| key.eql?("access") || key.eql?("port_access")}
    id = params[:property_id].present? ? params[:property_id] : params[:nid].present? ? params[:nid] : params[:id].present? ? params[:id] : @property.present? ? @property.try(:id) : @note.present? ? @note.id : ""

    if id.present? #&& !params[:access].present? #&& !params[:port_access].present?
      properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(current_user.id,prop_folder=true)
      if params[:access].present?
        id = properties.try(:last).try(:id)
        session[:property__id]= id
        session[:portfolio__id] = ""
      end

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

  def check_portfolio_access
     #~ params.delete_if{|key,value| key.eql?("access") || key.eql?("port_access")}

    if (params[:portfolio_id].present? && params[:property_id].blank?) #|| params[:portfolio_id].present? && params[:property_id].present? #&& !params[:port_access].present? # && params[:property_id].blank?)
      id = params[:real_estate_id].present? ? params[:real_estate_id] : params[:portfolio_id].present? ? params[:portfolio_id] : params[:pid].present? ? params[:pid] : @portfolio.present? ? @portfolio.try(:id) : ""
      if id.present?
        portfolios = Portfolio.find_portfolios(current_user)
        @portfolio_ids = portfolios.present? ? portfolios.map(&:id) : []
       unless @portfolio_ids.include?(id.to_i)
        properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(current_user.id,prop_folder=true)
        last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
        if last_portfolio.present? && first_property.present?
          redirect_to financial_info_path(last_portfolio.try(:id), first_property.try(:id),:port_access=>'true')
        elsif properties.present?
          redirect_to financial_info_path(properties.last.try(:portfolio_id), properties.last.try(:id),:port_access=>'true')
        else
          redirect_to notify_admin_path(:from_session=> true)
        end
      end

      end
  end
end

def find_property_users_and_send_mail_for_exec_summary(property,exec_summary,variable)
  @property_users = User.find_users_of_a_property(property) #.map(&:email)
  @property_users.each do |property_user|
    UserMailer.delay.send_mail_to_property_users_after_create_or_update_executive_summary(property_user,exec_summary,variable)
  end
end

def find_property_users_and_send_mail_for_comments(property,exec_summary,comment,variable)
  @property_users = User.find_users_of_a_property(property) #.map(&:email)
  @property_users.each do |property_user|
    UserMailer.delay.send_mail_to_property_users_after_create_or_update_comments_on_exec_summary(property_user,exec_summary,comment,variable)
  end
end

def dashboard_graphs
  trend_graph = params[:trend_graph].eql?('true') ? true : nil
  @real_estate_property = RealEstateProperty.find_real_estate_property(session[:property__id]) if session[:property__id].present?
  params[:parent_title] = 'income' if params[:parent_title].blank?
  @parent_title = params[:parent_title].include?('review') ? params[:parent_title].split('?')[0] : params[:parent_title]
  if params[:trend_graph].eql?('true')
    params[:tl_year] = params[:tl_period].eql?("3") ? Date.today.prev_year.year : Date.today.year
    find_financial_sub_items("Operating Revenue")
    @financial_sub_id  = params[:financial_subid]
    @financial_sub  = params[:financial_sub]
    if params[:selected_link].present?
      params[:selected_link] = params[:selected_link].include?('review') ? params[:selected_link].split('?')[0] : params[:selected_link]
      tmp_period = params[:tl_period]
      tmp_year = params[:tl_year]
      params[:tl_period] = "3"
      #      previous year details start
      params[:tl_year] = Date.today.prev_year.year
      find_financial_sub_items(map_title(params[:selected_link].strip))
      @last_year_financial_sub_id = params[:financial_subid]
      @last_year_financial_sub = params[:financial_sub]
      #      prev_year details ends
      #      prev_year's prev_year  details starts
      params[:tl_year] = Date.today.prev_year.prev_year.year
      find_financial_sub_items(map_title(params[:selected_link].strip))
      @second_last_year_financial_sub_id = params[:financial_subid]
      @second_last_year_financial_sub = params[:financial_sub]
      #      prev_year's prev_year  details ends
      params[:tl_period] = tmp_period
      params[:tl_year] = tmp_year
      find_financial_sub_items(map_title(params[:selected_link].strip))
      @financial_sub_id = params[:financial_subid]
      @financial_sub = params[:financial_sub]
    end
    trend_operating_trend_graph
  else
    find_data_for_operating_trend
  end
  find_data_for_noi_variances
  first_two_digit_year=Time.now.year.to_s.first(2)
  financial_ytd_occupancy_display if params[:tl_period] != "3"
  calc_for_financial_data_display
  if params[:tl_period] == "4" || params[:tl_period] == "11"
    store_income_and_cash_flow_statement
  elsif params[:tl_period] == "3"
    params[:tl_year] =Date.today.prev_year.year
    store_income_and_cash_flow_statement_for_prev_year
  end
  if trend_graph.present?
    if request.xhr?
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html "trend_sub",  :partial=> "/dashboard/trend_grouping",:locals=>{:operating_trend_rev =>@operating_trend['op rev'], :operating_trend_exp=>@operating_trend["operating expenses"],:operating_trend_noi=>@operating_trend['noi'],:operating_trend_cap=>@operating_trend['capital expenditures'],:operating_trend_cash => @operating_trend['net cash flow'] , :operating_trend_maint => @operating_trend['maintenance projects'],:month_array=>@month_array,:month_array_string=>@month_array_string,:financial_month=>@financial_month,:graph_property_id=>params[:property_id],:graph_portfolio_id=>params[:portfolio_id],:first_two_digit_year=>first_two_digit_year,:property_id=>params[:property_id],:value_noi =>@value_noi,:month_array_noi=>@month_array_noi,:positive_variance=>@positive_variance,:negative_variance=>@negative_variance,:rent_sqft => @rent_sqft,:occupied_percentage => @occupied_percentage,:sqft_variance => @sqft_variance,:sqft_var_percent => @sqft_var_percent,:diff => @diff,:operating_statement =>@operating_statement,:note => @note,:trend_graph => trend_graph,:operating_trend_graph => @operating_trend,:operating_trend_graph1 => @operating_trend1,:sqft_var_percent_check => @sqft_var_percent_check}
          end
        }
      end
    end
    #    render :partial => "dashboard_graphs",:locals=>{:operating_trend_rev =>@operating_trend['op rev'], :operating_trend_exp=>@operating_trend["operating expenses"],:operating_trend_noi=>@operating_trend['noi'],:operating_trend_cap=>@operating_trend['capital expenditures'],:operating_trend_cash => @operating_trend['net cash flow'] , :operating_trend_maint => @operating_trend['maintenance projects'],:month_array=>@month_array,:month_array_string=>@month_array_string,:financial_month=>@financial_month,:graph_property_id=>params[:property_id],:graph_portfolio_id=>params[:portfolio_id],:first_two_digit_year=>first_two_digit_year,:property_id=>params[:property_id],:value_noi =>@value_noi,:month_array_noi=>@month_array_noi,:positive_variance=>@positive_variance,:negative_variance=>@negative_variance,:rent_sqft => @rent_sqft,:occupied_percentage => @occupied_percentage,:sqft_variance => @sqft_variance,:sqft_var_percent => @sqft_var_percent,:diff => @diff,:operating_statement =>@operating_statement,:note => @note,:trend_graph => trend_graph,:operating_trend_graph => @operating_trend,:operating_trend_graph1 => @operating_trend1}
  else
    render :partial => "dashboard_graphs",:locals=>{:operating_trend_rev =>@operating_trend['op rev'], :operating_trend_exp=>@operating_trend["operating expenses"],:operating_trend_noi=>@operating_trend['noi'],:operating_trend_cap=>@operating_trend['capital expenditures'],:operating_trend_cash => @operating_trend['net cash flow'] , :operating_trend_maint => @operating_trend['maintenance projects'],:month_array=>@month_array,:month_array_string=>@month_array_string,:financial_month=>@financial_month,:graph_property_id=>params[:property_id],:graph_portfolio_id=>params[:portfolio_id],:first_two_digit_year=>first_two_digit_year,:property_id=>params[:property_id],:value_noi =>@value_noi,:month_array_noi=>@month_array_noi,:positive_variance=>@positive_variance,:negative_variance=>@negative_variance,:rent_sqft => @rent_sqft,:occupied_percentage => @occupied_percentage,:sqft_variance => @sqft_variance,:sqft_var_percent => @sqft_var_percent,:diff => @diff,:operating_statement =>@operating_statement,:note => @note,:sqft_var_percent_check => @sqft_var_percent_check}
  end
end

def exec_summary_for_leasing_info
  if request.xhr?
      comments_for_exec_summary_ajax
  else
     exec_summary_create_or_update
  end
end


def comments_for_exec_summary_ajax
    if session[:portfolio__id].present?
      @portfolio  =  Portfolio.find_by_id(params[:portfolio_id])
      @page = @portfolio.try(:assets).where(:month=>params[:month], :year=>params[:year]).first
    else
      @property  =  RealEstateProperty.find_by_id(params[:property_id])
      @page = @property.try(:assets).where(:month=>params[:month], :year=>params[:year]).first
    end
      if params[:form_comments]
        if @page.present?
          @comment = @page.comments.create(params[:comment])
          find_property_users_and_send_mail_for_comments(@property,@page,@comment,'create')
        end
      elsif params[:form_edit]
        @comment = Comment.find_by_id(params[:comment][:id])
        @comment.update_attributes(params[:comment])
        find_property_users_and_send_mail_for_comments(@property,@page,@comment,'update')
      elsif params[:from_delete_comment]
        @comment = Comment.find_by_id(params[:comment_id])
        @comment = @comment.delete
        find_property_users_and_send_mail_for_comments(@property,@page,@comment,'delete')
      end

      @comments = @page.try(:comments)
      if @page.nil?
        @page = @property.present? ? @property.try(:assets).build : @portfolio.try(:assets).build
      end
      @comment = @page.comments.build
      @last_updated_user = User.find_by_id(@page.try(:user_id))


            render :update do |page|
              page.replace_html  "comments_div", :partial => "/dashboard/comments_form", :locals => {:comments => @comments,:page=>@page}
              if params[:from_exec_summary]
                if @page.try(:notes).nil?
                  page << "jQuery('iframe').contents().find('.cke_show_borders').html(''); jQuery('#textarea_div').html('Click here to Enter Executive Summary');"
                  page << "jQuery('.aEXM').hide();"
                  page << "jQuery('#comments_exec_id').hide();"
                else
                  exec_summary_var = (@page.try(:month) < 9) ? ("0#{@page.try(:month)}" +'/'+"#{@page.try(:year)}") : ("#{@page.try(:month)}"+'/'+"#{@page.try(:year)}")
                  page.call "comments_replacement_in_exec_summary" ,"#{@page.try(:notes)}" ,"#{@last_updated_user.try(:name).titleize}","#{@page.updated_at.strftime('%m/%d/%Y')}","#{@page.updated_at.strftime('%I:%M%p')}", "#{exec_summary_var}"
                end
              end

            end
          end

  def exec_summary_create_or_update
      if session[:portfolio__id].present?  && !session[:property__id].present?
        @note = Portfolio.find_by_id(session[:portfolio__id])
        @resource = "'Portfolio'"
      else
        @real_estate_property = RealEstateProperty.find_real_estate_property(session[:property__id]) if session[:property__id].present?
        @real_property  =  RealEstateProperty.find_by_id(session[:property__id]) if session[:property__id].present?
        @note = @real_estate_property || @real_property
        @resource = "'RealEstateProperty'"
      end
      
      if @note.try(:assets).present?
        calc_for_financial_data_display
        if params[:page].present?
          @page = @note.try(:assets).where(:month=>params[:page][:month], :year=>params[:page][:year]).first
          @comments = @page.try(:comments)
        elsif params[:month].present? && params[:year].present?
          @page = @note.try(:assets).where(:month=>params[:month], :year=>params[:year]).first
          @comments = @page.try(:comments)
        else
          @page = @note.try(:assets).where(:month=>@financial_month, :year=>@financial_year).first
          @comments = @page.try(:comments)
        end
        if params[:page].present?
          if @page.present?
          @page.update_attributes(:user_id => params[:page][:user_id], :notes=>params[:page][:notes],:month=>params[:page][:month],:year=>params[:page][:year])
          find_property_users_and_send_mail_for_exec_summary(@note,@page,'update')
          else
            @page = @note.assets.create(params[:page])
            find_property_users_and_send_mail_for_exec_summary(@note,@page,'create')
          end
          if params[:action].eql?("financial_info")
            
            if session[:portfolio__id].present?  && !session[:property__id].present?
              redirect_to portfolio_financial_info_path(:portfolio_id=>params[:portfolio_id],:ckeditor=>true,:month=>params[:page][:month],:year=>params[:page][:year])
            else
              redirect_to financial_info_path(:property_id=>params[:property_id] , :portfolio_id=>params[:portfolio_id],:ckeditor=>true,:month=>params[:page][:month],:year=>params[:page][:year])
            end
            
          elsif params[:action].eql?("property_commercial_leasing_info")
            redirect_to property_commercial_leasing_info_path(:property_id=>params[:property_id] , :portfolio_id=>params[:portfolio_id],:ckeditor=>true,:month=>params[:page][:month],:year=>params[:page][:year])
          elsif params[:action].eql?("property_multifamily_leasing_info")
            redirect_to property_multifamily_leasing_info_path(:property_id=>params[:property_id] , :portfolio_id=>params[:portfolio_id],:ckeditor=>true,:month=>params[:page][:month],:year=>params[:page][:year])
          end
        end
        @last_updated_user = User.find_by_id(@page.try(:user_id))
      else
        @page = @note.assets.build
      end
      if params[:page].present? && @page && @page.new_record?
        if session[:portfolio__id].present?  && !session[:property__id].present?
          @portfolio  =  Portfolio.find_by_id(params[:portfolio_id].to_i) if params[:portfolio_id].present?
          @page = @portfolio.assets.create(params[:page])
        else  
          @property  =  RealEstateProperty.find_by_id(params[:property_id].to_i) if params[:property_id].present?
          @page = @property.assets.create(params[:page])
        end
        
        find_property_users_and_send_mail_for_exec_summary(@note,@page,'create')
        if params[:action].eql?("financial_info")           
           
          if session[:portfolio__id].present?  && !session[:property__id].present?
            redirect_to portfolio_financial_info_path(:portfolio_id=>params[:portfolio_id],:ckeditor=>true,:month=>params[:page][:month],:year=>params[:page][:year])
          else
            redirect_to financial_info_path(:property_id=>params[:property_id] , :portfolio_id=>params[:portfolio_id],:ckeditor=>true,:month=>params[:page][:month],:year=>params[:page][:year])
          end
           
        elsif params[:action].eql?("property_commercial_leasing_info")
          redirect_to property_commercial_leasing_info_path(:property_id=>params[:property_id] , :portfolio_id=>params[:portfolio_id],:ckeditor=>true,:month=>params[:page][:month],:year=>params[:page][:year])
        elsif params[:action].eql?("property_multifamily_leasing_info")
          redirect_to property_multifamily_leasing_info_path(:property_id=>params[:property_id] , :portfolio_id=>params[:portfolio_id],:ckeditor=>true,:month=>params[:page][:month],:year=>params[:page][:year])
        end
      end

      if @page.nil?
      @page = @note.try(:assets).build
    end
      @comment = @page.comments.build
  end

  def performance_analysis_trends
    @financial_sub = params[:financial_sub].include?('review') ? params[:financial_sub].split('?')[0].strip : params[:financial_sub].strip
    @financial_sub_id = params[:financial_subid].include?('review') ?  params[:financial_subid].split('?')[0] :  params[:financial_subid]
    @parent_title = params[:parent_title].include?('review') ? params[:parent_title].split('?')[0] : params[:parent_title]
    find_dashboard_portfolio_display
    render :update do |page|
      if params[:type].eql?('performance')
        page.replace_html "performance_analysis",  :partial=> "/dashboard/performance_analysis"
      else
        page.replace_html "performance_analysis",  :partial=> "/dashboard/year_on_year_growth"
      end
    end
  end
end
