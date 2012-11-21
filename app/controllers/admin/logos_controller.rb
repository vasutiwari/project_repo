class Admin::LogosController < ApplicationController
  layout 'admin', :except=>"new_accounting_system_type"
  before_filter :admin_login_required
  before_filter :new_portfolio_image, :only=>['new','create']


  def index
    @logos = PortfolioImage.find(:all , :conditions => ["attachable_type = 'Client' and attachable_id != 'NULL'"]).paginate(:page => params[:page],:per_page => 10)
  end

  def new
    @client = Client.new
    @client.chart_of_accounts.build
    @user = User.new
  end

    def prop_type
     @super=SuperAdminTemplate.find_by_sql("select * from super_admin_templates where template_id=1")
     puts( @super.first.inspect)
     puts( @super.first.inspect)
     puts( @super.first.inspect)
     PropertyType.all.each do |p|
       Template.create(:folder_name =>@super.first.folder_name,:parent_id => @super.parent_name,:property_type_name => p.name,:client_id=>cur)
      end
    end


  def create
    user_valid,client_valid,portfolio_valid,chart_account_valid = create_client_admin
    if params[:portfolio_image].blank?
      @error = "Please upload the Image"
    end
     if user_valid && client_valid && portfolio_valid && chart_account_valid



       @client.save

      @user.client_id = @client.id
      @user.password_code = User.random_passwordcode
      @user.save
       default_template_folder(@client)
      @portfolio_image.attachable_id = @client.id
      @portfolio_image.user_id = @user.id
      @portfolio_image.filename = 'login_logo' #added to display the logo based on the changes in complay tab#
      @portfolio_image.save
      @client.update_attributes(:portfolio_image_id => @portfolio_image.id)
      send_mail_to_client
      redirect_to  admin_logos_path
    else
      @client.chart_of_accounts.build if !@client.try(:chart_of_accounts).present?
      render :action => :new
    end
  end


  #create default folders in template table
  def default_template_folder(recent_client)
    #@super=SuperAdminTemplate.find_by_sql("select * from super_admin_templates where template_id=1")
    #@super=SuperAdminTemplate.where("template_id=?",1)
    @user=User.where("id = ?",current_user.id)

    PropertyType.all.each do |p|
      default_template_id=Template.maximum(:template_id)
      if default_template_id == nil
        temp_id=1
       else
         temp_id=default_template_id+1
       end
      temp_name=recent_client.name + "_" + p.name + "_" + "template"
    SuperAdminTemplate.all.each do |q|

      var_parent_id=q.parent_id
      if var_parent_id ==0
        @template_default_folder=Template.new
        @template_default_folder.folder_name=q.folder_name
        @template_default_folder.parent_id=q.parent_id
        @template_default_folder.property_type_name=p.name
        @template_default_folder.client_id=recent_client.id
        @template_default_folder.template_id=temp_id
        @template_default_folder.is_editable=false
        @template_default_folder.template_name=temp_name
        @template_default_folder.created_date=Date.today
        @template_default_folder.updated_date=Date.today
        @template_default_folder.save
       else
         puts(p.name)
         puts(p.name)
         puts(p.name)
         puts(p.name)
         puts(p.name)
         @super_parent_folder_name=SuperAdminTemplate.where("id=?",var_parent_id)
           default_template_sub_folder(p,recent_client.id,@super_parent_folder_name.first.folder_name,q.folder_name,temp_id,temp_name)

      end
    end

    end
  end



    def default_template_sub_folder(property_type,company_id,var_parent_folder_name,current_sub_folder_name,super_template_id,default_template_name)
      @parent_folder=Template.where("folder_name=?",var_parent_folder_name).order("id DESC")
      @template_default_sub_folder=Template.new
      @template_default_sub_folder.folder_name=current_sub_folder_name
      @template_default_sub_folder.parent_id=@parent_folder.first.id
      @template_default_sub_folder.client_id=company_id
      @template_default_sub_folder.property_type_name=property_type.name
      @template_default_sub_folder.template_id=super_template_id
      @template_default_sub_folder.template_name=default_template_name
      @template_default_sub_folder.is_editable=false
      @template_default_sub_folder.created_date=Date.today
      @template_default_sub_folder.updated_date=Date.today
      @template_default_sub_folder.save

    end

  def edit
    @portfolio_image = PortfolioImage.find(params[:id]) unless params[:id].blank?
    @user = @portfolio_image.try(:user)
    @client = @user.try(:client)
  end

  def update
    user_valid,client_valid,chart_account_valid = update_client_admin
     if user_valid && client_valid && chart_account_valid
      @client.save
#      @user.password_code = User.random_passwordcode
      @user.save
      send_mail_to_client
      redirect_to  admin_logos_path
    else
      @client.chart_of_accounts.build if !@client.try(:chart_of_accounts).present?
      render :action => :edit
    end
  end

  def destroy
    destroy_client_admin
    redirect_to admin_logos_path
  end

  def new_portfolio_image
    @portfolio_image = PortfolioImage.new
  end

  def new_accounting_system_type
    if params[:acc_sys_name] && !params[:acc_sys_name].blank?
      acc_sys=AccountingSystemType.find_or_create_by_type_name(params[:acc_sys_name].strip)
      responds_to_parent do
        render :update do |page|
          page << "Control.Modal.close();"
          page << "jQuery('#client_type_accounting_system_types').append('<option selected=\"selected\" value=\"#{acc_sys.id}\">#{acc_sys.type_name}</option>')"
          page.call "flash_writter", "Accounting System Type successfully created"
        end
      end
    end
  end
end
