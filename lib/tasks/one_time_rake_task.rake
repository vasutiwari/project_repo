namespace :one_time_rake_task do
  # The purpose this rake task is to add old lease records
  desc "One time rake task for creating lease rent roll records for previous data"
  task :update_old_lease_rent_roll_records => :environment do
    begin 
      leases = Lease.current_leases.join_property_lease_suites.each do |lease| 
        property_lease_suite = lease.property_lease_suite
        if property_lease_suite.present?
          property_lease_suite.update_lease_rent_roll
          tenant = lease.tenant
          if tenant.present?
            tenant.update_lease_rent_roll(true) 
            option = tenant.options.first
            option.update_lease_rent_roll(true) if option.present?
          end
          rent = lease.rent
          if rent.present?
            first_recovery = rent.recoveries.first
            first_recovery.update_lease_rent_roll(true) if first_recovery.present?
            rent_schedules = rent.rent_schedules
            if rent_schedules.present?
              rent_schedules.each do |rent_schedule|
                rent_schedule.update_lease_rent_roll(true)
              end
            end
            percentage_sales_rents = rent.percentage_sales_rents
            if percentage_sales_rents.present?
              percentage_sales_rents.each do |percentage_sales_rent|
                percentage_sales_rent.update_lease_rent_roll(true) if percentage_sales_rent.present?
              end
            end
          end
          cap_ex = lease.cap_ex
          if cap_ex.present?
            cap_ex.update_lease_rent_roll(true)
            first_tenant_improvement = cap_ex.tenant_improvements.first
            first_tenant_improvement.update_lease_rent_roll(true) if first_tenant_improvement.present?
            first_leasing_commission = cap_ex.leasing_commissions.first
            first_leasing_commission.update_lease_rent_roll(true) if first_leasing_commission.present?
          end
        end
      end  
    rescue => e
      puts "Exception had been raised with message: #{e.message}"
    end
  end
  
  desc "One time rake task for adding records for each client admin colloborators"
  task :rake_task_for_creating_Client_admin_collaborators => :environment do
    client_admins = User.where(:id => [9,29,61,95]) # why i put ids because they main client admins till now
    client_admins.each do |client_admin|
      client = client_admin.client
      users = client.users.reject{|user| user.email==client_admin.email}
      users.each do |user|
        Collaborator.find_or_create_by_user_1_id_and_user_2_id(client_admin.id, user.id) 
      end
    end
  end
end