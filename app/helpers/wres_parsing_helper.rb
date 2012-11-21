module WresParsingHelper
  def wres_call_parsing_functions_for_excel(tmp_doc,curr_user_id)
    parent_folder = Folder.find_by_id(tmp_doc.folder_id)
    gr_parent_folder = Folder.find_by_id(parent_folder.parent_id) if !parent_folder.nil?
    gr_gr_parent_folder = Folder.find_by_id(gr_parent_folder.parent_id) if !gr_parent_folder.nil?
    sql = ActiveRecord::Base.connection();
    tm_doc = "#{Rails.root.to_s}/public"+ tmp_doc.public_filename
    tm_xml=tm_doc.split('.')
    tm_xml.pop
    tm_xml=(tm_xml*".")+".xml"
    if !gr_gr_parent_folder.nil?
      if gr_gr_parent_folder.name == "Excel Uploads" || gr_gr_parent_folder.name == "Accounts"
        if (tmp_doc.filename.downcase.include?("actual") && !tmp_doc.filename.downcase.include?("financial") && !tmp_doc.filename.downcase.include?("capexp"))
          tmp_doc.update_attribute('parsing_done',nil)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"WRES,actual",curr_user_id)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
          sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
       elsif (tmp_doc.filename.downcase.include?("budget") && !tmp_doc.filename.downcase.include?("financial") && !tmp_doc.filename.downcase.include?("capexp"))
          tmp_doc.update_attribute('parsing_done',nil)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"WRES,budget",curr_user_id)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
          sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
        end
      end
      if gr_gr_parent_folder.name == "Excel Uploads" || gr_gr_parent_folder.name == "Leases"
        if  (tmp_doc.filename.downcase.include?("units") && !tmp_doc.filename.downcase.include?("leasing"))
          tmp_doc.update_attribute('parsing_done',nil)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"WRES,leases",curr_user_id)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
          sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
        end
      end
    end
  end

  def wres_actual_budget_analysis_parsing
    @real_estate_property= RealEstateProperty.find_real_estate_property(@options[:real_estate_id])
    @finanical_year = ''
    @template_year = Date.today
    @without_heading=["other months' rent","rental value - employee housing","month to month rent","security deposit forfeiture","late charges/nsf's","laundry commissions","utility income","insurance referral fees","miscellaneous income","furniture rental","recreation program receipts"]
    @array_record = []
    @month_list_partial =[]
    for mo in 1..12
      @month_list_partial << Date::MONTHNAMES[mo].slice(0,3)
    end
    @month_de = @month_list_partial[1]#.index(@document.folder.name)+1
    #~ oo =  Excel.new @xls_file
    #~ oo.default_sheet = oo.sheets.first
    oo=""
    date = (read_via_alpha(4,'C') != nil && (date_fetch(4,'C') == :date) ? get_as_date(4,'C') : get_as_date(4,'C') != nil && !(["budget","","actual"].include?(get_as_date(4,'C').downcase))) ? get_as_date(4,'C') : get_as_date(3,'C') != nil ? get_as_date(3,'C') : ''
    #~ date = (oo.cell(4,'C') != nil && (oo.celltype(4,'C') == :date) ? oo.cell(4,'C') : oo.cell(4,'C') != nil && !(["budget","","actual"].include?(oo.cell(4,'C').downcase))) ? oo.cell(4,'C') : oo.cell(3,'C') != nil ? oo.cell(3,'C') : ''
    @finanical_year = (date == :date) ? date.year : date.to_date.year if !date.nil?

		#delete un-updated records
		update_income_data=IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(@real_estate_property.id,"RealEstateProperty",@finanical_year).map(&:title)-fetch_base_cell_titles
		update_income_data.reject! {|ichk| ichk =="other income" or ichk == "operating statement summary"}
    update_income_data='("'+update_income_data*'","'+'")'
    ActiveRecord::Base.connection.execute("update income_and_cash_flow_details ic left join property_financial_periods pf on source_id = ic.id and pcb_type = 'c' and source_type='IncomeAndCashFlowDetail' set pf.january=0, pf.february=0, pf.march=0, pf.april=0, pf.may=0, pf.june=0, pf.july=0, pf.august=0, pf.september=0, pf.october=0, pf.november=0, pf.december=0 where ic.title in #{update_income_data} and ic.resource_id = #{@real_estate_property.id} and ic.resource_type = 'RealEstateProperty' and ic.year=#{@finanical_year};")

    @new_income_and_cash_flow_details=[]
		@new_income_and_cash_flow_details_query=[]
    @store_details_array=[]
    for row in 0..find_last_base_cell
      for col in 1..15
        if !read_via_numeral(row,col).nil? and read_via_numeral(row,col).class.to_s=="String" and read_via_numeral(row,col)=="operating income"
          @array_record = []
          wres_create_new_income_and_cash_flow_details("operating statement summary")
          start_row_oss=row;start_col_oss=col
          wres_create_new_income_and_cash_flow_details(read_via_numeral(row,col),@array_record.first)
          wres_parsing_operation_statement_summary(start_row_oss,start_col_oss,oo,'c','b',2)
        end
      end
    end
    find_or_create_new_income_and_cash_flow_details_via_mysql(@new_income_and_cash_flow_details, @new_income_and_cash_flow_details_query*" or ")
    update_property_financial_periods_via_mysql(@store_details_array*',')
    wres_calculate_sum_for_all_the_details_in_cash_flow_and_detail('c')
    wres_net_value_calculation('c')
    wres_store_variance_details(@real_estate_property.id,'actual_budget')
    wres_store_trailing_data_display(@real_estate_property.id,'actual_budget',@financial_year)
  end

  # created entries in the IncomeAndCashFlowDetail table for each title , also checking title already present are not.
  def wres_create_new_income_and_cash_flow_details(title,parent=nil)
    parent = [nil,nil] if parent.nil?
    if parent[1].nil?
      re_p=IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and parent_id IS NULL and resource_id=? and resource_type=? and year=?",title,@real_estate_property.id,@real_estate_property.class.to_s,@finanical_year])
    else
      re_p=IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and parent_id =? and resource_id=? and resource_type=? and year=?",title,parent[1],@real_estate_property.id,@real_estate_property.class.to_s,@finanical_year])
    end
    re_p=IncomeAndCashFlowDetail.create(:title=>title,:parent_id=> parent[1],:resource_id => @real_estate_property.id,:resource_type=>@real_estate_property.class.to_s,:user_id => @options[:user_id],:year =>@finanical_year,:template_date =>@template_year)  if re_p.nil?
    @new_income_and_cash_flow_details << {"source_id"=>"#{re_p.id}", "pcb_type"=>'c', "source_type"=>re_p.class.to_s} << {"source_id"=>"#{re_p.id}", "pcb_type"=>'b', "source_type"=>re_p.class.to_s}
		@new_income_and_cash_flow_details_query << ("("+"source_id=#{re_p.id} and pcb_type='c' and source_type='#{re_p.class.to_s}'"+")") << ("("+"source_id=#{re_p.id} and pcb_type='b' and source_type='#{re_p.class.to_s}'"+")")
    #~ PropertyFinancialPeriod.find_or_create_by_source_id_and_pcb_type_and_source_type(re_p.id, 'c', re_p.class.to_s)
    #~ PropertyFinancialPeriod.find_or_create_by_source_id_and_pcb_type_and_source_type(re_p.id, 'b', re_p.class.to_s)
    @array_record << [title,re_p.id] #if !re.nil?
  end

  def wres_parsing_operation_statement_summary(start_row_oss,start_col_oss,oo,pcb_type,another_pcb_type,column_start)
    row=start_row_oss+1
    while(row <=find_last_base_cell) do
      if !read_via_numeral(row,1).nil?
        last_element1 = nil
        last_element = nil
        if !read_via_numeral(row,1).nil? and !read_via_numeral(row,2).nil? and !read_via_numeral(row,2).blank?
          if read_via_numeral(row,1) != "total variable operating exp"
            if @without_heading.include?(read_via_numeral(row,1)) and @array_record.length < 3
              parent_id = (read_via_numeral(row,1)=="net income") ? @array_record.first : @array_record.last
              wres_create_new_income_and_cash_flow_details("other income",parent_id)
            end
            parent_id = (read_via_numeral(row,1)=="net income") ? @array_record.first : @array_record.last
            if pcb_type == 'c' and (read_via_numeral(row,1) == "total operating income" or read_via_numeral(row,1) == "total operating revenues")
              le = @array_record.last
              @array_record.pop if !le.nil? and !le[0].nil? and le[0] == "other income"
            end
            wres_create_new_income_and_cash_flow_details(read_via_numeral(row,1),parent_id)
            last_element = @array_record.pop
            record = IncomeAndCashFlowDetail.find_by_id(last_element[1])
            if record.title.match(/total/)
              record.destroy
              last_element = @array_record.pop
              record = IncomeAndCashFlowDetail.find_by_id(last_element[1])
            end
            wres_store_details(record,oo,row,pcb_type,another_pcb_type,column_start)
          else # have to be changes.
            last_element = @array_record.pop
            record = IncomeAndCashFlowDetail.find_by_id(last_element[1])
            if record.title.match(/total/)
              record.destroy
              last_element = @array_record.pop
              record = IncomeAndCashFlowDetail.find_by_id(last_element[1])
            end
            wres_store_details(record,oo,row,pcb_type,another_pcb_type,column_start)
          end
        elsif  !read_via_numeral(row,1).nil?  and !read_via_numeral(row,1).match(/created on:/)
          if !read_via_numeral(row,1).nil?
            @array_record.pop if @array_record.length > 2 &&  @array_record.last.first.casecmp("variable operating exp") != 0
            parent_id = (read_via_numeral(row,1)=="net income") ? @array_record.first : @array_record.last
            wres_create_new_income_and_cash_flow_details(read_via_numeral(row,1),parent_id)
            if read_via_numeral(row,1) == "operating expenses"
              wres_create_new_income_and_cash_flow_details('variable operating exp',@array_record.last)
            end
          end
        end
      end
      row=row+1
    end
  end

  def wres_calculate_sum_for_all_the_details_in_cash_flow_and_detail(pcb_type)
    a = ["operating statement summary","net operating income","net income before depreciation"]
    @sum_for_each_item_query_array=[]
    for income_and_cash_flow in IncomeAndCashFlowDetail.all(:conditions=>["title not in (?) and resource_id =?  and resource_type = ?",a,@real_estate_property.id,@real_estate_property.class.to_s])
      #~ if !a.include?(income_and_cash_flow.title)
        wres_sum_for_each_item(income_and_cash_flow,pcb_type)
      #~ end
    end
    update_property_financial_periods_via_mysql(@sum_for_each_item_query_array*',')
  end

  def wres_net_value_calculation(pcb_type)
    in_cash_income = IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and  resource_id=? and resource_type=? and year=?","operating income",@real_estate_property.id,@real_estate_property.class.to_s,@finanical_year])
    re_p_income = PropertyFinancialPeriod.find_by_source_id_and_pcb_type_and_source_type(in_cash_income.id, pcb_type, in_cash_income.class.to_s)
    in_cash_expense = IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and  resource_id=? and resource_type=? and year=?","operating expenses",@real_estate_property.id,@real_estate_property.class.to_s,@finanical_year])
    re_p_expense = PropertyFinancialPeriod.find_by_source_id_and_pcb_type_and_source_type(in_cash_expense.id, pcb_type, in_cash_expense.class.to_s)
    in_cash_npi = IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and  resource_id=? and resource_type=? and year=?","net operating income",@real_estate_property.id,@real_estate_property.class.to_s,@finanical_year])
    re_p_npi = PropertyFinancialPeriod.find_by_source_id_and_pcb_type_and_source_type(in_cash_npi.id, pcb_type, in_cash_npi.class.to_s)
    in_cash_other = IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and  resource_id=? and resource_type=? and year=?","other income and expense",@real_estate_property.id,@real_estate_property.class.to_s,@finanical_year])
    re_p_other = PropertyFinancialPeriod.find_by_source_id_and_pcb_type_and_source_type(in_cash_other.id, pcb_type, in_cash_other.class.to_s)
    in_cash_depre = IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and  resource_id=? and resource_type=? and year=?","net income before depreciation",@real_estate_property.id,@real_estate_property.class.to_s,@finanical_year])
    re_p_depre = PropertyFinancialPeriod.find_by_source_id_and_pcb_type_and_source_type(in_cash_depre.id, pcb_type, in_cash_depre.class.to_s)
    sum_jan=0;sum_feb=0;sum_mar=0;sum_apr=0;sum_may=0;sum_june=0;sum_july=0;sum_aug=0;sum_sep=0;sum_oct=0;sum_nov=0;sum_dec=0
    if !re_p_income.nil?  and !re_p_expense.nil?
      sum_jan = re_p_income.january - re_p_expense.january       if !re_p_income.january.nil? and !re_p_expense.january.nil?
      sum_feb = re_p_income.february - re_p_expense.february    if !re_p_income.february.nil? and !re_p_expense.february.nil?
      sum_mar = re_p_income.march - re_p_expense.march      if !re_p_income.march.nil? and !re_p_expense.march.nil?
      sum_apr = re_p_income.april - re_p_expense.april           if !re_p_income.april.nil? and !re_p_expense.april.nil?
      sum_may = re_p_income.may - re_p_expense.may        if !re_p_income.may.nil? and !re_p_expense.may.nil?
      sum_june = re_p_income.june - re_p_expense.june         if !re_p_income.june.nil? and !re_p_expense.june.nil?
      sum_july = re_p_income.july - re_p_expense.july            if !re_p_income.july.nil? and !re_p_expense.july.nil?
      sum_aug = re_p_income.august - re_p_expense.august       if !re_p_income.august.nil? and !re_p_expense.august.nil?
      sum_sep = re_p_income.september - re_p_expense.september  if !re_p_income.september.nil? and !re_p_expense.september.nil?
      sum_oct = re_p_income.october - re_p_expense.october        if !re_p_income.october.nil? and !re_p_expense.october.nil?
      sum_nov = re_p_income.november - re_p_expense.november   if !re_p_income.november.nil? and !re_p_expense.november.nil?
      sum_dec = re_p_income.december - re_p_expense.december   if !re_p_income.december.nil? and !re_p_expense.december.nil?
    end
    if !re_p_npi.nil?
      re_p_npi.update_attributes(:january =>sum_jan , :february  =>sum_feb, :march =>sum_mar, :april =>sum_apr,:may =>sum_may,:june=>sum_june,:july =>sum_july,:august =>sum_aug,:september=>sum_sep,:october=>sum_oct,:november=>sum_nov,:december=>sum_dec)
    end
    sum_jan=0;sum_feb=0;sum_mar=0;sum_apr=0;sum_may=0;sum_june=0;sum_july=0;sum_aug=0;sum_sep=0;sum_oct=0;sum_nov=0;sum_dec=0
    if !re_p_npi.nil?  and !re_p_other.nil?
      sum_jan = re_p_npi.january - re_p_other.january       if !re_p_npi.january.nil? and !re_p_other.january.nil?
      sum_feb = re_p_npi.february - re_p_other.february    if !re_p_npi.february.nil? and !re_p_other.february.nil?
      sum_mar = re_p_npi.march - re_p_other.march      if !re_p_npi.march.nil? and !re_p_other.march.nil?
      sum_apr = re_p_npi.april - re_p_other.april           if !re_p_npi.april.nil? and !re_p_other.april.nil?
      sum_may = re_p_npi.may - re_p_other.may         if !re_p_npi.may.nil? and !re_p_other.may.nil?
      sum_june = re_p_npi.june - re_p_other.june         if !re_p_npi.june.nil? and !re_p_other.june.nil?
      sum_july = re_p_npi.july - re_p_other.july            if !re_p_npi.july.nil? and !re_p_other.july.nil?
      sum_aug = re_p_npi.august - re_p_other.august       if !re_p_npi.august.nil? and !re_p_other.august.nil?
      sum_sep = re_p_npi.september - re_p_other.september  if !re_p_npi.september.nil? and !re_p_other.september.nil?
      sum_oct = re_p_npi.october - re_p_other.october        if !re_p_npi.october.nil? and !re_p_other.october.nil?
      sum_nov = re_p_npi.november - re_p_other.november   if !re_p_npi.november.nil? and !re_p_other.november.nil?
      sum_dec = re_p_npi.december - re_p_other.december   if !re_p_npi.december.nil? and !re_p_other.december.nil?
    end
    if !re_p_depre.nil?
      re_p_depre.update_attributes(:january =>sum_jan , :february  =>sum_feb, :march =>sum_mar, :april =>sum_apr,:may =>sum_may,:june=>sum_june,:july =>sum_july,:august =>sum_aug,:september=>sum_sep,:october=>sum_oct,:november=>sum_nov,:december=>sum_dec)
    end
  end

  def wres_store_variance_details(id, type)
    type1='RealEstateProperty'
    if type=="actual_budget"
      coll = IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type(id, type1)
    else
      coll = PropertyCapitalImprovement.find_all_by_real_estate_property_id(id)
    end
    common_var_per_array,common_var_per_query,common_var_per_all_data_array,@updated_query=[],[],[],[]
    all_pfp=PropertyFinancialPeriod.all(:conditions=>["source_id in (?) and source_type=?",coll.map(&:id),coll.first.class.to_s])
    coll.each do |itr|
      pfs =  all_pfp.select{|x| x.source_id==itr.id}
      #~ pfs =  itr.property_financial_periods
      b_row = pfs.detect {|i| i.pcb_type == 'b'}
      a_row = pfs.detect {|i| i.pcb_type == 'c'}
      unless b_row.nil? && a_row.nil?
        b_arr = [b_row.january, b_row.february, b_row.march, b_row.april, b_row.may, b_row.june, b_row.july, b_row.august, b_row.september, b_row.october, b_row.november, b_row.december]
        b_arr.each_with_index { |i,j| b_arr[j] = 0 if i.nil? }
        a_arr = [a_row.january, a_row.february, a_row.march, a_row.april, a_row.may, a_row.june, a_row.july, a_row.august, a_row.september, a_row.october, a_row.november, a_row.december]
        a_arr.each_with_index { |i,j| a_arr[j] = 0 if i.nil? }
        b_ytd_arr = Array.new(12,0)
        a_ytd_arr = Array.new(12,0)
        0.upto(11) do |ind|
          0.upto(ind) do |sub|
            b_ytd_arr[ind] += b_arr[sub]
            a_ytd_arr[ind] += a_arr[sub]
          end #unless ind == 0
        end
        var_arr = []
        per_arr = []
        var_ytd_arr = []
        per_ytd_arr = []
        income_or_expense_status = wres_find_income_or_expense(itr) if type=="actual_budget"
        0.upto(11) do |indx|
          if type=="actual_budget"
            var_arr[indx] = income_or_expense_status ? (b_arr[indx].to_f - a_arr[indx].to_f) : (a_arr[indx].to_f -  b_arr[indx].to_f)
            var_ytd_arr[indx] = income_or_expense_status ? (b_ytd_arr[indx].to_f - a_ytd_arr[indx].to_f) : (a_ytd_arr[indx].to_f -  b_ytd_arr[indx].to_f)
          else
            var_arr[indx] =  b_arr[indx].to_f - a_arr[indx].to_f
            var_ytd_arr[indx] =  b_ytd_arr[indx].to_f - a_ytd_arr[indx].to_f
          end
          per_arr[indx] =  (var_arr[indx] * 100) / b_arr[indx].to_f
          per_ytd_arr[indx] =  (var_ytd_arr[indx] * 100) / b_ytd_arr[indx].to_f
          if b_arr[indx].to_f==0
            per_arr[indx] = ( a_arr[indx].to_f == 0 ? 0 : wres_find_income_or_expense(itr) ? -100 : 100 )
          end
          if b_ytd_arr[indx].to_f==0
            per_ytd_arr[indx] = ( a_ytd_arr[indx].to_f == 0 ? 0 : wres_find_income_or_expense(itr) ? -100 : 100 )
          end
          per_arr[indx]= 0.0 if per_arr[indx].to_f.nan?
          per_ytd_arr[indx]= 0.0 if per_ytd_arr[indx].to_f.nan?
        end
        #~ pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_amt')
        #~ pf.january= var_arr[0];pf.february=var_arr[1];pf.march=var_arr[2];pf.april=var_arr[3];pf.may=var_arr[4];pf.june=var_arr[5];pf.july=var_arr[6];pf.august=var_arr[7];pf.september=var_arr[8];pf.october=var_arr[9];pf.november=var_arr[10];pf.december=var_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_amt', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_amt', "source_type"=>itr.class.to_s, "january"=>"#{var_arr[0]}", "february"=>"#{var_arr[1]}", "march"=>"#{var_arr[2]}", "april"=>"#{var_arr[3]}", "may"=>"#{var_arr[4]}", "june"=>"#{var_arr[5]}", "july"=>"#{var_arr[6]}", "august"=>"#{var_arr[7]}", "september"=>"#{var_arr[8]}", "october"=>"#{var_arr[9]}", "november"=>"#{var_arr[10]}", "december"=>"#{var_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='var_amt' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_per')
        #~ pf.january= per_arr[0];pf.february=per_arr[1];pf.march=per_arr[2];pf.april=per_arr[3];pf.may=per_arr[4];pf.june=per_arr[5];pf.july=per_arr[6];pf.august=per_arr[7];pf.september=per_arr[8];pf.october=per_arr[9];pf.november=per_arr[10];pf.december=per_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_per', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_per', "source_type"=>itr.class.to_s, "january"=>"#{per_arr[0]}", "february"=>"#{per_arr[1]}", "march"=>"#{per_arr[2]}", "april"=>"#{per_arr[3]}", "may"=>"#{per_arr[4]}", "june"=>"#{per_arr[5]}", "july"=>"#{per_arr[6]}", "august"=>"#{per_arr[7]}", "september"=>"#{per_arr[8]}", "october"=>"#{per_arr[9]}", "november"=>"#{per_arr[10]}", "december"=>"#{per_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='var_per' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'b_ytd')
        #~ pf.january= b_ytd_arr[0];pf.february=b_ytd_arr[1];pf.march=b_ytd_arr[2];pf.april=b_ytd_arr[3];pf.may=b_ytd_arr[4];pf.june=b_ytd_arr[5];pf.july=b_ytd_arr[6];pf.august=b_ytd_arr[7];pf.september=b_ytd_arr[8];pf.october=b_ytd_arr[9];pf.november=b_ytd_arr[10];pf.december=b_ytd_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'b_ytd', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'b_ytd', "source_type"=>itr.class.to_s, "january"=>"#{b_ytd_arr[0]}", "february"=>"#{b_ytd_arr[1]}", "march"=>"#{b_ytd_arr[2]}", "april"=>"#{b_ytd_arr[3]}", "may"=>"#{b_ytd_arr[4]}", "june"=>"#{b_ytd_arr[5]}", "july"=>"#{b_ytd_arr[6]}", "august"=>"#{b_ytd_arr[7]}", "september"=>"#{b_ytd_arr[8]}", "october"=>"#{b_ytd_arr[9]}", "november"=>"#{b_ytd_arr[10]}", "december"=>"#{b_ytd_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='b_ytd' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'c_ytd')
        #~ pf.january= a_ytd_arr[0];pf.february=a_ytd_arr[1];pf.march=a_ytd_arr[2];pf.april=a_ytd_arr[3];pf.may=a_ytd_arr[4];pf.june=a_ytd_arr[5];pf.july=a_ytd_arr[6];pf.august=a_ytd_arr[7];pf.september=a_ytd_arr[8];pf.october=a_ytd_arr[9];pf.november=a_ytd_arr[10];pf.december=a_ytd_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'c_ytd', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'c_ytd', "source_type"=>itr.class.to_s, "january"=>"#{a_ytd_arr[0]}", "february"=>"#{a_ytd_arr[1]}", "march"=>"#{a_ytd_arr[2]}", "april"=>"#{a_ytd_arr[3]}", "may"=>"#{a_ytd_arr[4]}", "june"=>"#{a_ytd_arr[5]}", "july"=>"#{a_ytd_arr[6]}", "august"=>"#{a_ytd_arr[7]}", "september"=>"#{a_ytd_arr[8]}", "october"=>"#{a_ytd_arr[9]}", "november"=>"#{a_ytd_arr[10]}", "december"=>"#{a_ytd_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='c_ytd' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_amt_ytd')
        #~ pf.january= var_ytd_arr[0];pf.february=var_ytd_arr[1];pf.march=var_ytd_arr[2];pf.april=var_ytd_arr[3];pf.may=var_ytd_arr[4];pf.june=var_ytd_arr[5];pf.july=var_ytd_arr[6];pf.august=var_ytd_arr[7];pf.september=var_ytd_arr[8];pf.october=var_ytd_arr[9];pf.november=var_ytd_arr[10];pf.december=var_ytd_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_amt_ytd', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_amt_ytd', "source_type"=>itr.class.to_s, "january"=>"#{var_ytd_arr[0]}", "february"=>"#{var_ytd_arr[1]}", "march"=>"#{var_ytd_arr[2]}", "april"=>"#{var_ytd_arr[3]}", "may"=>"#{var_ytd_arr[4]}", "june"=>"#{var_ytd_arr[5]}", "july"=>"#{var_ytd_arr[6]}", "august"=>"#{var_ytd_arr[7]}", "september"=>"#{var_ytd_arr[8]}", "october"=>"#{var_ytd_arr[9]}", "november"=>"#{var_ytd_arr[10]}", "december"=>"#{var_ytd_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='var_amt_ytd' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_per_ytd')
        #~ pf.january= per_ytd_arr[0];pf.february=per_ytd_arr[1];pf.march=per_ytd_arr[2];pf.april=per_ytd_arr[3];pf.may=per_ytd_arr[4];pf.june=per_ytd_arr[5];pf.july=per_ytd_arr[6];pf.august=per_ytd_arr[7];pf.september=per_ytd_arr[8];pf.october=per_ytd_arr[9];pf.november=per_ytd_arr[10];pf.december=per_ytd_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_per_ytd', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_per_ytd', "source_type"=>itr.class.to_s, "january"=>"#{per_ytd_arr[0]}", "february"=>"#{per_ytd_arr[1]}", "march"=>"#{per_ytd_arr[2]}", "april"=>"#{per_ytd_arr[3]}", "may"=>"#{per_ytd_arr[4]}", "june"=>"#{per_ytd_arr[5]}", "july"=>"#{per_ytd_arr[6]}", "august"=>"#{per_ytd_arr[7]}", "september"=>"#{per_ytd_arr[8]}", "october"=>"#{per_ytd_arr[9]}", "november"=>"#{per_ytd_arr[10]}", "december"=>"#{per_ytd_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='var_per_ytd' and source_type='#{itr.class.to_s}'"+")")

        #PropertyFinancialPeriod.create(:source_id => itr.id, :source_type=> itr.class.to_s, :pcb_type=>'var_per', :january=> per_arr[0], :february=>per_arr[1], :march=>per_arr[2], :april=>per_arr[3], :may=>per_arr[4], :june=>per_arr[5], :july=>per_arr[6], :august=>per_arr[7], :september=>per_arr[8], :october=>per_arr[9], :november=>per_arr[10], :december=>per_arr[11])
      end
    end
    create_and_update_property_financial_periods_via_mysql(common_var_per_array,common_var_per_query*" or ",common_var_per_all_data_array)
    update_property_financial_periods_via_mysql(@updated_query*",")
  end

  def wres_store_trailing_data_display(id,type,year)
    type1 = 'RealEstateProperty'
     common_var_per_array,common_var_per_query,common_var_per_all_data_array,@updated_query=[],[],[],[],[],[]
			a,b,c,d,e={},{},Hash.new { |h,k| h[k] = {} },{},Hash.new { |h,k| h[k] = {} }
			coll_prev = IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(id,type1,(year.to_i - 1))
			if coll_prev.present?
          all_pfp=PropertyFinancialPeriod.all(:conditions=>["source_id in (?) and source_type=?",coll_prev.map(&:id),coll_prev.first.class.to_s])
          coll_prev.each_with_index do |itr,index|
            pfs =  all_pfp.select{|x| x.source_id==itr.id}
            b_row = pfs.detect {|i| i.pcb_type == 'b_ytd'}
            a_row = pfs.detect {|i| i.pcb_type == 'c_ytd'}
            if !b_row.nil? && !a_row.nil?
              b_arr = [b_row.january, b_row.february, b_row.march, b_row.april, b_row.may, b_row.june, b_row.july, b_row.august, b_row.september, b_row.october, b_row.november, b_row.december]
							a_arr = [a_row.january, a_row.february, a_row.march, a_row.april, a_row.may, a_row.june, a_row.july, a_row.august, a_row.september, a_row.october, a_row.november, a_row.december]
               a["#{index}_actual"] = a_arr
               a["#{index}_budget"] = b_arr
            end
          end

          coll_current = IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(id, type1,year)
          all_pfp_current=PropertyFinancialPeriod.all(:conditions=>["source_id in (?) and source_type=?",coll_current.map(&:id),coll_current.first.class.to_s])
          coll_current.each_with_index do |itr1,indx|
            pfs_val =  all_pfp_current.select{|x| x.source_id==itr1.id}
            b_row_val = pfs_val.detect {|i| i.pcb_type == 'b_ytd'}
            a_row_val = pfs_val.detect {|i| i.pcb_type == 'c_ytd'}
             if !b_row_val.nil? &&  !a_row_val.nil?
                b_arr_cur = [b_row_val.january, b_row_val.february, b_row_val.march, b_row_val.april, b_row_val.may, b_row_val.june, b_row_val.july, b_row_val.august, b_row_val.september, b_row_val.october, b_row_val.november, b_row_val.december]
                a_arr_cur = [a_row_val.january, a_row_val.february, a_row_val.march, a_row_val.april, a_row_val.may, a_row_val.june, a_row_val.july, a_row_val.august, a_row_val.september, a_row_val.october, a_row_val.november, a_row_val.december]
                b["#{indx}_actual"] = a_arr_cur
                b["#{indx}_budget"] = b_arr_cur
                d["#{indx}"] =  itr1.id
              end
            end

						arr = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
						for j in 0..((b.count)/2 -1 )
              for i in 0..11
                c["#{j}"]["#{arr[i]}"] = i.eql?(0) ? b["#{j}_budget"][11].to_f  : (b["#{j}_budget"][11].to_f - b["#{j}_budget"][i].to_f) + a["#{j}_budget"][i].to_f
                e["#{j}"]["#{arr[i]}"] = i.eql?(0) ? b["#{j}_actual"][11].to_f  : (b["#{j}_actual"][11].to_f - b["#{j}_actual"][i].to_f) + a["#{j}_actual"][i].to_f
              end
            end
             d.keys.each do |val|
               c.keys.each do |key_val|
                 if val == key_val
                   x = c[key_val]
                  common_var_per_array<<{"source_id"=>"#{d[val]}", "pcb_type"=>'b_ytd12', "source_type"=>"IncomeAndCashFlowDetail"}
                  common_var_per_all_data_array<<{"source_id"=>"#{d[val]}", "pcb_type"=>'b_ytd12', "source_type"=>"IncomeAndCashFlowDetail", "january"=>"#{x["january"]}", "february"=>"#{x["february"]}", "march"=>"#{x["march"]}", "april"=>"#{x["april"]}", "may"=>"#{x["may"]}", "june"=>"#{x["june"]}", "july"=>"#{x["july"]}", "august"=>"#{x["august"]}", "september"=>"#{x["september"]}", "october"=>"#{x["october"]}", "november"=>"#{x["november"]}", "december"=>"#{x["december"]}"}
                   common_var_per_query << ("("+"source_id=#{d[val]} and pcb_type='b_ytd12' and source_type='IncomeAndCashFlowDetail'"+")")
                   end
                 end
                 e.keys.each do |key_val|
                 if val == key_val
                   y = e[key_val]
                  common_var_per_array<<{"source_id"=>"#{d[val]}", "pcb_type"=>'c_ytd12', "source_type"=>"IncomeAndCashFlowDetail"}
                  common_var_per_all_data_array<<{"source_id"=>"#{d[val]}", "pcb_type"=>'c_ytd12', "source_type"=>"IncomeAndCashFlowDetail", "january"=>"#{y["january"]}", "february"=>"#{y["february"]}", "march"=>"#{y["march"]}", "april"=>"#{y["april"]}", "may"=>"#{y["may"]}", "june"=>"#{y["june"]}", "july"=>"#{y["july"]}", "august"=>"#{y["august"]}", "september"=>"#{y["september"]}", "october"=>"#{y["october"]}", "november"=>"#{y["november"]}", "december"=>"#{y["december"]}"}
                   common_var_per_query << ("("+"source_id=#{d[val]} and pcb_type='c_ytd12' and source_type='IncomeAndCashFlowDetail'"+")")
                   end
                 end
               end

          else
          coll_current = IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(id, type,year)
          all_pfp_current=PropertyFinancialPeriod.all(:conditions=>["source_id in (?) and source_type=?",coll_current.map(&:id),coll_current.first.class.to_s])
          coll_current.each_with_index do |itr1,indx|
            pfs_val =  all_pfp_current.select{|x| x.source_id==itr1.id}
            b_row_val = pfs_val.detect {|i| i.pcb_type == 'b_ytd'}
            a_row_val = pfs_val.detect {|i| i.pcb_type == 'c_ytd'}
             if !b_row_val.nil? &&  !a_row_val.nil?
                b_arr_cur = [b_row_val.january, b_row_val.february, b_row_val.march, b_row_val.april, b_row_val.may, b_row_val.june, b_row_val.july, b_row_val.august, b_row_val.september, b_row_val.october, b_row_val.november, b_row_val.december]
                a_arr_cur = [a_row_val.january, a_row_val.february, a_row_val.march, a_row_val.april, a_row_val.may, a_row_val.june, a_row_val.july, a_row_val.august, a_row_val.september, a_row_val.october, a_row_val.november, a_row_val.december]
                b["#{indx}_actual"] = a_arr_cur
                b["#{indx}_budget"] = b_arr_cur
                d["#{indx}"] =  itr1.id
              end
            end

						arr = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
						for j in 0..((b.count)/2 -1 )
              for i in 0..11
                c["#{j}"]["#{arr[i]}"] = b["#{j}_budget"][i].to_f
                e["#{j}"]["#{arr[i]}"] = b["#{j}_actual"][i].to_f
              end
            end
             d.keys.each do |val|
               c.keys.each do |key_val|
                 if val == key_val
                   x = c[key_val]
                  common_var_per_array<<{"source_id"=>"#{d[val]}", "pcb_type"=>'b_ytd12', "source_type"=>"IncomeAndCashFlowDetail"}
                  common_var_per_all_data_array<<{"source_id"=>"#{d[val]}", "pcb_type"=>'b_ytd12', "source_type"=>"IncomeAndCashFlowDetail", "january"=>"#{x["january"]}", "february"=>"#{x["february"]}", "march"=>"#{x["march"]}", "april"=>"#{x["april"]}", "may"=>"#{x["may"]}", "june"=>"#{x["june"]}", "july"=>"#{x["july"]}", "august"=>"#{x["august"]}", "september"=>"#{x["september"]}", "october"=>"#{x["october"]}", "november"=>"#{x["november"]}", "december"=>"#{x["december"]}"}
                   common_var_per_query << ("("+"source_id=#{d[val]} and pcb_type='b_ytd12' and source_type='IncomeAndCashFlowDetail'"+")")
                   end
                 end
                 e.keys.each do |key_val|
                 if val == key_val
                   y = e[key_val]
                  common_var_per_array<<{"source_id"=>"#{d[val]}", "pcb_type"=>'c_ytd12', "source_type"=>"IncomeAndCashFlowDetail"}
                  common_var_per_all_data_array<<{"source_id"=>"#{d[val]}", "pcb_type"=>'c_ytd12', "source_type"=>"IncomeAndCashFlowDetail", "january"=>"#{y["january"]}", "february"=>"#{y["february"]}", "march"=>"#{y["march"]}", "april"=>"#{y["april"]}", "may"=>"#{y["may"]}", "june"=>"#{y["june"]}", "july"=>"#{y["july"]}", "august"=>"#{y["august"]}", "september"=>"#{y["september"]}", "october"=>"#{y["october"]}", "november"=>"#{y["november"]}", "december"=>"#{y["december"]}"}
                   common_var_per_query << ("("+"source_id=#{d[val]} and pcb_type='c_ytd12' and source_type='IncomeAndCashFlowDetail'"+")")
                   end
                 end
               end
               end
      create_and_update_property_financial_periods_via_mysql(common_var_per_array,common_var_per_query*" or ",common_var_per_all_data_array)
      update_property_financial_periods_via_mysql(@updated_query*",")
  end


  def wres_store_details(record,oo,row,pcb_type,another_pcb_type,column_start)
    if !@month_de.nil?
      prop_financial= PropertyFinancialPeriod.find_or_create_by_source_id_and_pcb_type_and_source_type(record.id, pcb_type, record.class.to_s)
      h = Hash.new
      col=column_start
      range = (pcb_type == 'c' and @finanical_year >= Date.today.year) ? (Date.today.day > 25 ? Date.today.month : Date.today.month - 1) : 12
      # this is to restrict the parsing for future month actual values
      for m in 1..range
        if !read_via_numeral(row,col).nil? and read_via_numeral(row,col).to_i != 0
          h["#{Date::MONTHNAMES[m].downcase}"] = wres_store_value_for_income_and_cash_flow(read_via_numeral(row,col))
        elsif prop_financial["#{Date::MONTHNAMES[m].downcase}"].nil?
          h["#{Date::MONTHNAMES[m].downcase}"] = 0
        else
          h["#{Date::MONTHNAMES[m].downcase}"] = 0
        end
        col=col+1
      end
      if  pcb_type == 'b'
        h["dollar_per_sqft"] = wres_store_value_for_income_and_cash_flow(read_via_numeral(row,col))
        h["dollar_per_unit"] = wres_store_value_for_income_and_cash_flow(read_via_numeral(row,col+1))
      end
      prop_financial.update_attributes(h)
      prop_financial1 = PropertyFinancialPeriod.find_or_create_by_source_id_and_pcb_type_and_source_type(record.id, another_pcb_type, record.class.to_s)
      h = Hash.new
      col=3
      for m in 1..12
        h["#{Date::MONTHNAMES[m].downcase}"] = if (prop_financial1["#{Date::MONTHNAMES[m].downcase}"].nil?)
          0
        else
          prop_financial1["#{Date::MONTHNAMES[m].downcase}"]
        end
        col=col+1
      end
      @store_details_array << "(#{prop_financial1.id},"+[h["january"],h["february"],h["march"],h["april"],h["may"],h["june"],h["july"],h["august"],h["september"],h["october"],h["november"],h["december"]].map(&:to_f)*","+")" if !h.empty?
      #~ prop_financial1.update_attributes(h)  if !h.empty?
    end
  end

  def wres_sum_for_each_item(income_and_cash_flow,pcb_type)
    children = IncomeAndCashFlowDetail.find_all_by_parent_id(income_and_cash_flow.id)
    sum_jan=0;sum_feb=0;sum_mar=0;sum_apr=0;sum_may=0;sum_june=0;sum_july=0;sum_aug=0;sum_sep=0;sum_oct=0;sum_nov=0;sum_dec=0
    for child_par in children
      wres_sum_for_each_item(child_par,pcb_type)
      child = PropertyFinancialPeriod.find_by_source_id_and_pcb_type_and_source_type(child_par.id, pcb_type, child_par.class.to_s)
      sum_jan = sum_jan +child.january       if !child.nil? and !child.january.nil?
      sum_feb = sum_feb +child.february     if !child.nil? and !child.february.nil?
      sum_mar = sum_mar +child.march      if !child.nil? and !child.march.nil?
      sum_apr = sum_apr +child.april           if !child.nil? and !child.april.nil?
      sum_may = sum_may +child.may        if !child.nil? and !child.may.nil?
      sum_june = sum_june +child.june         if !child.nil? and !child.june.nil?
      sum_july = sum_july +child.july             if !child.nil? and !child.july.nil?
      sum_aug = sum_aug +child.august       if !child.nil? and !child.august.nil?
      sum_sep = sum_sep +child.september  if !child.nil? and !child.september.nil?
      sum_oct = sum_oct +child.october        if !child.nil? and !child.october.nil?
      sum_nov = sum_nov +child.november   if !child.nil? and !child.november.nil?
      sum_dec = sum_dec +child.december   if !child.nil? and !child.december.nil?
    end
    if !children.empty?
      income_period = PropertyFinancialPeriod.find_by_source_id_and_pcb_type_and_source_type(income_and_cash_flow.id, pcb_type, income_and_cash_flow.class.to_s)
      @sum_for_each_item_query_array << "("+"#{income_period.id},#{sum_jan},#{sum_feb},#{sum_mar},#{sum_apr},#{sum_may},#{sum_june},#{sum_july},#{sum_aug},#{sum_sep},#{sum_oct},#{sum_nov},#{sum_dec}"+")" if !income_period.nil?
      if income_and_cash_flow.title == "other income"
         income_period.update_attributes(:january =>sum_jan , :february  =>sum_feb, :march =>sum_mar, :april =>sum_apr,:may =>sum_may,:june=>sum_june,:july =>sum_july,:august =>sum_aug,:september=>sum_sep,:october=>sum_oct,:november=>sum_nov,:december=>sum_dec)  if !income_period.nil?
      end
    end
  end

  def wres_store_value_for_income_and_cash_flow(value)
    begin
      if value.scan(".").length==1 || (!@parse_date.nil? && !@parse_date)
        return value
      else
        return value.to_date
      end
    rescue
    if value.class.to_s =="String"
      value = value.gsub(",","")
      if value.count("-") > 0 or value.count("(") > 0 or value.count(")") > 0
        value = value.gsub("(","").gsub(")","").gsub("-","")
        return "-#{value}"
      else
        return value
      end
    else
      return value
    end
    end
  end

  def wres_12_month_parsing
    @real_estate_property =   RealEstateProperty.find_real_estate_property(@options[:real_estate_id])
    @user = @real_estate_property.user
    @finanical_year = ''
    @template_year = Date.today
    @without_heading=["other months' rent","rental value - employee housing","month to month rent","security deposit forfeiture","late charges/nsf's","laundry commissions","utility income","insurance referral fees","miscellaneous income","furniture rental","recreation program receipts"]
    @array_record = []
    @month_list_partial =[]
    for mo in 1..12
      @month_list_partial << Date::MONTHNAMES[mo].slice(0,3)
    end
    @month_de = @month_list_partial[1]#.index(@document.folder.name)+1
    #    oo =  Excel.new "#{Rails.root.to_s}/public#{doc.public_filename}"
    #    oo.default_sheet = oo.sheets.first
    oo = ""
    date = (read_via_alpha(4,'C') != nil && (date_fetch(4,'C') == :date) ? get_as_date(4,'C') : get_as_date(4,'C') != nil && !(["budget","","actual"].include?(get_as_date(4,'C').downcase))) ? get_as_date(4,'C') : get_as_date(3,'C') != nil ? get_as_date(3,'C') : ''
    #date = (oo.cell(4,'C') != nil && (oo.celltype(4,'C') == :date) ? oo.cell(4,'C') : oo.cell(4,'C') != nil && !(["budget","","actual"].include?(oo.cell(4,'C').downcase))) ? oo.cell(4,'C') : oo.cell(3,'C') != nil ? oo.cell(3,'C') : ''
    @finanical_year = (date == :date) ? date.year : date.to_date.year if !date.nil?

		#delete un-updated records
		update_income_data=IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(@real_estate_property.id,"RealEstateProperty",@finanical_year).map(&:title)-fetch_base_cell_titles
		update_income_data.delete("operating statement summary")
    update_income_data='("'+update_income_data*'","'+'")'
    ActiveRecord::Base.connection.execute("update income_and_cash_flow_details ic left join property_financial_periods pf on source_id = ic.id and pcb_type = 'b' and source_type='IncomeAndCashFlowDetail' set pf.january=0, pf.february=0, pf.march=0, pf.april=0, pf.may=0, pf.june=0, pf.july=0, pf.august=0, pf.september=0, pf.october=0, pf.november=0, pf.december=0 where ic.title in #{update_income_data} and ic.resource_id = #{@real_estate_property.id} and ic.resource_type = 'RealEstateProperty' and ic.year=#{@finanical_year};")

    @new_income_and_cash_flow_details=[]
		@new_income_and_cash_flow_details_query=[]
    @store_details_array=[]
    for row in 0..find_last_base_cell
      for col in 1..15
        if !read_via_numeral(row,col).nil? and read_via_numeral(row,col).class.to_s=="String" and read_via_numeral(row,col)=="operating income"
          #if !oo.cell(row,col).nil? and oo.cell(row,col).class.to_s=="String" and convert_title_val(oo.cell(row,col))=="operating income"
          @array_record = []
          wres_create_new_income_and_cash_flow_details("operating statement summary")
          start_row_oss=row;start_col_oss=col
          wres_create_new_income_and_cash_flow_details(read_via_numeral(row,col),@array_record.first)
          wres_parsing_operation_statement_summary(start_row_oss,start_col_oss,oo,'b','c',3)
        end
      end
    end
    find_or_create_new_income_and_cash_flow_details_via_mysql(@new_income_and_cash_flow_details, @new_income_and_cash_flow_details_query*" or ")
    update_property_financial_periods_via_mysql(@store_details_array*',')
    wres_calculate_sum_for_all_the_details_in_cash_flow_and_detail('b')
    wres_net_value_calculation('b')
    wres_store_variance_details(@real_estate_property.id,'actual_budget')
    wres_store_trailing_data_display(@real_estate_property.id,'actual_budget',@financial_year)
    #Code to update the Income And Cash Flow details of the related Portfolios of that Property - start#
        portfolios_collect = @real_estate_property.portfolios
        portfolios_collect.each do |portfolio|
            Portfolio.portfolio_ic(portfolio.id, @finanical_year)
          end
    #ends here#
  end

  def wres_all_units_parsing
    @real_estate_property = RealEstateProperty.find_real_estate_property(@options[:real_estate_id])
    @titles = []
    #~ oo =   Excel.new "#{Rails.root.to_s}/public#{doc.public_filename}"
    #~ oo.default_sheet = oo.sheets.first
    oo=""
    v = read_via_alpha(3,'B')
    v1 = v.to_s.split(" ")[0].split("-")
    v1 = v1[0].split('/').reverse if v1.any? {|dt| dt.to_s.include?('/')} and v1.count == 1
    @property_occupancy_summary = PropertyOccupancySummary.find_or_create_by_real_estate_property_id_and_year_and_month(@real_estate_property.id,v1[0],v1[1])
    t =0
    for row in 6..find_last_base_cell
      for col in 1..find_last_column
        if !read_via_numeral(row,col).nil? and read_via_numeral(row,col).class.to_s=="String" and read_via_numeral(row,col)=="bldg/unit"    and t == 0
          start_row=row;start_col_oss=col
          wres_start_lease_parsing(start_row,oo)
          t =1
        end
        break if t==1
      end
      break if t==1
    end
  end

  def convert_title_val(val)
    val = val.delete 194.chr+160.chr
    val = val.downcase.strip
  end

  def convert_title_val_debt(val)
    val = val.delete 194.chr+160.chr
    val = val.strip
  end

  def wres_start_lease_parsing(start_row,oo)
    wres_store_titles(start_row,oo)
    row = start_row +1
    #~ query_array=[]
    while (read_via_numeral(row,1).nil? or (!read_via_numeral(row,1).nil?  and read_via_numeral(row,1) != "physical occupancy")) do
      if !read_via_numeral(row,1).nil? and !read_via_numeral(row,1).blank? and !read_via_numeral(row,1).match(/total for/) and !["bldg/unit","parameters:","parameters"].include?(read_via_numeral(row,1))
        suite_number = wres_find_value_for_each_column("bldg/unit",oo,row)
        floorplan = wres_find_value_for_each_column('floorplan',oo,row)
        sqft = wres_find_value_for_each_column('sqft',oo,row)
        property_suite = PropertySuite.find_or_create_by_suite_number_and_floor_plan_and_rented_area_and_real_estate_property_id(suite_number.to_s.gsub('.0', ''),floorplan,sqft,@real_estate_property.id)
	property_suite.update_attribute('client_id',@real_estate_property.client_id)
        h = {}
        h['base_rent'] = wres_find_value_for_each_column('market rent',oo,row)
        h['amt_per_sqft'] = wres_find_value_for_each_column('amt/sqft',oo,row)
        h['effective_rate'] = wres_find_value_for_each_column('lease rent',oo,row)
        h['actual_amt_per_sqft'] = wres_find_value_for_each_column('actual amt/sqft',oo,row)
        h['tenant'] = wres_find_value_for_each_column('name',oo,row)
        h['move_in'] = wres_find_value_for_each_column('-movein',oo,row)
        h['start_date'] = wres_find_value_for_each_column('lease start',oo,row)
        h['end_date'] = wres_find_value_for_each_column('lease end',oo,row)
        h['other_deposits'] = wres_find_value_for_each_column('deposits on hand',oo,row)
        h['made_ready'] = (wres_find_value_for_each_column('made ready',oo,row) == 'N') ? 0 : 1
        h['property_suite_id'] = property_suite.id  if !property_suite.nil?
        h['month'] = @property_occupancy_summary.month
        h['year'] = @property_occupancy_summary.year
        #~ query_array <<"("+"#{h['base_rent']},#{h['amt_per_sqft'] },#{h['effective_rate'].blank? ? 0 : h['effective_rate'] },#{h['actual_amt_per_sqft'].blank? ? 0 : h['actual_amt_per_sqft'] },'#{h['tenant]}',#{h['move_in']},#{h['start_date']},#{h['end_date']},#{h['other_deposits'].blank? ? 0 : h['other_deposits']},#{h['made_ready']},#{h['property_suite_id']},#{h['month']},#{h['year']}"+")"
        #PropertyLease.create(h)
        PropertyLease.procedure_call_amp_all_units(:propSuiteId=>h['property_suite_id'].blank? ? nil : h['property_suite_id'], :nameIn=>h['tenant'].blank? ? nil : h['tenant'], :startDate=>h['start_date'].blank? ? nil : h['start_date'], :endDate=>h['end_date'].blank? ? nil : h['end_date'],:baseRent=>h['base_rent'].blank? ? nil : h['base_rent'] , :effRate=>h['effective_rate'].blank? ? nil : h['effective_rate'], :tenantImp=>nil,  :leasingComm=>nil, :monthIn=>h['month'].blank? ? nil : h['month'], :yearIn=>h['year'].blank? ? nil : h['year'], :otherDepIn=> h['other_deposits'].blank? ? nil : h['other_deposits'], :commentsIn=>nil,  :amtPerSQFT=>h['amt_per_sqft'].blank? ? nil : h['amt_per_sqft'], :occType=>nil, :moveIn=> (h['move_in'].blank? or h['move_in'].class == String) ? nil : h['move_in'].strftime("%Y-%m-%d %H:%M:%S"), :madeReadyIn=> h['made_ready'].blank? ? nil : h['made_ready'], :actAmtPerSQFT=>h['actual_amt_per_sqft'].blank? ? nil : h['actual_amt_per_sqft'])
      end
      row=row+1
    end
    #~ create_property_leases_records_via_mysql((query_array*','))
    @titles = []
    wres_physical_occupancy_details(oo,row)
    row = row + 1
    h ={}
    while(read_via_numeral(row,1).nil? or (!read_via_numeral(row,1).nil?  and read_via_numeral(row,1) != "exposure to vacancy") ) do
      if !read_via_numeral(row,1).nil?
        if !read_via_numeral(row,1).nil? and read_via_numeral(row,1) == 'sqft'
          h['current_year_sf_occupied_actual'] = wres_find_value_for_each_column('occupied',oo,row)
          h['current_year_sf_vacant_actual'] = wres_find_value_for_each_column('vacant',oo,row)
          h['total_building_rentable_s'] = wres_find_value_for_each_column('total',oo,row)
        elsif !read_via_numeral(row,1).nil? and read_via_numeral(row,1) == 'unit count'
          h['current_year_units_occupied_actual'] = wres_find_value_for_each_column('occupied',oo,row)
          h['current_year_units_vacant_actual'] = wres_find_value_for_each_column('vacant',oo,row)
          h['current_year_units_total_actual'] = wres_find_value_for_each_column('total',oo,row)
        end
      end
      row=row+1
    end
    @property_occupancy_summary.update_attributes(h) if !h.empty?
    @titles = []
    wres_exposure_to_vacancy_details(oo,row)
    row = row +1
    h={}
    while(read_via_numeral(row,1).nil? or (!read_via_numeral(row,1).nil?  and read_via_numeral(row,1) != "rental rates") ) do
      if !read_via_numeral(row,1).nil?
        if !read_via_numeral(row,1).nil? and read_via_numeral(row,1) == 'currently vacant units'
          h['currently_vacant_leases_number'] = wres_find_value_for_each_column('number',oo,row).to_f
          h['currently_vacant_leases_percentage'] = ( h['currently_vacant_leases_number'] *100/ @property_occupancy_summary.current_year_units_total_actual ).abs.round(2)
        elsif !read_via_numeral(row,1).nil? and read_via_numeral(row,1) == 'less vacant leased'
          h['vacant_leased_number'] = wres_find_value_for_each_column('number',oo,row).to_f
          h['vacant_leased_percentage'] =( h['vacant_leased_number'] *100/ @property_occupancy_summary.current_year_units_total_actual ).abs.round(2)
        elsif !read_via_numeral(row,1).nil? and read_via_numeral(row,1) == 'plus occupied on notice'
          h['occupied_on_notice_number'] = wres_find_value_for_each_column('number',oo,row).to_f
          h['occupied_on_notice_percentage'] = ( h['occupied_on_notice_number'] *100/ @property_occupancy_summary.current_year_units_total_actual ).abs.round(2)
        elsif !read_via_numeral(row,1).nil? and read_via_numeral(row,1) == 'less occupied pre-leased'
          h['occupied_preleased_number'] = wres_find_value_for_each_column('number',oo,row).to_f
          h['occupied_preleased_percentage'] = ( h['occupied_preleased_number'] *100/ @property_occupancy_summary.current_year_units_total_actual ).abs.round(2)
        elsif !read_via_numeral(row,1).nil? and read_via_numeral(row,1) == 'net exposure to vacancy'
          h['net_exposure_to_vacancy_number'] = wres_find_value_for_each_column('number',oo,row).to_f
          h['net_exposure_to_vacancy_percentage'] =( h['net_exposure_to_vacancy_number'] *100/ @property_occupancy_summary.current_year_units_total_actual ).abs.round(2)
        end
      end
      row=row+1
    end
    @property_occupancy_summary.update_attributes(h) if !h.empty?
  end

  def create_property_leases_records_via_mysql(query)
		sql = ActiveRecord::Base.connection();
		sql.execute("insert into property_leases(base_rent,amt_per_sqft,effective_rate,actual_amt_per_sqft,tenant,move_in,start_date,end_date,other_deposits,made_ready,property_suite_id,month,year) values #{query}") unless query.blank?
	end

  def wres_store_titles(start_row,oo)
    for col in 1..86
      if !read_via_numeral(start_row,col).nil? and !read_via_numeral(start_row,col).blank?
        @titles << [read_via_numeral(start_row,col).gsub("\n","").downcase.strip , col]
      end
    end
  end

  def wres_find_value_for_each_column(heading,oo,row)
    for title in @titles
      att = title if title[0].downcase.strip == heading
    end
    value=''
    if !att.nil?
      value = read_via_numeral(row,att[1]) if !read_via_numeral(row,att[1]).nil? and !read_via_numeral(row,att[1]).blank?
      value = read_via_numeral(row,att[1]-1) if !read_via_numeral(row,att[1]-1).nil? and !read_via_numeral(row,att[1]-1).blank?
      value = read_via_numeral(row,att[1]+1) if !read_via_numeral(row,att[1]+1).nil? and !read_via_numeral(row,att[1]+1).blank?
    end
    return value
  end

  def wres_physical_occupancy_details(oo,row)
    arr =["physical occupancy","occupied","vacant","total"]
    for col in 1..86
      if !read_via_numeral(row,col).nil? and !read_via_numeral(row,col).blank?
        if arr.include?(read_via_numeral(row,col).downcase.strip)
          @titles << [read_via_numeral(row,col).downcase.strip, col]
        end
      end
    end
  end

  def wres_exposure_to_vacancy_details(oo,row)
    arr =["number","%"]
    for col in 1..86
      if !read_via_numeral(row,col).nil? and !read_via_numeral(row,col).blank?
        if arr.include?(read_via_numeral(row,col).downcase.strip)
          @titles << [read_via_numeral(row,col).downcase.strip, col] if @titles.length < 2
        end
      end
    end
  end

end
