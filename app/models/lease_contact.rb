class LeaseContact < ActiveRecord::Base
  belongs_to :contact, :polymorphic => true
  def self.create_contacts(*args)
    args = args.extract_options!
    lease_contact = self.create(:name => args[:contact_name],:address => args[:tenant_address],:phone => args[:phone],:email => args[:email],:fax => args[:fax],:contact_id => args[:contact_id],:contact_type => 'Tenant')
    self.create(:name => args[:billing_name],:address => args[:billing_address],:phone => args[:phone],:email => args[:email],:fax => args[:fax],:contact_id => args[:contact_id],:contact_type => "TenantBilling") if args[:billing_name].present? || args[:billing_address].present?
    self.create(:name => args[:notice_name],:address => args[:notice_address],:phone => args[:phone],:email => args[:email],:fax => args[:fax],:contact_id => args[:contact_id],:contact_type => "TenantNotice") if args[:notice_name].present? || args[:notice_address].present?
    self.create(:name => args[:assignee_contact],:address => args[:tenant_address],:phone => args[:phone],:email => args[:email],:fax => args[:fax],:contact_id => args[:contact_id],:contact_type => "TenantSubLease") if args[:assignee_contact].present?
    lease_contact
  end

  def self.store_insurance_contacts(params,insurid)
    self.create(:contact_type => "InsuranceBrokerContact", :contact_id => insurid,:name =>  params[:broker_name], :email => params[:broker_email]) if params[:broker_email].present? || params[:broker_name].present?
    self.create(:contact_type => "InsuranceCarrierContact", :contact_id => insurid,:name =>  params[:carrier_name]) if params[:carrier_name].present?
  end

end
