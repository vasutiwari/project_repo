class IncomeAndCashFlowDetail < ActiveRecord::Base
	belongs_to :user
  attr_accessor :tool_tip
	has_many :property_financial_periods, :as=>:source, :dependent=>:destroy
  has_one :income_cash_flow_explanation, :conditions=> "ytd=false", :dependent=>:destroy
  has_one :income_cash_flow_explanation_ytd,:class_name=>'IncomeCashFlowExplanation', :conditions=> "ytd=true", :dependent=>:destroy
  before_save :set_client_id_in_income_and_cash_flow_detail

  def self.procedure_call(*args)
    args = args.extract_options!
    user = User.find_by_id(args[:userIn])
    ret = ActiveRecord::Base.connection.execute("call incomeCashFlowFindReplace(\"#{args[:titleIn]}\",#{args[:realIn]},\"#{args[:realTypeIn]}\",#{args[:parentIn]},#{args[:userIn]},#{args[:yearIn]},#{user.client_id})")
    ret = Document.record_to_hash(ret).first rescue nil
    ActiveRecord::Base.connection.reconnect!
    ret
  end

  def self.procedure_call_scode(*args)
    args = args.extract_options!
    user = User.find_by_id(args[:userIn])
    ret = ActiveRecord::Base.connection.execute("call incomeCashFlowFindReplaceScode(\"#{args[:titleIn]}\",#{args[:realIn]},\"#{args[:realTypeIn]}\",#{args[:parentIn]},#{args[:userIn]},#{args[:yearIn]},\"#{args[:sCode].nil? ? '' : args[:sCode]  }\",\"#{args[:iNormalBalance].nil? ? '' : args[:iNormalBalance]  }\",#{user.client_id})")
    ret = Document.record_to_hash(ret).first rescue nil
    ActiveRecord::Base.connection.reconnect!
    ret
  end

  def self.procedure_call_transacrions(*args)
    args = args.extract_options!
    ret = ActiveRecord::Base.connection.execute("call FindOrCreateTransaction('#{args[:post_dateIn]}','#{args[:discriptionIn]}','#{args[:notesIn]}',#{args[:debitIn]},#{args[:creditIn]},#{args[:yearIn]},#{args[:monthIn]},#{args[:real_estate_property_id]},\"#{args[:da_amountIn].nil? ? 0 : args[:da_amountIn]}\",\"#{args[:acc_codeIn].nil? ? 0 : args[:acc_codeIn]}\", '#{args[:hMyIn]}')")
    ret = Document.record_to_hash(ret).first rescue nil
    ActiveRecord::Base.connection.reconnect!
    ret
  end

  def set_client_id_in_income_and_cash_flow_detail
      self.client_id = self.user.client_id
    end

  def self.trailing_months
      year = 2011
      property_collect= RealEstateProperty.where("property_name not like '%property_created_by_system%'")
      property_collect.each do |property|
			common_var_per_array,common_var_per_query,common_var_per_all_data_array,@updated_query=[],[],[],[],[],[]
			a,b,c,d,e={},{},Hash.new { |h,k| h[k] = {} },{},Hash.new { |h,k| h[k] = {} }
			coll_prev = IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(property.id, 'RealEstateProperty',year - 1)
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

          coll_current = IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(property.id, 'RealEstateProperty',year)
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
                c["#{j}"]["#{arr[i]}"] = i.eql?(0) ? a["#{j}_budget"][11].to_f  : (a["#{j}_budget"][11].to_f - a["#{j}_budget"][i].to_f) + b["#{j}_budget"][i].to_f	rescue []
                e["#{j}"]["#{arr[i]}"] = i.eql?(0) ? a["#{j}_actual"][11].to_f  : (a["#{j}_actual"][11].to_f - a["#{j}_actual"][i].to_f) + b["#{j}_actual"][i].to_f	rescue []
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
          coll_current = IncomeAndCashFlowDetail.find_all_by_resource_id_and_resource_type_and_year(property.id, 'RealEstateProperty',year)
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
                c["#{j}"]["#{arr[i]}"] = b["#{j}_budget"][i].to_f	rescue []
                e["#{j}"]["#{arr[i]}"] = b["#{j}_actual"][i].to_f	rescue []
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
    end

    def self.create_and_update_property_financial_periods_via_mysql(data_hash,query,overall_data_hash,is_year=false)
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
              @updated_query << "("+"#{y['id']},#{x['january'].present? ? x['january'] : 0},#{x['february'].present? ? x['february'] : 0},#{x['march'].present? ? x['march'] : 0},#{x['april'].present? ? x['april'] : 0},#{x['may'].present? ? x['may'] : 0},#{x['june'].present? ? x['june'] : 0 },#{x['july'].present? ? x['july'] : 0},#{x['august'].present? ? x['august'] : 0},#{x['september'].present? ? x['september'] : 0},#{x['october'].present? ? x['october'] : 0},#{x['november'].present? ? x['november'] : 0},#{x['december'].present? ? x['december']  : 0},#{x['year']}"+")"
            else
              @updated_query << "("+"#{y['id']},#{x['january'].present? ? x['january'] : 0},#{x['february'].present? ? x['february'] : 0},#{x['march'].present? ? x['march'] : 0},#{x['april'].present? ? x['april'] : 0},#{x['may'].present? ? x['may'] : 0},#{x['june'].present? ? x['june'] : 0 },#{x['july'].present? ? x['july'] : 0},#{x['august'].present? ? x['august'] : 0},#{x['september'].present? ? x['september'] : 0},#{x['october'].present? ? x['october'] : 0},#{x['november'].present? ? x['november'] : 0},#{x['december'].present? ? x['december']  : 0}"+")"
            end
          end
        end
      end
    end
  end

  def self.update_property_financial_periods_via_mysql(query,is_year=false)
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

end
