module Admin::LogosHelper
  def display_type_names(p)
    client_ids = Client.find_by_id(p.try(:attachable_id)).try(:accounting_system_type_ids)
    type_name = AccountingSystemType.where(:id => client_ids).map(&:type_name) if client_ids.present?
    type_name || []
  end

  def link_to_add_chart(name, f, association)
    new_object = f.object.class.reflect_on_association(association).klass.new
    fields = f.fields_for(association, new_object, :child_index => "new_#{association}") do |builder|
      render(association.to_s.singularize + "_fields", :f => builder)
    end
    link_to_function(name, "add_chart_fields(this, \"#{association}\", \"#{escape_javascript(fields)}\")", :id => "add_chart_fields")
  end

  def link_to_remove_chart_fields(name, f)
    f.hidden_field(:_destroy) + link_to_function(name, "remove_chart_fields(this)")
  end

  def create_client_admin
    if @client.blank? || @client.try(:id).blank?
      @client = Client.new params[:client]
    else
      @client.update_attributes(params[:client])
    end
    @client.name = params[:user][:company_name]
    @client.email = params[:user][:email]
    if @user.blank? || @user.try(:id).blank?
      @user = User.new(params[:user])
    else
      @user.update_attributes(params[:user])
    end
    @user.roles << Role.find_by_name('Client Admin')
    @user.roles << Role.find_by_name('Asset Manager')
    password = @user.generate_password
    @user.password , @user.password_confirmation , @user.login = password , password , params[:user][:email]
    if @portfolio_image.blank? || @portfolio_image.try(:id).blank?
      @portfolio_image = PortfolioImage.new(params[:portfolio_image])
    else
      @portfolio_image.update_attributes(params[:portfolio_image])
    end
    @portfolio_image.attachable_type = "Client"
    user_valid = @user.valid?
    client_valid = @client.valid?
    portfolio_valid = @portfolio_image.valid?
    chart_account_valid = params[:client][:chart_of_accounts_attributes].present? && params[:client][:chart_of_accounts_attributes]["0"][:name].present? ? true : false
    return user_valid,client_valid,portfolio_valid,chart_account_valid
    #    acc_sys_types = []
    #    sys_ids = AccountingSystemType.where(:id => @client.try(:accounting_system_type_ids))
    #    acc_sys_types = sys_ids.map(&:type_name) if sys_ids.present?
    #    UserMailer.clientadmin_setting(acc_sys_types,@user).deliver
  end

  def update_client_admin
    @portfolio_image = PortfolioImage.find(params[:id])
    @portfolio_image.update_attributes(params[:portfolio_image]) if params[:portfolio_image].present?
    client_id = @portfolio_image.try(:attachable_id)
    @client = Client.find  client_id
    @client.update_attributes params[:client]
    @client.name = params[:user][:company_name]
    @client.email = params[:user][:email]
    @client.portfolio_image_id = @portfolio_image.id
    @user = User.find params[:user_id]
    @user.name =  params[:user][:name]
    @user.company_name =  params[:user][:company_name]
    @user.email =  params[:user][:email]
#    password = @user.generate_password
    @user.login = params[:user][:email]
    @user.is_asset_edit = true
    user_valid = @user.valid?
    client_valid = @client.valid?
    chart_account_valid = params[:client][:chart_of_accounts_attributes].present? && params[:client][:chart_of_accounts_attributes]["0"][:name].present? ? true : false
    return user_valid,client_valid,chart_account_valid
    #    acc_sys_types = []
    #    sys_ids = AccountingSystemType.where(:id => client.try(:accounting_system_type_ids))
    #    acc_sys_types = sys_ids.map(&:type_name) if sys_ids.present?
    #    UserMailer.clientadmin_setting(acc_sys_types,user).deliver
  end

  def destroy_client_admin
    portfolio_image  = PortfolioImage.find(params[:id])
    client_id = portfolio_image.try(:attachable_id)
    if client_id.present?
      portfolio_image.destroy
      client = Client.find_by_id(client_id)
      client.destroy
    end
  end

  def send_mail_to_client
    acc_sys_types = []
    sys_ids = AccountingSystemType.where(:id => @client.try(:accounting_system_type_ids))
    acc_sys_types = sys_ids.map(&:type_name) if sys_ids.present?

#    UserMailer.clientadmin_setting(acc_sys_types,@user).deliver

  end
end
