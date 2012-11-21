class Note < ActiveRecord::Base
  belongs_to :note, :polymorphic => true#, :dependent => :destroy
  before_save :restrict_default_value
  before_save :update_client_id_for_note
  def self.tenant_improve_note(params,tenant_improve_id)
    self.create(:note_type => "TenantImprovement",:content => params[:tenant_improvement_note],:note_id => tenant_improve_id) if params[:tenant_improvement_note].present?
    self.create(:note_type => "TenantImprovement",:content => params[:tenant_improvement_note_1],:note_id => tenant_improve_id) if params[:tenant_improvement_note_1].present?
    self.create(:note_type => "TenantImprovement",:content => params[:tenant_improvement_note_2],:note_id => tenant_improve_id) if params[:tenant_improvement_note_2].present?
    self.create(:note_type => "TenantImprovement",:content => params[:tenant_improvement_note_3],:note_id => tenant_improve_id) if params[:tenant_improvement_note_3].present?
    self.create(:note_type => "TenantImprovement",:content => params[:tenant_improvement_note_4],:note_id => tenant_improve_id) if params[:tenant_improvement_note_4].present?
  end

  def self.leasing_commision_note(params,leasing_commision_id)
    self.create(:note_type => "LeasingCommission",:content => params[:leasing_commision_note],:note_id => leasing_commision_id) if params[:leasing_commision_note].present?
  end

  def self.cap_ex_note(params,capexid)
    self.create(:note_type => "CapEx",:content => params[:cap_ex_note],:note_id => capexid) if params[:cap_ex_note].present?
  end

  def self.other_exp_note(params,other_exp_id)
    self.create(:note_type => "OtherExp",:content => params[:other_exp_note],:note_id => other_exp_id) if params[:other_exp_note].present?
    self.create(:note_type => "OtherExp",:content => params[:other_exp_note_1],:note_id => other_exp_id) if params[:other_exp_note_1].present?
    self.create(:note_type => "OtherExp",:content => params[:other_exp_note_2],:note_id => other_exp_id) if params[:other_exp_note_2].present?
    self.create(:note_type => "OtherExp",:content => params[:other_exp_note_3],:note_id => other_exp_id) if params[:other_exp_note_3].present?
    self.create(:note_type => "OtherExp",:content => params[:other_exp_note_4],:note_id => other_exp_id) if params[:other_exp_note_4].present?
  end

  def self.create_notes(*args)
    args = args.extract_options!
    self.create(:content => args[:content],:note_type => args[:note_type],:note_id => args[:note_id])
  end

  # adding current_client_id before saving to db
  def update_client_id_for_note
    self.client_id = Client.current_client_id
  end

  #for lease suite notes start
  def self.lease_suite_note_data(suite_content,suite_id)
    self.create(:note_type => "Suite",:content => suite_content,:note_id => suite_id)
  end

  def lease_suite_note_update(suite_content,suite_id)
    self.update_attributes(:note_type => "Suite",:content => suite_content,:note_id => suite_id)
  end
  #for lease suite notes end

  def restrict_default_value
    self.content = nil if self.content.eql?('Edit this text to see the text area expand and contract.')
  end
end
