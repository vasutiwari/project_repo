module NavDashboardHelper
  #dashboard update display 
  def updates_display_for_dashboard
    @portfolio_real_estates = Portfolio.find_shared_and_owned_portfolios(User.current.id)
    @real_estate_properties = RealEstateProperty.find_by_sql("SELECT id FROM real_estate_properties WHERE id in (SELECT real_estate_property_id FROM shared_folders WHERE is_property_folder = 1 AND user_id = #{User.current.id} )")
    @real_estate_properties += RealEstateProperty.properties_of_portfolio_ids(@portfolio_real_estates.collect{|portfolio| portfolio.id }) unless @portfolio_real_estates.blank?
    #to get myfiles folder
    user_owned_folders = Folder.current_user_files
    user_owned_folders += Folder.find_by_sql("select id from folders where parent_id = #{user_owned_folders.first.id}") unless user_owned_folders.blank?
    #to get myfiles files
    user_owned_docs = Document.current_user_files(user_owned_folders.collect{|folder| folder.id} ) unless user_owned_folders.blank?
    @updated_properties = RealEstateProperty.find(:all, :conditions => ["id in (?) and real_estate_properties.property_name not in (?)",@real_estate_properties.collect{|y| y.id},["property_created_by_system","property_created_by_system_for_deal_room","property_created_by_system_for_bulk_upload"]], :order => "last_updated desc, created_at desc", :limit=>5)
    @updated_files = Document.find(:all, :conditions => ["user_id = ? && is_deleted = ? && is_master = ?",User.current,false,false], :order => "created_at desc", :limit=>5)
    events_conditions = []
    events_real_estates= RealEstateProperty.find(:all, :conditions => ["id in (?) and real_estate_properties.property_name not in (?)",@real_estate_properties.collect{|y| y.id},["property_created_by_system","property_created_by_system_for_deal_room","property_created_by_system_for_bulk_upload"]], :select=>"id")
    find_bool , event_real_ids = !(events_real_estates.nil? || events_real_estates.blank?) , events_real_estates.collect{|x4| x4.id}
    real_estate_properties_folders = Folder.find(:all, :conditions => ["real_estate_property_id in (?) and is_master = 0",event_real_ids], :select => "id,user_id,parent_id,is_master") if find_bool
    real_estate_properties_documents = Document.find(:all, :conditions => ["real_estate_property_id in (?)",event_real_ids], :select => "id,user_id") if find_bool
    real_estate_properties_folders = real_estate_properties_folders.collect{|real_prop_folder| real_prop_folder if check_is_folder_shared(real_prop_folder) == "true"}.compact if find_bool && !real_estate_properties_folders.empty?
    real_estate_properties_documents = real_estate_properties_documents.collect{|real_prop_doc| real_prop_doc if check_is_doc_shared(real_prop_doc) == "true"}.compact if find_bool && !real_estate_properties_documents.empty?
    events_conditions = "(resource_id IN (#{real_estate_properties_folders.collect{|x7| x7.id}.join(',')}) and resource_type = 'Folder')"   if !(real_estate_properties_folders.nil? || real_estate_properties_folders.blank?)
    events_conditions << " #{check_or_flag(events_conditions)} (resource_id IN (#{real_estate_properties_documents.collect{|x8| x8.id}.join(',')}) and resource_type = 'Document')" if !(real_estate_properties_documents.nil? || real_estate_properties_documents.blank?)
    events_conditions << " #{check_or_flag(events_conditions)} (resource_id IN (#{user_owned_folders.collect{|x10| x10.id}.join(',')}) and resource_type = 'Folder')" if !(user_owned_folders.nil? || user_owned_folders.blank?)
    events_conditions << " #{check_or_flag(events_conditions)} (resource_id IN (#{user_owned_docs.collect{|x11| x11.id}.join(',')}) and resource_type = 'Document')"   if !(user_owned_docs.nil? || user_owned_docs.blank?)
    if !(events_conditions.nil? || events_conditions.blank?)
      folder_events = EventResource.find(:all, :conditions=>["#{events_conditions}"])
      action_type = ["create","upload","new_version","delete","download","rename","shared","moved","copied","commented","restored","unshared","del_comment","rep_comment","up_comment","collaborators","de_collaborators","sharelink"]
      @events = Event.find(:all, :conditions=>["id IN (?) and action_type in (?)",folder_events.collect{|x13| x13.event_id},action_type], :order=>'created_at desc')   if !(folder_events.nil? || folder_events.blank?) #:limit => 6 removed for dashboard
    end
  end
	
	def check_or_flag(events_conditions)
    or_flag = !events_conditions.empty? ? " or " : " "
  end
  
  def find_leasing_type_of_portfolio
    Portfolio.find(params[:portfolio_id]) if params[:portfolio_id]
  end
  
  def find_properties_for_portfolio
    if params[:portfolio_id].present? && params[:property_id].blank?
      session[:portfolio_id1] = params[:portfolio_id]
    end
    portfolio_id = session[:portfolio_id1]
    portfolios = Portfolio.find_shared_and_owned_portfolios(current_user.id)
    shared_comm,shared_mul = [],[]
		commercial = RealEstateProperty.find(:all, :conditions=>["real_estate_properties.leasing_type=? and portfolios.id=? and property_name not in (?) and real_estate_properties.client_id = #{current_user.client_id}",'Commercial', portfolio_id.to_i,['property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload']],:joins=>:portfolios,:order=> "real_estate_properties.created_at desc")
		commercial = commercial #<< shared_comm.flatten
		@commercial = commercial.flatten.uniq
		@comm_count = @commercial.count
		multi = RealEstateProperty.joins(:portfolios).where("real_estate_properties.leasing_type=? and portfolios.id=? and property_name not in (?) and real_estate_properties.client_id = ?",'Multifamily', portfolio_id.to_i, ['property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload'],current_user.client_id) #.order(), :order=> "created_at desc")
    multi = multi #<< shared_mul.flatten
      @multi = multi.flatten.uniq
      @multi_count = @multi.count
    commercial_leases = RealEstateProperty.find(:all, :conditions=>["real_estate_properties.leasing_type=? and portfolios.id=? and property_name not in (?) and real_estate_properties.user_id = ? and real_estate_properties.client_id = #{current_user.client_id}",'Commercial', portfolio_id.to_i,['property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload'],current_user.id],:joins=>:portfolios, :order=> "real_estate_properties.created_at desc")
      commercial_leases = commercial_leases #<< shared_comm.flatten
      @commercial_leases = commercial_leases.flatten.uniq
      @comm_leases_count = @commercial_leases.count
      @portfolio_count = Portfolio.find_shared_and_owned_portfolios(User.current.id)
      @from_dash_board = true
    end
    
  def find_sort_type(sort_value,financial_access)
    if sort_value == 'vacancy_sf'
      sort_name = "Vacancy"
    elsif sort_value == 'expiration'
      sort_name = "Expirations"
    elsif sort_value== 'tenant'
      sort_name = "Tenant A/R"
    else
      if financial_access
        sort_name = "YTD - NOI Variances"
      else
        sort_name = "Vacancy"
      end
    end
    return sort_name
  end
  
  def find_url_for_nav_dashboard_commercial_property(portfolio_id, property_id,sort=nil,financial_access=nil)
      if sort && (sort.eql?("vacancy_sf") || sort.eql?("expiration"))
        url = "/dashboard/#{portfolio_id}/property_commercial_leasing_info/#{property_id}"
      elsif sort && sort.eql?("tenant")
        url = "/dashboard/#{portfolio_id}/properties"
      elsif ((sort && sort.eql?("neg_noi_percentage")) || sort.eql?("false")) && (financial_access.eql?(true))
        url = "/dashboard/#{portfolio_id}/financial_info/#{property_id}/financial_info"
      else
        url = "/dashboard/#{portfolio_id}/property_commercial_leasing_info/#{property_id}"
      end
      return url
  end
    
  def find_url_for_nav_dashboard_multifamily_property(portfolio_id, property_id,sort=nil,financial_access=nil)
      if sort && sort.eql?("vacancy_sf") 
        url = "/dashboard/#{portfolio_id}/property_multifamily_leasing_info/#{property_id}"
      elsif ((sort && sort.eql?("neg_noi_percentage")) || sort.eql?("false")) && (financial_access.eql?(true))
        url = "/dashboard/#{portfolio_id}/financial_info/#{property_id}/financial_info"
      else
        url = "/dashboard/#{portfolio_id}/property_multifamily_leasing_info/#{property_id}"
      end
      return url
  end
    
    
    
end
