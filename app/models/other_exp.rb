class OtherExp < ActiveRecord::Base

  # Associations
  belongs_to :cap_ex
  has_one :note, :as => :note,    :dependent => :destroy

  # Validations
  validates :amt_psf , :numericality => { :greater_than_or_equal_to  => 0 }, :if => Proc.new { |other_exp|  other_exp.amt_psf != nil }
  validates :tot_amt , :numericality => { :greater_than_or_equal_to => 0 },   :if => Proc.new { |other_exp|  other_exp.tot_amt != nil }

  accepts_nested_attributes_for :note
  def self.other_exp_data_push(params,capexid)
    self.create(:name => params[:name_other_exp],:amt_psf => params[:amt_psf_other_exp],:tot_amt => params[:tot_amt_other_exp],:cap_ex_id => capexid) if params[:name_other_exp].present? || params[:amt_psf_other_exp].present? || params[:tot_amt_other_exp].present?
    self.create(:name => params[:name_other_exp_1],:amt_psf => params[:amt_psf_other_exp_1],:tot_amt => params[:tot_amt_other_exp_1],:cap_ex_id => capexid) if params[:name_other_exp_1].present? || params[:amt_psf_other_exp_1].present? || params[:tot_amt_other_exp_1].present?
    self.create(:name => params[:name_other_exp_2],:amt_psf => params[:amt_psf_other_exp_2],:tot_amt => params[:tot_amt_other_exp_2],:cap_ex_id => capexid) if params[:name_other_exp_2].present? || params[:amt_psf_other_exp_2].present? || params[:tot_amt_other_exp_2].present?
    self.create(:name => params[:name_other_exp_3],:amt_psf => params[:amt_psf_other_exp_3],:tot_amt => params[:tot_amt_other_exp_3],:cap_ex_id => capexid) if params[:name_other_exp_3].present? || params[:amt_psf_other_exp_3].present? || params[:tot_amt_other_exp_3].present?
    self.create(:name => params[:name_other_exp_4],:amt_psf => params[:amt_psf_other_exp_4],:tot_amt => params[:tot_amt_other_exp_4],:cap_ex_id => capexid) if params[:name_other_exp_4].present? || params[:amt_psf_other_exp_4].present? || params[:tot_amt_other_exp_4].present?
  end

end
