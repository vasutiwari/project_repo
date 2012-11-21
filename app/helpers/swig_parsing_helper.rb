module SwigParsingHelper

  def call_parsing_functions_for_excel(tmp_doc,current_user_id)
    # begin
    parent_folder = Folder.find_by_id(tmp_doc.folder_id)
    gr_parent_folder = Folder.find_by_id(parent_folder.parent_id) if !parent_folder.nil?
    gr_gr_parent_folder = Folder.find_by_id(gr_parent_folder.parent_id) if !gr_parent_folder.nil?
    sql = ActiveRecord::Base.connection();
    tm_doc = "#{Rails.root.to_s}/public"+ tmp_doc.public_filename
    tm_xml=tm_doc.split('.')
    tm_xml.pop
    tm_xml=(tm_xml*".")+".xml"
    acc_sys_type=AccountingSystemType.find_by_id(parent_folder.real_estate_property.accounting_system_type_id) if parent_folder.present?

    if !gr_gr_parent_folder.nil?
      if gr_gr_parent_folder.name == "Excel Uploads" || gr_gr_parent_folder.name == "Accounts"
        if (tmp_doc.filename.downcase.include?("month") && tmp_doc.filename.downcase.include?("budget") && !tmp_doc.filename.downcase.include?("financial") && !tmp_doc.filename.downcase.include?("capexp"))
          tmp_doc.update_attribute('parsing_done',nil)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"SWIG,budget",current_user_id)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
          sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
        elsif  tmp_doc.filename.downcase.include?("capital")
          tmp_doc.update_attribute('parsing_done',nil)
          #          initiate_amp_parser(tmp_doc)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"SWIG,capital",current_user_id)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
          sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
        elsif  tmp_doc.filename.downcase.include?("aged")
          tmp_doc.update_attribute('parsing_done',nil)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"SWIG,aged",current_user_id)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
          sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
        end
      end
      if gr_gr_parent_folder.name == "Excel Uploads" || gr_gr_parent_folder.name == "Leases"
        if  (tmp_doc.filename.downcase.include?("occupancy") && !tmp_doc.filename.downcase.include?("tenant"))
          tmp_doc.update_attribute('parsing_done',nil)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"SWIG,leases",current_user_id)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name)
          sql.execute("UPDATE real_estate_properties SET last_updated = NOW( ) WHERE id = ( SELECT real_estate_property_id FROM folders WHERE id = #{parent_folder.id} )")
        elsif tmp_doc.filename.downcase.include?("rent") && acc_sys_type && (acc_sys_type.type_name == "MRI" || (acc_sys_type.type_name == "MRI, SWIG" && tmp_doc.filename.downcase.include?("rent")))
          tmp_doc.update_attribute('parsing_done',nil)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"MRI,rent roll",current_user_id)
        elsif tmp_doc.filename.downcase.include?("rent")
          tmp_doc.update_attribute('parsing_done',nil)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name)
              Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"SWIG,rent",current_user_id)
        end
      end
      if gr_gr_parent_folder.name == "Excel Uploads" || gr_gr_parent_folder.name == "Loan Docs"
        if tmp_doc.filename.downcase.include?("debt_summary")
          tmp_doc.update_attribute('parsing_done',nil)
          ParsingLog.create(:client_id=>tmp_doc.user.client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"SWIG,debt",current_user_id)
        end
      end
    end
  end

  def store_variance_details(id, type = [])
    unless type.empty?
      coll = IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type(id, type)
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
      #unless b_row.blank? && a_row.blank?
      if !b_row.nil? && !a_row.nil?
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
          end #unless ind == 0 Commented becoz its not showing the jan ytd.
        end
        var_arr = []
        per_arr = []
        var_ytd_arr = []
        per_ytd_arr = []
        income_or_expense_status = find_income_or_expense(itr) unless type.empty?
        0.upto(11) do |indx|
          unless type.empty?
            var_arr[indx] = income_or_expense_status ? (b_arr[indx].to_f - a_arr[indx].to_f) : (a_arr[indx].to_f -  b_arr[indx].to_f)
            var_ytd_arr[indx] = income_or_expense_status ? (b_ytd_arr[indx].to_f - a_ytd_arr[indx].to_f) : (a_ytd_arr[indx].to_f -  b_ytd_arr[indx].to_f)
          else
            var_arr[indx] =  b_arr[indx].to_f - a_arr[indx].to_f
            var_ytd_arr[indx] =  b_ytd_arr[indx].to_f - a_ytd_arr[indx].to_f
          end
          per_arr[indx] =  (var_arr[indx] * 100) / b_arr[indx].to_f
          per_ytd_arr[indx] =  (var_ytd_arr[indx] * 100) / b_ytd_arr[indx].to_f
          if  b_arr[indx].to_f==0
            per_arr[indx] = ( a_arr[indx].to_f == 0 ? 0 : -100 )
          end
          if  b_ytd_arr[indx].to_f==0
            per_ytd_arr[indx] = ( a_ytd_arr[indx].to_f == 0 ? 0 : -100 )
          end
          per_arr[indx]= 0.0 if per_arr[indx].to_f.nan?
          per_ytd_arr[indx]= 0.0 if per_ytd_arr[indx].to_f.nan?
        end
        #~ pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_amt')
        #~ pf.january= var_arr[0];pf.february=var_arr[1];pf.march=var_arr[2];pf.april=var_arr[3];pf.may=var_arr[4];pf.june=var_arr[5];pf.july=var_arr[6];pf.august=var_arr[7];pf.september=var_arr[8];pf.october=var_arr[9];pf.november=var_arr[10];pf.december=var_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_amt', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_amt', "source_type"=>itr.class.to_s, "january"=>"#{var_arr[0]}", "february"=>"#{var_arr[1]}", "march"=>"#{var_arr[2]}", "april"=>"#{var_arr[3]}", "may"=>"#{var_arr[4]}", "june"=>"#{var_arr[5]}", "july"=>"#{var_arr[6]}", "august"=>"#{var_arr[7]}", "september"=>"#{var_arr[8]}", "october"=>"#{var_arr[9]}", "november"=>"#{var_arr[10]}", "december"=>"#{var_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='var_amt' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_per')
        #~ pf.january= per_arr[0];pf.february=per_arr[1];pf.march=per_arr[2];pf.april=per_arr[3];pf.may=per_arr[4];pf.june=per_arr[5];pf.july=per_arr[6];pf.august=per_arr[7];pf.september=per_arr[8];pf.october=per_arr[9];pf.november=per_arr[10];pf.december=per_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_per', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_per', "source_type"=>itr.class.to_s, "january"=>"#{per_arr[0]}", "february"=>"#{per_arr[1]}", "march"=>"#{per_arr[2]}", "april"=>"#{per_arr[3]}", "may"=>"#{per_arr[4]}", "june"=>"#{per_arr[5]}", "july"=>"#{per_arr[6]}", "august"=>"#{per_arr[7]}", "september"=>"#{per_arr[8]}", "october"=>"#{per_arr[9]}", "november"=>"#{per_arr[10]}", "december"=>"#{per_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='var_per' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'b_ytd')
        #~ pf.january= b_ytd_arr[0];pf.february=b_ytd_arr[1];pf.march=b_ytd_arr[2];pf.april=b_ytd_arr[3];pf.may=b_ytd_arr[4];pf.june=b_ytd_arr[5];pf.july=b_ytd_arr[6];pf.august=b_ytd_arr[7];pf.september=b_ytd_arr[8];pf.october=b_ytd_arr[9];pf.november=b_ytd_arr[10];pf.december=b_ytd_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'b_ytd', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'b_ytd', "source_type"=>itr.class.to_s, "january"=>"#{b_ytd_arr[0]}", "february"=>"#{b_ytd_arr[1]}", "march"=>"#{b_ytd_arr[2]}", "april"=>"#{b_ytd_arr[3]}", "may"=>"#{b_ytd_arr[4]}", "june"=>"#{b_ytd_arr[5]}", "july"=>"#{b_ytd_arr[6]}", "august"=>"#{b_ytd_arr[7]}", "september"=>"#{b_ytd_arr[8]}", "october"=>"#{b_ytd_arr[9]}", "november"=>"#{b_ytd_arr[10]}", "december"=>"#{b_ytd_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='b_ytd' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'c_ytd')
        #~ pf.january= a_ytd_arr[0];pf.february=a_ytd_arr[1];pf.march=a_ytd_arr[2];pf.april=a_ytd_arr[3];pf.may=a_ytd_arr[4];pf.june=a_ytd_arr[5];pf.july=a_ytd_arr[6];pf.august=a_ytd_arr[7];pf.september=a_ytd_arr[8];pf.october=a_ytd_arr[9];pf.november=a_ytd_arr[10];pf.december=a_ytd_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'c_ytd', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'c_ytd', "source_type"=>itr.class.to_s, "january"=>"#{a_ytd_arr[0]}", "february"=>"#{a_ytd_arr[1]}", "march"=>"#{a_ytd_arr[2]}", "april"=>"#{a_ytd_arr[3]}", "may"=>"#{a_ytd_arr[4]}", "june"=>"#{a_ytd_arr[5]}", "july"=>"#{a_ytd_arr[6]}", "august"=>"#{a_ytd_arr[7]}", "september"=>"#{a_ytd_arr[8]}", "october"=>"#{a_ytd_arr[9]}", "november"=>"#{a_ytd_arr[10]}", "december"=>"#{a_ytd_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='c_ytd' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_amt_ytd')
        #~ pf.january= var_ytd_arr[0];pf.february=var_ytd_arr[1];pf.march=var_ytd_arr[2];pf.april=var_ytd_arr[3];pf.may=var_ytd_arr[4];pf.june=var_ytd_arr[5];pf.july=var_ytd_arr[6];pf.august=var_ytd_arr[7];pf.september=var_ytd_arr[8];pf.october=var_ytd_arr[9];pf.november=var_ytd_arr[10];pf.december=var_ytd_arr[11];pf.save
        common_var_per_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_amt_ytd', "source_type"=>itr.class.to_s}
        common_var_per_all_data_array<<{"source_id"=>"#{itr.id}", "pcb_type"=>'var_amt_ytd', "source_type"=>itr.class.to_s, "january"=>"#{var_ytd_arr[0]}", "february"=>"#{var_ytd_arr[1]}", "march"=>"#{var_ytd_arr[2]}", "april"=>"#{var_ytd_arr[3]}", "may"=>"#{var_ytd_arr[4]}", "june"=>"#{var_ytd_arr[5]}", "july"=>"#{var_ytd_arr[6]}", "august"=>"#{var_ytd_arr[7]}", "september"=>"#{var_ytd_arr[8]}", "october"=>"#{var_ytd_arr[9]}", "november"=>"#{var_ytd_arr[10]}", "december"=>"#{var_ytd_arr[11]}"}
        common_var_per_query << ("("+"source_id=#{itr.id} and pcb_type='var_amt_ytd' and source_type='#{itr.class.to_s}'"+")")

        #~ pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_per_ytd')
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


  def store_trailing_months_details(id,type,year)
    common_var_per_array,common_var_per_query,common_var_per_all_data_array,@updated_query=[],[],[],[],[],[]
			a,b,c,d,e={},{},Hash.new { |h,k| h[k] = {} },{},Hash.new { |h,k| h[k] = {} }
			coll_prev = IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(id,type,(year.to_i - 1))
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
                c["#{j}"]["#{arr[i]}"] = i.eql?(0) ? a["#{j}_budget"][11].to_f  : (a["#{j}_budget"][11].to_f - a["#{j}_budget"][i].to_f) + b["#{j}_budget"][i].to_f
                e["#{j}"]["#{arr[i]}"] = i.eql?(0) ? a["#{j}_actual"][11].to_f  : (a["#{j}_actual"][11].to_f - a["#{j}_actual"][i].to_f) + b["#{j}_actual"][i].to_f
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

  def create_and_update_property_financial_periods_via_mysql(data_hash,query,overall_data_hash,is_year=false)
    sql = ActiveRecord::Base.connection();
    unless query.blank?
      record=sql.execute("select source_id,pcb_type,source_type from property_financial_periods where #{query};")
      existing_hash=Document.record_to_hash(record)
      create_hash=data_hash-existing_hash
      create_query= create_hash.map(&:values).map{|x| "("+"'#{x[0]}',#{x[1]},'#{x[2]}'"+")"}*","
      sql.execute("INSERT INTO property_financial_periods (source_type,source_id,pcb_type) VALUES #{create_query};") unless create_query.blank?
      record=sql.execute("select id,source_id,pcb_type,source_type from property_financial_periods where #{query};")
      new_existing_hash=Document.record_to_hash(record)
      @updated_query.clear
      overall_data_hash.each do |x|
        new_existing_hash.each do |y|
          if x["source_id"]== y["source_id"] &&  x["pcb_type"]== y["pcb_type"] && x["source_type"]== y["source_type"]
            if is_year.eql?(true)
              @updated_query << "("+"#{y['id']},#{x['january']},#{x['february']},#{x['march']},#{x['april']},#{x['may']},#{x['june']},#{x['july']},#{x['august']},#{x['september']},#{x['october']},#{x['november']},#{x['december']},#{x['year']}"+")"
            else
              @updated_query << "("+"#{y['id']},#{x['january']},#{x['february']},#{x['march']},#{x['april']},#{x['may']},#{x['june']},#{x['july']},#{x['august']},#{x['september']},#{x['october']},#{x['november']},#{x['december']}"+")"
            end
          end
        end
      end
    end
  end

  def update_property_financial_periods_via_mysql(query,is_year=false)
    sql = ActiveRecord::Base.connection();
    if is_year.eql?(true)
      fields="(id,january,february,march,april,may,june,july,august,september,october,november,december,year)"
      updatable_fields="january=VALUES(january),february=VALUES(february),march=VALUES(march),april=VALUES(april),may=VALUES(may),june=VALUES(june),july=VALUES(july),august=VALUES(august),september=VALUES(september),october=VALUES(october),november=VALUES(november),december=VALUES(december),year=VALUES(year)"
    else
      fields="(id,january,february,march,april,may,june,july,august,september,october,november,december)"
      updatable_fields="january=VALUES(january),february=VALUES(february),march=VALUES(march),april=VALUES(april),may=VALUES(may),june=VALUES(june),july=VALUES(july),august=VALUES(august),september=VALUES(september),october=VALUES(october),november=VALUES(november),december=VALUES(december)"
    end
    sql.execute("INSERT into property_financial_periods #{fields} VALUES #{query} ON DUPLICATE KEY UPDATE #{updatable_fields};") unless query.blank?
  end

  #added to parse occupancy and leasing excel file
  def store_new_occupancy_leasing
    @curr_user =User.find_by_id(@options[:current_user]).id
    @prop_id = RealEstateProperty.find_real_estate_property(@options[:real_estate_id]).id
    import_occupancy_and_leasing_details("")
  end

  #added to parse occupancy and leasing excel file
  def import_occupancy_and_leasing_details(oo)
    if !read_via_numeral(1,1).nil? && date_fetch(1,"A") == :date
      month,year=read_via_numeral(1,1).to_date.month,read_via_numeral(1,1).to_date.year
      row,head_row,column=9,7,1
      title_and_column={}
      title=["unit","sf","tenant","spacetype","termstart","termend","base","effective","ti's","lc's","options/comments"]
      title.push "securitydeposit" if @cur_parse_type == 'AMP'
      while column <=16
        if  !read_via_numeral(head_row,column).nil? && !read_via_numeral(head_row,column).downcase.match(/(months)/)
          if read_via_numeral(head_row,column).downcase.gsub(' ','')=="dateexecuted" or read_via_numeral(head_row,column).downcase.gsub(' ','')=="leasedate"
            title_and_column.store("dateexecuted",column)
          elsif read_via_numeral(head_row,column).downcase.gsub(' ','').include? 'base' or read_via_numeral(head_row,column).downcase.gsub(' ','').include? "effective"
            title_and_column.store(read_via_numeral(head_row,column).downcase.gsub(' ','').include?("base") ? 'base' : 'effective',column)
          elsif title.include?(read_via_numeral(head_row,column).downcase.gsub(' ',''))
            title_and_column.store(read_via_numeral(head_row,column).downcase.gsub(' ','').gsub("'s","s").gsub('/',''),column)
          end
        end
        column=column+1
      end
      suites = Suite.find_all_by_real_estate_property_id(@prop_id).map(&:id)
      PropertyLease.delete_all(['month = ? and year = ? and property_suite_id IN (?) and occupancy_type != ? ', month, year, suites,'current'] ) if !suites.nil? and !suites.empty?
      PropertyOccupancySummary.delete_all(['real_estate_property_id = ? and month = ? and year = ?',@prop_id, month, year])
      while(row <=find_last_base_cell) do
          if !read_via_numeral(row,1).nil? and read_via_numeral(row,1).class == String and !(["total expiry","total new","total renewal","total future commencements","occupancy statistics","tenant occupancy"].include?(read_via_numeral(row,1).downcase.strip))
            occupancy_type,row=read_via_numeral(row,1).downcase.strip,row+1
            while(row <=find_last_base_cell) do
                if !read_via_numeral(row,3).nil?
                  #Leading zero truncation added .gsub!(/^0+/,'')
                  prop_suite = Suite.find(:all, :conditions=>['real_estate_property_id = ? and suite_no = ?  and space_type = ?  and rentable_sqft =?', @prop_id,read_via_numeral(row,title_and_column["unit"]).to_s.gsub('.0', ''),read_via_numeral(row,title_and_column["spacetype"]).downcase,read_via_numeral(row,title_and_column["sf"])])
                  prop_suite=prop_suite[0] unless prop_suite.blank?
                  # modified based on the Lease Mgmt DB structure
                  if !(read_via_numeral(row,title_and_column["termstart"]).nil? && read_via_numeral(row,title_and_column["termend"]).nil? ) && occupancy_type != "expirations" #&& (read_via_numeral(row,title_and_column["termstart"]) <= Date.today && read_via_numeral(row,title_and_column["termend"]) >= Date.today ) #added to check whether the suite is vacant
                    #Leading zero truncation added .gsub!(/^0+/,'')

                    mtm = read_via_numeral(row,title_and_column["termend"]) < Date.today ? 1 : 0

                    #Conditions for multiple suites present#
                    prop_suite_arr = []
                    suite_number =  read_via_numeral(row,title_and_column["unit"]).to_s.gsub('.0', '')
                    if suite_number.include?(',') || suite_number.include?('/')
                      suite_array = suite_number.split(',')  if suite_number.include?(',')
                      suite_array = suite_number.split('/')  if suite_number.include?('/')
                      suite_array.each do |val|
                        find_suite = Suite.find_by_suite_no_and_real_estate_property_id(val,@prop_id)
                        if !find_suite.present?
                          rentable_sqft = read_via_numeral(row,title_and_column["sf"]).to_f / suite_array.size  #Total Sqft divided equally based on array size. Each suite will have same sqft#
                          prop_suite=Suite.new
                          prop_suite.real_estate_property_id=@prop_id
                          prop_suite.suite_no=val
                          prop_suite.rentable_sqft=rentable_sqft
                          prop_suite.space_type=read_via_numeral(row,title_and_column["spacetype"]).downcase
                          prop_suite.user_id=@curr_user
                          prop_suite.status='Occupied'
                          prop_suite.save
                          prop_suite_arr << prop_suite
                        else
                          prop_suite=Suite.find_or_create_by_suite_no_and_real_estate_property_id(:real_estate_property_id=>@prop_id,:suite_no=>val,:rentable_sqft=>read_via_numeral(row,title_and_column["sf"]),:space_type=>read_via_numeral(row,title_and_column["spacetype"]).downcase,:user_id=>@curr_user,:status=>'Occupied') if prop_suite.blank?
                          prop_suite_arr << prop_suite
                        end
                      end
                    else
                      prop_suite=Suite.find_or_create_by_suite_no_and_real_estate_property_id(:real_estate_property_id=>@prop_id,:suite_no=>read_via_numeral(row,title_and_column["unit"]).to_s.gsub('.0', ''),:rentable_sqft=>read_via_numeral(row,title_and_column["sf"]),:space_type=>read_via_numeral(row,title_and_column["spacetype"]).downcase,:user_id=>@curr_user,:status=>'Occupied') if prop_suite.blank?
                      prop_suite_arr << prop_suite
                    end

                    prop_suite_arr.present? && prop_suite_arr.each do |prop_suite|
                      tenant = Tenant.create(:tenant_legal_name=>read_via_numeral(row,title_and_column["tenant"]))
                      lease = Lease.create(:commencement=> read_via_numeral(row,title_and_column["termstart"]), :expiration=>read_via_numeral(row,title_and_column["termend"]),:execution=>read_via_numeral(row,title_and_column["dateexecuted"]),:occupancy_type=>occupancy_type,:status =>'Active',:real_estate_property_id=>@prop_id,:is_executed=>1,:user_id=>@curr_user,:effective_rate=>read_via_numeral(row,title_and_column["effective"]),:mtm=>mtm)
                      PropertyLeaseSuite.find_or_create_by_lease_id_and_tenant_id(:suite_ids=>[prop_suite.id],:lease_id=>lease.id,:tenant_id=>tenant.id)
                      explanation =LeasesExplanation.create(:lease_id=>lease.id,:real_estate_property_id=>@prop_id,:explanation=>read_via_numeral(row,title_and_column["optionscomments"]),:occupancy_type=>occupancy_type,:user_id=>@curr_user,:month=>Date.today.month,:year=>Date.today.year)
                      rent  = Rent.create(:lease_id=>lease.id)
                      RentSchedule.find_or_create_by_suite_id(:suite_id=>prop_suite.id, :amount_per_month=>read_via_numeral(row,title_and_column["base"]),:rent_id=>rent.id)
                      capex = CapEx.find_or_create_by_lease_id(:lease_id=>lease.id,:security_deposit_amount=>title_and_column["securitydeposit"].nil? ? nil : read_via_numeral(row,title_and_column["securitydeposit"]))
                      TenantImprovement.find_or_create_by_cap_ex_id(:cap_ex_id=>capex.id,:total_amount=>read_via_numeral(row,title_and_column["tis"]))
                      LeasingCommission.find_or_create_by_cap_ex_id(:cap_ex_id=>capex.id,:total_amount=>read_via_numeral(row,title_and_column["lcs"]))
                    end
                  else
                    # for  vacant suites, expired leases

                    #Conditions for multiple suites present#
                    prop_suite_arr = []
                    suite_number =  read_via_numeral(row,title_and_column["unit"]).to_s.gsub('.0', '')
                    if suite_number.include?(',') || suite_number.include?('/')
                      suite_array = suite_number.split(',')  if suite_number.include?(',')
                      suite_array = suite_number.split('/')  if suite_number.include?('/')
                      suite_array.each do |val|
                        find_suite = Suite.find_by_suite_no_and_real_estate_property_id(val,@prop_id)
                        if !find_suite.present?
                          rentable_sqft = read_via_numeral(row,title_and_column["sf"]).to_f / suite_array.size  #Total Sqft divided equally based on array size. Each suite will have same sqft#
                          prop_suite=Suite.new
                          prop_suite.real_estate_property_id=@prop_id
                          prop_suite.suite_no=val
                          prop_suite.rentable_sqft=rentable_sqft
                          prop_suite.space_type=read_via_numeral(row,title_and_column["spacetype"]).downcase
                          prop_suite.user_id=@curr_user
                          prop_suite.status='Vacant'
                          prop_suite.save
                          prop_suite_arr << prop_suite
                        else
                          prop_suite=Suite.find_or_create_by_suite_no_and_real_estate_property_id(:real_estate_property_id=>@prop_id,:suite_no=>val,:rentable_sqft=>read_via_numeral(row,title_and_column["sf"]),:space_type=>read_via_numeral(row,title_and_column["spacetype"]).downcase,:user_id=>@curr_user,:status=>'Occupied') if prop_suite.blank?
                          prop_suite_arr << prop_suite
                        end
                      end
                    else
                      prop_suite=Suite.find_or_create_by_suite_no_and_real_estate_property_id(:real_estate_property_id=>@prop_id,:suite_no=>read_via_numeral(row,title_and_column["unit"]).to_s.gsub('.0', ''),:rentable_sqft=>read_via_numeral(row,title_and_column["sf"]),:space_type=>read_via_numeral(row,title_and_column["spacetype"]).downcase,:user_id=>@curr_user,:status=>'Occupied') if prop_suite.blank?
                      prop_suite_arr << prop_suite
                    end
                    prop_suite_arr.present? && prop_suite_arr.each do |prop_suite|
                      tenant = Tenant.create(:tenant_legal_name=>read_via_numeral(row,title_and_column["tenant"]))
                      lease = Lease.create(:commencement=> read_via_numeral(row,title_and_column["termstart"]), :expiration=>read_via_numeral(row,title_and_column["termend"]),:execution=>read_via_numeral(row,title_and_column["dateexecuted"]),:occupancy_type=>occupancy_type,:status =>'Inactive',:real_estate_property_id=>@prop_id,:is_executed=>1,:user_id=>@curr_user,:effective_rate=>read_via_numeral(row,title_and_column["effective"]))
                      PropertyLeaseSuite.find_or_create_by_lease_id_and_tenant_id(:suite_ids=>[prop_suite.id],:lease_id=>lease.id,:tenant_id=>tenant.id)
                      explanation =LeasesExplanation.create(:lease_id=>lease.id,:real_estate_property_id=>@prop_id,:explanation=>read_via_numeral(row,title_and_column["optionscomments"]),:occupancy_type=>occupancy_type,:user_id=>@curr_user,:month=>Date.today.month,:year=>Date.today.year)
                      rent  = Rent.create(:lease_id=>lease.id)
                      RentSchedule.find_or_create_by_suite_id(:suite_id=>prop_suite.id, :amount_per_month=>read_via_numeral(row,title_and_column["base"]),:rent_id=>rent.id)
                      capex = CapEx.find_or_create_by_lease_id(:lease_id=>lease.id,:security_deposit_amount=>title_and_column["securitydeposit"].nil? ? nil : read_via_numeral(row,title_and_column["securitydeposit"]))
                      TenantImprovement.find_or_create_by_cap_ex_id(:cap_ex_id=>capex.id,:total_amount=>read_via_numeral(row,title_and_column["tis"]))
                      LeasingCommission.find_or_create_by_cap_ex_id(:cap_ex_id=>capex.id,:total_amount=>read_via_numeral(row,title_and_column["lcs"]))
                    end
                  end
                end
                break if read_via_numeral(row,1).class == String && read_via_numeral(row,2).nil?
                row=row+1
              end
            elsif !read_via_numeral(row,1).nil? && read_via_numeral(row,1).class == String && (read_via_numeral(row,1).downcase.strip=="occupancy statistics" || read_via_numeral(row,1).downcase.strip.include?("tenant occupancy") )
              for new_row in row..find_last_base_cell
                for col in 1..2
                  if !read_via_numeral(new_row,col).nil? && read_via_numeral(new_row,col).class == String
                    if read_via_numeral(new_row, col).downcase.match(/building rentable square feet/)
                      up_col = find_column_for_sum_value(new_row,col+1,oo)
                      prop_occup_summary=CommercialLeaseOccupancy.find_or_create_by_real_estate_property_id(:real_estate_property_id=>@prop_id)
                      prop_occup_summary.update_attributes(:month=>month,:year=>year,:total_building_rentable_s=>read_via_numeral(new_row,up_col))
                    elsif read_via_numeral(new_row, col).downcase.match(/sf occupied as of/)
                      if read_via_numeral(new_row+1, col).nil?
                        up_col = find_column_for_sum_value(new_row,col+1,oo)
                        prop_occup_summary.update_attributes(:last_year_sf_occupied_actual=>read_via_numeral(new_row,up_col),:last_year_sf_occupied_budget=>read_via_numeral(new_row,up_col+1))
                      elsif  read_via_numeral(new_row+1, col).downcase.match(/occupancy/)
                        up_col = find_column_for_sum_value(new_row,col+1,oo)
                        prop_occup_summary.update_attributes(:current_year_sf_occupied_actual=>read_via_numeral(new_row,up_col),:current_year_sf_occupied_budget=>read_via_numeral(new_row,up_col+1))
                      end
                    elsif  read_via_numeral(new_row, col).downcase.match(/sf occupied/)
                      if read_via_numeral(new_row+1, col).downcase.match(/occupancy/)
                        up_col = find_column_for_sum_value(new_row,col+1,oo)
                        prop_occup_summary.update_attributes(:current_year_sf_occupied_actual=>read_via_numeral(new_row,up_col),:current_year_sf_occupied_budget=>read_via_numeral(new_row,up_col+1))
                      end
                    elsif read_via_numeral(new_row, col).downcase.match(/sf vacant/)
                      up_col = find_column_for_sum_value(new_row,col+1,oo)
                      prop_occup_summary.update_attributes(:current_year_sf_vacant_actual=>read_via_numeral(new_row,up_col),:current_year_sf_vacant_budget=>read_via_numeral(new_row,up_col+1))
                    elsif read_via_numeral(new_row,col).downcase.match(/new leases/)
                      up_col = find_column_for_sum_value(new_row,col+1,oo)
                      prop_occup_summary.update_attributes(:new_leases_actual=>read_via_numeral(new_row,up_col),:new_leases_budget=>read_via_numeral(new_row,up_col+1))
                    elsif read_via_numeral(new_row,col).downcase.match(/renewals/)
                      up_col = find_column_for_sum_value(new_row,col+1,oo)
                      prop_occup_summary.update_attributes(:renewals_actual=>read_via_numeral(new_row,up_col),:renewals_budget=>read_via_numeral(new_row,up_col+1))
                    elsif read_via_numeral(new_row,col).downcase.match(/expirations/)
                      up_col = find_column_for_sum_value(new_row,col+1,oo)
                      prop_occup_summary.update_attributes(:expirations_actual=>read_via_numeral(new_row,up_col),:expirations_budget=>read_via_numeral(new_row,up_col+1))
                    end
                  end
                end
                row=new_row
              end
            end
            row=row+1
          end
          #~ update_expiration_new_renewal(month,year)
        end
      end


      def find_column_for_sum_value(new_row,col,oo)
        while(read_via_numeral(new_row,col).nil?)
          col =col +1
        end
        return col
      end

      #added to parse occupancy and leasing excel file
      def update_expiration_new_renewal(month,year)
        total_new=Suite.find_by_sql("SELECT sum(suites.rentable_sqft) as total_new FROM suites,leases WHERE leases.occupancy_type='new' and leases.real_estate_property_id= #{@prop_id} and suites.real_estate_property_id=#{@prop_id};")

        total_expiration=Suite.find_by_sql("SELECT sum(suites.rentable_sqft) as total_expiration FROM suites,leases WHERE leases.occupancy_type='expirations' and leases.real_estate_property_id= #{@prop_id} and suites.real_estate_property_id=#{@prop_id};")

        total_renewal=Suite.find_by_sql("SELECT sum(suites.rentable_sqft) as total_renewal FROM suites,leases WHERE leases.occupancy_type='renewal' and leases.real_estate_property_id= #{@prop_id} and suites.real_estate_property_id=#{@prop_id};")
        prop_occup_summary=CommercialLeaseOccupancy.find_by_real_estate_property_id_and_month_and_year(@prop_id,month,year)
        prop_occup_summary.update_attributes(:new_leases_actual=>total_new[0].total_new,:renewals_actual=>total_renewal[0].total_renewal,:expirations_actual=>total_expiration[0].total_expiration) if prop_occup_summary
      end

      #added to parse debt summary excel file
      def store_new_debt_summary
        #~ @document = tmp_doc
        #~ @prop_id = @document.real_estate_property_id
        @prop_id = RealEstateProperty.find_by_id(@options[:real_estate_id]).id
        #~ file_path = "#{Rails.root.to_s}/public#{@document.public_filename}"
        #~ oo =  Excel.new(file_path)
        #~ oo.default_sheet = oo.sheets.first
        oo=""
        import_debt_summary(oo) if oo
      end

      #added to parse debt summary excel file
      def import_debt_summary(oo)
        date = read_via_numeral(7,1).split(" ") if !read_via_numeral(7,1).nil? && read_via_numeral(7,1).class == String
        month,year = Date::MONTHNAMES.index(date[0].capitalize), date[1].to_i unless date.blank?
        if month.nil? and year.nil?
          time=Time.now
          month,year=time.month,time.year
        end
        PropertyDebtSummary.delete_all(['real_estate_property_id = ? and month = ? and year = ? ', @prop_id, month, year])
        start_parse = false
        1.upto(find_last_base_cell) do | row |
          if !start_parse and !read_via_numeral_abs(row, 1, 1).blank? and read_via_numeral_abs(row, 1, 1).downcase == 'category' then start_parse = true ; next end
          next if read_via_numeral_abs(row, 1, 1).blank?  or !start_parse
          if !read_via_numeral_abs(row, 1, 1).blank? and !read_via_numeral_abs(row, 2, 1).blank? and read_via_numeral_abs(row, 1, 1).downcase.delete(":") != 'borrower'
            PropertyDebtSummary.create(:real_estate_property_id=>@prop_id, :category=>read_via_numeral_abs(row, 1, 1).delete(":"), :description=>read_via_numeral_abs(row, 2, 1), :month=>month, :year=>year)
          end
        end
      end

      def store_new_income_and_cash_flow_version
        @document  = Document.find_by_id(@options[:doc_id])
        @real_estate_property = RealEstateProperty.find_by_id(@document.real_estate_property_id)
        @user = @document.user
        file_path = "#{Rails.root.to_s}/public#{@document.public_filename}"
        oo = ""# Excel.new(file_path)
        #oo.default_sheet = oo.sheets.first
        if !find_last_base_cell.nil?
          @template_year = get_as_date(10,'B')
          @finanical_year = @template_year.to_date.year

          #delete un-updated records
          update_income_data=IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(@real_estate_property.id,"RealEstateProperty",@finanical_year).map(&:title)-fetch_base_cell_titles
          update_income_data='("'+update_income_data*'","'+'")'
          ActiveRecord::Base.connection.execute("update income_and_cash_flow_details ic left join property_financial_periods pf on source_id = ic.id and pcb_type in ('b','c') and source_type='IncomeAndCashFlowDetail' set pf.january=0, pf.february=0, pf.march=0, pf.april=0, pf.may=0, pf.june=0, pf.july=0, pf.august=0, pf.september=0, pf.october=0, pf.november=0, pf.december=0 where ic.title in #{update_income_data} and ic.resource_id = #{@real_estate_property.id} and ic.resource_type = 'RealEstateProperty' and ic.year=#{@finanical_year};")

          import_income_and_cash_flow_details(oo)
        end
        store_variance_details(@real_estate_property.id, "RealEstateProperty")
        store_trailing_months_details(@real_estate_property.id, "RealEstateProperty",@template_year.to_date.year)
        #Code to update the Income And Cash Flow details of the related Portfolios of that Property - start#
        portfolios_collect = @real_estate_property.portfolios
        portfolios_collect.each do |portfolio|
            Portfolio.portfolio_ic(portfolio.id, @template_year.to_date.year)
          end
        #ends here#
      end

      # started parsing the whole excel template for 12-month budget
      def import_income_and_cash_flow_details(oo)
        @array_record = []
        @month_list_partial =[]
        for mo in 1..12
          @month_list_partial << Date::MONTHNAMES[mo].slice(0,3)
        end
        if @month_list_partial.include?(@document.folder.name)
          @month_de = @month_list_partial.index(@document.folder.name)+1
        end
        #   IncomeAndCashFlowDetail.delete_all(["year = ? and resource_id =?  and resource_type=?",@finanical_year, @real_estate_property.id, @real_estate_property.class.to_s])
        @new_income_and_cash_flow_details=[]
        @new_income_and_cash_flow_details_query=[]
        @store_details_array=[]
        for row in 9..find_last_base_cell
          for col in 0..15
            if !read_via_numeral(row,col).nil? and read_via_numeral(row,col).class.to_s=="String" and read_via_numeral(row,col) =="cash flow statement summary"
              start_row_oss=row;start_col_oss=col
              create_new_income_and_cash_flow_details(read_via_numeral(row,col))
              parsing_cash_flow_statement_summary(start_row_oss,start_col_oss,oo)
            end
            if !read_via_numeral(row,col).nil? and read_via_numeral(row,col).class.to_s=="String" and read_via_numeral(row,col) =="income detail"
              @array_record = []
              create_new_income_and_cash_flow_details("operating statement summary")
              start_row_oss=row;start_col_oss=col
              create_new_income_and_cash_flow_details(read_via_numeral(row,col),@array_record.first)
              parsing_operation_statement_summary(start_row_oss,start_col_oss,oo)
            end
          end
        end
        update_property_financial_periods_via_mysql(@store_details_array*',')
        find_or_create_new_income_and_cash_flow_details_via_mysql(@new_income_and_cash_flow_details, @new_income_and_cash_flow_details_query*" or ")
        calculate_sum_for_all_the_details_in_cash_flow_and_detail
      end

      # method added to replace find_or_create in create_new_income_and_cash_flow_details
      def find_or_create_new_income_and_cash_flow_details_via_mysql(data_hash, query)
        sql = ActiveRecord::Base.connection();
        unless query.blank?
          record=sql.execute("select source_id,pcb_type,source_type from property_financial_periods where #{query};")
          existing_hash=Document.record_to_hash(record)
          create_hash=data_hash-existing_hash
          create_query= create_hash.map(&:values).map{|x| "("+"'#{x[0]}',#{x[1]},'#{x[2]}'"+")"}*","
          sql.execute("INSERT INTO property_financial_periods (source_type,source_id,pcb_type) VALUES #{create_query};") unless create_query.blank?
        end
      end

      # created entries in the IncomeAndCashFlowDetail table for each title , also checking title already present are not.
      def create_new_income_and_cash_flow_details(title,parent=nil)
        return if title.include? "+"
        parent = [nil,nil] if parent.nil?
        if parent[1].nil?
          re_p=IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and parent_id IS NULL and resource_id=? and resource_type=? and year=?",title,@real_estate_property.id,@real_estate_property.class.to_s,@finanical_year])
        else
          re_p=IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and parent_id =? and resource_id=? and resource_type=? and year=?",title,parent[1],@real_estate_property.id,@real_estate_property.class.to_s,@finanical_year])
        end
        re_p=IncomeAndCashFlowDetail.create(:title=>title,:parent_id=> parent[1],:resource_id => @real_estate_property.id,:resource_type=>@real_estate_property.class.to_s,:user_id => @user.id,:year =>@finanical_year,:template_date =>@template_year)  if re_p.nil?
        @new_income_and_cash_flow_details << {"source_id"=>"#{re_p.id}", "pcb_type"=>'p', "source_type"=>re_p.class.to_s} << {"source_id"=>"#{re_p.id}", "pcb_type"=>'c', "source_type"=>re_p.class.to_s} << {"source_id"=>"#{re_p.id}", "pcb_type"=>'b', "source_type"=>re_p.class.to_s}
        @new_income_and_cash_flow_details_query << ("("+"source_id=#{re_p.id} and pcb_type='p' and source_type='#{re_p.class.to_s}'"+")") << ("("+"source_id=#{re_p.id} and pcb_type='c' and source_type='#{re_p.class.to_s}'"+")") << ("("+"source_id=#{re_p.id} and pcb_type='b' and source_type='#{re_p.class.to_s}'"+")")
        #~ PropertyFinancialPeriod.find_or_create_by_source_id_and_pcb_type_and_source_type(re_p.id, 'p', re_p.class.to_s)
        #~ PropertyFinancialPeriod.find_or_create_by_source_id_and_pcb_type_and_source_type(re_p.id, 'c', re_p.class.to_s)
        #~ PropertyFinancialPeriod.find_or_create_by_source_id_and_pcb_type_and_source_type(re_p.id, 'b', re_p.class.to_s)
        #~ re_c=IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and parent_id =? and pcb_type=?",title,parent[2],'c'])
        #~ re_c=IncomeAndCashFlowDetail.create(:title=>title,:parent_id=> parent[2] ,:pcb_type=>'c',:resource_id => @real_estate_property.id,:resource_type=>@real_estate_property.class.to_s,:user_id => current_user.id,:year =>@finanical_year,:template_date =>@template_year)  if re_c.nil?
        #~ re_b=IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and parent_id =? and pcb_type=?",title,parent[3],'b'])
        #~ re_b=IncomeAndCashFlowDetail.create(:title=>title,:parent_id=> parent[3] ,:pcb_type=>'b',:resource_id => @real_estate_property.id,:resource_type=>@real_estate_property.class.to_s,:user_id => current_user.id,:year =>@finanical_year,:template_date =>@template_year) if re_b.nil?
        @array_record << [title,re_p.id] #if !re.nil?
      end

      # It is used to parse the cash flow statement summary details
      # it starts the 'cash flow statement summary' title & end when reach 'income detail'
      def parsing_cash_flow_statement_summary(start_row_oss,start_col_oss,oo)
        row=start_row_oss+1
        while(!(!read_via_numeral(row,2).nil? and read_via_numeral(row,2).class.to_s=="String" and read_via_numeral(row,2)=="income detail")  ) do
            if !read_via_numeral(row,1).nil? or  !read_via_numeral(row,2).nil? or !read_via_numeral(row,3).nil?
              last_element1 = nil
              last_element = nil
              if !read_via_numeral(row,1).nil?
                if read_via_numeral(row,1).class.to_s == "String" and (read_via_numeral(row,1)=='p' or read_via_numeral(row,1)=='c'  or read_via_numeral(row,1)=='b')
                  position = position_for_pcb_swig(read_via_numeral(row,1))
                  last_element = @array_record.pop
                  record = IncomeAndCashFlowDetail.find_by_id(last_element[1])
                  if (record.title.match(/total/) or record.title.match(/net cash/)) and record.title!="net cash flow"
                    record.destroy if position==3
                    last_element1 = @array_record.pop
                    record = IncomeAndCashFlowDetail.find_by_id(last_element1[1])
                  end
                  store_details(record,oo,row,read_via_numeral(row,1))
                  if position!=3
                    @array_record << last_element1 if last_element1
                    @array_record << last_element if last_element
                  end
                end
              elsif  read_via_numeral(row,2).nil? or  (!read_via_numeral(row,2).nil? and  read_via_numeral(row,2).class.to_s=="String" and !(["database:","entity:","accrual","january","cash"].include?(read_via_numeral(row,2))))
                if !read_via_numeral(row,2).nil?
                  if @array_record.length > 2
                    last_re = @array_record.pop
                  end
                  create_new_income_and_cash_flow_details(read_via_numeral(row,2),@array_record.last)
                end
                if !read_via_numeral(row,3).nil?
                  create_new_income_and_cash_flow_details(read_via_numeral(row,3),@array_record.last)
                end
              end
            end
            row=row+1
          end
        end

        # It is used to calculate the sum for the all the records in the income & cash table
        def calculate_sum_for_all_the_details_in_cash_flow_and_detail
          a = ["operating statement summary","cash flow statement summary","net cash flow","net operating income","net income"]
          @sum_for_each_item_query_array=[]
          for income_and_cash_flow in IncomeAndCashFlowDetail.all(:conditions=>["title not in (?) and resource_id =?  and resource_type = ?",a,@real_estate_property.id,@real_estate_property.class.to_s])
            #~ if !a.include?(income_and_cash_flow.title)
            sum_for_each_item(income_and_cash_flow,'p')
            sum_for_each_item(income_and_cash_flow,'c')
            sum_for_each_item(income_and_cash_flow,'b')
            #~ end
          end
          update_property_financial_periods_via_mysql(@sum_for_each_item_query_array*',')
        end

        # It is used to parse the operting statement summary details
        # it starts the 'income details' title & end at last row
        def parsing_operation_statement_summary(start_row_oss,start_col_oss,oo)
          row=start_row_oss+1
          while(row <=find_last_base_cell ) do
              if !read_via_numeral(row,1).nil? or  !read_via_numeral(row,2).nil? or !read_via_numeral(row,3).nil?
                last_element1 = nil
                last_element = nil
                if !read_via_numeral(row,1).nil?
                  if read_via_numeral(row,1).class.to_s == "String"  and (read_via_numeral(row,1)=='p' or read_via_numeral(row,1)=='c'  or read_via_numeral(row,1)=='b')
                    position = position_for_pcb_swig(read_via_numeral(row,1))
                    if @array_record.last[0]=="net operating income"
                      last_element = @array_record.last
                    else
                      last_element = @array_record.pop
                    end
                    record = IncomeAndCashFlowDetail.find_by_id(last_element[1])
                    if record.title.match(/total/)
                      record.destroy if position==3
                      last_element1 = @array_record.pop
                      record = IncomeAndCashFlowDetail.find_by_id(last_element1[1])
                    end
                    store_details(record,oo,row,read_via_numeral(row,1))
                    if position!=3
                      @array_record << last_element1 if last_element1
                      @array_record << last_element if last_element
                    end
                  end
                elsif  read_via_numeral(row,2).nil? or  (!read_via_numeral(row,2).nil? and  read_via_numeral(row,2).class.to_s=="String" and !(["database:","entity:","accrual","january","cash"].include?(read_via_numeral(row,2))))
                  if !read_via_numeral(row,2).nil?
                    parent_id = (read_via_numeral(row,2)=="net income") ? @array_record.first : @array_record.last
                    create_new_income_and_cash_flow_details(read_via_numeral(row,2),parent_id)
                  end
                  if !read_via_numeral(row,3).nil?
                    create_new_income_and_cash_flow_details(read_via_numeral(row,3),@array_record.last)
                  end
                end
              end
              row=row+1
            end
          end

          # It is used to store the property_financial_period for each income and cash flow statement
          def store_details(record,oo,row,pcb_type)
            if !@month_de.nil?
              prop_financial= PropertyFinancialPeriod.find_or_create_by_source_id_and_pcb_type_and_source_type(record.id, pcb_type, record.class.to_s)
              h = Hash.new
              col=2
              #the range restricted for future month actual parsing
              parse_range = pcb_type == 'c' && @finanical_year.to_i >= Date.today.year ? (Date.today.day > 25 ? 1..Date.today.month : 1...Date.today.month) : 1..12
              for m in parse_range
                if !read_via_numeral(row,col).nil? and read_via_numeral(row,col).to_i != 0
                  h["#{Date::MONTHNAMES[m].downcase}"] = read_via_numeral(row,col)
                elsif prop_financial["#{Date::MONTHNAMES[m].downcase}"].nil?
                  h["#{Date::MONTHNAMES[m].downcase}"] = 0
                else
                  h["#{Date::MONTHNAMES[m].downcase}"] = 0
                end
                col=col+1
              end
              @store_details_array << "(#{prop_financial.id},"+[h["january"],h["february"],h["march"],h["april"],h["may"],h["june"],h["july"],h["august"],h["september"],h["october"],h["november"],h["december"]].map(&:to_f)*","+")"
              #~ prop_financial.update_attributes(h)
              #prop_financial.update_attributes(:january =>oo.cell(row,2) , :february  =>oo.cell(row,3), :march =>oo.cell(row,4), :april =>oo.cell(row,5) ,:may => oo.cell(row,6),:june=> oo.cell(row,7),:july =>oo.cell(row,8),:august =>oo.cell(row,9),:september=> oo.cell(row,10),:october=> oo.cell(row,11),:november=>oo.cell(row,12) ,:december=>oo.cell(row,13))
            end
          end

          #added to parse capital improvement status report
          def extract_capital_improvement
            month_details = ['', 'january','february','march','april','may','june','july','august','september','october','november','december']
            categories = ['TENANT IMPROVEMENTS','BUILDING IMPROVEMENTS','LEASING COMMISSIONS','LOAN COSTS','LEASE COSTS','NET LEASE COSTS','CARPET & DRAPES']
            restricted_categories = ['TOTAL CAPITAL EXPENDITURES','TOTAL TENANT IMPROVEMENTS']
            exec_str = "prop_fin_period_A = prop_cap_improve.property_financial_periods.empty? ?  PropertyFinancialPeriod.new : prop_cap_improve.property_financial_periods.select{ |i| i.pcb_type == 'c' }.first; prop_fin_period_B = prop_cap_improve.property_financial_periods.empty? ?  PropertyFinancialPeriod.new : prop_cap_improve.property_financial_periods.select{ |i| i.pcb_type == 'b' }.first"
            prop_fin_period_A = Array.new # These are used to store the financial periods.
            prop_fin_period_B = Array.new
            cur_category = ''
            tenant_name = ''
            month_stored = []
            year_stored = ""
            @store_details_array = []
            processed = false
            doc = Document.find_by_id(@options[:doc_id])
            real_estate_property_id = doc.real_estate_property_id; # store the property id here
            #~ book = Excel.new "#{Rails.root.to_s}/public#{doc.public_filename}"
            #~ book.default_sheet = book.sheets[0]
            book=""
            roww = 7
            head = OpenStruct.new ; head.chk_category = nil
            budget_index = []
            actual_index = [] # below code skips TASK sheets and iterates over for headers.
            budget_index_category = Array.new(12,0)
            actual_index_category = Array.new(12,0)
            get_all_sheets.each do |rip|
              unless find_sheet_name(rip).include?("TASK")
                #book.default_sheet = rip
                1.upto find_last_column(rip) do |col|
                  case read_via_numeral_abs(roww, col, rip) #book.cell(roww, col)
                    when 'SUITE ID', 'SUITE'; head.suite = col
                    when 'CATEGORY'; head.category = col
                    when 'STATUS'; head.status = col
                    when 'BUDGET'; head.annual_budget = col if read_via_numeral_abs( roww - 1, col, rip)
                    when 'ACTUAL'; head.chk_category = col if head.chk_category.nil?
                  end
                end
                break
              end
            end
             (head.status + 1).upto head.status+12 do |ind| actual_index << ind  end
             (actual_index.last + 2).upto actual_index.last+13 do |ind| budget_index.push(ind) end
            @updated_query=[]
            prop_fin_period_A_array,prop_fin_period_A_query,prop_fin_period_A_all_data_array=[],[],[]
            prop_fin_period_B_array,prop_fin_period_B_query,prop_fin_period_B_all_data_array=[],[],[]
            get_all_sheets.each do |sheet|
              last_category = 'TENANT IMPROVEMENTS'
              last_tenant_name_flush = false;
              contd_flag = true
              sheet_name = read_via_numeral_abs(3,1,sheet).nil? ?  read_via_numeral_abs(3,8,sheet).split(' ') : read_via_numeral_abs(3,1,sheet).split(' ')
              sheet_name.push(read_via_numeral_abs(2,1,sheet).split(' ').first) if sheet_name.count < 2
              year = sheet_name[1].to_i
              @financial_year = year
              year_stored = year if year_stored.blank?
              month = month_details.index sheet_name[0].downcase
              next if month.nil? || year.nil? #(month.nil? || !PropertyCapitalImprovement.find_all_by_real_estate_property_id_and_month_and_year(real_estate_property_id, month, year).empty?)
              next if month > Date.today.month and year == Date.today.year
              month_stored << month
              #ActiveRecord::Base.connection.execute("delete t1, t2 from property_capital_improvements as t1, property_financial_periods as t2 where t1.real_estate_property_id = #{real_estate_property_id} and t1.month= #{month} and t1.year= #{year} and t2.source_id = t1.id and t2.source_type ='PropertyCapitalImprovement';")
              update_income_data = PropertyCapitalImprovement.find_all_by_real_estate_property_id_and_year_and_month(real_estate_property_id, year, month).map(&:tenant_name) - fetch_base_cell_titles
              update_income_data.reject! {|ichk| ["TOTAL BUILDING IMPROVEMENTS", "TOTAL LEASING COMMISSIONS", "TOTAL LEASE COSTS", "TOTAL LOAN COSTS", "TOTAL NET LEASE COSTS", "TOTAL CARPET & DRAPES"].include?(ichk) }
              update_income_data='("'+update_income_data*'","'+'")'
              ActiveRecord::Base.connection.execute("update property_capital_improvements pc left join property_financial_periods pf on pf.source_id = pc.id and (pf.pcb_type = 'b' or pf.pcb_type = 'c') and pf.source_type='PropertyCapitalImprovement' set pc.annual_budget=0, pf.january=0, pf.february=0, pf.march=0, pf.april=0, pf.may=0, pf.june=0, pf.july=0, pf.august=0, pf.september=0, pf.october=0, pf.november=0, pf.december=0 where pc.tenant_name in #{update_income_data} and pc.real_estate_property_id = #{real_estate_property_id} and pc.year=#{year} and pc.month=#{month};") unless update_income_data == "(\"\")"
              9.upto find_last_base_cell(sheet) do |row|
                processed = true
                category = read_via_numeral_abs(row, head.category, sheet)
                next if (category.nil? || category.empty?)
                categories.include?(category.strip) ? cur_category = category.strip : tenant_name = category.strip
                next if read_via_numeral_abs(row, head.chk_category, sheet).nil?
                #Leading zero truncation added .gsub!(/^0+/,'')
                suite_no = read_via_numeral_abs(row, head.suite, sheet).to_s.gsub('.0', '').gsub!(/^0+/,'')#.class == Float ) ? book.cell(row, head.suite).to_i : book.cell(row, head.suite)
                property_suite= (suite_no.nil? || suite_no.to_s.empty?) ? {'id' => nil } : Suite.find_or_create_by_real_estate_property_id_and_suite_number(real_estate_property_id, suite_no)
                if cur_category != last_category && ['LEASING COMMISSIONS','LEASE COSTS','NET LEASE COSTS','CARPET & DRAPES','LOAN COSTS'].include?(cur_category) && contd_flag
                  prop_cap_improve = PropertyCapitalImprovement.procedure_for_cap_exp(:nameIn=>"TOTAL "+last_category,:monthIn=>month,:yearIn=>year,:realIn=>real_estate_property_id,:categoryIn=> "TOTAL "+last_category, :statusIn=>'', :annualIn=>'NULL',:suiteIn=>nil, :typeIn=>'c')
                  swig_push_financial_record(prop_cap_improve['pcid'], actual_index_category, 'c', "PropertyCapitalImprovement")
                  swig_push_financial_record(prop_cap_improve['pcid'], budget_index_category, 'b', "PropertyCapitalImprovement")
                  budget_index_category = Array.new(12,0)
                  actual_index_category = Array.new(12,0)
                  last_category = cur_category
                  contd_flag = false if ['CARPET & DRAPES'].include?(cur_category)
                elsif last_tenant_name_flush
                  budget_index_category = Array.new(12,0)
                  actual_index_category = Array.new(12,0)
                  last_tenant_name_flush = false
                  last_category = cur_category
                end
                pri_category = restricted_categories.include?(tenant_name) ? tenant_name : cur_category
                prop_cap_improve = PropertyCapitalImprovement.procedure_for_cap_exp(:nameIn=>tenant_name,:monthIn=>month,:yearIn=>year,:realIn=>real_estate_property_id,:categoryIn=>pri_category,:statusIn=>read_via_numeral_abs(row, head.status, sheet), :annualIn=>read_via_numeral_abs(row, head.annual_budget, sheet).to_f,:suiteIn=>property_suite['id'], :typeIn=>'b')
                swig_push_financial_record(prop_cap_improve['pcid'], [read_via_numeral_abs(row, actual_index[0], sheet).to_f, read_via_numeral_abs(row, actual_index[1], sheet).to_f, read_via_numeral_abs(row, actual_index[2], sheet).to_f, read_via_numeral_abs(row, actual_index[3], sheet).to_f, read_via_numeral_abs(row, actual_index[4], sheet).to_f, read_via_numeral_abs(row, actual_index[5], sheet).to_f, read_via_numeral_abs(row, actual_index[6], sheet).to_f, read_via_numeral_abs(row, actual_index[7], sheet).to_f, read_via_numeral_abs(row, actual_index[8], sheet).to_f, read_via_numeral_abs(row, actual_index[9], sheet).to_f, read_via_numeral_abs(row, actual_index[10], sheet).to_f, read_via_numeral_abs(row, actual_index[11], sheet).to_f], 'c', "PropertyCapitalImprovement")
                 (0...Date.today.month).each do |month_ind|
                  actual_index_category[month_ind] +=read_via_numeral_abs(row, actual_index[month_ind], sheet).to_f unless read_via_numeral_abs(row, actual_index[month_ind], sheet).nil?
                end

                swig_push_financial_record(prop_cap_improve['pcid'], [read_via_numeral_abs(row, budget_index[0], sheet).to_f, read_via_numeral_abs(row, budget_index[1], sheet).to_f, read_via_numeral_abs(row, budget_index[2], sheet).to_f, read_via_numeral_abs(row, budget_index[3], sheet).to_f, read_via_numeral_abs(row, budget_index[4], sheet).to_f, read_via_numeral_abs(row, budget_index[5], sheet).to_f, read_via_numeral_abs(row, budget_index[6], sheet).to_f, read_via_numeral_abs(row, budget_index[7], sheet).to_f, read_via_numeral_abs(row, budget_index[8], sheet).to_f, read_via_numeral_abs(row, budget_index[9], sheet).to_f, read_via_numeral_abs(row, budget_index[10], sheet).to_f, read_via_numeral_abs(row, budget_index[11], sheet).to_f], 'b', "PropertyCapitalImprovement")
                 (0...12).each do |month_ind|
                  budget_index_category[month_ind] +=read_via_numeral_abs(row, budget_index[month_ind], sheet).to_f unless read_via_numeral_abs(row, budget_index[month_ind], sheet).nil?
                end
                last_tenant_name_flush = true if tenant_name == 'TOTAL TENANT IMPROVEMENTS'
              end
            end
            update_property_financial_periods_via_mysql(@store_details_array*',')
            month_stored.each do |ms|
              ikeys = PropertyCapitalImprovement.find_by_sql("select pf.id , pf.pcb_type from property_capital_improvements ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type= 'PropertyCapitalImprovement' and pf.pcb_type in ('c','b') where ic.tenant_name = 'Total capital expenditures' and ic.real_estate_property_id=#{real_estate_property_id} and ic.month=#{ms} and ic.year=#{year_stored} ;")
              ikeys.each do |ikey|
                ival = PropertyCapitalImprovement.find_by_sql("select ifnull(sum(pf1.january),'null') as january, ifnull(sum(pf1.february),'null') as february, ifnull(sum(pf1.march),'NULL') as march, ifnull(sum(pf1.april),'NULL') as april, ifnull(sum(pf1.may),'NULL') as may, ifnull(sum(pf1.june),'NULL') as june, ifnull(sum(pf1.july),'NULL') as july, ifnull(sum(pf1.august),'NULL') as august, ifnull(sum(pf1.september),'NULL') as september, ifnull(sum(pf1.october),'NULL') as october, ifnull(sum(pf1.november),'NULL') as november, ifnull(sum(pf1.december),'NULL') as december from property_capital_improvements pf  left join property_financial_periods pf1 on pf1.source_id = pf.id and pf1.source_type ='PropertyCapitalImprovement' and pf1.pcb_type ='#{ikey.pcb_type}' where pf.tenant_name in ('TOTAL BUILDING IMPROVEMENTS', 'TOTAL LEASING COMMISSIONS', 'TOTAL LEASE COSTS', 'TOTAL LOAN COSTS', 'TOTAL NET LEASE COSTS', 'TOTAL CARPET & DRAPES','TOTAL TENANT IMPROVEMENTS') and pf.real_estate_property_id= #{real_estate_property_id} and pf.month= #{ms} and pf.year= #{year_stored} group by pf1.pcb_type;").first
                ActiveRecord::Base.connection.execute("insert into property_financial_periods(id,january,february,march,april,may,june,july,august,september,october,november,december) values(#{ikey.id},#{ival.january}, #{ival.february}, #{ival.march},#{ival.april},#{ival.may},#{ival.june},#{ival.july},#{ival.august},#{ival.september},#{ival.october},#{ival.november},#{ival.december}) on duplicate key update january=values(january), february=values(february), march=values(march), april=values(april), may=values(may), june=values(june), july=values(july), august=values(august), september=values(september), october=values(october), november=values(november), december=values(december);")
              end
            end unless year_stored.blank? and month_stored.blank?
            store_variance_details(real_estate_property_id) if processed
          end

          def extract_capital_improvement_new
            month_details = ['', 'january','february','march','april','may','june','july','august','september','october','november','december']
            categories = ['TENANT IMPROVEMENTS','BUILDING IMPROVEMENTS','LEASING COMMISSIONS','LOAN COSTS','LEASE COSTS','NET LEASE COSTS','CARPET & DRAPES']
            restricted_categories = ['TOTAL CAPITAL EXPENDITURES','TOTAL TENANT IMPROVEMENTS']
            exec_str = "prop_fin_period_A = prop_cap_improve.property_financial_periods.empty? ?  PropertyFinancialPeriod.new : prop_cap_improve.property_financial_periods.select{ |i| i.pcb_type == 'c' }.first; prop_fin_period_B = prop_cap_improve.property_financial_periods.empty? ?  PropertyFinancialPeriod.new : prop_cap_improve.property_financial_periods.select{ |i| i.pcb_type == 'b' }.first"
            prop_fin_period_A = Array.new # These are used to store the financial periods.
            prop_fin_period_B = Array.new
            cur_category = ''
            tenant_name = ''
            month_stored = []
            year_stored = ""
            @store_details_array = []
            processed = false
            doc = Document.find_by_id(@options[:doc_id])
            real_estate_property_id = doc.real_estate_property_id; # store the property id here
            book = "" ; roww = 7
            head = OpenStruct.new ; head.chk_category = nil
            budget_index, actual_index = [], [] # below code skips TASK sheets and iterates over for headers.
            get_all_sheets.each do |rip|
              unless find_sheet_name(rip).include?("TASK")
                1.upto find_last_column(rip) do |col|
                  case read_via_numeral_abs(roww, col, rip) #book.cell(roww, col)
                    when 'SUITE ID', 'SUITE'; head.suite = col
                    when 'CATEGORY'; head.category = col
                    when 'STATUS'; head.status = col
                    when 'BUDGET'; head.annual_budget = col if read_via_numeral_abs( roww - 1, col, rip)
                    when 'ACTUAL'; head.chk_category = col if head.chk_category.nil?
                  end
                end
                break
              end
            end
             (head.suite + 2).upto head.suite+2 do |ind| actual_index << ind  end
             (actual_index.last + 2).upto actual_index.last+2 do |ind| budget_index.push(ind) end
            @updated_query=[]
            prop_fin_period_A_array,prop_fin_period_A_query,prop_fin_period_A_all_data_array=[],[],[]
            prop_fin_period_B_array,prop_fin_period_B_query,prop_fin_period_B_all_data_array=[],[],[]
            get_all_sheets.each do |sheet|
              last_category = 'TENANT IMPROVEMENTS'
              last_tenant_name_flush = false;
              contd_flag = true
              sheet_name = read_via_numeral_abs(3,1,sheet).nil? ?  read_via_numeral_abs(3,8,sheet).split(' ') : read_via_numeral_abs(3,1,sheet).split(' ')
              sheet_name.push(read_via_numeral_abs(2,1,sheet).split(' ').first) if sheet_name.count < 2
              year = sheet_name[1].to_i
              @financial_year = year
              year_stored = year if year_stored.blank?
              month = month_details.index sheet_name[0].downcase
              next if month.nil? || year.nil? #(month.nil? || !PropertyCapitalImprovement.find_all_by_real_estate_property_id_and_month_and_year(real_estate_property_id, month, year).empty?)
              next if month > Date.today.month and year == Date.today.year
              month_stored << month
              9.upto find_last_base_cell(sheet) do |row|
                processed = true
                chk = true
                category = read_via_numeral_abs(row, head.category, sheet)
                next if (category.nil? || category.empty?) && ( read_via_numeral_abs(row, head.chk_category, sheet).nil? || read_via_numeral_abs(row, head.chk_category, sheet) == "0.0" )  && read_via_numeral_abs(row+1, head.category, sheet).nil? && !read_via_numeral_abs(row+1, head.chk_category, sheet).nil?
                if read_via_numeral_abs(row, head.category, sheet).nil? && !read_via_numeral_abs(row, head.chk_category, sheet).nil? && read_via_numeral_abs(row, (head.category)+1, sheet).nil? && read_via_numeral_abs(row, (head.chk_category)+1, sheet).nil?
                  last_category =  "TOTAL "+cur_category
                end
                categories.include?(category.strip) ? cur_category = category.strip : tenant_name = category.strip unless (category.nil? || category.empty?)
                next if read_via_numeral_abs(row, head.chk_category, sheet).nil?
                #Leading zero truncation added .gsub!(/^0+/,'')
                suite_no = read_via_numeral_abs(row, head.suite, sheet).to_s.gsub('.0', '').gsub!(/^0+/,'')#.class == Float ) ? book.cell(row, head.suite).to_i : book.cell(row, head.suite)
                property_suite= (suite_no.nil? || suite_no.to_s.empty?) ? {'id' => nil } : Suite.find_or_create_by_real_estate_property_id_and_suite_no(real_estate_property_id, suite_no)
                if cur_category != last_category && ['LEASING COMMISSIONS','BUILDING IMPROVEMENTS','LEASE COSTS','NET LEASE COSTS','CARPET & DRAPES','LOAN COSTS'].include?(cur_category) && contd_flag && (read_via_numeral_abs(row, head.category, sheet).nil? || read_via_numeral_abs(row, head.category, sheet).empty?) &&  read_via_numeral_abs(row+1, head.category, sheet).nil? && read_via_numeral_abs(row+1, head.chk_category, sheet).nil?
                  chk = false
                  last_category = cur_category
                  prop_cap_improve = PropertyCapitalImprovement.procedure_for_cap_exp_new(:nameIn=>"TOTAL "+last_category,:monthIn=>month,:yearIn=>year,:realIn=>real_estate_property_id,:categoryIn=> "TOTAL "+last_category, :statusIn=>'', :annualIn=>'NULL',:suiteIn=>nil, :typeIn=>'c')
                  swig_push_financial_record_new(prop_cap_improve['pcid'], [read_via_numeral_abs(row, actual_index[0], sheet).to_f], 'c', "PropertyCapitalImprovement", month, year)
                  swig_push_financial_record_new(prop_cap_improve['pcid'], [read_via_numeral_abs(row, budget_index[0], sheet).to_f], 'b', "PropertyCapitalImprovement", month, year)
                  last_category = cur_category
                  contd_flag = false if ['CARPET & DRAPES'].include?(cur_category)
                elsif last_tenant_name_flush
                  last_tenant_name_flush = false
                  last_category = cur_category
                end
                if chk
                  pri_category = restricted_categories.include?(tenant_name) ? tenant_name : cur_category
                  prop_cap_improve = PropertyCapitalImprovement.procedure_for_cap_exp_new(:nameIn=>tenant_name,:monthIn=>month,:yearIn=>year,:realIn=>real_estate_property_id,:categoryIn=>pri_category,:statusIn=>read_via_numeral_abs(row, head.status, sheet), :annualIn=>read_via_numeral_abs(row, head.annual_budget, sheet).to_f,:suiteIn=>property_suite['id'], :typeIn=>'b')
                  swig_push_financial_record_new(prop_cap_improve['pcid'], [read_via_numeral_abs(row, actual_index[0], sheet).to_f], 'c', "PropertyCapitalImprovement", month, year)
                  swig_push_financial_record_new(prop_cap_improve['pcid'], [read_via_numeral_abs(row, budget_index[0], sheet).to_f], 'b', "PropertyCapitalImprovement", month, year)
                end
                last_tenant_name_flush = true if ['TOTAL TENANT IMPROVEMENTS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL LOAN COSTS','TOTAL LEASE COSTS','TOTAL NET LEASE COSTS','TOTAL CARPET & DRAPES'].include?(tenant_name)
              end
            end
            store_variance_details(real_estate_property_id) if processed
            #Code to update Property Capital Improvement of the Related portfolios of that property#
            doc = Document.find_by_id(@options[:doc_id])
            @real_estate_property = RealEstateProperty.find_by_id(doc.real_estate_property_id)
             portfolios_collect = @real_estate_property.portfolios
              portfolios_collect.each do |portfolio|
                Portfolio.portfolio_pci(portfolio.id,0, @financial_year)
              end
          end

          def swig_push_financial_record(data, lvl, type, source)
            # create the financial items and records for the property capital improvement item.
            pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>data, :sourceTypeIn=>source, :pcbIn=>type)
            lvl.fill('NULL', Date.today.month..11) if type == 'c' and @financial_year == Date.today.year
            @store_details_array << "(#{pf["pfid"]},"+lvl.join(',')+")"
          end

          def swig_push_financial_record_new(data, lvl, type, source, month, year)
            sql = ActiveRecord::Base.connection();
            #    pf = PropertyFinancialPeriod.procedure_call_new(:sourceIn=>data, :sourceTypeIn=>source, :pcbIn=>type, :jan_dec=>lvl,:monthIn=>month)
            pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>data, :sourceTypeIn=>source, :pcbIn=>type)
            month_details = ['', 'january','february','march','april','may','june','july','august','september','october','november','december']
            month_val = month_details[month]
            sql.execute("update property_financial_periods set #{month_val} = #{lvl[0]}, year = #{year} where id = #{pf["pfid"]};")
          end

          #used to parse aged receivables
          def extract_aged_receivables
            real_estate_property_id = RealEstateProperty.find_by_id(@options[:real_estate_id]).id
            # real_estate_property_id wants to be loaded here
            head = OpenStruct.new
            @base_cells.each do |rip|
              unless rip[1]["sheet"]["name"].include?("TASK")
                #~ book.default_sheet = rip
                1.upto find_last_base_cell(rip[0]) do |roww|
                  if read_via_numeral(roww, 1,rip[0]) == 'bldg - lease #'
                    1.upto find_last_column(rip[0]) do |coll|
                      case read_via_numeral(roww, coll,rip[0])
                        when 'tenant'; head.tenant = coll
                        when 'Amount'; head.amount = coll
                        when 'Current'; head.current = coll
                        when '30 Days'; head.days_30 = coll
                        when '60 Days'; head.days_60 = coll
                        when '90 Days'; head.days_90 = coll
                        when '120 Days'; head.days_120 = coll
                      end
                    end
                    head.start = roww
                    break;
                  end
                end
                break;
              end
            end
            @base_cells.each do |rip|
              if !rip[1]["sheet"]["name"].include?('TASK') # sheet title must contain 'AR' else not extracted
                sheet_date = read_via_numeral(3,1,rip[0]).nil? ? OpenStruct.new({:year=>nil, :month=>nil}) : (read_via_numeral(3,1,rip[0]).split(' ').last.to_date rescue read_via_numeral(3,1,rip[0]).split(' ').last.gsub('/','-').to_date) # Finding the month and year from excel
                year = sheet_date.year
                month = sheet_date.month
                ActiveRecord::Base.connection.execute("delete t1 from property_suites as t0, property_aged_receivables as t1 where t0.real_estate_property_id = #{real_estate_property_id} and t1.property_suite_id = t0.id and t1.month = #{month} and t1.year = #{year};") unless month.nil? and year.nil?
                head.start.next.upto find_last_base_cell(rip[0]) do |row|
                  next if read_via_numeral(row, head.tenant,rip[0]).nil? || read_via_numeral(row, head.tenant,rip[0]).empty?
                  break if (read_via_numeral(row, head.tenant,rip[0]) == "grand total:" || read_via_numeral(row, head.tenant,rip[0]) == "grand total") # exits when see the grand total in excel.
                  suite_id = read_via_numeral_abs(row, 1,rip[0]).nil? ? nil : read_via_numeral_abs(row, 1,rip[0]).to_s.gsub('.0', '')#.split(' ').last
                  prop_suite = suite_id.nil? ?  {'id' => nil}  : PropertySuite.find_or_create_by_real_estate_property_id_and_suite_number(real_estate_property_id, suite_id)
                  prop_aged_rec = PropertyAgedReceivable.new
                  prop_aged_rec.property_suite_id = prop_suite['id']
                  prop_aged_rec.tenant = read_via_numeral(row,head.tenant,rip[0])
                  prop_aged_rec.amount = read_via_numeral(row,head.amount,rip[0])
                  prop_aged_rec.paid_amount = read_via_numeral(row, head.current,rip[0])
                  prop_aged_rec.over_30days = read_via_numeral(row, head.days_30,rip[0])
                  prop_aged_rec.over_60days = read_via_numeral(row, head.days_60,rip[0])
                  prop_aged_rec.over_90days = read_via_numeral(row, head.days_90,rip[0])
                  prop_aged_rec.over_120days = read_via_numeral(row, head.days_120,rip[0])
                  prop_aged_rec.month = month
                  prop_aged_rec.year = year
                  prop_aged_rec.save
                end unless month.nil? and year.nil?
              end
            end
          end

          def swig_parse_rent_roll
            @cur_user=User.find_by_id(@options[:current_user]).id
            prop_id = RealEstateProperty.find_by_id(@options[:real_estate_id]).id
            month_and_year = read_via_numeral_abs(3,2).to_s.strip.split(' ').last.split('/').length>2 ? read_via_numeral_abs(3,2).to_s.strip.split(' ').last.split('/') :  read_via_numeral_abs(3,2).to_s.strip.split(' ').last.split('-')
            month = month_and_year.first
            year = '20'+month_and_year.last
            cont = true
            4.upto find_last_base_cell do |row|
              frst_col = read_via_numeral(row, 1).blank? ? '' : read_via_numeral(row, 1)
              cont = false if frst_col.include? 'lease'
              next if read_via_numeral(row, 2).blank? or frst_col.include? 'lease' or cont
              term_start = read_via_numeral(row, 6).to_date rescue nil
              term_end = read_via_numeral(row, 7).to_date rescue nil
              #Rent roll parsing - modified based on Lease Mgmt DB#
              if !(term_start.nil? && term_end.nil? ) && (term_start <= Date.today && term_end >= Date.today) #to check whether the suite is vacant
                #Leading zero truncation added .gsub!(/^0+/,'')
                suites = Suite.find_or_create_by_suite_no_and_real_estate_property_id(:suite_no=>read_via_numeral_abs(row,2).to_s.gsub('.0', '').gsub(/^0+/,''), :real_estate_property_id=>prop_id,:rentable_sqft=>read_via_numeral_abs(row, 3),:space_type=>read_via_numeral_abs(row, 5),:user_id=>@cur_user)
                suite_obj = Suite.find_by_id(suites.id)
                suite_obj.update_attributes(:status=>'Occupied')
                tenant = Tenant.procedure_tenant(:nameIn=>read_via_numeral(row,4).strip)
                lease = Lease.procedure_lease(:startDate=> term_start.nil? ? nil : term_start.strftime("%Y-%m-%d %H:%M:%S"), :endDate=>term_end.nil? ? nil : term_end.strftime("%Y-%m-%d %H:%M:%S"),:occType=>'current', :sStatus => nil,:realIn=>prop_id,:isExecuted=>1,:userId=>@cur_user,:effRate=>read_via_numeral(row, 11), :mtm => 0)
                lease_find = Lease.find_by_id(lease['leaseid'])
                lease_find.update_attributes(:status=>'Active')
                PropertyLeaseSuite.find_or_create_by_lease_id_and_tenant_id(:suite_ids=>[suites.id.to_i],:lease_id=>lease['leaseid'],:tenant_id=>tenant['tid'])
                rent  = Rent.find_or_create_by_lease_id(:lease_id=>lease['leaseid'])
                RentSchedule.find_or_create_by_suite_id(:suite_id=>suites.id, :amount_per_month=>read_via_numeral(row,10),:rent_id=>rent.id)
                #~ LeaseRentRoll.find_or_create_by_suite_id(:suite_id=>suites.id,:effective_rate=>read_via_numeral(row, 11),:month=>month, :year=> year,:real_estate_property_id=>prop_id)
                capex = CapEx.find_or_create_by_lease_id(:lease_id=>lease['leaseid'],:security_deposit_amount=>read_via_numeral(row, 14))
                TenantImprovement.find_or_create_by_cap_ex_id(:cap_ex_id=>capex.id,:total_amount=>read_via_numeral(row, 12))
                LeasingCommission.find_or_create_by_cap_ex_id(:cap_ex_id=>capex.id,:total_amount=>read_via_numeral(row, 13))
              else
                #A vacant suite will have a record only in suites alone mentioning the status 'vacant'
                #Leading zero truncation added .gsub!(/^0+/,'')
                suites = Suite.find_or_create_by_suite_no_and_real_estate_property_id(:suite_no=>read_via_numeral_abs(row,2).to_s.gsub('.0', '').gsub(/^0+/,''), :real_estate_property_id=>prop_id,:rentable_sqft=>read_via_numeral_abs(row, 3),:space_type=>read_via_numeral_abs(row, 5),:user_id=>@cur_user)
                suite_obj = Suite.find_by_id(suites.id)
                suite_obj.update_attributes(:status=>'Vacant')
                #~ LeaseRentRoll.find_or_create_by_suite_id(:suite_id=>suites.id,:effective_rate=>read_via_numeral(row, 11),:month=>month, :year=> year,:real_estate_property_id=>prop_id)
              end
            end unless month.blank? and year.blank?
          end

          # Recursive function used to calculate the sum for each element by adding the its each child records
          def sum_for_each_item(income_and_cash_flow,pcb_type)
            children = IncomeAndCashFlowDetail.find_all_by_parent_id(income_and_cash_flow.id)
            sum_jan=0;sum_feb=0;sum_mar=0;sum_apr=0;sum_may=0;sum_june=0;sum_july=0;sum_aug=0;sum_sep=0;sum_oct=0;sum_nov=0;sum_dec=0
            for child_par in children
              sum_for_each_item(child_par,pcb_type)
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
              income_period = PropertyFinancialPeriod.find_by_source_id_and_pcb_type_and_source_type(income_and_cash_flow.id, pcb_type, 'IncomeAndCashFlowDetail')
              #@sum_for_each_item_query_array << "("+"#{income_period.id},#{sum_jan},#{sum_feb},#{sum_mar},#{sum_apr},#{sum_may},#{sum_june},#{sum_july},#{sum_aug},#{sum_sep},#{sum_oct},#{sum_nov},#{sum_dec}"+")" if !income_period.nil?
              income_period.update_attributes(:january =>sum_jan , :february  =>sum_feb, :march =>sum_mar, :april =>sum_apr,:may =>sum_may,:june=>sum_june,:july =>sum_july,:august =>sum_aug,:september=>sum_sep,:october=>sum_oct,:november=>sum_nov,:december=>sum_dec)  if !income_period.nil?
            end
          end

          def added_lease(suite)
            property_lease_suites = PropertyLeaseSuite.all.map(&:suite_ids).flatten.compact.uniq
            @lease= nil
            if property_lease_suites.include?(suite.id)
              PropertyLeaseSuite.all.each do |property_lease_suite|
                if property_lease_suite.suite_ids?
                  suite_ids = property_lease_suite.suite_ids
                  suite_ids = [suite_ids]  if suite_ids.kind_of?(String) || suite_ids.kind_of?(Integer)
                  if suite_ids.include?(suite.id)
                    @lease = property_lease_suite.lease
                  end
                end
              end
            end
          end

          #To parse MRI - Rent Roll file
          def mri_parse_rent_roll
            @cur_user=User.find_by_id(@options[:current_user]).id
            prop_id = RealEstateProperty.find_by_id(@options[:real_estate_id]).id
            @new_page = false
            @date_row = 1
            2.upto find_last_base_cell do |row|
              @parse_date = true
              break if read_via_numeral(row,1).class.to_s =='String' && read_via_numeral(row,1).downcase.include?('total')
              page = read_via_numeral(row, 10)
              if page.class.to_s =='String' && page.include?('Page')
                @new_page = true
                @page_row = row
                @date_row = 1
              end
              if @new_page
                @date_row = @page_row + 1 if @page_row && @date_row != 0
                unless @date_row == 0
                  month_and_year = read_via_numeral_abs(@date_row,10).to_s.strip.split(' ').last.split('/').length>2 ? read_via_numeral_abs(@date_row,10).to_s.strip.split(' ').last.split('/') :  read_via_numeral_abs(@date_row,10).to_s.strip.split(' ').last.split('-')
                  @month = month_and_year.first
                  @year = month_and_year.last
                end
                @date_row = 0
                additional_space_suite = false
                if (read_via_numeral(row,3).class.to_s =='String' && read_via_numeral(row,3).downcase.include?('additional space'))
                  #Leading zero truncation added .gsub!(/^0+/,'')
                  suite_id = read_via_numeral(row,3).split(' ').last.gsub(/^0+/,'') if read_via_numeral(row,3) && read_via_numeral(row,3).split(' ')
                  additional_space_suite = true
                else
                  #Leading zero truncation added .gsub!(/^0+/,'')
                  suite_id = read_via_numeral(row,1).split('-')[1].to_s.gsub('.0', '').gsub(/^0+/,'') if read_via_numeral(row,1) && read_via_numeral(row,1).split('-')
                end
                if suite_id && !suite_id.blank?
                  term_start = read_via_numeral(row, 4).to_date rescue nil
                  if additional_space_suite
                    @parse_date = false
                    tenant_name = 'Additional space'
                    date_and_sqft = read_via_numeral(row, 5).split(' ')
                    term_end = date_and_sqft[0].to_date rescue nil
                    sqft = date_and_sqft[1]
                  else
                    tenant_name = read_via_numeral(row,3)
                    term_end = read_via_numeral(row, 5).to_date rescue nil
                  end
                  if(read_via_numeral(row,3).class.to_s =='String' && read_via_numeral(row,3).downcase.include?('vacant')) || (term_start.nil? && term_end.nil?)
                    sqft = (read_via_numeral(row,3).class.to_s =='String' && read_via_numeral(row,3).downcase.include?('vacant')) ? read_via_numeral(row,5) : read_via_numeral(row,6) unless additional_space_suite
                    base_rent_rate = (read_via_numeral(row,7) && read_via_numeral(row,7).split(' ')) ? read_via_numeral(row,7).split(' ')[0] : read_via_numeral(row,7)
                    base_rent_rate_anual = (read_via_numeral(row,7) && read_via_numeral(row,7).split(' ')) ? read_via_numeral(row,7).split(' ')[1] : read_via_numeral(row,7)
                    suites = Suite.find_or_create_by_suite_no_and_real_estate_property_id(:suite_no=>suite_id, :real_estate_property_id=>prop_id,:rentable_sqft=>sqft,:user_id=>@cur_user)
                    suite_obj = Suite.find_by_id(suites.id)
                    suite_obj.update_attributes(:status=>'Vacant',:rentable_sqft=>sqft)
                    if !(term_start.nil? && term_end.nil?)
                      added_lease(suite_obj)
                      new_start = "01-01-#{Date.today.year}"
                      occ_type = (!(term_start.nil? && term_end.nil? ) && (term_end < Date.today)) ? 'expirations' : (!(term_start.nil? && term_end.nil? ) && (term_start >= new_start.to_date && term_end > Date.today) ? 'new' : (!(term_start.nil? && term_end.nil? ) && (term_start <= Date.today && term_end >= Date.today) ? 'current' : ''))
                      is_executed = (term_start.nil? && term_end.nil? ) ? 0 : 1
                      unless additional_space_suite
                        if @lease.present?
                          @lease_new = false
                          @lease.update_attributes(:commencement=>(term_start.nil? ? nil : term_start.strftime("%Y-%m-%d %H:%M:%S")), :expiration=>(term_end.nil? ? nil : term_end.strftime("%Y-%m-%d %H:%M:%S")),:occupancy_type=>occ_type,:status => nil,:real_estate_property_id=>prop_id,:is_executed=>is_executed,:user_id=>@cur_user,:effective_rate=>nil, :mtm => 0)
                          lease = @lease
                        else
                          @lease_new = true
                          lease = Lease.create(:commencement=>(term_start.nil? ? nil : term_start.strftime("%Y-%m-%d %H:%M:%S")), :expiration=>(term_end.nil? ? nil : term_end.strftime("%Y-%m-%d %H:%M:%S")),:occupancy_type=>occ_type,:status => nil,:real_estate_property_id=>prop_id,:is_executed=>is_executed,:user_id=>@cur_user,:effective_rate=>nil, :mtm => 0)
                        end
                      end
                      commercial_lease_occupancy = CommercialLeaseOccupancy.find_or_create_by_real_estate_property_id_and_year_and_month(:real_estate_property_id=>prop_id,:month=>Date.today.month,:year=>Date.today.year)
                      if commercial_lease_occupancy
                        expirations_actual = LeaseRentRoll.find_by_sql("select sum(sqft) from lease_rent_rolls where occupancy_type= 'expirations' and real_estate_property_id = #{prop_id}")
                        commercial_lease_occupancy.expirations_actual = expirations_actual
                      end
                      lease_id =  additional_space_suite ? @master_lease_id : lease.id
                      unless additional_space_suite
                        master_lease = Lease.find_by_id(@master_lease_id)
                        if master_lease.present? && master_lease.rent.present? && master_lease.rent.rent_schedules.present? && master_lease.rent.rent_schedules.count.eql?(1)
                          latest_rent_schedule = master_lease.rent.rent_schedules.first
                          first_rent_schedule.update_attributes(:is_all_suites_selected => true, :suite_id => nil)
                        end
                      end
                      @master_lease_id = lease.id if additional_space_suite != true
                      lease.update_attributes(:status=>'Inactive') unless additional_space_suite
                      lease_exists = PropertyLeaseSuite.find_by_lease_id(lease_id)
                      tenant = Tenant.find_by_tenant_legal_name(tenant_name)
                      if lease_exists.present? && tenant.present?
                        tenant.tenant_legal_name = tenant_name
                        tenant.save
                      else
                        tenant = Tenant.create(:tenant_legal_name=>tenant_name)
                      end

                      number_of_months = RentSchedule.get_rent_schedule_period(term_start,term_end)

                      rent = Rent.find_by_lease_id(lease_id)
                      if rent.blank?
                        rent =  Rent.find_or_create_by_lease_id(:lease_id=>lease_id, :is_all_suites_selected => true)
                      else
                        rent.update_attributes(:lease_id=>lease_id, :is_all_suites_selected => true)
                      end

                      if additional_space_suite
                        property_lease_suite = PropertyLeaseSuite.find_by_lease_id(lease_id)
                        property_lease_suite.suite_ids << suite_obj.id
                        property_lease_suite.save
                        rent.update_attributes(:is_all_suites_selected => false)
                      else
                        property_lease_suite = PropertyLeaseSuite.find_or_create_by_lease_id(:suite_ids=>[suite_obj.id.to_i],:lease_id=>lease_id,:tenant_id=>tenant.id)
                      end

                      rent_schedule = RentSchedule.find_by_suite_id_and_rent_id(suites.id, rent.try(:id))
                      if rent_schedule.blank?
                        existing_suite_ids = property_lease_suite.try(:suite_ids) || []
                        if existing_suite_ids.include?(suites.id) && !additional_space_suite
                          rent.rent_schedules.destroy_all
                        end
                        rent_schedule = RentSchedule.find_or_create_by_suite_id_and_rent_id(:suite_id=>suites.id, :amount_per_month=>base_rent_rate,:rent_id=>rent.id,:amount_per_month_per_sqft=>base_rent_rate_anual.to_f/12,:from_date=>term_start,:to_date=>term_end,:no_of_months=>number_of_months, :rent_schedule_type => "Base")
                      elsif rent
                        rent.rent_schedules.destroy_all
                        rent_schedule = RentSchedule.find_or_create_by_suite_id_and_rent_id(:suite_id=>suites.id, :amount_per_month=>base_rent_rate,:rent_id=>rent.id,:amount_per_month_per_sqft=>base_rent_rate_anual.to_f/12,:from_date=>term_start,:to_date=>term_end,:no_of_months=>number_of_months, :rent_schedule_type => "Base")
                      end
                      #                      if additional_space_suite
                      #                        property_lease_suite = PropertyLeaseSuite.find_by_lease_id(lease_id)
                      #                        property_lease_suite.suite_ids << suite_obj.id
                      #                        property_lease_suite.save
                      #                      else
                      #                        PropertyLeaseSuite.find_or_create_by_lease_id(:suite_ids=>[suite_obj.id.to_i],:lease_id=>lease_id,:tenant_id=>tenant.id)
                      #                      end
                      #                      number_of_months = RentSchedule.get_rent_schedule_period(term_start,term_end)
                      #
                      #                      rent = Rent.find_by_lease_id(lease_id)
                      #                      if rent.blank?
                      #                        Rent.find_or_create_by_lease_id(:lease_id=>lease_id, :is_all_suites_selected => false)
                      #                      else
                      #                        rent.update_attributes(:lease_id=>lease_id, :is_all_suites_selected => false)
                      #                      end
                      #
                      #                      rent_schedule = RentSchedule.find_by_suite_id_and_rent_id(suites.id, rent.try(:id))
                      #                      if rent_schedule.blank?
                      #                        rent_schedule = RentSchedule.find_or_create_by_suite_id_and_rent_id(:suite_id=>suites.id, :amount_per_month=>base_rent_rate,:rent_id=>rent.id,:amount_per_month_per_sqft=>base_rent_rate_anual.to_f/12,:from_date=>term_start,:to_date=>term_end,:no_of_months=>number_of_months, :rent_schedule_type => "Base")
                      #                      elsif rent
                      #                        rent.rent_schedules.destroy_all
                      #                        rent_schedule = RentSchedule.find_or_create_by_suite_id_and_rent_id(:suite_id=>suites.id, :amount_per_month=>base_rent_rate,:rent_id=>rent.id,:amount_per_month_per_sqft=>base_rent_rate_anual.to_f/12,:from_date=>term_start,:to_date=>term_end,:no_of_months=>number_of_months, :rent_schedule_type => "Base")
                      #                      end

                    end
                  else
                    sqft = read_via_numeral(row,6)  unless additional_space_suite
                    base_rent_rate = (read_via_numeral(row,7) && read_via_numeral(row,7).split(' ')) ? read_via_numeral(row,7).split(' ')[0] : read_via_numeral(row,7)
                    base_rent_rate_anual = (read_via_numeral(row,7) && read_via_numeral(row,7).split(' ')) ? read_via_numeral(row,7).split(' ')[1] : read_via_numeral(row,7)
                    suites = Suite.find_or_create_by_suite_no_and_real_estate_property_id(:suite_no=>suite_id, :real_estate_property_id=>prop_id,:rentable_sqft=>sqft,:user_id=>@cur_user)
                    suite_obj = Suite.find_by_id(suites.id)
                    suite_obj.update_attributes(:status=>'Occupied',:rentable_sqft=>sqft)
                    new_start = "01-01-#{Date.today.year}"
                    occ_type = (!(term_start.nil? && term_end.nil? ) && (term_end < Date.today)) ? 'expirations' : (!(term_start.nil? && term_end.nil? ) && (term_start >= new_start.to_date && term_end > Date.today) ? 'new' : (!(term_start.nil? && term_end.nil? ) && (term_start <= Date.today && term_end >= Date.today) ? 'current' : ''))
                    added_lease(suite_obj)
                    mtm = term_end < Date.today ? 1 : 0
                    unless additional_space_suite
                      if @lease.present?
                        @lease_new = false
                        @lease.update_attributes(:commencement=>(term_start.nil? ? nil : term_start.strftime("%Y-%m-%d %H:%M:%S")), :expiration=>(term_end.nil? ? nil : term_end.strftime("%Y-%m-%d %H:%M:%S")),:occupancy_type=>occ_type,:status => nil,:real_estate_property_id=>prop_id,:is_executed=>1,:user_id=>@cur_user,:effective_rate=>nil, :mtm => mtm)
                        lease = @lease
                      else
                        @lease_new = true
                        lease = Lease.create(:commencement=>(term_start.nil? ? nil : term_start.strftime("%Y-%m-%d %H:%M:%S")), :expiration=>(term_end.nil? ? nil : term_end.strftime("%Y-%m-%d %H:%M:%S")),:occupancy_type=>occ_type,:status => nil,:real_estate_property_id=>prop_id,:is_executed=>1,:user_id=>@cur_user,:effective_rate=>nil, :mtm => mtm)
                      end
                    end
                    unless additional_space_suite
                      master_lease = Lease.find_by_id(@master_lease_id)
                      if master_lease.present? && master_lease.rent.present? && master_lease.rent.rent_schedules.present? && master_lease.rent.rent_schedules.count.eql?(1)
                        first_rent_schedule = master_lease.rent.rent_schedules.first
                        first_rent_schedule.update_attributes(:is_all_suites_selected => true, :suite_id => nil)
                      end
                    end

                    @master_lease_id = lease.id unless additional_space_suite

                    lease_id =  additional_space_suite ? @master_lease_id : lease.id
                    lease.update_attributes(:status=>'Active')  unless additional_space_suite
                    lease_exists = PropertyLeaseSuite.find_by_lease_id(lease_id)
                    tenant = Tenant.find_by_tenant_legal_name(tenant_name)
                    if lease_exists.present? && tenant.present?
                      tenant.tenant_legal_name = tenant_name
                      tenant.save
                    else
                      tenant = Tenant.create(:tenant_legal_name=>tenant_name)
                    end

                    number_of_months = RentSchedule.get_rent_schedule_period(term_start,term_end)

                    rent = Rent.find_by_lease_id(lease_id)
                    if rent.blank?
                      rent = Rent.find_or_create_by_lease_id(:lease_id=>lease_id, :is_all_suites_selected => true)
                    else
                      rent.update_attributes(:lease_id=>lease_id, :is_all_suites_selected => true)
                    end


                    if additional_space_suite
                      property_lease_suite = PropertyLeaseSuite.find_by_lease_id(lease_id)
                      if property_lease_suite
                        property_lease_suite.suite_ids << suite_obj.id
                        property_lease_suite.save
                      end
                      rent.update_attributes(:is_all_suites_selected => false)
                    else
                      property_lease_suite = PropertyLeaseSuite.find_or_create_by_lease_id(:suite_ids=>[suite_obj.id.to_i],:lease_id=>lease_id,:tenant_id=>tenant.id)
                    end


                    rent_schedule = RentSchedule.find_by_suite_id_and_rent_id(suites.id, rent.try(:id))
                    if rent_schedule.blank?

                      existing_suite_ids = property_lease_suite.try(:suite_ids) || []
                      rent.rent_schedules.destroy_all   if existing_suite_ids.include?(suites.id) && !additional_space_suite

                      rent_schedule = RentSchedule.find_or_create_by_suite_id_and_rent_id(:suite_id=>suites.id, :amount_per_month=>base_rent_rate,:rent_id=>rent.id,:amount_per_month_per_sqft=>base_rent_rate_anual.to_f/12,:from_date=>term_start,:to_date=>term_end,:no_of_months=>number_of_months, :rent_schedule_type => "Base")
                    elsif rent
                      rent.rent_schedules.destroy_all
                      rent_schedule = RentSchedule.find_or_create_by_suite_id_and_rent_id(:suite_id=>suites.id, :amount_per_month=>base_rent_rate,:rent_id=>rent.id,:amount_per_month_per_sqft=>base_rent_rate_anual.to_f/12,:from_date=>term_start,:to_date=>term_end,:no_of_months=>number_of_months, :rent_schedule_type => "Base")
                    end
                    #                    if additional_space_suite
                    #                      property_lease_suite = PropertyLeaseSuite.find_by_lease_id(lease_id)
                    #                      property_lease_suite.suite_ids << suite_obj.id
                    #                      property_lease_suite.save
                    #                    else
                    #                      PropertyLeaseSuite.find_or_create_by_lease_id(:suite_ids=>[suites.id.to_i],:lease_id=>lease_id,:tenant_id=>tenant.id)
                    #                    end
                    #                    number_of_months = RentSchedule.get_rent_schedule_period(term_start,term_end)
                    #
                    #                    rent = Rent.find_by_lease_id(lease_id)
                    #                    if rent.blank?
                    #                      Rent.find_or_create_by_lease_id(:lease_id=>lease_id, :is_all_suites_selected => false)
                    #                    else
                    #                      rent.update_attributes(:lease_id=>lease_id, :is_all_suites_selected => false)
                    #                    end
                    #
                    #                    rent_schedule = RentSchedule.find_by_suite_id_and_rent_id(suites.id, rent.try(:id))
                    #                    if rent_schedule.blank?
                    #                      rent_schedule = RentSchedule.find_or_create_by_suite_id_and_rent_id(:suite_id=>suites.id, :amount_per_month=>base_rent_rate,:rent_id=>rent.id,:amount_per_month_per_sqft=>base_rent_rate_anual.to_f/12,:from_date=>term_start,:to_date=>term_end,:no_of_months=>number_of_months, :rent_schedule_type => "Base")
                    #                    elsif rent
                    #                      rent.rent_schedules.destroy_all
                    #                      rent_schedule = RentSchedule.find_or_create_by_suite_id_and_rent_id(:suite_id=>suites.id, :amount_per_month=>base_rent_rate,:rent_id=>rent.id,:amount_per_month_per_sqft=>base_rent_rate_anual.to_f/12,:from_date=>term_start,:to_date=>term_end,:no_of_months=>number_of_months, :rent_schedule_type => "Base")
                    #                    end
                  end
                end
              end
            end
          end
        end
