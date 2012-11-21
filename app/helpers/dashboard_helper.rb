module DashboardHelper

  #method to find dashboard-financial ytd-occupancy info#
  def financial_ytd_occupancy_display
    if @note.try(:class).eql?(Portfolio)
      find_ytd_portfolio_occupancy
      #common to find the YTD Occupancy for both commercial and multifamily portfolios#
      if @occupancy.to_a.present? && @occupancy[0].present?
        @diff = @occupancy[0].current_year_sf_occupied_actual.to_f - @occupancy[0].current_year_sf_occupied_budget.to_f
        @sqft_variance = number_with_delimiter((@occupancy[0].current_year_sf_occupied_budget.to_f - @occupancy[0].current_year_sf_occupied_actual.to_f).abs.round)
        sqft_var_percent = (@occupancy[0].current_year_sf_occupied_budget.present? && @occupancy[0].current_year_sf_occupied_budget.to_f != 0.0) ? (@sqft_variance.to_f * 100) / @occupancy[0].current_year_sf_occupied_budget.to_f : 0
        @sqft_var_percent = number_with_precision(sqft_var_percent, :precision=>1)
        @sqft_var_percent_check = @occupancy[0].current_year_sf_occupied_budget.present? ? true : false
      end
    elsif @real_estate_property.present? && @real_estate_property.try(:class).eql?(RealEstateProperty)
      find_ytd_property_occupancy
      #common to find the YTD Occupancy for both commercial and multifamily properties#
      occupancy_var = @occupancy[0] if !@occupancy.nil? and !@occupancy.empty?
      if occupancy_var.present?
        @diff =occupancy_var.current_year_sf_occupied_actual.to_f - occupancy_var.current_year_sf_occupied_budget.to_f
        @sqft_variance = number_with_delimiter((occupancy_var.current_year_sf_occupied_budget.to_f - occupancy_var.current_year_sf_occupied_actual.to_f).abs.round)
        sqft_var_percent = (occupancy_var.current_year_sf_occupied_budget.present? && occupancy_var.current_year_sf_occupied_budget.to_f != 0.0) ? (@sqft_variance.to_f * 100) / occupancy_var.current_year_sf_occupied_budget.to_f : 0
        @sqft_var_percent = number_with_precision(sqft_var_percent, :precision=>1)
        @sqft_var_percent_check = occupancy_var.current_year_sf_occupied_budget.present? ? true : false
      end
    end
  end

  def find_ytd_portfolio_occupancy
    property_ids = find_properties(@note.id,current_user.id)
    if @note.leasing_type == "Commercial" && property_ids.present?
      if params[:tl_period]  == "3"
          @suites = Suite.find(:all, :conditions=>['real_estate_property_id IN (?)', property_ids.collect{|x|x.id}]).map(&:id)
          year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year <= ?',@suites,Date.today.prev_year.year],:select=>"year",:order=>"year desc",:limit=>1) if @suites.present?
          year= year && year[0] ? year[0].year.to_i : nil
          month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ?',@suites,year.to_i,get_month(year)],:select=>"month").map(&:month).max if @suites.present?
          occupied_sf = LeaseRentRoll.find_by_sql("select sum(lr.sqft) as occupied from lease_rent_rolls lr where lr.real_estate_property_id IN (#{property_ids.collect{|x|x.id}.split(',').join(',')}) and lr.tenant not like '%vacant%' and lr.month = #{month} and lr.year = #{year}") if month.present? && year.present?
          total_sf = LeaseRentRoll.find_by_sql("select sum(lr.sqft) as occupied from lease_rent_rolls lr where lr.real_estate_property_id IN (#{property_ids.collect{|x|x.id}.split(',').join(',')} ) and lr.month = #{month} and lr.year = #{year}") if month.present? && year.present?
          rent_sqft = occupied_sf[0].occupied if occupied_sf.present?
          @rent_sqft=number_with_delimiter(rent_sqft.to_f.round)
          percentage = (total_sf.present? && total_sf!= 0.0) ? (occupied_sf[0].occupied.to_f * 100 ) / total_sf[0].occupied.to_f : 0
          @occupied_percentage = number_with_precision(percentage, :precision=>2)
           year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id IN (?) and year <= ?',property_ids.collect{|x|x.id},Date.today.prev_year.year],:select=>"year",:order=>"year desc",:limit=>1)
          year = year.compact.empty? ? nil : year[0].year
          @occupancy = year.present? ? CommercialLeaseOccupancy.where("real_estate_property_id IN (#{property_ids.collect{|x|x.id}.split(',').join(',')}) and year = #{year} and month <= #{get_month(year)}").order("month desc").select("sum(current_year_sf_occupied_actual) as current_year_sf_occupied_actual  , sum(current_year_sf_occupied_budget) as current_year_sf_occupied_budget") : []
      elsif (params[:tl_period] == "4" || params[:tl_period] == "11")
          occupied_sqft_percent_calc_for_portfolio(property_ids)
          find_occupancy_values
          year_value = Date.today.year
          year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id IN (?) and year <= ?',property_ids.collect{|x|x.id},year_value],:select=>"year",:order=>"year desc",:limit=>1)
          year = year.compact.empty? ? nil : year[0].year
          @occupancy = year.present? ? CommercialLeaseOccupancy.where("real_estate_property_id IN (#{property_ids.collect{|x|x.id}.split(',').join(',')}) and year = #{year} and month <= #{get_month(year)}").order("month desc").select("sum(current_year_sf_occupied_actual) as current_year_sf_occupied_actual  , sum(current_year_sf_occupied_budget) as current_year_sf_occupied_budget") : []  #.group("portfolios_real_estate_properties.portfolio_id")
      end
    elsif @note.leasing_type == "Multifamily"
      year_value =  params[:tl_period]  == "3" ? Date.today.prev_year.year :  Date.today.year
      @suites = PropertySuite.find(:all, :conditions=>['real_estate_property_id IN (?)', property_ids.collect{|x|x.id}]).map(&:id)
      year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year <= ?',@suites,year_value],:select=>"year",:order=>"year desc",:limit=>1) if @suites.present?
      year= year && year[0] ? year[0].year.to_i : nil
      month = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year = ? and month <= ?',@suites,year.to_i,get_month(year)],:select=>"month").map(&:month).max if @suites.present?
      occupied_sf = PropertyLease.find_by_sql("select sum(ps.rented_area) as occupied from property_suites ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id IN (#{property_ids.collect{|x|x.id}.split(',').join(',')}) and pl.tenant not like '%vacant%' and pl.month = #{month} and pl.year = #{year}") if month.present? && year.present?
      total_sf = PropertyLease.find_by_sql("select sum(ps.rented_area) as occupied from property_suites ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id IN (#{property_ids.collect{|x|x.id}.split(',').join(',')}) and pl.month = #{month} and pl.year = #{year}") if month.present? && year.present?
      rent_sqft = occupied_sf[0].occupied if occupied_sf.present?
      @rent_sqft=number_with_delimiter(rent_sqft.to_f.round)
      percentage = (total_sf.present? && total_sf!= 0.0) ? (occupied_sf[0].occupied.to_f * 100 ) / total_sf[0].occupied.to_f : 0
      @occupied_percentage = number_with_precision(percentage, :precision=>2)
      year_value =  params[:tl_period]  == "3" ? Date.today.prev_year.year :  Date.today.year
      year = PropertyOccupancySummary.find(:all, :conditions=>['real_estate_property_id IN (?) and year <= ?',property_ids.collect{|x|x.id},year_value ],:select=>"year",:order=>"year desc",:limit=>1)
      year = year.compact.empty? ? nil : year[0].year
      @occupancy= year.present? ? PropertyOccupancySummary.where("real_estate_property_id IN (#{property_ids.collect{|x|x.id}.split(',').join(',')}) and year = #{year} and month <= #{get_month(year)}").order("month desc").select("sum(current_year_sf_occupied_actual) as current_year_sf_occupied_actual  , sum(current_year_sf_occupied_budget) as current_year_sf_occupied_budget") : [] #.group("portfolios_real_estate_properties.portfolio_id")
    end
  end

  def occupied_sqft_percent_calc_for_portfolio(property_ids)
    suite_c = Suite.where("suite_no is not null and real_estate_property_id IN (?) and status =?",property_ids.collect{|x|x.id},'Occupied')
    suite_properties = Suite.where("suite_no is not null and real_estate_property_id IN (?)",property_ids.collect{|x|x.id})
    occupied_rentable_sqft = suite_c.sum(:rentable_sqft)
    suite_all_sqft = suite_properties.sum(:rentable_sqft)
    percentagee = (suite_all_sqft.present? && suite_all_sqft!= 0.0) ? (occupied_rentable_sqft * 100 ) / suite_all_sqft : 0
    #For pipeline header display#
    @occupied_percentage = "#{number_with_precision(percentagee, :precision=>2)}"
    @rent_sqft = number_with_delimiter(occupied_rentable_sqft.round)
    return  @rent_sqft,@occupied_percentage
  end

  def find_ytd_property_occupancy
    if is_commercial(@real_estate_property) #For Commercial Properties#
      occupied_sqft_percent_calc(@real_estate_property.id)
      @note = @real_estate_property
      find_occupancy_values
        if params[:tl_period]  == "3"
          @suites = Suite.find(:all, :conditions=>['real_estate_property_id = ?', @real_estate_property.id]).map(&:id) if !@real_estate_property.nil?
          year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year <= ?',@suites,Date.today.prev_year.year],:select=>"year",:order=>"year desc",:limit=>1) if @suites.present?
          year= year && year[0] ? year[0].year.to_i : nil
          month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ?',@suites,year.to_i,get_month(year)],:select=>"month").map(&:month).max if @suites.present?
          occupied_sf = LeaseRentRoll.find_by_sql("select sum(lr.sqft) as occupied from lease_rent_rolls lr where lr.real_estate_property_id = #{@real_estate_property.id} and lr.tenant not like '%vacant%' and lr.month = #{month} and lr.year = #{year}") if month.present? && year.present?
          total_sf = LeaseRentRoll.find_by_sql("select sum(lr.sqft) as occupied from lease_rent_rolls lr where lr.real_estate_property_id = #{@real_estate_property.id} and lr.month = #{month} and lr.year = #{year}") if month.present? && year.present?
          rent_sqft = occupied_sf[0].occupied if occupied_sf.present?
          @rent_sqft=number_with_delimiter(rent_sqft.to_f.round)
          percentage = (total_sf.present? && total_sf!= 0.0) ? (occupied_sf[0].occupied.to_f * 100 ) / total_sf[0].occupied.to_f : 0
          @occupied_percentage = number_with_precision(percentage, :precision=>2)
          year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@real_estate_property.id,Date.today.prev_year.year],:select=>"year",:order=>"year desc",:limit=>1)
          year = year.compact.empty? ? nil : year[0].year
          @occupancy = year.present? ? CommercialLeaseOccupancy.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@real_estate_property.id,year,get_month(year)],:order => "month desc",:limit =>1) : []
        elsif (params[:tl_period] == "4" || params[:tl_period] == "11")
          year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@real_estate_property.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
          year = year.compact.empty? ? nil : year[0].year
          @occupancy = year.present? ? CommercialLeaseOccupancy.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@real_estate_property.id,year,get_month(year)],:order => "month desc",:limit =>1) : []
        end
    elsif is_multifamily(@real_estate_property) #For Multifamily Properties#
      year_value =  params[:tl_period]  == "3" ? Date.today.prev_year.year :  Date.today.year
      @suites = PropertySuite.find(:all, :conditions=>['real_estate_property_id = ?', @real_estate_property.id]).map(&:id) if !@real_estate_property.nil?
      year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year <= ?',@suites,year_value],:select=>"year",:order=>"year desc",:limit=>1) if @suites.present?
      year= year && year[0] ? year[0].year.to_i : nil
      month = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year = ? and month <= ?',@suites,year.to_i,get_month(year)],:select=>"month").map(&:month).max if @suites.present?
      occupied_sf = PropertyLease.find_by_sql("select sum(ps.rented_area) as occupied from property_suites ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id = #{@real_estate_property.id} and pl.tenant not like '%vacant%' and pl.month = #{month} and pl.year = #{year}") if month.present? && year.present?
      total_sf = PropertyLease.find_by_sql("select sum(ps.rented_area) as occupied from property_suites ps left join property_leases pl on pl.property_suite_id = ps.id  where ps.real_estate_property_id = #{@real_estate_property.id} and pl.month = #{month} and pl.year = #{year}") if month.present? && year.present?
      rent_sqft = occupied_sf[0].occupied if occupied_sf.present?
      @rent_sqft= "#{number_with_delimiter(rent_sqft.to_f.round)} SF"
      percentage = (total_sf.present? && total_sf!= 0.0) ? (occupied_sf[0].occupied.to_f * 100 ) / total_sf[0].occupied.to_f : 0
      @occupied_percentage = number_with_precision(percentage, :precision=>2)
      year = PropertyOccupancySummary.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',@real_estate_property.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
      year = year.compact.empty? ? nil : year[0].year
      @occupancy= year.present? ? PropertyOccupancySummary.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",@real_estate_property.id,year,get_month(year)],:order => "month desc",:limit =>1) : []
    end
  end

  def get_property_type_display(property_id)
    return RealEstateProperty.find_by_id(property_id).try(:leasing_type)
  end

  def get_portfolio_type_display(portfolio_id)
    return Portfolio.find_by_id(portfolio_id).try(:leasing_type)
  end

  def find_data_for_operating_trend
    if session[:portfolio__id].present?  && !session[:property__id].present?
      @note = Portfolio.find_by_id(session[:portfolio__id])
      @resource = "'Portfolio'"
    else
      @note = RealEstateProperty.find_real_estate_property(session[:property__id]) if session[:property__id].present?
      @resource = "'RealEstateProperty'"
    end
    if params[:tl_period] == "4" ||  params[:tl_period] == "3"
      find_data_display_for_ytd_and_prev_year
    elsif params[:tl_period] == "11"
      find_trailing_data_display
    end
  end

  def find_data_display_for_ytd_and_prev_year
    calc_for_financial_data_display
    params[:tl_year] = params[:tl_period] == "4" ? @financial_year : Date.today.prev_year.year
    @month =[]
    @month_array,@month_array_string = [],[]
    months = ["","january","february","march","april","may","june","july","august","september","october","november","december"]
    month_string = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    if params[:tl_period] == "4"
      for i in 1..@financial_month.to_i do
        @month << "sum(" + "f."+ "#{months[i]}" + ")" + "as" + " '#{month_string[i]}'"
        @month_array << month_string[i]
        @month_array_string << month_string[i]+'-'+Date.today.strftime('%y')
      end
    elsif  params[:tl_period] == "3"
      for i in 1..12 do
        @month << "sum(" + "f."+ "#{months[i]}" + ")" + "as" + " '#{month_string[i]}'"
        @month_array << month_string[i]
        @month_array_string << month_string[i]+'-'+Date.today.prev_year.strftime('%y')
      end
    end
    financial_title = find_financial_title
    qry1 =   "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(a.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{params[:tl_year]} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title" if @month.present? && @note.present?
    asset_details = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present?
    @operating_trend = {}
    if asset_details.present?
      for cash_row in asset_details
        if cash_row.Title	!= nil
          @operating_trend[cash_row.Title] =  form_hash_of_data_values(cash_row)
        end
      end
    end
    title_rev=map_title("Operating Revenue")
    title_noi=map_title("NOI")
    title_net = map_title("net cash flow")
    title_exp = map_title("operating expenses")
    @operating_trend['net cash flow'] = @operating_trend[title_net].present? ? @operating_trend[title_net] : ""
    @operating_trend['noi'] = @operating_trend[title_noi].present? ? @operating_trend[title_noi] : ""
    @operating_trend['op rev'] = @operating_trend[title_rev].present?  ? @operating_trend[title_rev] : ""
    @operating_trend['operating expenses'] = @operating_trend['operating expenses'].present?  ? @operating_trend['operating expenses'] : ""
    @operating_trend['capital expenditures'] = @operating_trend['capital expenditures'].present?  ? @operating_trend['capital expenditures'] : ""
    @operating_trend['maintenance projects'] = @operating_trend['maintenance projects'].present? ? @operating_trend['maintenance projects'] : ""
    if (@operating_trend['recoverable expenses detail'].present? || @operating_trend['non-recoverable expenses detail'].present?)
      @operating_trend['recoverable expenses detail'] = @operating_trend['recoverable expenses detail'].present? ? @operating_trend['recoverable expenses detail'] : ""
      @operating_trend['non-recoverable expenses detail'] = @operating_trend['non-recoverable expenses detail'].present? ? @operating_trend['non-recoverable expenses detail'] : ""
      @operating_trend['operating expenses'] = (@operating_trend['recoverable expenses detail'].present? && @operating_trend['non-recoverable expenses detail'].present?) ? @operating_trend['recoverable expenses detail'].merge(@operating_trend['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend['recoverable expenses detail'].present? ? @operating_trend['recoverable expenses detail']  : @operating_trend['non-recoverable expenses detail'].present? ?  @operating_trend['non-recoverable expenses detail'] : ""
    end
  end


  def find_trailing_data_display
    months = ["","january","february","march","april","may","june","july","august","september","october","november","december"]
    month_string = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    @month_array,@month_array_string = [],[]
    @operating_trend = {}
    @month = {}
    @month_val = {}
    month_val = []
    month_name = []
    calc_for_financial_data_display
    cur_year_days = Date.leap?(DateTime.now .year) ? 366 : 365
    for i in  (@month_format - cur_year_days).month..12 do
      @month_array << month_string[i]
      @month_array_string << month_string[i]+'-'+Date.today.prev_year.strftime('%y')
      month_val << "sum(" + "f."+ "#{months[i]}" + ")" + "as" + " '#{month_string[i]}'"
      @month = {(@month_format - cur_year_days).year =>  month_val.uniq }
      if i == 12
        for j in 1..@financial_month.to_i do
          @month_array << month_string[j]
          @month_array_string << month_string[j]+'-'+Date.today.strftime('%y')
          month_name << "sum("+ "f."+ "#{months[j] }" +")" + "as" + " '#{month_string[j] }'"
          @month_val = {Date.today.year =>  month_name.uniq}

        end
      end
    end
    @operating_trend_budget,@operating_trend_budget1 = {},{}
    financial_title = params[:trend_graph].present? ? '"Operating Revenue"' : find_financial_title
    if params[:trend_graph].present?
      #      string = "a.parent_id"
      @operating_trend,@operating_trend1 = {},{}
      parent = params[:financial_subid]
      last_year_parent = @last_year_financial_sub_id
      year = Date.today.year
      if @financial_sub.eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
        #       financial_title = "'recoverable expenses detail','non-recoverable expenses detail'"
        financial_title = find_financial_title
        @operating_trend,@operating_trend1,@operating_trend_budget,@operating_trend_budget1 = {},{},{},{}
        qry1 =   "SELECT k.title as Parent, a.title as Title,#{@month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{year - 1} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
        asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present?
        @operating_trend3 = {}
        if asset_details1.present?
          for cash_row in asset_details1
            if cash_row.Title	!= nil
              @operating_trend3[cash_row.Title] =  form_hash_of_data_values(cash_row)
            end
          end
        end
        qry =  "SELECT k.title as Parent, a.title as Title,#{@month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
        asset_details = IncomeAndCashFlowDetail.find_by_sql(qry) if qry.present?
        @operating_trend2 = {}
        if asset_details.present?
          for cash_row in asset_details
            if cash_row.Title	!= nil
              @operating_trend2[cash_row.Title] =  form_hash_of_data_values(cash_row)
            end
          end
        end
        qry5 =   "SELECT k.title as Parent, a.title as Title,#{@month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{year - 2} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
        asset_details5 = IncomeAndCashFlowDetail.find_by_sql(qry5) if qry5.present?
        @second_last_operating_trend1 = {}
        if asset_details5.present?
          for cash_row in asset_details5
            if cash_row.Title	!= nil
              @second_last_operating_trend1[cash_row.Title] =  form_hash_of_data_values(cash_row)
            end
          end
        end
        qry4 =  "SELECT k.title as Parent, a.title as Title,#{@month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','')IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{year -1} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
        asset_details4 = IncomeAndCashFlowDetail.find_by_sql(qry) if qry.present?
        @second_last_operating_trend = {}
        if asset_details4.present?
          for cash_row in asset_details4
            if cash_row.Title	!= nil
              @second_last_operating_trend[cash_row.Title] =  form_hash_of_data_values(cash_row)
            end
          end
        end
        qry3 =   "SELECT k.title as Parent, a.title as Title,#{@month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('b') AND a.year=#{year - 1} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
        asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry3) if qry3.present?
        @operating_trend_budget3 = {}
        if asset_details1.present?
          for cash_row in asset_details1
            if cash_row.Title	!= nil
              @operating_trend_budget3[cash_row.Title] =  form_hash_of_data_values(cash_row)
            end
          end
        end
        qry2 =  "SELECT k.title as Parent, a.title as Title,#{@month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
        asset_details = IncomeAndCashFlowDetail.find_by_sql(qry2) if qry2.present?
        @operating_trend_budget2 = {}
        if asset_details.present?
          for cash_row in asset_details
            if cash_row.Title	!= nil
              @operating_trend_budget2[cash_row.Title] =  form_hash_of_data_values(cash_row)
            end
          end
        end
        title_exp = map_title("operating expenses")
        if (@operating_trend2['recoverable expenses detail'].present? || @operating_trend3['recoverable expenses detail'].present? ) || (@operating_trend2['non-recoverable expenses detail'].present? || @operating_trend3['non-recoverable expenses detail'].present?)
          @operating_trend['operating expenses'] = (@operating_trend2['recoverable expenses detail'].present? && @operating_trend2['non-recoverable expenses detail'].present?) ? @operating_trend2['recoverable expenses detail'].merge(@operating_trend2['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend2['recoverable expenses detail'].present? ? @operating_trend2['recoverable expenses detail']  : @operating_trend2['non-recoverable expenses detail'].present? ?  @operating_trend2['non-recoverable expenses detail'] : ""
          @operating_trend1['operating expenses'] = (@operating_trend3['recoverable expenses detail'].present? && @operating_trend3['non-recoverable expenses detail'].present?) ? @operating_trend3['recoverable expenses detail'].merge(@operating_trend3['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend3['recoverable expenses detail'].present? ? @operating_trend3['recoverable expenses detail']  : @operating_trend3['non-recoverable expenses detail'].present? ?  @operating_trend3['non-recoverable expenses detail'] : ""
        end
        if (@operating_trend_budget2['recoverable expenses detail'].present? || @operating_trend_budget3['recoverable expenses detail'].present? ) || (@operating_trend_budget2['non-recoverable expenses detail'].present? || @operating_trend_budget3['non-recoverable expenses detail'].present?)
          @operating_trend_budget['operating expenses'] = (@operating_trend_budget2['recoverable expenses detail'].present? && @operating_trend_budget2['non-recoverable expenses detail'].present?) ? @operating_trend_budget2['recoverable expenses detail'].merge(@operating_trend_budget2['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend_budget2['recoverable expenses detail'].present? ? @operating_trend_budget2['recoverable expenses detail']  : @operating_trend_budget2['non-recoverable expenses detail'].present? ?  @operating_trend_budget2['non-recoverable expenses detail'] : ""
          @operating_trend_budget1['operating expenses'] = (@operating_trend_budget3['recoverable expenses detail'].present? && @operating_trend_budget3['non-recoverable expenses detail'].present?) ? @operating_trend_budget3['recoverable expenses detail'].merge(@operating_trend_budget3['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend_budget3['recoverable expenses detail'].present? ? @operating_trend_budget3['recoverable expenses detail']  : @operating_trend_budget3['non-recoverable expenses detail'].present? ?  @operating_trend_budget3['non-recoverable expenses detail'] : ""
        end
      else

        #      year = params[:tl_year].present? ? params[:tl_year] : Date.today.year
        if parent.present?
          qry = "select parent_id,title from income_and_cash_flow_details where parent_id=#{parent}"
          asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
          string = (asset_details.blank? || asset_details.first.parent_id.blank?) ? "a.id" : "a.parent_id"
          qry1 =   "SELECT k.title as Parent, a.title as Title,#{@month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{parent} AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'"
          qry2 =   "SELECT k.title as Parent, a.title as Title,#{@month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{last_year_parent} AND f.pcb_type IN ('c') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'"
          qry3 =   "SELECT k.title as Parent, a.title as Title,#{@month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{parent} AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'"
          qry4 =   "SELECT k.title as Parent, a.title as Title,#{@month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{last_year_parent} AND f.pcb_type IN ('b') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'"
          asset_details = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present?
          asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry2) if qry2.present? && last_year_parent.present?
          if asset_details.present?
            for cash_row in asset_details
              @operating_trend[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
            end
          end
          if asset_details1.present?
            for cash_row in asset_details1
              @operating_trend1[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
            end
          end if last_year_parent.present?
          asset_details_budget = IncomeAndCashFlowDetail.find_by_sql(qry3) if qry3.present?
          asset_details_budget1 = IncomeAndCashFlowDetail.find_by_sql(qry4) if qry4.present? && last_year_parent.present?
          if asset_details_budget.present?
            for cash_row in asset_details_budget
              @operating_trend_budget[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
            end
          end
          if asset_details_budget1.present?
            for cash_row in asset_details_budget1
              @operating_trend_budget1[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
            end
          end if last_year_parent.present?
          second_last_year = @second_last_year_financial_sub_id
          qry5 =   "SELECT k.title as Parent, a.title as Title,#{@month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{last_year_parent} AND f.pcb_type IN ('c') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'"
          qry6 =   "SELECT k.title as Parent, a.title as Title,#{@month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{second_last_year} AND f.pcb_type IN ('c') AND a.year=#{year-2} AND f.source_type='IncomeAndCashFlowDetail'"
          second_asset_details = IncomeAndCashFlowDetail.find_by_sql(qry5) if last_year_parent.present?
          second_asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry6) if second_last_year.present?
          @second_last_operating_trend,@second_last_operating_trend1 = {},{}
          if second_asset_details.present?
            for cash_row in second_asset_details
              @second_last_operating_trend[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
            end
          end if last_year_parent.present?
          if second_asset_details1.present?
            for cash_row in second_asset_details1
              @second_last_operating_trend1[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
            end
          end if second_last_year.present?
        end
      end
    else
      qry1 =   "SELECT k.title as Parent, a.title as Title,#{@month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{@month.keys} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title" if @month.present? && @note.present?
      asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present?
      @operating_trend1 = {}
      if asset_details1.present?
        for cash_row in asset_details1
          if cash_row.Title	!= nil
            @operating_trend1[cash_row.Title] =  form_hash_of_data_values(cash_row)
          end
        end
      end
      qry =  "SELECT k.title as Parent, a.title as Title,#{@month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{@month_val.keys} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title" if @month_val.present?  && @note.present?
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry) if qry.present?
      @operating_trend2 = {}
      if asset_details.present?
        for cash_row in asset_details
          if cash_row.Title	!= nil
            @operating_trend2[cash_row.Title] =  form_hash_of_data_values(cash_row)
          end
        end
      end
      title_rev=map_title("Operating Revenue")
      title_noi=map_title("NOI")
      title_net = map_title("net cash flow")
      title_exp = map_title("operating expenses")

      @operating_trend['operating expenses'] = (@operating_trend1['operating expenses'].present? && @operating_trend2['operating expenses'].present?) ? @operating_trend1['operating expenses'].merge(@operating_trend2['operating expenses']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend1['operating expenses'].present? ? @operating_trend1['operating expenses']  : @operating_trend2['operating expenses'].present? ?  @operating_trend2['operating expenses'] : ""

      @operating_trend['capital expenditures'] = (@operating_trend1['capital expenditures'].present? && @operating_trend2['capital expenditures'].present?) ? @operating_trend1['capital expenditures'].merge(@operating_trend2['capital expenditures']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend1['capital expenditures'].present? ? @operating_trend1['capital expenditures']  : @operating_trend2['capital expenditures'].present? ?  @operating_trend2['capital expenditures'] : ""

      @operating_trend['maintenance projects'] = (@operating_trend1['maintenance projects'].present? && @operating_trend2['maintenance projects'].present?) ? @operating_trend1['maintenance projects'].merge(@operating_trend2['maintenance projects']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend1['maintenance projects'].present? ? @operating_trend1['maintenance projects']  : @operating_trend2['maintenance projects'].present? ?  @operating_trend2['maintenance projects'] : ""

      if (@operating_trend1['recoverable expenses detail'].present? || @operating_trend2['recoverable expenses detail'].present? ) || (@operating_trend1['non-recoverable expenses detail'].present? || @operating_trend2['non-recoverable expenses detail'].present?)

        @operating_trend['recoverable expenses detail'] = (@operating_trend1['recoverable expenses detail'].present? && @operating_trend2['recoverable expenses detail'].present?)  ? @operating_trend1['recoverable expenses detail'].merge(@operating_trend2['recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } :  @operating_trend1['recoverable expenses detail'].present?  ?  @operating_trend1['recoverable expenses detail'] : @operating_trend2['recoverable expenses detail'].present?  ? @operating_trend2['recoverable expenses detail'] : ""

        @operating_trend['non-recoverable expenses detail'] = (@operating_trend1['non-recoverable expenses detail'].present? && @operating_trend2['non-recoverable expenses detail'].present?)  ? @operating_trend1['non-recoverable expenses detail'].merge(@operating_trend2['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } :  @operating_trend1['non-recoverable expenses detail'].present?  ?  @operating_trend1['non-recoverable expenses detail'] : @operating_trend2['non-recoverable expenses detail'].present?  ? @operating_trend2['non-recoverable expenses detail'] : ""

        @operating_trend['operating expenses'] = (@operating_trend['recoverable expenses detail'].present? && @operating_trend['non-recoverable expenses detail'].present?) ? @operating_trend['recoverable expenses detail'].merge(@operating_trend['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend['recoverable expenses detail'].present? ? @operating_trend['recoverable expenses detail']  : @operating_trend['non-recoverable expenses detail'].present? ?  @operating_trend['non-recoverable expenses detail'] : ""
      end

      @operating_trend['net cash flow'] = (@operating_trend1[title_net].present? && @operating_trend2[title_net].present?)  ? @operating_trend1[title_net].merge(@operating_trend2[title_net]) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend1[title_net].present? ?  @operating_trend1[title_net]  :  @operating_trend2[title_net].present?  ?  @operating_trend2[title_net]  : ""
      @operating_trend['noi'] = (@operating_trend1[title_noi].present? && @operating_trend2[title_noi]) ? @operating_trend1[title_noi].merge(@operating_trend2[title_noi]) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend1[title_noi].present? ? @operating_trend1[title_noi] : @operating_trend2[title_noi].present? ? @operating_trend2[title_noi] : ""
      @operating_trend['op rev'] = (@operating_trend1[title_rev].present? && @operating_trend2[title_rev] ) ? @operating_trend1[title_rev].merge(@operating_trend2[title_rev]) {|key,val1,val2| val1.to_f + val2.to_f }  : @operating_trend1[title_rev].present? ? @operating_trend1[title_rev] : @operating_trend2[title_rev].present? ? @operating_trend2[title_rev] : ""
    end
  end

  def form_hash_of_data_values(cash_row)
    @val = {"Jan"=> cash_row.attributes['Jan'] ? cash_row.attributes['Jan'] : 0,
      "Feb"=> cash_row.attributes['Feb'] ?  cash_row.attributes['Feb'] : 0,
      "Mar"=> cash_row.attributes['Mar']  ?  cash_row.attributes['Mar'] : 0,
      "Apr"=> cash_row.attributes['Apr'] ? cash_row.attributes['Apr'] : 0,
      "May"=> cash_row.attributes['May'] ?  cash_row.attributes['May'] : 0,
      "Jun"=> cash_row.attributes['Jun'] ?  cash_row.attributes['Jun'] : 0,
      "Jul"=>cash_row.attributes['Jul'] ? cash_row.attributes['Jul'] : 0,
      "Aug"=> cash_row.attributes['Aug']  ? cash_row.attributes['Aug'] : 0,
      "Sep"=> cash_row.attributes['Sep']  ? cash_row.attributes['Sep'] : 0,
      "Oct"=> cash_row.attributes['Oct'] ? cash_row.attributes['Oct'] : 0,
      "Nov"=> cash_row.attributes['Nov'] ? cash_row.attributes['Nov'] : 0,
      "Dec"=>cash_row.attributes['Dec'] ? cash_row.attributes['Dec'] : 0
    }
  end

  def pdf_path_and_note(property_id)
    pdf_convn_path = @pdf.blank? ? '' : Rails.root.to_s+'/public'
    @note = RealEstateProperty.find_by_id(property_id)
    return pdf_convn_path,@note
  end

  def lease_expiration_graph_display(prop_ids = nil)
    year_collection,rented_area_collection,indivitual_percentage,cumulatuive_percentage = [],[],[],[]
     (0..10).each do |i|
      year_collection << Date.today.year + i
    end
    qry_str = prop_ids.present? ? "lease_rent_rolls.real_estate_property_id IN (#{prop_ids.join(',')})" : "lease_rent_rolls.real_estate_property_id = #{@note.id}"

    # Finding month for which the rent roll records are available
    month_yr = LeaseRentRoll.find_by_sql("SELECT month,year FROM lease_rent_rolls WHERE #{qry_str} ORDER BY lease_rent_rolls.year DESC,lease_rent_rolls.month DESC")

    month = month_yr.present? ? month_yr.first.month : Time.now.month
    year = month_yr.present? ? month_yr.first.year : Time.now.year

    for i in (0 .. 10)
      start_date = Date.new(Date.today.year+i).strftime("%Y-%m-%d")
      end_date = start_date.to_date.end_of_year.strftime("%Y-%m-%d") if start_date
      @base_rent = LeaseRentRoll.find_by_sql("select sum(lease_rent_rolls.sqft) as rented_area from lease_rent_rolls where #{qry_str}  and lease_rent_rolls.lease_end_date >= '#{start_date}' and lease_rent_rolls.lease_end_date <= '#{end_date}' and month=#{month} and year=#{year}")
      @base_rent.each do |i|
        rented_area_collection << (i.rented_area.present? ? i.rented_area.to_i : 0)
      end
    end
    total_sum = rented_area_collection.sum
    rented_area_collection.each do |i|
      indivitual_percentage << ( i.to_f / total_sum.to_f ) * 100
    end
    indivitual_percentage.each_with_index do |i,j|
      sum_flag = 0
      for k in 0..j
        sum_flag += indivitual_percentage[k]
      end
      cumulatuive_percentage  << sum_flag
    end
    rented_area_collection.map! { |x| x == 0 ? '' : x }
    return year_collection,rented_area_collection,cumulatuive_percentage,total_sum
  end

  def trailing_12_month_graph(note_collection,prop_ids = nil)
    months = ["","january","february","march","april","may","june","july","august","september","october","november","december"]
    month_string = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    month_nos = [0,1,2,3,4,5,6,7,8,9,10,11,12]
    prev_months,prev_months_string,prev_months_string_x,cur_months,cur_months_string,cur_months_string_x = [],[],[],[],[],[]
    prev_month = {}
    cur_month = {}
    for i in  Date.today.prev_year.month..12 do
      prev_months << month_nos[i]
      prev_months_string << month_string[i]
      prev_months_string_x << month_string[i]+' '+Date.today.prev_year.strftime('%y')
    end
    prev_year_and_month = {Date.today.prev_year.year =>  prev_months }
    for i in  1...Date.today.month do
      cur_months << month_nos[i]
      cur_months_string << month_string[i]
      cur_months_string_x << month_string[i]+' '+Date.today.strftime('%y')
    end
    cur_year_and_month = {Date.today.year =>  cur_months }
    total_months = prev_months_string + cur_months_string
    total_months_x = prev_months_string_x + cur_months_string_x
    qry_str = prop_ids.present? ? "lr.real_estate_property_id IN (#{prop_ids.join(',')})" : "lr.real_estate_property_id = #{note_collection.id}"
    qry1 = "select lr.month as month,lr.year,s.status as status, sum(s.rentable_sqft) as tot from lease_rent_rolls lr INNER JOIN suites s ON lr.suite_id = s.id and #{qry_str} and lr.occupancy_type = 'current' and lr.month IN (#{prev_year_and_month.values.join(',')}) and lr.year = #{prev_year_and_month.keys} group by lr.month,s.status"
    qry2 = "select lr.month as month,lr.year,s.status as status, sum(s.rentable_sqft) as tot from lease_rent_rolls lr INNER JOIN suites s ON lr.suite_id = s.id and #{qry_str} and lr.occupancy_type = 'current' and lr.month IN (#{cur_year_and_month.values.join(',')}) and lr.year = #{cur_year_and_month.keys} group by lr.month,s.status"
    qry_vacant1 = "SELECT sum(sqft) as tot,month,'vacant' as status FROM `lease_rent_rolls` WHERE year = #{prev_year_and_month.keys} and month IN (#{prev_year_and_month.values.join(',')}) and #{qry_str.gsub('lr.','')} and tenant = 'Vacant' and ( lease_end_date IS NULL or `lease_end_date` <  #{Date.today} ) group by month"
    qry_vacant2 = "SELECT sum(sqft) as tot,month,'vacant' as status FROM `lease_rent_rolls` WHERE year = #{cur_year_and_month.keys} and month IN (#{cur_year_and_month.values.join(',')}) and #{qry_str.gsub('lr.','')} and tenant = 'Vacant' and ( lease_end_date IS NULL or `lease_end_date` <  #{Date.today} ) group by month"
    qry_occupied1 = "SELECT sum(sqft) as tot,month,'occupied' as status FROM `lease_rent_rolls` WHERE year = #{prev_year_and_month.keys} and month IN (#{prev_year_and_month.values.join(',')}) and #{qry_str.gsub('lr.','')} and tenant != 'Vacant' and ( lease_end_date IS NULL or `lease_end_date` >=  #{Date.today} ) group by month"
    qry_occupied2 = "SELECT sum(sqft) as tot,month,'occupied' as status FROM `lease_rent_rolls` WHERE year = #{cur_year_and_month.keys} and month IN (#{cur_year_and_month.values.join(',')}) and #{qry_str.gsub('lr.','')} and tenant != 'Vacant' and ( lease_end_date IS NULL or `lease_end_date` >=  #{Date.today} ) group by month"
    lease_rent1 = LeaseRentRoll.find_by_sql(qry_vacant1)
    lease_rent2 = LeaseRentRoll.find_by_sql(qry_vacant2)
    lease_rent3 = LeaseRentRoll.find_by_sql(qry_occupied1)
    lease_rent4 = LeaseRentRoll.find_by_sql(qry_occupied2)
    total_value = lease_rent1 + lease_rent2 + lease_rent3 + lease_rent4
    occ_and_vac_tot = {}
    occ_tot,vac_tot = {},{}
    flag_var = 0
    for rent in total_value
      occ_tot["#{month_string[rent.month]}"] = rent.tot.to_i if rent.status.eql?('occupied')
      vac_tot["#{month_string[rent.month]}"] = rent.tot.to_i if rent.status.eql?('vacant')
    end
    for rent in total_value
      if ( occ_tot["#{month_string[rent.month]}"].blank? || vac_tot["#{month_string[rent.month]}"].blank? )
        occ_and_vac_tot["#{month_string[rent.month]}"] = ''
      else
        occ_and_vac_tot["#{month_string[rent.month]}"] = occ_tot["#{month_string[rent.month]}"] + vac_tot["#{month_string[rent.month]}"]
        flag_var = 1
      end
      #      occ_and_vac_tot["#{month_string[rent.month]}"] = ( occ_tot["#{month_string[rent.month]}"].blank? || vac_tot["#{month_string[rent.month]}"].blank? ) ? '' : occ_tot["#{month_string[rent.month]}"] + vac_tot["#{month_string[rent.month]}"]
    end
    return total_months,occ_tot,vac_tot,occ_and_vac_tot,total_months_x,flag_var
  end

  def find_month_options_values
    @month_string = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    @time = Time.now.beginning_of_year
    @year_string = []
    @quarter_string = ["Q1","Q2","Q3","Q4"]
    for j in -3 .. 1
      @year_string << @time.advance(:years=>j).strftime("%Y")
    end
    return @month_string,@year_string,@quarter_string
  end

  def find_data_for_noi_variances
    if session[:portfolio__id].present?  && !session[:property__id].present?
      @note = Portfolio.find_by_id(session[:portfolio__id])
      @resource = "'Portfolio'"
    else
      @note = RealEstateProperty.find_real_estate_property(session[:property__id]) if session[:property__id].present?
      @resource = "'RealEstateProperty'"
    end
    months = ["","january","february","march","april","may","june","july","august","september","october","november","december"]
    month_string = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    @month_array,@month_array_noi = [],[]
    @noi_variance = {}
    @month = {}
    @month_val = {}
    month_val = []
    month_name = []
    calc_for_financial_data_display
    cur_year_days = Date.leap?(DateTime.now .year) ? 366 : 365
    if params[:tl_period] == "4" || params[:tl_period] == "11"
    for i in  (@month_format - cur_year_days).month..12 do
      @month_array << month_string[i]
      @month_array_noi << month_string[i]+'-'+Date.today.prev_year.strftime('%y')
      month_val << "sum(" + "f."+ "#{months[i]}" + ")" + "as" + " '#{month_string[i]}'"
      @month = {(@month_format - cur_year_days).year =>  month_val.uniq }
      @month_array, @month_array_noi = [], [] if params[:tl_period] == "4"
      if i == 12
        # Have to change to display YTD values - i.e. last month based on setting
        for j in 1..@financial_month.to_i do
          @month_array << month_string[j]
          @month_array_noi << month_string[j]+'-'+Date.today.strftime('%y')
          month_name << "sum("+ "f."+ "#{months[j] }" +")" + "as" + " '#{month_string[j] }'"
          @month_val = {Date.today.year =>  month_name.uniq}
        end
      end
    end
    elsif params[:tl_period] == "3"
      for j in 1..12 do
          @month_array << month_string[j]
          @month_array_noi << month_string[j]+'-'+Date.today.prev_year.strftime('%y')
          month_name << "sum("+ "f."+ "#{months[j] }" +")" + "as" + " '#{month_string[j] }'"
          @month_val = {Date.today.prev_year.year =>  month_name.uniq}
        end
    end
    if params[:selected_link].present?
      if params[:selected_link].strip.eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
        title = "recoverable expenses detail','non-recoverable expenses detail"
      else
        title = map_title(params[:selected_link].strip)
      end
    else
      title = map_title('NOI')
    end
#    title = params[:selected_link].present? ? map_title(params[:selected_link].strip) : map_title('NOI')
    qry1 ="SELECT a.title as Title, f.pcb_type, #{@month.values.join(",")}   FROM `income_and_cash_flow_details` a  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(a.title,'\\'','') IN ('#{title.gsub("'","")}')) AND f.pcb_type IN ('c') AND a.year=#{@month.keys} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT  a.title as Title, f.pcb_type, #{@month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(a.title,'\\'','') IN ('#{title.gsub("'","")}')) AND f.pcb_type IN ('b') AND a.year=#{@month.keys} AND f.source_type='IncomeAndCashFlowDetail' "  if @month.present? && @note.present?
    asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present?
    @noi_variance1 = {}
    if asset_details1.present?
      for cash_row in asset_details1
        if cash_row.Title	!= nil
          @noi_variance1[cash_row.pcb_type] =  form_hash_of_data_values(cash_row)
        end
      end
    end
    qry = "SELECT a.title as Title, f.pcb_type, #{@month_val.values.join(",")}   FROM `income_and_cash_flow_details` a  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(a.title,'\\'','') IN ('#{title.gsub("'","")}')) AND f.pcb_type IN ('c') AND a.year=#{@month_val.keys} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT  a.title as Title, f.pcb_type, #{@month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(a.title,'\\'','') IN ('#{title.gsub("'","")}')) AND f.pcb_type IN ('b') AND a.year=#{@month_val.keys} AND f.source_type='IncomeAndCashFlowDetail' "  if @month_val.present? && @note.present?
    asset_details = IncomeAndCashFlowDetail.find_by_sql(qry) if qry.present?
    @noi_variance2 = {}
    if asset_details.present?
      for cash_row in asset_details
        if cash_row.Title	!= nil
          @noi_variance2[cash_row.pcb_type] =  form_hash_of_data_values(cash_row)
        end
      end
    end
    #Commented temporarily to display only YTD data
    if params[:tl_period] == "11"
    @noi_variance["b"] = (@noi_variance1["b"].present? && @noi_variance2["b"].present?) ? @noi_variance1["b"].merge(@noi_variance2["b"]) {|key,val1,val2| val1.to_f + val2.to_f } : @noi_variance1["b"].present? ? @noi_variance1["b"] : @noi_variance2["b"].present? ? @noi_variance2["b"] : ""
    @noi_variance["c"] = (@noi_variance1["c"].present? && @noi_variance2["c"].present?) ? @noi_variance1["c"].merge(@noi_variance2["c"]) {|key,val1,val2| val1.to_f + val2.to_f } : @noi_variance1["c"].present? ? @noi_variance1["c"]  :  @noi_variance2["c"].present? ? @noi_variance2["c"] : ""
    elsif params[:tl_period] == "4" || params[:tl_period] == "3"
    @noi_variance["b"] = @noi_variance2["b"].present? ? @noi_variance2["b"] : ""
    @noi_variance["c"] = @noi_variance2["c"].present? ? @noi_variance2["c"] : ""
    end
    @value_noi, @var_noi, @positive_variance,@negative_variance = {},{},{}, {}
    cumulative_actual = 0
    cumulative_budget = 0
    @month_array.present? && @month_array.uniq.each do |month|
      cumulative_actual = cumulative_actual + @noi_variance["c"][month].to_f
      cumulative_budget = cumulative_budget +  @noi_variance["b"][month].to_f
       #temp =number_with_precision(((cumulative_budget - cumulative_actual) * 100 / cumulative_budget), :precision => 2)  #rescue ZeroDivisionError
      temp1 = ((cumulative_actual - cumulative_budget)) # * 100 / cumulative_budget) #Commented temporarily to change percentage to variance amt
      temp = temp1.nan? ? 0 : number_with_precision(temp1, :precision => 2).to_f
      @value_noi[month] = temp
      @var_noi[month] = (@noi_variance["c"][month].to_f  - @noi_variance["b"][month].to_f) if @noi_variance["c"][month].present? && @noi_variance["b"][month].present?
      if @value_noi[month].present?
        @positive_variance[month] =  (@var_noi[month].to_f > 0) ? @var_noi[month] : nil
        @negative_variance[month] = (@var_noi[month].to_f < 0) ? @var_noi[month] : nil
      end
    end
  end

  def commercial_lease_display(commercial_leases)
    property_total_units,vacancy_total_units,comm_tenant_total,total_expiration = 0,0,0,0
    comm_array = []
    commercial_leases.each_with_index {|i,index|
      comm_struct = Struct.new(:lease_actual,:comm_property,:net_income_de,:operating_statement,:cash_flow_statement,:leases,:real_prop,:exp_val,:total_tenant)
      @note,@net_income_de = i,nil
      @portfolio = i.portfolio
      net_income_de,operating_statement,cash_flow_statement = dashboard_store_income_and_cash_flow_statement(true) # For Op Rev, NOI and Cash Display
      title_net = map_title("NET OPERATING INCOME",true)
      remote_cash_actual,remote_cash_budget,remote_cash_variance,remote_cash_percent = dashboard_remote_cash_flow_statement(operating_statement,true) if remote_property(i.accounting_system_type_id)
      params[:tl_period] = "4"
      leases = dashboard_lease_details(nil, Date.today.year,i) # For Vacancy percent and vacancy sqft
      #real_prop = occupancy_total(@note,Date.today.year) # For Occupancy Sqft Display
      real_prop = leases[:total_rentable_space][:actual].blank? ? 0 : leases[:total_rentable_space][:actual].to_i
      property_total_units += real_prop # For Total Occupied Sqft display
      vacancy_total_units += leases[:current_vacant][:actual] # For Total Vacancy Sqft display
      total_tenant = dashboard_cash_and_receivables_for_receivables() # For Account Rec Aging For tenant
      comm_tenant_total += total_tenant # For Total Tenant for Acc_Rec_aging
      #rent_roll_swig = dashboard_rent_roll() # For Base rent
      #total_base_rent += rent_roll_swig # For Total Base rent
      exp_val = dashboard_exp() # For Expiration Calculation
      total_expiration += exp_val # For Total Expiration display
      lease_actual = leases[:current_vacant][:actual]
      comm_array << comm_struct.new(lease_actual,i,net_income_de,operating_statement,cash_flow_statement,leases,real_prop,exp_val,total_tenant)
    }
    if params[:sort_type] == 'vacancy'
      if params[:vacant_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.lease_actual <=> comm2.lease_actual}
      elsif params[:vacant_sort] == 'DESC'
        comm_array = comm_array.sort{|comm1, comm2| comm2.lease_actual <=> comm1.lease_actual}
      end
    elsif params[:sort_type] == 'vacancy_sf'
      if params[:vacant_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.leases[:current_vacant_percent][:actual] <=> comm2.leases[:current_vacant_percent][:actual]}
      elsif params[:vacant_sort] == 'DESC'
        comm_array = comm_array.sort{|comm1, comm2| comm2.leases[:current_vacant_percent][:actual] <=> comm1.leases[:current_vacant_percent][:actual]}
      end
    end
    if params[:sort_type] == 'expiration'
      if params[:expiration_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.exp_val <=> comm2.exp_val}
      elsif params[:expiration_sort] == 'DESC'
        comm_array = comm_array.sort{|comm1, comm2| comm2.exp_val <=> comm1.exp_val}
      end
    end
    return comm_array,property_total_units,vacancy_total_units,comm_tenant_total,total_expiration
  end
  #Find total values for leasing activity
  def find_total_for_leasing_activity(comm_array)
    comm_array.each_with_index{|i,index|
      @total_renewal_sf,@total_new_leases_sf,@total_renewal_bud,@total_new_leases_bud = 0,0,0,0
      calculations_properties(i.comm_property)
      value = @total_renewal_sf.present? ? @total_renewal_sf: "0 SF"
      @total_renewal_sf_sum += value
      new_renewal = @total_new_leases_sf.present? ? @total_new_leases_sf: 0
      new_budget = @total_new_leases_bud.present? ? @total_new_leases_bud: 0
      vari = form_hash_of_data_for_occupancy(new_renewal, new_budget)
      value1= display_sqrt_real_estate_overview(@total_new_leases_sf.present? ? @total_new_leases_sf : 0)
      @total_new_leases_sf_sum += value1.gsub("SF","").gsub(',','').to_i
      interested_and_negotiated_leases(i.comm_property.id,nil,nil)
      find_active_prospects(@property_lease_suites_interested,i.comm_property.id)
      value3 = @prospect_sqft.present? ? @prospect_sqft.gsub("SF","").gsub(',','').to_i : 0
      @total_pipeline += value3
      find_pending_approval(@property_lease_suites_negotiated,i.comm_property.id)
      value4 = @pending_sqft.present? ? @pending_sqft.gsub("SF","").gsub(',','').to_i : 0
      @total_approvals += value4
    }
  end
  
    def commercial_all_lease_display_new(commercial,from_nav=nil)
    property_total_units,vacancy_total_units,op_rev_total_units,noi_total_units,cash_total_units,comm_tenant_total,total_expiration = 0,0,0,0,0,0,0
    comm_array = []
      commercial.each_with_index {|i,index_for_prop|
      comm_struct = Struct.new(:lease_actual,:comm_property,:net_income_de,:operating_statement,:cash_flow_statement,:leases,:real_prop,:exp_val,:total_tenant,:remote_cash_actual,:remote_cash_budget,:remote_cash_variance,:remote_cash_percent,:noi)
      @note,@net_income_de = i,nil
      @portfolio = i.portfolio
      net_income_de,operating_statement,cash_flow_statement = dashboard_store_income_and_cash_flow_statement(true,from_nav) # For Op Rev, NOI and Cash Display
      title_net = map_title("NET OPERATING INCOME",true)
      remote_cash_actual,remote_cash_budget,remote_cash_variance,remote_cash_percent = dashboard_remote_cash_flow_statement(operating_statement,true) if remote_property(i.accounting_system_type_id)
      params[:tl_period] = "4"
      leases = dashboard_lease_details(nil, Date.today.year,i,from_nav) # For Vacancy percent and vacancy sqft
      #real_prop = occupancy_total(@note,Date.today.year) # For Occupancy Sqft Display
      real_prop = leases[:total_rentable_space][:actual].blank? ? 0 : leases[:total_rentable_space][:actual].to_i
      property_total_units += real_prop # For Total Occupied Sqft display
      vacancy_total_units += leases[:current_vacant][:actual] # For Total Vacancy Sqft display
      total_tenant = dashboard_cash_and_receivables_for_receivables(from_nav) # For Account Rec Aging For tenant
      comm_tenant_total += total_tenant # For Total Tenant for Acc_Rec_aging
      #rent_roll_swig = dashboard_rent_roll() # For Base rent
      #total_base_rent += rent_roll_swig # For Total Base rent
      exp_val = dashboard_exp() # For Expiration Calculation
      total_expiration += exp_val # For Total Expiration display
      lease_actual = leases[:current_vacant][:actual]
      noi_title = map_title("NOI",true)
      noi = operating_statement[noi_title]
      comm_array << comm_struct.new(lease_actual,i,net_income_de,operating_statement,cash_flow_statement,leases,real_prop,exp_val,total_tenant,remote_cash_actual,remote_cash_budget,remote_cash_variance,remote_cash_percent,noi)
    }
    if params[:sort_type] == 'neg_noi_percentage'
      comm_array = comm_array.sort{|comm1, comm2| -(comm1.noi[:percent] rescue 0) <=> -(comm2.noi[:percent] rescue 0)}
    elsif params[:sort_type] == 'vacancy_sf'
      if params[:vacant_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.leases[:current_vacant_percent][:actual] <=> comm2.leases[:current_vacant_percent][:actual]}
      elsif params[:vacant_sort] == 'DESC'
        comm_array = comm_array.sort{|comm1, comm2| comm2.leases[:current_vacant_percent][:actual] <=> comm1.leases[:current_vacant_percent][:actual]}
      end
    elsif params[:sort_type] == 'expiration'
      if params[:expiration_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.exp_val <=> comm2.exp_val}
      elsif params[:expiration_sort] == 'DESC'
        comm_array = comm_array.sort{|comm1, comm2| comm2.exp_val <=> comm1.exp_val}
      end
    elsif params[:sort_type] == 'tenant'
      if params[:tenant_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.total_tenant <=> comm2.total_tenant}
      elsif params[:tenant_sort] == 'DESC'
        comm_array = comm_array.sort{|comm1, comm2| comm2.total_tenant <=> comm1.total_tenant}
      end
    else
      comm_array = comm_array.sort{|comm1, comm2| -(comm1.noi[:percent] rescue 0) <=> -(comm2.noi[:percent] rescue 0)}
    end
    return comm_array
  end

  def commercial_all_lease_display(commercial)
    property_total_units,vacancy_total_units,op_rev_total_units,noi_total_units,cash_total_units,comm_tenant_total,total_expiration = 0,0,0,0,0,0,0
    comm_array = []
    commercial.each_with_index {|i,index|
      comm_struct = Struct.new(:lease_actual,:comm_property,:net_income_de,:operating_statement,:cash_flow_statement,:leases,:real_prop,:exp_val,:total_tenant,:remote_cash_actual,:remote_cash_budget,:remote_cash_variance,:remote_cash_percent,:noi)
      @note,@net_income_de = i,nil
      @portfolio = i.portfolio
      net_income_de,operating_statement,cash_flow_statement = dashboard_store_income_and_cash_flow_statement(true) # For Op Rev, NOI and Cash Display
      title_net = map_title("NET OPERATING INCOME",true)
      remote_cash_actual,remote_cash_budget,remote_cash_variance,remote_cash_percent = dashboard_remote_cash_flow_statement(operating_statement,true) if remote_property(i.accounting_system_type_id)
      params[:tl_period] = "4"
      leases = dashboard_lease_details(nil, Date.today.year,i) # For Vacancy percent and vacancy sqft
      #real_prop = occupancy_total(@note,Date.today.year) # For Occupancy Sqft Display
      real_prop = leases[:total_rentable_space][:actual].blank? ? 0 : leases[:total_rentable_space][:actual].to_i
      property_total_units += real_prop # For Total Occupied Sqft display
      vacancy_total_units += leases[:current_vacant][:actual] # For Total Vacancy Sqft display
      total_tenant = dashboard_cash_and_receivables_for_receivables() # For Account Rec Aging For tenant
      comm_tenant_total += total_tenant # For Total Tenant for Acc_Rec_aging
      #rent_roll_swig = dashboard_rent_roll() # For Base rent
      #total_base_rent += rent_roll_swig # For Total Base rent
      exp_val = dashboard_exp() # For Expiration Calculation
      total_expiration += exp_val # For Total Expiration display
      lease_actual = leases[:current_vacant][:actual]
      noi_title = map_title("NOI",true)
      noi = operating_statement[noi_title]
      comm_array << comm_struct.new(lease_actual,i,net_income_de,operating_statement,cash_flow_statement,leases,real_prop,exp_val,total_tenant,remote_cash_actual,remote_cash_budget,remote_cash_variance,remote_cash_percent,noi)
    }
    if params[:sort_type] == 'vacancy'
      if params[:vacant_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.lease_actual <=> comm2.lease_actual}
      else
        comm_array = comm_array.sort{|comm1, comm2| comm2.lease_actual <=> comm1.lease_actual}
      end
    elsif params[:sort_type] == 'vacancy_sf'
      if params[:vacant_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.leases[:current_vacant_percent][:actual] <=> comm2.leases[:current_vacant_percent][:actual]}
      else
        comm_array = comm_array.sort{|comm1, comm2| comm2.leases[:current_vacant_percent][:actual] <=> comm1.leases[:current_vacant_percent][:actual]}
      end
    elsif params[:sort_type] == 'expiration'
      if params[:expiration_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.exp_val <=> comm2.exp_val}
      else
        comm_array = comm_array.sort{|comm1, comm2| comm2.exp_val <=> comm1.exp_val}
      end
    elsif params[:sort_type] == 'tenant'
      if params[:tenant_sort] == 'ASC'
        comm_array = comm_array.sort{|comm1, comm2| comm1.total_tenant <=> comm2.total_tenant}
      else
        comm_array = comm_array.sort{|comm1, comm2| comm2.total_tenant <=> comm1.total_tenant}
      end
    elsif params[:sort_type] == 'pos_noi'
      comm_array = comm_array.sort{|comm1, comm2| -(comm2.noi[:variant] rescue 0) <=> -(comm1.noi[:variant] rescue 0)}
    elsif params[:sort_type] == 'pos_noi_percentage'
      comm_array = comm_array.sort{|comm1, comm2| -(comm2.noi[:percent] rescue 0) <=> -(comm1.noi[:percent] rescue 0)}
    elsif params[:sort_type] == 'neg_noi'
      comm_array = comm_array.sort{|comm1, comm2| -(comm1.noi[:variant] rescue 0) <=> -(comm2.noi[:variant] rescue 0)}
    elsif params[:sort_type] == 'neg_noi_percentage'
      comm_array = comm_array.sort{|comm1, comm2| -(comm1.noi[:percent] rescue 0) <=> -(comm2.noi[:percent] rescue 0)}
    end
    comm_array.each_with_index{|i,index|
        income_title = map_title("Operating Revenue")
        revenue = i.operating_statement[income_title]
        revenue_act = revenue.nil? ? 0 : dashboard_currency_display(revenue[:actuals],'false')
        revenue_act,revenue_bud,revenue_per,revenue_var = revenue_calc(revenue)
        op_rev_total_units += revenue_act
        noi_value = i.noi.nil? || i.noi[:actuals].nil? ? 0 : i.noi[:actuals].round
        noi_var = i.noi.nil? || i.noi[:variant].nil? ? 0 : i.noi[:variant].round
        noi_total_units += noi_value
        unless remote_property(i.comm_property.accounting_system_type_id)
          net_cash,cash_type = find_net_cash(i.operating_statement)
          cash_value = net_cash.nil? || net_cash[:actuals].nil? ? 0 : net_cash[:actuals].round
        else
          cash_value = i.remote_cash_actual
        end
        cash_total_units += cash_value
    }
    return comm_array,property_total_units,vacancy_total_units,op_rev_total_units,noi_total_units,cash_total_units,comm_tenant_total,total_expiration
  end
  
   def multifamily_all_lease_display_new(multi,from_nav=nil)
    multi_prop_tot_units,multi_op_rev_total,multi_vac_tot_units,net_avail_total,net_avail_vacant_tot,multi_noi_total,multi_cash_total = 0,0,0,0,0,0,0
    total_deposit_val,total_traffic_val,total_lease_rent = 0,0,0
    multi_array = []
    @traffic_pi, @traffic_dep = [],[]
    multi.each_with_index {|i,index|
      #if i.portfolio.present?
      multi_struct = Struct.new(:total_suite,:multi_property,:wres_leases,:net_units_per,:net_avail_crnt,:operating_statement,:net_income_de,:remote_cash_actual,:remote_cash_budget,:remote_cash_variance,:remote_cash_percent,:cash_flow_statement,:noi,:date,:noi_display,:noi_var,:noi_percent,:vac_per)
      @note = i
      @portfolio = i.portfolio
      @total_suite,@total_floor,@suite_plan,@suites,@floor_plan,@netunits_avail_crnt_total,@trafic_dep_total,@trafic_pi_total,@net_income_de,@operating_statement,@cash_flow_statement = nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil
      net_income_de,operating_statement,cash_flow_statement = dashboard_store_income_and_cash_flow_statement(true,from_nav) # For Op Rev, NOI and Cash Display
      remote_cash_actual,remote_cash_budget,remote_cash_variance,remote_cash_percent = dashboard_remote_cash_flow_statement(operating_statement) if remote_property(i.accounting_system_type_id)
      #executive_overview_details_for_year
      wres_leases = dashboard_lease_details(nil, Date.today.year,i,from_nav) # For Vacancy vacancy Unit
      wres_rent_analysis_cal_for_year
      date = PropertyWeeklyOsr.maximum(:time_period,:conditions=>["real_estate_property_id=?",i.id])
      unless date.nil?
        calculate_property_weekly_display_data(date.strftime("%Y-%m-%d"))
        count = @property_week_vacant_total.count
        property_weekly_display_total(count)     
        net_avail_crnt = @vacant_net_total.to_i+(@notice_gross_total.to_i-@notice_rented_total.to_i)
        net_avail_total += net_avail_crnt
        net_units_per = @vacant_units_total.nil? || @vacant_units_total.eql?(0) ? "0%" : "#{number_with_precision(((@vacant_net_total+(@notice_gross_total-@notice_rented_total))/@vacant_units_total.to_f)*100, :precision => 1)}%"
        net_avail_vacant_tot += @vacant_units_total.to_i
        total_deposit_val += @trafic_dep_total
        total_traffic_val += @trafic_pi_total
        @traffic_pi << @trafic_pi_total
        @traffic_dep << @trafic_dep_total
      end
      #net_income_operation_summary_report
      total_floor = @total_floor.nil? ? 0 : @total_floor
      total_suite = @total_suite.nil? ? 0 : @total_suite
      floor = (wres_leases.blank? || wres_leases.eql?(0)) ? 1 : wres_leases.to_f
      vac_per = total_suite.nil? ? 0 : (total_suite.to_f* 100 / floor).round
      multi_prop_tot_units += wres_leases
      multi_vac_tot_units += total_suite
      sort = "pl.end_date"
      lease_rent = 0
      suites_lease = PropertySuite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
      unless suites_lease.empty?
        year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year <= ?',suites_lease,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if !suites_lease.blank?
        year=year[0] ? year[0].year.to_i : nil
        #year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?)',suites_lease],:order=>"year desc",:limit=>1).map(&:year).max if !suites_lease.blank?
        month = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year = ? and month <= ?',suites_lease,year.to_i,get_month(year)],:select=>"month").map(&:month).max if !suites_lease.blank?
        #month = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year = ?',suites_lease,year.to_i],:select=>"month").map(&:month).max if !suites_lease.blank?
        rent_roll_wres = find_multifamily_rent_roll(month,year,sort)
        lease_rent = 0
        unless rent_roll_wres.nil?
          rent_roll_wres.each do |rent|
            lease_rent += rent.effective_rate ? rent.effective_rate : 0
          end
        end
      end
      total_lease_rent += lease_rent
      noi_title = map_title("NOI")
      noi = operating_statement[noi_title]
      noi_display = ( net_income_de == 0 || net_income_de.blank? ) ? 0 : net_income_de['diff']
      noi_act =  noi.nil? ? 0 : noi[:actuals]
      noi_bud =  noi.nil? ? 0 : noi[:budget]
      noi_var = noi_act.to_i - noi_bud.to_i
      noi_percent =  noi.nil? ? 0 :noi[:percent]
      multi_array << multi_struct.new(total_suite,i,wres_leases,net_units_per,net_avail_crnt,operating_statement,net_income_de,remote_cash_actual,remote_cash_budget,remote_cash_variance,remote_cash_percent,cash_flow_statement,noi,date,noi_display,noi_var,noi_percent,vac_per)
    }

    if params[:sort_type] == 'vacancy_sf'
      if params[:multi_vacant_sort] == 'ASC'
        multi_array = multi_array.sort{|comm1, comm2| comm1.vac_per <=> comm2.vac_per}
      elsif params[:multi_vacant_sort] == 'DESC'
        multi_array = multi_array.sort{|comm1, comm2| comm2.vac_per <=> comm1.vac_per}
      end
    elsif params[:sort_type] == 'neg_noi_percentage'
      multi_array = multi_array.sort{|comm1, comm2| comm1.noi_percent <=> comm2.noi_percent}
    end
    return multi_array
  end

  def multifamily_all_lease_display(multi)
    multi_prop_tot_units,multi_op_rev_total,multi_vac_tot_units,net_avail_total,net_avail_vacant_tot,multi_noi_total,multi_cash_total,total_vacant_units= 0,0,0,0,0,0,0,0
    total_deposit_val,total_traffic_val,total_lease_rent = 0,0,0
    multi_array = []
    @traffic_pi, @traffic_dep = [],[]
    multi.each_with_index {|i,index|
      #if i.portfolio.present?
      multi_struct = Struct.new(:total_suite,:multi_property,:wres_leases,:net_units_per,:net_avail_crnt,:operating_statement,:net_income_de,:remote_cash_actual,:remote_cash_budget,:remote_cash_variance,:remote_cash_percent,:cash_flow_statement,:noi,:date,:noi_display,:noi_var,:noi_percent,:vac_per,:vacant_units_display,:vacant_units_percent)
      @note = i
      @portfolio = i.portfolio
      @total_suite,@total_floor,@suite_plan,@suites,@floor_plan,@netunits_avail_crnt_total,@trafic_dep_total,@trafic_pi_total,@net_income_de,@operating_statement,@cash_flow_statement = nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil
      net_income_de,operating_statement,cash_flow_statement = dashboard_store_income_and_cash_flow_statement(true) # For Op Rev, NOI and Cash Display
      remote_cash_actual,remote_cash_budget,remote_cash_variance,remote_cash_percent = dashboard_remote_cash_flow_statement(operating_statement) if remote_property(i.accounting_system_type_id)
      #executive_overview_details_for_year
      wres_leases = dashboard_lease_details(nil, Date.today.year) # For Vacancy vacancy Unit
      wres_rent_analysis_cal_for_year
      date = PropertyWeeklyOsr.maximum(:time_period,:conditions=>["real_estate_property_id=?",i.id])
      unless date.nil?
        calculate_property_weekly_display_data(date.strftime("%Y-%m-%d"))
        count = @property_week_vacant_total.count
        property_weekly_display_total(count)
        
        #To display vacant units based on weekly report - starts here#
        vacant_units_display = @vacant_net_total.to_i
        total_vacant_units += vacant_units_display
        vacant_units_percent = (@vacant_units_total.nil? || @vacant_units_total.eql?(0)) ? 0 : "#{(((@vacant_net_total)/@vacant_units_total.to_f)*100)}"
        #To display vacant units based on weekly report - ends here#
        
        net_avail_crnt = @vacant_net_total.to_i+(@notice_gross_total.to_i-@notice_rented_total.to_i)
        net_avail_total += net_avail_crnt
        net_units_per = @vacant_units_total.nil? || @vacant_units_total.eql?(0) ? "0%" : "#{number_with_precision(((@vacant_net_total+(@notice_gross_total-@notice_rented_total))/@vacant_units_total.to_f)*100, :precision => 1)}%"
        net_avail_vacant_tot += @vacant_units_total.to_i   
        total_deposit_val += @trafic_dep_total
        total_traffic_val += @trafic_pi_total
        @traffic_pi << @trafic_pi_total
        @traffic_dep << @trafic_dep_total
      end
      #net_income_operation_summary_report
      total_floor = @total_floor.nil? ? 0 : @total_floor
      total_suite = @total_suite.nil? ? 0 : @total_suite
      floor = (wres_leases.blank? || wres_leases.eql?(0)) ? 1 : wres_leases.to_f
      vac_per = total_suite.nil? ? 0 : (total_suite.to_f* 100 / floor).round
      multi_prop_tot_units += wres_leases
      multi_vac_tot_units += total_suite
      sort = "pl.end_date"
      lease_rent = 0
      suites_lease = PropertySuite.find(:all, :conditions=>['real_estate_property_id = ?', @note.id]).map(&:id) if !@note.nil?
      unless suites_lease.empty?
        year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year <= ?',suites_lease,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if !suites_lease.blank?
        year=year[0] ? year[0].year.to_i : nil
        #year = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?)',suites_lease],:order=>"year desc",:limit=>1).map(&:year).max if !suites_lease.blank?
        month = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year = ? and month <= ?',suites_lease,year.to_i,get_month(year)],:select=>"month").map(&:month).max if !suites_lease.blank?
        #month = PropertyLease.find(:all, :conditions=>['property_suite_id IN (?) and year = ?',suites_lease,year.to_i],:select=>"month").map(&:month).max if !suites_lease.blank?
        rent_roll_wres = find_multifamily_rent_roll(month,year,sort)
        lease_rent = 0
        unless rent_roll_wres.nil?
          rent_roll_wres.each do |rent|
            lease_rent += rent.effective_rate ? rent.effective_rate : 0
          end
        end
      end
      total_lease_rent += lease_rent
      noi_title = map_title("NOI")
      noi = operating_statement[noi_title]
      noi_display = ( net_income_de == 0 || net_income_de.blank? ) ? 0 : net_income_de['diff']
      noi_act =  noi.nil? ? 0 : noi[:actuals]
      noi_bud =  noi.nil? ? 0 : noi[:budget]
      noi_var = noi_act.to_i - noi_bud.to_i
      noi_percent =  noi.nil? ? 0 :noi[:percent]
      multi_array << multi_struct.new(total_suite,i,wres_leases,net_units_per,net_avail_crnt,operating_statement,net_income_de,remote_cash_actual,remote_cash_budget,remote_cash_variance,remote_cash_percent,cash_flow_statement,noi,date,noi_display,noi_var,noi_percent,vac_per,vacant_units_display,vacant_units_percent)
    }

    if params[:sort_type] == 'vacancy'
      if params[:multi_vacant_sort] == 'ASC'
        multi_array = multi_array.sort{|comm1, comm2| comm1.total_suite <=> comm2.total_suite}
      elsif params[:multi_vacant_sort] == 'DESC'
        multi_array = multi_array.sort{|comm1, comm2| comm2.total_suite <=> comm1.total_suite}
      end
    elsif params[:sort_type] == 'vacancy_sf'
      if params[:multi_vacant_sort] == 'ASC'
        multi_array = multi_array.sort{|comm1, comm2| comm1.vac_per <=> comm2.vac_per}
      else
        multi_array = multi_array.sort{|comm1, comm2| comm2.vac_per <=> comm1.vac_per}
      end
    elsif params[:sort_type] == 'pos_noi'
      multi_array = multi_array.sort{|comm1, comm2| comm2.noi_var <=> comm1.noi_var}
    elsif params[:sort_type] == 'pos_noi_percentage'
      multi_array = multi_array.sort{|comm1, comm2| comm2.noi_percent <=> comm1.noi_percent}
    elsif params[:sort_type] == 'neg_noi'
      multi_array = multi_array.sort{|comm1, comm2| comm1.noi_var <=> comm2.noi_var}
    elsif params[:sort_type] == 'neg_noi_percentage'
      multi_array = multi_array.sort{|comm1, comm2| comm1.noi_percent <=> comm2.noi_percent}
    end
    #To find_total_array_for_ytd_op_rev_and_ytd_noi_and_ytd_cash start
    multi_array.each_with_index{|i,index|
      income_title = map_title("Operating Revenue")
      revenue = i.operating_statement[income_title]
      rev_val =  revenue.nil? ? 0 : revenue[:actuals]
      multi_op_rev_total += rev_val.to_i

      noi_val =  i.noi.nil? ? 0 : i.noi[:actuals]
      noi_bud =  i.noi.nil? ? 0 : i.noi[:budget]
      multi_noi_total += noi_val.to_i

      unless remote_property(i.multi_property.accounting_system_type_id)
        cash_val = i.operating_statement['CASH FLOW STATEMENT'].nil? ? 0 : i.operating_statement['CASH FLOW STATEMENT'][:actuals]
      else
        cash_val = i.remote_cash_actual
      end
      multi_cash_total += cash_val.to_i
    }
    #To find_total_array_for_ytd_op_rev_and_ytd_noi_and_ytd_cash end
    return multi_array,multi_prop_tot_units,multi_op_rev_total,multi_vac_tot_units,net_avail_total,net_avail_vacant_tot,multi_noi_total,multi_cash_total,total_deposit_val,total_traffic_val,total_lease_rent,total_vacant_units
  end

  def portfolio_lease_expirations_calculation(prop_ids) # If you do any changes here, please do the same in dashboard_exp method
    ##removed code related to period for time line selector removal
    #~ year = find_selected_year(year)

    @colors = ["fd5805","4cc94f","2f48e1","974cc6","dced84"]
    @suites = Suite.find(:all, :conditions=>['real_estate_property_id IN (?)', prop_ids]).map(&:id)
    year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?)  and year <= ? ',@suites,Date.today.year],:order=>"year desc",:limit=>1).map(&:year).max if !@suites.blank?
    month_val = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and  month <= ? and year=?',@suites,get_month(year),year],:select=>"month").map(&:month).max if !@suites.blank? && year.present?
    if year.present? && month_val.present?
      @year = year
      @month_val = month_val
      for i in (0 .. 3)
        start_date = Date.new(year.to_i+i).strftime("%Y-%m-%d")
        end_date = start_date.to_date.end_of_year.strftime("%Y-%m-%d") if start_date
        end_date_string = ( i == 3 ? '' : "and lease_rent_rolls.lease_end_date <= '#{end_date}'")
        @base_rent = LeaseRentRoll.find_by_sql("select sum(lease_rent_rolls.base_rent_monthly_amount) as base_rent,sum(lease_rent_rolls.sqft) as rented_area from lease_rent_rolls,suites where lease_rent_rolls.real_estate_property_id IN (#{prop_ids.join(',')})  and lease_rent_rolls.suite_id = suites.id and lease_rent_rolls.lease_end_date >= '#{start_date}' #{end_date_string} and lease_rent_rolls.month = '#{month_val}' and lease_rent_rolls.year = #{year} and lease_rent_rolls.occupancy_type != 'new'")
        @vacant_suite = Suite.find_by_sql("select sum(suites.rentable_sqft) as current_vacant from suites where suites.status = 'Vacant' and suites.real_estate_property_id IN (#{prop_ids.join(',')}) ")
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

  def portfolio_lease_details(prop_ids)
    change_occupancy_actual,change_occupancy_budget,current_occup_pecent_actual,current_occup_pecent_budget,current_vacant_pecent_actual,current_vacant_pecent_budget = 0,0,0,0,0,0
    renewals_actual,renewals_budget,new_leases_actual,new_leases_budget,expirations_actual,expirations_budget,last_year_sf_occupied_actual,last_year_sf_occupied_budget,current_year_sf_occupied_budget,current_year_sf_vacant_actual,current_year_sf_vacant_budget,current_year_sf_occupied_actual = 0,0,0,0,0,0,0,0,0,0,0,0
    year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id IN (?) and year <= ?',prop_ids,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
    year = year.compact.empty? ? nil : year[0].year
    os = []
    properties = RealEstateProperty.where(:id => prop_ids)
    properties.each do |property|
      year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id=? and year <= ?',property.id,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
      year = year.compact.empty? ? nil : year[0].year
      os << CommercialLeaseOccupancy.find(:all,:conditions => ["real_estate_property_id=? and year = ? and month <= ?",property.id,year,get_month(year)],:order => "month desc",:limit =>1)
    end
    #    os= CommercialLeaseOccupancy.find(:all,:conditions => ["real_estate_property_id IN (?) and year = ? and month <= ?",prop_ids,year,get_month(year)],:order => "month desc")
    os.flatten! if os.present?
    prop_occup_summary = os if !os.nil? and !os.empty?
    time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id IN (?) and resource_type=? ",prop_ids, 'RealEstateProperty'])
    actual = time_line_actual
    #    lease_details_calculation
    unless prop_occup_summary.blank?
      prop_occup_summary.each do |prop_occup_summary|
        change_occupancy_actual += prop_occup_summary.new_leases_actual.to_f - prop_occup_summary.expirations_actual.to_f
        change_occupancy_budget += prop_occup_summary.new_leases_budget.to_f - prop_occup_summary.expirations_budget.to_f

        current_vacant_pecent_actual += ((prop_occup_summary.current_year_sf_vacant_actual.to_f/(prop_occup_summary.current_year_sf_occupied_actual.to_f+prop_occup_summary.current_year_sf_vacant_actual.to_f))*100).round rescue 0
        if (prop_occup_summary.current_year_sf_vacant_budget.to_f+prop_occup_summary.current_year_sf_occupied_budget.to_f) != 0.0
          current_vacant_pecent_budget += ((prop_occup_summary.current_year_sf_vacant_budget.to_f/(prop_occup_summary.current_year_sf_vacant_budget.to_f+prop_occup_summary.current_year_sf_occupied_budget.to_f))*100).round rescue 0
        else
          current_vacant_pecent_budget += 0
        end
        renewals_actual += prop_occup_summary.renewals_actual.to_f
        renewals_budget += prop_occup_summary.renewals_budget.to_f
        new_leases_actual += prop_occup_summary.new_leases_actual.to_f
        new_leases_budget += prop_occup_summary.new_leases_budget.to_f
        expirations_actual += prop_occup_summary.expirations_actual.to_f
        expirations_budget += prop_occup_summary.expirations_budget.to_f
        last_year_sf_occupied_actual += prop_occup_summary.last_year_sf_occupied_actual.to_f
        last_year_sf_occupied_budget += prop_occup_summary.last_year_sf_occupied_budget.to_f
        current_year_sf_occupied_budget += prop_occup_summary.current_year_sf_occupied_budget.to_f
        current_year_sf_vacant_actual += prop_occup_summary.current_year_sf_vacant_actual.to_f
        current_year_sf_vacant_budget += prop_occup_summary.current_year_sf_vacant_budget.to_f
        current_year_sf_occupied_actual += prop_occup_summary.current_year_sf_occupied_actual.to_f
      end
      current_occup_pecent_actual += ((current_year_sf_occupied_actual.to_f/(current_year_sf_occupied_actual.to_f + current_year_sf_vacant_actual.to_f))*100).round rescue 0
      if (current_year_sf_vacant_budget.to_f + current_year_sf_occupied_budget.to_f) != 0.0
        current_occup_pecent_budget = ((current_year_sf_occupied_budget.to_f/(current_year_sf_vacant_budget.to_f+current_year_sf_occupied_budget.to_f))*100).round rescue 0
      else
        current_occup_pecent_budget = 0
      end
      @leases={:renewals=>{:actual=>renewals_actual.to_f,:budget=>renewals_budget.to_f},
        :new_leases=>{:actual=> new_leases_actual.to_f,:budget=>new_leases_budget.to_f},
        :expirations=>{:actual=>expirations_actual.to_f,:budget=>expirations_budget.to_f},
        :change_in_occupancy=>{:actual=>change_occupancy_actual.to_f,:budget=>change_occupancy_budget.to_f},
        :prev_year_occupancy=>{:actual=>last_year_sf_occupied_actual.to_f,:budget=>last_year_sf_occupied_budget.to_f},
        :current_occupancy_percent=>{:actual=>current_occup_pecent_actual.to_f,:budget=>current_occup_pecent_budget.to_f},
        :current_vacant_percent=>{:actual=>current_vacant_pecent_actual.to_f,:budget=>current_vacant_pecent_budget.to_f},
        :current_occupancy=>{:actual=>current_year_sf_occupied_actual.to_f, :budget=>current_year_sf_occupied_budget.to_f},
        :current_vacant=>{:actual=>current_year_sf_vacant_actual.to_f, :budget=>current_year_sf_vacant_budget.to_f},
        :total_rentable_space=>{:actual=>(current_year_sf_occupied_actual.to_f + current_year_sf_vacant_actual.to_f ), :budget=>(current_year_sf_occupied_budget.to_f + current_year_sf_vacant_budget.to_f)}}
    end
  end

  def portfolio_occupancy_percent_for_month(prop_ids)
    month= Date.today.prev_month.month
    year = CommercialLeaseOccupancy.find(:all, :conditions=>['real_estate_property_id IN (?) and year <= ?',prop_ids,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1)
    year = year.compact.empty? ? nil : year[0].year
    os= CommercialLeaseOccupancy.find(:all,:conditions => ["real_estate_property_id IN (?) and year = ? and month <= ?",prop_ids,year,get_month(year)],:order => "month desc")
    occupancy_summary = os || []
    occupancy_graph ={}
    act_total,occ_diff,vac_diff,occ_act_total,occ_bud_total,vac_act_total,vac_bud_total = 0,0,0,0,0,0,0
    occupancy_summary.each do |i|
      act_total += i.current_year_sf_vacant_actual.to_f + i.current_year_sf_occupied_actual.to_f
      occ_diff += i.current_year_sf_occupied_actual.to_f - i.current_year_sf_occupied_budget.to_f
      vac_diff += i.current_year_sf_vacant_actual.to_f - i.current_year_sf_vacant_budget.to_f
      occ_act_total += i.current_year_sf_occupied_actual.to_f
      occ_bud_total += i.current_year_sf_occupied_budget.to_f
      vac_act_total += i.current_year_sf_vacant_actual.to_f
      vac_bud_total += i.current_year_sf_vacant_budget.to_f
    end if occupancy_summary.present?
    occupancy_graph[:occupied] = {:value => occ_act_total.abs,:val_percent => ((occ_act_total.abs*100)/act_total.to_f rescue 0) ,:diff => occ_diff.abs,:diff_percent =>  ((occ_diff.abs*100)/occ_bud_total.abs rescue 0) ,:style => (occ_diff >= 0 ?  "greenrow" : "redrow3" ) ,:diff_word => (occ_diff >= 0 ?  "above" : "below" ) }
    occupancy_graph[:vacant] = {:value => vac_act_total.abs,:val_percent => ((vac_act_total.abs*100)/act_total.to_f rescue 0) ,:diff => vac_diff.abs,:diff_percent =>  ((vac_diff.abs*100)/vac_bud_total.abs rescue 0) ,:style => (vac_diff >= 0 ?  "redrow2" : "greenrow" )  ,:diff_word => (vac_diff >= 0 ?  "above" : "below" )}
    return occupancy_graph
  end

  def portfolio_percentage_cals_for_bar(property_id,tot_sqft)
    suite_properties = Suite.where("suite_no is not null and real_estate_property_id=?",property_id)
    suite_all_sqft = suite_properties.sum(:rentable_sqft)
    percentagee = (suite_all_sqft.present? && suite_all_sqft!= 0.0) ? (tot_sqft * 100 ) / suite_all_sqft : 0
    sqft_percentage = "#{number_with_precision(percentagee, :precision=>2)}"
    return bar_percentage_tenants(sqft_percentage,true)
  end

  def portfolio_top_ten_tenants(property_collection)
    portfolio_top_ten_tenants = []
    property_collection.each do |property|
      top_tenants, top_ten_tenants = RealEstateProperty.top_tenants_from_lease_rent_roll(property)
      portfolio_top_ten_tenants <<  top_ten_tenants
    end
    portfolio_top_ten_tenants=portfolio_top_ten_tenants.flatten!.select{|x| x.lease_rent_roll_sqft.present?}
    portfolio_top_ten_tenants = portfolio_top_ten_tenants.sort_by{|e| e[:lease_rent_roll_sqft].to_f }.reverse.first(10)
  end

  def portfolio_top_ten_expiration(property_collection)
    portfolio_top_ten_expirations = []
    property_collection.each do |property|
      upcoming_expiration_leases = RealEstateProperty.find_Upcoming_ten_Expirations(property)
      portfolio_top_ten_expirations  <<  upcoming_expiration_leases
    end
    portfolio_top_ten_expirations = portfolio_top_ten_expirations.flatten!.select{|x| x.lease_rent_roll_sqft.present?}
    portfolio_top_ten_expirations = portfolio_top_ten_expirations.sort_by{|e| e[:lease_end_date] }.first(10)
  end


  def find_nego_and_inter(property_collection)
    property_lease_suites_negotiated,property_lease_suites_interested = [],[]
    property_collection.each do |note_collection|
      interested_and_negotiated_leases(note_collection.id,nil,nil)
      property_lease_suites_negotiated << @property_lease_suites_negotiated
      property_lease_suites_interested << @property_lease_suites_interested
    end
    property_lease_suites_negotiated.flatten!.try(:compact!)
    property_lease_suites_interested.flatten!.try(:compact!)
    return property_lease_suites_negotiated,property_lease_suites_interested
  end

  def occupancy_start_of_year(real_ids)
    occ_lease_records = LeaseRentRoll.find(:all,:conditions=>["(real_estate_property_id IN (#{real_ids}) and month = '12' AND year = #{Date.today.prev_year.year})"])
    occ_suite_ids = occ_lease_records.collect{|record| record.suite_id}       if occ_lease_records.present?
    occ_rentable_sqft = Suite.find_by_sql("select sum(suites.rentable_sqft) as occupied from suites where suites.real_estate_property_id IN (#{real_ids}) and suites.id IN (#{occ_suite_ids.join(',')})") if occ_suite_ids.present?
    occ_rentable_sqft
  end

  def new_lease_not_commenced(real_ids)
    suites = Suite.find(:all, :conditions=>['real_estate_property_id IN (?)', real_ids]).map(&:id) if real_ids.present?
    year = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and  year <= ?',suites,Date.today.year],:select=>"year",:order=>"year desc",:limit=>1) if suites.present?
    if year
      year = year.compact.empty? ? nil : year[0].year
      month = LeaseRentRoll.find(:all, :conditions=>['suite_id IN (?) and year = ? and month <= ?',suites,year,get_month(year)],:select=>"month").map(&:month).max if suites.present?
    end
    lease_records = LeaseRentRoll.find(:all,:conditions=>["(occupancy_type = 'new' or occupancy_type = 'current') and lease_start_date > '#{Date.today.year}-#{Date.today.month}-31' and real_estate_property_id IN (#{real_ids}) and month = '#{month}' AND year = #{year}"]) if month.present? && year.present?
    lease_records
  end

  #for dashboard time line start
  def find_time_line_start(date_array,selected_time_line, next_button_status_disabled=true)
    total_set=date_array.each_slice(12).to_a
    total_set.each do |set|
      if selected_time_line >= 2 && next_button_status_disabled.eql?("true")
        @start_date = 3
      else
        if set.include?(date_array[selected_time_line])
          start_date=set[0]
          @start_date = date_array.index(start_date) - 1
        end
      end
    end
    return @start_date
  end

  def find_graph_month(key)
    graph_month={"Jan" => 1,"Feb" => 2,"Mar" => 3 ,"Apr" => 4,"May" => 5, "Jun" => 6,"Jul" => 7,"Aug" => 8, "Sep" => 9,"Oct" => 10,"Nov" => 11, "Dec" => 12}
    return graph_month[key]
  end

  def trend_operating_trend_graph
    #    if session[:portfolio__id].present?  && !session[:property__id].present?
    #      @note = Portfolio.find_by_id(session[:portfolio__id])
    #      @resource = "'Portfolio'"
    #    else
    #      @note = RealEstateProperty.find_real_estate_property(session[:property__id]) if session[:property__id].present?
    #      @resource = "'RealEstateProperty'"
    #    end
    find_dashboard_portfolio_display
    if params[:tl_period] == "4" ||  params[:tl_period] == "3"
      trend_ytd_and_prev_year
    elsif params[:tl_period] == "11"
      find_trailing_data_display
    end
  end

  def trend_ytd_and_prev_year
    calc_for_financial_data_display
    params[:tl_year] = params[:tl_period] == "4" ? @financial_year : Date.today.prev_year.year
    @month =[]
    @month_array,@month_array_string,@prev_month,@prev_month_array,@prev_month_array_string = [],[],[],[],[]
    months = ["","january","february","march","april","may","june","july","august","september","october","november","december"]
    month_string = ["","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
    if params[:tl_period] == "4"
      for i in 1..@financial_month.to_i do
        @month << "sum(" + "f."+ "#{months[i]}" + ")" + "as" + " '#{month_string[i]}'"
        @month_array << month_string[i]
        @month_array_string << month_string[i]+'-'+Date.today.strftime('%y')
      end
      for i in 1..12 do
        @prev_month << "sum(" + "f."+ "#{months[i]}" + ")" + "as" + " '#{month_string[i]}'"
        @prev_month_array << month_string[i]
        @prev_month_array_string << month_string[i]+'-'+Date.today.strftime('%y')
      end
    elsif  params[:tl_period] == "3"
      #    if  params[:tl_period] == "3" || params[:tl_period] == "4"
      for i in 1..12 do
        @month << "sum(" + "f."+ "#{months[i]}" + ")" + "as" + " '#{month_string[i]}'"
        @month_array << month_string[i]
        @month_array_string << month_string[i]+'-'+Date.today.prev_year.strftime('%y')
      end
    end
        financial_title = find_financial_title
    #    qry1 =   "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title}) or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{params[:tl_year]} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title" if @month.present? && @note.present?
    #    qry1 = get_query_for_financial_sub_page(@using_sub_id,2011,false)
    if @financial_sub.eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
#       financial_title = "'recoverable expenses detail','non-recoverable expenses detail'"
      @operating_trend,@operating_trend1,@operating_trend_budget,@operating_trend_budget1 = {},{},{},{}
       year = params[:tl_year].present? ? params[:tl_year] : Date.today.year
      qry1 =   "SELECT k.title as Parent, a.title as Title,#{params[:tl_period].eql?("3") ? @month.join(",") : @prev_month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{year - 1} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
      asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present?
      @operating_trend3 = {}
      if asset_details1.present?
        for cash_row in asset_details1
          if cash_row.Title	!= nil
            @operating_trend3[cash_row.Title] =  form_hash_of_data_values(cash_row)
          end
        end
      end
      qry =  "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title" 
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry) if qry.present?
      @operating_trend2 = {}
      if asset_details.present?
        for cash_row in asset_details
          if cash_row.Title	!= nil
            @operating_trend2[cash_row.Title] =  form_hash_of_data_values(cash_row)
          end
        end
      end
      qry3 =   "SELECT k.title as Parent, a.title as Title,#{params[:tl_period].eql?("3") ? @month.join(",") : @prev_month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('b') AND a.year=#{year - 1} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
      asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry3) if qry3.present?
      @operating_trend_budget3 = {}
      if asset_details1.present?
        for cash_row in asset_details1
          if cash_row.Title	!= nil
            @operating_trend_budget3[cash_row.Title] =  form_hash_of_data_values(cash_row)
          end
        end
      end
      qry2 =  "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') or (a.parent_id is null)) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
      asset_details = IncomeAndCashFlowDetail.find_by_sql(qry2) if qry2.present?
      @operating_trend_budget2 = {}
      if asset_details.present?
        for cash_row in asset_details
          if cash_row.Title	!= nil
            @operating_trend_budget2[cash_row.Title] =  form_hash_of_data_values(cash_row)
          end
        end
      end
      title_exp = map_title("operating expenses")
      if (@operating_trend2['recoverable expenses detail'].present? || @operating_trend3['recoverable expenses detail'].present? ) || (@operating_trend2['non-recoverable expenses detail'].present? || @operating_trend3['non-recoverable expenses detail'].present?)
        @operating_trend['operating expenses'] = (@operating_trend2['recoverable expenses detail'].present? && @operating_trend2['non-recoverable expenses detail'].present?) ? @operating_trend2['recoverable expenses detail'].merge(@operating_trend2['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend2['recoverable expenses detail'].present? ? @operating_trend2['recoverable expenses detail']  : @operating_trend2['non-recoverable expenses detail'].present? ?  @operating_trend2['non-recoverable expenses detail'] : ""
        @operating_trend1['operating expenses'] = (@operating_trend3['recoverable expenses detail'].present? && @operating_trend3['non-recoverable expenses detail'].present?) ? @operating_trend3['recoverable expenses detail'].merge(@operating_trend3['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend3['recoverable expenses detail'].present? ? @operating_trend3['recoverable expenses detail']  : @operating_trend3['non-recoverable expenses detail'].present? ?  @operating_trend3['non-recoverable expenses detail'] : ""
      end
      if (@operating_trend_budget2['recoverable expenses detail'].present? || @operating_trend_budget3['recoverable expenses detail'].present? ) || (@operating_trend_budget2['non-recoverable expenses detail'].present? || @operating_trend_budget3['non-recoverable expenses detail'].present?)
        @operating_trend_budget['operating expenses'] = (@operating_trend_budget2['recoverable expenses detail'].present? && @operating_trend_budget2['non-recoverable expenses detail'].present?) ? @operating_trend_budget2['recoverable expenses detail'].merge(@operating_trend_budget2['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend_budget2['recoverable expenses detail'].present? ? @operating_trend_budget2['recoverable expenses detail']  : @operating_trend_budget2['non-recoverable expenses detail'].present? ?  @operating_trend_budget2['non-recoverable expenses detail'] : ""
        @operating_trend_budget1['operating expenses'] = (@operating_trend_budget3['recoverable expenses detail'].present? && @operating_trend_budget3['non-recoverable expenses detail'].present?) ? @operating_trend_budget3['recoverable expenses detail'].merge(@operating_trend_budget3['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend_budget3['recoverable expenses detail'].present? ? @operating_trend_budget3['recoverable expenses detail']  : @operating_trend_budget3['non-recoverable expenses detail'].present? ?  @operating_trend_budget3['non-recoverable expenses detail'] : ""
      end
    else
      parent = @financial_sub_id
      last_year_parent = @last_year_financial_sub_id
      if parent.present?
        qry = "select parent_id from income_and_cash_flow_details where parent_id=#{parent}"
        asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
        string = (asset_details.present? && asset_details.first.parent_id.present?) ? "a.parent_id" : "a.id"
      end
      year = params[:tl_year].present? ? params[:tl_year] : Date.today.year
      @operating_trend,@operating_trend1,@operating_trend_budget,@operating_trend_budget1 = {},{},{},{}
      if params[:tl_period].eql?("4")
        qry1 =   "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{parent} AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'"
        qry2 =   "SELECT k.title as Parent, a.title as Title,#{@prev_month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{last_year_parent} AND f.pcb_type IN ('c') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'"
        qry3 =   "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{parent} AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'"
        qry4 =   "SELECT k.title as Parent, a.title as Title,#{@prev_month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{last_year_parent} AND f.pcb_type IN ('b') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'"
        asset_details = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present?
        asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry2) if qry2.present? && last_year_parent.present?
        if asset_details.present?
          for cash_row in asset_details
            @operating_trend[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
          end
        end
        if asset_details1.present?
          for cash_row in asset_details1
            @operating_trend1[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
          end
        end if last_year_parent.present?
        asset_details_budget = IncomeAndCashFlowDetail.find_by_sql(qry3) if qry3.present?
        asset_details_budget1 = IncomeAndCashFlowDetail.find_by_sql(qry4) if qry4.present? && last_year_parent.present?
        if asset_details_budget.present?
          for cash_row in asset_details_budget
            @operating_trend_budget[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
          end
        end
        if asset_details_budget1.present?
          for cash_row in asset_details_budget1
            @operating_trend_budget1[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
          end
        end if last_year_parent.present?
      else
        qry1 =   "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{last_year_parent} AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'"
        qry2 =   "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{last_year_parent} AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'"
        asset_details = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present? && last_year_parent.present?
        asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry2) if qry2.present? && last_year_parent.present?
        @operating_trend,@operating_trend1 = {},{}
        if asset_details.present?
          for cash_row in asset_details
            @operating_trend[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
          end
        end if last_year_parent.present?
        if asset_details1.present?
          for cash_row in asset_details1
            @operating_trend1[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
          end
        end if last_year_parent.present?
        second_last_year = @second_last_year_financial_sub_id
        qry3 =   "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{second_last_year} AND f.pcb_type IN ('c') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'"
        qry4 =   "SELECT k.title as Parent, a.title as Title,#{@month.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{second_last_year} AND f.pcb_type IN ('b') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'"
        second_asset_details = IncomeAndCashFlowDetail.find_by_sql(qry3) if qry3.present? && second_last_year.present?
        second_asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry4) if qry4.present? && second_last_year.present?
        @second_last_operating_trend,@second_last_operating_trend1 = {},{}
        if second_asset_details.present?
          for cash_row in second_asset_details
            @second_last_operating_trend[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
          end
        end if second_last_year.present?
        if second_asset_details1.present?
          for cash_row in second_asset_details1
            @second_last_operating_trend1[cash_row.Title] =  form_hash_of_data_values(cash_row) if cash_row.Title	!= nil
          end
        end if second_last_year.present?
      end if parent.present?
    end
  end

  def trend_drop_down(sub,port_id,prop_id,title)
    tmp_period = params[:tl_period]
    params[:tl_period] = "4"
    find_financial_sub_items(sub)
#    params[:tl_period] = tmp_period
    if (session[:property__id].present? && session[:portfolio__id].blank?)
      sub_tag =  "<li> #{link_to sub.gsub(' detail','').titleize, property_trends_path(port_id, prop_id, :selected_link => sub,:tl_period => params[:tl_period],:parent_title => title), :remote => true,:onclick => "close_nodes(this)"}#{trend_drop_down_next_level(@asset_details,port_id,prop_id,title)}</li>"
    else
      sub_tag =  "<li> #{link_to sub.gsub(' detail','').titleize, portfolio_trends_path(port_id,:selected_link => sub,:tl_period => params[:tl_period],:parent_title => title), :remote => true,:onclick => "close_nodes(this)"}#{trend_drop_down_next_level(@asset_details,port_id,prop_id,title)}</li>"
    end
    params[:tl_period] = tmp_period
    raw sub_tag
  end

  def trend_drop_down_next_level(asset,port_id,prop_id,title)
    sub_tag = ""
    if (session[:property__id].present? && session[:portfolio__id].blank?)
      asset.each do |asset_detail|
        find_financial_sub_items(asset_detail.Title)
        if @asset_details.present?
          sub_tag += "<ul><li> #{link_to asset_detail.Title.gsub(' detail','').titleize, property_trends_path(port_id, prop_id, :selected_link => asset_detail.Title,:tl_period => params[:tl_period],:parent_title => title), :remote => true,:onclick => "close_nodes(this)"}#{trend_drop_down_next_level1(@asset_details,port_id,prop_id,title)}</li></ul>"
        else
          sub_tag += "<ul><li> #{link_to asset_detail.Title.gsub(' detail','').titleize, property_trends_path(port_id, prop_id, :selected_link => asset_detail.Title,:tl_period => params[:tl_period],:parent_title => title), :remote => true,:onclick => "close_nodes(this)"} </li></ul>"
        end
      end
    else
      asset.each do |asset_detail|
        find_financial_sub_items(asset_detail.Title)
        if @asset_details.present?
          sub_tag += "<ul><li> #{link_to asset_detail.Title.gsub(' detail','').titleize, portfolio_trends_path(port_id,:selected_link => asset_detail.Title,:tl_period => params[:tl_period],:parent_title => title), :remote => true,:onclick => "close_nodes(this)"}#{trend_drop_down_next_level1(@asset_details,port_id,prop_id,title)}</li></ul>"
        else
          sub_tag += "<ul><li> #{link_to asset_detail.Title.gsub(' detail','').titleize, portfolio_trends_path(port_id,:selected_link => asset_detail.Title,:tl_period => params[:tl_period],:parent_title => title), :remote => true,:onclick => "close_nodes(this)"} </li></ul>"
        end
      end
    end
    sub_tag
  end
  def trend_drop_down_next_level1(asset,port_id,prop_id,title)
    sub_tag = ""
    if (session[:property__id].present? && session[:portfolio__id].blank?)
      asset.each do |asset_detail|
        sub_tag += "<ul><li> #{link_to asset_detail.Title.gsub(' detail','').titleize, property_trends_path(port_id, prop_id, :selected_link => asset_detail.Title,:tl_period => params[:tl_period],:parent_title => title), :remote => true,:onclick => "close_nodes(this)"} </li></ul>"
      end
    else
      asset.each do |asset_detail|
        sub_tag += "<ul><li> #{link_to asset_detail.Title.gsub(' detail','').titleize, portfolio_trends_path(port_id,:selected_link => asset_detail.Title,:tl_period => params[:tl_period],:parent_title => title), :remote => true,:onclick => "close_nodes(this)"} </li></ul>"
      end
    end
    sub_tag
  end

  def breadcrumb_in_trend(title,ids,port_id,prop_id)
    arr = []
    a = {"income detail" => "Operating Revenue"}
    start_string = "<div class=\"breadcrumbs5\">"
    end_string = "</div>"
    base = ""
    if ids.present?
      income=IncomeAndCashFlowDetail.find_by_id(ids)
      while(income and  income.parent_id.present?)
        arr << [income.title,income.id]
        income = IncomeAndCashFlowDetail.find_by_id(income.parent_id)
      end
      arr << ["Operating Expenses", 0] if params[:parent_title].eql?("expense") && title != 'Operating Expenses' && ids.present? && @note.present? && @note.leasing_type == "Commercial"
      last_element = arr.first
      for ar1 in arr.reverse
        if arr.count.eql?(1)
          if is_commercial(@note)
            base = "<span class=\"breadcrumbsSel\">#{a[ar1[0]].present? ? a[ar1[0]] : ar1[0].eql?('net operating income') ? "Non Operating Expense": ar1[0].gsub(' detail','').titleize} ></span>"
          else
            base = "<span class=\"breadcrumbsSel\">#{a[ar1[0]].present? ? a[ar1[0]] : ar1[0].eql?('other income and expense') ? "Non Operating Expense": ar1[0].gsub(' detail','').titleize} ></span>"
          end
        else
          if ar1[1].eql?(last_element[1])
            if is_commercial(@note)
              base = base + "<span class=\"breadcrumbsSel\">#{ar1[0].eql?('net operating income') ? "Non Operating Expense": ar1[0].gsub(' detail','').titleize}</span>"
            else
              base = base + "<span class=\"breadcrumbsSel\">#{ar1[0].eql?('other income and expense') ? "Non Operating Expense": ar1[0].gsub(' detail','').titleize}</span>"
            end
          else

            if (session[:property__id].present? && session[:portfolio__id].blank?)
              if is_commercial(@note)
            
                base = base + "<a onclick=\"trends_dropdown_change('#{a[ar1[0]].present? ? a[ar1[0]].gsub("'", "\\\\'") : ar1[0].gsub("'", "\\\\'").titleize}','#{port_id}','#{prop_id}','#{params[:tl_period]}','#{params[:parent_title]}')\"> #{a[ar1[0]].present? ? a[ar1[0]] : ar1[0].eql?('net operating income') ? "Non Operating Expense": ar1[0].gsub(' detail','').titleize}</a><span class=\"breadcrumbsSel\"> > </span>"
              else
                base = base + "<a onclick=\"trends_dropdown_change('#{a[ar1[0]].present? ? a[ar1[0]].gsub("'", "\\\\'") : ar1[0].gsub("'", "\\\\'").titleize}','#{port_id}','#{prop_id}','#{params[:tl_period]}','#{params[:parent_title]}')\"> #{a[ar1[0]].present? ? a[ar1[0]] : ar1[0].eql?('other income and expense') ? "Non Operating Expense": ar1[0].gsub(' detail','').titleize}</a><span class=\"breadcrumbsSel\"> > </span>"
              end
            else
              if is_commercial(@note)
                base = base + "<a onclick=\"trends_dropdown_change('#{a[ar1[0]].present? ? a[ar1[0]].gsub("'", "\\\\'") : ar1[0].gsub("'", "\\\\'").titleize}','#{port_id}','#{prop_id}','#{params[:tl_period]}','#{params[:parent_title]}')\"> #{a[ar1[0]].present? ? a[ar1[0]] : ar1[0].eql?('net operating income') ? "Non Operating Expense": ar1[0].gsub(' detail','').titleize}</a><span class=\"breadcrumbsSel\"> > </span>"
              else
                base = base + "<a onclick=\"trends_dropdown_change('#{a[ar1[0]].present? ? a[ar1[0]].gsub("'", "\\\\'") : ar1[0].gsub("'", "\\\\'").titleize}','#{port_id}',#{prop_id}','#{params[:tl_period]}','#{params[:parent_title]}')\"> #{a[ar1[0]].present? ? a[ar1[0]] : ar1[0].eql?('other income and expense') ? "Non Operating Expense": ar1[0].gsub(' detail','').titleize}</a><span class=\"breadcrumbsSel\"> > </span>"
              end
            end
          end
        end

      end
      #      base = start_string + base + end_string
    end
    base = "<span class=\"breadcrumbsSel\">Operating Expenses ></span>" if title.eql?("Operating Expenses") && ids.blank? && @note.present? && @note.leasing_type == "Commercial"
    base = start_string + base + end_string
    return base
  end

  def find_financial_details
    actual,budget =[],[]
    values = (@operating_trend.present? && @operating_trend["#{@operating_trend.keys.first}"].present?) ? @operating_trend["#{@operating_trend.keys.first}"].values.compact : []
    values = values.map(&:to_i)
    values1 = (@operating_trend1.present? && @operating_trend1["#{@operating_trend1.keys.first}"].present?) ? @operating_trend1["#{@operating_trend1.keys.first}"].values.compact : []
    values << values1.map(&:to_i) if params[:tl_period] != "4" &&  params[:tl_period] != "3"
    values3 = (@operating_trend_budget.present? && @operating_trend_budget["#{@operating_trend_budget.keys.first}"].present?) ? @operating_trend_budget["#{@operating_trend_budget.keys.first}"].values.compact : []
    values3 = values3.map(&:to_i)
    values4 = (@operating_trend_budget1.present? && @operating_trend_budget1["#{@operating_trend_budget1.keys.first}"].present?) ? @operating_trend_budget1["#{@operating_trend_budget1.keys.first}"].values.compact : []
    values3 << values4.map(&:to_i) if params[:tl_period] != "4" &&  params[:tl_period] != "3"
    if params[:tl_period] == "3"
      if @financial_sub.eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
        actual = values.flatten.compact
        budget = values3.flatten.compact
      else
        actual = values.flatten.compact
        budget = values1.flatten.compact
      end
    else
      actual = values.flatten.compact
      budget = values3.flatten.compact
    end

    actuals = actual.map(&:to_i).sum
    budgets = budget.map(&:to_i).sum
    variance = budgets - actuals
    percentage = (variance.to_f / budgets.to_f)*100 rescue ZeroDivisionError
    return actuals,budgets,variance,percentage
  end

   def month_name_data_values(cash_row)
    @val = {"January"=> cash_row.attributes['January'] ? cash_row.attributes['January'] : 0,
      "February"=> cash_row.attributes['February'] ?  cash_row.attributes['February'] : 0,
      "March"=> cash_row.attributes['March']  ?  cash_row.attributes['March'] : 0,
      "April"=> cash_row.attributes['April'] ? cash_row.attributes['April'] : 0,
      "May"=> cash_row.attributes['May'] ?  cash_row.attributes['May'] : 0,
      "June"=> cash_row.attributes['June'] ?  cash_row.attributes['June'] : 0,
      "July"=>cash_row.attributes['July'] ? cash_row.attributes['July'] : 0,
      "August"=> cash_row.attributes['August']  ? cash_row.attributes['August'] : 0,
      "September"=> cash_row.attributes['September']  ? cash_row.attributes['September'] : 0,
      "October"=> cash_row.attributes['October'] ? cash_row.attributes['October'] : 0,
      "November"=> cash_row.attributes['November'] ? cash_row.attributes['November'] : 0,
      "December"=>cash_row.attributes['December'] ? cash_row.attributes['December'] : 0
    }
  end

   def performance_analysis_trailing(cur_year,prev_year,type=nil)
     months = ["","january","february","march","april","may","june","july","august","september","october","november","december"]
     month_string = ["","January","February","March","April","May","June","July","August","September","October","November","December"]
     @year_growth_month = ["January","February","March","April","May","June","July","August","September","October","November","December"]
     @performance_array,@performance_array_string = [],[]
     @operating_trend = {}
     @performance_month = {}
     @performance_month_val = {}
     month_val = []
     month_name = []
     calc_for_financial_data_display
     cur_year_days = Date.leap?(DateTime.now .year) ? 366 : 365
     month_format = type.present? ? @month_format.prev_year : @month_format
     for i in  (month_format - cur_year_days).month..12 do
       @performance_array << month_string[i]
       @performance_array_string << month_string[i]+'-'+"#{prev_year.strftime('%y')}"
       month_val << "sum(" + "f."+ "#{months[i]}" + ")" + "as" + " '#{month_string[i]}'"
       @performance_month = {(month_format - cur_year_days).year =>  month_val.uniq }
       if i == 12
         for j in 1..@financial_month.to_i do
           @performance_array << month_string[j]
           @performance_array_string << month_string[j]+'-'+"#{cur_year.strftime('%y')}"
           month_name << "sum("+ "f."+ "#{months[j] }" +")" + "as" + " '#{month_string[j] }'"
           @performance_month_val = {cur_year.year =>  month_name.uniq}

         end
       end
     end
     @performance_trend_budget,@performance_trend_budget1 = {},{}
     tmp_period = params[:tl_period]
     tmp_year = params[:tl_year]
     params[:tl_period] = "3"
     params[:tl_year] = type.present? ? Date.today.prev_year.prev_year.year : Date.today.prev_year.year
     find_financial_sub_items(map_title(@financial_sub))
     @last_year_financial_sub_id = params[:financial_subid]
     @last_year_financial_sub = params[:financial_sub]
     #     params[:tl_period] = tmp_period
     params[:tl_year] = type.present? ? Date.today.prev_year.year : Date.today.year
     find_financial_sub_items(map_title(@financial_sub))
     @financial_sub_id = params[:financial_subid]
     @financial_sub = params[:financial_sub]
     params[:tl_year] = tmp_year
     params[:tl_period] = tmp_period
     parent = params[:financial_subid]
     last_year_parent = @last_year_financial_sub_id
     year = type.present? ? Date.today.prev_year.year : Date.today.year
     if @financial_sub.eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
       financial_title = "'recoverable expenses detail','non-recoverable expenses detail'"
       @performance_trend,@performance_trend1,@performance_trend_budget,@performance_trend_budget1 = {},{},{},{}
       qry1 =   "SELECT k.title as Parent, a.title as Title,#{@performance_month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}')) AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
       asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present?
       if asset_details1.present?
         for cash_row in asset_details1
           if cash_row.Title	!= nil
             @performance_trend[cash_row.Title] =  month_name_data_values(cash_row)
           end
         end
       end
       qry2 =   "SELECT k.title as Parent, a.title as Title,#{@performance_month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(a.title,'\\'','') IN ('#{financial_title.gsub("'","")}')) AND f.pcb_type IN ('c') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
       asset_details2 = IncomeAndCashFlowDetail.find_by_sql(qry2) if qry2.present?
       if asset_details2.present?
         for cash_row in asset_details2
           if cash_row.Title	!= nil
             @performance_trend1[cash_row.Title] =  month_name_data_values(cash_row)
           end
         end
       end
       qry3 =   "SELECT k.title as Parent, a.title as Title,#{@performance_month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (k.title IN (#{financial_title})) AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
       asset_details3 = IncomeAndCashFlowDetail.find_by_sql(qry3) if qry3.present?
       if asset_details3.present?
         for cash_row in asset_details3
           if cash_row.Title	!= nil
             @performance_trend_budget[cash_row.Title] =  month_name_data_values(cash_row)
           end
         end
       end
       qry4 =   "SELECT k.title as Parent, a.title as Title,#{@performance_month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND (REPLACE(a.title,'\\'','') IN ('#{financial_title.gsub("'","")}')) AND f.pcb_type IN ('b') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'  group by Parent, Title"
       asset_details4 = IncomeAndCashFlowDetail.find_by_sql(qry4) if qry4.present?
       if asset_details4.present?
         for cash_row in asset_details4
           if cash_row.Title	!= nil
             @performance_trend_budget1[cash_row.Title] =  month_name_data_values(cash_row)
           end
         end
       end
       
       
#       title_exp = map_title("operating expenses")
#       if (@operating_trend2['recoverable expenses detail'].present? || @operating_trend3['recoverable expenses detail'].present? ) || (@operating_trend2['non-recoverable expenses detail'].present? || @operating_trend3['non-recoverable expenses detail'].present?)
#         @operating_trend['operating expenses'] = (@operating_trend2['recoverable expenses detail'].present? && @operating_trend2['non-recoverable expenses detail'].present?) ? @operating_trend2['recoverable expenses detail'].merge(@operating_trend2['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend2['recoverable expenses detail'].present? ? @operating_trend2['recoverable expenses detail']  : @operating_trend2['non-recoverable expenses detail'].present? ?  @operating_trend2['non-recoverable expenses detail'] : ""
#         @operating_trend1['operating expenses'] = (@operating_trend3['recoverable expenses detail'].present? && @operating_trend3['non-recoverable expenses detail'].present?) ? @operating_trend3['recoverable expenses detail'].merge(@operating_trend3['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend3['recoverable expenses detail'].present? ? @operating_trend3['recoverable expenses detail']  : @operating_trend3['non-recoverable expenses detail'].present? ?  @operating_trend3['non-recoverable expenses detail'] : ""
#       end
#       if (@operating_trend_budget2['recoverable expenses detail'].present? || @operating_trend_budget3['recoverable expenses detail'].present? ) || (@operating_trend_budget2['non-recoverable expenses detail'].present? || @operating_trend_budget3['non-recoverable expenses detail'].present?)
#         @operating_trend_budget['operating expenses'] = (@operating_trend_budget2['recoverable expenses detail'].present? && @operating_trend_budget2['non-recoverable expenses detail'].present?) ? @operating_trend_budget2['recoverable expenses detail'].merge(@operating_trend_budget2['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend_budget2['recoverable expenses detail'].present? ? @operating_trend_budget2['recoverable expenses detail']  : @operating_trend_budget2['non-recoverable expenses detail'].present? ?  @operating_trend_budget2['non-recoverable expenses detail'] : ""
#         @operating_trend_budget1['operating expenses'] = (@operating_trend_budget3['recoverable expenses detail'].present? && @operating_trend_budget3['non-recoverable expenses detail'].present?) ? @operating_trend_budget3['recoverable expenses detail'].merge(@operating_trend_budget3['non-recoverable expenses detail']) {|key,val1,val2| val1.to_f + val2.to_f } : @operating_trend_budget3['recoverable expenses detail'].present? ? @operating_trend_budget3['recoverable expenses detail']  : @operating_trend_budget3['non-recoverable expenses detail'].present? ?  @operating_trend_budget3['non-recoverable expenses detail'] : ""
#       end
     else
       qry = "select parent_id,title from income_and_cash_flow_details where parent_id=#{parent}"
       if parent.present?
         asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
         string = (asset_details.blank? || asset_details.first.parent_id.blank?) ? "a.id" : "a.parent_id"
       end
       @performance_trend,@performance_trend1 = {},{}
       if parent.present?
         qry1 =   "SELECT k.title as Parent, a.title as Title,#{@performance_month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{parent} AND f.pcb_type IN ('c') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'"
         qry2 =   "SELECT k.title as Parent, a.title as Title,#{@performance_month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{last_year_parent} AND f.pcb_type IN ('c') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'"
         qry3 =   "SELECT k.title as Parent, a.title as Title,#{@performance_month_val.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{parent} AND f.pcb_type IN ('b') AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail'"
         qry4 =   "SELECT k.title as Parent, a.title as Title,#{@performance_month.values.join(",")}  FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.id} AND a.resource_type = #{@resource} AND #{string} =#{last_year_parent} AND f.pcb_type IN ('b') AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail'"
         asset_details = IncomeAndCashFlowDetail.find_by_sql(qry1) if qry1.present?
         asset_details1 = IncomeAndCashFlowDetail.find_by_sql(qry2) if qry2.present? && last_year_parent.present?
         if asset_details.present?
           for cash_row in asset_details
             @performance_trend[cash_row.Title] =  month_name_data_values(cash_row) if cash_row.Title	!= nil
           end
         end
         if asset_details1.present?
           for cash_row in asset_details1
             @performance_trend1[cash_row.Title] =  month_name_data_values(cash_row) if cash_row.Title	!= nil
           end
         end if last_year_parent.present?
         asset_details_budget = IncomeAndCashFlowDetail.find_by_sql(qry3) if qry3.present?
         asset_details_budget1 = IncomeAndCashFlowDetail.find_by_sql(qry4) if qry4.present? && last_year_parent.present?
         if asset_details_budget.present?
           for cash_row in asset_details_budget
             @performance_trend_budget[cash_row.Title] =  month_name_data_values(cash_row) if cash_row.Title	!= nil
           end
         end
         if asset_details_budget1.present?
           for cash_row in asset_details_budget1
             @performance_trend_budget1[cash_row.Title] =  month_name_data_values(cash_row) if cash_row.Title	!= nil
           end
         end if last_year_parent.present?
       end
     end
   end

   def find_month_val(month)
     month_hash = {"January"=> 1,"February"=>2,"March" =>3,"April" => 4,"May" => 5,"June" => 6,"July" =>7,"August" =>8,"September" =>9,"October" =>10,"November"=>11,"December" =>12}
     return "#{month_hash[month.split('-')[0]]}"
  end


   def trend_performance_calc()
     financial_sub_id,cur_year_actuals,cur_year_budget = @financial_sub_id,0,0
     if params[:tl_period] == "11"
       performance_analysis_trailing(Date.today,Date.today.prev_year)
       months = @performance_array_string
       if @financial_sub.eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
         cur_year_tmp_hash_a,prev_year_tmp_hash_a,cur_year_tmp_hash_b,prev_year_tmp_hash_b = {},{},{},{}
         cur_year_tmp_a = @performance_trend.present? ? @performance_trend.values.inject{|m, el| m.merge( el ){|k, old_v, new_v| old_v.to_i + new_v.to_i}} : []
         prev_year_tmp_a = @performance_trend1.present? ? @performance_trend1.values.inject{|m, el| m.merge( el ){|k, old_v, new_v| old_v.to_i + new_v.to_i}} : []
         cur_year_tmp_hash_a["Operating Expenses"] = cur_year_tmp_a if cur_year_tmp_a.present?
         prev_year_tmp_hash_a["Operating Expenses"] = prev_year_tmp_a if prev_year_tmp_a.present?
         cur_year_tmp_b = @performance_trend_budget.present? ? @performance_trend_budget.values.inject{|m, el| m.merge( el ){|k, old_v, new_v| old_v.to_i + new_v.to_i}} : []
         prev_year_tmp_b = @performance_trend_budget1.present? ? @performance_trend_budget1.values.inject{|m, el| m.merge( el ){|k, old_v, new_v| old_v.to_i + new_v.to_i}} : []
         cur_year_tmp_hash_b["Operating Expenses"] = cur_year_tmp_b if cur_year_tmp_b.present?
         prev_year_tmp_hash_b["Operating Expenses"] = prev_year_tmp_b if prev_year_tmp_b.present?
         @performance_trend,@performance_trend1 = {},{}
         @performance_trend,@performance_trend1,@performance_trend_budget,@performance_trend_budget1 = cur_year_tmp_hash_a,prev_year_tmp_hash_a,cur_year_tmp_hash_b,prev_year_tmp_hash_b
       end
       cur_year_actuals = (@performance_trend.present? ? @performance_trend["#{@performance_trend.keys.first}"].values.map(&:to_i) : []) + (@performance_trend1.present? ? @performance_trend1["#{@performance_trend1.keys.first}"].values.map(&:to_i) : [])
       cur_year_budget = ( @performance_trend_budget.present? ? @performance_trend_budget["#{@performance_trend_budget.keys.first}"].values.map(&:to_i) : [] ) + (@performance_trend_budget1.present? ? @performance_trend_budget1["#{@performance_trend_budget1.keys.first}"].values.map(&:to_i) : [])
       cur_year_actuals = cur_year_actuals.flatten.compact.sum
       cur_year_budget = cur_year_budget.flatten.compact.sum
     else
       actual_pcb_type,budget_pcb_type = find_pcb_type
       financial_title = "'#{@financial_sub}'"
       @resource = "#{@resource}"
       months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
       year = params[:tl_year].present? ? params[:tl_year] : Date.today.year
       if (@financial_sub.strip).eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
         calc_for_financial_data_display
         financial_title = "'recoverable expenses detail','non-recoverable expenses detail'"
         asset_details_cur_year = {}
         year = params[:tl_year].present? ? params[:tl_year] : Date.today.year
         qry = "select Parent, Title, sum(January_actuals) as January_actuals,  sum(February_actuals) as February_actuals,sum(March_actuals) as March_actuals,sum(April_actuals) as April_actuals,sum(May_actuals) as May_actuals,sum(June_actuals) as June_actuals,sum(July_actuals) as July_actuals,sum(August_actuals) as August_actuals,sum(September_actuals) as September_actuals,sum(October_actuals) as October_actuals,sum(November_actuals) as November_actuals,sum(December_actuals) as December_actuals,sum(January_budget) as January_budget,  sum(February_budget) as February_budget,sum(March_budget) as March_budget,sum(April_budget) as April_budget,sum(May_budget) as May_budget,sum(June_budget) as June_budget,sum(July_budget) as July_budget,sum(August_budget) as August_budget,sum(September_budget) as September_budget,sum(October_budget) as October_budget,sum(November_budget) as November_budget,sum(December_budget) as December_budget from (SELECT k.title as Parent, a.title as Title, f.pcb_type, IFNULL(f.january,0) as January_actuals,  IFNULL(f.february,0) as February_actuals,  IFNULL(f.march,0) as March_actuals,  IFNULL(f.april,0) as April_actuals,  IFNULL(f.may,0) as May_actuals,  IFNULL(f.june,0) as June_actuals,  IFNULL(f.july,0) as July_actuals,  IFNULL(f.august,0) as August_actuals,  IFNULL(f.september,0) as September_actuals,  IFNULL(f.october,0) as October_actuals,  IFNULL(f.november,0) as November_actuals,  IFNULL(f.december,0) as December_actuals,0 as January_budget, 0 as February_budget ,0 as March_budget, 0 as April_budget,0 as May_budget, 0 as June_budget,0 as July_budget, 0 as August_budget,0 as September_budget, 0 as October_budget,0 as November_budget, 0 as December_budget     FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id= a.parent_id left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') ) AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as January_actuals,0 as February_actuals,0 as March_actuals,0 as April_actuals,0 as May_actuals,0 as June_actuals,0 as July_actuals,0 as August_actuals,0 as September_actuals,0 as October_actuals,0 as November_actuals,0 as December_actuals,IFNULL(f.january,0) as January_budget,IFNULL(f.february,0) as February_budget,IFNULL(f.march,0) as March_budget,IFNULL(f.april,0) as April_budget,IFNULL(f.may,0) as May_budget,IFNULL(f.june,0) as June_budget,IFNULL(f.july,0) as July_budget,IFNULL(f.august,0) as August_budget,IFNULL(f.september,0) as September_budget,IFNULL(f.october,0) as October_budget,IFNULL(f.november,0) as November_budget,IFNULL(f.december,0) as December_budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') ) AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz" #if @note && parent.present?
         asset_details_cur_year = IncomeAndCashFlowDetail.find_by_sql(qry) if qry.present?
       else
         parent = financial_sub_id
         calc_for_financial_data_display
         if parent.present?
           qry = "select parent_id from income_and_cash_flow_details where parent_id=#{parent}"
           asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
           string = (asset_details.present? && asset_details.first.parent_id.present?) ? "a.parent_id" : "a.id"
         end
         #~ (REPLACE(a.title,'\\'','') IN ('#{title.gsub("'","")}'))
         financial_title=financial_title.gsub("'","")
         current_year_qry = "select Parent, Title, sum(January_actuals) as January_actuals,  sum(February_actuals) as February_actuals,sum(March_actuals) as March_actuals,sum(April_actuals) as April_actuals,sum(May_actuals) as May_actuals,sum(June_actuals) as June_actuals,sum(July_actuals) as July_actuals,sum(August_actuals) as August_actuals,sum(September_actuals) as September_actuals,sum(October_actuals) as October_actuals,sum(November_actuals) as November_actuals,sum(December_actuals) as December_actuals,sum(January_budget) as January_budget,  sum(February_budget) as February_budget,sum(March_budget) as March_budget,sum(April_budget) as April_budget,sum(May_budget) as May_budget,sum(June_budget) as June_budget,sum(July_budget) as July_budget,sum(August_budget) as August_budget,sum(September_budget) as September_budget,sum(October_budget) as October_budget,sum(November_budget) as November_budget,sum(December_budget) as December_budget from (SELECT k.title as Parent, a.title as Title, f.pcb_type, IFNULL(f.january,0) as January_actuals,  IFNULL(f.february,0) as February_actuals,  IFNULL(f.march,0) as March_actuals,  IFNULL(f.april,0) as April_actuals,  IFNULL(f.may,0) as May_actuals,  IFNULL(f.june,0) as June_actuals,  IFNULL(f.july,0) as July_actuals,  IFNULL(f.august,0) as August_actuals,  IFNULL(f.september,0) as September_actuals,  IFNULL(f.october,0) as October_actuals,  IFNULL(f.november,0) as November_actuals,  IFNULL(f.december,0) as December_actuals,0 as January_budget, 0 as February_budget ,0 as March_budget, 0 as April_budget,0 as May_budget, 0 as June_budget,0 as July_budget, 0 as August_budget,0 as September_budget, 0 as October_budget,0 as November_budget, 0 as December_budget     FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id= #{string} left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title}') ) AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as January_actuals,0 as February_actuals,0 as March_actuals,0 as April_actuals,0 as May_actuals,0 as June_actuals,0 as July_actuals,0 as August_actuals,0 as September_actuals,0 as October_actuals,0 as November_actuals,0 as December_actuals,IFNULL(f.january,0) as January_budget,IFNULL(f.february,0) as February_budget,IFNULL(f.march,0) as March_budget,IFNULL(f.april,0) as April_budget,IFNULL(f.may,0) as May_budget,IFNULL(f.june,0) as June_budget,IFNULL(f.july,0) as July_budget,IFNULL(f.august,0) as August_budget,IFNULL(f.september,0) as September_budget,IFNULL(f.october,0) as October_budget,IFNULL(f.november,0) as November_budget,IFNULL(f.december,0) as December_budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=#{string} inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title}') ) AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz" if @note && parent.present?
         asset_details_cur_year = current_year_qry.present? ? IncomeAndCashFlowDetail.find_by_sql(current_year_qry) : nil
       end
       asset_detail_cur_year = asset_details_cur_year.present? ? asset_details_cur_year.first : nil
       month_hash_cur_year = {"January" => {"January_actuals" => (asset_detail_cur_year.January_actuals rescue 0),"January_budget" => (asset_detail_cur_year.January_budget rescue 0)},"February" => {"February_actuals" => (asset_detail_cur_year.February_actuals rescue 0),"February_budget" => (asset_detail_cur_year.February_budget rescue 0)},"March" => {"March_actuals" => (asset_detail_cur_year.March_actuals rescue 0),"March_budget" => (asset_detail_cur_year.March_budget rescue 0)},"April" => {"April_actuals" => (asset_detail_cur_year.April_actuals rescue 0),"April_budget" => (asset_detail_cur_year.April_budget rescue 0)},"May" => {"May_actuals" => (asset_detail_cur_year.May_actuals rescue 0),"May_budget" => (asset_detail_cur_year.May_budget rescue 0)},"June" => {"June_actuals" => (asset_detail_cur_year.June_actuals rescue 0),"June_budget" => (asset_detail_cur_year.June_budget rescue 0)},"July" => {"July_actuals" => (asset_detail_cur_year.July_actuals rescue 0),"July_budget" => (asset_detail_cur_year.July_budget rescue 0)},"August" => {"August_actuals" => (asset_detail_cur_year.August_actuals rescue 0),"August_budget" => (asset_detail_cur_year.August_budget rescue 0)},"September" => {"September_actuals" => (asset_detail_cur_year.September_actuals rescue 0),"September_budget" => (asset_detail_cur_year.September_budget rescue 0)},"October" => {"October_actuals" => (asset_detail_cur_year.October_actuals rescue 0),"October_budget" => (asset_detail_cur_year.October_budget rescue 0)},"November" => {"November_actuals" => (asset_detail_cur_year.November_actuals rescue 0),"November_budget" => (asset_detail_cur_year.November_budget rescue 0)},"December" => {"December_actuals" => (asset_detail_cur_year.December_actuals rescue 0),"December_budget" => (asset_detail_cur_year.December_budget rescue 0)}}
       tmp_month = ["","January","February", "March","April","May","June","July","August","September","October", "November","December"]
       ytd_month = []
       if params[:tl_period] == "4"
         for i in 1..@financial_month.to_i do
           ytd_month << tmp_month[i]
         end
       elsif  params[:tl_period] == "3"
         for i in 1..12 do
           ytd_month << tmp_month[i]
         end
       end
       ytd_month.each do |i|
         cur_year_actuals += month_hash_cur_year[i]["#{i}_actuals"].to_i
       end
       ytd_month.each do |i|
         cur_year_budget += month_hash_cur_year[i]["#{i}_budget"].to_i
       end
       cur_year_variance = cur_year_budget.to_f - cur_year_actuals.to_f
     end
     cur_year_variance = cur_year_budget.to_f - cur_year_actuals.to_f
     return cur_year_actuals,cur_year_budget,cur_year_variance,financial_sub_id,month_hash_cur_year,months,year
   end

   def trend_year_on_year_growth_calc
     financial_sub_id,cur_year_actuals,prev_year_actuals,cur_year_budget,prev_year_budget = @financial_sub_id,0,0,0,0
     if params[:tl_period] == "11"
       performance_analysis_trailing(Date.today,Date.today.prev_year) # 2011 & 2012
       ##performance_analysis_trailing(Date.today.prev_year,Date.today.prev_year.prev_year,true)
       if @financial_sub.eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
         cur_year_tmp_hash_a,prev_year_tmp_hash_a = {},{}
         cur_year_tmp_a = @performance_trend.present? ? @performance_trend.values.inject{|m, el| m.merge( el ){|k, old_v, new_v| old_v.to_i + new_v.to_i}} : []
         prev_year_tmp_a = @performance_trend1.present? ? @performance_trend1.values.inject{|m, el| m.merge( el ){|k, old_v, new_v| old_v.to_i + new_v.to_i}} : []
         cur_year_tmp_hash_a["Operating Expenses"] = cur_year_tmp_a if cur_year_tmp_a.present?
         prev_year_tmp_hash_a["Operating Expenses"] = prev_year_tmp_a if prev_year_tmp_a.present?
         @performance_trend,@performance_trend1 = {},{}
         @performance_trend,@performance_trend1 = cur_year_tmp_hash_a,prev_year_tmp_hash_a
       end
       months = @year_growth_month
       cur_year_actuals = (@performance_trend.present? ? @performance_trend["#{@performance_trend.keys.first}"].values.map(&:to_i) : [] )+ (@performance_trend1.present? ? @performance_trend1["#{@performance_trend1.keys.first}"].values.map(&:to_i) : [])
       display_actuals = {}
       months.each do |month|
         display_actuals["#{month}"] = (@performance_trend.present? ? @performance_trend["#{@performance_trend.keys.first}"]["#{month}"].to_i : 0) + (@performance_trend1.present? ? @performance_trend1["#{@performance_trend1.keys.first}"]["#{month}"].to_i : 0)
       end
       cur_year_actuals = cur_year_actuals.flatten.compact.sum
       performance_analysis_trailing(Date.today.prev_year,Date.today.prev_year.prev_year,true) # 2010 & 2011
       if @financial_sub.eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
         cur_year_tmp_hash_a,prev_year_tmp_hash_a = {},{}
         cur_year_tmp_a = @performance_trend.present? ? @performance_trend.values.inject{|m, el| m.merge( el ){|k, old_v, new_v| old_v.to_i + new_v.to_i}} : []
         prev_year_tmp_a = @performance_trend1.present? ? @performance_trend1.values.inject{|m, el| m.merge( el ){|k, old_v, new_v| old_v.to_i + new_v.to_i}} : []
         cur_year_tmp_hash_a["Operating Expenses"] = cur_year_tmp_a if cur_year_tmp_a.present?
         prev_year_tmp_hash_a["Operating Expenses"] = prev_year_tmp_a if prev_year_tmp_a.present?
         @performance_trend,@performance_trend1 = {},{}
         @performance_trend,@performance_trend1 = cur_year_tmp_hash_a,prev_year_tmp_hash_a
       end
       months.each do |month|
         display_actuals["#{month}_prev"] = (@performance_trend.present? ? @performance_trend["#{@performance_trend.keys.first}"]["#{month}"].to_i : 0) + (@performance_trend1.present? ? @performance_trend1["#{@performance_trend1.keys.first}"]["#{month}"].to_i : 0)
       end
       prev_year_actuals = (@performance_trend.present? ? @performance_trend["#{@performance_trend.keys.first}"].values.map(&:to_i) : []) + (@performance_trend1.present? ? @performance_trend1["#{@performance_trend1.keys.first}"].values.map(&:to_i) : [])
       prev_year_actuals = prev_year_actuals.flatten.compact.sum
       year = params[:tl_year].present? ? params[:tl_year].to_i : Date.today.year
     else
       actual_pcb_type,budget_pcb_type = find_pcb_type
       #financial_title = find_non_financial_title
       financial_title = "'#{@financial_sub}'"
       @resource = "#{@resource}"
       parent = @financial_sub_id
       months = ["January","February","March","April","May","June","July","August","September","October","November","December"]
       year = params[:tl_year].present? ? params[:tl_year].to_i : Date.today.year
       if (@financial_sub.strip).eql?("Operating Expenses") && @note.present? && @note.leasing_type == "Commercial"
         calc_for_financial_data_display
         financial_title = "'recoverable expenses detail','non-recoverable expenses detail'"
         asset_details_cur_year = {}
         qry = "select Parent, Title, sum(January_actuals) as January_actuals,  sum(February_actuals) as February_actuals,sum(March_actuals) as March_actuals,sum(April_actuals) as April_actuals,sum(May_actuals) as May_actuals,sum(June_actuals) as June_actuals,sum(July_actuals) as July_actuals,sum(August_actuals) as August_actuals,sum(September_actuals) as September_actuals,sum(October_actuals) as October_actuals,sum(November_actuals) as November_actuals,sum(December_actuals) as December_actuals,sum(January_budget) as January_budget,  sum(February_budget) as February_budget,sum(March_budget) as March_budget,sum(April_budget) as April_budget,sum(May_budget) as May_budget,sum(June_budget) as June_budget,sum(July_budget) as July_budget,sum(August_budget) as August_budget,sum(September_budget) as September_budget,sum(October_budget) as October_budget,sum(November_budget) as November_budget,sum(December_budget) as December_budget from (SELECT k.title as Parent, a.title as Title, f.pcb_type, IFNULL(f.january,0) as January_actuals,  IFNULL(f.february,0) as February_actuals,  IFNULL(f.march,0) as March_actuals,  IFNULL(f.april,0) as April_actuals,  IFNULL(f.may,0) as May_actuals,  IFNULL(f.june,0) as June_actuals,  IFNULL(f.july,0) as July_actuals,  IFNULL(f.august,0) as August_actuals,  IFNULL(f.september,0) as September_actuals,  IFNULL(f.october,0) as October_actuals,  IFNULL(f.november,0) as November_actuals,  IFNULL(f.december,0) as December_actuals,0 as January_budget, 0 as February_budget ,0 as March_budget, 0 as April_budget,0 as May_budget, 0 as June_budget,0 as July_budget, 0 as August_budget,0 as September_budget, 0 as October_budget,0 as November_budget, 0 as December_budget     FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id= a.parent_id left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') ) AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as January_actuals,0 as February_actuals,0 as March_actuals,0 as April_actuals,0 as May_actuals,0 as June_actuals,0 as July_actuals,0 as August_actuals,0 as September_actuals,0 as October_actuals,0 as November_actuals,0 as December_actuals,IFNULL(f.january,0) as January_budget,IFNULL(f.february,0) as February_budget,IFNULL(f.march,0) as March_budget,IFNULL(f.april,0) as April_budget,IFNULL(f.may,0) as May_budget,IFNULL(f.june,0) as June_budget,IFNULL(f.july,0) as July_budget,IFNULL(f.august,0) as August_budget,IFNULL(f.september,0) as September_budget,IFNULL(f.october,0) as October_budget,IFNULL(f.november,0) as November_budget,IFNULL(f.december,0) as December_budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}') ) AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz" #if @note && parent.present?
         asset_details_cur_year = IncomeAndCashFlowDetail.find_by_sql(qry) if qry.present?
         asset_detail_cur_year = asset_details_cur_year.present? ? asset_details_cur_year.first : nil
         month_hash_cur_year = {"January" => {"January_actuals" => (asset_detail_cur_year.January_actuals rescue 0),"January_budget" => (asset_detail_cur_year.January_budget rescue 0)},"February" => {"February_actuals" => (asset_detail_cur_year.February_actuals rescue 0),"February_budget" => (asset_detail_cur_year.February_budget rescue 0)},"March" => {"March_actuals" => (asset_detail_cur_year.March_actuals rescue 0),"March_budget" => (asset_detail_cur_year.March_budget rescue 0)},"April" => {"April_actuals" => (asset_detail_cur_year.April_actuals rescue 0),"April_budget" => (asset_detail_cur_year.April_budget rescue 0)},"May" => {"May_actuals" => (asset_detail_cur_year.May_actuals rescue 0),"May_budget" => (asset_detail_cur_year.May_budget rescue 0)},"June" => {"June_actuals" => (asset_detail_cur_year.June_actuals rescue 0),"June_budget" => (asset_detail_cur_year.June_budget rescue 0)},"July" => {"July_actuals" => (asset_detail_cur_year.July_actuals rescue 0),"July_budget" => (asset_detail_cur_year.July_budget rescue 0)},"August" => {"August_actuals" => (asset_detail_cur_year.August_actuals rescue 0),"August_budget" => (asset_detail_cur_year.August_budget rescue 0)},"September" => {"September_actuals" => (asset_detail_cur_year.September_actuals rescue 0),"September_budget" => (asset_detail_cur_year.September_budget rescue 0)},"October" => {"October_actuals" => (asset_detail_cur_year.October_actuals rescue 0),"October_budget" => (asset_detail_cur_year.October_budget rescue 0)},"November" => {"November_actuals" => (asset_detail_cur_year.November_actuals rescue 0),"November_budget" => (asset_detail_cur_year.November_budget rescue 0)},"December" => {"December_actuals" => (asset_detail_cur_year.December_actuals rescue 0),"December_budget" => (asset_detail_cur_year.December_budget rescue 0)}}
         prev_year_qry = "select Parent, Title, sum(January_actuals) as January_actuals,  sum(February_actuals) as February_actuals,sum(March_actuals) as March_actuals,sum(April_actuals) as April_actuals,sum(May_actuals) as May_actuals,sum(June_actuals) as June_actuals,sum(July_actuals) as July_actuals,sum(August_actuals) as August_actuals,sum(September_actuals) as September_actuals,sum(October_actuals) as October_actuals,sum(November_actuals) as November_actuals,sum(December_actuals) as December_actuals,sum(January_budget) as January_budget,  sum(February_budget) as February_budget,sum(March_budget) as March_budget,sum(April_budget) as April_budget,sum(May_budget) as May_budget,sum(June_budget) as June_budget,sum(July_budget) as July_budget,sum(August_budget) as August_budget,sum(September_budget) as September_budget,sum(October_budget) as October_budget,sum(November_budget) as November_budget,sum(December_budget) as December_budget from (SELECT k.title as Parent, a.title as Title, f.pcb_type, IFNULL(f.january,0) as January_actuals,  IFNULL(f.february,0) as February_actuals,  IFNULL(f.march,0) as March_actuals,  IFNULL(f.april,0) as April_actuals,  IFNULL(f.may,0) as May_actuals,  IFNULL(f.june,0) as June_actuals,  IFNULL(f.july,0) as July_actuals,  IFNULL(f.august,0) as August_actuals,  IFNULL(f.september,0) as September_actuals,  IFNULL(f.october,0) as October_actuals,  IFNULL(f.november,0) as November_actuals,  IFNULL(f.december,0) as December_actuals,0 as January_budget, 0 as February_budget ,0 as March_budget, 0 as April_budget,0 as May_budget, 0 as June_budget,0 as July_budget, 0 as August_budget,0 as September_budget, 0 as October_budget,0 as November_budget, 0 as December_budget     FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}')) AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{(year.to_i)-1} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as January_actuals,0 as February_actuals,0 as March_actuals,0 as April_actuals,0 as May_actuals,0 as June_actuals,0 as July_actuals,0 as August_actuals,0 as September_actuals,0 as October_actuals,0 as November_actuals,0 as December_actuals,IFNULL(f.january,0) as January_budget,IFNULL(f.february,0) as February_budget,IFNULL(f.march,0) as March_budget,IFNULL(f.april,0) as April_budget,IFNULL(f.may,0) as May_budget,IFNULL(f.june,0) as June_budget,IFNULL(f.july,0) as July_budget,IFNULL(f.august,0) as August_budget,IFNULL(f.september,0) as September_budget,IFNULL(f.october,0) as October_budget,IFNULL(f.november,0) as November_budget,IFNULL(f.december,0) as December_budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}')) AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail') xyz" if @note
         asset_details_prev_year = IncomeAndCashFlowDetail.find_by_sql(prev_year_qry) if prev_year_qry.present?
         asset_detail_prev_year = prev_year_qry.present? ? asset_details_prev_year.first : nil
         month_hash_prev_year = {"January" => {"January_actuals" => (asset_detail_prev_year.January_actuals rescue 0),"January_budget" => (asset_detail_prev_year.January_budget rescue 0)},"February" => {"February_actuals" => (asset_detail_prev_year.February_actuals rescue 0),"February_budget" => (asset_detail_prev_year.February_budget rescue 0)},"March" => {"March_actuals" => (asset_detail_prev_year.March_actuals rescue 0),"March_budget" => (asset_detail_prev_year.March_budget rescue 0)},"April" => {"April_actuals" => (asset_detail_prev_year.April_actuals rescue 0),"April_budget" => (asset_detail_prev_year.April_budget rescue 0)},"May" => {"May_actuals" => (asset_detail_prev_year.May_actuals rescue 0),"May_budget" => (asset_detail_prev_year.May_budget rescue 0)},"June" => {"June_actuals" => (asset_detail_prev_year.June_actuals rescue 0),"June_budget" => (asset_detail_prev_year.June_budget rescue 0)},"July" => {"July_actuals" => (asset_detail_prev_year.July_actuals rescue 0),"July_budget" => (asset_detail_prev_year.July_budget rescue 0)},"August" => {"August_actuals" => (asset_detail_prev_year.August_actuals rescue 0),"August_budget" => (asset_detail_prev_year.August_budget rescue 0)},"September" => {"September_actuals" => (asset_detail_prev_year.September_actuals rescue 0),"September_budget" => (asset_detail_prev_year.September_budget rescue 0)},"October" => {"October_actuals" => (asset_detail_prev_year.October_actuals rescue 0),"October_budget" => (asset_detail_prev_year.October_budget rescue 0)},"November" => {"November_actuals" => (asset_detail_prev_year.November_actuals rescue 0),"November_budget" => (asset_detail_prev_year.November_budget rescue 0)},"December" => {"December_actuals" => (asset_detail_prev_year.December_actuals rescue 0),"December_budget" => (asset_detail_prev_year.December_budget rescue 0)}}
       else
         #year = year+1 if params[:tl_period].present? && params[:tl_period].eql?("3")
         parent = financial_sub_id
         if parent.present?
           qry = "select parent_id from income_and_cash_flow_details where parent_id=#{parent}"
           asset_details = IncomeAndCashFlowDetail.find_by_sql(qry)
           string = (asset_details.present? && asset_details.first.parent_id.present?) ? "a.parent_id" : "a.id"
         end
         calc_for_financial_data_display
         current_year_qry = "select Parent, Title, sum(January_actuals) as January_actuals,  sum(February_actuals) as February_actuals,sum(March_actuals) as March_actuals,sum(April_actuals) as April_actuals,sum(May_actuals) as May_actuals,sum(June_actuals) as June_actuals,sum(July_actuals) as July_actuals,sum(August_actuals) as August_actuals,sum(September_actuals) as September_actuals,sum(October_actuals) as October_actuals,sum(November_actuals) as November_actuals,sum(December_actuals) as December_actuals,sum(January_budget) as January_budget,  sum(February_budget) as February_budget,sum(March_budget) as March_budget,sum(April_budget) as April_budget,sum(May_budget) as May_budget,sum(June_budget) as June_budget,sum(July_budget) as July_budget,sum(August_budget) as August_budget,sum(September_budget) as September_budget,sum(October_budget) as October_budget,sum(November_budget) as November_budget,sum(December_budget) as December_budget from (SELECT k.title as Parent, a.title as Title, f.pcb_type, IFNULL(f.january,0) as January_actuals,  IFNULL(f.february,0) as February_actuals,  IFNULL(f.march,0) as March_actuals,  IFNULL(f.april,0) as April_actuals,  IFNULL(f.may,0) as May_actuals,  IFNULL(f.june,0) as June_actuals,  IFNULL(f.july,0) as July_actuals,  IFNULL(f.august,0) as August_actuals,  IFNULL(f.september,0) as September_actuals,  IFNULL(f.october,0) as October_actuals,  IFNULL(f.november,0) as November_actuals,  IFNULL(f.december,0) as December_actuals,0 as January_budget, 0 as February_budget ,0 as March_budget, 0 as April_budget,0 as May_budget, 0 as June_budget,0 as July_budget, 0 as August_budget,0 as September_budget, 0 as October_budget,0 as November_budget, 0 as December_budget     FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id= #{string}  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}')) AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as January_actuals,0 as February_actuals,0 as March_actuals,0 as April_actuals,0 as May_actuals,0 as June_actuals,0 as July_actuals,0 as August_actuals,0 as September_actuals,0 as October_actuals,0 as November_actuals,0 as December_actuals,IFNULL(f.january,0) as January_budget,IFNULL(f.february,0) as February_budget,IFNULL(f.march,0) as March_budget,IFNULL(f.april,0) as April_budget,IFNULL(f.may,0) as May_budget,IFNULL(f.june,0) as June_budget,IFNULL(f.july,0) as July_budget,IFNULL(f.august,0) as August_budget,IFNULL(f.september,0) as September_budget,IFNULL(f.october,0) as October_budget,IFNULL(f.november,0) as November_budget,IFNULL(f.december,0) as December_budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=#{string}  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}')) AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year} AND f.source_type='IncomeAndCashFlowDetail') xyz" if @note
         asset_details_cur_year = IncomeAndCashFlowDetail.find_by_sql(current_year_qry) if current_year_qry.present?
         asset_detail_cur_year = current_year_qry.present? ? asset_details_cur_year.first : nil
         #asset_detail_cur_year = nil if params[:tl_period].present? && params[:tl_period].eql?("3")
         month_hash_cur_year = {"January" => {"January_actuals" => (asset_detail_cur_year.January_actuals rescue 0),"January_budget" => (asset_detail_cur_year.January_budget rescue 0)},"February" => {"February_actuals" => (asset_detail_cur_year.February_actuals rescue 0),"February_budget" => (asset_detail_cur_year.February_budget rescue 0)},"March" => {"March_actuals" => (asset_detail_cur_year.March_actuals rescue 0),"March_budget" => (asset_detail_cur_year.March_budget rescue 0)},"April" => {"April_actuals" => (asset_detail_cur_year.April_actuals rescue 0),"April_budget" => (asset_detail_cur_year.April_budget rescue 0)},"May" => {"May_actuals" => (asset_detail_cur_year.May_actuals rescue 0),"May_budget" => (asset_detail_cur_year.May_budget rescue 0)},"June" => {"June_actuals" => (asset_detail_cur_year.June_actuals rescue 0),"June_budget" => (asset_detail_cur_year.June_budget rescue 0)},"July" => {"July_actuals" => (asset_detail_cur_year.July_actuals rescue 0),"July_budget" => (asset_detail_cur_year.July_budget rescue 0)},"August" => {"August_actuals" => (asset_detail_cur_year.August_actuals rescue 0),"August_budget" => (asset_detail_cur_year.August_budget rescue 0)},"September" => {"September_actuals" => (asset_detail_cur_year.September_actuals rescue 0),"September_budget" => (asset_detail_cur_year.September_budget rescue 0)},"October" => {"October_actuals" => (asset_detail_cur_year.October_actuals rescue 0),"October_budget" => (asset_detail_cur_year.October_budget rescue 0)},"November" => {"November_actuals" => (asset_detail_cur_year.November_actuals rescue 0),"November_budget" => (asset_detail_cur_year.November_budget rescue 0)},"December" => {"December_actuals" => (asset_detail_cur_year.December_actuals rescue 0),"December_budget" => (asset_detail_cur_year.December_budget rescue 0)}}
         prev_year_qry = "select Parent, Title, sum(January_actuals) as January_actuals,  sum(February_actuals) as February_actuals,sum(March_actuals) as March_actuals,sum(April_actuals) as April_actuals,sum(May_actuals) as May_actuals,sum(June_actuals) as June_actuals,sum(July_actuals) as July_actuals,sum(August_actuals) as August_actuals,sum(September_actuals) as September_actuals,sum(October_actuals) as October_actuals,sum(November_actuals) as November_actuals,sum(December_actuals) as December_actuals,sum(January_budget) as January_budget,  sum(February_budget) as February_budget,sum(March_budget) as March_budget,sum(April_budget) as April_budget,sum(May_budget) as May_budget,sum(June_budget) as June_budget,sum(July_budget) as July_budget,sum(August_budget) as August_budget,sum(September_budget) as September_budget,sum(October_budget) as October_budget,sum(November_budget) as November_budget,sum(December_budget) as December_budget from (SELECT k.title as Parent, a.title as Title, f.pcb_type, IFNULL(f.january,0) as January_actuals,  IFNULL(f.february,0) as February_actuals,  IFNULL(f.march,0) as March_actuals,  IFNULL(f.april,0) as April_actuals,  IFNULL(f.may,0) as May_actuals,  IFNULL(f.june,0) as June_actuals,  IFNULL(f.july,0) as July_actuals,  IFNULL(f.august,0) as August_actuals,  IFNULL(f.september,0) as September_actuals,  IFNULL(f.october,0) as October_actuals,  IFNULL(f.november,0) as November_actuals,  IFNULL(f.december,0) as December_actuals,0 as January_budget, 0 as February_budget ,0 as March_budget, 0 as April_budget,0 as May_budget, 0 as June_budget,0 as July_budget, 0 as August_budget,0 as September_budget, 0 as October_budget,0 as November_budget, 0 as December_budget     FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  left join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}')) AND f.pcb_type IN (#{actual_pcb_type}) AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail' UNION SELECT k.title as Parent, a.title as Title, f.pcb_type, 0 as January_actuals,0 as February_actuals,0 as March_actuals,0 as April_actuals,0 as May_actuals,0 as June_actuals,0 as July_actuals,0 as August_actuals,0 as September_actuals,0 as October_actuals,0 as November_actuals,0 as December_actuals,IFNULL(f.january,0) as January_budget,IFNULL(f.february,0) as February_budget,IFNULL(f.march,0) as March_budget,IFNULL(f.april,0) as April_budget,IFNULL(f.may,0) as May_budget,IFNULL(f.june,0) as June_budget,IFNULL(f.july,0) as July_budget,IFNULL(f.august,0) as August_budget,IFNULL(f.september,0) as September_budget,IFNULL(f.october,0) as October_budget,IFNULL(f.november,0) as November_budget,IFNULL(f.december,0) as December_budget FROM `income_and_cash_flow_details` a  LEFT JOIN income_and_cash_flow_details k ON k.id=a.parent_id  inner join property_financial_periods f ON a.id = f.source_id WHERE a.resource_id=#{@note.try(:id)} AND a.resource_type = #{@resource} AND (REPLACE(k.title,'\\'','') IN ('#{financial_title.gsub("'","")}')) AND f.pcb_type IN (#{budget_pcb_type}) AND a.year=#{year-1} AND f.source_type='IncomeAndCashFlowDetail') xyz" if @note
         asset_details_prev_year = IncomeAndCashFlowDetail.find_by_sql(prev_year_qry) if prev_year_qry.present?
         asset_detail_prev_year = prev_year_qry.present? ? asset_details_prev_year.first : nil
         month_hash_prev_year = {"January" => {"January_actuals" => (asset_detail_prev_year.January_actuals rescue 0),"January_budget" => (asset_detail_prev_year.January_budget rescue 0)},"February" => {"February_actuals" => (asset_detail_prev_year.February_actuals rescue 0),"February_budget" => (asset_detail_prev_year.February_budget rescue 0)},"March" => {"March_actuals" => (asset_detail_prev_year.March_actuals rescue 0),"March_budget" => (asset_detail_prev_year.March_budget rescue 0)},"April" => {"April_actuals" => (asset_detail_prev_year.April_actuals rescue 0),"April_budget" => (asset_detail_prev_year.April_budget rescue 0)},"May" => {"May_actuals" => (asset_detail_prev_year.May_actuals rescue 0),"May_budget" => (asset_detail_prev_year.May_budget rescue 0)},"June" => {"June_actuals" => (asset_detail_prev_year.June_actuals rescue 0),"June_budget" => (asset_detail_prev_year.June_budget rescue 0)},"July" => {"July_actuals" => (asset_detail_prev_year.July_actuals rescue 0),"July_budget" => (asset_detail_prev_year.July_budget rescue 0)},"August" => {"August_actuals" => (asset_detail_prev_year.August_actuals rescue 0),"August_budget" => (asset_detail_prev_year.August_budget rescue 0)},"September" => {"September_actuals" => (asset_detail_prev_year.September_actuals rescue 0),"September_budget" => (asset_detail_prev_year.September_budget rescue 0)},"October" => {"October_actuals" => (asset_detail_prev_year.October_actuals rescue 0),"October_budget" => (asset_detail_prev_year.October_budget rescue 0)},"November" => {"November_actuals" => (asset_detail_prev_year.November_actuals rescue 0),"November_budget" => (asset_detail_prev_year.November_budget rescue 0)},"December" => {"December_actuals" => (asset_detail_prev_year.December_actuals rescue 0),"December_budget" => (asset_detail_prev_year.December_budget rescue 0)}}
       end
       tmp_month = ["","January","February", "March","April","May","June","July","August","September","October", "November","December"]
       ytd_month,prev_year_ytd_month = [],[]
       if params[:tl_period] == "4"
         for i in 1..@financial_month.to_i do
           ytd_month << tmp_month[i]
           prev_year_ytd_month << tmp_month[i]
         end
       elsif  params[:tl_period] == "3"
         #for i in 1..12 do
         ##month << "sum(" + "f."+ "#{months[i]}" + ")" + "as" + " '#{month_string[i]}'"
         ##month_array << month_string[i]
         ##month_array_string << month_string[i]+'-'+Date.today.prev_year.strftime('%y')
         #end
         for i in 1..12 do
           ytd_month << tmp_month[i]
           prev_year_ytd_month << tmp_month[i]
         end
       end
       ytd_month.each do |i|
         cur_year_actuals += month_hash_cur_year[i]["#{i}_actuals"].to_i
       end
       ytd_month.each do |i|
         cur_year_budget += month_hash_cur_year[i]["#{i}_budget"].to_i
       end
       prev_year_ytd_month.each do |i|
         prev_year_actuals += month_hash_prev_year[i]["#{i}_actuals"].to_i
       end
     end
     cur_year_variance = cur_year_budget - cur_year_actuals
     prev_year_variance = cur_year_actuals - prev_year_actuals
     return year,cur_year_actuals,cur_year_budget,prev_year_actuals,cur_year_variance,prev_year_variance,financial_sub_id,months,month_hash_cur_year,month_hash_prev_year,display_actuals
   end
   
   def find_total_exp_explanation
      find_dashboard_portfolio_display											
      year = Date.today.prev_month.year  if year.nil?
      year = find_selected_year(year)
      @pci = @note.try(:class).eql?(Portfolio) ? PropertyCapitalImprovement.find(:first,:conditions => ["year=? and portfolio_id = ? and month < ? and tenant_name= ?",year,@note.id,Date.today.month,"Total Capital Expenditures"],:order => "month desc") : PropertyCapitalImprovement.find(:first,:conditions => ["year=? and real_estate_property_id=? and month < ? and tenant_name =?",year,@note.id,Date.today.month,"Total Capital Expenditures"],:order => "month desc")	
      return @pci
    end
end
