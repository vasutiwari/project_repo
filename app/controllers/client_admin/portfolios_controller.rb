class ClientAdmin::PortfoliosController < ApplicationController
	before_filter :user_required
	 layout "client_admin",:except=>['other_properties']
	before_filter :find_user,:only=>[:create,:update]
	 before_filter :find_properties_users,:only=>[:new]
	 before_filter :property_and_user_collection,:only=>[:get_type_properties]
	 before_filter :edit_user_properties, :only=>[:edit]

  def index
    portfolios=Portfolio.by_user_ids(current_user.id)
		@portfolios_count=portfolios.count
		@portfolios=portfolios.order("created_at DESC").paginate(:per_page=>25,:page=>params[:page])
  end

	def new
		@portfolio=Portfolio.new
		@chart_type=current_user.client.chart_of_accounts
	end

	def create
		#~ user_id=current_user.id
		if !Portfolio.by_user_id_and_name(@user_id,params[:portfolio][:name].strip).present?
		@portfolio = Portfolio.create(params[:portfolio])
		client_id=current_user.client_id
    if @portfolio.valid?
			#~ @portfolio.update_attributes(:chart_of_accounts=>params[:chart_of_accounts])
      Portfolio.create_new_properties_and_users(params,@portfolio,@user_id,client_id)
		redirect_to :action=>"index",:add_portfolio => 'true'
    else
			find_properties_users
			@errors=@portfolio.errors
			render "new"
    end
		else
			@name = params[:portfolio][:name]
			@portfolio = Portfolio.new
			@name_error="Portfolio name already present"
			find_properties_users
			render "new"
		end
	end

	def edit
	@name = @portfolio.name
	end


# changes to delete the entry from share folder =>vasu
	def update
=begin
		#~ user_id=current_user.id
    if params[:property]==nil || params[:user]==nil

    else
         params[:property].each do |p,s|
         @folder=Folder.where("real_estate_property_id = ?","#{s}")
         @folder.each do |f|
         params[:user].each do |p,u|
           @share_folder=SharedFolder.where("folder_id = ? AND sharer_id = ? AND user_id = ?",f.id,"#{current_user.id}","#{u.id}")
           if @share_folder.first== nil

           else
             ShareFolder.where("folder_id = ? AND sharer_id = ? AND user_id = ?",f.id,"#{current_user.id}",u.id).delete_all
             end
           end
      end
         end
         end
=end

		client_id=current_user.client_id
		@portfolio=Portfolio.find(params[:id])
		if !Portfolio.by_user_id_and_name(@user_id,params[:portfolio][:name].strip).reject{|x| x.id == @portfolio.id}.present?
		if !@portfolio.errors.present?
		Portfolio.update_portfolios(params,@portfolio,@user_id,client_id)
		redirect_to :action=>"index",:edit_portfolio => 'true'
		else
			edit_user_properties

		#~ @errors=@portfolio.errors
		#~ render :controller=>"client_admin/#{@user_id}/portfolios/#{@portfolio.id}",:action=>"edit"
		render "edit"
	end
	else
		@name=params[:portfolio][:name]
		edit_user_properties
		#~ @errors=@portfolio.errors
		@name_error="Portfolio name already present"
		#~ render :controller=>"client_admin/#{@user_id}/portfolios/#{@portfolio.id}",:action=>"edit"
		render "edit"
		end
	end

	def find_user
		@user_id=current_user.id
	end

	def destroy
		portfolio=Portfolio.find(params[:id])
		Portfolio.delete_users_basic_portfolio_properties(portfolio)
		if portfolio.destroy
			redirect_to :action=>"index"
		end
	end

	#~ private
	def property_and_user_collection
		if params[:action]=="edit"
			leasing_type=(params[:value]=="multifamily" ? "multifamily" : "commercial")
			@portfolio=Portfolio.find(params[:id])
			@portfolio_properties,@portfolio_users=Portfolio.filter_based_on_portfolio(@portfolio,leasing_type)
		else
			@users=User.by_client_ids(current_user.client_id, current_user.email)
			@properties=RealEstateProperty.by_client_ids(current_user.client_id,"commercial",1,current_user.id)
		end
	end

	def edit_user_properties
		@portfolio=Portfolio.find(params[:id])
		@chart_type=@portfolio.try(:chart_of_account).try(:name)
		portfolio_properties=Portfolio.portfolios_properties(@portfolio)
		#~ portfolio_users=SharedFolder.find(:all,:conditions=>["is_portfolio_folder=? AND portfolio_id=?",true,@portfolio.id])
		portfolio_users=SharedFolder.by_portfolio_id(@portfolio.id)
		@property_type=@portfolio.leasing_type
		@portfolio_properties=portfolio_properties.present? ? portfolio_properties.map(&:real_estate_property_id) : []
		@portfolio_users=portfolio_users.present? ? portfolio_users.map(&:user_id) : []
		@users=User.by_client_ids(current_user.client_id,current_user.email)
		@properties=RealEstateProperty.by_client_ids(current_user.client_id,@property_type,@portfolio.chart_of_account_id,current_user.id)
		@commercial_count = @properties.count
	end

	def get_type_properties
		type=params[:value]=="1" ? "commercial" : "multifamily"
		@properties=RealEstateProperty.by_client_ids(current_user.client_id,type,params[:chart],current_user.id)
		if type == "commercial"
		@commercial_count=@properties.count
		multi_family = RealEstateProperty.by_client_ids(current_user.client_id,"multifamily",params[:chart],current_user.id)
		@multifamily_count = multi_family.count
		else
		commercial = RealEstateProperty.by_client_ids(current_user.client_id,"commercial",params[:chart],current_user.id)
		@commercial_count=commercial.count
		@multifamily_count = @properties.count
		end
		render :partial=>"properties_check", :locals => {:type => type,:properties =>@properties, :commercial_count => @commercial_count, :multifamily_count => @multifamily_count}
	end


	def find_properties_users
	@users=User.by_client_ids(current_user.client_id,current_user.email)
	@chart_of_accounts = current_user.client.chart_of_accounts
	@properties=RealEstateProperty.by_client_ids(current_user.client_id,"commercial",@chart_of_accounts.first.try(:id),current_user.id)
	@commercial_count=@properties.count
	@multifamily_properties=RealEstateProperty.by_client_ids(current_user.client_id,"multifamily",@chart_of_accounts.first.try(:id),current_user.id)
	@multifamily_count=@multifamily_properties.count
	end

	def other_properties
		@portfolio=Portfolio.find_by_id(params[:id])
		@other_properties=Portfolio.portfolios_properties(@portfolio)
	end

end



