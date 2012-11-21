class ClientAdmin::AccountingController < ApplicationController
	before_filter :user_required
	 layout "client_admin"

  def index
    chart_accounts=ChartOfAccount.by_client_ids(current_user.client_id)
		@chart_accounts_count=chart_accounts.count
		@chart_accounts=chart_accounts.paginate(:per_page=>25,:page=>params[:page])
  end

	def edit
		@chart_of_account=ChartOfAccount.find_by_id_and_client_id(params[:id],current_user.client_id)
	 @type_name=@chart_of_account.accounting_system_type.type_name
	 @income_statement=Account.chart_account_id("Inc Stmt",@chart_of_account.id)
	 cash_statement=Account.chart_account_id("CF Stmt",@chart_of_account.id)
	 @income_cash_statement=@income_statement+cash_statement
	 unless @chart_of_account.line_items.present?
	 @chart_of_account.line_items.build
 end
 unless @chart_of_account.capital_expenditures.present?
	 @chart_of_account.capital_expenditures.build
 end
 unless @chart_of_account.main_headers.present?
	 @chart_of_account.main_headers.build
 end


	end

	def account_tree
		@chart_id=params[:chart]
		@financial_statement=Account::FINANCIAL_STATEMENT.index(params[:statement_type])
		@accounts=Account.chart_account_id(params[:statement_type],params[:chart])
	end

	def update_line_items
		@account=ChartOfAccount.find(params[:id])
		@account.update_attributes(params[:chart_of_account])
		redirect_to :controller =>"/client_admin/accounting",:action => "edit",:id => @account.id,:edit_account => 'true'
	end

end
