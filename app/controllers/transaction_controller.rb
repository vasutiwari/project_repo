class TransactionController < ApplicationController
  before_filter :user_required,:except=>'share_link_folder_for_trans'
  before_filter :change_session_value, :only=>[:index]
  before_filter :check_property_access, :only=> [:index]
  before_filter :check_portfolio_access, :only=> [:index]
  layout :documents_change_layout,:except=>['view_folder']
  def index
    find_portfolios_to_display_in_collabhub
    if (@portfolios.nil? || @portfolios.blank?)
      redirect_to welcome_path(:from_view_coll=>true)
    end
    if params[:folder_type] == 'property'
      @property = SharedFolder.find_by_folder_id_and_user_id(params[:open_folder],User.current.id)
      if @property.blank?
        flash[:now] = 'This property has been revoked'
      end
    end
    render :action => "collaboration_hub/index"
  end

  def view_folder
    @folder = find_by_user_id_and_name(current_user.id,'my_deal_room')
    @portfolio = Portfolio.find(params[:pid])
    @portfolios = []
    @real_estate_properties = []
    @user = current_user
    @real_estate_properties = RealEstateProperty.find(:all, :conditions => ["real_estate_properties.user_id = ? and real_estate_properties.client_id =?",current_user.id,Client.current_client_id],:joins=>:portfolios, :select => "portfolios.id,real_estate_properties.id", :order => "real_estate_properties.created_at desc, real_estate_properties.last_updated desc")
    @portfolios = Portfolio.find(:all, :conditions => ["user_id = ? and portfolio_type_id = 2",current_user.id])
  end
  #To create a new folder
  def new_folder
    @folder = find_by_user_id_and_name(current_user.id,'my_deal_room')
    @portfolio = Portfolio.find(params[:pid])
    folder_name = find_folder_name(@folder.id,params[:folder_name])
    folder=Folder.create(:name=>folder_name,:parent_id=>@folder.id,:portfolio_id=>@portfolio.id,:user_id=>current_user.id,:real_estate_property_id=>@folder.real_estate_property_id)
    responds_to_parent do
      render :update do |page|
        page.hide 'modal_container'
        page.hide 'modal_overlay'
        page.call "flash_writter", "Folder successfully created"
      end
    end
  end
  def share_link_folder_for_trans
    logout_keeping_session!
    render :action => "collaboration_hub/index"
  end
  def documents_change_layout
     current_user.nil? ? 'user_login' : 'user'
   end

   def change_session_value
		 if ( (params[:portfolio_id].present? && params[:property_id].blank?) || (params[:pid].present? && params[:nid].blank?) || (params[:real_estate_id].present? && params[:id].blank?) )
		  session[:portfolio__id] = params[:portfolio_id] || params[:pid] || params[:real_estate_id]
      session[:property__id] = ""
    elsif ( (params[:portfolio_id].present? && params[:property_id].present?) || (params[:pid].present? && params[:nid].present?) || (params[:real_estate_id].present? && params[:id].present?) )
      session[:portfolio__id] = ""
      session[:property__id] = params[:property_id] || params[:id] || params[:nid]
		elsif( (session[:portfolio__id].present? && session[:property__id].blank?) )
		  session[:portfolio__id] = session[:portfolio__id]
      session[:property__id] = ""
		else
			session[:portfolio__id] = ""
      session[:property__id] = session[:property__id]
    end
  end

  def check_property_access

   id = params[:id].present? ? params[:id] : params[:property_id].present? ? params[:property_id] : params[:nid].present? ? params[:nid] : @property.present? ? @property.try(:id) : @note.present? ? @note.id : ""

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

  def check_portfolio_access
    if (params[:portfolio_id].present? && params[:property_id].blank?)
      id = params[:real_estate_id].present? ? params[:real_estate_id] : params[:portfolio_id].present? ? params[:portfolio_id] : params[:pid].present? ? params[:pid] : @portfolio.present? ? @portfolio.try(:id) : ""
      if id.present?
        portfolios = Portfolio.find_portfolios(current_user)
        @portfolio_ids = portfolios.present? ? portfolios.map(&:id) : []
        unless @portfolio_ids.include?(id.to_i)
        properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(current_user.id,prop_folder=true)
        last_portfolio, first_property = Portfolio.last_created_portfolio_of_a_user(current_user)
        if last_portfolio.present? && first_property.present?
          redirect_to financial_info_path(last_portfolio.try(:id), first_property.try(:id),:port_access=>'true')
        elsif properties.present?
          redirect_to financial_info_path(properties.last.try(:portfolio_id), properties.last.try(:id),:port_access=>'true')
        else
          redirect_to notify_admin_path(:from_session=> true)
        end
      end
      end
  end
  end


end
