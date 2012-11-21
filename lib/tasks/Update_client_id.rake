namespace :multi_tenant do
  desc 'updates client_id in DB'
  task :update_client_id => :environment do
    @connection = ActiveRecord::Base.connection();
    #@connection.execute("update users set client_id = 5 where email not in ('prem@railsfactory.org','prem@theamp.com') or email IS NULL and client_id IS NULL")
    #@connection.execute("update users set client_id = 7 where email in ('prem@railsfactory.org','prem@theamp.com')")
    User.all.each do |user|
      client_id = user.client_id
      @connection.execute("update events set client_id = #{client_id} where user_id = #{user.id}")
      @connection.execute("update db_settings set client_id = #{client_id} where user_id = #{user.id}")
      @connection.execute("update income_and_cash_flow_details set client_id = #{client_id} where user_id = #{user.id}")
      @connection.execute("update folders set client_id = #{client_id} where user_id = #{user.id}")
      @connection.execute("update shared_folders set client_id = #{client_id} where user_id = #{user.id}")
      @connection.execute("update amp_users_phone_calls set client_id = #{user.client_id} where user_id = #{user.id}")
      user.client_setting.update_attribute('client_id',client_id) if user.client_setting.present?
      real_estate_properties =  RealEstateProperty.find(:all,:conditions => "user_id = #{user.id}")
      real_estate_properties.each do |real_estate_property|
        real_estate_property_id = real_estate_property.id
        real_estate_property.no_validation_needed = 'true'
        real_estate_property.update_attributes(:client_id => client_id)
        @connection.execute("update remote_properties set client_id = #{client_id} where real_estate_property_id = #{real_estate_property_id}")
        @connection.execute("update property_suites set client_id = #{client_id} where real_estate_property_id = #{real_estate_property_id}")
        @connection.execute("update suites set client_id = #{client_id} where real_estate_property_id = #{real_estate_property_id}")
        @connection.execute("update parsing_logs set client_id = #{client_id} where real_estate_property_id = #{real_estate_property_id}")
        @connection.execute("update leases set client_id = #{client_id} where real_estate_property_id = #{real_estate_property_id}")
        real_estate_property.address.update_attribute('client_id',client_id) if real_estate_property.address
        real_estate_property.portfolio.update_attribute('client_id',client_id) if real_estate_property.portfolio
        leases_ids = real_estate_property.leases.compact.map(&:id)
        tenant_ids = PropertyLeaseSuite.where(:lease_id=> leases_ids.compact).compact.map(&:tenant_id)
        suite_ids = Suite.where(:real_estate_property_id=> real_estate_property_id).compact.map(&:id)
        document_ids = Document.where(:real_estate_property_id=> real_estate_property_id).compact.map(&:id)
        info_ids = Info.where(:tenant_id=>tenant_ids).compact.map(&:id)
        option_ids = Option.where(:tenant_id=>tenant_ids).compact.map(&:id)
        cap_ex_ids = CapEx.where(:lease_id=>leases_ids).compact.map(&:id)
        income_proj_ids = IncomeProjection.where(:lease_id=>leases_ids).compact.map(&:id)
        tenant_impro_ids = TenantImprovement.joins(:cap_ex=>:lease).where('leases.id' => leases_ids).compact.map(&:id)
        leasing_commision_ids = LeasingCommission.joins(:cap_ex=>:lease).where('leases.id' => leases_ids).compact.map(&:id)
        other_exp_ids = OtherExp.joins(:cap_ex=>:lease).where('leases.id' => leases_ids).compact.map(&:id)
        rent_schedule_ids = RentSchedule.joins(:rent=>:lease).where('leases.id' => leases_ids).compact.map(&:id)
        parking_ids = Parking.joins(:rent=>:lease).where('leases.id' => leases_ids).compact.map(&:id)
        recovery_ids = Recovery.joins(:rent=>:lease).where('leases.id' => leases_ids).compact.map(&:id)
        cpi_detail_ids = CpiDetails.joins(:rent=>:lease).where('leases.id' => leases_ids).compact.map(&:id)
        service_ids = Service.joins(:clause=>:lease).where('leases.id' => leases_ids).compact.map(&:id)
        hour_ids = Hour.joins(:clause=>:lease).where('leases.id' => leases_ids).compact.map(&:id)
        lease_joins = leases_ids.join(',')
        tenant_joins = tenant_ids.join(',')
        info_joins = info_ids.join(',')
        option_joins = option_ids.join(',')
        cap_ex_joins = cap_ex_ids.join(',')
        income_proj_joins = income_proj_ids.join(',')
        tenant_impro_joins = tenant_impro_ids.join(',')
        leasing_commision_joins = leasing_commision_ids.join(',')
        other_exp_joins = other_exp_ids.join(',')
        rent_schedule_joins = rent_schedule_ids.join(',')
        parking_joins = parking_ids.join(',')
        recovery_joins = recovery_ids.join(',')
        cpi_detail_joins = cpi_detail_ids.join(',')
        service_joins = service_ids.join(',')
        hour_joins = hour_ids.join(',')
        suite_joins = suite_ids.join(',')
        document_joins = document_ids.join(',')
        @connection.execute("update tenants set client_id = #{client_id} where id IN (#{tenant_joins})") if tenant_ids.present?
        @connection.execute("update comm_property_lease_suites set client_id = #{client_id} where lease_id IN (#{lease_joins})") if leases_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{tenant_joins}) AND note_type = 'Tenant'") if tenant_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{lease_joins}) AND note_type = 'Lease'") if leases_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{info_joins}) AND note_type = 'Info'") if info_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{option_joins}) AND note_type = 'Option'") if option_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{cap_ex_joins}) AND note_type = 'CapEx'") if cap_ex_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{income_proj_joins}) AND note_type = 'IncomeProjection'") if income_proj_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{tenant_impro_joins}) AND note_type = 'TenantImprovement'") if tenant_impro_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{leasing_commision_joins}) AND note_type = 'LeasingCommission'") if leasing_commision_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{other_exp_joins}) AND note_type = 'OtherExp'") if other_exp_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{rent_schedule_joins}) AND note_type = 'RentSchedule'") if rent_schedule_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{parking_joins}) AND note_type = 'Parking'") if parking_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{recovery_joins}) AND note_type = 'Recovery'") if recovery_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{cpi_detail_joins}) AND note_type = 'CpiDetails'") if cpi_detail_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{service_joins}) AND note_type = 'Service'") if service_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{hour_joins}) AND note_type = 'Hour'") if hour_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{suite_joins}) AND note_type = 'Suite'") if suite_ids.present?
        @connection.execute("update notes set client_id = #{client_id} where note_id IN (#{document_joins}) AND note_type = 'Document'") if document_ids.present?
      end
    end
  end
end  