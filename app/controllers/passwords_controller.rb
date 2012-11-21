class PasswordsController < ApplicationController
  layout 'user_login'
  before_filter :login_required, :only=>'change_password'

  def new
    @password = Password.new
  end

  def create
    @password = Password.new(params[:password])
    @password.user = User.find_by_email(@password.email)
    if @password.user && @password.user.password_code != nil
      begin
       UserMailer.delay.account_detail_changed(@password.user, params[:password][:email], params[:password][:email])
        rescue
      end
      flash[:notice] = FLASH_MESSAGES['password']['208'] +" "+@password.email
        redirect_to reset_message_path
    else
      if params[:password][:email] == ""
        flash.now[:error] = FLASH_MESSAGES['password']['201']
        render :action => :new
      elsif @password.save
        begin
        PasswordMailer.forgot_password(@password).deliver
        rescue
        end
        flash[:notice] = FLASH_MESSAGES['password']['208'] +" "+@password.email
        redirect_to reset_message_path
      else
        flash.now[:error] = FLASH_MESSAGES['password']['202']
        render :action => :new
      end
    end
  end

  def reset
    begin
      @user = Password.find(:first, :conditions => ['reset_code = ? and expiration_date > ?', params[:reset_code], Time.now]).user
    rescue
      flash[:notice] = FLASH_MESSAGES['password']['207']
      redirect_to new_password_path
    end
  end

  def update_after_forgetting
      @user = Password.find_by_reset_code(params[:reset_code]).user
      if @user.has_role?('Shared User')
        @user.is_shared_user = true
      end
      if params[:user][:password] == params[:user][:password_confirmation]
        if params[:user][:password].match(/^[A-Za-z0-9_]/).nil?
          flash[:error] = FLASH_MESSAGES['password']['204']
          redirect_to :action => :reset, :reset_code => params[:reset_code]
        elsif @user.update_attributes(params[:user])
          @user.update_attributes(:last_pwd_modified => Time.current, :last_pwd=>User.encrypt_password(params[:user][:password]))
          flash[:notice] = FLASH_MESSAGES['password']['206']
          PasswordMailer.reset_password(@user).deliver
          redirect_to login_path
        else
          flash[:error] = FLASH_MESSAGES['password']['205']
          redirect_to :action => :reset, :reset_code => params[:reset_code]
        end
      else
        flash[:error] = FLASH_MESSAGES['password']['203']
        redirect_to :action => :reset, :reset_code => params[:reset_code]
      end
  end

  def message
  end

end
