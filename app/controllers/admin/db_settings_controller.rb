class Admin::DbSettingsController < ApplicationController
	before_filter :admin_required,:set_current_user
	before_filter :find_dbsettings,:only=>[:edit,:update]
	layout 'client_server'
	def index
		@db_settings_list = DbSettings.find(:all, :conditions=>['user_id = ?',current_user.id]).paginate(:page => params[:db_page],:per_page => 5)
	end

	def new
		@db_setting = DbSettings.new
	end

	def create
  	@db_setting = DbSettings.new(params[:db_setting])
		@db_setting.user_id = current_user.id
		@db_setting.client_id = current_client_id
    find_company_name
			if @db_setting.save
				params[:id] = @db_setting.id
				@db_setting = DbSettings.find_by_id(params[:id])
				roles_users = current_user.user_role(current_user.id)
				if roles_users == "Client Admin"
						acc_sys_type =AccountingSystemType.find(:all)
							i = 0
						  acc_sys_type.each do |x|
							if x.type_name.gsub(/\"/,'').include?("#{@company_name}")
							i = i+1
								 if x.type_name.gsub(/\"/,'').include?("#{@company_name}"+"#{i}")
									i = i+1
										@acc_sys_name = "#{@company_name}"+"#{i}" + "_" + "#{@db_setting.accounting_system_type}"
									else
											@acc_sys_name = "#{@company_name}"+"#{i}" + "_" + "#{@db_setting.accounting_system_type}"
									end
							else
							@acc_sys_name = "#{@company_name}" + "_" + "#{@db_setting.accounting_system_type}"
						end
						end
					elsif roles_users == "Server Admin"
				@acc_sys_name = "#{@company_name}" + "_" + "#{@db_setting.accounting_system_type}"
				end


		###To update the record in acc_sys_type
		@accounting_sys_type = AccountingSystemType.new
		@accounting_sys_type.type_name = @acc_sys_name
		@accounting_sys_type.save

		if @accounting_sys_type
		###To update the record in remote acc_system_type
		@remote_acc_sys_typename=RemoteAccountingSystemType.new
		@remote_acc_sys_typename.table_name = @acc_sys_name.split('_')[0]
		@remote_acc_sys_typename.accounting_system_type_id = @accounting_sys_type.id
		@remote_acc_sys_typename.save
		###To update the record in db settings
		###To update the record in client setings
		roles_users = current_user.user_role(current_user.id)
		@server_name = current_user.name
		@server_email = current_user.email

		if roles_users == "Client Admin"
		@client_admin_id = current_user.id
		@client_admin_details = ""
		@dbsetting_update = DbSettings.find_by_id(params[:id])
		@dbsetting_update.update_attribute(:accounting_system_type_id,@accounting_sys_type.id)
		UserMailer.server_db_setting(@client_admin_details,@db_setting,@acc_sys_name,@server_name,@server_email,roles_users).deliver
		elsif roles_users == "Server Admin"
		 @client_admin_id = ClientServerAdmins.where(:server_admin_id => current_user.id).map(&:client_admin_id).compact
		 @client_admin_details = User.find_by_id(@client_admin_id)
		 @dbsetting_update = DbSettings.find_by_user_id(current_user.id)
		 @dbsetting_update.update_attribute(:accounting_system_type_id,@accounting_sys_type.id)
		 UserMailer.server_db_setting(@client_admin_details,@db_setting,@acc_sys_name,@server_name,@server_email,roles_users).deliver
	 end
		@client_setting_update = ClientSetting.find(:all,:conditions=>['user_id = ?', @client_admin_id])
		@client_setting_update.each do |client_update|
		  accounting_sys_id = client_update.accounting_system_type_ids << @accounting_sys_type.id
		  client_update.update_attribute(:accounting_system_type_ids,accounting_sys_id)
		end
	end
	if roles_users == "Server Admin"
    redirect_to edit_admin_db_setting_path(:id=>params[:id])
		else
			flash[:notice] = 'Server has been created'
		redirect_to admin_client_admins_path
		end

else
		render :action => "new"
		end
	end

	def edit
		#~ @db_setting = DbSettings.find_by_id(params[:id])
    session[:db_id] = params[:id]
	  find_company_name
		@acc_sys_name = "#{@company_name}" + "_" + "#{@db_setting.accounting_system_type}"
	end

	def update
		#~ @db_setting = DbSettings.find_by_id(params[:id])
		find_company_name
    if @db_setting.update_attributes(params[:db_setting])
			 roles_users = current_user.user_role(current_user.id)
			 @server_name = current_user.name
			 @server_email = current_user.email
			 @acc_sys_name = "#{@company_name}" + "_" + "#{@db_setting.accounting_system_type}"
    		if roles_users == "Client Admin"
					@client_admin_details = ""
					UserMailer.server_db_setting(@client_admin_details,@db_setting,@acc_sys_name,@server_name,@server_email,roles_users).deliver
				redirect_to admin_client_admins_path
				elsif roles_users == "Server Admin"
					@client_admin_id = ClientServerAdmins.where(:server_admin_id => current_user.id).map(&:client_admin_id).compact
					@client_admin_details = User.find_by_id(@client_admin_id)
					UserMailer.server_db_setting(@client_admin_details,@db_setting,@acc_sys_name,@server_name,@server_email,roles_users).deliver
				 redirect_to edit_admin_db_setting_path(:id =>@db_setting.id )
			 end
      else
      render :action => "edit"
			end
	end

	def destroy
		db_setting = DbSettings.find_by_id(params[:id])
		find_company_name
		@server_name = current_user.name
		server_email = current_user.email
		@acc_sys_name = "#{@company_name}" + "_" + "#{db_setting.accounting_system_type}"
		db_setting.destroy
		roles_users = current_user.user_role(current_user.id)
			if roles_users == "Client Admin"
				@client_admin_details = ""
				UserMailer.server_db_setting(@client_admin_details,db_setting,@acc_sys_name,@server_name,server_email,roles_users).deliver
				redirect_to admin_client_admins_path
				elsif roles_users == "Server Admin"
					redirect_to admin_db_settings_path
			 end
		 end

		 def find_company_name
			 ###To identify company_name
		@user = User.find(:all,:conditions=>['id = ? and client_id = ?',current_user.id,current_client_id])
		@client_name = []
		@user.each do |user|
			@client_name  << user.company_name
		end
		 @company_name = @client_name.uniq.to_s
	 end

	 #To find dbsettings for edit and update
	 def find_dbsettings
		 @db_setting = DbSettings.find_by_id(params[:id])
	 end

end
