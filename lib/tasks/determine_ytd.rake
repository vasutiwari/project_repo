
namespace :make  do
  task :ytd => :environment do
    include PropertiesHelper
    type = ENV["type"]
    if type == "cash_flow"
      coll = IncomeAndCashFlowDetail.all
      puts " Processing..."
    elsif type == "cap_exp"
      coll = PropertyCapitalImprovement.all
      puts " Processing..."
    else
      puts "----------------------------------------------------------"
      puts " Please enter the type as [ cash_flow (or) cap_exp ] "
      puts "----------------------------------------------------------"
      exit(0)
    end
    coll.each do |itr|
      pfs =  itr.property_financial_periods
      b_row = pfs.detect {|i| i.pcb_type == 'b'}
      a_row = pfs.detect {|i| i.pcb_type == 'c'}
      unless b_row.nil? && a_row.nil?
        b_arr = [b_row.january, b_row.february, b_row.march, b_row.april, b_row.may, b_row.june, b_row.july, b_row.august, b_row.september, b_row.october, b_row.november, b_row.december]
        b_arr.each_with_index { |i,j| b_arr[j] = 0 if i.nil? }
        a_arr = [a_row.january, a_row.february, a_row.march, a_row.april, a_row.may, a_row.june, a_row.july, a_row.august, a_row.september, a_row.october, a_row.november, a_row.december]
        a_arr.each_with_index { |i,j| a_arr[j] = 0 if i.nil? }
        b_ytd_arr = Array.new(12,0)
        a_ytd_arr = Array.new(12,0)
        0.upto(11) do |ind|
          0.upto(ind) do |sub|
            b_ytd_arr[ind] += b_arr[sub]
            a_ytd_arr[ind] += a_arr[sub]
          end unless ind == 0
        end
        var_arr = []
        per_arr = []
        var_ytd_arr = []
        per_ytd_arr = []
        0.upto(11) do |indx|
          if type == "cash_flow"
            var_ytd_arr[indx] = find_income_or_expense(itr) ? (b_ytd_arr[indx].to_f - a_ytd_arr[indx].to_f) : (a_ytd_arr[indx].to_f -  b_ytd_arr[indx].to_f)
          else
            var_ytd_arr[indx] =  b_ytd_arr[indx].to_f - a_ytd_arr[indx].to_f
          end
          per_ytd_arr[indx] =  (var_ytd_arr[indx] * 100) / b_ytd_arr[indx].to_f
          if  b_ytd_arr[indx].to_f==0
            per_ytd_arr[indx] = ( a_ytd_arr[indx].to_f == 0 ? 0 : -100 )
          end
          per_ytd_arr[indx]= 0.0 if per_ytd_arr[indx].to_f.nan?
        end
        pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'b_ytd')
        pf.january= b_ytd_arr[0];pf.february=b_ytd_arr[1];pf.march=b_ytd_arr[2];pf.april=b_ytd_arr[3];pf.may=b_ytd_arr[4];pf.june=b_ytd_arr[5];pf.july=b_ytd_arr[6];pf.august=b_ytd_arr[7];pf.september=b_ytd_arr[8];pf.october=b_ytd_arr[9];pf.november=b_ytd_arr[10];pf.december=b_ytd_arr[11];pf.save
        pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'c_ytd')
        pf.january= a_ytd_arr[0];pf.february=a_ytd_arr[1];pf.march=a_ytd_arr[2];pf.april=a_ytd_arr[3];pf.may=a_ytd_arr[4];pf.june=a_ytd_arr[5];pf.july=a_ytd_arr[6];pf.august=a_ytd_arr[7];pf.september=a_ytd_arr[8];pf.october=a_ytd_arr[9];pf.november=a_ytd_arr[10];pf.december=a_ytd_arr[11];pf.save

        pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_amt_ytd')
        pf.january= var_ytd_arr[0];pf.february=var_ytd_arr[1];pf.march=var_ytd_arr[2];pf.april=var_ytd_arr[3];pf.may=var_ytd_arr[4];pf.june=var_ytd_arr[5];pf.july=var_ytd_arr[6];pf.august=var_ytd_arr[7];pf.september=var_ytd_arr[8];pf.october=var_ytd_arr[9];pf.november=var_ytd_arr[10];pf.december=var_ytd_arr[11];pf.save
        pf = PropertyFinancialPeriod.find_or_initialize_by_source_id_and_source_type_and_pcb_type(itr.id, itr.class.to_s, 'var_per_ytd')
        pf.january= per_ytd_arr[0];pf.february=per_ytd_arr[1];pf.march=per_ytd_arr[2];pf.april=per_ytd_arr[3];pf.may=per_ytd_arr[4];pf.june=per_ytd_arr[5];pf.july=per_ytd_arr[6];pf.august=per_ytd_arr[7];pf.september=per_ytd_arr[8];pf.october=per_ytd_arr[9];pf.november=per_ytd_arr[10];pf.december=per_ytd_arr[11];pf.save
      end
    end
    puts "Successfully YTD values calculated"
  end
end

namespace :bulk_uploads do
  desc "Create bulk upload folders for every old users."
  task :create_folders=> :environment do
    users = User.find_by_sql("select id from users where login <> 'admin' and id not in ( select user_id from folders where name ='Bulk Uploads' and parent_id = -2 )")
    users.each do |itr|
      portfolio_for_bulk_upload = Portfolio.find_or_create_by_user_id_and_name_and_portfolio_type_id(itr.id,'portfolio_created_by_system_for_bulk_upload',2)
      property_for_bulk_upload = RealEstateProperty.find_or_create_by_user_id_and_property_name_and_portfolio_id(itr.id,'property_created_by_system_for_bulk_upload',portfolio_for_bulk_upload.id)
      property_for_bulk_upload.no_validation_needed = 'true'
      property_for_bulk_upload.save
      folder_bulk = Folder.find_or_create_by_name_and_user_id_and_parent_id_and_is_master_and_portfolio_id_and_real_estate_property_id(:name =>"Bulk Uploads", :user_id => itr.id, :parent_id =>-2, :is_master =>1, :portfolio_id => portfolio_for_bulk_upload.id, :real_estate_property_id => property_for_bulk_upload.id)
      folder_year_bulk = Folder.find_or_create_by_name_and_user_id_and_parent_id_and_is_master_and_portfolio_id_and_real_estate_property_id(:name =>"#{Date.today.year}", :user_id => itr.id, :parent_id =>folder_bulk.id, :is_master =>1,  :portfolio_id => portfolio_for_bulk_upload.id, :real_estate_property_id => property_for_bulk_upload.id)
      12.downto(1).each do |mo|
       Folder.find_or_create_by_name_and_user_id_and_parent_id_and_is_master_and_portfolio_id_and_real_estate_property_id(:name =>"#{Date::MONTHNAMES[mo].slice(0,3)}", :user_id => itr.id, :parent_id =>folder_year_bulk.id,:is_master =>1, :portfolio_id => portfolio_for_bulk_upload.id, :real_estate_property_id => property_for_bulk_upload.id, :created_at => "#{1.second.since(Folder.last.created_at)}")
      end
    end
  end
end