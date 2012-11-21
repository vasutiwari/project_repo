class Admin::AccountingSystemTypesController < ApplicationController
  layout "admin"
  before_filter :admin_login_required

  def index
    @accounting_system_types = AccountingSystemType.all.paginate(:page => params[:page] , :per_page => 10)
  end

  def new
    @accounting_system_type = AccountingSystemType.new
  end

  def create
    @accounting_system_type = AccountingSystemType.new(:type_name => params[:accounting_system_type][:type_name].strip)
    if @accounting_system_type.valid?
      @accounting_system_type.save
      redirect_to admin_accounting_system_types_path
    else
      render :action => :new
    end
  end

end
