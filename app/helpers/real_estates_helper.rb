module RealEstatesHelper
  # Finding pcb type position for the destroy functionality
  def get_position_for_pcb(pcb)
    if pcb == 'p'
    1
    elsif pcb == 'c'
    2
    elsif pcb == 'b'
    3
    end
  end

  def portfolio_sqft_diff(graph_period,is_year_to_date,portfolio_id)
    graph_year,graph_month = graph_period.split('-')[0],graph_period.split('-')[1]
    property_ids = find_properties(portfolio_id,current_user.id)
    if is_year_to_date == true && property_ids
      occupancy_max_month = PropertyOccupancySummary.find_by_sql("SELECT max(`month`) as month FROM property_occupancy_summaries o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id} and r.id in (#{property_ids.collect{|x|x.id}.split(',').join(',')}) and o.month <= #{Date.today.prev_month.month}")
      @portfolio_occupancy = PropertyOccupancySummary.find_by_sql("select sum(c.budget) as budget,sum(c.actual ) as actual from (SELECT a . * ,b.current_year_sf_occupied_budget as budget, b.current_year_sf_occupied_actual as actual, b.id FROM  property_occupancy_summaries b RIGHT JOIN (SELECT #{occupancy_max_month[0].month} AS MONTH , real_estate_property_id FROM property_occupancy_summaries WHERE real_estate_property_id IN (#{property_ids.collect{|x|x.id}.split(',').join(',')}) AND year = #{graph_year} GROUP BY real_estate_property_id HAVING #{occupancy_max_month[0].month})a ON a.month = b.month AND a.real_estate_property_id = b.real_estate_property_id)c")
    else
      @portfolio_occupancy = PropertyOccupancySummary.find(:all,:conditions => ["year=? and month = ? and real_estate_property_id IN (?)",graph_year,graph_month,property_ids.collect{|x|x.id}], :select => "sum( current_year_sf_occupied_budget ) as budget, sum( current_year_sf_occupied_actual ) as actual ")
    end
  end

  def hash_formation_for_portfolio_occupancy(graph_period,is_year_to_date,portfolio_id)
    graph_year = graph_period.split('-')[0]
    graph_month = graph_period.split('-')[1]
    property_ids = find_properties(portfolio_id,current_user.id)
    if is_year_to_date == true
      if property_ids
        occupancy_max_month = CommercialLeaseOccupancy.find_by_sql("SELECT max(`month`) as month FROM commercial_lease_occupancies o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id} and r.id in (#{property_ids.collect{|x|x.id}.split(',').join(',')}) and o.month <= #{Date.today.prev_month.month}")
      else
        occupancy_max_month = CommercialLeaseOccupancy.find_by_sql("SELECT max(`month`) as month FROM commercial_lease_occupancies o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id}")
      end
      if occupancy_max_month[0].month.nil?
      @portfolio_occupancy = []
      else
        @portfolio_occupancy = CommercialLeaseOccupancy.find_by_sql("select sum(c.occupied) as occupied,sum(c.vaccant ) as vaccant from (SELECT a . * ,b.current_year_sf_occupied_actual as occupied, b.current_year_sf_vacant_actual as vaccant, b.id FROM  commercial_lease_occupancies b RIGHT JOIN (SELECT #{occupancy_max_month[0].month} AS MONTH , real_estate_property_id FROM commercial_lease_occupancies WHERE real_estate_property_id IN (#{property_ids.collect{|x|x.id}.split(',').join(',')}) AND year = #{graph_year} GROUP BY real_estate_property_id HAVING #{occupancy_max_month[0].month})a ON a.month = b.month AND a.real_estate_property_id = b.real_estate_property_id)c")
      end
    else
      @portfolio_occupancy = CommercialLeaseOccupancy.find(:all,:conditions => ["year=? and month = ? and real_estate_property_id IN (?)",graph_year,graph_month,property_ids.collect{|x|x.id}], :select => "sum( current_year_sf_occupied_actual ) as occupied, sum( current_year_sf_vacant_actual ) as vaccant ")
    end
    return @portfolio_occupancy
  end

  def wres_hash_formation_for_portfolio_occupancy(graph_period,is_year_to_date,portfolio_id)
    graph_year = graph_period.split('-')[0]
    graph_month = graph_period.split('-')[1]
    property_ids = find_properties(portfolio_id,current_user.id)
    if is_year_to_date == true
      if property_ids
        occupancy_max_month = PropertyOccupancySummary.find_by_sql("SELECT max(`month`) as month FROM property_occupancy_summaries o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id} and r.id in (#{property_ids.collect{|x|x.id}.split(',').join(',')}) and o.month <= #{Date.today.prev_month.month}")
      else
        occupancy_max_month = PropertyOccupancySummary.find_by_sql("SELECT max(`month`) as month FROM property_occupancy_summaries o INNER JOIN real_estate_properties r on o.real_estate_property_id = r.id and r.portfolio_id =#{@portfolio.id} and o.month <= #{Date.today.prev_month.month}")
      end
      if occupancy_max_month[0].month.nil?
      @portfolio_occupancy = []
      else
        @portfolio_occupancy = PropertyOccupancySummary.find_by_sql("select sum(c.occupied) as occupied,sum(c.vaccant ) as vaccant, sum(c.occupied_units) as occupied_units, sum(c.vaccant_units) as vaccant_units from (SELECT a . * ,b.current_year_sf_occupied_actual as occupied, b.current_year_sf_vacant_actual as vaccant,b.current_year_units_occupied_actual as occupied_units, b.current_year_units_vacant_actual as vaccant_units, b.id FROM  property_occupancy_summaries b RIGHT JOIN (SELECT     #{occupancy_max_month[0].month}  AS MONTH , real_estate_property_id FROM property_occupancy_summaries WHERE real_estate_property_id IN ( #{property_ids.collect{|x|x.id}.split(',').join(',')}) AND year = #{graph_year} GROUP BY real_estate_property_id HAVING #{occupancy_max_month[0].month})a ON a.month = b.month and b.year = #{graph_year} AND a.real_estate_property_id = b.real_estate_property_id)c")
      end
    else
      @portfolio_occupancy = PropertyOccupancySummary.find(:all,:conditions => ["year=? and month = ? and real_estate_property_id IN (?)",graph_year,graph_month,property_ids.collect{|x|x.id}], :select => "sum( current_year_sf_occupied_actual ) as occupied, sum( current_year_sf_vacant_actual ) as vaccant,sum( current_year_units_occupied_actual ) as occupied_units, sum( current_year_units_vacant_actual ) as vaccant_units ")
    end
    return @portfolio_occupancy
  end

  def get_location(city,province)
    if ( city == ''|| city.blank? ) && (province == '' || province.blank? )
      ''
    elsif ( city != '' || !city.blank? ) && ( province == '' || province.blank? )
    city
    elsif ( city == '' || city.blank? ) && ( province != '' || !province.blank? )
    province
    else
      city.to_s+', '+province.to_s
    end
  end

  def property_folder(folder)
    fol = Folder.find(:first, :conditions=>["real_estate_property_id = ? and parent_id =? and is_master =?", folder, 0, 0])
    fol ? fol.id : 0
  end

  def find_property_debt_summary(property_id)
    return PropertyDebtSummary.find(:all,:conditions =>["real_estate_property_id = ? ",property_id])
  end

  def find_property_occupancy(note,month_occ,year_occ)
    return PropertyOccupancySummary.find(:first, :conditions => ["real_estate_property_id = ? and month = ? and year = ?",note,month_occ,year_occ])
  end

  def find_property_occupancy_summary(note,year_occ)
    return PropertyOccupancySummary.find(:first, :conditions => ["real_estate_property_id = ? and year = ?",note,year_occ], :order => "month desc")
  end

  def find_property_type()
    return PropertyType.find(:all)
  end

  def find_by_real_estate_property_id(property_id)
    return Folder.find_by_real_estate_property_id(property_id,:conditions=>["parent_id = 0 and is_master = 0"])
  end

  def find_portfolio_type_for_realestate()
    return PortfolioType.find_portfolio_type('Real Estate')
  end

  def find_properties(portfolio_id,user_id)
    user = User.find_by_id(user_id)
    property_ids = RealEstateProperty.find(:all,:conditions => ["portfolios.id=? and real_estate_properties.user_id =? and real_estate_properties.client_id = #{user.client_id}",portfolio_id, user_id],:joins=>:portfolios)
    portfolio = Portfolio.find_by_id(portfolio_id)
    property_ids += portfolio.real_estate_properties.find_by_sql("SELECT * FROM real_estate_properties WHERE id in (SELECT real_estate_property_id FROM shared_folders WHERE is_property_folder = 1 AND user_id = #{user_id} and client_id = #{user.client_id})")
    property_ids.blank? ? nil : property_ids
  end

  def get_loan_tab_class
    (params[:from_debt_summary] == 'true' && params[:call_from_prop_files] != 'true') ? "suitetabbasicac" : "suitetabbasicde"
  end

  def get_property_tab_class
    (params[:from_property_details] == 'true' && params[:call_from_prop_files] != 'true') ? "suitetabbasicac" : "suitetabbasicde"
  end

  def get_basic_tab_class
    (params[:from_debt_summary] == 'true' || params[:from_property_details] == 'true'|| params[:highlight_users_form] == 'true' || (params[:call_from_prop_files] == 'true' && params[:add_property] !='true' && params[:highlight_basic_form] != 'true' ) || params[:is_property_folder] == 'true'|| params[:call_from_variances] == 'true') ? "suitetabbasicde" : "suitetabbasicac"
  end

  def get_user_tab_class
    ((params[:highlight_basic_form] != 'true') && (params[:from_property_details] != 'true')  && ((params[:call_from_prop_files] == 'true' && params[:add_property] !='true' ) || params[:is_property_folder] == 'true'|| params[:highlight_users_form] == "true" ) )   ? "suitetabbasicac" : "suitetabbasicde"
  end

  def get_variance_tab_class
    property = RealEstateProperty.find_real_estate_property(params[:property_id])
    if is_commercial(property)
      ((params[:highlight_users_form] != 'true') && (params[:from_property_details] != 'true')  && (params[:from_variances] == 'true' || params[:call_from_variances] == 'true') ) ? "suitetabbasicac" : "suitetabbasicde"
    elsif is_multifamily(property)
      ((params[:highlight_users_form] != 'true') && (params[:from_property_details] != 'true')  && (params[:from_variances] == 'true' || params[:call_from_variances] == 'true') ) ? "suitetabbasicac2" : "suitetabbasicde2"
    end
  end

  def get_suites_tab_class
    params[:call_from_suites] == 'true' ? "suitetabbasicac" : "suitetabbasicde"
  end

  def get_alerts_tab_class
    params[:call_from_alerts] == 'true' ? "suitetabbasicac2" : "suitetabbasicde2"
  end
end
