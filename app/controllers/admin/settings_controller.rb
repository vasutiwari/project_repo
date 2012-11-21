class Admin::SettingsController < ApplicationController
  	layout 'admin'
		before_filter :admin_login_required
		before_filter :find_setting,:only=>['edit','update']
		
	def index
		@settings = Setting.find :all
	end

	def edit		
		render :layout => false
	end

	def update		
		@setting.update_attributes(:value=>params[:setting][:value])
		flash[:notice] = "Setting value updated successfuly for #{@setting.name}"
		redirect_to admin_settings_path
	end
	
	def find_setting
		@setting = Setting.find params[:id]
	end	
end