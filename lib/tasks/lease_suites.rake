  namespace :lease_suites do
  desc "Updating suites status"
  task :update_suite_status => :environment do
    leases =  Lease.all
        leases.each do |lease|
					lease.change_lease_status
			end
		end
				
	desc "Updating lease status and occupancy type monthly"
  task :update_lease_status => :environment do
    leases =  Lease.all
        leases.each do |lease|
					Lease.update_lease_status(lease)
					Lease.update_lease_occupancy_type(lease)
			end
		end
end