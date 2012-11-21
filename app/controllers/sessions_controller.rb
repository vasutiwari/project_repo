class SessionsController < ApplicationController
  include AuthenticatedSystem
  before_filter :user_required,:only=>['destroy']
  layout :sessions_change_layout

  case RAILS_ENV
  when "production"
    ssl_required :new, :create
  end

  def new
    if current_user && current_user.last_visited_url.present?
      redirect_to current_user.last_visited_url
    else
      last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user) if current_user
      if current_user && current_user.has_role?('Client Admin') && !last_portfolio.present? && !first_property.present?
        session[:role] = 'Client Admin'
        cookies[:userid] = current_user.id

        redirect_back_or_default(client_admin_users_path( current_user.id))
      elsif current_user && (current_user.has_role?('Asset Manager') || current_user.has_role?("Client Admin") ) && (current_user.approval_status == nil || current_user.approval_status == true)
        session[:role] = 'Asset Manager'
        cookies[:userid] = current_user.id
        #~ if current_user && current_user.last_visited_url.present?
          #~ redirect_to current_user.last_visited_url
        #~ else
          if current_user && (current_user.has_role?('Asset Manager') || current_user.has_role?('Shared User') && current_user.has_role?('Asset Manager'))
            last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
          end
          if last_portfolio.present? && first_property.present?
            financial_access = current_user.try(:client).try(:is_financials_required)
            #~ redirect_to financial_access ? "/dashboard/#{last_portfolio.id}/financial_info?property_id=#{first_property.id}" : property_leasing_info_url(last_portfolio.id,first_property.id) #back_or_default(welcome_path)
            redirect_to "/nav_dashboard/dashboard?portfolio_id=#{last_portfolio.id}&property_id=#{first_property.id}" # : property_leasing_info_url(last_portfolio.id,first_property.id) #back_or_default(welcome_path)
          else
            redirect_to notify_admin_path(:from_session=> true)
          end
        #~ end
        #~ redirect_to welcome_path
      elsif current_user && current_user.has_role?('Admin')
        redirect_to admin_asset_managers_path
      elsif current_user && current_user.has_role?('Shared User') && is_leasing_agent
        redirect_to "#{goto_asset_view_path(current_user.id)}"
      elsif current_user && current_user.has_role?('Shared User') && !is_leasing_agent
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
      elsif current_user && is_leasing_agent
        redirect_to "#{goto_asset_view_path(current_user.id)}"
      end

    end

  end

  def create

    logout_keeping_session!
    user = User.authenticate(params[:email], params[:password])
    if user && (user.approval_status == nil || user.approval_status == true)
      setting_current_user(user)
      puts("****************************************")
      puts("****************************************")
      puts("first1 method")
      puts("****************************************")
      puts("****************************************")

      new_cookie_flag = (params[:remember_me] == "1")
      handle_remember_cookie! new_cookie_flag
      
      last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user) unless user.has_role?('Admin')
      
      if user.has_role?('Admin')
        flash.now[:notice] = FLASH_MESSAGES['session']['301']
        cookies[:userid] = current_user.id
        redirect_back_or_default(admin_asset_managers_path)
      elsif user && user.has_role?('Client Admin') && !last_portfolio.present? && !first_property.present?
        session[:role] = 'Client Admin'
        cookies[:userid] = current_user.id
        puts("****************************************")
        puts("****************************************")
        puts("first1 method")
        puts("****************************************")
        puts("****************************************")
        checking_for_template

        redirect_back_or_default(client_admin_users_path( current_user.id))
        #~ elsif user.has_role?('Asset Manager') && !user.has_role?("Client Admin") && (user.approval_status == nil || user.approval_status == true)
      elsif (user.has_role?('Asset Manager') || user.has_role?("Client Admin")) && (user.approval_status == nil || user.approval_status == true)
        session[:role] = 'Asset Manager'
        #called_user(user)
        cookies[:userid] = current_user.id
        # Here i have commented client admin code because it is redirecting to normal asset manager page.
        #        if user && user.has_role?('Client Admin')
        #          session[:role] = 'Client Admin'
        #          cookies[:userid] = current_user.id
        #          redirect_back_or_default(client_admin_users_path( current_user.id))
         
            if user && (user.has_role?('Asset Manager') || (user.has_role?('Shared User') && user.has_role?('Asset Manager')))    
              last_portfolio, first_property = Portfolio.default_portfolio_after_logged_in(current_user)
            end # it gets the portfolio(which has more properties) or property(if no portfolios) from the method written in portfolio.rb

            if last_portfolio.present? && first_property.present?
              dashboard_url = "/nav_dashboard/dashboard?portfolio_id=#{last_portfolio.id}" # navigates to nav_dashboard with selected portfolio
            else (last_portfolio.present? && first_property.blank?) || (last_portfolio.blank? && first_property.blank?)
              properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(user.id,prop_folder=true)
              first_property = properties.try(:first)               
              if first_property.blank?
                dashboard_url = "/dashboard/notify_admin?from_session=true" # navigates to notify admin, if the user doesnt have portfolios and properties
              else
                dashboard_url = "/nav_dashboard/dashboard?portfolio_id=#{first_property.try(:portfolio_id)}&property_id=#{first_property.id}" # navigates to nav_dashboard with selected property, if the user doesnt have portfolio
              end
            end
            redirect_back_or_default(dashboard_url)              
        
      elsif user && user.has_role?('Shared User') && is_leasing_agent
        session[:role] = 'Leasing Agent'
        cookies[:userid] = current_user.id
        redirect_back_or_default("#{goto_asset_view_path(current_user.id)}")
      elsif user && user.has_role?('Shared User')
        session[:role] = 'Shared User'
        #called_user(user)
        cookies[:userid] = current_user.id
        redirect_back_or_default(shared_users_path)
      elsif user && user.has_role?('Client Admin')
        session[:role] = 'Client Admin'
        #called_user(user)
        cookies[:userid] = current_user.id
        redirect_back_or_default(client_admin_users_path( current_user.id))
      elsif user && user.has_role?('Server Admin')
        session[:role] = 'Server Admin'
        #called_user(user)
        cookies[:userid] = current_user.id
        @db_set = DbSettings.find_by_user_id(current_user.id)
        if @db_set
          redirect_to  :controller=>"admin/db_settings/#{@db_set.id}", :action=>"edit"
        else
          redirect_back_or_default(new_admin_db_setting_path)
        end
      else
        note_failed_signin
        render :action => 'new'
      end
    else
      note_failed_signin
      @email       = params[:email]
      @remember_me = params[:remember_me]
      render :action => 'new'
    end
  end

  def checking_for_template
    #checking if template is not created
    puts("****************************************")
    puts("****************************************")
    puts("first method")
    puts("****************************************")
    puts("****************************************")

      @checking_template=Template.where("client_id = ? AND is_editable = ?","#{current_user.client_id}",false)
      if @checking_template.first == nil
        puts("****************************************")
        puts("****************************************")
        puts("if passed")
        puts("****************************************")
        puts("****************************************")
        create_default_template_folder(current_user.client_id)


      else


      end

    end



  def create_default_template_folder(recent_client)


    PropertyType.all.each do |p|
      default_template_id=Template.maximum(:template_id)
      if default_template_id == nil
        temp_id=1
      else
        temp_id=default_template_id+1
      end
      temp_name=recent_client.name + "_" + p.name + "_" + "template"
      SuperAdminTemplate.all.each do |q|
        var_parent_id=q.parent_id

        #var_parent_folder_name=@super.folder_name
        if var_parent_id ==0
          #temp=Template.create(:folder_name =>q.folder_name,:parent_id => q.parent_id,:property_type_name => p.name,:client_id =>@client.id,:user_id =>@user.id)
          @template_default_folder=Template.new
          @template_default_folder.folder_name=q.folder_name
          @template_default_folder.parent_id=q.parent_id
          @template_default_folder.property_type_name=p.name
          @template_default_folder.client_id=recent_client.id
          @template_default_folder.template_id=q.template_id
          @template_default_folder.template_name=temp_name
          @template_default_folder.is_editable=false
          @template_default_folder.created_date=Date.today
          @template_default_folder.updated_date=Date.today
          @template_default_folder.save
          #Template.create(:folder_name => q.folder_name,:parent_id => q.parent_id,:property_type_name =>p.name,:client_id =>recent_client.id)
          #amp_folder = Folder.create(:name =>"AMP Files",:user_id => property.user_id,:parent_id =>property_folder.id,:is_master =>1)
          puts("*****************creating parent folder*********")
          puts("*****************creating parent folder*********")
          puts("*****************creating parent folder*********")
        else
          @super_parent_folder_name=SuperAdminTemplate.where("id=?",var_parent_id)
          puts("*****************creating parent folder*********")
          puts("*****************creating parent folder*********")
          puts("*****************creating parent folder*********")
          puts(@super_parent_folder_name.first.folder_name)
          default_template_sub_folder(p,recent_client.id,@super_parent_folder_name.first.folder_name,q.folder_name,temp_id,temp_name)

          #default_template_sub_folder(p.name,recent_client.id,var_parent_name,)
        end
      end
    end
    end

    def create_default_template_sub_folder(property_name,company_id,var_parent_folder_name,current_sub_folder_name,super_template_id,default_template_name)
      @parent_folder=Template.where("folder_name=?",var_parent_folder_name).order("id DESC")
      @template_default_sub_folder=Template.new
      @template_default_sub_folder.folder_name=current_sub_folder_name
      @template_default_sub_folder.parent_id=@parent_folder.first.id
      @template_default_sub_folder.client_id=company_id
      @template_default_sub_folder.property_type_name=property_name
      @template_default_sub_folder.template_id=super_template_id
      @template_default_sub_folder.template_name=default_template_name
      @template_default_sub_folder.is_editable=false
      @template_default_sub_folder.created_date=Date.today
      @template_default_sub_folder.updated_date=Date.today
      @template_default_sub_folder.save
      #@parent_folder=Template.where("property_type_name= ? AND client_id=?",property_name,company_id).order("id")
      #Template.create(:folder_name => var_parent_folder_name,:parent_id => @parent_folder.first.id,:property_type_name =>property_name,:client_id =>company_id)
    end


  def destroy
    # added to fetch and save the last_visited_url in users table
    #~ find_last_visited_url(current_user)
    # ends here#
    logout_killing_session!
    cookies[:userid] = 0
    session[:role] = nil
    flash.now[:notice] =FLASH_MESSAGES['session']['302']
    redirect_back_or_default(APP_CONFIG[:main_url])
  end

  def sessions_change_layout
   (action_name  == 'new' or action_name == 'create') ? 'user_login' : 'admin'
  end

  protected

  def note_failed_signin
    flash.now[:error] = FLASH_MESSAGES['session']['303']
    logger.warn "Failed login for '#{params[:email]}' from #{request.remote_ip} at #{Time.now.utc}"
  end

  def called_user(user)
    if user.client_type == "swig"
      session[:wres_user] = false
    else
      session[:wres_user] = true
    end
    flash.now[:notice] =FLASH_MESSAGES['session']['301']
  end

  def setting_current_user(user)
    self.current_user = user
    User.current = user
    Client.current = user.client  if user.client
    Client.current_id = user.client.id if user.client
  end
end
