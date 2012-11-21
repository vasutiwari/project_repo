# AMP - Parsing Unit.
module YardiParser

  # Parse the yardi rent roll file.
  # Check whether the file should be uploaded to the sub folders of "Excel Uploads" folder.
  def parse_yardi_rent_roll_files(tmp_doc,curr_user_id)
    parent_folder = Folder.find_by_id(tmp_doc.folder_id)
    gr_parent_folder = Folder.find_by_id(parent_folder.parent_id) if !parent_folder.nil?
    gr_gr_parent_folder = Folder.find_by_id(gr_parent_folder.parent_id) if !gr_parent_folder.nil?
    sql = ActiveRecord::Base.connection();
    tm_doc = "#{Rails.root.to_s}/public"+ tmp_doc.public_filename
    tm_xml=tm_doc.split('.')
    tm_xml.pop
    tm_xml=(tm_xml*".")+".xml"
    if !gr_gr_parent_folder.nil?
      if gr_gr_parent_folder.name == "Excel Uploads"
        if  tmp_doc.filename.downcase.include?("financials")
          tmp_doc.update_attribute('parsing_done',nil)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"AMP,financials",curr_user_id)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
          sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
        end
        if tmp_doc.filename.downcase.include?("rentroll")
          tmp_doc.update_attribute('parsing_done',nil)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"YARDI,rent",curr_user_id)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
        elsif tmp_doc.filename.downcase.include?("boxscoresummary")
          tmp_doc.update_attribute('parsing_done',nil)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"YARDI,summary",curr_user_id)
#          initiate_amp_parser(tmp_doc)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
        end
      end
    end
  end

  def store_yardi_rent_roll_files
    doc = Document.find_by_id(@options[:doc_id])
    occ_type = ''
    get_all_sheets.each do |sheet|
      if !read_via_numeral_abs(1, 1, sheet).blank? and read_via_numeral_abs(1, 1, sheet).downcase == 'rent roll'
        ver = read_via_numeral_abs(4, 1, sheet).split('=').last.split('/') unless read_via_numeral_abs(4, 1, sheet).blank?
        #property_occupancy_summary = PropertyOccupancySummary.find_or_create_by_real_estate_property_id_and_year_and_month(doc.real_estate_property_id,ver[1].strip,ver[0].strip)
        6.upto find_last_base_cell(sheet) do |row|
          next if read_via_numeral_abs(row, 1, sheet).blank? and read_via_numeral_abs(row, 2, sheet).blank? # blank will not be parsed
          if !read_via_numeral_abs(row, 1, sheet).blank? and read_via_numeral_abs(row, 2, sheet).blank? then occ_type = read_via_numeral_abs(row, 1, sheet); next end
          unless read_via_numeral_abs(row, 1, sheet).blank? and !read_via_numeral_abs(row, 2, sheet).blank?
            property_suite = PropertySuite.find_or_create_by_suite_number_and_floor_plan_and_rented_area_and_real_estate_property_id(read_via_numeral_abs(row, 1, sheet).gsub('.00', '').gsub('.0', ''), read_via_numeral_abs(row, 2, sheet),read_via_numeral_abs(row, 3, sheet),doc.real_estate_property_id)
            property_suite.update_attribute('client_id',doc.real_estate_property.client_id)
            h = {} # Occ type has to be added.
            h['base_rent'] = read_via_numeral_abs(row, 6, sheet)
            h['effective_rate'] = read_via_numeral_abs(row, 7, sheet)
            h['tenant'] = read_via_numeral_abs(row, 5, sheet)
            h['start_date'] = read_via_numeral_abs(row, 10, sheet)
            h['end_date'] = read_via_numeral_abs(row, 11, sheet)
            h['other_deposits'] = read_via_numeral_abs(row, 8, sheet).to_i + read_via_numeral_abs(row, 9, sheet).to_i
            h['property_suite_id'] = property_suite.id  if !property_suite.nil?
            h['month'] = ver[0].strip#property_occupancy_summary.month
            h['year'] = ver[1].strip#property_occupancy_summary.year
            h['occ_type'] = occ_type
            h['actual_amt_per_sqft'] = h['effective_rate'].to_f/(read_via_numeral_abs(row, 3, sheet).blank? ? 1 : read_via_numeral_abs(row, 3, sheet).to_i)
            PropertyLease.procedure_call_amp_all_units(:propSuiteId=>h['property_suite_id'].blank? ? nil : h['property_suite_id'], :nameIn=>h['tenant'].blank? ? nil : h['tenant'], :startDate=>h['start_date'].blank? ? nil : h['start_date'], :endDate=>h['end_date'].blank? ? nil : h['end_date'],:baseRent=>h['base_rent'].blank? ? nil : h['base_rent'] , :effRate=>h['effective_rate'].blank? ? nil : h['effective_rate'], :tenantImp=>nil,  :leasingComm=>nil, :monthIn=>h['month'].blank? ? nil : h['month'], :yearIn=>h['year'].blank? ? nil : h['year'], :otherDepIn=> h['other_deposits'].blank? ? nil : h['other_deposits'], :commentsIn=>nil,  :amtPerSQFT=>h['amt_per_sqft'].blank? ? nil : h['amt_per_sqft'], :occType=> h['occ_type'].blank? ? nil :  h['occ_type'], :moveIn=> (h['move_in'].blank? or h['move_in'].class == String) ? nil : h['move_in'].strftime("%Y-%m-%d %H:%M:%S"), :madeReadyIn=> h['made_ready'].blank? ? nil : h['made_ready'], :actAmtPerSQFT=>h['actual_amt_per_sqft'].blank? ? nil : h['actual_amt_per_sqft'])
          end
        end
      end
    end
  end

  # parsing the boxscore monthly files.
  def store_yardi_summary_files
    doc = Document.find_by_id(@options[:doc_id])
    period = ''
    date_err = false
    month = year = nil
    get_all_sheets.each do |sheet|
      if !read_via_numeral_abs(1, 1, sheet).blank? and read_via_numeral_abs(1, 1, sheet).downcase == 'boxscore summary'
        unless read_via_numeral_abs(3, 1, sheet).blank?
          dts =  read_via_numeral_abs(3, 1, sheet).split(' = ').last.split('-')
          begin
            dts[0] = dts[0].to_date
            dts[1] = dts[1].to_date
          rescue
            date_err = true
          end
          unless date_err
            if dts[0] < dts[1] && dts[0].month == dts[1].month && (dts[1] - dts[0]).to_i > 27 && dts[1].year == dts[0].year
              month = dts[0].month
              year  = dts[0].year
              period = 'year'
            elsif dts[0] < dts[1] && (dts[1] - dts[0]).to_i == 6
              period = 'weekly'
            else
              period = 'quit'
              doc.update_attribute('parsing_done',false)
            end
          end
        end
        if period == 'year'
          6.upto find_last_base_cell(sheet) do |row|
            if read_via_numeral_abs(row, 1, sheet).blank? and !read_via_numeral_abs(row, 2, sheet).blank? and read_via_numeral_abs(row, 2, sheet).strip == 'Total'
              property_occupancy_summary = PropertyOccupancySummary.find_or_create_by_real_estate_property_id_and_year_and_month(doc.real_estate_property_id, year, month)
              property_occupancy_summary.total_building_rentable_s = read_via_numeral_abs(row, 3, sheet)
              property_occupancy_summary.current_year_sf_occupied_actual = (property_occupancy_summary.total_building_rentable_s.to_f * (read_via_numeral_abs(row,17,sheet).blank? ? 1 :  read_via_numeral_abs(row,17,sheet).to_f)) / 100 rescue 0
               property_occupancy_summary.current_year_sf_vacant_actual = property_occupancy_summary.total_building_rentable_s - property_occupancy_summary.current_year_sf_occupied_actual  rescue 0
              property_occupancy_summary.vacant_leased_number = read_via_numeral_abs(row, 7, sheet).blank? ? 0 : read_via_numeral_abs(row, 7, sheet).to_i
              property_occupancy_summary.vacant_leased_percentage = (property_occupancy_summary.vacant_leased_number.to_f / (read_via_numeral_abs(row, 5, sheet).blank? ? 1 : read_via_numeral_abs(row, 5, sheet).to_f)) * 100 rescue 0
              property_occupancy_summary.currently_vacant_leases_number = property_occupancy_summary.vacant_leased_number + (read_via_numeral_abs(row, 8, sheet).blank? ? 0 : read_via_numeral_abs(row, 8, sheet).to_f)
              property_occupancy_summary.currently_vacant_leases_percentage = ( property_occupancy_summary.currently_vacant_leases_number.to_f / (read_via_numeral_abs(row, 5, sheet).blank? ? 1 : read_via_numeral_abs(row, 5, sheet).to_f)) * 100 rescue 0
              property_occupancy_summary.occupied_preleased_number = read_via_numeral_abs(row, 9, sheet).blank? ? 0 : read_via_numeral_abs(row, 9, sheet).to_i
              property_occupancy_summary.occupied_preleased_percentage = (property_occupancy_summary.occupied_preleased_number.to_f / (read_via_numeral_abs(row, 5, sheet).blank? ? 1 : read_via_numeral_abs(row, 5, sheet).to_f)) * 100 rescue 0
              property_occupancy_summary.occupied_on_notice_number = property_occupancy_summary.occupied_preleased_number + (read_via_numeral_abs(row, 10, sheet).blank? ? 0 : read_via_numeral_abs(row, 10, sheet).to_i)
              property_occupancy_summary.occupied_on_notice_percentage = (property_occupancy_summary.occupied_on_notice_number.to_f / (read_via_numeral_abs(row, 5, sheet).blank? ? 1 : read_via_numeral_abs(row, 5, sheet).to_f)) * 100 rescue 0
              property_occupancy_summary.net_exposure_to_vacancy_number = (property_occupancy_summary.currently_vacant_leases_number - property_occupancy_summary.vacant_leased_number) + (property_occupancy_summary.occupied_on_notice_number - property_occupancy_summary.occupied_preleased_number)
              property_occupancy_summary.net_exposure_to_vacancy_percentage = (property_occupancy_summary.net_exposure_to_vacancy_number.to_f / (read_via_numeral_abs(row, 5, sheet).blank? ? 1 : read_via_numeral_abs(row, 5, sheet).to_f)) * 100 rescue 0
              property_occupancy_summary.current_year_units_total_actual = read_via_numeral_abs(row, 5, sheet).to_f
              property_occupancy_summary.current_year_units_occupied_actual = (property_occupancy_summary.current_year_units_total_actual.to_f * (read_via_numeral_abs(row,17,sheet).blank? ? 1 :  read_via_numeral_abs(row,17,sheet).to_f)) / 100 rescue 0
               property_occupancy_summary.current_year_units_vacant_actual = property_occupancy_summary.current_year_units_total_actual - property_occupancy_summary.current_year_units_occupied_actual  rescue 0
              property_occupancy_summary.save
              break
            end
          end if !date_err && month && year && period # check the excel file is valid.
        elsif period == "weekly"
          index_hash = {}
          availability, conversion = false, false
          4.upto find_last_base_cell(sheet) do |row|
            if !read_via_numeral_abs(row, 1, sheet).blank? && ["Availability", "Conversion Ratios", "Resident Activity"].include?(read_via_numeral_abs(row, 1, sheet))
              availability = true if read_via_numeral_abs(row, 1, sheet) == "Availability"
              conversion = true if read_via_numeral_abs(row, 1, sheet) == "Conversion Ratios"
            elsif read_via_numeral_abs(row, 1, sheet).blank? && !read_via_numeral_abs(row, 2, sheet).blank? && read_via_numeral_abs(row, 2, sheet) == 'Total'
              availability, conversion = false, false
            elsif !read_via_numeral_abs(row, 1, sheet).blank? && !read_via_numeral_abs(row, 2, sheet).blank?
              if availability
                index_hash.update({read_via_numeral_abs(row, 1, sheet)=> ''})
              elsif conversion
                index_hash.update({read_via_numeral_abs(row, 1, sheet)=> row}) if index_hash.include? read_via_numeral_abs(row, 1, sheet)
              end
            end
          end
          4.upto find_last_base_cell(sheet) do |row|
            unless read_via_numeral_abs(row, 1, sheet) == 'Code' && index_hash.include?(read_via_numeral_abs(row, 1, sheet))
              obj = PropertyWeeklyOsr.find_or_initialize_by_real_estate_property_id_and_floor_plan_and_time_period(doc.real_estate_property_id, read_via_numeral_abs(row, 1, sheet),dts[1].strftime("%Y-%m-%d"))
              obj.user_id = doc.user_id
              obj.units = read_via_numeral_abs(row, 5, sheet)
              obj.prelsd = read_via_numeral_abs(row, 7, sheet).blank? ? 0 : read_via_numeral_abs(row, 7, sheet).to_i
              obj.vacant_total = obj.prelsd + (read_via_numeral_abs(row, 8, sheet).blank? ? 0 : read_via_numeral_abs(row, 8, sheet).to_i)
              obj.prelsd2 = read_via_numeral_abs(row, 9, sheet).blank? ? 0 : read_via_numeral_abs(row, 9, sheet).to_i
              obj.ntv_status_total = obj.prelsd2 + (read_via_numeral_abs(row, 10, sheet).blank? ? 0 : read_via_numeral_abs(row, 10, sheet).to_i)
              obj.current = obj.vacant_total + obj.ntv_status_total
              obj.pi_total = read_via_numeral_abs(index_hash[read_via_numeral_abs(row, 1, sheet)], 3, sheet)
              obj.wi_total = read_via_numeral_abs(index_hash[read_via_numeral_abs(row, 1, sheet)], 4, sheet)
              obj.dep_total = read_via_numeral_abs(index_hash[read_via_numeral_abs(row, 1, sheet)], 9, sheet)
              obj.dep_rej = read_via_numeral_abs(index_hash[read_via_numeral_abs(row, 1, sheet)], 14, sheet)
              obj.dep_canc = read_via_numeral_abs(index_hash[read_via_numeral_abs(row, 1, sheet)], 15, sheet)
              obj.save
            end if !read_via_numeral_abs(row, 1, sheet).blank? && !read_via_numeral_abs(row, 2, sheet).blank?
            break if read_via_numeral_abs(row, 1, sheet).blank? && !read_via_numeral_abs(row, 2, sheet).blank? && read_via_numeral_abs(row, 2, sheet) == 'Total'
          end unless index_hash.empty?
        end
      end
    end
  end
end
