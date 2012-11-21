module Admin::DbSettingsHelper

	def find_db_setting(id)
		@db_setting = DbSettings.find(params[:id])
		@add_property = @db_setting.add_property
		@property_select = @db_setting.property_select
	end

	def find_db_setting_items(user_id)
		@db_setting_item = DbSettings.find_by_user_id(user_id)
		if @db_setting_item
		@add_property = @db_setting_item.add_property
		@property_select = @db_setting_item.property_select
		@server_name = @db_setting_item.accounting_system_type
		end
	end
end
