class UsersController < ApplicationController
  # Be sure to include AuthenticationSystem in Application Controller instead
  include AuthenticatedSystem
  # Protect these actions behind an admin login
  before_filter :login_required, :find_asset_manager, :only=>[:welcome,:notify_admin]
  before_filter :find_user, :only => [:suspend, :unsuspend, :destroy, :purge]
  before_filter :commercial_and_multi_collection, :only => [:welcome, :comm_display, :multifamily_display, :dashboard_commercial, :dashboard_commercial_leases]
  before_filter :check_leasing_agent,:except=>['add_contacts','create_contact']
  before_filter :check_portfolio_access, :only=> [:welcome,:notify_admin]
  before_filter :redirection, :only=> [:welcome]
  layout :user_change_layout,:except=>['add_contacts','create_contact']


  def new
    if current_user && is_leasing_agent
      redirect_to "#{goto_asset_view_path(current_user.id)}"
    elsif current_user && current_user.has_role?('Asset Manager')
      redirect_to welcome_path
    elsif current_user && current_user.has_role?('Admin')
      redirect_to admin_asset_managers_path
    elsif current_user && current_user.has_role?('Shared User')
      redirect_to :controller=>"shared_users",:action=>"index"
    elsif current_user && current_user.has_role?('Client Admin')
      redirect_to admin_client_admins_path
    elsif current_user && current_user.has_role?('Server Admin')
      @db_set = DbSettings.find_by_user_id(current_user.id)
      if @db_set
        redirect_to  :controller=>"admin/db_settings/#{@db_set.id}", :action=>"edit"
      else
        redirect_back_or_default(new_admin_db_setting_path)
      end
    end
    @user = User.new
    @user_profile_detail = UserProfileDetail.new
    @profile_errors={}
    @user_profile_detail.is_new_user=true
    params[:interests]=[] if params[:interests]==nil
  end

  def create
    logout_keeping_session!
    params[:user]={} if params[:user]==nil
    params[:interests]=[]  if params[:interests]==nil
    interests=params[:interests].join(',')
    @user = User.new_user(params[:user],params[:user][:email],params[:user_profile_detail],interests)
    @profile_errors = @user.user_profile_detail.errors if !@user.user_profile_detail.errors.nil?
    if @user.errors.empty? && @user.user_profile_detail.errors.empty?
      redirect_back_or_default('/login')
      flash[:notice] =FLASH_MESSAGES['user']['103']
    else
      render :action => 'new'
    end
  end

  def activate
    logout_keeping_session!
    user = User.find_by_activation_code_and_client_id(params[:activation_code],current_client_id) unless params[:activation_code].blank?
    case
      when (!params[:activation_code].blank?) && user && !user.active?
      user.activate!
      flash[:notice] = "Signup complete! Please sign in to continue."
      redirect_to '/login'
      when params[:activation_code].blank?
      flash[:error] = "The activation code was missing.  Please follow the URL from your email."
      redirect_back_or_default('/')
    else
      flash[:error]  = "We couldn't find a user with that activation code -- check your email? Or maybe you've already activated -- try signing in."
      redirect_back_or_default('/')
    end
  end

  def suspend
    @user.suspend!
    redirect_to users_path
  end

  def unsuspend
    @user.unsuspend!
    redirect_to users_path
  end

  def destroy
    @user.delete!
    redirect_to users_path
  end

  def purge
    @user.destroy
    redirect_to users_path
  end

  def welcome
    if (params[:portfolio_id].present? && params[:property_id].blank?)
      session[:portfolio__id] = params[:portfolio_id]
      session[:property__id] = ""
    else
      session[:portfolio__id] = ""
      session[:property__id] = params[:property_id]
    end
    session[:role] = 'Asset Manager'
    old_welcome_page if params[:home_page] == "old"
    @portfolio_real_estates = Portfolio.find_shared_and_owned_portfolios(User.current.id)
    @real_estate_properties = RealEstateProperty.find_by_sql("SELECT id FROM real_estate_properties WHERE id in (SELECT real_estate_property_id FROM shared_folders WHERE is_property_folder = 1 AND user_id = #{User.current.id} and client_id = #{Client.current_client_id} )")
    @real_estate_properties += RealEstateProperty.properties_of_portfolio_ids(@portfolio_real_estates.collect{|portfolio| portfolio.id }) unless @portfolio_real_estates.blank?
    #to get myfiles folder
    user_owned_folders = Folder.current_user_files


    user_owned_folders += Folder.find_by_sql("select id from folders where parent_id = #{user_owned_folders.first.id}") unless user_owned_folders.blank?



    #to get myfiles files
    user_owned_docs = Document.current_user_files(user_owned_folders.collect{|folder| folder.id} ) unless user_owned_folders.blank?
    @updated_properties = RealEstateProperty.find(:all, :conditions => ["id in (?) and real_estate_properties.property_name not in (?)",@real_estate_properties.collect{|y| y.id},["property_created_by_system","property_created_by_system_for_deal_room","property_created_by_system_for_bulk_upload"]], :order => "last_updated desc, created_at desc", :limit=>5)
    @updated_files = Document.find(:all, :conditions => ["user_id = ? && is_deleted = ? && is_master = ?",User.current,false,false], :order => "created_at desc", :limit=>5)
    events_conditions = []
    events_real_estates= RealEstateProperty.find(:all, :conditions => ["id in (?) and real_estate_properties.property_name not in (?)",@real_estate_properties.collect{|y| y.id},["property_created_by_system","property_created_by_system_for_deal_room","property_created_by_system_for_bulk_upload"]], :select=>"id")
    find_bool , event_real_ids = !(events_real_estates.nil? || events_real_estates.blank?) , events_real_estates.collect{|x4| x4.id}
    real_estate_properties_folders = Folder.find(:all, :conditions => ["real_estate_property_id in (?) and is_master = 0",event_real_ids], :select => "id,user_id,parent_id,is_master") if find_bool
    real_estate_properties_documents = Document.find(:all, :conditions => ["real_estate_property_id in (?)",event_real_ids], :select => "id,user_id") if find_bool
    real_estate_properties_folders = real_estate_properties_folders.collect{|real_prop_folder| real_prop_folder if check_is_folder_shared(real_prop_folder) == "true"}.compact if find_bool && !real_estate_properties_folders.empty?
    real_estate_properties_documents = real_estate_properties_documents.collect{|real_prop_doc| real_prop_doc if check_is_doc_shared(real_prop_doc) == "true"}.compact if find_bool && !real_estate_properties_documents.empty?
    events_conditions = "(resource_id IN (#{real_estate_properties_folders.collect{|x7| x7.id}.join(',')}) and resource_type = 'Folder')"   if !(real_estate_properties_folders.nil? || real_estate_properties_folders.blank?)
    events_conditions << " #{check_or_flag(events_conditions)} (resource_id IN (#{real_estate_properties_documents.collect{|x8| x8.id}.join(',')}) and resource_type = 'Document')" if !(real_estate_properties_documents.nil? || real_estate_properties_documents.blank?)
    events_conditions << " #{check_or_flag(events_conditions)} (resource_id IN (#{user_owned_folders.collect{|x10| x10.id}.join(',')}) and resource_type = 'Folder')" if !(user_owned_folders.nil? || user_owned_folders.blank?)
    events_conditions << " #{check_or_flag(events_conditions)} (resource_id IN (#{user_owned_docs.collect{|x11| x11.id}.join(',')}) and resource_type = 'Document')"   if !(user_owned_docs.nil? || user_owned_docs.blank?)
    if !(events_conditions.nil? || events_conditions.blank?)
      folder_events = EventResource.find(:all, :conditions=>["#{events_conditions}"])
      #action_type = ["create","upload","new_version","delete","permanent_delete","download","rename","restored","create_task","update_task"]
      #      action_type = ["create","upload","new_version","delete","permanent_delete","download","rename","restored"]
      action_type = ["create","upload","new_version","delete","download","rename","shared","moved","copied","commented","restored","unshared","del_comment","rep_comment","up_comment","collaborators","de_collaborators","sharelink"]
      @events = Event.find(:all, :conditions=>["id IN (?) and action_type in (?)",folder_events.collect{|x13| x13.event_id},action_type], :order=>'created_at desc')   if !(folder_events.nil? || folder_events.blank?) #:limit => 6 removed for dashboard
    end
    @commercial = @commercial.sort_by{|comm| comm.created_at}.reverse
    render :action=> 'dashboard',:locals=>{:portfolio_id => session[:portfolio_id1]}
  end

  def check_or_flag(events_conditions)
    or_flag = !events_conditions.empty? ? " or " : " "
  end

  def new_portfolio
    @portfolio_type = PortfolioType.find(params[:id])
    render :layout => false
  end

  def set_password
    logout_keeping_session!
    if (params[:enc_email] && User.exists?(:id=>params[:id],:email=>Base64.decode64(params[:enc_email]))) || (!params[:enc_email] && User.exists?(:id=>params[:id]))
      @user = User.find_by_id(params[:id])
      if params[:user] && params[:user][:portfolio_image]
        @portfolio_image = PortfolioImage.find(:first, :conditions=>["attachable_id= ? and attachable_type=? and filename != 'logo_image'", params[:id],'User'])
        @portfolio_image = PortfolioImage.new if @portfolio_image.nil?
        @portfolio_image.uploaded_data = params[:user][:portfolio_image][:uploaded_data]
      end
      if @user.password_code?
        if params[:user]
          @user.attributes = {:password => params[:user][:password] , :password_confirmation => params[:user][:password_confirmation] , :name => params[:user][:name],:designation => params[:user][:designation],:phone_number=>params[:user][:phone_number]}
          @user.is_set_password = true
          params[:user][:portfolio_image] ? (@portfolio_image.attributes = {:uploaded_data => params[:user][:portfolio_image][:uploaded_data],:attachable_id => params[:id] , :attachable_type => "User"}) : (@portfolio_image = nil)
          finalize_set_password
        end
      else
        flash[:error] = FLASH_MESSAGES['user']['102']
        redirect_to login_path
      end
    else
      flash[:error] = FLASH_MESSAGES['user']['101']
      redirect_to login_path
    end
  end

  def index
    if current_user && is_leasing_agent
      redirect_to "#{goto_asset_view_path(current_user.id)}"
    elsif current_user && current_user.has_role?('Asset Manager')
      redirect_to welcome_path
    elsif current_user && current_user.has_role?('Admin')
      redirect_to admin_asset_managers_path
    elsif current_user && current_user.has_role?('Shared User')
      redirect_to shared_users_path
    elsif current_user && current_user.has_role?('Client Admin')
      redirect_to admin_client_admins_path
    elsif current_user && current_user.has_role?('Server Admin')
      @db_set = DbSettings.find_by_user_id(current_user.id)
      if @db_set
        redirect_to  :controller=>"admin/db_settings/#{@db_set.id}", :action=>"edit"
      else
        redirect_back_or_default(new_admin_db_setting_path)
      end
    end
  end


 def add_contacts
  @collaborators = find_contact_details
  find_portfolios_to_display_in_collabhub
  end


def create_contact
 collaborators = params[:collaborator_list].split( /, */ ).each{|x| x.strip! }
    for collaborator in collaborators.uniq
       su,su_already = User.create_new_user(collaborator,params,current_user.id)
       UserMailer.delay.set_your_password(su,"users") if !su_already
    end
 responds_to_parent do
   render :update do |page|
       page.call 'close_control_model'
       page.replace_html "add_new_contact",:partial=>"/users/add_new_contact" if params[:from_dash_board] == 'true'
       page << "jQuery('#contact_count_display').html('View Users (#{find_contact_details.count})')" if params[:from_dash_board] != 'true'
       page.call "flash_writter", "An invitation to join AMP has been sent to the collaborator(s).Once the user logs on to AMP, you can find them in the \"Who's Online\" list"
   end
 end
end


  # There's no page here to update or destroy a user.  If you add those, be
  # smart -- make sure you check that the visitor is authorized to do so, that they
  # supply their old password along with a new one to update it, etc.

  def user_change_layout
    #~ if action_name == "welcome" || action_name == "dashboard" || action_name == "comm_display" || action_name == "multifamily_display" || action_name == "dashboard_commercial"
    if action_name == "welcome" || action_name == "dashboard" || action_name =="comm_display" || action_name =="multifamily_display" || action_name =="dashboard_commercial" || action_name =="dashboard_commercial_leases" || action_name =="notify_admin"
      'user'
    elsif action_name == "set_password" || action_name == "verify_password"
      'user_login'
    elsif !( action_name =="welcome" || action_name == "index" || action_name =="new" || action_name == "create" || action_name == "dashboard" || action_name == "set_password" || action_name == "verify_password" || action_name =="new_real_portfolio")
      'users'
    end
  end

  def comm_display
    @commercial = @commercial.sort_by{|comm| comm.created_at}.reverse
    @exp = params[:exp]
    respond_to do |format|
      format.js
    end
  end

  def multifamily_display
    session[:cur_selection] = 'Multifamily'
    @multi = @multi.sort_by{|mul| mul.created_at}.reverse
    respond_to do |format|
      format.js
    end
  end

  def dashboard_commercial
    session[:cur_selection] = 'Commercial'
    @commercial = @commercial.sort_by{|comm| comm.created_at}.reverse
    if current_user && is_leasing_agent
      redirect_to "#{goto_asset_view_path(current_user.id)}"
    else
      respond_to do |format|
        format.js
      end
    end
  end

  def dashboard_commercial_leases
    session[:cur_selection] = 'Commercial_leases'
    @commercial_leases = @commercial_leases.sort_by{|comm| comm.created_at}.reverse
    if current_user && is_leasing_agent
      redirect_to "#{goto_asset_view_path(current_user.id)}"
    else
      respond_to do |format|
        format.js
      end
    end
  end

  def commercial_and_multi_collection
    if params[:portfolio_id].present? && params[:property_id].blank?
      session[:portfolio_id1] = params[:portfolio_id]
    end
    portfolio_id = session[:portfolio_id1]
    portfolios = Portfolio.find_shared_and_owned_portfolios(current_user.id)
    shared_comm,shared_mul = [],[]
    ############################ Have to enanble to display shared properties and to do the same for megadropdown list too
    #~ portfolios.each do |port|
      #~ if port.user_id != current_user.id
        #~ shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{current_user.id} AND client_id = #{current_user.client_id})")
        #~ prop_condition = "and r.leasing_type= 'Commercial' and r.id in (#{shared_folders.collect {|x| x.real_estate_property_id}.join(',')})"  if !(port.id.nil? || port.id.blank? || shared_folders.nil? || shared_folders.blank?)
	#~ shared_comm << RealEstateProperty.find_properties_by_portfolio_id_with_cond(port.id,prop_condition,"")   if !(port.id.nil? || port.id.blank? || shared_folders.nil? || shared_folders.blank?)
        #~ prop_condition = "and r.leasing_type= 'Multifamily' and r.id in (#{shared_folders.collect {|x| x.real_estate_property_id}.join(',')})"  if !(port.id.nil? || port.id.blank? || shared_folders.nil? || shared_folders.blank?)
	#~ shared_mul << RealEstateProperty.find_properties_by_portfolio_id_with_cond(port.id,prop_condition,"")   if !(port.id.nil? || port.id.blank? || shared_folders.nil? || shared_folders.blank?)
      #~ end
    #~ end

      commercial = RealEstateProperty.find(:all, :conditions=>["real_estate_properties.leasing_type=? and portfolios.id=? and property_name not in (?) and real_estate_properties.client_id = #{current_user.client_id}",'Commercial', portfolio_id.to_i,['property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload']],:joins=>:portfolios,:order=> "real_estate_properties.created_at desc")
      commercial = commercial #<< shared_comm.flatten
      @commercial = commercial.flatten.uniq
      @comm_count = @commercial.count

      multi = RealEstateProperty.joins(:portfolios).where("real_estate_properties.leasing_type=? and portfolios.id=? and property_name not in (?) and real_estate_properties.client_id = ?",'Multifamily', portfolio_id.to_i, ['property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload'],current_user.client_id) #.order(), :order=> "created_at desc")
    multi = multi #<< shared_mul.flatten
      @multi = multi.flatten.uniq
      @multi_count = @multi.count

    commercial_leases = RealEstateProperty.find(:all, :conditions=>["real_estate_properties.leasing_type=? and portfolios.id=? and property_name not in (?) and real_estate_properties.user_id = ? and real_estate_properties.client_id = #{current_user.client_id}",'Commercial', portfolio_id.to_i,['property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload'],current_user.id],:joins=>:portfolios, :order=> "real_estate_properties.created_at desc")

      commercial_leases = commercial_leases #<< shared_comm.flatten
      @commercial_leases = commercial_leases.flatten.uniq
      @comm_leases_count = @commercial_leases.count

    #    @portfolio_count = Portfolio.count(:conditions=>['user_id=? and name not in (?)',current_user.id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]])

    @portfolio_count = Portfolio.find_shared_and_owned_portfolios(User.current.id)
    @from_dash_board = true
  end

  def paymentconfirm
  end

  def notify_admin
    if params[:mail_sent].present?
      UserMailer.notify_admin(current_client, current_user).deliver
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

  def redirection
    financial_access = current_user.try(:client).try(:is_financials_required)
    if !params[:view_more].present?
      unless financial_access
        if !params[:from_property_tab].eql?('true')
          if (params[:portfolio_id].present? && params[:property_id].blank?)
            @note = Portfolio.find_by_id(params[:portfolio_id])
            redirect_to portfolio_leasing_info_url(@note.try(:id))
          else
            @real_estate_property = RealEstateProperty.find_real_estate_property(session[:property__id]) if session[:property__id].present?
            @real_property  =  RealEstateProperty.find_by_id(session[:property__id]) if session[:property__id].present?
            @note = @real_estate_property || @real_property
            redirect_to property_leasing_info_url(@note.try(:portfolio_id),@note.try(:id))
          end
        end
      end
    end
  end


  protected
  def find_user
    @user = User.find_by_id(params[:id])
  end
end
