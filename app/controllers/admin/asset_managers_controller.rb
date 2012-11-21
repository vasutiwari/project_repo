class Admin::AssetManagersController < ApplicationController
  layout 'admin', :except=>[:approve,:add_variance]
  before_filter :admin_login_required
  before_filter :find_user_id,:only=>['edit','approve','approve_sendmail','update']

  def index
    @users =  User.find(:all,:include=>["roles"],:conditions=>["roles.id =2 and client_id = ?",current_client_id],:order=>"created_at desc")
    @users =  @users.paginate(:page => params[:page], :per_page =>10)
  end

  def new
    @user = User.new
  end

  def create
    existing_user = User.find_by_email_and_client_id(params[:user][:email],current_client_id)
    old_client_type = existing_user.client_type unless existing_user.nil?
    if !existing_user.nil? && existing_user.has_role?('Asset Manager')
      flash.now[:error] = FLASH_MESSAGES['assetmanager']['3004']
      render :action => 'new'
    elsif !existing_user.nil? && existing_user.has_role?('Shared User') && !existing_user.has_role?('Asset Manager')
      existing_user.login = params[:user][:email]
      existing_user.attributes  = params[:user]
      @user = existing_user
      existing_user.is_asset_edit = true
      if existing_user.valid? && old_client_type == params[:user][:client_type]
        existing_user.update_attributes(params[:user])
        assign_asset_manager_role(existing_user)
        set_flash_and_deliver_mail('Asset_Manager')
      elsif existing_user.valid? && old_client_type != params[:user][:client_type]
        flash.now[:error] = "User client type conflicts as #{existing_user.email} belongs to #{old_client_type.upcase}"
        render :action => 'new'
      else
        render :action => 'new'
      end
    else
      @user , valid_or_not = User.save_user_values(params)
      if valid_or_not
        set_flash_and_deliver_mail('Asset_Manager')
      else
        render :action => 'new'
      end
    end
  end

  def edit
  end

  def update
    #~ @user=User.find_by_id(params[:id])
    username=@user.name
    email=@user.email
    User.user_updates(@user,params,true)
    if @user.valid?
      @user.save
      if @user.name != username || @user.email != email
        UserMailer.delay.account_detail_changed(@user,params[:user][:email],params[:user][:email])  rescue ''
      end
      flash[:notice]=FLASH_MESSAGES['assetmanager']['3003']
      redirect_to admin_asset_managers_path(:page=>params[:page])
    else
      render :action=>'edit'
    end
    #below code is commented to resolved nil issue
    #~ user = User.user_updates(params)
    #~ if user
      #~ flash[:notice]=FLASH_MESSAGES['assetmanager']['3003']
      #~ redirect_to admin_asset_managers_path(:page=>params[:page])
    #~ else
      #~ render :action=>'edit'
    #~ end
  end
  def approve
  end

  def disapprove
    User.find_by_id(params[:id]).update_attribute(:approval_status, 0)
    flash[:notice]=FLASH_MESSAGES['assetmanager']['3005']
    redirect_to admin_asset_managers_path
  end

  def approve_sendmail
    @user.approval_status=true
    @user.save(false)
    set_flash_and_deliver_mail('Approval_mail')
  end

  def destroy_asset_manager
    user = User.find_by_id(params[:id])
    user.destroy
    flash[:notice]=FLASH_MESSAGES['assetmanager']['3006']
   #redirect_to  "/admin/asset_managers"
   if request.xhr?
     render :update do |page|
#       page.replace_html "/asset_manager/index/"
     page.redirect_to :controller => "admin/asset_managers", :action => "index"
     end
   end



  end

  def add_variance
    @portfolio_type = PortfolioType.find_by_id(params[:id])
  end

  def add_variance_content
    PortfolioType.find_and_save_portfolio_type(params)
  end

  def set_flash_and_deliver_mail(type)
    UserMailer.delay.set_your_password(@user,"users")
    type == 'Asset_Manager' ? flash[:notice] = FLASH_MESSAGES['assetmanager']['3002'] : flash[:notice]=FLASH_MESSAGES['assetmanager']['3001']
    redirect_to admin_asset_managers_path
  end
  def find_user_id
    @user=User.find_by_id(params[:id])
  end
end
