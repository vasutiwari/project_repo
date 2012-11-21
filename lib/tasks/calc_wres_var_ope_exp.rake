namespace :modify do
  task :var_ope_exp => :environment do
    all_props =  RealEstateProperty.all.map{|i| i.id if i.accounting_system_type_id == 4 }.compact
    all_props.each do |prop|
      ids_collection = []
      incs = IncomeAndCashFlowDetail.find_all_by_resource_id_and_title(prop, 'operating expenses')
      incs.each do  |inc|
      next if inc.nil?
      var_ope_exp = IncomeAndCashFlowDetail.procedure_call(:titleIn=>'variable operating exp',:realIn=>prop, :realTypeIn=>"RealEstateProperty",:parentIn=>inc.id,:userIn=>inc.user_id, :yearIn=>inc.year)
      all_inc_items = IncomeAndCashFlowDetail.find(:all ,:conditions=>['parent_id = ? and title not in (?)', inc, ['variable operating exp','contingency','taxes and insurance']])
      #PropertyFinancialPeriod.procedure_call(:sourceIn=>var_ope_exp, :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'c')
      #PropertyFinancialPeriod.procedure_call(:sourceIn=>var_ope_exp, :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'b')
      all_inc_items.each do |child|
        child.parent_id = var_ope_exp['id']
        child.save
        ids_collection << child.id
      end
      unless ids_collection.blank?
        ival = PropertyFinancialPeriod.find_by_sql("select sum(pf.january) january, sum(pf.february) february , sum(pf.march) march, sum(pf.april) april, sum(pf.may) may, sum(pf.june) june, sum(pf.july) july, sum(pf.august) august, sum(pf.september) september, sum(pf.october) october, sum(pf.november) november, sum(pf.december) december from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id  and pf.source_type ='IncomeAndCashFlowDetail' and pf.pcb_type = 'b' where ic.id in (#{ids_collection.join(',')}) group by resource_id").first
        Date::MONTHNAMES.compact.each {|iv| ival.send(:"#{iv.downcase}=",0) if ival.send(:"#{iv.downcase}").nil? }
        ActiveRecord::Base.connection.execute("insert into property_financial_periods(source_id,source_type,pcb_type,january,february,march,april,may,june,july,august,september,october,november,december) values(#{var_ope_exp['id']}, 'IncomeAndCashFlowDetail', 'b',#{ival.january}, #{ival.february}, #{ival.march},#{ival.april},#{ival.may},#{ival.june},#{ival.july},#{ival.august},#{ival.september},#{ival.october},#{ival.november},#{ival.december}) on duplicate key update january=values(january), february=values(february), march=values(march), april=values(april), may=values(may), june=values(june), july=values(july), august=values(august), september=values(september), october=values(october), november=values(november), december=values(december);")
        ival = PropertyFinancialPeriod.find_by_sql("select sum(pf.january) january, sum(pf.february) february , sum(pf.march) march, sum(pf.april) april, sum(pf.may) may, sum(pf.june) june, sum(pf.july) july, sum(pf.august) august, sum(pf.september) september, sum(pf.october) october, sum(pf.november) november, sum(pf.december) december from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id  and pf.source_type ='IncomeAndCashFlowDetail' and pf.pcb_type = 'c' where ic.id in (#{ids_collection.join(',')}) group by resource_id").first
        Date::MONTHNAMES.compact.each {|iv| ival.send(:"#{iv.downcase}=",0) if ival.send(:"#{iv.downcase}").nil? }
        ActiveRecord::Base.connection.execute("insert into property_financial_periods(source_id,source_type,pcb_type,january,february,march,april,may,june,july,august,september,october,november,december) values(#{var_ope_exp['id']}, 'IncomeAndCashFlowDetail', 'c',#{ival.january}, #{ival.february}, #{ival.march},#{ival.april},#{ival.may},#{ival.june},#{ival.july},#{ival.august},#{ival.september},#{ival.october},#{ival.november},#{ival.december}) on duplicate key update january=values(january), february=values(february), march=values(march), april=values(april), may=values(may), june=values(june), july=values(july), august=values(august), september=values(september), october=values(october), november=values(november), december=values(december);")
        coll = IncomeAndCashFlowDetail.find_by_id(var_ope_exp['id'])
          pfs = coll.property_financial_periods
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
              end
            end
            var_arr = []
            per_arr = []
            var_ytd_arr = []
            per_ytd_arr = []
            0.upto(11) do |indx|
              var_arr[indx] =  b_arr[indx].to_f - a_arr[indx].to_f
              var_ytd_arr[indx] =  b_ytd_arr[indx].to_f - a_ytd_arr[indx].to_f
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
            pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(coll.id, coll.class.to_s, 'var_amt')
            pf.january= var_arr[0];pf.february=var_arr[1];pf.march=var_arr[2];pf.april=var_arr[3];pf.may=var_arr[4];pf.june=var_arr[5];pf.july=var_arr[6];pf.august=var_arr[7];pf.september=var_arr[8];pf.october=var_arr[9];pf.november=var_arr[10];pf.december=var_arr[11];pf.save

            pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(coll.id, coll.class.to_s, 'var_per')
            pf.january= per_arr[0];pf.february=per_arr[1];pf.march=per_arr[2];pf.april=per_arr[3];pf.may=per_arr[4];pf.june=per_arr[5];pf.july=per_arr[6];pf.august=per_arr[7];pf.september=per_arr[8];pf.october=per_arr[9];pf.november=per_arr[10];pf.december=per_arr[11];pf.save

            pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(coll.id, coll.class.to_s, 'b_ytd')
            pf.january= b_ytd_arr[0];pf.february=b_ytd_arr[1];pf.march=b_ytd_arr[2];pf.april=b_ytd_arr[3];pf.may=b_ytd_arr[4];pf.june=b_ytd_arr[5];pf.july=b_ytd_arr[6];pf.august=b_ytd_arr[7];pf.september=b_ytd_arr[8];pf.october=b_ytd_arr[9];pf.november=b_ytd_arr[10];pf.december=b_ytd_arr[11];pf.save

            pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(coll.id, coll.class.to_s, 'c_ytd')
            pf.january= a_ytd_arr[0];pf.february=a_ytd_arr[1];pf.march=a_ytd_arr[2];pf.april=a_ytd_arr[3];pf.may=a_ytd_arr[4];pf.june=a_ytd_arr[5];pf.july=a_ytd_arr[6];pf.august=a_ytd_arr[7];pf.september=a_ytd_arr[8];pf.october=a_ytd_arr[9];pf.november=a_ytd_arr[10];pf.december=a_ytd_arr[11];pf.save

            pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(coll.id, coll.class.to_s, 'var_amt_ytd')
            pf.january= var_ytd_arr[0];pf.february=var_ytd_arr[1];pf.march=var_ytd_arr[2];pf.april=var_ytd_arr[3];pf.may=var_ytd_arr[4];pf.june=var_ytd_arr[5];pf.july=var_ytd_arr[6];pf.august=var_ytd_arr[7];pf.september=var_ytd_arr[8];pf.october=var_ytd_arr[9];pf.november=var_ytd_arr[10];pf.december=var_ytd_arr[11];pf.save

            pf = PropertyFinancialPeriod.find_or_create_by_source_id_and_source_type_and_pcb_type(coll.id, coll.class.to_s, 'var_per_ytd')
            pf.january= per_ytd_arr[0];pf.february=per_ytd_arr[1];pf.march=per_ytd_arr[2];pf.april=per_ytd_arr[3];pf.may=per_ytd_arr[4];pf.june=per_ytd_arr[5];pf.july=per_ytd_arr[6];pf.august=per_ytd_arr[7];pf.september=per_ytd_arr[8];pf.october=per_ytd_arr[9];pf.november=per_ytd_arr[10];pf.december=per_ytd_arr[11];pf.save

          end
        
      end
    
    
    
    end
    
    end
  end
  
  
  task :real_page_actuals => :environment do
    all_props =  RealEstateProperty.all.map{|i| i.i}.compact
    all_props.each do |itr|
      ActiveRecord::Base.connection.execute("update income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type= 'IncomeAndCashFlowDetail' and pf.pcb_type ='c'
      set pf.august = NULL, pf.september = NULL, pf.october = NULL, pf.november = NULL , pf.december = NULL
      where ic.resource_id =#{itr} and ic.resource_type ='RealEstateProperty' and ic.year = 2011;")
      ApplicationController.helpers.store_variance_details(itr, 'RealEstateProperty')
    end
    puts "Actual records modified"
  end
  
  
end