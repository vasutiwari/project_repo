class SharedUsersController < ApplicationController
  include AuthenticatedSystem
  before_filter :shared_user_login_required,:except=>['new','create','set_password']
  layout :shareduser_change_layout,:except=>['view_comment']

  # render new.erb.html
  def new
    if current_user && current_user.has_role?('Shared User')
      redirect_to shared_users_path
    end
  end

  def create
    logout_keeping_session!
    user = User.email_authenticate(params[:email], params[:password])
    if user
      # Protects against session fixation attacks, causes request forgery
      # protection if user resubmits an earlier form using back
      # button. Uncomment if you understand the tradeoffs.
      # reset_session
      new_cookie_flag = (params[:remember_me] == "1")
      handle_remember_cookie! new_cookie_flag
      if user.has_role?('Shared User')
        self.current_user = user
        flash[:notice] = FLASH_MESSAGES['session']['301']
        redirect_to shared_users_path
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

  def destroy
    logout_killing_session!
    session[:role] = nil
    flash[:notice] = FLASH_MESSAGES['session']['302']
    redirect_to login_path
  end

   def set_password
    if User.exists?(params[:id])
      @user = User.find_by_id(params[:id])
      if @user.password_code?
        if params[:user]
          @user.password = params[:user][:password]
          @user.password_confirmation = params[:user][:password_confirmation]
          @user.name = params[:user][:name]#added to set user name
          @user.designation = params[:user][:designation]
          @user.phone_number = params[:user][:phone_number]
          #to save profile image
          if params[:user][:portfolio_image]
            @portfolio_image = PortfolioImage.find(:first, :conditions=>["attachable_id= ? and attachable_type=? and filename != 'logo_image'", params[:id],'User'])
            @portfolio_image = PortfolioImage.new if @portfolio_image.nil?
            @portfolio_image.uploaded_data = params[:user][:portfolio_image][:uploaded_data]
          end
          @user.is_shared_user = true
          @user.is_set_password = true
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
    redirect_to collaboration_hub_index_path if current_user.has_role?('Asset Manager')
    session[:role] = 'Shared User'
   end

  def view_comment

  end

  def shareduser_change_layout
    (action_name == 'new' || action_name == 'create' || action_name == 'set_password') ? 'user_login' : 'user'
  end

  protected
  def note_failed_signin
    flash.now[:error] = FLASH_MESSAGES['session']['303']
    logger.warn "Failed login for '#{params[:email]}' from #{request.remote_ip} at #{Time.now.utc}"
  end
end
