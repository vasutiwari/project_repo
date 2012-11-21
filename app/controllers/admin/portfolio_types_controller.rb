class Admin::PortfolioTypesController < ApplicationController
	layout 'admin'
	before_filter :admin_login_required
	before_filter :portfolio_type_find, :only=>['edit','update']
	
	def index
		#@portfolio_type = PortfolioType.find(:all)
		@portfolio_type =	PortfolioType.find(:all,:page => params[:page]).paginate(:per_page =>10,:order=>"created_at desc")
		if request.xhr?
			render :update do |page|
				page.replace_html 'portfolio_list',:partial=>'portfolio_list',:locals=>{:portfolio_type => @portfolio_type}
			end
		end
	end
	
	def new
		
	end
	
	def create
		@portfolio_type = PortfolioType.new(params[:portfolio_type])
    if @portfolio_type.save
      flash[:notice] = FLASH_MESSAGES['portfoliotype']['4001']
      redirect_to admin_portfolio_types_path
    else
      render :action => 'new'
    end
	end
	
	def edit		
	end
	
	def update
		if @portfolio_type.update_attributes(params[:portfolio_type])
      flash[:notice] = FLASH_MESSAGES['portfoliotype']['4002']
      redirect_to admin_portfolio_types_path
    else
      render :action => 'edit'
    end
	end
	
	def destroy
		PortfolioType.find(params[:id]).destroy if params[:id] rescue nil
		redirect_to admin_portfolio_types_path
	end
	
	def  portfolio_type_find
		@portfolio_type = PortfolioType.find(params[:id])
	end
end