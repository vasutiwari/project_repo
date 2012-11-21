class CollaborationHubController < ApplicationController
  before_filter :user_required,:except=>['share_link_folder_for_coll']
  before_filter :find_current_user,:only=>["my_profile","change_user_name","update_password"]
  before_filter :change_session_value, :only=>[:index]
  before_filter :check_property_access, :only=> [:index]
  before_filter :check_portfolio_access, :only=> [:index]
  layout :documents_change_layout, :except=>['edit_user_image']

  def index
    find_portfolios_to_display_in_collabhub
    if (@portfolios.nil? || @portfolios.blank?)
      last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
      redirect_to "/dashboard/#{last_portfolio.id}/financial_info?property_id=#{first_property.id}&from_view_coll=>true"
      #~ redirect_to welcome_path(:from_view_coll=>true)
    end
    if params[:folder_type] == 'property'
      @property = SharedFolder.find_by_folder_id_and_user_id_and_client_id(params[:open_folder],User.current.id,User.current.client_id)
      if @property.blank?
        flash[:now] = 'This property has been revoked'
      end
    elsif params[:open_folder]
      @open_folder = SharedFolder.find_by_folder_id_and_user_id_and_client_id(params[:open_folder],User.current.id,User.current.client_id)
        flash[:now] = 'This folder has been revoked' if @open_folder.nil? || @open_folder.folder.is_deleted == true
    end
    if params[:mailer] == 'true' #  For Display page from mail link
      @from_mailer = 'true'
      @folder_for_mailer = Folder.find_by_id_and_is_deleted(params[:id],false) if params[:type] == "folder" # is_deleted condition added for restrict the deleted folder display from the mail link
      if @folder_for_mailer.nil? && params[:type] == "folder"
       flash[:now] = 'This folder has been revoked'
       @mail_con = 'folder'
      end
      @document_for_mailer = Document.find_by_id_and_is_deleted(params[:id],false) if params[:type] == "document"
      if @document_for_mailer.nil? && params[:type] == "document"
        flash[:now] = 'This document has been revoked'
       @mail_con = 'document'
      end
    end
  end

  def my_profile
    @portfolios = current_user.portfolios.find(:all,:conditions=>["is_basic_portfolio = false and name not in (?)",["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]],:order=>"id desc")
    if request.xhr?
       render :update do |page|
        #~ render :action => 'my_profile.rjs'
        page.replace_html  "overview",:partial=>"/collaboration_hub/profile",:locals=>{:user_collection=> @user,:portfolios_collection => @portfolios}
        page.call "flash_writter",'Password was successfully updated.' if 	@password_updated
      end
    end
  end

  def upload_profile_image
  end

  def list_of_folders
    @folders = params[:parent_id] == "-1" ? Folder.find(:all, :conditions => ["portfolio_id = ? and is_master = ? and parent_id = ? and is_deleted = ?",params[:portfolio_id],false,false,false]) : Folder.find(:all, :conditions => ["parent_id = ? and is_deleted = ?",params[:parent_id],false])
    render :update do |page|
      page.replace_html  "overview",:partial=>"/collaboration_hub/asset_list"
    end
  end

  def change_user_name
    if params[:field] == 'phone_number'
     change_user_phone_number
    elsif params[:field] == 'designation'
      change_designation
    else
     @user.update_attribute("#{params[:field]}",CGI.unescape(params[:name])) unless params[:name].strip.blank?
    params[:field] == 'name' ? update_old_data('change_name','disp_name',@user.name) : update_old_data('change_comment','disp_comment',@user.comment)
  end
  end

#To update user's phone_number
def change_user_phone_number
    if params[:name] == ""
       update_old_data('change_phone_number','disp_phone_number',@user.phone_number)
     else
      @user.phone_number = params[:name]
      @user.ignore_password = true
      show_profile_err('emsg_phone_number',@user.errors['phone_number'])       unless @user.save

    end
  end

#To update user's job title
def change_designation
  if params[:name] == ""
    update_old_data('change_job_title','disp_job_title',@user.designation)
   else
    @user.designation = params[:name]
    @user.ignore_password = true
    show_profile_err('emsg_designation',@user.errors['designation'])       unless @user.save
  end
end

#To show the error message
def show_profile_err(id,err_msg)
     render :update do |page|
      page << "jQuery('##{id}').show();jQuery('##{id}').html('#{err_msg}')"
    end
end

#To display old data if the data is blank
def update_old_data(id1,id2,data)
    render :update do |page|
      page << "jQuery('##{id1}').hide();jQuery('##{id2}').show();jQuery('##{id1} span input[name]').val('#{data}');"
      page << "jQuery('#name').html('<strong>#{data}</strong>')"  if params[:field] == 'name'
      page << "jQuery('#comment_description').html('<h>#{data}</h>')"  if params[:field] == 'comment'
      page.call "flash_writter", "Blank submission is not possible" if !params[:name].present?
   end
end


  def update_password
    @user.is_shared_user = true
    if params[:user][:password] == params[:user][:password_confirmation]
      if params[:user][:password].match(/^[A-Za-z0-9_]/).nil?
        flash[:error] = FLASH_MESSAGES['password']['204']
        call_change_password
      elsif @user.update_attributes(params[:user])
        @user.update_attributes(:last_pwd_modified => Time.current, :last_pwd=>User.encrypt_password(params[:user][:password]))
        @password_updated = true
        my_profile
      else
        flash[:error] = FLASH_MESSAGES['password']['205']
        call_change_password
      end
    else
      flash[:error] = FLASH_MESSAGES['password']['203']
      call_change_password
    end
  end

  def edit_user_image
  end

  def update_user_image
    if params[:id] && params[:user_image][:uploaded_data]
      @user = User.find_by_id(params[:id])
      @user_image=PortfolioImage.update_image(params[:id],params[:user_image][:uploaded_data],@user,params[:logo_image])
      @user.updated_at = Time.now
      @user.profile_image_path = @user_image.public_filename if params[:logo_image] != "true"
      @user.is_shared_user = true
       @user.save(false)
			@last_portfolio, @first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
      respond_to_parent do
        render :action => 'update_user_image.rjs'
      end
    end
  end

  def call_change_password
    render :update do |page|
      page.replace_html  "change_password",:partial=>"change_password"
    end
  end

  def find_current_user
    @user = current_user
  end
  def share_link_folder_for_coll
    logout_keeping_session!
    render :action => "index"
  end
  def documents_change_layout
     current_user.nil? ? 'user_login' : 'user'
   end

   def change_session_value
		 if ( (params[:portfolio_id].present? && params[:property_id].blank?) || (params[:pid].present? && params[:nid].blank?) || (params[:real_estate_id].present? && params[:id].blank?) )
      session[:portfolio__id] = params[:portfolio_id] || params[:pid] || params[:real_estate_id]
      session[:property__id] = ""
    elsif ( (params[:portfolio_id].present? && params[:property_id].present?) || (params[:pid].present? && params[:nid].present?) || (params[:real_estate_id].present? && params[:id].present?) )
      session[:portfolio__id] = ""
      session[:property__id] = params[:property_id] || params[:id] || params[:nid]
    elsif( (params[:id].present? && params[:open_portfolio]) )
		  session[:portfolio__id] = ""
      session[:property__id] = params[:id]
		elsif( (session[:portfolio__id].present? && session[:property__id].blank?) )
		  session[:portfolio__id] = session[:portfolio__id]
      session[:property__id] = ""
		else
			session[:portfolio__id] = ""
      session[:property__id] = session[:property__id]
    end
  end

  def check_property_access

   id = params[:id].present? ? params[:id] : params[:property_id].present? ? params[:property_id] : params[:nid].present? ? params[:nid] : @property.present? ? @property.try(:id) : @note.present? ? @note.id : ""

    if id.present?
      properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(current_user.id,prop_folder=true)
      p properties.map(&:id).uniq
      @property_ids = properties.present? ? properties.map(&:id) : []
      unless @property_ids.include?(id.to_i)
      flash[:notice]=FLASH_MESSAGES['portfolios']['508']
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
    if (params[:portfolio_id].present? && params[:property_id].blank?)
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
