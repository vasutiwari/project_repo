class PropertiesController < ApplicationController
  before_filter :user_required
  layout 'user',:except=>['edit_real_picture','view_portfolios_path']
  before_filter :user_required, :except=> [:upload_doc,:task_mulitfile_upload, :store_variance_details,:repeat_task]
  before_filter :find_property_id,:only=>['add_loan','update','delete_loan','show_asset_docs','destroy']
  #~ before_filter :find_form,:only=>[:suite_create_or_update_method,:set_form]
  #~ before_filter :find_portfolio_and_property,:only=>[:sales_preparation,:property_pipeline,:property_lease]
  before_filter :change_session_value, :only=>[:update]
  before_filter :change_session_value_for_files, :only=>[:show_asset_files]
  before_filter   :check_property_access,  :only => [:add_loan,:update,:delete_loan,:show_asset_docs,:destroy,:show,:add_or_edit_property,:single_file_upload_in_add_property,:delete_property_picture,:update_real_picture,:edit_real_picture]
  before_filter   :check_portfolio_access,  :only => [:show]
  @@time = Time.now

  def index
    portfolio=Portfolio.find_by_id(params[:real_estate_id])
    if portfolio.present?
      redirect_to portfolio_path(portfolio.try(:id))
    else
      redirect_to portfolios_path
    end
  end

  #To create or edit property
  def add_or_edit_property
    if params[:property_id]
      @property = RealEstateProperty.find_real_estate_property(params[:property_id])
      @property.update_attributes(:note_id=>params[:property][:note_id],:original_note_amount=>params[:property][:original_note_amount],:current_outstanding=>params[:property][:current_outstanding],:late_payments_amount_due=>params[:property][:late_payments_amount_due],:first_payment_date=>params[:property][:first_payment_date],:maturity_date=>params[:property][:maturity_date],:last_payment_date=>params[:property][:last_payment_date],:current_interest_rate=>params[:property][:current_interest_rate],:comments=>params[:property][:comments],:user_id=>current_user.id)
      portfolio = Portfolio.find_by_id(params[:pid])
        find_portfolio_association = @property.portfolios.map(&:id).include?(params[:pid])
        @property.portfolios << portfolio if find_portfolio_association.blank?
      @property.save
    else
      create_new_property
      if !@property.id.nil? && !@property.remote_property_name.blank? &&  !@property.property_code.blank?
        responds_to_parent do
          render :update do |page|
            page.call "flash_writter", "we are retrieving your data from the database. it will take sometime.we will intimate through mail once it is successfully completed"
            page.redirect_to "/real_estate/#{@portfolio.id}/properties/#{@property.id}?partial_disp=property_settings&from_property_details=true"
          end
        end
      elsif !@property.id.nil?
        responds_to_parent do
          render :update do |page|
            page.call "flash_writter","Property details saved successfully"
            page.redirect_to "/real_estate/#{@portfolio.id}/properties/#{@property.id}?partial_disp=property_settings&from_property_details=true"
          end
        end
      else
        update_tab_previous_next
      end
    end
  end

  #creates a new property
  def create_new_property
    property = RealEstateProperty.new
    property_remote_name,property_code = find_temp_property_name_property_code
    property.create_real_estate_property(params[:real_estate_property]["property_name"],params[:pid],params[:real_estate_property]["property_type_id"],current_user.id,property_remote_name,property_code)
    if params[:real_estate_property][:address]
      #client id added in query
      address  =  Address.store_address_details(params[:real_estate_property][:address][:txt],params[:real_estate_property][:address][:city], params[:real_estate_property][:address][:zip],params[:real_estate_property][:address][:province])
      property.address_id = address.id
    end
    @property_valid = "true"  if property.valid? && address.valid? && check_remote_property_validity(property)

    if @property_valid
      portfolio = Portfolio.find_by_id(property.portfolio_id)
      find_portfolio_association = property.portfolios.map(&:id).include?(property.portfolio_id)
      property.portfolios << portfolio if find_portfolio_association.blank?
      property.save
    end


    @tab = "2"
    if params[:attachment]
      PortfolioImage.create_portfolio_image(params[:attachment][:uploaded_data],property.id,nil)
    end
    @property = property
    update_accounting_type_info if params[:real_estate_property] && params[:real_estate_property][:accounting_system_type_id] && @property_valid
    @property_valid = "true"  if property.valid? && address.valid? && check_remote_property_validity(property)
    create_properties_folders_docs_filenames if @property_valid
    @real_estate_properties << @property if  @property_valid && @real_estate_properties
    if params[:real_estate_property]["remote_property_name"] && @property_valid
      import_datas_into_master_tabel
    end
  end

  #To check whether valid details has been given by the user or not
  def check_remote_property_validity(property)
    if params[:real_estate_property][:accounting_system_type_id] && remote_property(params[:real_estate_property][:accounting_system_type_id])
      property.remote_property_validation = true
      if(params[:real_estate_property]["remote_property_name"].blank? || params[:real_estate_property]["property_code"].blank?)
        return false
      elsif check_remote_name_and_code
        return true
      else
        return false
      end
    else
      return true
    end
  end

  #To check property name and property code is in temp table
  def check_remote_name_and_code
    table_name = find_table_name + '_Property'
    record = RealEstateProperty.find_by_sql("select id from #{table_name} where SCODE = '#{params[:real_estate_property]["property_code"].strip}' and SADDR1 = '#{params[:real_estate_property]["remote_property_name"].strip}'")
    if  record.nil? || record.empty?
      @remote_property_validity = false
      return false
    else
      @remote_property_validity = true
      return true
    end
  end

  #To find the temp table name
  def find_table_name
    client =  RemoteAccountingSystemType.find_by_accounting_system_type_id(params[:real_estate_property][:accounting_system_type_id])
    return client.table_name.to_s if client
  end

  def find_temp_property_name_property_code
    property_remote_name = params[:real_estate_property]["remote_property_name"]  ? params[:real_estate_property]["remote_property_name"] : nil
    property_code = params[:real_estate_property]["property_code"]  ? params[:real_estate_property]["property_code"] : nil
    return property_remote_name,property_code
  end

  #creates master folders
  def create_properties_folders_docs_filenames
    create_master_folders
    amp_create_subfolders_files_for_property(@asset_folder,@property)
  end

  #To Add loan form
  def add_loan
    @number = params[:number]
    @loan_form_number = params[:loan_form_number]
    @delete_number = (@number.to_i - 1).to_s
  end

  #updates the property details
  def update
    @portfolio = @property.portfolio
    suites_build_and_collection(@property)  if params[:form_txt] == "suites" || params[:suites_form_submit] == "true"
    find_suite_and_collection(params[:suite_id], @property)  if params[:suite_id]
    if !params[:suite_id]
      @property.add_property_validity = "no"
      @property.check_validation == "no"
      update_property_name   if params[:real_estate_property] && params[:real_estate_property][:property_name]
      update_property_address if params[:property_form] != "true" && params[:basic_form_submit] != "false" && params[:property_form_submit] != "false" && params[:loan_form_submit].nil? && params[:spms_form_submit].nil? && params[:alert_form_submit] != "true"
      update_accounting_type_info if  params[:real_estate_property] && params[:real_estate_property][:accounting_system_type_id]
      add_or_update_property_image if params[:attachment] && params[:attachment][:uploaded_data] && (params[:prop_form_close] == "true" || params[:property_form_submit] == 'true')
    end
    if  params[:loan_form_submit] == "true" ||  params[:loan_form_submit] == "false" || params[:loan_form_close]
      update_loan_details

    elsif params[:suites_form_submit] == "true" || params[:suite_id] #suites save
      suite_create_or_update_method
    elsif params[:alert_form_submit] == "true" || params[:alert_form_close] #alerts save
      send_weekly_alert_mail
      @tab = params[:tab_id]
      form = params[:form_txt] + "_form"
      update_respond_to_parent("#{form}","#{@tab}",FLASH_MESSAGES['properties']['406'],nil)
    elsif params[:property_form_submit] == "false" #property next
      @property.create_property_details(params)
      form_hash_for_loan_details
      update_tab_previous_next
    elsif params[:property_form] == "true"  #property save
      @property.check_prop_name_validation = false
      @property.update_attributes(params[:real_estate_property])
      @tab = params[:tab_id]
      form = params[:form_txt] + "_form"
      update_respond_to_parent("#{form}","#{@tab}",FLASH_MESSAGES['properties']['406'],nil)
    elsif params[:basic_form_submit] == "false" #basic next
      create_basic_details
    else
      add_or_update_property_image
      add_or_update_address
      @property.check_prop_name_validation = false
      update_tab_previous_next
    end
  end

  def update_property_name
    @folder = Folder.find_by_parent_id_and_is_master_and_real_estate_property_id(0,0,@property.id)
    @property.update_attributes(:property_name=>params[:real_estate_property][:property_name]) unless params[:real_estate_property][:property_name].empty?
    if @property.valid?
      @folder.update_attributes(:name =>params[:real_estate_property][:property_name]) if !@folder.nil? && !params[:real_estate_property][:property_name].empty?
    end
  end

  def update_property_address
    @property.update_attributes(:property_name=>params[:real_estate_property][:property_name],:property_type_id => params[:real_estate_property][:property_type_id])
    portfolio = Portfolio.find_by_id(@property.portfolio_id)
    find_portfolio_association = @property.portfolios.map(&:id).include?(@property.portfolio_id)
    @property.portfolios << portfolio if find_portfolio_association.blank?
    @property.save

    @address = Address.find_by_id(@property.address_id)
    @address.update_attributes(params[:real_estate_property][:address]) if !@address.nil?
  #client id added in query
  end

  def update_accounting_type_info
    @property.update_attributes(:accounting_system_type_id=>params[:real_estate_property][:accounting_system_type_id], :accounting_type=>params[:real_estate_property][:accounting_type], :leasing_type=>params[:real_estate_property][:leasing_type])
  end

  def update_loan_details
    debtsummary = PropertyDebtSummary.find(:all,:conditions =>["real_estate_property_id = ?",@property.id])
    debtsummary.empty? ? @add_loan_details = true : @edit_loan_details = true
    form_hash_for_loan_details
    @property = RealEstateProperty.find_real_estate_property(params[:property_id])
    create_or_update_loan_details
  end

  #Creates or updates loan details in add a property lightbox
  def create_or_update_loan_details
    @loan_hash_with_validation = []
    if (!@loan_hash.empty? || params[:form_txt] != 'spms')
      @loan_hash.compact.each do |loan|
        @add_loan = false
        loan.each do |key,value|
          @add_loan = true  if !value.strip.blank? && !value.strip.nil?
        end
        @add_loan ? @loan_hash_with_validation << loan :  @loan_hash_with_validation << {}
      end
      j =0
      @loan_hash_with_validation.compact.each do |loan|
        if loan.empty? == false
          loan.each do |key,value|
            if @edit_loan_details == true
              debtsummary = PropertyDebtSummary.find_all_by_real_estate_property_id_and_category(@property.id,key)
              debtsummary[j].update_attribute("description",value) if debtsummary[j] !=nil
              @add_loan_details = true  if debtsummary[j] == nil
            end
            PropertyDebtSummary.create_debt_summary_details(@property.id,key,value) if @add_loan_details == true
          end
          j += 1
        end
      end
      form = params[:form_txt] + "_form"
      @tab = params[:tab_id]
      validation = @loan_hash_with_validation.delete_if{|l| l.empty?}
      msg = validation.empty? ? " " : FLASH_MESSAGES['properties']['402']
      update_respond_to_parent("#{form}","#{@tab}",msg,nil)
    else
      responds_to_parent do
        render :update do |page|
          page.call "load_completer"
          page.call "flash_writter", "Please do not submit empty form"
        end
      end
    end
  end

  #called while clicking a folder in datahub
  def show_asset_docs
    @folder = Folder.find_folder(params[:id]) if params[:id]
    suites_build_and_collection(@property)  if params[:form_txt] == "suites" || params[:suites_form_submit] == "true"
    send_weekly_alert_mail if params[:form_txt] == "alerts" || params[:alert_form_submit] == "true"
    @portfolio = (params[:pid] && !params[:pid].blank?) ? Portfolio.find(params[:pid]) : Portfolio.find(:first,:conditions=>["user_id = #{User.current.id} and name not in (?)",["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]])
    find_real_estate_properties_for_navigation_bar
    if params[:data_hub] == "asset_data_and_documents"
      if params[:partial_page] == "portfolio_folder"
        find_property_folders
      else
        if params[:note_add_edit] =="true" || params[:property_id]
          if (params[:suites_form_submit] == "true")
            suite_create_or_update_method
          else
            add_or_edit_property
          end
        elsif(params[:show_past_shared] == "true")
          @folder = Folder.find_folder(params[:asset_id])
          find_past_shared_folders('false')
        else
          assign_initial_options
        end
      end
      if !params[:note_add_edit]
        render :update do |page|
          if !params[:nid] && params[:show_past_shared] != "true"
            page.replace_html "show_assets_list", :partial=>'properties/properties_and_files'
          else
            partial_page = (@folder && @folder.name == "my_files"  && @folder.parent_id == 0) ? '/collaboration_hub/my_files_assets_list' : 'assets_list'
            page.replace_html "show_assets_list",:partial=>partial_page
            page.call "highlight_datahub" if params[:show_past_shared] != "true"
          end
        end
      end
    else
      @properties = RealEstateProperty.find_properties_of_portfolio(@portfolio.id)
      render :update do |page|
        page.replace_html "show_assets_list",:partial=>'edit_assets'
        page.call "toggle_highlight", 'basic_info'
      end
    end
  end

  #...............................for note view here................................................#
   def show
     if params[:portfolio_selection].present?
      session[:portfolio__id] = params[:real_estate_id] || params[:pid] || params[:portfolio_id]
      session[:property__id] = ""
     elsif params[:property_selection].present?
      session[:portfolio__id] = ""
      session[:property__id] = params[:id] || params[:nid] || params[:property_id]
    else

		  if( (session[:portfolio__id].present? && session[:property__id].blank?) )
		    session[:portfolio__id] = session[:portfolio__id]
        session[:property__id] = ""
		  else
		  	session[:portfolio__id] = ""
        session[:property__id] = session[:property__id]
	    end
  end
@status=params[:status] ? params[:status] : 3
    if !Portfolio.exists?(params[:real_estate_id])
      @portfolios = Portfolio.find_shared_and_owned_portfolios(User.current.id)
      @portfolio = @portfolios.first
    else
      @portfolio = Portfolio.find_by_id(params[:real_estate_id])
    end
    @notes = RealEstateProperty.find_owned_and_shared_properties(@portfolio,User.current.id,true)
     if session[:property__id].present? && session[:portfolio__id].blank?
        @note = RealEstateProperty.find_real_estate_property(session[:property__id])
        @resource = "'RealEstateProperty'"
     elsif session[:portfolio__id].present? && session[:property__id].blank?
        @note = Portfolio.find_by_id(session[:portfolio__id])
        @resource = "'Portfolio'"
    end
    @partial_file = "/properties/sample_pie"
    @swf_file = "Pie2D.swf"
    @xml_partial_file = "/properties/sample_pie"
    #~ show_err_msg_if_no_access
    if @note
    find_timeline_values
    params[:tl_year] = (params[:tl_period] =="10" || params[:tl_period] == "3") ? params[:tl_year] : @today_year
    @operating_statement={}
    @cash_flow_statement={}
    financial_month
    @time_line_actual  = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, 'RealEstateProperty'])
    else
      flash[:notice]=FLASH_MESSAGES['portfolios']['508']
      redirect_to  portfolios_path
    end
  end




  #show folders - from events
  def show_folder_files
    @portfolios = Portfolio.find(:all, :conditions=>['user_id = ? and portfolio_type_id = 2 and name not in (?)', current_user,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]], :order=> "created_at desc")
    @portfolio = Portfolio.find(params[:pid])
    @folder = Folder.find_folder(params[:folder_id])
    @notes = RealEstateProperty.find_properties_by_portfolio_id_with_cond(@portfolio.id,"","order by created_at desc)") if !@portfolio.nil?
    @note = RealEstateProperty.find_real_estate_property(@folder.real_estate_property_id)
     (current_user.has_role?("Shared User") && session[:role] == 'Shared User') ? find_folders_and_docs(@folder.id) : assign_options
    if request.xhr?
      render :update do |page|
        page.replace_html "show_assets_list",:partial=>'assets_list'
      end
    else
      render :action => 'show_files'
    end
  end

  #To set the current form
  def set_form
    form = params[:form_txt] + "_form"
    @tab = params[:tab_id]
    form_hash_for_loan_details if !@loan_hash
    update_respond_to_parent(form,@tab,FLASH_MESSAGES['properties']['406'],nil)
  end

  #stores property - basic details
  def create_basic_details
    @tab = "2"
    property_remote_name,property_code = find_temp_property_name_property_code
    @property.create_real_estate_property(params[:real_estate_property]["property_name"],params[:pid],params[:real_estate_property]["property_type_id"],current_user.id,property_remote_name,property_code)
    add_or_update_address if params[:real_estate_property][:address]
    add_or_update_property_image
    #@property.save
    portfolio = Portfolio.find_by_id(@property.portfolio_id)
     find_portfolio_association = @property.portfolios.map(&:id).include?(@property.portfolio_id)
    @property.portfolios << portfolio if find_portfolio_association.blank?
    @property.save
    if params[:real_estate_property]["remote_property_name"]
      import_datas_into_master_tabel
    end
    update_tab_previous_next
  end

  #To insert datas into master tables from temp table
  def import_datas_into_master_tabel
    if params[:real_estate_property]["remote_property_name"] && remote_property(@property.accounting_system_type_id)
      remote_property = RealEstateProperty.find_by_sql("select HMY as hmy_id from #{find_table_name + '_Property'} where SCODE = '#{params[:real_estate_property]["property_code"].strip}' and SADDR1 = '#{params[:real_estate_property]["remote_property_name"].strip}'")
      if remote_property && !remote_property.empty?
        connection = ActiveRecord::Base.connection();
        connection.execute("INSERT INTO `remote_properties` (`HMY` ,`real_estate_property_id` ,`accounting_system_type_id`) VALUES ('#{remote_property[0].hmy_id}',#{@property.id},#{@property.accounting_system_type_id})")
      end
      hmy = RealEstateProperty.find_by_sql("select HMY as hmy_id from remote_properties where real_estate_property_id = #{@property.id} limit 1")[0]
      Delayed::Job.enqueue DelayedPropertyDataImport.new(@property.id,current_user.id,find_table_name,hmy.hmy_id.to_i,@property.portfolio.leasing_type,@property.property_name,@property.property_code,@property.portfolio_id)
    end
  end


  #to add or update address in add a property
  def add_or_update_address
    if @property.address !=nil
      @address = @property.address
      #client id added in query
      @address.update_attributes(params[:real_estate_property][:address_attributes])
    else
      #client id added in query
      @address = Address.store_address_details(params[:real_estate_property][:address_attributes][:txt],params[:real_estate_property][:address_attributes][:city], params[:real_estate_property][:address_attributes][:zip],params[:real_estate_property][:address_attributes][:province])
      @property.address_id = @address.id
    end
  end

  #deletes a last created loan details and updates the page
  def delete_loan
    PropertyDebtSummary.delete_debt_summary_details(@property.id,params[:loan_number]) if params[:delete_form] != "true"
    form_hash_for_loan_details
  end

  #to add or update image in add a property lightbox
  def add_or_update_property_image
    if params[:attachment]
      image_type = (params[:prop_form_close] == "true" || params[:property_form_submit] == 'true')  ? 'property_picture' : nil
      if (params[:prop_form_close] == "true" || params[:property_form_submit] == 'true')
        #image = PortfolioImage.find_by_attachable_id_and_attachable_type_and_is_property_picture(@property.id,"RealEstateProperty",true)
      else
        image = PortfolioImage.find_by_attachable_id_and_attachable_type(@property.id,"RealEstateProperty")
      end
      image != nil ?  image.update_attributes(params[:attachment]) : PortfolioImage.create_portfolio_image(params[:attachment][:uploaded_data],@property.id,image_type)
    end
  end

  #updatates page after lightbox close
  def update_page_after_close
    @portfolio = Portfolio.find(params[:pid])
    if params[:call_from_alerts] == "true"
      send_weekly_alert_mail
    elsif params[:call_from_variances] == "true"
      variances_exp_comment
    elsif params[:from_property_details] == "true"
      property_view
    elsif params[:from_debt_summary] == "true"
      loan_details
    elsif params[:sfid] == "0" && params[:list] != "shared_list"
      assign_initial_options
      params[:parent_delete] = "true"
      msg = "no_display"
      add_visual_effect_delete_file(msg)
    else
      @folder = Folder.find_folder(params[:sfid])  if params[:sfid].to_i > 0
      if(params[:show_past_shared] == "true")
        find_past_shared_folders('false')
      else
        params[:sfid].to_i > 0 ?  assign_options(@folder.id) : assign_options
      end
      @msg = "reverted"
      render :update do |page|
        update_partials(page)
      end
    end
  end

  #updates page while clicking previous in add a property
  def update_tab_previous_next
    if(@property.address.nil? || !@property.valid? || params[:real_estate_property][:address] || params[:real_estate_property][:property_name])
      if (params[:real_estate_property][:address] && params[:real_estate_property][:address][:province].empty?) || params[:real_estate_property][:property_name].empty?
        show_err_msg(FLASH_MESSAGES['properties']['404'])
      elsif  !check_remote_property_validity(@property) || !@property.valid?
        acc_type_id = params[:real_estate_property][:accounting_system_type_id] ? params[:real_estate_property][:accounting_system_type_id] : @property.accounting_system_type_id
        msg_num =(remote_property(acc_type_id) && !@remote_property_validity) ? '410' : (!@property.valid? && !(@property.errors['property_code'].nil? or @property.errors['property_code'].blank?)) ? '411' : (!@property.valid?) ? '407' :'404'
        show_err_msg(FLASH_MESSAGES['properties'][msg_num])
      elsif !@property.valid? && !(@property.errors['property_code'].nil? or @property.errors['property_code'].blank?)
        show_err_msg(FLASH_MESSAGES['properties']['411'])
      elsif !@property.valid?
        show_err_msg(FLASH_MESSAGES['properties']['407'])
      else
        set_form
      end
    else
      set_form
    end
  end

  #updates page while clicking continue from SPMS
  def respond_to_parent_initial_page
    if @dispaly_initial_list == true
      @folder = Folder.find_by_real_estate_property_id(@property.id,:conditions=>["parent_id = 0 and is_master = 0"])
      assign_options(@folder.id)
    else
      assign_initial_options
    end
    responds_to_parent do
      render :action => 'respond_to_parent_initial_page.rjs'
    end
  end

  #Property sales preparation
  def sales_preparation
    @portfolio = Portfolio.find_by_id(params[:portfolio_id])
    @note =  RealEstateProperty.find_real_estate_property(params[:id])
  end

  def property_pipeline
    @portfolio = Portfolio.find_by_id(params[:portfolio_id])
    @note =  RealEstateProperty.find_real_estate_property(params[:id])
  end

  def property_lease
    @portfolio = Portfolio.find_by_id(params[:portfolio_id])
   @note =  RealEstateProperty.find_real_estate_property(params[:id])
  end

  #shows property path to users
  def view_portfolios_path
  end

  #Viwe for editing Property image
  def edit_real_picture
  end

  #Update Property image
  def update_real_picture
    @note_image =   PortfolioImage.find_by_attachable_id_and_attachable_type_and_is_property_picture(params[:property_id],"RealEstateProperty",false)
    if !@note_image.nil?
      if !@note_image.temp_path.blank?
        @note_image.update_attributes(:uploaded_data=>params[:attachment][:uploaded_data])
        update_page_after_property_image_upload
      else
        property_image_upload_err_msg
      end
    else
      @note = RealEstateProperty.find_real_estate_property(params[:property_id])
      @note_image = PortfolioImage.new(:uploaded_data=>params[:attachment][:uploaded_data]) unless @note.nil?
      if !@note_image.temp_path.blank?
        @note.portfolio_image = @note_image
        @note.save
        update_page_after_property_image_upload
      else
        property_image_upload_err_msg
      end
    end
  end

  #To show error msg in add a property
  def show_err_msg(message)
    responds_to_parent do
      render :update do |page|
        page.call 'change_basic_form'
        page.call "flash_writter", "#{message}"
        page << "activate_click('#{params[:form_txt]}_onclick')"
        #page.call "load_completer"
      end
    end
  end

  #Display Success  message while uploading property image
  def update_page_after_property_image_upload
    responds_to_parent do
      render :action => 'update_page_after_property_image_upload.rjs'
    end
  end

  #Display Error  message while uploading property image
  def property_image_upload_err_msg
    responds_to_parent do
      render :update do |page|
        page.call "flash_completer"
        page.replace_html 'error_display', FLASH_MESSAGES['properties']['405']
      end
    end
  end

  def update_page_from_asset_files
    render :action=> 'update_page_from_asset_files.rjs'
  end

  #To display folders,docs,docnames while clicking a folder
  def show_asset_files
    display_collection_of_folders_docs_tasks
  end
  def find_property_id
    @property = RealEstateProperty.find_real_estate_property(params[:property_id])
  end

  def destroy
    suite = Suite.find(params[:suite_id])
    suite = suite.destroy
    @portfolio = @property.portfolio
    if (params[:form_page] =='setting_suite')
      @suites_collection = @property.suites
      render :update do |page|
        page.replace_html "suite_partial",:partial =>"/real_estates/partial_suite"
        page.call "flash_writter", "Suite Detail has been deleted successfully"
      end
    end
  end

  def suite_create_or_update_method
    form = params[:form_txt] + "_form"
    @tab = params[:tab_id]
    !params[:suite][:floor].empty? ? @new_suite.create_or_update_suite_details(params) : FLASH_MESSAGES['properties']['404']
    if !params[:textarea].empty?
      @new_suite.build_note(:content => params[:textarea])
      @new_suite.save
    end
    responds_to_parent do
      render :update do |page|
        @new_suite = @property.suites.new
        #~ page.replace_html "tabs",:partial =>"/real_estates/property_sub_tab",:locals=>{:tab_collection => @tab,:property_collection =>@property}
        page.replace_html "sheet123",:partial =>"/real_estates/#{form}"
        #~ page.call "activate_tabs","#{@tab}" if @tab != "4"
        page.call "flash_writter", "#{FLASH_MESSAGES['properties']['412']}"
      end
    end
  end


  def delete_property_picture
    image = PortfolioImage.find_by_id(params[:picture_id])
    image.destroy if image
    @property = RealEstateProperty.find_by_id(params[:property_id])
    find_uploaded_property_pictures
    if @pictures.empty?
      render :update do |page|
        page.hide "property_pictures_list"
        page << "AddedFiles.pop('#{image.filename}')"
      end
    else
      render :update do |page|
        page << "AddedFiles.pop('#{image.filename}')"
        page.call "flash_writter", "Picture deleted successfully"
      end
    end
  end

  def change_session_value
     #~ if ( (params[:portfolio_id].present? && params[:property_id].blank?) || (params[:pid].present? && params[:nid].blank?) || (params[:real_estate_id].present? && params[:id].blank?) )
		  #~ session[:portfolio__id] = params[:portfolio_id] || params[:pid] || params[:real_estate_id]
      #~ session[:property__id] = ""
    if ( (params[:portfolio_id].present? && params[:property_id].present?) || (params[:pid].present? && params[:nid].present? || params[:pid].present? && params[:property_id].present?) || (params[:real_estate_id].present? && params[:id].present?) )
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


  def change_session_value_for_files
     if ( (params[:portfolio_id].present? && params[:property_id].blank?) || (params[:pid].present? && params[:nid].blank?) || (params[:real_estate_id].present? && params[:id].blank?) )
		  session[:portfolio__id] = params[:portfolio_id] || params[:pid] || params[:real_estate_id]
      session[:property__id] = ""
    elsif ( (params[:portfolio_id].present? && params[:property_id].present?) || (params[:pid].present? && params[:nid].present? || params[:pid].present? && params[:property_id].present?) || (params[:real_estate_id].present? && params[:id].present?) )
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


  def single_file_upload_in_add_property
    @property = RealEstateProperty.find_by_id(params[:property_id])
    if params[:file]
      @property_image_file = PortfolioImage.new
      @property_image_file.uploaded_data = params[:file]
      @property_image_file.attachable_id = @property.id
      @property_image_file.attachable_type = "RealEstateProperty"
      @property_image_file.is_property_picture = true
      @property_image_file.save#(:validate => false)
    end
    if params[:task_id]
      fn = ['delect_selected_file_for_folder',params[:task_id]]
    elsif params[:document_id]
      fn = ['delect_selected_file',params[:document_id]]
    end
    val_list = ''
    final_list = []
    total = find_uploaded_property_pictures.compact.collect{|t| t.id}
    val_list = val_list + "<ul>"    unless total.empty?
    unless total.empty?
      for each_file in total
        doc = PortfolioImage.find_by_id(each_file)
        if !doc.nil?
          val_list =  val_list +  "<li id='property_picture_#{doc.id}'>	<a style='padding-right:3px;' onclick=\"if (confirm('Are you sure you want to remove this file ?')){jQuery('#property_picture_#{doc.id}').remove();remove_selected_picture(#{doc.id},#{@property.id},'#{doc.filename}');} return false;\" href='#'><img border='0' width='7' height='7' src='/images/del_icon.png'></a>#{doc.filename}</li>" if !doc.nil?
          final_list << doc.id
        end
      end
    end
    val_list = val_list + "</ul>"   unless total.empty?
    responds_to_parent do
      render :update do |page|
        page.show "property_pictures_list"
        page.replace_html  'upload_files_list',"<input type='hidden' name='already_upload_file' id='already_upload_file' value='#{final_list.join(",")}'/>"
        page.replace_html  'single_file_upload_list',val_list
        page.call "flash_writter", "Picture uploaded successfully"
        page << "jQuery('#fileUpAddFiles').val(null);"
      end
    end
  end

  def check_property_access

    id = params[:property_id].present? ? params[:property_id] : params[:nid].present? ? params[:nid] : params[:id].present? ? params[:id] : @property.present? ? @property.try(:id) : @note.present? ? @note.id : ""

    if id.present?
      properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(current_user.id,prop_folder=true)
      @property_ids = properties.present? ? properties.map(&:id) : []
      unless @property_ids.include?(id.to_i)
        last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
        if last_portfolio.present? && first_property.present?
          redirect_to financial_info_path(last_portfolio.try(:id), first_property.try(:id),:access=>'true')
        elsif properties.present?
          redirect_to financial_info_path(properties.last.try(:portfolio_id), properties.last.try(:id),:access=>'true')
        else
          redirect_to notify_admin_path(:from_session=> true)
        end
      end
    end
  end

  def check_portfolio_access
    unless current_user.has_role?("Shared User")
      if ((params[:portfolio_id].present? && params[:property_id].blank?) || (params[:pid].present? && params[:nid].blank?)) &&  params[:bulk_upload] != "true" && !params[:show_missing_file].present?
        id = params[:real_estate_id].present? ? params[:real_estate_id] : params[:portfolio_id].present? ? params[:portfolio_id] : params[:pid].present? ? params[:pid] : @portfolio.present? ? @portfolio.try(:id) : ""
        if id.present?
          portfolios = Portfolio.find_portfolios(current_user)
          @portfolio_ids = portfolios.present? ? portfolios.map(&:id) : []
          unless @portfolio_ids.include?(id.to_i)
          properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(current_user.id,prop_folder=true)
          last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
          if last_portfolio.present? && first_property.present?
            redirect_to financial_info_path(last_portfolio.try(:id), first_property.try(:id),:port_access=>'true')
          elsif properties.present?
            redirect_to financial_info_path(properties.last.try(:portfolio_id), properties.last.try(:id),:port_access=>'true')
          else
            redirect_to notify_admin_path(:from_session=> true)
          end
        end
        end
      end
    end

  end
 #~ def find_portfolio_and_property
   #~ @portfolio = Portfolio.find_by_id(params[:portfolio_id])
   #~ @note =  RealEstateProperty.find_real_estate_property(params[:id])
 #~ end

  #~ def find_form
    #~ form = params[:form_txt] + "_form"
    #~ @tab = params[:tab_id]
  #~ end
end
