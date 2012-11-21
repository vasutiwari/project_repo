class RealEstatesController < ApplicationController
  before_filter :user_required, :set_current_user
  before_filter :change_session_value, :only=>[:add_property]
  before_filter :check_property_access, :only=> [:add_property]
  layout "user"

  def add_property
    if params[:property_id]
      @property = RealEstateProperty.find_real_estate_property(params[:property_id])
      suites_build_and_collection(@property)  if params[:form_txt] == "suites" || params[:suites_form_submit] == "true"
      find_suite_and_collection(params[:suite_id], @property)  if params[:suite_id]
      else
      @property = RealEstateProperty.new
      create_new_property if params[:property]
    end
    @heading = params[:from_debt_summary] == "true" ? "Edit #{@property.property_name}" : (params[:from_property_details] == "true" ? "Edit #{@property.property_name}" : ( params[:edit_inside_asset] == 'true' ?  "Edit #{@property.property_name}" : ( params[:setup_edit_prop] == 'true' ?  "Edit #{@property.property_name}" : params[:call_from_prop_files] == "true" ? 'Add / Edit Property Users' : 'Add Property')) )
    @portfolio = Portfolio.find_by_id(params[:id])
    if params[:is_property_folder] == "true"
      params[:highlight] = 3
    elsif params[:highlight]
      @highlight = 1
    else
      params[:highlight] = 2
    end
      #~ render :update do |page|
        #~ page.replace_html 'show_assets_list',:partial=>"add_property"
      #~ end

    #~ if params[:tab_id]
      #~ render :update do |page|
        #~ page.replace_html 'sheet123',:partial=>"add_or_edit_property"
      #~ end
    #~ end
  end

  def add_property_restricted
    @portfolio = Portfolio.find_by_id(params[:id])
  end

  def new_property
      @property = RealEstateProperty.new
      create_new_property if params[:property]
    @heading = params[:from_debt_summary] == "true" ? "Edit #{@property.property_name}" : (params[:from_property_details] == "true" ? "Edit #{@property.property_name}" : ( params[:edit_inside_asset] == 'true' ?  "Edit #{@property.property_name}" : ( params[:setup_edit_prop] == 'true' ?  "Edit #{@property.property_name}" : params[:call_from_prop_files] == "true" ? 'Add / Edit Property Users' : 'Add Property')) )
    @portfolio = Portfolio.find_by_id(params[:id])
  end

  def change_session_value
		 if ( (params[:portfolio_id].present? && params[:property_id].blank?) || (params[:pid].present? && params[:nid].blank?) || (params[:real_estate_id].present? && params[:id].blank?) || (params[:id].present? && params[:property_id].blank?)  )
		  session[:portfolio__id] = params[:portfolio_id] || params[:pid] || params[:real_estate_id]
      session[:property__id] = ""
    elsif ( (params[:portfolio_id].present? && params[:property_id].present?) || (params[:pid].present? && params[:nid].present?) || (params[:real_estate_id].present? && params[:id].present?) || (params[:id].present? && params[:property_id].present?))
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

  def check_property_access

    id = params[:property_id].present? ? params[:property_id] : params[:nid].present? ? params[:nid] : @property.present? ? @property.try(:id) : @note.present? ? @note.id : ""

    if id.present?
      properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(current_user.id,prop_folder=true)
      @property_ids = properties.present? ? properties.map(&:id) : []
      unless @property_ids.include?(id.to_i)
        last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
        if last_portfolio.present? && first_property.present?
          redirect_to financial_info_path(last_portfolio.try(:id), first_property.try(:id),:access=>'true')
        elsif properties.present?
          redirect_to financial_info_path(properties.last.try(:portfolio_id), properties.last.try(:id),:access=>'true')
        else
          redirect_to notify_admin_path(:from_session=> true)
        end
      end
    end
  end

end
