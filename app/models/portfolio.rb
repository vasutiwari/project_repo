class Portfolio < ActiveRecord::Base
  has_many :real_estate_properties, :dependent=>:destroy
  has_one :portfolio_image ,:as => :attachable,:dependent=>:destroy
  has_one :excel_template, :dependent=>:destroy
  has_many :folders, :dependent=>:destroy
  has_many :property_capital_improvements
  has_many :shared_folders, :dependent=>:destroy
  has_many    :assets, :as => :assetable, :class_name => "Ckeditor::Asset"
  #many to many with real estate property
  has_and_belongs_to_many :real_estate_properties
  belongs_to :portfolio_type
  belongs_to :user
  belongs_to :chart_of_account
  validates_presence_of :name ,:message => "Please provide portfolio name"
  validates_uniqueness_of :name , :message => "Portfolio already exists" ,:scope => [:user_id,:portfolio_type_id]
  before_save :update_client_id_for_portfolio
  #~ before_destroy :delete_users_basic_portfolio_properties
  #Scope to find the portflios based on client admin ids

  scope :by_user_ids, (lambda do |user_id|
    {:conditions => ['user_id = ? and name NOT in (?) and is_basic_portfolio = ?', user_id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"],false]}
  end)

  scope :by_user_id_and_name, (lambda do |user_id,name|
    {:conditions => ['user_id = ? and name = ?', user_id,name]}
  end)

  scope :with_user_portfolios, (lambda do |users_portfolios|
    {:conditions=>["id in (?) and name NOT in (?)",users_portfolios,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]]}
  end)
  #  ================================= Main Code for PropertyCapitalImprovement ======================================
  def self.portfolio_pci(portfolio_id, month = 0, year=Time.now.year)
    #portfolio id will be sent
    portfolio = Portfolio.find_by_id(portfolio_id)

    #collect all properties of portfolio
    properties = portfolio.real_estate_properties.collect{|x|x.id}
    pci = PropertyCapitalImprovement.find(:all, :conditions=>['real_estate_property_id IN (?) and tenant_name like ? and month =? and year =?',properties,'Total%',month, year], :group=>'tenant_name')

    pci.each do |pci_prop|
      prop_fin = []
      portfolio_annual_budget = 0

      portfolio_pci = PropertyCapitalImprovement.find_by_portfolio_id_and_tenant_name_and_month_and_year(portfolio_id, pci_prop.tenant_name, pci_prop.month, pci_prop.year)

      if portfolio_pci.blank?
        portfolio_pci = pci_prop.clone
        portfolio_pci.portfolio_id = portfolio_id
        portfolio_pci.real_estate_property_id = nil
      portfolio_pci.save
      end

      properties.each do |prop|
        rec = PropertyCapitalImprovement.find(:first, :conditions=>['real_estate_property_id = ? and tenant_name like ? and month =? and year =?',prop, pci_prop.tenant_name, month, year])
        portfolio_annual_budget += rec.annual_budget.to_f if rec
        prop_fin << rec.id if rec
      end
      portfolio_pci.annual_budget = portfolio_annual_budget
      portfolio_pci.save
      create_prop_fin_for_pci(prop_fin, portfolio_pci.id) if prop_fin.present?
    end
    puts 'completed'
  end

  def self.create_prop_fin_for_pci(prop_fin_ids, portfolio_fin_id)
    pcb_types = ['p','c','b','c_ytd','b_ytd','var_amt','var_per','var_amt_ytd','var_per_ytd','c_ytd12','b_ytd12']
    pcb_types.each do |pcb_type|
      sum_values = PropertyFinancialPeriod.find_by_sql("select sum(january) as january, sum(february) as february, sum(march) as march, sum(april) as april , sum(may) as may, sum(june) as june, sum(july) as july, sum(august) as august, sum(september) as september,sum(october) as october, sum(november) as november, sum(december) as december, sum(dollar_per_sqft) as dollar_per_sqft, sum(dollar_per_unit) as dollar_per_unit  from property_financial_periods where pcb_type= '#{pcb_type}' and source_id in (#{prop_fin_ids.join(',')}) and source_type='PropertyCapitalImprovement'")
      sum_values.each do |sum_value|
        portfolio_fin_period = PropertyFinancialPeriod.find_by_source_id_and_source_type_and_pcb_type(portfolio_fin_id, 'PropertyCapitalImprovement', pcb_type)

        if portfolio_fin_period.blank?
          PropertyFinancialPeriod.create(:source_id => portfolio_fin_id, :source_type => 'PropertyCapitalImprovement', :pcb_type => pcb_type, :january => sum_value.january, :february => sum_value.february, :march => sum_value.march, :april => sum_value.april, :may => sum_value.may, :june => sum_value.june, :july => sum_value.july, :august => sum_value.august,:september => sum_value.september, :october => sum_value.october,:november => sum_value.november, :december => sum_value.december, :dollar_per_sqft => sum_value.dollar_per_sqft, :dollar_per_unit => sum_value.dollar_per_unit)
        else
          portfolio_fin_period.update_attributes(:source_id => portfolio_fin_id, :source_type => 'PropertyCapitalImprovement', :pcb_type => pcb_type, :january => sum_value.january, :february => sum_value.february, :march => sum_value.march, :april => sum_value.april, :may => sum_value.may, :june => sum_value.june, :july => sum_value.july, :august => sum_value.august,:september => sum_value.september, :october => sum_value.october, :november => sum_value.november, :december => sum_value.december, :dollar_per_sqft => sum_value.dollar_per_sqft, :dollar_per_unit => sum_value.dollar_per_unit)
        end
      end
    end
  end

  #  ================================= Main Code for income_and_cash_flow_take_Care ======================================
  def self.portfolio_ic(portfolio_id, year=Time.now.year)

    #portfolio id will be sent
    portfolio = Portfolio.find_by_id(portfolio_id)

    #collect all properties of portfolio
    properties = portfolio.real_estate_properties.map(&:id)

    # find first property that has income and cash flow detail id
    first_real_estate_property_has_income_cash_flow_record = IncomeAndCashFlowDetail.where(:resource_id => properties, :resource_type => "RealEstateProperty", :parent_id => nil, :year => year ).first.resource_id rescue nil
    r = RealEstateProperty.find_by_id(first_real_estate_property_has_income_cash_flow_record)
    #r = RealEstateProperty.find 80
    if r.present?
      ic = IncomeAndCashFlowDetail.find(:all, :conditions=>['resource_id =? and resource_type=? and parent_id is NULL and year =?',r.id,'RealEstateProperty',year])
      ic.each do |ic_prop|
        prop_fin = []
        portfolio_ic = IncomeAndCashFlowDetail.find_by_resource_id_and_resource_type_and_title_and_parent_id_and_year(portfolio_id, 'Portfolio', ic_prop.title, nil, year)
        if portfolio_ic.blank?
          portfolio_ic = ic_prop.clone
          portfolio_ic.resource_id = portfolio_id
          portfolio_ic.resource_type = 'Portfolio'
        portfolio_ic.save
        end
        properties.each do |prop|
          rec = IncomeAndCashFlowDetail.find(:first, :conditions=>['title=? and resource_id =? and resource_type=? and parent_id is NULL and year =?',ic_prop.title, prop,'RealEstateProperty',year])
          prop_fin << rec.id if rec
        end
        create_prop_fin(prop_fin, portfolio_ic.id) if prop_fin.present?
        portfolio_ic_recursive(ic_prop.id, ic_prop.title, portfolio_ic.id, portfolio_id, r, year)
      end
      Rails.logger.info 'completed'
    else
      Rails.logger.info "No Income and cash flow details found"
    end
  end

  def self.create_prop_fin(prop_fin_ids, portfolio_fin_id)
    pcb_types = ['p','c','b','c_ytd','b_ytd','var_amt','var_per','var_amt_ytd','var_per_ytd','c_ytd12','b_ytd12']
    pcb_types.each do |pcb_type|
      sum_values = PropertyFinancialPeriod.find_by_sql("select sum(january) as january, sum(february) as february, sum(march) as march, sum(april) as april, sum(may) as may, sum(june) as june, sum(july) as july, sum(august) as august, sum(september) as september,sum(october) as october, sum(november) as november, sum(december) as december, sum(dollar_per_sqft) as dollar_per_sqft, sum(dollar_per_unit) as dollar_per_unit  from property_financial_periods where pcb_type= '#{pcb_type}' and source_id in (#{prop_fin_ids.join(',')}) and source_type='IncomeAndCashFlowDetail'")
      sum_values.each do |sum_value|
        portfolio_fin_period = PropertyFinancialPeriod.find_by_source_id_and_source_type_and_pcb_type(portfolio_fin_id, 'IncomeAndCashFlowDetail', pcb_type)
        if portfolio_fin_period.blank?
          PropertyFinancialPeriod.create(:source_id => portfolio_fin_id, :source_type => 'IncomeAndCashFlowDetail', :pcb_type => pcb_type, :january => sum_value.january, :february => sum_value.february, :march => sum_value.march, :april => sum_value.april, :may => sum_value.may, :june => sum_value.june, :july => sum_value.july, :august => sum_value.august,:september => sum_value.september, :october => sum_value.october,:november => sum_value.november, :december => sum_value.december, :dollar_per_sqft => sum_value.dollar_per_sqft, :dollar_per_unit => sum_value.dollar_per_unit)
        else
          portfolio_fin_period.update_attributes(:source_id => portfolio_fin_id, :source_type => 'IncomeAndCashFlowDetail', :pcb_type => pcb_type, :january => sum_value.january, :february => sum_value.february, :march => sum_value.march, :april => sum_value.april, :may => sum_value.may, :june => sum_value.june, :july => sum_value.july, :august => sum_value.august,:september => sum_value.september, :october => sum_value.october, :november => sum_value.november, :december => sum_value.december, :dollar_per_sqft => sum_value.dollar_per_sqft, :dollar_per_unit => sum_value.dollar_per_unit)
        end
      end
    end
  end

  def self.portfolio_ic_recursive(id, title, parent_id, portfolio_id, first_real_estate_property_has_income_cash_flow_record,year=2012)
    portfolio  = Portfolio.find portfolio_id
    #collect all properties of portfolio
    properties = portfolio.real_estate_properties.collect{|x|x.id}

    ic = IncomeAndCashFlowDetail.find(:all, :conditions=>['resource_id =? and resource_type=? and parent_id =? and year =?',first_real_estate_property_has_income_cash_flow_record,'RealEstateProperty',id, year])
    ic.each do |ic_prop|
      prop_fin = []
      portfolio_ic = IncomeAndCashFlowDetail.find_by_resource_id_and_resource_type_and_title_and_parent_id_and_year(portfolio_id, 'Portfolio', ic_prop.title, parent_id, year)

      if portfolio_ic.blank?
        portfolio_ic = ic_prop.clone
        portfolio_ic.resource_id = portfolio_id
        portfolio_ic.resource_type = 'Portfolio'
      portfolio_ic.parent_id = parent_id
      portfolio_ic.save
      end
      properties.each do |prop|
      #Have to include condition to check for parent title also
        parent_ids_basing_on_title = IncomeAndCashFlowDetail.where(:title => title).map(&:id)
        rec = IncomeAndCashFlowDetail.where(:parent_id => parent_ids_basing_on_title, :title => ic_prop.title, :resource_id => prop, :resource_type => 'RealEstateProperty', :year => year).first

        #rec = IncomeAndCashFlowDetail.find(:first, :conditions=>['title=? and resource_id =? and resource_type=? and year =?',ic_prop.title, prop,'RealEstateProperty', year])
        prop_fin << rec.id if rec
      end
      create_prop_fin(prop_fin, portfolio_ic.id) if prop_fin.present?
      portfolio_ic_recursive(ic_prop.id, ic_prop.title, portfolio_ic.id, portfolio_id,first_real_estate_property_has_income_cash_flow_record, year)
    end
  end

  def self.find_portfolio(id)
    Portfolio.find_by_id(id)
  end

  #client id added
  def update_client_id_for_portfolio
    client_id  = Client.current_client_id
    self.client_id = client_id  if client_id.present? && self.client_id.blank?
  end

  def self.find_shared_and_owned_portfolios(user_id)
    portfolios = Portfolio.find(:all, :conditions=>['is_basic_portfolio = false and user_id = ? and portfolio_type_id = ? and name not in (?)', user_id,2,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]], :order=> "created_at desc")
    
    shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{user_id})")
    portfolios += Portfolio.find(:all, :conditions => ["id in (?)",shared_folders.collect {|x| x.portfolio_id}]) if !(shared_folders.nil? || shared_folders.blank?)
    portfolios = portfolios.sort_by{|portfolio| portfolio.created_at}.reverse
    portfolios
  end

  def self.last_created_portfolio_of_a_user(user)
    #~ last_portfolio = Portfolio.where("(leasing_type= 'Commercial' or leasing_type= 'Multifamily') and user_id= #{user.id} and name not in ('portfolio_created_by_system','portfolio_created_by_system_for_bulk_upload','portfolio_created_by_system_for_deal_room')").try(:last)

    portfolios = Portfolio.find(:all, :conditions=>['is_basic_portfolio = false and user_id = ? and portfolio_type_id = ? and name not in (?)', user.id,2,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]], :order=> "created_at desc") #removed portfolio_type_id = 2 for resolving the issue in shared user#
    #~ shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_property_folder =1 AND user_id = #{user.id})")
    #~ portfolios += Portfolio.find(:all, :conditions => ["id in (?)",shared_folders.collect {|x| x.portfolio_id}]) if !(shared_folders.nil? || shared_folders.blank?)
    last_portfolio = portfolios.sort_by{|portfolio| portfolio.created_at}.reverse.try(:first)
    first_property = last_portfolio.try(:real_estate_properties).try(:last)

    if last_portfolio.present? && first_property.present?
    return last_portfolio, first_property
    else
      if last_portfolio.present?
        properties = RealEstateProperty.find_owned_and_shared_properties(last_portfolio,user.id,prop_folder=nil)
        unless properties.present?
          properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(user.id,prop_folder=true)
        end
      else
        properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(user.id,prop_folder=true)
      end

      #~ property_ids = properties.present? ? properties.map(&:id) : []
      #~ unless property_ids.include?(first_property.try(:id))
      first_property = properties.try(:last)
      #~ end
      last_portfolio = first_property.try(:portfolio)
    end
    return last_portfolio, first_property
  end
  
  # This block finds the portfolio which has many properties count and if the two portfolios(commercial and multifamily has same no. of properties, it selects the commercial portfolio)
   def self.default_portfolio_after_logged_in(user)
    shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_portfolio_folder =1 AND user_id = #{user.id})")
    
    last_portfolio = Portfolio.where('portfolios.id in (?) or (is_basic_portfolio = false and portfolios.user_id = ? and portfolio_type_id = ? and name not in (?) and real_estate_properties.property_name not in (?))',shared_folders.collect {|x| x.portfolio_id}, user.id,2,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"], ["property_created_by_system","property_created_by_system_for_deal_room", "property_created_by_system_for_bulk_upload"]).joins(:real_estate_properties).select('portfolios.id, count(real_estate_properties.id) as counter').group('portfolios.id').order("counter DESC,real_estate_properties.leasing_type ASC").first
    
    first_property = last_portfolio.try(:real_estate_properties).try(:first)    
    return last_portfolio,first_property    
  end
  # ends here

  def self.find_portfolio_collections(options)
    return Portfolio.find(:all,options)
  end

  def self.portfolio_rename(id,value)
    new_portfolio = Portfolio.find(id)
    unless (value.strip()).blank?
      new_portfolio.name = value
      if new_portfolio.valid?
        new_portfolio.update_attributes(:name=>value)
        f = Folder.find_by_portfolio_id_and_parent_id(new_portfolio.id,-1)
        f.update_attributes(:name=>new_portfolio.name)
      end
    end
    return new_portfolio
  end

  def accounting_system_type_id
    if self.real_estate_properties.present?
    portfolio_prop = self.real_estate_properties.first
    acc_sys_id = portfolio_prop.accounting_system_type_id.present? ? portfolio_prop.accounting_system_type_id : 1
    else
    acc_sys_id = 1
    end
    return acc_sys_id
  end

  def accounting_type
    if self.real_estate_properties.present?
      portfolio_prop = self.real_estate_properties.first
      acc_sys_type = portfolio_prop.accounting_type.present? ? portfolio_prop.accounting_type : ""
    else
      acc_sys_type = ""
    end
    return acc_sys_type
  end

  def gross_rentable_area
    value = self.real_estate_properties.collect{|x|  x.try(:gross_rentable_area)}
    if (value.include?(nil) || value.include?(0))
    sum_gross = 0
    else
      sum_gross = self.real_estate_properties.sum(:gross_rentable_area)   if self.real_estate_properties.present?
    end
    sum_gross
  end

  def self.find_portfolios(current_user)
    portfolios = Portfolio.find(:all,:include =>["real_estate_properties"], :conditions=>['is_basic_portfolio = false and user_id = ? and portfolio_type_id = ? and name not in (?)', current_user.id,2,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]], :order=> "created_at desc").select{|x| x.real_estate_properties.present?}
    shared_folders = Folder.find_by_sql("SELECT * FROM folders WHERE id IN (SELECT folder_id FROM shared_folders WHERE is_portfolio_folder =1 AND user_id = #{current_user.try(:id)} AND client_id = #{current_user.client_id})")
    portfolios += Portfolio.find(:all,:include =>["real_estate_properties"], :conditions => ["is_basic_portfolio = false and id in (?)",shared_folders.collect {|x| x.portfolio_id}]).select{|y| y.real_estate_properties.present?} if !(shared_folders.nil? || shared_folders.blank?)
    return portfolios
  end

  def no_of_units
    value = self.real_estate_properties.collect{|x|  x.try(:no_of_units)}
    if (value.include?(nil) || value.include?(0))
    sum_no_of_units = 0
    else
      sum_no_of_units = self.real_estate_properties.sum(:no_of_units)   if self.real_estate_properties.present?
    end
    sum_no_of_units
  end

  #creating a properties and users for the new portfolios(client admin)
  def self.create_new_properties_and_users(params,portfolio,user_id,client_id)
    property_and_portfolio_access={}
    property_and_portfolio_access[:portfolio] = [portfolio.id] if portfolio
    #folder created for portfolio start
    folder=Folder.create(:name=>portfolio.name,:portfolio_id=>portfolio.id,:user_id=>user_id,:parent_id=>-1,:is_master=>0,:is_deleted=>0,:is_deselected=>0)
    #folder created for portfolio end
    portfolio_image = PortfolioImage.create_client_portfolio_image(params[:portfolio_image],portfolio.id)
    portfolio.portfolio_image = portfolio_image if portfolio_image
    portfolio.user_id = user_id
    if params[:property] && params[:property].values && params[:property].values.present?
      portfolio.real_estate_properties << RealEstateProperty.where("id in (?)",params[:property].values)
    end
    portfolio.portfolio_type_id = 2
    portfolio.save
    #Code for delayed job for portfolio update starts here - for property#
    for year in 2010..Date.today.year
      if portfolio.leasing_type.eql?("Commercial")
        Portfolio.delay.portfolio_ic(portfolio.id, year)
        Portfolio.delay.portfolio_pci(portfolio.id,0,year)
      elsif portfolio.leasing_type.eql?("Multifamily")
        Portfolio.delay.portfolio_ic(portfolio.id, year)
      end
    end
    #Code for delayed job for portfolio update ends here#
    if params[:user] && params[:user].values && params[:user].values.present?
      params[:user].values.each do |user|
      #shared folder created for portfolio start
        SharedFolder.create(:user_id=>user,:folder_id=>folder.id,:sharer_id=>user_id,:portfolio_id=>portfolio.id,:is_portfolio_folder=>true,:client_id=>client_id)
        #shared folder created for portfolio end
        Portfolio.save_shared_folder(portfolio,user,user_id,client_id)
        #Code for delayed job for portfolio update starts here - for user added#
        user_val = User.find_by_id(user)
        Portfolio.update_financial_info(user_val)
        #Code for delayed job for portfolio update ends here#
        if (property_and_portfolio_access && property_and_portfolio_access[:portfolio].present?)
          
          
          
          #UserMailer.property_and_portfolio_access_client(user_val,property_and_portfolio_access,"update").deliver
        
        
        end
      end
    end
  end

  def self.save_shared_folder(portfolio,user,user_id,client_id)
    portfolio_for_shared_folder = portfolio
    portfolio_id_val=portfolio.id
    portfolio_properties = portfolio.real_estate_properties
    portfolio_properties && portfolio_properties.each do |portfolio_property|
      portfolio_property_id = portfolio_property.id
      user=User.find(user)
      portfolio,property_check_value,real_estate_property = User.property_check(portfolio_property_id,client_id,user)
      unless property_check_value
      portfolio.real_estate_properties << real_estate_property
      portfolio.save
      end
      Portfolio.shared_folder_creation(portfolio_property,portfolio_property_id,user,user_id,client_id)
    end
  end

  #Shared folder creation starts here
  def self.shared_folder_creation(portfolio_property,portfolio_property_id,user,user_id,client_id)
    #shared folders and documents creation start
    folder_for_property = Folder.find_by_name_and_real_estate_property_id_and_user_id_and_client_id_and_parent_id(portfolio_property.property_name,portfolio_property.id,portfolio_property.user_id,portfolio_property.client_id,0)
    #shared folder created for property start
    shared_folder = SharedFolder.find_or_create_by_user_id_and_folder_id_and_sharer_id_and_real_estate_property_id_and_is_property_folder_and_client_id(user.id,folder_for_property.id,user_id,portfolio_property_id,true,client_id) if folder_for_property
    #shared folder created for property end
    #~ sub_folders =  Folder.find_all_by_real_estate_property_id_and_is_master(portfolio_property_id,1)
    sub_folders =  Folder.find(:all,:conditions => ["real_estate_property_id =? and parent_id!=0",portfolio_property_id])
    sub_folder_shared = sub_folders.uniq
    Portfolio.share_sub_folders_while_sharing_folder(sub_folder_shared,shared_folder) if sub_folder_shared
    document_collection = Document.where(:real_estate_property_id => folder_for_property.real_estate_property_id,:is_deleted => false) if folder_for_property
    documents = document_collection.uniq
    Portfolio.share_sub_docs_while_sharing_folder(documents,shared_folder) if documents
  #shared folders and documents creation end
  end

  #to share_folders_while_sharing_main_folder
  def self.share_sub_folders_while_sharing_folder(shared_sub_folder,shared_folder)
    shared_sub_folder.each do |f|
      if f.parent_id != 0 && !f.is_deleted
        sf = SharedFolder.find_or_create_by_folder_id_and_user_id_and_sharer_id_and_real_estate_property_id(f.id,shared_folder.user_id,shared_folder.sharer_id,shared_folder.real_estate_property_id)
      end
    end
  end

  #to share_docs_while_sharing_main_folder
  def self.share_sub_docs_while_sharing_folder(documents,shared_folder)
    documents.each do |d|
      if d.filename != "Cash_Flow_Template.xls" && d.filename != "Rent_Roll_Template.xls"
        sd = SharedDocument.find_or_create_by_document_id_and_user_id_and_sharer_id_and_real_estate_property_id_and_folder_id(d.id,shared_folder.user_id,shared_folder.sharer_id,shared_folder.real_estate_property_id,d.folder_id)
      end
    end
  end
  #Shared folder creation ends here

  #updating portfolios
  def self.update_portfolios(params,portfolio,user_id,client_id)
    property_and_portfolio_access={}
    property_and_portfolio_access[:portfolio] = [portfolio.id] if portfolio
    user=User.find(user_id)
    portfolio_shared = portfolio
    user_email=user.email
    portfolio.update_attributes(params[:portfolio])
    portfolio_image_form=params[:portfolio_image]
    portfolio_image=portfolio.portfolio_image
    portfolio_users = SharedFolder.by_portfolio_id(portfolio.id)
    existing_users=portfolio_users.present? ? portfolio_users.map(&:user_id) : []
    #update image
    if portfolio_image_form.present?
      portfolio.portfolio_image.present? ? PortfolioImage.update_client_image(portfolio.id,portfolio_image_form) : PortfolioImage.create_client_portfolio_image(portfolio_image_form,portfolio.id)
    end
    real_estate_property_user = total_real_estate = portfolio.real_estate_properties
    real_estate_properties_total=Portfolio.portfolios_properties(portfolio)
    #update property
    existing_properties=real_estate_properties_total.present? ? real_estate_properties_total.map(&:id) : []
    if params[:property].present?
      property_ids=params[:property].values.collect{|id| id.to_i}
      new_properties=property_ids-existing_properties
      delete_properties=existing_properties-property_ids
      if delete_properties.present?
        delete_properties.each do |delete_property|
        #shared folder delete start
          share_folder_properties_in_properties_available = SharedFolder.find(:all,:conditions=>["user_id in (?) and sharer_id = ? and real_estate_property_id in (?)",existing_users,user_id,[delete_property]])
          real_estate=RealEstateProperty.find(delete_property)
          Portfolio.delete_user_basic_portfolio_property_delete(portfolio,delete_property,existing_users)
          portfolio.real_estate_properties.delete(real_estate)
        end
      end
      if new_properties.present?
        portfolio.real_estate_properties << RealEstateProperty.where("id in (?)",new_properties)
      portfolio.save
      end
    else
      shared_folders_details = SharedFolder.find(:all,:conditions =>["portfolio_id =? and client_id = ? and sharer_id = ? and is_portfolio_folder = ?",portfolio.id,client_id,user_id,true])

      total_users = shared_folders_details ? shared_folders_details.reject{|x| x.user_id == user_id} : []
      total_users && existing_properties && existing_properties.each do |exist_delete|
        Portfolio.delete_user_basic_portfolio_property_delete(portfolio,exist_delete,total_users.map(&:user_id))
      end
      #Delete the shared folder for the shared users(when ever deleting the property)
      portfolio.real_estate_property_ids = []
    portfolio.save
    end
    #Code for delayed job for portfolio update starts here - for property#
    for year in 2010..Date.today.year
      if portfolio.leasing_type.eql?("Commercial")
        Portfolio.delay.portfolio_ic(portfolio.id, year)
        Portfolio.delay.portfolio_pci(portfolio.id,0,year)
      elsif portfolio.leasing_type.eql?("Multifamily")
        Portfolio.delay.portfolio_ic(portfolio.id, year)
      end
    end
    #Code for delayed job for portfolio update ends here#
    #update users
    if params[:user].present?
      user_ids=params[:user].values.collect{|id| id.to_i}
      new_users=user_ids-existing_users
      delete_users=existing_users-user_ids
      if delete_users.present?
        delete_users.each do |user|
        #Code for delayed job for portfolio update starts here - for delete user#
          user_val = User.find_by_id(user)
          existing_properties && existing_properties.each do |property_id|
            real_estate_user_property = RealEstateProperty.find(property_id)
            Portfolio.delete_basic_property_records(user_val,portfolio,client_id,real_estate_user_property)
          end
          Portfolio.update_financial_info(user_val)
        #Code for delayed job for portfolio update ends here#
        end
        #code for deleting the shared folders(both portfolios and properties)
        share_folder_portfolios=SharedFolder.find(:all,:conditions=>["portfolio_id in (?) and user_id in (?) and sharer_id = ? and is_portfolio_folder = ?",[portfolio_shared.id],delete_users,user_id,true])

        #~ share_folder_properties.each {|r| r.destroy}
        share_folder_portfolios.each {|r| r.destroy}
      end
      folder=Folder.find_by_portfolio_id_and_real_estate_property_id(portfolio,nil)
      new_users.each do |user|
        SharedFolder.create(:user_id=>user,:folder_id=>folder.id,:sharer_id=>user_id,:portfolio_id=>portfolio.id,:is_portfolio_folder=>true,:client_id=>client_id)
        Portfolio.save_shared_folder(portfolio,user,user_id,client_id)
        #Code for delayed job for portfolio update starts here - for new user#
        user_val = User.find_by_id(user)
        Portfolio.update_financial_info(user_val)
        #Code for delayed job for portfolio update ends here#
        if (property_and_portfolio_access && property_and_portfolio_access[:portfolio].present?)
          UserMailer.property_and_portfolio_access_client(user_val,property_and_portfolio_access,"update").deliver
        end
      end
    else
      share_folder_portfolios=SharedFolder.find(:all,:conditions=>["portfolio_id in (?) and user_id in (?) and sharer_id = ? and is_portfolio_folder = ?",[portfolio_shared.id],existing_users,user_id,true])
      find_user = share_folder_portfolios.map(&:user_id).uniq
      #~ Portfolio.delete_user_basic_portfolio_property_delete(portfolio,exist_delete,total_users.map(&:user_id))
      #Code for delayed job for portfolio update starts here - for destroy all user#
      if find_user.present?
        find_user.each do |user|
        #Code to delete the real estate property from the basic portfolio
          user_val = User.find_by_id(user)
          existing_properties && existing_properties.each do |property_id|
            real_estate_user_property = RealEstateProperty.find(property_id)
            Portfolio.delete_basic_property_records(user_val,portfolio,client_id,real_estate_user_property)
          end
          Portfolio.update_financial_info(user_val)
        end
      end
      #Code for delayed job for portfolio update ends here#
      share_folder_portfolios.each {|r| r.destroy}
    end
    #create basic portfolio properties while editing
    portfolio_users=SharedFolder.by_portfolio_id(portfolio.id)
    portfolio_users && portfolio_users.map(&:user_id) && portfolio_users.map(&:user_id).each do |portfolio_user|
      Portfolio.save_shared_folder(portfolio,portfolio_user,user_id,client_id)
    end

  end

  #Selecting the portfolios users and properties
  def self.filter_based_on_portfolio(portfolio,leasing_type)
    portfolio_properties=portfolio.real_estate_properties.find(:all,:conditions=>["property_name NOT in (?) and leasing_type=?",["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"],leasing_type])
    portfolio_users=SharedFolder.find(:all,:conditions=>["is_portfolio_folder=? AND portfolio_id=?",true,portfolio.id])
    portfolio_properties=portfolio_properties.present? ? portfolio_properties.map(&:real_estate_property_id) : [0]
    portfolio_users=portfolio_users.present? ? portfolio_users.map(&:user_id) : [0]
    return portfolio_properties,portfolio_users
  end

  def self.portfolios_properties(portfolio)
    properties=portfolio.real_estate_properties.find(:all,:conditions=>["property_name NOT in (?)",["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]])
  end

  #updating the financial info for portfolio in different scenarios#
  def self.update_financial_info(user)
    if user.present?
      portfolio_collect = user.try(:portfolios).where("portfolios.user_id = #{user.id} and portfolios.name NOT LIKE '%portfolio_created_by_system%'")
      portfolio_collect.each do |portfolio|
        for year in 2010..Date.today.year
          if portfolio.leasing_type.eql?("Commercial")
            Portfolio.delay.portfolio_ic(portfolio.id, year)
            Portfolio.delay.portfolio_pci(portfolio.id,0,year)
          elsif portfolio.leasing_type.eql?("Multifamily")
            Portfolio.delay.portfolio_ic(portfolio.id, year)
          end
        end
      end
    end
  end

  def self.update_wres_users
    Portfolio.transaction do
      Folder.transaction do
        RealEstateProperty.transaction do
          client = Client.find_by_name("WRESAMP")
          users = client.users
          users.each do |user|
            role_ids =   user.role_ids.uniq
            if role_ids.present? && role_ids.include?(2) && !role_ids.include?(4)
              basic_portfolios_count = user.portfolios.where(:is_basic_portfolio => true).count
              if basic_portfolios_count == 0
                chart_of_accounts = user.client.chart_of_accounts || []

                chart_of_accounts.each_with_index do |chart_of_account, number|
                  number += 1
                  multifamily_portfolio = Portfolio.create(:name => "All Multifamily #{number}", :user_id => user.id, :leasing_type => "Multifamily", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
                  Folder.create(:name => multifamily_portfolio.try(:name), :portfolio_id => multifamily_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if multifamily_portfolio.present?
                  commercial_portfolio = Portfolio.create(:name => "All Commercial #{number}", :user_id => user.id, :leasing_type => "Commercial", :client_id => user.client_id, :is_basic_portfolio => true, :chart_of_account_id => chart_of_account.try(:id), :portfolio_type_id => 2)
                  Folder.create(:name => commercial_portfolio.try(:name), :portfolio_id => commercial_portfolio.try(:id), :user_id => user.id, :is_master => true, :client_id => user.client_id) if commercial_portfolio.present?
                #end
                end
              end

              real_properties = RealEstateProperty.find_owned_and_shared_properties_of_a_user(user.id,true)

              #~ real_properties = RealEstateProperty.where('user_id = ? and client_id = ? and accounting_system_type_id is NOT NULL',user.id,client.id)
              real_properties.each do |real_props|
                if real_props.accounting_system_type_id.present?
                  chart_of_account =  ChartOfAccount.find_by_client_id_and_accounting_system_type_id(user.client_id,real_props.accounting_system_type_id)
                  if real_props.try(:chart_of_account_id).blank?
                    real_props.chart_of_account_id = chart_of_account.id
                    real_props.save(:validate => false)
                  end
                  insert_property_in_basic_portfolio(real_props,user)
                else
                  puts "No accounting_system_type_ids"
                  puts real_props.id
                end
              end
              portfolios = Portfolio.find_shared_and_owned_portfolios(user.id)
              #~ portfolios = Portfolio.where('user_id = ? and client_id = ? and name NOT IN (?) and is_basic_portfolio = ?',user.id,client.id,["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"],true)
              portfolios.each do |portfolio|
                if portfolio.real_estate_properties.present?
                  chart_of_account_id = portfolio.real_estate_properties.first.chart_of_account_id
                  portfolio.update_attributes(:chart_of_account_id => chart_of_account_id) if portfolio.chart_of_account_id.blank?
                else
                  puts "No real estate properties"
                  puts portfolio.id
                end
              end
            end
            Portfolio.update_financial_info(user)
          end
        end
      end
    end
  end

  # Code for mapping Propeties with basic portfolios [ We invoke this method from above method NO need to invoke seperatly]
  def self.insert_property_in_basic_portfolio(property,user)
    sql = ActiveRecord::Base.connection();
    chart_of_account_id = property.chart_of_account_id
    portfolio = Portfolio.where(:chart_of_account_id => chart_of_account_id,:leasing_type =>property.leasing_type,:user_id => user.id,:is_basic_portfolio => true).first
    portfolio_id =  portfolio.present? ? portfolio.id : ''
    if  portfolio.present? && !portfolio.real_estate_property_ids.uniq.include?(property.id)
      sql.execute("INSERT INTO portfolios_real_estate_properties (portfolio_id,real_estate_property_id) VALUES('#{portfolio_id}','#{property.id}')")
    end
  end

  def self.update_chart_of_account_in_all_the_portfolios
    portfolios = Portfolio.where("name not like ? and is_basic_portfolio = ?", "portfolio_created_by%",'false')
    portfolios.each do |portfolio|
      if portfolio.real_estate_properties.present?
        chart_of_account_id = portfolio.real_estate_properties.first.chart_of_account_id
        portfolio.update_attributes(:chart_of_account_id => chart_of_account_id)
      end
    end
  end

  def self.delete_basic_property_records(user_val,portfolio,client_id,delete_basic_property)
    total_shared_folders = SharedFolder.find(:all,:conditions => ["real_estate_property_id = ? and user_id = ?",delete_basic_property.id,user_val.id])
    if total_shared_folders && total_shared_folders.map(&:portfolio_id).uniq.count < 3
      basic_portfolios = user_val.portfolios.find(:all,:conditions => ["is_basic_portfolio = ? and leasing_type = ? and chart_of_account_id = ? and client_id = ?",true,portfolio.leasing_type,portfolio.chart_of_account_id,client_id])
      basic_portfolios && basic_portfolios.each do |basic_portfolio|
        delete_basic_properties = basic_portfolio.real_estate_properties.find(:all,:conditions => ["id in (?)",delete_basic_property.id])
        #~ delete_basic_properties = basic_portfolio.real_estate_properties
        delete_basic_properties && delete_basic_properties.each do |delete_basic_property|
          basic_portfolio.real_estate_properties.delete(delete_basic_property)
          delete_shared_folders = SharedFolder.find(:all,:conditions => ["real_estate_property_id = ?",delete_basic_property.id])
          delete_shared_folders.each {|x| x.destroy} if delete_shared_folders
        end
      end
    end
  end

  def self.delete_users_basic_portfolio_properties(portfolio)
    shared_folders = portfolio.shared_folders
    properties = portfolio.real_estate_properties.find(:all,:conditions=>["property_name NOT in (?)",["portfolio_created_by_system","portfolio_created_by_system_for_deal_room", "portfolio_created_by_system_for_bulk_upload"]])
    properties && properties.each do |property|
      shared_folders && shared_folders.map(&:user_id) && shared_folders.map(&:user_id).each do |user|
        user_rec = User.find(user)
        Portfolio.delete_basic_property_records(user_rec,property.portfolio,portfolio.client_id,property)
      end
    end
  end

  def self.delete_user_basic_portfolio_property_delete(portfolio,property_id,users)
    property = RealEstateProperty.find(property_id)
    users.each do |user|
      user_rec = User.find(user)
      Portfolio.delete_basic_property_records(user_rec,portfolio,portfolio.client_id,property) if (property.present? && user_rec.shared_folders.where(:portfolio_id =>property.portfolios.map(&:id).uniq,:is_portfolio_folder => true).blank?)
    end
  end

  #Rails best practice model logic methods

  def find_portfolio_image
    (self.present? && self.portfolio_image.present?) ? self.portfolio_image.public_filename : "/images/prepertyThumb.png"
  end

  def find_portfolio_image_form
    (self.present? && self.portfolio_image.present?) ? self.portfolio_image.public_filename : "/images/prepertyThumb.png"
  end

end
