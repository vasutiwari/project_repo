require Rails.root.to_s + '/config/boot'
require Rails.root.to_s + '/config/environment'
class DelayedPropertyDataImport
  attr_accessor :real_estate_property_id,:user_id,:table_name,:hmy_id,:leasing_type,:property_name,:property_code,:portfolio_id

  def initialize(real_estate_property_id,user_id,table_name,hmy_id,leasing_type,property_name,property_code,portfolio_id)
    self.real_estate_property_id= real_estate_property_id
    self.user_id= user_id
    self.table_name = table_name
    self.hmy_id = hmy_id
    self.leasing_type = leasing_type
    self.property_name = property_name
    self.property_code = property_code
    self.portfolio_id = portfolio_id
  end

  def delayed_logger message
    Rails.env=="production" ? (Delayed::Worker.logger.info message) : (puts message)
  end

  def perform
    delayed_logger "\nDJ InProgress for Import financial Data"
    map_hash = {}
    year = 2011 # Year Fixed as 2011
    real_estate_property_id = self.real_estate_property_id # real estate property id
    user_id = self.user_id # User id
    real_estate_property = RealEstateProperty.find_real_estate_property(self.real_estate_property_id)
    user = real_estate_property.try(:user)
    current_client_id = user.try(:client_id)
    property_table_name =  self.table_name + "_Property"
    total_table_name =  self.table_name + "_Total"
    account_table_name =  self.table_name + "_Acct"
    comm_amendments_table_name = self.table_name + "_commAmendments"
    tenant_table_name = self.table_name + "_tenant"
    tenant_aging_table_name = self.table_name + "_tenantaging"
    unit_table_name = self.table_name + "_unit"
    unit_type_table_name = self.table_name + "_UnitType"
    gldetail_table_name =  self.table_name + "_GLDetail"
    person_table_name = self.table_name + "_person"
    leasing_type = self.leasing_type
    hmy = self.hmy_id
    property_name  =  self.property_name
    property_code = self.property_code
    portfolio_id = self.portfolio_id

    t_years =[]
    years  = IncomeAndCashFlowDetail.find_by_sql("select UMONTH as u_month from #{total_table_name} t where t.HPPTY = #{hmy} group by UMONTH")
    t_years = years.collect{|t_year_month|  t_year_month.u_month.split('-')[0]}


    #.................................................................................................Import financial data into master table starts here.......................................................................................................
    t_years.compact.uniq.each do |year|
      (1..12).each do |month|
        delayed_logger "Preparing to insert the #{year} - #{Date::MONTHNAMES[month]}  details..."
        child_items = IncomeAndCashFlowDetail.find_by_sql("select a.HMY as id, a.HTOTALINTO as parent_id, a.SCODE as code, a.SDESC as title, YEAR(t.UMONTH) as year, MONTH(t.UMONTH) as month, t.SMTD as actual, t.SBUDGET as budget,t.SBEGIN 	as beginning_balance,a.INORMALBALANCE as balance from #{total_table_name} t left join #{account_table_name} a on a.HMY = t.HACCT where t.IBOOK = 1 and  t.HPPTY = #{hmy} and YEAR(t.UMONTH) = #{year} and MONTH(t.UMONTH) = #{month} and a.HCHART = 0 and a.IRPTTYPE=0;")
        next if child_items.blank?
        hie_childs = Array.new; hie_childs_values = Array.new; go_higher = true
        # [hie_childs_values] is an array is going to have all the values are available to store.
        # normally end childs only have budget and actual values.
        # according to the end item values we have to calculate the parent act , bud values.
        # ----
        # [hie_childs] is going to have the parent id's unique collection
        hie_childs_values << child_items #end items values assignment
        hie_childs << child_items.map(&:parent_id).uniq # end items parent id's collection added
        # ----
        # In above the end level items added then we have to find out all values and parent id's collection for the prior levels.
        while go_higher do
          # Push the parent level items
          # obviously parent items doesn't have the actual and budget values
          # we have to calculate the their actual and budget through the sub items.
          # ----
          hie_childs_values << IncomeAndCashFlowDetail.find_by_sql("select a.HMY as id, a.SCODE as code, a.INORMALBALANCE as balance, a.HTOTALINTO as parent_id, a.SDESC as title from #{account_table_name} a where HMY in (#{hie_childs.last.join(',')})")
          hie_childs << hie_childs_values.last.map(&:parent_id).uniq
          go_higher = false if hie_childs.last.all?{|itr| itr == 0}
        end
        #
        map_end_items = []
        # Create our own parent for storing and childs level by level.
        # Basically it is 'Griffin'
        income_detail = IncomeAndCashFlowDetail.procedure_call(:titleIn=>"#{self.table_name}", :realIn=>real_estate_property_id  , :realTypeIn=>"RealEstateProperty",:parentIn=> 'NULL', :userIn=>user_id, :yearIn=>year)
        # [map_hash] is used store our AMP system parent id's for corresponding [hie_childs_values] parent id's
        # EX. [hie_childs_values] parent id is 1 will be mapped our system id like map_hash.update({1=> income_detail['id']})
        # That will be used mapping later.
        # ----
        map_hash.update({0=> income_detail['id']})
        # Store end level items first then every upper level items later.
        hie_childs_values.reverse.each_with_index do |itr_arr, ind|
          itr_arr.each do |itr_item|

            income_detail = IncomeAndCashFlowDetail.procedure_call_scode(:titleIn=>itr_item.title.gsub(/^TOTAL /, ''), :realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=>map_hash[itr_item.parent_id], :userIn=>user_id, :yearIn=>year,:sCode=>itr_item.code,:iNormalBalance=>itr_item.balance)
            #p "#{map_hash[itr_item.parent_id]} --#{itr_item.parent_id}" if map_hash.include? itr_item.parent_id
            map_hash.update({itr_item.id=> income_detail['id']})
            # collect end child items.
            map_end_items << income_detail['id'] if ind == hie_childs_values.size - 1
          end
        end
        pf_coll = []
        # This is for strong the extreme end items actual, budget values
        # After that, we have to calculate the upper level items values.
        # ----
        child_items.each_with_index do |line_item, ind|
          pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>map_end_items[ind], :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'c')
          pf_coll << "(#{pf['pfid']}, #{line_item.balance == '1' ? (line_item.actual.to_f * -1) : line_item.actual})"
          pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>map_end_items[ind], :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'b')
          pf_coll << "(#{pf['pfid']},#{line_item.budget})"
          pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>map_end_items[ind], :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'p')
          pf_coll << "(#{pf['pfid']},#{line_item.balance == '1' ? (line_item.beginning_balance.to_f * -1) : line_item.beginning_balance})"
        end
        str = "insert into property_financial_periods(id, #{Date::MONTHNAMES[month].downcase}) values #{pf_coll*','} ON DUPLICATE KEY UPDATE #{Date::MONTHNAMES[month].downcase}=values(#{Date::MONTHNAMES[month].downcase})"
        ActiveRecord::Base.connection.execute str
        # Calculate the parent values from the end level items.
        # Run the query and store the values.
        begin
          parent_items = IncomeAndCashFlowDetail.find_by_sql("select ic.parent_id, sum(pf1.#{Date::MONTHNAMES[month].downcase}) actual, sum(pf2.#{Date::MONTHNAMES[month].downcase}) budget ,sum(pf3.#{Date::MONTHNAMES[month].downcase}) as beginning_balance from income_and_cash_flow_details ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf1.pcb_type = 'c' left join property_financial_periods pf2 on pf2.source_id = ic.id and pf2.source_type = 'IncomeAndCashFlowDetail' and pf2.pcb_type = 'b' left join property_financial_periods pf3 on pf3.source_id = ic.id and pf3.source_type = 'IncomeAndCashFlowDetail' and pf3.pcb_type = 'p' where ic.id in (#{map_end_items*','}) group by ic.parent_id ;")

          map_end_items = []; pf_coll = [] # MAKE empty for collecting the parent item's property financial periods.
          parent_items.each do |line_item|

            next if line_item.parent_id.blank?
            #break if line_item.parent_id.blank? and parent_items.count == 1
            pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>line_item.parent_id, :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'c')
            pf_coll << "(#{pf['pfid']}, #{line_item.actual.blank? ? 0 : line_item.actual})"
            pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>line_item.parent_id, :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'b')
            pf_coll << "(#{pf['pfid']}, #{line_item.budget.blank? ? 0 : line_item.budget})"
            pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>line_item.parent_id, :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'p')
            pf_coll << "(#{pf['pfid']}, #{line_item.beginning_balance.blank? ? 0 : line_item.beginning_balance})"
            map_end_items << line_item.parent_id
          end
          unless pf_coll.empty?
            str = "insert into property_financial_periods(id, #{Date::MONTHNAMES[month].downcase}) values #{pf_coll*','} ON DUPLICATE KEY UPDATE #{Date::MONTHNAMES[month].downcase}=values(#{Date::MONTHNAMES[month].downcase})"
            ActiveRecord::Base.connection.execute str
          end
        end while !map_end_items.empty?
      end


      # For NOI use actual income - actual budget.
      # do the above through the query.
      # ----
      act_nt_income = []
      bud_nt_income = []
      net_income = IncomeAndCashFlowDetail.find_by_sql("select id,parent_id from income_and_cash_flow_details ic where ic.resource_id = #{real_estate_property_id} and ic.title='NET OPERATING INCOME' and ic.year =#{year}").first

      unless net_income.nil?
      net_budget = PropertyFinancialPeriod.find_by_sql("select id from property_financial_periods where source_id = #{net_income.id} and source_type = 'IncomeAndCashFlowDetail' and pcb_type='b'").first
      net_actual = PropertyFinancialPeriod.find_by_sql("select id from property_financial_periods where source_id = #{net_income.id} and source_type = 'IncomeAndCashFlowDetail' and pcb_type='c'").first
      exp_actual = PropertyFinancialPeriod.find_by_sql("select * from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type='IncomeAndCashFlowDetail' and pf.pcb_type='c' where ic.resource_id = #{real_estate_property_id} and ic.parent_id = #{net_income.id} and ic.title='OPERATING EXPENSES' and ic.year =#{year};").first
      exp_budget = PropertyFinancialPeriod.find_by_sql("select * from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type='IncomeAndCashFlowDetail' and pf.pcb_type='b' where ic.resource_id = #{real_estate_property_id} and ic.parent_id = #{net_income.id} and ic.title='OPERATING EXPENSES' and ic.year =#{year};").first
      inc_actual = PropertyFinancialPeriod.find_by_sql("select * from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type='IncomeAndCashFlowDetail' and pf.pcb_type='c' where ic.resource_id = #{real_estate_property_id} and ic.parent_id = #{net_income.id} and ic.title='INCOME' and ic.year =#{year};").first
      inc_budget = PropertyFinancialPeriod.find_by_sql("select * from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type='IncomeAndCashFlowDetail' and pf.pcb_type='b' where ic.resource_id = #{real_estate_property_id} and ic.parent_id = #{net_income.id} and ic.title='INCOME' and ic.year =#{year};").first
      Date::MONTHNAMES[1,12].collect(&:downcase).each do |month_name|
        act_nt_income << ((inc_actual.nil? || inc_actual.send(:"#{month_name}").blank?) ? 0 : inc_actual.send(:"#{month_name}")) - ((exp_actual.nil? || exp_actual.send(:"#{month_name}").blank?) ? 0 : exp_actual.send(:"#{month_name}"))
        bud_nt_income << ((inc_budget.nil? || inc_budget.send(:"#{month_name}").blank?) ? 0 : inc_budget.send(:"#{month_name}")) - ((exp_budget.nil? || exp_budget.send(:"#{month_name}").blank?) ? 0 : exp_budget.send(:"#{month_name}"))
      end

      #Added to copy NOI values in NET INCOME
      net_income_before_dep_and_amort =  IncomeAndCashFlowDetail.find_by_id(net_income.parent_id)
      dep_and_amort_budget = PropertyFinancialPeriod.find_by_sql("select id from property_financial_periods where source_id = #{net_income_before_dep_and_amort.id} and source_type = 'IncomeAndCashFlowDetail' and pcb_type='b'").first
      dep_and_amort_actual = PropertyFinancialPeriod.find_by_sql("select id from property_financial_periods where source_id = #{net_income_before_dep_and_amort.id} and source_type = 'IncomeAndCashFlowDetail' and pcb_type='c'").first


      ActiveRecord::Base.connection.execute("insert into property_financial_periods(id,january,february,march,april,may,june,july,august,september,october,november,december) values(#{net_actual.id},#{act_nt_income*','}) ON DUPLICATE KEY UPDATE january=VALUES(january),february=VALUES(february),march=VALUES(march),april=VALUES(april),may=VALUES(may),june=VALUES(june),july=VALUES(july),august=VALUES(august),september=VALUES(september),october=VALUES(october),november=VALUES(november),december=VALUES(december)")
      ActiveRecord::Base.connection.execute("insert into property_financial_periods(id,january,february,march,april,may,june,july,august,september,october,november,december) values(#{net_budget.id},#{bud_nt_income*','}) ON DUPLICATE KEY UPDATE january=VALUES(january),february=VALUES(february),march=VALUES(march),april=VALUES(april),may=VALUES(may),june=VALUES(june),july=VALUES(july),august=VALUES(august),september=VALUES(september),october=VALUES(october),november=VALUES(november),december=VALUES(december)")


      #Added to copy NOI values in NET INCOME
      ActiveRecord::Base.connection.execute("insert into property_financial_periods(id,january,february,march,april,may,june,july,august,september,october,november,december) values(#{dep_and_amort_actual.id},#{act_nt_income*','}) ON DUPLICATE KEY UPDATE january=VALUES(january),february=VALUES(february),march=VALUES(march),april=VALUES(april),may=VALUES(may),june=VALUES(june),july=VALUES(july),august=VALUES(august),september=VALUES(september),october=VALUES(october),november=VALUES(november),december=VALUES(december)")

      ActiveRecord::Base.connection.execute("insert into property_financial_periods(id,january,february,march,april,may,june,july,august,september,october,november,december) values(#{dep_and_amort_budget.id},#{bud_nt_income*','}) ON DUPLICATE KEY UPDATE january=VALUES(january),february=VALUES(february),march=VALUES(march),april=VALUES(april),may=VALUES(may),june=VALUES(june),july=VALUES(july),august=VALUES(august),september=VALUES(september),october=VALUES(october),november=VALUES(november),december=VALUES(december)")


      delayed_logger "Calculating the variances..."
      ApplicationController.new.store_variance_details(real_estate_property_id, "RealEstateProperty") unless map_hash.empty?
      delayed_logger "Process done..."

     end
      delayed_logger "DJ completed  for Import financial Data\n"
    end

    #.................................................................................................Import financial data into master table ends here.......................................................................................................



    #~ #.................................................................................................Import cash flow data into master table starts here.......................................................................................................

    delayed_logger "Working for the cash flow operating summary(for balance sheet)"
    t_years.compact.uniq.each do |year|
      (1..12).each do |month|
        delayed_logger "Preparing to insert the #{year} - #{Date::MONTHNAMES[month]}  details..."
        child_items = IncomeAndCashFlowDetail.find_by_sql("select a.HMY as id, a.HTOTALINTO as parent_id, a.SCODE as code, a.SDESC as title, YEAR(t.UMONTH) as year, MONTH(t.UMONTH) as month, t.SMTD as actual,t.SBEGIN 	as beginning_balance,t.SBUDGET as budget,a.INORMALBALANCE as balance from #{total_table_name} t left join #{account_table_name} a on a.HMY = t.HACCT where t.IBOOK = 1 and  t.HPPTY = #{hmy} and YEAR(t.UMONTH) = #{year} and MONTH(t.UMONTH) = #{month} and a.HCHART = 0 and a.IRPTTYPE=1;")
        next if child_items.blank?
        hie_childs = Array.new; hie_childs_values = Array.new; go_higher = true
        hie_childs_values << child_items
        hie_childs << child_items.map(&:parent_id).uniq
        while go_higher do
          hie_childs_values << IncomeAndCashFlowDetail.find_by_sql("select a.HMY as id, a.HTOTALINTO as parent_id, a.SCODE as code,a.INORMALBALANCE as balance, a.SDESC as title from #{account_table_name} a where HMY in (#{hie_childs.last.join(',')})")
          hie_childs << hie_childs_values.last.map(&:parent_id).uniq
          go_higher = false if hie_childs.last.all?{|itr| itr == 0}
        end
        map_end_items = []
        income_detail = IncomeAndCashFlowDetail.procedure_call(:titleIn=>'balance sheet', :realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=> 'NULL', :userIn=>user_id, :yearIn=>year)
        map_hash.update({0=> income_detail['id']})
        hie_childs_values.reverse.each_with_index do |itr_arr, ind|
          itr_arr.each do |itr_item|
            income_detail = IncomeAndCashFlowDetail.procedure_call_scode(:titleIn=>itr_item.title.gsub(/^TOTAL /, ''), :realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=>map_hash[itr_item.parent_id], :userIn=>user_id, :yearIn=>year,:sCode=>itr_item.code,:iNormalBalance=>itr_item.balance)
            #p "#{map_hash[itr_item.parent_id]} --#{itr_item.parent_id}" if map_hash.include? itr_item.parent_id
            map_hash.update({itr_item.id=> income_detail['id']})
            map_end_items << income_detail['id'] if ind == hie_childs_values.size - 1
          end
        end
        pf_coll = []
        child_items.each_with_index do |line_item, ind|
          pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>map_end_items[ind], :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'c')
          pf_coll << "(#{pf['pfid']}, #{line_item.balance == '1' ? (line_item.actual.to_f * -1) : line_item.actual})"
          pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>map_end_items[ind], :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'b')
          pf_coll << "(#{pf['pfid']},#{line_item.budget})"
          pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>map_end_items[ind], :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'p')
          pf_coll << "(#{pf['pfid']},#{line_item.balance == '1' ? (line_item.beginning_balance.to_f * -1) : line_item.beginning_balance})"
        end

        str = "insert into property_financial_periods(id, #{Date::MONTHNAMES[month].downcase}) values #{pf_coll*','} ON DUPLICATE KEY UPDATE #{Date::MONTHNAMES[month].downcase}=values(#{Date::MONTHNAMES[month].downcase})"
        ActiveRecord::Base.connection.execute str
        begin
          parent_items = IncomeAndCashFlowDetail.find_by_sql("select ic.parent_id, sum(pf1.#{Date::MONTHNAMES[month].downcase}) actual, sum(pf2.#{Date::MONTHNAMES[month].downcase}) budget ,sum(pf3.#{Date::MONTHNAMES[month].downcase}) as beginning_balance
            from income_and_cash_flow_details ic left join property_financial_periods pf1 on pf1.source_id = ic.id and pf1.source_type = 'IncomeAndCashFlowDetail' and pf1.pcb_type = 'c' left join property_financial_periods pf2 on pf2.source_id = ic.id and pf2.source_type = 'IncomeAndCashFlowDetail' and pf2.pcb_type = 'b' left join property_financial_periods pf3 on pf3.source_id = ic.id and pf3.source_type = 'IncomeAndCashFlowDetail' and pf3.pcb_type = 'p'
            where ic.id in (#{map_end_items*','}) group by ic.parent_id ;")
          map_end_items = []; pf_coll = [] # MAKE empty for collecting the parent item's property financial periods.
          parent_items.each do |line_item|
            next if line_item.parent_id.blank?
            #break if line_item.parent_id.blank? and parent_items.count == 1
            pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>line_item.parent_id, :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'c')
            pf_coll << "(#{pf['pfid']}, #{line_item.actual.blank? ? 0 : line_item.actual})"
            pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>line_item.parent_id, :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'b')
            pf_coll << "(#{pf['pfid']}, #{line_item.budget.blank? ? 0 : line_item.budget})"
            pf = PropertyFinancialPeriod.procedure_call(:sourceIn=>line_item.parent_id, :sourceTypeIn=>'IncomeAndCashFlowDetail', :pcbIn=>'p')
            pf_coll << "(#{pf['pfid']}, #{line_item.beginning_balance.blank? ? 0 : line_item.beginning_balance})"
            map_end_items << line_item.parent_id
          end
          unless pf_coll.empty?
            str = "insert into property_financial_periods(id, #{Date::MONTHNAMES[month].downcase}) values #{pf_coll*','} ON DUPLICATE KEY UPDATE #{Date::MONTHNAMES[month].downcase}=values(#{Date::MONTHNAMES[month].downcase})"
            ActiveRecord::Base.connection.execute str
          end
        end while !map_end_items.empty?
      end
      act_nt_income = []
      bud_nt_income = []
      net_income = IncomeAndCashFlowDetail.find_by_sql("select id from income_and_cash_flow_details ic where ic.resource_id = #{real_estate_property_id} and ic.title='NET OPERATING INCOME' and ic.year =#{year}").first
      unless net_income.nil?
      net_budget = PropertyFinancialPeriod.find_by_sql("select id from property_financial_periods where source_id = #{net_income.id} and source_type = 'IncomeAndCashFlowDetail' and pcb_type='b'").first
      net_actual = PropertyFinancialPeriod.find_by_sql("select id from property_financial_periods where source_id = #{net_income.id} and source_type = 'IncomeAndCashFlowDetail' and pcb_type='c'").first
      exp_actual = PropertyFinancialPeriod.find_by_sql("select * from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type='IncomeAndCashFlowDetail' and pf.pcb_type='c' where ic.resource_id = #{real_estate_property_id} and ic.parent_id = #{net_income.id} and ic.title='OPERATING EXPENSES' and ic.year =#{year};").first
      exp_budget = PropertyFinancialPeriod.find_by_sql("select * from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type='IncomeAndCashFlowDetail' and pf.pcb_type='b' where ic.resource_id = #{real_estate_property_id} and ic.parent_id = #{net_income.id} and ic.title='OPERATING EXPENSES' and ic.year =#{year};").first
      inc_actual = PropertyFinancialPeriod.find_by_sql("select * from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type='IncomeAndCashFlowDetail' and pf.pcb_type='c' where ic.resource_id = #{real_estate_property_id} and ic.parent_id = #{net_income.id} and ic.title='INCOME' and ic.year =#{year};").first
      inc_budget = PropertyFinancialPeriod.find_by_sql("select * from income_and_cash_flow_details ic left join property_financial_periods pf on pf.source_id = ic.id and pf.source_type='IncomeAndCashFlowDetail' and pf.pcb_type='b' where ic.resource_id = #{real_estate_property_id} and ic.parent_id = #{net_income.id} and ic.title='INCOME' and ic.year =#{year};").first
      Date::MONTHNAMES[1,12].collect(&:downcase).each do |month_name|
        act_nt_income << ((inc_actual.nil? || inc_actual.send(:"#{month_name}").blank?) ? 0 : inc_actual.send(:"#{month_name}")) - ((exp_actual.nil? || exp_actual.send(:"#{month_name}").blank?) ? 0 : exp_actual.send(:"#{month_name}"))
        bud_nt_income << ((inc_budget.nil? || inc_budget.send(:"#{month_name}").blank?) ? 0 : inc_budget.send(:"#{month_name}")) - ((exp_budget.nil? || exp_budget.send(:"#{month_name}").blank?)  ? 0 : exp_budget.send(:"#{month_name}"))
      end
      ActiveRecord::Base.connection.execute("insert into property_financial_periods(id,january,february,march,april,may,june,july,august,september,october,november,december) values(#{net_actual.id},#{act_nt_income*','}) ON DUPLICATE KEY UPDATE january=VALUES(january),february=VALUES(february),march=VALUES(march),april=VALUES(april),may=VALUES(may),june=VALUES(june),july=VALUES(july),august=VALUES(august),september=VALUES(september),october=VALUES(october),november=VALUES(november),december=VALUES(december)")
      ActiveRecord::Base.connection.execute("insert into property_financial_periods(id,january,february,march,april,may,june,july,august,september,october,november,december) values(#{net_budget.id},#{bud_nt_income*','}) ON DUPLICATE KEY UPDATE january=VALUES(january),february=VALUES(february),march=VALUES(march),april=VALUES(april),may=VALUES(may),june=VALUES(june),july=VALUES(july),august=VALUES(august),september=VALUES(september),october=VALUES(october),november=VALUES(november),december=VALUES(december)")
      delayed_logger "Calculating the variances..."
      ApplicationController.new.store_variance_details(real_estate_property_id, "RealEstateProperty") unless map_hash.empty?
      end
      delayed_logger "Process done..."
    end

    #.................................................................................................Import cash flow data into master table starts here.......................................................................................................


    #......................... ...................................................Inserting data into property aged receivables data ......................................................................................................................................
    begin
      real_estate_property = RealEstateProperty.find_real_estate_property(self.real_estate_property_id)
      property_code = real_estate_property.try(:property_code)
      if property_code.present?
        delayed_logger "Inserting data into property aged receivables data"
        sql_query = "SELECT distinct(p.sCode) psCode, u.sCode usCode, sum(cPrepays) Prepays, CONCAT_WS(' ', IFNULL(t.sLastName, ''),IFNULL(t.sFirstName,'')) Tenant_Name,  sum(cAge30) age30, sum(cAge60) age60, sum(cAge90) age90, sum(cAgeOver90) age90Plus, month(ta.dtPeriod) month, year(ta.dtPeriod) year, coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),u.dSqft) as rentable_area, ut.SCODE as floor_plan FROM #{property_table_name} p  INNER JOIN #{unit_table_name} u ON (p.hmy = u.hproperty)  LEFT OUTER JOIN #{unit_type_table_name} ut on (u.hUnitType = ut.hMy)  INNER JOIN #{tenant_table_name} t on (t.hUnit = u.hMy)  INNER JOIN #{tenant_aging_table_name} ta on (t.hmyperson = ta.hTenant) LEFT JOIN #{account_table_name} a on ta.hARacct = a.hMy   WHERE p.sCode = #{property_code} and (abs(cAge30) + abs(cAge60) + abs(cAge90) + abs(cAgeOver90) + abs(cPrepays)) > 0 AND ifNull(u.exclude,0) = 0 GROUP BY  p.scode, p.sAddr1, u.sCode, t.scode, t.hMyPerson, t.sfirstname, t.slastname, ta.dtPeriod  ORDER BY  p.sCode, u.sCode"
        result = ActiveRecord::Base.connection.execute(sql_query)
        delayed_logger "Query had been executed successfully"
        rows = []
        result.each do |row|
          if row.present?
            row.delete_at(0)
            propert_suite = PropertySuite.procedure_call(:suiteIn=>row[0], :realIn=>self.real_estate_property_id, :areaIn=>row[9].blank? ? 'NULL' : row[9], :spaceTypeIn=>'',:scodeIn=>row[10], :currentClientId=>current_client_id)
            row[0] = propert_suite['psid']
            row[2] = "\"#{row[2].gsub("\"","")}\"" if row[2].present?
            row.pop(2)
            rows << "(#{row.join(',')})"
          end
        end
        if rows.present?
          rows = rows.join(',')
          insert_query = "insert into property_aged_receivables(property_suite_id, prepaid, tenant,paid_amount, over_30days, over_60days, over_90days, month, year) values #{rows}"
          ActiveRecord::Base.connection.execute(insert_query)
          delayed_logger "Data had been insertedd successfully into property_aged_receivables table"
        else
          delayed_logger "Data is not available for inserting into property_aged_receivables table"
        end
      end
    rescue => e
      delayed_logger "Exception had been raised with message: #{e.message}"
    end
    #....................................... End of inserting data into property aged receivables data  .............................................
  #.................................................................................................Import Lease and rent roll data into master table starts here.......................................................................................................
    delayed_logger "Importing lease details starts"
    lease_year_qry = PropertyLease.find_by_sql("select DTLEASEFROM as lease_from  from #{tenant_table_name} where DTLEASEFROM between '2010-01-01' and '#{Date.today.year}-12-31' group by DTLEASEFROM")
    lease_years = lease_year_qry.collect{|l_year_month|  l_year_month.lease_from.split('-')[0].to_i}
    if leasing_type == "Multifamily"
     lease_years.compact.uniq.each do |year|
        #To insert lease and rent roll data
        (1..12).each do |month|
          delayed_logger "Preparing to insert the #{year} - #{Date::MONTHNAMES[month]}  details..."
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
          #c_y_u_o_a = (c_y_u_t_a.current_year_units_total_actual.to_f * total.to_f)/100  rescue 0
          #~ current_year_units_occupied_actual = (c_y_u_t_a.current_year_units_total_actual.to_f *   ((c_y_s_o_a.current_year_sf_occupied_actual.to_f * 100) /(c_y_s_o_a.current_year_sf_occupied_actual.to_f + current_year_sf_vacant_actual.to_f)).to_f)/100  rescue 0
          #current_year_units_vacant_actual = c_y_u_t_a.current_year_units_total_actual.to_f - current_year_units_occupied_actual.to_f rescue 0
         c_y_u_o_a = c_y_u_t_a.current_year_units_total_actual.to_f - c_y_u_v_a.current_year_units_vacant_actual.to_f rescue 0
          occupancy_year = year
          occupancy_month = month
          PropertyOccupancySummary.procedure_call(:total_building_rentable_s=>t_b_r_s.total_building_rentable_s.to_f,:current_year_sf_occupied_actual=>c_y_s_o_a.current_year_sf_occupied_actual.to_f,:current_year_sf_vacant_actual=>current_year_sf_vacant_actual.to_f,:current_year_units_total_actual =>c_y_u_t_a.current_year_units_total_actual.to_f,:vacant_leased_number=>v_l_n.vacant_leased_number.to_f,:vacant_leased_percentage=>vacant_leased_percentage.to_f,:currently_vacant_leases_number=>currently_vacant_leases_number.to_f,:currently_vacant_leases_percentage=>currently_vacant_leases_percentage.to_f,:occupied_preleased_number=>o_p_n.occupied_preleased_number.to_f,:occupied_preleased_percentage=>occupied_preleased_percentage.to_f,:occupied_on_notice_number=>occupied_on_notice_number.to_f,:occupied_on_notice_percentage=>occupied_on_notice_percentage.to_f,:net_exposure_to_vacancy_number=>net_exposure_to_vacancy_number.to_f,:net_exposure_to_vacancy_percentage=>net_exposure_to_vacancy_percentage.to_f,:current_year_units_occupied_actual=>c_y_u_o_a.to_f,:current_year_units_vacant_actual=>c_y_u_v_a.current_year_units_vacant_actual.to_f,:real_estate_property_id=>real_estate_property_id,:m_year=>occupancy_year,:m_month=>occupancy_month)
          delayed_logger "inserting #{Date::MONTHNAMES[month]}-#{year} details of rent roll "
          lease_recs = PropertyLease.find_by_sql "SELECT CASE WHEN t.DTLEASEFROM BETWEEN '#{year}-01-01' AND '#{year}-#{month}-31' THEN 'new' WHEN t.dtLeaseTo BETWEEN '#{year}-01-01' AND '#{year}-#{month}-31' THEN 'expirations' ELSE 'current' END AS occupancy_type, IFNULL(concat(t.sFirstName,' ',t.sLastName), 'VACANT') as tenant_name, t.dtLeaseFrom AS 'Lease Start Date', coalesce( ( SELECT dContractArea FROM Griffin_commAmendments cAmend WHERE cAmend.hTenant = t.hMyPerson ORDER BY dtEnd DESC LIMIT 1 ), u.dSqft) AS rentable_area, t.sRent AS base_rent, t.dtLeaseTo AS lease_expiry, u.sCode AS suite_number, u.sStatus AS status, u_t.SCODE AS floor_plan FROM Griffin_unit u LEFT JOIN Griffin_tenant t ON t.hUnit = u.hMy AND ((t.DTLEASEFROM < '#{year}-#{month}-31' OR t.dtLeaseFrom IS NULL) AND (t.dtLeaseTo > '#{year}-#{month}-31' OR t.dtLeaseTo IS NULL)) AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) AND t.hProperty = u.hProperty LEFT JOIN Griffin_UnitType u_t ON u_t.hmy = u.HUNITTYPE WHERE u.HPROPERTY =#{hmy}"
          lease_recs.each do |line_item|
            lease_year = year
            lease_month =  month
            base_rent = leasing_type == 'Multifamily' ? nil : line_item.base_rent
            effRate  = leasing_type == 'Multifamily' ?  line_item.base_rent : nil
            suite = PropertySuite.procedure_call(:suiteIn=>line_item.suite_number, :realIn=>real_estate_property_id, :areaIn=>line_item.rentable_area.blank? ? 'NULL' : line_item.rentable_area, :spaceTypeIn=>'',:scodeIn=>line_item.floor_plan, :currentClientId=>current_client_id)
            PropertyLease.procedure_call(:propSuiteId=>suite['psid'], :nameIn=>line_item.tenant_name.strip, :startDate=> nil, :endDate=>"#{line_item.lease_expiry}", :baseRent=>base_rent, :effRate=>effRate, :tenantImp=>nil, :leasingComm=> nil , :monthIn=> lease_month, :yearIn=> lease_year, :otherDepIn=> nil, :commentsIn=>nil, :amtPerSQFT=>nil, :occType=>'current',:sStatus =>line_item.status )
          end
          break if month == Date.today.month && year == Date.today.year
        end
      end
    else
    lease_years.compact.uniq.each do |year|
  #To find last year property occupancy data
     last_yr_t_b_r_s = Lease.find_by_sql("SELECT sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),gu.dSqft)) as total_building_rentable_s,gu.dtLastModified as last_modified FROM #{unit_table_name} gu left join #{tenant_table_name} t  on t.sUnitCode=gu.sCode where gu.HPROPERTY = #{hmy} and t.DTLEASEFROM < '#{year-1}-12-31 00:00:00' and t.dtLeaseTo > '#{year-1}-12-01 00:00:00'")[0]
    last_yr_s_o_a = Lease.find_by_sql("select sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),gu2.dSqft)) as last_year_sf_occupied_actual from #{unit_table_name} gu2 left join #{tenant_table_name} t on t.sUnitCode=gu2.sCode where (gu2.sStatus = 'Occupied No Notice' or gu2.sStatus like 'Vacant Rented%') and gu2.HPROPERTY = #{hmy} and t.DTLEASEFROM < '#{year-1}-12-31 00:00:00' and t.dtLeaseTo > '#{year-1}-12-01 00:00:00'")[0]
  (1..12).each do |month|
     delayed_logger "Preparing to insert the #{year} - #{Date::MONTHNAMES[month]}  details..."
    #To insert  property occupancy data
     t_b_r_s = Lease.find_by_sql("SELECT  sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),gu.dSqft)) as total_building_rentable_s,gu.dtLastModified as last_modified FROM #{unit_table_name} gu left join #{tenant_table_name} t  on t.sUnitCode=gu.sCode and t.DTLEASEFROM < '#{year}-#{month}-31 00:00:00' and t.dtLeaseTo > '#{year}-#{month}-01 00:00:00' where gu.HPROPERTY = #{hmy} ")[0]
    next if  t_b_r_s.total_building_rentable_s  == nil  && t_b_r_s.last_modified == nil  || t_b_r_s.total_building_rentable_s  == "0"
   c_y_s_o_a = Lease.find_by_sql("select sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),gu2.dSqft)) as current_year_sf_occupied_actual from #{unit_table_name} gu2 left join #{tenant_table_name} t on t.sUnitCode=gu2.sCode and t.DTLEASEFROM < '#{year}-#{month}-31 00:00:00' and t.dtLeaseTo > '#{year}-#{month}-01 00:00:00' where (gu2.sStatus = 'Occupied No Notice' or gu2.sStatus like 'Vacant Rented%') and gu2.HPROPERTY = #{hmy} ")[0]
    current_year_sf_vacant_actual  = t_b_r_s.total_building_rentable_s.to_f - c_y_s_o_a.current_year_sf_occupied_actual.to_f
    #To find new leases and lease expiry
    new_leases = Lease.find_by_sql("select sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),u.dSqft)) as new_lease from #{unit_table_name} u left join #{tenant_table_name} t on t.sUnitCode=u.sCode and t.hProperty=u.hProperty and u.hProperty = #{hmy} and (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) where t.DTLEASEFROM between '#{year}-01-01' and '#{year}-#{month}-31'")
    lease_expiry= Lease.find_by_sql("select sum(coalesce((select dContractArea from #{comm_amendments_table_name} cAmend where cAmend.hTenant=t.hMyPerson order by dtEnd desc limit 1),u.dSqft)) as lease_expiry from #{unit_table_name} u left join #{tenant_table_name} t on t.sUnitCode=u.sCode and t.hProperty=u.hProperty and u.hProperty = #{hmy} and  (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) where t.dtLeaseTo between '#{year}-01-01' and '#{year}-#{month}-31'")
    #Insert into property occupancy summary
    CommercialLeaseOccupancy.procedure_call_for_commercial_occupancy(:current_yr_sf_occupiedIn=>c_y_s_o_a.current_year_sf_occupied_actual,:current_year_sf_vacantIn=>current_year_sf_vacant_actual,:yearIn=>year,:monthIn=>month,:new_leasesIn=>new_leases[0].new_lease,:lease_expiryIn=>lease_expiry[0].lease_expiry,:real_estate_property_id=>real_estate_property_id,:last_year_sf_occupied_actualIn=>last_yr_s_o_a.last_year_sf_occupied_actual)
    #Insert into property leases and property suites
    lease_recs = Lease.find_by_sql("SELECT case WHEN t.DTLEASEFROM BETWEEN '#{year}-01-01' and '#{year}-#{month}-31' THEN 'new' WHEN t.dtLeaseTo BETWEEN '#{year}-01-01' AND '#{year}-#{month}-31' THEN 'expirations' else 'current' END AS occupancy_type, IFNULL(concat(t.sFirstName,' ',t.sLastName), 'VACANT') as tenant_name, t.dtLeaseFrom AS lease_start, t.bMTM as lease_mtm, coalesce( (SELECT dContractArea FROM Griffin_commAmendments cAmend WHERE cAmend.hTenant = t.hMyPerson ORDER BY dtEnd DESC LIMIT 1), u.dSqft ) AS rentable_area, t.sRent AS base_rent, t.dtLeaseTo AS lease_expiry, u.sCode AS suite_number, u.sStatus AS status FROM Griffin_unit u LEFT JOIN Griffin_tenant t ON t.hUnit = u.hMy AND ((t.DTLEASEFROM < '#{year}-#{month}-31' OR t.dtLeaseFrom IS NULL) or (t.dtLeaseTo > '#{year}-#{month}-31' OR t.dtLeaseTo IS NULL)) AND (t.istatus IN (0,2,4,6,8) OR t.istatus IS NULL) AND t.hProperty = u.hProperty LEFT JOIN Griffin_UnitType u_t ON u_t.hmy = u.HUNITTYPE WHERE u.HPROPERTY =#{hmy}")
    lease_recs.each do |line_item|
      lease_mtm = line_item.lease_mtm
      if lease_mtm.present? && lease_mtm.eql?(-1)
        mtm=1
      else
        mtm=0
      end

lease_year = year
      lease_month =  month
      base_rent = leasing_type == 'Multifamily' ? nil : line_item.base_rent
      effRate  = leasing_type == 'Multifamily' ?  line_item.base_rent : nil
      #modified based on the LeaseDB structure
      if (!line_item.lease_expiry.nil? && line_item.lease_expiry != "0000-00-00 00:00:00") # to check there is expiration date
          if (!line_item.lease_start.nil? || line_item.lease_start == "0000-00-00 00:00:00" && line_item.lease_start.to_date <= Date.today && !line_item.lease_expiry.nil?  && line_item.lease_expiry != "0000-00-00 00:00:00" && line_item.lease_expiry.to_date >= Date.today) #to check whether the suite is vacant
        suites = Suite.find_or_create_by_suite_no_and_real_estate_property_id(:suite_no=>line_item.suite_number, :real_estate_property_id=>real_estate_property_id, :rentable_sqft=>line_item.rentable_area.blank? ? 'NULL' : line_item.rentable_area, :space_type=>'',:user_id=>user_id)
          suite_obj = Suite.find_by_id(suites.id)
          suite_obj.update_attributes(:status=>'Occupied')
          tenant = Tenant.procedure_tenant(:nameIn=>line_item.tenant_name.strip)
          lease = Lease.procedure_lease(:startDate=>"#{line_item.lease_start}", :endDate=>"#{line_item.lease_expiry}",:occType=>line_item.occupancy_type, :sStatus => line_item.status ,:realIn=>real_estate_property_id,:isExecuted=>1,:userId=>user_id,:effRate=>effRate, :mtm => mtm)
          PropertyLeaseSuite.find_or_create_by_lease_id_and_tenant_id(:suite_ids=>[suites.id.to_i],:lease_id=>lease['leaseid'],:tenant_id=>tenant['tid'])
          rent  = Rent.find_or_create_by_lease_id(:lease_id=>lease['leaseid'])
          RentSchedule.find_or_create_by_suite_id(:suite_id=>suites.id, :amount_per_month=>base_rent,:rent_id=>rent.id)
        end
          else
          #A vacant suite will have a record only in suites alone mentioning the status 'vacant'
         suites =Suite.find_or_create_by_suite_no_and_real_estate_property_id(:suite_no=>line_item.suite_number, :real_estate_property_id=>real_estate_property_id, :rentable_sqft=>(line_item.rentable_area.blank? || line_item.rentable_area == '0') ? 'NULL' : line_item.rentable_area, :space_type=>'',:user_id=>user_id)
         suites.status = 'Vacant'
         suites.save
      end
    end
  end
end
end

   #.................................................................................................Import Lease and rent roll data into master table ends here.......................................................................................................
     #.................................................................................................Import transactions data into master table starts here.......................................................................................................
    delayed_logger "Importing the transation details from the properties"
    prop_code = RealEstateProperty.find_by_sql("select property_code from real_estate_properties where id = #{real_estate_property_id}")
    prop = RealEstateProperty.find_by_sql("select HMY from #{property_table_name} where scode=#{prop_code[0].property_code}")[0]
    gl_details = RealEstateProperty.find_by_sql("select g.HPROP as property_id,CASE WHEN g.DAMOUNT > 0 THEN ABS(g.DAMOUNT) ELSE 0 END AS DEBIT,CASE WHEN g.DAMOUNT < 0 THEN ABS(g.DAMOUNT) ELSE 0 END AS CREDIT,g.DAMOUNT as da_amount,g.SNOTES as s_notes,g.DTPost	 as dt_post,g.DTDATE as dt_date,g.HPERSON as hperson, a.SCODE as acc_code, g.hMy as hMy from #{gldetail_table_name} g left join #{account_table_name} a on g.HACCT = a.HMY where g.HPROP = #{hmy}")
    gl_details.each do |gl_detail|
      l_year = gl_detail.dt_date.split('-')[0].to_i
      l_month = gl_detail.dt_date.split('-')[1].to_i
      discription = RealEstateProperty.find_by_sql("select ULASTNAME as lastname from #{person_table_name} where hmy = '#{gl_detail.hperson}'")
      discription = !discription.empty? ? discription[0].lastname : ""
      discription = discription.gsub("\'","").gsub('\"',"")
      notes = gl_detail.s_notes.gsub("\'","").gsub('\"',"")
      IncomeAndCashFlowDetail.procedure_call_transacrions(:post_dateIn=>"#{gl_detail.dt_post}",:discriptionIn=>"#{discription}",:notesIn=>"#{notes}",:debitIn=>gl_detail.DEBIT,:creditIn=>gl_detail.CREDIT,:yearIn=>l_year,:monthIn=>l_month,:real_estate_property_id=>real_estate_property_id,:da_amountIn =>gl_detail.da_amount,:acc_codeIn => gl_detail.acc_code, :hMyIn => gl_detail.hMy)
    end
    #.................................................................................................Import transactions data into master table ends here.......................................................................................................
    user_data = User.find_by_id(user_id)
    UserMailer.delay.property_details_imported_notification(user_data,property_name,property_code,portfolio_id,real_estate_property_id)
  end

  def failure
    delayed_logger "\nDJ Failed for Import Data\n"
  end
end
