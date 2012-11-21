module PropertiesHelper
  include ActionView::Helpers::TextHelper
  def listing_sub_folders(f_options,d_options)
     #Find the folders based on real estate property start
      portfolio_id_selected = params[:pid] ? params[:pid] : params[:portfolio_id] ? params[:portfolio_id] : ""
      if @property_view.eql?("false") && !portfolio_id_selected.nil? && params[:action] != "share_folder"
        portfolio_selected = Portfolio.find_by_id(portfolio_id_selected)
        portfolio_property_ids = portfolio_selected.real_estate_properties.map(&:id)
        @folders = Folder.find(:all,:conditions => ["real_estate_property_id in (?) and is_master = false and parent_id = false and is_deleted = false",portfolio_property_ids])
      else
        @folders = Folder.find(:all,f_options)
      end
    #Find the folders based on real estate property end
    @documents = Document.find(:all,d_options) if !@display_properties
    if @folder && @folder.parent_id != -1
      @real_estate_property = RealEstateProperty.find_real_estate_property(params[:nid])
      params[:folder_id] = Folder.find_by_real_estate_property_id_and_parent_id(@real_estate_property.id,0)   if params[:folder_id].nil? && params[:sfid].nil? && !@real_estate_property.nil?
      params[:folder_id] = f_options["folder_id"] if !f_options["folder_id"].nil?
      d=f_options[:conditions].split("and").collect{|c| c if c.include?("parent_id")}.compact if  f_options[:conditions] != nil
      params[:folder_id] = d[0].split('=')[1].strip if d && !d.empty?
    end
    folder_names = ["Excel Uploads","AMP Files"]
    @folders = @folders.compact.collect{|folder| folder if !(folder && folder.parent_id != 0 && folder.is_master && folder_names.index(folder.name) && is_leasing_agent)} unless @folders.empty?
    return @folders,@documents
  end
  def property_image(note_id)
    image = PortfolioImage.find(:first,:conditions=>['attachable_id = ? and attachable_type = ? and is_property_picture =?',note_id,"RealEstateProperty",false])
    if image.nil?
      image = Document.find(:first,:conditions =>  ["is_deleted = ? and real_estate_property_id=? and (content_type LIKE LOWER(?) or filename like LOWER(?) or filename like LOWER(?) or filename like LOWER(?) or filename like LOWER(?) or filename like LOWER(?))", false,"#{note_id}",  "%%image/%%", "%%.jpg%%", "%%.gif%%", "%%.png%%", "%%.bmp%%", "%%.jpeg%%"])
    end
    if image.nil?
      return '/images/property.jpg'
    else
      return image.public_filename.to_s
    end
  end
  def real_estate_property_image(note_id)
    image = PortfolioImage.find(:first,:conditions=>['attachable_id = ? and attachable_type = ? and is_property_picture =?',note_id,"RealEstateProperty",false])
    if image.nil?
      image = Document.find(:first,:conditions =>  ["is_deleted = ? and real_estate_property_id=? and (content_type LIKE LOWER(?) or filename like LOWER(?) or filename like LOWER(?) or filename like LOWER(?) or filename like LOWER(?) or filename like LOWER(?))", false,"#{note_id}",  "%%image/%%", "%%.jpg%%", "%%.gif%%", "%%.png%%", "%%.bmp%%", "%%.jpeg%%"])
    end
    return image.nil? ? '/images/property_img.png' : FileTest.exists?("#{image.public_filename}") ? image.public_filename : '/images/property_img.png'
  end
  def total_gross_rentable_area(props)
    gra = 0
    props.each do |p|
      gra += p.gross_rentable_area
    end
    return gra
  end
  def find_property_images(note_id)
    @images = Document.find(:all,:conditions =>  ["is_deleted = ? and real_estate_property_id=? and (content_type LIKE LOWER(?) or filename like LOWER(?) or filename like LOWER(?) or filename like LOWER(?) or filename like LOWER(?) or filename like LOWER(?))", false,"#{note_id}",  "%%image/%%", "%%.jpg%%", "%%.gif%%", "%%.png%%", "%%.bmp%%", "%%.jpeg%%"])
    return @images.nil? ? '/images/property.jpg' : @images
  end
  def get_folder_of_notes_real_estate(note_id,portfolio_id)
    #return Folder.find(:first,:conditions=>['parent_id = ? and portfolio_id = ? and real_estate_property_id = ? and user_id = ?',0,portfolio_id,note_id,current_user.id]).id
    return Folder.find(:first,:conditions=>['parent_id = ? and portfolio_id = ? and real_estate_property_id = ?',0,portfolio_id,note_id]).id
  end
  #to find is there any missing file in a folder
  def check_missing_files_real_estate(fid)
    docname_files= DocumentName.find(:all,:conditions=>["is_deleted = ? and folder_id = ? and is_master = ? and real_estate_property_id is not NULL and due_date is not NULL and document_id is NULL",false,fid,0])
    doc_files = Document.find(:all,:conditions=>["is_deleted = ? and folder_id = ? and is_master = ? and real_estate_property_id is not NULL and due_date is NOT NULL",false,fid,0])
    missing_files = docname_files + doc_files
    is_missing_files = missing_files.empty? ? "no" : "yes"
    return is_missing_files
  end
  #To find shared folders
  def find_manage_real_estates_shared_folders
    @show_deleted = (params[:del_files] == 'true') ? true : false
    conditions =  @show_deleted == true ?   "" : "and is_deleted = false"
    s = SharedFolder.find(:all,:conditions=>["user_id = ? and client_id = ? ",current_user.id,current_user.client_id]).collect{|sf| sf.folder_id}
    fs = Folder.find(:all,:conditions=>["id in (?) and parent_id not in (?) #{conditions} and real_estate_property_id is NOT NULL",s,s]).collect{|f| f.id}
    s_folders = SharedFolder.find(:all,:conditions=>["user_id = ? and folder_id in (?) and client_id = ? ",current_user.id,fs,current_user.client_id])
    folders = s_folders.collect {|sf| sf.folder}.uniq
    return   folders
  end
  def get_location_slider(property)
    if property.city == '' && property.province == ''
      ''
    elsif property.city != '' && property.province == ''
      raw("<span title='#{property.city}'> #{display_truncated_chars(property.city.to_s, 18, true)}</span>")
    elsif property.city == '' && property.province != ''
      property.province.slice(0,2)
    else
      raw("<span title='#{property.city}'>#{display_truncated_chars(property.city.to_s.titleize, 12, true)}</span>"+', '+property.province.slice(0,2))
    end
  end
  def check_collaborators(user_id,collaborator_list)
    return (collaborator_list.split(",").include?(user_id.to_s)) ? true : false
  end
  def re_portfolio_property_types(pid)
    portfolio = Portfolio.find_by_id(portfolio_id)
    prop_names = portfolio.real_estate_properties.find_by_sql("SELECT p.name ,r.id,r.user_id FROM real_estate_properties r, property_types p WHERE r.property_type_id = p.id").collect{|x| x.name if check_property_shared_or_owned(x.id,x.user_id)}
    return prop_names.compact.uniq.join(', ')
  end
  def  check_property_shared_or_owned(property_id,user_id)
    if(user_id != current_user.id)
      property_folder  = Folder.find_by_real_estate_property_id_and_parent_id_and_is_master(property_id,0,0)
      shared_property_folder = SharedFolder.find_by_folder_id_and_user_id_and_client_id(property_folder.id,current_user.id,current_user.client_id,:conditions=>["is_property_folder is not null and is_property_folder = true"]) if property_folder && property_folder.parent_id != -1
      is_shared = shared_property_folder.nil? ? false : true
      return is_shared
    else
      return true
    end
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
  def check_document_functionality(document)
    parent_folder = Folder.find_by_id(document.folder_id)
    gr_parent_folder = Folder.find_by_id(parent_folder.parent_id) if !parent_folder.nil?
    if !gr_parent_folder.nil? and ["Excel Uploads","Loan Docs"].include?(gr_parent_folder.name) and !parent_folder.nil? and parent_folder.name == "Sample Templates"
      return false
    else
      return true
    end
  end
  def check_folder_functionality(folder_id)
    parent_folder = Folder.find_by_id(folder_id)
    gr_parent_folder = Folder.find_by_id(parent_folder.parent_id) if !parent_folder.nil?
    if !gr_parent_folder.nil? and ["Excel Uploads","Loan Docs"].include?(gr_parent_folder.name) and !parent_folder.nil? and parent_folder.name == "Sample Templates"
      return false
    else
      return true
    end
  end
  def cap_exp_explanation(id,month,ytd_check)
    txt = CapitalExpenditureExplanation.cap_exp_explanation(id,month,ytd_check)
    return txt.explanation if !(txt.nil? || txt.blank?)
  end

  def cap_exp_explanation_doc(id,month,ytd_check)
    txt = CapitalExpenditureExplanation.cap_exp_explanation(id,month,ytd_check)
    return txt.document_id if !(txt.nil? || txt.blank?)
  end

  def cap_exp_explanation_user_id(id,month,ytd_check)
    txt = CapitalExpenditureExplanation.cap_exp_explanation(id,month,ytd_check)
    return txt.user_id if !(txt.nil? || txt.blank?)
  end

  def cap_exp_explanation_updated_at(id,month,ytd_check)
    txt = CapitalExpenditureExplanation.cap_exp_explanation(id,month,ytd_check)
    return txt.updated_at if !(txt.nil? || txt.blank?)
  end
  def financial_explanation(id,month,ytd_check)
    #txt = IncomeCashFlowExplanation.find_by_income_and_cash_flow_detail_id(id)
    txt = IncomeCashFlowExplanation.in_cash_flow_exp(id,month,ytd_check)
    # for retrieve explaination user_id not required
    return txt.explanation if !(txt.nil? || txt.blank?)
  end

  def rent_roll_explanation(id,month,year)
    txt = PropertyLease.in_rent_roll_exp(id,month,year)
    return txt.comments if !(txt.nil? || txt.blank?)
  end
  def sub_lease_explanation(id,occupancy_type,property_id)
    txt = LeasesExplanation.lease_explanation(id,occupancy_type,property_id)
    return txt.explanation if !(txt.nil? || txt.blank?)
  end

  def find_lease_explanation(id,occupancy_type)
    txt = Lease.lease_exp(id,occupancy_type)
    return txt.note.content if !( (txt.nil? || txt.blank?) && txt.note.nil?)
  end

  def aged_receivable_explanation(id,month,ytd_check)
    txt = PropertyAgedReceivable.find(:first, :conditions => ["id = ?",id])
    return txt.explanation if !(txt.nil? || txt.blank?)
  end


  def financial_explanation_doc(id,month,ytd_check)
    txt = IncomeCashFlowExplanation.in_cash_flow_exp(id,month,ytd_check)
    return txt.document_id  if !(txt.nil? || txt.blank?)
  end
  def financial_explanation_user_id(id,month,ytd_check)
    txt = IncomeCashFlowExplanation.in_cash_flow_exp(id,month,ytd_check)
    return txt.user_id  if !(txt.nil? || txt.blank?)
  end

  def financial_explanation_updated_at(id,month,ytd_check)
    txt = IncomeCashFlowExplanation.in_cash_flow_exp(id,month,ytd_check)
    return txt.updated_at  if !(txt.nil? || txt.blank?)
  end
  def cash_receivable_explanation(id,month)
    txt = PropertyCashFlowForecastExplanation.find(:first, :conditions => ["property_cash_flow_forecast_id = ? and month = ?",id,month])
    return txt.explanation if !(txt.nil? || txt.blank?)
  end
  def lease_explanation(id,month,year,type)
    #txt = IncomeCashFlowExplanation.find_by_income_and_cash_flow_detail_id(id)
    txt = LeasesExplanation.find(:first, :conditions =>["month = ? and year = ? and real_estate_property_id = ? and occupancy_type=?",month, year,id,type])
    # for retrieve explaination user_id not required
    return txt.explanation if !(txt.nil? || txt.blank?)
  end
  def leases_explanation_updated_at(id,month,ytd_check)
    txt = LeasesExplanation.find_by_id_and_month(id,month)
    return txt.updated_at if !(txt.nil? || txt.blank?)
  end

  def wres_store_variance_details_forecast(id, type)
    coll = PropertyCashFlowForecast.find_all_by_resource_id_and_resource_type(id, type)
    coll.each do |itr|
      next if ['BEGINNING CASH','TOTAL CASH INCREASE (DECREASE)','ENDING CASH'].any?{|i|itr.title.include?(i)}
      pfs =  itr.property_financial_periods
      b_row = pfs.detect {|i| i.pcb_type == 'b'}
      a_row = pfs.detect {|i| i.pcb_type == 'c'}
      unless b_row.nil? && a_row.nil?
        b_arr = [b_row.january, b_row.february, b_row.march, b_row.april, b_row.may, b_row.june, b_row.july, b_row.august, b_row.september, b_row.october, b_row.november, b_row.december]
        #b_arr.each_with_index { |i,j| b_arr[j] = 0 if i.nil? }
        a_arr = [a_row.january, a_row.february, a_row.march, a_row.april, a_row.may, a_row.june, a_row.july, a_row.august, a_row.september, a_row.october, a_row.november, a_row.december]
        #a_arr.each_with_index { |i,j| a_arr[j] = 0 if i.nil? }
        var_arr = []
        per_arr = []
        0.upto(11) do |indx|
          if b_arr[indx].nil? or a_arr[indx].nil?
            var_arr[indx] = nil
            per_arr[indx] = nil
          else
            var_arr[indx] = wres_find_income_or_expense(itr) ? (b_arr[indx].to_f - a_arr[indx].to_f) : (a_arr[indx].to_f -  b_arr[indx].to_f)
            per_arr[indx] =  (var_arr[indx] * 100) / b_arr[indx].to_f
            if  b_arr[indx].to_f==0
              per_arr[indx] = ( a_arr[indx].to_f == 0 ? 0 : -100 )
            end
            per_arr[indx]= 0.0 if per_arr[indx].to_f.nan?
          end
        end
        pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_amt')
        pf.january= var_arr[0];pf.february=var_arr[1];pf.march=var_arr[2];pf.april=var_arr[3];pf.may=var_arr[4];pf.june=var_arr[5];pf.july=var_arr[6];pf.august=var_arr[7];pf.september=var_arr[8];pf.october=var_arr[9];pf.november=var_arr[10];pf.december=var_arr[11];pf.save
        pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_per')
        pf.january= per_arr[0];pf.february=per_arr[1];pf.march=per_arr[2];pf.april=per_arr[3];pf.may=per_arr[4];pf.june=per_arr[5];pf.july=per_arr[6];pf.august=per_arr[7];pf.september=per_arr[8];pf.october=per_arr[9];pf.november=per_arr[10];pf.december=per_arr[11];pf.save
        #PropertyFinancialPeriod.create(:source_id => itr.id, :source_type=> itr.class.to_s, :pcb_type=>'var_per', :january=> per_arr[0], :february=>per_arr[1], :march=>per_arr[2], :april=>per_arr[3], :may=>per_arr[4], :june=>per_arr[5], :july=>per_arr[6], :august=>per_arr[7], :september=>per_arr[8], :october=>per_arr[9], :november=>per_arr[10], :december=>per_arr[11])
      end
    end
  end
  def wres_find_income_or_expense(rec)
    if rec.title.downcase.match(/capital expenditure/) or rec.title.downcase.match(/expense/) or rec.title.downcase.match(/others/)
      true
    else
      unless rec.parent_id.nil?
        find_income_or_expense( IncomeAndCashFlowDetail.find(rec.parent_id) )
      else
        false
      end
    end
  end
  def find_expense_for_variance(str = "")
    str.downcase.include?("expense") ? true : false
  end
  def find_income_or_expense(rec)
    if rec.title.downcase.match(/capital expenditure/) or rec.title.downcase.match(/expenses/)
      true
    else
      unless rec.parent_id.nil?
        find_income_or_expense( IncomeAndCashFlowDetail.find(rec.parent_id) )
      else
        false
      end
    end
  end
  def find_income_or_expense_amp_excel(rec)
    if rec.title.downcase.match(/capital expenditure/) or (rec.title.downcase.match(/expense/) && !rec.title.downcase.match(/recovery/))
      true
    else
      unless rec.parent_id.nil?
        find_income_or_expense_amp_excel( IncomeAndCashFlowDetail.find(rec.parent_id) )
      else
        false
      end
    end
  end
  def explanation_required_property(real_estate_property, month_det = nil, year_det = nil)
    constr = real_estate_property.variance_threshold.nil? ?  real_estate_property.portfolio.portfolio_type : real_estate_property.variance_threshold
    if constr.and_or == "and"
      qry = "select ic.* from income_and_cash_flow_details ic
               join property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type ='IncomeAndCashFlowDetail' AND pf1.pcb_type='var_amt' AND (pf1.#{month_det} > #{constr.variance_amount.nil? ? 0 : constr.variance_amount} or pf1.#{month_det} < -#{constr.variance_amount.nil? ? 0 : constr.variance_amount})
               join property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type ='IncomeAndCashFlowDetail' AND pf2.pcb_type='var_per' AND (pf2.#{month_det}< -#{constr.variance_percentage.nil? ? 0 : constr.variance_percentage} or pf2.#{month_det} > #{constr.variance_percentage.nil? ? 0 : constr.variance_percentage})
             where ic.year =#{year_det} AND ic.resource_type = 'RealEstateProperty' AND ic.resource_id=#{real_estate_property.id};"
    elsif constr.and_or == "or"
      qry = "select distinct  ic.* from income_and_cash_flow_details ic join property_financial_periods pf on pf.source_id = ic.id and pf.source_type ='IncomeAndCashFlowDetail' and  (( pf.pcb_type='var_amt' and (pf.#{month_det} < -#{constr.variance_amount.nil? ? 0 : constr.variance_amount} or pf.#{month_det} > #{constr.variance_amount.nil? ? 0 : constr.variance_amount} ) )  or ( pf.pcb_type='var_per' and (pf.#{month_det} < -#{constr.variance_percentage.nil? ? 0 : constr.variance_percentage} or pf.#{month_det} > #{constr.variance_percentage.nil? ? 0 : constr.variance_percentage} ))) WHERE ic.year=#{year_det} AND ic.resource_type = 'RealEstateProperty' AND ic.resource_id=#{real_estate_property.id};"
    end
    expl_required = IncomeAndCashFlowDetail.find_by_sql(qry)
    expl_required.select{|i| i.tool_tip = wres_and_swig_path_for_items(i.id) if !wres_and_swig_path_for_items(i.id).nil? }
  end
  def explanation_required_property_ytd(real_estate_property, month_det = nil, year_det = nil)
    constr = real_estate_property.variance_threshold.nil? ?  real_estate_property.portfolio.portfolio_type : real_estate_property.variance_threshold
    if constr.and_or_ytd == "and"
      qry = "select ic.* from income_and_cash_flow_details ic
               join property_financial_periods pf1 on pf1.source_id = ic.id AND pf1.source_type ='IncomeAndCashFlowDetail' AND pf1.pcb_type='var_amt_ytd' AND (pf1.#{month_det} > #{constr.variance_amount_ytd.nil? ? 0 : constr.variance_amount_ytd} or pf1.#{month_det} < -#{constr.variance_amount_ytd.nil? ? 0 : constr.variance_amount_ytd})
               join property_financial_periods pf2 on pf2.source_id = ic.id AND pf2.source_type ='IncomeAndCashFlowDetail' AND pf2.pcb_type='var_per_ytd' AND (pf2.#{month_det}< -#{constr.variance_percentage_ytd.nil? ? 0 : constr.variance_percentage_ytd} or pf2.#{month_det} > #{constr.variance_percentage_ytd.nil? ? 0 : constr.variance_percentage_ytd})
             where ic.year =#{year_det} AND ic.resource_type = 'RealEstateProperty' AND ic.resource_id=#{real_estate_property.id};"
    elsif constr.and_or_ytd == "or"
      qry = "select distinct  ic.* from income_and_cash_flow_details ic join property_financial_periods pf on pf.source_id = ic.id and pf.source_type ='IncomeAndCashFlowDetail' and (( pf.pcb_type='var_amt_ytd' and (pf.#{month_det} < -#{constr.variance_amount_ytd.nil? ? 0 : constr.variance_amount_ytd} or pf.#{month_det} > #{constr.variance_amount_ytd.nil? ? 0 : constr.variance_amount_ytd} ) )  or ( pf.pcb_type='var_per_ytd' and (pf.#{month_det} < -#{constr.variance_percentage_ytd.nil? ? 0 : constr.variance_percentage_ytd} or pf.#{month_det} > #{constr.variance_percentage_ytd.nil? ? 0 : constr.variance_percentage_ytd} ))) WHERE ic.year=#{year_det} AND ic.resource_type = 'RealEstateProperty' AND ic.resource_id=#{real_estate_property.id};"
    end
    expl_required = IncomeAndCashFlowDetail.find_by_sql(qry)
    expl_required.select{|i| i.tool_tip = wres_and_swig_path_for_items(i.id) if !wres_and_swig_path_for_items(i.id).nil? }
  end
  def explanation_required_expenditures(real_estate_property, month_det = nil, year_det = nil)
    month_row = ['','january','february','march','april','may','june','july','august','september','october','november','december']
    constr = real_estate_property.variance_threshold.nil? ?  real_estate_property.portfolio.portfolio_type : real_estate_property.variance_threshold
    insert_month =((find_accounting_system_type(2,real_estate_property) || find_accounting_system_type(0,real_estate_property)) && real_estate_property.leasing_type=="Commercial") ? "" : "and    (ci.month = #{month_det} or ci.month = 0)"
    qry = "select ci.* from property_capital_improvements ci, property_financial_periods pi
           where ci.real_estate_property_id = #{real_estate_property.id}
           and ci.year= #{year_det}
           and pi.source_id = ci.id and pi.source_type = 'PropertyCapitalImprovement'
           and pi.pcb_type = 'var_amt' #{insert_month}
           and pi.#{month_row[month_det]} and ci.tenant_name in ('TOTAL TENANT IMPROVEMENTS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL LEASE COSTS','TOTAL NET LEASE COSTS','TOTAL CAPITAL EXPENDITURES')
               and (pi.#{month_row[month_det]} < - #{constr.cap_exp_variance.nil? ? 0 : constr.cap_exp_variance } or pi.#{month_row[month_det]} > #{constr.cap_exp_variance.nil? ? 0 : constr.cap_exp_variance });"
    PropertyCapitalImprovement.find_by_sql(qry)
  end
  def explanation_required_expenditures_ytd(real_estate_property, month_det = nil, year_det = nil)
    month_row = ['','january','february','march','april','may','june','july','august','september','october','november','december']
    constr = real_estate_property.variance_threshold.nil? ?  real_estate_property.portfolio.portfolio_type : real_estate_property.variance_threshold
    insert_month =((find_accounting_system_type(2,real_estate_property) || find_accounting_system_type(0,real_estate_property)) && real_estate_property.leasing_type=="Commercial") ? "" : "and (ci.month = #{month_det} or ci.month = 0)"
    qry = "select ci.* from property_capital_improvements ci, property_financial_periods pi
           where ci.real_estate_property_id = #{real_estate_property.id} and ci.year= #{year_det} and pi.source_id = ci.id and pi.source_type = 'PropertyCapitalImprovement' #{insert_month}  and pi.pcb_type = 'var_amt_ytd' and ci.tenant_name in ('TOTAL TENANT IMPROVEMENTS','TOTAL BUILDING IMPROVEMENTS','TOTAL LEASING COMMISSIONS','TOTAL LEASE COSTS','TOTAL NET LEASE COSTS','TOTAL CAPITAL EXPENDITURES')
            and (pi.#{month_row[month_det]} < - #{constr.cap_exp_variance_ytd.nil? ? 0 : constr.cap_exp_variance_ytd } or pi.#{month_row[month_det]} > #{constr.cap_exp_variance_ytd.nil? ? 0 : constr.cap_exp_variance_ytd });"
    PropertyCapitalImprovement.find_by_sql(qry)
  end
  def find_name_of_the_parents_parent(id)
    fol = Folder.find_by_id(id)
    fol.nil? ? '' : fol.name
  end
  def wres_parsing_cash_flow_forecast(doc)
    actual_end = nil
    real_estate_property_id = doc.real_estate_property_id
    year = ''
    act_row  = Array.new(12,nil)
    bud_row  = Array.new(12,nil)
    title_definer = []
    parent_definer = []
    blockers = ['SUBTOTAL RENT','TOTAL OPERATING INCOME','TOTAL OPERATING EXPENSES','TOTAL CASH ADJUSTMENTS']
    book = Excel.new "#{Rails.root.to_s}/public#{doc.public_filename}"
    book.default_sheet = book.sheets[0]
    xl_name = book.cell(1,1)
    if xl_name.downcase.gsub(/[^a-z]/,'').include?("reportcashflowforecast")
      year = book.cell(4,2).to_s.split('/').last.to_i
      3.upto(65) do |row|
        next if book.cell(row,1).nil? && book.cell(row,2).nil?
        unless (book.cell(row,1).nil? || book.cell(row,1).blank?) && (book.cell(row,2).nil? || book.cell(row,2).blank? )
          if (book.cell(row,1).nil? || book.cell(row,1).blank?) && book.cell(row,2) == 'Actual'
            3.upto(13) do |col|
              actual_end = col - 1 if book.cell(row,col).include?('Forecast')
            end
            next
          end
          if ((!book.cell(row,1).nil? || !book.cell(row,1).blank?) && (book.cell(row,2).nil? || book.cell(row,2).blank? ))
            title_definer.push(book.cell(row,1))
            parent_definer.push(store_values_for_cash_flow_forcast(nil, real_estate_property_id, title_definer.last, year, act_row, bud_row))
            next
          end
          if ['TOTAL CASH INCREASE (DECREASE)','BEGINNING CASH','ENDING CASH'].any?{|i|book.cell(row,1).to_s.include?(i)}
           (2..actual_end).each_with_index do |col,ind|
              act_row[ind] =  book.celltype(row,col) == :string ? get_correct_value(book.cell(row, col)) : book.cell(row, col)
            end
             ((actual_end + 1)..13).each do |col|
              bud_row[col-2] = (book.celltype(row,col) == :string) ? get_correct_value(book.cell(row, col)) : book.cell(row, col)
            end
            store_values_for_cash_flow_forcast(nil, real_estate_property_id, book.cell(row,1), year, act_row, bud_row)
            eval("act_row  = Array.new(12,nil);bud_row = Array.new(12,nil)")
            #PropertyCashFlowForecast.create(:title=>)
          elsif blockers.any?{|i|book.cell(row,1).to_s.include?(i)}
            update_for = parent_definer.last
            parent_definer.pop; title_definer.pop
            store_values_for_cash_flow_forcast(parent_definer.last, real_estate_property_id, book.cell(row,1), year, act_row, bud_row, update_for)
            eval("act_row  = Array.new(12,nil);bud_row = Array.new(12,nil)");
          elsif (!book.cell(row,1).nil? || !book.cell(row,1).blank?)
            if (book.cell(row,1).include?('Contingency') || book.cell(row,1).include?('Maintenance Projects'))
              set_title = book.cell(row,1).include?('Contingency') ? "OTHER EXPENSES" :"OTHERS"
              title_definer.push(set_title)
              parent_definer.push(store_values_for_cash_flow_forcast(nil, real_estate_property_id, title_definer.last, year, act_row, bud_row))
            end
             (2..actual_end).each_with_index do |col,ind|
              act_row[ind] =  book.celltype(row,col) == :string ? get_correct_value(book.cell(row, col)) : book.cell(row, col)
            end
             ((actual_end + 1)..13).each do |col|
              bud_row[col-2] = (book.celltype(row,col) == :string) ? get_correct_value(book.cell(row, col)) : book.cell(row, col)
            end
            store_values_for_cash_flow_forcast(parent_definer.last, real_estate_property_id, book.cell(row,1), year, act_row, bud_row)
            eval("act_row  = Array.new(12,nil);bud_row = Array.new(12,nil)")
            if (book.cell(row,1).include?('Real Estate Taxes')||(book.cell(row,1).include?('Interest Expense - 1st')))
              update_for = parent_definer.last
              parent_definer.pop; title_definer.pop
              store_values_for_cash_flow_forcast(parent_definer.last, real_estate_property_id, book.cell(row,1), year, act_row, bud_row, update_for)
            end
          end
        end
      end
    end
  end
  def get_correct_value(val)
    if ['-','(',')'].any?{|i| val.include?(i)}
     ("-" + val.gsub("(",'').gsub(")","").gsub("-","").gsub(',','')).to_d
    else
      val.to_d
    end
  end
  def store_values_for_cash_flow_forcast(parent_id, rid, title, year, act, bud, for_parent = 0)
    unless for_parent.zero?
      forecast = PropertyCashFlowForecast.find(for_parent);
      qry = "select sum(january) a, sum(february) b, sum(march) c, sum(april) d,sum(may) e,sum(june) f,sum(july) g,sum(august) h,sum(september) i,sum(october) jth,sum(november) k,sum(december) l from property_financial_periods where source_id IN(select id from property_cash_flow_forecasts where parent_id = #{for_parent}) and source_type = 'PropertyCashFlowForecast' and pcb_type = 'b';"
      val = PropertyFinancialPeriod.find_by_sql(qry).first
      bud = [val.a, val.b, val.c ,val.d ,val.e ,val.f ,val.g ,val.h ,val.i ,val.jth ,val.k, val.l]
      qry.gsub!('\'b\'','\'c\'')
      val = PropertyFinancialPeriod.find_by_sql(qry).first
      act = [val.a, val.b, val.c ,val.d ,val.e ,val.f ,val.g ,val.h ,val.i ,val.jth ,val.k, val.l]
    else
      forecast = PropertyCashFlowForecast.find_or_initialize_by_resource_id_and_resource_type_and_title_and_year(rid, 'RealEstateProperty', title, year);
    end
    forecast.parent_id = parent_id
    forecast.user_id = params[:user_id] ? params[:user_id] : current_user.id
    forecast.save
    budget = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(forecast.id, forecast.class.to_s, 'b')
    budget.january = bud[0] if budget.january.nil? ; budget.february = bud[1] if budget.february.nil? ; budget.march = bud[2] if budget.march.nil?
    budget.april = bud[3] if budget.april.nil? ; budget.may = bud[4] if budget.may.nil? ; budget.june = bud[5] if budget.june.nil?
    budget.july = bud[6] if budget.july.nil? ; budget.august = bud[7] if budget.august.nil? ; budget.september = bud[8] if budget.september.nil?
    budget.october = bud[9] if budget.october.nil? ; budget.november = bud[10] if budget.november.nil? ; budget.december = bud[11] if budget.december.nil?
    budget.save
    actual = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(forecast.id, forecast.class.to_s, 'c')
    actual.january = act[0] if actual.january.nil? ; actual.february = act[1] if actual.february.nil? ; actual.march = act[2] if actual.march.nil?
    actual.april = act[3] if actual.april.nil? ; actual.may = act[4] if actual.may.nil? ; actual.june = act[5] if actual.june.nil?
    actual.july = act[6] if actual.july.nil? ; actual.august = act[7] if actual.august.nil? ; actual.september = act[8] if actual.september.nil?
    actual.october = act[9] if actual.october.nil? ; actual.november = act[10] if actual.november.nil? ; actual.december = act[11] if actual.december.nil?
    actual.save
    return forecast.id
  end
  def calculate_var_values(record)
    val = 0
    ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"].each do |i|
      val = val + record.send(:"#{i}") unless record.send(:"#{i}").nil?
    end
    val.zero? ? nil : val
  end
  def wres_explanation_required_property(real_estate_property, month_det = nil, year_det = nil)

    constr = real_estate_property.variance_threshold.nil? ?  real_estate_property.portfolio.portfolio_type : real_estate_property.variance_threshold
    if constr.and_or == "and"
      qry = "SELECT ic.* FROM (
                SELECT pf.source_id psid
                FROM
                 property_financial_periods pf
                WHERE
                  pf.source_id IN (SELECT ic.id FROM property_cash_flow_forecasts ic WHERE ic.year = #{year_det} AND ic.resource_type = 'RealEstateProperty' AND ic.resource_id= #{real_estate_property.id} ) AND
                  ((pf.pcb_type = 'var_amt' AND pf.#{month_det}< -#{constr.variance_amount.nil? ? 0 : constr.variance_amount}) OR (pf.pcb_type = 'var_per' AND pf.#{month_det}< -#{constr.variance_percentage.nil? ? 0 : constr.variance_percentage}))
                  GROUP BY pf.source_id
                  HAVING COUNT(pf.source_id) >= 2
                  ) kk
             LEFT JOIN property_cash_flow_forecasts ic
             ON ic.id = kk.psid WHERE ic.year = #{year_det} AND ic.resource_type = 'RealEstateProperty' AND ic.resource_id=#{real_estate_property.id};"
    elsif constr.and_or == "or"
      qry = "SELECT ic.* FROM ( SELECT DISTINCT pf.source_id psid  FROM  property_financial_periods pf WHERE pf.source_id IN (SELECT ic.id FROM property_cash_flow_forecasts ic WHERE ic.year = #{year_det} AND ic.resource_type = 'RealEstateProperty' AND ic.resource_id=#{real_estate_property.id} ) AND ((pf.pcb_type = 'var_amt' AND pf.#{month_det} < -#{constr.variance_amount}) OR (pf.pcb_type = 'var_per' AND pf.#{month_det} < -#{constr.variance_percentage})) ) kk  LEFT JOIN property_cash_flow_forecasts ic  ON ic.id = kk.psid WHERE ic.year=#{year_det} AND ic.resource_type = 'RealEstateProperty' AND ic.resource_id=#{real_estate_property.id};"
    end
    expl_required = PropertyCashFlowForecast.find_by_sql(qry)
  end

  def update_partials(page)
    if current_user.has_role?("Shared User") && session[:role] == 'Shared User'
      if params[:folder_id]
        @folder = Folder.find_by_id(params[:folder_id])
      end
    end
    if params[:change_portfolio] == 'true'
      replace_navigation_bar(page,@portfolio,@note)
    end
    if @go_to_collab_hub
      page.replace_html "show_assets_list",:partial=>'/collaboration_hub/my_files_assets_list'
    elsif params[:call_from_prop_files] == "true"
      page.replace_html 'show_assets_list',:partial=>"/properties/properties_and_files"
    else
      parent_n = Folder.find_by_id(@folder.parent_id) if @folder
      if parent_n && parent_n.name == "my_files" && !params[:folder_id]
        page.replace_html "show_assets_list",:partial=>'/collaboration_hub/my_files_assets_list'
      else
        shared_property_folder = SharedFolder.find_by_folder_id_and_user_id_and_client_id(@folder.id,current_user.id,current_user.client_id,:conditions=>["is_property_folder is not null and is_property_folder = true"]) if @folder && @folder.parent_id != -1
        d = SharedFolder.find_by_folder_id_and_user_id_and_client_id(@folder.id,current_user.id,current_user.client_id) if @folder
        shared_others_folder = SharedFolder.find_by_folder_id_and_sharer_id(@folder.id,current_user.id) if @folder
        if parent_n && parent_n.name == "my_files" && params[:del_files] != "true" && parent_n.parent_id == 0 || find_manage_real_estate_shared_folders('false').flatten.index(@folder)
          page.replace_html "show_assets_list",:partial=>'/properties/assets_list'
        else
          if (params[:from_collab_task] == "true" || params[:from_task] == "true" || params[:call_for_task]) && @folder.name == "my_files" && @folder.parent_id == 0 || (@folder && @folder.parent_id != -1 &&  @folder && shared_property_folder.nil? && @folder.user_id != current_user.id && (!d && shared_others_folder.nil?))
            page.replace_html "show_assets_list",:partial=>'/collaboration_hub/my_files_assets_list'
          else
            if @folder && (@folder.name == "my_files" || @folder.name == "my_deal_room") && @folder.parent_id == 0 && params['list'] != 'shared_list'
              page.replace_html "show_assets_list",:partial=>'/collaboration_hub/my_files_assets_list'
            elsif params[:list] == "shared_list"
              page.replace_html "show_assets_list2",:partial=>'/properties/assets_list'
            else
              page.replace_html "show_assets_list",:partial=>'/properties/assets_list'
            end
          end
        end
      end
    end
  end

  def find_past_shared_folders_documents_tasks(find_deleted_folders)
    params[:asset_id] =@folder.id
    conditions = find_deleted_folders == 'true' ?   "" : "and is_deleted = false"
    find_manage_real_estate_shared_folders('false')  if ( @folder.name == 'my_files' || @folder.name == 'my_deal_room') && @folder.parent_id == 0
    #to find folders,tasks,files shared to user ,then user shares that to some others
    folder_ids = (@shared_folders_real_estate && !@shared_folders_real_estate.empty?) ? @shared_folders_real_estate.collect{|f| f.id} :  []
    doc_ids = (@shared_docs_real_estate && !@shared_docs_real_estate.empty?) ? @shared_docs_real_estate.collect{|f| f.id} :  []
    #To find shared folders
    fids_in_cur_folder = Folder.find(:all,:conditions=>["(parent_id = ? or id in (?)) #{conditions}",params[:asset_id],folder_ids]).collect{|f| f.id}
    @past_shared_folders = SharedFolder.find(:all,:conditions=>["sharer_id = ? and folder_id in (?) and user_id != sharer_id",current_user.id,fids_in_cur_folder]).collect{|sf| sf.folder}.uniq
    #To find shared documents
    docids_in_cur_folder = Document.find(:all,:conditions=>["(folder_id = ? or id in (?)) #{conditions}",params[:asset_id],doc_ids]).collect{|d| d.id}
    @past_shared_docs  = SharedDocument.find(:all,:conditions=>["sharer_id = ? and document_id in (?) and user_id != sharer_id",current_user.id,docids_in_cur_folder]).collect{|sd| sd.document}.uniq
  end


  def get_explanation_date(document_id,month,collaborator_id)
    if params[:from_assign_task] == 'cap_exp'
      cec = CapitalExpenditureExplanation.find(:last, :conditions=>['document_id = ? and month = ? and user_id = ?', document_id, month, collaborator_id])
      explained_on = cec.updated_at.strftime("%b %d").downcase if cec
    else
      ice = IncomeCashFlowExplanation.find(:last, :conditions=>['document_id = ? and month = ? and user_id = ?', document_id, month, collaborator_id])
      explained_on = ice.updated_at.strftime("%b %d").downcase if ice
    end
  end

  def find_by_parent_id_and_portfolio_id(id)
    return Folder.find_by_parent_id_and_real_estate_property_id(-1,id)
  end

  def bulk_find_by_id(parent_id)
    return Folder.find_by_id(parent_id)
  end

  def find_folder(id)
    return Folder.find(id)
  end
  def find_document(id)
    return DocumentName.find(id)
  end

  def find_income_and_cash_flow_detail(note,year)
    return IncomeAndCashFlowDetail.find(:first,:conditions=> ["title=? and resource_id=? and year=?",'operating income',note,year])
  end
  #forms a hash for loan details in add a property
  def form_hash_for_loan_details
    #max_month_year = PropertyDebtSummary.find(:all,:conditions =>["real_estate_property_id = #{@property.id}"],:select=>"max(month) as month,max(year) as year")[0]
    if params[:from_debt_summary] == 'true' && params[:property_id]
      @property = RealEstateProperty.find_real_estate_property(params[:property_id])  if @property.nil?
    end
    debtsummary = PropertyDebtSummary.find(:all,:conditions =>["real_estate_property_id = ?",@property.id])
    a = debtsummary.each_slice(13).to_a #separate_debt_items(debtsummary)
    @loan_hash = []
    if @add_loan_details == true || @edit_loan_details == true
      for i in 0..2
        if !check_if_loan_value_exists(params,i) && a[i] != nil && (params[:loan_form_submit] == 'true' || params[:loan_form_close] == 'true')
          a[i].each do |debt|
            debt.destroy
          end
        end
        if check_if_loan_value_exists(params,i)
          @loan_hash[i] ={'Lender' =>params[:Lender]["#{i}"],'Guarantors' =>params[:Guarantors]["#{i}"],'Loan Amount' =>params[:Loan_Amount]["#{i}"],'Loan Balance' =>params[:Loan_Balance]["#{i}"],'Term' =>params[:Term]["#{i}"] , 'Date of Promissory Note' => params[:Date_of_Promissory_Note]["#{i}"],'Maturity' => params[:Maturity]["#{i}"],'Interest Rate' => params[:Interest_Rate]["#{i}"],'Payments' => params[:Payments]["#{i}"],'Tax Escrow Payments'=>params[:Tax_Escrow_Payments]["#{i}"],'Replacement Reserve'=> params[:Replacement_Reserve]["#{i}"],'Tenant Improvement and Leasing Commission Reserve'=>params[:Tenant_Improvements_and_Leasing_Commission_Reserve]["#{i}"],'Prepayment'=>params[:Prepayment]["#{i}"]}
        end
      end
    elsif !debtsummary.empty?
      i=0
      summary_array =  debtsummary.each_slice(13).to_a
      summary_array.each do |s|
        @loan_hash[i] = {}
        s.each do |d|
          @loan_hash[i]["#{d.category}"] = d.description
        end
        i += 1
      end
      @edit_loan_details = true
    else
      @loan_hash[0] ={'Lender' =>"",'Guarantors' =>"",'Loan Amount' => "",'Loan Balance' => "",'Term' => "", 'Date of Promissory Note' => "",'Maturity' => "",'Interest Rate' => "",'Payments' => "",'Tax Escrow Payments'=>"",'Replacement Reserve'=> "",'Tenant Improvement and Leasing Commission Reserve'=>"",'Prepayment'=>""}
      @add_loan_details = true
    end
    @loan_hash = @loan_hash.compact
  end

  def separate_debt_items(debtsummary)
    i =0
    j=0
    indexes = []
    debtsummary.each do |item|
      indexes << i if item.category == "Prepayment"
      i +=1
    end
    b=[]
    k=0
    indexes.each do |index|
      b[k] = {}
      for j in j..index
        b[k][j] = debtsummary[j]
      end
      k +=1
      j +=1
    end
    return b
  end

  def check_if_loan_value_exists(params,loan_number)
    loan_number = loan_number.to_s
    if (params[:Lender][loan_number] != nil && params[:Lender][loan_number].strip != "") ||  (params[:Guarantors][loan_number] != nil && params[:Guarantors][loan_number].strip != "") || (params[:Loan_Amount][loan_number]   != nil  && params[:Loan_Amount][loan_number].strip   != "" ) || (params[:Loan_Balance][loan_number] != nil && params[:Loan_Balance][loan_number].strip != "") || (params[:Term][loan_number]  != nil && params[:Term][loan_number].strip  != "" ) || (params[:Date_of_Promissory_Note][loan_number]  != nil && params[:Date_of_Promissory_Note][loan_number].strip  != "") || (params[:Maturity][loan_number]  != nil && params[:Maturity][loan_number].strip  != "") || (params[:Interest_Rate][loan_number]  != nil && params[:Interest_Rate][loan_number].strip  != "" ) || (params[:Payments][loan_number]  != nil && params[:Payments][loan_number].strip  != "" ) || (params[:Tax_Escrow_Payments][loan_number]  != nil && params[:Tax_Escrow_Payments][loan_number].strip != "") || (params[:Replacement_Reserve][loan_number] != nil && params[:Replacement_Reserve][loan_number].strip   != "") || (params[:Tenant_Improvements_and_Leasing_Commission_Reserve][loan_number]  != nil && params[:Tenant_Improvements_and_Leasing_Commission_Reserve][loan_number].strip  != "" ) || (params[:Prepayment][loan_number] != nil && params[:Prepayment][loan_number].strip != "" )
      return true
    else
      return false
    end
  end
  def lease_exp(note_id,month,year,type)
    @exp=LeasesExplanation.find(:first, :conditions=>['month = ? and year = ? and real_estate_property_id = ? and occupancy_type = ?', month, year,note_id,type], :select => "explanation,user_id,id")
  end

  def document_row_image_link(t)
    if !t.is_deleted
      unless params[:user] == 'false'
        if t.user_id != current_user.id || (@past_shared_docs && @past_shared_docs.index(t)) || params[:shared] == "yes"
          raw("<img src='/images/#{find_content_type(t,'shared','false')}' width='32' height='32' border='0' onclick='make_downloads(#{t.id})' style='cursor: pointer;' />")
        else
          raw("<img src='/images/#{find_content_type(t,'unshared','false')}' width='32' height='32' border='0' onclick='make_downloads(#{t.id})' style='cursor: pointer;'/>")
        end
      else
        if t.user_id != current_user.id || (@past_shared_docs && @past_shared_docs.index(t)) || params[:shared] == "yes"
          raw("<img src='/images/#{find_content_type(t,'shared','false')}' width='32' height='32' border='0' onclick='make_downloads_for_public(#{t.id})' style='cursor: pointer;' />")
        else
          raw("<img src='/images/#{find_content_type(t,'unshared','false')}' width='32' height='32' border='0' onclick='make_downloads_for_public(#{t.id})' style='cursor: pointer;'/>")
        end
      end
    else
      if t.user_id != current_user.id || (@past_shared_docs && @past_shared_docs.index(t))
        raw("<img src='/images/#{find_content_type(t,'shared','true')}' width='32' height='32' border='0' />")
      else
        raw("<img src='/images/#{find_content_type(t,'unshared','true')}' width='32' height='32' border='0' />")
      end
    end
  end


  def prop_cal(i)
    @act_prop = i.property_financial_periods.detect { |itr| itr.pcb_type == 'c'}
    @bud_prop = i.property_financial_periods.detect { |itr| itr.pcb_type == 'b'}
    @amt_prop  = i.property_financial_periods.detect { |itr| itr.pcb_type == 'var_amt'}
    @per_prop  = i.property_financial_periods.detect { |itr| itr.pcb_type == 'var_per'}
    @var_actual = eval("@act_prop.#{@month_option}.nil? ? 0 : @act_prop.#{@month_option}")
    @var_budget = eval("@bud_prop.#{@month_option}.nil? ? 0 : @bud_prop.#{@month_option}")
    @var_amt = eval("@amt_prop.#{@month_option}.nil? ? 0 : @amt_prop.#{@month_option}").abs
    @var_per = eval("@per_prop.#{@month_option}.nil? ? 0 : @per_prop.#{@month_option}")
  end
  def prop_ytd_cal(i)
    @act_prop_ytd = i.property_financial_periods.detect { |itr| itr.pcb_type == 'c_ytd'}
    @bud_prop_ytd = i.property_financial_periods.detect { |itr| itr.pcb_type == 'b_ytd'}
    @amt_prop_ytd = i.property_financial_periods.detect { |itr| itr.pcb_type == 'var_amt_ytd'}
    @per_prop_ytd = i.property_financial_periods.detect { |itr| itr.pcb_type == 'var_per_ytd'}
    @var_actual_ytd = eval("@act_prop_ytd.#{@month_option}.nil? ? 0 : @act_prop_ytd.#{@month_option}")
    @var_budget_ytd = eval("@bud_prop_ytd.#{@month_option}.nil? ? 0 : @bud_prop_ytd.#{@month_option}")
    @var_amt_ytd = eval("@amt_prop_ytd.#{@month_option}.nil? ? 0 : @amt_prop_ytd.#{@month_option}").abs
    @var_per_ytd = eval("@per_prop_ytd.#{@month_option}.nil? ? 0 : @per_prop_ytd.#{@month_option}")
  end
  def current_user_type(i)
    if @document.try(:real_estate_property).try(:accounting_system_type_id)==4
      @is_expense = find_expense_for_variance(i.tool_tip)
    elsif @document.try(:real_estate_property).try(:accounting_system_type_id)==1
      @is_expense = find_income_or_expense_amp_excel(i)
    else
      @is_expense = find_income_or_expense(i)
    end
  end


  #..........................helpers called from properties controller starts here [please don't put any code inside this block ]........................................................................................................................................
  #To check whether name exists already
  def find_folder_name(folder_id,folder_name_old)
    folder = Folder.find_by_name(folder_name_old.strip,:conditions=>["parent_id = ?",folder_id])
    i =1
    f_name = folder_name_old
    while folder !=nil
      folder_name = "#{f_name}_#{i}"
      folder = Folder.find_by_name(folder_name,:conditions=>["parent_id = ?",folder_id])
      i += 1
    end
    folder_name =  folder_name.nil? ? folder_name_old : folder_name
    return folder_name
  end
  #updates the page and displays flash notice
  def  add_visual_effect_folder_file_name(obj,action)
    responds_to_parent do
      render :update do |page|
        page.hide 'modal_container'
        page.hide 'modal_overlay'
        update_partials(page)
        page.call "flash_writter", "#{obj} successfully #{action}"
      end
    end
  end
  #creates shared folders
  def create_share_folders(shared_folders_1,folder)
    unless shared_folders_1.empty?
      shared_folders_1.each do |subshared_folders_1|
        SharedFolder.create(:folder_id=>folder.id,:user_id=>subshared_folders_1.user_id,:sharer_id=>current_user.id,:real_estate_property_id=>@folder.real_estate_property_id)
      end
    end
    SharedFolder.create(:folder_id=>folder.id,:user_id=>@folder.user_id,:sharer_id=>current_user.id,:real_estate_property_id=>@folder.real_estate_property_id) if current_user.id != @folder.user_id
  end

  #assigns params
  def assign_params(txt1,txt2)
    params[:data_hub] = txt1
    params[:action] = txt2
  end

  #collection based on params
  def find_folders_collection_based_on_params
    if(params[:show_past_shared] == "true")
      find_past_shared_folders('false')
    else
      assign_options(@folder.id)
    end
  end

  #find_real_estate_properties(shared,owned)
  def find_real_estate_properties_for_navigation_bar
    @real_estate_properties = RealEstateProperty.find(:all, :conditions => ["portfolios.id in (?) and real_estate_properties.user_id = ? and real_estate_properties.client_id = #{current_user.client_id}",@portfolio.id,current_user.id],:joins=>:portfolios)
    @real_estate_properties += RealEstateProperty.find_by_sql("SELECT * FROM real_estate_properties WHERE id in (SELECT real_estate_property_id FROM shared_folders WHERE is_property_folder = 1 AND user_id = #{current_user.id} and client_id = #{current_user.client_id} )")
    @note = @real_estate_properties.first unless @real_estate_properties.empty?
    return @real_estate_properties
  end
  #find_property_folders(shared,owned)
  def find_property_folders
    order_by_string =  params[:sort] ? "order by #{params[:sort]}" : ""
    @folders = Folder.find(:all, :conditions => ["portfolio_id = ? and parent_id = 0 and is_master = 0 and user_id = ?",@portfolio.id,current_user.id], :order => "#{params[:sort]}")
    @folders += Folder.find_by_sql("select * from folders where id in (SELECT folder_id FROM shared_folders WHERE is_property_folder = 1 AND user_id = #{current_user.id} AND client_id = #{current_user.client_id} ) and portfolio_id = #{@portfolio.id} #{order_by_string}")
    return  @folders
  end

  #to create master folders
  def create_master_folders
    @master_folder = Folder.find_by_portfolio_id_and_is_master(@portfolio.id,true)
    @asset_folder = Folder.find_or_create_by_name_and_portfolio_id_and_real_estate_property_id(@property.property_name,@portfolio.id,@property.id)
    @asset_folder.update_attributes(:user_id=>@portfolio.user_id)
    Event.create_new_event("create",current_user.id,nil,[@asset_folder],"",@property.property_name,nil)
  end
  def create_public_documents(folder,document)
    path ="#{Rails.root.to_s}/public"+document.public_filename.to_s
    temfile = Tempfile.new(document.filename)
    begin
      temfile.write(File.open(path).read)
      temfile.flush
      upload_data = ActionDispatch::Http::UploadedFile.new({:filename=>document.filename,:type=>document.content_type, :tempfile=>tempfile})
      d= Document.new(:folder_id=>folder.id,:user_id=>current_user.id,:is_master=>folder.is_master)
      d.uploaded_data = upload_data
      d.due_date = @portfolio.updated_at + fl.due_days.days if !document.due_days.nil?
      d.save
    ensure
      temfile.close
      temfile.unlink
    end
    return d
  end

  #collects folders,docs,checklist in a particular folder
  def assign_options(folder_id = nil)
    view_del_files = (params[:del_files] == 'true') ? true : false
    @show_deleted = view_del_files
    f_id = folder_id.nil? ? params[:folder_id] : folder_id
    if  params[:users_form_close] != 'true' && ((@folder && @folder.parent_id == -1) || params[:folder_id] == "0" || (@folder && @folder.parent_id == 0 && params[:action] == "share_folder"))
      @property_view = "false"
      f_conditions =   "portfolio_id = #{params[:pid]} and is_master = #{false} and parent_id = #{false} and is_deleted = #{false}"  if params[:pid]
      f_conditions =   "portfolio_id = #{params[:portfolio_id]} and is_master = #{false} and parent_id = #{false} and is_deleted = #{false}"  if params[:portfolio_id]
      f_conditions << " and is_deleted = #{view_del_files}" if view_del_files == false
      f_options = {:conditions => f_conditions}
      d_options = {}
      @display_properties = true
      listing_sub_folders(f_options,d_options)
    elsif (params[:sfid]) && (params[:sfid].to_i <= 0 )
      show_portfolios
    else
      @property_view = "true"
      if  f_id
        #Added for find basic portfolio_id
        portfolio_id = (Folder.find(f_id).present? && Folder.find(f_id).portfolio_id) ? Folder.find(f_id).try(:portfolio_id) : params[:pid].present? ? params[:pid].to_i : params[:portfolio_id].present? ? params[:portfolio_id].to_i : ""
        f_conditions = "portfolio_id = #{portfolio_id} and parent_id = #{f_id}"
      else
        f_conditions = "portfolio_id = #{params[:pid]} and parent_id = #{f_id}" if params[:pid]
        f_conditions = "portfolio_id = #{params[:portfolio_id]} and parent_id = #{f_id}" if params[:portfolio_id]
      end
      f_conditions << " and is_deleted = #{view_del_files}" if view_del_files == false
      f_options = {:conditions => f_conditions}
      d_conditions = "folder_id = #{f_id}"
      d_conditions << " and is_deleted = #{view_del_files}" if view_del_files == false
      d_options = {:conditions => d_conditions}
      listing_sub_folders(f_options,d_options)
    end
  end

  #updates the page and displays flash notice
  def add_visual_effect_delete_file(msg)
    if request.xhr?
      render :update do |page|
        if params[:spms_form_submit] == "true"
          page.hide 'modal_container'
          page.hide 'modal_overlay'
        end
        if params[:call_from_prop_files] == 'true'
          page.replace_html "show_assets_list",:partial=>"/properties/properties_and_files"
          unless request.env["HTTP_REFERER"].include?("show_folder_files") || request.env["HTTP_REFERER"].include?("collaboration_hub")
            if !(request.env["HTTP_REFERER"] && request.env["HTTP_REFERER"].include?("shared_users"))
              page.replace_html "edit_count_#{@portfolio.id}", :text=>"#{property_count(@portfolio.real_estate_properties.length)}" if !@portfolio.nil? && @portfolio.user_id == current_user.id
            end
          end
          if @portfolio.real_estate_properties && @portfolio.real_estate_properties.count == 0
            page << "jQuery('#asset_view_path').attr('href','/portfolios/#{@portfolio.id}?show_notice=true');"
          else
            page << "jQuery('#asset_view_path').attr('href','/real_estate/#{@portfolio.id}/properties/#{@portfolio.real_estate_properties.last.id}');"
          end
          page.call "flash_writter", "#{msg}" if msg
        elsif @folder && (@folder.name == "my_files" || @folder.name == "my_deal_room") && @folder.parent_id == 0 && params[:list] != "shared_list"
          page.replace_html "show_assets_list",:partial=>'/collaboration_hub/my_files_assets_list'
          page.call "flash_writter", "#{msg}" unless msg =="no_display"
          page.call "load_completer"
        elsif params[:call_from_prop_files] != 'true' && params[:highlight] != "2"
          page.replace_html "show_assets_list",:partial=>'/properties/assets_list' if params[:highlight] != "1"
          page.replace_html "show_assets_list",:partial=>"/properties/properties_and_files" if params[:highlight] == "1"
          unless  request.env["HTTP_REFERER"].include?("show_folder_files") || request.env["HTTP_REFERER"].include?("collaboration_hub")
            if !(request.env["HTTP_REFERER"] && request.env["HTTP_REFERER"].include?("shared_users")) && params[:parent_delete] == "true"
              page.replace_html "edit_count_#{@portfolio.id}", :text=>"#{property_count(@portfolio.real_estate_properties.length)}" if !@portfolio.nil? && @portfolio.user_id == current_user.id
            end
          end
          page.call 'highlight_datahub' if params[:highlight] == '1'
          page.call "flash_writter", "#{msg}" unless msg =="no_display"
        elsif params[:highlight] == "2"
          page.replace_html "edit_count_#{@portfolio.id}",:text=>"#{property_count(@portfolio.real_estate_properties.length)}" if !@portfolio.nil? && @portfolio.user_id == current_user.id
          page.call "update_asset_view_path", "#{@portfolio.id}", "#{params[:property_id]}"
          page.replace_html "show_assets_list",:partial=>"/properties/properties_and_files"
        end
      end
    end
  end

  def add_edit_collab_display_members
    for user in @members.uniq
      @mem_list = @mem_list.to_s + user.email.to_s + "," if user && user.email
      @data = @data + "<div class='add_users_collaboratercol' id='#{user.email}'><div class='add_users_imgcol'><img width='30' height='36' src='#{display_image_for_user_add_collab(user.id)}'/></div><div class='collaboraterow'> #{display_revoke_option(user)}<div class='collaboratername'>#{(user.name?) ?  "#{lengthy_word_simplification(user.name,7,5)}" : user.email.split('@')[0]}</div><div class='collaborateremail'>#{user.email}</div> </div></div>" if user && user.email
    end
    @leasing_members  = SharedFolder.find(:all,:conditions=>["folder_id = ? and user_id!= ?",params[:folder_id],current_user.id]).collect{|sf| sf.user if sf.user.has_role?("Leasing Agent")}.compact
    for user in @leasing_members.uniq
      @leasing_agent_mem_list = @leasing_agent_mem_list.to_s + user.email.to_s + ","  if user && user.email
      @leasing_agents_data = @leasing_agents_data + "<div class='add_users_collaboratercol' id='added_leasing_agent_#{user.email}' style='display:none;'><div class='add_users_imgcol'><img width='30' height='36' src='#{display_image_for_user_add_collab(user.id)}'/></div><div class='collaboraterow'> #{display_revoke_option(user)}<div class='collaboratername'>#{(user.name?) ?  "#{lengthy_word_simplification(user.name,7,5)}" : user.email.split('@')[0]}</div><div class='collaborateremail'>#{user.email}</div> </div></div>" if user && user.email
    end
    if params[:add_contacts] == 'true' && params[:note_add_edit] != 'true'
      responds_to_parent do
        render :update do |page|
          page.replace_html "basicbodycontainer",:partial=>"collaborators/view_to_add_collaborators"
        end
      end
    end


  end
  #...........................................................helpers called from properties controller ends here.. [please don't put any code inside this block].......................................................................................................
  # To find all folders to be listed - called from assign_initial_options
  def listing_folders(f_options)
    @folders = Folder.find(:all,f_options)
    @document_names = [ ]
    @documents = [ ]
    @folders = @folders.compact.collect{|f| f if f && check_is_folder_shared(f) == "true"}.compact unless @folders.empty?
  end
  #To check if a document name is shared to any
  def check_is_doc_name_shared(d)
    sdn = ShareDocumentName.find_by_document_name_id(d.id,:conditions=>["user_id = ? or sharer_id =?",current_user.id,current_user.id],:select=>'id')
    if sdn.nil? && d.user_id != current_user.id
      return "false"
    else
      return "true"
    end
  end
  def is_show_deleted(t)
    if  t.is_deleted == true && params[:del_files] == "true"
      return true
    elsif t.is_deleted == true && params[:del_files] != "true"
      return false
    else
      return true
    end
  end
  #To download the all files and sub files and sub folders of a folder as zip file
  def dwn_fld(folder_id,zipfile)
    @folder = Folder.find_by_id(folder_id,true)
    zipfile.mkdir("#{@folder.name}")
    recursive_function(folder_id,zipfile,"#{@folder.name}")
  end
  #To find the all files and sub files and sub folders of a folder
  def recursive_function(folder_id,zipfile,location)
    if @nav && @nav == 'edit'
      folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id])
      documents = Document.find(:all,:conditions=> ["folder_id = ? and is_deleted=false",folder_id])
    else
      folders = Folder.find(:all,:conditions=> ["parent_id = ? and is_deleted=false",folder_id])
      documents = Document.find(:all,:conditions=> ["folder_id = ? and is_deleted=false",folder_id])
    end
    folders.each do |f|
      zipfile.mkdir("#{location}/#{f.name}")
      recursive_function(f.id,zipfile,"#{location}/#{f.name}")
    end
    documents.each do |f|
      zipfile.add("#{location}/#{f.filename}","#{Rails.root.to_s}/public#{f.public_filename}")
    end
  end
  def find_folders_and_docs(folder_id)
    if @folder.parent_id == -1
      assign_options
    else
      folder_id = params[:move_folder_id] if params[:move_folder_id]
      @show_deleted = (params[:del_files] == 'true') ? true : false
      conditions =  @show_deleted == true ?   "" : "and is_deleted = false"
      @folders = Folder.find(:all,:conditions=>["parent_id = ? #{conditions}",folder_id])
      documents = Document.find(:all,:conditions=>["folder_id = ? #{conditions}",folder_id])
      @documents = documents.reject{|d|  d.document_name !=nil } #changed
      @document_names =  DocumentName.find(:all,:conditions=>["folder_id = ? #{conditions}",folder_id])
    end
  end
  def generate_loan_table(page,table_name)
    page << "yield_calender('true');jQuery('#{table_name}').html('<div class=loancontentrow style=padding-left:10px;><div class=collab_lightbox_contentrow style=width:716px;><div class=loan_tag> <div class=loancol>Loan #{@loan_form_number}</div> <a href=# id=deleteInfo onclick=delete_loan_form(#{@loan_form_number}) class=bluecolor><img border=0 width=7 height=7 src=/images/del_icon.png></a></div><div class=loan_headerow>Original Terms</div><div class=loan_fieldrow><div class=loanfieldcol style=width:150px;><div class=loan_fieldlabel>Loan Amount</div><div class=loan_fieldinput style=margin-left:-8px;>$ <input type=text  name=Loan_Amount[#{@number}] size=12 style=width:138px;></div></div><div class=loanfieldcol style=width:150px;><div class=loan_fieldlabel>Date of Promissory Note</div><div class=loan_fieldinput style=clear:none;><input type=text id=date_of_note_#{@number} size=12 readonly  name=Date_of_Promissory_Note[#{@number}] /><div class=loan_iconcoll ><a href=#></a></div></div></div><div class=loanfieldcol style=width:150px;><div class=loan_fieldlabel>Maturity</div><div class=loan_fieldinput style=clear:none;><input type=text size=12 readonly= value= name=Maturity[#{@number}] id=maturity_#{@number} /><div class=loan_iconcoll ><a href=#></a></div></div></div><div class=loanfieldcol style=width:150px;><div class=loan_fieldlabel> Interest Rate </div><div class=loan_fieldinput><input type=text  name=Interest_Rate[#{@number}] class=loan_fieldinput size=12 style=width:150px;></div></div><div class=loanfieldcol style=width:150px;clear:both;margin-left:7px;><div class=loan_fieldlabel> Lender</div><div class=loan_fieldinput><input type=text size=15 class=loan_fieldinput   name=Lender[#{@number}] style=width:138px;></div></div></div></div><div class=collab_lightbox_contentrow style=width:716px;><div class=loan_headerow>Loan Status &amp; Payments Due</div><div class=loan_fieldrow><div class=loanfieldcol style=width:150px;><div class=loan_fieldlabel>Loan Balance</div><div class=loan_fieldinput><input type=text size=12  name=Loan_Balance[#{@number}] style=width:138px;></div></div><div class=loanfieldcol style=width:150px;><div class=loan_fieldlabel> Term Remaining</div><div class=loan_fieldinput> <input type=text class=loan_fieldinput size=12 name=Term[#{@number}] style=width:138px;></div></div><div class=loanfieldcol style=width:150px;><div class=loan_fieldlabel> Payments</div><div class=loan_fieldinput><textarea class=loan_fieldinput cols=23 name=Payments[#{@number}] style=width:142px;></textarea></div></div><div class=loanfieldcol style=width:150px;><div class=loan_fieldlabel>Tax Escrow Payments</div><div class=loan_fieldinput><input type=text name=Tax_Escrow_Payments[#{@number}] style=width:150px;></div></div></div></div><div class=collab_lightbox_contentrow style=width:716px;><div class=loan_headerow>Other Details</div>    <div class=loan_fieldrow><div class=loanfieldcol style=width:350px;><div class=loan_fieldlabel>Prepayment </div><div class=loan_fieldinput><input type=text size=22 name=Prepayment[#{@number}] style=width:269px> </div></div><div class=loanfieldcol style=width:300px;><div class=loan_fieldlabel>Replacement Reserve </div><div class=loan_fieldinput><input type=text class=loan_fieldinput size=22 name=Replacement_Reserve[#{@number}] style=width:261px;></div></div><div class=loanfieldcol style=width:350px;><div class=loan_fieldlabel>Tenant Improvements &amp; Leasing Commission Reserve</div><div class=loan_fieldinput><textarea class=loan_fieldinput cols=35 name=Tenant_Improvements_and_Leasing_Commission_Reserve[#{@number}] style=width:267px;></textarea></div></div><div class=loanfieldcol style=width:300px;><div class=loan_fieldlabel>Guarantors</div><div class=loan_fieldinput><textarea class=loan_fieldinput cols=35 name=Guarantors[#{@number}] style=width:260px;></textarea></div></div></div></div></div>')";
  end

  #collects folders(properties) of a portfolio
  def assign_initial_options
    view_del_files = (params[:del_files] == 'true') ? true : false
    @show_deleted = view_del_files
    portfolio_id =params[:portfolio_id] ? params[:portfolio_id] : params[:pid]
    if !@real_estate_properties.nil? && !@real_estate_properties.empty?
      f_conditions = "portfolio_id = #{portfolio_id} and real_estate_property_id in (#{@real_estate_properties.collect{|y| y.id}.join(',')}) and parent_id = false and is_master=false"
    else
      f_conditions = "portfolio_id = #{portfolio_id} and parent_id = false and is_master=false #{RealEstateProperty.find_shared_clients(nil,portfolio_id)}"
    end
    f_conditions << " and is_deleted = #{view_del_files}" if view_del_files == false
    f_options = {:conditions => f_conditions}
    listing_folders(f_options)
  end

  def find_timeline_values
    @summary_page = true if !params[:tl_period].present?
    #@default_month_and_year = 45.days.ago
    @current_time_period = Date.new(Date.today.year,Date.today.month,1)
    if params[:tl_period].present?
      @period = params[:tl_period]
    else
      @period = params[:period] == "9" ? "9" : "4"
    end
   @period = Date.today.month == 1 ?  "5" : @period
    params[:period] =  @period
    #      @period = "4"
    #@set_prev_month = true
    @reset_selected_item = true
    @today_year = Date.today.year
    @time_line_start_date = Date.new(2010,1,1)
    @time_line_end_date = Date.new(@today_year,12,31)
    @time_line_actual = IncomeAndCashFlowDetail.find(:all,:conditions => ["resource_id =? and resource_type=? ",@note.id, 'RealEstateProperty'])
    @actual = @time_line_actual
    #common_financial_wres_swig(params,"swig")

    # if session[:wres_user]
    #@initial_val = true
    #wres_executive_overview_details(@default_month_and_year.month,@default_month_and_year.year)
    #else
    #~ if @period == "5"
      #~ executive_overview_details(Date.today.prev_month.month,Date.today.prev_month.year)
    #~ else
      #~ executive_overview_details_for_year if params[:partial_page] != "rent_roll_highlight"
    #~ end
    #executive_overview_details(@default_month_and_year.month,@default_month_and_year.year)
    #end
  end

  def display_collection_of_folders_docs_tasks
    @portfolio = Portfolio.find_portfolio(params[:pid])
    if params[:nid].present?
      @note = RealEstateProperty.find_real_estate_property(params[:nid])
      @folder=Folder.find(:first,:conditions=>['parent_id = ? and real_estate_property_id = ?',0,params[:nid]])
      #@folder=Folder.find(:first,:conditions=>['parent_id = ? and real_estate_property_id = ? and portfolio_id =?',0,params[:nid],@portfolio.id])
      assign_options(@folder.try(:id))
    else
      if(params[:show_past_shared] == "true")
        @folder = Folder.find_folder(@folder.parent_id) if @folder.parent_id!=0
        find_folder_to_update_page('folder',@folder) if @folder.user_id != current_user.id
        find_past_shared_folders('false')
      else
        @folder = Folder.find_folder(params[:folder_id])
        if params[:from_parent_folder] =='true' && !@folder.nil?
          pid = params[:portfolio_id] ? params[:portfolio_id]  :  params[:pid]
          portfolio_folder = Folder.find_by_portfolio_id_and_parent_id(pid,-1) if (params[:portfolio_id] || params[:pid] )
          @go_to_collab_hub = false
          until @folder && !is_folder_shared_to_current_user(@folder.id).nil? || @go_to_collab_hub == true || @folder && @folder.user_id == current_user.id
            if @folder
              if @folder.parent_id == 0 && portfolio_folder && is_folder_shared_to_current_user(@folder.id).nil? ||  (@folder.name == 'my_files' && @folder.parent_id == 0)
                @go_to_collab_hub = true
              end
              @folder = Folder.find_folder(@folder.parent_id) unless @folder.parent_id == 0
            end
          end
        end
        assign_options(@folder.id) if @folder
        assign_options if !@folder
      end
    end
    @property_image_path =  property_image(@note.id) if !@note.nil?
    if params[:move_folder_id]
      update_page_from_move_to
    elsif request.xhr? || params[:edit_from_room] || params[:user] == 'false'
      update_page_from_asset_files
    end
  end

  def create_sub_folders_wres_swig(property_folder,property,name,template)
    folder_excel = Folder.create_sub_folders(property_folder,property,name)
    store_excel_template(template,folder_excel)
  rescue Exception => e
    p "error creating folders:#{e.message}"
  end

  def action_and_title(from_debt_summary,from_property_details)
    name= from_debt_summary == "true" ? "Edit #{@folder.name}" : (from_property_details == "true" ? "Edit #{@folder.name}" : "Edit #{@folder.name}")
    title= from_debt_summary == "true" ? "Edit #{@folder.name}" : (from_property_details == "true" ? "Edit #{@folder.name}" : "Edit #{@folder.name}")
    action= ((from_property_details == "true" || from_debt_summary == "true") && @folder && @folder.user_id !=current_user.id ) ? "add_property" : "add_property"
    return name,title,action
  end

  def title_text_and_img_name(a)
    if a
      title_text = (a.parent_id == 0 && !a.is_master) ? (is_leasing_agent ? "Leasing Agents" : "Property Users") : "Collaborators"
      property_folder = (a.parent_id == 0 && !a.is_master) ? true : false
      img_name =  (a.parent_id == 0 && !a.is_master) ? "asset_manager_icon" :  "asset_folderow_addicon"
      return title_text,property_folder,img_name
    end
  end

  def show_or_hide_loan_details
    @val_emp,j,validation = [],0,[]
    @loan_hash.each do |l|
      if l
        a = l.values
        a.delete_if {|x| x.include?("\t") || x=="" || x==" "}
        validation << a
        vals = l.values
        val = vals.compact
        @val_emp[j] = val.all?{|x| x==""}
        j=j+1
      end
    end
    return validation
  end

  def find_graph_period(portfolio_collection)
    @note = RealEstateProperty.find_real_estate_property(params[:property_id]) if @note.nil? && params[:property_id]
    @graph_period = params[:period]  == "5" ? Date.today.prev_month.strftime("%Y-%m") : Date.today.strftime("%Y-%m")
    @hash_portfolio_occupancy = (@note && !(@note.leasing_type== "Multifamily")) ? hash_formation_for_portfolio_occupancy(@graph_period,true,portfolio_collection.id)  : wres_hash_formation_for_portfolio_occupancy(@graph_period,true,portfolio_collection.id)
    total_sqft = 0
    for i in @hash_portfolio_occupancy
      total_sqft = i.occupied.to_i + i.vaccant.to_i
      @vaccant = i.vaccant.to_f
      @occupied = i.occupied.to_f
    end
    @occupied_percent = ((@occupied * 100) / (@occupied + @vaccant)).round rescue ZeroDivisionError
    @vaccant_percent = 100 - @occupied_percent   if !(@occupied.nil? || @occupied.blank? || @occupied == 0)
    return total_sqft
  end

  def portfolio_leasing_type(id)
    leasingtype = Portfolio.find(id).leasing_type
    return leasingtype
  end
  def current_user
    if params[:user] == 'false'
      @current_user = Portfolio.find(params[:pid]).user
    else
      @current_user ||= (login_from_session || login_from_basic_auth || login_from_cookie) unless @current_user == false
    end
  end

  #to display loan details in debt summary
  def loan_details
    @note = params[:property_id] ?  RealEstateProperty.find_real_estate_property(params[:property_id]) : RealEstateProperty.find_real_estate_property(params[:id])
    @property = @note
    @portfolio = Portfolio.find_by_id(@note.portfolio_id)
    @folder = Folder.find_by_portfolio_id_and_real_estate_property_id_and_parent_id_and_is_master(@portfolio.id,@property.id,0,0) if @property && @portfolio
    if(params[:basic_form_close] == "true" ||  params[:prop_form_close] == "true" ||  params[:variances_form_close]  ||  params[:users_form_close]  || params[:users_mail_close]  )
      @add_loan_details,@edit_loan_details = false,false
    end
    form_hash_for_loan_details
    if params[:from_debt_summary] == 'true' && (params[:loan_form_close] == "true" || params[:basic_form_close] == "true" ||  params[:prop_form_close] == "true" || params[:variances_form_close] == "true" || params[:users_mail_form_close] == "true" )
      responds_to_parent do
        render :update do |page|
          update_page_after_adding_physical_details(page,"/properties/loan_details","note_terms")
        end
      end
    elsif params[:from_debt_summary] == 'true'
      render :update do |page|
        update_page_after_adding_physical_details(page,"/properties/loan_details","note_terms")
      end
    else request.xhr?
      render :update do |page|
        #~ page.replace_html "head_for_titles", :partial => "/properties/head_for_titles/",:locals =>{:portfolio_collection => @portfolio,
#~ :note_collection => @note}
        #~ page.call "active_title","note_terms"
        page.replace_html "show_assets_list", :partial => "loan_details"
      end
    end
  end


  def find_uploaded_property_pictures
    @pictures = PortfolioImage.find_all_by_attachable_id_and_attachable_type_and_is_property_picture(@property.id,"RealEstateProperty",true)
  end

  def suites_build_and_collection(property)
    @new_suite = property.suites.new
    @suites_collection = property.suites
  end

  def find_suite_and_collection(suite_id, property)
    @new_suite = Suite.find_by_id(suite_id)
    @suites_collection = property.suites
  end

  #To send Weekly Alert mail in Settings >Alert Tab#
  def send_weekly_alert_mail
    @note = params[:property_id] ?  RealEstateProperty.find_real_estate_property(params[:property_id]) : RealEstateProperty.find_real_estate_property(params[:id])
    @property = @note
    if params[:selected_users] && !params[:selected_users].empty?
       @property.no_validation_needed ='true'
       @property.update_attributes(:alert_users=>params[:selected_users].keys.join(',').to_s)
     else
       @property.no_validation_needed ='true'
       @property.update_attributes(:alert_users=>'')
     end
      @property.save
  end

  def send_weekly_alerts
    @commercial_properties = RealEstateProperty.where(:leasing_type => "Commercial")
    @commercial_properties.each do |commercial_property|
      @note =  commercial_property.id
      @property = @note
      #@portfolio = Portfolio.find_by_id(@note.portfolio_id)
      @lease,@option,@insr,@t_imp = [],[],[],[]
      find_month_for_alert_view
      @months.each do |val|
        find_alerts_for_month(val, commercial_property.id)
        @lease << @find_lease.uniq if @find_lease.present?
        @option << @find_option.uniq if @find_option.present?
        #~ @insr << @find_insurance.uniq if @find_insurance.present?
        @insr << @find_insurance if @find_insurance.present?
        @t_imp << @find_tmp.uniq if @find_tmp.present?
      end
      current_user = commercial_property.user
      #~ @members=SharedFolder.find(:all,:conditions=>["real_estate_property_id = ? and user_id!= ?",commercial_property.try(:id) ,current_user.id]).collect{|sf| sf.user}.compact.uniq
      UserMailer.send_alert_to_property_users(current_user,commercial_property.property_name,@note).deliver
      commercial_property.alert_users.present? && commercial_property.alert_users.split(",").each do |user|
          property_user = User.find(user)
        if !property_user.has_role?("Leasing Agent")
          UserMailer.send_alert_to_property_users(property_user,commercial_property.property_name,@note).deliver
          end
        end
      end
  end

  def alert_users_for_property(user_email,note)
       @existing_user = []
       @existing_user << note.alert_users if note.alert_users.present?
        user_email.present? && user_email.each do |mail|
        find_user = User.find_by_email(mail).id
        @existing_user << find_user
        note.no_validation_needed ='true'
        note.update_attributes(:alert_users=>@existing_user.join(',').to_s) if @existing_user.present?
    end
  end

  #find the property users for a property to display in Alerts#
  def find_users_to_send_weekly_report(note)
    @members  = SharedFolder.find(:all,:conditions=>["real_estate_property_id = ? and user_id!= ?",note.id ,current_user.id]).collect{|sf| sf.user}.compact.uniq
    @data,@mem_list= '','',[]
    if !@members.blank?
      @members << note.user  if note && note.user != current_user
      alert_prop_users = note.alert_users.split(',') if note.alert_users
      for user in @members.uniq
        if !user.has_role?("Leasing Agent")
          @mem_list = @mem_list.to_s + user.email.to_s + "," if user && user.email
          @data = @data + "<div><div class='adduser-alert'><div style='float:left;'><input type ='checkbox' name='selected_users[#{user.id}]' value='#{user.email}' #{(!alert_prop_users.nil? && !alert_prop_users.index(user.id.to_s).nil?) ? 'checked' : ''}/></div><div id='#{user.email}'><div class='collaboraterow'><div class='collaboratername'>#{(user.name?) ?  "#{lengthy_word_simplification(user.name,7,5)}" : user.email.split('@')[0]}</div><div class='collaborateremail'>#{lengthy_word_simplification(user.email,30,5)}</div></div></div></div></div>" if user && user.email
        end
      end
    end
  end
end
