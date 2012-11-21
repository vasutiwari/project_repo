class XmlExtractor
  include WresParsingHelper
  include SwigParsingHelper
  include PropertiesHelper
  include AmpParsingHelper
  include BulkUploadParser
  include YardiParser

  def initialize(*args)
    @options = args.extract_options!
    @options[:current_user] ||= nil
    @options[:month] ||= Date.today.month
    @options[:year] ||= Date.today.year
    @options[:uploaded_date] ||= Time.now
    @options[:real_estate_id] ||= nil
    @options[:validator] ||= 'WRES'
    @months = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
  end

  def xls_file=(input_filepath)
    @xls_file = input_filepath
  end

  def output_file=(output_filepath)
    @out_file = output_filepath
  end

  def xml_dump
    begin
      time1=Time.now
      system("python lib/python_xls_to_xml/xlstoxml.py #{@xls_file} #{@out_file}")
      Delayed::Worker.logger.info "XLS to XML conversion took #{Time.now-time1} s" if Rails.env=="production"
    rescue
      puts "Issues with XML file creation has occurred"
    end
    @base_cells = {}
    reader = Nokogiri::XML::Reader(IO.read(@out_file))
    sheet_index=0
    reader.each do |node|
      if node.name == 'sheet_name' and node.node_type==1
        sheet_index+=1
        @base_cells["#{sheet_index}"]={"sheet"=>{"name"=>node.read.value, "last_row"=>node.attribute('last_row')}} unless @base_cells.member?(node.attribute('row'))
      end
      if node.name == 'columns' and node.node_type==1
        @base_cells["#{sheet_index}"]["sheet"]["last_column"]=node.attribute('last_column')
      end
      if node.name == 'cell' and node.node_type==1
        @base_cells["#{sheet_index}"][node.attribute('row')] = Hash.new unless @base_cells["#{sheet_index}"].member?(node.attribute('row'))
        @base_cells["#{sheet_index}"][node.attribute('row')].update({"#{node.attribute('column_alpha')}"=>node.read.value.try(:squish)})
      end
    end
  end

  def process!(opts="",user="")
    upload_type=opts.split(',')
    @cur_parse_type = upload_type.first
    @cur_file_type = upload_type.last
    if(upload_type.first=='MRI' && upload_type.last=='rent roll') || (upload_type.first=='SWIG' && upload_type.last=='rent')
      mri_parse_rent_roll
    elsif upload_type.first=='WRES'
      wres_12_month_parsing if upload_type.last=='budget'
      wres_actual_budget_analysis_parsing if upload_type.last=='actual'
      wres_all_units_parsing if upload_type.last=='leases'
    elsif upload_type.first=='SWIG'
      store_new_income_and_cash_flow_version if upload_type.last=='budget'
      store_new_occupancy_leasing if upload_type.last=='leases'
      store_new_debt_summary if upload_type.last=='debt'
      swig_parse_rent_roll if upload_type.last=='rent'
      extract_aged_receivables if upload_type.last=='aged'
#      extract_capital_improvement if upload_type.last=='capital'
      extract_capital_improvement_new if upload_type.last=='capital'
    elsif upload_type.first == 'AMP'
      amp_parsing_financials if upload_type.last=='financials'
      amp_extract_capital_improvement if upload_type.last == 'capital'
      swig_parse_rent_roll if upload_type.last == 'rent'
      store_new_occupancy_leasing if upload_type.last == 'occupancy'
      wres_all_units_parsing if upload_type.last=='leases'
      amp_aged_receivables if upload_type.last=='aged'
    elsif upload_type.first == 'OSR'
      store_weekly_osr_files if upload_type.last=='weekly'
    elsif upload_type.first == 'YARDI'
      store_yardi_rent_roll_files if upload_type.last=='rent'
      store_yardi_summary_files if upload_type.last=='summary'
    end
  end

  def read_via_alpha(row, col, sheet="1")
    return nil unless @base_cells["#{sheet}"].member?("#{row}")
    if col == 'A'
      convert_title_val(@base_cells["#{sheet}"]["#{row}"][col])
    else
      wres_store_value_for_income_and_cash_flow(@base_cells["#{sheet}"]["#{row}"][col])
    end
  end

  def get_as_date(row, col, sheet="1")
    return nil unless @base_cells["#{sheet}"].member?("#{row}")
    @base_cells["#{sheet}"]["#{row}"][col]
  end

  def read_via_numeral(row, col, sheet="1")
    return nil unless @base_cells["#{sheet}"].member?("#{row}")
    hit_col = get_hits(col)
    chk = @cur_parse_type == 'SWIG' ? ["A","B","C"] : ["A"]
    if chk.member? hit_col
      if @cur_parse_type=="SWIG" && @cur_file_type=="budget"
        @base_cells["#{sheet}"]["#{row}"][hit_col].nil? ? nil : (((@base_cells["#{sheet}"]["#{row}"][hit_col].scan(".").length!=1 && @base_cells["#{sheet}"]["#{row}"][hit_col].to_date) rescue false) ? nil : convert_title_val(@base_cells["#{sheet}"]["#{row}"][hit_col]))
      else
        @base_cells["#{sheet}"]["#{row}"][hit_col].nil? ? nil : (@cur_file_type == 'debt' ? convert_title_val_debt(@base_cells["#{sheet}"]["#{row}"][hit_col]) :  convert_title_val(@base_cells["#{sheet}"]["#{row}"][hit_col]))
      end
    else
      @base_cells["#{sheet}"]["#{row}"][hit_col].nil? ? nil : wres_store_value_for_income_and_cash_flow(@base_cells["#{sheet}"]["#{row}"][hit_col])
    end
  end

  def read_via_numeral_abs(row, col, sheet="1")
    return nil unless @base_cells["#{sheet}"].member?("#{row}")
    hit_col = get_hits(col)
    @base_cells["#{sheet}"]["#{row}"][hit_col].nil? ? nil : @base_cells["#{sheet}"]["#{row}"][hit_col]
  end

  def get_hits(ind)
    alpha = ["", "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
    if ind<=26
      return alpha[ind]
    else
      return (alpha[ind/26]+alpha[ind%26])
    end
  end

  def date_fetch(row, col, sheet="1")
    begin
      @base_cells["#{sheet}"]["#{row}"][col].to_date
      :date
    rescue
      :false
    end
  end

  def find_last_base_cell(sheet="1")
    @base_cells["#{sheet}"]['sheet']['last_row'].to_i!=0 ? @base_cells["#{sheet}"]['sheet']['last_row'].to_i : @base_cells["#{sheet}"].keys.map{|x| x.to_i}.max
  end

  def find_number_for_alpha(alpha)
    alpha_hash={"V"=>22, "K"=>11, "W"=>23, "L"=>12, "A"=>1, "X"=>24, "M"=>13, "B"=>2, "Y"=>25, "N"=>14, "C"=>3, "Z"=>26, "O"=>15, "D"=>4, "P"=>16, "E"=>5, "Q"=>17, "F"=>6, "R"=>18, "G"=>7, "S"=>19, "H"=>8, "T"=>20, "I"=>9, "U"=>21, "J"=>10}
    if alpha.length==1
      alpha_hash[alpha]
    else
      alpha_arr=alpha.split('')
      ((alpha_hash[alpha_arr[0]]*26)+alpha_hash[alpha_arr[1]])
    end
  end

  def find_last_column(sheet="1")
    last_col_alpha=@base_cells["#{sheet}"].values.map(&:keys).flatten.uniq.reject!{|x| ["last_column","last_row","name"].include?(x)}
    last_col_alpha=last_col_alpha.select{|x| x.length==1}.sort+last_col_alpha.select{|x| x.length==2}.sort
    @base_cells["#{sheet}"]['sheet']['last_column'].to_i!=0 ? @base_cells["#{sheet}"]['sheet']['last_column'].to_i : find_number_for_alpha(last_col_alpha.last)
  end

  def get_real_estate_id
    @options[:real_estate_id]
  end

  def position_for_pcb_swig(pcb)
    ["","p","c","b"].index(pcb)
  end

  def get_all_sheets
    @base_cells.keys
  end

  def find_sheet_name(sheet="1")
    @base_cells["#{sheet}"]['sheet']['name']
  end

  def convert_base_cell_val(val)
		return nil if val.blank?
    val = val.delete 194.chr+160.chr
    val.downcase.strip.gsub(/  /,' ')
  end

  def fetch_base_cell_titles
    if @cur_parse_type=="WRES"
      @base_cells.values.map{|x| x.values.map{|x| convert_base_cell_val(x["A"])}}.flatten.compact
    elsif @cur_parse_type=="SWIG"
      if @cur_file_type == 'capital'
        @base_cells.values.map{|x| x.values.map{|x| x["B"] }}.flatten.compact
      else
        @base_cells.values.map{|x| x.values.map{|x| [convert_base_cell_val(x["B"]),convert_base_cell_val(x["C"])]}}.flatten.compact
      end
    elsif @cur_parse_type=="AMP"
      if @cur_file_type == 'capital'
        @base_cells.values.map{|x| x.values.map{|x| x["E"] }}.flatten.compact
      else
        @base_cells.values.map{|x| x.values.map{|x| x["C"] }}.flatten.compact
      end
    end
  end

end
