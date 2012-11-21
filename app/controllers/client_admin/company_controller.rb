class ClientAdmin::CompanyController < ApplicationController
  before_filter :user_required
  layout "client_admin"
  before_filter :check_current_user,:only => ["edit","update"]
  before_filter :check_portfolio_image_and_client, :check_accounting_syste_types, :only => [:edit]

  def check_current_user
    @user = current_user
  end

  def edit
    #~ @user = current_user
  end

  def update
    #~ @user = current_user
    @user.is_asset_edit=true
    @client = current_user.client
    @portfolio_image = PortfolioImage.find_by_user_id_and_attachable_type(current_user.id,"Client")
    #~ @portfolio_image = PortfolioImage.find_by_user_id_and_attachable_type(current_user.id,"ClientSetting")
    @portfolio_image.uploaded_data = params[:portfolio_image][:uploaded_data] if(@portfolio_image.present? && params[:portfolio_image])
    if @user.valid? && @portfolio_image.present? && @portfolio_image.valid?
      @user.update_attributes(params[:client_admin_form])
      @client.update_attributes(params[:client])
      @portfolio_image.save
      redirect_to edit_client_admin_company_path(@user, @client)
    else
      check_portfolio_image_and_client if @portfolio_image.blank?
      check_accounting_syste_types if @accounting_type_names.blank?
      render :edit
    end

  end

  private

  def  check_portfolio_image_and_client
    #~ @portfolio_image = PortfolioImage.find_by_user_id_and_attachable_type(current_user.id,"ClientSetting")
    @portfolio_image = PortfolioImage.find_by_user_id_and_attachable_type(current_user.id,"Client")
    if @portfolio_image.blank?
      @portfolio_image = PortfolioImage.create(:filename => "amp-logo.png", :content_type => "image/png", :attachable_type => "ClientSetting", :height => 35, :width => 104, :size => "3036", :user_id => current_user.id)
      #  PortfolioImage.create(:filename => "amp-logo_client_image_index.png", :content_type => "image/png", :thumbnail => "client_image_index",  :attachable_type => "ClientSetting", :height => 42, :width => 42, :size => "3036", :parent_id => @portfolio_image.id)
      # PortfolioImage.create(:filename => "amp-logo_client_image_edit.png", :content_type => "image/png", :thumbnail => "client_image_edit", :attachable_type => "ClientSetting", :height => 60, :width => 60, :size => "3036", :parent_id => @portfolio_image.id)
      #PortfolioImage.create(:filename => "amp-logo_thumb.png", :content_type => "image/png", :thumbnail => "thumb", :attachable_type => "ClientSetting", :height => 83, :width => 172, :size => "3036", :parent_id => @portfolio_image.id)
    end
    @client = current_user.client

    if @client.blank?
      client = Client.find_by_name("Demo")
      current_user.client_id = client.try(:id)
      current_user.save(false)
    end
  end

  def check_accounting_syste_types
    accounting_system_type_ids = current_user.client.try(:accounting_system_type_ids) || []
    @accounting_type_names = AccountingSystemType.where(:id => accounting_system_type_ids).map(&:type_name) || []
  end

end
