class CapitalExpenditureExplanation < ActiveRecord::Base
  belongs_to :user
  belongs_to :property_capital_improvement
  acts_as_commentable
  belongs_to :document

  def self.cap_exp_explanation(id,month,ytd_check)
    return CapitalExpenditureExplanation.find_by_property_capital_improvement_id_and_month_and_ytd(id,month,ytd_check)
  end

  #Save variance tab cap exp explanations
  def save_variance_tab_cap_exp_explanations(params,financial_month)
    if params[:type] == 'cap_exp' #Save variance tab cap exp explanations
      if params[:expid].present?
       expln = CapitalExpenditureExplanation.find_by_id_and_property_capital_improvement_id_and_month_and_ytd(params[:expid],params[:id],params[:month],params[:is_ytd_explanation]) if params[:expid]
       expln.update_attributes(:explanation=>params[:expln],:user_id=>current_user.id,:ytd=>params[:is_ytd_explanation])
      else
      expln = CapitalExpenditureExplanation.new
      expln.property_capital_improvement_id = params[:id]
      if params[:period] == "4"
        params[:month] = financial_month
      elsif params[:period]  == "8" || params[:period] == "3"
        params[:month] = 12
      end
        expln.month = params[:month]
        item = PropertyCapitalImprovement.find_by_id(params[:id]).tenant_name.strip
      end
    elsif params[:type] == 'leases'
      expln = LeasesExplanation.find(:first, :conditions=>['id = ? and month = ?', params[:id], params[:month]])
      expln = LeasesExplanation.new if expln.nil?
      expln.id = params[:id]
    else
      expln = IncomeCashFlowExplanation.find(:first, :conditions=>['income_and_cash_flow_detail_id=? and month = ? and ytd =?', params[:id], params[:month], params[:is_ytd_explanation]])
      exp_id_to_delete = nil if expln.nil?
      expln = IncomeCashFlowExplanation.new if expln.nil?
      expln.income_and_cash_flow_detail_id = params[:id]
      item = IncomeAndCashFlowDetail.find_by_id(params[:id]).title.strip
    end
    expln.document_id = params[:document] if params[:type] != 'leases'
    expln.explanation = params[:expln].strip unless params[:dummy_rec]
    if !params[:dummy_rec] && params[:type] != 'leases'
      self.collection_exp_comments[current_user.id] = {} if self.collection_exp_comments[current_user.id].nil?
      expln.explanation = params[:expln].strip
      if (self.collection_exp_comments[current_user.id].empty? or !self.collection_exp_comments[current_user.id].has_key?(item))
        self.collection_exp_comments[current_user.id].update({item=>{'explanation'=>params[:expln].strip}})
      else
        self.collection_exp_comments[current_user.id][item]['explanation'] = params[:expln].strip
      end
    end
    expln.month = params[:month]
    chk_new =  expln.new_record? ? true : false
    expln.user_id = current_user.id
    expln.ytd = params[:is_ytd_explanation] if params[:type] != 'leases'
    expln.save
  end
end
