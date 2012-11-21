# Amp parsing helper.
# It will parse the universal - amp template for the financials
module AmpParsingHelper

  def amp_parsing_for_excel(tmp_doc,curr_user_id)
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
        if @portfolio.leasing_type=="Multifamily"
          if  tmp_doc.filename.downcase.include?("leasing")
            tmp_doc.update_attribute('parsing_done',nil)
            Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"AMP,leases",curr_user_id)
            ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
            sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
          end
        elsif @portfolio.leasing_type=="Commercial"
          if  tmp_doc.filename.downcase.include?("capexp")
            tmp_doc.update_attribute('parsing_done',nil)
            Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"AMP,capital",curr_user_id)
            ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
            sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
          elsif  tmp_doc.filename.downcase.include?("occupancy")
            tmp_doc.update_attribute('parsing_done',nil)
            Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"AMP,occupancy",curr_user_id)
            ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
            sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
          elsif  tmp_doc.filename.downcase.include?("rent_roll")
            tmp_doc.update_attribute('parsing_done',nil)
            Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"AMP,rent",curr_user_id)
            ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
            sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
          elsif  tmp_doc.filename.downcase.include?("aging")
            tmp_doc.update_attribute('parsing_done',nil)
            Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"AMP,aged",curr_user_id)
            ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
            sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
          end
        end
      end
    end
  end

  def initiate_amp_parser(tmp_doc) # will be removed shortly
    tm_doc = "#{Rails.root.to_s}/public"+ tmp_doc.public_filename
    tm_xml=tm_doc.split('.')
    tm_xml.pop
    tm_xml=(tm_xml*".")+".xml"
    budget_parser = XmlExtractor.new(:month=>1, :year=>2011, :real_estate_id=> tmp_doc.real_estate_property_id, :user_id=> tmp_doc.user_id, :doc_id=>tmp_doc.id)
    budget_parser.xls_file = tm_doc
    budget_parser.output_file = tm_xml
    budget_parser.xml_dump
    budget_parser.process!("SWIG,capital")
  end

  def amp_parsing_financials
    doc = Document.find_by_id(@options[:doc_id])
    real_estate_property_id = doc.real_estate_property_id;
    acc_type = RealEstateProperty.find_by_sql("select accounting_type from real_estate_properties where id = #{real_estate_property_id}").first.accounting_type rescue nil
    @store_details_array = []
    is_sub_detail_part = false
    sub_detail_headers = nil
    sub_detail_id = nil
    sub_detail_head = nil
    pcb = year = nil
    get_all_sheets.each do |sheet|
      if find_sheet_name(sheet).downcase == 'financials' or (find_sheet_name(sheet).downcase == "cash flow statement" && acc_type == "Accrual")# Parse only the Financials named sheet
        pcb = 'b' if read_via_numeral_abs(1,5, sheet).downcase.strip.include? 'budget' # Check the budget financials presents in the file.
        pcb = 'c' if read_via_numeral_abs(1,5, sheet).downcase.strip.include? 'actual' # This is to determine the sheet for actual or budget
        year = read_via_numeral_abs(3,4,sheet).to_s.split('-').first if read_via_numeral_abs(3,4,sheet).to_s.split('-').first.length == 4  #if date_fetch(3, 4, sheet) == :date
        @financial_year = year
        headers = Array.new # Used to collect the heads and sub items from the excel file
        # Parsing will be started from the 6 line(row) the excel sheet.
        # Anything prior to the sixth line wont be taken for parsing        if sheet == '2'
        if find_sheet_name(sheet).downcase == 'financials'
          update_income_data= IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(real_estate_property_id,"RealEstateProperty", year).map(&:title) - fetch_base_cell_titles
          update_income_data= '("'+update_income_data*'","'+'")'
          ActiveRecord::Base.connection.execute("update income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.pcb_type = '#{pcb}' and pf.source_type='IncomeAndCashFlowDetail' set pf.january=0, pf.february=0, pf.march=0, pf.april=0, pf.may=0, pf.june=0, pf.july=0, pf.august=0, pf.september=0, pf.october=0, pf.november=0, pf.december=0 where ic.title in #{update_income_data} and ic.resource_id = #{real_estate_property_id} and ic.resource_type = 'RealEstateProperty' and ic.year=#{year};") unless update_income_data == "(\"\")" and year.blank? and pcb.blank?
          6.upto find_last_base_cell(sheet) do |row|
            next if read_via_numeral_abs(row, 3, sheet).blank? # blank will not be parsed
            unless is_sub_detail_part
              # Check the 'C' has value and 'D' doesn't have value then it('C') should be a title or head
              # The title or head found then create a income and cash flow record.
              # the created cash flow record id will become the parent id of the subordinate items.
              if !read_via_numeral_abs(row, 3, sheet).blank? and read_via_numeral_abs(row, 4, sheet).blank?
                unless read_via_numeral_abs(row, 3, sheet).include? "Sub Detail"
                  unless read_via_numeral_abs(row, 3, sheet).include? "End Key Numbers & Ratios"
                    income_detail = IncomeAndCashFlowDetail.procedure_call(:titleIn=>read_via_numeral_abs(row, 3, sheet),:realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=>headers.count.zero? ? 'NULL' : headers.last,:userIn=>doc.user_id, :yearIn=>year)
                    headers.push income_detail['id']
                  end
                  # pushing the financial items.
                  # 'TOTAL VARIABLE OPERATING..' record will be a separate item which doesn't have parent id
                else
                  sub_detail_headers = read_via_numeral_abs(row, 3, sheet).split('Sub Detail').first.strip
                  is_sub_detail_part = true
                end
              elsif !read_via_numeral_abs(row, 3, sheet).blank? and !read_via_numeral_abs(row, 4, sheet).blank?
                if read_via_numeral_abs(row, 3, sheet).include? "TOTAL VARIABLE OPERATING EXP"
                  income_detail = IncomeAndCashFlowDetail.procedure_call(:titleIn=>read_via_numeral_abs(row, 3, sheet),:realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=>'NULL',:userIn=>doc.user_id, :yearIn=>year)
                  push_financial_record(income_detail['id'], [read_via_numeral(row, 4, sheet), read_via_numeral(row, 5, sheet), read_via_numeral(row, 6, sheet), read_via_numeral(row, 7, sheet), read_via_numeral(row, 8, sheet), read_via_numeral(row, 9, sheet), read_via_numeral(row, 10, sheet), read_via_numeral(row, 11, sheet), read_via_numeral(row, 12, sheet), read_via_numeral(row, 13, sheet), read_via_numeral(row, 14, sheet), read_via_numeral(row, 15, sheet)], pcb)
                  # The item or title doesn't contain 'total' then it should be an sub items with financial values
                  # items with 'total' is the finalizer of the header or placeholder
                elsif read_via_numeral_abs(row, 3, sheet).include? "Total Reserves" or read_via_numeral_abs(row, 3, sheet).include? "Net Income Before Debt Service" or (!read_via_numeral_abs(row, 3, sheet).downcase.include? "total " and !read_via_numeral_abs(row, 3, sheet).include? "NOI" and !read_via_numeral_abs(row, 3, sheet).include? "Net Non Operating Income" and !read_via_numeral_abs(row, 3, sheet).include? "Net Income" and !read_via_numeral_abs(row, 3, sheet).include? "End Key Numbers & Ratios")
                  income_detail = IncomeAndCashFlowDetail.procedure_call(:titleIn=>read_via_numeral_abs(row, 3, sheet),:realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=>headers.last, :userIn=>doc.user_id, :yearIn=>year)
                  push_financial_record(income_detail['id'], [read_via_numeral(row, 4, sheet), read_via_numeral(row, 5, sheet), read_via_numeral(row, 6, sheet), read_via_numeral(row, 7, sheet), read_via_numeral(row, 8, sheet), read_via_numeral(row, 9, sheet), read_via_numeral(row, 10, sheet), read_via_numeral(row, 11, sheet), read_via_numeral(row, 12, sheet), read_via_numeral(row, 13, sheet), read_via_numeral(row, 14, sheet), read_via_numeral(row, 15, sheet)], pcb)
                else
                  unless read_via_numeral_abs(row, 3, sheet).include? "End Key Numbers & Ratios"
                    push_financial_record(headers.last, [read_via_numeral(row, 4, sheet), read_via_numeral(row, 5, sheet), read_via_numeral(row, 6, sheet), read_via_numeral(row, 7, sheet), read_via_numeral(row, 8, sheet), read_via_numeral(row, 9, sheet), read_via_numeral(row, 10, sheet), read_via_numeral(row, 11, sheet), read_via_numeral(row, 12, sheet), read_via_numeral(row, 13, sheet), read_via_numeral(row, 14, sheet), read_via_numeral(row, 15, sheet)], pcb)
                  end
                  headers.pop
                  # Here the head or placeholder have been finalized.
                end
              end
            else
              if !read_via_numeral_abs(row, 3, sheet).blank? and read_via_numeral_abs(row, 4, sheet).blank?
                if read_via_numeral_abs(row, 3, sheet).include? "Sub Detail"
                  # If the title includes 'Sub detail' then find out the cash flow record.
                  sub_detail_headers = read_via_numeral_abs(row, 3, sheet).split('Sub Detail').first.strip
                else
                  sub_detail_head = read_via_numeral_abs(row, 3, sheet).strip
                end
              elsif !read_via_numeral_abs(row, 3, sheet).blank? and !read_via_numeral_abs(row, 4, sheet).blank? and !sub_detail_headers.blank?
                if !read_via_numeral_abs(row, 3, sheet).downcase.include? "total "
                  sub_detail_id = sub_detail_headers(sub_detail_headers, real_estate_property_id, year) if sub_detail_id.blank?
                  sub_detail_par_id = sub_detail_parent_definer(sub_detail_id, sub_detail_head) if sub_detail_par_id.blank?
                  unless sub_detail_par_id.blank?
                    income_detail = IncomeAndCashFlowDetail.procedure_call(:titleIn=>read_via_numeral_abs(row, 3, sheet),:realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=>sub_detail_par_id, :userIn=>doc.user_id, :yearIn=>year)
                    push_financial_record(income_detail['id'], [read_via_numeral(row, 4, sheet), read_via_numeral(row, 5, sheet), read_via_numeral(row, 6, sheet), read_via_numeral(row, 7, sheet), read_via_numeral(row, 8, sheet), read_via_numeral(row, 9, sheet), read_via_numeral(row, 10, sheet), read_via_numeral(row, 11, sheet), read_via_numeral(row, 12, sheet), read_via_numeral(row, 13, sheet), read_via_numeral(row, 14, sheet), read_via_numeral(row, 15, sheet)], pcb)
                  end
                elsif read_via_numeral_abs(row, 3, sheet).downcase.include? "total "
                  sub_detail_id = nil
                  sub_detail_par_id = nil
                end
              end
            end
          end unless year.nil? && pcb.nil?
        elsif sheet == '3'
          6.upto find_last_base_cell(sheet) do |row|
            next if read_via_numeral_abs(row, 3, sheet).blank? or read_via_numeral_abs(row, 3, sheet).include? 'Only if using accrual accounting' # blank will not be parsed
            # Check the 'C' has value and 'D' doesn't have value then it('C') should be a title or head
            if !read_via_numeral_abs(row, 3, sheet).blank? and read_via_numeral_abs(row, 4, sheet).blank?
              income_detail = IncomeAndCashFlowDetail.procedure_call(:titleIn=>read_via_numeral_abs(row, 3, sheet),:realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=>headers.count.zero? ? 'NULL' : headers.last,:userIn=>doc.user_id, :yearIn=>year)
              headers.push income_detail['id']
            elsif !read_via_numeral_abs(row, 3, sheet).blank? and !read_via_numeral_abs(row, 4, sheet).blank?
              if read_via_numeral_abs(row, 3, sheet).downcase.include? "total " or read_via_numeral_abs(row, 3, sheet).downcase.include? "net cash flow"
                push_financial_record(headers.last, [read_via_numeral(row, 4, sheet), read_via_numeral(row, 5, sheet), read_via_numeral(row, 6, sheet), read_via_numeral(row, 7, sheet), read_via_numeral(row, 8, sheet), read_via_numeral(row, 9, sheet), read_via_numeral(row, 10, sheet), read_via_numeral(row, 11, sheet), read_via_numeral(row, 12, sheet), read_via_numeral(row, 13, sheet), read_via_numeral(row, 14, sheet), read_via_numeral(row, 15, sheet)], pcb)
                headers.pop
              else
                income_detail = IncomeAndCashFlowDetail.procedure_call(:titleIn=>read_via_numeral_abs(row, 3, sheet),:realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=>headers.last, :userIn=>doc.user_id, :yearIn=>year)
                push_financial_record(income_detail['id'], [read_via_numeral(row, 4, sheet), read_via_numeral(row, 5, sheet), read_via_numeral(row, 6, sheet), read_via_numeral(row, 7, sheet), read_via_numeral(row, 8, sheet), read_via_numeral(row, 9, sheet), read_via_numeral(row, 10, sheet), read_via_numeral(row, 11, sheet), read_via_numeral(row, 12, sheet), read_via_numeral(row, 13, sheet), read_via_numeral(row, 14, sheet), read_via_numeral(row, 15, sheet)], pcb)
              end
            end
          end unless year.nil? && pcb.nil?
        end
      end
    end
    update_property_financial_periods_via_mysql(@store_details_array*',')
    # Do the variance calculations only when the property has the actual and budget records in db for the par. year
    store_variance_details(real_estate_property_id, "RealEstateProperty")
    #Code to update the Income And Cash Flow details of the related Portfolios of that Property - start#
    doc = Document.find_by_id(@options[:doc_id])
    @real_estate_property = RealEstateProperty.find_by_id(doc.real_estate_property_id)
        portfolios_collect = @real_estate_property.portfolios
        portfolios_collect.each do |portfolio|
            Portfolio.portfolio_ic(portfolio.id, @finanical_year)
          end
    #ends here#
  end

  def push_financial_record(data, lvl, type, source="IncomeAndCashFlowDetail")
    # create the financial items and records for the cash flow item.
    pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>data, :sourceTypeIn=>source, :pcbIn=>type)
    arr = []
    lvl.each_with_index do |sub, ind|  arr << sub.to_f  end
    arr.fill('NULL', (Date.today.day > 25 ? Date.today.month : Date.today.month - 1 )..11) if type == 'c' and @financial_year.to_i == Date.today.year
    @store_details_array << "(#{pf["pfid"]},"+arr.join(',')+")"
    unless type.tainted? # Functionality under review need be finalized.
      chk = {'c'=>'b','b'=>'c'}
      type = chk[type]
      proceed = PropertyFinancialPeriod.find(:first, :conditions=>["source_id=#{data} and source_type='#{source}' and pcb_type='#{type}'"], :select=>:id)
      type.taint
      push_financial_record(data, Array.new(12, 0), type, source) if proceed.blank?
    end
  end

  def amp_extract_capital_improvement
    doc = Document.find_by_id(@options[:doc_id])
    real_estate_property_id = doc.real_estate_property_id;
    @store_details_array = []
    pcb = year = month =  nil
    get_all_sheets.each do |sheet|
      if find_sheet_name(sheet).downcase.include? 'cap'
        pcb = 'b' if read_via_numeral_abs(1,7, sheet).downcase.strip.include? 'budget' # Check the type for cap exp presents in the file.
        pcb = 'c' if read_via_numeral_abs(1,7, sheet).downcase.strip.include? 'actual' # This is to determine the sheet for actual or budget
        year = read_via_numeral_abs(3,6,sheet).to_s.split('-').first if read_via_numeral_abs(3,6,sheet).to_s.split('-').first.length == 4 #check the col contains year
        @financial_year = year
        month = 1 if year
        category = ""
        # Existing items will be removed from db after uploading the new version (review).
        # ActiveRecord::Base.connection.execute("delete t1, t2 from property_capital_improvements as t1, property_financial_periods as t2 where t1.real_estate_property_id = #{real_estate_property_id} and t1.month= #{month} and t1.year= #{year} and t2.source_id = t1.id and t2.source_type= '#{pcb}' and t2.source_type ='PropertyCapitalImprovement';")
        update_income_data = PropertyCapitalImprovement.find_all_by_real_estate_property_id_and_year(real_estate_property_id, year).map(&:tenant_name) - fetch_base_cell_titles
        update_income_data='("'+update_income_data*'","'+'")'
        ActiveRecord::Base.connection.execute("update property_capital_improvements pc left join property_financial_periods pf on pf.source_id = pc.id and pf.pcb_type = '#{pcb}' and pf.source_type='PropertyCapitalImprovement' set #{pcb=='b'? 'pc.annual_budget=0, ':''} pf.january=0, pf.february=0, pf.march=0, pf.april=0, pf.may=0, pf.june=0, pf.july=0, pf.august=0, pf.september=0, pf.october=0, pf.november=0, pf.december=0 where pc.tenant_name in #{update_income_data} and pc.real_estate_property_id = #{real_estate_property_id} and pc.year=#{year};") unless update_income_data == "(\"\")" and year.blank? and pcb.blank?
        8.upto find_last_base_cell(sheet) do |row|
          next if read_via_numeral_abs(row, 5, sheet).blank?
          if !read_via_numeral_abs(row, 5, sheet).blank? and read_via_numeral_abs(row, 6, sheet).blank?
            category = read_via_numeral_abs(row, 5, sheet) if category.blank?
            prop_cap_improve = PropertyCapitalImprovement.procedure_for_cap_exp(:nameIn=>read_via_numeral_abs(row, 5, sheet),:monthIn=>month,:yearIn=>year,:realIn=>real_estate_property_id,:categoryIn=>category, :statusIn=>'NULL', :annualIn=>'NULL',:suiteIn=>nil, :typeIn=>pcb)
            push_financial_record(prop_cap_improve['pcid'], Array.new(12,0), pcb, "PropertyCapitalImprovement")
          elsif !read_via_numeral_abs(row, 5, sheet).blank? and !read_via_numeral_abs(row, 6, sheet).blank?
            if read_via_numeral_abs(row, 5, sheet).downcase.include? "total "
              category = "";
              prop_cap_improve = PropertyCapitalImprovement.procedure_for_cap_exp(:nameIn=>read_via_numeral_abs(row, 5, sheet),:monthIn=>month,:yearIn=>year,:realIn=>real_estate_property_id,:categoryIn=>read_via_numeral_abs(row, 5, sheet), :statusIn=>'NULL', :annualIn=>read_via_numeral_abs(row, 18, sheet).to_f,:suiteIn=>nil, :typeIn=>pcb)
              push_financial_record(prop_cap_improve['pcid'], [read_via_numeral(row, 6, sheet), read_via_numeral(row, 7, sheet), read_via_numeral(row, 8, sheet), read_via_numeral(row, 9, sheet), read_via_numeral(row, 10, sheet), read_via_numeral(row, 11, sheet), read_via_numeral(row, 12, sheet), read_via_numeral(row, 13, sheet), read_via_numeral(row, 14, sheet), read_via_numeral(row, 15, sheet), read_via_numeral(row, 16, sheet), read_via_numeral(row, 17, sheet)], pcb, "PropertyCapitalImprovement")
              # total value of the items are stored here.
              # Annual budget items are added here.
            else
              # this are the items which have the annual budget and project status
              # values are stored.
              ps = !read_via_numeral_abs(row, 4, sheet).blank? ? PropertySuite.find_or_create_by_real_estate_property_id_and_suite_number(real_estate_property_id, read_via_numeral_abs(row, 4, sheet).to_s.gsub('.0', '')).id : nil
              prop_cap_improve = PropertyCapitalImprovement.procedure_for_cap_exp(:nameIn=>read_via_numeral_abs(row, 5, sheet),:monthIn=>month,:yearIn=>year,:realIn=>real_estate_property_id,:categoryIn=>category, :statusIn=>read_via_numeral_abs(row, 3, sheet), :annualIn=>read_via_numeral_abs(row, 18, sheet).to_f, :suiteIn=>ps, :typeIn=>pcb)
              push_financial_record(prop_cap_improve['pcid'], [read_via_numeral(row, 6, sheet), read_via_numeral(row, 7, sheet), read_via_numeral(row, 8, sheet), read_via_numeral(row, 9, sheet), read_via_numeral(row, 10, sheet), read_via_numeral(row, 11, sheet), read_via_numeral(row, 12, sheet), read_via_numeral(row, 13, sheet), read_via_numeral(row, 14, sheet), read_via_numeral(row, 15, sheet), read_via_numeral(row, 16, sheet), read_via_numeral(row, 17, sheet)], pcb, "PropertyCapitalImprovement")
              # Items with the values will be pushed into the database.
            end
          end
        end unless year.nil? && pcb.nil?
      end
    end
    update_property_financial_periods_via_mysql(@store_details_array*',')
    # Check the capital improvement records are available like actual and budget
    # if pcb type 'c' and 'b' are there, start variance calculations.
    prop_imp = PropertyCapitalImprovement.find(:first, :conditions=>["real_estate_property_id =? and month =? and year=?", real_estate_property_id, month, year])
    if prop_imp.property_financial_periods.count >= 2
      store_variance_details(real_estate_property_id)
    end
     #Code to update the Income And Cash Flow details of the related Portfolios of that Property - start#
    doc = Document.find_by_id(@options[:doc_id])
    @real_estate_property = RealEstateProperty.find_by_id(doc.real_estate_property_id)
        portfolios_collect = @real_estate_property.portfolios
        portfolios_collect.each do |portfolio|
             Portfolio.portfolio_pci(portfolio.id,0, @financial_year)
          end
    #ends here#
  end

  # used to find the title of record from the excel title associated with 'Sub Detail'
  def sub_detail_headers(title, real_id, year)
    IncomeAndCashFlowDetail.find_by_sql("select id from income_and_cash_flow_details where title='#{title}' and resource_id=#{real_id} and year=#{year} and resource_type='RealEstateProperty';").first.id rescue nil
  end

  # find the sub detail child items.
  def sub_detail_parent_definer(par_id, title)
    IncomeAndCashFlowDetail.find_by_sql("select id from income_and_cash_flow_details where parent_id = #{par_id} and title ='#{title}';").first.id rescue nil
  end

  def amp_aged_receivables
    doc = Document.find_by_id(@options[:doc_id])
    real_estate_property_id = doc.real_estate_property_id;
    year = month = nil
    get_all_sheets.each do |sheet|
      # Parsing sheet should contain the name ' aged recv ' or 'Aged Recv'
      if find_sheet_name(sheet).downcase == 'aged recv'
        if read_via_numeral_abs(3, 5, sheet).to_s.include?('/')
          month = read_via_numeral_abs(3, 5, sheet).to_s.split('/').first if read_via_numeral_abs(3, 5, sheet).to_s.split('/').first.length <= 2
          year  = read_via_numeral_abs(3, 5, sheet).to_s.split('/').last if read_via_numeral_abs(3, 5, sheet).to_s.split('/').last.length == 4
        else
          year = read_via_numeral_abs(3, 5, sheet).to_s.split('-')[0] if read_via_numeral_abs(3, 5, sheet).to_s.split('-')[0].length == 4
          month = read_via_numeral_abs(3, 5, sheet).to_s.split('-')[1] if read_via_numeral_abs(3, 5, sheet).to_s.split('-')[1].length < 3
        end
        4.upto find_last_base_cell(sheet) do |row|
          # leave the first two cells if blank.
          # the tenant contains total then it should not be saved.
          next if (!read_via_numeral_abs(row, 1, sheet).blank? and read_via_numeral_abs(row, 1, sheet).include? 'Unit or Lease') or (read_via_numeral_abs(row, 1, sheet).blank? and read_via_numeral_abs(row, 2, sheet).blank?) or (read_via_numeral_abs(row, 1, sheet).blank? and read_via_numeral_abs(row, 2, sheet).include?('Total'))
          unless read_via_numeral_abs(row, 1, sheet).blank? and read_via_numeral_abs(row, 2, sheet).blank?
            # check the suite already added.
            suite = PropertySuite.procedure_call(:suiteIn=>read_via_numeral_abs(row, 1, sheet).to_s.gsub('.0', ''), :realIn=>real_estate_property_id, :areaIn=>'NULL', :spaceTypeIn=>'')
            aged_rec = PropertyAgedReceivable.find_or_initialize_by_property_suite_id_and_tenant_and_month_and_year(suite['psid'], read_via_numeral_abs(row, 2, sheet), month, year)
            aged_rec.prepaid = read_via_numeral_abs(row, 3, sheet) # pre paid col was added newly
            aged_rec.amount = read_via_numeral_abs(row, 4, sheet)
            aged_rec.paid_amount =read_via_numeral_abs(row, 5, sheet)
            aged_rec.over_30days =read_via_numeral_abs(row, 6, sheet)
            aged_rec.over_60days =read_via_numeral_abs(row, 7, sheet)
            aged_rec.over_90days =read_via_numeral_abs(row, 8, sheet)
            aged_rec.over_120days =read_via_numeral_abs(row, 9, sheet)
            aged_rec.explanation = read_via_numeral_abs(row, 10, sheet)
            aged_rec.save
          end
        end unless year.nil? && month.nil? # Do not parse if there is no valid date in the xls file.
      end
    end
  end

end
