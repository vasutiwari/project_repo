class LeaseController < ApplicationController
  before_filter :user_required
  before_filter :finding_suite_bp, :only =>['rent_sch_persft_total_calc','rent_revenue_total_calc','rent_persft_total_calc']
  before_filter :finding_lease_bp, :only =>['insurance_data_push','cap_exp_data_push']
  before_filter :finding_lease_id_bp, :only =>['update','update1','term_data_push']
  before_filter :finding_document_bp, :only =>['delete_suite_doc','download_lease_doc']
  before_filter :prop_and_port_collection,:except=>['download_lease_doc','change_portfolio','getting_started','vacant_occupied_suites','rent_sch_tot_calc','rent_sch_persft_total_calc','rent_revenue_total_calc','item_destroy', 'get_property_suite_details','month_calc','stacking']
  before_filter :change_session_value, :only=>[:management,:pipeline, :alert,:stacking_plan,:budget,:encumbrance,:rent_roll,:suites, :dashboard_terms]
  before_filter   :check_property_access, :only=> [:management,:pipeline,:alert,:stacking_plan, :budget,:encumbrance,:rent_roll,:suites, :dashboard_terms]
     if request.xhr?
      unless @pdf
        respond_to do |format|
          format.js {
            render :update do |page|
              page.replace_html  "show_assets_list", :partial => "/lease/management", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
            end
          }
        end
      end
    end
  end

  def management_header
    find_month_for_alert_view
    start_month =  @months[0]
    end_month = @months[11]
    if @months && start_month && end_month
      display_for_management_header(start_month,end_month,params[:property_id])
    end
    find_collections_of_leases
    executed_tenant = RealEstateProperty.find_real_estate_property(params[:property_id]).executed_leases # executed leases collection
    @tenant_count = executed_tenant.count
    @a = params[:selected_value].eql?("Inactive Leases") ? Lease.executed_leases_archeived_method(params[:property_id]) : Lease.executed_leases_method(params[:property_id],params[:search_txt])
    @a = sorting_all_prop_lease_suites(@a) # For sorting based on suite number
    if params[:selected_value] == "Inactive Leases"
      #      @archeived_sort_val = Lease.executed_leases_archeived_method(params[:property_id])
      @property_lease_suites = @pdf ? @a.compact : @a.compact.paginate(:per_page=>25,:page=>$mgmt_page)
    else
      if @pdf && !params[:search_txt].present? #included for print PDF
        params[:search_txt] = nil
      end
      if @a.present? && params[:selected_value] != "new_lease" && params[:selected_value] != "insurance_alerts" && params[:selected_value] != "upcoming_tis"
        @property_lease_suites = @pdf ?  @a.compact : @a.compact.paginate(:per_page=>25,:page=>$mgmt_page)
      end
    end
  end

  def pipeline
    ajax_page_refresh_method
  end

  def alert
    #~ replace_partial_method('lease_container','property_alert')
  end

  def encumbrance
    unless @pdf
      if request.xhr?
        render :update do |page|
          page.replace_html  "lease_container", :partial => "/lease/property_encumb", :locals => {:rent_roll_swig => @rent_roll_swig, :note_collection => @note, :portfolio_collection => @portfolio_collection}
        end
      end
    end
    #~ unless @pdf
    #~ respond_to do |format|
    #~ format.js {
    #~ render :update do |page|
    #~ page.replace_html  "lease_container", :partial => "/lease/property_encumb", :locals => {:rent_roll_swig => @rent_roll_swig, :note_collection => @note, :portfolio_collection => @portfolio_collection}
    #~ end
    #~ }
    #~ end
    #~ end
  end
  #budget start
  def budget
    @note = RealEstateProperty.find_by_id(params[:property_id]) if params[:property_id].present?
    @total_property = Suite.where(:real_estate_property_id => @note.try(:id)).sum(:rentable_sqft) rescue 0
    if params[:leasing_budget].blank? && params[:selected_year].blank?
      @leasing_budget = LeasingBudget.leasing_budget(@note)
    elsif params[:selected_year].present? && params[:leasing_budget].blank?
      @leasing_budget = LeasingBudget.leasing_budget(@note,params[:selected_year])
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "leasing_budget", :partial => "/lease/budget", :locals => {:property_id => @note.try(:id), :portfolio_id => @portfolio_collection.try(:id)}
          end
        }
      end
    elsif params[:leasing_budget].present?
      current_year = Time.now.year
      selected_year = params[:leasing_budget][:selected_year] ||  current_year
      @leasing_budget = @note.leasing_budgets.where(:selected_year => selected_year).first
      if @leasing_budget.blank?
        @leasing_budget = LeasingBudget.new(params[:leasing_budget])
        @leasing_budget.save
        @success_budget=FLASH_MESSAGES['leases']['125']
      else
        @leasing_budget.update_attributes(params[:leasing_budget])
        @success_budget=FLASH_MESSAGES['leases']['125']
      end
      unless params[:current_selected_year].blank? &&  params[:current_selected_year].eql?(selected_year)
        @leasing_budget = @note.leasing_budgets.where(:selected_year => params[:current_selected_year]).first
        @leasing_budget = LeasingBudget.new(:selected_year => params[:current_selected_year])  if  @leasing_budget.blank?
      end
    end
  end
  #budget end

  #lease suites start
  def suites
    @portfolio = @portfolio_collection
    if request.xhr?
      render :update do |page|
        if params[:suite_filter].present?
          page.replace_html "suite_filter_display",:partial =>"/lease/partial_suite",:locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
        else
          page.replace_html  "lease_container", :partial => "/lease/suites_form", :locals => {:rent_roll_swig => @rent_roll_swig, :note_collection => @note, :portfolio_collection => @portfolio_collection}
        end
      end
    end
    #~ respond_to do |format|
    #~ format.js {
    #~ render :update do |page|
    #~ if params[:suite_filter].present?
    #~ page.replace_html "suite_filter_display",:partial =>"/lease/partial_suite",:locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
    #~ else
    #~ page.replace_html  "lease_container", :partial => "/lease/suites_form", :locals => {:rent_roll_swig => @rent_roll_swig, :note_collection => @note, :portfolio_collection => @portfolio_collection}
    #~ end
    #~ replace_navigation_bar(page,@portfolio_collection,@note)
    #~ end
    #~ }
    #~ end
  end

  def suites_create
    params[:suite_no].present? ? suites_data_push : params[:suite_no1].present? ? edit_suites : params[:suite_file_up].present? ? suite_attach_file : params[:suite_filter].present? ? suite_filter_data : lease_suite_msg(FLASH_MESSAGES['properties']['404'])
  end

  def edit_suites
    @propid = @note.id
    @suite_folder =  Folder.find_suite_folder_by_property_id(params[:property_id])
    @suite_data = Suite.find_by_id_and_real_estate_property_id(params[:suite_field_id],@propid)
    @lease_suite = @suite_data.update_lease_suite_data(params,@propid,current_user.id)
    @suite_id = params[:suite_field_id]
    @suite_note = Note.find_by_note_id_and_note_type(@suite_id,"Suite")
    @suite_note.lease_suite_note_update(params[:suite_note1],@suite_id) if params[:suite_note1].present? && @suite_note.present?
    Note.lease_suite_note_data(params[:suite_note1],@suite_id) if params[:suite_note1].present? && !@suite_note.present?
    @suite_files = Document.find_by_suite_id_and_real_estate_property_id(@suite_id,params[:property_id])
    @suite_files.update_attach_files_for_suites(params[:suite_file_upload1],params[:property_id],current_user.id,@suite_folder.id,@suite_id) if @suite_files.present?
    Document.attach_files_for_suites(params[:suite_file_upload1],params[:property_id],current_user.id,@suite_folder.id,@suite_id) if params[:suite_file_upload1].present? && !@suite_files.present?
    responds_to_parent do
      render :update do |page|
        page.replace_html "mgmt_lease_suite_id",:partial =>"/lease/suites_form",:locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
        page.call "flash_writter", "#{FLASH_MESSAGES['properties']['412']}"
      end
    end
    Rails.cache.clear("stack_#{current_user.id}_#{params[:portfolio_id]}_#{params[:property_id]}")
  end

  def suite_filter_data
    render :update do |page|
      page.replace_html "suite_filter_display",:partial =>"/lease/partial_suite",:locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
    end
  end

  def suite_attach_file
    @propid = @note.id
    @suite_folder =  Folder.find_suite_folder_by_property_id(@note.id)
    document = Document.attach_files_for_suites(params[:suite_file_up],params[:property_id],current_user.id,@suite_folder.id,params[:suiteid])
    shared_document_for_lease(@suite_folder,document) if @suite_folder.present? && document.present?
    responds_to_parent do
      render :update do |page|
        page.replace_html "mgmt_lease_suite_id",:partial =>"/lease/suites_form",:locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
        page.call "flash_writter", "#{FLASH_MESSAGES['properties']['412']}"
      end
    end
  end

  def suites_data_push
    @propid = params[:property_id]
    @suite_folder =  Folder.find_suite_folder_by_property_id(@propid)
    #~ suite_arr = params[:suite_no].split(',')
    #~ suite_arr.each do |s|
    @suite_find = Suite.find_by_suite_no_and_real_estate_property_id(params[:suite_no],@propid)
    suite_available = false
    if @suite_find.present?
      @suite_find.update_lease_suite_data_add(params[:suite_no],params,@propid,current_user.id)
      @lease_suite = @suite_find
      suite_available = true
    end
    @lease_suite =  Suite.create_lease_suite_data_push(params[:suite_no],params,@propid,current_user.id) if @suite_find.nil?
    @suite_id = @lease_suite.id if @suite_find.nil?
    @suite_id = @suite_find.id if @suite_find.present?
    @suite_note = Note.find_by_note_id_and_note_type(@suite_id,"Suite")
    @suite_note.lease_suite_note_update(params[:suite_note],@suite_id) if params[:suite_note].present? && @suite_note.present?
    Note.lease_suite_note_data(params[:suite_note],@suite_id) if params[:suite_note].present? && @lease_suite.present? && !@suite_note.present?
    @suite_files = Document.find_by_suite_id_and_real_estate_property_id(@suite_id,params[:property_id])
    @suite_files.update_attach_files_for_suites(params[:suite_file_upload],params[:property_id],current_user.id,@suite_folder.id,@suite_id) if @suite_files.present?
    document = Document.attach_files_for_suites(params[:suite_file_upload],params[:property_id],current_user.id,@suite_folder.id,@suite_id) if params[:suite_file_upload].present? && !@suite_files.present?
    shared_document_for_lease(@suite_folder,document) if @suite_folder.present? && document.present? && !@suite_files.present?
    #~ end
    responds_to_parent do
      render :update do |page|
        if @lease_suite.present? && !@lease_suite.id.nil?
          if suite_available
            page.call "flash_writter", "Suite '#{@lease_suite.suite_no}' updated successfully "
          else
            page.call "flash_writter", "Suite '#{@lease_suite.suite_no}' added successfully "
          end
          page.replace_html "mgmt_lease_suite_id",:partial =>"/lease/suites_form",:locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
        else
          rentable_sqft_value = (((params[:rentable_sqft] == "0" || !(params[:rentable_sqft].to_i.to_s == params[:rentable_sqft])) && (params[:usable_sqft] == "0" || (params[:usable_sqft].present? && !(params[:usable_sqft].to_i.to_s == params[:usable_sqft]))))) ? "Rentable SF and Usable SF" : (params[:rentable_sqft].blank? || params[:rentable_sqft] == "0" || !(params[:rentable_sqft].to_i.to_s == params[:rentable_sqft])) ? "Rentable SF" : (!params[:usable_sqft].blank? && (params[:usable_sqft] == "0" || !(params[:usable_sqft].to_i.to_s == params[:usable_sqft]))) ? "Usable SF" : ""
          message_for_invalid = "#{FLASH_MESSAGES['leases']['102']}"
          message_for_invalid_data = message_for_invalid.gsub("xxxx","#{rentable_sqft_value}") if !rentable_sqft_value.blank?
          if message_for_invalid_data.present?
            page.call "flash_writter", "#{message_for_invalid_data}"
          end
        end
      end
    end
    Rails.cache.clear("stack_#{current_user.id}_#{params[:portfolio_id]}_#{params[:property_id]}")
  end


  def delete_suite_doc
    #~ @document = Document.find(params[:id])
    @document.destroy
    render :update do |page|
      page.replace_html "mgmt_lease_suite_id",:partial =>"/lease/suites_form",:locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
      page.call "flash_writter", "#{FLASH_MESSAGES['leases']['103']}"
    end
  end

  def delete_suite_data
    @document = Suite.find(params[:id])
    Suite.update_commercial_lease_occupancy(params[:id])
    @document.destroy
    render :update do |page|
      page.replace_html "mgmt_lease_suite_id",:partial =>"/lease/suites_form",:locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
      page.call "flash_writter", "#{FLASH_MESSAGES['leases']['104']}"
    end
  end

  def lease_suite_msg(message,save=nil,partial=nil)
    responds_to_parent do
      render :update do |page|
        page.call "flash_writter", "#{FLASH_MESSAGES['leases']['107']}"
        page<<"jQuery('#suites_form').val('true')" if save.present?
        #page.replace_html "mgmt_lease_suite_id",:partial =>"/lease/suites_form",:locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
      end
    end
  end
  #lease suites end



  def rent_roll
    rent_roll_for_commercial(nil,Date.today.year,'rent_roll')
    if request.xhr?
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "rent_roll_container", :partial => "/lease/property_rentroll", :locals => {:rent_roll_swig => @rent_roll_swig, :note_collection => @note, :portfolio_collection => @portfolio_collection}
            page << "jQuery('#lease_rent_roll option[value=#{params[:rent_roll_filter]}]').attr('selected', 'selected');"
          end
        }
      end
    end
  end

  def dashboard_terms
    find_lease_id
    prop_and_port_collection
  end

  def terms
    if params[:lease_id].present? && !params[:lease_id].eql?('undefined')
      find_lease_id
      lease_tab_data_push
    else
      @lease = Lease.new
      @tenant = @lease.build_property_lease_suite.build_tenant
      option_note = @tenant.options.build
      option_note.build_note
      info = @tenant.build_info
      info.build_note
      @tenant.build_lease_contact
      @tenant.build_note
      @lease.build_note
      @rent = @lease.build_rent
      @rent.rent_schedules.build
      @rent.other_revenues.build
      @rent.cpi_details.build
      @rent.parkings.build
      @rent.recoveries.build
      @rent.percentage_sales_rents.build
    end
    unless @pdf
      respond_to do |format|
        format.js {
          render :update do |page|
            page.call "replace_rentroll_class"
            page.replace_html  "show_assets_list", :partial => "/lease/mgmt_head_tabs", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection, :@lease => @lease, :param_pipeline=> !params[:param_pipeline].blank? ? params[:param_pipeline] : nil}
          end
        }
      end
    end
  end

  def clauses
    if params[:lease_id].present? && !params[:lease_id].eql?('undefined')
      find_lease_id
      @clause = @lease.clause
    else
      @lease = Lease.new
      @clause = @lease.build_clause
    end
    unless @pdf
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "lease_term_nav", :partial => "/lease/mgmt_clauses", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
          end
        }
      end
    end
  end

  def lease_term_navigation
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html  "lease_term_nav", :partial => "/lease/mgmt_terms", :locals => {:rent_roll_swig => @rent_roll_swig, :note_collection => @note, :portfolio_collection => @portfolio_collection}
        end
      }
    end
  end

  def update
    #~ find_lease_id if params[:lease_id].present? && !params[:lease_id].eql?('undefined')
    @lease_folder =  Folder.find_lease_folder_by_property_id(@note.id) if params[:form_txt].eql?("docs")
    if  params[:term_form].eql?('true') || params[:clause_form].eql?('true') || params[:insurance_form].eql?('true') || params[:cap_exp_form].eql?('true') || params[:doc_form].eql?('true')
      replace_other_partials
    else
      if (params[:lease].present? && params[:lease][:property_lease_suite_attributes] && params[:lease][:property_lease_suite_attributes][:tenant_attributes][:tenant_legal_name].present?)
        term_data_push
      elsif (params[:lease].present? && params[:lease][:clause_attributes].present?)
        clause_data_push
      elsif  (params[:lease].present? && params[:lease][:cap_ex_attributes].present?)
        cap_exp_data_push
      elsif (params[:lease].present? && params[:lease][:insurance_attributes].present?)
        insurance_data_push
      elsif params[:uploaded_data].present? || params[:doc_data].present?
        doc_data_push
      elsif (params[:lease].present? && params[:lease][:income_projection].present?)
        income_projection_push
      else
        lease_msg(FLASH_MESSAGES['leases']['101'])
      end
    end
    Rails.cache.clear("stack_#{current_user.id}_#{params[:portfolio_id]}_#{params[:property_id]}")
  end

  def update1
    #~ find_lease_id if params[:lease_id].present? && !params[:lease_id].eql?('undefined')
    @lease_folder =  Folder.find_lease_folder_by_property_id(@note.id) if params[:form_txt].eql?("docs")
    @lease = params[:lease_id].present? ? Lease.find_by_id(params[:lease_id]) : Lease.new
    if  params[:term_form].eql?('true') || params[:clause_form].eql?('true') || params[:insurance_form].eql?('true') || params[:cap_exp_form].eql?('true') || params[:doc_form].eql?('true')
      replace_other_partials
    else
      if (params[:lease].present? && params[:lease][:property_lease_suite_attributes] && params[:lease][:property_lease_suite_attributes][:tenant_attributes][:tenant_legal_name].present?)
        term_data_push
      elsif (params[:lease].present? && params[:lease][:clause_attributes].present?)
        clause_data_push
      elsif  (params[:lease].present? && params[:lease][:cap_ex_attributes].present?)
        cap_exp_data_push
      elsif params[:lease][:insurance_attributes].present?
        insurance_data_push
      elsif (params[:lease].present? && params[:lease][:income_projection].present?)
        income_projection_push
      elsif params[:uploaded_data].present? || params[:doc_data].present?
        doc_data_push
      else
        lease_msg(FLASH_MESSAGES['leases']['101'])
      end
    end
    #~ Rails.cache.clear("stack_#{current_user.id}_#{params[:portfolio_id]}_#{params[:property_id]}")
  end

  def replace_other_partials
    err_msg = ""
    if params[:frm_name].eql?('rent_form') && params["lease"].present? && params["lease"]["rent_attributes"].present? && params["lease"]["rent_attributes"]["rent_schedules_attributes"].present?
      rent_schedule_attributes = params["lease"]["rent_attributes"]["rent_schedules_attributes"]
      rent_schedule_keys =rent_schedule_attributes.keys
      tmp_array = []
      rent_schedule_keys = rent_schedule_keys.flatten
      rent_schedule_last_to_date = ""
      rent_schedule_keys.each do |rent_schedule_key|
        rent_schedule_destroy_value = rent_schedule_attributes[rent_schedule_key]["_destroy"] rescue nil
        rent_schedule_from_date = rent_schedule_attributes[rent_schedule_key]["from_date"] rescue nil
        rent_schedule_to_date = rent_schedule_attributes[rent_schedule_key]["to_date"] rescue nil
        unless rent_schedule_destroy_value.eql?("1") || rent_schedule_from_date.blank? || rent_schedule_to_date.blank?
          rent_schedule_last_to_date = rent_schedule_attributes[rent_schedule_key]["to_date"] rescue nil
          tmp_array << rent_schedule_last_to_date.to_date
        end
      end
      tmp_array.sort!
      rent_schedule_last_to_date =  tmp_array.last.strftime("%m/%d/%Y") rescue nil
      rent_schedule_date = rent_schedule_last_to_date.to_date rescue nil
      lease_expiration_date = @lease.try(:expiration).to_date rescue nil
      if lease_expiration_date && rent_schedule_date && rent_schedule_date > lease_expiration_date
        err_msg = "Rent Schedule End Date Should Not Be Greater Than Lease End Date"
      end
    end
    if (params[:on_change_cpi] != 'true') && (params[:frm_name].eql?('rent_form') && params[:is_cpi_escalation].present?) && params[:lease][:rent_attributes][:cpi_details_attributes].present? && params[:lease][:rent_attributes][:cpi_details_attributes]["0"][:adjustment_start_month].blank? && params[:is_cpi_escalation].eql?('true')
      err_msg = "Adjustment Month can not be blank"
    end

    rent_data_push if params[:frm_name].eql?('rent_form') && err_msg.blank?
    message = params[:stored_lease_suites].present? ? "#{FLASH_MESSAGES['leases']['105']}" : "#{FLASH_MESSAGES['leases']['106']}"
    if params[:frm_name].eql?('rent_form') && err_msg.present?
      responds_to_parent do
        render :update do |page|
          page.call "suite_flash_writter", "#{err_msg}"
        end
      end
    elsif params[:frm_name].eql?('rent_form') && @suites_present.eql?(true) && request.xhr?
      respond_to do |format|
        format.json  {render :json => {:text => true}}
      end
    elsif params[:frm_name].eql?('rent_form') && @suites_present.eql?(false) && request.xhr?
      respond_to do |format|
        format.json  {render :json => {:text => message}}
      end
    elsif params[:frm_name].eql?('rent_form') && @suites_present.eql?(false)
      #      message = params[:stored_lease_suites].present? ? "#{FLASH_MESSAGES['leases']['105']}" : "#{FLASH_MESSAGES['leases']['106']}"
      responds_to_parent do
        render :update do |page|
          page.call "suite_flash_writter", "#{message}"
        end
      end
    else
      replace_lease_partial(params[:form_txt]) #if @check_status_rent.nil? || @check_status_rent.eql?(false)
    end
  end

  #attach files for docs start
  def doc_data_push
    if @pdf
      params[:current_lease_id] = params[:lease_id] if params[:lease_id]
      @lease = Lease.find_by_id(params[:current_lease_id].to_i) if params[:current_lease_id].present?
    else
      @lease = params[:current_lease_id].present? ? Lease.find_by_id(params[:current_lease_id].to_i) : @lease.update_attributes(params[:lease])
    end
    @lease_folder =  Folder.find_by_real_estate_property_id_and_name_and_is_master(@note.id,"Lease Files",1)
    lease_tab_data_push
    unless @pdf
      data = params[:uploaded_data]
      document = Document.attach_files_for_docs(data,params[:property_id],current_user.id,@lease_folder.id,@lease.id) if data.present?
      shared_document_for_lease(@lease_folder,document) if @lease_folder.present? && document.present?
      lease_msg("#{FLASH_MESSAGES['leases']['108']}",true,params[:form_txt])
    end
  end
  #attach files for docs end

  def income_projection_push
    @lease =  Lease.find_by_id(params["current_lease_id"]) if params["current_lease_id"].present? && @lease.blank?
    note_data = params[:lease][:income_projection].delete("note")
    if @lease.present? && @lease.income_projection.blank?
      @income_projection = @lease.create_income_projection(params[:lease][:income_projection])
      @income_projection.create_note(note_data)
      unless @income_projection.valid?
        error = @income_projection.errors.to_a.first if @income_projection.errors.present?
        err_msg = error.gsub!(/npv/i, 'NPV') || error if error.present?
        lease_msg(err_msg) if err_msg.present?
        return
      end
      @lease.update_attribute(:is_approval_requested,true) if  params["save_and_approve"].eql?("true")
      lease_tab_data_push
      lease_msg("#{FLASH_MESSAGES['leases']['108']}",true,params[:form_txt])
    elsif @lease.present? && @lease.income_projection.present?
      @income_projection =  @lease.income_projection
      if @income_projection.update_attributes(params[:lease][:income_projection])
        @note = @income_projection.note
        @note.update_attributes(note_data) if @note.present?
        @lease.update_attribute(:is_approval_requested,true) if  params["save_and_approve"].eql?("true")
        lease_tab_data_push
        lease_msg("#{FLASH_MESSAGES['leases']['108']}",true,params[:form_txt])
      else
        error = @income_projection.errors.to_a.first if @income_projection.errors.present?
        err_msg = error.gsub!(/npv/i, 'NPV') || error if error.present?
        lease_msg(err_msg) if err_msg.present?
      end
    else
       lease_msg(FLASH_MESSAGES['leases']['101'])
    end

  end
  #attach files for docs end

  def term_data_push
    check_status = check_suite_status(@lease.property_lease_suite,params[:property_id],"management") if params[:lease_id].present? && !params[:param_pipeline].present?
    if check_status.present?
      responds_to_parent do
        render :update do |page|
          #~ page.alert("Please change Lease date")
          page.alert("#{FLASH_MESSAGES['leases']['122']}")
        end
      end
    else
      #~ find_lease_id if params[:lease_id].present? && !params[:lease_id].eql?('undefined')
      terms_build_methods
      lease_tab_data_push
      lease_msg("#{FLASH_MESSAGES['leases']['108']}",true,params[:form_txt])
    end
  end

  def build_cap_ex
    #for cap_ex build start
    @cap_ex_build=@lease.build_cap_ex
    @cap_ex_build.build_note
    @tenant_improvement_build=@cap_ex_build.tenant_improvements.build
    @tenant_improvement_build.build_note
    3.times do
      @lease_com=@cap_ex_build.leasing_commissions.build
      @lease_com.build_note
    end
    @cap_ex_build.other_exps.build
    #for cap_ex build end
  end



  # Code moved to lease helper------------ starts
  #def build_cap_ex_blank
  #def build_insurance_blank
  #def build_doc_blank
  #def lease_tab_data_push
  #def find_lease_id
  # Code moved to helper------------ Ends

  def clause_data_push
    params[:lease_id] = params[:current_lease_id] if params[:current_lease_id]
    find_lease_id
    if @lease.clause.blank? && @pdf
      @clause = @lease.build_clause
    elsif @pdf
      @clause = @lease.clause
    end
    unless @pdf
      @lease = params[:current_lease_id].present? ? Lease.find_by_id(params[:current_lease_id].to_i) : @lease.update_attributes(params[:lease])
      @clause = @lease.clause.blank? ? @lease.create_clause(params[:lease][:clause_attributes]) : @lease.clause.update_attributes(params[:lease][:clause_attributes])
      @clause = @lease.clause if @clause == true
      @lease = params[:current_lease_id].present? ? Lease.find_by_id(params[:current_lease_id].to_i) : @lease
      #~ lease_msg('Data saved successfully',true,params[:form_txt])
    end
    lease_tab_data_push
    lease_msg("#{FLASH_MESSAGES['leases']['108']}",true,params[:form_txt])
  end

  def rent_data_push
    #~ @check_status_rent = check_suite_status(@lease.property_lease_suite,params[:property_id],"management") if params[:lease_id].present? && !params[:param_pipeline].present?
    if params[:on_blur].eql?('true')
      suites = Suite.find_by_suite_no_and_real_estate_property_id(params[:suite],params[:property_id])
      rent_sum = 0.0
      if (params[:variable] == "undefined")
        @lease = Lease.find_by_id(params[:lse_id])
        logic_array = []
        logic = true
        lease_suite = finding_lease_of_a_suite(suites,'management')
        lease_suite.each do |prop_lease|
          logic = logic && !(( @lease.commencement <= prop_lease.expiration ) && ( @lease.expiration >= prop_lease.commencement ))
        end
        logic_array << (lease_suite.present? ? logic : true)
        @check_suite_status_var = logic_array.include?(false)
      else
        @check_suite_status_var = false
      end

      if suites.present?
        tmp_hash,prev_tmp_hash = tmp_hash_calc(suites)
        comm_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(suites.id,params[:lse_id],params[:tnt_id])
        CommPropertyLeaseSuite.create(:suite_id=>suites.id,:lease_id=>params[:lse_id],:tenant_id=>params[:tnt_id]) if comm_prop.blank?
        move_in = comm_prop.try(:move_in).present? ? comm_prop.move_in : ''
        move_out = comm_prop.try(:move_out).present? ? comm_prop.move_out : ''
        old_suite = Suite.find_by_suite_no_and_real_estate_property_id(params[:prev_suite],params[:property_id])
        old_suite_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(old_suite.try(:id),params[:lse_id],params[:tnt_id])
        if old_suite_prop.present?
          old_suite_prop.suite_id = suites.id
          #         old_suite_prop.move_in = move_in.present? ? move_in : nil
          #         old_suite_prop.move_out = move_out.present? ? move_out : nil
          old_suite_prop.save
        end
        is_all_suite_selected = Lease.find_by_id(params[:lse_id]).try(:rent).try(:is_all_suites_selected)

        suite_ids = PropertyLeaseSuite.find_by_lease_id(params[:lse_id]).try(:suite_ids)
        if(!is_all_suite_selected)
          cur_suite = Suite.find_by_suite_no_and_real_estate_property_id(params[:suite],params[:property_id])
          if prev_tmp_hash.present?
            prev_tmp_hash.each_key{|key|
              rent_sch_coll = RentSchedule.where(:suite_id => key)
              rent_sch_coll.destroy_all if rent_sch_coll.present?
              RentSchedule.create(:suite_id => cur_suite.try(:id),:rent_id => Lease.find_by_id(params[:lse_id]).try(:rent).try(:id))
            }
          else
            RentSchedule.create(:suite_id => cur_suite.try(:id),:rent_id => Lease.find_by_id(params[:lse_id]).try(:rent).try(:id))
          end
        else
          rent_sqft = Suite.find_all_by_id_and_real_estate_property_id(suite_ids, params[:property_id]).map(&:rentable_sqft)
          rent_sum = rent_sqft.sum if rent_sqft.present?
        end
        #        respond_to do |format|
        #          format.json do
        #            render :json =>{:tmp_hash =>tmp_hash,:prev_tmp_hash => prev_tmp_hash, :cur_id =>params[:cur_id].to_i,:suite_no => suites.suite_no, :rentable_sqft => suites.rentable_sqft.present? ? suites.rentable_sqft : '', :floor => suites.floor.present? ? suites.floor : '', :usable_sqft => suites.usable_sqft.present? ? suites.usable_sqft : '',:is_all_suite_selected => is_all_suite_selected,:prev_suite => params[:prev_suite]}.to_json
        #          end
        if(is_all_suite_selected.eql?(false) && suite_ids.present?)
          @lease = Lease.find_by_id(params[:lse_id])
          @portfolio_collection = Portfolio.find_by_id(params[:portfolio_id])
          #          render "change_rent_sch.js.erb"
          if params[:prev_suite].present?
            render "change_suite_change_rent_sch.js.erb"
          else
            render "change_rent_sch_without_prev_suite.js.erb"
          end
        else
          respond_to do |format|
            format.json do
              render :json =>{:tmp_hash =>tmp_hash,:prev_tmp_hash => prev_tmp_hash, :cur_id =>params[:cur_id].to_i,:suite_no => suites.suite_no, :rentable_sqft => suites.rentable_sqft? ? suites.rentable_sqft : '', :floor => suites.floor? ? suites.floor : '', :usable_sqft => suites.usable_sqft? ? suites.usable_sqft : '',:is_all_suite_selected => is_all_suite_selected,:prev_suite => params[:prev_suite],:rent_sum => rent_sum}.to_json
            end
          end
        end
        #        end
      else
        render :json => {:text => "test",:suite_no => params[:cur_id]}
      end
    elsif params[:on_rent_sqft_blur].eql?('true')
      #~ suites = Suite.find_by_suite_no_and_real_estate_property_id(params[:suite],params[:property_id])
      #~ suites.update_attributes(:rentable_sqft => params[:rent_sqft]) if suites.present?
      render :nothing => true
    else
      #~ if @check_status_rent.eql?(true)
      #~ responds_to_parent do
      #~ render :update do |page|
      #~ page.alert("please select any other suites")
      #~ end
      #~ end
      #~ else
      @lease = Lease.find_by_id(params[:lease_id].to_i)
      #Added to update lease status#
      Lease.update_lease_status(@lease)
      unless @pdf
        @suites_present = false
        rent_suite_update
        if params[:rent_schedule_ids]
          rent_schedule_ids = params[:rent_schedule_ids].split(",") rescue nil
          rent_schedule_ids.shift rescue nil
          RentSchedule.delete(rent_schedule_ids)
          if params["lease"].present? && params["lease"]["rent_attributes"].present? && params["lease"]["rent_attributes"]["rent_schedules_attributes"].present?
            rent_schedule_attributes = params["lease"]["rent_attributes"]["rent_schedules_attributes"]
            keys = params["lease"]["rent_attributes"]["rent_schedules_attributes"].keys
            keys = keys.flatten rescue nil
            keys.each do |key|
              current_id = rent_schedule_attributes[key]["id"] rescue nil
              if rent_schedule_ids.include?(current_id)
                rent_schedule_attributes.delete(key)
              end
            end
            params["lease"]["rent_attributes"]["rent_schedules_attributes"] = rent_schedule_attributes
          end
        end


        @rent = @lease.rent.blank? ? @lease.create_rent(params[:lease][:rent_attributes]) : @lease.rent.update_attributes(params[:lease][:rent_attributes]) if @suites_present.eql?(true)
        @lease = Lease.find_by_id(params[:lease_id].to_i)
        if params[:is_cpi_escalation] && params[:is_cpi_escalation] == "true" && @lease && @lease.rent && @lease.rent.cpi_details.present?
          @lease.rent.update_attributes(:is_cpi_escalation=> true)
          @lease.rent.cpi_details.first.update_attributes(:adjustment_frequency => "12")
        elsif params[:is_cpi_escalation] && params[:is_cpi_escalation] == "false" && @lease && @lease.rent && @lease.rent.cpi_details.present?
          @lease.rent.cpi_details.each do |cpi_detail|
            cpi_detail.delete
          end
          @lease.rent.update_attributes(:is_cpi_escalation=> false)
        end
        notes_creation
      end
      lease_tab_data_push
      #~ end
    end
    #~ end
  end

  #for insurance start
  def insurance_data_push
    #~ @lease = params[:current_lease_id].present? ? Lease.find_by_id(params[:current_lease_id].to_i) : @lease.update_attributes(params[:lease])
    unless @pdf
      @insurance = @lease.insurance.blank? ? Insurance.create(params[:lease][:insurance_attributes]) : @lease.insurance.update_attributes(params[:lease][:insurance_attributes])
      @insurance = @lease.insurance if @insurance == true
      @lease = params[:current_lease_id].present? ? Lease.find_by_id(params[:current_lease_id].to_i) : @lease
    end
    lease_tab_data_push
    lease_msg("#{FLASH_MESSAGES['leases']['108']}",true,params[:form_txt])
  end
  #for insurance end

  #for lease cap exp start
  def cap_exp_data_push
    #~ @lease = params[:current_lease_id].present? ? Lease.find_by_id(params[:current_lease_id].to_i) : @lease.update_attributes(params[:lease])
    unless @pdf
      @cap_exp = @lease.cap_ex.blank? ? CapEx.create(params[:lease][:cap_ex_attributes]) : @lease.cap_ex.update_attributes(params[:lease][:cap_ex_attributes])
      @cap_exp = @lease.cap_ex if @cap_exp == true
      #~ #for use percentage start
      if params[:is_percentage] && params[:is_percentage] == "true" && @lease && @lease.cap_ex && @lease.cap_ex.leasing_commissions.present?
        @lease.cap_ex.update_attributes(:is_percentage => true)
      elsif params[:is_percentage] && params[:is_percentage] == "false" && @lease && @lease.cap_ex && @lease.cap_ex.leasing_commissions.present?
        @lease.cap_ex.update_attributes(:is_percentage => false)
      end
      #~ #for use percentage end
      @lease = params[:current_lease_id].present? ? Lease.find_by_id(params[:current_lease_id].to_i) : @lease
    end
    lease_tab_data_push
    lease_msg("#{FLASH_MESSAGES['leases']['108']}",true,params[:form_txt])
  end
  #for lease cap exp end

  #for lease documents download start
  def download_lease_doc
    #~ @document = Document.find(params[:id])
    send_file "#{Rails.root.to_s}/public"+@document.public_filename
  end
  #for lease documents download end

  #for lease documents delete start
  def delete_lease_doc
    params[:current_lease_id] = params[:lease_id] if params[:lease_id]
    @lease = Lease.find_by_id(params[:current_lease_id].to_i) if params[:current_lease_id].present?
    @lease_folder =  Folder.find_lease_folder_by_property_id(@note.id)
    @document = Document.find(params[:id])
    @document.destroy
    lease_tab_data_push
    render :update do |page|
      page.replace_html "delet_lease_file",:partial=>'mgmt_docs', :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
      page.call "flash_writter", "#{FLASH_MESSAGES['leases']['103']}"
    end
  end
  #for lease documents delete end

  def add_option
    @property = RealEstateProperty.find_real_estate_property(params[:property_id])
    @number = params[:number]
    @option_section_number = params[:option_section_number]
    @delete_number = (@number.to_i - 1).to_s
  end

  def cap_exp
    replace_partial_method('lease_term_nav','mgmt_cap_exp')
  end

  def insurance
    replace_partial_method('lease_term_nav','mgmt_insurance')
  end

  #  def projection
  #
  #    @real_estate_property_id = params[:property_id]
  #    @portfolio_id = params[:portfolio_id]
  #    unless @pdf
  #      @lease = Lease.find_by_id(125)
  #      @lease = Lease.includes(:cap_ex => [:tenant_improvements, :other_exps, :leasing_commissions], :property_lease_suite => {:tenant => [:info, :options]}, :rent => [:rent_schedules, :other_revenues, :percentage_sales_rents, :parkings]).where("leases.id=125").try(:first)
  #      @lease = Lease.includes(:cap_ex => [:tenant_improvements, :other_exps, :leasing_commissions], :property_lease_suite => {:tenant => [:info, :options]}, :rent => [:rent_schedules, :other_revenues, :percentage_sales_rents, :parkings]).where("leases.id=1").try(:first)
  #
  #      @lease = Lease.includes(:cap_ex => [:tenant_improvements, :other_exps, :leasing_commissions], :property_lease_suite => {:tenant => [:info, :options]}, :rent => [:rent_schedules, :other_revenues, :percentage_sales_rents, :parkings]).where("leases.id=1").try(:first)
  #    end
  #    mgmt_lease_details(@lease)
  #
  #    @usable_sqft = 0
  #    @rentable_sqft = 0
  #    @suites = Suite.where(:id => @suite_ids)
  #    @suites.each do |suite|
  #      @usable_sqft = @usable_sqft + suite.usable_sqft.to_f
  #      @rentable_sqft = @rentable_sqft + suite.rentable_sqft.to_f
  #    end
  #    @income_projection=IncomeProjection.first
  #    #    @income_projection = IncomeProjection.new
  #    @income_projection.note unless @income_projection.nil?
  #
  #    unless  @income_projection.present?
  #      @income_projection = IncomeProjection.new
  #      @income_projection.build_note
  #    end
  #    replace_partial_method('lease_term_nav','mgmt_projection') unless @pdf
  #  end
  #
  #
  #  def income_projection_comment
  #
  #    @income_projection = IncomeProjection.new(params[:income_projection])
  #
  #    if @income_projection.save
  #
  #      render :update do |page|
  #        page.replace_html  "income_projection_div_save", :partial => "income_projection_comment", :object => @income_projection
  #      end
  #
  #    end
  #  end

  def docs
    replace_partial_method('lease_term_nav','mgmt_docs')
  end

  def save_lease_details
    lease = Lease.find(params[:lease_id])
    lease.update_attributes(:commencement => params[:commencement] != "mm/dd/yy" ? Date.parse(params[:commencement]) : '')
    lease.update_attributes(:expiration => params[:expiration] != "mm/dd/yy" ? Date.parse(params[:expiration]) : '')
    lease.update_attributes(:effective_rate => params[:effective_rate])
    #~ lease.update_attributes(:activity_status => params[:activity_status])
    #~ lease.update_attributes(:activity_date => params[:activity_date] != "mm/dd/yy" ? Date.parse(params[:activity_date]) : '')
    lease.update_attributes(:basic_rentable_sqft => params[:rentable_sqft])
     (lease && lease.note) ? lease.note.update_attributes(:content => params[:content]) : lease.create_note(:content => params[:content])

    if ( lease && lease.cap_ex.nil? && params[:ti])
      cap_ex = lease.create_cap_ex
      ti = cap_ex.tenant_improvements.create(:amount_psf => params[:ti])
    elsif (lease && lease.cap_ex && lease.cap_ex.tenant_improvements.blank?  && params[:ti])
      ti1=  lease.cap_ex.tenant_improvements.create(:amount_psf => params[:ti])
    else
      ti2 = lease.cap_ex.tenant_improvements.first.update_attributes(:amount_psf => params[:ti])  if params[:ti]
    end

    tenant = Tenant.find(params[:tenant_id])
    tenant.update_attributes(:tenant_legal_name => params[:tenant_legal_name])
    @prop_leas_suite = lease.property_lease_suite.update_attributes(:tenant_id=>tenant.id, :suite_ids => @suite_ids)

  end

  def create_suite_and_lease
    if !params[:tenant_legal_name].blank?
      nil_suites = nil
      if (!params[:suite_numbers].blank?) || (params[:suite] && !params[:suite][:suite_no].blank?)
        @suite_ids = []
        nil_suites = []
        suite_arr = params[:suite_numbers].present? ? params[:suite_numbers].split(',') : params[:suite][:suite_no].split(',')
        suite_arr.each do |s|
          find_suite = Suite.find_by_suite_no_and_real_estate_property_id(s,params[:property_id])
          @suite_ids << find_suite.try(:id)
          nil_suites << s if find_suite.nil?
        end

      else
        @suite_ids = []
      end
      if (nil_suites.nil? && @suite_ids.blank? ) ||  nil_suites.blank?
        if !params[:lease_id].blank?
          save_lease_details
        else
          @check_var = true
          @new_lease = @note.interested_prospects_leases.create(:basic_rentable_sqft => params[:rentable_sqft], :effective_rate=>params[:effective_rate], :commencement=> params[:commencement] != "mm/dd/yy" ? Date.parse(params[:commencement]) : '', :expiration=> params[:expiration] != "mm/dd/yy" ? Date.parse(params[:expiration]) : '',:is_executed=>false, :is_approval_requested=>false, :is_archived=> false, :status=> 'Active')
          @cap_ex = @new_lease.create_cap_ex
          @tenant_imprv =  @cap_ex.tenant_improvements.create(:amount_psf=> params[:ti])
          @new_tenant = Tenant.create(:tenant_legal_name=> params[:tenant_legal_name])
          @prop_leas_suite = @new_lease.create_property_lease_suite(:tenant_id=>@new_tenant.id, :suite_ids => @suite_ids)
          if !params[:notes].blank?
            @new_lease.build_note(:content => params[:notes])
            @new_lease.save
          end

        end

        #for docs start
        if params[:pipeline_file_upload].present?
          data = params[:pipeline_file_upload]
          current_user_id =current_user.id
          lease_folder =  Folder.find_by_real_estate_property_id_and_name_and_is_master(params[:property_id],"Lease Files",1)
          if params[:lease_id].present?
            Document.find_by_id(params[:document_id]).destroy if params[:document_id].present?
            Document.attach_files_for_docs(data,params[:property_id],current_user_id,lease_folder.try(:id), params[:lease_id])
          else
            Document.attach_files_for_docs(data,params[:property_id],current_user_id,lease_folder.try(:id), @new_lease.id) if @new_lease.present?
          end
        end


        #for docs end
        ajax_page_refresh_method

      else
        responds_to_parent do
          render :update do |page|
            #~ page.call "load_completer"
            #~ page.call "flash_writter", "Please Add Suite Number(s) #{nil_suites.join(',')} in Suite Tab"
            #~ page.call "flash_writter", "Entered suite number is not available in our records. Kindly re-enter. You can add new suite through Suite tab."
            page.alert("#{FLASH_MESSAGES['leases']['110']}")
          end
        end
      end

    else
      responds_to_parent do
        render :update do |page|
          #~ page.call "load_completer"
          #~ page.call "flash_writter", "Please enter valid data / All the fields"
          page.alert("#{FLASH_MESSAGES['leases']['111']}")
        end
      end
    end
  end

  #for managment attach files start
  def attach_management_docs
    @lease = params[:lease_id]
    @lease_folder =  Folder.find_by_real_estate_property_id_and_name_and_is_master(@note.id,"Lease Files",1)

    unless @pdf
      data = params[:mgmt_file_upload]
      document = Document.attach_files_for_docs(data,@note.id,current_user.id,@lease_folder.id,@lease) if data.present?
      shared_document_for_lease(@lease_folder,document) if @lease_folder.present? && document.present?
      property_lease_suite = Lease.find(@lease).property_lease_suite
      #property_lease_suite.update_attributes(:updated_at=>Time.now)
      $mgmt_page = (params[:mgmt] == 'true') ? params[:page] : (params[:action] == 'attach_management_docs') ? $mgmt_page.to_i : 1
      management_header
      responds_to_parent do
        render :update do |page|
          page.replace_html  "show_assets_list", :partial => "/lease/management", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
          page.call "flash_writter", "#{FLASH_MESSAGES['leases']['109']}"
        end
      end
    end
  end
  #for managment attach files end

  def update_suite_and_lease
    params[:name] == "tenant_legal_name" ? tenant_create_or_update : (params[:name] == "commencement" || params[:name] == "expiration" || params[:name] == "effective_rate" || params[:name] == "activity_status" || params[:name] == "activity_date" || params[:name] == "content" || params[:name] == "ti" || params[:name] == "rent") ? lease_create_or_update : params[:pipeline_file_upload].present? ? update_file_for_pipeline : ""
  end

  #for pipeline approved lease attachments start
  def update_file_for_pipeline
    if params[:propleasesuite]=="true"
      #for docs start
      data = params[:pipeline_file_upload]
      current_user_id =current_user.id
      lease_folder =  Folder.find_by_real_estate_property_id_and_name_and_is_master(params[:property_id],"Lease Files",1)
      document = Document.attach_files_for_docs(data,params[:property_id],current_user_id,lease_folder.try(:id), params[:lease_id]) if params[:lease_id].present?
      shared_document_for_lease(lease_folder,document) if lease_folder.present? && document.present?
      #for docs end
      property_lease_suite_id = params[:suiteid]
      property_lease_suite = PropertyLeaseSuite.find_by_id(property_lease_suite_id)
      #~ suite_ids = property_lease_suite.suite_ids
      #~ suite_ids.each do |s|
      #~ attachment_pipeline(s)
      #~ end
      #~ property_lease_suite.update_attributes(:updated_at=>Time.now)
    else
      suite_id = params[:suiteid]
      attachment_pipeline(suite_id)
    end
    temp_method_for_pipeline
  end

  def attachment_pipeline(suiteid)
    #for docs start
    data = params[:pipeline_file_upload]
    current_user_id =current_user.id
    lease_folder =  Folder.find_by_real_estate_property_id_and_name_and_is_master(params[:property_id],"Floor Plans",1)
    document = Document.attach_files_for_suites(data,@note.id,current_user_id,lease_folder.try(:id),suiteid)
    shared_document_for_lease(lease_folder,document) if lease_folder.present? && document.present?
    #for docs end
  end

  def temp_method_for_pipeline
    new_suite
    interested_and_negotiated_leases(params[:property_id],($page1.present?) ? $page1.to_i : 1,($page.present?) ? $page.to_i : 1)
    @portfolio = @portfolio_collection
    @portfolio_index = true
    @notes = RealEstateProperty.find_owned_and_shared_properties(@portfolio_collection,current_user.id,true)
    find_folder_and_lease_agents
    responds_to_parent do
      render :update do |page|
        @new_suite = @note.suites.new
        page.replace_html  "pipeline_attachment", :partial => "/lease/property_pipeline", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
        page.call "flash_writter", "#{FLASH_MESSAGES['leases']['112']}"
      end
    end
  end
  #for pipeline approved lease attachments end


  def tenant_create_or_update
    if !params[:lease_id].blank?
      tenant = Tenant.find(params[:tenant_id])
      tenant.update_attributes(:tenant_legal_name => params[:value])
      # tenant.property_lease_suite.update_attributes(:updated_at=>Time.now)
    else
      @new_lease = @note.interested_prospects_leases.create(:commencement=> '',:activity_date=> '', :expiration=> '',:is_executed=>false, :is_approval_requested=>false, :is_archived=> false, :status=> 'Active')
      @new_tenant = Tenant.create(:tenant_legal_name=> params[:value])
      @prop_leas_suite = @new_lease.create_property_lease_suite(:tenant_id=>@new_tenant.id, :suite_ids => params[:suite_ids].to_i.to_a)
      #~ if !params[:notes].empty?
      #~ @new_suite.build_note(:content => params[:notes])
      #~ @new_suite.save
      #~ end
      @check_var = true
    end
    ajax_page_refresh_method
  end

  def lease_create_or_update
    if !params[:lease_id].blank?
      lease = Lease.find(params[:lease_id])
      lease.update_attributes(:commencement => Date.parse(params[:value])) if params[:name] == "commencement"
      lease.update_attributes(:expiration => Date.parse(params[:value])) if params[:name] == "expiration"
      lease.update_attributes(:effective_rate => params[:value]) if params[:name] == "effective_rate"
      lease.update_attributes(:activity_status => params[:value]) if params[:name] == "activity_status"
      lease.update_attributes(:activity_date => Date.parse(params[:value])) if params[:name] == "activity_date"
      lease.update_attributes(:basic_rentable_sqft => params[:value]) if params[:name] == "rent"
       (lease && lease.note) ? lease.note.update_attributes(:content => params[:value]) : lease.create_note(:content => params[:value]) if params[:name] == "content"

      if ( lease && lease.cap_ex.nil? && params[:name] == "ti")
        cap_ex = lease.create_cap_ex
        ti = cap_ex.tenant_improvements.create(:amount_psf => params[:value])
      elsif (lease && lease.cap_ex && lease.cap_ex.tenant_improvements.blank?  && params[:name] == "ti" )
        ti1=  lease.cap_ex.tenant_improvements.create(:amount_psf => params[:value])
      else
        ti2 = lease.cap_ex.tenant_improvements.first.update_attributes(:amount_psf => params[:value])  if params[:name] == "ti"
      end
      # lease.property_lease_suite.update_attributes(:updated_at=>Time.now)
      ajax_page_refresh_method
    else
      render:nothing => true
    end

  end


  def edit_lease
    #~ proprty_lease_suite = PropertyLeaseSuite.find_by_lease_id(params[:id])
    #~ suite_ids = proprty_lease_suite.suite_ids - params[:suite_id].to_i.to_a
    #~ proprty_lease_suite.update_attributes(:suite_ids=>suite_ids)
    lease = Lease.find_by_id(params[:id])
    if (params[:user_action] == 'execute')
      lease.update_attributes(:is_executed=>true,:status=>"Active",:is_approval_requested=>false)
      ajax_page_refresh_method
    elsif (params[:user_action] == 'status_inactive')
      lease.update_attributes(:status=>"Inactive",:is_executed=>true,:is_approval_requested=>false)
      ajax_page_refresh_method
    elsif (params[:user_action] == 'approve')
      lease.property_lease_suite.update_attributes(:updated_at => Time.now)
      lease.update_attributes(:is_approval_requested=>true)
      ajax_page_refresh_method
    elsif ((params[:form_page] =='interested_suite' || params[:form_page] =='negotiated_suite') && params[:user_action] == 'archieve')
      lease.update_attributes(:is_archived=>true)
      ajax_page_refresh_method
    elsif (params[:form_page] =='lease_suite' && params[:user_action] == 'archieve')
      lease.update_attributes(:is_archived=>true)
      $mgmt_page = (params[:mgmt] == 'true') ? params[:page] : (params[:action] == 'edit_lease') ? $mgmt_page.to_i : 1
      @property_lease_suites = @pdf ? Lease.executed_leases_method(params[:property_id],params[:search_txt]) : Lease.executed_leases_method(params[:property_id],params[:search_txt]).paginate(:per_page=>25,:page=>$mgmt_page)
      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "show_assets_list", :partial => "/lease/management", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
            page.call "flash_writter", "#{FLASH_MESSAGES['leases']['113']}"
          end
        }
      end
    end
  end

  def destroy
    find_lease_id
    lease = @lease.destroy
    vaca = Suite.where("suite_no is not null and real_estate_property_id=? and status =?",params[:property_id],'vacant').map(&:suite_no)
    occu = occupied_suite_calcs(params[:property_id]).map(&:suite_no)
    @vacant_and_occupied_suites = (vaca + occu).uniq
    find_folder_and_lease_agents
    if (params[:form_page] =='lease_suite')
      $mgmt_page = (params[:mgmt] == 'true') ? params[:page] : $mgmt_page.present? ? $mgmt_page.to_i : 1
      if params[:selected_value] == "Inactive Leases"
        @archeived_sort_val= Lease.executed_leases_archeived_method(params[:property_id])
        @property_lease_suites = @pdf ? @archeived_sort_val.compact : @archeived_sort_val.compact.paginate(:per_page=>25,:page=>$mgmt_page)
      else
        if @pdf && !params[:search_txt].present? #included for print PDF
          params[:search_txt] = nil
        end
        @a = Lease.executed_leases_method(params[:property_id],params[:search_txt])
        @property_lease_suites = @pdf ?  @a.compact : @a.compact.paginate(:per_page=>25,:page=>$mgmt_page)
      end
      #~ @property_lease_suites = @pdf ? Lease.executed_leases_method(params[:property_id],params[:search_txt]) : Lease.executed_leases_method(params[:property_id],params[:search_txt]).paginate(:per_page=>25,:page=>$mgmt_page)

      respond_to do |format|
        format.js {
          render :update do |page|
            page.replace_html  "show_assets_list", :partial => "/lease/management", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
            page.call "flash_writter", "#{FLASH_MESSAGES['leases']['114']}"
          end
        }
      end
    elsif (params[:form_page] =='negotiated_suite' || params[:form_page] =='interested_suite')
      interested_and_negotiated_leases(params[:property_id],($page1.present?) ? $page1.to_i : 1,($page.present?) ? $page.to_i : 1)
      respond_to do |format|
        format.js {
          render :update do |page|
            @new_suite = @note.suites.new
            page.replace_html  "lease_container", :partial => "/lease/property_pipeline", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
            page.call "flash_writter", "#{FLASH_MESSAGES['leases']['114']}"
          end
        }
      end
    end
  end

  def item_destroy
    @item = Item.find(params[:id])
    @item.destroy
    #~ @lease = Lease.find(11)
    #~ @clause = @lease.clause.blank? ? @lease.build_clause : @lease.clause
    #~ @items_count = @clause.items
    render:nothing => true
  end


  #To display pipeline details for Leasing Agent
  def show_pipeline

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

    @note = RealEstateProperty.find_real_estate_property(params[:id])
    @reset_selected_item = false
    new_suite
    interested_and_negotiated_leases(params[:id],($page1.present?) ? $page1.to_i : 1,($page.present?) ? $page.to_i : 1)
    vaca = Suite.where("suite_no is not null and real_estate_property_id=? and status =?",params[:id],'vacant').map(&:suite_no)
    occu = occupied_suite_calcs(params[:id]).map(&:suite_no)
    @vacant_and_occupied_suites = (vaca + occu).uniq
    if params[:id] && @note
      @portfolio = @note.portfolio
      @portfolios = Portfolio.find_shared_and_owned_portfolios(User.current.id)
      @notes = RealEstateProperty.find_owned_and_shared_properties(@portfolio,User.current.id,params[:prop_folder])
      @folder , @lease_agents = RealEstateProperty.find_lease_agents(params[:id],current_user.id)
    elsif @note.nil?
      @portfolios = Portfolio.find_shared_and_owned_portfolios(User.current.id)
      @portfolio = @portfolios.first if @portfolios && !@portfolios.empty?
      @notes = RealEstateProperty.find_owned_and_shared_properties(@portfolio,User.current.id,params[:prop_folder])
      @note = @notes.first if !@notes.empty?
      @folder , @lease_agents = RealEstateProperty.find_lease_agents(params[:id],current_user.id)
    end
    show_err_msg_if_no_access
  end

  #Creates PDF for pipeline,encumbrance,management pages
  def lease_pdf
    @content_to_render = ""
    @pdf  =  true
    @pdf_convn_path = Rails.root.to_s+'/public'
    @note_name = @note.property_name
    @property_address = @note.get_property_address(@note.address)
    @property_image = @note.try(:portfolio_image)
    @pdf_convn_path = Rails.root.to_s+'/public'
    if params[:partial_page] == 'property_pipeline'
      ajax_page_refresh_method
      page_title = "Pipeline"
    elsif params[:partial_page] == 'property_encumb'
      encumbrance
      page_title = "Encumbrance"
    elsif params[:partial_page] == 'management'
      management
      page_title = "Management"
    end
    insert_heading_in_lease(page_title,@note_name)
    @content_to_render << "<div style=\"margin-left:50px;margin-top:17px;\">"
    @content_to_render << render_to_string(:template=>"/lease/#{params[:partial_page]}Pdf.html.erb").gsub('href','vhref').gsub('onclick','vonclick')
    append_end_div
    @content_to_render << "</div>"
    headers["Content-Type"] = "application/octet-stream"
    headers["Content-Disposition"] = "attachment; filename=\"#{@note_name}\""
    render :pdf => "#{@note_name}",:layout => '/layouts/_user_pdf.html.erb', :template=>'/performance_review_property/all_tabs_Pdf.html.erb', :footer => {:left=>'[page]', :right =>"Powered by AMP", :font_size => 7},:margin=>{:top=>5, :bottom=>10, :left=>10, :right=>10},:page_size=>'A4'
  end

  def get_partial_title(partial)
    @partial_pages = []
    if partial.present?
      if params[:partial_page] == 'management'
        @partial_pages << "Management"
      elsif params[:partial_page] == 'property_encumb'
        @partial_pages << "Property Encumbrance"
      elsif  params[:partial_page] == 'property_pipeline'
        @partial_pages << "Property Pipeline"
      end
    end
    @partial_pages
  end


  #To Create PDF in Abstract view
  def lease_export_pdf

  end

  #To create PDF for all tabs
  def  lease_export_pdf_all_tabs
    @pdf_loop = 0
    @content_to_render = ""
    @pdf  =  true
    @note_name = @note.property_name
    @property_image = @note.try(:portfolio_image)
    @property_address = @note.get_property_address(@note.address)
    @pdf_convn_path = Rails.root.to_s+'/public'
    find_lease_id
    if params[:partial_pages] && !params[:partial_pages].empty?
      get_partial_titles(params[:partial_pages])
      @number_of_loop =0
      @tenant_legal_name = find_tenant_legal_name        if params[:lease_id] && params[:lease_id] !='undefined' && !params[:lease_id].nil? && params[:lease_id].present? && !params[:lease_id].blank?
      @tenant_legal_name_display = @tenant_legal_name && @tenant_legal_name != '' && !@tenant_legal_name.nil? ? "#{@tenant_legal_name}" : ''
      render_partial_for_pdf_header('pdf_header','')
      params[:partial_pages].split(',').each do |partial_page|
        @number_of_loop += 1
        lease_tab_data_push  if params[:lease_id] && params[:lease_id] !='undefined' && !params[:lease_id].nil? && params[:lease_id].present?
        if partial_page == '1'
          terms
          render_partial_for_pdf('mgmt_head_tabsPdf','Terms')
        elsif partial_page == '2'
          render_partial_for_pdf('mgmt_rentPdf','Rent')
        elsif partial_page == '6'
          render_partial_for_pdf('mgmt_clausesPdf','Clauses')
        elsif partial_page == '5'
          render_partial_for_pdf('mgmt_insurancePdf','Insurance')
        elsif partial_page == '4'
          @income_projection =  @lease.income_projection
          income_projection_calculations(@lease.id)
          render_partial_for_pdf('mgmt_projectionPdf','Income Projection')
        elsif partial_page == '7'
          doc_data_push
          render_partial_for_pdf('mgmt_docsPdf','Docs')
        elsif partial_page == '3'
          render_partial_for_pdf('mgmt_cap_expPdf','CapEx & Dep')
        end
        @pdf_loop += 1
      end
    end
    headers["Content-Type"] = "application/octet-stream"
    headers["Content-Disposition"] = "attachment; filename=\"#{@note_name}\""
    render :pdf => "#{@note_name}",:layout => '/layouts/_user_pdf.html.erb', :template=>'/performance_review_property/all_tabs_Pdf.html.erb', :footer => {:left=>'[page]', :right =>"Powered by AMP", :font_size => 7},:disable_javascript => false,:margin=>{:top=>5, :bottom=>10, :left=>10, :right=>10},:page_size=>'A4'
  end




  #Insert Heading for PDF
  def insert_heading_in_lease(title,heading)
    padding =(title == 'Clauses' || title == 'Terms' || (@pdf_loop == 0 && (params[:param_pipeline] == "nego_pipeline" || params[:param_pipeline] == "inters_pipeline"))) ? "padding-right:100px;" : ""
    logo_img,company_name =  find_logo_and_company_name
    @content_to_render <<  "<div class=\"pdf_break_page\" style=\"float:left;margin-top:7px;\"><div style=\"z-index:18900;margin-bottom: 0px;padding-bottom: 10px;border-bottom: none;\"><div id=\"page\" style=\"margin-left: 50px;\"> <img src=\"#{ Rails.root}/public/images/header-inner-bg.png\" style=\"position:absolute; top:0px; height:94px; width:100%; \"/> <div id=\"header-inner\"><div align=\"center\" style=\"font-family: Arial,Helvetica,sans-serif; padding: 46px 0pt 0pt;\"><div style=\"font-size: 14px; padding-bottom: 5px; font-weight: bold;\">#{heading}</div><div>#{title}</div><div style=\"float: right; padding-right: 15px; font-size: 11px; margin-top: -14px;\">#{APP_CONFIG[:main_url]}</div></div><div class=\"logoDiv-inner\"><img align=\"left\" src=\"#{@pdf_convn_path}#{logo_img}\"  width=\"73\" height=\"68\" /><div class=\"company-name\">#{company_name}</div></div></div></div>"
  end

  #To append div in last
  def  append_end_div
    @content_to_render << "</div></div>"
  end

  #To render partial for PDF
  def render_partial_for_pdf(partial,title)
    insert_heading_in_lease(title,"Property: #{@note_name}") if @number_of_loop.nil? || (@number_of_loop && @number_of_loop != 0)
    find_prop_div_disp_lease_suites
    @content_to_render << "<div style=\"margin-left:50px;margin-top:17px;\">"
    @content_to_render << render_to_string(:template=>"/lease/#{partial}.html.erb").gsub('href','vhref').gsub('onclick','vonclick')
    append_end_div
    @content_to_render << "</div>"
  end

  #To render partial for PDF Header
  def render_partial_for_pdf_header(partial,title)
    @content_to_render <<  "<div class=\"pdf_break_page\" style=\"float:left;width:100%;\"><div style=\"z-index:18900;margin-bottom: 0px;padding-bottom: 10px;border-bottom: none;\"><span style=\"font-size: 13px ! important; font-weight: bold; color: rgb(0, 0, 0) ! important;\">#{title}</span><div class=\"lebredcomsright\" ><div style=\"font-size: 13px ! important; font-weight: bold; color: rgb(0, 0, 0) ! important; line-height: 20px;padding-bottom: 10px;\"></div></div>"
    @content_to_render << render_to_string(:template=>"/lease/pdf_header.html.erb").gsub('href','vhref').gsub('onclick','vonclick')
    append_end_div
  end


  def find_prop_div_disp_lease_suites
    if params[:param_pipeline] == "inters_pipeline"  || params[:param_pipeline] == "nego_pipeline"
      interested_and_negotiated_leases(@note.id,($page1.present?) ? $page1.to_i : 1,($page.present?) ? $page.to_i : 1)
      @property_lease_suites_all = (params[:param_pipeline] == "inters_pipeline") ? @property_lease_suites_interested : (params[:param_pipeline] == "nego_pipeline") ? @property_lease_suites_negotiated : ""
    end
  end


  def getting_started
  end

  def vacant_occupied_suites
    @vacant_suites = Suite.where("suite_no is not null and real_estate_property_id IN (?) and status =?",params[:propertyid],'vacant').order("CAST(suite_no AS SIGNED)ASC")  if params[:item] == 'vacant_suites'
    if (params[:item] == 'occupied_suites' && params[:propertyid].present?)
      @interested_six_mnth_suites = params[:from_dash_portfolio].present? ? Lease.portfolio_six_mnth_expirations_leases(params[:propertyid]) : Lease.six_mnth_expirations_leases(params[:propertyid])
      #~ @occupied_suites_six_mnth = @interested_six_mnth_suites.map(&:suite_ids).flatten.compact
      #~ @occupied_suites = Suite.find(:all, :conditions=>["id IN (?)", @occupied_suites_six_mnth])
    end
  end

  #To change the is_getting_started_closed field in real_estate_properties table to 1
  def close_getting_started
    RealEstateProperty.change_is_closed(params[:property_id])
    render :nothing=>true
  end


  def get_suite_details

    suite = Suite.find_by_suite_no_and_real_estate_property_id(params[:suite_no], params[:property_id])

    suite_status = suite.try(:status).present? ? suite.try(:status) : "vacant"

    respond_to do |format|
      format.json do
        render :json =>{:suite_no => suite.try(:suite_no), :rentable_sqft => suite.try(:rentable_sqft), :floor => suite.try(:floor), :usable_sqft => suite.try(:usable_sqft), :status => suite_status, :note => suite.try(:note).try(:content)}.to_json
      end
    end
  end

  def get_suite_rentable_sqft
    sqft_total = 0
    suite_status = ""
    suite_numb_arr = params[:suite_nos].split(',').uniq
    suite_numb_arr = suite_numb_arr.delete_if{|q| q.strip.length==0}
    suite_numb_arr = suite_numb_arr.map{|q| q.strip}
    if suite_numb_arr.blank?
      suite_status = "Vacant"
    end
    suite_numb_arr.each do |suite_no|
      suite = Suite.find_by_suite_no_and_real_estate_property_id(suite_no, params[:property_id])
      sqft_total = sqft_total + suite.try(:rentable_sqft).to_f  if !suite.nil?
      if suite.try(:status).present?
        suite_status << "#{suite.try(:status)}#{(suite_no == suite_numb_arr.last) ? '' : ', '}"
      else
        suite_status << "NA#{(suite_no == suite_numb_arr.last) ? '' : ', '}"
      end
    end
    respond_to do |format|
      format.json do
        render :json =>{:suite_nos_uniq => suite_numb_arr.join(','),:sqft_total => sqft_total, :statuses=> suite_status}.to_json
      end
    end
  end


  def rent_sch_total_calc
    psf_per_month,tot_amt = 0.0,0.0
    if(params[:suite_id].nil? || params[:suite_id].eql?('nil'))
      rent_sqft = Suite.find_all_by_id_and_real_estate_property_id(params[:suite_array], params[:property_id]).map(&:rentable_sqft).sum
    else
      suite = Suite.find_by_id_and_real_estate_property_id(params[:suite_id], params[:property_id])
      rent_sqft = suite.try(:rentable_sqft )
    end
    if params[:rent_type].eql?('rent_sch_tot_amt_calc') || params[:rent_type].eql?('other_revenue_tot_calc')
      rent_sqft = rent_sqft.nil? ? 1 : rent_sqft
      tot_amt = params[:psf_or_tot_amt].present? ? params[:psf_or_tot_amt].gsub(',','').to_f*rent_sqft : ''
    else
      rent_sqft = rent_sqft.nil? ? 1 : rent_sqft
      psf_per_month = params[:psf_or_tot_amt].present? ? params[:psf_or_tot_amt].gsub(',','').to_f / rent_sqft : ''
    end
    respond_to do |format|
      format.json do
        render :json =>{:psf_per_month => psf_per_month,:tot_amt => tot_amt, :psf_id => params[:cur_id],:rent_type => params[:rent_type]}.to_json
      end
    end
  end


  #   For rent schedule auto calculation latest
  def new_rent_sch_total_calc
    psf_per_month,tot_amt = 0.0,0.0
    if(params[:rent_type].eql?('same_rent_sch_tot_amt_calc') || params[:rent_type].eql?('same_rent_sch_psf_calc'))
      prop_lease_suite = PropertyLeaseSuite.find_by_lease_id_and_tenant_id(params[:lease_id],params[:tenant_id])
      suite_ids = prop_lease_suite.suite_ids || []
      rent_sqft = Suite.find_all_by_id_and_real_estate_property_id(suite_ids, params[:property_id]).map(&:rentable_sqft).sum
      rent_sqft = rent_sqft.nil? ? 1 : rent_sqft
      if params[:rent_type].eql?('same_rent_sch_tot_amt_calc')
        tot_amt = params[:psf_or_tot_amt].present? ? params[:psf_or_tot_amt].gsub(',','').to_f*rent_sqft : ''
      elsif params[:rent_type].eql?('same_rent_sch_psf_calc')
        psf_per_month = params[:psf_or_tot_amt].present? ? params[:psf_or_tot_amt].gsub(',','').to_f / rent_sqft : ''
      end
    elsif(params[:rent_type].eql?('diff_rent_sch_tot_amt_calc') || params[:rent_type].eql?('diff_rent_sch_psf_calc'))
      suite = Suite.find_by_suite_no_and_real_estate_property_id(params[:suite_no], params[:property_id])
      rent_sqft = suite.try(:rentable_sqft )
      if params[:rent_type].eql?('diff_rent_sch_tot_amt_calc')
        tot_amt = params[:psf_or_tot_amt].present? ? params[:psf_or_tot_amt].gsub(',','').to_f*rent_sqft : ''
      elsif params[:rent_type].eql?('diff_rent_sch_psf_calc')
        psf_per_month = params[:psf_or_tot_amt].present? ? params[:psf_or_tot_amt].gsub(',','').to_f / rent_sqft : ''
      end
    end
    respond_to do |format|
      format.json do
        render :json =>{:psf_per_month => psf_per_month,:tot_amt => tot_amt, :psf_id => params[:cur_id],:rent_type => params[:rent_type],:suite_no => params[:suite_no]}.to_json
      end
    end
  end


  def rent_sch_persft_total_calc
    #~ suite = Suite.find_by_id_and_real_estate_property_id(params[:suite_id], params[:property_id])
    rent_sqft = suite.try(:rentable_sqft )
    rent_sqft = rent_sqft.nil? ? 1 : rent_sqft
    per_month = params[:per_month].present? ? params[:per_month].to_i : 0
    total_amt = per_month * rent_sqft
    respond_to do |format|
      format.js {
        render :update do |page|
          if(total_amt.eql?(0.0) || total_amt.eql?(0))
            page << "jQuery('#lease_rent_attributes_rent_schedules_attributes_#{params[:tot_amt_id]}_amount_per_month').val("");"
          else
            page << "jQuery('#lease_rent_attributes_rent_schedules_attributes_#{params[:tot_amt_id]}_amount_per_month').val(#{total_amt});"
          end
        end
      }
    end
  end

  def rent_revenue_total_calc
    #~ suite = Suite.find_by_id_and_real_estate_property_id(params[:suite_id], params[:property_id])
    rent_sqft = suite.try(:rentable_sqft )
    rent_sqft = rent_sqft.nil? ? 1 : rent_sqft
    per_month = params[:per_month].present? ? params[:per_month].to_i : 0
    total_amt = per_month * rent_sqft
    respond_to do |format|
      format.js {
        render :update do |page|
          if(total_amt.eql?(0.0) || total_amt.eql?(0))
            page << "jQuery('#lease_rent_attributes_other_revenues_attributes_#{params[:tot_amt_id]}_amount_per_month').val("");"
          else
            page << "jQuery('#lease_rent_attributes_other_revenues_attributes_#{params[:tot_amt_id]}_amount_per_month').val(#{total_amt});"
          end
        end
      }
    end
  end

  def rent_persft_total_calc
    #~ suite = Suite.find_by_id_and_real_estate_property_id(params[:suite_id], params[:property_id])
    rent_sqft = suite.try(:rentable_sqft )
    rent_sqft = rent_sqft.nil? ? 1 : rent_sqft
    per_month = params[:per_month].present? ? params[:per_month].to_i : 0
    total_amt = per_month * rent_sqft
    respond_to do |format|
      format.js {
        render :update do |page|
          if(total_amt.eql?(0.0) || total_amt.eql?(0))
            page << "jQuery('#lease_rent_attributes_other_revenues_attributes_#{params[:tot_amt_id]}_amount_per_month').val("");"
          else
            page << "jQuery('#lease_rent_attributes_other_revenues_attributes_#{params[:tot_amt_id]}_amount_per_month').val(#{total_amt});"
          end
        end
      }
    end
  end


  def get_property_suite_details
    suite_id = params[:suite_id].to_i
    @property_lease_suites = PropertyLeaseSuite.all.map(&:suite_ids).flatten.compact.uniq
    if @property_lease_suites.include?(suite_id)
      @tenants = []
      @property_lease_suites_array =[]
      PropertyLeaseSuite.all.each do |pls|
        if pls.suite_ids.present?
          suite_ids = pls.suite_ids
          suite_ids = [suite_ids]  if suite_ids.kind_of?(String) || suite_ids.kind_of?(Integer)
          if suite_ids.include?(suite_id)
            tenant  = Tenant.find_by_id(pls.tenant_id)
            @tenants << tenant.tenant_legal_name if tenant.present? && tenant.tenant_legal_name?
          end
        end
      end
    end
    msg = ""
    if @tenants.present?
      @tenants = @tenants.uniq.join(",")
      msg = "To delete this suite, please delete the lease/prospect which has the '#{@tenants}' details."
    end
    respond_to do |format|
      format.json do
        render :text => msg
      end
    end
  end

  def month_calc
    if params[:exp_date].present? && params[:comm_date].present? && params[:exp_date].match(/\d{2}\/\d{2}\/\d{4}/) && params[:comm_date].match(/\d{2}\/\d{2}\/\d{4}/)
      to_date = params[:exp_date]
      from_date = params[:comm_date]
      replace_month = "#{RentSchedule.get_rent_schedule_period(from_date, to_date)} Month(s)"
    else
      replace_month = "0 Month(s)"
    end
    respond_to do |format|
      format.json do
        render :json => {:text => replace_month}
      end
    end
  end

  def delete_suite
    suite = Suite.find_by_suite_no_and_real_estate_property_id(params[:suite_no], params[:property_id])
    suite_id = suite.try(:id)
    lease = Lease.find_by_id(params[:lease_id].to_i)
    is_all_suite_selected = nil
    if suite_id.present?
      prop_lease_suites = lease.try(:property_lease_suite).try(:suite_ids)
      lease.property_lease_suite.update_attributes(:suite_ids => (prop_lease_suites - suite_id.to_a ))
      suite.update_attribute(:status, "vacant")
      tenant_id = lease.try(:tenant).try(:id)
      comm_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(suite_id,lease.try(:id),tenant_id)
      comm_prop.delete if comm_prop.present?
      is_all_suite_selected = lease.try(:rent).try(:is_all_suites_selected)
      if(!is_all_suite_selected)
        rent_sch_coll = RentSchedule.where(:suite_id => suite_id)
        rent_sch_coll.destroy_all if rent_sch_coll.present?
      end
    end
    respond_to do |format|
      format.json do
        render :json => {:suite_no => params[:suite_no],:is_all_suite_selected => is_all_suite_selected}
      end
    end
  end

  #Dsiplays stacking plan
  def stacking_plan
    stacking
    @portfolio =  @portfolio_collection
  end

  #For http call from js
  def stacking
    @displayed_suites = []
    suite_ids =[]
    property_lease_suites = Lease.executed_leases_method(params[:property_id],params[:search_txt])
    #~ executed_leases=leases.collect{|property_lease_suite|   if !is_expired_lease(property_lease_suite)}
    property_lease_suites && property_lease_suites.each do |property_lease_suite|
     suite_ids <<property_lease_suite.suite_ids if !is_expired_lease(property_lease_suite)
  end
    executed_leases = Suite.where(:id => suite_ids.flatten.uniq) || []
    suites = Suite.find(:all,:conditions=>['status = ? and real_estate_property_id = ?','Vacant',params[:property_id]])
    suites = suites + executed_leases			
    if suites && !suites.empty?
      @suites_without_floor =  suites.flatten.compact.map{|suite| suite if !suite.floor? || suite.floor.eql?(nil)}.compact
      @suites = suites.flatten.compact.map{|suite| suite if suite.present? && suite.floor? && !suite.floor.eql?(nil) && !suite.floor.eql?("")}.compact.sort_by(&:floor).reverse
      @floors = []
      floors =  Suite.find(:all,:conditions=>['real_estate_property_id = ?',params[:property_id]],:order=>('CAST(floor AS SIGNED) DESC')).map(&:floor).uniq
      if floors.include?("")
        val_index = floors.index("")
        floors[val_index] = nil
      end
      floors.uniq.each do |floor_check|
        @floors << floor_check
      end
    end
  end

  def stacking_plan_expanded
    @notes = RealEstateProperty.find_owned_and_shared_properties(@portfolio_collection,User.current.id,params[:prop_folder])
    if @notes.map(&:id).compact.include?(params[:property_id].to_i)
      stacking_plan
    else
      flash[:notice]=FLASH_MESSAGES['portfolios']['508']
      redirect_to  portfolios_path
    end
  end



  def change_rent_sch
    @lease = Lease.find_by_id(params[:lease_id])
    rent_sch = RentSchedule.where(:rent_id => @lease.try(:rent).try(:id))
    rent_sch.destroy_all if rent_sch.present?
    if @lease.present? && @lease.try(:rent) && @lease.try(:rent).try(:id)
      @lease.rent.update_attributes(:is_all_suites_selected => params[:cur_type], :is_cpi_escalation => params[:is_cpi_escalation_selected] )
    elsif @lease.present?
      Rent.create(:lease_id => params[:lease_id], :is_all_suites_selected => params[:cur_type], :is_cpi_escalation => params[:is_cpi_escalation_selected] )
    end
    if params[:is_cpi_escalation_selected] != 'true'
      cpi_details = @lease.try(:rent).try(:cpi_details)
      cpi_details.destroy_all if cpi_details.present?
    end
    @lease = Lease.find_by_id(params[:lease_id])
    lease_tab_data_push
    if( params[:cur_type].eql?('false') && params[:is_cpi_escalation_selected].eql?('true'))
      suite_ids = PropertyLeaseSuite.find_by_lease_id(params[:lease_id]).try(:suite_ids)
      suite_ids.each do |i|
        RentSchedule.create(:suite_id => i,:rent_id => @lease.try(:rent).try(:id))
      end
    end
    @lease = Lease.find_by_id(params[:lease_id])  if( params[:cur_type].eql?('false') || params[:is_cpi_escalation_selected].eql?('true'))
  end

  #---------------------------------Private Methods------------------------------------------------------------------------------------------------------------------------------------------------

  private

  def replace_partial_method(container,partial)
    respond_to do |format|
      format.js {
        render :update do |page|
          page.replace_html  "#{container}", :partial => "/lease/#{partial}"
        end
      }
    end
  end

  def prop_and_port_collection
    @note = params[:property_id] ? RealEstateProperty.find_real_estate_property(params[:property_id]) : (RealEstateProperty.find_real_estate_property(params[:id]))
    @portfolio_collection = params[:portfolio_id] ? Portfolio.find(params[:portfolio_id])  : @note.portfolio
  end

  def find_folder_and_lease_agents
    @folder , @lease_agents = RealEstateProperty.find_lease_agents(params[:property_id],current_user.id)
  end

  def new_suite
    @new_suite = @note.suites.new
  end

  def lease_msg(message,save=nil,partial=nil)
    income_projection_calculations(@lease) if partial.eql?("projection")
    params[:lease_id] = @lease.id if @lease

    #updating lease_id in options table after saved#
    if @lease && @lease.tenant && @lease.tenant.options
      @lease.tenant.options.each do |option|
        option.update_attributes(:lease_id=>@lease.id) if option.present?
      end
    end

    @lease.tenant.info.update_attributes(:lease_id=>@lease.id)   if @lease && @lease.tenant && @lease.tenant.info #updating lease_id in info table after saved#

    unless @pdf
      find_prop_div_disp_lease_suites if params[:frm_name] == 'term_form'
      responds_to_parent do
        render :update do |page|
          page.call "flash_writter", "#{message}" unless params[:trm_exec].eql?("1")
          page<<"jQuery('#term_form').val('true')" if save.present?
          #Removed as Abstract top Bar display is also there
          #~ page.replace_html "tenant_abstract_view","#{abstract_view_title}"
          page.replace_html  "mgmt_tabs", :partial => "/lease/mgmt_abstract_view", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection, :@property_lease_suites_all => @property_lease_suites_all, :@lease => @lease,:lease_collection=> @lease}  if partial.present? && partial != 'rent_schedule'
          property_id = params[:property_id] ? params[:property_id] : @note.id
          page << "update_print_pdf_link(\'#{@portfolio_collection.id}\',\'#{property_id}\',\'#{@lease.id}\',\'#{params[:move_out1]}\',\'#{params[:move_out2]}\',\'#{params[:move_out3]}\',\'#{params[:move_out4]}\',\'#{params[:move_out5]}\',\'#{params[:suite_no1]}\',\'#{params[:suite_no2]}\',\'#{params[:suite_no3]}\',\'#{params[:suite_no4]}\',\'#{params[:suite_no5]}\',\'#{params[:move_in1]}\',\'#{params[:move_in2]}\',\'#{params[:move_in3]}\',\'#{params[:move_in4]}\',\'#{params[:move_in5]}\',\'#{params[:usable_sqft1]}\',\'#{params[:usable_sqft2]}\',\'#{params[:usable_sqft3]}\',\'#{params[:usable_sqft4]}\',\'#{params[:usable_sqft5]}\',\'#{params[:rentable_sqft1]}\',\'#{params[:rentable_sqft2]}\',\'#{params[:rentable_sqft3]}\',\'#{params[:rentable_sqft4]}\',\'#{params[:rentable_sqft5]}\',\'#{params[:floor1]}\',\'#{params[:floor2]}\',\'#{params[:floor3]}',\'#{params[:floor4]}',\'#{params[:floor5]}\',\'#{params[:param_pipeline]}\')"
          show_or_hide_lightbox(message,page)  if params[:from_pdf] == 'true'
        end
      end
    end
  end


  def replace_lease_partial(partial)
    income_projection_calculations(@lease) if partial.eql?("projection")
    params[:lease_id] = @lease.id if @lease
    unless @pdf
      find_prop_div_disp_lease_suites if params[:frm_name] == 'rent_form'
      responds_to_parent do
        render :update do |page|
          if params[:frm_name].eql?('rent_form')
            msg= (params[:on_change_cpi] != 'true' && @lease && @lease.rent  && @lease.rent.cpi_details && @lease.rent.cpi_details.first &&  params[:is_cpi_escalation] !='false' && !params[:is_cpi_escalation].blank? && !@lease.rent.cpi_details.first.valid?) ? "#{FLASH_MESSAGES['leases']['117']}" : "#{FLASH_MESSAGES['leases']['108']}"
            page.call "flash_writter", "#{msg}"
          end
          #Removed as Abstract top Bar display is also there
          #~ page.replace_html "tenant_abstract_view","#{abstract_view_title}"
          page.replace_html  "mgmt_tabs", :partial => "/lease/mgmt_abstract_view", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection, :@property_lease_suites_all => @property_lease_suites_all}
          property_id = params[:property_id] ? params[:property_id] : @note.id
          page << "update_print_pdf_link(\'#{@portfolio_collection.id}\',\'#{property_id}\',\'#{@lease.id}\',\'#{params[:move_out1]}\',\'#{params[:move_out2]}\',\'#{params[:move_out3]}\',\'#{params[:move_out4]}\',\'#{params[:move_out5]}\',\'#{params[:suite_no1]}\',\'#{params[:suite_no2]}\',\'#{params[:suite_no3]}\',\'#{params[:suite_no4]}\',\'#{params[:suite_no5]}\',\'#{params[:move_in1]}\',\'#{params[:move_in2]}\',\'#{params[:move_in3]}\',\'#{params[:move_in4]}\',\'#{params[:move_in5]}\',\'#{params[:usable_sqft1]}\',\'#{params[:usable_sqft2]}\',\'#{params[:usable_sqft3]}\',\'#{params[:usable_sqft4]}\',\'#{params[:usable_sqft5]}\',\'#{params[:rentable_sqft1]}\',\'#{params[:rentable_sqft2]}\',\'#{params[:rentable_sqft3]}\',\'#{params[:rentable_sqft4]}\',\'#{params[:rentable_sqft5]}\',\'#{params[:floor1]}\',\'#{params[:floor2]}\',\'#{params[:floor3]}',\'#{params[:floor4]}',\'#{params[:floor5]}\',\'#{params[:param_pipeline]}\')"
          show_or_hide_lightbox(msg,page)  if params[:from_pdf] == 'true'
        end
      end
    end
  end



  def ajax_page_refresh_method
    $page1 = (params[:nego] == 'true') ? params[:page] : (params[:action] == 'edit_lease' || params[:action] == 'create_suite_and_lease') ? $page1.to_i : 1
    $page = (params[:intr] == 'true') ? params[:page] : (params[:action] == 'edit_lease' || params[:action] == 'create_suite_and_lease') ? $page.to_i : 1
    #~ $page = ((params[:intr] == 'true' || params[:action] == 'edit_lease' || params[:action] == 'destroy') ? params[:page] : 1 )
    new_suite
    vaca = Suite.where("suite_no is not null and real_estate_property_id=? and status =?",params[:property_id],'vacant').map(&:suite_no)
    occu = occupied_suite_calcs(params[:property_id]).map(&:suite_no)
    @vacant_and_occupied_suites = (vaca + occu).uniq
    interested_and_negotiated_leases(params[:property_id],($page1.present?) ? $page1.to_i : $page1=1,($page.present? && @check_var != true) ? $page.to_i : $page=1)
    @portfolio = @portfolio_collection
    @portfolio_index = true
    @notes = RealEstateProperty.find_owned_and_shared_properties(@portfolio_collection,current_user.id,true)
    find_folder_and_lease_agents
    unless @pdf
      unless params[:action] == 'pipeline' || params[:action] == 'edit_lease' || params[:action] == 'update_suite_and_lease'
        responds_to_parent do
          render :update do |page|
            page.call "flash_writter","#{FLASH_MESSAGES['leases']['108']}"  if params[:action] == "create_suite_and_lease"
            page.replace_html  "lease_container", :partial => "/lease/property_pipeline", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
          end
        end
      else
        if params[:action] == 'pipeline' && !params[:selected_value].present?
          render
        else
          render :update do |page|
            page.replace_html  "lease_container", :partial => "/lease/property_pipeline", :locals => {:note_collection => @note, :portfolio_collection => @portfolio_collection}
            #~ replace_navigation_bar(page, @portfolio_collection,@note)
          end
        end

      end
    end
  end


  def income_projection_calculations(lease_id)
    @real_estate_property_id = params[:property_id] ? params[:property_id] : params[:id]
    @portfolio_id = params[:portfolio_id]
    @building_sqft = Suite.get_building_sqft(@real_estate_property_id)
    @lease = Lease.includes(:cap_ex => [:tenant_improvements, :other_exps, :leasing_commissions], :property_lease_suite => {:tenant => [:info, :options]}, :rent => [:rent_schedules, :other_revenues, :percentage_sales_rents, :parkings]).where("leases.id=?",lease_id).try(:first)
    mgmt_lease_details(@lease)
    @rent_schedules_total_amount_per_month_per_sqft = @rent_schedules_total_amount_per_month.to_f/@lease_rentable_sqft  rescue 0 unless @lease_rentable_sqft.eql?(0)
    @percentage_of_building = IncomeProjection.get_percentage_of_building(@lease_rentable_sqft, @building_sqft)
    @net_lease_cash_flow_psf = IncomeProjection.net_lease_cash_flow_psf(@net_lease_cash_flow, @lease_rentable_sqft)
    if @lease.present? && @lease.income_projection.present?
      @income_projection = @lease.income_projection
    else
      @income_projection = IncomeProjection.new
      @income_projection.build_note
    end
  end


  def get_partial_titles(partials)
    @partial_pages = []
    if partials.present?
      partials = partials.split(",")
      partials.each do |partial|
        result = case partial
          when "1"
        "Terms"
          when "2"
        "Rent"
          when "3"
        "CapEx & Dep"
          when "4"
        "Income Projection"
          when "5"
        "Insurance"
          when "6"
        "Clauses"
          when "7"
        "Docs"
        end
        @partial_pages << result
      end
    end
    @partial_pages
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

  protected
  def finding_suite_bp
    suite = Suite.find_by_id_and_real_estate_property_id(params[:suite_id], params[:property_id])
  end

  def finding_lease_bp
    @lease = params[:current_lease_id].present? ? Lease.find_by_id(params[:current_lease_id].to_i) : @lease.update_attributes(params[:lease])
  end

  def finding_lease_id_bp
    find_lease_id if params[:lease_id].present? && !params[:lease_id].eql?('undefined')
  end

  def finding_document_bp
    @document = Document.find(params[:id])
  end

  def check_property_access

    id = params[:id].present? ? params[:id] : params[:property_id].present? ? params[:property_id] : params[:nid].present? ? params[:nid] : @property.present? ? @property.try(:id) : @note.present? ? @note.id : ""

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

end
