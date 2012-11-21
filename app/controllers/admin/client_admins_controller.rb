class Admin::ClientAdminsController < ApplicationController
  ##before_filter :client_admin_login_required
  #~ before_filter :find_client_user_id,:only=>['edit','update']
  #~ layout 'client_server', :except => [:new, :create, :edit]
  #~ def index
    #~ @db_settings_list = DbSettings.find(:all, :conditions=>['user_id = ?',current_user.id]).paginate(:page => params[:db_page],:per_page => 5)
    #~ server_admins
  #~ end

  #~ def new
    #~ @user = User.new
  #~ end

  #~ def create
    #~ @user , valid_or_not = User.save_server_admin_values(params)
    #~ if (valid_or_not.blank? ? false : ( valid_or_not))
      #~ @user.save
      #~ UserMailer.set_your_password(@user,"users").deliver
      #~ create_server_admin
      #~ server_admins
       ##if request.xhr?
        #~ render :update do |page|
          #~ page << "Control.Modal.close();"
          #~ page.replace_html 'client_server_index',:partial=>"admin/client_admins/index", :object => @users
          #~ page.call "flash_writter", "Server Admin successfully created"
       ##   page.redirect_to "client_admins"
        #~ end
      ##end
    #~ else
     ## if request.xhr?
        #~ render :update do |page|
         ## page.redirect_to "client_admins/new"
          #~ page.replace_html 'check_client_admin',:partial=>"admin/client_admins/new", :locals => {:user => @user}
          #~ page.call "flash_writter", "Server Admin successfully created"
        #~ end
      ## end
    #~ end
  #~ end

  #~ def edit

  #~ end

  #~ def update
    #~ @user = User.user_updates(@user, params,false)
    #~ if @user.save
      #~ server_admins
      ##if request.xhr?
        #~ render :update do |page|
          #~ page << "Control.Modal.close();"
          #~ page.replace_html 'client_server_index',:partial=>"admin/client_admins/index", :object => @users
          #~ page.call "flash_writter", "Server Admin successfully updated"
        ##  page.redirect_to "client_admins"
        #~ end
     ## end
    #~ else
     ## if request.xhr?
        #~ render :update do |page|
          #~ page.replace_html 'edit_client_admin_form',:partial=>"admin/client_admins/edit", :locals => {:user => @user}
          #~ page.call "flash_writter", "Server Admin successfully updated"
           ##page.redirect_to  "client_admins/#{params[:id]}"
        #~ end
      ##end
    #~ end
  #~ end

  #~ def show
  #~ end

  #~ def destroy
    #~ user = User.find_by_id(params[:id])
    #~ user.destroy
    #~ redirect_to admin_client_admins_path
  #~ end
#~ end

  #~ def find_client_user_id
    #~ @user = User.find_by_id(params[:id])
  #~ end

#~ private

#~ def server_admins
  #~ server_admin_ids = ClientServerAdmins.where(:client_admin_id => current_user.id).map(&:server_admin_id).compact
  #~ @users =  User.where(:id => server_admin_ids).order("id desc").paginate(:page => params[:admin_server_page],:per_page => 5)
#~ end



#~ def create_server_admin
  #~ @client_server = ClientServerAdmins.new
  #~ @client_server.client_admin_id = current_user.id
  #~ @client_server.server_admin_id =@user.id
  #~ @client_server.save
end
