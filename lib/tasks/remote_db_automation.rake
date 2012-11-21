# remote db automation rake tasks..
namespace :automate do
  task :extract_griffin=> :environment do
    # Here the RealEstateProperty is just faked to remote properties.
    refs = "" # reference tables that are added in our system
    new_refs = "" # check whether new properties.
    rp = []
    str_params_to_sh = "" # params to the shell script
    accounting_system_type_id = AccountingSystemType.find_by_sql("select a.accounting_system_type_id from db_settings a  left join  remote_accounting_system_types r on a.accounting_system_type_id = r.accounting_system_type_id  where  r.table_name = 'Griffin'").try(:first).try(:accounting_system_type_id)
    if accounting_system_type_id.present?
      rp = RealEstateProperty.find_by_sql("select * from timestamp_logs where accounting_system_type_id = #{accounting_system_type_id} and table_name='Total'")
      prop = RealEstateProperty.find_by_sql "select group_concat(HMY) as refs from remote_properties where accounting_system_type_id = #{accounting_system_type_id} and is_new IS NULL group by accounting_system_type_id"
      new_props = RealEstateProperty.find_by_sql "select group_concat(HMY) as refs from remote_properties where accounting_system_type_id = #{accounting_system_type_id} and is_new group by accounting_system_type_id"
      ActiveRecord::Base.connection.execute("update remote_properties set is_new = NULL where is_new and accounting_system_type_id = #{accounting_system_type_id}")
      refs = prop.first.refs unless prop.blank?
      new_refs = new_props.first.refs unless new_props.blank?
      rp = rp.first unless rp.blank?
      if refs.present? and rp.present?
        if new_refs.blank?
          str_params_to_sh = "#{rp.table_name}\n#{rp.last_ts}\n#{refs}\n"
        else
          str_params_to_sh = "#{rp.table_name}\n#{rp.last_ts}\n#{refs}\n#{new_refs}\n"
        end
      end
      params_file = File.open(Rails.root.to_s+'/autoParams.txt','w')
      params_file.write(str_params_to_sh) unless str_params_to_sh.blank?
      params_file.close
    else
      puts "Accounting System Type is not Avilable"
    end
  end
  
  task :extract_property=> :environment do
    accounting_system_type_id = AccountingSystemType.find_by_sql("select a.accounting_system_type_id from db_settings a  left join  remote_accounting_system_types r on a.accounting_system_type_id = r.accounting_system_type_id  where  r.table_name = 'Griffin'").try(:first).try(:accounting_system_type_id)
    if accounting_system_type_id.present?
      # Here the RealEstateProperty is just faked to remote properties.
      refs = "" # reference tables that are added in our system
      rp = []
      str_params_to_sh = "" # params to the shell script
      rp = RealEstateProperty.find_by_sql("select * from timestamp_logs where accounting_system_type_id = #{accounting_system_type_id} and table_name='Property'")
      unless rp.blank?
        rp = rp.first
        str_params_to_sh = "#{rp.table_name}\n#{rp.last_ts}\n"
      end
      params_file = File.open(Rails.root.to_s+'/autoParams.txt','w')
      params_file.write(str_params_to_sh) unless str_params_to_sh.blank?
      params_file.close
    else
      puts "Accounting System Type is not Avilable"
    end
  end
  
  # Automation part for the leases related tables.
  task :extract_leases=> :environment do
    accounting_system_type_id = AccountingSystemType.find_by_sql("select a.accounting_system_type_id from db_settings a  left join  remote_accounting_system_types r on a.accounting_system_type_id = r.accounting_system_type_id  where  r.table_name = 'Griffin'").try(:first).try(:accounting_system_type_id)
    tbl_name = ENV['table'] ||= ''
    
    if accounting_system_type_id.present? && tbl_name.present?
      # Here the RealEstateProperty is just faked to remote properties.
      rp = []
      str_params_to_sh = "" # params to the shell script
      rp = RealEstateProperty.find_by_sql("select * from timestamp_logs where accounting_system_type_id =#{accounting_system_type_id} and table_name='#{tbl_name}'")
      unless rp.blank?
        rp = rp.first
        str_params_to_sh = "#{rp.table_name}\n#{rp.last_ts}\n"
      end
      params_file = File.open(Rails.root.to_s+'/autoParams.txt','w')
      params_file.write(str_params_to_sh) unless str_params_to_sh.blank?
      params_file.close
    else
      puts "Accounting System Type is not Avilable" if accounting_system_type_id.blank?
      puts "Please specify table name" if tbl_name.blank?
    end
  end
  
end