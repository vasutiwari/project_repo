class NavDashboardController < ApplicationController
	before_filter :user_required
	layout 'nav_dashboard', :only=>[:dashboard]
	before_filter :change_session_value, :only=>[:dashboard,:graph_check]
	before_filter :commercial_and_multi_collection, :only => [:dashboard,:graph_check]
	def dashboard
		if request.xhr?
			portfolio = find_leasing_type_of_portfolio
			render :update do |page|
				if portfolio && portfolio.try(:leasing_type).eql?("Commercial")
					page.replace_html  "commercial_comparison", :partial => "/nav_dashboard/commercial_comparison",:locals => { :portfolio_id => params[:portfolio_id]}
				elsif portfolio && portfolio.try(:leasing_type).eql?("Multifamily")
					page.replace_html  "multifamily_comparison", :partial => "/nav_dashboard/multifamily_comparison",:locals => { :portfolio_id => params[:portfolio_id]}
				end
			end
		end
	end
	
	def graph_check
		portfolio = find_leasing_type_of_portfolio
		if portfolio && portfolio.try(:leasing_type).eql?("Commercial")
		render :partial => "commercial_comparison",:locals => { :portfolio_id => params[:portfolio_id]}
		elsif portfolio && portfolio.try(:leasing_type).eql?("Multifamily")
					render :partial => "multifamily_comparison",:locals => { :portfolio_id => params[:portfolio_id]}
		end
end
	
	def commercial_and_multi_collection
		find_properties_for_portfolio
  end

	
	def change_session_value
		 if (params[:portfolio_id].present? && params[:property_id].blank?)
		  session[:portfolio__id] = params[:portfolio_id]
      session[:property__id] = ""
    elsif (params[:portfolio_id].present? && params[:property_id].present?)
      session[:portfolio__id] = ""
      session[:property__id] = params[:property_id] || params[:nid]
		elsif( (session[:portfolio__id].present? && session[:property__id].blank?) )
		  session[:portfolio__id] = session[:portfolio__id]
      session[:property__id] = ""
		else
			session[:portfolio__id] = ""
      session[:property__id] = session[:property__id]
    end
  end
	
	def occupancy_type
	@real_estate_property_records=params[:real_estate_property_records]
		if params[:leasing_type]=="Commercial"
		render :partial =>"commercial_occupancy"
		else
		render :partial =>"multifamily_occupancy"
		end
	end
	
	def expiration_graph
		render :partial => "graph"
	end
	
	def call_updates_nav
		updates_display_for_dashboard
		render :partial => "updates"
	end
end
