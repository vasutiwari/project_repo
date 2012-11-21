class ClientAdmin::UsersController < ApplicationController
  before_filter :user_required
  layout "client_admin",:except=>[:other_properties,:other_portfolio]
  before_filter :find_user,:only=>[:edit,:update,:destroy,:other_properties,:other_portfolio]
  before_filter :find_property_portfolios,:only=>[:new,:edit]
  before_filter :get_user_client,:only=>[:create,:update]


  def index
    users=User.by_client_ids(current_user.client_id,current_user.email)
    @users_count=users.count
    @users=users.paginate(:per_page=>25,:page=>params[:page])
  end

  def new
    @user=User.new
  end

  def create
    #~ client_user_id=current_user.id
    #~ client_id=current_user.client_id
    @user,@valid_user=User.save_client_admin_user(params,@client_id,current_user.id)
    @user.selected_role = params[:selected_user]
    if @valid_user
    User.create_property_and_portfolio(params,@user,@client_id,@client_user_id)
    #~ UserMailer.set_your_password(@user,"users").deliver
    redirect_to :action=>"index",:add_user => 'true'
    else
    find_property_portfolios
    @users_properties=params[:property].values if params[:property]
    @users_portfolios=params[:portfolio].values if params[:portfolio]
    @errors=@user.errors
    render :new
    end
  end

  def edit
    #~ @user=User.find(params[:id])
    #~ users_properties_collection=SharedFolder.find(:all,:conditions=>["user_id=? AND is_property_folder=? AND client_id=?",@user.id,true,@user.client_id])
    users_properties_collection=SharedFolder.property_client_ids(@user.client_id,@user.id)
    @users_properties=users_properties_collection.present? ? users_properties_collection.map(&:real_estate_property_id) : []
    #~ users_portfolios_collection=SharedFolder.find(:all,:conditions=>["user_id=? AND is_portfolio_folder=? AND client_id=?",@user.id,true,@user.client_id])
    users_portfolios_collection=SharedFolder.portfolio_client_ids(@user.client_id,@user.id)
    @users_portfolios=users_portfolios_collection.present? ? users_portfolios_collection.map(&:portfolio_id) : []
  end

  def update
    #~ client_user_id=current_user.id
    #~ client_id=current_user.client_id
    #~ @user=User.find(params[:id])
    @user.is_asset_edit=true
    @user.designation_check = true
    @user.update_attributes(params[:user].reject {|key,value| key == "roles" })
    @user.update_attribute("selected_role",params[:selected_user])
    user_roles=@user.roles
    #~ if !(user_roles.map(&:role_id).include?(params[:user][:roles]))
    user_roles= Role.find(params[:user][:roles])
    #~ end
    if !@user.errors.present?
    User.update_property_and_portfolio(params,@user,@client_user_id,@client_id)
    redirect_to :action=>"index",:edit_user=>'true'
    else
    find_property_portfolios
    @users_properties = params[:property].values if params[:property]
    @users_portfolios = params[:portfolio].values if params[:portfolio]
    @errors=@user.errors
    render "edit"
    end
  end

  def get_user_client
    @client_user_id=current_user.id
    @client_id=current_user.client_id
  end

  def find_user
    @user=User.find(params[:id])
  end

  def destroy
    #~ user=User.find(params[:id])
    if @user.destroy
       redirect_to :action=>"index"
    end
  end

  def find_property_portfolios
     @portfolios=current_user.portfolios.find(:all,:conditions=>["name NOT in (?) AND is_basic_portfolio = ?",["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"],false])
    @properties=current_user.real_estate_properties.find(:all,:conditions=>["property_name NOT in (?)",["property_created_by_system","property_created_by_system_for_deal_room","property_created_by_system_for_bulk_upload"]])
    @roles=Role.not_admin_and_client_admin
  end

  def other_properties
    #~ user=User.find(params[:id])
    #~ users_properties_collection=SharedFolder.find(:all,:select=>[:id,:user_id,:is_property_folder,:real_estate_property_id],:conditions=>["user_id=? AND is_property_folder=?",@user.id,true])
    users_properties_collection=SharedFolder.shared_folder_properties_with_out_client_id(@user.id)
    users_properties=users_properties_collection.present? ? users_properties_collection.map(&:real_estate_property_id) : []
    @other_properties =RealEstateProperty.find_other_properties(users_properties)
	end

  def other_portfolio
    #~ user=User.find(params[:id])
    #~ users_portfolios_collection=SharedFolder.find(:all,:conditions=>["user_id=? AND is_portfolio_folder=?",@user.id,true])
    users_portfolios_collection=SharedFolder.portfolios_with_out_client_id(@user.id)
    users_portfolios=users_portfolios_collection.present? ? users_portfolios_collection.map(&:portfolio_id) : []
    #~ @portfolios=Portfolio.find(:all,:conditions=>["id in (?) and name NOT in (?)",users_portfolios,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]
    @portfolios=Portfolio.with_user_portfolios(users_portfolios)
  end

end


