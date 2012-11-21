module ClientAdmin::PropertiesHelper
  def find_user_names(property)
    shared_properties  = SharedFolder.where(:real_estate_property_id => property.id, :is_property_folder => 1)
    #    user_ids = shared_properties.map(&:user_id) if shared_properties.present?
    if shared_properties.present?
      tmp_ids = shared_properties.map(&:user_id)
      tmp_ids.delete(User.current.id) if tmp_ids.present?
      user_ids = tmp_ids
      user_names = User.find_all_by_id(user_ids)  #.map(&:name) if shared_properties.present?
    end
    # return user_names, user_ids if shared_properties.present? #.join(',') if shared_properties.present?
  end

  def find_property_types
    arr=["Multifamily", "Student Housing", "Senior Housing (Assisted Living)"]
    property_set_one = PropertyType.all.select{|x| !arr.include?(x.name)}.map{|x| [x.name,x.id]}
    property_set_two = PropertyType.all.select{|x| arr.include?(x.name)}.map{|x| [x.name,x.id]}
    property_types = if params[:sort].eql?("Commercial")
      property_set_one
    else
      property_set_two
    end
    property_types
  end

  def create_property_folders(user_id,client_id,property)
    property.no_validation_needed = 'true'
    property.save
    @property = property
    #for upload picture start
    PortfolioImage.create_portfolio_image(params[:attachment][:uploaded_data],property.id,nil) if property && params[:attachment] && params[:attachment][:uploaded_data]
    #for upload picture end
    #~ Folder.create(:name => property.try(:property_name), :user_id => user_id, :client_id => client_id, :real_estate_property_id => property.try(:id)  )
    sql = ActiveRecord::Base.connection();
    chart_of_account_id = property.chart_of_account_id
    @portfolio = Portfolio.where(:chart_of_account_id => chart_of_account_id,:leasing_type =>property.leasing_type,:user_id => user_id,:is_basic_portfolio => true)
    portfolio_id =  @portfolio.present? ? @portfolio.first.id : ''
    sql.execute("INSERT INTO portfolios_real_estate_properties (portfolio_id,real_estate_property_id) VALUES('#{portfolio_id}','#{property.id}')") if portfolio_id.present?
    create_properties_folders_docs_filenames
  end

    #creates master folders
  def create_properties_folders_docs_filenames
    create_master_folders
    amp_create_subfolders_files_for_property(@asset_folder,@property)
  end

   def create_master_folders
    @master_folder = Folder.find_by_portfolio_id_and_is_master(@portfolio.first.id,true)
    @asset_folder = Folder.find_or_create_by_name_and_portfolio_id_and_real_estate_property_id_and_user_id_and_client_id(@property.property_name,@portfolio.first.id,@property.id,@property.user_id,@property.client_id)
    #~ @asset_folder.update_attributes(:user_id=>@portfolio.user_id)
  end

  def amp_create_subfolders_files_for_property(property_folder,property)
    amp_folder = Folder.create(:name =>"AMP Files",:portfolio_id => property.portfolio_id,:real_estate_property_id => property.id,:user_id => property.user_id,:parent_id =>property_folder.id,:is_master =>1)
    folder_lease = Folder.create(:name =>"Lease Files",:portfolio_id => property.portfolio_id,:real_estate_property_id => property.id,:user_id => property.user_id,:parent_id =>property_folder.id,:is_master =>1)
    folder_lease = Folder.create(:name =>"Floor Plans",:portfolio_id => property.portfolio_id,:real_estate_property_id => property.id,:user_id => property.user_id,:parent_id =>property_folder.id,:is_master =>1)
    folder_report = Folder.create(:name =>"Report Docs",:portfolio_id => property.portfolio_id,:real_estate_property_id => property.id,:user_id => property.user_id,:parent_id =>amp_folder.id,:is_master =>1)
    folder_prop = Folder.create(:name =>"Property Pictures",:portfolio_id => property.portfolio_id,:real_estate_property_id => property.id,:user_id => property.user_id,:parent_id =>amp_folder.id,:is_master =>1)
    array=[{:name=>"Excel Uploads"}]
    acc_sys_type=AccountingSystemType.find_by_id(property.accounting_system_type_id).try(:type_name)
    array[0][:templates] = if acc_sys_type=="MRI, SWIG"
      ['12_Month_Budget.xls', 'Capital_Improvement_Status_Report.xls', 'Occupancy_Leasing_Report.xls', 'Aged_Delinquencies.xls', 'Debt_Summary.xls', 'Rent_Roll_Commercial.xls']
    elsif acc_sys_type=="Real Page"
      ['12_Month_budget.xls', 'Actual_Budget_Analysis_Report.xls', 'All_Units.xls']
    elsif acc_sys_type=="MRI"
      ['12_Month_Budget.xls', 'CapExp_TenantDetails_actuals.xls', 'CapExp_TenantDetails_budget.xls', 'Tenant_Occupancy_Report.xls', 'Receivables_Aging.xls', 'Rent_Roll_Commercial.xls']
    elsif acc_sys_type=="AMP Excel"
      if property.leasing_type=="Commercial"
        ['Financials_actuals.xls', 'Financials_budget.xls', 'CapExp_TenantDetails_actuals.xls', 'CapExp_TenantDetails_budget.xls', 'Tenant_Occupancy_Report.xls', 'Receivables_Aging.xls', 'Rent_Roll_Commercial.xls']
      elsif property.leasing_type=="Multifamily"
        ['Financials_actuals.xls', 'Financials_budget.xls', 'Multifamily_Leasing_AllUnits.xls']
      end
    elsif acc_sys_type=="YARDI V1"
      ['Financials_actuals.xls', 'Financials_budget.xls','RentRoll.xls','BoxScoreSummary.xls']
    end
    array.reverse.each do |name_temp|
      create_sub_folders_wres_swig(property_folder,property,name_temp[:name],name_temp[:templates])
    end
  rescue Exception => e
    p "error creating folders:#{e.message}"
  end

   def create_sub_folders_wres_swig(property_folder,property,name,template)
    folder_excel = Folder.create_sub_folders(property_folder,property,name)
    store_excel_template(template,folder_excel)
  rescue Exception => e
    p "error creating folders:#{e.message}"
  end

    def store_excel_template(arr,folder)
    if arr && !arr.empty?
      arr.each do |fl|
        path ="#{Rails.root.to_s}/public/template/"+fl.to_s
        tempfile = Tempfile.new(fl)
        begin
          tempfile.write(File.open(path).read)
          tempfile.flush
          upload_data = ActionDispatch::Http::UploadedFile.new({:filename=>fl,:type=>"application/vnd.ms-excel", :tempfile=>tempfile})
          d= Document.new(:folder_id=>folder.id,:user_id=>current_user.id,:is_master=>1,:real_estate_property_id=>folder.real_estate_property_id)
          d.uploaded_data = upload_data
          d.save
        ensure
          tempfile.close
          tempfile.unlink
        end
      end
    end
  end

    def find_chart_of_account_name(chart_of_account_id)
      ChartOfAccount.find_by_id(chart_of_account_id).try(:name)
    end
end
