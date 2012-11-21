class PortfoliosController < ApplicationController
  before_filter :user_required
  before_filter :check_leasing_agent,:except =>['edit_portfolio_real_picture','update_portfolio_real_picture']
  layout "user", :except=>[:edit_portfolio_real_picture]

def index
    @portfolio_type=PortfolioType.find_by_name('Real Estate')
    @portfolios = Portfolio.find(:all, :conditions=>['user_id = ? and portfolio_type_id = ? and name not in (?)', User.current,@portfolio_type.id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]], :order=> "created_at desc")
    find_time_period;init_chart;
    @portfolios = Portfolio.find_shared_and_owned_portfolios(User.current.id)
    #@note = RealEstateProperty.find(:first, :conditions=>['portfolio_id = ? or portfolio_id = ? and property_name not in (?)', @portfolios.first.id,params[:portfolio_id],["property_created_by_system","property_created_by_system_for_deal_room"]], :order=> "created_at desc") if !@portfolios.blank?
    @portfolio_index= true
    @notes = RealEstateProperty.find_owned_and_shared_properties(@portfolios.first,User.current.id,params[:prop_folder])  if !@portfolios.blank?
    if @notes && !@notes.empty?
    @note = @notes.first
    @note_old =  @note
  end
  unless @portfolios.blank?
      @portfolio = params[:portfolio_id].present? ? Portfolio.find(params[:portfolio_id]) : @portfolios.first
      portfolio_overview_noi_capital_exp_occupancy(@portfolio.id) if !@portfolio.real_estate_properties.empty?
      @note = @note_old
      @folder = Folder.find(:all, :conditions => ["parent_id = ? and is_master = ? and user_id = ? and portfolio_id = ?",0,0,User.current,@portfolio.id], :order=> "name #{params[:order]}")
      calculate_noi_and_occupancy if !@real_properties.blank?
      render :action => 'index.js.rjs' if request.xhr?
    else
      if params[:from_view];redirect_to welcome_path(:from_view_port=>true,:asset_view=>true);else;redirect_to welcome_path(:from_view_port=>true);end;
    end
  end

  def new
    @portfolio_id=params[:id]
    render :update do |page|
      page.replace_html 'show_assets_list', :partial => '/portfolios/datahub_header'
    end
  end

  def create
    @portfolio = Portfolio.new(params[:portfolio])
    @portfolio_image = PortfolioImage.new(params[:portfolio_image]) if params[:portfolio_image]
    @portfolio.portfolio_image = @portfolio_image if @portfolio_image
    @portfolio.user_id = current_user.id
    if @portfolio.valid? and @portfolio.save
      Folder.create(:name=>@portfolio.name,:portfolio_id=>@portfolio.id,:user_id=>current_user.id,:parent_id=>-1,:is_master=>0,:is_deleted=>0,:is_deselected=>0)
      flash[:notice] = FLASH_MESSAGES['portfolios']['504']
      redirect_to portfolios_path
    else
      redirect_to "/welcome"
    end
  end

  def show
    @portfolio = Portfolio.find_by_id(params[:id])
    session[:portfolio_id] = params[:id] if params[:id].present?
    @portfolios = Portfolio.find_shared_and_owned_portfolios(User.current.id)
    find_time_period
    if !@portfolios.blank? && Portfolio.exists?(params[:id])
      if @portfolios.collect { |x| x.id }.include?(params[:id].to_i)
        prop_condition = "and r.property_name not in ('property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload')"
	@note = RealEstateProperty.find_properties_by_portfolio_id_with_cond(@portfolio.id,prop_condition,"order by r.created_at desc limit 1")[0] if !@portfolios.nil?
        session[:property_id] = @note
        @notes = RealEstateProperty.find_owned_and_shared_properties(@portfolios.first,User.current.id,params[:prop_folder])  if !@portfolios.blank?
        @note_old =  @note
        portfolio_overview_noi_capital_exp_occupancy(@portfolio.id) if !@portfolio.real_estate_properties.empty?
        @note = @note_old
        init_chart
        calculate_noi_and_occupancy if !@real_properties.blank?
        flash[:notice] = FLASH_MESSAGES['portfolios']['501'] if !@note && params[:show_notice] == 'true'
        #~ flash[:notice] = FLASH_MESSAGES['portfolios']['501'] if !@note
        render :action => 'index'
        return
      else
        flash[:notice]=FLASH_MESSAGES['portfolios']['508']
        redirect_to portfolios_path
        return
      end
      if request.xhr?
        #~ render :update do |page|
          #~ page.replace_html "overview", :partial => "portfolio_real_overview",:locals=>{:periods=>@period,:real_properties=>@real_properties,:portfolio_collection=>@portfolio,:graph_period=>@graph_period,:hash_portfolio_occupancy=>@hash_portfolio_occupancy,:operating_statement=>@operating_statement,:net_income_de=>@net_income_de,
        #~ :year_to_date=>@year_to_date,:divide=>@divide}
        #~ end
      end
    else
      flash[:notice]= FLASH_MESSAGES['portfolios']['506']
      redirect_to portfolios_path
    end
  end

  #initialize chart
  def init_chart
    @partial_file = "/properties/sample_pie"
    @swf_file = "Pie2D.swf"
    @xml_partial_file = "/properties/sample_pie"
  end

  #for sorting in overview tab
  def portfolio_overview_index
    index
  end

  #Time line based portfolios overview
  def select_time_period_real_overview
    params[:period] = params[:period] ? params[:period] : "9"
    @portfolio = params[:id] ? Portfolio.find_by_id(params[:id]) : Portfolio.find_by_id(params[:portfolio_id])
    @note = RealEstateProperty.find_properties_by_portfolio_id_with_cond(@portfolio.id,"","order by r.created_at desc limit 1")[0] unless @portfolio.nil?
    find_time_period;init_chart;
    fail,display_head=0,''
    if params[:period] == "9"
    @portfolios = Portfolio.find(:all, :conditions=>['user_id = ? and portfolio_type_id = ? and name not in (?)', User.current,2,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]])
    else
    @portfolios = Portfolio.find(:all, :conditions=>['user_id = ? and portfolio_type_id = ? and name not in (?)', User.current,2,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]], :order=>params[:sort])
    end
    if @portfolio != nil
      if params[:period] == "9"
         prop_condition = " and r.property_name  not in ('property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload')"
         prop_sort = params[:prop_sort] ? "order by #{params[:prop_sort]}" : ""
	@real_properties = RealEstateProperty.find_properties_by_portfolio_id_with_cond(@portfolio.id,prop_condition,prop_sort)
      else
        @real_properties = RealEstateProperty.find(:all, :conditions=>["portfolios.id=? and property_name not in (?)", @portfolio.id,["property_created_by_system","property_created_by_system_for_deal_room","property_created_by_system_for_bulk_upload"]],:joins=>:portfolios).paginate(:page=>params[:page], :per_page=>10,:order=>params[:sort]) if !@portfolios.blank?
      end
    elsif !@portfolios.blank?
      @portfolio = @portfolios.first
      @real_properties = RealEstateProperty.find(:all, :conditions=>["portfolios.id=? and property_name not in (?)", @portfolios.first.id,["property_created_by_system","property_created_by_system_for_deal_room","property_created_by_system_for_bulk_upload"]],:joins=>:portfolios).paginate(:page=>params[:page], :per_page=>10,:order=>params[:sort]) if !@portfolios.blank?
    end
    unless params[:period] == "9"
      portfolio_overview_noi_capital_exp_occupancy(@portfolio.id)
      calculate_noi_and_occupancy if !@real_properties.blank?
    else
      date_calc(@real_properties)
      property_count = @prop_id_coll.count
     for i in 0...property_count
    date = params[:prev_date] ? params[:prev_date].to_date : ( params[:next_date] ? params[:next_date].to_date : (params[:cur_date] ? params[:cur_date].to_date : @prev_sunday))
    calculate_portfolio_weekly_report(@prop_id_coll[i],date.strftime("%Y-%m-%d"))
    fail+=1 if @property_week_floor[0].nil?
  end
  display_head = property_count == fail ? 'No Display' : 'Display'
      #      calculate_portfolio_weekly_report
    end
    #~ render :update do |page|
      #~ if params[:partial_page] == "portfolio_real_overview" || params[:period] == "9"
            #~ page.replace 'show_assets_list', :partial => 'portfolio_real_overview' ,:locals=>{:periods=>@period,:note=>@note,:real_properties=>@real_properties,:portfolio_collection=>@portfolio,:graph_period=>@graph_period,:hash_portfolio_occupancy=>@hash_portfolio_occupancy,:operating_statement=>@operating_statement,:net_income_de=>@net_income_de,
              #~ :year_to_date=>@year_to_date,:divide=>@divide,:display_head=>display_head}
      #~ end
    #~ end
    render :update do |page|
      if params[:partial_page] == "portfolio_real_overview" || params[:period] == "9"
            page.replace_html 'multifamily_data', :partial => 'portfolio_weekly_display' ,:locals=>{:note_collection=>@note,:periods=>9,:real_properties=>@real_properties,:portfolio_collection=>@portfolio,:year_to_date=>@year_to_date,:display_head=>display_head}
      end
    end
  end

  #find shared portfolios of current user
  def find_shared_portfolios
    shared_portfolios = []
    props = RealEstateProperty.find_by_sql("SELECT * FROM real_estate_properties WHERE id in (SELECT real_estate_property_id FROM shared_folders WHERE is_property_folder = 1 AND user_id = #{User.current.id} and client_id = #{User.current.client_id} ) order by created_at desc")
    shared_portfolios << props.collect { |p| p.portfolio }
    shared_portfolios.blank? ? [] : shared_portfolios.flatten.compact.uniq
  end
=begin
  # called while Portfolios->overview tab navigation and properties pagination in overview tab
  def show_real_overview
    @portfolio = Portfolio.find(params[:id])
    session[:portfolio_id] = params[:id] if params[:id].present?
     prop_condition = " and r.property_name  not in ('property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload')"
    @note = RealEstateProperty.find_properties_by_portfolio_id_with_cond(@portfolio.id,prop_condition,"order by created_at desc limit 1")[0] if !@portfolio.nil?
    session[:property_id] = params[:property_id].present? ? params[:property_id] : @note
    init_chart;find_time_period;
    fail,display_head=0,''

    if @portfolio.leasing_type=="Multifamily" &&  params[:period] == "9"
      @period = '9'
    elsif params[:period] == "9" && @portfolio.leasing_type !="Multifamily"
      params[:period] = "4"
      @period = '4'
     end

    if params[:period] == "9" && (@note && !@note.nil?) &&  @portfolio.leasing_type == "Multifamily" #(account_system_type_name(@note.accounting_system_type_id) == "Real Page" || account_system_type_name(@note.accounting_system_type_id) == "YARDI" )
      @period = "9"
      @portfolios = Portfolio.find(:all, :conditions=>['user_id = ? and portfolio_type_id = ? and name not in (?)', User.current,2,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]])
      prop_sort = params[:prop_sort] ? "order by #{params[:prop_sort]}" : ""
      if @portfolio != nil
       @real_properties = RealEstateProperty.find_properties_by_portfolio_id_with_cond(@portfolio.id,prop_condition,prop_sort) if @portfolio
     elsif !@portfolios.blank?
        @portfolio = @portfolios.first
       @real_properties = RealEstateProperty.find_properties_by_portfolio_id_with_cond(@portfolio.id,prop_condition,prop_sort) if @portfolio
      end
      date_calc(@real_properties)
      property_count = @prop_id_coll.count
     for i in 0...property_count
    date = (params[:prev_date] && !params[:prev_date].blank?) ? params[:prev_date].to_date : ( (params[:next_date] && !params[:next_date].blank?) ? params[:next_date].to_date : ((params[:cur_date] && !params[:cur_date].blank?) ? params[:cur_date].to_date : @prev_sunday))
    calculate_portfolio_weekly_report(@prop_id_coll[i],date.strftime("%Y-%m-%d"))
    fail+=1 if @property_week_floor[0].nil?
     end
    elsif  params[:period] == "9" && (@note && !@note.nil?) &&  @portfolio.leasing_type != "Multifamily" #&& (account_system_type_name(@note.accounting_system_type_id) != "Real Page" && account_system_type_name(@note.accounting_system_type_id) != "YARDI" )
      @period,params[:period] = "4","4"
       portfolio_overview_noi_capital_exp_occupancy(@portfolio.id) if !@portfolio.real_estate_properties.empty?
      calculate_noi_and_occupancy if !@real_properties.blank?
    else
      portfolio_overview_noi_capital_exp_occupancy(@portfolio.id) if !@portfolio.real_estate_properties.empty?
      calculate_noi_and_occupancy if !@real_properties.blank?
    end
    display_head = property_count == fail ? 'No Display' : 'Display'
#    unless params[:period] == "9"
#      portfolio_overview_noi_capital_exp_occupancy(@portfolio.id) if !@portfolio.real_estate_properties.empty?
#      calculate_noi_and_occupancy if !@real_properties.blank?
#    else
#      @portfolios = Portfolio.find(:all, :conditions=>['user_id = ? and portfolio_type_id = ? and name not in (?)', User.current,2,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]])
#      if @portfolio != nil
#        @real_properties = RealEstateProperty.find(:all, :conditions=>['portfolio_id=? and property_name not in (?)', @portfolio.id,["property_created_by_system","property_created_by_system_for_deal_room","property_created_by_system_for_bulk_upload"]],:order=>params[:prop_sort]) if !@portfolios.blank?
#      elsif !@portfolios.blank?
#        @portfolio = @portfolios.first
#        @real_properties = RealEstateProperty.find(:all, :conditions=>['portfolio_id=? and property_name not in (?)', @portfolios.first.id,["property_created_by_system","property_created_by_system_for_deal_room","property_created_by_system_for_bulk_upload"]],:order=>params[:prop_sort]) if !@portfolios.blank?
#      end
#      date_calc(@real_properties)
#    end
    #~ render :update do |page|
        #~ page.replace_html "overview", :partial => "portfolio_real_overview",:locals=>{:periods=>@period,:real_properties=>@real_properties,:portfolio_collection=>@portfolio,:graph_period=>@graph_period,:hash_portfolio_occupancy=>@hash_portfolio_occupancy,:operating_statement=>@operating_statement,:net_income_de=>@net_income_de,
          #~ :year_to_date=>@year_to_date,:divide=>@divide,:display_head=>display_head}
    #~ end
  end
=end
  def edit_portfolio_real_picture;end

  #to update portfolio picture
  def update_portfolio_real_picture
    @portfolio_image=PortfolioImage.find_by_attachable_id_and_attachable_type(params[:id],'Portfolio')
    if !@portfolio_image.nil? && params[:portfolio_image][:uploaded_data]
      @portfolio_image.update_attributes(:uploaded_data=>params[:portfolio_image][:uploaded_data])
    else
      @portfolio=Portfolio.find_by_id(params[:id])
      @portfolio_image=PortfolioImage.new(:uploaded_data=>params[:portfolio_image][:uploaded_data]) if params[:portfolio_image][:uploaded_data]
      @portfolio.portfolio_image=@portfolio_image if @portfolio_image
      @portfolio.save
    end
    responds_to_parent do
      render :action => 'update_portfolio_real_picture.rjs'
    end
  end

  #delete portfolio
  def destroy_portfolio
    @portfolios = Portfolio.find_shared_and_owned_portfolios(User.current.id)
    @properties = RealEstateProperty.find(:all, :conditions=>["portfolios.id=?", @portfolios.first.id ],:joins=>:portfolios).paginate(:page=>params[:page], :per_page=>10, :order=> "real_estate_properties.created_at desc") if !@portfolios.blank?
    if Portfolio.exists?(params[:id])
      @portfolio = Portfolio.find_by_id(params[:id])
      @portfolio.destroy
      flash[:notice] = FLASH_MESSAGES['portfolios']['505']
    end
    redirect_to portfolios_path
  end

  #to rename portfolio
  def rename_portfolio
    @new_portfolio = Portfolio.portfolio_rename(params[:id],params[:value])
  end

  def calculate_noi_and_occupancy
    @graph_period =  params[:period]  == "5" ? Date.today.prev_month.strftime("%Y-%m") : Date.today.strftime("%Y-%m")
    @year_to_date = @period == "4" ? true : false
    find_net_operating_income_summary_portfolio(@portfolio.id,@period)
    @hash_portfolio_occupancy =  !(@portfolio.leasing_type== "Multifamily") ? hash_formation_for_portfolio_occupancy(@graph_period,@year_to_date,@portfolio.id) :  wres_hash_formation_for_portfolio_occupancy(@graph_period,@year_to_date,@portfolio.id)
  end
end
