class DocumentsController < ApplicationController
  before_filter :user_required , :except=>['upload_doc','scribd_view','share_link_scribd_view','download_file_for_share_link','share_link_view_for_folder']
  layout :documents_change_layout,:except=>['upload_asset_files','view_scribd_image','view_scribd_image_for_public_via_folder']
  #  layout 'user',:except=>['upload_asset_files','view_scribd_image']
  before_filter :find_portfolio_and_document,:only=>['del_or_revert_doc','delete_doc']
  before_filter :find_doc_for_scribd,:only=>['scribd_view','view_scribd_image','share_link_scribd_view']
  before_filter :logout_keeping_session!,:only=>['scribd_view_for_public','scribd_view_with_link','scribd_view_with_link_for_public','view_scribd_image_for_public','view_scribd_image_for_public_via_folder']
  before_filter :find_document,:only=>['scribd_view_for_public','scribd_view_with_link_for_public','view_scribd_image_for_public','view_scribd_image_for_public_via_folder']
  #view for document upload

  def upload_asset_files
    @portfolio = Portfolio.find_by_id(params[:pid])
    @folder = Folder.find_folder(params[:folder_id])
    @user = current_user
  end
  #to upload a document
  def upload_doc
    acc_sys_type = ""
    @user = User.find(params[:user_id])
    User.current = @user
    @portfolio = Portfolio.find(params[:pid])
    @folder = Folder.find(:first,:conditions=> ["id = ?",params[:folder_id]])
    @tmp_doc = Document.new
    @tmp_doc.uploaded_data = params[:flash_ups] ? params[:Filedata] : params[:attachment][:uploaded_data]
    # check exist is used to find out the uploaded file name duplication via single upload.
    # If the file name already exist then take the reference of exist and ask user to replace or rename V.
    @chk_exist = params[:flash_ups] ? nil : Document.find_by_folder_id_and_filename(@folder.id, @tmp_doc.filename,:conditions=>['real_estate_property_id is not null'])
    if !@tmp_doc.temp_path.blank?
      @tmp_doc.folder_id = params[:folder_id]
      @tmp_doc.is_deleted = false
      @tmp_doc.user_id = params[:user_id]
      @tmp_doc.real_estate_property_id = @folder.real_estate_property_id
      real_estate_property = RealEstateProperty.find_by_id(@folder.real_estate_property_id)
      arr = ["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"]
      @real_estate_property = real_estate_property unless arr.include?(real_estate_property.property_name)
      parsing_file_names=["budget", "actual", "capital", "capexp", "rent", "occupancy", "units", "financial", "actual", "leasing","aged","debt"]
      acc_sys_type=AccountingSystemType.find_by_id(@real_estate_property.accounting_system_type_id).try(:type_name) if @real_estate_property.present?
      variance_ecp_files = if (acc_sys_type=="MRI, SWIG" || acc_sys_type=="MRI")
        ['month_budget']
      elsif (acc_sys_type=="Real Page" || acc_sys_type=="AMP Excel")
        ['actual','actuals','financial','financials']
      else
      []
    end
      #~ variance_ecp_files = ["actual","actuals"]
      if @folder && is_parsing_folder(@folder.id) && @tmp_doc.filename.split(".").pop.downcase == "xls" && variance_ecp_files.any?{|chk| @tmp_doc.filename.downcase.include? chk}
         variance_exp_users = @folder.real_estate_property.var_exp_users
         variance_exp_users =  User.find(:all,:conditions=>["id in (?)",variance_exp_users.split(',').compact]) if !variance_exp_users.nil? && !variance_exp_users.blank?
         updated_month = @folder.name
         updated_year = @gr_parent_folder.name.to_i if  @gr_parent_folder
        if variance_exp_users && !variance_exp_users.empty?
           variance_exp_users.each do |var_exp_user|
             UserMailer.delay.variance_explain_request_mail(var_exp_user,@user,@folder.real_estate_property,updated_month,updated_year)
           end
         end
       end
      if is_parsing_folder(@folder.id) && @tmp_doc.filename.split(".").pop.downcase == "xlsx" && parsing_file_names.any?{|chk| @tmp_doc.filename.downcase.include? chk}
        responds_to_parent do
          render :update do |page|
            page.call("flash_writter","#{FLASH_MESSAGES['documents']['1003']}")
            page << "setTimeout('flash_completer();',1500);"
          end
        end
      else
        if params[:is_missing_file]
          create_missing_file(@tmp_doc)
        else
          @tmp_doc.save
          if params[:bulk_upload] == 'true'
            parse_weekly_osr_files(@tmp_doc,User.current.id)
          else
            acc_sys_type=AccountingSystemType.find_by_id(@real_estate_property.accounting_system_type_id) if @real_estate_property.present?
            if (acc_sys_type.type_name=="MRI, SWIG") || (acc_sys_type.type_name=="MRI" && @tmp_doc.filename.include?("month")) || (acc_sys_type.type_name=="MRI" && @tmp_doc.filename.downcase.include?("rent"))
              call_parsing_functions_for_excel(@tmp_doc,User.current.id)
            elsif acc_sys_type.type_name=="Real Page"
              wres_call_parsing_functions_for_excel(@tmp_doc,User.current.id)
            elsif acc_sys_type.type_name=="YARDI V1" || acc_sys_type.type_name.eql?("Griffin_YARDI")
              parse_yardi_rent_roll_files(@tmp_doc,User.current.id)
            else
              amp_parsing_for_excel(@tmp_doc,User.current.id)
            end if ['xls','xlsx'].any?{|chk| chk == @tmp_doc.filename.split('.').last.downcase } && acc_sys_type != ''
          end
          @type = "Document"
          shared_folders_1 = SharedFolder.find(:all,:conditions=>['folder_id = ?',@folder.id])
          @repeat_email = false
          #to restrict the auto sharing inside the property folder
          if @tmp_doc.folder.parent_id !=0
            unless shared_folders_1.empty?
              shared_folders_1.each do |subshared_folders_1|
                if @tmp_doc.filename != "Cash_Flow_Template.xls" && @tmp_doc.filename != "Rent_Roll_Template.xls"
                  @repeat_email = (subshared_folders_1.user.email == @folder.user.email) ? true : false if !@repeat_email
                  SharedDocument.create(:folder_id=>@folder.id,:user_id=>subshared_folders_1.user_id,:sharer_id=> @user.id,:real_estate_property_id=>@folder.real_estate_property_id,:document_id=>@tmp_doc.id)
                end
              end
              SharedDocument.create(:document_id=>@tmp_doc.id,:folder_id=>@tmp_doc.folder_id,:user_id=>@folder.user_id,:sharer_id=>@user.id,:real_estate_property_id=>@folder.real_estate_property_id) if @user.id != @folder.user_id
            end
          end
          Event.create_new_event("upload",@user.id,nil,[@tmp_doc],@user.user_role(@user.id),@tmp_doc.filename,nil)
        end
        assign_params("asset_data_and_documents","show_asset_files" )
        self.current_user = @user
        @type = "Document"
        find_folders_collection_based_on_params
        responds_to_parent do
          render :action => 'upload_doc.rjs'
        end
      end
    else #!@file_upload.temp_path.blank?
      responds_to_parent do
        render :update do |page|
          page.replace_html 'error_display', FLASH_MESSAGES['properties']['405']
        end
      end
    end
  end
  #To Temporarily delete or Undelete a document
  def del_or_revert_doc
    if @document.parsing_done.eql?(nil)
      @msg = FLASH_MESSAGES['documents']['1004']
    else
    @document.update_attributes(:is_deleted=>params[:fn])
    (params[:fn] == 'false') ? Event.create_new_event("restored",current_user.id,nil,[@document],current_user.user_role(current_user.id),@document.filename,nil) : Event.create_new_event("delete",current_user.id,nil,[@document],current_user.user_role(current_user.id),@document.filename,nil)
    action_type = (params[:fn] == 'false') ? "restored" : "deleted"
    shared_folders_1 , sh_documents = @folder.shared_folders , @document.shared_documents
    mail_sent = shared_documents_and_folders_emails(action_type,sh_documents,shared_folders_1)
    UserMailer.delay.send_collab_folder_updates("#{action_type}", current_user, @folder.user, @document.filename, @folder.name,'document',@document) if @folder.user.email != current_user.email && !@repeat_email && !mail_sent
    assign_params("asset_data_and_documents","show_asset_files")
    @msg = params[:fn] == "false" ? FLASH_MESSAGES['documents']['1001'] : @document.filename+" "+FLASH_MESSAGES['documents']['1002']
    find_folder_to_update_page('document',@folder) if @document.user_id != current_user.id
    end
    update_page_after_file_deletion

  end
  #To permanently delete a document
  def delete_doc
    Event.create_new_event("permanent_delete",current_user.id,nil,[@document],current_user.user_role(current_user.id),@document.filename,nil)
    shared_folders_1 , sh_documents = @folder.shared_folders , @document.shared_documents
    mail_sent = shared_documents_and_folders_emails("permanently deleted",sh_documents,shared_folders_1)
    UserMailer.delay.send_collab_folder_updates("permanently deleted", current_user, @folder.user, @document.filename, @folder.name,'document',@document) if @folder.user.email != current_user.email && !@repeat_email && !mail_sent
    @document.document_name.update_attributes(:document_id => nil) if @document.document_name !=nil
    @document.destroy
    assign_params("asset_data_and_documents","show_asset_files" )
    @msg = "#{@document.filename} deleted"
    params[:from_portfolio_summary] == "true" ? update_portfolio_summary : update_page_after_file_deletion
  end
  def download_file
    @user = current_user
    @document = (( current_user.has_role?("Shared User") && session[:role] == 'Shared User' || current_user.has_role?('Asset Manager') ) && params[:list].blank?) ? ((params[:type] == "TaskFile") ? (TaskFile.find_by_id(params[:id])) : (Document.find_by_id(params[:id]))) : ((params[:list] == "shared_list") ? (SharedDocument.find(params[:id]).document) : (Document.find_by_id(params[:id])))
    send_file "#{Rails.root.to_s}/public"+@document.public_filename
    @folder = (@document.folder)
    Event.create_new_event("download",current_user.id,nil,[@document],current_user.user_role(current_user.id),@document.filename,nil)

  end
  def change_filename
    document = Document.find(params[:id])
    filename , d , if_or_else = document.change_attributes(current_user,params)
    @portfolio = document.real_estate_property.portfolio
    if if_or_else
      render :update do |page|
        page.replace "document#{document.id}", :partial=>"properties/document_row", :locals=>{:t=>document,:doc_index=>params[:zindex],:x=>params[:zindex]}
        page.call("flash_writter","File renamed to #{filename}")
      end
    else
      render :update do |page|
        page.call("do_asset_file_update","#{params[:id]}","#{params[:value]}", "#{params[:value]}",d)
      end
    end
  end

  def  share_link_scribd_view
    permalink = "/document/#{params[:permalink]}"
    @document = Document.find_by_permalink(permalink)
    logout_keeping_session!
    unless @document.nil? || @document.is_deleted?
      portfolio = @document.real_estate_property.portfolio
      is_image = find_extension(@document)
      if @document.ipaper_id.eql?(nil) &&  @document.ipaper_access_key.eql?(nil) && is_image == "no"&& current_user.nil?
        redirect_to :controller => 'documents', :action => "scribd_view_with_link_for_public", :user=> "false", :pid => portfolio.id, :document => @document
      elsif @document.ipaper_id.eql?(nil) &&  @document.ipaper_access_key.eql?(nil) && is_image == "no"&& !current_user.nil?
        render :action => "scribd_view_with_link"
      elsif((@document.ipaper_id.eql?(nil) &&  @document.ipaper_access_key.eql?(nil) && is_image == "yes" ))&& current_user.nil?
        redirect_to :controller => 'documents', :action => "view_scribd_image_for_public", :user=> "false", :pid => portfolio.id, :document => @document
      elsif((@document.ipaper_id.eql?(nil) &&  @document.ipaper_access_key.eql?(nil) && is_image == "yes" ))&& !current_user.nil?
        render :action => "view_scribd_image"
      elsif current_user.nil?
        redirect_to :controller => 'documents', :action => "scribd_view_for_public", :user=> "false", :pid => portfolio.id, :document => @document
      else
        render :action => "scribd_view"
      end
    else
      flash[:error] = FLASH_MESSAGES['user']['105']
      redirect_to login_path
    end
    #    render :nothing => true, :layout => true

  end

  def share_link_view_for_folder
    folder = Folder.find_by_permalink("/folder_share/#{params[:permalink]}")
    logout_keeping_session!
    unless folder.nil? || folder.is_deleted?
      portfolio = folder.portfolio
      if portfolio.name == 'portfolio_created_by_system_for_deal_room' && current_user.nil?
        redirect_to :controller => 'transaction', :action => "share_link_folder_for_trans",:deal_room => 'true',:pid=> portfolio.id ,:folder_id=>folder.id,:shared_link_folder => 'true', :user => 'false'
      elsif portfolio.name == 'portfolio_created_by_system_for_deal_room' && !current_user.nil?
        redirect_to :controller => 'transaction',:deal_room => 'true',:pid=> portfolio.id ,:folder_id=>folder.id,:shared_link_folder => 'true'
      elsif portfolio.name != 'portfolio_created_by_system_for_deal_room' && current_user.nil?
        redirect_to :controller => 'collaboration_hub', :action => "share_link_folder_for_coll",:pid=> portfolio.id ,:folder_id=>folder.id,:shared_link_folder => 'true', :user => 'false'
      else
        redirect_to :controller => 'collaboration_hub',:pid=> portfolio.id ,:folder_id=>folder.id,:shared_link_folder => 'true'
      end
    else
      flash[:error] = FLASH_MESSAGES['user']['105']
      redirect_to login_path
    end
  end

  def scribd_view
    logout_keeping_session! if params[:user] == 'false'
    @portfolio = @document.folder.portfolio
    @note = @document.folder.property
  end
  def scribd_view_for_public
    #~ logout_keeping_session!
    #~ @document = Document.find params[:document]
    render :action => "scribd_view"
  end
  def  scribd_view_with_link
    #~ logout_keeping_session!
    @portfolio = @document.folder.portfolio
    @note = @document.folder.property
  end
  def  scribd_view_with_link_for_public
    #~ logout_keeping_session!
    #~ @document = Document.find params[:document]
    render :action => "scribd_view_with_link"
  end
  def download_file_for_share_link
    @document = Document.find_by_id(params[:id])
    send_file "#{Rails.root.to_s}/public"+@document.public_filename
  end
  def view_scribd_image
  end
  def view_scribd_image_for_public
    #~ logout_keeping_session!
    #~ @document = Document.find params[:document]
    #    render :action => "view_scribd_image"
  end
  def view_scribd_image_for_public_via_folder
    #~ logout_keeping_session!
    #~ @document = Document.find params[:document]
    render :action => "view_scribd_image"
  end
  def find_portfolio_and_document
    @portfolio , @document = Portfolio.find(params[:pid]) , Document.find(params[:doc_id])
    @folder = @document.folder
  end
  def  find_doc_for_scribd
    @document = Document.find_by_id(params[:id])
  end

  def reload_parsing_status
    doc=Document.find(params[:doc_id])
    html_data=if doc.parsing_done==nil
      "<span style='color: #0000ff;font-weight: bold;', id='reload_#{doc.id}'>&nbsp;&nbsp;&nbsp;&nbsp;In Progress</span>"
    elsif doc.parsing_done==false
      "<span style='color: #f63e3e;font-weight: bold;', id='reload_#{doc.id}'>&nbsp;&nbsp;&nbsp;&nbsp;Upload failed. Try again</span>"
    else
      ""
    end
    render :update do |page|
      page.replace_html "reload_#{doc.id}", raw(html_data)
      unless doc.parsing_done==nil
        page.call "remove_reload_link", doc.id
      end
    end
  end

  def show_parsing_logs
    rp = RealEstateProperty.find_real_estate_property(params[:id])
    logs = rp.blank? ? [] : ParsingLog.find_by_sql("select pl.*,dc.filename,dc.parsing_done from parsing_logs pl left join documents dc on dc.id = pl.document_id where  pl.real_estate_property_id = #{rp.id}")
    logs = logs.paginate :page => params[:page], :per_page => 30
    render :update do |page|
      page.replace_html "portfolio_dropbox_view", :partial=>'/logs/parsing_logs',:locals => {:pid=>rp.portfolio_id, :fol=>params[:fol_id], :logs=>logs, :prop_name=>rp.property_name}
    end
  end

  def replace_or_rename_doc
    exist_doc = Document.find_by_id(params[:exist_doc])
    uploaded_new = Document.find_by_id(params[:uploaded_new])
    uploaded_new.filename = exist_doc.filename
    exist_doc.destroy
    uploaded_new.save(false)
    render :update do |page|
      page << "show_hide_asset_docs1_real_estate(#{params[:port_id]}, #{params[:fol_id]}, 'hide_del');"
      page << " jQuery(document).ready(function(){jQuery('#modal_container').hide(); jQuery('#modal_overlay').hide();});"
      #page.call "show_hide_asset_docs1_real_estate" "#{params[:port_id]}","#{uploaded_new.folder_id}",'show_del'
    end
  end
  def documents_change_layout
    params[:user] == 'false' ? 'public_login' : 'user'
  end
  def status_check
    folder = Folder.find_by_id(params[:folder_id])
    items = ""
    folder.documents.each do |doc|
      if doc.parsing_done.eql?(true)
        items <<"if (jQuery('#reload_#{doc.id}').siblings('img#reload_parsing_file_status').length>0) {jQuery('#reload_#{doc.id}').html('');jQuery('#reload_#{doc.id}').siblings('img#reload_parsing_file_status').remove();/*flash_writter('#{doc.filename} has been parsed successfully.');*/}"
      elsif doc.parsing_done.eql?(false)
        error_display="<span style=\"color: #f63e3e;font-weight: bold;\", id=\"reload_#{doc.id}\">&nbsp;&nbsp;&nbsp;&nbsp;Upload failed. Try again</span>"
        items <<"if (jQuery('#reload_#{doc.id}').siblings('img#reload_parsing_file_status').length>0) {jQuery('#reload_#{doc.id}').html('#{error_display}');jQuery('#reload_#{doc.id}').siblings('img#reload_parsing_file_status').remove();flash_writter('Parsing failed for #{doc.filename}.');}"
        end
        end unless folder.documents.blank?
        render :update do |page|
        page << items
        end
      end

  def find_document
    @document = Document.find params[:document]
  end

  end
