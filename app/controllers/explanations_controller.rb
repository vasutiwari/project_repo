class ExplanationsController < ApplicationController
  before_filter :user_required
  before_filter :customize_path,:only=>['save_explanation','save_financial_explanation','save_cash_receivable_explanation','save_lease_explanation','save_rent_roll_explanation','save_sub_lease_explanation','save_aged_receivable_explanation']
  before_filter :change_session_value, :only=>[:new_threshold]
  #~ before_filter :check_property_access, :only=> [:new_threshold]
  def new_threshold
    @prop = @property = RealEstateProperty.find_real_estate_property(params[:property_id])
    @portfolio = @property.portfolio if @property
    suites_build_and_collection(@property)  if params[:form_txt] == "suites" || params[:suites_form_submit] == "true"
    @folder = find_property_folder_by_property_id(@property.id) if @property
    if params[:variance_percentage] && params[:variance_amount] && params[:variance_percentage_ytd] && params[:variance_amount_ytd]
      threshold = VarianceThreshold.find_or_initialize_by_real_estate_property_id(@prop.id)
      threshold.update_attributes(:variance_percentage => (params[:variance_percentage].empty? ? 0 : params[:variance_percentage]),:variance_amount => (params[:variance_amount].empty? ? 0 : params[:variance_amount]),:and_or => (!params[:variance_and_or] ? 'and' : params[:variance_and_or]),:cap_exp_variance => (params[:cap_exp_variance].empty? ? 0 : params[:cap_exp_variance]),:variance_percentage_ytd => (params[:variance_percentage_ytd].empty? ? 0 : params[:variance_percentage_ytd]),:variance_amount_ytd => (params[:variance_amount_ytd].empty? ? 0 : params[:variance_amount_ytd]),:and_or_ytd => (!params[:variance_and_or_ytd] ? 'and' : params[:variance_and_or_ytd]),:cap_exp_variance_ytd => (params[:cap_exp_variance_ytd].empty? ? 0 : params[:cap_exp_variance_ytd]),:user_id => current_user.id)
      f = Folder.find_by_real_estate_property_id(@prop.id)
      shared_mngrs = find_folder_member(f)
      update_pages
      if !shared_mngrs.empty?
      shared_mngrs.each do |s|
        if !s.has_role?("Leasing Agent")
          UserMailer.modify_variance_threshold(s,threshold,f.real_estate_property_id).deliver
        end
      end
      end
      #~ render :update do |page|
      #~ page << "eval(back_threshold);" if params[:try_reload]
      #~ page << "eval(threshold_reload);" if params[:place_reload]
      #~ page.hide 'modal_container'
      #~ page.hide 'modal_overlay'
      #~ page.call "flash_writter", FLASH_MESSAGES['explanation']['901']
      #~ end
    end
  end

  def save_explanations_now
    exp_id_to_delete=""
    # To find the month
    calc_for_financial_data_display

    if params[:type] == 'cap_exp' #Save variance tab cap exp explanations
      if params[:expid].present?
       expln = CapitalExpenditureExplanation.find_by_id_and_property_capital_improvement_id_and_month_and_ytd(params[:expid],params[:id],params[:month],params[:is_ytd_explanation]) if params[:expid]
       expln.update_attributes(:explanation=>params[:expln],:user_id=>current_user.id,:ytd=>params[:is_ytd_explanation])
      else
      expln = CapitalExpenditureExplanation.new
      expln.property_capital_improvement_id = params[:id]
      if params[:period] == "4"
        params[:month] = @financial_month
      elsif params[:period]  == "8" || params[:period] == "3"
        params[:month] = 12
      end
        expln.month = params[:month]
        item = PropertyCapitalImprovement.find_by_id(params[:id]).tenant_name.strip
      end
    elsif params[:type] == 'leases'
      expln = LeasesExplanation.find(:first, :conditions=>['id = ? and month = ?', params[:id], params[:month]])
      expln = LeasesExplanation.new if expln.nil?
      expln.id = params[:id]
    else
      expln = IncomeCashFlowExplanation.find(:first, :conditions=>['income_and_cash_flow_detail_id=? and month = ? and ytd =?', params[:id], params[:month], params[:is_ytd_explanation]])
      exp_id_to_delete = nil if expln.nil?
      expln = IncomeCashFlowExplanation.new if expln.nil?
      expln.income_and_cash_flow_detail_id = params[:id]
      item = IncomeAndCashFlowDetail.find_by_id(params[:id]).title.strip
    end
    expln.document_id = params[:document] if params[:type] != 'leases'
    expln.explanation = params[:expln].strip unless params[:dummy_rec]
    if !params[:dummy_rec] && params[:type] != 'leases'
      self.collection_exp_comments[current_user.id] = {} if self.collection_exp_comments[current_user.id].nil?
      expln.explanation = params[:expln].strip
      if (self.collection_exp_comments[current_user.id].empty? or !self.collection_exp_comments[current_user.id].has_key?(item))
        self.collection_exp_comments[current_user.id].update({item=>{'explanation'=>params[:expln].strip}})
      else
        self.collection_exp_comments[current_user.id][item]['explanation'] = params[:expln].strip
      end
    end
    expln.month = params[:month]
    chk_new =  expln.new_record? ? true : false
    expln.user_id = current_user.id
    expln.ytd = params[:is_ytd_explanation] if params[:type] != 'leases'
    expln.save


    #~ save_variance_tab_cap_exp_explanations(params,@financial_month)
		if params[:type] == 'cap_exp'
			expln = CapitalExpenditureExplanation.find(:first, :conditions=>['property_capital_improvement_id = ? and month = ? and ytd =?', params[:id], params[:month], params[:is_ytd_explanation]])
			exp_id_to_delete = expln.id if exp_id_to_delete.blank? rescue nil
			else
			exp_id_to_delete = expln.id if exp_id_to_delete.nil? rescue nil
		end
    render :update do |page|
      page.call("set_comment_and_exp_id",exp_id_to_delete,"all_saved_explanation_ids") unless exp_id_to_delete.blank?
        tmp_place = params[:is_ytd_explanation] == '1' ? ["#usr_ytd_#{params[:id]}", "#upt_ytd_#{params[:id]}", "#det_ytd_#{params[:id]}", "create_comment_ytd_#{params[:id].strip}", "explanation_comment_ytd_#{expln.id}","#add_more_#{params[:id]}","#totalVariance_#{params[:id]}"] : ["#usr_#{params[:id]}", "#upt_#{params[:id]}", "#det_#{params[:id]}", "create_comment_#{params[:id].strip}", "explanation_comment_#{expln.id}","#add_more_#{params[:id]}","#totalVariance_#{params[:id]}"]
      page << "jQuery('#{tmp_place[0]}').html('#{current_user.user_name}');"
      page << "jQuery('#{tmp_place[1]}').html('#{ 'on ' + expln.updated_at.strftime("%b %d,%Y")}');"
      page << "jQuery('#{tmp_place[2]}').css('visibility','visible');"
      page << "jQuery('#{tmp_place[5]}').css('visibility','visible');"
      page << "jQuery('#{tmp_place[6]}').css('visibility','visible');"
      page.call "flash_writter", FLASH_MESSAGES['explanation']['902']
     if params[:type] == 'cap_exp'
        explanations = CapitalExpenditureExplanation.find(:all, :conditions=>['property_capital_improvement_id = ? and month = ? and ytd =?', params[:id], params[:month], params[:is_ytd_explanation]])
      elsif params[:type] == 'cash_flow'
         explanations = IncomeCashFlowExplanation.find(:all, :conditions=>['income_and_cash_flow_detail_id = ? and month = ? and ytd =?', params[:id], params[:month], params[:is_ytd_explanation]])
      end
      if explanations.length == 1
        @exp_item = params[:type] == 'cap_exp' ? CapitalExpenditureExplanation.find(:first, :conditions=>['property_capital_improvement_id = ? and month = ? and ytd =?', params[:id], params[:month], params[:is_ytd_explanation]]) : expln
        @exp_type = 'explanation'
        @exp_cmt_for = params[:type]   
         page.replace_html "#{tmp_place[3]}", :partial => '/explanations/comment_explanation_view' if !params[:performance_review_path].include?('dashboard') && !params[:performance_review_path].include?('real_estate') && !params[:performance_review_path].include?('welcome') && !params[:performance_review_path].include?('financial') 
        page << "jQuery('##{tmp_place[3]}').attr('id','#{tmp_place[4]}')" if !params[:performance_review_path].include?('dashboard') && !params[:performance_review_path].include?('real_estate') && !params[:performance_review_path].include?('welcome') && !params[:performance_review_path].include?('financial') 
      end
      if params[:type] == 'cap_exp'
        params[:performance_review_path] = params[:performance_review_path].gsub("and","&")
        page.call "flash_writter", FLASH_MESSAGES['explanation']['902']
        page.call "replace_performance_review", "#{params[:performance_review_path]}","true"
      end
    end
  end

  # action for deleting the explanations and comments when clicking the cancel
  def delete_exps_and_comments
    comment_ids = params[:comment_ids].split("$$").select{|id| id.strip!=""}.collect{|id| id.strip.to_i}
    ActiveRecord::Base.connection.execute("delete from comments where id in (#{comment_ids.join(",")})") unless comment_ids.empty?
    ActiveRecord::Base.connection.execute("delete from comments where parent_id in (#{comment_ids.join(",")})") unless comment_ids.empty?
    explanation_ids = params[:explanation_ids].split("$$").select{|id| id.strip!=""}.collect{|id| id.strip.to_i}
    #~ ActiveRecord::Base.connection.execute("delete from income_cash_flow_explanations where id in (#{explanation_ids.join(",")})") unless explanation_ids.empty?
    event_ids = params[:event_ids].split("$$").select{|id| id.strip!=""}.collect{|id| id.strip.to_i}
    ActiveRecord::Base.connection.execute("delete from events where id in (#{event_ids.join(",")})") unless event_ids.empty?
    ActiveRecord::Base.connection.execute("delete from event_resources where event_id in (#{event_ids.join(",")})") unless event_ids.empty?
    render :nothing => true
  end

  def delete_exps
    expln_id = params[:expln_id]
    if params[:type] == 'cash_flow'
          ActiveRecord::Base.connection.execute("delete from income_cash_flow_explanations where income_and_cash_flow_detail_id = #{expln_id} and month = #{params[:month]} and ytd = #{params[:is_ytd_explanation]}") if expln_id
          render :nothing => true
    else
        if params[:expid].present? #separate condition for deleting capexp - variances explanations and cost
            if (params[:type_val] == 'capital' || params[:type]  == "capital")
                ytd= params[:ytd_check]  || params[:is_ytd_cost]
              elsif params[:type] == 'cap_exp'
                ytd = params[:is_ytd_cost]  || params[:is_ytd_explanation]
            end
          ActiveRecord::Base.connection.execute("delete from capital_expenditure_explanations where id = #{params[:expid]} and property_capital_improvement_id = #{expln_id} and month = #{params[:month]} and ytd = #{ytd}") if expln_id

          #Collection to find whether the item has one explanation and delete comment#
            cap_exp_collection  = CapitalExpenditureExplanation.find_by_sql("select * from capital_expenditure_explanations where property_capital_improvement_id = #{expln_id} and month= #{params[:month]} and ytd = #{ytd}")
            cap_id = cap_exp_collection.first.id  if cap_exp_collection.present?
            ActiveRecord::Base.connection.execute("update comments set commentable_id = #{cap_id} where commentable_id = #{params[:expid]} and commentable_type = 'CapitalExpenditureExplanation'") if cap_id
            if !cap_exp_collection.present?
              ActiveRecord::Base.connection.execute("delete from comments where commentable_id = #{params[:expid]} and commentable_type = 'CapitalExpenditureExplanation'") if expln_id
            end

        end
        render :update do |page|
          params[:performance_review_path] = params[:performance_review_path].gsub("and","&")
          page.call "replace_performance_review", "#{params[:performance_review_path]}","true"
        end
    end
  end

  def save_explanation #Method to save Cap exp explantion
    #~ customize_path ->before_filter added
    params[:ytd_check] = (params[:ytd_check] == "true") ? true : false
     if params[:expid].present?
       exp_id = CapitalExpenditureExplanation.find_by_id_and_property_capital_improvement_id_and_month_and_ytd(params[:expid],params[:id],params[:month],params[:ytd_check])
        exp_id.update_attributes(:explanation=>params[:exp],:user_id=>current_user.id,:month=>params[:month],:ytd=>params[:ytd_check])
       else
      CapitalExpenditureExplanation.create(:property_capital_improvement_id=>params[:id],:explanation=>params[:exp],:user_id=>current_user.id,:month=>params[:month],:document_id=>params[:variance_doc_id],:ytd=>params[:ytd_check])
    end
    render :update do |page|
      page.call "flash_writter", FLASH_MESSAGES['explanation']['902']
      page.call "replace_performance_review", "#{params[:performance_review_path]}","true"
    end
  end

  def save_financial_explanation
    #~ customize_path->before_filter added
    params[:ytd_check] = (params[:ytd_check] == "true") ? true : false
    exp_id = IncomeCashFlowExplanation.find(:first, :conditions=>["income_and_cash_flow_detail_id = ? and month = ? and ytd = ?",params[:id],params[:month],params[:ytd_check]])
    if !exp_id.nil?
      exp_id.update_attributes(:explanation=>params[:exp],:user_id=>current_user.id,:month=>params[:month],:ytd=>params[:ytd_check])
    else
      IncomeCashFlowExplanation.create(:income_and_cash_flow_detail_id=>params[:id],:explanation=>params[:exp],:user_id=>current_user.id,:month=>params[:month],:document_id=>params[:variance_doc_id],:ytd=>params[:ytd_check])
    end
    render :update do |page|
      page.call "flash_writter", FLASH_MESSAGES['explanation']['902']
      page.call "replace_performance_review", "#{params[:performance_review_path]}","true"
    end
  end

  def save_cash_receivable_explanation
    #~ customize_path->before_filter added
    exp_id = PropertyCashFlowForecastExplanation.find(:first, :conditions=>["property_cash_flow_forecast_id = ? and month = ?",params[:id],params[:month]])
    if !exp_id.nil?
      exp_id.update_attributes(:explanation=>params[:exp],:user_id=>current_user.id,:month=>params[:month])
    else
      PropertyCashFlowForecastExplanation.create(:property_cash_flow_forecast_id=>params[:id],:explanation=>params[:exp],:user_id=>current_user.id,:month=>params[:month])
    end
    render :update do |page|
      page.call "flash_writter", FLASH_MESSAGES['explanation']['902']
      page.call "replace_performance_review", "#{params[:performance_review_path]}","true"
    end
  end

  def save_lease_explanation
    #~ customize_path->before_filter added
    exp_id = LeasesExplanation.find_by_real_estate_property_id_and_month_and_year_and_occupancy_type(params[:id],params[:month],params[:year],params[:occupancy_type])
    if !exp_id.nil?
      exp_id.update_attributes(:explanation=>params[:exp],:user_id=>current_user.id,:month=>params[:month])
    else
      LeasesExplanation.create(:real_estate_property_id=>params[:id],:explanation=>params[:exp],:month=>params[:month],:year=>params[:year],:occupancy_type=>params[:occupancy_type],:user_id=>current_user.id)
    end
    render :update do |page|
      page.call "flash_writter", FLASH_MESSAGES['explanation']['902']
      page.call "replace_performance_review", "#{params[:performance_review_path]}","true"
    end
  end

  def save_rent_roll_explanation
    #~ customize_path->before_filter added
    exp_id = PropertyLease.find_by_property_suite_id_and_month_and_year_and_occupancy_type(params[:id],params[:month],params[:year],params[:occupancy_type])
    unless exp_id.nil?
      exp_id.update_attributes(:comments=>params[:exp],:month=>params[:month])
    else
      PropertyLease.create(:property_suite_id=>params[:id],:comments=>params[:exp],:month=>params[:month],:year=>params[:year],:occupancy_type=>params[:occupancy_type])
    end
    render :update do |page|
      page.call "flash_writter", FLASH_MESSAGES['explanation']['902']
      page.call "replace_performance_review", "#{params[:performance_review_path]}","true"
    end
  end
  def save_sub_lease_explanation
    #~ customize_path->before_filter added
     exp_id = LeasesExplanation.find_by_lease_id_and_real_estate_property_id_and_month_and_year_and_occupancy_type(params[:id],params[:property_id],params[:month],params[:year],params[:occupancy_type])
    if !exp_id.nil?
      exp_id.update_attributes(:explanation=>params[:exp],:user_id=>current_user.id,:month=>params[:month])
    else
      LeasesExplanation.create(:lease_id=>params[:id],:real_estate_property_id=>params[:property_id],:explanation=>params[:exp],:month=>params[:month],:year=>params[:year],:occupancy_type=>params[:occupancy_type],:user_id=>current_user.id)
    end
    render :update do |page|
      page.call "flash_writter", FLASH_MESSAGES['explanation']['902']
      page.call "replace_performance_review", "#{params[:performance_review_path]}","true"
    end
  end

  def save_aged_receivable_explanation
    #~ customize_path->before_filter added
    exp_id = PropertyAgedReceivable.find(:first, :conditions=>["id = ?",params[:id]])
    exp_id.update_attributes(:explanation=>params[:exp]) if !exp_id.nil?
    render :update do |page|
      page.call "flash_writter", "Explanation saved"
      page.replace_html "non_account_receivables_aging_#{exp_id.id}", :text=>"#{truncate_extra_chars_for_expl(exp_id.explanation.gsub(/\n/,'<br>'), 100)}" if !exp_id.nil?
    end
  end

  def save_costs_now   #Method to save cost along with explanation
    if (params[:type] == 'cap_exp' ||  params[:type] =='capital')
      expln = CapitalExpenditureExplanation.find_by_id_and_property_capital_improvement_id_and_month_and_ytd(params[:expid],params[:id],params[:month],params[:is_ytd_cost]) if params[:expid]
      cost_old = expln.cost ? expln.cost : 0
      expln.update_attributes(:cost=>params[:cost])
    end
    render :update do |page|
      page << "var init_total_value = jQuery('span#total_#{params[:id]}').html();total_value_old =parseFloat(init_total_value) - parseFloat(#{cost_old}); total_value = parseFloat(total_value_old) + parseFloat(#{expln.cost});jQuery('span#total_#{params[:id]}').html(parseFloat(total_value));"
      page.call "flash_writter", FLASH_MESSAGES['explanation']['903']
    end
  end

  def add_more_explanation #To add more explanation using the Add More link in cap exp - vairances tab
    @number = params[:number]
    @form_number = params[:form_number]
    @delete_number = (@number.to_i - 1).to_s
    @month = params[:month]
    @doc_id = params[:doc]
    @type = params[:type].to_s
    @condition = params[:cond]
    @exp_id = params[:exp_id]
    @incr =params[:incr]
    @partial = params[:partial]
    @id = params[:expid]
    @path = params[:path]
    @type_val = params[:type_val]
  end

  def customize_path
    params[:performance_review_path] = params[:performance_review_path].gsub("and","&")
  end

   def change_session_value
		 if ( (params[:portfolio_id].present? && params[:property_id].blank?) || (params[:pid].present? && params[:nid].blank?) || (params[:real_estate_id].present? && params[:id].blank?) )
		  session[:portfolio__id] = params[:portfolio_id] || params[:pid] || params[:real_estate_id]
      session[:property__id] = ""
    elsif ( (params[:portfolio_id].present? && params[:property_id].present?) || (params[:pid].present? && params[:nid].present?) || (params[:real_estate_id].present? && params[:id].present?) )
      session[:portfolio__id] = ""
      session[:property__id] = params[:property_id] || params[:id] || params[:nid]
		elsif( (session[:portfolio__id].present? && session[:property__id].blank?) )
		  session[:portfolio__id] = session[:portfolio__id]
      session[:property__id] = ""
		else
			session[:portfolio__id] = ""
      session[:property__id] = session[:property__id]
	  end
  end
end
