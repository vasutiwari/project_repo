module LeaseHelper

  def generate_option_table(page,table_name)
    page << "yield_calender('true');jQuery('#{table_name}').html(\"<div class='lsrowwrapper'>Options &#8250; Option #{@option_section_number}<div class='loan_tag'><div class='loancol'>Option <%=i+1%></div><a href='javascript:;' id='deleteInfo' onclick=delete_option_form(#{@option_section_number}) class='bluecolor'><img src='/images/del_icon.png' width='7' height='7' border='0' /></a></div></div><div class='termsnamerow'><div class='termsname namefirst' style='margin-left:5px; width:100px; text-align:left;'>Option Type</div><div class='termsform' style='padding-left:5px;'><select name='select' class='lsselect' style='width:113px; text-align:left;'><option>Renewal</option><option>Contraction</option><option>Termination</option><option>Right of First Refusal</option><option>Expansion</option><option>Right of First Offer</option><option>Exclusive Use</option><option>Assignment, Subletting</option><option>Early Possession</option><option>Right of First Purchase</option><option>Other</option></select></div><div class='termsname' style='width:111px; text-align:left; margin-left:37px'>Option Start</div><div class='termsform' style='padding-left:5px;'><input type='text' name='Date_of_Promissory_Note_4'  class='lstextfield inputtext_for_datepicker date-pick dp-applied loan_fieldinput'  style='width:91px' value = '' readonly size='12'  /></div><div class='termsname' style='width:111px; text-align:left; margin-left:37px'>Option End</div><div class='termsform' style='padding-left:5px;'><input type='text' name='Date_of_Promissory_Note_4'  class='lstextfield inputtext_for_datepicker date-pick dp-applied loan_fieldinput'  style='width:91px' value = '' readonly size='12'  /> </div></div><div class='termsnamerow'><div class='termsname namefirst' style='margin-left:5px; width:100px; text-align:left;'>L. Para</div><div class='termsform' style='padding-left:5px;'><input name='input4' type='text' class='lstextfield' style='width:111px' value='enter comma separated' /></div><div class='termsname' style='width:111px; text-align:left; margin-left:37px'>Notice Start</div><div class='terms m' style='padding-left:5px;'><input type='text' name='Date_of_Promissory_Note_4'  class='lstextfield inputtext_for_datepicker date-pick dp-applied loan_fieldinput'  style='width:91px' value = '' readonly size='12'  /> </div><div class='termsname' style='width:111px; text-align:left; margin-left:37px'>Notice End</div><div class='termsform' style='padding-left:5px;'><input type='text' name='Date_of_Promissory_Note_4'  class='lstextfield inputtext_for_datepicker date-pick dp-applied loan_fieldinput'  style='width:91px' value = '' readonly size='12'  /></div></div><div class='termsnamerow'><div class='termsname namefirst' style='margin-left:5px; width:100px; text-align:left;'>Encumbered Floors</div><div class='termsform' style='padding-left:5px;'><input name='input' type='text' class='lstextfield' style='width:111px' value='enter comma separated' /></div><div class='termsname' style='width:111px; text-align:left; margin-left:37px'>Encumbered Suites</div><div class='termsform' style='padding-left:5px;'><input name='input' type='text' class='lstextfield' style='width:111px' value='enter comma separated' /></div></div><div class='termsnamerow'><div class='termsname namefirst' style='width:100px; text-align:left'>Notes</div><div class='termsform' style='padding-left:5px;'><textarea name='textarea1' rows='3' cols='27'  style='width:643px;' class='expand taskfieldinput2'>Edit this text to see the text area expand and contract.</textarea></div></div>\")";
  end

  def encumb_suite_no_display(suite_ids)
    @suite_no_arr = []
    suite_ids.each do |suiteid|
      suite_collection = Suite.find_by_id(suiteid)
      @suite_no_arr << suite_collection.suite_no if suite_collection.present?
    end
    @suite_no_join = @suite_no_arr.join(',')
  end

  def find_executed_lease_count(property_id)
    executed_leases =  Lease.joins(:tenant => :options ).where("leases.real_estate_property_id=? and leases.is_executed=true and leases.is_archived=false and ((options.encumbered_suites is not NULL and options.encumbered_suites!='') or (options.encumbered_floors is not NULL and options.encumbered_floors!=''))",property_id).order("CAST(options.encumbered_suites AS SIGNED)ASC")
    #executed_leases =  Lease.joins(:tenant => :options ).where("leases.real_estate_property_id=? and leases.is_executed=true and leases.is_archived=false and options.encumbered_suites is not NULL and options.encumbered_suites!=''",property_id).order("CAST(options.encumbered_suites AS SIGNED)ASC")
    executed_leases = executed_leases.uniq
    tenant_name=[]
    @suite_no_arr = []
    executed_leases.each do |lease|
      if !lease.property_lease_suite.nil? && lease.property_lease_suite.suite_ids.present?
        suite_ids = lease.property_lease_suite.suite_ids
        suite_ids.each do |suiteid|
          suite_collection = Suite.find_by_id(suiteid)
          @suite_no_arr << suite_collection.rentable_sqft if suite_collection.present? && suite_collection.rentable_sqft.present?
        end
      end
      tenant_name<<lease.tenant.tenant_legal_name if lease.tenant.present?
		end
		sum = 0
		@suite_rentable_sqft_total = @suite_no_arr.inject{|sum,x| sum + x }
		if @suite_rentable_sqft_total.nil?
			@suite_rentable_sqft_total = 0
		end
		@tenant_legal_name_count = tenant_name.count
	end

def encumbrance_details(property_id,paramsort)
	#@leases =  Lease.joins(:tenant => :options ).where("leases.real_estate_property_id=? and leases.is_executed=true and leases.is_archived=false and options.encumbered_suites is not NULL and options.encumbered_suites!=''",property_id).order("CAST(options.encumbered_suites AS SIGNED)ASC")
	@leases =  Lease.joins(:tenant => :options ).where("leases.real_estate_property_id=? and leases.is_executed=true and leases.is_archived=false and ((options.encumbered_suites is not NULL and options.encumbered_suites!='') or (options.encumbered_floors is not NULL and options.encumbered_floors!=''))",property_id).order("CAST(options.encumbered_suites AS SIGNED)ASC")
  @executed_leases = @leases.uniq.paginate(:per_page=>25,:page=>params[:page])
	if paramsort == "Tenant"
		@executed_leases.sort! do |a,b|
			b.tenant.tenant_legal_name <=> a.tenant.tenant_legal_name
		end
	#~ elsif paramsort == "Suite"
		#~ @executed_leases.sort! do |a,b|
			#~ b.property_lease_suite.suite_ids <=> a.property_lease_suite.suite_ids
		#~ end
	#~ else
		#~ if paramsort == "Encumb_flr_sf"
			#~ @executed_leases.each do |exec_lease|
				#~ @tenant_options = exec_lease.tenant.options
				#~ @tenant_options.sort! do |a,b|
					#~ b.encumbered_floors <=> a.encumbered_floors
				#~ end
			#~ end
		#~ else
			#~ @tenant_options = []
				#~ @executed_leases.each do |exec_lease|
					#~ @tenant_options << exec_lease.tenant.options
				#~ end
				#~ @tenant_options = @tenant_options.flatten
		#~ end
	end
end



def encumbrance_sort_link_helper_for_rent_roll(text, parameter, options)
		update = options.delete(:update)
    action = options.delete(:action)
    controller = options.delete(:controller)
		page = options.delete(:page)
    per_page = options.delete(:per_page)
    id = options.delete(:property_id)
		partial_page = options.delete(:partial_page)
		portfolio_id = options.delete(:portfolio_id)
    key = parameter
    key += " DESC" if params[:sort] == parameter
    key += " ASC" if params[:sort] == "nil"
		order = " DESC" if params[:sort] == parameter
    order = " ASC" if params[:sort] == "nil"
    link_to(text,
    {:controller=>controller,:action =>action,:sort => key, :partial_page => partial_page,:property_id => id,:portfolio_id => portfolio_id, :page => page ,:per_page => per_page,:order => order},
      :update => update,
      :loading =>"load_writter();",
      :complete => "load_completer();", :remote=>true
    )
end

#moving options_and_ti method to application_helper#

def tenant_improvement(lease)
	string1 = ""
	tenant_impr_collection = lease.cap_ex.tenant_improvements if (lease && lease.cap_ex)
	unless tenant_impr_collection.blank?
	tenant_impr_collection.each do |ti|
		string1 << "#{ti.work_start_date.nil? ? '' : 'TI: Work start'} #{(ti && ti.work_start_date) ? ti.work_start_date.strftime('%m/%y') : ''}#{ (ti.try(:work_start_date) && ti != tenant_impr_collection.last) ? ', ' : '' }"
	end
	end
	return string1
end

def insurance(lease)
	string2 = ""
  @string1 = ""
	insurance_docs = lease.insurance.documents if lease && lease.insurance.present?
  if insurance_docs.present?
    insurance_docs.each do |ins_doc|
      if ins_doc && !ins_doc.filename.nil? && !ins_doc.filename.blank? && !ins_doc.expiration_date.nil? && !ins_doc.expiration_date.blank?
        string2 += "Insur: #{truncate(ins_doc.filename,:length=>7)}, #{ins_doc.expiration_date.strftime('%m/%y')} "
         @string1 += "Insur: #{ins_doc.filename}, #{ins_doc.expiration_date.strftime('%m/%y')} "
      end
    end
  end
	return string2
end
#for insurance start
def find_insur_group_items
	@group_items = Group.find(:all)
end
#for insurance end
#for lease docs start
def lease_docs(foldercollection,propid,leaseid)
	@lease_docs = Document.find_all_by_real_estate_property_id_and_folder_id_and_lease_id(propid,foldercollection.try(:id),leaseid)
end
#for lease docs end
#for suite start
def find_suite_all(propid)
	suite_data_collection = Suite.find(:all,:conditions=>["real_estate_property_id =?",propid],:order => "CAST(suite_no AS SIGNED) ASC" )
	@suite_data = suite_data_collection.paginate(:per_page=>25,:page=>params[:page])
end
def find_vacant_suite(propid,suite_filter)
	suite_data_collection = Suite.find(:all,:conditions=>["real_estate_property_id =? and status =?",propid,suite_filter],:order => "CAST(suite_no AS SIGNED) ASC")
	@suite_data = suite_data_collection.paginate(:per_page=>25,:page=>params[:page])
end
def find_floor_suite_total(propid)
	#~ @floor_count = Suite.where("floor is not null and real_estate_property_id=?",propid).count
  @floor_count = Suite.where("floor is not null and real_estate_property_id=? and floor!=?",propid,"").map(&:floor).uniq.count
	@suite_count = Suite.where("suite_no is not null and real_estate_property_id=?",propid).count
	suite_properties = Suite.where("suite_no is not null and real_estate_property_id=?",propid)
	@rentable_sqft_total = suite_properties.sum(:rentable_sqft)
end
def find_floor_suite_count(propid,suite_filter)
	@floor_count = Suite.where("floor is not null and real_estate_property_id=? and status =? and floor!=?",propid,suite_filter,"").map(&:floor).uniq.count
	@suite_count = Suite.where("suite_no is not null and real_estate_property_id=? and status =?",propid,suite_filter).count
	suite_properties = Suite.where("suite_no is not null and real_estate_property_id=? and status =?",propid,suite_filter)
	@rentable_sqft_total = suite_properties.sum(:rentable_sqft)
end
#for suite end


#to replace the navigation bar while changing portfolio
def  replace_navigation_bar(page,portfolio,note)
  if params[:change_portfolio] == 'true'
    @notes = RealEstateProperty.find_owned_and_shared_properties(portfolio,current_user.id,true)
    	find_portfolio_fol_doc_task(portfolio)
			page['mycarousel'].replace :partial => '/properties/filtered_properties',:locals =>{:portfolio_collection =>portfolio,:note_collection =>note,:notes_collection =>@notes}
		  page << "jQuery('#property_count').html('#{property_count(@portfolio_prop.count)}');"
      page.replace_html  "selected_portfolio", :partial => "/lease/selected_portfolio",:locals =>{:portfolio_collection =>portfolio,:note_collection =>note,:notes_collection =>@notes}
   end
 end

def link_to_add_fields(name, f, association,tmp_type,selected_suite_no = nil,selected_suite_id = nil)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, "add_fields(\"#{tmp_type}\",this, \"#{association}\", \"#{escape_javascript(fields)}\", \"#{selected_suite_no}\", \"#{selected_suite_id}\")", :id => "Rent_Schedule_id")
  end

def link_to_add_fields_new(name, f, association,tmp_type,selected_suite_no = nil,selected_suite_id = nil)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render("new_"+association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, "add_fields(\"#{tmp_type}\",this, \"#{association}\", \"#{escape_javascript(fields)}\", \"#{selected_suite_no}\", \"#{selected_suite_id}\")", :id => "Rent_Schedule_id")
  end

		#for cap_ex_other_exp_items start
	def link_to_add_option_for_other_exp(name, f, association,tmp_type)
    new_object = f.object.class.reflect_on_association(association).klass.new
		new_note = new_object.build_note
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, "add_item_other_exp(\"#{tmp_type}\",this, \"#{association}\", \"#{escape_javascript(fields)}\")")
  end
	#for cap_ex_other_exp_items end
	#for cap_ex_tenant_improvement_items start
	def link_to_add_option_for_tenant_improvement(name, f, association,tmp_type)
    new_object = f.object.class.reflect_on_association(association).klass.new
		new_note = new_object.build_note
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, "add_item_tenant_improvement(\"#{tmp_type}\",this, \"#{association}\", \"#{escape_javascript(fields)}\")")
  end
	#for cap_ex_tenant_improvement_items end
	#for insurance docs start
	def link_to_attach_copies(name, f, association,tmp_type)
    new_object = f.object.class.reflect_on_association(association).klass.new
    new_note = new_object.build_note
		#~ new_object.documents.build
		fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, "add_attachment_for_insurance(\"#{tmp_type}\",this, \"#{association}\", \"#{escape_javascript(fields)}\")")
  end
	#for insurance docs end

def link_to_add_service_fields(name, f, association,tmp_type,index)
	  new_object = f.object.class.reflect_on_association(association).klass.new
		new_note = new_object.build_note
		fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder, :@index => index)
    end
    link_to_function(name, "add_service_fields(\"#{tmp_type}\",this, \"#{association}\", \"#{escape_javascript(fields)}\")")
  end

def link_to_remove_service_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_service_fields(this)")
  end

  #for close add items for capex start
  def link_to_remove_tenant_improvement_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_tenant_improvement_fields(this)")
  end
  def link_to_remove_other_exp_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_other_exp_fields(this)")
  end
  #for close add items for capex end

  #for insurance attach files remove start
  def link_to_remove_insurance_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_insurance_fields(this)")
  end
  #for insurance attach files remove end

  def link_to_remove_recovery_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_recovery_fields(this)")
  end

  def link_to_remove_sch_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_sch_fields(this)")
  end

  def link_to_remove_sales_rent_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_sales_fields(this)")
  end
  def link_to_remove_parking_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_parking_fields(this)")
  end
  def link_to_remove_other_rev_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_other_rev_fields(this)")
  end
  def link_to_remove_option_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_option_fields(this)")
  end

def link_to_add_item_fields(name, f, association,tmp_type,index)
    new_object = f.object.class.reflect_on_association(association).klass.new
		#new_note = new_object.build_note
		fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder, :@index => index)
    end
    link_to_function(name, "add_item_fields(\"#{tmp_type}\",this, \"#{association}\", \"#{escape_javascript(fields)}\")")
  end

def vac_suite_calcs(propid)
	suite_c = Suite.where("suite_no is not null and real_estate_property_id IN (?) and status =?",propid,'vacant')
	suite_properties = Suite.where("suite_no is not null and real_estate_property_id IN (?)",propid)
	vac_rentable_sqft_total = suite_c.sum(:rentable_sqft)
  suite_all_sqft = suite_properties.sum(:rentable_sqft)
  percentagee = (suite_all_sqft.present? && suite_all_sqft!= 0.0) ? (vac_rentable_sqft_total * 100 ) / suite_all_sqft : 0
  #For pipeline header display#
  @vacant_display = "#{number_with_precision(percentagee, :precision=>2)}"
  @rent_sqft = "#{number_with_delimiter(vac_rentable_sqft_total.round)} SF"
  @suites_count = "#{suite_c.count} Suite(s)"
return  @suites_count,@rent_sqft,@vacant_display
end

def vac_sqft(propid)
  suite_cal = Suite.where("suite_no is not null and real_estate_property_id=? and status =?",propid,'vacant')
	vac_rentable_sqft_total = suite_cal.sum(:rentable_sqft)
  return "#{number_with_delimiter(vac_rentable_sqft_total.round)} SF"
end


def occupied_suite_calcs(propid,from_portfolio=nil)
  occupied_suites_six_month_exp_arr,suite_ids_col,occupied_suites_six_month_exp_coll = [],[],[]
  property = RealEstateProperty.find_real_estate_property(propid,from_portfolio)
  if from_portfolio.present?
#    property.each do |i|
#      occupied_suites_six_month_exp_coll << i.six_month_expiration_leases
#    end
   occupied_suites_six_month_exp_coll =  Lease.port_six_month_expiration_leases(propid)
  else
    occupied_suites_six_month_exp_coll = property.six_month_expiration_leases if property.present?
  end
  occupied_suites_six_month_exp_coll.flatten!
  occupied_suites_six_month_exp_coll.each do |occupied_suites_six_month_exp|
    occupied_suites_six_month_exp_arr << occupied_suites_six_month_exp.property_lease_suite # property lease suites collection
  end
  occupied_suites_property_lease = occupied_suites_six_month_exp_arr.flatten
  @lease_count = occupied_suites_property_lease.count
  occupied_suites_property_lease.compact.each do |f|
    suite_ids_col << f.suite_ids
  end
  suite_ids_col = suite_ids_col.compact
  @suite_dets = Suite.where(:id=>suite_ids_col)
end

def occupied_suite_total_calcs(propid,from_portfolio=nil)
  occupied_suite_calcs(propid,from_portfolio)
  six_mnth_expr_rent_sqft = @suite_dets.sum(:rentable_sqft)
  six_mnth_expr_rent_sqft = six_mnth_expr_rent_sqft.present? ? six_mnth_expr_rent_sqft : 0
  all_suites_sqft = Suite.where("suite_no is not null and real_estate_property_id IN(?)",propid)
  all_suites_sqft = all_suites_sqft.sum(:rentable_sqft)
  percentage = (all_suites_sqft.present? && all_suites_sqft!= 0.0) ? (six_mnth_expr_rent_sqft * 100 ) / all_suites_sqft : 0
  #For Pipeline Header#
  @sqft_value = "#{number_with_delimiter(six_mnth_expr_rent_sqft.round)} SF"
  @occ_percent = "#{percentage.round}"
  @leases_exp = "#{@lease_count} Lease(s)"
  return @sqft_value,@occ_percent,@leases_exp
end

def vacant_leased(property_lease_suites_negotiated)
  if property_lease_suites_negotiated.present?
            sum_1 = sum1_1 = 0
            property_lease_suites_negotiated.each_with_index do |property_lease_suite, i|
              tenant_1 = property_lease_suite.tenant
              lease_1 = property_lease_suite.lease
              suite_details = Suite.suites(property_lease_suite)
              total_rentable_sqft_1 = 0
                if suite_details && suite_details.present?
                suite_details.each_with_index do |suite_detail,j|
                   total_rentable_sqft_1 = total_rentable_sqft_1 + suite_detail.rentable_sqft.to_i unless suite_detail.rentable_sqft.nil?
                end
              end
              sum_1 = sum_1 + total_rentable_sqft_1
            end
          end
          return "#{sum_1 ? number_with_delimiter(sum_1) : 0} SF"
end



def tl_pipeline(lease)
	ti_collection = lease.cap_ex.tenant_improvements if (lease && lease.cap_ex)
	ti = ti_collection.map(&:amount_psf).compact.inject(:+) if (!ti_collection.blank? && ti_collection.present?)
	return ti
end


def lease_month_calculation(lease)
    months = RentSchedule.get_rent_schedule_period(lease.try(:commencement), lease.try(:expiration))
    months.present? && months > 0 ? "#{months.round} Month(s)" : "0 Month(s)"
end

def display_added_suites(suites,rentable_sqft=nil,usable_sqft=nil)
  suites_array = []
  if suites.eql?('suites')
    suites_array << params[:suite_no1] if params[:suite_no1].present?
    suites_array << params[:suite_no2] if params[:suite_no2].present?
    suites_array << params[:suite_no3] if params[:suite_no3].present?
    suites_array << params[:suite_no4] if params[:suite_no4].present?
    suites_array << params[:suite_no5] if params[:suite_no5].present?
    return "No of Suite(s):#{suites_array.count}"
#    return suites_array.empty? ? "" : (suites_array.empty? ? "" : suites_array.uniq.join(','))
  elsif rentable_sqft.present?
    total_calc(params[:rentable_sqft1],params[:rentable_sqft2],params[:rentable_sqft3],params[:rentable_sqft4],params[:rentable_sqft5])
  elsif usable_sqft.present?
    total_calc(params[:usable_sqft1],params[:usable_sqft2],params[:usable_sqft3],params[:usable_sqft4],params[:usable_sqft5])
  end
end
def total_calc(a,b,c,d,e)
  total_rent_sqft = 0
  total_rent_sqft += a.to_i if a.present?
  total_rent_sqft += b.to_i if b.present?
  total_rent_sqft += c.to_i if c.present?
  total_rent_sqft +=d.to_i if d.present?
  total_rent_sqft += e.to_i if e.present?
  return total_rent_sqft.eql?(0) ? "" : number_with_delimiter(total_rent_sqft)
end


def rent_page_all_suites(lease)
  prop_lease_suite = PropertyLeaseSuite.find_by_lease_id_and_tenant_id(@lease.try(:id).to_i,@lease.tenant.try(:id).to_i)
  cur_suites = prop_lease_suite.present? && prop_lease_suite.suite_ids.present? ? Suite.where(:id=>prop_lease_suite.suite_ids) : nil
  added_suites = cur_suites || []
  added_suites
end

def terms_build_methods
  if @lease.blank?
    @lease = params[:current_lease_id].present? ? Lease.find_by_id(params[:current_lease_id].to_i) : Lease.create(params[:lease])
  else
    @lease.update_attributes(params[:lease])
  end
  Lease.update_lease_occupancy_type(@lease)
  #Added to update lease status#
  Lease.update_lease_status(@lease)
end

def tmp_hash_calc(suites=nil)
  Suite.create(:suite_no => params[:suite],:real_estate_property_id => params[:property_id],:status => 'Occupied',:user_id => current_user.id) if suites.nil?
  prop_lease_suite = PropertyLeaseSuite.find_by_lease_id_and_tenant_id(params[:lse_id].to_i,params[:tnt_id].to_i)
  ste_ids = prop_lease_suite.try(:suite_ids) || []
  needed_suites = suites.nil? ? Suite.find_by_suite_no_and_real_estate_property_id(params[:suite],params[:property_id]).id : suites.id
  ste_ids << needed_suites
  tmp_hash = {}
  prev_tmp_hash = {}
  if ste_ids.present?
    ste_ids.uniq!
    cur_suite_id = Suite.find_by_suite_no_and_real_estate_property_id(params[:prev_suite],params[:property_id]).try(:id)
    ste_ids.delete(cur_suite_id) if cur_suite_id.present?
    cur_suite = Suite.find_by_id(cur_suite_id)
    cur_suite.update_attribute(:status, "vacant") if cur_suite.present?
    # The purpose of this line of code is to delete lease rent roll records whenever we are deleting suite for that lease
    LeaseRentRoll.where(:suite_id => cur_suite.try(:id)).destroy_all if cur_suite.present?
  end
  if prop_lease_suite
  prop_lease_suite.suite_ids = ste_ids
  prop_lease_suite.save
  already_added_suites = Suite.where(:id=>prop_lease_suite.suite_ids)
  already_added_suites.each do |i|
    tmp_hash[i.id]=i.suite_no
  end
  end
  if ste_ids.present?
    prev_suite_details = Suite.find_by_suite_no_and_real_estate_property_id(params[:prev_suite],params[:property_id])
    prev_tmp_hash[prev_suite_details.id]=prev_suite_details.suite_no if prev_suite_details.present?
  end
  return tmp_hash,prev_tmp_hash
end

def rent_suite_update
  tenant_id = @lease.try(:tenant).try(:id)
  if params[:suite_no1].present?
    @suites_present = true
    sid=Suite.find_by_suite_no_and_real_estate_property_id(params[:suite_no1],params[:property_id])
    sid = sid.update_attributes(:status => sid.status) if sid
    comm_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(sid.try(:id),params[:lease_id],tenant_id)
    if comm_prop.present?
      comm_prop.update_attributes(:move_in => params[:move_in1], :move_out => params[:move_out1])
    else
      CommPropertyLeaseSuite.create(:suite_id => sid.id, :lease_id => params[:lease_id], :tenant_id => tenant_id, :move_in => params[:move_in1], :move_out => params[:move_out1])
    end
  end
  if params[:suite_no2].present?
    @suites_present = true
    sid=Suite.find_by_suite_no_and_real_estate_property_id(params[:suite_no2],params[:property_id])
    sid = sid.update_attributes(:status => sid.status) if sid
    comm_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(sid.try(:id),params[:lease_id],tenant_id)
    if comm_prop.present?
      comm_prop.update_attributes(:move_in => params[:move_in2], :move_out => params[:move_out2])
    else
      CommPropertyLeaseSuite.create(:suite_id => sid.id, :lease_id => params[:lease_id], :tenant_id => tenant_id, :move_in => params[:move_in2], :move_out => params[:move_out2])
    end
  end
  if params[:suite_no3].present?
    @suites_present = true
    sid=Suite.find_by_suite_no_and_real_estate_property_id(params[:suite_no3],params[:property_id])
    sid = sid.update_attributes(:status => sid.status) if sid
    comm_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(sid.try(:id),params[:lease_id],tenant_id)
    if comm_prop.present?
      comm_prop.update_attributes(:move_in => params[:move_in3], :move_out => params[:move_out3])
    else
      CommPropertyLeaseSuite.create(:suite_id => sid.id, :lease_id => params[:lease_id], :tenant_id => tenant_id, :move_in => params[:move_in3], :move_out => params[:move_out3])
    end
  end
  if params[:suite_no4].present?
    @suites_present = true
    sid=Suite.find_by_suite_no_and_real_estate_property_id(params[:suite_no4],params[:property_id])
    sid = sid.update_attributes(:status => sid.status) if sid
    comm_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(sid.try(:id),params[:lease_id],tenant_id)
    if comm_prop.present?
      comm_prop.update_attributes(:move_in => params[:move_in1], :move_out => params[:move_out1])
    else
      CommPropertyLeaseSuite.create(:suite_id => sid.id, :lease_id => params[:lease_id], :tenant_id => tenant_id, :move_in => params[:move_in4], :move_out => params[:move_out4])
    end
  end
  if params[:suite_no5].present?
    @suites_present = true
    sid=Suite.find_by_suite_no_and_real_estate_property_id(params[:suite_no5],params[:property_id])
    sid = sid.update_attributes(:status => sid.status) if sid
    comm_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(sid.try(:id),params[:lease_id],tenant_id)
    if comm_prop.present?
      comm_prop.update_attributes(:move_in => params[:move_in5], :move_out => params[:move_out5])
    else
      CommPropertyLeaseSuite.create(:suite_id => sid.id, :lease_id => params[:lease_id], :tenant_id => tenant_id, :move_in => params[:move_in5], :move_out => params[:move_out5])
    end
  end
end

def tot_square_feet(lease)
  arra =  lease.try(:property_lease_suite).try(:suite_ids).try(:compact) || []
  total_rentable_sqft = Suite.where( :id => arra).sum(:rentable_sqft)
end

def notes_creation
  if params[:rent_scheldule_note] && @lease.present? && @lease.rent.present? && @lease.rent.rent_schedules.present?
    rent_sch_first = @lease.rent.rent_schedules[0].id
    cur_note = Note.find_by_note_type_and_note_id('RentSchedule',rent_sch_first)
    cur_note.present? ? cur_note.update_attributes(:content => params[:rent_scheldule_note]) : Note.create(:content => params[:rent_scheldule_note], :note_type=>'RentSchedule', :note_id => rent_sch_first)
  end
  #For cpi details notes start
  if params[:cpi_escalation_note] && @lease.present? && @lease.rent.present? && @lease.rent.cpi_details.present?
    rent_cpi_first = @lease.rent.cpi_details[0].id
    cur_note = Note.find_by_note_type_and_note_id('CpiDetails',rent_cpi_first)
    cur_note.present? ? cur_note.update_attributes(:content => params[:cpi_escalation_note]) : Note.create(:content => params[:cpi_escalation_note], :note_type=>'CpiDetails', :note_id => rent_cpi_first)
  end
  #For cpi details notes end
  if params[:rent_parking_note] && @lease.present? && @lease.rent.present? && @lease.rent.parkings.present?
    rent_par_first = @lease.rent.parkings[0].id
    cur_note = Note.find_by_note_type_and_note_id('Parking',rent_par_first)
    cur_note.present? ? cur_note.update_attributes(:content => params[:rent_parking_note]) : Note.create(:content => params[:rent_parking_note], :note_type=>'Parking', :note_id => rent_par_first)
  end
  if params[:rent_recovery_note] && @lease.present? && @lease.rent.present? && @lease.rent.recoveries.present?
    rent_rec_first = @lease.rent.recoveries[0].id
    cur_note = Note.find_by_note_type_and_note_id('Recovery',rent_rec_first)
    cur_note.present? ? cur_note.update_attributes(:content => params[:rent_recovery_note]) : Note.create(:content => params[:rent_recovery_note], :note_type=>'Recovery', :note_id => rent_rec_first)
  end
  if params[:rent_suite_note]
    prop_lease_suite = PropertyLeaseSuite.find_by_lease_id_and_tenant_id(@lease.try(:id).to_i,@lease.tenant.try(:id).to_i)
    if prop_lease_suite.present?
      cur_note =''
      suite_id = prop_lease_suite.suite_ids.present? ? prop_lease_suite.suite_ids.first : nil
      cur_note = Note.find_by_note_type_and_note_id('Suite',suite_id) if suite_id.present?
      cur_note.present? ? cur_note.update_attributes(:content => params[:rent_suite_note]) : Note.create(:content => params[:rent_suite_note], :note_type=>'Suite', :note_id => suite_id)
    end
  end
end

def display_rent_scheldule_note(note_type)
  if note_type.eql?('rnt_sch')
    @lease.try(:rent).try(:rent_schedules).try(:first).try(:note) ? @lease.rent.rent_schedules.first.note.content : ''
  elsif note_type.eql?('cpi_escal')
    @lease.try(:rent).try(:cpi_details).try(:first).try(:note) ? @lease.rent.cpi_details.first.note.content : ''
  elsif note_type.eql?('parking_note')
    @lease.try(:rent).try(:parkings).try(:first).try(:note) ? @lease.rent.parkings.first.note.content : ''
  elsif note_type.eql?('rent_recovery')
    @lease.try(:rent).try(:recoveries).try(:first).try(:note) ? @lease.rent.recoveries.first.note.content : ''
  elsif note_type.eql?('suite_note')
    cur_note = ''
    prop_lease_suite = PropertyLeaseSuite.find_by_lease_id_and_tenant_id(@lease.try(:id).to_i,@lease.tenant.try(:id).to_i)
    if prop_lease_suite.present?
      suite_id = prop_lease_suite.suite_ids.present? ? prop_lease_suite.suite_ids.first : nil
      cur_note = Note.find_by_note_type_and_note_id('Suite',suite_id).try(:content) if suite_id.present?
    end
    cur_note.present? ? cur_note : ''
  end
end

def calculate_enabled_suites
  value_present = 0
  for i in 1..5
    value_present += 1 if params["suite_no"+(i).to_s].present?
  end
  value_present
end

def convert_to_integer(value)
  number_with_delimiter(value.to_i) if value.present?
end

#Displays lightbox or throws error
def show_or_hide_lightbox(msg,page)
      page << "close_control_modal='true'" if msg !=  "#{FLASH_MESSAGES['leases']['108']}"
      page << "close_or_open_lightbox()"
  end

def terms_master_display(property_id)
  qry = @lease.try(:tenant).try(:tenant_legal_name).present? ? " and leases.id != #{@lease.id}" : ""
  PropertyLeaseSuite.joins(:lease).where("leases.is_executed=true and leases.is_archived=false and leases.status ='Active' and real_estate_property_id =?#{qry}",property_id).joins(:tenant).select('property_lease_suites.suite_ids,property_lease_suites.lease_id,tenants.tenant_legal_name')
end

def terms_options_for_select(container, selected = nil)
  return container if String === container
  container = container.to_a if Hash === container
  selected, disabled = extract_selected_and_disabled(selected).map do | r |
    Array.wrap(r).map(&:to_s)
  end
  container.map do |element|
    html_attributes = option_html_attributes(element)
    text, value = terms_option_text_and_value(element).map(&:to_s)
    selected_attribute = ' selected="selected"' if option_value_selected?(value, selected)
    disabled_attribute = ' disabled="disabled"' if disabled && option_value_selected?(value, disabled)
    %(<option value="#{html_escape(value)}"#{selected_attribute}#{disabled_attribute}#{html_attributes}>#{html_escape(text)}</option>) if text.present?
  end.join("\n").html_safe
end

def terms_option_text_and_value(option)
  # Options are [text, value] pairs or strings used for both.
  case
  when Array === option
    option = option.reject { |e| Hash === e }
    [option.first, option.last]
  when !option.is_a?(String) && option.respond_to?(:first) && option.respond_to?(:last)
    [option.first, option.last]
  else
    suite_nos = Suite.where('id IN (?)',option.suite_ids).map(&:suite_no).join(', ')
    master_tenant_display = suite_nos.present? ? "#{option.tenant_legal_name} - #{suite_nos}" : option.tenant_legal_name
    [master_tenant_display, option.lease_id]
  end
end

  def abstract_view_title
    if find_tenant_legal_name && find_tenant_legal_name != ''
    "Abstract View" + " - " + find_tenant_legal_name     if((@lease && !@lease.nil? ) || (params[:lease_id].present? && params[:lease_id] != 'undefined' && !params[:lease_id].blank?))
    elsif find_tenant_legal_name
      "Abstract View"
    end
  end

  def params_formation
    lease_id = @lease.try(:id).to_i
    tenant_id = @lease.tenant.try(:id).to_i
    prop_lease_suite = PropertyLeaseSuite.find_by_lease_id_and_tenant_id(lease_id,tenant_id)
    cur_suites = prop_lease_suite.present? && prop_lease_suite.suite_ids.present? ? Suite.where(:id=>prop_lease_suite.suite_ids) : nil
    total_suites = Suite.where(:real_estate_property_id=>params[:property_id])
    total_added_suites = total_suites || []
    tmp_hash = {}
    unless cur_suites.nil?
      cur_suites.uniq!
      CommPropertyLeaseSuite
      cur_suites.each_with_index do |i,j|
        comm_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(i.id,lease_id,tenant_id)
        params["suite_no"+(j+1).to_s] = i.suite_no
        params["rentable_sqft"+(j+1).to_s] = i.rentable_sqft
        params["floor"+(j+1).to_s] = i.floor
        move_in = comm_prop.try(:move_in).present? ? comm_prop.move_in.strftime("%m/%d/%Y") : nil
        params["move_in"+(j+1).to_s] = move_in
        move_out = comm_prop.try(:move_out).present? ? comm_prop.move_out.strftime("%m/%d/%Y") : nil
        params["move_out"+(j+1).to_s] = move_out
        params["usable_sqft"+(j+1).to_s] = i.usable_sqft
      end
      ((cur_suites.count)+1..5).each do |j|
        params["suite_no"+j.to_s] = ''
        params["rentable_sqft"+j.to_s] = ''
        params["floor"+j.to_s] = ''
        params["move_in"+j.to_s] = ''
        params["move_out"+j.to_s] = ''
        params["usable_sqft"+j.to_s] = ''
      end
      calculate_enabled_suites
      cur_suites.each do |i|
        tmp_hash[i.id]=i.suite_no
      end
    end
    return prop_lease_suite,total_added_suites
  end

  def comm_prop_lease_suite_update
    comm_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(suites.id,params[:lse_id],params[:tnt_id])
    move_in = comm_prop.try(:move_in).present? ? comm_prop.move_in.strftime("%m/%d/%Y") : "mm/dd/yyyy"
    move_out = comm_prop.try(:move_out).present? ? comm_prop.move_out.strftime("%m/%d/%Y") : "mm/dd/yyyy"
    old_suite = Suite.find_by_suite_no_and_real_estate_property_id(params[:prev_suite],params[:property_id])
    old_suite_prop = CommPropertyLeaseSuite.find_by_suite_id_and_lease_id_and_tenant_id(old_suite.try(:id),params[:lse_id],params[:tnt_id])
    if old_suite_prop.present?
      old_suite_prop.suite_id = suites.id
      old_suite_prop.move_in = move_in.eql?("mm/dd/yyyy") ? nil : move_in
      old_suite_prop.move_out = move_out.eql?("mm/dd/yyyy") ? nil : move_out
      old_suite_prop.save
    end
    return move_in,move_out
  end


   #.............................................................................................Methods for stacking plan.................................................................................................................................................

  #To find leases in a floor
  def find_leases_in_floor(floor, property_id)
   @leases= []
   suites= []
   @lease_details = {}
   @floor_suites = floor.nil? ? @suites_without_floor : @suites.map{|suite| suite if suite.floor == floor}
   @all_property_lease_suites = PropertyLeaseSuite.includes(:lease).where("leases.real_estate_property_id=#{property_id}")
   @property_lease_suites = @all_property_lease_suites.map(&:suite_ids).flatten.compact.uniq
   @floor_suites.compact.each do |suite|
   #@all_property_lease_suites = PropertyLeaseSuite.all
   # @property_lease_suites = @all_property_lease_suites.map(&:suite_ids).flatten.compact.uniq
    if @property_lease_suites.include?(suite.id)
       @all_property_lease_suites.each do |pls|
        if pls.suite_ids.present?
          suite_ids = pls.suite_ids
          suite_ids = [suite_ids]  if suite_ids.kind_of?(String) || suite_ids.kind_of?(Integer)
          @leases << pls.lease if suite_ids.include?(suite.id) && pls.lease && suite.status != 'Vacant' && pls.lease.is_executed && !is_expired_lease(pls)
        end
      end
    end
  end
  @leases = @leases.uniq if @leases.present?
  find_occ_and_vacant_suites(floor)
 end

   #to check for expired leases
  def is_expired_lease(property_lease_suite)
 property_lease_suite_lease =  property_lease_suite.lease
  expired_lease =  ((property_lease_suite_lease.present? && property_lease_suite_lease.expiration.nil?) || (property_lease_suite_lease.try(:mtm))) ? false : ((property_lease_suite_lease.present? && property_lease_suite_lease.expiration && property_lease_suite_lease.expiration > Time.now) ? false : true)
end

 #To find occupied and vacant suites
  def  find_occ_and_vacant_suites(floor)
    @occupied_suites = []
    @leases.each do |lease|
	@occupied_suites <<  find_suites_of_lease(lease,floor)
       end
    @suites_collection = (@occupied_suites +  find_vacant_suites(floor)).flatten.compact.sort_by(&:suite_no)
  end

 #To collect lease information of a suite
 def collect_lease_data(suite,floor)
	 if suite.status && suite.status.downcase == 'vacant'
	       vacant_area =0
               vacant_area = suite.rentable_sqft.to_i unless suite.rentable_sqft.nil?
               @lease_details = {'tenant_name'=>"Vacant",'ending_date' => '-','suite_numbers'=>suite.suite_no,'area' =>vacant_area,'lease_expire' => 'vacant','lease_id'=>nil,'terms'=>"-"}
           elsif suite.status
	    if @property_lease_suites.include?(suite.id)
              @all_property_lease_suites.each do |property_lease_suite|
		if property_lease_suite.suite_ids?
		  suite_ids = property_lease_suite.suite_ids
		  suite_ids = [suite_ids]  if suite_ids.kind_of?(String) || suite_ids.kind_of?(Integer)
		  if suite_ids.include?(suite.id) && is_active_property_lease_suite(property_lease_suite)
	            lease = property_lease_suite.lease
		    tenant_name = lease.tenant.tenant_legal_name
		     expiration_diff = lease.try(:mtm) ? 'm2m' : (lease && lease.expiration ?  ((lease.expiration.year.to_i  - Date.today.year.to_i) + 1) : 10 )
                     expiration_diff = 10 if (expiration_diff.to_i > 10 || expiration_diff.to_i == 0) && expiration_diff != 'm2m'
                     lease_terms = lease_month_calculation(lease)
		     find_suite_numbers_and_area(lease,floor)
@lease_details =  {'tenant_name'=>tenant_name.gsub('&','&amp;'),'ending_date' => lease.try(:mtm) ? 'MTM' : ((lease && lease.expiration)  ? lease.expiration.strftime('%m/%d/%y') : "-"),'suite_numbers'=>@suite_numbers,'area' =>@area,'options'=>options_and_ti(lease.tenant),'terms'=>(lease_terms == "0 Month(s)" ? "-" : lease_terms),'lease_expire' => expiration_diff,'lease_id'=>lease.id}
               end
		end
	      end
	    end
    end
    end

#To find suite numbers and sqft of a lease
def find_suite_numbers_and_area(lease,floor)
       suites =[]
       suites = find_suites_of_lease(lease,floor)
       @displayed_suites << suites
       suites.each_with_index do |suite,j|
       comma = (j+1 != suites.count) ? ',' : ''
       @area = @area + suite.rentable_sqft.to_i unless suite.rentable_sqft.nil?
       @suite_numbers += !suite.suite_no.eql?(nil) ? "#{suite.suite_no}#{comma} "  :  ""
     end if suites && !suites.empty?
  end

  #to find suite details of lease
  def find_suites_of_lease(lease,floor)
     @area = 0
     @suite_numbers = ""
      property_lease_suite = lease.property_lease_suite
      suites = is_active_property_lease_suite(property_lease_suite) ? Suite.suites_with_floor(property_lease_suite,floor) : []
  end

  #To check whether the lease is active or not
  def is_active_property_lease_suite(property_lease_suite)
	(property_lease_suite && !is_expired_lease(property_lease_suite) && property_lease_suite.lease && property_lease_suite.lease.is_executed) ? true : false
  end


  #total floor sqft
  def  find_total_rentable_sqft(floor)
    @total_sqft = 0
    @vacant_area = 0
    @vacant_area = @vacant_suites.uniq.compact.sum(&:rentable_sqft).round
    @total_sqft = @occupied_suites.flatten.compact.uniq.map{|s| s if s.rentable_sqft}.compact.sum(&:rentable_sqft).round + @vacant_area
   return @total_sqft
  end

    #to find_vacant_suites_in_a_floor
    def find_vacant_suites(floor)
      floor_condition = (floor.nil? || floor.blank?) ? "(floor is null or floor = '')" : "floor = '#{floor}'"
      @vacant_suites =  Suite.where("status = ? and real_estate_property_id = ? and #{floor_condition} and rentable_sqft is not null",'Vacant',params[:property_id])
    end

 #.............................................................................................Methods for stacking plan.................................................................................................................................................

    def find_active_prospects(active_prospects,property_id)
      suite_id = []
       active_prospects.present? && active_prospects.flatten.each do |prospect|
            suite_id << prospect.suite_ids
        end
      suite_id  = suite_id.compact
      @find_suite = Suite.where(:id=>suite_id)
      rent_sqft = @find_suite.sum(:rentable_sqft)
      all_suites_sqft = Suite.where("suite_no is not null and real_estate_property_id IN (?)",property_id)
      all_suites_sqft = all_suites_sqft.sum(:rentable_sqft)
      percentage = (all_suites_sqft.present? && all_suites_sqft!= 0.0) ? ( rent_sqft * 100 ) / all_suites_sqft : 0
      @prospect_count = "#{active_prospects.present? ? active_prospects.count : 0} Prospect(s)"
      @prospect_sqft = "#{number_with_delimiter(rent_sqft.round)} SF"
      @prospect_percent = "#{percentage.round}"
    end

    def find_pending_approval(pending_approval,property_id)
      suite_id = []
      pending_approval.present? && pending_approval.flatten.each do |prospect|
          suite_id << prospect.suite_ids
      end
      suite_id  = suite_id.compact
      @find_suite = Suite.where(:id=>suite_id)
      rent_sqft = @find_suite.sum(:rentable_sqft)
      all_suites_sqft = Suite.where("suite_no is not null and real_estate_property_id IN (?)",property_id)
      all_suites_sqft = all_suites_sqft.sum(:rentable_sqft)
      percentage = (all_suites_sqft.present? && all_suites_sqft!= 0.0) ? ( rent_sqft * 100 ) / all_suites_sqft : 0
      @pending_count = "#{pending_approval.present? ? pending_approval.count : 0} Lease(s)"
      @pending_sqft = "#{number_with_delimiter(rent_sqft.round)} SF"
      @pending_percent = "#{percentage.round}"
    end

    #moved mgmt_lease_details to application_helper#


    def find_lease_mgmt_header
      @find_lease = []
    		@leases.uniq.each do|lease|
          if lease && lease.commencement && ((lease.commencement.to_date.strftime("%Y-%m-%d") > Time.now.strftime("%Y-%m-%d") ))
            @find_lease <<   lease
          end
				end
        return @find_lease
    end

  def display_for_management_header(start_month,end_month,property_id)
		@leases = Lease.find(:all,:conditions=>['real_estate_property_id = ? and is_executed = ?',property_id,true])
		@insurance = Insurance.find(:all,:conditions=>['lease_id IN (?)' ,@leases])
    lease_id = PropertyLeaseSuite.find(:all,:conditions=>['lease_id IN (?)',@leases])
		@tenant= []
		lease_id.each do |val|
			@tenant << val.tenant_id
    end
		cap_ex = CapEx.find(:all,:conditions=>['lease_id IN (?)' ,@leases])
		@tenant_imp = TenantImprovement.find(:all,:conditions=>['cap_ex_id IN (?)',cap_ex])
			if @leases.present? || @insurance.present? || @tenant_imp.present?
				find_lease_mgmt_header
			 @insurance.uniq.each do |ins|
            insurance_docs = ins.documents if ins.present?
            if insurance_docs.present?
              insurance_docs.each do |ins_doc|
                if ins_doc && ins_doc.expiration_date.present?
                @lease_for_insurance = Insurance.find_by_sql("select DISTINCT ins.lease_id as lease_id from insurances ins left join documents doc on ins.id = doc.insurance_id inner join leases l on ins.lease_id = l.id and l.real_estate_property_id = #{property_id} and l.is_executed=true and doc.expiration_date IS NOT null and doc.expiration_date between '#{start_month}-01' and '#{end_month}-31'")
                end
              end
            end
				end
				@tenant_imp.uniq.each do |tmp|
					if tmp.work_start_date.present?
						@find_tmp = TenantImprovement.find_by_sql("select DISTINCT cp.lease_id as lease_id from tenant_improvements tmp inner join cap_exes cp on tmp.cap_ex_id = cp.id left outer join property_lease_suites pl on pl.lease_id = cp.lease_id right join tenants t on pl.tenant_id = t.id  right join leases l on pl.lease_id = l.id  and l.real_estate_property_id = #{property_id} and l.is_executed=true and tmp.work_start_date IS NOT null where tmp.work_start_date between '#{start_month}-01' and '#{end_month}-31'")
					end
				end
      end
   end

  def lease_tab_data_push
    find_lease_id
    prop_lease_suite = @lease.property_lease_suite.blank? ? @lease.build_property_lease_suite : @lease.property_lease_suite
    @tenant = prop_lease_suite.tenant.blank? ? prop_lease_suite.build_tenant : prop_lease_suite.tenant
    @tenant.options.blank? ? @tenant.options.build : @tenant.options
    info = @tenant.info.blank? ? @tenant.build_info : @tenant.info
    info.note.blank? ? info.build_note : info.note
    @tenant.lease_contact.blank? ? @tenant.build_lease_contact : @tenant.lease_contact
    @tenant.note.blank? ? @tenant.build_note : @tenant.note
    @lease.note.blank? ? @lease.build_note : @lease.note

    @rent = @lease.rent.blank? ? @lease.build_rent : @lease.rent
    @rent.rent_schedules.blank? ? @rent.rent_schedules.build : @rent.rent_schedules
    #    @rent.suites.blank? ? @rent.suites.build : @rent.suites
    @rent.other_revenues.blank? ? @rent.other_revenues.build : @rent.other_revenues
    @rent.cpi_details.blank? ? @rent.cpi_details.build : @rent.cpi_details
    @rent.parkings.blank? ? @rent.parkings.build : @rent.parkings
    @rent.recoveries.blank? ? @rent.recoveries.build : @rent.recoveries
    @rent.percentage_sales_rents.blank? ? @rent.percentage_sales_rents.build : @rent.percentage_sales_rents
    @clause = @lease.clause.blank? ? @lease.build_clause : @lease.clause
    @hour = @clause.hour.blank? ? @clause.build_hour : @clause.hour
    @notes = @hour.note.blank? ? @hour.build_note : @hour.note
    @legal_provision = @clause.legal_provision.blank? ? @clause.build_legal_provision : @clause.legal_provision
    @items_count = @clause.items
    @income_projection = @lease.income_projection.blank? ? @lease.build_income_projection : @lease.income_projection
    @income_projection.build_note if @income_projection.new_record?
    if @clause.services.blank?
      3.times do
        @services = @clause.services.build
        @note_obj = @services.build_note
      end
    else
      @services_count = @clause.services
      #======= PLEASE   DONT DELETE======#
      #~ if (@services_count.count == 1)
      #~ servise = []
      #~ 2.times do
      #~ @services = @clause.services.build
      #~ @note = @services.build_note
      #~ servise << @services
      #~ end
      #~ @services_count = @services_count + servise
      #~ else (@services_count.count == 2)
      #~ @services_count = @services_count.delete_if {| a| a.id==nil}
      #~ @services = @clause.services.build
      #~ @note = @services.build_note
      #~ @services_count = @services_count + @services.to_a
      #~ end
      #======= PLEASE   DONT DELETE======#
    end
    build_cap_ex_blank
    build_insurance_blank
    build_doc_blank
  end

  def find_lease_id
    @lease = Lease.find(params[:lease_id]) if params[:lease_id] && params[:lease_id] !='undefined' && !params[:lease_id].nil? && params[:lease_id].present?
  end
  def build_cap_ex_blank
    #for cap_ex build start
    @cap_ex_build=@lease.cap_ex.blank? ? @lease.build_cap_ex : @lease.cap_ex
    @cap_ex_build_note = @cap_ex_build.note.blank? ? @cap_ex_build.build_note : @cap_ex_build.note
    if @cap_ex_build.tenant_improvements.blank?
      @tenant_improvement_build=@cap_ex_build.tenant_improvements.build
      @tenant_improvement_build.build_note
    else
      @cap_ex_build.tenant_improvements
      @cap_ex_build.tenant_improvements.first.build_note if @cap_ex_build.tenant_improvements && @cap_ex_build.tenant_improvements.first.present?  && @cap_ex_build.tenant_improvements.first.note.blank?
    end
    if @cap_ex_build.leasing_commissions.blank? || (@cap_ex_build && @cap_ex_build.leasing_commissions && @cap_ex_build.leasing_commissions.count == 1)
      3.times do
        @lease_com=@cap_ex_build.leasing_commissions.build
        @lease_com.build_note
      end
    end
    if @cap_ex_build.other_exps.blank?
      @other_exp_build = @cap_ex_build.other_exps.build
      @other_exp_build.build_note
    else
      @cap_ex_build.other_exps
    end
    #for cap_ex build end
  end

  def build_insurance_blank
    #for insurance build start
    @insurance_build=@lease.insurance.blank? ? @lease.build_insurance : @lease.insurance
    if @insurance_build.documents.blank?
      @insurance_docs = @insurance_build.documents.build
      @insurance_docs.build_note
    else
      @insurance_build.documents
    end
    if @insurance_build.ins_categories.blank?
      13.times do
        @insurance_build.ins_categories.build
      end
    else
      @insurance_build.ins_categories
    end
    #for insurance build end
  end

  def build_doc_blank
    @doc_build = @lease.documents.blank? ? @lease.documents.build : @lease.documents
  end

  #Method for displaying Days vacant in suites and in light box for Vacant Suites#
    def calculate_vac_days_for_suite(suite_id)
      @vac_days = ""
      property_id = params[:property_id] ? params[:property_id]  : params[:propertyid]
      lease_end  = Time.now.strftime("%Y-%m-%d")
      find_lease  = LeaseRentRoll.find(:first,:conditions=>['real_estate_property_id IN (?) and suite_id = ? and lease_end_date < ?', property_id,suite_id,lease_end],:order => "lease_end_date desc") # used to find the latest expired lease for a suite based on lease end date
     if find_lease.present?
        exp_date = find_lease.try(:lease).try(:expiration)
        vaccant_days = exp_date.to_date - Date.today if exp_date
        @vac_days = vaccant_days.to_i.abs if vaccant_days
      end
      return @vac_days
    end

    def display_from_date_for_rent_schedule(from_date, lease, rent_sch_cnt)
      if rent_sch_cnt==1
        from_date = lease.try(:commencement).strftime("%m/%d/%Y") rescue nil
      else
        from_date = from_date.strftime("%m/%d/%Y") rescue nil
      end
      from_date
    end


    def display_currency_overview_from_lease_helper(value, precision_count=2)
    if (params[:sqft_calc]  == "per_sqft" ||  params[:unit_calc] =='unit_calc') && (params[:partial_page] != "cash_and_receivables" && !params[:cash_find_id] && params[:partial_page] !='cash_and_receivables_for_receivables')
        display_currency_persqft(value,precision_count=2)
    else
    return "" if value.blank?
      return "-#{number_with_delimiter(value.round.abs)}" if value < 0
    "#{number_with_delimiter(value.round.abs)}"
    end
  end


    def precission_with_delimeter(value, precission=2)
      number_with_delimiter(number_with_precision(value, :precission => precission))
    end


    def get_parking_revenue(parking,lease_start_date, lease_end_date, monthly_parking)
      total_parking = parking.total_parking_revenue(@lease.try(:expiration), @lease.try(:commencement), parking.total_monthly) rescue nil
     total_parking = nil  if (total_parking.eql?(0) || total_parking.eql?(0.00))
     total_parking
   end

     def get_other_revenue_period(other_revenue_from_date,other_revenue_to_date)
      no_of_months =  RentSchedule.get_rent_schedule_period(other_revenue_from_date, other_revenue_to_date)
      no_of_months = nil if no_of_months.eql?(0)
      no_of_months
    end

    def display_total_other_revenue(total_other_revenue)
      if (total_other_revenue.eql?(0) || total_other_revenue.eql?(0.00))
        other_revenue = nil
      else
        other_revenue = number_with_delimiter(number_with_precision(total_other_revenue, :precission => 2))
      end
      other_revenue
    end

    #To find mgmt header Occ SF and percent#
    def occupied_sqft_percent_calc(propid)
      suite_c = Suite.where("suite_no is not null and real_estate_property_id=? and status =?",propid,'Occupied')
      suite_properties = Suite.where("suite_no is not null and real_estate_property_id=?",propid)
      occupied_rentable_sqft = suite_c.sum(:rentable_sqft)
      suite_all_sqft = suite_properties.sum(:rentable_sqft)
      percentagee = (suite_all_sqft.present? && suite_all_sqft!= 0.0) ? (occupied_rentable_sqft * 100 ) / suite_all_sqft : 0
      #For pipeline header display#
      @occupied_percentage = "#{number_with_precision(percentagee, :precision=>2)}"
      @rent_sqft = "#{number_with_delimiter(occupied_rentable_sqft.round)} SF"
      return  @rent_sqft,@occupied_percentage
    end
    #for add lease document for shared user
    def shared_document_for_lease(folder,document)
      shared_folders = SharedFolder.find(:all,:conditions=>['folder_id = ?',folder.id])
      user = User.find(document.user_id)
      if document.folder.parent_id !=0
            unless shared_folders.empty?
              shared_folders.each do |subshared_folders_1|
                  SharedDocument.create(:folder_id=>folder.id,:user_id=>subshared_folders_1.user_id,:sharer_id=> document.user_id,:real_estate_property_id=>folder.real_estate_property_id,:document_id=>document.id)
              end
              SharedDocument.create(:document_id=>document.id,:folder_id=>document.folder_id,:user_id=>folder.user_id,:sharer_id=>document.user_id,:real_estate_property_id=>folder.real_estate_property_id) if document.user_id != folder.user_id
            end
          end
          Event.create_new_event("upload",document.user_id,nil,[document],user.user_role(document.user_id),document.filename,nil)
        end


#|This methods returns 'true' or 'false' based on the array of suites' leases' expiration is greater than the expiration of leases in pipeline page #
 def check_suite_status(prop_lease_suite, prop_id, variable)
   @lease = Lease.find_by_id(params[:lease_id]) if params[:lease_id] && prop_lease_suite.nil?
   prop_lease_suite = @lease.property_lease_suite if @lease && prop_lease_suite.nil?
    suites = Suite.where(:id => [prop_lease_suite.suite_ids], :real_estate_property_id => prop_id)
    lease = prop_lease_suite.lease
    logic_array = []
    logic = true
    suites.each do |suite|
      lease_suite = finding_lease_of_a_suite(suite,variable)
      lease_suite.each do |prop_lease|
      if(variable== "pipeline")
      #~ logic = logic && !(((prop_lease.commencement..prop_lease.expiration).include?(lease.commencement)) || ((prop_lease.commencement..prop_lease.expiration).include?(lease.expiration)))

      starting = (!lease.try(:commencement).nil? && !lease.try(:expiration).nil?) ? ( lease.try(:commencement) <= prop_lease.try(:expiration) ) : false
      ending = (!lease.try(:commencement).nil? && !lease.try(:expiration).nil?) ? ( lease.try(:expiration) >= prop_lease.try(:commencement) ) : false

      logic = logic && !( starting && ending )
      else
      #~ logic = logic && !(((prop_lease.commencement..prop_lease.expiration).include?((params[:lease][:commencement]).to_datetime)) || ((prop_lease.commencement..prop_lease.expiration).include?((params[:lease][:expiration]).to_datetime)))
      logic = logic && !(( (params[:lease][:commencement]).to_datetime <= prop_lease.try(:expiration) ) && ( (params[:lease][:expiration]).to_datetime >= prop_lease.try(:commencement) ))
      #~ !(((prop_lease.commencement < prop_lease.expiration).include?((params[:lease][:commencement]).to_datetime)) )
    end
    end
      logic_array << (lease_suite.present? ? logic : true)
    end
    return logic_array.include?(false)
  end

#This method is to find all the executed leases of a particular suite#
  def finding_lease_of_a_suite(suite,variable)
    property_lease_suites = PropertyLeaseSuite.includes(:lease).where("leases.real_estate_property_id = ? AND leases.is_executed = ?",  suite.real_estate_property_id, true)
    leases = []
    suite_ids = property_lease_suites.map(&:suite_ids).flatten.uniq
    if suite_ids && suite_ids.include?(suite.id)
      property_lease_suites.each do |pls|
       if(variable== "pipeline")
        leases << pls.lease if pls && pls.suite_ids && pls.try(:suite_ids).include?(suite.id)
        else
        leases << pls.lease if pls && pls.suite_ids && pls.try(:suite_ids).include?(suite.id) && (pls.lease_id.to_i != params[:lease_id].to_i)
      end
      end
    end
    return leases
  end

  #to calculate cpi_adjusted_annualized_psf in rent schedule
  def cpi_adjusted_annualized_psf(amount)
	 amount.to_f * 12
  end

  def rent_sch_build(lease,prop_lease_suite)
    if lease.try(:rent).try(:rent_schedules).present?
      rent_sch = lease.rent.rent_schedules
      if rent_sch.first.id.present?
        rent_sch_coll = rent_sch.reject { |i| i.suite_id.nil?}.sort_by(&:suite_id)
      else
        suite_ids = prop_lease_suite.try(:suite_ids)
        suite_ids.each do |i|
          RentSchedule.create(:suite_id => i,:rent_id => lease.try(:rent).try(:id))
        end
        @lease = Lease.find_by_id(params[:lease_id])
        rent_sch = @lease.rent.rent_schedules
        rent_sch_coll = rent_sch.reject { |i| i.suite_id.nil?}.sort_by(&:suite_id)
      end
    else
      rent_sch_coll =[]
    end
    return rent_sch_coll
  end

  def sorting_all_prop_lease_suites(leases)
    prop_lease_suites,suites,sorted,suite_ids = [],[],[],[]
    leases.each do |i|
      suite_ids << i.suite_ids.first if i.present? && i.suite_ids.present?
    end
    suite_ids.flatten!
    suites = Suite.where('id in (?)',suite_ids)
    if suites.present?
      sorted = Suite.find_by_sql("select id from suites where id in (#{suites.map(&:id).join(',')}) order by CAST(suite_no AS SIGNED) ASC")
      sorted.flatten!
      # Need to change the following logic
      sorted.map(&:id).each do |suite|
        leases.each do |prop_lease_suite|
          prop_lease_suites << prop_lease_suite if prop_lease_suite.try(:suite_ids) && prop_lease_suite.suite_ids.include?(suite)
        end
      end
      prop_lease_suites.uniq! if prop_lease_suites.present?
    end
    prop_lease_suites
  end

  def find_collections_of_leases
    @find_lease_count = @find_lease.compact.count if @find_lease
    @lease_for_insurance_count = @lease_for_insurance.compact.count if @lease_for_insurance
    @find_tmp_count = @find_tmp.compact.count if @find_tmp
    if params[:selected_value] == "New Leases" && @find_lease && @find_lease_count > 0
      @find_lease= @pdf ?  @find_lease.compact : @find_lease.compact.paginate(:per_page=>25,:page=>$mgmt_page)
    elsif params[:selected_value] == "Insurance Alerts" && @lease_for_insurance && @lease_for_insurance_count > 0
      @lease_for_insurance = @pdf ?  @lease_for_insurance.compact : @lease_for_insurance.compact.paginate(:per_page=>25,:page=>$mgmt_page)
    elsif params[:selected_value] == "Upcoming TIs" && @find_tmp && @find_tmp_count > 0
      @find_tmp = @pdf ?  @find_tmp.compact : @find_tmp.compact.paginate(:per_page=>25,:page=>$mgmt_page)
    end
  end

  end
