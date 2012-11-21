namespace :lease do
  desc 'lease records'
  task :lease_load => :environment do
    year = 2011 # Year Fixed as 2011
    real_estate_property_id = 911 #894 # real estate property id
    user_id = 167 # User id
    gldetail_table_name =  "Griffin" + "_GLDetail"
    account_table_name =  "Griffin" + "_Acct"
    property_table_name =  "Griffin" + "_Property"
    total_table_name =  "Griffin" + "_Total"
    person_table_name = "Griffin" + "_person"
    hmy = 36
    comm_amendments_table_name = "Griffin" + "_commAmendments"
    tenant_table_name = "Griffin" + "_tenant"
    tenant_aging_table_name = "Griffin" + "_tenantaging"
    unit_table_name = "Griffin" + "_unit"
    unit_type_table_name = "Griffin" + "_UnitType"
    gldetail_table_name =  "Griffin" + "_GLDetail"
    person_table_name = "Griffin" + "_person"
    
    leasing_type ="Multifamily"
    
    
    #.................................................................................................Import Lease and rent roll data into master table starts here.......................................................................................................
    p "Importing lease details starts"
    lease_year_qry = PropertyLease.find_by_sql("select DTLEASEFROM as lease_from  from #{tenant_table_name} where DTLEASEFROM between '2010-01-01' and '#{Date.today.year}-12-31' group by DTLEASEFROM")
    lease_years = lease_year_qry.collect{|l_year_month|  l_year_month.lease_from.split('-')[0].to_i}
   if leasing_type == "Multifamily"
     lease_years.compact.uniq.each do |year|
        #To insert lease and rent roll data
        (1..12).each do |month|
          p "Preparing to insert the #{year} - #{Date::MONTHNAMES[month]}  details..."
          #To insert  property occupancy data
          t_b_r_s = PropertyLease.find_by_sql("SELECT SUM(DSQFT) as total_building_rentable_s,gu.dtLastModified as last_modified FROM #{unit_table_name} gu left join #{tenant_table_name} t  on t.sUnitCode=gu.sCode and  ((t.DTLEASEFROM < '#{year}-#{month}-31') and (t.dtLeaseTo > '#{year}-#{month}-31') or t.dtLeaseTo is null or t.dtLeaseFrom is null) AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) where gu.HPROPERTY = #{hmy}")[0]
         next if  t_b_r_s.total_building_rentable_s  == nil  && t_b_r_s.last_modified == nil  || t_b_r_s.total_building_rentable_s  == "0"
          c_y_u_t_a =PropertyLease.find_by_sql("select count(*) as current_year_units_total_actual from #{unit_table_name} gu1 left join #{tenant_table_name} t on t.sUnitCode=gu1.sCode and ((t.DTLEASEFROM < '#{year}-#{month}-31') and (t.dtLeaseTo > '#{year}-#{month}-31') or t.dtLeaseTo is null or t.dtLeaseFrom is null) AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) where gu1.HPROPERTY = #{hmy}")[0]
          c_y_u_v_a = PropertyLease.find_by_sql("SELECT count(*) as current_year_units_vacant_actual FROM #{unit_table_name} u LEFT JOIN #{tenant_table_name} t ON t.hUnit = u.hMy AND ((t.DTLEASEFROM < '#{year}-#{month}-31' OR t.dtLeaseFrom IS NULL) AND (t.dtLeaseTo > '#{year}-#{month}-31' OR t.dtLeaseTo IS NULL)) AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) AND t.hProperty = u.hProperty  LEFT JOIN Griffin_UnitType u_t ON u_t.hmy = u.HUNITTYPE WHERE u.HPROPERTY = #{hmy} AND t.sFirstName  IS NULL and t.sLastName  IS NULL")[0]
          c_y_s_o_a = PropertyLease.find_by_sql("select SUM(DSQFT) as current_year_sf_occupied_actual from #{unit_table_name} gu2 left join #{tenant_table_name} t on t.sUnitCode=gu2.sCode where (gu2.sStatus = 'Occupied No Notice' or gu2.sStatus like 'Vacant Rented%') and gu2.HPROPERTY = #{hmy} and ((t.DTLEASEFROM between '#{year}-01-01' and '#{year}-#{month}-31') and (t.dtLeaseTo > '#{year}-#{month}-31') or t.dtLeaseTo is null or t.dtLeaseFrom is null) AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL )")[0]
          v_l_n =  PropertyLease.find_by_sql("select count(*) as vacant_leased_number from #{unit_table_name} gu3 left join #{tenant_table_name} t on t.sUnitCode=gu3.sCode  and ((t.DTLEASEFROM < '#{year}-#{month}-31') and (t.dtLeaseTo > '#{year}-#{month}-31') or t.dtLeaseTo is null or t.dtLeaseFrom is null AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL ))  where gu3.sStatus like 'Vacant Rented%' and gu3.HPROPERTY = #{hmy}")[0]
          o_p_n =PropertyLease.find_by_sql(" select (count(*) * 100 / (select count(*) from Griffin_unit gu3 left join #{tenant_table_name} t on t.sUnitCode=gu3.sCode where gu3.HPROPERTY=#{hmy} and ((t.DTLEASEFROM between '#{year}-01-01' and '#{year}-#{month}-31') and (t.dtLeaseTo > '#{year}-#{month}-31') or t.dtLeaseTo is null or t.dtLeaseFrom is null))) as occupied_preleased_number from Griffin_unit gu3 left join #{tenant_table_name} t on t.sUnitCode=gu3.sCode and ((t.DTLEASEFROM < '#{year}-#{month}-31') and (t.dtLeaseTo > '#{year}-#{month}-31') or t.dtLeaseTo is null or t.dtLeaseFrom is null) AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) where sStatus like 'Notice Rented%' and gu3.HPROPERTY=#{hmy}")[0]
          o_on_n_n = PropertyLease.find_by_sql("(select count(*) as occupied_on_notice_number from #{unit_table_name} gu5 left join #{tenant_table_name} t on t.sUnitCode=gu5.sCode and ((t.DTLEASEFROM < '#{year}-#{month}-31') and (t.dtLeaseTo > '#{year}-#{month}-31') or t.dtLeaseTo is null or t.dtLeaseFrom is null AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL))  where sStatus like 'Notice UnRented%' and gu5.HPROPERTY = #{hmy})")[0]
          v_u = PropertyLease.find_by_sql("(select count(*) as vacant_unrented from #{unit_table_name} gu7 left join #{tenant_table_name} t on t.sUnitCode=gu7.sCode and ((t.DTLEASEFROM < '#{year}-#{month}-31') and (t.dtLeaseTo > '#{year}-#{month}-31') or t.dtLeaseTo is null or t.dtLeaseFrom is null AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL)) where gu7.sStatus like 'Vacant UnRented%' and gu7.HPROPERTY = #{hmy})")[0]
          current_year_sf_vacant_actual  = t_b_r_s.total_building_rentable_s.to_f - c_y_s_o_a.current_year_sf_occupied_actual.to_f
          vacant_leased_percentage = (v_l_n.vacant_leased_number.to_f / c_y_u_t_a.current_year_units_total_actual.to_f) * 100 rescue 0
          currently_vacant_leases_number = v_l_n.vacant_leased_number.to_f + v_u.vacant_unrented.to_f rescue 0
          currently_vacant_leases_percentage = ( currently_vacant_leases_number.to_f) / (c_y_u_t_a.current_year_units_total_actual.to_f) * 100 rescue 0
          occupied_preleased_percentage = (o_p_n.occupied_preleased_number.to_f) / (c_y_u_t_a.current_year_units_total_actual.to_f) rescue 0
          occupied_on_notice_number = o_p_n.occupied_preleased_number.to_f  + o_on_n_n.occupied_on_notice_number.to_f rescue 0
          occupied_on_notice_percentage = (occupied_on_notice_number.to_f ) / (c_y_u_t_a.current_year_units_total_actual.to_f) * 100 rescue 0
          net_exposure_to_vacancy_number = (currently_vacant_leases_number.to_f - v_l_n.vacant_leased_number.to_f) + (occupied_on_notice_number.to_f - o_p_n.occupied_preleased_number.to_f) rescue 0
          net_exposure_to_vacancy_percentage = (net_exposure_to_vacancy_number.to_f) / (c_y_u_t_a.current_year_units_total_actual.to_f) * 100 rescue 0
          total = ((c_y_s_o_a.current_year_sf_occupied_actual.to_f * 100) /(c_y_s_o_a.current_year_sf_occupied_actual.to_f + current_year_sf_vacant_actual.to_f)) rescue 0
          total = total.nan? ? 0 : total rescue 0
         c_y_u_o_a = c_y_u_t_a.current_year_units_total_actual.to_f - c_y_u_v_a.current_year_units_vacant_actual.to_f rescue 0
          #~ current_year_units_occupied_actual = (c_y_u_t_a.current_year_units_total_actual.to_f *   ((c_y_s_o_a.current_year_sf_occupied_actual.to_f * 100) /(c_y_s_o_a.current_year_sf_occupied_actual.to_f + current_year_sf_vacant_actual.to_f)).to_f)/100  rescue 0
          #current_year_units_vacant_actual = c_y_u_t_a.current_year_units_total_actual.to_f - current_year_units_occupied_actual.to_f rescue 0
          occupancy_year = year
          occupancy_month = month
          PropertyOccupancySummary.procedure_call(:total_building_rentable_s=>t_b_r_s.total_building_rentable_s.to_f,:current_year_sf_occupied_actual=>c_y_s_o_a.current_year_sf_occupied_actual.to_f,:current_year_sf_vacant_actual=>current_year_sf_vacant_actual.to_f,:current_year_units_total_actual =>c_y_u_t_a.current_year_units_total_actual.to_f,:vacant_leased_number=>v_l_n.vacant_leased_number.to_f,:vacant_leased_percentage=>vacant_leased_percentage.to_f,:currently_vacant_leases_number=>currently_vacant_leases_number.to_f,:currently_vacant_leases_percentage=>currently_vacant_leases_percentage.to_f,:occupied_preleased_number=>o_p_n.occupied_preleased_number.to_f,:occupied_preleased_percentage=>occupied_preleased_percentage.to_f,:occupied_on_notice_number=>occupied_on_notice_number.to_f,:occupied_on_notice_percentage=>occupied_on_notice_percentage.to_f,:net_exposure_to_vacancy_number=>net_exposure_to_vacancy_number.to_f,:net_exposure_to_vacancy_percentage=>net_exposure_to_vacancy_percentage.to_f,:current_year_units_occupied_actual=>c_y_u_o_a.to_f,:current_year_units_vacant_actual=>c_y_u_v_a.current_year_units_vacant_actual.to_f,:real_estate_property_id=>real_estate_property_id,:m_year=>occupancy_year,:m_month=>occupancy_month)
          p "inserting #{Date::MONTHNAMES[month]}-#{year} details of rent roll "
          lease_recs = PropertyLease.find_by_sql "SELECT CASE WHEN t.DTLEASEFROM BETWEEN '#{year}-01-01' AND '#{year}-#{month}-31' THEN 'new' WHEN t.dtLeaseTo BETWEEN '#{year}-01-01' AND '#{year}-#{month}-31' THEN 'expirations' ELSE 'current' END AS occupancy_type, IFNULL(concat(t.sFirstName,' ',t.sLastName), 'VACANT') as tenant_name, t.dtLeaseFrom AS 'Lease Start Date', coalesce( ( SELECT dContractArea FROM Griffin_commAmendments cAmend WHERE cAmend.hTenant = t.hMyPerson ORDER BY dtEnd DESC LIMIT 1 ), u.dSqft) AS rentable_area, t.sRent AS base_rent, t.dtLeaseTo AS lease_expiry, u.sCode AS suite_number, u.sStatus AS status, u_t.SCODE AS floor_plan FROM Griffin_unit u LEFT JOIN Griffin_tenant t ON t.hUnit = u.hMy AND ((t.DTLEASEFROM < '#{year}-#{month}-31' OR t.dtLeaseFrom IS NULL) AND (t.dtLeaseTo > '#{year}-#{month}-31' OR t.dtLeaseTo IS NULL)) AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) AND t.hProperty = u.hProperty LEFT JOIN Griffin_UnitType u_t ON u_t.hmy = u.HUNITTYPE WHERE u.HPROPERTY =#{hmy}"
          lease_recs.each do |line_item|
            lease_year = year
            lease_month =  month
            base_rent = leasing_type == 'Multifamily' ? nil : line_item.base_rent
            effRate  = leasing_type == 'Multifamily' ?  line_item.base_rent : nil
            suite = PropertySuite.procedure_call(:suiteIn=>line_item.suite_number, :realIn=>real_estate_property_id, :areaIn=>line_item.rentable_area.blank? ? 'NULL' : line_item.rentable_area, :spaceTypeIn=>'',:scodeIn=>line_item.floor_plan)
            PropertyLease.procedure_call(:propSuiteId=>suite['psid'], :nameIn=>line_item.tenant_name.strip, :startDate=> nil, :endDate=>"#{line_item.lease_expiry}", :baseRent=>base_rent, :effRate=>effRate, :tenantImp=>nil, :leasingComm=> nil , :monthIn=> lease_month, :yearIn=> lease_year, :otherDepIn=> nil, :commentsIn=>nil, :amtPerSQFT=>nil, :occType=>'current',:sStatus =>line_item.status )
          end
          break if month == Date.today.month && year == Date.today.year
        end
      end
    else
    lease_years.compact.uniq.each do |year|
  #To find last year property occupancy data
     last_yr_t_b_r_s = PropertyLease.find_by_sql("SELECT sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),gu.dSqft)) as total_building_rentable_s,gu.dtLastModified as last_modified FROM #{unit_table_name} gu left join #{tenant_table_name} t  on t.sUnitCode=gu.sCode where gu.HPROPERTY = #{hmy} and t.DTLEASEFROM < '#{year-1}-12-31 00:00:00' and t.dtLeaseTo > '#{year-1}-12-01 00:00:00'")[0]
    last_yr_s_o_a = PropertyLease.find_by_sql("select sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),gu2.dSqft)) as last_year_sf_occupied_actual from #{unit_table_name} gu2 left join #{tenant_table_name} t on t.sUnitCode=gu2.sCode where (gu2.sStatus = 'Occupied No Notice' or gu2.sStatus like 'Vacant Rented%') and gu2.HPROPERTY = #{hmy} and t.DTLEASEFROM < '#{year-1}-12-31 00:00:00' and t.dtLeaseTo > '#{year-1}-12-01 00:00:00'")[0]
  (1..12).each do |month|
     p "Preparing to insert the #{year} - #{Date::MONTHNAMES[month]}  details..."
    #To insert  property occupancy data
     t_b_r_s = PropertyLease.find_by_sql("SELECT  sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),gu.dSqft)) as total_building_rentable_s,gu.dtLastModified as last_modified FROM #{unit_table_name} gu left join #{tenant_table_name} t  on t.sUnitCode=gu.sCode and t.DTLEASEFROM < '#{year}-#{month}-31 00:00:00' and t.dtLeaseTo > '#{year}-#{month}-01 00:00:00' where gu.HPROPERTY = #{hmy} ")[0]
    next if  t_b_r_s.total_building_rentable_s  == nil  && t_b_r_s.last_modified == nil  || t_b_r_s.total_building_rentable_s  == "0"
   c_y_s_o_a = PropertyLease.find_by_sql("select sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),gu2.dSqft)) as current_year_sf_occupied_actual from #{unit_table_name} gu2 left join #{tenant_table_name} t on t.sUnitCode=gu2.sCode and t.DTLEASEFROM < '#{year}-#{month}-31 00:00:00' and t.dtLeaseTo > '#{year}-#{month}-01 00:00:00' where (gu2.sStatus = 'Occupied No Notice' or gu2.sStatus like 'Vacant Rented%') and gu2.HPROPERTY = #{hmy} ")[0]
    current_year_sf_vacant_actual  = t_b_r_s.total_building_rentable_s.to_f - c_y_s_o_a.current_year_sf_occupied_actual.to_f
    #To find new leases and lease expiry
    new_leases = PropertyLease.find_by_sql("select sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),u.dSqft)) as new_lease from #{unit_table_name} u left join #{tenant_table_name} t on t.sUnitCode=u.sCode and t.hProperty=u.hProperty and u.hProperty = #{hmy} and (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) where t.DTLEASEFROM between '#{year}-01-01' and '#{year}-#{month}-31'")
    lease_expiry= PropertyLease.find_by_sql("select sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),u.dSqft)) as lease_expiry from #{unit_table_name} u left join #{tenant_table_name} t on t.sUnitCode=u.sCode and t.hProperty=u.hProperty and u.hProperty = #{hmy} and  (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) where t.dtLeaseTo between '#{year}-01-01' and '#{year}-#{month}-31'")
    #Insert into property occupancy summary
    PropertyOccupancySummary.procedure_call_for_commercial_occupancy(:current_yr_sf_occupiedIn=>c_y_s_o_a.current_year_sf_occupied_actual,:current_year_sf_vacantIn=>current_year_sf_vacant_actual,:yearIn=>year,:monthIn=>month,:new_leasesIn=>new_leases[0].new_lease,:lease_expiryIn=>lease_expiry[0].lease_expiry,:real_estate_property_id=>real_estate_property_id,:last_year_sf_occupied_actualIn=>last_yr_s_o_a.last_year_sf_occupied_actual)
    #Insert into property leases and property suites

    lease_recs = PropertyLease.find_by_sql("SELECT case WHEN t.DTLEASEFROM BETWEEN '#{year}-01-01' and '#{year}-#{month}-31' THEN 'new' WHEN t.dtLeaseTo BETWEEN '#{year}-01-01' AND '#{year}-#{month}-31' THEN 'expirations' else 'current' END AS occupancy_type, IFNULL(concat(t.sFirstName,' ',t.sLastName), 'VACANT') as tenant_name, t.dtLeaseFrom AS 'Lease Start Date', coalesce( (SELECT dContractArea FROM Griffin_commAmendments cAmend WHERE cAmend.hTenant = t.hMyPerson ORDER BY dtEnd DESC LIMIT 1), u.dSqft ) AS rentable_area, t.sRent AS base_rent, t.dtLeaseTo AS lease_expiry, u.sCode AS suite_number, u.sStatus AS status FROM Griffin_unit u LEFT JOIN Griffin_tenant t ON t.hUnit = u.hMy AND ((t.DTLEASEFROM < '#{year}-#{month}-31' OR t.dtLeaseFrom IS NULL) or (t.dtLeaseTo > '#{year}-#{month}-31' OR t.dtLeaseTo IS NULL)) AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) AND t.hProperty = u.hProperty LEFT JOIN Griffin_UnitType u_t ON u_t.hmy = u.HUNITTYPE WHERE u.HPROPERTY =#{hmy}")
    lease_recs.each do |line_item|
      lease_year = year
      lease_month =  month
      base_rent = leasing_type == 'Multifamily' ? nil : line_item.base_rent
      effRate  = leasing_type == 'Multifamily' ?  line_item.base_rent : nil
      suite = PropertySuite.procedure_call(:suiteIn=>line_item.suite_number, :realIn=>real_estate_property_id, :areaIn=>line_item.rentable_area.blank? ? 'NULL' : line_item.rentable_area, :spaceTypeIn=>'',:scodeIn=>'')
      PropertyLease.procedure_call(:propSuiteId=>suite['psid'], :nameIn=>line_item.tenant_name.strip, :startDate=> nil, :endDate=>"#{line_item.lease_expiry}", :baseRent=>base_rent, :effRate=>effRate, :tenantImp=>nil, :leasingComm=> nil , :monthIn=> lease_month, :yearIn=> lease_year, :otherDepIn=> nil, :commentsIn=>nil, :amtPerSQFT=>nil, :occType=>line_item.occupancy_type,:sStatus =>line_item.status )
    end
  end
end
end

   #.................................................................................................Import Lease and rent roll data into master table ends here.......................................................................................................

end
end