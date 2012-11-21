class IncomeCashFlowExplanation < ActiveRecord::Base
  belongs_to :user
  belongs_to :income_and_cash_flow_detail
  acts_as_commentable
  belongs_to :document
  def self.in_cash_flow_exp(id,month,ytd_check)
    return IncomeCashFlowExplanation.find(:first, :conditions => ["income_and_cash_flow_detail_id = ? and month = ? and ytd = ?",id,month,ytd_check])
  end
end
