class ClientAdmin::SettingsController < ApplicationController
  before_filter :user_required
  layout "client_admin"
  before_filter :client_current_user, :only => [:check_client,:update,:edit]
  before_filter :check_client, :only => [:edit]


  def update
    #~ @client = current_user.client
    if @client.update_attributes(params[:client])
      redirect_to edit_client_admin_setting_path(current_user, @client,:updated=>true)
    else
      render :edit
    end
  end

  def check_client
    #~ @client = current_user.client
    if @client.blank?
      client = Client.find_by_name("Demo")
      current_user.client_id = client.try(:id)
      current_user.save(false)
    end
  end

  def client_current_user
  @client = current_user.client
  end

end
