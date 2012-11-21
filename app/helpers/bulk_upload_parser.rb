# AMP .
# Stuff to parse the bulk upload excel files for the real page account types.
# and open the template in the editor.
module BulkUploadParser

  # Parse the weekly upload file.
  # Check whether the file should be uploaded to the sub folders of "Bulk Uploads" folder.
  def parse_weekly_osr_files(tmp_doc,user_id)
    parent_folder = Folder.find_by_id(tmp_doc.folder_id)
    gr_parent_folder = Folder.find_by_id(parent_folder.parent_id) if !parent_folder.nil?
    gr_gr_parent_folder = Folder.find_by_id(gr_parent_folder.parent_id) if !gr_parent_folder.nil?
    sql = ActiveRecord::Base.connection();
    tm_doc = "#{Rails.root.to_s}/public"+ tmp_doc.public_filename
    tm_xml=tm_doc.split('.')
    tm_xml.pop
    tm_xml=(tm_xml*".")+".xml"
    if !gr_gr_parent_folder.nil?
      if gr_gr_parent_folder.name == "Bulk Uploads"
        if tmp_doc.filename.downcase.include?("occupancy_status")
          tmp_doc.update_attribute('parsing_done',nil)
          #initiate_amp_parser(tmp_doc)
          Delayed::Job.enqueue DelayedParsing.new(tm_doc, tm_xml, tmp_doc.id,"OSR,weekly",user_id)
          #ParsingLog.create(:client_id=>current_client_id,:document_id=>tmp_doc.id, :user_id=>tmp_doc.user_id, :real_estate_property_id=>tmp_doc.real_estate_property_id,:path=>gr_gr_parent_folder.name+ '/' +gr_parent_folder.name + '/' +parent_folder.name )
        end
      end
    end
  end

  def store_weekly_osr_files
    doc = Document.find_by_id(@options[:doc_id])
    real_estate_property = []
    @store_details_array = []
    pcb = year = nil
    get_all_sheets.each do |sheet|
      if find_sheet_name(sheet).downcase == 'sheet3' # Parse only the sheet3 named sheet
        real_estate_properties = RealEstateProperty.where("user_id = #{doc.user_id} and property_name not in('property_created_by_system','property_created_by_system_for_deal_room','property_created_by_system_for_bulk_upload')").select('property_name,id') + RealEstateProperty.find_by_sql("select rp.property_name, rp.id from shared_folders sf left join real_estate_properties rp on rp.id = sf.real_estate_property_id and rp.accounting_system_type_id = 4  where sf.user_id =#{doc.user_id} and sf.is_property_folder = true")
        2.upto find_last_base_cell(sheet) do |row|
          next if read_via_numeral_abs(row, 1, sheet).blank? or read_via_numeral_abs(row, 1, sheet).include? "Owner" # blank will not be parsed
          if !read_via_numeral_abs(row, 1, sheet).blank? and !read_via_numeral_abs(row, 2, sheet).blank? and !read_via_numeral_abs(row, 3, sheet).blank?
            real_estate_property = real_estate_properties.select {|i|i.property_name == read_via_numeral_abs(row, 3, sheet) }.first rescue nil
            unless real_estate_property.blank?
              obj = PropertyWeeklyOsr.find_or_initialize_by_real_estate_property_id_and_floor_plan_and_time_period(real_estate_property.id, read_via_numeral_abs(row, 4, sheet),read_via_numeral_abs(row, 22, sheet))
              obj.owner = read_via_numeral_abs(row, 1, sheet)
              obj.regional_manager = read_via_numeral_abs(row, 2, sheet)
              obj.user_id = doc.user_id
              obj.units = read_via_numeral_abs(row, 5, sheet)
              obj.vacant_total = read_via_numeral_abs(row, 6, sheet)
              obj.prelsd = read_via_numeral_abs(row, 7, sheet)
              obj.ntv_status_total = read_via_numeral_abs(row, 8, sheet)
              obj.prelsd2 = read_via_numeral_abs(row, 9, sheet)
              obj.rtr = read_via_numeral_abs(row, 10, sheet)
              obj.max_rent = read_via_numeral_abs(row, 11, sheet)
              obj.min_rent = read_via_numeral_abs(row, 12, sheet)
              obj.current = read_via_numeral_abs(row, 13, sheet)
              obj.wk1 = read_via_numeral_abs(row, 14, sheet)
              obj.wk4 = read_via_numeral_abs(row, 15, sheet)
              obj.pi_total = read_via_numeral_abs(row, 16, sheet)
              obj.wi_total = read_via_numeral_abs(row, 17, sheet)
              obj.dep_total = read_via_numeral_abs(row, 18, sheet)
              obj.dep_rej = read_via_numeral_abs(row, 19, sheet)
              obj.dep_canc = read_via_numeral_abs(row, 20, sheet)
              obj.preleased_status = read_via_numeral_abs(row, 21, sheet)
              obj.save(false)
              # income_detail = IncomeAndCashFlowDetail.procedure_call(:titleIn=>read_via_numeral_abs(row, 3, sheet),:realIn=>real_estate_property_id, :realTypeIn=>"RealEstateProperty",:parentIn=>headers.count.zero? ? 'NULL' : headers.last,:userIn=>doc.user_id, :yearIn=>year)
            end
          end
        end
      end
    end
  end

end
